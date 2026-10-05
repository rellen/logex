# T-rev · The configuration file, globals and event tasks: M2-2, M2-3, M2-4, M2-6, revised

Label T-rev, track T of the Milestone 2 design pass. This revises T-synth
(`scratchpad/m2/T-synth.md`) against the confirmed findings of the refutation pass
(rf-T-correct, rf-T-fit, rf-X-consistency). Written 2026-10-02 against `/home/user/logex`
at `47319f7` (main, 2026-10-01), which this pass did not modify (`git -C /home/user/logex
status --short` is empty). The spike was revised in a copy of T-synth's,
`scratchpad/m2/T-rev-work`. Its diff against `47319f7`, untracked files included, is
`scratchpad/m2/T-rev.patch`. The mutation driver, its per-mutant results and its log are
`scratchpad/m2/T-rev-mutation.py`, `.jsonl` and `.log` (raw output `.out`). Probes and
receipts are in `scratchpad/m2/T-rev-probe/`; the vendor sources the naming survey read are
in `T-rev-probe/sources/` with a `README.txt`. Every `mix` run used Elixir 1.20.4 / OTP 28
(`scratchpad/toolchain/env.sh`) and is judged by its exit code.

**Citations.** `org` is `docs/organisation.md` and `PLAN` is `PLAN.md`, both at `47319f7`.
A bare `file:line` is the repository at `47319f7`. `spike:file` is the file in
`T-rev-work`, cited by function name because its line numbers move. `T-synth.md`,
`T1.md`, `JT1.md`, `S-rev.md`, `F-rev.md`, `inventory.md` (`inv`), `research.md` (`res`),
`readiness.md` (`rdy`) and the refuters' files (`rf-T-correct.md`, `rf-T-fit.md`,
`rf-X-consistency.md`) are this pass's documents in `scratchpad/m2/`. Finding ids
(`rf-T-correct-3`, `TF-5`, `X1` and so on) are the refutation pass's.

**Labels.** Rule labels (`Rn`, `Wn`), message labels (`Hn`, `Fn`, `Tn`, `Cn`, `Vn`),
mutant labels (`Mn`, `Jn`, `Nn`, `Xn`, `Pn`) and question labels (`Q-n`) are this
document's own. They must never be cited in `lib/`, `test/` or `CLAUDE.md`
(`edit_test.exs`'s labels test, `test/logex/edit_test.exs:1541-1603`; it caught a stray
"R25" in a spike comment during this revision, since removed). The spike cites none, and
cites no decision past 29 and no fix past F16. `Rn` keeps T1's numbers where the rule is
T1's; rules added by T-synth are R51–R61, and by this revision R62–R68. Message labels
added here: H15, F10–F12, C6b, C49, V4. Question numbers Q-1 to Q-21 keep T-synth's
numbers, so S-rev's cross-references stay right; Q-4 and Q-13 are withdrawn (§11), and new
questions start at Q-22. The conventional vendor and its products are not named.

---

## Changed in revision

Each confirmed finding against track T, and each cross-track finding with a T side, and
what was done. "Red" means the mutant that reverts the fix alone fails the full suite
(§7.2). Every mutant was run on the final spike, the whole table at once.

### Fixed in code, each with a test that fails when the fix alone is reverted

- **rf-T-correct-1** (an improper list escaped as `FunctionClauseError`). `entries!/1` now
  walks the list to its tail before anything walks it with `Enum` (`proper!/2`), and an
  improper tail raises H8, `entries must be a list, got: …`. `print/1`, `check/3` and
  `new!/3` all go through it. Tests: "host mistakes" gains four calls, `entries!/1`,
  `print/1`, `check/3` and `new!/3` on `[entry | :x]`, each with the pinned message. The
  totality test's `junk(0)` gains `[:a | :b]` and an entry list with an improper tail, and
  a new `case_of(10)` builds entry-shaped lists with improper tails, so the seeded test
  reaches the case. Mutant **P1** is red. Receipt: `T-rev-probe/fixes.log` gives the
  pinned `ArgumentError` from all four.
- **rf-T-correct-2** (a line holding `(`, `|` or `)` declared nothing, and cascaded). The
  reader now reads a delimiter line's words up to the delimiter, and turns what they name
  into the same `{:declared, …}` placeholder any broken line gives. The delimiter stays
  the line's one diagnostic. R13 is amended to say so. Tests:
  - new, "a line broken by a delimiter still declares what its words before it name", one
    line of each kind (task, global, program, connection) as a whole list. It gives exactly
    the four delimiter diagnostics, with no "no task", "no global", "no instance" or
    "unconnected" after them, and pins `read/1`'s placeholders;
  - the existing delimiter test loses "this configuration declares no `program`", which
    only followed from the line declaring nothing (the verdict's note).

  Mutant **P2** is red. Receipt: `program m1 motor ( with fast` with uses of `m1` now gives
  only `line 3, column 18: a configuration line cannot hold `(``.
- **rf-T-correct-3** (`entries!/1` and `print/1` accepted entries the reader refuses).
  `entries!/1` now refuses, in any case, the keyword the reader takes for itself in each
  of four places: a task's name or its `single` (`single`, `interval`, `priority`; T9,
  T13), a global's name (`at`, `bool`, `dint`; T18), and a program's type (`with`; T30).
  The H9 rule reads, for example, ``a global's name is not `at`, `bool` or `dint`, in any
  case: a line reads that word as its keyword``. A keyword that hits no such place (`task`
  as a name or as a type) is still taken, since it reads back. Tests:
  - five cases in "an entry no line can say raises ArgumentError", each through `check/3`
    and `print/1`;
  - a new property, "every entry entries!/1 takes prints to text that reads back to it,
    keywords included". It draws 3,000 seeded lists of one to three entries of every kind,
    with names from all ten keywords (lower case and capitalised) and five plain names, and
    for each list `entries!/1` takes, asserts `read(print(entries))` gives the same entries
    on lines 1, 2, 3. It asserts both halves are reached. The property passes with exactly
    these four places, so the reader has no fifth.

  Mutants **P3a–P3d**, one per place, are all red. R48 and R49 are amended.
- **rf-T-correct-4** (a dotted name after `with` got a global's or a member's reading). A
  dotted name where a task is wanted is now ``no task `<n>`: a task's name has no `.`,
  which is kept for a path and a location``, with a did-you-mean among the tasks (C49,
  rule R64). Test: "a dotted name after `with` is told a task's name has no `.`…", which
  covers `fast.x` (the verdict's added case, now with ``did you mean `fast`?``),
  `panel.i.0`, `m1.start` and `x.y`. Mutant **P4** is red.
- **rf-T-correct-5** (file-kind messages contradicted themselves). Both loaders now
  classify a path before its extension, by one rule written in both modules: an empty
  path (F11), a path ending in `/` (F10), and a dotfile, which is all extension
  (`Path.extname/1` gives `""` for `.ld`). So `Logex.compile_file(".lxcf")` gives F6, the
  configuration loader's `.lxcf` gives F12 (`` `.lxcf` names no configuration…``), and its
  `.ld` gives F1, the verdict's added case. Tests: logex_test.exs "a path that names no
  file, a directory or only an extension says which", and the same in the loader's
  describe. Mutants **P5a–P5g** are all red.
- **rf-T-correct-6** (C6 told an event task to drop `with`). A task with `single` and
  `interval 0` now gets C6b, ``… and a task that runs only on the events of its `single` is
  declared without `interval`, as in `task fast single g priority 1` ``, the example
  carrying the task's own priority. Test: "an event task's interval of 0 is told to leave
  `interval` out…", which also compiles the source with the advice taken. Mutant **P6** is
  red.
- **rf-T-correct-7** (C45's example in a refused spelling). The example now carries the
  location's one spelling, from the parsed key. Test: "a location's advice is written in
  its one spelling…", for `panel.I.3` and the verdict's `panel.i.04`; it compiles the
  advice as written. Mutant **P7** is red.
- **rf-T-correct-8** (a declaration refused for its name cascades). In part, in code: a
  name refused as a keyword or for its `.` (C1, C2) now enters `broken`, as a broken line's
  name does, so nothing that names it is reported again. That removes the one new
  misreading the verdict found (`task a.b` then `with a.b`), and the second message on a
  keyword. A name declared twice, or a case twin, is left as the `.ld` side leaves it ("a
  bad name is not recovered", `lib/logex/declarations.ex:190-194`), and the test pins that
  too, so a change of rule shows. Test: "a name no line can declare is refused once…".
  Mutant **P8** is red. Whether duplicates should become placeholders is §13 **Q-26**.
- **rf-T-correct-10** (a device named like an instance). Where a global is wanted, a
  location that a global is declared at now reads as that location first, whatever its
  device is called. So `m1.start m1.i.0`, with `g` at `m1.i.0`, gets C44 (name `g`), not
  C26. A device spelled like an instance with no global at that point still reads as the
  instance's member. Test: in "a location's advice is written in its one spelling, and a
  declared one reads first". Mutant **P10** is red. Device names' case, and whether a
  device may share an instance's name, are §13 **Q-27**.
- **TF-11** (a location in a `.ld` body was not named as one). The `.ld` compiler now
  names an operand shaped like a location (a device, `i` or `q` in any case, then
  whole-number fields), when its first part is undeclared, as V4: ``` `panel.i.0` is a
  location, written only after `at` on a configuration's `var_global` line: a program
  reaches a point through a var_input or var_output that the configuration connects to the
  global at it```. It is reported once a device, as any undeclared name. Test:
  validation_test.exs "a location in a rung is named as one…", which also pins that
  `drive.x.0` and `m1.i.x` stay plain undeclared names. Mutant **P11** is red. The IEC
  spellings half (`:=`, `;`, `%`) is not changed: no decided rule asks for a hint, and a
  lex error is one diagnostic by convention (the verdict's correction).
- **X13** (a block type given as a program; T's side). `compile/3`, `check/3` and `new!/3`
  refuse a `%Logex.FbType{}` under a key with H15, in S-rev's interim words (its BT-2):
  ``the program given as `<key>` is `<name>`, a function block type, which runs inside a
  program: a program instance is of a %Logex.Program{}``, instead of the generic H6. Test:
  two cases in "host mistakes", `ton` under its own name and under another. Mutant **P13**
  is red. One wording at every entry point is §13 **Q-25**, as S-rev Q-39.
- **X15** (`diagnostic.ex`'s attribution of `:configure`). T's `lib/logex/diagnostic.ex` is
  now S-rev's file byte for byte (`diff` of the two is empty), so both moduledoc bullets
  attribute the stage to `Logex.Configuration.check/1` at M2-1 and the merge has no
  conflict there. No test: a moduledoc.

### Fixed in `docs/naming.md` (documents; `naming_test.exs` still passes)

- **TF-5.** The 17 vendor rows that read "not surveyed" or "not checked" are surveyed from
  primary sources: 9 Mitsubishi, 7 Siemens, 1 CODESYS. Sources:
  - Siemens *Programming Guideline for S7-1200/S7-1500*, V1.5, 03/2017;
  - Siemens *S7-1500 Getting Started*, A5E03981761-AC, for the cycle time;
  - Siemens' S7-1500 digital input module manual, A5E35681478-AC, for the hardware
    interrupt's edges;
  - Mitsubishi *MELSEC iQ-R Programming Manual (Program Design)*, SH(NA)-081265ENG-R;
  - Mitsubishi *MELSEC iQ-R CPU Module User's Manual (Application)*, SH(NA)-081264ENG-AR;
  - CODESYS help, *AT Declaration*.

  Each row quotes its source with section and page. Three `unverified` marks remain, and
  each says what was looked for: Ed 4's text, whether CODESYS fires an event task at start,
  and what Siemens' `AT` does (the guideline only lists "AT instruction" as an access
  type). Two findings came out of the survey and are recorded in the rows:
  - Mitsubishi's event execution type on "Bit data ON (TRUE)" is a level, not an edge;
  - the same page says a timer (T) "do[es] not measure time when the trigger execution
    condition … is not met", the hazard W6 warns of.
- **TF-1.** The `priority` stanza's Why now says that Ed 3's UINT gives 0 to 65535 (Table
  63, p.182; Table 10 note d, p.31), that Ed 2 and the grammar bound nothing, and that
  logex takes a dint's range, wider than Ed 3's. The choice is §13 Q-9.
- **TF-6.** The `program` stanza says "a program's `.ld` file has no header line", not "a
  `.ld` file", so decision 4's `function_block <name>` header does not falsify it.
- **TF-2 (in part).** The `var_external` stanza's IEC row cites Ed 2 Table 33 features
  10a and 10b and the grammars of both editions: IEC allows VAR_EXTERNAL in a function
  block.

### Fixed in the design (documents only: no code changes, so no test)

- **rf-T-correct-9.** §12 now gives the measured figures, re-run on the revised spike
  (`T-rev-probe/growth/p6.log`, `p7.log`). The valid path costs 3.83x for 4x the
  instances. The error path costs 15.8x for an undeclared global and 15.72x for an
  undeclared task. The `.ld` compiler's undeclared uses cost 16.03x, so the cost is
  inherited. The fix was already listed as a risk; no index was built.
- **TF-1.** Q-9 gains option (d), 0 to 65535 from Ed 3's UINT, with decision 7's argument
  for tightening now, and is recommended. inv U24 is answered from `ed3.txt`. S-rev's Q-8
  recommends (a) on the premise that IEC states no bound, which holds for Ed 2 and the
  grammar only, so the two tracks now differ: one answer is needed.
- **TF-2.** Q-18 cites both grammars and Table 33. §11 records the refusal as a
  deliberate, reversible departure from IEC. inv U19 is resolved.
- **TF-3, X7.** Q-16 now has S-rev Q-23's option set, including the next multiple of the
  new interval from the anchor. It names that option's cost: the anchor becomes runtime
  state with its own rule across an edit. It also says that (a) gives up the anchored
  phase after an edit. Both tracks now recommend (a).
- **TF-7.** Q-1 states (b)'s cost as a connotation with 0 uses found (res EXT-8), not the
  collision that ruled out `.lcf`.
- **TF-8.** Q-17 now says which program's externals the merge and the split use at a
  switch, and which value decision 25's "the value kept" means under a configuration, in
  both directions.
- **TF-9.** An event task's due time is new question **Q-22**, with the owed same-priority
  ordering test (§7.1).
- **TF-10.** §8 stages the messages that advertise words: T2, T3, T10, C5 and the
  line-keyword did-you-mean set, at commits 3, 10 and 16. §9 lists PLAN.md's three `.lcf`
  occurrences (954, 1314, 1784) and annotates decision 3 instead of rewriting it.
- **TF-12.** Q-4 and Q-13 are withdrawn from §13: decided text settles both, and §11
  already recorded the readings. §4's row for a global's changed initial value is marked
  *rec.* and points to **Q-28**, the same question as S-rev Q-34.
- **X1.** §8's "nothing below changes but commit 13" is corrected. With M2-5 before M2-2
  (Q-23), the change lands in the commits that read programs: 2, 5, 12, 13, 14 and 16
  (§8). §5 states the two seam rules: a writes walk keyed by the instance's own type, not
  `Compiler.instructions/0`'s `:block` marker; and a loader that checks a file's kind.
- **X2.** §8 says the `Logex.Configuration` surface pin in `runtime_test.exs` is rewritten
  once, when T's checks become rows of S's `check/1`. Two textual pins merge cleanly and
  cannot both pass. The error mode for a host mistake in the validator is part of **Q-20**
  (S-rev Q-37, part 3). T's view is stated there.
- **X3.** §8 commit 13 refuses `var_external` in a block's file unconditionally once M2-5
  has landed, with a located `:validate` diagnostic and a test that fails when it is
  reverted.
- **X4.** §8 commit 2 composes the `.ld` gate in front of F's `load/3`. Commit 5 resolves
  program types through `load/3`, with one memo per configuration and a kind check.
- **X5.** The landing order is **Q-23**, the same question as S-rev Q-22. The
  recommendation is M2-1, then M2-5, then M2-2: it keeps the decided Done-when text, and
  puts M2-5 before T's code.
- **X9.** Q-21 is merged with S-rev Q-20, with what each track would do. T keeps its view
  on part 3, and says why.
- **X10.** Q-20 is merged with S-rev Q-37: the words, the granularity, and the error mode.
- **X14.** §8 begins with one design-record commit for all three tracks, which allocates
  the §7 decision numbers. "30 onward" is no longer claimed.
- **X18.** F15's owner is **Q-24**, as S-rev Q-38. §5 states both citation conventions.
- **X19.** The agreements are in §13's closing table. TF-1 changes one row: the priority
  bound is no longer agreed.
- **X20.** §8 records the hand composition of `Declarations.check/2` with `shared/1`, and
  of the two naming tests.
- **No T side:** X6 and X16 (S and F only), and X11 and X12 (S's statements, which S-rev
  corrected).

---

## 0. Summary

- **Base: T-synth**, itself T1 with JT1's defects fixed and grafts added. Its reader,
  checks, loader, extension, reservations and run-time rules are kept.
- **Every confirmed finding on track T is fixed or turned into a question.** Ten are fixed
  in code, each with a red mutant of its own: rf-T-correct-1 to -8 and -10, TF-11 and X13.
  rf-T-correct-8 is fixed in part, and its remainder is Q-26. The naming survey is complete
  (TF-5).
- **Gate:** passes three times, **508 tests** (6 doctests), up from 499 in T-synth and 430 at
  `47319f7` (§6).
- **Mutation table:** **127 rules reverted one at a time, 127 red** (§7.2): T-synth's 107, five
  re-pointed at moved code, and 20 new, one or more for each fix.
- **The track's done-when still passes.** org §4.4's plant reads into 40 entries and
  compiles with no diagnostic and no warning. The receipt's broken source gives exactly
  seven diagnostics, on lines 7, 9, 11, 12, 14, 15 and 16.
- **Decisions for the maintainer (§13): 26 questions**, Q-1 to Q-28 less the two
  withdrawn (Q-4, Q-13; decided text settles them). Seven are new: Q-22 to Q-28. Fifteen
  are cross-track. Each is stated in S-rev's terms, with its S-rev number and what each
  track would do. The tracks still differ in two places that need one answer:
  - the priority bound: T now recommends Ed 3's 0..65535 (Q-9), and S-rev Q-8 a dint's;
  - whether `check` raises or returns a diagnostic for a host's mistake: a bad line
    (Q-21 part 3) and a bad name or program (Q-20 part 3). T says raise; S-rev says
    return.

  Everything else that both tracks ask is now recommended the same way in both (§13's
  closing table).

---
## 1. API and data shapes

### 1.1 `Logex.Configuration.Text` (new; the configuration file's own module)

```elixir
Logex.Configuration.Text.keywords()        :: [String.t()]   # the ten words, lowercase
Logex.Configuration.Text.keyword?(word)    :: boolean        # in any case
Logex.Configuration.Text.read(source)      :: {:ok, [entry]} | {:error, [%Logex.Diagnostic{}], [entry | placeholder]}
Logex.Configuration.Text.print([entry])    :: String.t()
Logex.Configuration.Text.entries!([entry]) :: :ok            # raises ArgumentError
```

- `read/1` is a hand-written recursive descent over `Logex.Lexer`'s tokens (spike:
  `lib/logex/configuration/text.ex`). It gives one diagnostic for each line it cannot
  read. Each is at its token, with a column, at `stage: :configure`, in line order. A lex
  error stops the read and is the only diagnostic (`stage: :lex`).
- With an error, `read/1` also gives the entries it could read. For a broken line whose
  name it could read, it gives a placeholder: `{:declared, line, %{kind:, name:}}`, or for
  a broken connection `{:declared, line, %{kind: :connection, instance:, member:}}`. The
  checks then never report that name again. A line broken by `(`, `|` or `)` is read up to
  the delimiter for this, so it declares what its words name too (rf-T-correct-2).
- `print/1` writes lowercase keywords, one space between words, no indentation and no
  comments. An entry with a line is printed on that line, the lines between left empty.
  Entries with no line are printed on lines 1, 2, 3 and on. It runs `entries!/1` first.
- `entries!/1` is the text's own definition of its data, as `Logex.Parser.well_formed!/1`
  is a program's (`lib/logex/parser.ex`). Both `print/1` and `Configuration.check/3` call
  it. It raises `ArgumentError` (§3.1 H8, H9) unless the list is proper and every entry
  is one a line can say:
  - one of the four kinds below, with that kind's fields;
  - every name one name token to the lexer;
  - a connection's instance with no `.`, and `instance <> "." <> member` again one token;
  - no name a keyword the reader takes for itself in that place, in any case: `single`,
    `interval` or `priority` as a task's name or its `single`; `at`, `bool` or `dint` as a
    global's name; `with` as a program's type (rf-T-correct-3);
  - every number an integer of 0 or more;
  - the lines all nil, or positive and strictly rising.
- Every public function refuses a host mistake with a pinned `ArgumentError` (§3.1).

### 1.2 Entries: what the text reads into

```elixir
{:task,       line, %{name: name, single: nil | global, interval: nil | ms, priority: nil | p}}
{:global,     line, %{name: name, type: :bool | :dint, initial: nil | n, at: nil | location}}
{:program,    line, %{name: name, type: type, task: nil | task}}
{:connection, line, %{instance: name, member: member, to: {:global, name} | {:constant, n}}}
```

- `line` is a positive integer from text and `nil` from Elixir. Every other field is plain
  data. A location is the string as written, `"panel.q.0"`, and is parsed by the checks,
  so text and Elixir meet one rule for it.
- `member` is the text after the first `.`: `m1.t1.pre` is `instance: "m1", member:
  "t1.pre"`, which the checks refuse as too deep. `m1.0` is member `"0"`, which the text
  can say, so the data path takes it (JT1 D2's reverse case).
- A missing `priority`, or a task with neither `interval` nor `single`, reads as `nil`.
  The grammar allows it, and the checks refuse it with one message on both paths.
- org §4.4's plant reads into 3 tasks, 16 globals, 3 programs and 18 connections, in line
  order (§6).

### 1.3 `Logex.Configuration` (the spike's stand-in for track S's constructor)

```elixir
Logex.Configuration.compile(name, source, programs) :: {:ok, %Logex.Configuration{}} | {:error, [diagnostic]}
Logex.Configuration.check(name, entries, programs)  :: {:ok, %Logex.Configuration{}} | {:error, [diagnostic]}
Logex.Configuration.new!(name, entries, programs)   :: %Logex.Configuration{}          # raises ArgumentError
Logex.Configuration.compile_file(path)              :: {:ok, %Logex.Configuration{}} | {:error, [diagnostic]}
Logex.Configuration.extension()                     :: ".lxcf"
```

- `compile/3` is org §4.4's pure seam, in its decided argument order (org:470; §13 Q-19).
  `programs` is a map from each type's name to the `%Logex.Program{}` of that name. It
  does no file I/O.
- `check/3` is the one checked constructor's core. It takes the entries `read/1` gives,
  or the same entries built in Elixir with no lines. A problem the text could also have is
  a diagnostic. One about an entry with no line has `line: nil` and sorts after those with
  a line.
- `new!/3` is the Elixir face (JT1 graft 3). It refuses an entry with a line
  (S-synth NW-3, "a line is where a configuration file declares the element"). It then
  raises one `ArgumentError` whose message is every problem `check/3` finds, a line each,
  formatted by `Logex.Diagnostic.format/1`, as `Runtime.call/4` raises every input
  problem at once (`lib/logex/runtime.ex:270-289`). Warnings do not raise; they ride on
  the configuration.
- `compile_file/1` is the loader:
  - the path must end in `.lxcf`, and the configuration is named for the basename less it.
    An empty path, one ending in `/`, and `.lxcf` alone are refused each with its own
    message, and `.ld` alone is a program's file (F1, F10–F12; rf-T-correct-5);
  - each type a `program` line names is compiled once, with `Logex.compile_file/1`, from
    `<type>.ld` in the same directory, in the order of the line that first names it;
  - every diagnostic and warning carries its file, the configuration's own first, in
    line order, then each type file's;
  - a type with no file is an unknown program type, at `:configure`, with a did-you-mean
    among the `.ld` files beside the configuration (D4);
  - a message that cites a line of a type's file names that file (graft 1).
- A `%Logex.FbType{}` given as a program is refused with H15, not the generic H6 (X13).
- `%Logex.Configuration{name, tasks, globals, instances, connections, programs, warnings}`
  in the spike. Each list is in declaration order, each element a map with its `:line`.
  `connections` are resolved to `%{instance, member, direction: :input | :output, to,
  line}`. `warnings` are `%Logex.Diagnostic{severity: :warning, stage: :configure}`, in
  line order.

### 1.4 Changes to existing modules (spike)

- `Logex.compile_file/1`: a path whose extension is not exactly `.ld` is a `:file`
  diagnostic, `line: nil`, `file: path`, and the file is not read (PLAN M2-2,
  PLAN.md:1322). A path is classified first, by the same rule as the loader's: empty,
  ending in `/`, or a dotfile, which is all extension. Messages F6–F11 (§3.2).
- `Logex.Compiler`: an operand shaped like a location whose first part is undeclared is
  reported as a location (V4, R67; TF-11), once a device. Nothing else in the `.ld`
  language changes; the golden record is untouched.
- `Logex.Declarations`: `"var_external" => :var_external` in `@sections`. `check/1` gains
  three rules: no initial value, no instance, and no name that a configuration file
  reserves (§3.6).
- `Logex.Tag`: `section` gains `:var_external` (typespec).
- `Logex.Diagnostic`: `stage` gains `:configure`. `line` may be nil for a `:configure`
  problem with an element built from Elixir or with the configuration as a whole. The
  file is S-rev's, byte for byte, which attributes the stage to
  `Logex.Configuration.check/1` at M2-1 (X15).
- `Logex.Runtime`: unchanged. A lone instance keeps a `var_external` as its own tag at 0,
  which `call/4` refuses as an input with its existing message (`lib/logex/runtime.ex:305-308`;
  §13 Q-10, option G2).
- The public-surface test (`test/logex/runtime_test.exs:688-735`) pins both new modules:
  `Logex.Configuration` `[__struct__/0,1, check/3, compile/3, compile_file/1, extension/0,
  new!/3]` and `Logex.Configuration.Text` `[entries!/1, keyword?/1, keywords/0, print/1,
  read/1]`.

### 1.5 The contract with track S, against S-synth's actual design

T1 wrote its contract (C1–C8) blind. S-synth now exists (`S-synth.md` §1.1, §5), so each
item is stated against it. S-synth lands the §4.4 checks with M2-1, on structs, through
`check/1` (S-synth D-1). This track's checks therefore become rows of S-synth's `check/1`
when they land; the spike's `check/3` is where they were built and measured.

| # | What track T needs | S-synth today | What the merge must do |
|---|---|---|---|
| C1 | Entries in, by kind and line, mapped one to one onto S's element structs | `Task`, `Global`, `Instance`, `Connection` structs with `line` (S-synth §1.1) | `read/1`'s entries map one to one. `to: {:global, g} \| {:constant, n}` becomes S's `to: g \| n`. `Task` gains `single` (S-synth §5, M2-6) |
| C2 | Every check runs once, for text and Elixir alike | `check/1`, total, stage `:configure`, line order, `file` stamped (CF-28) | Add R14 (keywords as names), R41, R51–R54 (§2), R44–R45, W1–W6. Choose one message per rule (§13 Q-20) |
| C3 | Problems as diagnostics, lined ones in line order, unlined last | CF-28a | Agreed |
| C4 | A raising Elixir face, every problem at once | `new!/1`, a keyword list, raising all (S-synth §3.1) | Agreed in substance. The spike's `new!/3` stands in, with positional arguments to match `compile/3` |
| C5 | Placeholders for broken lines from the text path | not in S-synth | Either `check/1` takes `{:declared, …}` stand-ins, or the reader filters `check/1`'s diagnostics that name a broken line's name (§13 Q-20) |
| C6 | Types that failed to load are declared, not echoed as unknown | not in S-synth | The loader passes the failed set, or filters as for C5 |
| C7 | Fields read back: a global's location, initial, line; an instance's type, task, line; a connection's direction; `warnings` | all present but direction, which S derives from the member's section | Agreed: S's runtime derives direction once, in `wiring` |
| C8 | One copy of each global; no `var_external` held in an instance's env between scans | `globals`, one value each (S-synth §1.2) | M2-4 adds the merge and split around `call/4` (§5, §13 Q-10) |
| C9 (new) | Lines in text order only: nil from Elixir, or rising | CF-4: a line is positive or nil; `new!/1` refuses lines (NW-3) | `check/1` also refuses a non-rising line, or the printer's round trip compares "but for lines" (§13 Q-21) |
| C10 | One spelling of an address | CF-11b: no leading zero | Agreed; the spike refuses `panel.q.00` too (R25) |
| C11 (new, X2) | A host mistake in a configuration's name or programs raised as `ArgumentError` (H1, H4, H6, H15) | `check/1` returns it as a diagnostic; raises only on a non-struct | One mode (§13 Q-20 part 3; S-rev Q-37) |
| C12 (new, X2) | The surface pin of `Logex.Configuration` in `runtime_test.exs` | S's pin: `check/1`, `location/1`, `new!/1` | Rewritten once when T's checks become rows of `check/1`: a textual merge keeps both pins side by side, cleanly, and cannot pass |
| C13 (new, X1, X4) | Programs that hold `cal`, and block files on a `program` line | not in S | With M2-5 first: a writes walk keyed by each instance's type, and a loader kind check (§5, §8) |

---

## 2. Rules, numbered

Each rule names its source: decided where, IEC's, or this design's. It also names the
test that pins it (`configuration_test.exs` unless named) and its mutant in §7.2.
"Changed" marks a rule that differs from T1's; "Revised" one that this revision changed.

### 2.1 File kinds and the loader

- **R1** `Logex.compile_file/1` compiles only a path ending exactly in `.ld`. Anything
  else is a `:file` diagnostic and is not read. *(PLAN M2-2, PLAN.md:1322.)* Test:
  `logex_test.exs` "only a .ld file is a program's…". Mutants M1, M44, J13, N27.
- **R2** The loader takes only a path ending in `.lxcf`, and points a `.ld` path to
  `Logex.compile_file/1`. *(This design.)* M32.
- **R3** The loader resolves type `t` to `t.ld` in the configuration's directory, and
  compiles each type once, in the order of its first `program` line. *(org §4.4
  "Loading", org:469-475.)* J5.
- **R4** *Changed.* A type with no file is an unknown program type, at the `program` line
  that first names it, at stage `:configure`. It carries a did-you-mean among the `.ld`
  files beside the configuration, or lists them. A type file that exists but cannot be
  read is a `:file` diagnostic at that line. *(org §4.4 "Unknown names … with a
  did-you-mean"; JT1 D4.)* Test: "a type with no file is an unknown type…". M39, N12, N13.
- **R5** A type file's own diagnostics come after the configuration's, each with its
  file. That type's instances are not checked further (C6). X1, X2.
- **R6** A configuration's name is its basename less `.lxcf`, shaped like a program's
  name. A bad one is a `:file` diagnostic, and the source is still checked. X3.
- **R65** *New.* Both loaders classify a path before its extension, by one rule: an empty
  path (F11), a path ending in `/` (F10), and a dotfile, which is all extension, so
  `.lxcf` alone names no configuration (F12) and `.ld` alone no program (F9). *(One
  message that does not contradict itself; rf-T-correct-5.)* Tests: "a path that names
  no file, a directory or only an extension says which", in both test files. P5a–P5g.
- **R51** *New.* A message that cites a line of a type's file names that file, when the
  loader read it: `on line 8 of <dir>/motor.ld`. *(Milestone 2's done sentence, "names
  its file and line", PLAN; JT1 graft 1.)* Test: "the loader names a type's own file…".
  N21, N22.

### 2.2 Reading (`Text`, line and column)

- **R7** A line starts with `task`, `var_global` or `program`, or is a connection (a first
  word with a `.`). Anything else is an unknown configuration line, with a did-you-mean
  among the three. X4.
- **R8** A keyword that belongs on a line cannot start one, and the message names the
  line it belongs on. X5.
- **R9** `(`, `|` and `)` are refused at their token. M5.
- **R10** Keywords match in any case; names are case-sensitive. M31.
- **R11** A task's inputs come in IEC's order, `single`, `interval`, `priority`, each
  once. *(Ed 2 Annex B.1.7 `task_initialization`.)* M6, M7.
- **R12** The shapes of a global, program and connection line (§3.3): one mistake a line,
  the rest of the line skipped. J19, X6.
- **R13** *Revised.* A broken line still declares its name, and a broken connection still
  connects its var_input. A line broken by `(`, `|` or `)` too: its words up to the
  delimiter are read for what they name (rf-T-correct-2). M30, M35, J18, P2.
- **R55** *New.* A line ends at LF, CRLF or a lone CR and keeps its number, as the lexer
  gives it (B8). Test: "a line ends at LF, CRLF or a lone CR…" (JT1 G5). No mutant: the
  reader holds no line-ending logic of its own; the test guards against a later reader
  that splits on `"\n"`.

### 2.3 Names

- **R14** A task, global or instance name is not a configuration keyword (in any case)
  and has no `.`. *(org §4.8, decision 10; the `.` rule PLAN §5.)* M19, X7.
- **R66** *New.* A name refused under R14 is reported once: what names it later is not
  reported again, as for a broken line's name. A name declared twice, or a case twin, is
  not recovered, as on a `.ld` declaration line (`lib/logex/declarations.ex:190-194`).
  *(One mistake, one message; rf-T-correct-8; §13 Q-26.)* Test: "a name no line can
  declare is refused once…". P8.
- **R15** Tasks, globals and instances share one namespace. A name is declared once, and
  two names differing only in case are refused. *(§13 Q-5; S-synth CF-2 agrees.)* M18, J9.
- **R16** A program type's name is a name, not a configuration keyword. X8.
- **R52** *Changed (T1's C5 doc).* A broken line's name passes the same name checks, so a
  keyword in a name's place is refused there too. Once in, nothing that names it is
  reported again. Test: "a broken line's name passes the name checks too…" (JT1 D10). X17.
- **R53** *New.* No message advises declaring a keyword. An unknown reference that is a
  keyword is said to be one. Test: "no message advises declaring a keyword" (JT1 D5). N14.
- **R54** *New.* A case-only did-you-mean names what is case-sensitive: names, program
  types or members, never tags. Test: "a case-only did-you-mean says what is
  case-sensitive" (JT1 D8). N16, N17, N18.

### 2.4 Tasks (M2-3, M2-6)

- **R17** A task has `interval` or `single`. *(org §4.4 "Tasks".)* M15.
- **R18** *Revised.* An interval is 1 to 2147483647 ms. *(At least 1 decided in org
  §4.4; the upper bound is this design's.)* A task with `single` and `interval 0` is told
  to leave `interval` out (C6b), since IEC reads 0 as no periodic scheduling (org §4.4;
  rf-T-correct-6). M13, J16, P6.
- **R19** A task has a priority, 0 to 2147483647, 0 the highest. *(Mandatory by decision
  11; range §13 Q-9.)* M14, J17.
- **R20** A task's `single` names a bool global. *(org §4.4 "Events".)* M20.
- **R21** `with` names a declared task. X9.
- **R64** *New.* A dotted name after `with` is told that a task's name has no `.` (C49),
  with a did-you-mean among the tasks, never a global's or a member's reading. *(org
  §4.7; rf-T-correct-4.)* Test: "a dotted name after `with`…". P4.

### 2.5 Globals and locations (M2-2)

- **R22** An unlocated global's initial value fits its type. X10.
- **R23** An input point takes no initial value. *(org §4.4 "Input points".)* M28.
- **R24** An output point takes no initial value. *(org §4.4's line table gives none with
  `at`; S-synth CF-10b agrees.)* M42.
- **R25** *Changed.* A location is a device of one name part, `i` or `q`, then one
  integer field or more. Each is written one way: `i` or `q` lowercase, and no field with
  a leading zero. A location written another way is refused with its one spelling.
  *(Decision 6; org §4.5; §13 Q-8; S-synth CF-11, CF-11b.)* M16, N20, N26.
- **R26** One global a location. M17.
- **R56** *New.* A refused global (a name declared twice, or a keyword) has its location
  checked but does not take it. *(The house's "one mistake, one message",
  `lib/logex/declarations.ex:190-194`; JT1 D6.)* Test: "a refused global does not take
  its location". N15.

### 2.6 Program lines (M2-2)

- **R27** A program line's type is one of the types given, with a did-you-mean, or the
  list. X11.
- **R28** A configuration declares one `program` at least. *(IEC Ed 2 B.1.7, Ed 3 Annex A;
  res IEC-5; S-synth CF-27.)* M27.

### 2.7 Connections (M2-2)

- **R29** A connection names a declared instance. Lines come in any order, so a
  connection may come before its `program` line. *(The decided plant needs it; §11, T-synth's Q-4 withdrawn.)* J3.
- **R30** A connection names one member, never a deeper path. X12.
- **R31** Only a var_input or a var_output connects. A `var` is internal; a
  `var_external` reaches its global itself. *(org §4.4.)* X13, X14.
- **R32** A var_input has one source. *(This design.)* M12.
- **R33** A constant source fits its var_input's type. M29.
- **R34** A var_input reads any global of its type: an input point, an output point read
  back, or an unlocated global. *(org §4.4: the snapshot reads `k1` back.)* X15.
- **R35** A var_input's global agrees with it in type. *(org §4.4.)* M10a.
- **R36** A var_output drives globals, never a constant. J11.
- **R37** Nothing drives an input point by connection, and the message names the member's
  section. *(org §4.4.)* M9.
- **R38** A var_output's global agrees with it in type. M10b.
- **R39** One driver per sink. *(org §4.4 "One driver per sink", an error.)* M8.
- **R40** Every var_input is connected, cited at its instance's `program` line, the
  unconnected ones in declaration order. *(Decision 7.)* M11, M33.
- **R41** A dotted name whose first part is a declared instance, where a global is wanted,
  is refused as an instance's member: instances share a value only through a global.
  *(org §5, no program-to-program connection.)* J8.
- **R57** *Revised.* A location where a global is wanted (a connection's source or sink,
  a `single`) is named as a location. The message names the global at it, or says to
  declare one, in the location's one spelling (rf-T-correct-7). A location a global is
  declared at reads as that location first, even when its device is spelled like an
  instance (rf-T-correct-10). A location that begins a connection line is named as one
  too. *(org §4.7: "each wrong reading gets a diagnostic that names it"; org §5: raw
  addresses in connections are not adopted, org:1248; JT1 D1.)* Tests: "a location is
  written only after `at`…", "a location's advice is written in its one spelling…". N1,
  N2, P7, P10.
- **R58** A dotted name, where a global is wanted, whose first part is not an instance
  says what that part is, or that there is no such instance, with a did-you-mean among
  the instances. Where a task is wanted, R64 applies instead. *(org §4.7; JT1 D1's "no
  instance" half.)* N3.
- **R59** *New.* A connection after a broken one to the same var_input is not reported as
  a second source, but its own source is checked. *(JT1 D10.)* N19.

### 2.8 `var_external` (M2-4)

- **R42** In `.ld`, `var_external` is a section: a bool or a dint, no initial value, no
  instance. *(Ed 2 Table 16a; Ed 2 §2.4.3 p.43; org §6.1.)* `validation_test.exs`. M2, M3,
  X16.
- **R43** A `var_external`'s name is not a configuration keyword. *(org §4.8, "legal in
  both kinds", org:747.)* M4.
- **R44** Each instantiated type's `var_external` has a global of its name and type. It
  is checked once a type, at its first instance's `program` line. *(Ed 2 §2.4.3; the
  citing place §13 Q-6.)* M21, M43, J4.
- **R45** Nothing writes an input point through a `var_external`. *(org §4.4.)* M22.
- **R46** A program alone keeps its `var_external` as its own tag, starting at 0, which
  the host cannot set. *(§13 Q-10, option G2.)* `validation_test.exs`.
- **R67** *New.* In a `.ld` body, an operand shaped like a location (a device, `i` or `q`
  in any case, then whole-number fields) whose first part is undeclared is reported as a
  location (V4), once a device. *(org §4.7; TF-11.)* `validation_test.exs`, "a location
  in a rung is named as one…". P11.

### 2.9 Warnings (on the configuration's `warnings`; §13 Q-12)

- **W1** A global nothing uses. A use is a connection's source or sink, a task's
  `single`, or a `var_external` of an instantiated type. M25, J2, J20.
- **W2** An output point that something reads but nothing drives. An output point
  nothing uses gets W1 only. M37, J14.
- **W3** A task that runs no instance. M38.
- **W4** Two instances write one global through `var_external`. *(org §4.4, "a
  warning".)* M23.
- **W5** An instance writes, through `var_external`, a global that a connection drives.
  *(This design, §13 Q-11.)* M36.
- **W6** *Changed.* A `ton` in a program that an event task runs, whether the task has
  `single` alone or `single` and `interval`. *(org §4.6 "Caveats", org:649-652; JT1 G1;
  §11, T-synth's Q-13 withdrawn.)* M24, N23.

### 2.10 Order, data path, growth

- **R47** Diagnostics come in line order, those with no line last; warnings in line
  order. Every check's diagnostic is at stage `:configure`. M34, J1.
- **R48** *Revised.* An entry no line could say raises `ArgumentError` from `check/3`,
  `new!/3`, `print/1` and `entries!/1` alike (§3.1 H8, H9). This includes an improper
  list (rf-T-correct-1), lines that are not all nil or strictly rising, a connection's
  instance with a `.`, and a keyword in a place the reader takes it for itself
  (rf-T-correct-3). A member the text can say is taken. *(org §4.9, "the data API refuses
  what the text cannot say", org:777; JT1 D2.)* M40, N4, N5, N6, N7, P1, P3a–P3d.
- **R49** *Revised.* Every configuration the constructor accepts prints to text that
  reads back to it. With lines, it is exactly the same entries, gaps included. With no
  lines, the entries are numbered from line 1. Tested on 200 seeded configurations, each
  both ways. Every entry list `entries!/1` takes reads back too, keywords in every name
  place included: 3,000 seeded lists (rf-T-correct-3). *(JT1 graft 4.)* M41, N8, P3a–P3d.
- **R50** Checking a configuration is linear in its instances: 4x the instances cost under
  5.1x the reductions. M26.
- **R60** *New.* Nothing but `ArgumentError` escapes `Text.read/1`, `print/1`,
  `keyword?/1`, `entries!/1`, `Configuration.check/3`, `new!/3`, `compile/3` (each
  argument) or `compile_file/1`. Tested with 3,000 seeded junk values through each, improper
  lists among them since this revision (rf-T-correct-1).
  *(CLAUDE.md, Conventions; JT1 D3 and graft 2.)* N9, N10, N11.
- **R61** *New.* `new!/3` refuses a line on an entry from Elixir, and raises every problem
  in one `ArgumentError`. Warnings do not raise. *(org §4.4 "Loading"; S-synth NW-3 and
  §3.1.)* N24, N25, N28.
- **R68** *New.* A `%Logex.FbType{}` given as a program raises H15, naming it a function
  block type, under any key. *(One mistake, one message; X13; §13 Q-25.)* Test: "host
  mistakes". P13.

---

## 3. Every host-mistake message and diagnostic, exact

`<x>` is a placeholder. Every other character is the message. A reader diagnostic carries
a column; a check's does not. Every one below is pinned by a test in the spike, as a whole
list from source or as an exact `assert_raise` message.

### 3.1 Host mistakes (`ArgumentError`)

| # | Where | Message |
|---|---|---|
| H1 | `compile/3`, `check/3`, `new!/3` | `a configuration's name is a string, got: <inspect>` |
| H2 | same | ``"<name>" cannot name a configuration: a name is a letter or `_`, then letters, digits or `_` `` |
| H3 | `compile/3` | `Logex.Configuration.compile/3 takes source text as a binary, got: <inspect>` |
| H4 | `compile/3`, `check/3`, `new!/3` | `programs must be a map of type names to %Logex.Program{}, as in %{"motor" => motor}, got: <inspect>` |
| H5 | same | ``the program given as `<key>` is named <inspect name>: a type is given under its own name`` |
| H6 | same | `programs must be a map of type names to %Logex.Program{}, got: <inspect %{key => value}>` |
| H7 | `Configuration.compile_file/1` | `Logex.Configuration.compile_file/1 takes a path as a binary, got: <inspect>` |
| H8 | `check/3`, `new!/3`, `print/1`, `entries!/1` | `entries must be a list, got: <inspect>`, an improper list included (revised) |
| H9 | same | `not an entry a configuration file can say: <rule>, got: <inspect entry>`. The rule is one of: `an entry is {kind, line, fields}, its line nil or positive`; ``an entry is a :task, :global, :program or :connection with that kind's fields, a global's type :bool or :dint``; ``a connection is `to` {:global, name} or {:constant, n}``; `a name lexes as one name token`; ``a connection's instance has no `.`: its first `.` begins the member``; `a number is an integer, 0 or more: a negative one does not lex yet (PLAN.md §5)`; `lines are nil for entries built in Elixir, or rise from entry to entry, one entry a line, and this one comes after line <n>`; `lines are nil for entries built in Elixir, or rise from entry to entry, one entry a line, and no line is nil beside one that is not`; and, new, ``<place> is not <words>, in any case: a line reads that word as its keyword``, where the place and words are ``a task's name`` or ``a task's `single` `` with `` `interval`, `priority` or `single` ``, ``a global's name`` with `` `at`, `bool` or `dint` ``, and ``a program's type`` with `` `with` `` |
| H10 | `Tag.new!/4` | as V1, V2 and V3 below |
| H11 | `Text.read/1` | `Logex.Configuration.Text.read/1 takes source text as a binary, got: <inspect>` |
| H12 | `Text.keyword?/1` | `Logex.Configuration.Text.keyword?/1 takes a word as a string, got: <inspect>` |
| H13 | `new!/3` | `an entry built in Elixir has no line: a line is where a configuration file declares an entry, got: <inspect entry>` |
| H14 | `new!/3` | every diagnostic `check/3` gives, each formatted by `Logex.Diagnostic.format/1`, joined by `"\n"` |
| H15 | `compile/3`, `check/3`, `new!/3` | ``the program given as `<key>` is `<name>`, a function block type, which runs inside a program: a program instance is of a %Logex.Program{}`` (new; S-rev BT-2's words; §13 Q-25) |

H9 covers a `{:declared, …}` placeholder given from Elixir or to `print/1`. A
`%Logex.Program{}` built or edited by hand is outside the contract, as it is for
`Logex.Runtime` (`lib/logex/runtime.ex:42-43`): the checks assume a program from
`Logex.compile/2`.

### 3.2 `:file` diagnostics, and the loader's unknown type

| # | Where | Message |
|---|---|---|
| F1 | loader, a `.ld` path | ``` `<base>` is a program's file, not a configuration's: compile it with Logex.compile_file/1, and name its type on a `program` line``` |
| F2 | loader, any other | ``` `<base>` is not a configuration file: a configuration's file ends in `.lxcf`, as in `plant.lxcf` ``` |
| F3 | loader | `cannot be read: <reason>` |
| F4 | loader | ``"<name>" cannot name a configuration: a name is a letter or `_`, then letters, digits or `_` (rename the file)`` |
| F5 | loader, at the line; a type file that exists but cannot be read | ``no program type `<type>`: <path> cannot be read: <reason>`` |
| F5b | loader, at the line, stage `:configure`; no file of that name | ``unknown program type `<t>`: there is no `<t>.ld` beside this configuration`` then one of: `` — did you mean `<u>`?`` (and `` (program types are case-sensitive)`` for a case-only match); ``: the program files beside it are `a.ld` and `b.ld` ``; `, nor any program file` |
| F6 | `Logex.compile_file/1` | ``` `<base>` is a configuration's file, not a program's: load it with Logex.Configuration.compile_file/1``` |
| F7 | `Logex.compile_file/1` | ``` `<base>` has no extension: a program's file ends in `.ld`, as in `<base>.ld` ``` |
| F8 | `Logex.compile_file/1` | ``` `<base>` is not a program's file: its extension is `<ext>`, and a program's file ends in `.ld` ``` (changed, JT1 D9) |
| F9 | `Logex.compile_file/1`, a bare `.ld` | ``` `.ld` names no program: a program's file is its name, then `.ld`, as in `motor.ld` ``` (new, JT1 D9) |
| F10 | both loaders, a path ending in `/` | ``` `<path>` ends in `/`, so it names a directory: a program's file ends in `.ld`, as in `motor.ld` ``` / ``…: a configuration's file ends in `.lxcf`, as in `plant.lxcf` `` (new) |
| F11 | both loaders, an empty path | ``the path is empty: a program's file ends in `.ld`, as in `motor.ld` `` / ``…: a configuration's file ends in `.lxcf`, as in `plant.lxcf` `` (new) |
| F12 | loader, a bare `.lxcf` | ``` `.lxcf` names no configuration: a configuration's file is its name, then `.lxcf`, as in `plant.lxcf` ``` (new) |

A bare `.lxcf` given to `Logex.compile_file/1` gets F6, and a bare `.ld` given to the
loader gets F1: a dotfile is all extension (rf-T-correct-5).

### 3.3 Reading (`:configure`, with a column; `:lex` from the lexer)

Unchanged from T1 §7.3, T1–T34. Each is pinned in the spike's reader tests:

| # | Case | Message |
|---|---|---|
| T1 | first word near a line keyword | ``unknown configuration line `<w>` — did you mean `<kw>`?`` |
| T2 | any other first word, or a number | ``unknown configuration line `<w>`: a line starts with `task`, `var_global` or `program`, or is a connection, as in `m1.start pb_start_1` `` |
| T3 | `single`, `interval`, `priority` first | ``a line cannot start with `<kw>`: it goes on a `task` line, as in `task fast interval 10 priority 1` `` |
| T4 | `with` first | ``a line cannot start with `with`: it goes on a `program` line, as in `program m1 motor with fast` `` |
| T5 | `at`, `bool`, `dint` first | ``a line cannot start with `<kw>`: it goes on a `var_global` line, as in `var_global k1 bool at panel.q.0` `` |
| T6 | `(`, `\|`, `)` | ``a configuration line cannot hold `<(|)>` `` |
| T7 | `task` alone | ``` `task` needs a name, as in `task fast interval 10 priority 1` ``` |
| T8 | a number for a name | ``expected a task's name after `task`, found `<n>` `` |
| T9 | an input for a name | ``` `task` needs a name before `<input>`, as in `task fast interval 10 priority 1` ``` (for `single`, the example is `task trip single estop priority 0`) |
| T10 | a word not an input | ``unexpected `<w>` on the line of task `<t>`: a task takes `single`, `interval` and `priority` `` |
| T11 | twice | ``` `<input>` is given twice on the line of task `<t>` ``` |
| T12 | out of order | ``` `<input>` goes before `<later>`, as in `task fast interval 10 priority 1` ``` (for `single`, its example) |
| T13 | `single` | ``` `single` needs a bool global, as in `single estop` ```, then ``, found `<w>` `` when a word was found |
| T14 | `interval` | ``` `interval` takes a number of milliseconds, as in `interval 10` ``` + found |
| T15 | `priority` | ``` `priority` takes a number, 0 the highest, as in `priority 1` ``` + found |
| T16 | `var_global` alone | ``` `var_global` needs a name and a type, as in `var_global estop bool` ``` |
| T17 | a number for a name | ``expected a global's name after `var_global`, found `<n>` `` |
| T18 | a type word or `at` for a name | ``` `var_global` needs a name before `<w>`, as in `var_global estop bool` ``` |
| T19 | no type | ``` `<g>` needs a type: `var_global <g> bool` or `var_global <g> dint` ``` |
| T20 | a number for a type | ``` `<g>` needs a type before its initial value `<n>` ``` |
| T21 | `at` for a type | ``` `<g>` needs a type before `at`, as in `var_global <g> bool at panel.q.0` ``` |
| T22 | an unknown type | ``unknown type `<w>`: a global is a `bool` or a `dint` `` + `` — did you mean `bool`?`` (or `dint`) when one is near |
| T23 | a function block type | ``` `<g>` cannot be a `<fb>`: a global is a `bool` or a `dint`, and a <fb> is declared inside a program, as in `var <g> <fb>` ``` |
| T24 | `at` without a location | ``` `at` needs a location, as in `at panel.i.0` ``` + found |
| T25 | anything after | ``unexpected `<w>` after the declaration of `<g>` `` |
| T26 | `program` alone | ``` `program` needs an instance name and a program type, as in `program m1 motor` ``` |
| T27 | a number for a name | ``expected an instance name after `program`, found `<n>` `` |
| T28 | no type | ``` `program <i>` needs a program type, as in `program <i> motor` ``` |
| T29 | a number for a type | ``expected a program type after `program <i>`, found `<n>` `` |
| T30 | `with` for a type | ``` `program <i>` needs a program type before `with`, as in `program <i> motor with fast` ``` |
| T31 | `with` without a task | ``` `with` needs a task, as in `program <i> <type> with fast` ``` + found |
| T32 | anything after | ``unexpected `<w>` after `program <i> <type>` `` or ``… after `program <i> <type> with <t>` `` |
| T33 | a connection alone | ``` `<path>` needs a global or a constant to connect, as in `<path> pb_start_1` ``` |
| T34 | anything after | ``unexpected `<w>` after `<path> <to>` `` |

The suggestion in T1 and T22 is `Declarations.suggest/4`'s. Keywords match in any case, so
no case-only suggestion arises there.

### 3.4 The checks (`:configure`, line only, nil from Elixir)

| # | Rule | Message |
|---|---|---|
| C1 | R14 | ``` `<w>` is a keyword and cannot name a task``` / `a global` / `an instance` |
| C2 | R14 | ``` `<w>` cannot name <a kind>: `.` is kept for a path, as in `m1.start`, and a location, as in `panel.i.0` ``` |
| C3 | R15 | ``` `<n>` is declared twice: first on line <l>, as <a kind>``` (no line: ``: the first is <a kind>``) |
| C4 | R15 | ``` `<n>` and `<twin>` (line <l>) differ only in case: names are case-sensitive, so these would be two (`<twin>` is <a kind>)``` |
| C5 | R17 | ``task `<t>` needs an interval, as in `task <t> interval 10 priority 1`, or a trigger, as in `task <t> single estop priority 0` `` |
| C6 | R18 | ``the interval of `<t>` is 0: an interval is at least 1 ms, and an instance that runs every cycle is declared without `with` `` |
| C6b | R18 | ``the interval of `<t>` is 0: an interval is at least 1 ms, and a task that runs only on the events of its `single` is declared without `interval`, as in `task <t> single <g> priority <p>` `` (new; `<p>` the task's priority, or 0) |
| C7 | R18 | ``the interval of `<t>` is `<n>` ms: an interval is 1 to 2147483647 ms`` |
| C8 | R19 | ``task `<t>` needs a priority, as in `task <t> interval 10 priority 1`: 0 is the highest`` |
| C9 | R19 | ``the priority of `<t>` is `<n>`: a priority is 0 to 2147483647, and 0 is the highest`` |
| C10 | R20 | ``` `<g>` is a dint (line <l>): a task's `single` is a bool global``` |
| C11 | R22 | ``` `<g>` is a bool: its initial value must be 0 or 1, found `<n>` ``` |
| C12 | R22 | ``` `<g>` is a dint: `<n>` does not fit in 32 bits``` |
| C13 | R23 | ``` `<g>` is an input point: its value comes from the input image, so it takes no initial value``` |
| C14 | R24 | ``` `<g>` is an output point: it takes no initial value, and is 0 until its driver writes it``` |
| C15 | R25 | ``` `<loc>` is not a location: a location is a device, `i` or `q`, and an address, as in `panel.i.0` ``` |
| C16 | R25 | ``` `<loc>` is not a location as written: a location's `i` or `q` is lowercase and its address has no leading zero, so it is written `<one spelling>` ``` (changed) |
| C17 | R26 | ``` `<g>` is at `<loc>`, where `<other>` already is (line <l>): a location holds one global``` |
| C18 | R16 | ``` `<type>` is a keyword and cannot name a program type``` |
| C19 | R16 | ``` `<type>` cannot name a program type: a type is named by its file, `motor.ld` for `motor`, and a name is a letter or `_`, then letters, digits or `_` ``` |
| C20 | R27 | ``unknown program type `<type>` — did you mean `<t>`?`` (+ `` (program types are case-sensitive)`` for a case-only match) / ``…: the types given are `a` and `b` `` / ``…: no program types were given`` |
| C21 | R20, R21, R29, R35 | ``no <task\|global\|instance> `<n>` — did you mean `<m>`?`` when one is near, + `` (names are case-sensitive)`` for a case-only match (changed: was "tags") |
| C22 | R35, R20 | ``no global `<n>`: declare it, as in `var_global <n> bool` `` |
| C23 | R21 | ``no task `<n>`: declare it with a `task` line, as in `task <n> interval 10 priority 1` `` |
| C24 | R29 | ``no instance `<n>`: declare it, as in `program <n> motor` `` |
| C25 | any reference | ``` `<n>` is <a kind> (line <l>), not <a wanted kind>``` |
| C26 | R41 | ``` `<i.m>` is an instance's member: instances share a value only through a global, which one drives and the other reads``` |
| C27 | R30 | ``` `<i>.<path>` goes too deep: a connection names an instance's var_input or var_output, as in `<i>.start` ``` |
| C28 | R30 | ``` `<i>` is a `<type>`, which declares no `<m>` ``` + did-you-mean among its var_inputs and var_outputs (+ `` (members are case-sensitive)`` for a case-only match) |
| C29 | R31 | ``` `<i>.<m>` is internal to `<type>` (declared `var`): only a var_input or var_output connects``` |
| C30 | R31 | ``` `<i>.<m>` is a var_external of `<type>`, which reaches the global `<m>` itself: only a var_input or var_output connects``` |
| C31 | R32 | ``` `<i>.<m>` is already connected, to `<to>` (line <l>): a var_input has one source``` |
| C32 | R33 | ``` `<i>.<m>` is a bool: only 0 or 1 fit, found `<n>` ``` / ``` `<i>.<m>` is a dint: `<n>` does not fit in 32 bits``` |
| C33 | R35, R38 | ``` `<i>.<m>` is a <t>, but `<g>` is a <t'> (line <l>)``` |
| C34 | R36 | ``` `<i>.<m>` is a var_output, which drives a global: it cannot drive the constant `<n>` ``` |
| C35 | R37 | ``` `<g>` is an input point (line <l>): `<i>.<m>`, a var_output, cannot drive it``` |
| C36 | R39 | ``` `<g>` is already driven by `<i>.<m>` (line <l>)``` |
| C37 | R40 | ``` `<i>` leaves its var_input `<m>` unconnected: connect it to a global, a point or a constant, as in `<i>.<m> 0` ```; plural: ``` `<i>` leaves its var_inputs `a`, `b` and `c` unconnected: connect each to a global, a point or a constant, as in `<i>.a 0` ``` |
| C38 | R44 | ``` `<type>` declares `var_external <n> <t>`<where>, but this configuration declares no `var_global <n>` ``` + did-you-mean among globals |
| C39 | R44 | ``` `<type>` declares `var_external <n> <t>`<where>, but `<n>` is a <t'> (line <l'>)``` |
| C40 | R44 | ``` `<type>` declares `var_external <n> <t>`<where>, but `<n>` is a task (line <l'>), not a global``` |
| C41 | R45 | ``` `<type>` writes its `var_external <n>`<where>, but `<n>` is an input point (line <l'>): nothing drives an input point``` |
| C42 | R28 | ``this configuration declares no `program`: it would run nothing`` (line nil) |
| C43 | R53 | ``no <task\|global\|instance> `<n>`: `<n>` is a keyword of a configuration file, and nothing in one is named so`` (new) |
| C44 | R57 | ``` `<loc>` is a location, written only after `at` on a `var_global` line: name the global at it, `<g>` (line <l>)``` (new) |
| C45 | R57 | ``` `<loc>` is a location, written only after `at` on a `var_global` line: declare a global at it, as in `var_global point bool at <one spelling>`, and name that``` (revised: the example in the one spelling) |
| C46 | R57 | ``` `<loc>` is a location, written only after `at` on a `var_global` line: a connection begins with an instance's var_input or var_output, as in `m1.start` ``` (new) |
| C47 | R58 | ``` `<x.y>` names a member of `<x>`, but `<x>` is <a kind> (line <l>), not an instance``` (new) |
| C48 | R58 | ``` `<x.y>` names a member of an instance, and there is no instance `<x>` ``` + did-you-mean among instances (new) |
| C49 | R64 | ``no task `<x.y>`: a task's name has no `.`, which is kept for a path and a location`` + did-you-mean among the tasks (new) |

`<where>` in C38–C41 (and W6) is `` on line <l> of <path>`` when the loader read the type
from a file (R51), `` on its line <l>`` for a type given to `compile/3`, and empty for a
tag declared from Elixir. "(line <l>)" is left out for an entry with no line.

### 3.5 Warnings (`severity: :warning`, `stage: :configure`, on the configuration)

| # | Message, at the line named |
|---|---|
| W1 | ``` `<g>` is declared but nothing uses it``` (the global's line) |
| W2 | ``` `<g>` is an output point, but nothing drives it: it stays at 0``` (the global's line) |
| W3 | ``task `<t>` runs no instance`` (the task's line) |
| W4 | ``` `<i2>` writes `<g>` through its `var_external`, as `<i1>` does (line <l>): the later of the two in a cycle wins``` (each later writer's `program` line) |
| W5 | ``` `<i>` writes `<g>` through its `var_external`, and `<i'>.<m>` drives it (line <l>): the later of the two in a cycle wins``` (each writer's `program` line) |
| W6a | ``` `<i>` runs only on the events of `<t>`, and `<type>` runs `ton <timer>`<where>: a timer that is timing counts the time between events too``` (the instance's line; a task with `single` alone) |
| W6b | ``` `<i>` runs on the events of `<t>`, and on its interval only while `<g>` is 0, and `<type>` runs `ton <timer>`<where>: a timer that is timing counts the time `<g>` holds its interval off too``` (new; a task with `single` and `interval`) |

### 3.6 `.ld` (`:validate`), M2-4

| # | Message |
|---|---|
| V1 | ``` `<n>` is a var_external: its value is the configuration's global of that name, so it takes no initial value``` |
| V2 | ``` `<n>` is a <fb>: an instance is the program's own, declared with `var`, as in `var <n> <fb>`, not with `var_external` ``` (the existing message, now for this section too) |
| V3 | ``` `<n>` cannot name a var_external: it is declared again as a `var_global`, and `<n>` is a keyword of a configuration file``` |
| V4 | ``` `<loc>` is a location, written only after `at` on a configuration's `var_global` line: a program reaches a point through a var_input or var_output that the configuration connects to the global at it``` (new, R67) |

The existing shape messages take the section word, as T1 §7.6 lists. A lone instance's
`var_external` sent as an input keeps the runtime's message: ``input `estop` is a
var_external (declared on line 1), not a var_input: only a var_input is set from outside``
(`lib/logex/runtime.ex:305-308`).

### 3.7 The receipt's seven, against org §4.4

The broken source is the test's `@broken`: 19 lines, one mistake on each of lines 7, 9,
11, 12, 14, 15 and 16, against the §4.2 motor. The spike gives exactly these, pinned
(§6 has the probe output):

```
line 7, column 1: unknown configuration line `progam` — did you mean `program`?
line 9: no task `medium`: declare it with a `task` line, as in `task medium interval 10 priority 1`
line 11: `m1` is a `motor`, which declares no `strat` — did you mean `start`?
line 12: `pb` is an input point (line 2): `m1.motor`, a var_output, cannot drive it
line 14: `k` is already driven by `m1.run_lamp` (line 13)
line 15: `m1.fault` is internal to `motor` (declared `var`): only a var_input or var_output connects
line 16: `m1.speed_sp` is a dint, but `k` is a bool (line 3)
```

The differences from org:452-460 are T1's (T1 §7.8):
- the house's em-dash did-you-mean;
- "declare it first" dropped, because lines come in any order (§11);
- a did-you-mean where a name is near;
- the member's section named, as org §4.4 asks of a wrong direction.

S-synth's `check/1` words four of these differently (S-synth §3.2). §13 Q-20 decides which
words land.

---

## 4. The rule across an online edit for each new piece of state

CLAUDE.md's rule ("New state in an instance") applies to a field of `%Logex.Instance{}`,
a member of a block type, or an M2 item's piece of state. This track adds nothing to
`%Logex.Instance{}` or `%Logex.Scan{}`. Its state lives in S's opaque `%Logex.Runtime{}`
(S-synth §1.2, §4), so each piece gets a value at `start/1`, a rule for a cycle, for
`restart/2` and for OE-2's switch, and the edit's exceptions are listed. Rows marked *rec.*
are this design's recommendations. Where S-synth already states a row, this table agrees
with it unless the row says otherwise.

| State (item) | At `start/1` | Each cycle | `restart/2` (cold) | OE-2: added | OE-2: kept | OE-2: removed |
|---|---|---|---|---|---|---|
| A global's value (M2-2) | its initial value, or 0 | written by copy-out and by `var_external` writes | back to its initial value or 0 (S-synth RS-5) | its initial value, the one rule (`Program.initial_env/1`'s rule, carried over) | kept. *rec.* a changed initial value is reported, as decision 29 reports a tag's; decision 29 covers a program's tags only, so this extends it (§13 Q-28; S-rev Q-34) | kept unused until assemble, pruned there |
| A global's `at`, type (M2-2) | — | — | — | refused while running (located I/O, org §4.9) | a change refused at accept | refused |
| The input image (M2-2) | every input point 0 | merged at step 2 | kept, as `restart/3` keeps var_inputs (S-synth RS-3) | — (no point is added while running) | kept | — |
| An output point's value (M2-2) | 0 | step 5 | 0 | refused | held and reported `{:held, point, value}` when no logic drives it any more (org §4.9; decision 20) | refused |
| A connection (M2-2) | no state | — | — | allowed (org §4.9); decision 7 still applies to the candidate | — | allowed, unless it leaves a var_input unconnected |
| An instance (M2-2) | `Runtime.instance/1` (F14) | — | `restart/3` | `instance/1`, so its first scan is a first scan | moved by OE-1's per-instance switch, one plan per type (F5) | pruned at assemble |
| A task's `next_due` (M2-3) | 0, anchored at start | whole intervals (S-synth CY-5) | the kept `now` (S-synth RS-2) | refused (decision 19) | interval changed: *rec.* `min(next_due, now + new interval)`, which S-rev now recommends too; priority changed: nothing (§13 Q-16; S-rev Q-23) | refused |
| A task's overlap count (M2-3) | 0 | `+ missed` | 0 (S-synth RS-1) | refused | kept | refused |
| An instance's task (M2-3) | — | — | — | — | a change refused (decision 19) | — |
| A `var_external` (M2-4) | none in a runtime's env; a lone instance's tag starts at 0 | merged in before its instance's scan and split off after (§5) | none held | binds to its global by name | — | — |
| A section change to or from `var_external` (M2-4) | — | — | — | — | OE-1, a lone instance: the value is kept (decision 25). OE-2: *rec.* the configuration's switch merges globals in by the running program's externals before the per-instance switch, and splits them off by the candidate's after, so `Logex.Edit` sees a full env and the value kept is the one the instance read last (§13 Q-17) | — |
| An event task's last sample (M2-6) | 0, so a trigger already 1 fires in cycle 1 (decision 11) | sampled at step 3 | back to 0, so a trigger already 1 fires, as IEC's R_TRIG after a cold restart (org §4.6) | refused (decision 19) | **kept** (the listed exception), so a switch fires no event | refused |
| An event task's `single` source, or `interval` added to or removed from it (M2-6) | — | — | — | — | *rec.* refused, as a task change decision 19 does not allow (§13 Q-15) | — |

The trigger's rule has no home in `Program.initial_env/1`'s doc (inv C21). It belongs in
`Logex.Runtime`'s `start/1` doc and in org §4.9's "One rule for new state" list
(org:1106). The sentence at `lib/logex/program.ex:41-42` ("M2-6 will add an event task's
trigger") moves there in M2-6's last commit.

---

## 5. What each later item and OE-2 add

- **M2-3 on M2-2.** The reader already reads `task` lines and `with`; M2-3 reserves the
  four words and turns them on (§8). S's `Task` and `Instance.task` already exist
  (S-synth §5). The acceptance counts, 100 and 20, run on S's scheduler.
- **M2-4 on M2-2.**
  - B5's one IR walk (rdy §4.1) replaces the spike's private `writes/1` and `timers/1`.
    It also replaces `Logex.Warnings`' and `Logex.Edit`'s walks, which raise `KeyError` on
    a lowered `cal` (inv §3, measured). M2-4 needs a public "which tags a program writes",
    a function over the IR rather than a field on `%Logex.Program{}` (T1-Q13, kept).
  - The scan step merges each `var_external`'s global into the instance's env before
    `call/4` and splits it off after, so between scans the only copy is in
    `%Logex.Runtime{}.globals` (§13 Q-10, option G2). `call/4` is unchanged and stays the
    scheduler's step. `get/2` reads `m1.estop` as the global (S-synth §5 agrees).
- **M2-5 (track F), landing before M2-2 (§13 Q-23).** Composed with F's spike, T-synth's
  suite stays green (558 tests) but `Configuration.compile/3` and `compile_file/1` raise
  exceptions other than `ArgumentError` at the seam (X1, reproduced by the refuter). T's
  code meets M2-5 in four places, each owed in the commit named in §8:
  - **Loading (commits 2 and 5).** A block file is a `.ld` whose first line is
    `function_block <name>`. There is one loader, F's `Logex.compile_file/1` with its
    `load/3`: commit 2 puts the `.ld` gate in front of `load/3`, and commit 5 resolves
    each program type through `load/3` with one memo per configuration. A block used by
    two program types is then read and compiled once, not four times and twice (X4).
  - **A `program` line naming a block file (commit 5).** The loader checks a file's kind
    and gives a located diagnostic, never puts a `%Logex.FbType{}` into `programs`. In
    F's words at every entry point (§13 Q-25, S-rev Q-39): ``` `seal` is a function block
    type, which runs inside a program through `cal`…```. T-synth's spike crashed here with
    `FunctionClauseError` in `instructions/1`.
  - **What a program writes, and its timers (commit 12, before commit 14).** The private
    `writes/1` zips each instruction's signature from `Compiler.instructions/0`, and F's
    `cal` has the marker `:block` there, so a program holding a `cal` raised
    `Protocol.UndefinedError`. B5's one IR walk replaces it, keyed by each instance's own
    type: a `cal`'s output operands count as writes for R45, W4 and W5, and a `ton` inside
    a block counts for W6. With the crash guarded and no more, W6 silently misses a block's
    `ton` (X1's refinement), so the walk must reach block bodies.
  - **`var_external` in a block file (commit 13).** Refused with a located `:validate`
    diagnostic, and a test that fails when it is reverted, unconditionally once M2-5 has
    landed (§13 Q-18). Composed with F, a block declaring one raised `FunctionClauseError`
    in `FbType.role/1` (X3). F recommends the same.
- **M2-6 on M2-3.** `Task` gains `single`, and `interval` may then be nil. The reader
  already reads `single`; the item reserves it and turns it on. The run-time rules are
  below.
- **OE-2.**
  - The candidate is a configuration's source and its types, compiled by the same loader.
  - Accept compares by name:
    - tasks: interval and priority changes allowed; `single` changes, and adding or
      removing a task, refused;
    - globals: `at` and type changes refused;
    - instances: type and task changes refused;
    - connections: allowed.
  - Its diagnostics are `:edit`, cited in the configuration file.
  - Fix F15 (a `file` on `%Logex.Program{}`) is still owed for `Logex.Edit`'s candidate
    from a file. Its owner is §13 Q-24 (S-rev Q-38): under the recommended order, M2-5,
    which meets it first. Two citation conventions stand side by side and are stated
    together: F's R68 stamps a block file's diagnostics with that file in the `file`
    field; T's R51 keeps a configuration diagnostic in the configuration's file and names a
    type's file and line in its text, `on line 8 of <dir>/motor.ld`.
- **Later targets.**
  - `var_config` (org §5): a fifth line kind, `var_config m2.speed_sp 900`, and an
    eleventh keyword, refused on a var_input (org §4.4).
  - The `%` fallback (decision 6): a `%` lexeme valid only after `at`. It changes the
    lexer and the golden record, which the `panel.q.0` form does not.
  - Forcing: a force map applied between steps 2 and 5 of `cycle/3` (org §5). Nothing
    here blocks it.

### 5.1 Run-time semantics this track owes S's scheduler (not spiked)

- **Points.**
  - The input image is keyed by input-point name, persistent, merged each cycle, and
    every point is 0 at `start/1` (S-synth CY-2).
  - The output image is every output point after every due scan (S-synth CY-9).
  - S-synth's input-image messages (S-synth §3.3) supersede T1 §7.7's proposal; they
    agree in substance.
- **Periodic tasks.** As org §4.6 and S-synth §2.4. A task with no instance keeps its
  schedule and runs nothing (S-synth CY-10), and W3 warns of it.
- **One copy of each global (M2-4, G2).**
  - Before each scan of an instance whose type declares `var_external`s, the scheduler
    puts each one's global value into the instance's env.
  - It calls `call/4`, reads each back from the returned env into the global, and drops
    them from the env.
  - Visibility therefore follows execution order (D1.8), and `call/4` stays the step
    (D1.13).
- **Event tasks (M2-6).**
  - Each `single` is sampled once a cycle, after the input merge and before due tasks
    are worked out. A task is due on an edge: last sample 0, this sample 1.
  - The last sample starts at 0, so a trigger already 1 in cycle 1 fires (decision 11).
  - An event task's due time is the cycle's `now`, for the earlier-due-time tie-break
    (*rec.*; §13 Q-22, with its owed test).
  - A task with `single` alone never overlaps.
- **`single` with `interval`** (*rec.*, §13 Q-14):
  - one run a cycle at most;
  - due on an edge, or when this sample is 0 and its periodic `next_due` has come;
  - the phase stays anchored at start;
  - while the sample is 1, a periodic due time that comes is skipped, `next_due` moves
    past `now`, and no overlap is counted;
  - when the sample falls to 0, the task is next due at its next phase point;
  - an edge run does not move the phase.
  - There is no free-software precedent: MatIEC ignores INTERVAL when SINGLE is given
    (res MAT-2).
- **`next_due_in/1`.** It answers for periodic tasks. An event-only task is not
  predictable, so a runner that reads inputs cycles on any input change (S-synth NX-1).

---

## 6. Spike receipts

**Gate,** three times on the final spike, each command judged by its exit code
(`T-rev-probe/gate.sh`; `gate-1.log` to `gate-3.log`, full test output `test-1.log` to
`test-3.log`):

| Run | `mix format --check-formatted` | `mix compile --force --warnings-as-errors` | `MIX_ENV=test mix compile --force --warnings-as-errors` | `mix test --warnings-as-errors` |
|---|---|---|---|---|
| 1 | 0 | 0 | 0 | 0, `Result: 508 passed (6 doctests, 502 tests)` |
| 2 | 0 | 0 | 0 | 0, `Result: 508 passed (6 doctests, 502 tests)` |
| 3 | 0 | 0 | 0 | 0, `Result: 508 passed (6 doctests, 502 tests)` |

At `47319f7` the suite is 430 tests (6 doctests), and T-synth's spike 499. This revision
adds 9 tests:
- 7 in `configuration_test.exs` (70 now): the delimiter line's placeholders, C6b, a
  dotted `with`, one spelling and a declared location first, a refused name reported
  once, the loader's path kinds, and the read-back property over every entry
  `entries!/1` takes;
- 1 in `validation_test.exs`, a location in a rung;
- 1 in `logex_test.exs`, `Logex.compile_file/1`'s path kinds.

It also extends five existing tests: the delimiter test, "an entry no line can say", the
totality test's junk, "host mistakes", and the dot-readings test.

**Done-when, as the spike runs it.** `T-synth-probe/donewhen.exs` was rerun on the revised
spike, and its output `T-rev-probe/donewhen.log` is identical to T-synth's (`diff` is
empty):
- the plant is 40 entries: 18 connections, 16 globals, 3 programs and 3 tasks;
- it compiles to 3 tasks, 16 globals, 3 instances and 18 connections, with no warning;
- the broken source gives exactly seven diagnostics, on lines 7, 9, 11, 12, 14, 15 and
  16, as §3.7 prints them.

**Each finding's repro, rerun** (`T-rev-probe/fixes.exs`, output `fixes.log`, `mix run`,
exit 0):
- rf-T-correct-1: all four calls on `[entry | :x]` give `ArgumentError`, ``entries must be
  a list, got: [… | :x]``.
- rf-T-correct-2: `program m1 motor ( with fast`, with uses of `m1`, gives only
  ``line 3, column 18: a configuration line cannot hold `(` ``. `task fast interval 10 |
  priority 1` gives only its delimiter.
- rf-T-correct-3: `print/1` of `AT`, `single`, `with` and `single: "interval"` each raise
  H9 with the place's rule. None prints.
- rf-T-correct-4: `with x.y`, `with m1.start`, `with panel.i.0` and `with fast.x` each give
  C49, the last with ``did you mean `fast`?``.
- rf-T-correct-5: the ten paths give F12, F6, F10 (four times), F11 (twice), F1 and F9.
  None names a missing extension that is present.
- rf-T-correct-6: C6b, ``… as in `task fast single g priority 0` `` in that run. The final
  spike gives the task's own priority; the test pins `priority 1`.
- rf-T-correct-7: ``… as in `var_global point bool at panel.i.0`, and name that``.
- rf-T-correct-8: `task a.b …` with `with a.b` gives only the line 1 C2.
- rf-T-correct-10: `m1.start m1.i.0`, with `g` at `m1.i.0`, gives ``… name the global at
  it, `g` (line 2)``.
- X13: H15 for `ton` given as a program.
- TF-11: V4 for `xic panel.i.0`.

**Error-path growth,** rf-T-correct-9's probes rerun on the revised spike:
`T-rev-probe/growth/p6.log`, `p7.log`; figures in §12.

**The naming survey's sources** are in `T-rev-probe/sources/`, with a `README.txt` saying
what each is and where it came from. The Mitsubishi manuals are AES-encrypted PDFs, read
with PyMuPDF. The Siemens guideline was read with pypdf.

**The patch.** `git add -A && git diff --cached HEAD` in `T-rev-work`, saved as
`T-rev.patch`. `git apply --check T-rev.patch` on a fresh clone of `/home/user/logex` at
`47319f7` exits 0, and the clone was deleted after. The patch touches 13 files, with 4,696
insertions and 22 deletions:
- new: `lib/logex/configuration.ex`, `lib/logex/configuration/text.ex`,
  `test/logex/configuration_test.exs`;
- changed: `lib/logex.ex`, `lib/logex/compiler.ex` (new in this revision, R67),
  `lib/logex/declarations.ex`, `lib/logex/diagnostic.ex`, `lib/logex/tag.ex`,
  `docs/naming.md` (nine stanzas appended), `test/logex/naming_test.exs`,
  `test/logex/runtime_test.exs`, `test/logex/validation_test.exs` and
  `test/logex_test.exs`.

`/home/user/logex` was not modified (`git status --short` is empty).

---
## 7. Test plan and mutation table

### 7.1 Where each rule is pinned (in the spike)

| File | Tests | Rules |
|---|---|---|
| `configuration_test.exs`, "M2-2's done-when, as far as the text goes" | 5: plant to entries; plant from org §4.4 itself; plant from disk; the seven; file and line on four kinds of connection mistake | R3, R7–R12, R29–R40, §3.7 |
| same, "reading a line" | 14, among them line endings and a delimiter line's placeholders | R7–R13, R55 |
| same, "the checks, from the text and from Elixir alike" | 14, whole lists, C6b among them | R14–R41 |
| same, "the readings of `.`" | 5: locations, members, a dotted `with`, one spelling and a declared location first, a refused name reported once | R41, R57, R58, R64, R66 |
| same, "messages name what they are about" | 6 | R51–R54, R56, R59, W6 with files |
| same, "M2-4: var_external binds a program to a global by name" | 4 | R44, R45, W4, W5, R31 |
| same, "warnings, which stop nothing" | 4 | W1–W3, W6a, W6b, R47's stage |
| same, "the loader" | 6 | R2–R6, R4, R65 |
| same, "the data path" | 8: text and Elixir agree; unsayable entries (16 kinds); every entry `entries!/1` takes reads back, 3,000 seeded; lines; member `0`; the round trip both ways, 200 seeded; `new!/3`; totality, 3,000 seeded junk values × 10 calls, improper lists among them | R48, R49, R60, R61 |
| same, "host mistakes" | 1, 19 calls | H1–H12, H8 on improper lists, H15 |
| same, "reserved words, by file kind" | 2 | §8 |
| same, "growth" | 1: 250 and 1,000 instances | R50 |
| `validation_test.exs` | 6, "var_external (M2-4)", a location in a rung among them | R42, R43, R46, R67 |
| `logex_test.exs` | the extension test, flipped, with `.ld.bak` and a bare `.ld`; a path that names no file, a directory or only an extension | R1, R65, F6–F11 |
| `naming_test.exs` | every keyword of a configuration file surveyed | §8 |
| `runtime_test.exs` | the public surface | §1 |

**Owed at landing, on S's runtime:**
- `end_to_end_test.exs`:
  - M2-2's done-when: two instances of one `.ld` wired to different points, N cycles
    from one image, independent state, through `compile_file/1` and `cycle/3`;
  - M2-3's: the plant without `trip`, `m1` 100 runs and `m2` 20, each `t1` against one
    clock;
  - M2-4's: an e-stop stops both in one cycle;
  - M2-6's: once per edge, before a lower priority, in cycle 1;
  - Q-22's: an event task and a late periodic task of one priority both write one global,
    and the test asserts which write lands (TF-9).
  - Assertions name no IR tag.
- `api_contract_test.exs`: a configuration walk. Configurations are drawn from the spike's
  generator with deliberate breaks of every §3.3–§3.4 kind. Reach is asserted under seeds
  it was not tuned on.
- The labels test: every decision number a landing cites is in org §7 first, numbered
  once by the design-record commit (X14).
- With M2-5 landed first: a configuration whose program holds a `cal`, one whose
  `program` line names a block file, and an event task over a block holding a `ton`. Each
  is asserted as a whole diagnostic or warning list, never an exception (X1;
  `rf-X-consistency-probe/ft_probe.exs`'s three cases).

### 7.2 The mutation table

Each row reverts one rule alone in a copy of the spike, runs the full suite (`mix test`;
M45 runs `naming_test.exs` alone), and writes the file back. The script is
`T-rev-mutation.py`, T-synth's driver re-pointed at `T-rev-work`. There is one JSON line
a mutant in `T-rev-mutation.jsonl`, and a summary in `T-rev-mutation.log`, with the raw
run in `T-rev-mutation.out`. Plain `mix test` is used, as before: some mutants leave a
clause that can never match, and `--warnings-as-errors` would fail them for the wrong
reason. Exit 2 is ExUnit's code for failing tests.

**Result: 127 rules reverted, 127 red**, every rule old and new, in one run on the final
spike with four workers. The table has:
- the 107 of T-synth's table, five of them re-pointed at changed code: M1, M32, J13, N1
  and N27, where the code they revert moved under rf-T-correct-5 and -10;
- 20 new for this revision's fixes, P1 to P13.

P6 was rerun alone after C6b's example took the task's own priority; it is red. Every run
exited 2, none failed to compile, and none but M26 failed through a growth bound. 54 runs
printed a compile warning, which was in every case the mutant's own unreachable clause or
unused function. M26, the growth mutant, measured 11.48x against the bound 5.1.

| # | Rule reverted | File | Exit | Result | Tests that failed (first two, and the count) |
|---|---|---|---|---|---|
| M1 | compile_file takes only .ld | `logex.ex` | 2 | 506/508 passed (6/6 doctests, 500/502 tests) | LogexTest: compile_file/1 only a .ld file is a program's, named for its basename less .ld; LogexTest: compile_file/1 a path that names no file, a directory or only an extension says which |
| M2 | var_external is a section row | `declarations.ex` | 2 | 494/508 passed (6/6 doctests, 488/502 tests) | Logex.ValidationTest: var_external (M2-4): a tag a configuration's global supplies is no var_input: a host does not set it on a lone instance; Logex.ValidationTest: var_external (M2-4): a tag a configuration's global supplies declares a bool or a dint that logic reads and writes, with no warning (+12 more) |
| M3 | a var_external takes no initial value | `declarations.ex` | 2 | 506/508 passed (6/6 doctests, 500/502 tests) | Logex.ValidationTest: var_external (M2-4): a tag a configuration's global supplies takes no initial value, no instance, and no name a configuration file reserves; Logex.ValidationTest: var_external (M2-4): a tag a configuration's global supplies from Elixir, the same rules |
| M4 | a var_external's name is legal in a configuration file | `declarations.ex` | 2 | 505/508 passed (6/6 doctests, 499/502 tests) | Logex.ValidationTest: var_external (M2-4): a tag a configuration's global supplies from Elixir, the same rules; Logex.ValidationTest: var_external (M2-4): a tag a configuration's global supplies takes no initial value, no instance, and no name a configuration file reserves (+1 more) |
| M5 | the reader refuses ( \| ) | `text.ex` | 2 | 505/508 passed (6/6 doctests, 499/502 tests) | Logex.ConfigurationTest: reading a line (M2-2, M2-3, M2-6): its grammar, at its token a line broken by a delimiter still declares what its words before it name; Logex.ConfigurationTest: reading a line (M2-2, M2-3, M2-6): its grammar, at its token a branch delimiter has no place in a configuration (+1 more) |
| M6 | a task's inputs in IEC's order | `text.ex` | 2 | 507/508 passed (6/6 doctests, 501/502 tests) | Logex.ConfigurationTest: reading a line (M2-2, M2-3, M2-6): its grammar, at its token a task line: a name, then single, interval and priority, once each, in that order |
| M7 | each task input once | `text.ex` | 2 | 507/508 passed (6/6 doctests, 501/502 tests) | Logex.ConfigurationTest: reading a line (M2-2, M2-3, M2-6): its grammar, at its token a task line: a name, then single, interval and priority, once each, in that order |
| M8 | one driver per sink | `configuration.ex` | 2 | 505/508 passed (6/6 doctests, 499/502 tests) | Logex.ConfigurationTest: M2-2's done-when, as far as the text goes (spike) gives the receipt's seven diagnostics for a broken source, one a line; Logex.ConfigurationTest: the checks, from the text and from Elixir alike a var_output drives globals, never an input point, one driver a sink (+1 more) |
| M9 | nothing drives an input point by connection | `configuration.ex` | 2 | 504/508 passed (6/6 doctests, 498/502 tests) | Logex.ConfigurationTest: M2-2's done-when, as far as the text goes (spike) a mis-wired, unknown, undriven-input or mistyped connection names its file and line; Logex.ConfigurationTest: M2-2's done-when, as far as the text goes (spike) gives the receipt's seven diagnostics for a broken source, one a line (+2 more) |
| M10a | a var_input's global agrees in type | `configuration.ex` | 2 | 506/508 passed (6/6 doctests, 500/502 tests) | Logex.ConfigurationTest: the checks, from the text and from Elixir alike a var_input has one source, a global or a constant of its type; Logex.ConfigurationTest: M2-2's done-when, as far as the text goes (spike) a mis-wired, unknown, undriven-input or mistyped connection names its file and line |
| M10b | a var_output's global agrees in type | `configuration.ex` | 2 | 506/508 passed (6/6 doctests, 500/502 tests) | Logex.ConfigurationTest: the checks, from the text and from Elixir alike a var_output drives globals, never an input point, one driver a sink; Logex.ConfigurationTest: M2-2's done-when, as far as the text goes (spike) gives the receipt's seven diagnostics for a broken source, one a line |
| M11 | every var_input connected (decision 7) | `configuration.ex` | 2 | 502/508 passed (6/6 doctests, 496/502 tests) | Logex.ConfigurationTest: the loader a type's own mistakes come after the configuration's, each in its file; Logex.ConfigurationTest: the data path: one constructor, refusing what the text cannot say a member the text can say, the data path takes: `m1.0` is member `0` (+4 more) |
| M12 | a var_input has one source | `configuration.ex` | 2 | 506/508 passed (6/6 doctests, 500/502 tests) | Logex.ConfigurationTest: the checks, from the text and from Elixir alike a var_input has one source, a global or a constant of its type; Logex.ConfigurationTest: messages name what they are about no message advises declaring a keyword |
| M13 | an interval is at least 1 | `configuration.ex` | 2 | 506/508 passed (6/6 doctests, 500/502 tests) | Logex.ConfigurationTest: the checks, from the text and from Elixir alike a task has a priority, an interval of 1 ms or more or a trigger, in range; Logex.ConfigurationTest: the checks, from the text and from Elixir alike an event task's interval of 0 is told to leave `interval` out, not to drop `with` |
| M14 | a task has a priority | `configuration.ex` | 2 | 507/508 passed (6/6 doctests, 501/502 tests) | Logex.ConfigurationTest: the checks, from the text and from Elixir alike a task has a priority, an interval of 1 ms or more or a trigger, in range |
| M15 | a task has an interval or a trigger | `configuration.ex` | 2 | 507/508 passed (6/6 doctests, 501/502 tests) | Logex.ConfigurationTest: the checks, from the text and from Elixir alike a task has a priority, an interval of 1 ms or more or a trigger, in range |
| M16 | a location's address is integers | `configuration.ex` | 2 | 507/508 passed (6/6 doctests, 501/502 tests) | Logex.ConfigurationTest: the checks, from the text and from Elixir alike a location is a device, `i` or `q`, and an address; one global a location |
| M17 | one global a location | `configuration.ex` | 2 | 507/508 passed (6/6 doctests, 501/502 tests) | Logex.ConfigurationTest: the checks, from the text and from Elixir alike a location is a device, `i` or `q`, and an address; one global a location |
| M18 | a name is declared once, one namespace | `configuration.ex` | 2 | 505/508 passed (6/6 doctests, 499/502 tests) | Logex.ConfigurationTest: messages name what they are about a refused global does not take its location; Logex.ConfigurationTest: the checks, from the text and from Elixir alike a name is not a keyword, has no `.`, and is declared once, in one namespace (+1 more) |
| M19 | a keyword names nothing in a configuration | `configuration.ex` | 2 | 503/508 passed (6/6 doctests, 497/502 tests) | Logex.ConfigurationTest: messages name what they are about a refused global does not take its location; Logex.ConfigurationTest: reserved words, by file kind (§4.8) every keyword is reserved in a configuration file, in any case (+3 more) |
| M20 | a task's single is a bool | `configuration.ex` | 2 | 507/508 passed (6/6 doctests, 501/502 tests) | Logex.ConfigurationTest: the checks, from the text and from Elixir alike a task's single is a bool global |
| M21 | a var_external agrees in type with its global | `configuration.ex` | 2 | 506/508 passed (6/6 doctests, 500/502 tests) | Logex.ConfigurationTest: M2-4: var_external binds a program to a global by name a var_external has a global of its name and type, checked once a type; Logex.ConfigurationTest: messages name what they are about the loader names a type's own file where a message cites a line of it |
| M22 | nothing writes an input point through var_external | `configuration.ex` | 2 | 506/508 passed (6/6 doctests, 500/502 tests) | Logex.ConfigurationTest: messages name what they are about the loader names a type's own file where a message cites a line of it; Logex.ConfigurationTest: M2-4: var_external binds a program to a global by name nothing writes an input point through a var_external |
| M23 | two var_external writers warn | `configuration.ex` | 2 | 507/508 passed (6/6 doctests, 501/502 tests) | Logex.ConfigurationTest: M2-4: var_external binds a program to a global by name two writers of one global, or a writer and a connection, are a warning |
| M24 | a ton under an event task warns | `configuration.ex` | 2 | 506/508 passed (6/6 doctests, 500/502 tests) | Logex.ConfigurationTest: warnings, which stop nothing M2-6: a ton in a program only an event task runs times across events; Logex.ConfigurationTest: messages name what they are about the loader names a type's own file where a message cites a line of it |
| M25 | an unused global warns | `configuration.ex` | 2 | 503/508 passed (6/6 doctests, 497/502 tests) | Logex.ConfigurationTest: warnings, which stop nothing a global nothing uses, an output point nothing drives, a task that runs nothing; Logex.ConfigurationTest: warnings, which stop nothing a check's diagnostic is at stage :configure, a warning too (+3 more) |
| M26 | an instance is found by name in one step (growth) | `configuration.ex` | 2 | 507/508 passed (6/6 doctests, 501/502 tests) | Logex.ConfigurationTest: growth compiling a configuration stays linear in its instances 4x the instances took 11.48x the reductions |
| M27 | a configuration has a program | `configuration.ex` | 2 | 504/508 passed (6/6 doctests, 498/502 tests) | Logex.ConfigurationTest: reading a line (M2-2, M2-3, M2-6): its grammar, at its token a task line: a name, then single, interval and priority, once each, in that order; Logex.ConfigurationTest: the checks, from the text and from Elixir alike a configuration has a program (+2 more) |
| M28 | an input point takes no initial value | `configuration.ex` | 2 | 507/508 passed (6/6 doctests, 501/502 tests) | Logex.ConfigurationTest: the checks, from the text and from Elixir alike a global's initial value fits its type, and a located one takes none |
| M29 | a constant fits its var_input | `configuration.ex` | 2 | 507/508 passed (6/6 doctests, 501/502 tests) | Logex.ConfigurationTest: the checks, from the text and from Elixir alike a var_input has one source, a global or a constant of its type |
| M30 | a broken line declares its name | `text.ex` | 2 | 502/508 passed (6/6 doctests, 496/502 tests) | Logex.ConfigurationTest: reading a line (M2-2, M2-3, M2-6): its grammar, at its token reading gives every broken line and what could be read; Logex.ConfigurationTest: reading a line (M2-2, M2-3, M2-6): its grammar, at its token a program line: an instance, its type, then `with` and a task (+4 more) |
| M31 | keywords in any case | `text.ex` | 2 | 507/508 passed (6/6 doctests, 501/502 tests) | Logex.ConfigurationTest: reading a line (M2-2, M2-3, M2-6): its grammar, at its token keywords are matched in any case, and names are not folded |
| M32 | the loader takes only .lxcf | `configuration.ex` | 2 | 506/508 passed (6/6 doctests, 500/502 tests) | Logex.ConfigurationTest: the loader takes only a configuration's file, and says what a .ld is; Logex.ConfigurationTest: the loader a path that names no file, a directory or only an extension says which |
| M33 | unconnected var_inputs in declaration order | `configuration.ex` | 2 | 504/508 passed (6/6 doctests, 498/502 tests) | Logex.ConfigurationTest: messages name what they are about a case-only did-you-mean says what is case-sensitive; Logex.ConfigurationTest: the checks, from the text and from Elixir alike every var_input is connected (decision 7), cited at its instance's line (+2 more) |
| M34 | diagnostics in line order, unlined last | `configuration.ex` | 2 | 506/508 passed (6/6 doctests, 500/502 tests) | Logex.ConfigurationTest: the loader a file that cannot be read, or whose name cannot name a configuration; Logex.ConfigurationTest: the loader a type's own mistakes come after the configuration's, each in its file |
| M35 | a broken connection counts as connected | `configuration.ex` | 2 | 506/508 passed (6/6 doctests, 500/502 tests) | Logex.ConfigurationTest: reading a line (M2-2, M2-3, M2-6): its grammar, at its token a line broken by a delimiter still declares what its words before it name; Logex.ConfigurationTest: reading a line (M2-2, M2-3, M2-6): its grammar, at its token a broken connection still connects its var_input, so it is not reported unconnected |
| M36 | a var_external writer and a connection driver warn | `configuration.ex` | 2 | 507/508 passed (6/6 doctests, 501/502 tests) | Logex.ConfigurationTest: M2-4: var_external binds a program to a global by name two writers of one global, or a writer and a connection, are a warning |
| M37 | an output point nothing drives warns | `configuration.ex` | 2 | 507/508 passed (6/6 doctests, 501/502 tests) | Logex.ConfigurationTest: warnings, which stop nothing a global nothing uses, an output point nothing drives, a task that runs nothing |
| M38 | a task that runs nothing warns | `configuration.ex` | 2 | 507/508 passed (6/6 doctests, 501/502 tests) | Logex.ConfigurationTest: warnings, which stop nothing a global nothing uses, an output point nothing drives, a task that runs nothing |
| M39 | an unreadable type file is the configuration's, at its line | `configuration.ex` | 2 | 507/508 passed (6/6 doctests, 501/502 tests) | Logex.ConfigurationTest: the loader a type with no file is an unknown type, at the line that first names it, with a did-you-mean among the program files beside it |
| M40 | an entry's name lexes as one name (data path) | `text.ex` | 2 | 507/508 passed (6/6 doctests, 501/502 tests) | Logex.ConfigurationTest: the data path: one constructor, refusing what the text cannot say an entry no line can say raises ArgumentError |
| M41 | the printer writes a task's inputs in IEC's order | `text.ex` | 2 | 506/508 passed (6/6 doctests, 500/502 tests) | Logex.ConfigurationTest: the data path: one constructor, refusing what the text cannot say every entry entries!/1 takes prints to text that reads back to it, keywords included; Logex.ConfigurationTest: the data path: one constructor, refusing what the text cannot say every configuration the constructor accepts prints to text that reads back to it |
| M42 | an output point takes no initial value | `configuration.ex` | 2 | 507/508 passed (6/6 doctests, 501/502 tests) | Logex.ConfigurationTest: the checks, from the text and from Elixir alike a global's initial value fits its type, and a located one takes none |
| M43 | a var_external with no global is a diagnostic | `configuration.ex` | 2 | 507/508 passed (6/6 doctests, 501/502 tests) | Logex.ConfigurationTest: M2-4: var_external binds a program to a global by name a var_external has a global of its name and type, checked once a type |
| M44 | compile_file points a configuration's file to its loader | `logex.ex` | 2 | 506/508 passed (6/6 doctests, 500/502 tests) | LogexTest: compile_file/1 a path that names no file, a directory or only an extension says which; LogexTest: compile_file/1 only a .ld file is a program's, named for its basename less .ld |
| M45 | a configuration keyword is surveyed (naming.md) | `naming.md` | 2 | 4/5 passed | Logex.NamingTest: every keyword of a configuration file has been surveyed |
| J1 | a check's diagnostic is at stage :configure | `configuration.ex` | 2 | 507/508 passed (6/6 doctests, 501/502 tests) | Logex.ConfigurationTest: warnings, which stop nothing a check's diagnostic is at stage :configure, a warning too |
| J14 | W2 only for an output point something reads | `configuration.ex` | 2 | 507/508 passed (6/6 doctests, 501/502 tests) | Logex.ConfigurationTest: warnings, which stop nothing an output point nothing uses is unused, not undriven; a trigger is a use |
| J20 | a task's single counts as a use of its global (W1) | `configuration.ex` | 2 | 507/508 passed (6/6 doctests, 501/502 tests) | Logex.ConfigurationTest: warnings, which stop nothing an output point nothing uses is unused, not undriven; a trigger is a use |
| J2 | a global a var_external binds counts as used (W1) | `configuration.ex` | 2 | 505/508 passed (6/6 doctests, 499/502 tests) | Logex.ConfigurationTest: messages name what they are about the loader names a type's own file where a message cites a line of it; Logex.ConfigurationTest: M2-4: var_external binds a program to a global by name two writers of one global, or a writer and a connection, are a warning (+1 more) |
| J3 | a connection may come before its program line | `configuration.ex` | 2 | 506/508 passed (6/6 doctests, 500/502 tests) | Logex.ConfigurationTest: the checks, from the text and from Elixir alike a connection names a declared instance's var_input or var_output; Logex.ConfigurationTest: the data path: one constructor, refusing what the text cannot say every configuration the constructor accepts prints to text that reads back to it |
| J4 | a type's var_external mistakes are cited once a type | `configuration.ex` | 2 | 507/508 passed (6/6 doctests, 501/502 tests) | Logex.ConfigurationTest: M2-4: var_external binds a program to a global by name a var_external has a global of its name and type, checked once a type |
| J5 | the loader compiles each type once | `configuration.ex` | 2 | 507/508 passed (6/6 doctests, 501/502 tests) | Logex.ConfigurationTest: the loader a type with no file is an unknown type, at the line that first names it, with a did-you-mean among the program files beside it |
| J8 | a dotted name whose first part is an instance is its member (R41) | `configuration.ex` | 2 | 505/508 passed (6/6 doctests, 499/502 tests) | Logex.ConfigurationTest: the readings of `.` (§4.7): each wrong one named a location's advice is written in its one spelling, and a declared one reads first; Logex.ConfigurationTest: the checks, from the text and from Elixir alike a var_input has one source, a global or a constant of its type (+1 more) |
| J9 | two names differing only in case are refused | `configuration.ex` | 2 | 507/508 passed (6/6 doctests, 501/502 tests) | Logex.ConfigurationTest: the checks, from the text and from Elixir alike a name is not a keyword, has no `.`, and is declared once, in one namespace |
| J11 | a var_output never drives a constant | `configuration.ex` | 2 | 507/508 passed (6/6 doctests, 501/502 tests) | Logex.ConfigurationTest: the checks, from the text and from Elixir alike a var_output drives globals, never an input point, one driver a sink |
| J13 | compile_file takes exactly .ld, not .LD | `logex.ex` | 2 | 507/508 passed (6/6 doctests, 501/502 tests) | LogexTest: compile_file/1 only a .ld file is a program's, named for its basename less .ld |
| J16 | an interval is at most 2147483647 ms | `configuration.ex` | 2 | 507/508 passed (6/6 doctests, 501/502 tests) | Logex.ConfigurationTest: the checks, from the text and from Elixir alike a task has a priority, an interval of 1 ms or more or a trigger, in range |
| J17 | a priority is at most 2147483647 | `configuration.ex` | 2 | 507/508 passed (6/6 doctests, 501/502 tests) | Logex.ConfigurationTest: the checks, from the text and from Elixir alike a task has a priority, an interval of 1 ms or more or a trigger, in range |
| J18 | a broken line's name enters the namespace | `configuration.ex` | 2 | 503/508 passed (6/6 doctests, 497/502 tests) | Logex.ConfigurationTest: reading a line (M2-2, M2-3, M2-6): its grammar, at its token a line broken by a delimiter still declares what its words before it name; Logex.ConfigurationTest: reading a line (M2-2, M2-3, M2-6): its grammar, at its token a broken line's name is declared, so nothing that names it is reported again (+3 more) |
| J19 | a type word or `at` in a global's name place is a missing name | `text.ex` | 2 | 507/508 passed (6/6 doctests, 501/502 tests) | Logex.ConfigurationTest: reading a line (M2-2, M2-3, M2-6): its grammar, at its token a global line: a name, a type, then an initial value or a location |
| J21 | a name of the wrong kind says what it is | `configuration.ex` | 2 | 504/508 passed (6/6 doctests, 498/502 tests) | Logex.ConfigurationTest: the checks, from the text and from Elixir alike a connection names a declared instance's var_input or var_output; Logex.ConfigurationTest: the checks, from the text and from Elixir alike a task's single is a bool global (+2 more) |
| N1 | a location where a global is wanted is named as one | `configuration.ex` | 2 | 506/508 passed (6/6 doctests, 500/502 tests) | Logex.ConfigurationTest: the readings of `.` (§4.7): each wrong one named a location's advice is written in its one spelling, and a declared one reads first; Logex.ConfigurationTest: the readings of `.` (§4.7): each wrong one named a location is written only after `at`: in a connection or a `single` it is named |
| N2 | a location that begins a connection is named as one | `configuration.ex` | 2 | 507/508 passed (6/6 doctests, 501/502 tests) | Logex.ConfigurationTest: the readings of `.` (§4.7): each wrong one named a location is written only after `at`: in a connection or a `single` it is named |
| N3 | a member of a declared non-instance says what the name is | `configuration.ex` | 2 | 507/508 passed (6/6 doctests, 501/502 tests) | Logex.ConfigurationTest: the readings of `.` (§4.7): each wrong one named a member of something that is not an instance, or of no instance, says so |
| N4 | lines rise from entry to entry | `text.ex` | 2 | 507/508 passed (6/6 doctests, 501/502 tests) | Logex.ConfigurationTest: the data path: one constructor, refusing what the text cannot say lines are nil from Elixir, or rise one entry a line, as the text gives them |
| N5 | no nil line beside a line | `text.ex` | 2 | 507/508 passed (6/6 doctests, 501/502 tests) | Logex.ConfigurationTest: the data path: one constructor, refusing what the text cannot say lines are nil from Elixir, or rise one entry a line, as the text gives them |
| N6 | a connection's instance has no `.` | `text.ex` | 2 | 507/508 passed (6/6 doctests, 501/502 tests) | Logex.ConfigurationTest: the data path: one constructor, refusing what the text cannot say an entry no line can say raises ArgumentError |
| N7 | a member is checked as the text reads it, joined to its instance | `text.ex` | 2 | 507/508 passed (6/6 doctests, 501/502 tests) | Logex.ConfigurationTest: the data path: one constructor, refusing what the text cannot say a member the text can say, the data path takes: `m1.0` is member `0` |
| N8 | the printer puts a lined entry on its line | `text.ex` | 2 | 507/508 passed (6/6 doctests, 501/502 tests) | Logex.ConfigurationTest: the data path: one constructor, refusing what the text cannot say every configuration the constructor accepts prints to text that reads back to it |
| N9 | Text.read refuses a non-binary with ArgumentError | `text.ex` | 2 | 505/508 passed (6/6 doctests, 499/502 tests) | Logex.RuntimeTest: the public surface (B5) is exactly this: every evaluate clause is private, in Logex.Runtime; Logex.ConfigurationTest: the data path: one constructor, refusing what the text cannot say nothing but ArgumentError escapes the text or the constructor, whatever it is given (+1 more) |
| N10 | Text.keyword? refuses a non-string with ArgumentError | `text.ex` | 2 | 505/508 passed (6/6 doctests, 499/502 tests) | Logex.RuntimeTest: the public surface (B5) is exactly this: every evaluate clause is private, in Logex.Runtime; Logex.ConfigurationTest: host mistakes every public function of the text and the constructor refuses a host mistake (+1 more) |
| N11 | Text.print checks its entries first | `text.ex` | 2 | 504/508 passed (6/6 doctests, 498/502 tests) | Logex.ConfigurationTest: the data path: one constructor, refusing what the text cannot say lines are nil from Elixir, or rise one entry a line, as the text gives them; Logex.ConfigurationTest: host mistakes every public function of the text and the constructor refuses a host mistake (+2 more) |
| N12 | the loader's missing type is an unknown type, not a file error | `configuration.ex` | 2 | 507/508 passed (6/6 doctests, 501/502 tests) | Logex.ConfigurationTest: the loader a type with no file is an unknown type, at the line that first names it, with a did-you-mean among the program files beside it |
| N13 | the loader suggests among the program files beside it | `configuration.ex` | 2 | 507/508 passed (6/6 doctests, 501/502 tests) | Logex.ConfigurationTest: the loader a type with no file is an unknown type, at the line that first names it, with a did-you-mean among the program files beside it |
| N14 | no message advises declaring a keyword | `configuration.ex` | 2 | 507/508 passed (6/6 doctests, 501/502 tests) | Logex.ConfigurationTest: messages name what they are about no message advises declaring a keyword |
| N15 | a refused global takes no location | `configuration.ex` | 2 | 507/508 passed (6/6 doctests, 501/502 tests) | Logex.ConfigurationTest: messages name what they are about a refused global does not take its location |
| N16 | a name's case-only hint says names | `configuration.ex` | 2 | 507/508 passed (6/6 doctests, 501/502 tests) | Logex.ConfigurationTest: messages name what they are about a case-only did-you-mean says what is case-sensitive |
| N17 | a type's case-only hint says program types | `configuration.ex` | 2 | 507/508 passed (6/6 doctests, 501/502 tests) | Logex.ConfigurationTest: messages name what they are about a case-only did-you-mean says what is case-sensitive |
| N18 | a member's case-only hint says members | `configuration.ex` | 2 | 507/508 passed (6/6 doctests, 501/502 tests) | Logex.ConfigurationTest: messages name what they are about a case-only did-you-mean says what is case-sensitive |
| N19 | a connection after a broken one still has its source checked | `configuration.ex` | 2 | 507/508 passed (6/6 doctests, 501/502 tests) | Logex.ConfigurationTest: messages name what they are about a connection after a broken one to the same var_input still has its source checked |
| N20 | an address field has no leading zero (one spelling) | `configuration.ex` | 2 | 507/508 passed (6/6 doctests, 501/502 tests) | Logex.ConfigurationTest: the checks, from the text and from Elixir alike a location is a device, `i` or `q`, and an address; one global a location |
| N21 | the loader names the type's file in a message citing its line | `configuration.ex` | 2 | 507/508 passed (6/6 doctests, 501/502 tests) | Logex.ConfigurationTest: messages name what they are about the loader names a type's own file where a message cites a line of it |
| N22 | the loader passes each type's file to the checks | `configuration.ex` | 2 | 507/508 passed (6/6 doctests, 501/502 tests) | Logex.ConfigurationTest: messages name what they are about the loader names a type's own file where a message cites a line of it |
| N23 | W6 covers a task with single and interval | `configuration.ex` | 2 | 507/508 passed (6/6 doctests, 501/502 tests) | Logex.ConfigurationTest: warnings, which stop nothing M2-6: a ton in a program only an event task runs times across events |
| N24 | new!/3 raises every problem, not the first | `configuration.ex` | 2 | 507/508 passed (6/6 doctests, 501/502 tests) | Logex.ConfigurationTest: the data path: one constructor, refusing what the text cannot say new!/3 is the Elixir face: the configuration, or one ArgumentError with every problem |
| N25 | new!/3 refuses a line on an entry from Elixir | `configuration.ex` | 2 | 507/508 passed (6/6 doctests, 501/502 tests) | Logex.ConfigurationTest: the data path: one constructor, refusing what the text cannot say new!/3 is the Elixir face: the configuration, or one ArgumentError with every problem |
| N26 | a location's i or q is lowercase | `configuration.ex` | 2 | 505/508 passed (6/6 doctests, 499/502 tests) | Logex.ConfigurationTest: the checks, from the text and from Elixir alike a location is a device, `i` or `q`, and an address; one global a location; Logex.ConfigurationTest: the readings of `.` (§4.7): each wrong one named a location is written only after `at`: in a connection or a `single` it is named (+1 more) |
| N27 | compile_file names a bare .ld as no program | `logex.ex` | 2 | 507/508 passed (6/6 doctests, 501/502 tests) | LogexTest: compile_file/1 only a .ld file is a program's, named for its basename less .ld |
| N28 | new!/3 checks with the same checks (warnings ride) | `configuration.ex` | 2 | 507/508 passed (6/6 doctests, 501/502 tests) | Logex.ConfigurationTest: the data path: one constructor, refusing what the text cannot say new!/3 is the Elixir face: the configuration, or one ArgumentError with every problem |
| X1 | a type's own diagnostics come after the configuration's (R5) | `configuration.ex` | 2 | 507/508 passed (6/6 doctests, 501/502 tests) | Logex.ConfigurationTest: the loader a type's own mistakes come after the configuration's, each in its file |
| X2 | a failed type's instances are not checked further (R5, C6) | `configuration.ex` | 2 | 506/508 passed (6/6 doctests, 500/502 tests) | Logex.ConfigurationTest: the loader a type's own mistakes come after the configuration's, each in its file; Logex.ConfigurationTest: the loader a type with no file is an unknown type, at the line that first names it, with a did-you-mean among the program files beside it |
| X3 | a configuration's file name is shaped like a name (R6) | `configuration.ex` | 2 | 507/508 passed (6/6 doctests, 501/502 tests) | Logex.ConfigurationTest: the loader a file that cannot be read, or whose name cannot name a configuration |
| X4 | an unknown line has a did-you-mean among the line keywords (R7) | `text.ex` | 2 | 506/508 passed (6/6 doctests, 500/502 tests) | Logex.ConfigurationTest: reading a line (M2-2, M2-3, M2-6): its grammar, at its token a line starts with a keyword or is a connection; Logex.ConfigurationTest: M2-2's done-when, as far as the text goes (spike) gives the receipt's seven diagnostics for a broken source, one a line |
| X5 | a keyword that belongs on a line names that line (R8) | `text.ex` | 2 | 507/508 passed (6/6 doctests, 501/502 tests) | Logex.ConfigurationTest: reading a line (M2-2, M2-3, M2-6): its grammar, at its token a keyword that belongs on a line cannot start one |
| X6 | words after a connection's source are refused (R12, T34) | `text.ex` | 2 | 506/508 passed (6/6 doctests, 500/502 tests) | Logex.ConfigurationTest: messages name what they are about a connection after a broken one to the same var_input still has its source checked; Logex.ConfigurationTest: reading a line (M2-2, M2-3, M2-6): its grammar, at its token a connection line: a member, then one global or constant |
| X7 | a name has no `.` (R14) | `configuration.ex` | 2 | 505/508 passed (6/6 doctests, 499/502 tests) | Logex.ConfigurationTest: the readings of `.` (§4.7): each wrong one named a dotted name after `with` is told a task's name has no `.`, not a global's reading; Logex.ConfigurationTest: the readings of `.` (§4.7): each wrong one named a name no line can declare is refused once, and what names it is not reported again (+1 more) |
| X8 | a keyword cannot name a program type (R16) | `configuration.ex` | 2 | 507/508 passed (6/6 doctests, 501/502 tests) | Logex.ConfigurationTest: the checks, from the text and from Elixir alike a program line names a type given, by a name that is not a keyword |
| X9 | `with` names a declared task (R21) | `configuration.ex` | 2 | 501/508 passed (6/6 doctests, 495/502 tests) | Logex.ConfigurationTest: messages name what they are about no message advises declaring a keyword; Logex.ConfigurationTest: the checks, from the text and from Elixir alike `with` names a declared task, before or after its line (+5 more) |
| X10 | an unlocated global's initial value fits its type (R22) | `configuration.ex` | 2 | 507/508 passed (6/6 doctests, 501/502 tests) | Logex.ConfigurationTest: the checks, from the text and from Elixir alike a global's initial value fits its type, and a located one takes none |
| X11 | a program line's type is one of the types given (R27) | `configuration.ex` | 2 | 505/508 passed (6/6 doctests, 499/502 tests) | Logex.ConfigurationTest: messages name what they are about a case-only did-you-mean says what is case-sensitive; Logex.ConfigurationTest: warnings, which stop nothing a check's diagnostic is at stage :configure, a warning too (+1 more) |
| X12 | a connection names no path deeper than one member (R30) | `configuration.ex` | 2 | 507/508 passed (6/6 doctests, 501/502 tests) | Logex.ConfigurationTest: the checks, from the text and from Elixir alike a connection names a declared instance's var_input or var_output |
| X13 | a var is internal: it does not connect (R31) | `configuration.ex` | 2 | 505/508 passed (6/6 doctests, 499/502 tests) | Logex.ConfigurationTest: the checks, from the text and from Elixir alike a connection names a declared instance's var_input or var_output; Logex.ConfigurationTest: the data path: one constructor, refusing what the text cannot say the entries read from text and built in Elixir meet the same checks (+1 more) |
| X14 | a var_external does not connect (R31) | `configuration.ex` | 2 | 507/508 passed (6/6 doctests, 501/502 tests) | Logex.ConfigurationTest: M2-4: var_external binds a program to a global by name a connection does not reach a var_external |
| X15 | a var_input may read an output point back (R34) | `configuration.ex` | 2 | 503/508 passed (6/6 doctests, 497/502 tests) | Logex.ConfigurationTest: growth compiling a configuration stays linear in its instances; Logex.ConfigurationTest: M2-2's done-when, as far as the text goes (spike) the plant as docs/organisation.md §4.4 prints it reads to the same entries (+3 more) |
| X16 | a var_external is no function block instance (R42, V2) | `declarations.ex` | 2 | 506/508 passed (6/6 doctests, 500/502 tests) | Logex.ValidationTest: var_external (M2-4): a tag a configuration's global supplies takes no initial value, no instance, and no name a configuration file reserves; Logex.ValidationTest: var_external (M2-4): a tag a configuration's global supplies from Elixir, the same rules |
| P1 | entries!/1 refuses an improper list with its pinned message (rf-T-correct-1) | `text.ex` | 2 | 506/508 passed (6/6 doctests, 500/502 tests) | Logex.ConfigurationTest: the data path: one constructor, refusing what the text cannot say nothing but ArgumentError escapes the text or the constructor, whatever it is given; Logex.ConfigurationTest: host mistakes every public function of the text and the constructor refuses a host mistake |
| P2 | a line broken by a delimiter declares what its words name (rf-T-correct-2) | `text.ex` | 2 | 506/508 passed (6/6 doctests, 500/502 tests) | Logex.ConfigurationTest: reading a line (M2-2, M2-3, M2-6): its grammar, at its token a branch delimiter has no place in a configuration; Logex.ConfigurationTest: reading a line (M2-2, M2-3, M2-6): its grammar, at its token a line broken by a delimiter still declares what its words before it name |
| P3a | no task is named by a task input word (rf-T-correct-3) | `text.ex` | 2 | 506/508 passed (6/6 doctests, 500/502 tests) | Logex.ConfigurationTest: the data path: one constructor, refusing what the text cannot say an entry no line can say raises ArgumentError; Logex.ConfigurationTest: the data path: one constructor, refusing what the text cannot say every entry entries!/1 takes prints to text that reads back to it, keywords included |
| P3b | no task's single is a task input word (rf-T-correct-3) | `text.ex` | 2 | 506/508 passed (6/6 doctests, 500/502 tests) | Logex.ConfigurationTest: the data path: one constructor, refusing what the text cannot say an entry no line can say raises ArgumentError; Logex.ConfigurationTest: the data path: one constructor, refusing what the text cannot say every entry entries!/1 takes prints to text that reads back to it, keywords included |
| P3c | no global is named by a type word or `at` (rf-T-correct-3) | `text.ex` | 2 | 506/508 passed (6/6 doctests, 500/502 tests) | Logex.ConfigurationTest: the data path: one constructor, refusing what the text cannot say every entry entries!/1 takes prints to text that reads back to it, keywords included; Logex.ConfigurationTest: the data path: one constructor, refusing what the text cannot say an entry no line can say raises ArgumentError |
| P3d | no program type is `with` (rf-T-correct-3) | `text.ex` | 2 | 506/508 passed (6/6 doctests, 500/502 tests) | Logex.ConfigurationTest: the data path: one constructor, refusing what the text cannot say an entry no line can say raises ArgumentError; Logex.ConfigurationTest: the data path: one constructor, refusing what the text cannot say every entry entries!/1 takes prints to text that reads back to it, keywords included |
| P4 | a dotted name after `with` is told a task's name has no `.` (rf-T-correct-4) | `configuration.ex` | 2 | 507/508 passed (6/6 doctests, 501/502 tests) | Logex.ConfigurationTest: the readings of `.` (§4.7): each wrong one named a dotted name after `with` is told a task's name has no `.`, not a global's reading |
| P5a | Logex.compile_file names an empty path (rf-T-correct-5) | `logex.ex` | 2 | 507/508 passed (6/6 doctests, 501/502 tests) | LogexTest: compile_file/1 a path that names no file, a directory or only an extension says which |
| P5b | Logex.compile_file names a directory (rf-T-correct-5) | `logex.ex` | 2 | 507/508 passed (6/6 doctests, 501/502 tests) | LogexTest: compile_file/1 a path that names no file, a directory or only an extension says which |
| P5c | Logex.compile_file reads a dotfile as all extension (rf-T-correct-5) | `logex.ex` | 2 | 506/508 passed (6/6 doctests, 500/502 tests) | LogexTest: compile_file/1 a path that names no file, a directory or only an extension says which; LogexTest: compile_file/1 only a .ld file is a program's, named for its basename less .ld |
| P5d | the loader names an empty path (rf-T-correct-5) | `configuration.ex` | 2 | 507/508 passed (6/6 doctests, 501/502 tests) | Logex.ConfigurationTest: the loader a path that names no file, a directory or only an extension says which |
| P5e | the loader names a directory (rf-T-correct-5) | `configuration.ex` | 2 | 507/508 passed (6/6 doctests, 501/502 tests) | Logex.ConfigurationTest: the loader a path that names no file, a directory or only an extension says which |
| P5f | the loader reads a dotfile as all extension (rf-T-correct-5) | `configuration.ex` | 2 | 507/508 passed (6/6 doctests, 501/502 tests) | Logex.ConfigurationTest: the loader a path that names no file, a directory or only an extension says which |
| P5g | the loader says a bare .lxcf names no configuration (rf-T-correct-5) | `configuration.ex` | 2 | 507/508 passed (6/6 doctests, 501/502 tests) | Logex.ConfigurationTest: the loader a path that names no file, a directory or only an extension says which |
| P6 | an event task's interval 0 is told to leave interval out (rf-T-correct-6) | `configuration.ex` | 2 | 507/508 passed (6/6 doctests, 501/502 tests) | Logex.ConfigurationTest: the checks, from the text and from Elixir alike an event task's interval of 0 is told to leave `interval` out, not to drop `with` |
| P7 | a location's advice is in its one spelling (rf-T-correct-7) | `configuration.ex` | 2 | 507/508 passed (6/6 doctests, 501/502 tests) | Logex.ConfigurationTest: the readings of `.` (§4.7): each wrong one named a location's advice is written in its one spelling, and a declared one reads first |
| P8 | a name refused as a keyword or for its `.` is not reported again where it is used (rf-T-correct-8) | `configuration.ex` | 2 | 506/508 passed (6/6 doctests, 500/502 tests) | Logex.ConfigurationTest: the readings of `.` (§4.7): each wrong one named a name no line can declare is refused once, and what names it is not reported again; Logex.ConfigurationTest: the readings of `.` (§4.7): each wrong one named a dotted name after `with` is told a task's name has no `.`, not a global's reading |
| P10 | a declared location reads first, whatever its device is called (rf-T-correct-10) | `configuration.ex` | 2 | 506/508 passed (6/6 doctests, 500/502 tests) | Logex.ConfigurationTest: the readings of `.` (§4.7): each wrong one named a location's advice is written in its one spelling, and a declared one reads first; Logex.ConfigurationTest: the readings of `.` (§4.7): each wrong one named a location is written only after `at`: in a connection or a `single` it is named |
| P11 | a location in a .ld rung is named as one (TF-11) | `compiler.ex` | 2 | 507/508 passed (6/6 doctests, 501/502 tests) | Logex.ValidationTest: var_external (M2-4): a tag a configuration's global supplies a location in a rung is named as one, once a device, as any undeclared name |
| P13 | a block type given as a program has its own message (X13) | `configuration.ex` | 2 | 507/508 passed (6/6 doctests, 501/502 tests) | Logex.ConfigurationTest: host mistakes every public function of the text and the constructor refuses a host mistake |
| X17 | a broken line's name passes the name checks (R52) | `configuration.ex` | 2 | 507/508 passed (6/6 doctests, 501/502 tests) | Logex.ConfigurationTest: messages name what they are about a broken line's name passes the name checks too: a keyword is refused as one |

### 7.3 Rules no test can see, and why

Every rule of §2 that has code of its own has a mutant above.
Four kinds of rule have none, for these reasons:

- **R55 (line endings).** The reader has no line-ending code: it takes the lexer's `rnd`
  tokens, and B8's lone-CR rule is the lexer's, pinned by `frontend_test.exs` and the
  golden record. The test is a guard against a later reader that splits on `"\n"`, and a
  mutant of the lexer would test the lexer.
- **R46 (a lone instance's `var_external` cannot be set by its host).** No code of its
  own: `Logex.Runtime.call/4`'s existing refusal of anything that is not a var_input
  (`lib/logex/runtime.ex:303-308`) gives it. That refusal is M1-5's rule, pinned in
  `runtime_test.exs`. The new test in `validation_test.exs` pins its message for this
  section.
- **R12's other line shapes.** Each is a message in a whole-list test, so rewording or
  dropping one fails that test. Two of them got a mutant (J19: T18; X6: T34) as samples of
  "the rest of the line is skipped". Reverting each of the other 30 shape clauses one by
  one was not done.
- **The F+T seam (X1, X3, X4).** It has no code in this track's spike, which has no
  `cal`. §7.1 lists the tests owed when commits 2, 5, 12 and 13 land after M2-5.
- **X15, TF-5, TF-1, TF-6.** These change a moduledoc and `docs/naming.md` only. M45
  still guards the naming test's reach.
- **§4's state rules and §5.1's run-time rules.** They have no code in this track: the
  spike has no runtime (the brief: "no runtime needed"). They are owed with S's runtime
  and OE-2, and §7.1 lists the tests owed with them.

---

## 8. Landing order, as commits, each green

Each commit lands green with the full gate and its mutation rows in the message
(CLAUDE.md; CONTRIBUTING.md).

**Assumed order (§13 Q-23, S-rev Q-22).** A design-record commit first, then M2-1 (track
S), then M2-5 (track F), then this track's M2-2, M2-3, M2-4 and M2-6. M2-1 lands S-rev's
`%Logex.Configuration{}`, `new!/1`, `check/1` (the §4.4 checks on data), `start/1` and
`cycle/3`. This track's checks then become rows of S's `check/1`, in the words and the
granularity §13 Q-20 settles.

T-synth said that if M2-5 landed earlier, "nothing below changes but commit 13's
block-file rule". That was wrong (X1). With M2-5 first, every commit that reads a program
changes:
- commit 2: the `.ld` gate is composed in front of F's `load/3`;
- commit 3: the naming test is composed by hand;
- commit 5: the loader goes through `load/3` and checks a file's kind;
- commit 12: the one IR walk must know `cal` and reach block bodies;
- commit 13: the block-file refusal is unconditional;
- commits 14 and 16: R45, W4, W5 and W6 come from that walk.

Under the other order (M2-5 after M2-2), F's item would have to retrofit all of these into
T's landed code. That is the order argument for M2-5 before M2-2.

**Before any (the design-record commit, X14).** One commit for all three tracks' answers,
before any M2 code cites a decision number:
- org §7 gains the decisions, numbered once across the tracks, so no track claims "30
  onward" on its own. T's are the extension, the reader, one namespace, one spelling, where
  a type's mistakes are cited, how a scan reaches a global, the warnings' channel, and the
  answers to the cross-track questions;
- org §4.4's receipt is replaced by §3.7's pinned text, in the words §13 Q-20 settles;
- decision 3 is annotated with the chosen extension, not rewritten, since §7 keeps the
  decisions "with their options" (org:1446);
- org §8's `.lcf` line is settled (res §8 item 1);
- the overlapping document edits of the three tracks (org §4.4, §4.9 and §6.2; PLAN's
  Done-whens; README's syntax list and "Settled, not yet landed"; CLAUDE.md's
  `lib/logex.ex` entry) are ordered in the merged plan, one owner a section a commit.

| # | Item | Commit | Stanzas | Words reserved | Tags or names it breaks |
|---|---|---|---|---|---|
| 1 | M2-2 | naming stanzas `program`, `var_global`, `at` (docs only) | 3 | — | — |
| 2 | M2-2 | `Logex.compile_file/1` takes only `.ld` (R1, R65, F6–F11), composed as a gate in front of F's `load/3` (X4); `logex_test.exs` flips | — | — | any host that compiles `seal.txt` or `seal`; nothing in the repository (inv §10) |
| 3 | M2-2 | `Logex.Configuration.Text`: reader, `keywords/0`, `entries!/1`, `print/1`; the naming test reads `keywords/0`, composed with F's `kinds/0` test (X20); reader tests, line endings, host mistakes | — | `program var_global at bool dint` in `.lxcf` (`bool dint` already reserved in `.ld`) | no `.ld` program. A configuration name, task, global or instance spelled like one; no configuration exists yet |
| 4 | M2-2 | the M2-2 checks into S's `check/1`: R14, R25's one spelling, R41, R51–R54, R56–R59, R64, R66, W1, W2; `compile/3`; the seven. The `Logex.Configuration` surface pin in `runtime_test.exs` is rewritten here, once (X2) | — | — | — |
| 5 | M2-2 | the loader `compile_file/1` (R2–R6, R4, R51, R65), through F's `load/3`, one memo per configuration, refusing a block file on a `program` line (X1, X4) | — | — | — |
| 6 | M2-2 | the round trip (R49), totality (R60), `new!` faces agreed with S (R61, R68), growth (R50) | — | — | — |
| 7 | M2-2 | the `.ld` location reading (R67, V4) | — | — | — |
| 8 | M2-2 | done-when end to end on S's `cycle/3`; documents (§9) | — | — | — |
| 9 | M2-3 | stanzas `task`, `interval`, `priority`, `with` | 4 | — | — |
| 10 | M2-3 | task lines and `with` turned on (R11, R17–R19, R21, W3) | — | `task interval priority with` in `.lxcf` | a configuration's names spelled like them |
| 11 | M2-3 | done-when (100 and 20 runs) and documents | — | — | — |
| 12 | M2-4 | B5's one IR walk, with a public "what a program writes" and "which timers it runs", knowing `cal` and reaching block bodies; no behaviour change | — | — | — |
| 13 | M2-4 | stanza `var_external`; the section row and its `.ld` rules (R42, R43, R46); a block file refuses `var_external` with a located diagnostic and its test, unconditionally since M2-5 has landed (X3; §13 Q-18) | 1 | `var_external` in every `.ld`, in any case | any program with a tag named `var_external` (none in the repository); a `var_external` named like a `.lxcf` keyword (V3) |
| 14 | M2-4 | binding checks and writer warnings (R44, R45, W4, W5) into S's `check/1`, from the walk | — | — | — |
| 15 | M2-4 | one copy at run time (§5.1, S's scan step), done-when, documents | — | — | — |
| 16 | M2-6 | stanza `single`; `single` lines turned on (R20, W6a, W6b, C6b), W6 from the walk; S's `Task` gains `single` | 1 | `single` in `.lxcf` | a configuration's names spelled `single` |
| 17 | M2-6 | edges at run time (§5.1), done-when, documents; the trigger's rule moved out of `initial_env/1`'s doc (§4) | — | — | — |

**Words and the messages that name them (TF-10).** The spike reserves all ten words at
once (§11 D2). Commits 3, 10 and 16 stage them, as PLAN does. A message that names a word
is staged with it. Otherwise a message would advertise a word the reader still refuses:
before commit 10, T2 would tell a reader whose `task` line was just refused that "a line
starts with `task`". So:
- **commit 3:** T2 reads ``…: a line starts with `var_global` or `program`, or is a
  connection…``; T1's did-you-mean set is `var_global` and `program`; T3 and T4 do not
  exist yet, and `single`, `interval`, `priority` and `with` are names;
- **commit 10:** T2 gains `task`, the did-you-mean set gains `task`, T3 (for `interval`
  and `priority` only) and T4 arrive, and C5 reads ``task `<t>` needs an interval, as in
  `task <t> interval 10 priority 1` ``, with no trigger. T10 reads ``…: a task takes
  `interval` and `priority` ``. Before commit 16, `single` on a task line gets that T10;
- **commit 16:** T3 gains `single`, T10 and C5 gain the trigger, and C6b arrives.

Each staged message is pinned whole in its commit's tests, so the next commit's widening
shows in its diff.

---
## 9. Documents each commit stales

| Commit | README.md | CLAUDE.md | PLAN.md | organisation.md | naming.md |
|---|---|---|---|---|---|
| design record | — | — | the three `.lcf` occurrences (PLAN.md:954, 1314, 1784) become the chosen extension | decision 3 annotated with the choice, not rewritten (org:1446 keeps the decisions with their options); the other 17 `.lcf` occurrences (`grep -o '\.lcf' docs/organisation.md \| wc -l` gives 18) renamed | — |
| 1, 9, 13, 16 | — | — | — | — | the stanzas, appended; the intro sentence on what `naming_test.exs` checks (`docs/naming.md:8`) gains configuration keywords at commit 3 |
| 2 | `compile_file/1`'s description (README.md:12, 177) | `lib/logex.ex`'s Key Files entry (CLAUDE.md:22-24): only `.ld` | M2-2 status; `PLAN.md:939`'s "compile_file/1 names the …" | §6.2 M2-2 | — |
| 3–6 | syntax list for configuration lines (README.md:26-47); the "Settled, not yet landed" bullet (README.md:131-140) | Key Files: `configuration.ex`, `configuration/text.ex`, `configuration_test.exs`; the "Nothing compiles a user's program to BEAM" bullet's front-end list | B5's module list; M2-2 status; §5's organisation bullet | §4.4: the receipt replaced by §3.7 (in the design-record commit), the loader's did-you-mean; §4.7's location reading message; §4.8's table heading; §8's `.lcf` unverified line settled; IEC-14 beside org:434 | — |
| 7 | — | — | — | §4.7: a location in a `.ld` body is named (R67) | — |
| 8 | a worked configuration example, its output re-run | Tests line: `configuration_test.exs`; `end_to_end_test.exs` gains configurations | M2-2 done | §6.2 | — |
| 10, 11 | the task line in the syntax list; the example gains tasks | — | M2-3 done | §4.4 line table unchanged | — |
| 12 | — | Key Files: the walk's module; `Logex.Warnings` and `Logex.Edit` entries | B5 module list | — | — |
| 13–15 | `var_external` in the declaration list and instruction table | `lib/logex/declarations.ex`'s entry (sections), the "New state" bullet (a `var_external` holds no state between scans) | M2-4 done | §4.4 "Globals shared by name" (G2); §4.9's section change row | — |
| 16, 17 | `single` in the syntax list; an event-task example | `lib/logex/program.ex`'s doc pointer moved (§4) | M2-6 done; Milestone 2's done sentence walked | §4.6's caveat now landed; §4.9 "One rule for new state" gains the trigger | — |

---

## 10. What came from which design and judge

| Piece | From | Why |
|---|---|---|
| The token reader, its grammar and every reader message (T1–T34) | T1 | JT1: "a sound, small recursive descent over the unchanged lexer"; kept over S2's route through `Logex.Parser` (JT1 graft 5) |
| The checks, R14–R46, W1–W5 and their messages | T1 | reproduced by JT1 |
| `compile(name, source, programs)` | T1, org:470 | decided text; JT1 graft 5 keeps it over S2-Q15 |
| A location in a connection or `single` named (R57, R58) | JT1 D1 | org §4.7 |
| Lines nil or rising; member checked as the text reads it; instance with no `.` (R48) | JT1 D2 | CLAUDE.md data-path rule |
| `ArgumentError` on every public function of `Text`; `entries!/1` public, shared by `print/1` and `check/3` | JT1 D3 | CLAUDE.md |
| The loader's did-you-mean for a missing type (R4) | JT1 D4 | org §4.4 "Unknown names" |
| No message advises a keyword (R53) | JT1 D5 | — |
| A refused global takes no location (R56) | JT1 D6 | one mistake, one message |
| J1, J14, J20 pinned | JT1 D7 | CLAUDE.md, a rule needs a test |
| Case-only hints name their kind (R54) | JT1 D8 | — |
| `compile_file/1`'s F8 and F9 | JT1 D9 | — |
| R52's doc, R59 | JT1 D10 | — |
| The `.ld` file named in R44, R45 and W6's messages (R51) | JT1 graft 1 (the half needing no F15); S2 §7.3's wording | Milestone 2's done sentence |
| The totality test (R60) | JT1 graft 2; S2's CF-29 property | would have caught D3 |
| `new!/3`, raising every problem, refusing lines (R61) | JT1 graft 3; S1, S2, S3; S-synth NW-3 and §3.1 | org §4.4 "Loading" |
| The exact round trip with lines placed (R49) | JT1 graft 4, strengthened: lines kept rather than compared away | — |
| W6 for `single` with `interval` (W6b) | JT1 G1 | org §4.6 "Caveats" |
| The edit's view of a `var_external` (§13 Q-17) | JT1 G2 | — |
| `var_external` in a block file (§13 Q-18) | JT1 G3; F2.md:549-553 | — |
| A read-but-never-written global (§13 Q-12, option) | JT1 G4 | — |
| The line-ending test (R55) | JT1 G5 | — |
| One spelling of an address (R25) | S-synth CF-11b and its Q-9 | removes a contradiction between tracks |
| The plant read from organisation.md itself | this synthesis | the decided example and the reader cannot drift |
| The refutation pass's fixes (Changed in revision) | rf-T-correct, rf-T-fit, rf-X-consistency | each reproduced by a skeptic before it was fixed |
| The vendor rows of the nine stanzas | this revision's survey (TF-5), `T-rev-probe/sources/` | CLAUDE.md, step 1 of a new word |
| One question per cross-track decision, in S-rev's terms | S-rev §13, X-consistency | one answer, not two |
| The contract against S-synth (§1.5) | this synthesis, replacing T1 §4.3 and §21 | S-synth exists now |

**Where the judge and the designs disagreed, and what was decided.** There was one judge
and one design, so there was no tie to break. Two places needed a decision:
- **JT1 graft 4 offered two ways out:** compare the round trip "but for lines", or refuse
  non-rising lines. This design does both halves of the stronger one. It refuses
  non-rising lines (R48), and it prints lined entries on their own lines, so equality is
  exact (R49). The cost is that a printed file keeps empty lines where the entries had
  gaps. That is what a file read and printed back should look like.
- **T1 compared address fields as numbers (`panel.q.00` collided with `panel.q.0`).**
  S-synth refuses the leading zero. JT1 listed T1's behaviour as correct. One validator
  must have one rule. S-synth's is taken because it gives each point one spelling, which
  a printer and a diff both want, and either can relax later (§13 Q-8).

---

## 11. Departures from decided rules

- **D1 (a reading that may be a departure).** org §4.4 "One driver per sink"
  (org:431-433) puts the two-writer warning "in M1-5's `warnings:` channel". The spike
  carries it, and W6 (org §4.6 Caveats: "an M1-5 warning"), on
  `%Logex.Configuration{}.warnings`. `%Logex.Program{}.warnings` sees one program, never
  two instances or a task. Raised as §13 Q-12.
- **D2 (spike only).** PLAN M2-2, M2-3 and M2-6 (PLAN.md:1314-1358) reserve their words
  item by item. The spike reserves all ten at once. §8 stages them as PLAN does.
- **D3 (spike only; S's to settle).** The spike's `new!/3` takes positional arguments to
  match `compile/3`. S-synth's `new!/1` takes a keyword list. One must land (§13 Q-19).
- **D4 (a departure from IEC, deliberate and reversible; TF-2).** A function block's file
  refuses `var_external` (§13 Q-18). IEC allows it: Ed 2 Table 33 features 10a and 10b,
  *"VAR_EXTERNAL declarations within function block type declarations"* (ed2.txt:3731,
  3742), Ed 2's `other_var_declarations` (B.1.5.2, ed2.txt:8169-8175) and Ed 3's
  `Func_Var_Decls : External_Var_Decls | Var_Decls` in `FB_Decl` (ed3.txt:13138, 13156).
  Recorded here as org §4.8 records its own departures from IEC. inv U19 is answered.
- **Not departures, recorded (and why T-synth's Q-4 and Q-13 are withdrawn, TF-12):**
  - org §4.4's seven messages are "pinned by no test" (org:449) and are reworded (§3.7).
  - "Declare it first" in that receipt is not a decided rule, and the decided plant needs
    forward references (`trip` names `estop` on line 4; `estop` is declared on line 6).
    T-synth asked this as Q-4, but the decided example settles it: names resolve over the
    whole file (built).
  - Output points take no initial value, as org §4.4's line table gives none with `at`.
  - The `var_external` name rule implements org §4.8's "legal in both kinds" at the `.ld`
    compile.
  - Research finding IEC-14 contradicts org:434's "No IEC rule on an unconnected program
    input was found"; decision 7 still stands, with a different reason (res §8 item 4).
  - W6b widens T1's W6 to what org §4.6's caveat says, so it narrows nothing decided.
    PLAN M2-6 (PLAN.md:1354) writes `task <n> single <g> [interval <ms>] priority <p>`, so
    a task with both is an event task, and the caveat covers it. T-synth asked this as
    Q-13; the decided text settles it.

---

## 12. Risks

- **The lexer's `.` rule carries every location.** PLAN §5 warns that `.` is safe only
  while there are no float literals; a float lexeme would split `panel.q.0`. Mitigation:
  a location lexeme valid only after `at`, which the `%` fallback would need anyway.
- **Two validators until the merge.** The spike's `check/3` and S-synth's `check/1` both
  check names, intervals, locations and connections, with different words (§13 Q-20).
  Landing both would put two messages on one mistake. The merge is the first M2-2 commit
  after M2-1 (§8, commit 4).
- **Placeholders (C5) and failed types (C6) are text-path concerns** that the spike puts
  in the constructor. S-synth's `check/1` has neither yet. Without them a broken line's
  name is reported twice.
- **Did-you-mean on error paths** is a Jaro pass over a kind's names for each unknown
  reference: O(errors × names), as the `.ld` compiler's (`lib/logex/compiler.ex:801`).
  R50's growth test covers accepted configurations only. Measured on the revised spike
  (`T-rev-probe/growth/p6.log`, `p7.log`; rf-T-correct-9's probes):
  - valid, 250 to 1,000 instances: 560,664 to 2,148,384 reductions, 3.83x;
  - one undeclared global per instance: 7,312,226 to 115,552,034, 15.8x (66 ms to 826 ms);
  - one undeclared task per instance: 7,335,209 to 115,297,428, 15.72x;
  - the `.ld` compiler's undeclared uses, by the same probe: 16.03x.

  The cost is inherited and paid only on mistakes. Building each kind's candidate list
  and its lowercase index once per check would make it linear in names plus errors, as
  PLAN records was done for the `.ld` twin lookup. Not built; S-rev Q-31 asks the same of
  the runtime.
- **The loader lists the directory** to suggest a type. That is one `File.ls/1` per
  missing type. A directory that cannot be listed gives the ", nor any program file"
  wording, which is then not quite true.
- **Case-insensitive filesystems.** On macOS, `Motor.ld` resolves for `program m1 Motor`,
  and the loader's `File.exists?/1` says so, so the case-only hint is not given there.
  The type's name is still the line's. Unverified on macOS; the test runs on Linux.
- **One namespace** refuses a task named like a global. No example does that, but a
  converted plant might.
- **The plant test reads `docs/organisation.md`.** An edit to §4.4's example breaks a
  test. That is intended, since the example is decided text, but it couples a document to
  the suite. The split is on "```\n// plant.", which survives the `.lcf` → `.lxcf` rename.
- **R51 names a type's file only through the loader.** A program given to `compile/3`
  keeps "on its line 8" without a file, and `Logex.Edit` still lacks one (F15).
- **Growth tests in reductions are not immune to load.** Under a load average near 45
  the configuration's growth test and the existing `compile/2` one each failed once,
  at 5.18x–5.2x against bounds of 5.1 (§7.2). Alone they measure 4.16x–4.21x. The cause
  is unverified; a CI runner that shares cores could see it.
- **The stand-in is not S's code.** §1.5 is what must survive a merge. The checks'
  structure and messages are this track's; their home is S's.
- **The seam with M2-5 is not spiked.** X1, X3 and X4 were reproduced on a hand merge of
  T-synth and F-synth by the refuters. This revision fixes T's side in the plan (§5, §8),
  not in code, since T's spike has no `cal`. The F+T composition must be rebuilt and
  re-probed (`rf-X-consistency-probe/ft_probe.exs`) when commits 2, 5 and 12 land.
- **The location shape is written twice.** The configuration's `location/1` and the `.ld`
  compiler's `located/2` (R67) both know "a device, `i` or `q`, whole-number fields". The
  compiler's reads any spelling, and only to name the mistake. S-rev's public
  `Configuration.location/1` would let the compiler call one rule once both land.

---

## 13. Decisions for the maintainer

Each question gives its options and their consequences, a recommendation and why, and the
item it must be decided before. "Built" marks what the spike does. **Cross-track** marks a
question another track's design also asks. Each is stated here in the terms S-rev states
it, with its S-rev number, what each track recommends, and what each would do. The merged
design record must answer each once. T-synth's numbers are kept. Q-4 and Q-13 are
withdrawn: decided text settles both (§11; TF-12). New questions start at Q-22.

**Q-1 · The extension** (M2-2; decision 3; T1-Q1). *Before the design-record commit.*
- (a) `.lxcf`, "logex configuration file": 0 files on GitHub, and no entry on fileinfo,
  filext, file-extension.info or Linguist (res EXT-8). Research flags the "lx" prefix as
  possibly suggesting Linux or LXC, but for `.lxcfg`, not `.lxcf`, and lists `.lxc` as
  taken, a different extension.
- (b) `.ldcfg` or `.ldcf`: pairs visibly with `.ld`. Research found 0 uses of either
  (EXT-8). Its cost is a connotation, not a collision: "ld" is the GNU linker's name, so
  `plant.ldcfg` may read as a linker configuration, and it sits near `ldconfig`. JT1 notes
  that `.ld` already carries that connotation (JT1.md:613). This is not the clash that
  ruled out `.lcf`, which is in use by four other tools (EXT-1..4) in 5,264 GitHub files
  (EXT-6).
- (c) Keep `.lcf`: it collides with CodeWarrior's, CudaText's, Loon's and Archicad's
  files (res EXT-1..6), and a later rename is a migration.
- *Recommend (a).* It has no recorded use and no recorded other reading. (b) is a fair
  second if pairing with `.ld` matters more than the connotation. In the spike the choice
  is one module attribute.

**Q-2 · How a configuration file is read** (M2-2; T1-Q2). *Before commit 3.*
- (a) A recursive descent over `Logex.Lexer`'s tokens (built). Line-shape mistakes get
  columns, and `( )` is refused at its token, the words before it still read. The `.ld`
  grammar, golden record and `@required_shapes` are untouched.
- (b) Through `Logex.Parser`'s rung tree, as declaration lines are. Less code, but no
  column, a `( )`-only line has no line to cite, and groups are refused element by
  element.
- *Recommend (a)*, as JT1 does: a configuration has no rungs. S-rev §5 no longer asserts
  (b) (X11).

**Q-3 · The stage of a configuration diagnostic** (M2-2; T1-Q3). **Cross-track** (S-rev
Q-16, agreed). (a) A new `:configure` (built), attributed to `Logex.Configuration.check/1`
at M2-1, in S-rev's words, which T's `diagnostic.ex` now carries byte for byte (X15).
*Recommend (a).*

**Q-4** · *Withdrawn* (TF-12). Line order is settled by the decided plant, which names
`estop` before declaring it; §11 records the reading. Names resolve over the whole file
(built).

**Q-5 · One namespace** (M2-1, M2-2; T1-Q5). **Cross-track** (S-rev Q-7, agreed in rule;
words in Q-20). *Before M2-1's constructor.* (a) Tasks, globals and instances in one
namespace, a case-only twin refused (built in both). (b) One per kind. *Recommend (a)*:
`get(rt, "m1")` and `single m1` cannot be ambiguous.

**Q-6 · Where a program type's mistake is cited** (M2-4; T1-Q6). *Before commit 14.*
- (a) Once a type, at its first instance's `program` line in the configuration file,
  naming the type's `.ld` file and line in the message when the loader read it (built,
  R51). Every configuration diagnostic stays in the configuration's file.
- (b) At the `.ld` declaration, in the program's file. Needs F15's `file` on
  `%Logex.Program{}`, and the message must name the configuration.
- (c) At every instance: one fix, many messages.
- *Recommend (a).* It works without F15; with F15 (Q-24) the file comes from the program
  rather than from the loader. It is one of two citation conventions to state together
  with F's R68 (§5).

**Q-7 · An output point's initial value** (M2-2; T1-Q7). **Cross-track** (S-rev Q-10,
agreed). (a) None (built in both; org §4.4's line table gives none). (b) Allowed, written
before `at`. *Recommend (a)*: strict and reversible.

**Q-8 · The location grammar and its spelling** (M2-2; T1-Q8). **Cross-track** (S-rev
Q-9, agreed). *Before commit 4.* (a) A device of one name part, `i` or `q` lowercase, one
or more whole-number fields with no leading zero; one global a location (built in both).
(b) Fields compared as numbers. (c) Dotted devices, or `I`/`Q` in any case. *Recommend
(a).* An oddity both tracks share: `panel.i.1` and `panel.i.1.0` are two locations (IEC's
rule unverified). Device names are Q-27.

**Q-9 · A task line's order and ranges** (M2-3; T1-Q9). **Cross-track** (S-rev Q-8;
*they now differ*, TF-1). *Before commit 10.*
- (a) IEC's order (`single`, `interval`, `priority`), each once; interval 1..2147483647
  ms; priority 0..2147483647, a dint's range (built in both spikes).
- (b) Any order: two spellings of one line.
- (c) Priority 0..31, one vendor's bound (CODESYS's help gives "0..31").
- (d) IEC's order and interval range, with priority 0..65535. That is Ed 3's own bound:
  Table 63 (p.182) types PRIORITY as UINT, and Table 10 (p.31) note d makes a UINT 0 to
  2^16-1 (`sed -n 10780,10790p inv-sources-src/ed3.txt`; line 1717). Ed 2 says
  `integer`, and Ed 3's grammar `Unsigned_Int` is a digit string, so neither bounds it.
  inv U24 ("No range is quoted") is answered by this.
- *Recommend (d).* Decision 7's reasoning is to start strict where relaxing later breaks
  no plant. S-rev Q-8 argued that priority is the exception because "any tighter bound is
  one vendor's number". That holds for (c), but not for (d), which is IEC's own type, so
  the exception's premise falls. (d) costs one module attribute and one test in each
  track. S-rev recommends (a), and the merged record must pick one. The `priority`
  stanza's Why says what is built and is updated by the choice before commit 9.

**Q-10 · How a scan reaches a global through `var_external`** (M2-4; T1-Q10). Unchanged
from T-synth.
- (a) G1: a private scheduler entry, and `instance/1` refuses a program with a
  `var_external`. Faithful to IEC, but it bars `scan/2` and `Logex.Edit` on such a
  program.
- (b) G2: `call/4` unchanged. The scheduler merges each global into the env before a scan
  and splits it off after, and a lone instance keeps the tag at 0 (built; S-rev §5
  agrees). One copy, and no public contract change. A lone program's `var_external`
  cannot be driven by its host, and an edit's switch needs Q-17's rule.
- (c) G3: `call/4` takes a `var_external` as an input and returns it with the outputs.
  M1-5's pinned input contract changes.
- *Recommend (b).*

**Q-11 · A global both driven by a connection and written through `var_external`**
(M2-4; T1-Q11). *Before commit 14.* (a) A warning (built, W5). (b) An error. *Recommend
(a)*: org §4.4 makes a `var_external` write a warning because it is visible only in the
IR.

**Q-12 · Which warnings a configuration carries, and where** (M2-2, M2-4, M2-6). *Before
commit 4.*
- (a) W1–W6 on `%Logex.Configuration{}.warnings` (built). This reads "M1-5's `warnings:`
  channel" (org:432, org:650) as "warnings carried on the compiled value". S-rev lands the
  field empty in M2-1, and M2-2 is the first to fill it (S-rev Q-29).
- (b) As (a), plus W7, a global something reads and nothing writes. It would catch
  `single go` on a global with initial value 1, which fires once and never again. But it
  would also fire on an unlocated global used as a fixed parameter, which is legitimate
  until `var_config` exists.
- (c) On `%Logex.Program{}.warnings`. This is impossible: a program's warnings see one
  program, never two instances or a task.
- *Recommend (a)*, with W7 deferred to `var_config`.

**Q-13** · *Withdrawn* (TF-12). W6 for a task with `single` and `interval` is settled:
PLAN M2-6 makes such a task an event task, and org §4.6's caveat covers every event task.
§11 records the reading, and W6b is built.

**Q-14 · `single` with `interval`** (M2-6; T1-Q14). *Before commit 17.*
- (a) §5.1's rules: the phase is anchored at start; periods under a high trigger are
  skipped and not counted; one run a cycle; an edge run does not move the phase.
- (b) Re-anchor the phase when the trigger falls.
- (c) Count suspended periods as overlaps.
- *Recommend (a).* There is no free-software precedent (res MAT-2). The survey found the
  nearest vendor behaviour: Mitsubishi's event type on "Bit data ON (TRUE)" runs at each
  execution turn while the bit is on, and its timer (T) does not time while the condition
  is not met (`docs/naming.md`, `single`). That is a level trigger, not IEC's edge.

**Q-15 · An event task's trigger across a restart and an edit** (M2-6, OE-2).
**Cross-track** (agreed with S-rev §5; T also refuses adding or removing an event task's
`interval`). (a) A restart resets the last sample to 0, an edit keeps it, and a change of
a task's `single`, or adding or removing its `interval`, is refused. *Recommend (a)*:
decision 19 allows only interval and priority changes.

**Q-16 · `next_due` when OE-2 changes a task's interval** (M2-3, OE-2). **Cross-track**
(S-rev Q-23; TF-3, X7). *Before OE-2's design pass; M2-3's documents state the answer.*
The option set below is S-rev's:
- (a) `min(next_due, now + new interval)`. A shorter interval takes effect within one new
  period, and a longer one runs once more on the old phase. Neither adds a run at the
  switch. But the phase is then the switch's, not the anchor's: with anchor 0, a cut from
  1000 ms to 10 ms at `now` 505 runs at 515, 525 and on. So (a) gives up the anchored
  phase after an edit. org §4.6:556 ("anchored at start … the phase never drifts")
  describes steady running, and no decided text fixes `next_due` across an interval
  change.
- (b) Keep `next_due`; the next run steps by the new interval. No run is added or lost,
  but a shortened interval waits out the old period: in S-rev's probe, 0 runs in 1000 ms.
- (c) The next multiple of the new interval from the anchor. This is the one option that
  keeps the anchored phase: the same cut runs at 510, 520 and on. Its cost is new runtime
  state. The anchor (start, or the last restart, S-rev RS-2) must be kept beside
  `next_due`, since `%{next_due:, overlaps:}` cannot recover it after an earlier change.
  It also owes CLAUDE.md's rule for new state across an edit.
- (d) Re-anchor at the switch: an extra run, or a gap.
- *Recommend (a)*, as S-rev now does too. It bounds the wait by the new interval, adds no
  run, and adds no state. If the anchored phase matters more than one field of state, (c)
  is the alternative.

**Q-17 · How an online edit's switch sees an instance's `var_external`** (M2-4, OE-2; JT1
G2; TF-8). *Before OE-2's design pass; stated in M2-4's documents.*
- (a) The configuration's switch merges each global into the instance's env before the
  per-instance switch (fix F5), and splits it off after, as a scan does (§5.1).
  `Logex.Edit` is unchanged and sees a full env. Which externals each step uses decides
  what decision 25's "the value kept" means under a configuration:
  - *merge by the running program's externals, split by the candidate's* (*rec.*). Then
    `var x` to `var_external x` keeps the instance's own `x` as the edit's value, and the
    split writes it into the global. `var_external x` to `var x` keeps the global's value
    as the instance's own `x`. In both directions the value kept is the one the running
    instance last read or wrote, which is decision 25's rule for a lone instance;
  - merging by the candidate's instead loses a value. `var_external x` to `var x` leaves
    `x` out of the env, so `Edit` starts it fresh as `:added` (`lib/logex/edit.ex:583`)
    and drops the global's value. `var x` to `var_external x` overwrites the instance's
    `x` with the global's.

  The cost of the recommended pair is that `var x` to `var_external x` writes a local
  value into a shared global at the switch, which other instances then read. How OE-2
  reports that write is OE-2's to design; this question only fixes which value is kept.
- (b) `Logex.Edit` skips `var_external` tags in its plans. That is a second rule for one
  section, and OE-1's lone-instance behaviour changes.
- (c) Nothing. Under G2, today's `Edit` reports the external as `{:added, "estop", 0}` and
  writes a second copy into the env (JT1 `p9b_g2_edit.log`).
- *Recommend (a)*, with the pair above.

**Q-18 · `var_external` in a function block file** (M2-4, M2-5; inv Q4.9; TF-2, X3). **Cross-track** (F-rev §5, agreed).
*Before commit 13.*
- IEC allows it. Ed 2 Table 33 lists features 10a and 10b, *"VAR_EXTERNAL [CONSTANT]
  declarations within function block type declarations"* (ed2.txt:3731, 3742), and Ed 2's
  grammar allows it through `other_var_declarations ::= external_var_declarations | …`
  (B.1.5.2, ed2.txt:8169-8175). Ed 3 has `Func_Var_Decls : External_Var_Decls |
  Var_Decls`, which `FB_Decl` uses (ed3.txt:13138, 13156). inv U19 is resolved, and
  T-synth's "unverified" was wrong.
- (a) Refused in a block's file, with a located `:validate` diagnostic. This is a
  deliberate, reversible departure from IEC (§11 D4). A block takes a global through a
  `var_input` operand instead. F recommends the same (F-rev §5). With M2-5 first the
  refusal is unconditional in commit 13, with its test (X3). Composed with F's spike and
  without it, a block that declares one raises `FunctionClauseError` in `FbType.role/1`.
- (b) Bound through the containing program's instance. That needs the one IR walk to
  reach block bodies, and a write path out of a body.
- *Recommend (a)*: strict and reversible, with the departure recorded.

**Q-19 · `compile`'s argument order, and `new!`'s shape** (M2-2). **Cross-track** (S-rev
Q-24, agreed). (a) org:470's `compile(name, source, programs)`, as decided, beside S's
`new!/1` keyword form. T's `new!/3` is a stand-in. *Recommend (a)*, as both tracks now
do.

**Q-20 · One `Logex.Configuration` for S and T: the words, the granularity, and the error
mode.** **Cross-track** (S-rev Q-37; X2, X10). *Before commit 4, where T's checks become
rows of S's `check/1`.*
1. *Words.* Where both tracks check one rule, the messages differ: the namespace, the
   interval, the priority, an output point's initial value, one address, an unknown task,
   a second source, and no program instance. Of org §4.4's seven receipt lines, T keeps
   three word for word (lines 14, 15, 16) and rewords four (7, 9, 11, 12), as X10
   corrects. S keeps four, and adds ": one connection drives a global" to one. *Recommend
   the configuration file's words, rule by rule*, as both tracks now do: the text is the
   saved form.
2. *Granularity of an unconnected var_input.* (a) One diagnostic per member (S's CF-26).
   (b) One per instance, listing its members (T's C37, built). *Recommend (b)*, as both
   tracks now do.
3. *A host mistake in a configuration's name or programs.* S's `check/1` returns it as a
   diagnostic and raises only on a non-struct. T's `check/3` raises `ArgumentError` (H1,
   H4, H6, H15). The tracks differ:
   - S-rev recommends S's form, because `check/1` is the one validator for a struct a
     host may build by hand.
   - T recommends raising. CLAUDE.md's convention is "a mistake by the host is an
     `ArgumentError`, raised", and the house precedent is `instructionize/2`, which raises
     on a tree no text could say (OE-1). A name that is not a string, or a block type
     under `programs`, is never in a configuration's text. A raise keeps it out of the
     diagnostics a user reads for the file.
   - What each would do: under S's form, T's H1, H4, H6 and H15 become `:configure`
     diagnostics with `line: nil`. Under T's, S's two diagnostics become `ArgumentError`s
     from `check/1`, which `new!/1` and `start/1` already raise.
- The `Logex.Configuration` surface pin in `runtime_test.exs` is rewritten once, in that
  commit (X2).

**Q-21 · Lines: from Elixir, their order, and a bad one.** **Cross-track** (S-rev Q-20;
X9). *Before commit 3.*
1. *Order.* (a) S's CF-4: positive or nil, in any order. (b) T's R48: all nil, or
   strictly rising (built). *Both tracks recommend (b)*: the data API then refuses exactly
   what the text cannot say (org:777), and the printer's round trip is exact.
2. *A line on an entry from Elixir.* Both refuse it, in different words. *Both recommend
   S's per-element form*, ``task `t1` from Elixir has no line, got: 3``, since it names the
   element. T's H13 changes. T's check order also changes, so that a line on an entry from
   Elixir is reported as such before the rising rule (X9's `[3, nil]` case).
3. *A bad line in `check`.* S gives a `:configure` diagnostic, and T raises
   `ArgumentError` (H9). The tracks differ, on the ground stated in Q-20 part 3: a line
   order no file gives is a host's mistake. *T recommends raising*, as
   `Parser.well_formed!/1` does for a tree. S-rev recommends a diagnostic. The two parts
   should be answered together.

**Q-22 · An event task's due time, for the earlier-due-time tie-break** (M2-6; inv Q6.4;
TF-9). *Before commit 17.*
- Decision 11 orders due tasks by priority, then the earlier due time, then declaration
  order (org:1483). An event task has no `next_due`. No decided text gives its due time,
  and IEC's rule 3a ("longest waiting time") does not settle it. The choice changes
  outputs, since a later scan in a cycle sees what an earlier one wrote (org §4.6).
- (a) The cycle's `now` (T-synth's reading). A periodic task of the same priority that is
  late (`next_due < now`) runs before the event task, and one due exactly at `now` ties
  and falls to declaration order.
- (b) The previous cycle's `now`, when the edge was last not seen. The event task runs
  before every periodic task of its priority that came due this cycle, as if it had
  waited one cycle.
- (c) Last within its priority, always: a fixed rule, simple to state.
- *Recommend (a)*: it treats the edge as becoming due when it is seen, which is what
  §4.6 step 3 says. Owed with it: a test in `end_to_end_test.exs` with an event task and a
  late periodic task of one priority, both writing one global, asserting which write
  lands (§7.1).

**Q-23 · The order of the milestone.** **Cross-track** (S-rev Q-22, F-rev FS-Q16; X5).
*Before the design-record commit.*
- (a) M2-1 first, then M2-5, then M2-2. PLAN's and org's M2-5 Done-when (PLAN:1345,
  org:1408) stays as written: `m1.s2.run` is read through M2-1's `get/2`. T's text,
  loader and walks are then written against `cal` from their first commit (§8).
- (b) M2-5 first, then M2-1. M2-5's Done-when must be reworded.
- The code does not choose between them: S and F conflict in the same three files either
  way, and the union passes. T needs M2-1 before its items either way.
- *Recommend (a)*, as S-rev and F-rev now do. It keeps the decided text unchanged. It is
  not the only order consistent with T: T is neutral about M2-5 except that it must come
  before M2-2.

**Q-24 · Who owns fix F15?** **Cross-track** (S-rev Q-38; X18). *Before the first item
that meets it.* (a) The first item that needs a file on a program or block. Under Q-23(a)
that is M2-5. (b) M2-2, as S-synth and T-synth said. *Recommend (a)*, stating F's R68 and
T's R51 conventions together (§5).

**Q-25 · One message for a block type given as a program** (X13). **Cross-track** (S-rev
Q-39). *Before M2-5.*
- Today the wording depends on the entry point. F's R8/R9 (Runtime, Edit) mentions `cal`.
  S's BT-2 and T's H15 share the interim words. T's loader composed with F crashed (X1,
  §5).
- (a) F's words at every entry point, with the configuration's prefix ``the program
  given as `<key>` is`` where key and name differ. The loader refuses a block file on a
  `program` line with the same words at that line.
- *Recommend (a).* T's H15 leaves out `cal` only because `cal` does not exist before
  M2-5.

**Q-26 · Is a declaration refused for its name a placeholder?** (rf-T-correct-8.) *Before
commit 4.*
- Built: a keyword or a `.` (R66) is reported once, and its later uses are skipped. A
  duplicate or a case twin is not recovered, as on a `.ld` line
  (`lib/logex/declarations.ex:190-194`). So `program m1 timed` after `program m1 motor`
  checks `m1.done` against the motor, and says the motor has no `done`.
- (a) Keep the house rule for duplicates and twins (built). It is the same rule in both
  file kinds.
- (b) Make the second declaration a placeholder too, so that its uses are skipped. One
  message, but uses that the first declaration does make wrong are then not checked
  either, and the `.ld` side would differ.
- *Recommend (a).*

**Q-27 · A location's device name** (rf-T-correct-10). *Before commit 4.*
- Today a device name is case-sensitive, so `panel.i.0` and `Panel.i.0` are two points,
  and the check is silent. A device may share an instance's or a global's name. A
  mistyped device is refused only when the host binds devices at start (org §4.5: "An
  unbound device … is an error at start").
- (a) As built, with R57's revision: a declared location reads first, whatever its device
  is called.
- (b) Refuse two devices that differ only in case, as R15 refuses names. That catches the
  slip at compile time, at one more rule.
- (c) Keep devices apart from instance names too. Stricter, and it breaks no example.
- *Recommend (b)*: it is R15's reasoning ("these would be two") applied to the one name a
  location carries. Not built.

**Q-28 · Does OE-2 report a kept global whose initial value changed?** **Cross-track**
(S-rev Q-34; TF-12). *Before OE-2's design pass.* (a) Report it as decision 29 reports a
tag's. (b) Say nothing. *Recommend (a)* for one rule, but it extends decision 29 to
globals, which it does not cover, so it is the maintainer's call. §4's row is marked
*rec.*

The questions T1 raised that are not repeated above stand as T1 recommended, with JT1's
agreement (JT1 §8):
- T1-Q13: "what a program writes" is a function over the IR, landed with the walk
  extraction (§8 commit 12), not a field on `%Logex.Program{}` that a hand-built program
  could get wrong;
- T1-Q18: one diagnostic for each instance with unconnected var_inputs (Q-20 part 2);
- T1-Q20: a printer now (built, R49), as S-rev Q-25 agrees;
- T1-Q21: exactly `.ld`, case-sensitive (built, mutant J13).

### Cross-track agreements (X19), carried into the design record

| Topic | T | S-rev | F-rev | State |
|---|---|---|---|---|
| One namespace | Q-5 | Q-7 | — | agreed in rule; words in Q-20 |
| Stage `:configure`, attributed to M2-1 | Q-3 | Q-16 | — | agreed; `diagnostic.ex` identical (X15) |
| Output point takes no initial value | Q-7 | Q-10 | — | agreed |
| Location grammar, no leading zero | Q-8 | Q-9 | — | agreed; device names Q-27 (T only) |
| Interval range | Q-9 | Q-8 | — | agreed, 1..2147483647 ms |
| Priority range | Q-9 | Q-8 | — | **differ** since TF-1: T recommends Ed 3's 0..65535, S-rev a dint's |
| G2, one copy of a global | Q-10 | §5 M2-4 | — | agreed |
| Event trigger across restart and edit | Q-15 | §5 M2-6 | — | agreed; adding or removing an event task's `interval` refused in both |
| `new!` raises every problem; S's `new!/1` | R61, Q-19 | Q-14, Q-24 | — | agreed |
| `var_external` refused in a block's file | Q-18 | — | §5 | agreed; an IEC departure (§11 D4) |
| B5's one IR walk before the M2-4 checks | §8 commit 12 | §5 M2-4 | FS-Q23 | agreed; it must know `cal` (X1) |
| `next_due` after an interval change | Q-16 | Q-23 | — | agreed on (a) since this revision |
| Lines rise; S's per-element message | Q-21 1, 2 | Q-20 1, 2 | — | agreed |
| A bad line in `check`; a host mistake in the validator | Q-21 3, Q-20 3 | Q-20 3, Q-37 3 | — | **differ**: T raises, S returns a diagnostic |
| Order: M2-1, M2-5, M2-2… | Q-23 | Q-22 | FS-Q16 | agreed |
| F15 to the first item that meets it | Q-24 | Q-38 | FS-Q29 | agreed |
| One block-type message | Q-25 | Q-39 | §5 | agreed: F's words |
| A global's changed initial value | Q-28 | Q-34 | — | agreed on (a), the maintainer's call |
