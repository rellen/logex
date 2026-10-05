# rf-F-correct · refuting the M2-5 spike (F-synth) for correctness

Label rf-F-correct. Target: the F-synth spike (`scratchpad/m2/F-synth-work`, patch
`F-synth.patch` on `47319f7`), design `F-synth.md`. `/home/user/logex` was not modified
(`git -C /home/user/logex status --short` is empty). Work copy: `cp -a F-synth-work
rf-F-correct-work`, deleted when done; the probe scripts are kept in
`scratchpad/m2/rf-F-correct-probes/` (each runs as `mix run probe/<file>` from a fresh copy of
`F-synth-work` with the scripts in `probe/`). Toolchain: Elixir 1.20.4 / OTP 28
(`scratchpad/toolchain/env.sh`). The spike's suite passes on my copy:
`mix test --warnings-as-errors` exit 0, `Result: 489 passed (6 doctests, 483 tests)`.

Every finding below comes with the command I ran and what it printed. Severity is my reading.

---

## Findings

### RF-1 (high) · A one-shot blocked inside a block whose `cal` is false at the switch scan fires a false pulse later

**Claim.** A switch lists a nested bit (`x.e`) in `ons_blocked`, and the report says
`{:ons_blocked, "x.e", 0}`, which the Edit moduledoc's table defines as "its `ons` passes no
power at the next scan". But a scan empties the whole block list (`Runtime.run/3`), and if that
scan's `cal x` is de-energised the body never runs (decision 12). So the block is used up without
the `ons` ever seeing it. When the block next runs, the `ons` compares the rung it has *now* with
the bit the *old* rung wrote. That is exactly the false pulse decision 21 exists to prevent.

**Repro.** `probe/p13.exs`. v1 body `xio a ons e ote q`, v2 body `xic a ons e ote q`; program
`xic en cal x a q`. The steps: scan with a=1, en=1, so e=0; freeze with en=0; accept, then test;
scan with en still 0; scan with en=1, a unchanged.

```
frozen: x=%{"a" => 1, "e" => 0, "q" => 0}
test: [{:ons_blocked, "x.e", 0}] blocked=["x.e"]
switch scan (EN false): %{"q" => 0} blocked after=[]
next scan (EN true, a unchanged at 1): %{"q" => 1} x=%{"a" => 1, "e" => 1, "q" => 1}
candidate alone: %{"q" => 0} then after a freeze %{"q" => 0}
```

`a` never changed, and the candidate run alone never pulses, yet `q` pulses once. The seeded walk
in `api_contract_test.exs` checks only "passes no power **where it ran**" (F-synth §7.1), so it
leaves this case out by construction. F-synth decides the first-scan analogue (FS-Q10 (a),
"a block frozen on the first scan fires its one-shot the first time it runs") but never states
it for an edit. For an edit, decision 21 is the rule, and the report's own words promise more
than the code delivers.

**Suggested fix.** Keep a nested bit in the instance's block list until a scan in which its
instance's body actually runs. For example, `call/4` could carry forward the subtrees under each
`cal` that was de-energised. That changes `ons_blocked`'s scan rule, so per CLAUDE.md it needs its
rule restated and a pinned test. The alternative is to decide that a frozen block loses the block
like it loses the first scan. In that case the report kind's definition and §4.9 say so, and
the walk's oracle covers the frozen case.

### RF-2 (medium) · A program that holds nested blocks grows 2^depth when copied out of its process

**Claim.** `FbType.of/1` builds `members` from `body.tags`, so every nested `%FbType{}` is
referenced twice: `members[i].type` and `body.tags[name].type`. Inside one process the term is
shared and small. But any copy that does not keep sharing doubles at every level: a message to
another process, a GenServer call or reply, ETS, `:persistent_term`, `term_to_binary`,
`:erlang.phash2`, or a map key. F-synth's cost and growth receipts all run in one process.

**Repro.** `probe/p10.exs` (a chain `b0`…`bn`, each holding the one below, one program holding
`bn`), and `probe/p15.exs` for the hash:

```
depth 4: words shared=826 flat=6208 term_to_binary=27041B in 90us; send to a process 45us
depth 8: words shared=1402 flat=100528 term_to_binary=439121B in 923us; send to a process 338us
depth 12: words shared=1978 flat=1609648 term_to_binary=7032426B in 16826us; send to a process 8118us
depth 16: words shared=2554 flat=25755568 term_to_binary=112525326B in 279527us; send to a process 133401us
depth 18: words shared=2842 flat=103022512 term_to_binary=450102606B in 1171806us; send to a process 556999us
depth 20: words shared=3130 flat=412090288 term_to_binary=1800411726B in 8916563us; send to a process 10866277us
   phash2 at depth 16: 107755us; depth 20: 1752665us; depth 24: 29230460us
```

At depth 16, the conventional family's nesting limit that F-synth cites, sending one program to
another process copies 25.7M words (about 206 MB). A first attempt to measure `user?/1` from a
spawned process captured the type in the closure and did not finish in 600 s. M2-1's runtime is
plain data (S-synth PD-1), and an Elixir host will usually keep such data in a process.

**Suggested fix.** Store each nested type once. One way: a member or tag names its block type
and the program or type carries one table of types by name, which R16 already makes unique. Add
a growth test on `:erts_debug.flat_size/1` (or a send) at two depths.

### RF-3 (medium) · Reordering a block's inputs changes what reaches a nested `ons`, but the edit does not block it

**Claim.** R54/R55 and the Edit moduledoc say a nested `ons` is blocked where "a change to any of
them, a `cal`'s operands included" occurs along its chain. The chain is compared as stripped
rung *text*. R46 lets an edit reorder a block's members. When it reorders two inputs of one type,
`cal x i1 i2 q` keeps its text but now copies `i2` into `a`. The chain matches, so the switch
blocks nothing, and the `ons` reads a new source against a bit the old source wrote.

**Repro.** `probe/p5.exs`. v1 `var_input a bool`, `var_input b bool`; v2 the same two inputs
swapped; body `xic a ons e ote q` in both; program `cal x i1 i2 q`; i1=0, i2=1.

```
before: x=%{"a" => 0, "b" => 1, "e" => 0, "q" => 0}
forecast: []
test: [] blocked=[]
switch scan: out=%{"q" => 1} x=%{"a" => 1, "b" => 0, "e" => 1, "q" => 1}
candidate alone, steady: %{"q" => 0}
```

There is a top-level analogue in the same probe: changing the rung that *feeds* an unchanged
`ons` rung also pulses (`top-level analogue: test=[] switch scan out=%{"q" => 1}`), and decision
21 accepts that. But at the top level the feeding rung is a separate rung. Here the binding is
part of the `cal` element on the chain, the very part the moduledoc says blocks.

**Suggested fix.** Key the `cal` element of each chain rung by its operands *and* the formals they
fill (for example the signature's member names), so a reorder changes the key. Alternatively,
state in §4.9 that a reorder is outside decision 21, and test that.

### RF-4 (low) · One block, compiled from its file and from its text, counts as "two different function blocks"

**Claim.** R16 compares types with `==`. `compile_file/1` stamps `file:` on each warning of a
block's body (`Logex.in_file/2`) and `compile/2` does not, and two spellings of one path stamp
different strings. So the same block, if it has any warning, is refused as two versions with a
pinned `ArgumentError` whose advice ("compile each block against the same types") the host
already followed.

**Repro.** `probe/p7.exs` and `probe/p6.exs`:

```
no warning: equal=true warnings_file=[]
one warning: equal=false warnings_file=["/tmp/rffc7_1923/seal.ld"]
  same apart from warnings: true
  compile with [b] then instance tag a via Tag.new!: {:raised, ArgumentError, "types holds two different function blocks named `seal`, one inside another type given: compile each block against the same types"}
compile(prog, types: [seal from compile/2, wrap from compile_file]): {:raised, ArgumentError, "types holds two different function blocks named `seal`, …"}
compile(prog, types: [seal from compile_file abs, wrap from compile_file rel]): {:raised, ArgumentError, "types holds two different function blocks named `seal`, …"}
```

**Suggested fix.** Compare versions with warnings (and `file`) left out, or keep a block's
warnings out of the type's identity.

### RF-5 (low) · The switch scan grows quadratically in depth when every level holds a one-shot

**Claim.** F-synth §12 says that with path strings O(n²) in bytes, "reductions stay linear". Its
growth test puts an `ons` only at the deepest level. With an `ons` at every level the scan right
after a switch is quadratic, because `tree/1` splits each of the n blocked paths of length up to
n. `accept` is mildly superlinear.

**Repro.** `probe/p14.exs` (program's `cal` rung changed, so every nested bit is blocked):

```
ons at every level=true depth=50:  accept=56416 (1128/level)  blocked=51  switch scan=11845 (236/level)
ons at every level=true depth=100: accept=122578 (1225/level) blocked=101 switch scan=44204 (442/level)
ons at every level=true depth=200: accept=273291 (1366/level) blocked=201 switch scan=170770 (853/level)
ons at every level=true depth=400: accept=680884 (1702/level) blocked=401 switch scan=668733 (1671/level)
(ons at the deepest level only, depth 50→400: switch scan 11→8 per level, linear)
```

**Suggested fix.** Correct the §12 claim, or keep the block list as a tree in the instance (that
is new state, with its rules) and add the every-level shape to the growth test.

### RF-6 (low) · `compile_file/1` over a chain of block files is quadratic in the chain's length

**Claim.** Each file's compile re-validates the types it is given at full depth (`library!/1`
→ `FbType.user?/1`, plus `one_version!/2` and the recursion marks). Each compile is linear, as
F-synth measures, but loading a chain of N files costs O(N²), even though the loader built every
one of those types itself.

**Repro.** `probe/p8.exs`:

```
n=25  compile_file reductions=199665   per level=7986
n=50  compile_file reductions=589809   per level=11796
n=100 compile_file reductions=1959702  per level=19597
n=200 compile_file reductions=7028113  per level=35140
n=400 compile_file reductions=26538687 per level=66346
```

**Suggested fix.** Let the loader skip re-validating types it compiled in the same call (an
internal entry point), or memoise `user?/1` by type name within one compile. Otherwise record the
cost as accepted.

### RF-7 (low) · A program file with a bad name reports its blocks as unknown types

**Claim.** When the file name cannot name a program, `from_file/4` adds `mistakes(source)`, which
compiles with `types: []`. Every block beside the file is then reported as an unknown type, and
its uses as undeclared, though the block files exist.

**Repro.** `probe/p6.exs`, with `1plant.ld` holding `var s1 seal` and `seal.ld` beside it:

```
["…/1plant.ld: \"1plant\" cannot name a program: … (rename the file)",
 "…/1plant.ld: line 4: unknown type `seal`: logex has `bool`, `dint` and `ton`",
 "…/1plant.ld: line 5: `s1` is not declared"]
```

**Suggested fix.** Still load the dependencies under a refused name and compile with them, or
leave out the source's own mistakes about type words.

### RF-8 (low) · Wording: "types holds" with no `types:`, and "a inner"

**Claim.** (a) Two versions of one block reached only through tags declared from Elixir raise
"types holds two different function blocks named `a`…" when the call passed no `types`. (b) The
`:edit` message uses "a" before a block name: "is a inner in the running program and a other in
the candidate".

**Repro.** `probe/p11.exs`: `program: Elixir tags of c and a v2: {:raised, ArgumentError, "types
holds two different function blocks named `a`, one inside another type given: …"}`.
`probe/p12.exs`: ``line 4: `w.k` is a inner in the running program and a other in the
candidate: a member's type changes only with a restart``.

**Suggested fix.** Word the R16 message by where the versions came from. Write the type as
"of type `inner`" or quote it.

---

## What held (probed, no defect found)

- **`cal` with EN sequences, three levels deep** (`probe/p2.exs`): a false EN at any level freezes
  only that subtree. A frozen timer keeps `.en`/`last` and catches up (acc 10 → 100 after a 110
  ms gap, decision 8). The program's first scan blocks a nested `ons`. A top-level freeze while
  `go` rises gives one real pulse when the freeze lifts.
- **Operand checks** (`probe/p3.exs`, `p16.exs`): `move`/`eq`/`xic`/`ote` of a whole instance,
  hidden `s1.e`, deeper `s1.t1.dn`, writes to `s1.run` by `ote`/`ons`/`cal`, wrong types,
  literals that do not fit, arity, a second `cal`, `cal` in a branch, `cal` of nothing or of a
  member, and odd headers. Each is a located diagnostic. An instance in a `var_input` or
  `var_output` section, in a program or a block, is refused (`probe/p1.exs`).
- **Recursion** (`probe/p11.exs`): in-file, through a type given at depth (a → c → b → a, with
  the chain named), through an Elixir tag (the pinned `ArgumentError`), and a block given an
  older version of itself. Uses of a refused declaration are excused.
- **Edits** (`probe/p4.exs`, `p12.exs`): a nested member added, a preset changed, a rung changed
  two levels down, a round trip, a nested instance added and then cancelled, a member's kind
  change two deep, and a nested instance retyped, from source and from Elixir tags. Reports and
  state are as F-synth's §2 says.
- **The loader** (`probe/p6.exs`): a lex-broken block, invalid UTF-8, an empty file (reported as
  a program), a header-only block, a directory named `x.ld`, a symlink loop, a symlink naming a
  block of another name, and a block holding itself in its own file. All are diagnostics carrying
  the right file; nothing escapes.
- **Escapes** (`probe/fuzz.exs`, seeds 1-3 × 300 walks × 60 steps over 100 programs built from
  5 leaf, 4 mid and 5 program versions: scans with random inputs and time, restarts, plain swaps,
  and accept/test/untest/assemble/cancel at random stages): `escapes: 0` on each seed.
