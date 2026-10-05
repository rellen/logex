# JT1 · Judging T1: the configuration text, globals and event tasks (M2-2, M2-3, M2-4, M2-6)

Label JT1, track T of the Milestone 2 design pass. Written 2026-10-02 against
`/home/user/logex` at `47319f7`. This pass did not modify that repository. One design was
judged, T1 (`scratchpad/m2/T1.md`, `scratchpad/m2/T1.patch`).

**Lens: critic.** I checked T1 against these sources:
- `docs/organisation.md` §4.4–4.8;
- decisions 3, 5, 6, 7, 10 and 11;
- `scratchpad/m2/research.md`;
- the lexer as it stands.

I ran T1's probe. I then looked for every case its reader or checks get wrong or leave
unspecified.

**Citations.**
- `org` is `docs/organisation.md` and `PLAN` is `PLAN.md`, both at `47319f7`.
- `inv` is `scratchpad/m2/inventory.md` and `res` is `scratchpad/m2/research.md`.
- The spike's code is cited by function name.

**What counts as a defect.** Every defect below was reproduced by a probe in
`scratchpad/m2/JT1-probe/`, and its output is quoted. Where a defect is a matter of
rules, it is quoted against a decided rule. Anything I could not check is marked
"unverified".

**How to rerun.**
1. Apply `T1.patch` to a fresh copy of `47319f7` (`git apply --index`).
2. `source scratchpad/toolchain/env.sh`.
3. In that copy, run `mix run scratchpad/m2/JT1-probe/<probe>.exs`.

The copy I judged in, `scratchpad/m2/JT1-T1-work`, has been deleted as the brief asked.

---

## 0. The verdict

| Design | Score | In one line |
|---|---|---|
| **T1** | **7.5 / 10** | **Winner** (the only design), with the changes in §6. |

**Why T1 wins.**
- The reader is a sound, small recursive descent over the unchanged lexer.
- Every edge case in my lens's list reads correctly.
- The done-when and the gate reproduce exactly.
- The 21 open questions are honest and well argued.

**Why it is not higher.** I reproduced eleven defects and five gaps. None is fatal, but
four break a written rule:
- **§4.7.** A raw location in a connection is misdiagnosed as an instance's member.
- **The data path.** It accepts entries that no text can say, so R48 and R49 are false
  for them. One entry the text *can* say raises "not an entry a configuration file can
  say".
- **The public API.** `Logex.Configuration.Text`'s public functions let
  `FunctionClauseError` and `KeyError` escape (CLAUDE.md).
- **§4.4's "with a did-you-mean".** The loader drops it for an unknown program type.

**Untested rules.** Three of the rules T1 implements are pinned by no test. I found them
by reverting each one alone.

---

## 1. What I ran

### 1.1 The gate, on my own copy (Elixir 1.20.4 / OTP 28)

- `git apply --index T1.patch` applied cleanly to a fresh copy of `47319f7`.
- Every changed file is byte-identical to `T1-work` (`cmp` over the 12 files).
- Receipt: `JT1-probe/T1-gate.log`.

| Command | Exit |
|---|---|
| `mix format --check-formatted` | 0 |
| `mix compile --force --warnings-as-errors` | 0 |
| `MIX_ENV=test mix compile --force --warnings-as-errors` | 0 |
| `mix test --warnings-as-errors` | 0, `Result: 483 passed (6 doctests, 477 tests)` |

This matches T1's claim.

### 1.2 T1's own probes

- `T1-probe/p1.exs` reads the plant into 40 entries and loads it from disk. Exit 0.
- `T1-probe/p2.exs` gives exactly seven diagnostics, on lines 7, 9, 11, 12, 14, 15
  and 16. Exit 0:

```
line 7, column 1: unknown configuration line `progam` — did you mean `program`?
line 9: no task `medium`: declare it with a `task` line, as in `task medium interval 10 priority 1`
line 11: `m1` is a `motor`, which declares no `strat` — did you mean `start`?
line 12: `pb` is an input point (line 2): `m1.motor`, a var_output, cannot drive it
line 14: `k` is already driven by `m1.run_lamp` (line 13)
line 15: `m1.fault` is internal to `motor` (declared `var`): only a var_input or var_output connects
line 16: `m1.speed_sp` is a dint, but `k` is a bool (line 3)
```

I also cut org §4.4's plant out of `docs/organisation.md` verbatim, keeping its
`// plant.lcf` comment, rather than using the test's copy. It reads into 40 entries, and
it compiles against the §4.2 motor with no diagnostic and no warning
(`JT1-probe/p1_reader.log`).

### 1.3 Reverting T1's rules

**A sample of T1's own table.** I re-ran 8 of T1's 46 mutants on my copy, with T1's own
script pointed at it (`JT1-probe/t1_mutate_copy.py`, `t1-sample.log`): M5, M17, M22,
M28, M30, M35, M42 and M44. Every one went red, exit 2, with the tests T1's §15 names.

**Rules T1's table does not list.** I reverted 16 more, each alone, with the full suite
(`JT1-probe/mutate.py`, `mutate.log`). These runs used plain `mix test`, because a few
mutants leave an unused function behind and `--warnings-as-errors` would fail them for
the wrong reason. No surviving run printed a compile warning.

**13 went red:**
- J2: a var_external use counts for W1.
- J3: a connection may come before its program line.
- J4: a type's mistakes are cited once per type.
- J5: the loader compiles each type once.
- J8: R41's message.
- J9: case-only twins.
- J11: a var_output never drives a constant.
- J13: `.LD` is refused.
- J16 and J17: the interval and priority upper bounds.
- J18: placeholders enter the namespace.
- J19: T18.
- J21: C25.

**3 stayed green** (defect D7):

| Mutant | Rule reverted | Result |
|---|---|---|
| J1 | a check's diagnostic carries `stage: :configure` (changed to `:validate`) | exit 0, 483 passed |
| J14 | W2 fires only for an output point something reads (filter removed) | exit 0, 483 passed |
| J20 | a task's `single` counts as a use of its global, for W1 | exit 0, 483 passed |

`JT1-probe/p5_mutant_effect.exs` shows that each surviving mutant changes what a caller
sees:

```
--- unmutated
trigger used only by single: ok []
output point nothing uses: ok ["line 1: warning: `k` is declared but nothing uses it"]
a check's stage: [configure: "line 1: no task `nope`: ..."]
--- J1+J14+J20 applied
trigger used only by single: ok ["line 1: warning: `go` is declared but nothing uses it"]
output point nothing uses: ok ["line 1: warning: `k` is declared but nothing uses it", "line 1: warning: `k` is an output point, but nothing drives it: it stays at 0"]
a check's stage: [validate: "line 1: no task `nope`: ..."]
```

### 1.4 Probes

Each probe and its log is in `JT1-probe/`:

| Probe | What it covers |
|---|---|
| `p1_reader` | comments, blank lines, line endings, keyword case, cross-kind names, duplicates, line order, located points with initial values, lex errors, line shapes |
| `p2_data` | the data path, host mistakes on the public functions, `compile_file` names, `var_external` in `.ld`, a section change under `Logex.Edit` |
| `p3_checks` | case-only names, the warnings, M2-4's and M2-6's checks |
| `p4_dot` | §4.7's readings of `.` |
| `p6_crosskind` | `.ld` tags named like configuration keywords |
| `p7_roundtrip` | lined entries and the printer |
| `p8_loader` | an unknown type on disk |
| `p9`, `p9b` | G2's state against `Logex.Edit` |

---

## 2. What T1 gets right, reproduced

### 2.1 The lens's checklist

Every row passed (`p1_reader.log`, `p6_crosskind.log`).

| Case | Result |
|---|---|
| **Comments** | A comment glued to the last token (`priority 1// note`) and a file of nothing but comments both work. Leading blank and comment lines work too, and the first entry keeps its true line (6). A comment-only or empty file gives `this configuration declares no \`program\`: it would run nothing` (line nil). |
| **Blank lines and indentation** | Coalesced by the lexer. Tab indentation reads the same as spaces. |
| **CRLF and lone CR (B8)** | The verbatim plant with every `\n` replaced by `\r\n` reads to the same 40 entries and lines (`true`). With every `\n` replaced by `\r` it also reads the same (`true`). *A mix of `\r` and `\n` with an empty line between is CRLF to the lexer by design, so that probe line was my own mistake, not T1's.* |
| **Keyword case** | `TASK fast INTERVAL 10 PRIORITY 1`, `PROGRAM … WITH …`, `VAR_GLOBAL pb Bool AT panel.i.0` and `Program` all compile. `var_global Task bool` and `var_global WITH bool` are refused as keywords. A location's `I`/`Q` is refused with a lowercase hint (`panel.I.0` → "`panel.i.0`"). |
| **A word reserved in the other file kind** | `.ld` words used as configuration names compile: `task ton …`, `var_global ote bool`, `var_global var_external bool`, `program xic motor with ton`, `xic.start ote`. `.lxcf` words used as `.ld` tags compile and connect: `var_input task`, `var_input with`, `var_output priority`, then `m1.task 0`, `m1.priority q`. A `var_external` named like a configuration keyword is refused in any case (`Single`, `SINGLE`), per org §4.8. |
| **Duplicate declarations** | A task twice, a task and a global of one name, an instance twice, a case-only twin, a var_input connected twice and one var_output to one global twice are each refused with one message citing the first line. |
| **Ordering of lines** | Connections before their `program` line, with the task after them, compile. So does a global declared after its use, and the plant's `single estop` before `var_global estop`. J3 shows a test pins the connection case. |
| **Located input with an initial value** | `var_global pb bool 1 at panel.i.0` → "`pb` is an input point: its value comes from the input image, so it takes no initial value". An output point with one gets C14. A value after `at` gets T25 at its column (`line 1, column 33: unexpected \`1\` after the declaration of \`pb\``). |
| **Lex errors** | `at %ix0.0` and `dint -5` each give one located `:lex` diagnostic, and stop the read, as `Logex.compile/2` does. |
| **Addresses compared as numbers** | `panel.i.07` collides with `panel.i.7`, and a test pins `panel.q.00`. |

### 2.2 The rest of the design

**Grammar and reader.**
- The reader is a real hand-written descent, decided on the next token, as
  `Logex.Parser` is.
- It reuses the lexer whole and leaves the `.ld` front end, the golden record and
  `@required_shapes` untouched. That is the right answer to T1-Q2.
- Each line-shape mistake is located at its token, with a column.

**The decided rules are implemented.**
- org §4.4's checks: input points, one driver per sink, decision 7, types at both ends,
  only a var_input or var_output connects, unknown names, tasks, events.
- M2-4's binding checks.
- §4.8's per-kind reservation, including the "legal in both kinds" rule for a
  `var_external` name, checked at the `.ld` compile.

**Points beyond the brief.**
- A printer with a round-trip property.
- A growth test in reductions.
- Nine naming stanzas that argue the `panel.q.0` coinage plainly, as org §4.5 asks.
- A careful state table (§11) for every new piece of state across a start, a cycle, a
  restart and an OE-2 edit.

**Writing rules.** No forbidden vendor or product name appears in T1.md, the stanzas,
`lib/` or `test/`. I grepped the patch and the document.

**Citations.** Most line references check out at `47319f7`, among them `lexer.ex:92-96`,
`:121-138`, `declarations.ex:81,88`, `diagnostic.ex:9-17`, `runtime.ex:270-289`,
`:303-308`, `compiler.ex:801` and `logex_test.exs:270-279`. The one wrong reference is
D11.

---

## 3. Defects, reproduced, most severe first

### D1 · A raw location or an access path in a connection is called "an instance's member" (org §4.7)

`p4_dot.log`:

```
== raw location as a connection source       (var_global pb bool at panel.i.0 / x1.go panel.i.0)
  line 3: `panel.i.0` is an instance's member: instances share a value only through a global, which one drives and the other reads
== raw location as a connection sink          (x1.done panel.q.0)
  line 3: `panel.q.0` is an instance's member: ...
== raw location as single                     (task t single panel.i.0 priority 0)
  line 1: `panel.i.0` is an instance's member: ...
```

`panel` is not an instance, so the message is false.

**The rules it breaks.**
- org §4.7: *"Position decides what it means, and each wrong reading gets a diagnostic
  that names it"*. The location reading is legal *"only after `at` in a `.lcf`"*.
- org §5 rules out exactly this case: *"Direct representation `%IX0.0` and raw addresses
  in connections: not adopted"*. An IEC user writing Table 49 8a's `OFF_PB := %I0.0` in
  logex form is the person who will hit it.

**Where it happens.** `undeclared(true, …)` in `configuration.ex` treats every dotted
unknown name as R41's case.

**Fix.** A dotted name whose first part is a declared instance is R41. One whose first
part is no instance and that parses as a location gets a message naming the reading, for
example:

``"`panel.i.0` is a location: a location is written only after `at`, on a `var_global` line; connect the global at it, `pb` (line 1)"``

Any other dotted name gets "no instance `<first part>`".

### D2 · The data path accepts entries no text can say, and refuses one the text can

`p2_data.log`, `p7_roundtrip.log`:

```
== two entries on one line          ok, 1 instance(s)
== lines decreasing                 ok, 1 instance(s)
== lines mixed nil and integer      ok, 1 instance(s)
check/3 on lines 9,4,4,2,1: :ok
print then read gives the same entries: false
read back: {:ok, [{:program, 1, …}, {:connection, 2, …}, … {:connection, 5, …}]}
text says member 0: {:ok, [{:connection, 1, %{member: "0", instance: "m1", to: {:constant, 5}}}]}
Elixir member "0": ArgumentError not an entry a configuration file can say: a name lexes as one name token, got: {:connection, nil, %{member: "0", …}}
```

**The claims this falsifies.**
- T1's R48 says *"An entry no line could say raises `ArgumentError`"*.
- T1's R49 says *"Every configuration the constructor accepts prints to text that reads
  back to the same entries"*. Its test (`configuration_test.exs`, "every configuration
  the constructor accepts prints…") generates only `nil`-line entries, so it never
  meets this case.

**The rules it breaks.**
- CLAUDE.md: *"the data API refuses what the text cannot say"*.
- Decision 28's full entry check, which T1 invokes for R48. For programs it requires
  *"each rung on a line after the last"*.

**The reverse case.** The member `"0"` is something the text says (`m1.0 5` reads as
member `"0"`). From Elixir it raises a message that is false: "not an entry a
configuration file can say".

**Fix.**
- `entries!` refuses lines that are not all nil or strictly increasing, with a pinned
  message.
- A connection's member is checked as what follows the first `.` of one name token, by
  lexing `instance <> "." <> member`.
- R49's generator also draws lined entries.

### D3 · `Logex.Configuration.Text`'s public functions let non-`ArgumentError` exceptions escape

`p2_data.log`:

```
== Text.read(:atom)                          RAISED FunctionClauseError: no function clause matching in Logex.Configuration.Text.read/1
== Text.print(:atom)                         RAISED FunctionClauseError: … Text.print/1
== Text.print([{:declared, 1, %{…}}])         RAISED FunctionClauseError: … Text.printed/1
== Text.print([{:task, 1, %{name: "x"}}])     RAISED KeyError: key :single not found in: %{name: "x"}
== Text.keyword?(1)                          RAISED FunctionClauseError: … Text.keyword?/1
```

**The rule it breaks.** CLAUDE.md, Conventions: *"a mistake by the host is an
`ArgumentError`, raised, whose message a test pins. Nothing else may escape the public
API"*. T1 makes `Text` public: it pins `[keyword?/1, keywords/0, print/1, read/1]` in
`runtime_test.exs`'s surface test. JS1 judged the same escape a hard defect in S1 and S3.

**Fix.**
- `read/1` and `keyword?/1` get catch-all clauses raising pinned `ArgumentError`s.
- `print/1` runs the constructor's `entries!` first, so an entry it cannot print is
  refused with §7.1's H9.
- Adopt S2's CF-29 totality property (§7) over `Text` too.

### D4 · The loader drops §4.4's did-you-mean for an unknown program type

`p8_loader.log`. The source has `program m1 motor` and `program m2 motr`, with `motor.ld`
in the directory:

```
[file] <dir>/plant.lxcf: line 3: no program type `motr`: <dir>/motr.ld cannot be read: no such file or directory
pure seam, same source:
[configure] line 3: unknown program type `motr` — did you mean `motor`?
```

**The rule it breaks.** org §4.4, Checks: *"Unknown names. An unknown task, program type,
instance or member is a located diagnostic with a did-you-mean."* The loader is the path
most users take, and there the suggestion is lost. One mistake also gets two stages
(`:file` against `:configure`), depending on how it was loaded.

**Fix.** When `<type>.ld` is missing, suggest among the types that loaded and the `*.ld`
basenames beside the configuration. Keep the reason the file could not be read only for
a file that exists but cannot be read.

### D5 · Messages that tell the user to write a line the reader then refuses

`p1_reader.log`, `p6_crosskind.log`:

```
line 2: no global `task`: declare it, as in `var_global task bool`
line 3: no global `bool`: declare it, as in `var_global bool bool`
line 1: no global `at`: declare it, as in `var_global at bool`            (task t single at priority 0)
line 1: no task `program`: declare it with a `task` line, as in `task program interval 10 priority 1`
line 4: no instance `task`: declare it, as in `program task motor`        (task.start 0)
```

Each line the message suggests is itself refused, by C1 or T18. **Fix.** In `no/3`,
check `Text.keyword?/1` first: "`task` is a keyword of a configuration file, and no
global can be named so".

### D6 · A refused global still claims its location, giving a second, misleading message

`p1_reader.log`:

```
== global twice, the duplicate located
    line 2: `a` is declared twice: first on line 1, as a global
    line 3: `b` is at `panel.i.1`, where `a` already is (line 2): a location holds one global
== keyword-named global with a location
    line 1: `task` is a keyword and cannot name a global
    line 2: `b` is at `panel.i.0`, where `task` already is (line 1): a location holds one global
```

Line 3's `b` is correct. It is reported only because the refused line 2 took
`panel.i.1`.

**The rule it breaks.** T1's own "one mistake, one message" (R13, C5), and the house's
(`declarations.ex:190-194`, *"one mistake, one message"*).

**Where it happens.** `declare({:global, …})` calls `locate/3` whatever `enter/4`
returned. **Fix.** Locate only an entered global.

### D7 · Three rules pinned by no test (J1, J14, J20; §1.3)

**The rules it breaks.**
- CLAUDE.md: *"A fix needs a test that fails when the fix is reverted"*.
- org §6.2: *"Each rule is checked by reverting it"*.

**What each survivor means.**
- **J1.** T1-Q3 recommends `:configure`, and T1 changes `Logex.Diagnostic`'s moduledoc
  for it. Yet only the reader's diagnostics have their stage asserted
  (`configuration_test.exs`, "reading gives every broken line…"); none of the checks'
  diagnostics do.
- **J14.** W2's definition, "an output point *something reads* but nothing drives", is
  not pinned.
- **J20.** A global used only as a trigger would be warned as unused.

**Fix.** Assert `stage: :configure` on one check diagnostic. Add a warnings test with an
unused output point (W1 only) and a trigger-only global (no W1).

### D8 · "(tags are case-sensitive)" in configuration messages

`p3_checks.log`, `p1_reader.log`:

```
line 3: no task `Fast` — did you mean `fast`? (tags are case-sensitive)
line 2: unknown program type `Motor` — did you mean `motor`? (tags are case-sensitive)
line 3: `m1` is a `motor`, which declares no `Start` — did you mean `start`? (tags are case-sensitive)
line 4: no global `pb` — did you mean `Pb`? (tags are case-sensitive)
```

A configuration has tasks, globals, instances and types, not tags.
`Declarations.suggest/4` takes a `kind` for exactly this (`declarations.ex:65`), and T1
passes the default. **Fix.** Pass `"names"`, `"program types"` or `"members"`.

### D9 · `compile_file/1`'s example is wrong for some names

`p2_data.log`:

```
`.ld` has no extension: a program's file ends in `.ld`, as in `.ld.ld`
`motor.ld.bak` is not a program's file: a program's file ends in `.ld`, as in `motor.ld.ld`
```

**Fix.**
- A dotfile `.ld` has a name with no type part. Say so.
- For `x.ld.bak`, name the extension found (`.bak`) and leave out the example.

### D10 · C5's doc is not what the code does, and a broken connection hides a later line's mistake

**C5 against the code.** T1 §4.3 C5 says placeholder names *"enter the namespace
unchecked"*. In fact `declare({:declared, …})` calls `enter/4`, which runs the keyword and
`.` checks. So a broken line can give two diagnostics (`p1_reader.log`):

```
line 1, column 20: `interval` takes a number of milliseconds, as in `interval 10`, found `x`
line 1: `with` is a keyword and cannot name a task
```

**A hidden mistake.** `m1.start pb extra` (broken) followed by `m1.start pbx` gives only
the line-3 diagnostic. Line 4's unknown global `pbx` is never resolved, because
`sourced({:broken, _}, …)` returns the state unchanged.

**Fix.** Make the doc and the code agree. Still resolve the source of a later connection
to a var_input whose first connection was broken.

### D11 · A wrong citation

T1.md §5 cites `parser.ex:269-282` for "a line of `( )` keeps no line at all". At
`47319f7` `lib/logex/parser.ex` has 221 lines (`wc -l`). The claim itself holds: a
`{:branches, legs}` node carries no line (CLAUDE.md, Conventions).

---

## 4. Left unspecified or narrowed, with the rule each touches

### G1 · W6 is narrowed, and its channel is a second D1-type reading

org §4.6, *Caveats*: *"A `ton` in an event-task program times across events. It should
be an M1-5 warning."*

T1's W6 fires only for a task with `single` and no `interval` (`event_timers/1`).
`p3_checks.log`, "ton under event+interval task: ok; warnings: []". A task with both
inputs is an event task too: IEC's rule 2 suspends its periods while the trigger is 1,
so a `ton` under it also times across gaps.

T1 records this only as a Risk (§19). It should be a question with options, because it
narrows a decided caveat. W6 also rides on `%Configuration{}.warnings`, not a program's,
which is the same reading as T1's D1 (T1-Q12) and belongs in that question.

### G2 · G2 (T1-Q10) against the per-instance switch OE-2 will reuse

PLAN M2-1 requires that OE-2 *"needs no rework"* and that there be *"one copy of each
global"*. Fix F5 builds the switch per instance so OE-2 can call it on each.

Under T1's G2, an instance's env holds no `var_external` between scans. Today's
`Logex.Edit` on such a state reports the external as added, and writes a second copy into
the env (`p9b_g2_edit.log`):

```
full env: accept forecast: []
full env: test report: []
G2 env (estop dropped): accept forecast: [{:added, "estop", 0}]
G2 env (estop dropped): test report: [{:added, "estop", 0}]
G2 env (estop dropped): env after test: %{"estop" => 0, "motor" => 1, "start" => 1}
```

T1-Q10's G2 option and §11's `var_external` row do not say how a switch sees an
instance's externals. One of these is needed:
- the configuration's switch merges the globals in before calling the per-instance
  switch, and splits them off after;
- or `Logex.Edit` skips `var_external` tags.

A related unverified point: `call/4` on such a state silently reads the missing tag as 0
(`p9_g2_edit.log`). So a scheduler that forgot to merge would not crash.

### G3 · `var_external` in a function block file (inv Q4.9) is not answered

`var_external` is now a row of `Declarations.@sections`, so once M2-5 lands, a
`function_block` file would accept it. But T1's R44, R45, W4 and W5 read only a program
instance's own top-level tags (`bound/2`, `external_writers/1`). IEC allows VAR_EXTERNAL
in a function block (inv U19), and T1 §12 is silent on it.

**Recommendation.** Ask the maintainer:
1. refuse `var_external` in a block file until M2-5 decides;
2. or bind a block's externals through the containing program's instance, which then
   needs the one IR walk to reach `cal` bodies.

I recommend option 1. It is strict and reversible.

### G4 · A global that something reads and nothing writes gets no warning, unless it is an output point

`p3_checks.log`:
- `var_global go bool 1` plus `task t single go priority 0` fires once in cycle 1, then
  never again. Only W6 is given.
- `var_global g bool` read by `x1.go g` gives no warning at all.

Only W2 covers this, and only for an output point. inv Q2.17 lists the candidates. T1-Q17
does not say why a read-but-never-written unlocated global, or an unconnected var_output,
gets none. This is not decided. It is a candidate W7.

### G5 · No configuration test for CRLF or lone CR

The behaviour is right today (§2.1), and the lexer's own tests pin B8. But nothing in
`configuration_test.exs` would catch a later reader that numbers lines by splitting on
`"\n"`. A one-line test reading the plant with `\r\n` and with `\r` would cover it.

---

## 5. T1 against the decided rules it touches

| Rule | Holds? | Where |
|---|---|---|
| Decision 3: choose the extension before M2-2 | yes, `.lxcf` argued from res EXT-1..8, with `.ldcfg` and `.ldcf` as options (T1-Q1). The maintainer's call | T1 §2 |
| Decision 5: arrow-free; direction from the member's section | yes. C34 and C35 name the section, as §4.4 asks of a wrong direction | `sectioned/5`, `drive/6` |
| Decision 6: `panel.q.0`; `%` is the fallback | yes. `%` stays a lex error, and the grammar is the strict form (T1-Q8) | `location/1` |
| Decision 7: every var_input connected, as an error | yes, one diagnostic per instance at its `program` line (T1-Q18). IEC-14's inference is recorded beside it | `unconnected/2` |
| Decision 10: reserved words by file kind | yes. The ten words are reserved in `.lxcf`, `var_external` in `.ld`, and the "legal in both" rule is checked at the `.ld` compile. The spike reserves all ten at once and the landing order stages them (T1's D2) | `@keywords`, `shared/1` |
| Decision 11: PRIORITY required, 0 highest; SINGLE already true fires | yes for the text (C8, C9). The run-time half is stated in §10.4 and not spiked | §10.4 |
| §4.4 line shapes, checks and loading | yes, except D4 (did-you-mean) and the D3 readings T1 lists (the raising face is S's) | §6 |
| §4.4 "two writers … a warning, in M1-5's `warnings:` channel" | a reading, raised as T1-Q12. W6 should join it (G1) | `writers/1` |
| §4.5 location structure; the `at` stanza argues the coinage | yes | naming.md `at` |
| §4.6 Caveats, the `ton` warning | narrowed (G1) | `event_timers/1` |
| §4.7 each wrong reading of `.` named | **no** for a location in a connection or in `single` (D1) | `undeclared/4` |
| §4.8 per-kind table | yes | §8 |
| CLAUDE.md: the data API refuses what the text cannot say | **no** for lines; it also refuses one entry the text can say (D2) | `entries!/1` |
| CLAUDE.md: nothing but `ArgumentError` escapes the public API | **no** for `Text` (D3) | `Text` |
| CLAUDE.md: a rule needs a test that fails when it is reverted | 46 of T1's rules yes (8 re-checked), plus 13 of the 16 I added. 3 did not (D7) | §1.3 |

---

## 6. What must change before T1's design lands

**Required:**
1. **D1.** Name the location reading of `.` in connections and `single`.
2. **D2.** Refuse non-increasing or mixed lines from Elixir. Check a member as the text
   reads it. Draw lined entries in R49.
3. **D3.** Pinned `ArgumentError`s on every public function of `Text`. Add a totality
   property.
4. **D4.** Keep the did-you-mean for a missing type file.
5. **D7.** Pin the `:configure` stage, W2's "something reads" and `single` as a use.

**Messages:**
6. **D5.** No message advises declaring a keyword.
7. **D6.** A refused global takes no location.
8. **D8.** The case-sensitivity suffix names what it is about.
9. **D9.** `compile_file/1`'s example.
10. **D10.** The doc and the hidden connection.

**Documents:**
11. **D11.** Correct the parser citation.

**Questions to add for the maintainer:**
12. **G1.** W6 with `single` plus `interval`, and its channel.
13. **G2.** How an online edit's switch sees an instance's `var_external` under G2.
14. **G3.** `var_external` in a function block file.
15. **G4.** A read-but-never-written global (optional).

---

## 7. Ideas to graft from the other tracks' designs

T is a one-design track, so these come from S1, S2 and S3 (M2-1). JS1 judged S2 the
winner there.

1. **S2's file on `%Logex.Program{}`** (fix F15, S2 §7.1 and §7.3: *"cited at the
   `program` line with the `.ld` file and line in the message"*). T1's R44, R45 and W6
   name a `.ld` line without its file, which T1 lists as a Risk. Milestone 2's done
   sentence asks for *"a located diagnostic naming its file and line"*. The loader knows
   each type's path, so even without F15 it can put the `.ld` path in the message.
   F15 is still owed for `Logex.Edit`.
2. **S2's CF-29 totality property** (S2 §4.1: *"any value in any field … gives
   diagnostics, never another exception"*, found by a seeded property). Run it over
   `Text.read/1`, `Text.print/1` and `check/3`. It would have found D3.
3. **The raising Elixir face from S1, S2 and S3, `Logex.Configuration.new!/1`.** It
   raises every problem in one `ArgumentError`. This is T1's own contract item C4, and
   §4.4 "Loading" says a constructor from Elixir data *"runs the same checks, as
   `Tag.new!/4` does"*.
4. **S2's round-trip wording** (S2 §7.1: equal *"but for lines and file"*). Either
   compare modulo lines or refuse non-increasing lines (D2). One of the two must be
   stated.
5. **Keep T1's own choices where it and S2 differ:**
   - the token reader over S2's route through `Logex.Parser` (T1-Q2), for the columns
     and for `( )`;
   - org §4.4's decided `compile(name, source, programs)` order over S2-Q15's
     reordering (T1-Q19).

   The merge should take the message wording a configuration file's reader sees, rule by
   rule, as T1 §21 says.

**What T1 asks of S's constructor.** C5 (`{:declared, …}` placeholders from the text
path) and C6 (types that failed to load) are text-path concerns that T1 asks S's
constructor to carry. Neither is in S2's contract yet (T1 §21). The merge must either
adopt them or keep them in the text path, by filtering the constructor's diagnostics
that mention a broken name. That decision belongs with the constructor's owner.

---

## 8. On T1's open questions

I agree with T1's recommendation on T1-Q1 to Q9, Q11 to Q15 and Q17 to Q21, with these
notes:

| Question | Note |
|---|---|
| **T1-Q1** | res EXT-7 notes `.ld` is already GNU's linker-script extension. So `.ldcfg`'s cost is a pairing the repository has already made, not a new clash. `.lxcf` is still the safer word. The maintainer's call. |
| **T1-Q6** | Agree, with graft 1: name the `.ld` file. |
| **T1-Q10** | G2 is the right shape, but its consequence must include G2 above. |
| **T1-Q12** | Fold W6's channel into it (G1). |
| **T1-Q16** | `min(next_due, now + new)` is sound. It is OE-2's to decide. |
| **T1-Q17** | Add G4 as a considered option. |

---

## 9. Receipts

- **Gate:** `JT1-probe/T1-gate.log`.
- **Mutation:** `JT1-probe/mutate.py` and `mutate.log` (J1 to J21), `JT1-probe/t1_mutate_copy.py`
  and `t1-sample.log` (T1's M5, M17, M22, M28, M30, M35, M42, M44), and
  `p5_mutant_effect.exs`. Its output is quoted in §1.3 only, with no log file.
- **Probes:** `p1_reader`, `p2_data`, `p3_checks`, `p4_dot`, `p6_crosskind`,
  `p7_roundtrip`, `p8_loader`, `p9_g2_edit` and `p9b_g2_edit`, each an `.exs` with its
  `.log`.
- **Unverified:** whether S2's merged constructor keeps any of D2, D5, D6 or D8 (not run
  here); the run-time semantics of T1 §10 (not spiked by T1, not checked by me); and
  every naming-stanza row T1 marks unverified.
- `/home/user/logex` is untouched: `git status --short` is empty at `47319f7`.
