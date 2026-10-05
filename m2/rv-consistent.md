# rv-consistent: the design record, read for consistency and house rules

Label: rv-consistent. I reviewed `record.patch` applied with `git apply` to a fresh copy of
`/home/user/logex` at `47319f7`. The copy was `scratchpad/m2/rv-consistent-work`, and it
has been deleted. `/home/user/logex` was not modified. Line numbers are in the patched
files.

## Gate, run in my copy (Elixir 1.20.4 / OTP 28, judged by exit code)

| Command | Exit |
|---|---|
| `mix format --check-formatted` | 0 |
| `mix compile --force --warnings-as-errors` | 0 |
| `MIX_ENV=test mix compile --force --warnings-as-errors` | 0 |
| `mix test --warnings-as-errors` | 0 (`Result: 430 passed (6 doctests, 424 tests)`) |

`git diff HEAD --check` reports no whitespace errors.

## Checks that passed

- **§7 numbering.** I extracted §7 the way the labels test does (from `## 7. Decisions` to
  `## 8. `):
  - `^(\d+)\. \*\*` gives exactly 1 to 40, in order, and nothing else;
  - `^- \*\*F(\d+)\.\*\*` gives exactly F1 to F16.
- **Vendor names and model names.** Searching the whole tree for the conventional vendor's names
  and model names finds nothing.
- **Design-pass labels.** The added lines contain no A-n, B-n, D-n, S Q-, FS-Q, T Q-, X-n,
  R-n, RF-, TF-, JS/JF/JT, W-n, G2 or commit-number citations.
- **`.lcf`.** It is left only in decision 3's original text, which is annotated, and in
  decision 35's options. No `.lcf` appears in `lib/` or `test/`.
- **Decisions 30 to 40** are each recorded with options, a recommendation and an outcome.
  Decision 35 uses "*Recommended …* The maintainer chose …", the style of decisions 18, 28
  and 29.

## Findings

### C1 (medium): "the header is the file's first rung" contradicts M1-3's rule that declarations come before the first rung

The record words the block header as the first *rung* in four places:

- org §4.3, line 254: "*(its first rung, since 2026-10-02: comments and blank lines may
  come before it …)*";
- org §4.10 M2-5, line 1422: "Its header, `function_block <name>`, is the file's first
  rung";
- decision 4's annotation, line 1818: "the header is the file's first rung, so comments
  and blank lines may come before it";
- PLAN M2-5, line 1446: "*(its first rung since 2026-10-02 …)*".

Every block's declarations follow that header (§4.3's own `seal` example). The repository
already uses "the first rung" to mean the first rung of logic, which every declaration
must precede:

- README line 27: "declaration lines before the first rung";
- README line 152: "Every tag is declared before the first rung";
- PLAN M1-3, line 704: "Declarations live in the `.ld` file, before the first rung";
- PLAN M1-3, line 781: "a declaration after the first rung" is a diagnostic;
- `lib/logex/declarations.ex:5`: "every one comes before the first rung of logic".

Reproduced on today's code:
`Logex.compile("// seal\n\nfunction_block seal\nvar_input start bool\n…", name: "seal")`
gives "line 4: `var_input` after the first rung (line 3): declarations come first". So
under the record's wording, every block file declares "after the first rung".

**Fix:** say what is meant: "its first line that is not blank or a comment (the lexer
drops those)". Use that wording at all four places.

### C2 (medium): decision 32's "until a scan runs it" is not annotated in three places that still say "one scan" or "next scan"

The record annotates decision 21 and §4.9's "A scan empties the list". These places are
left as they were:

- org §4.9, lines 876–879, the "**Settled (decision 21):**" bullet: "An `ons` the edit
  adds, or whose rung changed …, passes no power on the first scan after the switch".
- org §4.9, line 1059, the switch-rule table: "| One-shots (decision 21) | Blocks an `ons`
  for the next scan: below |".
- org §5, line 1590, the Online edit row. The record edited this row, adding "M2-5 brings
  the edit of a program that holds function blocks (decisions 31 and 32)". The same row's
  third column still ends "and blocks an added or changed `ons` for one scan". The row now
  contradicts itself.

**Fix:** add "*(Changed 2026-10-02 by decision 32: inside a function block, until a scan
runs it)*" at all three places.

### C3 (medium-low): the new refusal of adding or removing an event task's `interval` narrows decision 19 and §4.9's "Allowed" list, and neither is annotated

- Decision 19 (line 1869): "interval and priority may change".
- §4.9 (line 915): "Allowed while running: … a task's interval and priority". The record
  annotates this sentence, but only with decision 40 and decision 31.
- The record adds the refusal at §4.10 M2-6 (line 1562): "Changing a task's `single`, or
  adding or removing an event task's `interval`, is refused while running". It repeats it
  in §4.9's state table (line 1207) and in PLAN OE-2 (line 1675).

Adding or removing an interval is a change to the interval, which the decided text allows.
Changing `single` is also absent from §4.9's "Refused while running" list.

**Fix:** annotate decision 19 and the §4.9 "Allowed" sentence. Optionally add the
`single` refusal to the "Refused while running" list.

### C4 (medium-low): §4.10 and PLAN disagree on which item refuses two device names that differ only in case

- org §4.10, under **M2-1** *Points* (line 1372): "Two device names that differ only in
  case are refused, as two names that differ only in case are; no spike built this". §4.10
  says its rules are "grouped by item in the order they land", so this reads as an M2-1
  rule.
- PLAN "Owed" (line 1523) says M2-2's fourth commit does it: "Two device names that differ
  only in case are refused there".

The design put it in commit 16, which is M2-2.

**Fix:** move the sentence to §4.10's M2-2 "The checks", or say there that M2-2's port
lands it.

### C5 (low): code that has not landed is described as landed

- org §4.10 M2-1 *Warnings* (line 1383): "`%Logex.Configuration{}` has a `warnings`
  field, landed empty." No `Logex.Configuration` exists. The design says "lands empty in
  M2-1".
- Weaker cases, in the same direction:
  - "*(its first rung, since 2026-10-02 …)*" (org line 254; PLAN line 1446);
  - "*(Since 2026-10-02 a priority is 0 to 65535 …)*" (PLAN line 1508).

  Each reads as a rule in force since that date, for syntax and tasks that do not exist
  yet.

**Fix:** "lands empty with M2-1". Also "decided 2026-10-02" in place of "since 2026-10-02".

### C6 (low): §4.9 still has configurations edited "from M2", against the record's rule that a configured plant is not edited until OE-2

The record states the rule at §4.10 "Throughout" (line 1350), in PLAN M2-1 and in PLAN
OE-2: "A configured plant is not edited until OE-2". OE-2 comes after Milestone 2.

§4.9 is not annotated:

- line 839: "A candidate, the whole program (from M2, the whole configuration)";
- line 850: "Every switch happens between two scans, and from M2-1 between two cycles";
- line 898: "The report of every step lists each var_output, and from M2-2 each output
  point".

**Fix:** annotate each to read "from OE-2", or add one note at the head of §4.9's edit
cycle.

### C7 (low): §6.1 point 4 restates decision 9's member rule without decision 33's annotation

- org line 1657: "**Member writes (decision 9).** Members are readable anywhere; logic may
  write only `.pre` and `.acc`."
- Decision 9 (line 1836) and §4.3 (line 334) carry "*(Changed 2026-10-02 by decision 33
  …)*". This restatement does not.

**Fix:** add the same one-line annotation.

### C8 (low): two rows of §4.9's new state table state the rule for adding or removing a task differently

Both rows are about adding or removing a task, and decision 19's rule is "adding or
removing a task is refused until its rule is verified":

- the `next_due` row (line 1204) reads "refused until verified (decision 19) | refused until
  verified";
- the event task's last-sample row (line 1207) reads "refused (decision 19) | refused".

**Fix:** use "refused until verified (decision 19)" in both rows.

### C9 (low; the design sanctions it, so this is a judgment call): decided and landed history rewritten from `.lcf` to `.logex` without annotation

Decision 3 is annotated, but these were rewritten in place:

- decision 5 (line 1824): "or configuration files (`.logex`) will have two spellings";
- §6.1 point 7 (line 1676), a landed record: "**Fix B8 (a lone CR) before any `.logex`
  exists.** … *(Landed 2026-09-30.)*";
- PLAN M1-5 (line 958): "so the `.logex` words wait for M2-2".

The house rule is that decided text a new decision changes is annotated rather than
silently rewritten. The design's commit 0 did ask to rename the other occurrences, and
only decision 3 was to be annotated.

**Fix, if wanted:** in decision 5 and §6.1 point 7, keep `.lcf` and add "(`.logex` since
decision 35)".

## Not defects (checked)

- **§4.6's API block** is annotated directly after it, with decision 38's `restart/2` and
  `overlaps/1`. It agrees with decision 38, §4.10 *Restarting* and the state table.
- **Decision 4** is annotated. Its only problem is the wording in C1.
- **§4.9's Resume row** is annotated. No other text states the "a `last` before `now`"
  basis.
- **The M2-1 and M2-3 Done-whens:**
  - PLAN rewrote them in place and §6.2 kept the old wording; both are annotated.
  - The counts are right: 10 ms → 100, 30 ms → 34, task-less → 100; 50 ms → 20.
- **PLAN's "M2-5 needs only M1-6 and B5"** is still true, because B5's narrow part landed
  (`d0870b3`). B5's annotation states what Milestone 2 still needs from it.
- **OE-2's three "OE-2 decides" questions** match between §4.9's table and PLAN OE-2.
