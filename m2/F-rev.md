# F-rev · M2-5, user function blocks: the one design, revised

Label F-rev, track F (`PLAN.md` §3, M2-5). This revises `F-synth.md` (2026-10-02) against
the findings the refutation pass confirmed: eight of correctness (RF-1 to RF-8), seven of fit
(rf-F-fit-1 to rf-F-fit-7) and the cross-track findings that fall to this track (X1, X3 to
X6, X13, X14, X16, X18 to X20). It is written against `/home/user/logex` at `47319f7`
(main, 2026-10-01), which this pass did not modify. The spike is a fresh copy of the
synthesis's, `scratchpad/m2/F-rev-work`. Its diff against `47319f7`, new test file
included, is `scratchpad/m2/F-rev.patch` (`git add -A && git diff --cached HEAD`: 20 files,
+4,466 −240). Every `mix` run used Elixir 1.20.4 on OTP 28
(`scratchpad/toolchain/env.sh`) and is judged by its exit code.

**Citations.** `org` is `docs/organisation.md` and `PLAN` is `PLAN.md`, by line at `47319f7`. A
bare `file:line` is the repository at `47319f7`. "Spike `file`, `fun/n`" is the copy in
`F-rev-work`, cited by function because its lines move. "Unverified" marks what I could not
check. `F1-Qn`, `F2-Qn`, `F2-Rn`, `FB-n` belong to `F1.md` and `F2.md`; `D`, `E`, `H`, `J`,
`K`, `N`, `T` to the judges' `JF1.md` and `JF2.md`; `RF-n` and `rf-F-fit-n` to the refuters'
`rf-F-correct.md` and `rf-F-fit.md`; `Xn` to `rf-X-consistency.md`; `S-rev Q-n` to track S's
revision, `S-rev.md`.

**Labels.** `Rn` (a rule and its revert, §2 and §7) and `FS-Qn` (a question, §13) belong to this
document only. Never cite them in `lib/`, `test/` or `CLAUDE.md`: the labels test
(`test/logex/edit_test.exs:1541-1603`) refuses `R` and a number. Every decision and fix the spike
cites, the revision's additions among them (decisions 4, 8, 9, 12, 21, 23 and 26; fixes F1,
F2, F3 and F11), is one org §7 defines, and the labels test passes on it. R1 to R77 keep their meaning from `F-synth.md`;
R78 to R93 are new here.

**The base.** Unchanged: F2's spike as the synthesis grafted and fixed it (both judges' choice,
JF1 §0, JF2 §0). Every change below is a revision of that spike, not a new base.

---

## Changed in revision

Each finding, what was done, and the test that fails when that change alone is reverted (its
revert in §7.2). "Doc" marks a change to this document only; "question" one left to the
maintainer in §13.

### Correctness (rf-F-correct)

- **RF-1 (high), a one-shot blocked inside a frozen block fired a false pulse later. Fixed.**
  A scan now keeps in the instance's block list every bit inside an instance whose body it
  did not run (R78), and a switch taken after such a scan lists it again where the program
  it starts still has that `ons` (R79), as fix F2 does for a block an earlier edit left
  pending. The runtime learns which bodies ran from the `cal` that runs an instance holding a
  blocked bit, which records it in its routine's env under an atom key that `call/4` takes
  out again (spike `Runtime.unrun/2`, `ran/4`); the evaluator's signature is unchanged. This
  is a new scan rule for existing instance state, so it is restated where CLAUDE.md's "New
  state" rule asks: `Logex.Instance`, `Logex.Scan`, `Logex.Runtime` and `Logex.Edit`
  moduledocs (the `:ons_blocked` row now reads "at the next scan that runs it") and the
  CLAUDE.md `evaluate/3` convention line. Tests: `function_block_test.exs` "a one-shot
  blocked inside an instance whose cal is false stays blocked until a scan runs the
  instance's body" and "a one-shot still blocked after a scan stays blocked through the next
  edit's switch"; and `api_contract_test.exs`'s block walk, whose one-shot oracle now asks of
  every scan, not only the one right after a switch, whether a one-shot ran under a chain of
  rungs other than the one it last ran under, and asserts its reach on two new atoms,
  `:ons_x_changed_late` and `:ons_inner_changed_late`. With R78 reverted the walk and both
  tests fail (§7.2, R78). The refuter's `p13.exs` on the spike now prints `switch scan (EN false): %{"q" => 0} blocked after=["x.e"]` and
  `next scan (EN true, a unchanged at 1): %{"q" => 0}`. The alternative, a frozen block that
  loses its block, stays a question (FS-Q30).
- **RF-2 (medium), a nested type was held twice, so a flat copy doubled per level. Fixed.**
  A member holding an instance of a user block now has the type `{:block, name}`; the type
  itself is held once, in the body's tag table, and `FbType.type_of/2` gives it (R80). The
  compiler's `nested/1`, `FbType.initial/2` and `user?/1`, and the edit's member walks read
  it from there. Test: "a program copied flat stays linear in the depth of nesting",
  `:erts_debug.flat_size/1` at 6 and 12 levels (1.7x). The refuter's `p10.exs` at depth 16
  now gives `flat=3961` words, `term_to_binary=17160B`, a send in `34us` (was 25,755,568
  words, 112,525,326 B, 131,423 µs); `p15.exs` hashes depth 24 in `27us` (was 29,230,460 µs).
  The finding's other suggestion, one table of types by name on the program, is FS-Q31.
- **RF-3 (medium), reordering a block's inputs changed what reached a nested `ons` and blocked
  nothing. Fixed.** The chain of rungs now keys each `cal` by its operands and the formals
  they fill (R81), so a reorder changes the chain as an operand swap does. Test: "an edit
  that reorders a block's inputs blocks the one-shots it runs, as an edit of the cal's
  operands does". `p5.exs` now prints `test: [{:ons_blocked, "x.e", 0}]` and `switch scan:
  out=%{"q" => 0}`.
- **RF-4 (low), one block from its file and from its text counted as two versions. Fixed.**
  R16 compares two versions with their warnings left out at every depth (spike
  `Compiler.same?/2`), a type compared with itself costing no walk (R82). Test: "a block
  compiled from its file, and from its text, is one version" (from text, and through a
  second spelling of the path). `p7.exs` and `p6.exs` now give `{:ok, :ok}` for each case.
- **RF-5 (low), the switch scan is quadratic in the depth when every level holds a one-shot.
  Claim corrected; question.** §12's "reductions stay linear" was wrong. The scan is linear in
  the length of the block list, its names' bytes, and those grow as the square of the depth
  because each path is as long as its depth; the edit's reports do too. New growth test:
  "the scan after a switch stays linear in the length of the block list" (4x the depth,
  16x the bytes, the bound 1.3x the bytes' ratio). This falls short of org §4.9's cost rule
  as written ("linear in the one-shots it blocks", org:1160), so it is a departure (§11,
  item 10) and a question (FS-Q27): accept it, or keep the list as a tree.
- **RF-6 (low), a chain of N block files costs O(N²) to load. Not fixed; question.** The
  corrected claim holds: `compile/2` itself validates every type it is given at full depth,
  so building a chain one block at a time is quadratic whoever does it. The revision makes
  the constant larger: `user?/1` now relowers each body (rf-F-fit-1), 2,486 reductions for a
  small block against 244. `p8.exs` now gives 138,358,875 reductions for 400 files (was
  26,536,725). At the conventional family's 16 levels a chain of 25 costs 680,019. FS-Q28
  asks whether to trust a type across compiles.
- **RF-7 (low), a program file with a refused name reported its blocks as unknown types.
  Fixed.** The loader now finds the blocks beside a file whose name it refuses and compiles
  the source with them, under no name (R91). Test: "a file with a refused name finds its
  blocks beside it all the same". `p6.exs`'s `1plant.ld` now gives the `:file` diagnostic
  alone.
- **RF-8 (low), two messages. Fixed.** (1) Two versions reached through tags declared from
  Elixir now name the tag, not `types` (R83): "a tag declared from Elixir holds a function
  block named `a` other than the one of that name in the types given or in another tag: give
  every instance of a block the same version, compiled against the same types". (2) The
  edit names a user block's type as "an instance of `inner`", with no article (R84). Tests:
  "a type holds one version of each block, the one given under its name" and "a member whose
  kind changes is refused, by its path; a block renamed is a type change", both extended.
  The same article problem remains in M1-6's member messages for a block named with a vowel
  ("is not a member of `m1.o`, a outer"), which the finding did not cover (§12).
- **Found in this pass: R78's record and an env built by hand.** An env that already held the
  record's atom key with a value that is no map made a scan raise `BadMapError` (a probe with
  `:ran => 5`). The record is now read as a map wherever it is met (R92, R93). Test: "an env
  built by hand under the scan's own key runs: nothing escapes".

### Fit (rf-F-fit)

- **rf-F-fit-1 (high), a type whose body was edited by hand passed `types:` and the public API
  then raised. Fixed.** `Logex.Compiler.lowered?/1`, new and public, is the definition of a
  compiled body, as `Logex.Parser.well_formed!/1` is of a parse tree: each rung, turned back
  into the elements its text parses to, lowers through the compiler's own checks to itself
  with no diagnostic (R86); the one-per-bit, one-per-timer and one-per-instance rules and the
  path after a `ton` hold; each timer's preset is the one on its `ton` (R90); the rungs are on
  rising lines after the declarations (R87); the warnings are the ones the rungs give, a file
  aside (R88). `FbType.user?/1` checks it once every type a body holds is valid (R85), and
  checks every tag's name as a declaration line could give it (R89). So the one validator
  is reused on the IR, not duplicated. Test: "a type whose body was edited by hand is refused
  where it is given", over every shape the refuter reproduced plus an `ote` on an input, a
  rung over two lines, a duplicated rung, an improper list, a renamed tag and a changed
  preset; each is refused by `types:` and by `Tag.new!/4`. The old test that asserted
  `user?/1` accepted a hand-edited body now builds the program by hand instead, outside the
  contract, where R45 and R65 still keep the runtime and the edit from raising. FS-Q22 is
  rewritten (its option (a) was false), and so are §12 and `user?/1`'s doc. The refuter's
  `p1.exs` now prints `user? false` for each shape, and compile raises the documented
  `ArgumentError`. The cost is RF-6's.
- **rf-F-fit-2 (medium), FS-Q2 left out org:866-867's rule for a type-changed member. Doc.**
  FS-Q2 gains the sub-question: refused (R47, org:820, org:860) or started at its initial
  value (org:866-867). §9's commit-4 row adds org:945-948, which R46 makes untrue.
- **rf-F-fit-3 (medium), FS-Q4 dropped F1-Q12's option (b), the IR carrying the block type.
  Doc.** Restored as FS-Q4 (d), with the costs the verdict corrected: it removes the `Scan`
  key, R43 and the pinned key, but `cal` still narrows `ons_blocked` per body, the IR-shape
  convention and every IR walk change, and a body change would change every calling rung in
  the edit's comparison.
- **rf-F-fit-4 (low), a block's warnings never reach a `compile_file/1` caller. Doc; question.**
  `compile_file/1`'s doc now says a block's warnings stay in its type, each with its file.
  FS-Q26 asks whether to merge them into the program's.
- **rf-F-fit-5 (low), FS-Q16 and S-synth Q-22 are one decision. Doc.** Merged as FS-Q16 with
  S-rev Q-22, the recommendation reversed to M2-1 first (X5's reconciliation). I merged this
  revision's spike onto S-synth's (`git apply --3way`, one conflict, the alias line, resolved
  to the union; the two test-file conflicts taken from this side): `mix compile
  --warnings-as-errors` exits 0, `mix test` gives `Result: 561 passed (7 doctests, 554
  tests)`, and the refuter's `sf_get.exs` prints `m1.s2.run: {:ok, 1}`, refuses `m1.s2.t1`
  and `m1.s2.inner` as not members of `m1.s2`, and `m1.s2` named whole.
- **rf-F-fit-6 (low), the stanza, the README and a CLAUDE.md line. Fixed in the spike.** The
  `function_block` stanza and the README now say "first rung, comments and blank lines
  allowed before it", per FS-Q21 (a); §8 commit 1 says the stanza's sentence follows FS-Q21's
  answer, since `naming.md` is append-only. CLAUDE.md's type-word line now covers
  `Declarations.kinds/0` and says a user block's name is no row and owes no stanza.
- **rf-F-fit-7 (low), FS-Q10 and FS-Q19 were decided. Doc.** Moved to "Kept as decided" at the
  end of §13.

### Cross-track (rf-X-consistency)

- **X1 (high, F+T).** This side: §5 lists what T's configuration code must take from M2-5
  before its checks land: a cal-aware writes walk (a `cal`'s output is a write, its signature
  per instance type, not `Compiler.instructions/0`'s `:block` marker), block `ton`s for W6
  through B5's one walk, and R8's message for a `program` line that names a block file. T's §8
  sentence is T's to correct.
- **X3 (medium, F+T).** This side: §5 M2-4 says the refusal of `var_external` in a block's
  file is unconditional once M2-5 lands first, with a located diagnostic and a test, in T's
  commit; `FbType.of/1` takes three sections only, so a new section must be refused before a
  block's type is built. Not built here: the section does not exist in this spike.
- **X4 (medium, F+T).** This side: §5 M2-2 says T's loader composes its `.ld` gate in front of
  this `load/3`, resolves program types through it with one memo per configuration, and checks
  a file's kind. Not built here.
- **X5 (medium).** FS-Q16 merged with S-rev Q-22 and the recommendation changed (above).
- **X6 (medium).** Under M2-1 first, M2-5 lands second and owns the test of
  `Logex.Runtime.get(rt, "m1.s2.run")`: §8's blocks commit carries it, and FS-Q1 now only
  matters if the maintainer takes M2-5 first.
- **X13 (low).** F's R8 words at every entry point, as S-rev Q-39 recommends; §5 says so.
- **X14 (medium).** §8 starts with one design-record commit for all three tracks, which
  allocates the decision numbers; §9 no longer says "numbered from 30".
- **X16 (low).** §5 now says `get/2` resolves a path with `FbType.member/2`, and that a depth
  growth test of `get/2` is owed only under FS-Q9 (b).
- **X18 (low).** F15 goes to M2-5 under the recommended order (S-rev Q-38): FS-Q29 states R68's
  and T's R51's citation conventions together. Not built here.
- **X19, X20 (low).** §5 records the agreements this track is party to, and §8 the hand
  composition of `Declarations.check/2` with T's `shared/1` and of the two naming tests.
- **X2, X7, X9, X10, X11, X12, X15** concern tracks S and T only; nothing here changes.

---

## 0. The answer in one page

- **A block is a `.ld` file headed `function_block <name>`**, its first rung (comments and blank
  lines may come before it), the name matching the file's. `Logex.compile(source, name: "seal")`
  returns `{:ok, %Logex.FbType{name: "seal", members: [...], body: %Logex.Program{}}}`.
  `function_block` is reserved in a block's file, names no block, and is recognised in any case.
- **A program gets its blocks two ways:** `Logex.compile(source, name:, types: [seal])`, or
  `Logex.compile_file/1`, which finds `seal.ld` beside the file that names `seal`, compiles it
  once, refuses a cycle of files, and refuses a program's file named as a type before it looks
  for a cycle; a file whose name it refuses still finds its blocks.
- **A type given is one a compile gives**, checked exactly: its members are `of/1` of its body,
  and its body's rungs lower again through the compiler's own checks to themselves
  (`Logex.Compiler.lowered?/1`), so a hand-edited body is an `ArgumentError` where it is given
  and never reaches the runtime or an edit. Each nested type is held once, in its holder's tag
  table; a member names it, `{:block, "seal"}`.
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
  `now` and `first` the program's.
- **Online edit, by path:** a block's type is its name and its members' kinds; its body may
  change, and members may be added or dropped. A switch migrates each instance member by member
  by OE-1's own rules, a one-shot inside is blocked where its chain of rungs changed (a `cal`
  keyed by the formals its operands fill), and stays blocked until a scan runs it, nested
  timers meet the timer rules, and an output only a `cal` drove is held.
- **Order:** M2-1 first, then M2-5 before M2-2 (FS-Q16, with S-rev Q-22), so PLAN M2-5's
  Done-when stands as written and M2-5's test reads `m1.s2.run` through `get/2`.
- **Receipts:** the gate passes three times (`Result: 498 passed (6 doctests, 492 tests)`, up
  from 489 in the synthesis and 430 at `47319f7`). 88 rules reverted one at a time (§7.2).
  `api_contract_test.exs`'s block walk now checks the one-shot rule on every scan. A program
  with no blocks pays 278→283 reductions per `call/4` and 7,111→7,308 per compile.

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
Logex.Compiler.lowered?(%Logex.Program{}) :: boolean  # new: the definition of a compiled body

# lib/logex/fb_type.ex
%Logex.FbType{name:, members:, body: nil | %Logex.Program{}}          # body is new
%Logex.FbType.Member{role: :input | :output | :local | :internal,     # :local is new
                     type: :bool | :dint | :clock | %FbType{} | {:block, name}}  # {:block, _} new
Logex.FbType.of(%Logex.Program{}) :: %Logex.FbType{}                  # new
Logex.FbType.signature(%Logex.FbType{}) :: [{slot, %Member{} | nil}]  # new, cal's operands
Logex.FbType.type_of(%Logex.FbType{}, %Member{}) :: type              # new: a member's type
Logex.FbType.user?(term) :: boolean                                   # new, total, exact
Logex.FbType.public/1, member/2, writable/1                          # unchanged code
Logex.FbType.initial/1,2              # unchanged result; a {:block, _} member read via type_of/2

# lib/logex/scan.ex
%Logex.Scan{now:, first:, ons_blocked: [], tags: nil}                 # tags is new, the runtime's

# lib/logex/declarations.ex
Logex.Declarations.kinds() :: ["function_block"]                      # new, for naming_test
Logex.Declarations.block_name?(word) :: boolean                       # new
Logex.Declarations.split(rungs, declared \\ [], types \\ %{})         # types is new
```

`Logex.Runtime` and `Logex.Edit` gain no function. The pinned surface test
(`test/logex/runtime_test.exs:688-735`) changes in three places: `Compiler.instructionize/3`
and `lowered?/1`; `FbType.of/1`, `signature/1`, `type_of/2` and `user?/1`; `Scan`'s keys gain
`:tags`.

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
%Member{name: "inner", type: {:block, "seal"},   role: :local, initial: %{}}
# ... and the type itself once, in the body's tag table: body.tags["inner"].type == seal

# the IR of `xic en cal s1 a stop k1`
{:rung, [{:xic, 9, [{:name, 9, "en"}]},
         {:cal, 9, [{:name, 9, "s1"}, {:name, 9, "a"}, {:name, 9, "stop"}, {:name, 9, "k1"}]}]}

# an instance's state: one map per instance, at any depth (Program.initial_env/1, unchanged)
env["s1"]                == %{"start" => 0, "stop" => 0, "run" => 1}
env["o"]["inner"]["run"] == 1

# the instance's block list: a bit by its path; after a scan, the bits of the instances
# whose bodies it did not run are still there (R78)
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
  its body one a compile gives (R85), and none holding a type of its own name at any depth
  (JF2 H4, H5: a hand-edited `write: true` or reordered members are refused). Spike
  `FbType.valid/3`, `fresh/4`.
- **R13** `user?/1` refuses a name no block could have: not a name, reserved, or the header word.
  Spike `FbType.named/4`.
- **R14** `user?/1` accepts a member declared from Elixir, which has no line, so a type
  `instructionize/3` makes from Elixir tags is one a compile takes (JF1 defect 4). Spike
  `FbType.declared?/1`.
- **R15** No two blocks of one name in `types:`. Spike `Compiler.given!/3`.
- **R16** One version of each block name per compile, across the types given, the types they
  hold, and the types of tags declared from Elixir: the runtime and the edit look types up by
  name, two that differ only in their warnings being one (R82; FS-Q14). Spike
  `Compiler.one_version!/2`.
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
- **R41** `first` and `now` are the program instance's inside a body (PLAN:1351-1352; kept as decided, §13).
- **R42** The body sees its own instance's blocked bits and its type's tag table, no other: a
  program bit `edge` and a block's `edge` never collide.
- **R43** `scan.tags` is the runtime's: a host that fills it in is refused, as one that fills
  `ons_blocked` is (OE-1). Spike `Runtime.scan!/2`.
- **R44** An instance a plain swap left as no map runs from an empty one (within the contract: a
  plain swap is a scan of another program). Spike `Runtime.called/5` (`as_map/1`).
- **R45** A `cal` of an instance its table does not hold as a user block's runs nothing (JF2
  D2b; from F1's total clause). A type given cannot hold one (R85); only a program built or
  edited by hand, outside the contract, can. Spike `Runtime.called/5`.

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
  the body's rung, each `cal` keyed by the formals it fills (R81); decision 21 blocks it where
  any rung on the chain is new or changed, at any depth, until a scan runs it (R78) (FS-Q5;
  JF2 K6 and F1 J4). Spike `Edit.rungs/1`, `inside/5`.
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
- **R65** The edit's walk is total on a program edited by hand to hold such a body: a `cal` of
  no block writes and runs nothing, as the runtime runs nothing (R45). Spike `Edit.calling/3`.
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

### The revision (R78 to R93)

- **R78** A scan keeps in the instance's block list each bit inside an instance whose body it
  did not run, a `cal` false or none, so the block is not used up unseen (RF-1; decision 21).
  Spike `Runtime.unrun/2`, `ran/4`.
- **R79** A switch taken after a scan lists again every bit the scan left listed where the
  program it starts still has that `ons`, as fix F2 does for an earlier edit's (RF-1). Spike
  `Edit.scanned/3`.
- **R80** A member holding an instance of a user block names its type, `{:block, name}`; the
  type is held once, in the body's tag table, `FbType.type_of/2` giving it, so a type copied
  flat is linear in its depth (RF-2). Spike `FbType.held/1`.
- **R81** In a one-shot's chain of rungs a `cal` is keyed by its operands and the formals they
  fill, so reordering a block's inputs changes the chain (RF-3). Spike `Edit.bare/2`,
  `formals/1`.
- **R82** Two versions of a block are one where they differ only in their warnings, at any
  depth (RF-4). Spike `Compiler.same?/2`.
- **R83** A second version found through a tag declared from Elixir is reported as the tag's,
  not the types' (RF-8). Spike `Compiler.versions!/4`.
- **R84** An edit names a user block's type as "an instance of `inner`" (RF-8). Spike
  `Edit.word/1`.
- **R85** `user?/1` holds only for a type whose body is one a compile gives,
  `Logex.Compiler.lowered?/1`, checked once every type the body holds is valid
  (rf-F-fit-1; org:775-779). Spike `FbType.lowered/2`.
- **R86** Each rung of such a body lowers again to itself, through the compiler's own checks,
  with no diagnostic. Spike `Compiler.lowers_to_itself?/2`.
- **R87** Its rungs are on rising lines, each on one line, after its declaration lines. Spike
  `Compiler.lines?/2`.
- **R88** Its warnings are the ones its rungs give, a file aside. Spike `Compiler.relowered/4`.
- **R89** Its tags are named as a declaration line in a block's file can name them. Spike
  `FbType.tag_name?/1`.
- **R90** Its timers carry the preset of the `ton` that runs each. Spike `Compiler.relowered/4`.
- **R91** A file whose name `compile_file/1` refuses is compiled with the blocks beside it, so
  its only extra diagnostic is the name's (RF-7). Spike `Logex.from_file/4`.
- **R92, R93** The record R78 keeps while a scan runs is a map, whatever an env built by hand
  held under its key, where a `cal` adds to it (R92) and where it is taken out (R93), so a
  scan raises nothing (found in this pass). Spike `Runtime.ran/4`, `recorded/1`.

`lowered?/1` also checks the one-`ons`-per-bit, one-`cal`-per-instance and nothing-after-a-`ton`
rules on the body, by calling the compiler's own `shared_bits/2`, `calls/1` and `path/2`. No
test edits a body so that only one of those three calls refuses it, so no revert of them is in
§7.2: they are unpinned (§12).

---

## 3. Every host-mistake message and diagnostic, exact

### 3.1 Host mistakes (`ArgumentError`), each pinned by a test

| Where | Message |
|---|---|
| `compile/2`, a bad option | ``Logex.compile/2 takes a name and, where the source uses function blocks, their types, as in Logex.compile(source, name: "motor", types: [seal]), got: …`` (replaces M1-5's, `lib/logex.ex:65-71`, pinned at `test/logex_test.exs:133-138`) |
| `types:` not a list | `types must be a list of function block types from Logex.compile/2, got: …` |
| an element `user?/1` refuses (R11-R13, R85-R90): a hand-edited member or body | `types must be function block types from Logex.compile/2, got: …` |
| two of one name (R15) | ``types holds two function blocks named `seal`: one name, one type`` |
| two versions of one name (R16) | ``types holds two different function blocks named `seal`, one inside another type given: compile each block against the same types`` |
| two versions, the second through a tag from Elixir (R83) | ``a tag declared from Elixir holds a function block named `seal` other than the one of that name in the types given or in another tag: give every instance of a block the same version, compiled against the same types`` |
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
| a block renamed (R84) | ``line 4: `p` is an instance of `pulse` in the running program and an instance of `latch` in the candidate: a tag's type changes only with a restart`` (OE-1's template; "a pulse" before) |
| a member holding another block (R47, R84) | ``line 3: `w.k` is an instance of `inner` in the running program and an instance of `other` in the candidate: a member's type changes only with a restart`` |

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
| a one-shot bit inside it, `s1.edge` | its initial | its `ons`, if the block runs; a listed bit stays listed while no scan runs its block (R78) | started again; the block list emptied | listed by path where its chain changed (R54, R55, R81), its instance is added, or it is pending from an earlier switch (R57) or a scan that did not run it (R79); the bit untouched | not listed (no switch); a listed bit stays listed | — |
| `scan.tags` | — | filled from the program, narrowed per body | — | — | — | — |

`first` stays false at a switch. Var_inputs stay top-level, the program's interface: a block's
inputs are copied in by `cal`, never `:input` or `:unread`.

---

## 5. What each later item and OE-2 add, and the seams with tracks S and T

The order this revision recommends is M2-1, then M2-5, then M2-2, M2-3, M2-4 and M2-6
(FS-Q16, with S-rev Q-22; X5). Each item below says what it takes from M2-5, and where a
consistency finding put a seam, what the item that lands second must do.

- **M2-1 (scheduler), before M2-5.** `start/1` builds each instance through `instance/1` (fix
  F14), so nested state needs nothing new; `cycle/3` calls `call/4`, which fills `scan.tags`
  and keeps a frozen block's bits (R78). `get(rt, "m1.s2.run")` resolves the part after the
  instance name with `FbType.member/2`, which under R31 and R32 reaches a tag or one member of
  an instance and no deeper (X16): a growth test of `get/2` in depth is owed only if FS-Q9 is
  decided (b). M2-5, landing second, owns the test of `get(rt, "m1.s2.run")` (X6): with
  S-synth's spike and this one merged, it reads `{:ok, 1}`, refuses `m1.s2.t1` and
  `m1.s2.inner` as no members of `m1.s2`, and refuses `m1.s2` named whole (Changed in
  revision, rf-F-fit-5). A configuration needs no block library: every block a program holds
  is inside its tags. A block type given as a program is refused with R8's words at every
  entry point, `check/1` and `new!/1` included (X13, S-rev Q-39).
- **M2-2 (the configuration file).** The loader's rule, a type word names a file beside the
  file that names it, is also `program m1 motor`'s (T-synth adopts it, T-synth.md:637-640).
  What T's loader must take from this one (X4): its `.ld` gate composed in front of
  `load/3`, not beside it (`Logex.compile_file/1` conflicts textually); program types
  resolved through `load/3` with one memo for the whole configuration, so a block two
  programs hold is read and compiled once (T's spike reads it four times); and a kind check,
  so `program m1 seal` naming a block file gets R8's words as a located diagnostic instead of
  T's `FunctionClauseError` (X1). Every check T computes from a program's writes must take a
  `cal`'s outputs as writes, each `cal` with its own instance type's signature: T's
  `writes/1` zips `Compiler.instructions/0`'s `{:cal, :block}` marker and raises (X1). The
  hand composition of `Declarations` (F's `check/2` with T's `shared/1`, both moduledoc
  paragraphs, the grammar line with `| var_external` and `a block's name`) and of the two new
  naming tests is X20's. Fix F15 goes to M2-5 under this order (FS-Q29; X18).
- **M2-3.** Nothing new: a block's timers read the scan's `now`, the task's clock.
- **M2-4 (`var_external`).** A body runs over its instance's map, which holds no global, and
  `FbType.of/1` takes `var_input`, `var_output` and `var` only (spike `FbType.role/1`). So
  once M2-5 has landed, the refusal of `var_external` in a block's file is unconditional, a
  located `:validate` diagnostic with a test that fails when it is reverted, before the
  block's type is built; in the F+T merge the section reaches `role/1` and raises
  `FunctionClauseError` (X3). Both tracks recommend the refusal (T Q-18 (a); X19). Whether
  IEC allows VAR_EXTERNAL in a FUNCTION_BLOCK is unverified here (inventory U19). M2-4's
  "which tags a program writes" takes B5's cal-aware walk (FS-Q23), which must land before
  any configuration check reads writes or timers (X1, X19).
- **M2-6.** An `ons` in a block in an event task follows R41, and W6 must count a `ton`
  inside a block that the program's `cal`s run: with T's walk, a block's `ton` is silently
  missed today (X1's verdict).
- **OE-2.** The plans are already per program type, the switch and prune per instance (fix
  F5), so the nested plans ride along. Report names gain the instance in front, `m1.p.count`. A
  block type changed for the whole configuration changes every program type that holds it,
  each by its own plan. PLAN OE-2's "a function block's members … until M2-5" (PLAN:1491-1493)
  is lifted by R46 to R48; under FS-Q2's alternative it stays. A frozen block's pending bits
  (R78) are per instance, in its `ons_blocked`, so OE-2's switch carries them as R79 does. The
  generation counter is unaffected.

---

## 6. Spike receipts

- **Gate** (see §7.2's status note: one run on the final tree, two on trees one and two tests smaller), on the finished spike (`F-rev-gate.sh`, `F-rev-gate.log`):
  `mix format --check-formatted` 0; `mix compile --force --warnings-as-errors` 0;
  `MIX_ENV=test mix compile --force --warnings-as-errors` 0; `mix test --warnings-as-errors` 0,
  `Result: 498 passed (6 doctests, 492 tests)`, each time. F-synth gave 489, `47319f7` 430.
- **The patch** `F-rev.patch`: 20 files changed, 4466 insertions(+), 240 deletions(-).
- **New tests in this revision: 9** in `function_block_test.exs` (65 there now), all named in
  "Changed in revision"; two extended (R83, R84); one rewritten (R45's, now on a program built
  by hand); `api_contract_test.exs`'s block walk with an every-scan one-shot oracle and two
  more reach atoms; `runtime_test.exs`'s surface pin gains `Compiler.lowered?/1` and
  `FbType.type_of/2`.
- **Done-when** (`--trace`, unchanged from F-synth):
  ```
  * test user function blocks (M2-5) PLAN M2-5's Done-when: a seal-in written once as a block, run three times (41.6ms) [L#1419]
  Result: 1 passed, 78 excluded
  * test PLAN M2-5's Done-when a false EN freezes only its own instance, and the tags its outputs name (559.5ms) [L#105]
  * test PLAN M2-5's Done-when a recursive type, an unknown function block type and a cal of a non-instance are each a located diagnostic (0.4ms) [L#122]
  * test PLAN M2-5's Done-when a seal-in written once as a block and instantiated three times behaves as three independent seal-ins, and m1.s2.run reads one of them (0.6ms) [L#82]
  Result: 3 passed, 61 excluded
  ```
  Under FS-Q16 (a) the landed test also reads `get(rt, "m1.s2.run")`; on the merge of this spike
  with S-synth's, `sf_get.exs` prints `m1.s2.run: {:ok, 1}` (Changed in revision, rf-F-fit-5).
- **Reverts:** 6 reverts, 6 red by a failing test of their own (§7.2).
- **The refuters' probes on the revised spike** (a copy with their probe files,
  `scratchpad/m2/F-rev-pc`): RF-1 `p13.exs`, RF-3 `p5.exs`, RF-4 `p7.exs` and `p6.exs`, RF-7
  `p6.exs`, RF-8 `p11.exs` and `p12.exs`, rf-F-fit-1 `p1.exs`: as quoted in "Changed in
  revision". RF-2 `p10.exs`: depth 4 `flat=1225` words, depth 20 `flat=4873`,
  `term_to_binary=21140B`, a send in `36us`. RF-5 `p14.exs`, a one-shot at every level, switch
  scan 13,091 / 46,517 / 175,664 / 680,691 reductions at depth 50 / 100 / 200 / 400, report
  bytes 8,998 / 32,948 / 125,848 / 491,648. RF-6 `p8.exs`: 680,019 / 2,420,443 / 9,087,510 /
  35,159,526 / 138,358,875 reductions for 25 / 50 / 100 / 200 / 400 files.
- **The judges' probes on the revised spike:** JF1 `walk.exs`: `failures: 0`. JF1 `p3.exs`
  case A untest reports `[]` and `x.t1` catches up to acc 40, as with no edit; case B untest
  reports `[{:resume_undone, "x.t1", 30}]`. JF2 `walk.exs` seeds 1-3 × 300 and `walk2.exs`
  seeds 11-12 × 300: `escapes 0, rebuild mismatches 0, duplicate entries 0, forecast
  mismatches 0` each. JF2 `soup.exs` seed 1: `3000 soups, 34 programs and 3 blocks compiled,
  escapes 0` (`F-rev-jf1walk.log`, `F-rev-jf2walk.log`, `F-rev-jf2soup.log`,
  `F-rev-jf1p3.log`).
- **Cost** (`F2-probe/cost.exs`, least of 200, three runs, identical): the README motor at HEAD
  against the spike, `call/4` with no inputs 278 against 283 (F-synth 281; the 2 more are the
  empty block list's check after the scan), `compile/2` 7,111 against 7,308. A seal through
  `cal` 273 against 153 inline. `FbType.user?/1` on a small block 2,486 reductions (F-synth
  244), on a block holding it 4,013 (`F-rev-probe/cost.exs`).
- **Growth** (`F-synth-ratios.exs`, 5 runs, at 50 and 800 levels, 16x): scan 14.88x to 15.44x,
  compile 15.30x to 15.41x (F-synth 13.24x to 13.43x: the relowering is linear per type), edit
  15.44x to 16.41x; the blocked scan at 16x the bits 16.21x to 16.23x. A flat copy at 6 and 12
  levels 1.7x the words (`F-rev-probe/growth.exs`: 1,957 and 3,325).

---

## 7. Test plan and mutation table

### 7.1 Tests

`test/logex/function_block_test.exs`, 65 tests:

| Describe | Pins |
|---|---|
| PLAN M2-5's Done-when (3) | R37-R39, R31, R19, R22, R17, R24 |
| a function block's file (6) | R1-R10, R13, R32, R75 |
| the types a compile is given (5) | R10-R18, R14, R16, R82, R83, R85-R90 |
| recursion (1) | R20, R21 |
| cal (4) | R23-R30, R74 |
| members (1) | R31, R33 |
| warnings (3) | R34-R36 |
| running a block (8) | R40-R45, R37, R92, R93 |
| the online edit of a program that holds blocks (15) | R46-R49, R51, R54, R57, R58, R60, R64, R78, R79, R81, R84 |
| the online edit, at depth and across a round trip (8) | R50, R53, R55, R56, R59, R61, R62, R63 |
| a block's file found beside the file that names it (5) | R67-R70, R73, R3, R91 |
| growth in the depth of nesting (1) | R66 |
| growth in the size of a term (2) | R80; RF-5's claim |
| the host contract over sources that use blocks (1) | 3,000 seeded soups |
| growth in the instances (1) | the blocked scan |
| an instance's state nests by path (1) | — |

`end_to_end_test.exs`: the Done-when through `compile_file/1` (R67, R68 for files).
`api_contract_test.exs`: the fourth walk, 800 walks × 100 steps over 252 programs built from 9
versions of `blk`, 4 of `wrap` (which holds a `blk`) and 7 programs. Its oracles: the writes of
each report, applied by path, rebuild the state; the block list equals the `:ons_blocked`
entries; after a switch every leaf of the started program's initial env is present; after a
prune no leaf the kept program lacks remains; a test then an untest with no scan between gives
back every leaf neither switch started, `last` included; and, new here, on every scan that runs
a `blk` one level (`x`) or two levels (`w.inner`) down, under a chain of rung texts other than
the one it last ran under, its one-shot passes no power. Under which chain each last ran is
known from the walk alone: none after a start or restart (the first run fires, PLAN M2-5),
unknown where a `wrap` runs its `blk` under a one-shot of its own. It asserts its reach: every
step kind, a refusal, a round trip with a nested timer, both one-shot oracles on the scan right
after a switch and on a later one (`:ons_x_changed_late`, `:ons_inner_changed_late`, which only a
`cal` false in between can produce), and nested `:added`, `:dn_drops`, `:dn_rises`,
`:initial_changed`, `:ons_blocked`, `:preset`, `:pruned`, `:resume_undone`, `:resumed`. With R78
reverted by hand it fails (§7.2, R78). Changed pins: `runtime_test.exs` (surface, `Scan` keys),
`logex_test.exs` (options message), `validation_test.exs` and `api_contract_test.exs:108` ("only
an instance of a function block has members"), `naming_test.exs` (a test over
`Declarations.kinds/0`).

### 7.2 Mutation table

**Status of this table when this document was written:** the run over all 88 reverts, on the final tree, was still going (detached; it writes `F-rev-mutation.log` and, when done, `F-rev-mutation.json`). The rows below are the reverts it had finished, read from their logs (`F-rev-doc/build.py` rebuilds this section from the finished JSON). An earlier, aborted run on the tree before the last two test changes is `F-rev-mutation-aborted.log`. The gate on the final tree passed once here (`Result: 498 passed (6 doctests, 492 tests)`, exit 0); two earlier runs on trees one and two tests smaller also exited 0 (496 and 497 passed). The third run on the final tree is owed.

Each rule of §2 reverted alone in a copy of the finished spike, the whole suite run with
`mix test --warnings-as-errors`, the file restored. Driver `F-rev-mutation.py` (`check` then
`run`, four copies in parallel), results `F-rev-mutation.json`, logs `F-rev-mutation/Rn.log`,
summary `F-rev-mutation.log`. R1 to R72 are F-synth's, their patterns moved where the revision
moved the code they revert (R16, R33, R41, R42); R78 to R93 are new. **6 reverts: 6 red with a failing test of their own, 0 failing only a load-sensitive growth test in the parallel run, 0 green.** 2 (marked w) also printed a compile warning in `lib/` from Elixir 1.20's type checker, which sees a clause made unreachable; the suite still ran, and the failing tests are listed. The parallel run shared the machine with another track's (load average about 40), and in it the pre-existing reduction-ratio tests of `logex_test.exs` and `edit_test.exs`'s F16 growth tests failed now and then whatever was reverted; the gate, run alone, passes three times. A revert whose only failures were those is rerun alone.

| Revert | Rule reverted | File | Exit | Result | Tests that failed (a load-sensitive growth test listed only where nothing else failed) |
|---|---|---|---|---|---|
| R1 | the header word is recognised in any case | `logex/compiler.ex` | 2 | 496/498 passed (6/6 doctests, 490/492 tests) | FunctionBlockTest: a function block's file its header is its first rung: comments and blank lines may come before it; and 1 more |
| R2 | a var is a :local member | `logex/fb_type.ex` | 2 | 497/498 passed (6/6 doctests, 491/492 tests) | FunctionBlockTest: a function block's file a var is local: in the state, named only inside the block |
| R3 | a block is named after its file | `logex.ex` | 2 | 494/498 passed (6/6 doctests, 488/492 tests) | FunctionBlockTest: a function block's file its first line names it as it is compiled, and as its file is named; FunctionBlockTest: a block's file found beside the file that names it a program's file is no type, and a block's first line must match its file's name; and 2 more |
| R4 (w) | a block's name is no reserved word | `logex/compiler.ex` | 2 | 497/498 passed (6/6 doctests, 491/492 tests) | FunctionBlockTest: a function block's file its first line names it as it is compiled, and as its file is named |
| R5 | function_block names no block (org §4.8) | `logex/compiler.ex` | 2 | 497/498 passed (6/6 doctests, 491/492 tests) | FunctionBlockTest: a function block's file its first line names it as it is compiled, and as its file is named |
| R6 (w) | function_block names no tag in a block's file | `logex/compiler.ex` | 2 | 432/498 passed (6/6 doctests, 426/492 tests) | FunctionBlockTest: the online edit of a program that holds blocks a nested block an earlier edit left pending survives a second edit before any scan (F2); FunctionBlockTest: running a block ENO is the power out: what follows a cal sees its EN; FunctionBlockTest: the host contract, over sources that use blocks compile/2 never raises, its diagnostics are in line order and it reaches every M2-5 diagnostic; every program it gives scans without raising; and 63 more |

---

## 8. Landing order, as commits, each green

The milestone's order is FS-Q16 (a): M2-1's commits (S-rev §8) land first, then these, then
M2-2. Commit 0 is shared with tracks S and T.

0. **The design record, for all three tracks at once** (X14). The maintainer's answers to
   S's, F's and T's §13 go into org §7 in one commit, each decision numbered once across the
   tracks, before any M2 code cites one: the labels test (`test/logex/edit_test.exs:1557-1569`)
   refuses a cited decision §7 does not define and needs §7 to run 1..n. The same commit
   orders the overlapping document edits (org §4.4, §4.9, §6.2; PLAN's Done-whens; README's
   syntax list and "Settled, not yet landed"; CLAUDE.md's `lib/logex.ex` entry). From this
   track: FS-Q2's sub-answer rewords org:866-867 and org:945-948; FS-Q21's rewords decision
   4's record; FS-Q27's restates org:1160; FS-Q30's restates org:1015. Documents only.
1. **Survey.** Append the `function_block` and `cal` stanzas to `docs/naming.md` (`cal`
   supersedes the `cal <routine>` row at `docs/naming.md:240`, which stays: the file is
   append-only), the `function_block` stanza's header sentence worded by FS-Q21's answer (the
   spike's says "first rung", for (a)). Add `Declarations.kinds/0` and its `naming_test` test.
   Reserves nothing yet; breaks no tag.
2. **The walks learn a signature per instruction** (no behaviour change). `Logex.Edit` and
   `Logex.Warnings` look a `cal`'s slots up from its instance's type and are total on one that is
   no block (R65's code). If the maintainer takes FS-Q23 (b), the B5 extraction goes here, and
   it is the walk T's configuration checks then take (X1).
3. **Blocks and `cal`.** `FbType` gains `body`, `:local`, `of/1`, `signature/1`, `type_of/2`,
   `user?/1`, and a member's `{:block, name}` (R80); `Compiler` gains `lowered?/1` (R85-R90);
   `Declarations` takes a library and gains `block_name?/1`; the compiler gains the header, the
   library checks, one version per name without warnings (R82, R83), the recursion marks and
   excused uses, the `cal` lowering and checks, one `cal` per instance; `Logex.compile/2` gains
   `types:`; `Scan` gains `tags`; the runtime gains its `cal` pair, the block-type message, the
   total clause, and the frozen block's kept bits (R78), with its new scan rule restated in
   `Logex.Instance`, `Logex.Scan`, `Logex.Runtime` and CLAUDE.md; the warnings learn `cal`. Fix
   F15, under FS-Q29 (a): `%Logex.Program{}` gains a `file`, which `compile_file/1` sets, and
   `Logex.Edit`'s diagnostics carry it (not built in the spike). Tests: the function_block
   describes for the file, the library (the hand-edited bodies among them), recursion, `cal`,
   members, warnings, running a block, the host contract, growth in the depth and in a term's
   size, and the Done-when, which, M2-1 having landed, reads `get(rt, "m1.s2.run")` through a
   configuration (X6). **Reserves `cal` in every `.ld`, in any case** (a mnemonic), and
   **`function_block` in a block's file**. **Breaks** any program with a tag named `cal` in any
   case (no test, `lib/` file or golden-record entry uses one; inventory item 11), and changes
   the pinned messages listed in §7.1. The edit is naive here (any block change refused by
   `!=`, nested one-shots not blocked): land 3 and 4 in one push.
4. **The edit, by path.** R46 to R64, R66, R79, R81 and R84, the edit's growth tests, the "at
   depth and across a round trip" describe, the frozen-block tests, and the
   `api_contract_test.exs` walk over blocks with its every-scan one-shot oracle. Breaks no tag.
5. **The loader.** `compile_file/1` finds block files beside (R67-R70, R73, R91), its describe,
   the end-to-end Done-when through `compile_file/1`, and FS-Q26's answer. Breaks no tag. Of
   M2-2's commits, the one that adds the configuration loader composes its `.ld` gate in front
   of this `load/3` (X4), and the one that lands `var_external` refuses it in a block's file
   (X3); whichever of tracks F and T lands second composes `Declarations.check/2` with T's
   `shared/1`, both moduledoc paragraphs, the grammar line and both naming tests by hand (X20).
6. **Documents** (§9). Reserves nothing.

The spike is commits 1 to 5 together, without F15 and without the `get/2` assertion, which
need M2-1 and the design record, with the CLAUDE.md lines, moduledocs and README of 6.

---

## 9. Documents each commit stales

| Commit | README | CLAUDE.md | PLAN | organisation.md | naming.md |
|---|---|---|---|---|---|
| 0 | — | — | M2-5's Done-when kept (FS-Q16 (a)) | §7: the decisions, numbered once with S and T (X14); org:866-867, org:945-948 (FS-Q2), decision 4's record (FS-Q21), org:1015 (FS-Q30), org:1160 (FS-Q27) | — |
| 1 | — | — | — | — | the two stanzas (in the spike), the header sentence by FS-Q21 |
| 2 | — | the B5 note, if FS-Q23 (b) | — | — | — |
| 3 | syntax list (the `function_block` bullet, "first rung"), the `cal` row, "Settled, not yet landed" (in the spike) | the `evaluate/3` convention with the frozen block's kept bits, step 2's `cal` exception, the type-word line (`kinds/0`, a block's name no row), Key Files for `fb_type.ex` and `compiler.ex` (`lowered?/1`) (all in the spike); `scan.ex`, `logex.ex` (`types:`), `function_block_test.exs`; F15's `file` | M2-5's record | §4.3 as landed: `:local`, `user?/1` and `lowered?/1`, the library, one version per name, members hidden and unwritable, a member's `{:block, name}` | — |
| 4 | "Changing a running program": a block may change while running, by path | Key Files for `edit.ex` and `api_contract_test.exs`'s fourth walk | OE-2's sentence (PLAN:1491-1493) | §4.9: the members' refusal (org:866) lifted; the Resume row (org:1004) reworded for "the program that last scanned" and "from the text" (§11, item 3); "A scan empties the list" (org:1015) for a frozen block; the nested rows in the tables | — |
| 5 | `compile_file/1` finds blocks beside | Key Files for `logex.ex` | M2-2's loader sentence, if FS-Q12 (a) | §4.3 the loader; §6.2 M2-2's loader is shared, one memo per configuration (X4) | — |
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

The revision (this document):

| Part | From | Why |
|---|---|---|
| Frozen block keeps its bits (R78, R79), every-scan oracle | RF-1's suggested fix, its first option | decision 21's purpose |
| A member names its block's type (R80) | RF-2, a variant of its suggestion | linear flat copies |
| `cal` keyed by formals (R81) | RF-3's suggested fix | FS-Q5's stated reason |
| Versions without warnings (R82) | RF-4's suggested fix | R16's purpose |
| Messages (R83, R84) | RF-8's suggested fixes | the host's argument named |
| `lowered?/1` (R85-R90) | rf-F-fit-1's second suggestion, with the compiler's own checks | org:775-779, one validator |
| Refused name finds blocks (R91) | RF-7's suggested fix | `compile_file/1`'s own doc |
| FS-Q16 merged and reversed; FS-Q29, FS-Q32 joint | X5, X18, X13; S-rev Q-22, Q-38, Q-39 | one answer per cross-track question |

---

## 11. Departures from decided rules

1. **CLAUDE.md:134, the `evaluate/3` convention:** "The scan is read-only and the same for every
   instruction of one call." Here it is the same for every instruction of one routine run, and
   `cal` narrows it for its body. The spike's CLAUDE.md line says so (FS-Q4).
2. **PLAN:1343-1347 and org:1407-1410, M2-5's Done-when:** "`m1.s2.run` reads one of them".
   The spike, on today's main, reads `s2.run` of the instance it names `m1` by a rung and from
   its state. Under FS-Q16 (a) this is no departure when it lands: M2-1 is in, and the test
   reads `get(rt, "m1.s2.run")` (FS-Q1).
3. **Org:1004 and `lib/logex/edit.ex:84-87,692-695`, the Resume rule's mechanism.** The rule "A
   timer T runs and F did not … resumes" is kept. Its stated basis, "a `last` before `now` says F
   did not run it", is replaced by two checks: F's text does not run the timer (F2's), and F is
   the program that last scanned (as fix F3 asks for one-shots). Top-level behaviour is
   unchanged: the OE-1 suite and its contract walk pass unmodified (FS-Q6).
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
9. **M2-2's loader, ahead of M2-2.** `compile_file/1` loads block files beside before the
   configuration file exists (R67; FS-Q12).
10. **Org:1160, §4.9's cost rule,** "keep the scan right after a switch linear in the one-shots
    it blocks". With a one-shot at every level of a chain the scan is linear in the length of
    the block list, which grows as the square of the depth (R78's growth test; FS-Q27). At the
    top level, where a bit's name is one name, nothing changes.
11. **Org:1015, §4.9:** "A scan empties the list, and so does a restart." A scan now keeps the
    bits inside an instance whose body it did not run (R78), and a switch after it lists them
    again (R79). At the top level every rung runs, so nothing changes there (FS-Q30).
12. **CLAUDE.md's Key Files entry for `fb_type.ex`** said each member has "a type". A member
    holding a user block now has `{:block, name}`, the type held in the body's tag table
    (R80; FS-Q31). The spike's CLAUDE.md says so.

No other decided rule moves: decisions 8, 12, 20, 21, 23, 26, 28 and 29, the reserved-word scope
(org §4.8) and the no-BEAM rule are kept. Nothing compiles a user's program; the edit path calls
no Elixir compiler. F-synth's unlisted gap against org:775-779 and CLAUDE.md's "Nothing else may
escape the public API", a hand-edited body passing `types:` (rf-F-fit-1), is closed (R85).

---

## 12. Risks

- **`Logex.Edit` roughly doubles in its per-instance code.** The block walk is the independent
  oracle the judges asked for, and its one-shot oracle now covers every scan, frozen instances
  included; it covers only versions whose output only the `ons` rung writes, and it has no
  `.pre` oracle independent of the rules (R59 is pinned by an example test only).
- **The scan convention.** A later evaluate clause that looks anything up in `scan.tags` must use
  the routine's table; CLAUDE.md says so. The frozen block's record (R78) rides in the env under
  an atom key while a scan runs: a clause that walked an env's keys would meet it. None does,
  and `call/4` takes it out before the state is returned. An env built by hand that already
  holds that key is read as a record, so it may consume a block its value names (R92, R93
  keep it from raising); a key no host can write, such as a reference made per scan, would
  close that too.
- **The exact check costs.** `user?/1` relowers each body: 2,486 reductions for a small block,
  ten times F-synth's 244, at every compile, for every type given at every depth (FS-Q22,
  FS-Q28). The depth-growth test's chain of 800 blocks now takes about 6 s to build, and the
  suite about 20 s instead of 9 on this machine.
- **Three of `lowered?/1`'s checks are unpinned** by a revert: its calls to the compiler's
  `shared_bits/2`, `calls/1` and `path/2` (§2, after R91).
- **Path strings at depth.** Reports and the block list name a member by its full path: O(n²)
  bytes for a chain n deep with a one-shot or a report at every level, and the scan right after
  a switch is linear in those bytes, so quadratic in the depth (RF-5; FS-Q27). Negligible at
  the conventional family's 16 levels (`docs/naming.md`'s new stanza, read from its manual).
- **Report details.** `{:added, path, map}` for a whole nested instance carries a map, as a timer's
  `:added` already does.
- **Fix F15 stays open in the spike.** A nested member's refusal cites the instance's line in the
  program, not the member's line in the block's file, and carries no file (FS-Q29).
- **A block's warnings live inside its type** (FS-Q26).
- **Articles before a block's name.** M1-6's member messages put "a" before a type's name, which
  reads "a outer" for a block so named (seen in the S+F merge: "`m1.o.s` is not a member of
  `m1.o`, a outer"). RF-8 fixed the edit's message only.
- **Per-`cal` cost.** `FbType.signature/1` is rebuilt at every energised `cal`: 273 reductions for
  a seal through `cal` against 153 inline. Precomputing it into the type is a cheap later change.
- **The loader stops at the first broken dependency** (FS-Q15) and reads a dependency's file twice
  (`peek/1`, then `load/3`) where it is a block.
- **Reduction-ratio tests under load.** During the mutation run, which shared the machine with
  another track's (load average about 40), three pre-existing growth tests
  (`logex_test.exs`'s two, `edit_test.exs`'s F16 pair) failed now and then with no rule
  reverted that bears on them. The gate, run alone, passes three times. §7.2 lists every
  failing test per revert, and says which reverts failed only such a test.

---

## 13. Decisions for the maintainer

FS-Q1 to FS-Q25 keep their numbers; FS-Q10 and FS-Q19 are now "Kept as decided", at the end. FS-Q26 to FS-Q32 are new. Three are cross-track, each one question with track S's revision: FS-Q16 (S-rev Q-22), FS-Q29 (S-rev Q-38) and FS-Q32 (S-rev Q-39).

**FS-Q1 · Only if FS-Q16 takes M2-5 first: PLAN M2-5's Done-when says `m1.s2.run` reads one of the seal-ins, but `get/2` is M2-1's. How is it asserted?** (M2-5 Done-when (inventory C1; F1-Q1, F2-Q12; X6))

- *(a) Reword it for M2-5 and assert `get(rt, "m1.s2.run")` in M2-1's acceptance.* The test reads `s2.run` of the instance it names `m1`, by a rung (`xic s2.run`) and from its state; one PLAN sentence and org:1407-1410 change.
- *(b) Land M2-1 first.* The Done-when stays as written, and M2-5, landing second, owns the test through `get/2` (X6). This is FS-Q16 (a).
- *(c) Add a per-instance read now, which M2-1's `get/2` delegates to.* A public function lands ahead of its scheduler and must be reconciled with `get(rt, path)`.

*Recommend (b), through FS-Q16.* The merged spikes read `m1.s2.run` through `get/2` with nothing changed (§5), so nothing is gained by rewording a decided Done-when. (a) applies only if FS-Q16 is decided (b). *Decide before:* FS-Q16.

**FS-Q2 · What may change in a block type while a program that holds it runs?** (M2-5 online edit / OE-2 (org:858-869; F1-Q2, F1-Q3, F2-Q2; rf-F-fit-2))

- *(a) Nothing: refuse any change to a block type, ignoring line numbers (F1).* Editing a block's logic needs a restart, as the conventional family edits its user-defined instructions offline only. Replace R46-R63's edit code with F1's FB-38 to FB-41 (+151 lines in edit.ex); OE-2 brings the migration, and org:866 and PLAN:1491-1493 are reworded.
- *(b) The body only.* Needs the path-keyed one-shot and timer rules (R54-R63, R78, R79, R81) without the member migration (R48-R53).
- *(c) The full nested migration in M2-5, as org:866 assigns (the spike).* About +560 lines in edit.ex with its moduledoc; 12 edit tests, 8 depth tests, the revision's 3, 2 growth tests and a seeded walk. Matches Beremiz's hot swap (copy leaves by path and type) and CODESYS's code-only replacement.

And, under (b) or (c), **a member whose type changes** (rf-F-fit-2), on which org pulls both ways:
- *(i) Refused, as a tag's type change is (the spike, R47):* org:820's table row ("A tag's or member's type | refused") and org:860's list ("the type of a tag or a member").
- *(ii) Started at its initial value and reported `:added`:* org:866-867's "copy the members that match by name and type, as CODESYS does, and initialise the rest", read literally.

*Recommend (c) with (i).* The documents give the migration to M2-5; both judges' walks and this pass's found no rebuild, prune or one-shot failure after the fixes; (i) keeps one rule for a type change at every depth, and a value that silently restarts inside a running block is what (ii) would add. Under (c), org:866-867 is reworded to (i), and so is org:945-948, which says any `Tag.type` inequality between two schemas is refused (§9). *Decide before:* the edit commit (§8 step 4).

**FS-Q3 · Should the uses of a declaration with an unknown type stop being reported as 'not declared', as a recursive one's now are?** (follow-up to M1-3 (F1-Q11))

- *(a) Keep M1-3's cascade (the spike).* A misspelled block name gives one extra line per use (the end-to-end test pins `line 18: `s3` is not declared`).
- *(b) Excuse those uses too.* One mistake, one message; some M1-3 and M1-6 pins change.

*Recommend (b), as a separate commit after M2-5.* A misspelled block name is now the likeliest unknown type. *Decide before:* nothing in M2-5.

**FS-Q4 · How does the private evaluator reach a block's body, given CLAUDE.md:134's 'the scan is the same for every instruction of one call'?** (M2-5 runtime (inventory C11; F1-Q12, F2-Q1; rf-F-fit-3))

- *(a) `Scan.tags`, runtime-filled; `cal` hands its body the scan narrowed to its instance (the spike).* The convention becomes 'of one routine run'; one pinned `Scan` key and one host check (R43); linear in depth.
- *(b) Expand each `cal` at compile time into the body with absolute paths.* The scan is unchanged, but each operand at depth k walks k maps: a chain of n blocks scans in O(n^2), and the IR grows with instances.
- *(c) A private frame struct as `evaluate/3`'s third argument.* The convention changes for every clause, not one.
- *(d) The IR carries the block type, a fourth tuple element or operand kind (F1-Q12 (b), restored).* No `Scan` key, no R43, no pinned key at `runtime_test.exs:711-712`, and linear. But `cal` still narrows `ons_blocked` per body, so the convention still becomes 'of one routine run'; CLAUDE.md's IR shape changes and every IR walk (compiler, Warnings, Edit) handles it; and since each `cal` rung would embed its type, a change to a block's body changes every calling rung's text in the edit's chain comparison, blocking one-shots that (a) leaves running unless every walk strips the type out again.

*Recommend (a).* It is the smallest departure that keeps the IR shape and the edit's chain rule as they are; (d) trades one runtime-owned scan key for a change to the IR every walk reads. *Decide before:* §8 step 3.

**FS-Q5 · Which rung changes make a one-shot inside a block 'changed', blocked for one scan?** (M2-5 online edit, decision 21 (F2-Q3; RF-3))

- *(a) Any rung on its chain: the program's `cal` rung, each body's `cal` rung, the body's `ons` rung, each `cal` keyed by its operands and the formals they fill (the spike, R54, R55, R81).* A changed EN condition, `cal` operand or order of a block's inputs blocks the one-shots under it, at any depth; at worst one real edge is lost, decision 21's accepted cost.
- *(b) The body's rung only.* A changed calling rung leaves the bit compared against a condition it never saw: the false pulse decision 21 prevents (JF2 J4, K6).
- *(c) Every one-shot inside an instance whose type changed.* Cruder; loses real edges where nothing on the chain changed.

*Recommend (a).* Decision 21 restated for a chain of rungs; the walk's independent oracle checks it one and two levels down, on every scan (R78). *Decide before:* §8 step 4.

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

**FS-Q9 · Are a block's own `var`s, instances it holds included, visible from outside?** (M2-5 members / M2-1 get/2 (fb_type.ex:21-24; F1-Q17, F2-Q7; X16))

- *(a) Hidden (the spike).* No path from outside goes deeper than one member; M2-1's `get/2` reaches at most `inst.tag.member`, so it owes no growth test in depth.
- *(b) Readable.* Internals become part of `get/2`'s contract; the compiler needs member lookup at any depth, and M2-1's `get/2` then owes the growth test in depth that S-synth §5 assigned (X16).

*Recommend (a).* IEC Ed 3's PRIVATE default and the conventional family's local tags; reversible; a debug read can be a separate API that is not logic. *Decide before:* §8 step 3.

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

**FS-Q14 · May one compile hold two versions of a block of one name?** (M2-5 library (F2-Q13; RF-4))

- *(a) No: one version per name across the types given, the types they hold, and tags declared from Elixir, two that differ only in their warnings being one (the spike, R16, R82, R83).* A host compiles each block against the same types; the runtime and the edit look types up by name.
- *(b) Yes.* Needs a type identity beyond the name in the runtime's lookups and the edit's plans.

*Recommend (a).* Names are the identity everywhere else in logex; a block's warnings, which carry the path it was compiled from, are no part of what runs. *Decide before:* §8 step 3.

**FS-Q15 · When a block's file has mistakes, is the file that names it compiled further?** (M2-5 loader (F2-Q14))

- *(a) Stop, and report the block's mistakes with its file (the spike).* The dependent file's own mistakes appear once the block compiles.
- *(b) Continue, the type marked broken.* Every mistake in every file at once, as the Milestone 2 done sentence's 'every mistake' may want; another marker type in Declarations.

*Recommend (a) for M2-5, revisited with M2-2's loader.* Simple, and precedented: a lex or parse error already stops a compile. *Decide before:* §8 step 5.

**FS-Q16 · The order of the milestone: M2-1 first, or M2-5?** **Cross-track**, one question with S-rev Q-22 (F1-Q14, F2-Q15; rf-F-fit-5, X5). *Decide before:* the first Milestone 2 commit.

- *(a) M2-1 first, then M2-5 before M2-2 (decision 1's default for M2-1; decision 1 lets M2-5 move).* PLAN's and org's M2-5 Done-when (PLAN:1345, org:1408) stays as written, `m1.s2.run` read through M2-1's `get/2` in M2-5's own test (X6); and T's reader, loader and walks are written against `cal` from their first commit (X1, X4).
- *(b) M2-5 first (F-synth's recommendation, inventory §11).* M2-5's Done-when is reworded (FS-Q1 (a)); the nested state and the edit's changes are settled while OE-1 is fresh.
- The code does not choose: S+F conflict in the same three files, one hunk each, in either order (X5's verdict). With this revision on S-synth's spike (one conflict, the alias line, resolved to the union): `mix compile --warnings-as-errors` exits 0, `mix test` gives `Result: 561 passed (7 doctests, 554 tests)` (S's additions to `api_contract_test.exs` and `end_to_end_test.exs` left out, where the two sides conflict), and `get/2` reads `m1.s2.run` as `{:ok, 1}`.

*Recommend (a)*, as S-rev Q-22 does: it keeps decided text unchanged, and this revision's gain from (b), settling `get/2`'s reach, needs no earlier landing, since S's `get/2` already reads the nested member. T is neutral. This reverses F-synth's recommendation.

**FS-Q17 · Is a block member's changed initial value an allowed edit?** (M2-5 online edit, decision 29 (F2-Q16))

- *(a) Yes: keep the running value, report `:initial_changed` by path (the spike).* Decision 29, applied by path.
- *(b) No: the initial value is part of the type.* Changing a member's default needs a restart.

*Recommend (a).* Consistent with decision 29 at the top level. *Decide before:* §8 step 4.

**FS-Q18 · How is `cal` represented in `@instructions`?** (M2-5 cal / CLAUDE.md step 2 (inventory Q5.9; F2-Q17))

- *(a) `"cal" => {:cal, :block}`, a marker meaning the signature is the block's (the spike).* Reserved and surveyed like any mnemonic; CLAUDE.md step 2 notes the exception (in the spike).
- *(b) A separate list of signature-less mnemonics.* `mnemonic?/1`, `reserved/1` and `naming_test` each read a second table.

*Recommend (a).* One source of truth for reserved mnemonics. *Decide before:* §8 step 3.

**FS-Q20 · Is a block's name matched exactly, or in any case?** (M2-5 names (F1-Q7))

- *(a) Exactly, like a tag (the spike).* `var s1 Seal` is an unknown type with '— did you mean `seal`? (type names are case-sensitive)'; on a case-insensitive file system the loader may still find `Seal.ld` (unverified).
- *(b) In any case, like `ton`.* Unlike tags; two blocks differing in case must then be refused; IEC's case rule for identifiers is unverified here.

*Recommend (a).* A block's name is a file name, and tags set the precedent. *Decide before:* §8 step 3.

**FS-Q21 · Must `function_block <name>` be literally line 1, or the first rung?** (M2-5, decision 4 (org:1461; F1-Q16; rf-F-fit-6))

- *(a) The first rung: comments and blank lines may come before it (the spike).* A file may start with a licence comment; decision 4's record is reworded; the `function_block` stanza and the README already say so in the spike.
- *(b) Literally line 1.* A file with a heading comment is refused; needs a check the lexer does not make today, and the stanza and the README go back to "first line".

*Recommend (a).* The lexer drops comments before the parser sees any line; nothing is lost. *Decide before:* §8 step 1, since `docs/naming.md` is append-only and its stanza must say the answer.

**FS-Q22 · How exactly must a type given in `types:` or to `Tag.new!/4` be what `Logex.compile/2` gives?** (M2-5 data path, decision 28 (org:775-779, org:1124-1126; F1-Q13; JF2 D2b; rf-F-fit-1, RF-6))

- *(a) Exactly: its members are `of/1` of its body, and its body's IR, turned back into the elements its text parses to, lowers through the compiler's own checks to itself, with its lines, presets, warnings and tag names what a compile gives (`Logex.Compiler.lowered?/1`; the revision, R85-R90).* One validator, applied to the IR; a hand-edited body is an `ArgumentError` where it is given, so the runtime and the edit never meet one. Each type is checked once per call, but every call checks every type at full depth: 2,486 reductions for a small block against 244 before, and a chain built one block at a time is quadratic (FS-Q28).
- *(b) Recompile `body.source` with the types the body holds and compare.* Exact for a type with source; a type from `instructionize/3` has none and must be refused or trusted; the lexer and parser run again for each type.
- *(c) A shape check alone (known symbols, operand kinds, declared names).* Totality without exactness: an `ote` on a var_input, which no text says, passes.
- *(d) F-synth's: members only.* Not total: a hand-edited rung passed and the runtime and the edit raised `FunctionClauseError`, `Protocol.UndefinedError` and `KeyError` (rf-F-fit-1). F-synth's claim that such a body "runs nothing and raises nothing" was false.

*Recommend (a).* It meets org:775-779 ("the data API refuses anything the text cannot say") and CLAUDE.md's "Nothing else may escape the public API" with no second validator. *Decide before:* §8 step 3.

**FS-Q23 · Should the three IR walks (compiler, Warnings, Edit) be merged into one module before M2-5?** (M2-5 / B5 (readiness §4.1; F1-Q15; X1))

- *(a) Land M2-5 as spiked: one `cal` signature clause each in Warnings and Edit.* Three walks remain.
- *(b) Extract first.* One walk, one signature function, one public write set; M2-5 waits for it.

*Recommend (a) for M2-5, (b) before any configuration check reads a program's writes or timers.* M2-5 does not need a public "which tags a program writes"; track T's checks do, from M2-2 on, and its own `writes/1` raises on `cal` (X1), so the walk lands in T's commit that X1 names, before its checks read it. Both tracks agree on the order (X19). *Decide before:* §8 step 2.

**FS-Q24 · Where do members declared from Elixir go in a block's positional `cal` order, given that a tag table keeps no list order?** (M2-5 data path (JF1 defect 4))

- *(a) First, by name, then the source's in line order (the spike).* `of/1` re-derives the order, so `user?/1` accepts the type; a host passing [b, a] gets `cal` formals a, b.
- *(b) First, in the order given (F1).* Needs the order kept outside the tag table, which `of/1` cannot then re-derive.
- *(c) Refuse a tag from Elixir in a block's compile.* The data API cannot build a block from Elixir, against org:775-779's one model.

*Recommend (a).* Deterministic, re-derivable, and it keeps one model for text and data. *Decide before:* §8 step 3.

**FS-Q25 · How do the new stanzas name the conventional family's user-defined instructions?** (docs/naming.md (JF1 F1 defect 5))

- *(a) 'user-defined instruction', and 'the family's manual for its user-defined instructions' (the spike).* Follows the design pass's naming rule; differs from naming.md:403,418,433, which spell out the family's own term.
- *(b) The family's own term, spelled out, as naming.md already does.* Consistent with the file; against the pass's rule for new text.

*Recommend (a).* New text should follow the rule; the older stanzas are append-only and stay. *Decide before:* §8 step 1.

**FS-Q26 · Does `compile_file/1` hand back the warnings of the blocks it loads?** (M2-5 loader / M1-5 warnings (rf-F-fit-4))

- *(a) No: a block's warnings stay in its type, `type.body.warnings`, each with its file (the spike; its doc now says so).* A host sees them by compiling the block's file, or by reading the type.
- *(b) Yes: the program's `warnings` gain each loaded block's, once per call, each stamped with its block's file.* M1-5's `warnings` is the host's one warning channel; under M2-2 a block several programs hold reports once per configuration only if the loader's memo is the configuration's (§5).

*Recommend (b) for `compile_file/1`, (a) for `compile/2`,* where the host compiled each block itself and holds its warnings. *Decide before:* the loader commit (§8 step 5).

**FS-Q27 · Is the scan right after a switch linear in the one-shots it blocks, or in the length of their names?** (org §4.9 cost, org:1160 (RF-5))

- *(a) In the length of the block list, its names' bytes (the revision; a growth test pins it).* A one-shot n levels down has a path of n names, so a chain with a one-shot at every level blocks n bits whose names total O(n²) bytes; the scan is quadratic in the depth, as the edit's reports already are. org:1160 is restated.
- *(b) In the one-shots: `Instance.ons_blocked` kept as a tree, as `Scan.ons_blocked` is.* New instance state shape, its host check (fix F8) and messages, the edit's and the reports' paths derived from it.

*Recommend (a).* At the conventional family's 16 levels a path is at most 16 names; (b) reshapes a host-visible field for a cost only absurd depths show. *Decide before:* the edit commit (§8 step 4).

**FS-Q28 · Does every compile check every type it is given at full depth?** (M2-5 data path, cost (RF-6))

- *(a) Yes (the spike).* Exact (FS-Q22 (a)); one compile given a type of depth d costs about d relowerings; building a chain of N blocks one at a time, by `compile/2` or `compile_file/1`, is O(N²): 680,019 reductions for 25 files, 138,358,875 for 400 (`p8.exs` on the spike).
- *(b) A type a compile has checked carries a mark the next compile trusts.* Linear builds; a mark copied onto an edited type passes, so (b) gives back part of FS-Q22's exactness unless the mark is bound to the content, which costs a hash of it.
- *(c) The loader alone skips checking the types it compiled in the same call.* `compile_file/1` becomes linear; a host's own chain stays quadratic; needs a path into the compiler no host may take.

*Recommend (a).* The cost is real only past the conventional family's 16 levels, and exactness is a decided rule. *Decide before:* §8 step 3.

**FS-Q29 · Who owns fix F15, a `file` on `%Logex.Program{}`?** **Cross-track**, one question with S-rev Q-38 (X18). *Decide before:* the first item that meets it.

- *(a) The first item that needs a file on a program or block: M2-5 under FS-Q16 (a).* Its R68 stamps a block file's diagnostics with that file in the `file` field; T's R51 names a type's file in a configuration diagnostic's message. Both conventions are stated together in the design record.
- *(b) M2-2, as S-synth and T-synth said.* M2-5 keeps its own convention until then, and a nested member's `:edit` refusal keeps citing the instance's line with no file.

*Recommend (a)*, as S-rev Q-38 does. Not built in this spike.

**FS-Q30 · How long does an edit's block on a one-shot inside a block last?** (M2-5 online edit, decision 21 (RF-1))

- *(a) Until a scan runs its `ons` (the revision, R78, R79).* A scan keeps the bits inside each instance whose body it did not run; a switch after such a scan lists them again where the program it starts has the `ons`. A new scan rule for `ons_blocked`, restated in its moduledocs and CLAUDE.md, and in org §4.9's "A scan empties the list" (§11, item 11).
- *(b) The next scan, as at the top level.* A frozen block uses its block up unseen, and the `ons` then compares a changed rung against the bit the old one wrote: the false pulse decision 21 prevents (RF-1's `p13.exs`). The `:ons_blocked` row and §4.9 say so, and the walk's oracle excuses frozen instances.

*Recommend (a).* Decision 21's purpose holds only if the block lasts until the `ons` runs. *Decide before:* §8 step 3 (the runtime half) and step 4 (the edit half).

**FS-Q31 · How is a block type a type holds stored once?** (M2-5 data shape (RF-2))

- *(a) A member holding an instance names its type, `{:block, name}`; the type is in the body's tag table, `FbType.type_of/2` giving it (the revision, R80).* `Tag.type` keeps CLAUDE.md's shape; a member's type gains a form.
- *(b) One table of types by name on the program (and on each type), every tag and member naming its type.* The finding's suggestion; `Tag.type` changes for every instance in every program, and every walk resolves names.

*Recommend (a).* It is linear (6 to 12 levels, 1.7x the words copied flat) and leaves the tag shape every module reads. *Decide before:* §8 step 3.

**FS-Q32 · One message for a block type given where a program goes.** **Cross-track**, one question with S-rev Q-39 (X13). *Decide before:* M2-5.

- *(a) F's R8 words at every entry point (`Runtime`, `Edit.accept/3`, `Configuration.check/1` and `new!/1`, `compile/3`, the loader), with S's prefix where a key and a name differ.*
- *(b) Each entry point its own words, as the three spikes have today:* F's R8, S's "is not a %Logex.Program{} from Logex.compile/2" with its cascade, T's generic programs-map message.

*Recommend (a)*, as S-rev Q-39 does: one mistake, one message.

### Kept as decided (rf-F-fit-7)

These were F-synth's FS-Q10 and FS-Q19. Each answers itself from a decided note and brings no
fact that would reopen it, so they are listed, not asked.

- **`first` inside a block is the program instance's** (PLAN:1351-1352): a block frozen on the
  first scan fires its one-shot the first time it runs (R41, the `cal` stanza). Research
  CNV-14 supports it.
- **A block's name is not reserved** (PLAN:732-734): `var seal seal` is legal, and with a
  library holding `seal`, a lone `var seal` reads "needs a tag name before the type `seal`"
  (inventory C30, which calls this consistent).
