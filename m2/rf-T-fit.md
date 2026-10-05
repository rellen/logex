# rf-T-fit · Track T's synthesis against the decided rules, the research and the naming stanzas

Label rf-T-fit. Written 2026-10-02 against `/home/user/logex` at `47319f7` (not modified)
and `T-synth.md` / `T-synth-work`. The probes ran in a copy,
`scratchpad/m2/rf-T-fit-work` (`cp -a T-synth-work`), deleted when done. The probe script
and its output are kept in `scratchpad/m2/rf-T-fit-probe/p1.exs` and `p1.log`. The run
used Elixir 1.20.4 / OTP 28 (`toolchain/env.sh`) and exited 0.

Lens: fit. That covers organisation.md §4.4–4.8, §7 decisions 3, 5, 6, 7, 10, 11, 13 and
19, and PLAN M2-2/3/4/6. It also covers `research.md` on the extension and on IEC and its
precedents, the nine naming stanzas, and whether T-synth §13's questions are real,
correctly framed and complete. Every finding is either reproduced (command and output) or
quoted against a decided rule, an IEC text kept on disk, or the code.

**Checked and found to fit:**
- the ten `.lxcf` words and their staging against §4.8 and PLAN M2-2/3/6;
- `var_external` reserved in `.ld`, and its name legal in both kinds (V3, R43);
- arrow-free connections (decision 5) and `at panel.q.0` (decision 6);
- every var_input connected, as an error (decision 7);
- reservation by file kind (decision 10);
- priority required, 0 the highest, a trigger already 1 fires (decision 11);
- integer ms (decision 13);
- interval and priority changes allowed, a task move refused, task add and remove refused
  (decision 19, §4.9);
- `compile_file/1` refusing anything but `.ld` (PLAN M2-2);
- IEC-5's at-least-one-program rule (R28), IEC-7's no-initial-value rule for an external
  (V1), and IEC-14's note on decision 7 (§11);
- MAT-2 cited for the combined task (Q-14).

`.ld` declarations refuse case-only twins (`lib/logex/declarations.ex:488`), so R15's
one-namespace rule leaves a `var_external` legal in both kinds. Keywords match in any
case in both file kinds (probe 3). Neither file kind contradicts the other there.

---

## Findings

### TF-1 (medium) · IEC does give PRIORITY a range; the stanza says it does not, and Q-9 leaves out that option

- The `priority` stanza's own IEC row says Ed 3 *"types it `Unsigned_Int` (Annex A,
  p.226) and UINT (Table 63)"*. Its **Why** then says *"No range of IEC's is quoted, so
  logex takes a dint's"* (`rf-T-fit-work/docs/naming.md:679`).
- Ed 3 Table 63, on the kept text (`inv-sources-src/ed3.txt`, pdfpage 184), gives:
  ```
  BOOL--- |SINGLE   |
  TIME--- |INTERVAL |
  UINT--- |PRIORITY |
  ```
  Table 10 (pdfpage 33) gives `7 Unsigned integer  UINT 0 16 d`. So IEC's own type for
  PRIORITY holds 0..65535.
- T-synth Q-9 (T-synth.md:1219-1225) offers (a) 0..2147483647, (b) any order, and (c)
  "0..31, as CODESYS: an arbitrary bound IEC does not state (inv U24)". It has no option
  for 0..65535, IEC's UINT. inv U24 ("No range is quoted") is answered by the sources this
  pass already holds.
- S-synth's version of this question, which T marks "S", keeps the caveat that a tighter
  bound "is the safer start by decision 7's reasoning, so the choice is the maintainer's"
  (S-synth.md:955-962). T's version drops it. So one S-marked question is put to the
  maintainer two ways.
- Reproduced: the spike accepts `priority 65536` with no diagnostic or warning (`p1.log`,
  "single on output point": `ok; warnings: []`).
- **Fix:**
  - correct the stanza's Why (IEC types PRIORITY as UINT, 0..65535; logex takes a dint's
    range, or IEC's);
  - add the UINT option to Q-9, with decision 7's tighten-now argument;
  - mark inv U24 as resolved;
  - give both tracks one wording of the question.

### TF-2 (medium) · Q-18 calls `VAR_EXTERNAL` in a function block "unverified", but IEC's grammar allows it

- Q-18 (T-synth.md:1314-1315): *"IEC allowing VAR_EXTERNAL in a FUNCTION_BLOCK is
  unverified (inv U19)."*
- Ed 2 Annex B.1.5.2 (printed p.155, `inv-sources-src/ed2.txt` lines 8169-8175):
  ```
  function_block_declaration ::=
  'FUNCTION_BLOCK' derived_function_block_name
     { io_var_declarations | other_var_declarations }
  ...
  other_var_declarations ::= external_var_declarations | var_declarations | ...
  ```
- Ed 3 Annex A (pdfpage 227): `FB_Decl : 'FUNCTION_BLOCK' … ( FB_IO_Var_Decls |
  Func_Var_Decls | Temp_Var_Decls | Other_Var_Decls )* …` and `Func_Var_Decls :
  External_Var_Decls | Var_Decls;`.
- So option (a), "refused in a block file until decided", is a departure from IEC, not a
  wait for a fact. It may still be the right first step: a block has no configuration of
  its own, and reaching a global from inside `cal` needs a write path out of a body. But
  Q-18 should say that (a) departs from IEC and is reversible. T-synth §11 should list it
  as a departure, as F2.md's matching recommendation should.
- **Fix:** replace "unverified" with the two citations, and mark (a) as a departure in
  §11. inv U19 is resolved.

### TF-3 (medium) · Q-16 leaves out the one option that keeps §4.6's anchored phase, which S-synth's version has

- org §4.6:556: *"Each task keeps a `next_due`, anchored at start. … After a run,
  `next_due` advances by whole intervals, so the phase never drifts."*
- T-synth Q-16 (T-synth.md:1286-1294) offers:
  - (a) `min(next_due, now + new)`;
  - (b) keep `next_due`;
  - (c) re-anchor at the switch.

  Neither (a) nor (b) keeps the phase anchored at start. Under (a), an interval cut from
  1000 to 10 at `now` 505 runs at 515, 525 and on: phase 5, not 0. Under (b), the phase
  re-anchors at the first run after the switch.
- S-synth's version of the same question has the anchored option: Q-23 (b), "The next
  multiple of the new interval from the anchor" (S-synth.md:1071-1077). In the example
  above it runs at 510. The wait is bounded by the new interval, no run is added, and
  §4.6's rule still holds after an edit.
- So the S-marked question that §0 calls one of the four the tracks "must merge" has
  different option sets in the two tracks. Both recommendations leave out the only option
  that matches decided text. Option (a) also says (b) "does not" add no run, but S-synth
  states that (b) adds none.
- **Fix:** add the anchored option to Q-16, and give one option set for Q-16 and S-synth
  Q-23. If the recommendation stays (a), say that it gives up §4.6's "anchored at start"
  after an edit.

### TF-4 (medium) · A departure from decided text that §11 does not list: where "which tags a program writes" lives

- org §4.4:465-466 (decided, "Globals shared by name"): *"A program that writes a
  `var_external` bound to an input point is an error, so `%Logex.Program{}` records which
  tags it writes."*
- T-synth §5 (M2-4) and the tail of §13 keep T1-Q13: *"'what a program writes' is a
  function over the IR, … not a field on `%Logex.Program{}`"*. The spike has a private
  `writes/1`.
- §11 ("Departures from decided rules") does not list this. Yet it lists D1, a weaker
  letter-against-intent reading of "M1-5's `warnings:` channel". And §13 records T1-Q13
  only as "stand as T1 recommended", not as a question.
- The design may well be right: a derived function cannot disagree with a hand-built
  struct, as decision 28 argues. But it changes decided text, and only the maintainer can
  approve that.
- **Fix:** list it in §11 as a departure, with org §4.4:466 to be reworded in the M2-4
  documents commit (§9 row 13–15), or raise it as a §13 question.

### TF-5 (medium-low) · The nine stanzas leave 17 vendor rows unsurveyed, where `docs/naming.md` has none

- `git diff HEAD -- docs/naming.md` in the spike has 15 rows reading `unverified`: not
  surveyed in this pass:
  - every Mitsubishi row (9 of 9);
  - 5 Siemens rows;
  - CODESYS for `at`.
- It has 2 more Siemens rows reading "`unverified`: the word was not checked" (`interval`
  and `single`).
- At `47319f7`, `grep -c 'not surveyed' docs/naming.md` gives `0`, and all 21 Mitsubishi
  rows are surveyed.
- CLAUDE.md, step 1: *"IEC … then the major vendor toolchains … Mark what you could not
  verify `unverified`; never guess."* "Not surveyed" is not "could not verify".
- Commits 1, 9, 13 and 16 (§8) land these stanzas as they are, and the file is
  append-only. The research pass did not cover Mitsubishi, and has only a short Siemens
  section (§7).
- **Fix:** before commit 1, survey the missing rows, or keep `unverified` for a row
  actually looked for and not found, with what was searched.

### TF-6 (low) · The `program` stanza says a `.ld` file has no header line, which decision 4 makes false for block files

- The `program` stanza (`rf-T-fit-work/docs/naming.md:596`): *"Reserved, in any case, in
  a configuration file only (§4.8): a `.ld` file has no header line and never spells its
  own type."*
- Decision 4 (org:1461) and PLAN M2-5 (PLAN.md:1340) say otherwise: *"`function_block
  <name>` as a file's first line, matching the file name"*. That is a header line that
  spells the file's own type. T-synth §5 says so itself ("a `.ld` whose first line is
  `function_block <name>`").
- If M2-5 lands first, which inventory §11's order allows, the stanza is false when it
  lands, in an append-only file.
- **Fix:** "a program's `.ld` file has no header line and never spells its own type".

### TF-7 (low) · Q-1 states the extension costs differently from the research it cites

- Q-1 (b) (T-synth.md:1153-1155): *"'ld' is the GNU linker's name, so `plant.ldcfg` reads
  as a linker configuration, the clash that ruled out `.lcf`."*
- `research.md` ruled `.lcf` out because it is in use, not because of how it reads:
  - CodeWarrior's linker requires it: "Linker command files must end in .lcf" (EXT-1);
  - CudaText, Loon and Archicad use it too (EXT-2..4);
  - GitHub has 5,264 such files (EXT-6).
- The same research found `.ldcfg` and `.ldcf` on no registry, with 0 GitHub files
  (EXT-8). So (b) has a cost of connotation, not of collision.
- Q-1 (a) says `.lxcf` has "no other reading". But EXT-8 warns of `lx` for `.lxcfg` ("may
  suggest Linux or LXC"), and lists `.lxc` as taken (libvirt AppArmor templates).
- The question is real, and decision 3 says to choose before M2-2. The comparison should
  set the same kind of cost against each option.
- **Fix:** restate (b)'s cost as a connotation (`ldconfig`, GNU `ld`, EXT-7/8), with 0
  uses found. Give (a) the `lx` caveat.

### TF-8 (low-medium) · Q-17 does not say what happens to a section change between `var` and `var_external` under merge-and-split

- Decision 25: a section change while running is *"allowed, the value kept"*.
- T-synth §4's row for "A section change to or from `var_external`" cites decision 25 only
  for a lone instance. For OE-2 it points to Q-17 (a): merge each global into the env
  before the per-instance switch and split it off after.
- Under a configuration, a change from `var x` to `var_external x` meets two values: the
  instance's own `x`, and the global `x`. Merging overwrites the instance's own value, so
  "the value kept" keeps the global's, not the instance's. For `var_external x` to
  `var x`, Q-17 does not say whose `var_external` list (the running program's or the
  candidate's) the merge and the split use. That decides whether the instance keeps the
  global's value as its own.
- Q-17's options do not cover this. Its (b) objection ("OE-1's lone-instance behaviour
  (decision 25) changes") applies to (a) in this case too.
- **Fix:** add to Q-17 which value a section change keeps under a configuration, and
  which program's externals the merge and the split use at a switch.

### TF-9 (low) · An event task's due time decides decision 11's tie-break, and is neither a rule nor a question

- Decision 11: *"ties go to the earlier due time, then declaration order"* (org:1483).
- T-synth §5.1 (T-synth.md:690): *"An event task's due time is the cycle's `now`, for the
  earlier-due-time tie-break."*
- So a late periodic task of the same priority always runs before an event task. The
  alternatives are the previous cycle's `now` (the earliest time the edge could have
  occurred) or always last within a priority. IEC rule 3a's "longest waiting time" cannot
  tell them apart, because the edge's time within a host step is unknown.
- This is a design choice that orders scans and changes outputs. It has no `Rn` number,
  no mutant owed in §7.1, and no §13 question.
- **Fix:** number it, and add it to Q-14 or a new question before commit 17.

### TF-10 (low) · The landing order stages the reserved words but not the messages that name them

- §8 says *"Before commit 10 a `task` line is refused as an unknown configuration line,
  with T2's message"*. But T2 is *"a line starts with `task`, `var_global` or `program`,
  or is a connection"* (§3.3). So the refusal tells the reader to start the line with
  `task`.
- In the same way, before commit 16:
  - T10 lists `single` among a task's inputs;
  - C5 suggests `task <t> single estop priority 0`.
- R7's did-you-mean set needs staging with these.
- §9 misses three `.lcf` occurrences in PLAN.md (lines 954, 1314, 1784; `grep -n '\.lcf'
  PLAN.md`). It also counts org §7 decision 3's own text among the 18 to rename. §7 keeps
  its decisions "with their options so the reasons stay with them" (org:1446), so decision
  3's placeholder sentence should be annotated, not rewritten.
- **Fix:**
  - stage T2, T3, T10, C5 and the line-keyword set with commits 10 and 16;
  - add PLAN.md's three occurrences to §9;
  - annotate decision 3 rather than rename inside it.

### TF-11 (low) · Wrong readings outside `.lxcf`'s own lines are not named (org §4.7)

- org §4.7: *"Position decides what it means, and each wrong reading gets a diagnostic that
  names it"*, with the location's row "only after `at` in a `.lcf`".
- Reproduced (`p1.log`):
  ```
  == ld body location
    line 2: `panel` is not declared
  ```
  for `xic panel.i.0` in a `.ld` body. R57 names a location only inside `.lxcf`.
- IEC spellings that §4.4 and decisions 5 and 6 name as fallbacks give a bare lex error,
  and that error stops the whole read:
  ```
  == iec :=
    line 3, column 10: illegal character ":"
  == iec ;
    line 3, column 11: illegal character ";"
  == percent
    line 1, column 22: illegal character "%"
  ```
  No decided rule requires a hint for these. They are the first things an IEC user will
  type, and §4.7's rule covers the `.ld` case.
- **Fix:** have the `.ld` compiler name a `<dev>.i|q.<n>`-shaped undeclared operand as a
  location that a configuration gives (or record that M2-2 leaves this out). Optionally,
  have the reader hint at the arrow-free form when it meets `:`.

### TF-12 (low) · Some §13 entries are answered by decided text, and one §4 row is a recommendation not marked as one

- **Q-13** (W6 for `single` with `interval`): org §4.6's caveat says "a `ton` in an
  event-task program", and PLAN M2-6, "Event tasks", includes "`single` combined with
  `interval`". Option (b) narrows decided text, so this is a reading to record, not a
  choice.
- **Q-4** (line order): §13 itself says the decided plant needs (a) (line 4 names `estop`,
  declared on line 6).
- Keeping these as decisions inflates the maintainer's list of 21. They belong in §11's
  "not departures, recorded".
- §4's "A global's value" row, "kept; a changed initial value is reported, as decision 29
  reports a tag's", is not marked *rec.*. Decision 29 covers "a kept bool or dint" of a
  program instance, not a configuration's global. The row is this design's extension, and
  should be marked *rec.* or raised.

---

## Are §13's questions real, correctly framed, complete?

**Real and correctly framed, as written:** Q-2, Q-3, Q-5, Q-6, Q-7, Q-8, Q-10, Q-11,
Q-12, Q-14, Q-15, Q-19, Q-20, Q-21.

**Real, framing to fix:**
- Q-1: (TF-7);
- Q-9: the UINT option, and the S wording (TF-1);
- Q-16: the anchored option (TF-3);
- Q-17: section changes (TF-8);
- Q-18: IEC allows it (TF-2).

**Answered by decided text:** Q-4, Q-13 (TF-12).

**Missing:**
- the event task's due time (TF-9);
- where "which tags a program writes" lives, against org §4.4:466 (TF-4);
- the staging of messages before commits 10 and 16 (TF-10, a landing question rather than
  a maintainer's).
