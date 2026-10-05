# rf-X-consistency · cross-track consistency of S-synth, F-synth and T-synth

Label rf-X-consistency. Written 2026-10-02 against `/home/user/logex` at `47319f7`, which was
not modified. Every merge was built in `scratchpad/m2/rf-X-consistency-work` (a copy of the
repository) from single-patch reference trees (`rf-X-consistency-work-{base,S,F,T}`, made by
`rf-X-consistency-probe/trees.sh`); those copies are deleted at the end of this pass. What is
kept is `scratchpad/m2/rf-X-consistency-probe/`: `merge.sh` (3-way `git merge-file` of every
file two tracks touch), `resolve-FT.py` (the F+T resolution), the probes `sf_get.exs`,
`ft_probe.exs`, `ft_stack.exs` with their logs, the pairwise conflict diffs `pair-*.diff`, the
suite logs `SF-test.log` and `FT-test.log`, and `ST-runtime_test.exs` (the clean textual
merge of the surface test that cannot pass). Every `mix` run used Elixir 1.20.4 / OTP 28
(`scratchpad/toolchain/env.sh`) and is judged by its exit code.

`S`, `F`, `T` are `S-synth.md`, `F-synth.md`, `T-synth.md`; `org` is `docs/organisation.md`.
Labels X1… are this document's own.

---

## 0. Summary

- **The patches apply alone** (`git apply --check`, each `ok`). Together, in all six orders,
  `git apply --3way` leaves 10 files conflicted. Pairwise on a clean base:

  | Pair (either order) | Conflicted files (hunks) | Nature |
  |---|---|---|
  | S + F | `lib/logex/runtime.ex` (1), `test/logex/api_contract_test.exs` (1), `test/logex/end_to_end_test.exs` (1) | adjacency only: one alias line, two appended describes/walks |
  | S + T | `lib/logex/configuration.ex` (1, the whole file: both create it), `lib/logex/diagnostic.ex` (1), `test/logex/configuration_test.exs` (5–6) | **two different modules of one name**; not resolvable textually |
  | F + T | `lib/logex.ex` (2), `lib/logex/declarations.ex` (3), `test/logex/naming_test.exs` (1), `docs/naming.md` (1) | real: two `compile_file/1`s, two `check/1`s, two naming tests |

  `CLAUDE.md`, `lib/logex/program.ex` and `test/logex/runtime_test.exs` merge cleanly in every
  pair, but S's and T's surface tests pin two incompatible `Logex.Configuration` surfaces in
  the cleanly merged file (X2).
- **S + F** (resolved as a union, 4 hand fixes at the seams): `mix format --check-formatted`
  0, `mix compile --warnings-as-errors` 0, `mix test --warnings-as-errors` exit 0, `Result:
  559 passed (7 doctests, 552 tests)` (= 500 + 489 − 430). S's `get/2` reads F's `m1.s2.run`
  unchanged (X6).
- **F + T** (resolved by composing both: T's `.ld` gate in front of F's loader, both
  declaration checks, both naming tests): compile 0, test exit 0, `Result: 558 passed (6
  doctests, 552 tests)`. **Green, and still broken**: a configuration whose program holds a
  `cal` crashes with `Protocol.UndefinedError`, a `program` line naming a block crashes with
  `FunctionClauseError`, and a block file with `var_external` crashes `Logex.compile/2` (X1,
  X3). No suite in either spike sees it.
- **S + T** does not merge: each defines `Logex.Configuration` with another API, data shape
  and error mode (X2). Keeping S's module, T's code fails `--warnings-as-errors` on
  `Logex.Configuration.extension/0 is undefined`; keeping T's, S's fails on `check/1`,
  `location/1` and `Logex.Configuration.Global`.
- **Landing order.** S recommends M2-1 first (S Q-22), F recommends M2-5 first (FS-Q16), T
  assumes M2-1 first and says M2-5's position changes only its commit 13. The code shows M2-1
  first is the order consistent with all three; and M2-5 should land before M2-2, so that T's
  text, loader and walks are written against `cal` from their first commit (§3).
- **20 findings** (X1–X20): 2 high, 8 medium, 10 low.

---

## 1. Conflicts found by applying the patches

### 1.1 S + F: adjacency only, green after a union

`git apply --3way ../F-synth.patch` on S (and the reverse) reports `Applied patch to
'lib/logex/runtime.ex' with conflicts`, likewise `api_contract_test.exs` and
`end_to_end_test.exs`, one hunk each. The runtime hunk is one alias line:

```
<<<<<<< ours
  alias Logex.{Configuration, Declarations, Diagnostic, FbType, Instance, Program, Scan, Tag}
=======
  alias Logex.{Declarations, FbType, Instance, Program, Scan, Tag}
  alias Logex.FbType.Member
>>>>>>> theirs
```

The two test hunks are S's M2-1 walk/describe and F's M2-5 walk/describe, both appended
before the module's final `end`; `git merge-file --union` drops one shared closing line at
each seam (`TokenMissingError ... missing terminator: end`), which a hand fix restores. After
that the full gate is green (559). S's `%Logex.Scan{now:, first:}` built inside `cycle/3` and
F's new `tags: nil` key coexist; S's walk and F's walk both pass.

### 1.2 S + T: two modules named `Logex.Configuration`

Both patches create `lib/logex/configuration.ex` (S 1,160 lines, T 1,385 lines) and
`test/logex/configuration_test.exs`; the 3-way merge yields one conflict covering each whole
file. Public functions (`grep 'def '`): S has `check/1`, `location/1`, `new!/1`; T has
`check/3`, `compile/3`, `compile_file/1`, `extension/0`, `new!/3`. The modules are designs of
one thing, not halves of one thing (X2). `diagnostic.ex` conflicts on one moduledoc sentence
whose two versions attribute `:configure` to different items (X15).

### 1.3 F + T: two loaders, two declaration checks

- `lib/logex.ex`, `compile_file/1`: F's `load(path, {%{}, []}, %{})` (a memo and cycle check
  over block files beside) against T's `by_kind(Path.extname(path), path)` (only `.ld` is a
  program's file). The composition that works: `by_kind(".ld", path)` calls F's `load/3`;
  T's 2-arity `read/2` must go, since F replaced it with `read/4`.
- `lib/logex/declarations.ex`: the moduledoc grammar line (`type: bool | dint | ton | a
  block's name` against `| var_external`), the moduledoc paragraph, and the clause
  `defp check(%Tag{} = tag, _types)` (F, which threads a block library) against `def
  check(%Tag{} = tag)` with T's `shared(tag)` (a `var_external` named like a configuration
  keyword). Composed: F's arity with T's `shared/1`.
- `test/logex/naming_test.exs`: F's "every word that heads a file of another kind has been
  surveyed (M2-5)" (`Declarations.kinds/0`) and T's "every keyword of a configuration file
  has been surveyed" (`Configuration.Text.keywords/0`) are inserted at one place. Both kept.
- `docs/naming.md`: both append stanzas at the end of an append-only file. Both kept.

With these, the suite is green (558) and the crashes of X1 and X3 remain.

---

## 2. Findings

### X1 (high) · F + T: green suite, three crashes at the seam

**Claim.** Once F's `cal` exists, T's configuration code raises exceptions other than
`ArgumentError` on valid or ordinary source, so CLAUDE.md's "Nothing else may escape the
public API" fails, and T's statement (T §8, "Where M2-5 lands earlier (inventory §11's
order), nothing below changes but commit 13's block-file rule") is refuted.

**Repro.** `merge.sh F T`, `python3 resolve-FT.py`, `mix compile --warnings-as-errors` (0),
`mix test --warnings-as-errors` (0, 558 passed), then `mix run
../rf-X-consistency-probe/ft_probe.exs` (`ft_probe.log`, `ft_stack.log`):

```
lxcf with a program that holds a block: {:raised, Protocol.UndefinedError,
 "protocol Enumerable not implemented for Atom. ...\n\nGot value:\n\n    :block\n"}
lxcf naming a block file on a program line: {:raised, FunctionClauseError,
 "no function clause matching in Logex.Configuration.instructions/1"}
event task running a program whose ton is inside a block (W6): {:raised, Protocol.UndefinedError, ...}
```

`a.lxcf` is three located globals, `program m1 motor`, three connections; `motor.ld` is
`var s1 seal` and `cal s1 a b q`, with `seal.ld` beside it. The first crash is T's private
walk `writes/1` (`configuration.ex:1355`), which does `Map.new(Map.values(
Logex.Compiler.instructions()))` and `Enum.zip(Map.get(signatures, symbol, []), operands)`:
F makes `instructions()` hold `"cal" => {:cal, :block}`, so the "signature" is the atom
`:block`. The second is `Logex.Configuration.instructions(%Logex.FbType{...})`
(`configuration.ex:1368`, called from `writes/1` ← `analysed/3` ← `declare/2`): F's
`Logex.compile_file/1` returns `{:ok, %Logex.FbType{}}` for `seal.ld`, and T's loader puts it
in the programs map.

**What must be reconciled.**
- T's `writes/1` and `timers/1` are replaced by one `cal`-aware walk before any check uses
  them. F FS-Q23 and T §8 commit 12 both put B5's one walk "before M2-4"; that is enough only
  because T's landing order brings `writes/1` in at commit 14. The walk must also reach
  `cal` bodies for T's W6 (T §5: "A `ton` inside a block counts for W6") and for R45/W4/W5
  (T §5: "`cal`'s output operands count as writes").
- A `program` line naming a block type needs the diagnostic T §5 only proposes (```` `seal`
  is a function block, not a program: instantiate it inside a program, as in `var s1 seal`
  ````), in M2-2's loader commit (T §8 commit 5) if M2-5 is in by then. F has the mirror
  rule already (R69, "`prog` is a program (prog.ld), not a function block").
- T's commits 2, 3, 5, 12, 13, 14 and 16 all change with F in (1.3 and X3), not only 13.

### X2 (high) · S and T define two incompatible `Logex.Configuration`s

**Claim.** The two tracks' configuration modules differ in API, data shape, line rule and
error mode, and both pin their own surface; the pinned-surface test merges textually clean
and then cannot pass.

**Repro.** `git merge-file -p S/runtime_test.exs base/runtime_test.exs T/runtime_test.exs`
exits 0; the result (`ST-runtime_test.exs`) has at lines 976 and 1015:

```elixir
assert Enum.sort(Logex.Configuration.__info__(:functions)) ==
         [__struct__: 0, __struct__: 1, check: 1, location: 1, new!: 1]          # S
assert Enum.sort(Logex.Configuration.__info__(:functions)) == [
         __struct__: 0, __struct__: 1, check: 3, compile: 3, compile_file: 1,
         extension: 0, new!: 3]                                                  # T
```

The differences, quoted:

| Point | S | T |
|---|---|---|
| Elixir face | `new!(keyword)` (S §1.1) | `new!(name, entries, programs)` (T §1.3); T Q-19 recommends S's form for the landing |
| Validator | `check(config) :: [%Logex.Diagnostic{stage: :configure}]` (S §1.1) | `check(name, entries, programs) :: {:ok, %Logex.Configuration{}} \| {:error, [diagnostic]}` (T §1.3) |
| Elements | structs `%Task{}`, `%Global{}`, `%Instance{}`, `%Connection{to: global_name \| non_neg_integer}` | tuples `{:connection, line, %{... to: {:global, name} \| {:constant, n}}}`; the built struct's connections carry `direction:` |
| The struct | `name file programs tasks globals instances connections warnings` | no `file` field (T §1.3 struct list) |
| Lines | "CF-4 A line is a positive integer or nil" (any order) | "R48 ... lines that are not all nil or strictly rising" raise `ArgumentError` |
| Host mistakes in the validator | `check/1` is "total over any value in any field" and returns them as diagnostics, e.g. `programs must be a map of program names to %Logex.Program{}, got: <inspect>` and `<inspect> cannot name a configuration: …` | raised: H1 `a configuration's name is a string, got: <inspect>`, H4 `programs must be a map of type names to %Logex.Program{}, as in %{"motor" => motor}, got: <inspect>` |
| A broken line's name | not in S | placeholders `{:declared, line, %{kind:, name:}}` passed to the checks (T §1.1, C5) |
| Location | public `location/1` | private |

T §1.5 states the merge contract (C1–C10) and T Q-20 recommends S's `check/1` as the one
validator with T's checks as its rows; S does not mention placeholders, a `direction`, or the
rising-lines rule. Both tracks agree on the namespace, the location grammar, output points
taking no initial value, the bounds, the stage name, and that the checks land once.

### X3 (medium) · `var_external` in a block file: both recommend refusing it, neither does, and the merge crashes

**Claim.** T Q-18 (a) "Refused in a block file, with a located diagnostic, until decided" and
F §5 "Recommend refusing `var_external` in a block's file in M2-4" agree; neither spike
builds the refusal, and in the F + T merge `Logex.compile/2` of such a block raises.

**Repro.** In the F + T merge, `mix run` (`ft_stack.log`):

```
block with var_external: FunctionClauseError
   (logex 0.1.0) lib/logex/fb_type.ex:132: Logex.FbType.role(:var_external)
   (logex 0.1.0) lib/logex/fb_type.ex:130: Logex.FbType.member_of/1
```

for `Logex.compile("function_block b\nvar_input a bool\nvar_external g bool\nxic a ote g\n",
name: "b")`. T §8 commit 13 carries the refusal "if M2-5 has landed"; with M2-5 before M2-4
in every order considered in §3, commit 13 must carry it and its test.

### X4 (medium) · Two loaders where the inventory asks for one

**Claim.** F §5 says M2-2's loader reuses F's: "The loader's rule, a type word names a file
beside the file that names it, is also `program m1 motor`'s ... One `load/3`, one memo, one
cycle check." T's loader is its own: `load({type, line}, ...)` → `on_disk(File.exists?(path),
...)` → `loaded_type(Logex.compile_file(path), ...)` (T spike `configuration.ex:225-232`),
one `Logex.compile_file/1` call per program type, each with a fresh memo (`{result,
_loaded} = load(path, {%{}, []}, %{})` in F's `lib/logex.ex`). The inventory's "Decisions to
take before the first item" says: "M2-5 and M2-2 must share one rule, or the done sentence's
configuration with a block inside it gets two."

**Consequences (from the code, not run):** a block held by two program types is compiled
once per type; T checks the kind of nothing it loads (X1's crash), where F peeks each file's
kind before loading it (`peek/1`, `kind_of/4`); T tests `File.exists?/1`, F
`File.regular?/1`. Reconcile: T's loader resolves program types through F's `load/3` with one
memo for the whole configuration, with a kind check for "a program line names a block".

### X5 (medium) · Landing order: S and F recommend opposite first items

- S Q-22: "(a) Decision 1's default, M2-1 first. ... *Recommend (a).*"
- F FS-Q16: "(a) M2-5 first, with FS-Q1 (a). ... *Recommend (a).* The spike shows M2-5
  self-contained on today's main." (Also inventory §11: "Recommendation: M2-5, then M2-1,
  M2-2, M2-3, M2-4, M2-6".)
- T §8: "**Assumed order.** Track S's M2-1 lands first ... Where M2-5 lands earlier
  (inventory §11's order), nothing below changes but commit 13's block-file rule."

Resolution and evidence in §3.

### X6 (medium) · M2-5's Done-when `m1.s2.run`: each track hands it to the other, and no spike asserts it

**Claim.** F FS-Q1 (a): "Reword it for M2-5 and assert `get(rt, "m1.s2.run")` in M2-1's
acceptance." S Q-22 (a): "M2-5's acceptance `m1.s2.run` reads through `get/2` unchanged
(unverified until a nested user block exists)." `grep -rn 's2\.run\|m1\.s2'` over S's tests
finds nothing; F's end-to-end test reads `s2.run` by a rung and from state, not through
`get/2`. PLAN:1345 and org:1408 still say "`m1.s2.run` reads one of them".

**Verified here:** in the S + F merge, `sf_get.exs` (`sf_get.log`):

```
cycle 1: {%{"k" => 1}, [{:ran, :none, "m1", 0}]}
m1.s2.run: {:ok, 1}
m1.s2.t1: {ArgumentError, "`m1.s2.t1` is not a member of `m1.s2`, a seal: its members are `start`, `stop` and `run`"}
m1.s2: {ArgumentError, "`m1.s2` is a seal: an access path names one of its members, as in `m1.s2.run`"}
```

So S's `get/2` already does what F's FS-Q9 (a) (a block's `var`s hidden) requires, through
`FbType.member/2` → `public/1`. **Reconcile:** whichever item lands second owns a test of
`Logex.Runtime.get(rt, "m1.s2.run")`; with M2-1 first that is M2-5's Done-when, as written.

### X7 (medium) · `next_due` when OE-2 changes an interval

- S Q-23: "(a) Keep it; the next run steps by the new interval ... *Recommend (a).*"
- T Q-16: "(a) `min(next_due, now + new interval)` ... *Recommend (a).* The two tracks
  disagree here, so one answer is needed. (a) bounds the wait by the new interval and adds
  no run, which (b) does not."
- T §4's state table also records S's answer as the other option. One answer before OE-2's
  design pass; M2-3's documents state it (T).

### X8 (low) · `Configuration.compile`'s argument order

- S Q-24: "(a) `compile(source, programs, name: "plant")`, mirroring `Logex.compile/2`.
  Departs from org:470. ... *Recommend (a)*, but it is M2-2's question and T1 keeps (b); the
  merge of track T decides."
- T Q-19: "*Recommend (a)* [`compile(name, source, programs)`] for `compile`, since it is
  decided and the difference is cosmetic, and S-synth's `new!/1` keyword form for the Elixir
  face." Opposite recommendations on one signature; agreed on `new!/1`.

### X9 (medium) · Lines from Elixir and line order

- S Q-20 (a): "`new!/1` refuses one ... `check/1` and `start/1` accept lines, for M2-2's
  reader", with CF-4 "A line is a positive integer or nil" in any order.
- T Q-21 (a): "Lines are all nil or strictly rising; `new!` refuses any line; the printer
  places a lined entry on its line" (R48, raised from `check/3` as well); option (b) is
  S's rule, "then the data path accepts an order no file gives".
- Agreed: `new!` refuses a line (S NW-3, T R61), but with two messages: S ``task `<n>` from
  Elixir has no line, got: <inspect>``; T H13 ``an entry built in Elixir has no line: a line
  is where a configuration file declares an entry, got: <inspect entry>``.

### X10 (medium) · One rule, two messages; and the §4.4 receipt

Where S's `check/1` and T's checks implement the same rule, the words differ (S §3.2 against
T §3.4). Examples, each pair one rule:

| Rule | S | T |
|---|---|---|
| namespace | `` `<n>` is already the name of a <kind><where>: tasks, globals and program instances share one namespace`` | `` `<n>` is declared twice: first on line <l>, as <a kind>`` |
| interval | ``task `<n>`: an interval is 1 to 2147483647 ms, found <inspect>`` | ``the interval of `<t>` is 0: an interval is at least 1 ms, and an instance that runs every cycle is declared without `with` `` / ``the interval of `<t>` is `<n>` ms: …`` |
| priority | ``task `<n>`: a priority is 0, the highest, to 2147483647, found <inspect>`` | ``the priority of `<t>` is `<n>`: a priority is 0 to 2147483647, and 0 is the highest`` |
| output point initial | ``global `<n>` is an output point: it starts at 0 and takes its value from the instance that drives it, so it takes no initial value`` | `` `<g>` is an output point: it takes no initial value, and is 0 until its driver writes it`` |
| one address | ``global `<n>` is at `<at>`, the address of global `<first>`<where>: one address holds one global`` | `` `<g>` is at `<loc>`, where `<other>` already is (line <l>): a location holds one global`` |
| unknown task | ``program instance `<n>`: there is no task `<t>`<hint>`` | ``no task `<n>`: declare it with a `task` line, as in `task <n> interval 10 priority 1` `` |
| second source | `` `<i>.<m>` is already connected, to …<where>: a var_input is connected once`` | `` `<i>.<m>` is already connected, to `<to>` (line <l>): a var_input has one source`` |
| no instance | `a configuration runs at least one program instance` | ``this configuration declares no `program`: it would run nothing`` |
| unconnected var_input | one per member: `` `<i>.<m>` is not connected: every var_input is connected, to a global or a constant`` (CF-26) | one per instance (T1-Q18): `` `<i>` leaves its var_inputs `a`, `b` and `c` unconnected: …`` (C37) |

The last row is a difference of rule (granularity, so diagnostic count), not only words. And
org §4.4's receipt: S §3.2 "Four of the configuration spike's seven messages (org:452-460) are
kept word for word but for the trailing rule"; T §3.7 rewords all seven and plans "org §4.4's
receipt is replaced by §3.7's pinned text" (T §8 "Before any"). T Q-20 (a): "the
configuration file's reader-facing words win rule by rule". S asks no question on it. One
list of words must be chosen before T's commit 4.

### X11 (low) · How a configuration file is read

- S §5, M2-2: "`Logex.Configuration.compile/3` lexes and parses with
  `Logex.Lexer`/`Logex.Parser` as `Logex.Declarations` does".
- T Q-2: "(a) A recursive descent over `Logex.Lexer`'s tokens (built) ... (b) Through
  `Logex.Parser`'s rung tree, as declaration lines are (S-synth §5, from S2) ... *Recommend
  (a)*". T is M2-2's owner; S §5's sentence should follow the answer.

### X12 (low) · Who first fills `%Logex.Configuration{}.warnings`

S §1.1 and §12: "empty in M2-1; M2-4 is the first to fill it" (S Q-29). T lands W1 (unused
global) and W2 (undriven output point) in M2-2 (T §8 commit 4) and W3 (a task with no
instance) in M2-3 (commit 10). The decision (land the field empty in M2-1) agrees; S's
statement of who fills it first is wrong under T's plan.

### X13 (low) · A block type handed to a configuration as a program

F gives every program entry point a dedicated message (F §3.1, R8/R9): ``` `seal` is a function
block type, which runs inside a program through `cal`: an instance is of a %Logex.Program{}
```. In the S + F merge, `Configuration.new!(name: "p", programs: [seal], instances:
[%Instance{name: "x", type: "seal"}])` raises (`sf_get.log`):

```
programs: %Logex.FbType{name: "seal", ...} is not a %Logex.Program{} from Logex.compile/2
program instance `x`: there is no program `seal`: this configuration has no program
```

"from Logex.compile/2" is no longer a distinguishing description, since F's `Logex.compile/2`
returns `%Logex.FbType{}` for a block's source, and one mistake gives two messages. T's
`compile/3` gives its generic H6 (`programs must be a map of type names to %Logex.Program{},
got: %{"seal" => %Logex.FbType{...`, `ft_probe.log`), and T's loader crashes (X1). Reconcile:
one block-type message across `new!`, `check`, `compile/3` and the loader, with no cascade.

### X14 (medium) · Every track claims organisation.md §7 decisions "30 onward"

- S §8 commit 1: "appended to org §7 as decisions 30 onward (the labels test requires every
  decision number cited in `lib/` or `test/` to be defined there first)".
- T §8: "org §7 gains this design's decisions as 30 onward".
- F §9 commit 3: "§7 a new decision for each FS-Q answer, numbered from 30".

Because `edit_test.exs`'s labels test fails on a decision number §7 does not define, and lib
and test files will cite the numbers, the numbers must be allocated once, before any M2 code
commit cites one: one design-record commit for all three tracks' answers, or a fixed range
per track.

Overlapping document edits the same reconciliation must order (none of the three patches
touches `PLAN.md` or `docs/organisation.md`; each design lists them for a documents commit):
- org §6.2: S moves "The §4.4 checks" and "Adds `configuration_test.exs`" from M2-2 to M2-1
  (S D-1, §9 commit 1); T edits "§6.2 M2-2" (T §9 commit 2); F "§6.2 M2-2's loader is
  shared" (F §9 commit 5).
- org §4.4: S corrects the unconnected-input sentence (org:434-435) by research IEC-14 and
  keeps four receipt messages; T renames `.lcf` to `.lxcf` (18 occurrences) and replaces the
  receipt (X10).
- org §4.9: S (restart note), F (the members' refusal at org:866 lifted; the Resume row
  org:1004 reworded), T (the section-change row, "One rule for new state" gains the trigger).
- PLAN: M2-1's Done-when (S Q-21), M2-5's Done-when (F FS-Q1, X6), M2-2's loader sentence
  (F §9 commit 5, X4).
- README: F (patch) and T (§9 commits 3–6) both edit the syntax list and the "Settled, not
  yet landed" bullets; S edits the stage paragraph and the `call/4` sentence.
- CLAUDE.md: the `lib/logex.ex` Key Files entry is edited by T (§9 commit 2, "only `.ld`")
  and F (§9 commit 5, the loader). S's and F's CLAUDE.md edits in the patches merge cleanly.

### X15 (low) · Which item introduces the `:configure` stage

The two `diagnostic.ex` moduledocs conflict: S "`:configure` (a configuration's tasks, globals,
instances and connections, `Logex.Configuration.check/1`, M2-1)"; T "`:configure` (a
configuration's lines and wiring, `Logex.Configuration`, M2-2)". T's own text agrees with S
(T §1.5: "S-synth lands the §4.4 checks with M2-1"), so T's moduledoc is the one to change.

### X16 (low) · `get/2` "at any depth" against F's depth cap

S GT-1: "a public member of a function block instance at any depth"; S §5: "M2-5 owes `get/2`
a growth test in depth"; S §12: "no growth test pins it until M2-5 gives it depth". F R32 / FS-
Q9 (a): "No path from outside goes deeper than one member; M2-1's `get/2` reaches at most
`inst.tag.member`." With F, an instance can be held only by `var` (a `:local` member), which
`public/1` hides, so no path is longer than three parts (`sf_get.log`: `m1.s2.t1` refused).
The growth-in-depth test S assigns to M2-5 has nothing to measure; the inventory's reason 2
for M2-5 first ("M2-1's growth test for `get/2` in depth needs real depth") falls with it.
F §5 also says `get/2` "resolves the part after the instance name with the compiler's member
lookup"; S's `get/2` uses `FbType.member/2`. They agree in behaviour (probe), not in mechanism.

### X17 (low) · The extension

T Q-1 recommends `.lxcf` and renames 18 occurrences in org §4.4; S §5 ("It reserves `program
var_global at bool dint` in `.lcf`") and F §5 ("M2-2 (`.lcf`)") still write `.lcf`. One
answer, then S's and F's texts follow.

### X18 (low) · Fix F15 (`file` on `%Logex.Program{}`): three positions

- S §5, M2-2: "It owes fix F15 (a `file` on `%Logex.Program{}`, set by `compile_file/1`)".
- T Q-6 (a): F15 is not needed for R51, which names the type's file in the message text, but
  "should land in M2-2 anyway".
- F §12: "Fix F15 stays open", though F lands first under its own order; the inventory:
  "Where a program's file is kept (Q0.2, fix F15). M2-2's, M2-4's and M2-5's diagnostics all
  need it, and M2-5 meets it first if it leads."
- Two conventions result: F stamps a block file's diagnostics with that file in the `file`
  field (R68), while T's R51 cites a type file's line inside a configuration diagnostic's
  message (``on line 8 of <dir>/motor.ld``). One item must own F15, and the two conventions be
  stated together.

### X19 (low) · Shared questions on which the tracks agree (recorded, no action)

The namespace (S Q-7, T Q-5), the stage (S Q-16, T Q-3), an output point's initial value (S
Q-10, T Q-7), the location grammar with no leading zero (S Q-9, T Q-8), interval and priority
bounds (S Q-8, T Q-9), one copy of a global through `var_external`, G2 (S §5, T Q-10), the
restart and edit rules for an event task's trigger (S §5, T Q-15), `new!` raising every
problem (S Q-14, T R61), and T's `new!/1` recommendation (T Q-19 on S's `new!/1`). F and T
agree on refusing `var_external` in a block (X3) and on B5's one walk before M2-4 (F FS-Q23,
T commit 12).

### X20 (low) · The naming-test and declaration seams are additive, but must be landed by one hand

F's `Declarations.kinds/0` (`["function_block"]`) and T's `Configuration.Text.keywords/0`
both feed `naming_test.exs` through `surveyed_mnemonics/0`; T's `Declarations.check/1` calls
`Logex.Configuration.Text.keyword?/1` from the `.ld` validator. Composed (1.3), both pass.
Whoever lands second must merge the moduledoc grammar line to `bool | dint | ton | a block's
name` and the section list to include `var_external`, and keep F's `check/2` arity.

---

## 3. The landing order across Milestone 2

**What each track recommends.** S: M2-1 first (Q-22 a). F: M2-5 first (FS-Q16 a, with FS-Q1
a's reworded Done-when). T: M2-1 (S) first, M2-5 free.

**What the code says.**
1. **T after S, necessarily.** T's `Logex.Configuration` is "the spike's stand-in for track S's
   constructor" (T §1.3), and S + T do not compile together with either module (1.2).
2. **F is independent of S, in either order.** S then F and F then S give the same three
   adjacency conflicts; the union is green (559), and S's `get/2` reads F's `m1.s2.run` with
   the hidden-member rule F wants (X6, X16). Nothing in M2-1 forces an answer from M2-5, as S
   Q-22 claims, and nothing in M2-5 needs M2-1, as F claims.
3. **F and T interact whichever lands second** (1.3, X1, X3, X4). If F is in first, T's M2-2
   is written against `cal` and F's loader from its first commit. If T is in first, F must
   retrofit T's `writes/1`, `timers/1`, loader and `compile_file/1` gate; F §8 step 2 ("The
   walks learn a signature per instruction") names only `Logex.Edit` and `Logex.Warnings`.

**Which is consistent with all three.** M2-1 first: S recommends it, T assumes it, and F's
design runs under it unchanged with its Done-when as written (F's own option FS-Q1 (b): "the
Done-when stays as written"), which the merged probe shows works. M2-5 first contradicts S's
recommendation and requires rewording a decided Done-when (PLAN:1345, org:1408) for no
technical gain, since point 2 shows M2-1 needs nothing from M2-5. Decision 1 (org:1447,
"M2-1…M2-6, with M2-5 free to move earlier") allows M2-5 anywhere before M2-6.

**Recommended merged order:** a design-record commit (X14, all three tracks' answers, the
decision numbers allocated once), then **M2-1** (S §8 commits 2–7), **M2-5** (F §8 steps 1–5),
then **M2-2, M2-3, M2-4, M2-6** (T §8), with these reconciliations:
- before T's commit 4: one `check/1` with one list of words (X2, X10), the line rule (X9),
  the placeholders, the receipt text;
- T's commit 2 composes with F's loader (`by_kind(".ld")` → `load/3`), and T's commit 5
  resolves program types through F's `load/3` with one memo and the "is a function block, not
  a program" diagnostic (X1, X4, X13);
- T's commit 12 (B5's one walk) is `cal`-aware and reaches block bodies, before commit 14
  (X1);
- T's commit 13 refuses `var_external` in a block file, with its test (X3);
- M2-5's Done-when asserts `get(rt, "m1.s2.run")` (X6);
- before OE-2: X7.

If the maintainer prefers M2-5 first (inventory §11, F FS-Q16), only the Done-when wording
(F FS-Q1 a) and the owner of the `get/2` assertion (into M2-1's acceptance) change; the F/T
reconciliations above are the same, since M2-5 still precedes M2-2.

---

## 4. Receipts

```
$ for p in S F T; do git apply --check ../$p-synth.patch && echo ok; done     # ok ok ok
$ (pairwise, git apply --3way on a commit of the first patch)
S then F: runtime.ex 1, api_contract_test.exs 1, end_to_end_test.exs 1
S then T: configuration.ex 1, diagnostic.ex 1, configuration_test.exs 5   (T then S: 6)
F then T: docs/naming.md 1, lib/logex.ex 2, declarations.ex 3, naming_test.exs 1
$ merge.sh S F; (union + 4 seam fixes); mix format --check-formatted → 0
$ mix compile --warnings-as-errors → 0; mix test --warnings-as-errors → 0
  Result: 559 passed (7 doctests, 552 tests)
$ merge.sh F T; python3 resolve-FT.py; mix compile --warnings-as-errors → 0
$ mix test --warnings-as-errors → 0
  Result: 558 passed (6 doctests, 552 tests)
$ mix run ../rf-X-consistency-probe/ft_probe.exs   → X1, X3 (ft_probe.log, ft_stack.log)
$ (S+F) mix run ../rf-X-consistency-probe/sf_get.exs → X6, X13, X16 (sf_get.log)
$ (S+T, keeping S's configuration.ex) mix compile --warnings-as-errors →
  warning: Logex.Configuration.extension/0 is undefined or private
$ (S+T, keeping T's) → Logex.Configuration.check/1 is undefined or private;
  Logex.Configuration.location/1 is undefined or private;
  struct Logex.Configuration.Global is undefined
```
