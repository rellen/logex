# rv-facts: the design record, checked for facts and sources

Lens: every factual claim in `record.patch` about the outside world and about the code,
against `research.md`, `ext-logex.md`, the saved primary sources in `inv-sources-src/`, the
track documents, and the repository at `47319f7`. The patch was applied to a copy
(`rv-facts-work`), which is deleted. Line numbers are in the patched copy.

## Verdict on the extension

**The record's statement holds.** I re-ran the search on 2026-10-02:

- **Registries.** fileinfo.com, filext.com, file-extension.info and solvusoft.com give 404
  for `logex`, and 200 for the `.lcf` control.
- **Unchecked registries.** file-extensions.org and filesuffix.com give 403.
- **reviversoft.** It now redirects both `logex` and `lcf` to `/file-extensions/missing/…`.
  It lists neither extension, so it says nothing either way (see finding 5).
- **Linguist.** `languages.yml` at `main` has 0 matches for `logex`.
- **Open VSX.** 0 extensions.
- **VS Code Marketplace.** The same 5 extensions `ext-logex.md` lists.
- **Sourcegraph.** `file:\.logex$`: 0. `file:\.lcf$`: 532 matches in 93 repositories. The
  quoted `".logex"` regex: 0.
- **Hex.** `logex`: 404.
- **Local tables.** Vim 9.1 gives `plant.logex` no filetype. `/usr/share/mime/globs2` and
  `/etc/mime.types` have no `logex`.
- **Web searches.** Two searches found no `.logex` format. One project not in
  `ext-logex.md` turned up, `kennyparsons/logex`, a bash note-taker. I cloned it at
  `ed45f18`: it uses no `.logex` file (its README writes `-f mynotes.log`).

## Findings

### 1. (medium) PRIORITY is UINT in Ed 2 too; the record says only Ed 3 types it

- **Where:** `docs/organisation.md` decision 37 (lines 2127-2128), the decision 11
  annotation (line 1847), and the §4.4 table row (line 418).
- **Claim:** "0 to 65535, IEC Ed 3's own: its Table 63 (p.182) types PRIORITY as UINT, and
  its Table 10 (p.31) note d makes a UINT 0 to 2^16 − 1. Ed 2 says `integer`".
- **Evidence:**
  - Ed 2 Table 50 "Task features" (`ed2.txt`, pdfpage 118, printed p.116) gives the same
    general form: `UINT---|PRIORITY |`.
  - Ed 2 Table 10 note d (printed p.31) gives "from 0 to (2N)-1", with UINT N=16.
  - Only Ed 2's *grammar* says `integer`.
  - Ed 3's Table 10 starts on p.31, but its note d is on printed p.32 (pdfpage 34).
- **Fix:** Say IEC types PRIORITY as UINT in both editions: Ed 2 Table 50, p.116, and
  Table 10 note d, p.31; Ed 3 Table 63, p.182, and Table 10 note d, p.32. Say the grammars
  (`integer` in Ed 2, `Unsigned_Int` in Ed 3) set no upper bound. Add Ed 2 Table 50 to §8.
  The maintainer's own phrase "IEC Ed 3's UINT" can stay as the answer's wording.

### 2. (medium) §8 does not list sources the new decisions rely on

- **Where:** `docs/organisation.md` §8, whose only addition is "Ed 2 §2.5.2 (Table 32) and
  Table 33 with Annex B.1.5.2; Ed 3 Table 10 note d, Table 63 and Figure 13".
- **Sources cited but not registered:**
  - **Decision 33,** "Hidden `var`s are IEC Ed 3's PRIVATE default". This is Ed 3 §6.6.3.2
    rule 11, p.100.
  - **Decision 33,** "writes ... to its inputs, taking effect at the next call, as IEC Ed 3
    allows". This is Ed 3 §6.6.3.4.2, p.108.
  - **Decision 33,** "the conventional family's local tags" and "to its inputs and outputs,
    as the conventional family does, by inference". These come from the family's add-on
    instructions programming manual (Sept 2025), pp.23 and 79, which §8 does not list.
  - **Decision 32,** "the conventional family's 16 levels". This is the same manual, p.21,
    and the design considerations reference, p.15. §8 lists that reference only for
    pp.65, 85, 88 and 91.
  - **Decision 37,** "0 to 31, one vendor's (CODESYS's help)". This is CODESYS "Object:
    Task". §8 lists only "Online Change" and `FB_Init`.
  - **Decision 39,** "Beremiz's editor cannot express both". This is Beremiz
    `editors/ResourceEditor.py` at `5e3a749`, which §8 does not list.
- **Why it matters:** §8 is the document's register of what is sourced and what is "from
  memory". Decision 9 was marked from memory, and the record's new claims about the
  conventional family now rest on manuals the register does not name.
- **Fix:** Add these sources to §8, citing by title, publication date and page, without
  vendor names, as `research.md` §6 does.

### 3. (low) "a path is at most 16 names" is off by one

- **Where:** `docs/organisation.md` decision 32 (line 2058).
- **Claim:** "at the conventional family's 16 levels a path is at most 16 names".
- **Evidence:** The add-on manual says "The instructions can be nested up to 16 levels
  deep" (1756-pm010.txt:703). Take a one-shot's storage bit inside the 16th nested
  instance: its block-list name is 16 instance names plus the bit's own name, which is 17.
- **Fix:** "at most 17 names", or "about 16 names".

### 4. (low) §4.6's annotation says the phase becomes the switch's, which is not always true

- **Where:** `docs/organisation.md` §4.6, Periodic (line 584): "so after such an edit the
  phase is the switch's". Decision 40's option (line 2165) says the same.
- **Evidence:** By the rule's own arithmetic, take an interval of 10 anchored at 0, with
  `now` = 25 and `next_due` = 30, changed to 50. Then `min(30, 25 + 50)` = 30, and the runs
  fall at 30, 80, 130: the old phase, not 25 + 50k.
  - This holds whenever `next_due ≤ now + new interval`. That is every lengthened
    interval, and a shortened one cut late in its period.
  - T-rev Q-16's own example is a cut from 1000 to 10 ms at 505, which brings `next_due`
    forward.
- **Fix:** "where the new interval brings `next_due` forward, the phase is then the
  switch's".

### 5. (low) "three registries refused the requests" overstates one of them

- **Where:** `docs/organisation.md` decision 35 (line 2107) and §8 (line 2252).
- **Evidence:**
  - `ext-logex.md` records "403 / 403 / 504" for file-extensions.org, filesuffix.com and
    reviversoft.com. A 504 is a gateway timeout, not a refusal.
  - Re-run 2026-10-02: reviversoft answers. It sends 302 to
    `/en/file-extensions/missing/logex`, and likewise for `lcf`. It lists neither, so it is
    uninformative, not refusing.
- **Fix:** "two registries refused the requests, and a third lists neither extension".

### 6. (low) The §4.4 receipt note says four lines are reworded but names three changes

- **Where:** `docs/organisation.md` §4.4 (line 466): "rewords four of them: a did-you-mean
  where a name is near, the member's section named, and no 'declare it first'".
- **Evidence:** T-rev §3.7 rewords lines 7, 9, 11 and 12. Line 7 becomes ``line 7, column 1:
  unknown configuration line `progam` — did you mean `program`?``, gaining a column and the
  em-dash. Its did-you-mean was already there, so the note's three changes cover only
  lines 9, 11 and 12.
- **Fix:** Add "line 7 gains its column".

### 7. (low) PLAN's new receipts do not say they ran on 1.20.4

- **Where:** `PLAN.md` §3 Milestone 2:
  - "113 rules ... 88 ... 127" (line 1307);
  - "466, 504, 509, 510 and 514 tests" (line 1372);
  - "2,486 reductions ... 138,358,875" (line 1542).
- **Evidence:**
  - PLAN's preamble: "Every claim below was reproduced ... (Erlang/OTP 25, Elixir 1.14) ...
    Claims that ran on the pinned Elixir 1.20.4 / OTP 28 instead say so".
  - The record labels only "582 tests on Elixir 1.20.4".
  - S-rev, F-rev and T-rev each state that every `mix` run was on 1.20.4 / OTP 28.
  - Reduction counts depend on the VM.
- **Fix:** Add "on Elixir 1.20.4" to the paragraph's opening sentence and to the costs
  bullet, as line 1183 does for OE-1.

### 8. (low) The flaky growth tests are main's own, and the record drops that

- **Where:** `PLAN.md` Owed, "Costs to keep in view" (line 1544): "Three growth tests in
  reductions failed now and then under a load average near 40".
- **Evidence:**
  - F-rev §12: "three pre-existing growth tests (`logex_test.exs`'s two, `edit_test.exs`'s
    F16 pair)". The source's list names four, against its count of three.
  - These tests are in the suite at `47319f7` (`logex_test.exs:149,159`;
    `edit_test.exs:1428,1445`), so the risk is in main now, not only in a spike.
- **Fix:** Name them as the current suite's reduction-ratio tests in `logex_test.exs` and
  `edit_test.exs` (F16). Give either the number or the list, not both.

### 9. (low) "`Logex.Edit` roughly doubles" drops its source's qualifier

- **Where:** `docs/organisation.md` decision 31 (line 2040).
- **Evidence:**
  - F-rev §12 says "roughly doubles in its per-instance code".
  - The whole file goes from 752 lines (`47319f7`) to 1,275 (`F-rev-work`), which is 1.7x.
- **Fix:** "`Logex.Edit`'s per-instance code roughly doubles".

### 10. (low) Decision 35 quotes a loader message that no recorded rule establishes

- **Where:** `docs/organisation.md` decision 35 (lines 2108-2109): "the loader's refusal of
  a bare dotfile reads '`.logex` names no configuration'".
- **Evidence:**
  - That refusal exists only in the configuration spike, as T-rev F12/R65 (``` `.lxcf`
    names no configuration: … ```).
  - §4.10's M2-2 "Loading" bullet records no such rule.
  - The present tense describes it as existing.
- **Fix:** Record the bare-dotfile rule in §4.10 M2-2 Loading, or say "would read".

### 11. (low) Ed 3 §6.6.1.5 (EN/ENO) is still not carried

- **Where:**
  - Decision 12 (line 1851): "which is IEC's 'keep their states'".
  - §4.3's false-EN rules, which cite Ed 2 §2.5.2.1a) only.
  - §4.10 M2-5, which designs `cal`.
- **Evidence:**
  - Ed 3 §6.6.1.5 rule 4 (p.63): with ENO false, the values of all POU outputs "are
    Implementer specific".
  - Rule 1: "The Implementer shall specify the behavior in this case in detail".
  - `research.md` IEC-9 and correction 5 flagged this. The record cites Ed 3 elsewhere
    (decisions 33 and 37) but leaves the EN claim as Ed 2's alone.
- **Fix:** Annotate decision 12. Its freeze is required by Ed 2 and is one permitted choice
  under Ed 3 (EXAMPLE 2/4). Say that M2-5's `cal` stanza states the behaviour, as Ed 3
  requires.

## Checked and correct

**IEC citations**
- Ed 3 Table 63, p.182, types PRIORITY as UINT.
- Ed 2 Table 33 features 10a ("VAR_EXTERNAL declarations within function block type
  declarations") and 10b, pp.71-72.
- Both grammars allow `var_external` in a function block: Ed 2 `other_var_declarations`,
  and Ed 3 `FB_Decl` → `Func_Var_Decls`.
- Ed 2 §2.5.3, p.83, and §2.5.2(.1), p.67, for the unconnected-input inference.
- Ed 2 Table 32 and Ed 3 Figure 13: an input may not be read from outside.
- Ed 3 PRIVATE default, §6.6.3.2 rule 11.

**Other implementations**
- MatIEC ignores INTERVAL when SINGLE is given (`task_initialization_c`, `run_dt`).
- Beremiz's editor makes the two triggers exclusive.
- CODESYS priority 0..31.
- The conventional family edits user-defined instructions offline only and nests them 16
  deep.
- Beremiz's hot swap copies leaves by path and type; the CODESYS pages read do not say so.

**Figures**
- Mutation rows: 113 red; 87 of 88 red, with R87 green; 127 red.
- Gated series: 466, 504, 509, 510 and 514 tests.
- Merged spikes: 582 passed, and `m1.s2.run` gives `{:ok, 1}`.
- 2,486 against 244 reductions, and 138,358,875 at 400 files.
- The conflicts occur in either order.
- Done-when counts: 100, 34, 100, then 100 and 20.
- Decision 40's probe: 0 runs, and 100 under `min`. I reproduced the 100 by running the
  probe with `min` on a copy of S-rev-work.

**Current code**
- "only a timer has members" is at `compiler.ex:652`.
- "a #{tag.type.name}" is in M1-6's member messages.
- `runtime_test.exs:290` pins key order past 32 keys.
- `%Logex.Edit{}` is defined in `edit.ex:193`.
- `Tag.new!/4` raises the first problem (`declarations.ex:140`).
- A var_input takes no initial value (`declarations.ex:397-399`).
- The lexer drops comments and blank lines, and treats LF, CRLF and a lone CR as line
  ends.
- The compiler, `Logex.Warnings` and `Logex.Edit` each walk `{:branches, _}` separately.
