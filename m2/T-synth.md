# T-synth · The configuration file, globals and event tasks: M2-2, M2-3, M2-4, M2-6

Label T-synth, track T of the Milestone 2 design pass. Written 2026-10-02 against
`/home/user/logex` at `47319f7` (main, 2026-10-01), which this pass did not modify
(`git -C /home/user/logex status --short` is empty). The spike was built in a fresh copy,
`scratchpad/m2/T-synth-work`: T1's patch applied to `47319f7`, then every defect the judge
reproduced fixed and the judge's grafts added there. Its diff, untracked files included,
is `scratchpad/m2/T-synth.patch`. The mutation driver, its per-mutant results and its log
are `scratchpad/m2/T-synth-mutation.py`, `.jsonl` and `.log`. Probes and receipts are in
`scratchpad/m2/T-synth-probe/`. Every `mix` run used Elixir 1.20.4 / OTP 28
(`scratchpad/toolchain/env.sh`) and is judged by its exit code.

**Citations.** `org` is `docs/organisation.md` and `PLAN` is `PLAN.md`, both at `47319f7`.
A bare `file:line` is the repository at `47319f7`. `spike:file` is the file in
`T-synth-work`, cited by function name because its line numbers move. `T1.md`, `JT1.md`,
`S-synth.md`, `F2.md`, `inventory.md` (`inv`), `research.md` (`res`) and `readiness.md`
(`rdy`) are this pass's documents in `scratchpad/m2/`.

**Labels.** Rule labels (`Rn`, `Wn`), message labels (`Hn`, `Fn`, `Tn`, `Cn`, `Vn`),
mutant labels (`Mn`, `Jn`, `Nn`) and question labels (`Q-n`) are this document's own. They
must never be cited in `lib/`, `test/` or `CLAUDE.md` (`edit_test.exs`'s labels test,
`test/logex/edit_test.exs:1541-1603`). The spike cites none, and cites no decision past
29 and no fix past F16. `Rn` keeps T1's numbers where the rule is T1's, so JT1 can be
read beside this file. A rule added here is numbered from R51.

---

## 0. Summary

- **Base: T1**, the judge's only design and its winner (JT1, 7.5/10). T1's reader, its
  checks, loader, extension, reservations and run-time rules are kept.
- **Every defect JT1 reproduced is fixed**, each with a test that fails when the fix is
  reverted (§7):
  - D1: a location in a connection or a `single` is named as a location;
  - D2: the data path refuses lines no file gives, and accepts a member the text says;
  - D3: nothing but `ArgumentError` escapes `Logex.Configuration.Text`;
  - D4: the loader keeps a did-you-mean for a missing type file;
  - D5: no message advises declaring a keyword;
  - D6: a refused global takes no location;
  - D7: the three unpinned rules (J1, J14, J20) are pinned;
  - D8: each case-only hint names what is case-sensitive;
  - D9: `compile_file/1`'s examples are right for `.ld` and `motor.ld.bak`;
  - D10: the code and its doc agree, and a connection after a broken one is checked;
  - D11: the wrong citation is not repeated.
- **Grafted:**
  - the loader names a type's own `.ld` file in every message that cites one of its
    lines (JT1 graft 1, the half that needs no F15);
  - a seeded totality test, 3,000 junk values through ten public calls (graft 2);
  - `Logex.Configuration.new!/3`, the raising Elixir face, every problem in one
    `ArgumentError`, refusing a line on an entry from Elixir (graft 3, S-synth NW-3);
  - an exact round trip: a lined entry is printed on its own line, so text reads back to
    the very entries (graft 4).
- **Also changed:**
  - W6 covers a task with `single` and `interval` too (JT1 G1, org §4.6 "Caveats");
  - an address has one spelling, no leading zero, to agree with S-synth CF-11b (§13
    Q-8);
  - a test reads the plant straight out of `docs/organisation.md` §4.4, so the decided
    example and the reader cannot drift apart.
- **Gate:** passes three times, **499 tests** (6 doctests), up from 430 at `47319f7` (§6).
- **The track's done-when passes:** org §4.4's plant reads into 40 entries and compiles
  with no diagnostic and no warning. The receipt's broken source gives exactly seven
  diagnostics, on lines 7, 9, 11, 12, 14, 15 and 16 (§6).
- **Mutation table:** 107 rules reverted one at a time, every one red (§7.2).
- **21 decisions for the maintainer** (§13). Nine are shared with track S's merged design
  and marked "S". Four of those are where the two tracks still differ or must merge: Q-16
  (`next_due` after an edit), Q-19 (argument order and `new!`'s shape), Q-20 (where the
  checks live, and whose words land) and Q-21 (lines from Elixir). Q-8 (one spelling of an
  address) is now agreed.

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
  checks then never report that name again.
- `print/1` writes lowercase keywords, one space between words, no indentation and no
  comments. An entry with a line is printed on that line, the lines between left empty.
  Entries with no line are printed on lines 1, 2, 3 and on. It runs `entries!/1` first.
- `entries!/1` is the text's own definition of its data, as `Logex.Parser.well_formed!/1`
  is a program's (`lib/logex/parser.ex`). Both `print/1` and `Configuration.check/3` call
  it. It raises `ArgumentError` (§3.1 H9) unless every entry is one a line can say:
  - one of the four kinds below, with that kind's fields;
  - every name one name token to the lexer;
  - a connection's instance with no `.`, and `instance <> "." <> member` again one token;
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
  - the path must end in `.lxcf`, and the configuration is named for the basename less it;
  - each type a `program` line names is compiled once, with `Logex.compile_file/1`, from
    `<type>.ld` in the same directory, in the order of the line that first names it;
  - every diagnostic and warning carries its file, the configuration's own first, in
    line order, then each type file's;
  - a type with no file is an unknown program type, at `:configure`, with a did-you-mean
    among the `.ld` files beside the configuration (D4);
  - a message that cites a line of a type's file names that file (graft 1).
- `%Logex.Configuration{name, tasks, globals, instances, connections, programs, warnings}`
  in the spike. Each list is in declaration order, each element a map with its `:line`.
  `connections` are resolved to `%{instance, member, direction: :input | :output, to,
  line}`. `warnings` are `%Logex.Diagnostic{severity: :warning, stage: :configure}`, in
  line order.

### 1.4 Changes to existing modules (spike)

- `Logex.compile_file/1`: a path whose extension is not exactly `.ld` is a `:file`
  diagnostic, `line: nil`, `file: path`, and the file is not read (PLAN M2-2,
  PLAN.md:1322). Messages F6–F9 (§3.2).
- `Logex.Declarations`: `"var_external" => :var_external` in `@sections`. `check/1` gains
  three rules: no initial value, no instance, and no name that a configuration file
  reserves (§3.6).
- `Logex.Tag`: `section` gains `:var_external` (typespec).
- `Logex.Diagnostic`: `stage` gains `:configure`. `line` may be nil for a `:configure`
  problem of an entry from Elixir or of the whole configuration (moduledoc and `@type`).
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
| C10 (new) | One spelling of an address | CF-11b: no leading zero | Agreed; the spike now refuses `panel.q.00` too (R25) |

---

## 2. Rules, numbered

Each rule names its source: decided where, IEC's, or this design's. It also names the
test that pins it (`configuration_test.exs` unless named) and its mutant in §7.2.
"Changed" marks a rule that differs from T1's.

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
- **R13** A broken line still declares its name, and a broken connection still connects
  its var_input. M30, M35, J18.
- **R55** *New.* A line ends at LF, CRLF or a lone CR and keeps its number, as the lexer
  gives it (B8). Test: "a line ends at LF, CRLF or a lone CR…" (JT1 G5). No mutant: the
  reader holds no line-ending logic of its own; the test guards against a later reader
  that splits on `"\n"`.

### 2.3 Names

- **R14** A task, global or instance name is not a configuration keyword (in any case)
  and has no `.`. *(org §4.8, decision 10; the `.` rule PLAN §5.)* M19, X7.
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
- **R18** An interval is 1 to 2147483647 ms. *(At least 1 decided in org §4.4; the upper
  bound is this design's.)* M13, J16.
- **R19** A task has a priority, 0 to 2147483647, 0 the highest. *(Mandatory by decision
  11; range §13 Q-9.)* M14, J17.
- **R20** A task's `single` names a bool global. *(org §4.4 "Events".)* M20.
- **R21** `with` names a declared task. X9.

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
  connection may come before its `program` line. *(§13 Q-4.)* J3.
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
- **R57** *New.* A location where a global is wanted (a connection's source or sink, a
  `single`) is named as a location. The message names the global at it, or says to
  declare one. A location that begins a connection line is named as one too. *(org §4.7:
  "each wrong reading gets a diagnostic that names it"; org §5: raw addresses in
  connections are not adopted, org:1248; JT1 D1.)* Test: "a location is written only
  after `at`…". N1, N2.
- **R58** *New.* A dotted name whose first part is not an instance says what that part
  is, or that there is no such instance, with a did-you-mean among the instances.
  *(org §4.7; JT1 D1's "no instance" half.)* N3.
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
  §13 Q-13.)* M24, N23.

### 2.10 Order, data path, growth

- **R47** Diagnostics come in line order, those with no line last; warnings in line
  order. Every check's diagnostic is at stage `:configure`. M34, J1.
- **R48** *Changed.* An entry no line could say raises `ArgumentError` from `check/3`,
  `new!/3`, `print/1` and `entries!/1` alike (§3.1 H9). This includes lines that are not
  all nil or strictly rising, and a connection's instance with a `.`. A member the text
  can say is taken. *(org §4.9, "the data API refuses what the text cannot say", org:777;
  JT1 D2.)* M40, N4, N5, N6, N7.
- **R49** *Changed.* Every configuration the constructor accepts prints to text that reads
  back to it. With lines, it is exactly the same entries, gaps included. With no lines,
  the entries are numbered from line 1. Tested on 200 seeded configurations, each both
  ways. *(JT1 graft 4.)* M41, N8.
- **R50** Checking a configuration is linear in its instances: 4x the instances cost under
  5.1x the reductions. M26.
- **R60** *New.* Nothing but `ArgumentError` escapes `Text.read/1`, `print/1`,
  `keyword?/1`, `entries!/1`, `Configuration.check/3`, `new!/3`, `compile/3` (each
  argument) or `compile_file/1`. Tested with 3,000 seeded junk values through each.
  *(CLAUDE.md, Conventions; JT1 D3 and graft 2.)* N9, N10, N11.
- **R61** *New.* `new!/3` refuses a line on an entry from Elixir, and raises every problem
  in one `ArgumentError`. Warnings do not raise. *(org §4.4 "Loading"; S-synth NW-3 and
  §3.1.)* N24, N25, N28.

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
| H8 | `check/3`, `new!/3`, `print/1`, `entries!/1` | `entries must be a list, got: <inspect>` |
| H9 | same | `not an entry a configuration file can say: <rule>, got: <inspect entry>`. The rule is one of: `an entry is {kind, line, fields}, its line nil or positive`; ``an entry is a :task, :global, :program or :connection with that kind's fields, a global's type :bool or :dint``; ``a connection is `to` {:global, name} or {:constant, n}``; `a name lexes as one name token`; ``a connection's instance has no `.`: its first `.` begins the member``; `a number is an integer, 0 or more: a negative one does not lex yet (PLAN.md §5)`; `lines are nil for entries built in Elixir, or rise from entry to entry, one entry a line, and this one comes after line <n>`; `lines are nil for entries built in Elixir, or rise from entry to entry, one entry a line, and no line is nil beside one that is not` |
| H10 | `Tag.new!/4` | as V1, V2 and V3 below |
| H11 | `Text.read/1` | `Logex.Configuration.Text.read/1 takes source text as a binary, got: <inspect>` |
| H12 | `Text.keyword?/1` | `Logex.Configuration.Text.keyword?/1 takes a word as a string, got: <inspect>` |
| H13 | `new!/3` | `an entry built in Elixir has no line: a line is where a configuration file declares an entry, got: <inspect entry>` |
| H14 | `new!/3` | every diagnostic `check/3` gives, each formatted by `Logex.Diagnostic.format/1`, joined by `"\n"` |

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
| C45 | R57 | ``` `<loc>` is a location, written only after `at` on a `var_global` line: declare a global at it, as in `var_global point bool at <loc>`, and name that``` (new) |
| C46 | R57 | ``` `<loc>` is a location, written only after `at` on a `var_global` line: a connection begins with an instance's var_input or var_output, as in `m1.start` ``` (new) |
| C47 | R58 | ``` `<x.y>` names a member of `<x>`, but `<x>` is <a kind> (line <l>), not an instance``` (new) |
| C48 | R58 | ``` `<x.y>` names a member of an instance, and there is no instance `<x>` ``` + did-you-mean among instances (new) |

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
- "declare it first" dropped, because lines come in any order (§13 Q-4);
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
| A global's value (M2-2) | its initial value, or 0 | written by copy-out and by `var_external` writes | back to its initial value or 0 (S-synth RS-5) | its initial value, the one rule (`Program.initial_env/1`'s rule, carried over) | kept; a changed initial value is reported, as decision 29 reports a tag's | kept unused until assemble, pruned there |
| A global's `at`, type (M2-2) | — | — | — | refused while running (located I/O, org §4.9) | a change refused at accept | refused |
| The input image (M2-2) | every input point 0 | merged at step 2 | kept, as `restart/3` keeps var_inputs (S-synth RS-3) | — (no point is added while running) | kept | — |
| An output point's value (M2-2) | 0 | step 5 | 0 | refused | held and reported `{:held, point, value}` when no logic drives it any more (org §4.9; decision 20) | refused |
| A connection (M2-2) | no state | — | — | allowed (org §4.9); decision 7 still applies to the candidate | — | allowed, unless it leaves a var_input unconnected |
| An instance (M2-2) | `Runtime.instance/1` (F14) | — | `restart/3` | `instance/1`, so its first scan is a first scan | moved by OE-1's per-instance switch, one plan per type (F5) | pruned at assemble |
| A task's `next_due` (M2-3) | 0, anchored at start | whole intervals (S-synth CY-5) | the kept `now` (S-synth RS-2) | refused (decision 19) | interval changed: *rec.* `min(next_due, now + new interval)`; priority changed: nothing. **S-synth Q-23 recommends keeping `next_due`** (§13 Q-16) | refused |
| A task's overlap count (M2-3) | 0 | `+ missed` | 0 (S-synth RS-1) | refused | kept | refused |
| An instance's task (M2-3) | — | — | — | — | a change refused (decision 19) | — |
| A `var_external` (M2-4) | none in a runtime's env; a lone instance's tag starts at 0 | merged in before its instance's scan and split off after (§5) | none held | binds to its global by name | — | — |
| A section change to or from `var_external` (M2-4) | — | — | — | — | OE-1, a lone instance: the value is kept (decision 25). OE-2: *rec.* the configuration's switch merges globals in before the per-instance switch and splits them off after, so `Logex.Edit` sees a full env (§13 Q-17) | — |
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
- **M2-5 (track F).**
  - A function block file is a `.ld` whose first line is `function_block <name>`. The
    loader does not resolve block types itself: `Logex.compile_file/1` resolves `seal` to
    `seal.ld` beside the program (F's rule), so one directory holds programs and blocks.
  - A `program` line naming a block type is a check of its own, proposed: ``` `seal` is a
    function block, not a program: instantiate it inside a program, as in `var s1 seal` ```.
  - `cal`'s output operands count as writes for R45, W4 and W5. A `ton` inside a block
    counts for W6. Both come from the one IR walk.
  - `var_external` in a block file: refused until decided (§13 Q-18). F2 recommends the
    same (F2.md:549-553).
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
    from a file. R51 names a type's file without it, because the loader knows each path
    (§13 Q-6).
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
  - An event task's due time is the cycle's `now`, for the earlier-due-time tie-break.
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
(`T-synth-probe/gate-1.log`, `gate-2.log`, `gate-3.log`):

| Run | `mix format --check-formatted` | `mix compile --force --warnings-as-errors` | `MIX_ENV=test mix compile --force --warnings-as-errors` | `mix test --warnings-as-errors` |
|---|---|---|---|---|
| 1 | 0 | 0 | 0 | 0, `Result: 499 passed (6 doctests, 493 tests)` |
| 2 | 0 | 0 | 0 | 0, `Result: 499 passed (6 doctests, 493 tests)` |
| 3 | 0 | 0 | 0 | 0, `Result: 499 passed (6 doctests, 493 tests)` |

The script is `T-synth-probe/gate.sh`; the full test output of each run is
`T-synth-probe/test-1.log` to `test-3.log`.

At `47319f7` the suite is 430 tests (6 doctests). The spike adds 69 tests: 63 in the new
`configuration_test.exs`, 5 in `validation_test.exs`, 1 in `naming_test.exs`. It flips one
in `logex_test.exs` and extends one in `runtime_test.exs`.

**Done-when, as the spike runs it** (`T-synth-probe/donewhen.exs`, output
`T-synth-probe/donewhen.log`). The plant is cut from `docs/organisation.md` itself, its
first comment and all. The tests assert the same:

```
plant entries: 40
  connection: 18
  global: 16
  program: 3
  task: 3
first: {:task, 2, %{name: "fast", priority: 1, single: nil, interval: 10}}
last:  {:connection, 45, %{member: "b_was", instance: "snap", to: {:global, "k2_at_trip"}}}
compiled: 3 tasks, 16 globals, 3 instances, 18 connections, warnings []
broken: 7 diagnostics
  [configure] line 7, column 1: unknown configuration line `progam` — did you mean `program`?
  [configure] line 9: no task `medium`: declare it with a `task` line, as in `task medium interval 10 priority 1`
  [configure] line 11: `m1` is a `motor`, which declares no `strat` — did you mean `start`?
  [configure] line 12: `pb` is an input point (line 2): `m1.motor`, a var_output, cannot drive it
  [configure] line 14: `k` is already driven by `m1.run_lamp` (line 13)
  [configure] line 15: `m1.fault` is internal to `motor` (declared `var`): only a var_input or var_output connects
  [configure] line 16: `m1.speed_sp` is a dint, but `k` is a bool (line 3)
```

The tests that make it pass are, in `configuration_test.exs`:
- "reads §4.4's plant into plain data, every line an entry with its line" (the whole list
  of 40 entries);
- "the plant as docs/organisation.md §4.4 prints it reads to the same entries";
- "loads the plant from disk, each type from its file beside it";
- "gives the receipt's seven diagnostics for a broken source, one a line";
- "a mis-wired, unknown, undriven-input or mistyped connection names its file and line".

**JT1's probes, rerun on the spike** (`T-synth-probe/jt1/*.log`). Each was run with `mix
run` in `T-synth-work`.
- `p4_dot`: every location reading is now named, for example ``line 3: `panel.i.0` is a
  location, written only after `at` on a `var_global` line: name the global at it, `pb`
  (line 1)``.
- `p8_loader`: ``[configure] …/plant.lxcf: line 3: unknown program type `motr`: there is
  no `motr.ld` beside this configuration — did you mean `motor`?``. The pure seam gives
  the same stage and suggestion.
- `p2_data` and `p7_roundtrip` exit 1. They now stop at an `ArgumentError` for the entries
  JT1 showed were wrongly accepted ("lines are nil for entries built in Elixir, or rise
  from entry to entry, one entry a line, and this one comes after line 9, got: …";
  "a connection's instance has no `.`: …"). That is the fix: the probes were written to
  print the old acceptance.
- No log contains "(tags are case-sensitive)" from a configuration message, or advises
  `var_global task bool`.

**The patch.** `git add -A && git diff --cached HEAD` in `T-synth-work`, saved as
`T-synth.patch`. `git apply --check T-synth.patch` on a fresh clone of `/home/user/logex` at `47319f7` exits 0 (the clone was deleted after). 12 files, 4,205 insertions, 20 deletions. Changed files:
- new: `lib/logex/configuration.ex`, `lib/logex/configuration/text.ex`,
  `test/logex/configuration_test.exs`;
- changed: `lib/logex.ex`, `lib/logex/declarations.ex`, `lib/logex/diagnostic.ex`,
  `lib/logex/tag.ex`, `docs/naming.md` (nine stanzas appended),
  `test/logex/naming_test.exs`, `test/logex/runtime_test.exs`,
  `test/logex/validation_test.exs`, `test/logex_test.exs`.

---

## 7. Test plan and mutation table

### 7.1 Where each rule is pinned (in the spike)

| File | Tests | Rules |
|---|---|---|
| `configuration_test.exs`, "M2-2's done-when, as far as the text goes" | 5: plant to entries; plant from org §4.4 itself; plant from disk; the seven; file and line on four kinds of connection mistake | R3, R7–R12, R29–R40, §3.7 |
| same, "reading a line" | 13, among them line endings | R7–R13, R55 |
| same, "the checks, from the text and from Elixir alike" | 13, whole lists | R14–R41 |
| same, "the readings of `.`" | 2 | R41, R57, R58 |
| same, "messages name what they are about" | 6 | R51–R54, R56, R59, W6 with files |
| same, "M2-4: var_external binds a program to a global by name" | 4 | R44, R45, W4, W5, R31 |
| same, "warnings, which stop nothing" | 4 | W1–W3, W6a, W6b, R47's stage |
| same, "the loader" | 5 | R2–R6, R4 |
| same, "the data path" | 7: text and Elixir agree; unsayable entries (11 kinds); lines; member `0`; the round trip both ways, 200 seeded; `new!/3`; totality, 3,000 seeded junk values × 10 calls | R48, R49, R60, R61 |
| same, "host mistakes" | 1, 13 calls | H1–H12 |
| same, "reserved words, by file kind" | 2 | §8 |
| same, "growth" | 1: 250 and 1,000 instances | R50 |
| `validation_test.exs` | 5, "var_external (M2-4)" | R42, R43, R46 |
| `logex_test.exs` | the extension test, flipped, with `.ld.bak` and a bare `.ld` | R1, F6–F9 |
| `naming_test.exs` | every keyword of a configuration file surveyed | §8 |
| `runtime_test.exs` | the public surface | §1 |

**Owed at landing, on S's runtime:**
- `end_to_end_test.exs`:
  - M2-2's done-when: two instances of one `.ld` wired to different points, N cycles
    from one image, independent state, through `compile_file/1` and `cycle/3`;
  - M2-3's: the plant without `trip`, `m1` 100 runs and `m2` 20, each `t1` against one
    clock;
  - M2-4's: an e-stop stops both in one cycle;
  - M2-6's: once per edge, before a lower priority, in cycle 1.
  - Assertions name no IR tag.
- `api_contract_test.exs`: a configuration walk. Configurations are drawn from the spike's
  generator with deliberate breaks of every §3.3–§3.4 kind. Reach is asserted under seeds
  it was not tuned on.
- The labels test: every decision number a landing cites is in org §7 first (30 onward).

### 7.2 The mutation table

Each row reverts one rule alone in a copy of the spike, runs the full suite (`mix test`;
M45 runs `naming_test.exs` alone), and writes the file back. Script:
`T-synth-mutation.py`; one JSON line a mutant in `T-synth-mutation.jsonl`; a summary in
`T-synth-mutation.log`. Plain `mix test` is used, as JT1 did, because some mutants leave a
clause that can never match, and `--warnings-as-errors` would fail them for the wrong
reason. Exit 2 is ExUnit's for failing tests.

**Result: 107 rules reverted, 107 red.** Every run exited 2 with at least one test
failing, and none failed to compile. The first batch was 90 mutants: T1's 45 (M1–M45),
re-pointed at this code; JT1's 16 (J1–J21, among them the three that survived on T1);
and 28 for this synthesis's fixes and grafts (N1–N28). A second batch of 17 (X1–X17) gave
a mutant of its own to every rule of §2 the first left without one. The batches' raw
outputs are `T-synth-probe/mutation-batch1.out` and `mutation-batch2.out`. A run marked
"warned" in the `.jsonl` printed a compile warning, which in every case was the mutant's
own unreachable clause or unused variable; the suite still compiled and ran.

The growth test (R50) failed as a side effect in M5 and M19, with ratios 5.2 and 5.18
against the bound 5.1. Under M19 the existing `compile/2` growth test in `logex_test.exs`
failed as well, though M19 touches nothing it runs. Both runs were made while the machine's
load average was about 45 (this table's four workers and another track's mutation run on
four cores). Run alone afterwards, ten times, the unmutated test measured 4.16x–4.21x
(`T-synth-probe/growth10.log`). The cause of the higher counts under load is unverified.
Each of the two mutants is red by its own tests regardless (M5: the delimiter test; M19:
four keyword tests). M26, the growth mutant, measured 11.59x.

| # | Rule reverted | File | Exit | Result | Tests that failed (first two, and the count) |
|---|---|---|---|---|---|
| M1 | compile_file takes only .ld | `logex.ex` | 2 | 498/499 passed (6/6 doctests, 492/493 tests) | logex: compile_file/1 only a .ld file is a program's, named for its basename less .ld |
| M2 | var_external is a section row | `declarations.ex` | 2 | 485/499 passed (6/6 doctests, 479/493 tests) | configuration: growth compiling a configuration stays linear in its instances; configuration: M2-4: var_external binds a program to a global by name a var_external has a global of its name and type, checked once a type (+12 more) |
| M3 | a var_external takes no initial value | `declarations.ex` | 2 | 497/499 passed (6/6 doctests, 491/493 tests) | validation: var_external (M2-4): a tag a configuration's global supplies takes no initial value, no instance, and no name a configuration file reserves; validation: var_external (M2-4): a tag a configuration's global supplies from Elixir, the same rules |
| M4 | a var_external's name is legal in a configuration file | `declarations.ex` | 2 | 496/499 passed (6/6 doctests, 490/493 tests) | configuration: reserved words, by file kind (§4.8) and none in a program, but where a var_external's name must be legal in both; validation: var_external (M2-4): a tag a configuration's global supplies from Elixir, the same rules (+1 more) |
| M5 | the reader refuses ( \| ) | `text.ex` | 2 | 496/499 passed (6/6 doctests, 490/493 tests) | configuration: reading a line (M2-2, M2-3, M2-6): its grammar, at its token a branch delimiter has no place in a configuration; configuration: the data path: one constructor, refusing what the text cannot say nothing but ArgumentError escapes the text or the constructor, whatever it is given (+1 more) ratio: 4x the instances took 5.2x the reductions |
| M6 | a task's inputs in IEC's order | `text.ex` | 2 | 498/499 passed (6/6 doctests, 492/493 tests) | configuration: reading a line (M2-2, M2-3, M2-6): its grammar, at its token a task line: a name, then single, interval and priority, once each, in that order |
| M7 | each task input once | `text.ex` | 2 | 498/499 passed (6/6 doctests, 492/493 tests) | configuration: reading a line (M2-2, M2-3, M2-6): its grammar, at its token a task line: a name, then single, interval and priority, once each, in that order |
| M8 | one driver per sink | `configuration.ex` | 2 | 496/499 passed (6/6 doctests, 490/493 tests) | configuration: the checks, from the text and from Elixir alike a var_output drives globals, never an input point, one driver a sink; configuration: the data path: one constructor, refusing what the text cannot say the entries read from text and built in Elixir meet the same checks (+1 more) |
| M9 | nothing drives an input point by connection | `configuration.ex` | 2 | 495/499 passed (6/6 doctests, 489/493 tests) | configuration: M2-2's done-when, as far as the text goes (spike) gives the receipt's seven diagnostics for a broken source, one a line; configuration: M2-2's done-when, as far as the text goes (spike) a mis-wired, unknown, undriven-input or mistyped connection names its file and line (+2 more) |
| M10a | a var_input's global agrees in type | `configuration.ex` | 2 | 497/499 passed (6/6 doctests, 491/493 tests) | configuration: M2-2's done-when, as far as the text goes (spike) a mis-wired, unknown, undriven-input or mistyped connection names its file and line; configuration: the checks, from the text and from Elixir alike a var_input has one source, a global or a constant of its type |
| M10b | a var_output's global agrees in type | `configuration.ex` | 2 | 497/499 passed (6/6 doctests, 491/493 tests) | configuration: M2-2's done-when, as far as the text goes (spike) gives the receipt's seven diagnostics for a broken source, one a line; configuration: the checks, from the text and from Elixir alike a var_output drives globals, never an input point, one driver a sink |
| M11 | every var_input connected (decision 7) | `configuration.ex` | 2 | 493/499 passed (6/6 doctests, 487/493 tests) | configuration: the data path: one constructor, refusing what the text cannot say new!/3 is the Elixir face: the configuration, or one ArgumentError with every problem; configuration: the checks, from the text and from Elixir alike every var_input is connected (decision 7), cited at its instance's line (+4 more) |
| M12 | a var_input has one source | `configuration.ex` | 2 | 497/499 passed (6/6 doctests, 491/493 tests) | configuration: the checks, from the text and from Elixir alike a var_input has one source, a global or a constant of its type; configuration: messages name what they are about no message advises declaring a keyword |
| M13 | an interval is at least 1 | `configuration.ex` | 2 | 498/499 passed (6/6 doctests, 492/493 tests) | configuration: the checks, from the text and from Elixir alike a task has a priority, an interval of 1 ms or more or a trigger, in range |
| M14 | a task has a priority | `configuration.ex` | 2 | 498/499 passed (6/6 doctests, 492/493 tests) | configuration: the checks, from the text and from Elixir alike a task has a priority, an interval of 1 ms or more or a trigger, in range |
| M15 | a task has an interval or a trigger | `configuration.ex` | 2 | 498/499 passed (6/6 doctests, 492/493 tests) | configuration: the checks, from the text and from Elixir alike a task has a priority, an interval of 1 ms or more or a trigger, in range |
| M16 | a location's address is integers | `configuration.ex` | 2 | 498/499 passed (6/6 doctests, 492/493 tests) | configuration: the checks, from the text and from Elixir alike a location is a device, `i` or `q`, and an address; one global a location |
| M17 | one global a location | `configuration.ex` | 2 | 498/499 passed (6/6 doctests, 492/493 tests) | configuration: the checks, from the text and from Elixir alike a location is a device, `i` or `q`, and an address; one global a location |
| M18 | a name is declared once, one namespace | `configuration.ex` | 2 | 497/499 passed (6/6 doctests, 491/493 tests) | configuration: the checks, from the text and from Elixir alike a name is not a keyword, has no `.`, and is declared once, in one namespace; configuration: messages name what they are about a refused global does not take its location |
| M19 | a keyword names nothing in a configuration | `configuration.ex` | 2 | 493/499 passed (6/6 doctests, 487/493 tests) | logex: compile/2 compiling stays linear in the program's size; configuration: growth compiling a configuration stays linear in its instances (+4 more) ratio: 4x the instances took 5.18x the reductions |
| M20 | a task's single is a bool | `configuration.ex` | 2 | 498/499 passed (6/6 doctests, 492/493 tests) | configuration: the checks, from the text and from Elixir alike a task's single is a bool global |
| M21 | a var_external agrees in type with its global | `configuration.ex` | 2 | 497/499 passed (6/6 doctests, 491/493 tests) | configuration: M2-4: var_external binds a program to a global by name a var_external has a global of its name and type, checked once a type; configuration: messages name what they are about the loader names a type's own file where a message cites a line of it |
| M22 | nothing writes an input point through var_external | `configuration.ex` | 2 | 497/499 passed (6/6 doctests, 491/493 tests) | configuration: M2-4: var_external binds a program to a global by name nothing writes an input point through a var_external; configuration: messages name what they are about the loader names a type's own file where a message cites a line of it |
| M23 | two var_external writers warn | `configuration.ex` | 2 | 498/499 passed (6/6 doctests, 492/493 tests) | configuration: M2-4: var_external binds a program to a global by name two writers of one global, or a writer and a connection, are a warning |
| M24 | a ton under an event task warns | `configuration.ex` | 2 | 497/499 passed (6/6 doctests, 491/493 tests) | configuration: warnings, which stop nothing M2-6: a ton in a program only an event task runs times across events; configuration: messages name what they are about the loader names a type's own file where a message cites a line of it |
| M25 | an unused global warns | `configuration.ex` | 2 | 493/499 passed (6/6 doctests, 487/493 tests) | configuration: the data path: one constructor, refusing what the text cannot say new!/3 is the Elixir face: the configuration, or one ArgumentError with every problem; configuration: warnings, which stop nothing a global nothing uses, an output point nothing drives, a task that runs nothing (+4 more) |
| M26 | an instance is found by name in one step (growth) | `configuration.ex` | 2 | 498/499 passed (6/6 doctests, 492/493 tests) | configuration: growth compiling a configuration stays linear in its instances ratio: 4x the instances took 11.59x the reductions |
| M27 | a configuration has a program | `configuration.ex` | 2 | 494/499 passed (6/6 doctests, 488/493 tests) | configuration: the checks, from the text and from Elixir alike a configuration has a program; configuration: reading a line (M2-2, M2-3, M2-6): its grammar, at its token a branch delimiter has no place in a configuration (+3 more) |
| M28 | an input point takes no initial value | `configuration.ex` | 2 | 498/499 passed (6/6 doctests, 492/493 tests) | configuration: the checks, from the text and from Elixir alike a global's initial value fits its type, and a located one takes none |
| M29 | a constant fits its var_input | `configuration.ex` | 2 | 498/499 passed (6/6 doctests, 492/493 tests) | configuration: the checks, from the text and from Elixir alike a var_input has one source, a global or a constant of its type |
| M30 | a broken line declares its name | `text.ex` | 2 | 495/499 passed (6/6 doctests, 489/493 tests) | configuration: reading a line (M2-2, M2-3, M2-6): its grammar, at its token a program line: an instance, its type, then `with` and a task; configuration: reading a line (M2-2, M2-3, M2-6): its grammar, at its token a broken line's name is declared, so nothing that names it is reported again (+2 more) |
| M31 | keywords in any case | `text.ex` | 2 | 498/499 passed (6/6 doctests, 492/493 tests) | configuration: reading a line (M2-2, M2-3, M2-6): its grammar, at its token keywords are matched in any case, and names are not folded |
| M32 | the loader takes only .lxcf | `configuration.ex` | 2 | 498/499 passed (6/6 doctests, 492/493 tests) | configuration: the loader takes only a configuration's file, and says what a .ld is |
| M33 | unconnected var_inputs in declaration order | `configuration.ex` | 2 | 495/499 passed (6/6 doctests, 489/493 tests) | configuration: the data path: one constructor, refusing what the text cannot say new!/3 is the Elixir face: the configuration, or one ArgumentError with every problem; configuration: the data path: one constructor, refusing what the text cannot say a member the text can say, the data path takes: `m1.0` is member `0` (+2 more) |
| M34 | diagnostics in line order, unlined last | `configuration.ex` | 2 | 497/499 passed (6/6 doctests, 491/493 tests) | configuration: the loader a type's own mistakes come after the configuration's, each in its file; configuration: the loader a file that cannot be read, or whose name cannot name a configuration |
| M35 | a broken connection counts as connected | `configuration.ex` | 2 | 498/499 passed (6/6 doctests, 492/493 tests) | configuration: reading a line (M2-2, M2-3, M2-6): its grammar, at its token a broken connection still connects its var_input, so it is not reported unconnected |
| M36 | a var_external writer and a connection driver warn | `configuration.ex` | 2 | 497/499 passed (6/6 doctests, 491/493 tests) | configuration: M2-4: var_external binds a program to a global by name two writers of one global, or a writer and a connection, are a warning; Logex.EditTest: growth (F16) accept and its steps stay linear in the program's size |
| M37 | an output point nothing drives warns | `configuration.ex` | 2 | 498/499 passed (6/6 doctests, 492/493 tests) | configuration: warnings, which stop nothing a global nothing uses, an output point nothing drives, a task that runs nothing |
| M38 | a task that runs nothing warns | `configuration.ex` | 2 | 498/499 passed (6/6 doctests, 492/493 tests) | configuration: warnings, which stop nothing a global nothing uses, an output point nothing drives, a task that runs nothing |
| M39 | an unreadable type file is the configuration's, at its line | `configuration.ex` | 2 | 498/499 passed (6/6 doctests, 492/493 tests) | configuration: the loader a type with no file is an unknown type, at the line that first names it, with a did-you-mean among the program files beside it |
| M40 | an entry's name lexes as one name (data path) | `text.ex` | 2 | 498/499 passed (6/6 doctests, 492/493 tests) | configuration: the data path: one constructor, refusing what the text cannot say an entry no line can say raises ArgumentError |
| M41 | the printer writes a task's inputs in IEC's order | `text.ex` | 2 | 498/499 passed (6/6 doctests, 492/493 tests) | configuration: the data path: one constructor, refusing what the text cannot say every configuration the constructor accepts prints to text that reads back to it |
| M42 | an output point takes no initial value | `configuration.ex` | 2 | 498/499 passed (6/6 doctests, 492/493 tests) | configuration: the checks, from the text and from Elixir alike a global's initial value fits its type, and a located one takes none |
| M43 | a var_external with no global is a diagnostic | `configuration.ex` | 2 | 498/499 passed (6/6 doctests, 492/493 tests) | configuration: M2-4: var_external binds a program to a global by name a var_external has a global of its name and type, checked once a type |
| M44 | compile_file points a configuration's file to its loader | `logex.ex` | 2 | 498/499 passed (6/6 doctests, 492/493 tests) | logex: compile_file/1 only a .ld file is a program's, named for its basename less .ld |
| M45 | a configuration keyword is surveyed (naming.md) | `naming.md` | 2 | 4/5 passed | naming: every keyword of a configuration file has been surveyed |
| J1 | a check's diagnostic is at stage :configure | `configuration.ex` | 2 | 498/499 passed (6/6 doctests, 492/493 tests) | configuration: warnings, which stop nothing a check's diagnostic is at stage :configure, a warning too |
| J14 | W2 only for an output point something reads | `configuration.ex` | 2 | 498/499 passed (6/6 doctests, 492/493 tests) | configuration: warnings, which stop nothing an output point nothing uses is unused, not undriven; a trigger is a use |
| J20 | a task's single counts as a use of its global (W1) | `configuration.ex` | 2 | 498/499 passed (6/6 doctests, 492/493 tests) | configuration: warnings, which stop nothing an output point nothing uses is unused, not undriven; a trigger is a use |
| J2 | a global a var_external binds counts as used (W1) | `configuration.ex` | 2 | 496/499 passed (6/6 doctests, 490/493 tests) | configuration: messages name what they are about the loader names a type's own file where a message cites a line of it; configuration: M2-4: var_external binds a program to a global by name nothing writes an input point through a var_external (+1 more) |
| J3 | a connection may come before its program line | `configuration.ex` | 2 | 497/499 passed (6/6 doctests, 491/493 tests) | configuration: the data path: one constructor, refusing what the text cannot say every configuration the constructor accepts prints to text that reads back to it; configuration: the checks, from the text and from Elixir alike a connection names a declared instance's var_input or var_output |
| J4 | a type's var_external mistakes are cited once a type | `configuration.ex` | 2 | 498/499 passed (6/6 doctests, 492/493 tests) | configuration: M2-4: var_external binds a program to a global by name a var_external has a global of its name and type, checked once a type |
| J5 | the loader compiles each type once | `configuration.ex` | 2 | 498/499 passed (6/6 doctests, 492/493 tests) | configuration: the loader a type with no file is an unknown type, at the line that first names it, with a did-you-mean among the program files beside it |
| J8 | a dotted name whose first part is an instance is its member (R41) | `configuration.ex` | 2 | 497/499 passed (6/6 doctests, 491/493 tests) | configuration: the checks, from the text and from Elixir alike a task's single is a bool global; configuration: the checks, from the text and from Elixir alike a var_input has one source, a global or a constant of its type |
| J9 | two names differing only in case are refused | `configuration.ex` | 2 | 498/499 passed (6/6 doctests, 492/493 tests) | configuration: the checks, from the text and from Elixir alike a name is not a keyword, has no `.`, and is declared once, in one namespace |
| J11 | a var_output never drives a constant | `configuration.ex` | 2 | 498/499 passed (6/6 doctests, 492/493 tests) | configuration: the checks, from the text and from Elixir alike a var_output drives globals, never an input point, one driver a sink |
| J13 | compile_file takes exactly .ld, not .LD | `logex.ex` | 2 | 498/499 passed (6/6 doctests, 492/493 tests) | logex: compile_file/1 only a .ld file is a program's, named for its basename less .ld |
| J16 | an interval is at most 2147483647 ms | `configuration.ex` | 2 | 498/499 passed (6/6 doctests, 492/493 tests) | configuration: the checks, from the text and from Elixir alike a task has a priority, an interval of 1 ms or more or a trigger, in range |
| J17 | a priority is at most 2147483647 | `configuration.ex` | 2 | 498/499 passed (6/6 doctests, 492/493 tests) | configuration: the checks, from the text and from Elixir alike a task has a priority, an interval of 1 ms or more or a trigger, in range |
| J18 | a broken line's name enters the namespace | `configuration.ex` | 2 | 496/499 passed (6/6 doctests, 490/493 tests) | configuration: reading a line (M2-2, M2-3, M2-6): its grammar, at its token a program line: an instance, its type, then `with` and a task; configuration: reading a line (M2-2, M2-3, M2-6): its grammar, at its token a broken line's name is declared, so nothing that names it is reported again (+1 more) |
| J19 | a type word or `at` in a global's name place is a missing name | `text.ex` | 2 | 498/499 passed (6/6 doctests, 492/493 tests) | configuration: reading a line (M2-2, M2-3, M2-6): its grammar, at its token a global line: a name, a type, then an initial value or a location |
| J21 | a name of the wrong kind says what it is | `configuration.ex` | 2 | 495/499 passed (6/6 doctests, 489/493 tests) | configuration: the checks, from the text and from Elixir alike a connection names a declared instance's var_input or var_output; configuration: M2-4: var_external binds a program to a global by name a var_external has a global of its name and type, checked once a type (+2 more) |
| N1 | a location where a global is wanted is named as one | `configuration.ex` | 2 | 498/499 passed (6/6 doctests, 492/493 tests) | configuration: the readings of `.` (§4.7): each wrong one named a location is written only after `at`: in a connection or a `single` it is named |
| N2 | a location that begins a connection is named as one | `configuration.ex` | 2 | 498/499 passed (6/6 doctests, 492/493 tests) | configuration: the readings of `.` (§4.7): each wrong one named a location is written only after `at`: in a connection or a `single` it is named |
| N3 | a member of a declared non-instance says what the name is | `configuration.ex` | 2 | 498/499 passed (6/6 doctests, 492/493 tests) | configuration: the readings of `.` (§4.7): each wrong one named a member of something that is not an instance, or of no instance, says so |
| N4 | lines rise from entry to entry | `text.ex` | 2 | 498/499 passed (6/6 doctests, 492/493 tests) | configuration: the data path: one constructor, refusing what the text cannot say lines are nil from Elixir, or rise one entry a line, as the text gives them |
| N5 | no nil line beside a line | `text.ex` | 2 | 498/499 passed (6/6 doctests, 492/493 tests) | configuration: the data path: one constructor, refusing what the text cannot say lines are nil from Elixir, or rise one entry a line, as the text gives them |
| N6 | a connection's instance has no `.` | `text.ex` | 2 | 498/499 passed (6/6 doctests, 492/493 tests) | configuration: the data path: one constructor, refusing what the text cannot say an entry no line can say raises ArgumentError |
| N7 | a member is checked as the text reads it, joined to its instance | `text.ex` | 2 | 498/499 passed (6/6 doctests, 492/493 tests) | configuration: the data path: one constructor, refusing what the text cannot say a member the text can say, the data path takes: `m1.0` is member `0` |
| N8 | the printer puts a lined entry on its line | `text.ex` | 2 | 498/499 passed (6/6 doctests, 492/493 tests) | configuration: the data path: one constructor, refusing what the text cannot say every configuration the constructor accepts prints to text that reads back to it |
| N9 | Text.read refuses a non-binary with ArgumentError | `text.ex` | 2 | 496/499 passed (6/6 doctests, 490/493 tests) | configuration: the data path: one constructor, refusing what the text cannot say nothing but ArgumentError escapes the text or the constructor, whatever it is given; runtime: the public surface (B5) is exactly this: every evaluate clause is private, in Logex.Runtime (+1 more) |
| N10 | Text.keyword? refuses a non-string with ArgumentError | `text.ex` | 2 | 496/499 passed (6/6 doctests, 490/493 tests) | runtime: the public surface (B5) is exactly this: every evaluate clause is private, in Logex.Runtime; configuration: host mistakes every public function of the text and the constructor refuses a host mistake (+1 more) |
| N11 | Text.print checks its entries first | `text.ex` | 2 | 495/499 passed (6/6 doctests, 489/493 tests) | configuration: the data path: one constructor, refusing what the text cannot say an entry no line can say raises ArgumentError; configuration: the data path: one constructor, refusing what the text cannot say lines are nil from Elixir, or rise one entry a line, as the text gives them (+2 more) |
| N12 | the loader's missing type is an unknown type, not a file error | `configuration.ex` | 2 | 498/499 passed (6/6 doctests, 492/493 tests) | configuration: the loader a type with no file is an unknown type, at the line that first names it, with a did-you-mean among the program files beside it |
| N13 | the loader suggests among the program files beside it | `configuration.ex` | 2 | 498/499 passed (6/6 doctests, 492/493 tests) | configuration: the loader a type with no file is an unknown type, at the line that first names it, with a did-you-mean among the program files beside it |
| N14 | no message advises declaring a keyword | `configuration.ex` | 2 | 498/499 passed (6/6 doctests, 492/493 tests) | configuration: messages name what they are about no message advises declaring a keyword |
| N15 | a refused global takes no location | `configuration.ex` | 2 | 498/499 passed (6/6 doctests, 492/493 tests) | configuration: messages name what they are about a refused global does not take its location |
| N16 | a name's case-only hint says names | `configuration.ex` | 2 | 498/499 passed (6/6 doctests, 492/493 tests) | configuration: messages name what they are about a case-only did-you-mean says what is case-sensitive |
| N17 | a type's case-only hint says program types | `configuration.ex` | 2 | 498/499 passed (6/6 doctests, 492/493 tests) | configuration: messages name what they are about a case-only did-you-mean says what is case-sensitive |
| N18 | a member's case-only hint says members | `configuration.ex` | 2 | 498/499 passed (6/6 doctests, 492/493 tests) | configuration: messages name what they are about a case-only did-you-mean says what is case-sensitive |
| N19 | a connection after a broken one still has its source checked | `configuration.ex` | 2 | 498/499 passed (6/6 doctests, 492/493 tests) | configuration: messages name what they are about a connection after a broken one to the same var_input still has its source checked |
| N20 | an address field has no leading zero (one spelling) | `configuration.ex` | 2 | 498/499 passed (6/6 doctests, 492/493 tests) | configuration: the checks, from the text and from Elixir alike a location is a device, `i` or `q`, and an address; one global a location |
| N21 | the loader names the type's file in a message citing its line | `configuration.ex` | 2 | 498/499 passed (6/6 doctests, 492/493 tests) | configuration: messages name what they are about the loader names a type's own file where a message cites a line of it |
| N22 | the loader passes each type's file to the checks | `configuration.ex` | 2 | 498/499 passed (6/6 doctests, 492/493 tests) | configuration: messages name what they are about the loader names a type's own file where a message cites a line of it |
| N23 | W6 covers a task with single and interval | `configuration.ex` | 2 | 498/499 passed (6/6 doctests, 492/493 tests) | configuration: warnings, which stop nothing M2-6: a ton in a program only an event task runs times across events |
| N24 | new!/3 raises every problem, not the first | `configuration.ex` | 2 | 498/499 passed (6/6 doctests, 492/493 tests) | configuration: the data path: one constructor, refusing what the text cannot say new!/3 is the Elixir face: the configuration, or one ArgumentError with every problem |
| N25 | new!/3 refuses a line on an entry from Elixir | `configuration.ex` | 2 | 498/499 passed (6/6 doctests, 492/493 tests) | configuration: the data path: one constructor, refusing what the text cannot say new!/3 is the Elixir face: the configuration, or one ArgumentError with every problem |
| N26 | a location's i or q is lowercase | `configuration.ex` | 2 | 497/499 passed (6/6 doctests, 491/493 tests) | configuration: the readings of `.` (§4.7): each wrong one named a location is written only after `at`: in a connection or a `single` it is named; configuration: the checks, from the text and from Elixir alike a location is a device, `i` or `q`, and an address; one global a location |
| N27 | compile_file names a bare .ld as no program | `logex.ex` | 2 | 498/499 passed (6/6 doctests, 492/493 tests) | logex: compile_file/1 only a .ld file is a program's, named for its basename less .ld |
| N28 | new!/3 checks with the same checks (warnings ride) | `configuration.ex` | 2 | 498/499 passed (6/6 doctests, 492/493 tests) | configuration: the data path: one constructor, refusing what the text cannot say new!/3 is the Elixir face: the configuration, or one ArgumentError with every problem |
| X1 | a type's own diagnostics come after the configuration's (R5) | `configuration.ex` | 2 | 498/499 passed (6/6 doctests, 492/493 tests) | configuration: the loader a type's own mistakes come after the configuration's, each in its file |
| X2 | a failed type's instances are not checked further (R5, C6) | `configuration.ex` | 2 | 497/499 passed (6/6 doctests, 491/493 tests) | configuration: the loader a type's own mistakes come after the configuration's, each in its file; configuration: the loader a type with no file is an unknown type, at the line that first names it, with a did-you-mean among the program files beside it |
| X3 | a configuration's file name is shaped like a name (R6) | `configuration.ex` | 2 | 498/499 passed (6/6 doctests, 492/493 tests) | configuration: the loader a file that cannot be read, or whose name cannot name a configuration |
| X4 | an unknown line has a did-you-mean among the line keywords (R7) | `text.ex` | 2 | 497/499 passed (6/6 doctests, 491/493 tests) | configuration: M2-2's done-when, as far as the text goes (spike) gives the receipt's seven diagnostics for a broken source, one a line; configuration: reading a line (M2-2, M2-3, M2-6): its grammar, at its token a line starts with a keyword or is a connection |
| X5 | a keyword that belongs on a line names that line (R8) | `text.ex` | 2 | 498/499 passed (6/6 doctests, 492/493 tests) | configuration: reading a line (M2-2, M2-3, M2-6): its grammar, at its token a keyword that belongs on a line cannot start one |
| X6 | words after a connection's source are refused (R12, T34) | `text.ex` | 2 | 497/499 passed (6/6 doctests, 491/493 tests) | configuration: reading a line (M2-2, M2-3, M2-6): its grammar, at its token a connection line: a member, then one global or constant; configuration: messages name what they are about a connection after a broken one to the same var_input still has its source checked |
| X7 | a name has no `.` (R14) | `configuration.ex` | 2 | 498/499 passed (6/6 doctests, 492/493 tests) | configuration: the checks, from the text and from Elixir alike a name is not a keyword, has no `.`, and is declared once, in one namespace |
| X8 | a keyword cannot name a program type (R16) | `configuration.ex` | 2 | 498/499 passed (6/6 doctests, 492/493 tests) | configuration: the checks, from the text and from Elixir alike a program line names a type given, by a name that is not a keyword |
| X9 | `with` names a declared task (R21) | `configuration.ex` | 2 | 493/499 passed (6/6 doctests, 487/493 tests) | configuration: the checks, from the text and from Elixir alike `with` names a declared task, before or after its line; configuration: the data path: one constructor, refusing what the text cannot say the entries read from text and built in Elixir meet the same checks (+4 more) |
| X10 | an unlocated global's initial value fits its type (R22) | `configuration.ex` | 2 | 498/499 passed (6/6 doctests, 492/493 tests) | configuration: the checks, from the text and from Elixir alike a global's initial value fits its type, and a located one takes none |
| X11 | a program line's type is one of the types given (R27) | `configuration.ex` | 2 | 496/499 passed (6/6 doctests, 490/493 tests) | configuration: warnings, which stop nothing a check's diagnostic is at stage :configure, a warning too; configuration: the checks, from the text and from Elixir alike a program line names a type given, by a name that is not a keyword (+1 more) |
| X12 | a connection names no path deeper than one member (R30) | `configuration.ex` | 2 | 498/499 passed (6/6 doctests, 492/493 tests) | configuration: the checks, from the text and from Elixir alike a connection names a declared instance's var_input or var_output |
| X13 | a var is internal: it does not connect (R31) | `configuration.ex` | 2 | 496/499 passed (6/6 doctests, 490/493 tests) | configuration: the checks, from the text and from Elixir alike a connection names a declared instance's var_input or var_output; configuration: M2-2's done-when, as far as the text goes (spike) gives the receipt's seven diagnostics for a broken source, one a line (+1 more) |
| X14 | a var_external does not connect (R31) | `configuration.ex` | 2 | 498/499 passed (6/6 doctests, 492/493 tests) | configuration: M2-4: var_external binds a program to a global by name a connection does not reach a var_external |
| X15 | a var_input may read an output point back (R34) | `configuration.ex` | 2 | 494/499 passed (6/6 doctests, 488/493 tests) | configuration: M2-2's done-when, as far as the text goes (spike) the plant as docs/organisation.md §4.4 prints it reads to the same entries; configuration: warnings, which stop nothing a global nothing uses, an output point nothing drives, a task that runs nothing (+3 more) |
| X16 | a var_external is no function block instance (R42, V2) | `declarations.ex` | 2 | 497/499 passed (6/6 doctests, 491/493 tests) | validation: var_external (M2-4): a tag a configuration's global supplies takes no initial value, no instance, and no name a configuration file reserves; validation: var_external (M2-4): a tag a configuration's global supplies from Elixir, the same rules |
| X17 | a broken line's name passes the name checks (R52) | `configuration.ex` | 2 | 498/499 passed (6/6 doctests, 492/493 tests) | configuration: messages name what they are about a broken line's name passes the name checks too: a keyword is refused as one |

### 7.3 Rules no test can see, and why

Every rule of §2 that has code of its own has a mutant above, and every mutant was red.
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
- **§4's state rules and §5.1's run-time rules.** They have no code in this track: the
  spike has no runtime (the brief: "no runtime needed"). They are owed with S's runtime
  and OE-2, and §7.1 lists the tests owed with them.

---

## 8. Landing order, as commits, each green

Each commit lands green with the full gate and its mutation rows in the message
(CLAUDE.md; CONTRIBUTING.md).

**Assumed order.** Track S's M2-1 lands first, with S-synth's `%Logex.Configuration{}`,
`new!/1`, `check/1` (the §4.4 checks on data, S-synth D-1), `start/1` and `cycle/3`.
This track's checks then become rows of S's `check/1`, with the message chosen by §13
Q-20. Where M2-5 lands earlier (inventory §11's order), nothing below changes but commit
13's block-file rule.

**Before any.** org §7 gains this design's decisions as 30 onward: the extension, the
reader, line order, one namespace, one spelling, where a type's mistakes are cited, how a
scan reaches a global, the warnings' channel. org §4.4's receipt is replaced by §3.7's
pinned text, and org §8's `.lcf` line is settled (res §8 item 1).

| # | Item | Commit | Stanzas | Words reserved | Tags or names it breaks |
|---|---|---|---|---|---|
| 1 | M2-2 | naming stanzas `program`, `var_global`, `at` (docs only) | 3 | — | — |
| 2 | M2-2 | `Logex.compile_file/1` takes only `.ld` (R1, F6–F9); `logex_test.exs` flips | — | — | any host that compiles `seal.txt` or `seal`; nothing in the repository (inv §10) |
| 3 | M2-2 | `Logex.Configuration.Text`: reader, `keywords/0`, `entries!/1`, `print/1`; the naming test reads `keywords/0`; reader tests, line endings, host mistakes | — | `program var_global at bool dint` in `.lxcf` (`bool dint` already reserved in `.ld`) | no `.ld` program. A configuration name, task, global or instance spelled like one; no configuration exists yet |
| 4 | M2-2 | the M2-2 checks into S's `check/1`: R14, R25's one spelling, R41, R51–R54, R56–R59, W1, W2; `compile/3`; the seven | — | — | — |
| 5 | M2-2 | the loader `compile_file/1` (R2–R6, R4, R51) | — | — | — |
| 6 | M2-2 | the round trip (R49), totality (R60), `new!` faces agreed with S (R61), growth (R50) | — | — | — |
| 7 | M2-2 | done-when end to end on S's `cycle/3` | — | — | — |
| 8 | M2-2 | documents (§9) | — | — | — |
| 9 | M2-3 | stanzas `task`, `interval`, `priority`, `with` | 4 | — | — |
| 10 | M2-3 | task lines and `with` turned on (R11, R17–R19, R21, W3) | — | `task interval priority with` in `.lxcf` | a configuration's names spelled like them |
| 11 | M2-3 | done-when (100 and 20 runs) and documents | — | — | — |
| 12 | M2-4 | B5's one IR walk, with a public "what a program writes" and "which timers it runs"; no behaviour change | — | — | — |
| 13 | M2-4 | stanza `var_external`; the section row and its `.ld` rules (R42, R43, R46); a block file refuses `var_external` if M2-5 has landed (§13 Q-18) | 1 | `var_external` in every `.ld`, in any case | any program with a tag named `var_external` (none in the repository); a `var_external` named like a `.lxcf` keyword (V3) |
| 14 | M2-4 | binding checks and writer warnings (R44, R45, W4, W5) into S's `check/1` | — | — | — |
| 15 | M2-4 | one copy at run time (§5.1, S's scan step), done-when, documents | — | — | — |
| 16 | M2-6 | stanza `single`; `single` lines turned on (R20, W6a, W6b); S's `Task` gains `single` | 1 | `single` in `.lxcf` | a configuration's names spelled `single` |
| 17 | M2-6 | edges at run time (§5.1), done-when, documents; the trigger's rule moved out of `initial_env/1`'s doc (§4) | — | — | — |

The spike reserves all ten words at once (§11 D2). Commits 3, 10 and 16 stage them, as
PLAN does. Before commit 10 a `task` line is refused as an unknown configuration line,
with T2's message. Before commit 16 the word `single` reads as an unknown task input,
with T10's message.

---

## 9. Documents each commit stales

| Commit | README.md | CLAUDE.md | PLAN.md | organisation.md | naming.md |
|---|---|---|---|---|---|
| 1, 9, 13, 16 | — | — | — | — | the stanzas, appended; the intro sentence on what `naming_test.exs` checks (`docs/naming.md:8`) gains configuration keywords at commit 3 |
| 2 | `compile_file/1`'s description (README.md:12, 177) | `lib/logex.ex`'s Key Files entry (CLAUDE.md:22-24): only `.ld` | M2-2 status; `PLAN.md:939`'s "compile_file/1 names the …" | §6.2 M2-2 | — |
| 3–6 | syntax list for configuration lines (README.md:26-47); the "Settled, not yet landed" bullet (README.md:131-140) | Key Files: `configuration.ex`, `configuration/text.ex`, `configuration_test.exs`; the "Nothing compiles a user's program to BEAM" bullet's front-end list | B5's module list; M2-2 status; §5's organisation bullet | §4.4: `.lcf` → `.lxcf` (18 occurrences), the receipt replaced by §3.7, the loader's did-you-mean; §4.7's location reading message; §4.8's table heading; §8's `.lcf` unverified line settled; IEC-14 beside org:434 | — |
| 7, 8 | a worked configuration example, its output re-run | Tests line: `configuration_test.exs`; `end_to_end_test.exs` gains configurations | M2-2 done | §6.2 | — |
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
- **Not departures, recorded:**
  - org §4.4's seven messages are "pinned by no test" (org:449) and are reworded (§3.7).
  - "Declare it first" in that receipt is not a decided rule, and the decided plant needs
    forward references (`trip` names `estop` on line 4; `estop` is declared on line 6).
  - Output points take no initial value, as org §4.4's line table gives none with `at`.
  - The `var_external` name rule implements org §4.8's "legal in both kinds" at the `.ld`
    compile.
  - Research finding IEC-14 contradicts org:434's "No IEC rule on an unconnected program
    input was found"; decision 7 still stands, with a different reason (res §8 item 4).
  - W6b widens T1's W6 to what org §4.6's caveat says, so it narrows nothing decided.

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
  R50's growth test covers accepted configurations only.
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

---

## 13. Decisions for the maintainer

Each question gives 2–4 options with their consequences, a recommendation and why, and
the item it must be decided before. "S" marks a question that track S's merged design
also answers.

**Q-1 · The extension** (M2-2; decision 3; T1-Q1). *Before M2-2's first code commit.*
- (a) `.lxcf`: "logex configuration file", no other reading, zero hits on GitHub,
  fileinfo, filext, file-extension.info and Linguist (res EXT-8).
- (b) `.ldcfg` or `.ldcf`: pairs visibly with `.ld`. But "ld" is the GNU linker's name,
  so `plant.ldcfg` reads as a linker configuration, the clash that ruled out `.lcf`.
  JT1 notes `.ld` already has that clash.
- (c) Keep `.lcf`: CodeWarrior's, CudaText's, Loon's and Archicad's (res EXT-1..6); a
  rename later is a migration.
- *Recommend (a).* It is the one choice with no other reading. In the spike it is one
  module attribute.

**Q-2 · How a configuration file is read** (M2-2; T1-Q2). *Before commit 3.*
- (a) A recursive descent over `Logex.Lexer`'s tokens (built). Line-shape mistakes get
  columns, and `( )` is refused at its token. The `.ld` grammar, golden record and
  `@required_shapes` are untouched.
- (b) Through `Logex.Parser`'s rung tree, as declaration lines are (S-synth §5, from S2).
  Less code, but no column, a `( )`-only line has no line to cite, and groups are
  refused element by element.
- *Recommend (a)*, as JT1 does: a configuration has no rungs.

**Q-3 · The stage of a configuration diagnostic** (M2-2; T1-Q3; S-synth Q-16, S). *Before
commit 4.*
- (a) A new `:configure` (built here and in S-synth). (b) `:validate`, with only the file
  telling them apart.
- *Recommend (a).* A stage says which stage found it (`lib/logex/diagnostic.ex:9-17`).
  Now pinned (R47, mutant J1).

**Q-4 · Line order** (M2-2, M2-3, M2-6; T1-Q4). *Before commit 4.*
- (a) Names resolve over the whole file (built). org §4.4's plant compiles as written.
- (b) Declare before use. The decided plant becomes an error (line 4 names `estop`, line
  6 declares it), and the example must be reordered.
- *Recommend (a).* The decided example needs it.

**Q-5 · One namespace** (M2-1, M2-2; T1-Q5; S-synth Q-7, S). *Before M2-1's
constructor.*
- (a) Tasks, globals and instances in one namespace, a case-only twin refused (built here
  and in S-synth). (b) One per kind.
- *Recommend (a)*: `get(rt, "m1")` and `single m1` cannot be ambiguous.

**Q-6 · Where a program type's mistake is cited** (M2-4; T1-Q6). *Before commit 14.*
- (a) Once a type, at its first instance's `program` line in the configuration file,
  naming the type's `.ld` file and line in the message when the loader read it (built,
  R51). Every configuration diagnostic stays in the configuration file, and F15 is not
  needed for it.
- (b) At the `.ld` declaration, in the program's file. Needs F15's `file` on
  `%Logex.Program{}`, and the message must name the configuration.
- (c) At every instance: one fix, many messages.
- *Recommend (a).* F15 is still owed for `Logex.Edit` (org §7 F15) and should land in
  M2-2 anyway; with it, (a)'s message names the file from the program, not from the
  loader.

**Q-7 · An output point's initial value** (M2-2; T1-Q7; S-synth Q-10, S). *Before
commit 4.*
- (a) None (built here and in S-synth; org §4.4's line table gives none). (b) Allowed,
  written before `at`: one more line shape and one more rule for OE-2.
- *Recommend (a)*: strict and reversible.

**Q-8 · The location grammar and its spelling** (M2-2; T1-Q8; S-synth Q-9, S). *Before
commit 4.*
- (a) A device of one name part, `i` or `q` lowercase, one or more integer fields with no
  leading zero; one global a location (built, changed from T1 to agree with S-synth).
  One spelling per point, so a printer and a diff need no normalising.
- (b) T1's: fields compared as numbers, so `panel.q.00` is `panel.q.0`. Two spellings of
  one point.
- (c) Dotted devices, or `I`/`Q` in any case. Ambiguous where `i` or `q` sits.
- *Recommend (a).* Each part can be widened later without breaking a plant. An oddity
  both tracks share: `panel.i.1` and `panel.i.1.0` are two locations (IEC's rule
  unverified).

**Q-9 · A task line's order and ranges** (M2-3; T1-Q9; S-synth Q-8, S). *Before commit
10.*
- (a) IEC's order (`single`, `interval`, `priority`), each once; priority 0..2147483647;
  interval 1..2147483647 (built here and in S-synth).
- (b) Any order: two spellings of one line.
- (c) Priority 0..31, as CODESYS: an arbitrary bound IEC does not state (inv U24).
- *Recommend (a).*

**Q-10 · How a scan reaches a global through `var_external`** (M2-4; T1-Q10). *Before
commit 13.*
- (a) G1: a private scheduler entry, and `instance/1` refuses a program with a
  `var_external`. Faithful to IEC, but it bars `scan/2` and `Logex.Edit` on such a
  program.
- (b) G2: `call/4` unchanged. The scheduler merges each global into the env before a
  scan and splits it off after; a lone instance keeps the tag at 0 (built; S-synth §5
  agrees). One copy, no public contract change. A lone program's `var_external` cannot
  be driven by its host. An edit's switch needs Q-17's rule.
- (c) G3: `call/4` takes a `var_external` as an input and returns it with the outputs.
  Testable alone, but M1-5's pinned input contract (`lib/logex/runtime.ex:303-308`) and
  `scan/2`'s outputs change.
- *Recommend (b).* It is the smallest change that keeps one copy and keeps `call/4` as
  the step.

**Q-11 · A global both driven by a connection and written through `var_external`**
(M2-4; T1-Q11). *Before commit 14.*
- (a) A warning (built, W5): the configuration compiles, and the later write in a cycle
  wins. (b) An error: stricter than org §4.4's own rule for two `var_external` writers.
- *Recommend (a)*: org §4.4 makes a `var_external` write a warning because it is visible
  only in the IR, whatever the other writer is.

**Q-12 · Which warnings a configuration carries, and where** (M2-2, M2-4, M2-6; T1-Q12,
T1-Q17; JT1 G1, G4). *Before commit 4.*
- (a) W1–W6 on `%Logex.Configuration{}.warnings` (built), reading "M1-5's `warnings:`
  channel" (org:432; org:650) as "warnings carried on the compiled value as
  `%Diagnostic{severity: :warning}`".
- (b) As (a), plus W7: a global something reads and nothing writes (JT1 G4). It catches
  `single go` on a global with initial value 1, which fires once and never again. But it
  also fires on an unlocated global used as a fixed parameter, which is legitimate until
  `var_config` exists.
- (c) The literal reading: on `%Logex.Program{}.warnings`. Impossible, since a program's
  warnings see one program, never two instances or a task. This is departure D1 if it
  was meant.
- *Recommend (a)*, with W7 deferred to `var_config`.

**Q-13 · W6 for a task with `single` and `interval`** (M2-6; JT1 G1). *Before commit 16.*
- (a) Both kinds of event task warn, with two wordings (built, W6a and W6b). This follows
  org §4.6's caveat, "a `ton` in an event-task program".
- (b) Only `single` alone (T1's): a combined task's timer also stops counting periods
  while its trigger is 1, so this narrows the decided caveat.
- *Recommend (a).*

**Q-14 · `single` with `interval`** (M2-6; T1-Q14). *Before commit 17.*
- (a) §5.1's rules: phase anchored at start; periods under a high trigger skipped and not
  counted; one run a cycle; an edge run does not move the phase.
- (b) Re-anchor the phase when the trigger falls: a run at once on the fall, which IEC
  does not ask for.
- (c) Count suspended periods as overlaps: reports misses that are not misses.
- *Recommend (a)*: no added state and no false overlap. There is no free-software
  precedent (res MAT-2).

**Q-15 · An event task's trigger across a restart and an edit** (M2-6, OE-2; T1-Q15).
*Before commit 17; OE-2.*
- (a) A restart resets the last sample to 0; an edit keeps it; a change of a task's
  `single`, or adding or removing its `interval`, is refused (§4).
- (b) Allow those changes while running: needs a rule decision 19 does not give.
- *Recommend (a)*: decision 19 allows only interval and priority changes.

**Q-16 · `next_due` when OE-2 changes an interval** (M2-3, OE-2; T1-Q16; S-synth Q-23,
S). *Before OE-2's design pass; M2-3's documents state it.*
- (a) `min(next_due, now + new interval)`. A shorter interval takes effect within one new
  period, and a longer one runs once more on the old phase. Neither adds a run.
- (b) Keep `next_due`; the next run steps by the new interval (S-synth's recommendation).
  A change from 1,000 ms to 10 ms can wait up to 1,000 ms before it takes effect.
- (c) Re-anchor at the switch: an extra run at the switch.
- *Recommend (a).* The two tracks disagree here, so one answer is needed. (a) bounds the
  wait by the new interval and adds no run, which (b) does not.

**Q-17 · How an online edit's switch sees an instance's `var_external`** (M2-4, OE-2; JT1
G2). *Before OE-2's design pass; stated in M2-4's documents.*
- (a) The configuration's switch merges each global into the instance's env before the
  per-instance switch (fix F5) and splits it off after, exactly as a scan does (§5.1).
  `Logex.Edit` is unchanged and sees a full env.
- (b) `Logex.Edit` skips `var_external` tags in its plans. That is a second rule for one
  section, and OE-1's lone-instance behaviour (decision 25) changes.
- (c) Nothing: under G2, today's `Edit` reports the external as `{:added, "estop", 0}`
  and writes a second copy into the env (JT1 `p9b_g2_edit.log`), which breaks "one copy
  of each global".
- *Recommend (a)*: one rule, merge and split, around every per-instance step.

**Q-18 · `var_external` in a function block file** (M2-4, M2-5; JT1 G3; inv Q4.9).
*Before whichever of M2-4 and M2-5 lands second.*
- (a) Refused in a block file, with a located diagnostic, until decided. A block takes a
  global through a `var_input` operand. F2 recommends the same (F2.md:549-553).
- (b) Bound through the containing program's instance. That needs the one IR walk to
  reach `cal` bodies, and a write path out of a body.
- *Recommend (a)*: strict and reversible. IEC allowing VAR_EXTERNAL in a FUNCTION_BLOCK is
  unverified (inv U19).

**Q-19 · `compile`'s argument order, and `new!`'s shape** (M2-2; T1-Q19; S-synth Q-24,
S). *Before commit 4.*
- (a) org §4.4's `compile(name, source, programs)` (built), with `new!(name, entries,
  programs)` beside it. Keeps the decided text.
- (b) `compile(source, programs, name: name)`, as `Logex.compile/2` and S-synth Q-24
  recommend, with S-synth's `new!(keyword)`. Consistent with `Logex.compile/2`, but it
  changes decided text, so it needs the maintainer.
- *Recommend (a)* for `compile`, since it is decided and the difference is cosmetic, and
  S-synth's `new!/1` keyword form for the Elixir face, since that is what the data path's
  users will write. The spike's `new!/3` is a stand-in.

**Q-20 · Where the checks live, and whose words land** (M2-1, M2-2; JT1 §7 "what T1 asks
of S's constructor"; S). *Before commit 4.*
- (a) S-synth's `check/1` is the one validator (S-synth D-1). This track's checks become
  its rows. Where both check a rule, the configuration file's reader-facing words win
  rule by rule, since the text is the saved form (T1 §21). The reader passes placeholders
  (C5) and failed types (C6) in.
- (b) As (a), but the reader filters `check/1`'s diagnostics that name a broken line's
  name, so S's struct contract does not grow placeholders.
- (c) Two validators, one for data and one for text. Two messages for one mistake; this
  breaks org §4.4 "Loading" ("the same checks").
- *Recommend (a).* Placeholders as an input are simpler than filtering messages by name.
  Examples of the words to choose: T's ``` `<n>` is declared twice: first on line <l>, as
  a global``` against S's ``` `<n>` is already the name of a global (line <l>): tasks,
  globals and program instances share one namespace```; T's ``the interval of `t2` is
  0: …`` against S's ``task `t2`: an interval is 1 to 2147483647 ms, found 0``.

**Q-21 · Lines from Elixir, and the round trip** (M2-2; JT1 D2, graft 4; S-synth Q-20,
S). *Before commit 3.*
- (a) Lines are all nil or strictly rising; `new!` refuses any line; the printer places a
  lined entry on its line, so the round trip is exact (built).
- (b) Lines are positive or nil, in any order (S-synth CF-4), and the round trip compares
  "but for lines". Simpler for S's `check/1`, but then the data path accepts an order no
  file gives.
- *Recommend (a)*: the data API then refuses exactly what the text cannot say.

The questions T1 raised and that are not repeated above stand as T1 recommended, with
JT1's agreement (JT1 §8):
- T1-Q13: "what a program writes" is a function over the IR, landed with the walk
  extraction (§8 commit 12), not a field on `%Logex.Program{}` that a hand-built program
  could get wrong.
- T1-Q18: one diagnostic for each instance with unconnected var_inputs.
- T1-Q20: a printer now (built, R49).
- T1-Q21: exactly `.ld`, case-sensitive (built, mutant J13).
