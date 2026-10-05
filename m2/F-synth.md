# F-synth · M2-5, user function blocks: the one design

Label F-synth, track F (`PLAN.md` §3, M2-5). Written 2026-10-02 against `/home/user/logex` at
`47319f7` (main, 2026-10-01), which this pass did not modify (`git -C /home/user/logex status
--short` is empty). The spike was built from a fresh copy, `scratchpad/m2/F-synth-work`: F2's
patch applied to it, then F1's parts ported by hand, then the judges' defects fixed. Its diff,
new test file included, is `scratchpad/m2/F-synth.patch` (`git add -A && git diff --cached
HEAD`: 20 files, +3,745 −218). Every `mix` run used Elixir 1.20.4 on OTP 28
(`scratchpad/toolchain/env.sh`) and is judged by its exit code.

**Citations.** `org` is `docs/organisation.md` and `PLAN` is `PLAN.md`, by line at `47319f7`. A
bare `file:line` is the repository at `47319f7`. "Spike `file`, `fun/n`" is the copy in
`F-synth-work`, cited by function because its lines move. "Unverified" marks what I could not
check. `F1-Qn`, `F2-Qn`, `F2-Rn`, `FB-n` belong to the design documents `F1.md` and `F2.md`;
`D`, `E`, `H`, `J`, `K`, `N`, `T` to the judges' `JF1.md` and `JF2.md`.

**Labels.** `Rn` (a rule and its revert, §2 and §7) and `FS-Qn` (a question, §13) belong to this
document only. Never cite them in `lib/`, `test/` or `CLAUDE.md`: the labels test
(`test/logex/edit_test.exs:1541-1603`) refuses `R` and a number. The spike cites only decisions
8, 12, 20, 21, 23, 26, 28 and 29 and fixes F1, F2, F3, F7, F11 and F15, all of which org §7
defines, and the labels test passes on it.

**The base, and why.** Both judges chose F2 (JF1 7.5 to 7.0; JF2 7.0 to 6.5). They agree on why:
org §4.9 gives the nested migration to M2-5 ("the members of a function block type, until M2-5
brings the nested migration", org:866; PLAN:1491-1493), and F2 builds it, holding under both
judges' seeded walks. They disagree only on a condition: JF2 makes F2 the base *only if* the
maintainer takes the nested migration in M2-5, and otherwise F1's smaller edit. I take F2, because
the documents already say the migration is M2-5's, and the alternative stays one question
(FS-Q2) with a clean fallback: replace R46 to R63's edit code with F1's refusal (F1's FB-38 to
FB-41), keeping the rest.

---

## 0. The answer in one page

- **A block is a `.ld` file headed `function_block <name>`**, its first rung (comments and blank
  lines may come before it), the name matching the file's. `Logex.compile(source, name: "seal")`
  returns `{:ok, %Logex.FbType{name: "seal", members: [...], body: %Logex.Program{}}}`.
  `function_block` is reserved in a block's file, names no block, and is recognised in any case.
- **A program gets its blocks two ways:** `Logex.compile(source, name:, types: [seal])`, or
  `Logex.compile_file/1`, which finds `seal.ld` beside the file that names `seal`, compiles it
  once, refuses a cycle of files, and refuses a program's file named as a type before it looks
  for a cycle.
- **`cal s1 a b q`:** positional, the block's var_inputs then its var_outputs; rung power is EN,
  and ENO, the power out, is EN. Energised, it copies in, runs the body over `env["s1"]`, and
  copies out. De-energised, it does nothing at all (decision 12). One `cal` runs an instance; a
  `cal` of a `ton`, a bool, a dint, a member, a literal or nothing is a located diagnostic.
- **Members:** from outside, a block's inputs and outputs are read anywhere; its own `var`s are
  hidden; nothing outside writes any of its members.
- **Recursion:** a block holding an instance of itself, at any depth (in its own file, through a
  type given, across files), is one located diagnostic, and its uses add no second message.
  Through a tag declared from Elixir it is an `ArgumentError`.
- **The runtime** finds a body through a new runtime-filled `Scan.tags`; `cal` hands its body
  the scan narrowed to its instance (its tag table and its own subtree of blocked one-shots),
  `now` and `first` the program's. A plain swap that leaves an instance as no map, or a body
  edited by hand that `cal`s an instance its table lacks, runs without raising.
- **Online edit, by path:** a block's type is its name and its members' kinds; its body may
  change, and members may be added or dropped. A switch migrates each instance member by member
  by OE-1's own rules, a one-shot inside is blocked where its chain of rungs changed, nested
  timers meet the timer rules, and an output only a `cal` drove is held. Two judge-found timer
  defects are fixed: Resume now asks which program **last scanned** (as fix F3 does for
  one-shots), and fix F11's undo reaches a timer only one version of a block declares, and one
  inside an instance only one program declares.
- **Receipts:** the gate passes three times (489 tests, 6 doctests, up from 430). PLAN M2-5's
  Done-when is a passing test in `end_to_end_test.exs` through `compile_file/1`, and three more
  in `function_block_test.exs`. 72 rules reverted one at a time: 72 red, each with at least one
  failing test. `api_contract_test.exs` gains a seeded edit walk over programs that hold blocks,
  which asserts its reach. A program with no blocks pays 278→281 reductions per `call/4` and
  7,111→7,308 per compile.

---

## 1. API and data shapes

```elixir
# lib/logex.ex
Logex.compile(source, name: name)                         # unchanged
Logex.compile(source, name: name, types: [%Logex.FbType{}])
Logex.compile(source, types: types, name: name)           # either order
  :: {:ok, %Logex.Program{}}           # a program's source
   | {:ok, %Logex.FbType{}}            # a source whose first rung is `function_block <name>`
   | {:error, [%Logex.Diagnostic{}]}   # every mistake, in line order
Logex.compile_file(path)              # same three shapes; block files found beside (R67-R70)

# lib/logex/compiler.ex
Logex.Compiler.instructionize(routine, declared \\ [], types \\ [])
  :: {:ok, %Logex.Program{}} | {:ok, %Logex.FbType{}} | {:error, [%Logex.Diagnostic{}]}
Logex.Compiler.instructions()         # gains "cal" => {:cal, :block}

# lib/logex/fb_type.ex
%Logex.FbType{name:, members:, body: nil | %Logex.Program{}}          # body is new
%Logex.FbType.Member{role: :input | :output | :local | :internal}     # :local is new
Logex.FbType.of(%Logex.Program{}) :: %Logex.FbType{}                  # new
Logex.FbType.signature(%Logex.FbType{}) :: [{slot, %Member{} | nil}]  # new, cal's operands
Logex.FbType.user?(term) :: boolean                                   # new, total
Logex.FbType.public/1, member/2, writable/1, initial/1,2              # unchanged code

# lib/logex/scan.ex
%Logex.Scan{now:, first:, ons_blocked: [], tags: nil}                 # tags is new, the runtime's

# lib/logex/declarations.ex
Logex.Declarations.kinds() :: ["function_block"]                      # new, for naming_test
Logex.Declarations.block_name?(word) :: boolean                       # new
Logex.Declarations.split(rungs, declared \\ [], types \\ %{})         # types is new
```

`Logex.Runtime` and `Logex.Edit` gain no function. The pinned surface test
(`test/logex/runtime_test.exs:688-735`) changes in three places: `Compiler.instructionize/3`;
`FbType.of/1`, `signature/1` and `user?/1`; `Scan`'s keys gain `:tags`.

**Shapes.**

```elixir
# seal.ld compiled
%FbType{name: "seal",
        members: [%Member{name: "start", type: :bool, role: :input,  write: false, initial: 0},
                  %Member{name: "stop",  type: :bool, role: :input,  write: false, initial: 0},
                  %Member{name: "run",   type: :bool, role: :output, write: false, initial: 0}],
        body: %Program{name: "seal", source: "function_block seal\n...", rungs: [...],
                       tags: %{...}, warnings: [...]}}

# member order: tags declared from Elixir first, by name, then declaration lines in order
# (spike FbType.of/1, order/1); a member holding an instance carries its overrides map
%Member{name: "t1",    type: Logex.FbType.ton(), role: :local, initial: %{"pre" => 250}}
%Member{name: "inner", type: seal,               role: :local, initial: %{}}

# the IR of `xic en cal s1 a stop k1`
{:rung, [{:xic, 9, [{:name, 9, "en"}]},
         {:cal, 9, [{:name, 9, "s1"}, {:name, 9, "a"}, {:name, 9, "stop"}, {:name, 9, "k1"}]}]}

# an instance's state: one map per instance, at any depth (Program.initial_env/1, unchanged)
env["s1"]                == %{"start" => 0, "stop" => 0, "run" => 1}
env["o"]["inner"]["run"] == 1

# the instance's block list: a bit by its path
%Logex.Instance{ons_blocked: ["edge", "p1.edge", "o.inner.edge"]}

# what call/4 hands the evaluator, built once a scan
%Logex.Scan{now: 60, first: false, tags: program.tags,
            ons_blocked: %{"edge" => true, "p1" => %{"edge" => true},
                           "o" => %{"inner" => %{"edge" => true}}}}
# and what `cal p1 ...` hands p1's body
%Logex.Scan{now: 60, first: false, tags: pulse.body.tags, ons_blocked: %{"edge" => true}}
```

Inside `Logex.Edit` (private, built at accept from the two programs alone, fix F5), each
direction's plan has `nested`: one entry per instance either program declares. An instance the
program started declares has a member plan, `%{members: [...], names: %{...}}`, whose entries
are `{:leaf, name, type, initial, old_initial, kept?}`, `{:timer, name, keys, start, from_pre,
to_pre, kept?}`, `{:block, name, {type, overrides}, kept?, plan}`, and, new here,
`{:timer_gone, name}` and `{:block_gone, name, plan}` for what only the stopped program's version
declares. An instance only the stopped program declares has a gone plan of its timers alone. A
member plan is built once per `{type name, whether the other program holds the type, {ran, run}}`,
and a gone plan once per type name, so planning is linear in the types and their members.

---

## 2. Rules, numbered

Each rule names where it is decided (or the question that leaves it open), the code that holds
it, and its revert in §7. A rule a test cannot see is listed at the end with why.

### A block's file

- **R1** The header word is recognised in any case (org §4.8 recognises keywords so). Spike
  `Compiler.file_kind/1`.
- **R2** A block compiles to its type: a `var_input` an `:input`, a `var_output` an `:output`, a
  `var` a `:local` member; `write: false` on each; the body a `%Program{}` named after the block
  (F2-R2; FS-Q13). Spike `FbType.of/1`.
- **R3** Its name is the name it is compiled under, and so its file's (PLAN:1340-1341). Spike
  `Logex.named_as/4`.
- **R4** Its name is a name, and no reserved word: `var s1 move` would read a mnemonic. Spike
  `Compiler.reserved_block/3`.
- **R5** `function_block` names no block, in any case (org:744; JF2 D3, from F1's FB-3). Spike
  `Compiler.reserved_block/3`, `header_word/3`; `Declarations.block_name?/1`.
- **R6** `function_block` names no tag in a block's file; one declared from Elixir is an
  `ArgumentError` (org:744). Spike `Compiler.header_tags/2`.
- **R7** `function_block` in mnemonic position, anywhere, has its own message. Spike
  `Compiler.unknown/2`.
- **R8, R9** A `%FbType{}` given to the runtime or to `Edit.accept/3` gets its own
  `ArgumentError` (from F1; JF2 H10, H11, H13). Spike `Runtime.program!/1`, `Edit.program!/1`.
- **R10** Members follow `cal`'s positional order: tags declared from Elixir first, by name, then
  declaration lines in order (JF1 defect 4; FS-Q24). Spike `FbType.order/1`.

### The types a compile is given

- **R11** `types:` holds only types `FbType.user?/1` accepts; anything else is a host mistake
  (decision 28; org:779). Spike `Compiler.library!/1`.
- **R12** `user?/1` holds exactly when a type is `of/1` of its body, every type it holds valid,
  and none holding a type of its own name at any depth (JF2 H4, H5: a hand-edited `write: true`
  or reordered members are refused). Spike `FbType.valid/3`, `fresh/4`.
- **R13** `user?/1` refuses a name no block could have: not a name, reserved, or the header word.
  Spike `FbType.named/4`.
- **R14** `user?/1` accepts a member declared from Elixir, which has no line, so a type
  `instructionize/3` makes from Elixir tags is one a compile takes (JF1 defect 4). Spike
  `FbType.declared?/1`.
- **R15** No two blocks of one name in `types:`. Spike `Compiler.given!/3`.
- **R16** One version of each block name per compile, across the types given, the types they
  hold, and the types of tags declared from Elixir: the runtime and the edit look types up by
  name (FS-Q14). Spike `Compiler.one_version!/2`.
- **R17** The unknown-type message lists the blocks given, with a did-you-mean among them, case
  first (from F1's FB-12; JF1 graft 3). Spike `Declarations.unknown_type/4`.
- **R18** From Elixir, `Tag.new!("s1", seal)` with an initial value is refused with the message a
  declaration line gets (decision 28). Spike `Declarations.instance/1`.

### Recursion

- **R19** A block never holds an instance of itself: its own name as a type word in its own file
  is refused at the `var` line (Ed 2 §2.5; org:342-344). Spike `Compiler.marked/2`.
- **R20** Nor of a type given that holds a type of its name, at any depth, the chain named. Spike
  `Compiler.marked/2`, `chain/3`.
- **R21** Nor through a tag declared from Elixir: an `ArgumentError`, since no line can cite it
  (JF1 defect 3; from F1). Spike `Compiler.holds_itself!/2`.
- **R22** The uses of a declaration refused as recursive are excused, so one mistake gives one
  message (JF1 graft 2, JF2 D7; from F1's FB-16). Spike `Compiler.excused/3`, `excused?/2`.

### `cal` at compile time

- **R23** `cal` of a `ton` is refused, naming the `ton` that runs it (PLAN:1352-1353). Spike
  `Compiler.not_run/5`.
- **R24** `cal` of a bool or a dint is a located "`cal` of a non-instance" (PLAN M2-5's
  Done-when). Spike `Compiler.not_run/5`.
- **R25** An arity error names every formal, in order (org §4.3). Spike `Compiler.cal_count/5`.
- **R26** An operand of the wrong type names the formal it fills (org:325-326). Spike
  `Compiler.typed_formal/5`.
- **R27** A var_input where `cal` writes is refused. Spike `Compiler.input_formal/4`.
- **R28** A member logic may not write, where `cal` writes, is refused. Spike
  `Compiler.member_formal/6`.
- **R29** A literal that does not fit an input is refused. Spike `Compiler.fits_formal/5`.
- **R30** One `cal` runs an instance; a second is an error at its line, citing the first
  (FS-Q11). Spike `Compiler.calls/1`.

### Members and warnings

- **R31** A user block's inputs and outputs are read anywhere an operand of their type may go
  (decision 9; org:328; FS-Q7). Spike `FbType.public/1`.
- **R32** Its own `var`s are hidden: from outside, no path is deeper than one member (FS-Q9).
  Spike `FbType.public/1`.
- **R33** No member of a user block is written by logic outside it (FS-Q8). Spike `FbType.of/1`
  (`write: false`), `Compiler.unwritable/3`.
- **R34** An instance no `cal` runs is warned about, saying `cal` (PLAN:1350-1351). Spike
  `Warnings.uncalled/2`.
- **R35** A `cal`'s operands are uses with its block's signature: an output only a `cal` drives is
  driven, and a `cal` output onto an `ons` storage bit is warned about. Spike
  `Warnings.signature/3`.
- **R36** A block's body is warned about as a program is, in `type.body.warnings`. Spike
  `Compiler.lowered/4`.

### Running a block

- **R37** De-energised, nothing: no copy in, no body, no copy out (decision 12). A timer inside
  keeps `.en` and `last` and catches up (decision 8; PLAN:1349-1350). Spike
  `Runtime.evaluate/3`.
- **R38, R39** Energised: inputs copied in, body run over the instance's map, outputs copied out
  (org:293-307). Spike `Runtime.called/5`, `copy_in/3`, `copy_out/3`.
- **R40** ENO is EN: anything may follow a `cal` on its path (org:296-297).
- **R41** `first` and `now` are the program instance's inside a body (PLAN:1351-1352; FS-Q10).
- **R42** The body sees its own instance's blocked bits and its type's tag table, no other: a
  program bit `edge` and a block's `edge` never collide.
- **R43** `scan.tags` is the runtime's: a host that fills it in is refused, as one that fills
  `ons_blocked` is (OE-1). Spike `Runtime.scan!/2`.
- **R44** An instance a plain swap left as no map runs from an empty one (within the contract: a
  plain swap is a scan of another program). Spike `Runtime.called/5` (`as_map/1`).
- **R45** A `cal` of an instance its table does not hold as a user block's, which only a body
  edited by hand can have, runs nothing (JF2 D2b; from F1's total clause). Spike
  `Runtime.called/5`.

### The online edit of a program that holds blocks (`Logex.Edit`)

- **R46** A user block's type, for the edit, is its name and its members' kinds, at any depth: its
  body, member order and roles, and members added or dropped are not part of it (org:858-869;
  FS-Q2). Spike `Edit.changes/3`.
- **R47** A member whose kind changes is refused by its path, as a member's, at the instance's
  line. Spike `Edit.retyped/4`, `whose/1`.
- **R48** Inside an instance both programs declare, a member the state lacks starts at its
  initial value, reported `{:added, "p.count", 7}` (the nested migration). Spike
  `Edit.moved_member/4`.
- **R49** At the first test a member the candidate's version adds, or whose value does not fit
  its type, starts too (decision 26, by path). Spike `Edit.moved_member/4`, `starts?/4`.
- **R50** At the first test an instance a plain swap left as no map starts whole (decision 26;
  JF2 K2). Spike `Edit.fits?/2`.
- **R51** A kept member whose initial value changed keeps its value and is reported
  `{:initial_changed, "p.n", {5, 6}}` (decision 29, by path; FS-Q17). Spike
  `Edit.initial_changed/3`.
- **R52, R53** Assemble and cancel prune what the kept version does not declare, at any depth,
  `{:pruned, "w1.p.old", 4}` (JF2 K4). Spike `Edit.prune/3`, `prune_members/4`, `nested_prune/3`.
- **R54, R55** An `ons` inside an instance a `cal` runs is a one-shot of the program, its bit
  named by its path, its rung the chain of stripped rungs from the program's `cal` rung down to
  the body's rung; decision 21 blocks it where any rung on the chain is new or changed, at any
  depth (FS-Q5; JF2 K6 and F1 J4). Spike `Edit.rungs/1`, `inside/5`.
- **R56** A blocked bit inside an instance is reported with its value, found by path (F1 J1).
  Spike `Edit.bit_at/2`.
- **R57** A nested bit an earlier edit left pending survives a second edit before any scan (fix
  F2, by path). Spike `Edit.facts/1` (`ons_bits`).
- **R58** A timer inside a block meets the `.pre` rules by its path, with the presets of the
  `ton`s in each version, where each program runs the block (decision 23, fixes F1 and F6).
  Spike `Edit.runs_ton/2`.
- **R59** A nested plan is per whether each program runs the instance, so an instance no `cal`
  runs keeps its `.pre` frozen beside one that a `cal` runs (decision 23; JF2 K5). Spike
  `Edit.member_plan/5`.
- **R60** A timer both programs run is never resumed: one frozen by a false `cal` catches up when
  the block next runs (decision 8; FS-Q6). Spike `Edit.resumed/4`.
- **R61** Resume happens only where the program the switch stops is the one that last scanned,
  asked as fix F3 asks it for one-shots (org:1021-1031). A test then an untest with no scan
  between therefore leaves a timer a false EN froze exactly as it was (JF1 defect 1, `p3.exs`
  case A). Spike `Edit.switch/4` (`clock`), `resumed/4`.
- **R62** Fix F11's undo, and the `.pre` undo of fix F1, reach a timer only the stopped program's
  version of a block declares (JF1 defect 2, `p3.exs` case B). Spike `Edit.gone/3`,
  `moved_member/4` (`:timer_gone`, `:block_gone`).
- **R63** And a timer inside an instance only the stopped program declares (found by this pass's
  walk, seed 3: `y.t1`). Spike `Edit.nested/2`.
- **R64** An output only a `cal` drove is held where the candidate drives it no more (decision
  20, through R35's writes). Spike `Edit.calling/3`.
- **R65** The edit's walk is total on a body edited by hand: a `cal` of no block writes and runs
  nothing, as the runtime runs nothing (R45). Spike `Edit.calling/3`.
- **R66** The plan builds a nested block's initial state only where one starts; built for every
  member it made the plan quadratic in the depth (F2-R48). Spike `Edit.block_moved/4`.

### Loading a block's file (`Logex.compile_file/1`)

- **R67** A type word that is a name, no reserved word, no built-in type and not the file's own
  name, is looked for as `<word>.ld` beside the file that names it, compiled first, once per call
  (FS-Q12). Spike `Logex.needed/2`, `dependency/3`, `found/4`.
- **R68** A mistake in a block's file is reported with that file, and the file that names it is
  not compiled further (FS-Q15). Spike `Logex.in_file/2`.
- **R69** A program's file named as a type is refused at the `var` line, in the file that names
  it, before any cycle is looked for (JF2 D5: before, `blk.ld` naming `prog`, which holds `blk`,
  was reported as a cycle in `prog.ld`). Spike `Logex.kind_of/4`, `peek/1`.
- **R70** A dotted type word names no file: `var s a.b` is an unknown type where it is written
  (JF2 D6). Spike `Logex.needed/2`.

### Naming

- **R71, R72** `function_block` and `cal` each have a `docs/naming.md` stanza, which
  `naming_test.exs` checks (CLAUDE.md step 1). The stanzas are F1's, read from IEC Ed 2 and Ed 3
  directly (JF1 graft 1, JF2 D4), reworded to name the conventional family's user-defined
  instructions without its own term (FS-Q25).

### Rules no revert separates, and why

- **R73** A cycle of block files is refused at the line in the file that closes it, naming the
  chain. Reverting it makes the loader recurse without end, so the suite never reports; its test
  is `function_block_test.exs` "a chain of files that holds itself …".
- **R74** `cal` is reserved in every `.ld`, in any case. The reservation is `@instructions`
  membership; removing it removes the instruction, and every `cal` test fails for that reason.
  Pinned by "cal is reserved, a mnemonic" and JF2 N1, N2.
- **R75** The header may follow comments and blank lines. No code holds this: the lexer drops
  comments before the parser sees a line. It is pinned by "its header is its first rung", and
  is a departure (§11, item 5).
- **R76** `ton s1 5000` on a user instance gives the instance no preset (spike
  `Compiler.run_by/4` matches only a built-in). The `{:instance, "ton"}` refusal fires anyway, so
  the program never compiles and no test can see the preset. Hygiene.
- **R77** The host sets no member of a user instance (`put_inputs/3`). Unchanged code
  (`runtime.ex:310-351`), exercised by JF2's walk and F2's `misc.exs`.

### PLAN M2-5's notes from M1-6, each answered

| PLAN M2-5 (PLAN:1347-1353) | Answer |
|---|---|
| `Logex.FbType` already recurses into a member whose type is a type | Kept; nested state from `initial/2`, unchanged; a member holding an instance carries its overrides (R2) |
| `public/1` leaves a `:local` role out | Kept; `:local` in the typespec, hidden from outside (R32) |
| a frozen instance leaves a timer's `.en` and `last` alone | R37; across an edit too (R60, R61) |
| the "no `ton` runs it" warning must say `cal` for a user type | R34 |
| `first` is the program instance's | R41 |
| which of a user block's members logic may write is open | none (R33; FS-Q8) |
| `cal` on a built-in type should be refused | R23 |

---

## 3. Every host-mistake message and diagnostic, exact

### 3.1 Host mistakes (`ArgumentError`), each pinned by a test

| Where | Message |
|---|---|
| `compile/2`, a bad option | ``Logex.compile/2 takes a name and, where the source uses function blocks, their types, as in Logex.compile(source, name: "motor", types: [seal]), got: …`` (replaces M1-5's, `lib/logex.ex:65-71`, pinned at `test/logex_test.exs:133-138`) |
| `types:` not a list | `types must be a list of function block types from Logex.compile/2, got: …` |
| an element `user?/1` refuses (R11-R13) | `types must be function block types from Logex.compile/2, got: …` |
| two of one name (R15) | ``types holds two function blocks named `seal`: one name, one type`` |
| two versions of one name (R16) | ``types holds two different function blocks named `seal`, one inside another type given: compile each block against the same types`` |
| a block holding itself through a tag from Elixir (R21) | ``` `y` holds an instance of `a`, the function block being compiled: a function block never holds an instance of itself, at any depth ``` |
| a tag from Elixir named the header word, in a block (R6) | ``` `Function_Block` heads a function block's file and cannot name a tag in one ``` |
| `Runtime.*` or `Edit.accept/3` given a block type (R8, R9) | ``` `seal` is a function block type, which runs inside a program through `cal`: an instance is of a %Logex.Program{} ``` |
| `scan.tags` filled by the host (R43) | `scan.tags is the runtime's, taken from the program: a host leaves it out, got: …` |
| `Tag.new!/4`, a user type and an initial value (R18) | ``` `s1` is a seal: an instance takes no initial value, and its members start where its type says ``` |
| `Tag.new!/4`, a type `user?/1` refuses | ``unknown function block type "seal": logex has Logex.FbType.ton() and the types Logex.compile/2 gives for a function block's file`` (M1-6's, extended; its pins in `validation_test.exs` move to an attribute) |

### 3.2 Diagnostics (`:validate`), each asserted in a whole list from source

`line N: ` comes before each; from `compile_file/1`, `path: ` before that.

| Rule | Message |
|---|---|
| R1, header | ``` `function_block` takes the block's name, as in `function_block seal` ``` |
| R3 | ``this function block is `seal`, but it is compiled as `latch`: a block is named after its file`` |
| R4 | ``` `move` is an instruction and cannot name a function block ```; ``` `Var_Input` is a keyword and cannot name a function block ```; ``` `a.b` cannot name a function block: a name is a letter or `_`, then letters, digits or `_` ``` |
| R5 | ``` `Function_Block` is a keyword and cannot name a function block ``` |
| R6 | ``` `function_block` heads a function block's file and cannot name a tag in one ``` |
| R7 | ``` `function_block` heads a function block's file, as its first line ``` |
| R17 | ``unknown type `sael`: logex has `bool`, `dint` and `ton`, and the function block `seal` — did you mean `seal`?`` (several: ``and the function blocks `latch` and `seal` ``; case: ``— did you mean `seal`? (type names are case-sensitive)``). Without a library the M1-3 message is unchanged |
| R19 | ``` `seal` cannot hold an instance of `seal`: a function block never holds an instance of itself ``` |
| R20, R73 | ``` `a` cannot hold an instance of `c` (a → c → b → a): a function block never holds an instance of itself, at any depth ``` |
| R23 | ``` `cal` runs an instance of a user function block, but `t1` is a ton (declared on line 5), which `ton t1` and its preset run ``` |
| R24 | ``` `cal` runs an instance of a function block, but `x` is a bool (declared on line 1) ``` |
| `cal` of a member, literal, nothing, reserved word | ``` `cal` runs an instance of a function block, named whole: found `s1.run` ```; ``` `cal` expects an instance of a function block, found `5` ```; ``` `cal` expects an instance of a function block, found none ``` (+ `stopped_at`); ``` `cal` expects an instance of a function block, found the keyword `var` ``` (or `the type`, `the instruction`); an undeclared name gets M1-3's message once |
| R25 | ``` `cal s1` expects 3 operands after its instance, `start` (var_input bool), then `stop` (var_input bool), then `run` (var_output bool): found 2 ``` (+ `before the instruction …`) |
| R26 | ``operand 2 of `cal s1` is `stop` (var_input bool), but `n` is a dint`` |
| R29 | ``operand 2 of `cal s1` is `stop` (var_input bool): only 0 or 1 fit, found `7` ``; ``… (var_input dint): `X` does not fit in 32 bits`` |
| literal where `cal` writes | ``operand 3 of `cal s1` is `run` (var_output bool), which it writes: found `1` `` |
| R27 | ``operand 3 of `cal s1` is `run` (var_output bool), which it writes: `b` is a var_input (declared on line 2), and logic must not write an input`` |
| an instance named whole as an operand | ``operand 1 of `cal s1` is `start` (var_input bool), but `t1` is a ton (declared on line 5): name one of its members`` |
| R28 | ``operand 3 of `cal s1` is `run` (var_output bool), which it writes: logic may write only `.pre` and `.acc` of a ton`` |
| R30 | ``` `s1` is already run by the `cal` on line 5: one `cal` runs an instance ``` (`in this rung` where both are on one line) |
| R32 | ``` `l1.held` is not a member of `l1`, a latch: its members are `set` and `q` ``` (M1-6's, unchanged) |
| R33 | ``` `ote` writes `s1.run`, but no member of a seal is written from outside it: its body writes them ``` |
| members of a non-instance | ``` `x.run` names a member of `x`, but `x` is a bool (declared on line 2): only an instance of a function block has members ``` (was "only a timer has members", `validation_test.exs:1607,1611,1637,1692`, `api_contract_test.exs:108`) |
| R69 | ``` `prog` is a program (prog.ld), not a function block: only a function block's file gives a type for `var` ``` (with `file:` the file that names it, at its `var` line) |
| R70 | ``unknown type `a.b`: logex has `bool`, `dint` and `ton` `` |

### 3.3 Edit diagnostics (`:edit`)

| Rule | Message |
|---|---|
| R47 | ``line 4: `p.edge` is a bool in the running program and a dint in the candidate: a member's type changes only with a restart`` |
| a block renamed | ``line 4: `p` is a pulse in the running program and a latch in the candidate: a tag's type changes only with a restart`` (OE-1's, unchanged) |

Sorted by `{line, tag, path}`; a tag from Elixir last; still no file (fix F15).

### 3.4 Warnings

| Rule | Message |
|---|---|
| R34 | ``line 2: warning: `s2` is a seal, but no `cal` runs it: it never runs, and its members stay at their initial values`` |
| R35 | ``line 6: warning: `cal` writes `e`, the storage bit of the `ons` on line 5: the one-shot then fires on the wrong scans`` (M1-6's, `cal` as the writer) |

### 3.5 Deliberately unchanged

The unknown type with no library (`validation_test.exs:416,505,661,1105`); "`t2` is a ton, but no
`ton` runs it" (`validation_test.exs:1173,1347`); OE-1's top-level type-change message
(`edit_test.exs:59-81`).

---

## 4. Every new piece of state, across an online edit

CLAUDE.md "New state in an instance" and org:1106-1122. `%Logex.Instance{}` gains no field: the
block list keeps its type and check (fix F8); only its names may now be paths.

| State | `instance/1` | a scan | `restart/3` | a switch (test, untest) | assemble, cancel | first test only |
|---|---|---|---|---|---|---|
| an instance's map, `env["s1"]` | `Program.initial_env/1` recursively (`FbType.initial/2`) | an energised `cal` replaces it; a false EN leaves it; one left as no map runs from `%{}` (R44) | started again | kept where both programs declare it with one type name; started whole, `:added`, where the state lacks it | pruned where the kept program does not declare it | started whole where the candidate adds it or it is no map (R50) |
| a member inside it, `s1.count` | its member's initial | written by its body only | started again | the nested migration (R48): kept; started where missing; `:initial_changed` where its initial differs (R51) | pruned by path where the kept version does not declare it (R52, R53) | started where the candidate's version adds it, or its value does not fit (R49) |
| a timer inside it, `s1.t1` | `initial` with the body's preset | its `ton`, if the block runs | started again | `.pre` rules by path (R58, R59); Resume only where the stopped program last scanned and does not run it (R60, R61); undo by path over both versions and both programs (R62, R63); the record's `pre` keyed by path | as a member | started where added or its keys do not fit |
| a one-shot bit inside it, `s1.edge` | its initial | its `ons`, if the block runs | started again; the block list emptied | listed by path where its chain changed (R54, R55), its instance is added, or it is pending (R57); the bit untouched | not listed (no switch) | — |
| `scan.tags` | — | filled from the program, narrowed per body | — | — | — | — |

`first` stays false at a switch. Var_inputs stay top-level, the program's interface: a block's
inputs are copied in by `cal`, never `:input` or `:unread`.

---

## 5. What each later item and OE-2 add

- **M2-1 (scheduler).** `start/1` builds each instance through `instance/1` (fix F14), so nested
  state needs nothing new; `cycle/3` calls `call/4`, which fills `scan.tags`. `get(rt,
  "m1.s2.run")` resolves the part after the instance name with the compiler's member lookup,
  which under R31 and R32 reaches a tag or one member of an instance and no deeper. A
  configuration needs no block library: every block a program holds is inside its tags. M2-1's
  acceptance asserts `get(rt, "m1.s2.run")` (FS-Q1).
- **M2-2 (`.lcf`).** The loader's rule, a type word names a file beside the file that names it, is
  also `program m1 motor`'s: `motor.ld` beside the `.lcf`, its blocks beside `motor.ld`. One
  `load/3`, one memo, one cycle check. "Names its file and line" needs fix F15: the loader stamps
  a block file's diagnostics with its file, but `%Program{}` keeps none (readiness §2.3).
- **M2-3.** Nothing new: a block's timers read the scan's `now`, the task's clock.
- **M2-4 (`var_external`).** A body runs over its instance's map, which holds no global.
  Recommend refusing `var_external` in a block's file in M2-4: a block takes a global through a
  `var_input` operand. Whether IEC allows VAR_EXTERNAL in a FUNCTION_BLOCK is unverified here
  (inventory U19). M2-4's public "which tags a program writes" should take the cal-aware walk
  (FS-Q23).
- **M2-6.** Nothing new: an `ons` in a block in an event task follows R41.
- **OE-2.** The plans are already per program type, the switch and prune per instance (fix F5),
  so the nested plans ride along. Report names gain the instance in front, `m1.p.count`. A block
  type changed for the whole configuration changes every program type that holds it, each by its
  own plan. PLAN OE-2's "a function block's members … until M2-5" (PLAN:1491-1493) is lifted by
  R46 to R48; under FS-Q2's alternative it stays. The generation counter is unaffected.

---

## 6. Spike receipts

- **Gate**, three times on the finished spike (`F-synth-gate.sh`, `F-synth-gate.log`):
  `mix format --check-formatted` 0; `mix compile --force --warnings-as-errors` 0;
  `MIX_ENV=test mix compile --force --warnings-as-errors` 0; `mix test --warnings-as-errors` 0,
  `Result: 489 passed (6 doctests, 483 tests)`, each time. HEAD gives 430.
- **New tests: 59.** `function_block_test.exs` 56, `end_to_end_test.exs` 1,
  `api_contract_test.exs` 1, `naming_test.exs` 1.
- **Done-when** (`F-synth-donewhen.log`, `--trace`):
  ```
  * test user function blocks (M2-5) PLAN M2-5's Done-when: a seal-in written once as a block, run three times (20.3ms) [L#1419]
  Result: 1 passed, 78 excluded
  * test PLAN M2-5's Done-when a false EN freezes only its own instance, and the tags its outputs name (17.6ms) [L#105]
  * test PLAN M2-5's Done-when a recursive type, an unknown function block type and a cal of a non-instance are each a located diagnostic (1.1ms) [L#122]
  * test PLAN M2-5's Done-when a seal-in written once as a block and instantiated three times behaves as three independent seal-ins, and m1.s2.run reads one of them (0.2ms) [L#82]
  Result: 3 passed, 53 excluded
  ```
  The end-to-end test writes `seal.ld` and `plant.ld` to a temporary directory and compiles
  `plant.ld` with `Logex.compile_file/1` alone. Three seal-ins run independently through nine
  scans; a false EN on `s3` freezes `s3` and `run_3` only; `m1.s2.run` is read by the rung
  `xic s2.run ote lamp_2` and from `m1.env["s2"]["run"]`; and `loop.ld`, `unknown.ld` and
  `wired.ld` give, exactly, one recursion message (its use excused), the unknown type with
  "did you mean `seal`?", and "`cal` runs an instance of a function block, but `start_1` is a
  bool (declared on line 1)", each prefixed by its file.
- **Reverts:** 72 of 72 red (§7; `F-synth-mutation.py`, `.json`, `.log`, `F-synth-mutation/`).
- **The judges' probes on the spike:** JF1 `p3.exs` case A untest reports `[]` and `x.t1` reaches
  acc 40, as with no edit; case B untest reports `[{:resume_undone, "x.t1", 30}]` and `last`
  10. JF1 `walk.exs` (80 seeds × 120 steps): 0 failures (`F-synth-jf1walk.log`). JF2 `walk.exs`
  seeds 1-3 × 300 and `walk2.exs` seeds 11-12 × 300: 0 escapes, 0 rebuild mismatches, 0
  duplicates, 0 forecast mismatches (`F-synth-jf2walk.log`). JF2 `soup.exs` seed 1, 4,000
  soups: 0 escapes. JF2 `n8.exs`: `function_block function_block` is an error. JF2 `loader.exs`:
  `blk.ld: line 4: `prog` is a program (prog.ld)…` from either file; `dotted.ld: line 3:
  unknown type `a.b``. Diffs of JF1 `p1`-`p8` against F2's logs: `F-synth-p*.diff`.
- **Cost** (`F2-probe/cost.exs`, least of 200, three runs, identical): the README motor at HEAD
  (copy `F2-base`) against the spike, `call/4` with no inputs 278 against 281, `compile/2` 7,111
  against 7,308. A seal through `cal` 269 against 151 inline. (An excused-uses walk on every
  program first cost 7,656; it now runs only for a block's file.)
- **Growth:** F2's two growth tests pass unchanged (scan, compile and edit at 50 and 800 levels,
  bound 20.5; the scan after a switch at 250 and 4,000 nested blocked bits, bound 24). Ratios
  over 5 runs on the spike (`F-synth-ratios.exs`, F2's probe; `F-synth-ratios.log`), at 50 and
  800 levels (16x): scan 15.31x to 15.54x, compile 13.24x to 13.43x, edit 15.34x to 16.54x; the
  blocked scan at 16x the bits 16.14x to 16.19x. F2 measured compile at 12.0x to 12.4x; the
  recursion checks from Elixir and the excused uses add about one more x, still linear.

---

## 7. Test plan and mutation table

### 7.1 Tests

`test/logex/function_block_test.exs`, 56 tests:

| Describe | Pins |
|---|---|
| PLAN M2-5's Done-when (3) | R37-R39, R31, R19, R22, R17, R24 |
| a function block's file (6) | R1-R10, R13, R32, R75 |
| the types a compile is given (3) | R10-R18, R14, R16 |
| recursion (1) | R20, R21 |
| cal (4) | R23-R30, R74 |
| members (1) | R31, R33 |
| warnings (3) | R34-R36 |
| running a block (7) | R40-R45, R37 |
| the online edit of a program that holds blocks (12) | R46-R49, R51, R54, R57, R58, R60, R64 |
| the online edit, at depth and across a round trip (8, new) | R50, R53, R55, R56, R59, R61, R62, R63 |
| a block's file found beside the file that names it (4) | R67-R70, R73, R3 |
| growth in the depth, in the instances (2) | R66 |
| the host contract over sources that use blocks (1) | 3,000 seeded soups, now with a fixed seed |
| an instance's state nests by path (1) | — |

`end_to_end_test.exs`: the Done-when through `compile_file/1` (R67, R68 for files).
`api_contract_test.exs`: a fourth walk, 800 walks × 100 steps over 252 programs built from 9
versions of `blk`, 4 of `wrap` (which holds a `blk`) and 7 programs. Its oracles: the writes of
each report, applied by path, rebuild the state; the block list equals the `:ons_blocked`
entries; after a switch every leaf of the started program's initial env is present; after a
prune no leaf the kept program lacks remains; a test then an untest with no scan between gives
back every leaf neither switch started, `last` included; and on the scan right after a switch, a
`blk` one-shot one level (`x`) or two levels (`w.inner`) down, whose chain of rung texts differs
from the program that last scanned, passes no power where it ran. It asserts its reach: every
step kind, a refusal, a round trip with a nested timer, both one-shot oracles, and nested
`:added`, `:dn_drops`, `:dn_rises`, `:initial_changed`, `:ons_blocked`, `:preset`, `:pruned`,
`:resume_undone`, `:resumed`. It held at each of the seeds 1 to 16. Changed pins:
`runtime_test.exs` (surface, `Scan` keys), `logex_test.exs` (options message),
`validation_test.exs` and `api_contract_test.exs:108` ("only an instance of a function block has
members"), `naming_test.exs` (a test over `Declarations.kinds/0`).

### 7.2 Mutation table

Each rule of §2 reverted alone in a copy of the finished spike, the whole suite run with
`mix test --warnings-as-errors`, the file restored. Driver `F-synth-mutation.py` (`check` then
`run`, four copies in parallel), results `F-synth-mutation.json`, logs
`F-synth-mutation/Rn.log`, summary `F-synth-mutation.log`. **All 72 exited 2, and every one has
at least one failing test.** Fifteen (marked w) also printed a compile warning in `lib/` from
Elixir 1.20's type checker, which sees a clause made unreachable; the suite still ran, and the
failing tests are listed. During the first run, R63 survived (no test reached an instance only
one program declares); a test was added and R63 then failed. A first run also showed the soup
property was unseeded and flaky (39 programs where it asks for more than 40); it now seeds
`{2026, 10, 2}`.

| Revert | Rule reverted | File | Exit | Result | Tests that failed |
|---|---|---|---|---|---|
| R1 | the header word is recognised in any case | `logex/compiler.ex` | 2 | 488/489 passed (6/6 doctests, 482/483 tests) | FunctionBlockTest: a function block's file its header is its first rung: comments and blank lines may come before it |
| R2 | a var is a :local member | `logex/fb_type.ex` | 2 | 487/489 passed (6/6 doctests, 481/483 tests) | LogexTest: compile/2 compiling stays linear in the depth of nesting; FunctionBlockTest: a function block's file a var is local: in the state, named only inside the block |
| R3 | a block is named after its file | `logex.ex` | 2 | 487/489 passed (6/6 doctests, 481/483 tests) | FunctionBlockTest: a function block's file its first line names it as it is compiled, and as its file is named; FunctionBlockTest: a block's file found beside the file that names it a program's file is no type, and a block's first line must match its file's name |
| R4 (w) | a block's name is no reserved word | `logex/compiler.ex` | 2 | 488/489 passed (6/6 doctests, 482/483 tests) | FunctionBlockTest: a function block's file its first line names it as it is compiled, and as its file is named |
| R5 | function_block names no block (org §4.8) | `logex/compiler.ex` | 2 | 488/489 passed (6/6 doctests, 482/483 tests) | FunctionBlockTest: a function block's file its first line names it as it is compiled, and as its file is named |
| R6 (w) | function_block names no tag in a block's file | `logex/compiler.ex` | 2 | 432/489 passed (6/6 doctests, 426/483 tests) | FunctionBlockTest: the online edit of a program that holds blocks at the first test a member whose value does not fit its type starts again (decision 26), by its path; FunctionBlockTest: the online edit, at depth and across a round trip a timer in an instance no cal runs keeps its .pre frozen, beside one of the same block that a cal runs (decision 23); FunctionBlockTest: the online edit of a program that holds blocks a timer inside a block meets the preset rules by its path; and 54 more |
| R7 | function_block outside the first line has its own message | `logex/compiler.ex` | 2 | 487/489 passed (6/6 doctests, 481/483 tests) | FunctionBlockTest: the host contract, over sources that use blocks compile/2 never raises, its diagnostics are in line order and it reaches every M2-5 diagnostic; every program it gives scans without raising; FunctionBlockTest: a function block's file function_block is reserved in a block's file only, and heads it |
| R8 (w) | the runtime refuses a block type with its own message | `logex/runtime.ex` | 2 | 488/489 passed (6/6 doctests, 482/483 tests) | FunctionBlockTest: a function block's file a block is not a program: the runtime and the edit refuse its type |
| R9 (w) | the edit refuses a block type with its own message | `logex/edit.ex` | 2 | 488/489 passed (6/6 doctests, 482/483 tests) | FunctionBlockTest: a function block's file a block is not a program: the runtime and the edit refuse its type |
| R10 | members follow declaration order, those from Elixir first | `logex/fb_type.ex` | 2 | 488/489 passed (6/6 doctests, 482/483 tests) | FunctionBlockTest: the types a compile is given from Elixir, an instance of a user block is a tag whose type is the block's |
| R11 | types: holds only types user?/1 accepts | `logex/compiler.ex` | 2 | 488/489 passed (6/6 doctests, 482/483 tests) | FunctionBlockTest: the types a compile is given each must be one Logex.compile/2 gave, no two of one name |
| R12 | user?/1 is what of/1 gives for its body | `logex/fb_type.ex` | 2 | 488/489 passed (6/6 doctests, 482/483 tests) | FunctionBlockTest: the types a compile is given each must be one Logex.compile/2 gave, no two of one name |
| R13 (w) | user?/1 refuses a name no block could have | `logex/fb_type.ex` | 2 | 488/489 passed (6/6 doctests, 482/483 tests) | FunctionBlockTest: a function block's file its first line names it as it is compiled, and as its file is named |
| R14 | user?/1 accepts a member declared from Elixir | `logex/fb_type.ex` | 2 | 488/489 passed (6/6 doctests, 482/483 tests) | FunctionBlockTest: the types a compile is given from Elixir, an instance of a user block is a tag whose type is the block's |
| R15 | types: holds no two blocks of one name | `logex/compiler.ex` | 2 | 488/489 passed (6/6 doctests, 482/483 tests) | FunctionBlockTest: the types a compile is given each must be one Logex.compile/2 gave, no two of one name |
| R16 | one version of each block name, in the types given | `logex/compiler.ex` | 2 | 488/489 passed (6/6 doctests, 482/483 tests) | FunctionBlockTest: the types a compile is given a type holds one version of each block, the one given under its name |
| R17 | the unknown-type message suggests a block given | `logex/declarations.ex` | 2 | 487/489 passed (6/6 doctests, 481/483 tests) | FunctionBlockTest: PLAN M2-5's Done-when a recursive type, an unknown function block type and a cal of a non-instance are each a located diagnostic; EndToEndTest: user function blocks (M2-5) PLAN M2-5's Done-when: a seal-in written once as a block, run three times |
| R18 | an instance of a user block takes no initial value (Elixir) | `logex/declarations.ex` | 2 | 488/489 passed (6/6 doctests, 482/483 tests) | FunctionBlockTest: the types a compile is given from Elixir, an instance of a user block is a tag whose type is the block's |
| R19 | a block never holds an instance of itself | `logex/compiler.ex` | 2 | 486/489 passed (6/6 doctests, 480/483 tests) | FunctionBlockTest: PLAN M2-5's Done-when a recursive type, an unknown function block type and a cal of a non-instance are each a located diagnostic; FunctionBlockTest: the host contract, over sources that use blocks compile/2 never raises, its diagnostics are in line order and it reaches every M2-5 diagnostic; every program it gives scans without raising; EndToEndTest: user function blocks (M2-5) PLAN M2-5's Done-when: a seal-in written once as a block, run three times |
| R20 | nor of a type given that holds it, at any depth | `logex/compiler.ex` | 2 | 487/489 passed (6/6 doctests, 481/483 tests) | FunctionBlockTest: recursion a type given that holds the block's own name, at any depth; EditTest: growth (F16) accept and its steps stay linear in the program's size |
| R21 | nor through a tag declared from Elixir (ArgumentError) | `logex/compiler.ex` | 2 | 488/489 passed (6/6 doctests, 482/483 tests) | FunctionBlockTest: recursion a type given that holds the block's own name, at any depth |
| R22 | a recursive declaration's uses are excused: one message | `logex/compiler.ex` | 2 | 487/489 passed (6/6 doctests, 481/483 tests) | FunctionBlockTest: PLAN M2-5's Done-when a recursive type, an unknown function block type and a cal of a non-instance are each a located diagnostic; EndToEndTest: user function blocks (M2-5) PLAN M2-5's Done-when: a seal-in written once as a block, run three times |
| R23 | cal on a ton is refused, naming ton | `logex/compiler.ex` | 2 | 487/489 passed (6/6 doctests, 481/483 tests) | FunctionBlockTest: cal runs only an instance of a user block, and one cal runs it; FunctionBlockTest: the host contract, over sources that use blocks compile/2 never raises, its diagnostics are in line order and it reaches every M2-5 diagnostic; every program it gives scans without raising |
| R24 | cal on a bool or a dint is refused | `logex/compiler.ex` | 2 | 486/489 passed (6/6 doctests, 480/483 tests) | FunctionBlockTest: PLAN M2-5's Done-when a recursive type, an unknown function block type and a cal of a non-instance are each a located diagnostic; FunctionBlockTest: the host contract, over sources that use blocks compile/2 never raises, its diagnostics are in line order and it reaches every M2-5 diagnostic; every program it gives scans without raising; EndToEndTest: user function blocks (M2-5) PLAN M2-5's Done-when: a seal-in written once as a block, run three times |
| R25 | an arity error names every formal | `logex/compiler.ex` | 2 | 487/489 passed (6/6 doctests, 481/483 tests) | FunctionBlockTest: cal an arity error names every formal, in order; FunctionBlockTest: the host contract, over sources that use blocks compile/2 never raises, its diagnostics are in line order and it reaches every M2-5 diagnostic; every program it gives scans without raising |
| R26 | an operand of the wrong type names its formal | `logex/compiler.ex` | 2 | 488/489 passed (6/6 doctests, 482/483 tests) | FunctionBlockTest: cal a type error names the formal the operand fills |
| R27 | a var_input where cal writes is refused | `logex/compiler.ex` | 2 | 488/489 passed (6/6 doctests, 482/483 tests) | FunctionBlockTest: cal a type error names the formal the operand fills |
| R28 | a member logic may not write, where cal writes, is refused | `logex/compiler.ex` | 2 | 488/489 passed (6/6 doctests, 482/483 tests) | FunctionBlockTest: cal a type error names the formal the operand fills |
| R29 (w) | a literal that does not fit an input is refused | `logex/compiler.ex` | 2 | 487/489 passed (6/6 doctests, 481/483 tests) | FunctionBlockTest: cal a type error names the formal the operand fills; FunctionBlockTest: the host contract, over sources that use blocks compile/2 never raises, its diagnostics are in line order and it reaches every M2-5 diagnostic; every program it gives scans without raising |
| R30 (w) | one cal runs an instance | `logex/compiler.ex` | 2 | 487/489 passed (6/6 doctests, 481/483 tests) | FunctionBlockTest: cal runs only an instance of a user block, and one cal runs it; FunctionBlockTest: the host contract, over sources that use blocks compile/2 never raises, its diagnostics are in line order and it reaches every M2-5 diagnostic; every program it gives scans without raising |
| R31 | a block's inputs and outputs are read anywhere | `logex/fb_type.ex` | 2 | 447/489 passed (6/6 doctests, 441/483 tests) | RuntimeTest: a timer in an instance (M1-6) is a map of its members in state.env, every key a string, and never an output; RuntimeTest: Logex.FbType (M1-6) the ton's members, and which a program may name and write; RuntimeTest: a timer in an instance (M1-6) restart puts it back at its initial state, and keeps the input image; and 39 more |
| R32 | a block's own var is hidden from outside | `logex/fb_type.ex` | 2 | 487/489 passed (6/6 doctests, 481/483 tests) | FunctionBlockTest: a function block's file a var is local: in the state, named only inside the block; FunctionBlockTest: the host contract, over sources that use blocks compile/2 never raises, its diagnostics are in line order and it reaches every M2-5 diagnostic; every program it gives scans without raising |
| R33 | no member of a user block is written from outside | `logex/fb_type.ex` | 2 | 486/489 passed (6/6 doctests, 480/483 tests) | FunctionBlockTest: the host contract, over sources that use blocks compile/2 never raises, its diagnostics are in line order and it reaches every M2-5 diagnostic; every program it gives scans without raising; FunctionBlockTest: a function block's file compiles to its type: its members in declaration order, its body a program; FunctionBlockTest: members a block's inputs and outputs are read anywhere, and written by no logic outside it |
| R34 | an instance no cal runs is warned about, saying cal | `logex/warnings.ex` | 2 | 487/489 passed (6/6 doctests, 481/483 tests) | FunctionBlockTest: the host contract, over sources that use blocks compile/2 never raises, its diagnostics are in line order and it reaches every M2-5 diagnostic; every program it gives scans without raising; FunctionBlockTest: warnings an instance no cal runs, saying cal |
| R35 | a cal's operands are uses with its block's signature (warnings) | `logex/warnings.ex` | 2 | 487/489 passed (6/6 doctests, 481/483 tests) | FunctionBlockTest: warnings a cal's outputs are written: a var_output only a cal drives is driven; FunctionBlockTest: PLAN M2-5's Done-when a seal-in written once as a block and instantiated three times behaves as three independent seal-ins, and m1.s2.run reads one of them |
| R36 | a block's body is warned about, in its type | `logex/compiler.ex` | 2 | 488/489 passed (6/6 doctests, 482/483 tests) | FunctionBlockTest: warnings a block's body is warned about as a program is, in its own type |
| R37 | a false EN runs nothing (decision 12) | `logex/runtime.ex` | 2 | 482/489 passed (6/6 doctests, 476/483 tests) | FunctionBlockTest: running a block first is the program instance's: an ons in a block frozen on the first scan fires when the block first runs; FunctionBlockTest: the online edit of a program that holds blocks at the first test a member whose value does not fit its type starts again (decision 26), by its path; FunctionBlockTest: the online edit of a program that holds blocks a timer in a frozen block is not resumed by a switch, and catches up (decision 8); one whose cal the candidate restores resumes from the switch (decision 23); and 4 more |
| R38 | the inputs are copied in | `logex/runtime.ex` | 2 | 470/489 passed (6/6 doctests, 464/483 tests) | FunctionBlockTest: the online edit of a program that holds blocks a timer in a frozen block is not resumed by a switch, and catches up (decision 8); one whose cal the candidate restores resumes from the switch (decision 23); FunctionBlockTest: running a block a body built by hand that runs an instance its table lacks runs nothing, and an edit takes it: nothing escapes; FunctionBlockTest: PLAN M2-5's Done-when a false EN freezes only its own instance, and the tags its outputs name; and 16 more |
| R39 | the outputs are copied out | `logex/runtime.ex` | 2 | 479/489 passed (6/6 doctests, 473/483 tests) | FunctionBlockTest: the online edit of a program that holds blocks an output only a cal drove is held where the candidate drives it no more; FunctionBlockTest: running a block a body built by hand that runs an instance its table lacks runs nothing, and an edit takes it: nothing escapes; FunctionBlockTest: running a block an instance a plain swap left as no map runs from an empty one: nothing escapes; and 7 more |
| R40 | ENO is EN | `logex/runtime.ex` | 2 | 488/489 passed (6/6 doctests, 482/483 tests) | FunctionBlockTest: running a block ENO is the power out: what follows a cal sees its EN |
| R41 | first is the program instance's inside a body | `logex/runtime.ex` | 2 | 487/489 passed (6/6 doctests, 481/483 tests) | FunctionBlockTest: running a block first is the program instance's: an ons in a block frozen on the first scan fires when the block first runs; EditTest: growth (F16) accept and its steps stay linear in the program's size |
| R42 | the body sees only its own instance's blocked bits | `logex/runtime.ex` | 2 | 483/489 passed (6/6 doctests, 477/483 tests) | FunctionBlockTest: the online edit of a program that holds blocks an ons in a block's rung the edit changes is blocked by its path, in every instance, and a top-level bit of the same name is not; ApiContractTest: an online edit of a program that holds blocks: each report's writes rebuild the state by path, a switch leaves every member present, a prune leaves no other, a round trip gives every value back, and no one-shot fires on a changed chain; FunctionBlockTest: the online edit of a program that holds blocks a nested block an earlier edit left pending survives a second edit before any scan (F2); and 3 more |
| R43 (w) | scan.tags is the runtime's | `logex/runtime.ex` | 2 | 488/489 passed (6/6 doctests, 482/483 tests) | FunctionBlockTest: running a block the scan's tag table is the runtime's |
| R44 | an instance left as no map runs from an empty one | `logex/runtime.ex` | 2 | 488/489 passed (6/6 doctests, 482/483 tests) | FunctionBlockTest: running a block an instance a plain swap left as no map runs from an empty one: nothing escapes |
| R45 | a hand-built cal of no block runs nothing | `logex/runtime.ex` | 2 | 488/489 passed (6/6 doctests, 482/483 tests) | FunctionBlockTest: running a block a body built by hand that runs an instance its table lacks runs nothing, and an edit takes it: nothing escapes |
| R46 | a block's body is not its type: an edit may change it | `logex/edit.ex` | 2 | 475/489 passed (6/6 doctests, 469/483 tests) | FunctionBlockTest: the online edit of a program that holds blocks a timer inside a block meets the preset rules by its path; FunctionBlockTest: the online edit of a program that holds blocks a kept member whose initial value changed keeps its value, and is reported; FunctionBlockTest: the online edit, at depth and across a round trip assemble prunes a member at any depth, inside an instance an instance holds; and 11 more |
| R47 | a member's kind change is cited as a member's | `logex/edit.ex` | 2 | 488/489 passed (6/6 doctests, 482/483 tests) | FunctionBlockTest: the online edit of a program that holds blocks a member whose kind changes is refused, by its path; a block renamed is a type change |
| R48 (w) | the nested migration starts a member the state lacks or the candidate adds | `logex/edit.ex` | 2 | 486/489 passed (6/6 doctests, 480/483 tests) | FunctionBlockTest: the online edit of a program that holds blocks a member the block adds starts at its initial value in the instance, and one it drops is kept until assemble prunes it, each by its path; FunctionBlockTest: the online edit of a program that holds blocks at the first test a member whose value does not fit its type starts again (decision 26), by its path; ApiContractTest: an online edit of a program that holds blocks: each report's writes rebuild the state by path, a switch leaves every member present, a prune leaves no other, a round trip gives every value back, and no one-shot fires on a changed chain |
| R49 | at the first test a nested member that does not fit starts again (decision 26) | `logex/edit.ex` | 2 | 487/489 passed (6/6 doctests, 481/483 tests) | FunctionBlockTest: the online edit of a program that holds blocks at the first test a member whose value does not fit its type starts again (decision 26), by its path; EditTest: growth (F16) a second edit before any scan stays linear in the bits still pending (F2) |
| R50 | at the first test an instance that is not a map starts again whole | `logex/edit.ex` | 2 | 488/489 passed (6/6 doctests, 482/483 tests) | FunctionBlockTest: the online edit, at depth and across a round trip at the first test an instance a plain swap left as no map starts again whole (decision 26) |
| R51 (w) | a kept member whose initial value changed is reported | `logex/edit.ex` | 2 | 487/489 passed (6/6 doctests, 481/483 tests) | ApiContractTest: an online edit of a program that holds blocks: each report's writes rebuild the state by path, a switch leaves every member present, a prune leaves no other, a round trip gives every value back, and no one-shot fires on a changed chain; FunctionBlockTest: the online edit of a program that holds blocks a kept member whose initial value changed keeps its value, and is reported |
| R52 (w) | assemble and cancel prune a block's dropped members | `logex/edit.ex` | 2 | 486/489 passed (6/6 doctests, 480/483 tests) | FunctionBlockTest: the online edit of a program that holds blocks a member the block adds starts at its initial value in the instance, and one it drops is kept until assemble prunes it, each by its path; FunctionBlockTest: the online edit, at depth and across a round trip assemble prunes a member at any depth, inside an instance an instance holds; ApiContractTest: an online edit of a program that holds blocks: each report's writes rebuild the state by path, a switch leaves every member present, a prune leaves no other, a round trip gives every value back, and no one-shot fires on a changed chain |
| R53 | prune reaches an instance an instance holds | `logex/edit.ex` | 2 | 487/489 passed (6/6 doctests, 481/483 tests) | ApiContractTest: an online edit of a program that holds blocks: each report's writes rebuild the state by path, a switch leaves every member present, a prune leaves no other, a round trip gives every value back, and no one-shot fires on a changed chain; FunctionBlockTest: the online edit, at depth and across a round trip assemble prunes a member at any depth, inside an instance an instance holds |
| R54 | a nested one-shot's chain includes the rung that cals its instance | `logex/edit.ex` | 2 | 486/489 passed (6/6 doctests, 480/483 tests) | FunctionBlockTest: the online edit, at depth and across a round trip a blocked bit inside an instance is reported with its value, by its path; ApiContractTest: an online edit of a program that holds blocks: each report's writes rebuild the state by path, a switch leaves every member present, a prune leaves no other, a round trip gives every value back, and no one-shot fires on a changed chain; FunctionBlockTest: the online edit of a program that holds blocks an ons in a block run from a rung the edit changes is blocked; one under unchanged rungs keeps its real edge |
| R55 | a one-shot two levels down belongs to the chain too | `logex/edit.ex` | 2 | 487/489 passed (6/6 doctests, 481/483 tests) | FunctionBlockTest: the online edit, at depth and across a round trip an instance of a block that holds a block, added with its cal, blocks the one-shot two levels down for the switch scan (decision 21); ApiContractTest: an online edit of a program that holds blocks: each report's writes rebuild the state by path, a switch leaves every member present, a prune leaves no other, a round trip gives every value back, and no one-shot fires on a changed chain |
| R56 (w) | a blocked bit inside an instance is reported with its value, by path | `logex/edit.ex` | 2 | 487/489 passed (6/6 doctests, 481/483 tests) | FunctionBlockTest: the online edit of a program that holds blocks a timer in a frozen block is not resumed by a switch, and catches up (decision 8); one whose cal the candidate restores resumes from the switch (decision 23); FunctionBlockTest: the online edit, at depth and across a round trip a blocked bit inside an instance is reported with its value, by its path |
| R57 | a nested block an earlier edit left pending is kept (F2) | `logex/edit.ex` | 2 | 488/489 passed (6/6 doctests, 482/483 tests) | FunctionBlockTest: the online edit of a program that holds blocks a nested block an earlier edit left pending survives a second edit before any scan (F2) |
| R58 | a timer inside a block meets the preset rules by its path | `logex/edit.ex` | 2 | 483/489 passed (6/6 doctests, 477/483 tests) | FunctionBlockTest: the online edit, at depth and across a round trip a timer in an instance no cal runs keeps its .pre frozen, beside one of the same block that a cal runs (decision 23); FunctionBlockTest: the online edit of a program that holds blocks a timer inside a block meets the preset rules by its path; FunctionBlockTest: the online edit, at depth and across a round trip an untest gives back a resume its test made of a timer only the candidate's version of a block declares (fix F11, by path); and 3 more |
| R59 | a nested plan is per whether each program runs the instance (decision 23) | `logex/edit.ex` | 2 | 488/489 passed (6/6 doctests, 482/483 tests) | FunctionBlockTest: the online edit, at depth and across a round trip a timer in an instance no cal runs keeps its .pre frozen, beside one of the same block that a cal runs (decision 23) |
| R60 | a timer both programs run is not resumed (decision 8) | `logex/edit.ex` | 2 | 487/489 passed (6/6 doctests, 481/483 tests) | FunctionBlockTest: the online edit of a program that holds blocks a timer in a frozen block is not resumed by a switch, and catches up (decision 8); one whose cal the candidate restores resumes from the switch (decision 23); FunctionBlockTest: the online edit of a program that holds blocks at the first test a member whose value does not fit its type starts again (decision 26), by its path |
| R61 | resume only where the program stopped last scanned | `logex/edit.ex` | 2 | 487/489 passed (6/6 doctests, 481/483 tests) | ApiContractTest: an online edit of a program that holds blocks: each report's writes rebuild the state by path, a switch leaves every member present, a prune leaves no other, a round trip gives every value back, and no one-shot fires on a changed chain; FunctionBlockTest: the online edit, at depth and across a round trip a test and an untest with no scan between leave a timer a false EN froze as it was: the program that last scanned ran it, so no resume is due |
| R62 | an undo by path reaches a timer only the stopped version declares (F1, F11) | `logex/edit.ex` | 2 | 488/489 passed (6/6 doctests, 482/483 tests) | FunctionBlockTest: the online edit, at depth and across a round trip an untest gives back a resume its test made of a timer only the candidate's version of a block declares (fix F11, by path) |
| R63 | an undo by path reaches an instance only the stopped program declares | `logex/edit.ex` | 2 | 488/489 passed (6/6 doctests, 482/483 tests) | FunctionBlockTest: the online edit, at depth and across a round trip an untest gives back a resume its test made inside an instance only the candidate declares (fix F11, by path) |
| R64 (w) | an output only a cal drove is held (decision 20) | `logex/edit.ex` | 2 | 484/489 passed (6/6 doctests, 478/483 tests) | FunctionBlockTest: the online edit, at depth and across a round trip at the first test an instance a plain swap left as no map starts again whole (decision 26); FunctionBlockTest: the online edit, at depth and across a round trip an untest gives back a resume its test made inside an instance only the candidate declares (fix F11, by path); FunctionBlockTest: the online edit of a program that holds blocks a timer in a frozen block is not resumed by a switch, and catches up (decision 8); one whose cal the candidate restores resumes from the switch (decision 23); and 2 more |
| R65 | a hand-built cal of no block writes nothing in the edit's walk | `logex/edit.ex` | 2 | 487/489 passed (6/6 doctests, 481/483 tests) | EditTest: growth (F16) accept and its steps stay linear in the program's size; FunctionBlockTest: running a block a body built by hand that runs an instance its table lacks runs nothing, and an edit takes it: nothing escapes |
| R66 | the nested plan builds a block's initial state only where one starts (growth) | `logex/edit.ex` | 2 | 488/489 passed (6/6 doctests, 482/483 tests) | FunctionBlockTest: growth in the depth of nesting a scan, a compile and an edit each stay linear |
| R67 (w) | compile_file finds a block's file beside the file that names it | `logex.ex` | 2 | 484/489 passed (6/6 doctests, 478/483 tests) | FunctionBlockTest: a block's file found beside the file that names it compile_file/1 compiles it first, once, and the program holds its type; FunctionBlockTest: a block's file found beside the file that names it a program's file is no type, and a block's first line must match its file's name; FunctionBlockTest: a block's file found beside the file that names it a chain of files that holds itself is located in the file that closes it; and 2 more |
| R68 | a mistake in a block's file is reported with its file | `logex.ex` | 2 | 486/489 passed (6/6 doctests, 480/483 tests) | FunctionBlockTest: a block's file found beside the file that names it a chain of files that holds itself is located in the file that closes it; FunctionBlockTest: a block's file found beside the file that names it a program's file is no type, and a block's first line must match its file's name; FunctionBlockTest: a block's file found beside the file that names it a mistake in it is reported with its file, and stops the file that names it |
| R69 (w) | a program's file is no type, before any cycle is looked for | `logex.ex` | 2 | 488/489 passed (6/6 doctests, 482/483 tests) | FunctionBlockTest: a block's file found beside the file that names it a program's file is no type, and a block's first line must match its file's name |
| R70 | a dotted type word names no file | `logex.ex` | 2 | 488/489 passed (6/6 doctests, 482/483 tests) | FunctionBlockTest: a block's file found beside the file that names it a program's file is no type, and a block's first line must match its file's name |
| R71 | the function_block stanza is in docs/naming.md | `docs/naming.md` | 2 | 488/489 passed (6/6 doctests, 482/483 tests) | NamingTest: every word that heads a file of another kind has been surveyed (M2-5) |
| R72 | the cal stanza is in docs/naming.md | `docs/naming.md` | 2 | 488/489 passed (6/6 doctests, 482/483 tests) | NamingTest: every implemented instruction has been surveyed |

---

## 8. Landing order, as commits, each green

1. **Survey.** Append the `function_block` and `cal` stanzas to `docs/naming.md` (`cal`
   supersedes the `cal <routine>` row at `docs/naming.md:240`, which stays: the file is
   append-only). Add `Declarations.kinds/0` and its `naming_test` test. Reserves nothing yet;
   breaks no tag. Green: nothing reads the words.
2. **The walks learn a signature per instruction** (no behaviour change). `Logex.Edit` and
   `Logex.Warnings` look a `cal`'s slots up from its instance's type and are total on one that is
   no block (R65's code). If the maintainer takes FS-Q23 (b), the B5 extraction goes here.
3. **Blocks and `cal`.** `FbType` gains `body`, `:local`, `of/1`, `signature/1`, `user?/1`;
   `Declarations` takes a library and gains `block_name?/1`; the compiler gains the header, the
   library checks, the recursion marks and excused uses, the `cal` lowering and checks, one
   `cal` per instance; `Logex.compile/2` gains `types:`; `Scan` gains `tags`; the runtime gains
   its `cal` pair, the block-type message and the total clause; the warnings learn `cal`. Tests:
   the function_block describes for the file, the library, recursion, `cal`, members, warnings,
   running a block, the host contract, growth in the depth for scan and compile, and the
   Done-when in `function_block_test.exs` (through `types:`). **Reserves `cal` in every `.ld`,
   in any case** (a mnemonic), and **`function_block` in a block's file**. **Breaks** any program
   with a tag named `cal` in any case (no test, `lib/` file or golden-record entry uses one;
   inventory item 11), and changes the pinned messages listed in §7.1. The edit is naive here
   (any block change refused by `!=`, nested one-shots not blocked): land 3 and 4 in one push.
4. **The edit, by path.** R46 to R64 and R66, the edit's growth tests, the "at depth and across a
   round trip" describe, and the `api_contract_test.exs` walk over blocks. Breaks no tag.
5. **The loader.** `compile_file/1` finds block files beside (R67-R70, R73), its describe, and
   the end-to-end Done-when through `compile_file/1`. Breaks no tag.
6. **Documents** (§9). Reserves nothing.

The spike is commits 1 to 5 together, with the CLAUDE.md lines and moduledocs of 6 and the README
of 6.

---

## 9. Documents each commit stales

| Commit | README | CLAUDE.md | PLAN | organisation.md | naming.md |
|---|---|---|---|---|---|
| 1 | — | — | — | — | the two stanzas (in the spike) |
| 2 | — | the B5 note, if FS-Q23 (b) | — | — | — |
| 3 | syntax list (the `function_block` bullet), the `cal` row, "Settled, not yet landed" (in the spike) | the `evaluate/3` convention (in the spike), step 2's `cal` exception (in the spike), Key Files for `fb_type.ex` (in the spike), `scan.ex`, `compiler.ex` (`types`), `logex.ex` (`types:`), `function_block_test.exs` | M2-5's record; the Done-when reworded (FS-Q1) | §4.3 as landed: `:local`, `user?/1`, the library, one version per name, members hidden and unwritable; §7 a new decision for each FS-Q answer, numbered from 30 | — |
| 4 | "Changing a running program": a block may change while running, by path | Key Files for `edit.ex` and `api_contract_test.exs`'s fourth walk | OE-2's sentence (PLAN:1491-1493) | §4.9: the members' refusal (org:866) lifted; the Resume row (org:1004) reworded for "the program that last scanned" and "from the text" (§11, item 3); the nested rows in the tables | — |
| 5 | `compile_file/1` finds blocks beside | Key Files for `logex.ex` | M2-2's loader sentence, if FS-Q12 (a) | §4.3 the loader; §6.2 M2-2's loader is shared | — |
| 6 | an example re-run (CLAUDE.md:113-118: "its output is real") | — | the item marked landed | §5 decided list | — |

---

## 10. What came from which design and judge

| Part | From | Why |
|---|---|---|
| Base: blocks, `cal`, runtime, scan narrowing, nested migration, loader, `user?/1`, soup property, growth tests | F2 | both judges' winner (JF1 §0, JF2 §0) |
| Naming stanzas, reworded without the conventional family's own term | F1 | JF1 graft 1, JF2 graft 1, D4 |
| `function_block` names no block (R5), `user?/1` refuses it (R13) | F1 FB-3 | JF2 D3, graft 2 |
| Excused uses of a recursive declaration (R22) | F1 FB-16 | JF1 graft 2, JF2 D7 |
| Did-you-mean among blocks (R17) | F1 FB-12 | JF1 graft 3 |
| Recursion through a tag from Elixir raises (R21) | F1 | JF1 defect 3, graft 4 |
| Elixir-declared members first, accepted by `user?/1` (R10, R14) | F1's order, F2's validator | JF1 defect 4, graft 5 |
| Done-when in `end_to_end_test.exs` through `compile_file` | F1 | JF1 graft 6, JF2 D8 |
| Dedicated block-type message (R8, R9) | F1 | JF1 graft 7, JF2 graft 4 |
| Header-first-rung test and departure (R75) | F1 | JF1 defect 5, graft 8 |
| README entry and `cal` row | F1, adjusted for the loader | JF1 graft 9 |
| Total runtime `cal` clause (R45) | F1 | JF2 graft 5, D2b |
| Edit walk over blocks in `api_contract_test.exs` | JF1 `walk.exs`, extended | JF1 graft 10, defect 7; JF2 T6 |
| Resume asks who last scanned (R61) | this pass, fixing JF1 defect 1 | fix F3's own question, org:1021-1031 |
| F11/F1 undo over both versions (R62) | this pass, fixing JF1 defect 2 | as `timers/2` at the top level |
| Undo inside an instance only one program declares (R63) | this pass; found by the new walk at seed 3 | same defect class as JF1 defect 2, one level up |
| Program kind before cycle (R69), dotted word (R70) | this pass, fixing JF2 D5, D6 | JF2's suggested fixes |
| Tests for T1-T5 (R56, R55, R50, R53, R59) | this pass, from JF2's `survivors.exs` scenarios | each was a surviving revert |
| Total edit walk on a hand-built body (R65) | this pass | the runtime is total, so the edit must be (D2b) |
| Seeded soup property | this pass | the unseeded one failed under one revert's run |
| F1-Q10, F1-Q13, F1-Q16 kept as questions | JF2 graft 7 | FS-Q6, FS-Q22, FS-Q21 |

Not taken from F1: refusing every change to a block type (FB-38 to FB-41), kept as FS-Q2 (a);
`compile_file/2` with `types:` (F1-Q6), kept as FS-Q12 (b).

---

## 11. Departures from decided rules

1. **CLAUDE.md:134, the `evaluate/3` convention:** "The scan is read-only and the same for every
   instruction of one call." Here it is the same for every instruction of one routine run, and
   `cal` narrows it for its body. The spike's CLAUDE.md line says so (FS-Q4).
2. **PLAN:1343-1347 and org:1407-1410, M2-5's Done-when:** "`m1.s2.run` reads one of them".
   Before M2-1 the test reads `s2.run` of the instance it names `m1`, by a rung and from its
   state (FS-Q1).
3. **Org:1004 and `lib/logex/edit.ex:84-87,692-695`, the Resume rule's mechanism.** The rule "A
   timer T runs and F did not … resumes" is kept. Its stated basis, "a `last` before `now` says F
   did not run it", is replaced by two checks: F's text does not run the timer (F2's), and F is
   the program that last scanned (this pass, as fix F3 asks for one-shots). Top-level behaviour
   is unchanged: the OE-1 suite and its contract walk pass unmodified (FS-Q6).
4. **PLAN:1340-1343, M2-5's scope sentence,** does not list the nested migration, though org:866
   and PLAN:1491-1493 give it to M2-5. The spike builds it. A scope extension, not a departure
   from org (FS-Q2).
5. **Org:1461, decision 4:** "a required first line `function_block <name>`". The header is the
   first rung: comments and blank lines may come before it (R75; FS-Q21).
6. **Decision 9 and org §4.3, "reads anywhere":** a user block's own `var`s are hidden from
   outside (R32). `fb_type.ex:21-24` left this to M2-5, so this may be that decision rather than
   a departure (FS-Q9).
7. **CLAUDE.md:146-159, "New instructions, step 2":** `cal`'s `@instructions` entry is a marker,
   `{:cal, :block}`, its signature built per compile (org:326-327). The spike's CLAUDE.md says so
   (FS-Q18).
8. **PLAN M1-5's `Logex.compile(source, name:)`,** pinned by "takes a name and no other option"
   (`test/logex_test.exs:133-138`), gains `types:`, and a block's file compiles to `%FbType{}`
   (FS-Q12, FS-Q13).
9. **M2-2's loader, ahead of M2-2.** `compile_file/1` loads block files beside before the `.lcf`
   exists (R67; FS-Q12).

No other decided rule moves: decisions 8, 12, 20, 21, 23, 26, 28 and 29, the reserved-word scope
(org §4.8) and the no-BEAM rule are kept. Nothing compiles a user's program; the edit path calls
no Elixir compiler.

---

## 12. Risks

- **`Logex.Edit` roughly doubles in its per-instance code** (edit.ex +542 −53). The
  new walk is the independent oracle the judges asked for, but its one-shot oracle covers only
  versions whose output only the `ons` rung writes, and it has no `.pre` oracle independent of
  the rules (R59 is pinned by an example test only).
- **The scan convention.** A later evaluate clause that looks anything up in `scan.tags` must use
  the routine's table; CLAUDE.md says so.
- **`user?/1` trusts a body's rungs.** A body edited by hand passes `types:` (JF2 H6, H7). The
  runtime and the edit are total on it (R45, R65), but what it computes is unspecified. FS-Q22.
- **Path strings at depth.** Reports name a member by its full path: O(n²) bytes for a chain n
  deep with a report at every level. Reductions stay linear. Negligible at the conventional
  family's 16 levels (`docs/naming.md`'s new stanza, read from its manual); measurable at 800
  (unverified in wall time).
- **Report details.** `{:added, path, map}` for a whole nested instance carries a map, as a timer's
  `:added` already does.
- **Fix F15 stays open.** A nested member's refusal cites the instance's line in the program, not
  the member's line in the block's file, and carries no file.
- **A block's warnings live inside its type.** A host compiling a program sees its blocks'
  warnings only if it compiles each block file itself (or reads `type.body.warnings`).
- **Per-`cal` cost.** `FbType.signature/1` is rebuilt at every energised `cal`: 269 reductions for
  a seal through `cal` against 151 inline. Precomputing it into the type is a cheap later change.
- **The loader stops at the first broken dependency** (FS-Q15) and reads a dependency's file twice
  (`peek/1`, then `load/3`) where it is a block.
- **Fifteen reverts printed a lib compile warning** beside their failing tests. Each is red by a
  failing test, which the table lists; a reviewer re-running one should read the test list, not
  only the exit code.

---

## 13. Decisions for the maintainer

**FS-Q1 · PLAN M2-5's Done-when says `m1.s2.run` reads one of the seal-ins, but `get/2` is M2-1's. How is it asserted if M2-5 lands first?** (M2-5 Done-when (inventory C1; F1-Q1, F2-Q12))

- *(a) Reword it for M2-5 and assert `get(rt, "m1.s2.run")` in M2-1's acceptance (the spike).* The test reads `s2.run` of the instance it names `m1`, by a rung (`xic s2.run`) and from its state; one PLAN sentence and org:1407-1410 change.
- *(b) Land M2-1 first.* M2-5 waits for a scheduler it does not need; the Done-when stays as written.
- *(c) Add a per-instance read now, which M2-1's `get/2` delegates to.* A public function lands ahead of its scheduler and must be reconciled with `get(rt, path)`.

*Recommend (a).* The spike shows M2-5 needs nothing from M2-1, and both tests already read it this way. *Decide before:* the commit that lands blocks and cal (§8 step 3).

**FS-Q2 · What may change in a block type while a program that holds it runs?** (M2-5 online edit / OE-2 (org:858-869; F1-Q2, F1-Q3, F2-Q2))

- *(a) Nothing: refuse any change to a block type, ignoring line numbers (F1).* Editing a block's logic needs a restart, as the conventional family edits its user-defined instructions offline only. Replace R46-R63's edit code with F1's FB-38 to FB-41 (+151 lines in edit.ex); OE-2 brings the migration, and org:866 and PLAN:1491-1493 are reworded.
- *(b) The body only.* Needs the path-keyed one-shot and timer rules (R54-R63) without the member migration (R48-R53).
- *(c) The full nested migration in M2-5, as org:866 assigns (the spike).* About +542 −53 lines in edit.ex with its moduledoc; 12 edit tests, 8 depth tests, 2 growth tests and a seeded walk; 21 of the 72 reverts are its rules, all red. Matches Beremiz's hot swap (copy leaves by path and type) and CODESYS's code-only replacement.

*Recommend (c).* The documents already give it to M2-5; both judges' walks and this pass's walk found no rebuild, prune or one-shot failure after the two timer fixes; it leaves OE-2 configuration-level work. *Decide before:* the edit commit (§8 step 4).

**FS-Q3 · Should the uses of a declaration with an unknown type stop being reported as 'not declared', as a recursive one's now are?** (follow-up to M1-3 (F1-Q11))

- *(a) Keep M1-3's cascade (the spike).* A misspelled block name gives one extra line per use (the end-to-end test pins `line 18: `s3` is not declared`).
- *(b) Excuse those uses too.* One mistake, one message; some M1-3 and M1-6 pins change.

*Recommend (b), as a separate commit after M2-5.* A misspelled block name is now the likeliest unknown type. *Decide before:* nothing in M2-5.

**FS-Q4 · How does the private evaluator reach a block's body, given CLAUDE.md:134's 'the scan is the same for every instruction of one call'?** (M2-5 runtime (inventory C11; F1-Q12, F2-Q1))

- *(a) `Scan.tags`, runtime-filled; `cal` hands its body the scan narrowed to its instance (the spike).* The convention becomes 'of one routine run'; one pinned `Scan` key and one host check; linear in depth.
- *(b) Expand each `cal` at compile time into the body with absolute paths.* The scan is unchanged, but each operand at depth k walks k maps: a chain of n blocks scans in O(n^2), and the IR grows with instances.
- *(c) A private frame struct as `evaluate/3`'s third argument.* The convention changes for every clause, not one.

*Recommend (a).* The smallest departure that stays linear; F1 and F2 reached it independently. *Decide before:* §8 step 3.

**FS-Q5 · Which rung changes make a one-shot inside a block 'changed', blocked for one scan?** (M2-5 online edit, decision 21 (F2-Q3))

- *(a) Any rung on its chain: the program's `cal` rung, each body's `cal` rung, the body's `ons` rung (the spike).* A changed EN condition or `cal` operand blocks the one-shots under it, at any depth; at worst one real edge is lost, decision 21's accepted cost.
- *(b) The body's rung only.* A changed calling rung leaves the bit compared against a condition it never saw: the false pulse decision 21 prevents (JF2 J4, K6).
- *(c) Every one-shot inside an instance whose type changed.* Cruder; loses real edges where nothing on the chain changed.

*Recommend (a).* Decision 21 restated for a chain of rungs; the walk's independent oracle checks it one and two levels down. *Decide before:* §8 step 4.

**FS-Q6 · How does the Resume rule decide that 'F did not run' a timer inside a block, which a false `cal` can freeze?** (M2-5 online edit, decision 23 (inventory C9; F1-Q10, F2-Q4))

- *(a) F's text does not run it, and F is the program that last scanned (the spike).* A frozen timer both programs run catches up (decision 8); one whose `cal` an edit restores resumes (decision 23, org:838-842); a test then an untest with no scan between leaves a frozen timer as it was (fix F11). Top level unchanged; org:1004's justification sentence is reworded.
- *(b) F2's: F's text only.* An untest at once after a test resumes a timer the original froze by a false EN: decision 8's catch-up lost (JF1 defect 1).
- *(c) OE-1's inference, 'a `last` before `now`'.* Any switch resumes a timer frozen by a false `cal`, losing its frozen time.
- *(d) F1's: no Resume inside blocks; a restored `cal` catches up the whole gap.* The hazard org:838-842 settled returns inside blocks.

*Recommend (a).* It computes what decision 23 says ('T runs and F did not') about the program that actually ran last, as fix F3 already does for one-shots. *Decide before:* §8 step 4.

**FS-Q7 · May logic outside a block read its var_inputs? IEC forbids it (Ed 2 Table 32, Ed 3 Figure 13).** (M2-5 members (research IEC-11; decision 9; F1-Q4, F2-Q5))

- *(a) Inputs and outputs readable, as decision 9 and org:328 say (the spike).* `s1.start` can be read; a timer's `.pre` is already read this way.
- *(b) Outputs only, as IEC.* Reversible later; an explicit change of decision 9; `public/1` needs a rule by type.

*Recommend (a).* Decided, and harmless: a positional `cal` passes every input from a tag the caller already holds. *Decide before:* §8 step 3.

**FS-Q8 · Which of a user block's members may logic outside it write?** (M2-5 members (PLAN:1352; inventory C3; F1-Q5, F2-Q6))

- *(a) None (the spike).* Reversible: allowing some later breaks no program.
- *(b) Inputs, effective at the next call (IEC Ed 3).* Useful only while frozen, since a positional `cal` overwrites every input; the edit and warning rules must count those writes.
- *(c) Inputs and outputs (the conventional family, by inference).* A body reading its own output, as a seal-in does, sees foreign writes.

*Recommend (a).* Reversible and simplest to reason about; consistent with IEC for outputs. *Decide before:* §8 step 3.

**FS-Q9 · Are a block's own `var`s, instances it holds included, visible from outside?** (M2-5 members / M2-1 get/2 (fb_type.ex:21-24; F1-Q17, F2-Q7))

- *(a) Hidden (the spike).* No path from outside goes deeper than one member; M2-1's `get/2` reaches at most `inst.tag.member`.
- *(b) Readable.* Internals become part of `get/2`'s contract; the compiler needs member lookup at any depth.

*Recommend (a).* IEC Ed 3's PRIVATE default and the conventional family's local tags; reversible; a debug read can be a separate API that is not logic. *Decide before:* §8 step 3.

**FS-Q10 · Inside a block, is `first` the program instance's, as decided?** (M2-5 first (PLAN:1351-1352; F1-Q9, F2-Q8))

- *(a) The program instance's (the spike).* A block frozen on the first scan fires its one-shot the first time it runs, as the conventional family documents for its own blocks.
- *(b) A first-run bit per instance.* New instance state with CLAUDE.md's three rules, and a change to the decided note.

*Recommend (a).* Decided, documented in the `cal` stanza, tested (R41). *Decide before:* §8 step 3.

**FS-Q11 · May one instance be run by two `cal`s?** (M2-5 cal (F1-Q8, F2-Q9))

- *(a) No, refused like a second `ton` (the spike).* Reversible; the edit names one calling chain per nested one-shot and timer.
- *(b) Yes, as IEC allows.* Inputs replaced halfway through a scan, timers and one-shots stepped twice, and each nested bit has several chains whose identity needs a new rule.

*Recommend (a).* No arrangement of two positional calls is safe, and the choice is reversible. *Decide before:* §8 step 3.

**FS-Q12 · How does a library of block types reach the compiler and `compile_file`?** (M2-5 library / M2-2 loader (inventory Q5.5, C22; F1-Q6, F2-Q10))

- *(a) `types:` on `compile/2`, and `compile_file/1` loading `<word>.ld` beside the file that names it (the spike).* M2-2's `.lcf` loader reuses the rule and the function; `compile_file/1` compiles a program that holds a block; a cycle of files is located.
- *(b) `types:` only, on `compile/2` and a `compile_file/2`; the loader waits for M2-2 (F1).* Until M2-2, `compile_file` of a program that uses a block reports an unknown type; M2-2 designs the loader.
- *(c) `types:` as a map keyed by name.* Each name stored twice; a key disagreeing with its type's name is a new host mistake.

*Recommend (a).* One loader, designed once; the Done-when then runs from files on disk with no host glue. *Decide before:* the loader commit (§8 step 5).

**FS-Q13 · What does compiling a block's file return?** (M2-5 API (F2-Q11))

- *(a) `{:ok, %FbType{}}`, its body a `%Program{}` named after it (the spike, F1 too).* A file is a POU type, and the block type is decision 9's schema; every program entry point refuses a block type with its own message (R8, R9).
- *(b) `{:ok, %Program{kind: :function_block}}`.* The type is built at use; every program-consuming API must refuse a block by its kind.

*Recommend (a).* It reuses the schema M1-6 defined. *Decide before:* §8 step 3.

**FS-Q14 · May one compile hold two versions of a block of one name?** (M2-5 library (F2-Q13))

- *(a) No: one version per name across the types given, the types they hold, and tags declared from Elixir (the spike).* A host compiles each block against the same types; the runtime and the edit look types up by name.
- *(b) Yes.* Needs a type identity beyond the name in the runtime's lookups and the edit's plans.

*Recommend (a).* Names are the identity everywhere else in logex. *Decide before:* §8 step 3.

**FS-Q15 · When a block's file has mistakes, is the file that names it compiled further?** (M2-5 loader (F2-Q14))

- *(a) Stop, and report the block's mistakes with its file (the spike).* The dependent file's own mistakes appear once the block compiles.
- *(b) Continue, the type marked broken.* Every mistake in every file at once, as the Milestone 2 done sentence's 'every mistake' may want; another marker type in Declarations.

*Recommend (a) for M2-5, revisited with M2-2's loader.* Simple, and precedented: a lex or parse error already stops a compile. *Decide before:* §8 step 5.

**FS-Q16 · Should M2-5 land before M2-1?** (Milestone 2 order (decision 1; F1-Q14, F2-Q15))

- *(a) M2-5 first, with FS-Q1 (a).* Settles the nested state shape, `get/2`'s reach and the `.ld` and Edit changes while OE-1 is fresh, before M2-1's `start/1` and OE-2 build on them.
- *(b) M2-1 first, decision 1's default.* The Done-when is asserted through `get/2` as written; M2-1 defines `get/2` before the members it reads are settled.

*Recommend (a).* The spike shows M2-5 self-contained on today's main. *Decide before:* the first Milestone 2 commit.

**FS-Q17 · Is a block member's changed initial value an allowed edit?** (M2-5 online edit, decision 29 (F2-Q16))

- *(a) Yes: keep the running value, report `:initial_changed` by path (the spike).* Decision 29, applied by path.
- *(b) No: the initial value is part of the type.* Changing a member's default needs a restart.

*Recommend (a).* Consistent with decision 29 at the top level. *Decide before:* §8 step 4.

**FS-Q18 · How is `cal` represented in `@instructions`?** (M2-5 cal / CLAUDE.md step 2 (inventory Q5.9; F2-Q17))

- *(a) `"cal" => {:cal, :block}`, a marker meaning the signature is the block's (the spike).* Reserved and surveyed like any mnemonic; CLAUDE.md step 2 notes the exception (in the spike).
- *(b) A separate list of signature-less mnemonics.* `mnemonic?/1`, `reserved/1` and `naming_test` each read a second table.

*Recommend (a).* One source of truth for reserved mnemonics. *Decide before:* §8 step 3.

**FS-Q19 · May a tag be named like a block the compile is given (`var seal seal`)?** (M2-5 names (PLAN:732-734; inventory Q5.6, C30; F2-Q18))

- *(a) Yes: a block's name is not reserved (the spike).* A lone `var seal` reads 'needs a tag name before the type `seal`' where a library holds `seal`.
- *(b) No.* A block's name becomes reserved per compile, against PLAN:732-734.

*Recommend (a).* Decided. *Decide before:* §8 step 3.

**FS-Q20 · Is a block's name matched exactly, or in any case?** (M2-5 names (F1-Q7))

- *(a) Exactly, like a tag (the spike).* `var s1 Seal` is an unknown type with '— did you mean `seal`? (type names are case-sensitive)'; on a case-insensitive file system the loader may still find `Seal.ld` (unverified).
- *(b) In any case, like `ton`.* Unlike tags; two blocks differing in case must then be refused; IEC's case rule for identifiers is unverified here.

*Recommend (a).* A block's name is a file name, and tags set the precedent. *Decide before:* §8 step 3.

**FS-Q21 · Must `function_block <name>` be literally line 1, or the first rung?** (M2-5, decision 4 (org:1461; F1-Q16))

- *(a) The first rung: comments and blank lines may come before it (the spike).* A file may start with a licence comment; decision 4's record is reworded.
- *(b) Literally line 1.* A file with a heading comment is refused; needs a check the lexer does not make today.

*Recommend (a).* The lexer drops comments before the parser sees any line; nothing is lost. *Decide before:* §8 step 3.

**FS-Q22 · How exactly must a type given in `types:` or to `Tag.new!/4` be what `Logex.compile/2` gives?** (M2-5 data path, decision 28 (org:779; F1-Q13; JF2 D2b))

- *(a) `user?/1` checks its members against its body's tags, at any depth, and the runtime and the edit are total on a body edited by hand (the spike).* Hand-edited members are refused (JF2 H4, H5); a hand-edited body rung passes, runs nothing and raises nothing (H6, H7), but what it computes is unspecified.
- *(b) Also recompile `body.source` with the types the body holds and compare.* Exact for a type with source; one compile per type per compile; a type from `instructionize/3` has no source and must be refused or trusted.
- *(c) Also check the body's IR structurally (each `cal` a user instance of its table, each operand a declared tag).* A second validator beside the compiler, which the data API's one-validator rule (org:775-779) argues against.

*Recommend (a) now, (b) when M2-2's loader makes `source` universal.* (a) closes what a host can say about members, which is what `cal` and the edit read; the body's rungs are trusted as a `%Program{}`'s are (runtime.ex:42-43). *Decide before:* §8 step 3.

**FS-Q23 · Should the three IR walks (compiler, Warnings, Edit) be merged into one module before M2-5?** (M2-5 / B5 (readiness §4.1; F1-Q15))

- *(a) Land M2-5 as spiked: one `cal` signature clause each in Warnings and Edit.* Three walks remain.
- *(b) Extract first.* One walk, one signature function, one public write set; M2-5 waits for it.

*Recommend (a) for M2-5, (b) before M2-4.* M2-4 needs a public 'which tags a program writes'; M2-5 does not. *Decide before:* §8 step 2.

**FS-Q24 · Where do members declared from Elixir go in a block's positional `cal` order, given that a tag table keeps no list order?** (M2-5 data path (JF1 defect 4))

- *(a) First, by name, then the source's in line order (the spike).* `of/1` re-derives the order, so `user?/1` accepts the type; a host passing [b, a] gets `cal` formals a, b.
- *(b) First, in the order given (F1).* Needs the order kept outside the tag table, which `of/1` cannot then re-derive.
- *(c) Refuse a tag from Elixir in a block's compile.* The data API cannot build a block from Elixir, against org:775-779's one model.

*Recommend (a).* Deterministic, re-derivable, and it keeps one model for text and data. *Decide before:* §8 step 3.

**FS-Q25 · How do the new stanzas name the conventional family's user-defined instructions?** (docs/naming.md (JF1 F1 defect 5))

- *(a) 'user-defined instruction', and 'the family's manual for its user-defined instructions' (the spike).* Follows the design pass's naming rule; differs from naming.md:403,418,433, which spell out the family's own term.
- *(b) The family's own term, spelled out, as naming.md already does.* Consistent with the file; against the pass's rule for new text.

*Recommend (a).* New text should follow the rule; the older stanzas are append-only and stay. *Decide before:* §8 step 1.

