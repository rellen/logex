# JF2 · Judging track F (M2-5, user function blocks): online edit, host contract, naming, mutation

Judge JF2, 2026-10-02. I judged the two designs, F1 (`scratchpad/m2/F1.md`, `F1.patch`) and F2
(`scratchpad/m2/F2.md`, `F2.patch`), against `/home/user/logex` at `47319f7`. I did not modify
that repository; `git status` there is empty at the end of this pass.

My lens was how each design fits logex in four areas:
- online edit: `Logex.Edit` on a program that holds block instances, and whether anything
  escapes or is misreported;
- the host contract;
- naming and reserved words;
- tests and mutation strength. I reverted five rules of each spike myself, and one more of F2.

Every claim below comes with the command I ran and its output, or with a quotation of the
decided rule it breaks. Probes and logs are in `scratchpad/m2/JF2-probe/`. Every `mix` run used
`scratchpad/toolchain/env.sh` (Elixir 1.20.4, OTP 28) and was judged by its exit code.

**Citations.** `org` means `docs/organisation.md` at `47319f7`. Design labels (`FB-n`, `F1-Qn`,
`F2-Rn`, `F2-Qn`) belong to the design documents. My own labels (`E`, `H`, `N`, `J`, `K`) belong
to this document only, and must never be cited in `lib/`, `test/` or `CLAUDE.md`.

---

## 0. Verdict

| Design | Score | In one line |
|---|---|---|
| **F2** | **7.0** | Brings the nested migration that org §4.9 gives to M2-5, applies decisions 23 and 26 by path, and checks the types it is given deeply. Nothing escaped in 2,600 edit walks. It has an `org` §4.8 reserved-word hole, a loader misreport, stanzas resting on sources outside the repository, and four untested nested-edit branches that a host can see. |
| F1 | 6.5 | A conservative edit that refuses any block change, with strong naming and nothing escaping in 2,600 walks. It misses decision 26 for a member inside an instance. Its shallow `types:` check lets a hand-edited type say what no text can, and two edit branches a host can see are untested. |

**Winner: F2.** This holds only if the maintainer takes F2-Q2 (c), the nested migration in M2-5,
which is what org §4.9 line 866 and PLAN:1491-1493 already say.

If the maintainer instead takes F1-Q2 (a), refusing every change to a block type, then F1's edit
is the smaller and safer base. It must then take F2's decision-26 leaf check (defect D1 below)
and F2's `user?/1` (defect D2).

Graft from F1 onto F2 in either case:
- the naming stanzas;
- the refusal of `function_block` as a block's name;
- the one-message rule for recursion (FB-16);
- the dedicated host message for a block type given as a program;
- the Done-when test in `end_to_end_test.exs`;
- the runtime's total `cal` clause.

---

## 1. What I ran

### 1.1 The gate, on fresh copies with each patch applied

```
JF2-probe/gate.sh <copy>      # format; compile --force; MIX_ENV=test compile --force; mix test
F1: format exit 0 / compile exit 0 / test compile exit 0 / Result: 478 passed (6 doctests, 472 tests) / test exit 0
F2: format exit 0 / compile exit 0 / test compile exit 0 / Result: 476 passed (6 doctests, 470 tests) / test exit 0
```

Logs are in `JF2-probe/gate-F1.log` and `gate-F2.log`. Both designs' gate claims reproduce.

### 1.2 A seeded walk of online edits over programs that hold blocks (`JF2-probe/walk.exs`, `walk2.exs`)

The generator builds random programs named `m` from a pool of declarations and rungs:
- instances of `seal`, `pulse`, `delay`, and `wrap`, a block holding a `pulse` and a `delay`;
- two versions each of `pulse`, `delay` and `wrap`: the second `pulse` adds members and
  changes its `ons` rung, and the second `delay` changes its preset;
- `cal` rungs, with or without an EN contact, member reads, and plain rungs.

The walk takes random steps: scan, restart, accept, test, untest, assemble and cancel. `walk2.exs`
adds plain swaps, and a tag `z1` whose type varies (bool, dint, ton or any block) between programs.

At every step the walk checks four things:
1. Nothing raises. Every call is within the contract, so not even an `ArgumentError` is expected.
2. A report has at most one entry per kind and name.
3. The report's writes, applied to the state before the step, give the state after it, exactly,
   by path. This is the `Logex.Edit` moduledoc's claim; my oracle applies `:added`, `:input`,
   `:preset`, `:resumed`, `:resume_undone`, `:pruned` and `:ons_blocked` by dotted path.
4. A forecast equals the report of a test taken at once (decision 27).

```
mix run walk.exs <seed> <walks>     (seeds 1-6; seed 1 at 200 walks, 2-6 at 300; 30 steps each)
F1: 1,700 walks, 51,000 steps, 6,234 accepted, 4,773 refused: escapes 0, rebuild mismatches 0, duplicates 0, forecast mismatches 0
    kinds reached: added, held, initial_changed, ons_blocked, pruned
F2: 1,700 walks, 51,000 steps, 8,049 accepted, 0 refused: escapes 0, rebuild mismatches 0, duplicates 0, forecast mismatches 0
    kinds reached: added, dn_drops, dn_rises, held, initial_changed, ons_blocked, preset, pruned, resume_undone, resumed
mix run walk2.exs <seed> 300        (seeds 11-13, with plain swaps and a tag of varying type)
F1: 900 walks, 581 accepted, 7,618 refused: escapes 0, mismatches 0; kinds add preset_kept
F2: 900 walks, 1,046 accepted, 6,745 refused: escapes 0, mismatches 0; kinds add preset_kept
```

**Both edits are robust.** Nothing escaped, and every report rebuilds its state exactly, by path.
F2 reaches every timer report kind under blocks. F1 refuses about 43% of the accepts in the first
walk, because any change to a block type is refused (FB-38).

### 1.3 Token soups through `compile/2` and a scan (`JF2-probe/soup.exs`)

Seeds 1 to 3 ran 4,000 sources each. The soups mix `function_block`, `cal`, block type words, and
members such as `s1.edge` and `s2.t1.acc`. Each compiled with `types:` empty, `[seal]` or
`[seal, pulse]`. Every program that compiled was scanned three times, and every block that
compiled was run inside a host program.

```
F1 and F2 alike: 12,000 soups, 118 programs and 29 blocks compiled, escapes 0
```

Only F2's spike has a soup property of its own (`function_block_test.exs`, "compile/2 never
raises…"). F1 has none, and this run is the first evidence that F1's compile stays total with
blocks.

---

## 2. Online edit: scenarios, both designs (`JF2-probe/edit.exs`, logs `edit-F1.log`, `edit-F2.log`)

For each step, the probe applies the report's writes and compares the result with the actual state.
Every step in both designs printed `rebuild ok`.

| # | Scenario | F1 | F2 |
|---|---|---|---|
| E1 | Decision 26 inside an instance. Block `cnt` v1 has `var n dint` and sets it to 7. A plain swap to v2, where `n` is a bool, leaves `c.n` = 7. Then an edit's first test. | `test: [{:added, "extra", 0}]`. `c.n` stays 7. The candidate's first scan gives `q` = 1 by reading `n` = 7 as closed. **Not restarted.** | `test: [{:added, "c.n", 0}, {:added, "extra", 0}]`. `c.n` = 0 and `q` = 0. |
| E2 | Decision 23 inside an instance. Edit 1 removes the `cal` of a timing block at 50 ms. Edit 2 restores it at 10,000 ms. | `edit 2 test: []`. 10 ms later `acc` is 100 and `done` is 1: **the whole gap is caught up.** | `[{:resumed, "d.t1", 9950}]`. 10 ms later `acc` is 60 and `done` is 0. |
| E3 | Fix F2. Edit 1 adds `cal p`, and the pending `p.edge` must survive edit 2, taken before any scan. | `[{:added, "other", 0}, {:ons_blocked, "p.edge", 0}]`. `fired` is 0. Correct. | Same. Correct. |
| E4 | Add an instance and its `cal`, then test, untest, test and assemble. | `{:added, "q", %{…}}`, `{:ons_blocked, "q.edge", 0}`. The forecast equals the test report. | Same. |
| E5 | A body change: add a member, change the `ons` rung. | Refused: ``line 3: `p` is a pulse in the running program and a changed pulse in the candidate: a function block's members and body change only with a restart``. | `[{:added, "p.count", 7}, {:ons_blocked, "p.edge", 1}]`. Untest, test again and assemble all rebuild. |
| E6 | A nested preset change, 100 to 300 ms, test then untest. | Refused, as E5. | `[{:dn_drops, "d.t1", {100, 300}}, {:preset, "d.t1", {100, 300}}]`. Untest gives back the original's state exactly. |
| E7 | A `cal` moved under a new contact. | `[{:ons_blocked, "p.edge", 1}]` | Same. |
| E8 | Fix F7 by path: the body also writes the `ons` bit with `otu`, and the edit is unrelated. | Not blocked. This is harmless: F1's body cannot change, and nothing outside a block writes its locals. | `{:ons_blocked, "p.edge", 1}`, as fix F7 does at the top level. |
| E9 | A `cal` that was an output's only driver is dropped. | `{:held, "fired", 0}` | Same. |
| E10 | A restart during test, then untest. | Refused, as E5. | `untest: [{:added, "p.old", 4}]`. Correct. |

**E1 is a defect of F1 (D1).** It is reproduced, and its top-level analogue at HEAD restarts the
same value:

```
mix run JF2-probe/e1-head.exs   (in an unmodified copy of 47319f7)
plain swap: n = 7, q = 1
first test report: [{:added, "extra", 0}, {:added, "n", 0}]; n = 0
```

Decision 26 (org:1547-1554) says the first test "re-initialises … any tag whose value does not fit
its declared type (`Declarations.fits?/2`, or a timer's member keys)". F1's FB-41 restates "fit" for
an instance of a user block as member keys only (spike `Logex.Edit.fits?/2`, `keys/1`). For a timer,
keys are enough, because all of its members are dints. A user block can hold bools, so a value that
does not fit passes silently into the candidate. F2 checks each leaf with `Declarations.fits?/2`
(spike `moved_member/4`).

**E2 is F1's explicit question, F1-Q10, not a silent departure.** The observable result is the
catch-up that org §4.9 line 839 calls the problem ("It must start timing at the edit instead.
**Settled:** it resumes from the switch"). F1's §12 list of departures does not include it. F2
resolves it by computing "the stopped program did not run it" from the programs' text (F2-Q4). The
OE-1 suite passes unchanged under F2, and my walks reached `:resumed` and `:resume_undone` under
blocks without a mismatch.

---

## 3. The host contract (`JF2-probe/host.exs`, logs `host-F1.log`, `host-F2.log`)

| # | Call | F1 | F2 |
|---|---|---|---|
| H1 | `types: [FbType.ton()]` | `ArgumentError` "types holds … which is not a function block type" | `ArgumentError` "types must be function block types from Logex.compile/2" |
| H2 | `types: nil` | `ArgumentError`, pinned | `ArgumentError`, pinned |
| H3 | `types: [seal, seal]` | `ArgumentError` | `ArgumentError` |
| H4 | A `seal` whose members were edited to `write: true`, then `xic a ote s1.run` | **`ok: Program, warnings []`** | `ArgumentError` (`user?/1` is false) |
| H5 | A `seal` whose members were reordered by hand | **`ok: Program`**: the positional `cal` now maps its operands to other formals | `ArgumentError` |
| H6 | A `seal` whose body was given a rung `cal zz` by hand | `ok` at compile; a scan runs it as nothing | `ok` at compile; **`KeyError` escapes `Runtime.call/4`** |
| H7 | A `seal` whose body reads an undeclared tag | `ok` | `ok` |
| H10, H11, H13 | `Runtime.instance(seal)`, `Edit.accept(p, seal, s)`, `Runtime.scan(seal, s)` | `ArgumentError` with its own message: ``` `seal` is a function block type, which runs inside a program through `cal`: an instance is of a %Logex.Program{} ``` | `ArgumentError` with the generic "expected a %Logex.Program{}…", which prints the whole type |
| H12 | `%Scan{tags: %{}}` from the host | `ArgumentError`, pinned | `ArgumentError`, pinned |

**D2: H4 and H5 in F1 break the decided data-path rule.** Org §4.9 line 779 says "the data API
refuses anything the text cannot say", and decision 28 (org:1559-1572) records that the maintainer
chose the full entry check over a narrow one. F1's `Compiler.block!/1` (spike `compiler.ex`) checks
only the struct's shape and the name. F1 knows this: it asks F1-Q13 and recommends a deep check at
landing. As spiked, though, a host can make a user block's member writable from outside, or remap
`cal`'s positional operands, through `types:`. F2's `FbType.user?/1` holds exactly when the type is
`of/1` of its body, at any depth, and refuses both.

**H6 and H7 are shared.** Neither design checks a body's rungs when a type arrives through `types:`
or `Tag.new!/4`. `Logex.Runtime`'s moduledoc puts a hand-edited program outside the contract
(`lib/logex/runtime.ex:42-43`), and F2 documents it in its §12. Even so, org line 779 and decision
28 argue for refusing it at entry.

A synthesis can make "a type `Logex.compile/2` gave" exact. It can recompile `body.source` with the
types the body holds and compare the result with the type. That is one compile per type per compile,
and still linear.

**F1's runtime is total on the hand-built case.** Its `called/5` clause runs nothing for a name its
table lacks. F2's `evaluate/3` matches with `Map.fetch!`. F2 is within its documented contract here,
but F1's clause costs nothing and should be grafted.

---

## 4. Naming and reserved words (`JF2-probe/host.exs` N1-N17, `n8.exs`)

| # | Source | F1 | F2 |
|---|---|---|---|
| N1, N2 | `var cal bool`, `var CaL bool` | refused: ``…is an instruction and cannot name a tag`` | same |
| N3 | `var function_block bool` in a program | allowed (org §4.8) | allowed |
| N4 | `var FUNCTION_BLOCK bool` in a block | refused | refused |
| N5-N7 | `function_block cal`, `TON`, `Var_Input` | refused | refused |
| **N8** | `function_block function_block` | refused: ``` `function_block` is a keyword and cannot name a function block ``` | **`ok: FbType function_block`** |
| N9 | `FUNCTION_BLOCK seal` | accepted, any case | accepted |
| N10 | `var seal seal` | allowed (PLAN:732-734) | allowed |
| N11 | `var s1 Seal` | unknown type, with a case-sensitive "did you mean" | unknown type, listing `seal` |
| N12 | `function_block q` as a program's rung | its own message | its own message |
| N15, N16 | `cal` on a `ton`; `ton` on a user instance | refused, located | refused, located |
| N17 | `var x seal` inside `seal` | one message (FB-16 excuses the uses) | the recursion message plus ``line 5: `x` is not declared`` |

**D3: F2 accepts a block named `function_block`, which org §4.8 reserves in a block's file.**

```
mix run JF2-probe/n8.exs   (F2 copy)
compile the block named function_block: :ok
a program holding one: ok Logex.Program
a block holding one: ok Logex.FbType        # `var x function_block` in a block's file
```

Org line 744 reserves `function_block` in a function block's file, and F2-R4 says a block's name is
"no reserved word". F2's `block_name/3` (spike `compiler.ex:104-123`) asks `Declarations.reserved/1`,
which does not return the word, because the word is reserved by file kind. The fix is F1's FB-3:
refuse `Declarations.header_word/0` (or F2's `kinds/0`) as a block's name, in any case.

**D4: F2's naming stanzas break CLAUDE.md's survey rule.** The rule (CLAUDE.md "New instructions,
step 1") asks for "then `Checked:` with sources … Mark what you could not verify `unverified`; never
guess". F2's stanzas fall short in three ways:
- Both rest on "the M2 design pass's research notes", which are not in the repository. A maintainer
  reading `docs/naming.md` cannot follow that citation. One example is the conventional-family row's
  "nesting limited to 16 levels", which org §8 (lines 1670-1678) does not contain.
- The CODESYS row of the `function_block` stanza has an empty Notes cell, and its `Checked:` line
  names only Siemens and Mitsubishi as not checked. The row therefore reads as verified without a
  source.
- The IEC rows cite the research notes, not pages read directly.

F1's stanzas read Ed 2 and Ed 3 directly, page by page, and they add two facts to the record:
- IL's conditional-call rule: assignments only "together with the invocation, if the condition is
  true", Ed 2 §3.2.3 p.126 and Ed 3 §7.2.4.3 p.198. This is decision 12 in IEC's own text.
- Ed 2's swap of features 1a and 1b on p.126.

Both stanza sets are append-only. `git diff` of `docs/naming.md` shows 0 removed lines in each, and
one hunk `@@ -588,3 +588,33 @@`.

**Vendor names.** I grepped both patches for the conventional vendor's names, products and
abbreviated terms. Only
"add-on instruction", spelled out, appears, in F1's stanzas. HEAD's `docs/naming.md:403,418,425`
already uses that term, so it follows the existing practice and is not the forbidden abbreviation.
Neither patch adds `if`, `cond`, `unless` or `case` in `lib/`.

---

## 5. Mutation strength: my reverts (`JF2-probe/mutate.py`, logs `mut-*.log`, `survivors.log`)

I chose these rules inside my lens, where I expected weak tests: nested edit paths, report values,
the host check and reserved words. Most are rules that the designs' own revert tables do not cover.

Each revert was applied alone to a mutation copy of the finished spike. I ran the whole suite
(`mix test --warnings-as-errors`) and then restored the file from the index. None of the runs
counted below compiled with a warning. My first run of K4 printed a compile warning, so I reran it
in a warning-free form, and that rerun is the one recorded. Every survivor was then run through a
scenario that shows what a host sees (`survivors.exs`), on the spike and on the mutant.

| Revert | Rule reverted | Suite | What a host sees under the revert |
|---|---|---|---|
| F1 J1 | A nested blocked bit is reported with its value, found by path (FB-40's report) | **478 passed: survives** | `[{:ons_blocked, "p.edge", 0}]` while the state holds `p.edge` = 1; the spike reports 1 |
| F1 J2 | A changed block type has its own `:edit` message | red, 1 test (`edit_test.exs:1595`) | — |
| F1 J3 | `cal` is reserved, in any case | red, 1 test (only through the block-name test; no test declares `var cal`) | — |
| F1 J4 | The one-shots of a block held by a block belong to the calling rung too (FB-40 at depth 2) | **478 passed: survives** | An edit adds `cal w1` while `go` stays 1: the report is `[]` and **the switch scan pulses `q` = 1**, a one-shot the edit made fire (decision 21). The spike reports `{:ons_blocked, "w1.p.edge", 0}` and `q` = 0 |
| F1 J5 | A block type's identity includes its members' initial values (FB-38) | red, 1 test | — |
| F1 J6 | Only a built-in `ton` meets the edit's timer rules (FB-42) | 478 passed: survives | Nothing: F1's claim that the rule has no observable effect holds. A user block's preset is nil, so every timer rule is a no-op |
| F2 K1 | A member's kind change is cited as a member's | red, 1 test | — |
| F2 K2 | At the first test, an instance that is not a map starts again whole (decision 26) | **476 passed: survives** | A plain swap leaves `z` = 1 under `var z seal`. The first test reports only `{:input, "st", 0}` and leaves `z` = 1. The spike reports `{:added, "z", %{…}}` |
| F2 K3 | `user?/1` is `of/1` of the body, not only its shape (decision 28) | red, 1 test | — |
| F2 K4 | Assemble prunes at any depth, inside an instance an instance holds (F2-R39) | **476 passed: survives** | Assemble reports `[]` and keeps `w1.p.old` = 4. The spike reports `{:pruned, "w1.p.old", 4}` |
| F2 K5 | A nested plan is memoised per whether each program runs the instance | **476 passed: survives** | Two `delay`s, one run by `cal` and one not, and a 30 to 50 ms preset change. The unrun `db.t1.pre` moves to 50 (`{:preset, "db.t1", {30, 50}}`) where decision 23 keeps it frozen. The spike moves only `da.t1` |
| F2 K6 | The chain of a block held by a block (F2-R41 at depth 2), the same rule as F1's J4 | **476 passed: survives** | The same false pulse as J4: `q` = 1 on the switch scan |

**Results.**
- F1: 2 of my 5 counted reverts (J1 to J5) survive, and each changes what a host sees. J6, a sixth,
  confirms F1's own claim that FB-42 has no observable effect.
- F2: 4 of my 6 reverts survive, and each changes what a host sees.

The designs' own tables are true for the rules they chose: F1's 41 and F2's 29 all go red. My
survivors fall where both designs say their tests are thin: neither extends `api_contract_test.exs`'s
edit walk to blocks (F1.md §8, F2.md §7). F2's survivors sit in exactly the code F1 does not have,
the nested migration. **A depth-2 nested one-shot is untested in both designs**, and reverting that
rule makes an edit fire a one-shot it should have blocked.

---

## 6. Other reproduced defects

**D5: F2's loader blames the wrong file and gives the wrong reason when a block names a program.**

```
blk.ld:  function_block blk / var_input a bool / var_output q bool / var p prog / cal p a q
prog.ld: var_input a bool / var_output q bool / var b blk / cal b a q
Logex.compile_file("blk.ld")  →  prog.ld: line 3: `prog` cannot hold an instance of `blk` (prog → blk → prog): a function block never holds an instance of itself, at any depth
Logex.compile_file("prog.ld") →  blk.ld: line 4: `blk` cannot hold an instance of `prog` (blk → prog → blk): …
```

The real mistake is `blk.ld` line 4, which names a program as a type. F2-R52's own message
(``` `prog` is a program (prog.ld), not a function block ```) is never reached, because the cycle
check runs first (spike `lib/logex.ex`, `found/4` before `dependent/3`). For `compile_file("blk.ld")`
the diagnostic lands in another file, against a program that is allowed to hold `blk`.

The diagnostic is located, but it misreports both the place and the reason. A fix is to enter only
block files into `held`, or to read the target file's kind before the cycle check.

**D6: F2's loader looks up a dotted type word as a file.**

```
var s a.b   →  a.b.ld: "a.b" cannot name a program … | a.b.ld: line 1: `a.b` cannot name a function block …
```

F1 reports this as an unknown type in the file that has the mistake. The fix is to look up a file
only for a word for which `Declarations.name?/1` holds.

**D7: F2's recursion cascades.** N17 adds ``line 5: `x` is not declared`` after the recursion
message. F1's FB-16 excuses the uses: one mistake, one message.

**D8: F2's Done-when sits in `function_block_test.exs`, not `end_to_end_test.exs`.** CLAUDE.md's
Key Files make `end_to_end_test.exs` the place where a behaviour change is pinned, and PLAN OE-1's
Done-when is there. F2.md §7 lists the move as owed. F1 already puts the test there
(`end_to_end_test.exs:1375-1454` in its spike).

**Shared, and owed by both.** Neither extends `api_contract_test.exs`'s edit walk to blocks. Org
§4.9's Tests paragraph and the property "every property asserts its reach" require it. My walk in
§1.2 is a minimal stand-in: rebuild by path, forecast, and uniqueness. It has no one-shot or timer
oracle independent of the rules.

---

## 7. Strengths, reproduced

**F1**
- The gate is green with 478 tests. All 41 of its own reverts are red (F1.md §9).
- Nothing escapes and every report rebuilds exactly, over 2,600 edit walks with plain swaps and
  12,000 soups.
- The edit change is small and reviewable (+151 lines in `edit.ex`). Refusing any block change is
  reversible, and its refusal message names the reason (E5).
- The naming survey is the best on the track: IEC read directly, the IL conditional-call fact, the
  1a/1b note, and every unchecked row marked `unverified`.
- `function_block` is refused as a block name (N8). A recursive declaration's uses are excused
  (N17).
- It gives a dedicated `ArgumentError` for a block type given where a program goes (H10, H11, H13).
- Its runtime `cal` clause is total on a hand-built program (H6).
- The Done-when is in `end_to_end_test.exs`.

**F2**
- The gate is green with 476 tests. All 29 of its own reverts are red (F2.md §8).
- Nothing escapes and every report rebuilds exactly, over 2,600 walks. Under blocks, it reaches
  every report kind but `:input` and `:unread`, which do not depend on blocks (`:preset_kept` in
  `walk2.exs`).
- It delivers what org §4.9 line 866 assigns to M2-5: members copied by name and kind, the rest
  started, and members pruned at assemble.
- It applies decision 23 (E2), decision 26 (E1), decision 29 and fix F7 (E8) by path, and its
  untest round trip is exact (E6).
- `FbType.user?/1` closes the data-path gap for members (H4, H5).
- Its compile soup property ships in the suite.
- Its growth tests are linear, and one of them caught a quadratic step in its own spike (F2.md §0).

---

## 8. What the synthesis must take

**Base: F2.** Graft the following from F1, each with the reason:
1. **The naming stanzas** for `function_block` and `cal`. F1's stanzas read IEC directly, add the IL
   conditional-call fact, and mark what is `unverified` (D4).
2. **The refusal of `function_block` as a block name** (FB-3), which closes D3.
3. **FB-16's excused uses of a refused declaration** (D7): one mistake, one message.
4. **The dedicated `ArgumentError`** for a `%FbType{}` given to `Runtime.*` or `Edit.accept/3`. It
   is shorter and says what to do (H10, H11, H13).
5. **The total `cal` clause** (`called(_not_a_block, …)`), so a hand-built body never raises
   `KeyError` (H6).
6. **The Done-when in `end_to_end_test.exs`** (D8).
7. **Ask F1-Q10, F1-Q13 and F1-Q16 as questions.** F2 answers Q10 and Q13 in code, but the
   maintainer should see the choice.

---

## 9. Defects the synthesis must fix, each with its reproduction

| # | Defect | Design | Repro |
|---|---|---|---|
| D1 | A member that a plain swap left not fitting its type is not restarted at the first test (decision 26) | F1 (F2 correct) | `edit.exs` E1; `e1-head.exs` |
| D2 | `types:` and `Tag.new!/4` accept a hand-edited type: writable members, reordered formals (org:779, decision 28) | F1 (F2 correct) | `host.exs` H4, H5 |
| D2b | Neither checks a type's body rungs. F2 raises `KeyError` at scan | both | `host.exs` H6, H6b |
| D3 | A block may be named `function_block` and used as a type word in a block's file (org §4.8, line 744) | F2 | `n8.exs` |
| D4 | The stanzas cite notes outside the repository, and the CODESYS row is unmarked | F2 | §4 |
| D5 | A program reached through a block is reported as recursion in the wrong file | F2 | `loader.exs`, `files/x/{blk,prog}.ld` |
| D6 | A dotted type word is looked up as a file | F2 | `loader.exs` `dotted.ld` |
| D7 | A recursion cascades into "not declared" | F2 | `host.exs` N17 |
| D8 | The Done-when is outside `end_to_end_test.exs` | F2 | F2.md §7 |
| T1 | Untested: a nested blocked bit's report value | F1 | J1 |
| T2 | Untested: one-shots of a block held by a block, at depth 2 (a false pulse) | both | J4, K6 |
| T3 | Untested: a non-map instance restarted at the first test | F2 | K2 |
| T4 | Untested: prune at depth 2 | F2 | K4 |
| T5 | Untested: the nested plan's memo key per whether each program runs the instance | F2 | K5 |
| T6 | `api_contract_test.exs`'s edit walk does not reach blocks | both | F1.md §8, F2.md §7 |

---

## 10. Housekeeping

- I applied each patch to a fresh copy (`JF2-F1-work`, `JF2-F2-work`) and made mutation copies
  (`JF2-F1-mut`, `JF2-F2-mut`) and an unmodified copy (`JF2-head-work`). All five are deleted at the
  end of this pass.
- Probes, logs and the mutation driver remain in `scratchpad/m2/JF2-probe/`.
- `/home/user/logex` is unmodified at `47319f7`.
