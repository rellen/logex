# rf-F-fit · refutation of F-synth (M2-5), lens: fit

Label rf-F-fit. Written 2026-10-02 against `/home/user/logex` at `47319f7`, which this pass
did not modify. Every probe ran in `scratchpad/m2/rf-F-fit-work`, a `cp -a` of
`F-synth-work`, with Elixir 1.20.4 / OTP 28 (`scratchpad/toolchain/env.sh`). The spike's
suite passes there unchanged: `mix test --warnings-as-errors` exits 0 with
`Result: 489 passed (6 doctests, 483 tests)`. One probe (F5) ran in
`scratchpad/m2/rf-F-fit-merge`, the same copy committed, with the `lib/` part of
`S-synth.patch` applied by `git apply --3way --include='lib/*'`. That apply gave one conflict,
the `alias` line of `lib/logex/runtime.ex`, which I resolved to the union of the two lines. Both
copies are deleted. The probe scripts and their logs are kept in `scratchpad/m2/rf-F-fit-probe/`.
To run one again: `cp -a F-synth-work X && cd X && source …/env.sh && mix run
../rf-F-fit-probe/pN.exs`.

Citations: `org` is `docs/organisation.md` and `PLAN` is `PLAN.md`, each by line at `47319f7`.
`FS-Qn` and `Rn` refer to F-synth.md.

## What fits (checked, no finding)

- **Reserved words (org §4.8).** `cal` is refused as a tag name in a program, in any case
  (`var_input cal bool` and `var_input CAL bool` give "`cal` is an instruction and cannot name
  a tag"). In a block's file, `function_block` is refused as a tag name in any case. A
  program keeps a tag named `function_block` or `Function_Block`, and it compiles with no
  warning. A block cannot be named `ton`, `Ton` or `cal`. Probe `p2.exs`, log `p2.log`.
- **Decision 24 / R18.** `var s1 seal 1` and `Tag.new!("s1", seal, :var, 1)` give the same
  message: "`s1` is a seal: an instance takes no initial value, and its members start where
  its type says" (`p8.exs`).
- **Fix F7 through `cal`.** Take a running program whose `cal` writes the storage bit `e` and
  a candidate that keeps the identical `ons e` rung but drops the `cal`. Accept forecasts
  `[{:ons_blocked, "e", 1}]`, the same as the `otu` control (`p7.exs`).
- **The naming stanzas.** The rule-1 basis on Ed 2/3 IL, the two meanings of rung power,
  EN/ENO as Ed 2 Table C.2 keywords, Ed 3's "Implementer specific" (research IEC-9, IEC-10,
  IEC-17) and Table 52 feature 19 all agree with `docs/instruction-sets.md` §4.1 and
  research.md. Neither F-synth.md nor F-synth.patch names the conventional vendor or its
  products. A grep of both for the vendor's names and its own term for a user-defined
  instruction finds nothing.
- **PLAN M2-5's M1-6 notes** are each answered (F-synth §2 table). Decisions 8, 12, 20, 21,
  26 and 29, applied by path, have rules and reverts.

## Findings

### F1 (high) · `types:` accepts a type whose body was edited by hand, and the public API then raises. FS-Q22 says it does not.

F-synth's FS-Q22 (a) and §12 say a hand-edited body rung "passes, runs nothing and raises
nothing (H6, H7)". `FbType.user?/1`'s doc says it holds for "a user function block type
`Logex.compile/2` could have given". `user?/1` never looks at `body.rungs`, though. Each
shape below is `seal` from `Logex.compile/2`, with `body.rungs` replaced, passed as
`types:` to compile `var s1 seal / cal s1 a b q`. In every case `user?/1` is `true` and the
compile returns `{:ok, %Program{}}`. Then (`p1.exs`, `p1.log`; `p5.exs`, `p6.exs`):

```
== unknown mnemonic: user? true
  ESCAPED FunctionClauseError: no function clause matching in Logex.Runtime.evaluate/3
== not a list: user? true
  ESCAPED Protocol.UndefinedError: protocol Enumerable not implemented for Atom …
== string rung: user? true
  ESCAPED FunctionClauseError: no function clause matching in Logex.Runtime.rung/3
== move to member: user? true
  outputs: %{"q" => %{"x" => 5}}          # a bool var_output handed to the host as a map
unknown mnemonic: ESCAPED from Edit: KeyError        # Logex.Edit.accept/3
not a list: ESCAPED from Edit: Protocol.UndefinedError
string rung: ESCAPED from Edit: FunctionClauseError
```

**Against which rules.**
- CLAUDE.md: "Nothing else may escape the public API".
- Decision 28. The maintainer chose the full entry check over the recommended narrow one.
- org §4.9's data path (org:775-779): "the data API refuses anything the text cannot say".

`types:` is a new data-path input to `Logex.compile/2`. As spiked, it turns an unchecked
`%Program{}` into one that `Logex.compile/2` gave, which the runtime then trusts. JF2 listed
this as defect D2b, one the synthesis "must fix". The synthesis fixed only the `cal zz`
shape (R45, R65). §11 does not list it as a departure.

**Fix.**
- Correct FS-Q22's description of (a), and `user?/1`'s doc.
- Either recommend (b), recompiling `body.source` and comparing (exact, linear, and JF2's own
  suggestion), or add a well-formedness check of the body's IR beside `Parser.well_formed!/1`.
  Today (c) is called "a second validator", but the IR shape is exactly what
  `instructionize/2` emits.
- List the gap in §11 until it is closed.
- Add a test that each shape above is an `ArgumentError` at compile.

### F2 (medium) · FS-Q2 leaves out the migration org:866-867 describes: a member whose type changes is initialised, not refused

org:866-867 gives M2-5 "the nested migration: copy the members that match by name and type,
as CODESYS does, and initialise the rest". R47 refuses an edit in which a member's type
changes. `p4.exs` changes a block's local `var n` from dint to bool:

```
accept, a local member dint -> bool: {:error, [%Logex.Diagnostic{stage: :edit, line: 3,
  message: "`c1.n` is a dint in the running program and a bool in the candidate: a member's
  type changes only with a restart", …}]}
```

org itself pulls both ways:
- its §4.9 table row says "A tag's or member's type | refused";
- org:866-867 says initialise.

None of FS-Q2's options (a) to (c) asks which one M2-5 takes. FS-Q2 (c) is offered "as
org:866 assigns", but it is not org:866's rule for this case.

The same lift also changes org:945-948, "Every tag both programs declare whose type differs
is refused: any `Tag.type` inequality … or one function block schema and another". R46 makes
that untrue for a user block. §9 lists only "the members' refusal (org:866) lifted".

**Fix.**
- Add an FS-Q2 option or a sub-question: "a member whose type changes: refuse (R47, the §4.9
  table) or start it at its initial value and report `:added` (org:866-867, CODESYS)".
- List org:945-948 in §9's commit-4 row.

### F3 (medium) · FS-Q4 drops F1-Q12's option (b), the one that avoids the pinned `Scan` change

F1-Q12 (F1.md:861-871) offered "(b) The IR carries the block type (a fourth tuple element,
or a fourth operand kind)". FS-Q4 replaces it with two options that do not carry the type in
the IR:
- "(b) Expand each `cal` at compile time into the body", whose cost is quadratic;
- "(c) A private frame struct".

It then calls (a) "the smallest departure".

In the spike, `scan.tags` is read only to find a `cal`'s instance type (`runtime.ex`,
`evaluate({:cal, …})` and `called/5`; `scan.ex` moduledoc: "so that `cal` finds the type of
the instance it runs"). A `cal` whose IR carries its type would need no new `Scan` key, no
new host check (R43) and no change to the pinned surface test (`runtime_test.exs:702`). The
CLAUDE.md departure would shrink to the `ons_blocked` narrowing alone, which (a) needs too.
The cost is the IR-shape rule in CLAUDE.md, and every IR walk.

**Fix.** Restore F1-Q12 (b) as an FS-Q4 option with its real costs, and say why (a) still
wins if it does.

### F4 (low) · A block's warnings never reach the host that compiled it through `compile_file/1`, and no question asks about it

`p3.exs` has `seal.ld` with an unused `var`, an unused `var_output` and a second `ote`. It
compiles `plant.ld`, which holds `var s1 seal`, with `Logex.compile_file/1` (`p3.log`):

```
seal.ld alone, warnings: …seal.ld: line 5: warning: `spare` is declared but no rung uses it | …line 6 … | …line 9 …
plant.ld warnings: []
plant's seal type body warnings: (the same three, stamped with seal.ld)
```

The call that read and compiled `seal.ld` returns `warnings: []`. §12 records this as a risk
("A block's warnings live inside its type"), but no FS-Q asks the maintainer about it. M1-5's
decided `warnings:` field is the host's only channel for warnings. The loader's own memo
already knows every file it compiled.

**Fix.** Add a question: surface the loaded blocks' warnings (each stamped with its file) in
the program's `warnings:`, or keep them inside the type. Decide it before §8 step 5.

### F5 (low) · FS-Q16 and S-synth's Q-22 are one decision with opposite recommendations. Merged, they show both orders work.

- FS-Q16 recommends "(a) M2-5 first".
- S-synth Q-22 (S-synth.md:1061-1069) recommends "(a) M2-1 first". Its premise that
  `m1.s2.run` reads through `get/2` is marked "unverified until a nested user block exists".

With the two `lib/` patches merged (one alias-line conflict), `p9.exs` (`p9.log`) runs a
one-instance configuration holding `var s2 seal`:

```
get m1.s2.run before: 0
get m1.s2.run after pb: 1
get m1.s2.inner: ArgumentError: `m1.s2.inner` is not a member of `m1.s2`, a seal: its members are `start`, `stop` and `run`
get m1.s2.start: 1
get m1.s2: ArgumentError: `m1.s2` is a seal: an access path names one of its members, as in `m1.s2.run`
```

So S-synth's `get/2` reads PLAN M2-5's Done-when path as written, over F-synth's
`public/1`. FS-Q1's rewording is needed only under FS-Q16 (a).

**Fix.**
- Present FS-Q16 and S Q-22 to the maintainer as one question, citing this receipt.
- Under (b), FS-Q1 becomes a no-op.

### F6 (low) · The append-only `function_block` stanza, and the README bullet, say "first line", but the spike takes the first rung (R75, FS-Q21)

The stanza (spike `docs/naming.md`) says "recognised in any case on any file's first line
only". The README bullet says "a file whose first line is `function_block seal`". `p2.exs`:

```
block header after comment: ok FbType x
```

The source is `// licence` and a blank line, then `function_block x`. naming.md is
append-only, so a wrong sentence there stays.

CLAUDE.md's Conventions line "a function block type word a key of
`Logex.FbType.builtins/0`; either is reserved in any case and owes a `docs/naming.md`
stanza" is also left unchanged. A user block's type word is neither a key of `builtins/0`
nor reserved, and `function_block` is a third kind of word (`Declarations.kinds/0`). §9
does not list either line.

**Fix.**
- Word the stanza and the README by the outcome of FS-Q21, before commit 1.
- Add the CLAUDE.md line to §9's commit-3 row.

### F7 (low) · FS-Q10 and FS-Q19 are already decided, and nothing new is offered against them

- FS-Q10 answers itself "Decided" (PLAN:1351-1352) and brings no new evidence.
- FS-Q19 answers itself "Decided" (PLAN:732-734).

FS-Q7 also restates a decision, but it brings new IEC evidence (research IEC-11), so it is a
real question. The two decided items swell the list to 25 and hide the questions that really
need the maintainer.

**Fix.** Move FS-Q10 and FS-Q19 to a "kept as decided" list (F-synth §2's PLAN-notes table
already does this), or say what new fact would reopen each.

## Questions §13: real, framed, complete?

- **Real and correctly framed:** FS-Q1, Q3, Q5, Q6, Q7, Q8, Q9, Q11, Q12, Q13, Q14, Q15, Q17,
  Q18, Q20, Q21, Q23, Q24, Q25.
- **Misframed:**
  - FS-Q22: option (a)'s "raises nothing" is false (F1).
  - FS-Q4: it misses an option (F3).
  - FS-Q2: it misses org:866's "initialise the rest" (F2).
  - FS-Q16: it duplicates S-synth Q-22, with the opposite recommendation (F5).
- **Not questions:** FS-Q10 and FS-Q19 (F7).
- **Missing:** the visibility of block warnings (F4), and the type-changed member (F2).
