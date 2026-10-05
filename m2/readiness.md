# Milestone 2 readiness: what M2 touches at 47319f7, and what should change first

Label: inv-readiness. Read at `main`, HEAD `47319f7` (2026-10-01), on Elixir 1.20.4 / OTP 28
(the scratchpad toolchain). Every claim about the repository cites `file:line` at that
commit, or a document section. Measurements were taken in a copy,
`m2/inv-readiness-work`; its probes and one spike are in `m2/inv-readiness.patch`
(section 10). `/home/user/logex` was not modified.

Words used here: *scan* is one execution of one instance, *cycle* one step of the
resource (`docs/organisation.md` §4.6). "Measured" means a probe printed it; "inferred"
means I read it from the code and did not run it; "unverified" means I could not check it.

---

## 0. What should change first

Ordered by when it bites. Each has a recommendation and the option against it; section 9
restates the open ones as questions for the maintainer.

| # | Change | Needed by | Why now | Recommendation |
|---|---|---|---|---|
| 1 | Decide what `%Logex.Configuration{}` holds in M2-1, before any syntax: globals and connections, or only instances and tasks | M2-1 | M2-1's Done-when has copy-in/copy-out and "the README program gives identical outputs through `scan/2` and through a one-instance configuration" (PLAN.md M2-1); copy-in needs a source, and M2-2's checks then judge that data. §4.9 asks for "one checked constructor, which M2-2's parser feeds" | Globals and connections are in M2-1's data from the start, keyed by name; M2-2 adds only text |
| 2 | A scan stops walking the whole tag table to find the var_outputs | M2-1 (cost), not correctness | `Runtime.outputs/2` (`lib/logex/runtime.ex:154-160`) runs a comprehension over every tag on every scan: about 10 reductions per declared tag, outputs or not (measured, 1.7). A scheduler pays it per instance per cycle | Optional before M2-1. If taken: a list of var_output names computed once by the compiler. The spike (1.7) takes the README motor's `call/4` from 277 to 233 reductions and a one-output program with 10,000 vars from 100,138 to 87. Pin it with a growth test in reductions |
| 3 | One IR walk instead of three, with a signature per instruction | M2-4 (which tags a program writes), M2-5 (`cal`) | The same walk is written twice (`lib/logex/compiler.ex:243-252`, `lib/logex/warnings.ex:45-54`) and a third time with the write count (`lib/logex/edit.ex:489-518`); two of them look a signature up by IR symbol in the static table (`lib/logex/warnings.ex:21,61`, `lib/logex/edit.ex:490,510`). A lowered `cal` raises `KeyError` in both (measured, 4.1) | Extract before M2-4/M2-5, as the rest of PLAN.md B5 ("`Ast`, `Instruction`, `Analyzer`"). Not needed for M2-1 to M2-3 |
| 4 | Where a program's file lives (fix F15) | M2-2, M2-4, OE-2 | `%Logex.Program{}` has no file (`lib/logex/program.ex:16`); `compile_file/1` puts the path only on diagnostics and warnings (`lib/logex.ex:110-114`). A configuration diagnostic that cites a `.ld` declaration (a `var_external` of the wrong type, M2-4) cannot name that file; an `:edit` diagnostic has none either (measured, 2.3) | A `file` field on `%Logex.Program{}`, set by `compile_file/1`, nil from `compile/2`. Alternative: the loader's own map from type name to path |
| 5 | Reserved words by file kind | M2-2 onward | `Logex.Declarations.reserved/1` is one global function (`lib/logex/declarations.ex:40-51`), used by every name check. `.lcf` words must not be reserved in `.ld` (§4.8) and are not today (measured: `var_input task bool`, `var_input program bool`, `var_output at bool` compile, `probe/m2_words.exs`) | A second word table for `.lcf`, and a kind argument where a check differs; keep `reserved/1` as the `.ld` one |
| 6 | The compile API takes function block types | M2-5 | `Logex.compile/2` accepts `name:` and nothing else, and a test pins the message (`lib/logex.ex:59-71`; `test/logex_test.exs:134-138`). `Declarations.check/1` accepts only a built-in type (`lib/logex/declarations.ex:349-364`), so a user type cannot be declared from text or from Elixir (measured, 2.4 and 3.2) | A `types:` option, a map of compiled types by name, mirroring `Configuration.compile(name, source, %{"motor" => program})` (§4.4 "Loading"); `compile_file/1` resolves `seal` to `seal.ld` beside it |
| 7 | How a `cal` reaches its block's body at evaluation | M2-5 | `evaluate/3` sees only the instruction, `{power, env}` and the `%Logex.Scan{}` (`lib/logex/runtime.ex:380-383`; CLAUDE.md conventions). Nothing there holds a block's rungs | Section 1.5 gives three options; recommend the scan carry the program's block types, filled by the runtime as `ons_blocked` is |
| 8 | What `Logex.Edit` does with a user block | M2-5, OE-2 | `retyped/2` compares types with `!=` (`lib/logex/edit.ex:357-365`), so a block body inside the type makes every body edit a refused "type change"; the timer rules see top-level tags only (`lib/logex/edit.ex:407,630-654`) | Decide in M2-5's design: refuse any change to a block type until OE-2's nested migration, and say so in §4.9, or compare schemas only and block every `ons` in a changed body |

Not first, but owed by the item that adds it: per-kind messages that still say `ton`
(section 3.2), the public-surface test (`test/logex/runtime_test.exs:688-735`), the
naming survey's new sources (section 7), and the documents (section 8).

---

## 1. `Logex.Runtime`

### 1.1 `call/4`'s contract

`call(program, state, inputs, scan)` (`lib/logex/runtime.ex:69-74`): checks the program,
the state, the scan, then the inputs, merges the inputs into the instance and runs every
rung. It returns `{outputs, state}`.

**Checks, in order, and their messages** (each a raise of `ArgumentError`):

| Order | Check | Clause | Message |
|---|---|---|---|
| 1 | program is `%Program{}` with a map of tags and a list of rungs | `runtime.ex:163-170` | `expected a %Logex.Program{} from Logex.compile/2, got: …` |
| 2a | `state.type` a binary or nil | `runtime.ex:172-173` | `state.type must be a program name, got: …` |
| 2b | `state.env` a map, not a struct | `runtime.ex:175-177` | `state.env must be a map of tag names to values, got: …` |
| 2c | `state.now` a non-negative integer | `runtime.ex:179-180` | `state.now must be a non-negative integer of milliseconds, got: …` |
| 2d | `state.first` a boolean | `runtime.ex:182-183` | `state.first must be true or false, got: …` |
| 2e | `state.switched` a boolean | `runtime.ex:185-186` | `state.switched must be true or false, got: …` |
| 2f | `state.ons_blocked` a proper list of binaries (fix F8) | `runtime.ex:188-211` | `state.ons_blocked must be a list of storage bit names, got: …` |
| 2g | the state's owner: `state.type == program.name` | `runtime.ex:213-219` | ``this state is an instance of `x`, not of `y` `` (nil is "an unnamed program") |
| 2h | anything else | `runtime.ex:191-196` | `expected a %Logex.Instance{} from Logex.Runtime.instance/1, got: …` |
| 3a | `scan.now` a non-negative integer | `runtime.ex:221-222` | `scan.now must be …` |
| 3b | `scan.first` a boolean | `runtime.ex:224-225` | `scan.first must be true or false, got: …` |
| 3c | `scan.ons_blocked` left `[]` by the host | `runtime.ex:227-233` | `scan.ons_blocked is the runtime's, taken from the instance: a host leaves it out, got: …` |
| 3d | time never goes backwards | `runtime.ex:235-241` | `time went backwards: this scan is at N ms, but the instance was last scanned at M ms` |
| 3e | `scan.first` agrees with `state.first` | `runtime.ex:243-257` | two messages, one per direction |
| 3f | anything else | `runtime.ex:259-260` | `expected a %Logex.Scan{}, got: …` |
| 4 | `inputs` a map, not a struct | `runtime.ex:278-284` | ``inputs must be a map of var_input names to values, as in %{"start" => 1}, got: …`` |
| 5 | each key, in key order, all problems in one raise, a line each | `runtime.ex:269-357` | a non-binary key; a declared tag that is not a var_input (`… is a var_output (declared on line 5), not a var_input …`); a key reaching into an instance (`names a member of` / `reaches into`, `runtime.ex:314-317`); an undeclared key with a did-you-mean or the list of var_inputs (`runtime.ex:319-334`); a value that does not fit (`runtime.ex:336-347`) |

**Inputs.** Keys are var_input names as strings; values fit their type exactly (bool 0 or
1, dint an integer of 32 bits). They *merge* into `state.env` and stay there
(`runtime.ex:286`), so a host sends only what changed.

**Outputs.** Every var_output, by name, its value from the env after the scan, 0 where a
hand-built env lacks it (`runtime.ex:153-160`). Nothing else: no var, no member, no
`var_external` (none exists yet).

**The scan itself.** `run/3` (`runtime.ex:141-151`) makes the instance's block list a
map once (`Map.from_keys/2`), folds every rung, and returns the state with `now` set,
`first: false`, `ons_blocked: []` and `switched: false`.

### 1.2 `instance/1`, `put_inputs/3`, `scan/2,3`, `restart/3`

- `instance/1` (`runtime.ex:60-63`): checks the program, then
  `%Instance{type: program.name, env: Program.initial_env(program), now: 0, first: true}`,
  `ons_blocked: []` and `switched: false` by default (`lib/logex/instance.ex:28`). This is
  the one constructor M2-1's `start/1` must call (§4.9, fix F14; PLAN.md M2-1). It does not
  require a name: an unnamed program gives `type: nil`.
- `put_inputs/3` (`runtime.ex:80-83`): checks program and state, merges inputs as `call/4`
  does. `Logex.Edit` uses it with `%{}` as its state check (`lib/logex/edit.ex:343`).
- `scan/2,3` (`runtime.ex:89-93`): `call/4` with no inputs at
  `state.now + elapsed_ms` and `first: state.first`. It checks program and state twice
  (once itself, once through `call/4`): 289 reductions against 277 for `call/4` (1.7).
  `elapsed_ms` must be a non-negative integer (`runtime.ex:262-265`).
- `restart/3` (`runtime.ex:106-117`): `:cold | :warm` (`:warm` equals `:cold` until
  `retain`, `runtime.ex:131-134`); every tag back to its initial value except the
  var_inputs whose values fit their types (`runtime.ex:121-129`); `first: true`,
  `ons_blocked: []`; `now` and `switched` kept.

### 1.3 The two structs

- `%Logex.Instance{type, env, now, first, ons_blocked: [], switched: false}`
  (`lib/logex/instance.ex:28`). `env` is flat by tag name, with each function block
  instance a nested map of its members (`instance.ex:7-9`). Each field has a rule for a
  scan, a restart and a switch (CLAUDE.md "New state in an instance").
- `%Logex.Scan{now, first, ons_blocked: []}` (`lib/logex/scan.ex:19`). The host builds
  `now` and `first`; the runtime alone fills `ons_blocked`, as a map, for one scan.
- `runtime_test.exs:699-704` pins both key sets exactly. Any field M2 adds changes that
  test.

### 1.4 Members: `read/2`, `write/3`, and how a member write is checked

- `read/2` (`runtime.ex:539-545`) takes `{:int_lit, …}`, `{:name, …}` or
  `{:member, _, path}`; a member walks its path at any depth, and a missing key or a
  non-map on the way reads 0.
- `write/3` (`runtime.ex:549-558`) puts a value at a path of any depth, rebuilding a
  non-map on the way as a map.
- So the runtime already reads and writes `s1.t1.acc`; only the compiler stops at one
  level (3.1).
- **A member write is checked at compile time only.** `check_member_write`
  (`lib/logex/compiler.ex:688-704`) refuses a write slot on a member whose `write` is
  false, naming `FbType.writable/1`'s list (`lib/logex/fb_type.ex:100`). The runtime does
  not check. A host cannot write any member: `put_inputs/3` and `call/4` refuse a key that
  reaches into an instance (`runtime.ex:310-317`). An instance is named whole only in an
  `{:instance, type}` slot whose type matches (`compiler.ex:570-571`).

### 1.5 Re-entering the evaluator for a user block's body

B5 made `rung/3`, `series/3`, `element/3` and every `evaluate/3` clause private
(`runtime.ex:358-378`); `runtime_test.exs:689-694` pins the public surface. A `cal`
clause in the same module can call `rung/3` over the block's rungs with the instance's map
as the env, so **no public re-entry is needed**. What is missing is the block's body at
that point. Options:

- **A. The scan carries the program's block types.** The runtime fills a field such as
  `scan.blocks`, a map from type name to `%Logex.FbType{}` with its lowered rungs, as it
  fills `ons_blocked`; the lowered `cal` keeps the shape `{:cal, line, operands}` and its
  type is found from that map. Cost: a `%Scan{}` field (pinned by
  `runtime_test.exs:704`), and the type name must reach the clause (in the `{:instance,
  type}` slot's lowering, or by a second lookup).
- **B. The lowered instruction carries the type.** A fourth operand kind, or a fourth
  tuple element. Cost: CLAUDE.md fixes an instruction as `{symbol, line, operands}` and
  operands as three shapes, and "anything that walks IR operands must handle it": three
  walks today (0, item 3), and the printer-free IR tests.
- **C. The evaluator threads a context with the program.** `evaluate/3`'s third argument
  becomes something other than the scan. Cost: CLAUDE.md's `evaluate/3` convention
  changes for every clause.

*Recommend A*, inferred, not spiked. Two more points M2-5 must settle with it:

- **One-shots in a body.** `blocked?/2` looks a bare bit name up
  (`runtime.ex:479-484`), whose comment leaves the naming to M2-5. Inside a body the env
  is the instance's map, so a body's `ons s` and the program's `ons s` share the key `"s"`:
  a switch that blocks the program's `s` would also block every block's `s` for that scan
  (inferred). Since no edit blocks a body's `ons` until a block's migration exists, a body
  could run with an empty block map; or the map is keyed by path, which needs a path
  prefix in the scan and breaks CLAUDE.md's "the same for every instruction of one call".
- **`first`.** Decided as the program instance's (PLAN.md M2-5 note), so a block frozen on
  the first scan runs its `ons` unblocked the first time it runs.

### 1.6 What a scheduler needs, and whether `call/4` serves as it is

**For M2-1 to M2-3 and M2-6, yes, as it is** (inferred from 1.1, and the moduledoc says so,
`runtime.ex:7-8`). Per due instance, a cycle builds the copy-in map from the connected
globals and constants, builds `%Scan{now: rt.now, first: state.first}` (the instance's own
`first`, or check 3e raises), calls `call/4`, and copies the connected var_outputs out.
`call/4` is pure, so a cycle is too.

What it costs to use as it is (measured, 1.7): every call re-checks program and state (34
reductions of 277) and each input (about 19 reductions per input). A configuration has
checked its connections once at construction, so this is redundant work, about 12% plus
the copy-in. Not worth a second, unchecked entry point.

What has to change, and when:

1. **M2-1, optional:** the per-scan walk of every tag (item 2 of section 0).
2. **M2-1, required:** `Runtime.start/1`, `cycle/3`, `next_due_in/1`, `get/2` and a
   `%Logex.Runtime{}` struct. `defstruct` in `Logex.Runtime` adds `__struct__/0,1` to the
   surface `runtime_test.exs:693-694` pins as exactly six functions. `get/2` can reuse the
   private `read/2` walk; it must refuse an internal member (`FbType.public/1`,
   `fb_type.ex:96`). Whether it reads a plain `var` (`m1.fault`) is open (section 9).
3. **M2-4, required:** `var_external`. §4.4 says an instance "reads and writes the global
   directly" during a scan. `call/4` refuses every key that is not a var_input
   (`runtime.ex:305-308`) and returns only var_outputs (`runtime.ex:154-160`). Options:
   a second argument to the scan for the globals, merged before the rungs and split off
   after; or the global kept in the instance's env under its name, synced by `cycle/3`.
   The second puts a copy of the global in every instance between scans, against §4.9's
   "one copy of each global's value"; the first keeps one copy (inferred).
4. **M2-5, required:** a `cal` clause pair and the body (1.5).
5. **M2-6:** nothing in `call/4`; the trigger's last value is per task, held in
   `%Logex.Runtime{}`, and is §4.9's listed exception.

### 1.7 Baseline cost, and the spike

Measured on 1.20.4 / OTP 28 in the copy, `probe/call_cost2.exs`: every measured call is
in a compiled module, 50 warm-up calls, the least of 200 counts of
`Process.info(self(), :reductions)`, less the 5 reductions the counting itself costs.
Three runs gave the same figures, to within 2 reductions on the largest.

**At HEAD:**

| README motor (8 tags: 4 var_input, 3 var_output, 1 var; 5 rungs) | Reductions |
|---|---|
| `call/4`, no inputs | **277** |
| `call/4`, 1 input | 296 |
| `call/4`, all 4 inputs (a configuration's copy-in) | 354 |
| `scan/3`, 10 ms | 289 |
| `put_inputs/3`, no inputs (the program and state checks alone) | 34 |
| `put_inputs/3`, 4 inputs | 110 |
| `instance/1` | 81 |
| `restart/3` | 187 |
| `Logex.compile/2` | 7,107 |

| Shape, `call/4` with no inputs | Reductions |
|---|---|
| N motors in one program (8N tags, 5N rungs): N = 1, 10, 100 | 274, 2,540, 25,031 |
| one rung, one var_output, N plain vars: N = 10, 100, 1,000, 10,000 | 162, 1,112, 10,112, 100,138 |
| N instances of the motor, one `call/4` each with 1 input (a cycle by hand): N = 1, 10, 100 | 314, 3,050, 30,812 |

The second table's middle row is the finding: a scan of one rung costs about 10
reductions for every declared tag. The comprehension in `outputs/2` alone, over 10,000
tags, costs 100,045 (`probe/m2_words.exs`), which is all of it. Wall time for one motor
`call/4` read 3.2 to 4.9 µs, mean of 100,000, across runs; that figure is noisy and is
unverified as a stable number.

**Spike (in the patch):** the compiler lists the var_output names once, in a new
`outputs` field of `%Logex.Program{}`, and `outputs/2` reads that list, walking the tags
only for a hand-built program whose field is nil. The motor's `call/4` falls to **233**
(−16%), the one-rung program to **87** at every N from 10 to 10,000, and N motors in one
program to 18,217 at N = 100. The gate passed on the spike: format, both compiles with
`--warnings-as-errors`, and `mix test --warnings-as-errors`, 430 tests (6 doctests), exit
0. No test fails when the spike is reverted, so landing it owes a growth test in
reductions ("a scan's cost does not grow with tags no rung writes"), which the two rows
above separate by three orders of magnitude. It is a public struct change: `program.ex`,
the CLAUDE.md Key Files line, and every hand-built `%Logex.Program{}` in the tests
(`test/logex/evaluation_test.exs:42,92,125`) keep working through the nil clause.

---

## 2. `Logex.Program`, `Logex.compile/2`, `compile_file/1`

### 2.1 The struct

`%Logex.Program{rungs, tags, name: nil, source: nil, warnings: []}`
(`lib/logex/program.ex:16`). `initial_env/1` (`program.ex:44-55`) is the one rule for
new state, whose doc lists the edit's exceptions and names M2-1's `start/1` and M2-6's
trigger (`program.ex:26-43`).

### 2.2 How a name is derived

- `compile(source, name: name)`: the name must be a string shaped like a name
  (`lib/logex.ex:59-74`, `Declarations.name?/1` at `lib/logex/declarations.ex:57`). No
  other option is accepted, and the message is pinned (`test/logex_test.exs:134-138`).
- `compile_file(path)`: the basename less its last extension (`lib/logex.ex:94`). So
  `seal.txt` and `plant.lcf` both compile as programs, named `seal` and `plant`, and
  `m.v2.ld` is a `:file` diagnostic (measured, `probe/m2_words.exs`).
  `test/logex_test.exs:272-278` pins that; PLAN.md M2-2 says the `seal.txt` line flips
  when only `.ld` is taken (decided 2026-09-30). The no-extension line (`seal` → `seal`,
  `logex_test.exs:276`) flips with it. The test's comment, "No document chooses between
  that and `.ld` only" (`logex_test.exs:270-271`), is stale since PLAN.md M2-2 chose.

### 2.3 Where a file name is kept, and is not (fix F15)

- Kept: on every diagnostic and warning of `compile_file/1` (`lib/logex.ex:110-114`).
- Not kept: on the program. So an `:edit` diagnostic for a candidate read from a file
  formats as `line 2: …` with no path (measured: `file=nil`, `probe/m2_words.exs`);
  `lib/logex/edit.ex:36`, `lib/logex/diagnostic.ex:14-17` and §4.9 document the gap, and
  §7 F15 says Milestone 2 needs it closed.
- A configuration's own diagnostics can carry the `.lcf` path the way `compile_file/1`
  does. The ones that cite a program type's declaration (a `var_external` of another type
  than its global, M2-4; a connection naming a member, M2-2) need the type's file too.
  `%Logex.Diagnostic{}` holds one file and one line (`diagnostic.ex:22`), so the second
  location goes in the message.

### 2.4 What a configuration needs from a program

| Need | Today |
|---|---|
| its name | `program.name` |
| its var_inputs and var_outputs with types | in `program.tags`: `%Tag{section:, type:}` (`lib/logex/tag.ex:14-19`) |
| which tags it writes (§4.4: "a program that writes a `var_external` bound to an input point is an error, so `%Logex.Program{}` records which tags it writes") | **not exposed.** Computed privately twice: `Warnings.uses/2` (`lib/logex/warnings.ex:58-64`) and `Edit.rungs/1` (`lib/logex/edit.ex:489-518`) |
| its function block instances | tags whose type is `%Logex.FbType{}` |
| its file | **not kept** (2.3) |
| an instance of it | `Runtime.instance/1` |

Today `.ld` sources using M2 words fail as unknown instructions, and the next lines
cascade (measured, `probe/m2_words.exs`): `function_block seal` as line 1 gives
``unknown instruction `function_block` `` and then "after the first rung" for every
declaration; `var_external estop bool` likewise; `var s1 seal` gives
``unknown type `seal`: logex has `bool`, `dint` and `ton` ``; `cal` gives
``unknown instruction `cal` ``.

---

## 3. `Logex.FbType`, `Logex.Tag`, `Logex.Declarations`

### 3.1 What M2-5 can reuse

- `%Logex.FbType.Member{name, type, role, write: false, initial: 0}`
  (`lib/logex/fb_type.ex:30`): role and write flag fit a user block's sections; `initial`
  may be a map, so a nested timer's preset can ride on its member as it rides on a tag
  today (`compiler.ex:147`).
- `initial/2` (`fb_type.ex:75-84`) already recurses into a member whose type is an
  `%FbType{}`; `Program.initial_env/1` calls it (`program.ex:47-52`).
- `member/2` and `public/1` (`fb_type.ex:87,96`) are allowlists of `:input` and `:output`,
  so a `:local` role, which the moduledoc anticipates (`fb_type.ex:21-24`), is left out
  without a change. The `@type` of `role` does not list `:local` yet (`fb_type.ex:35`).
- `writable/1` (`fb_type.ex:100`) and the compiler's member checks
  (`compiler.ex:594-598,676-704`), whatever M2-5 decides a user block's writable members
  are.
- `Declarations.suggest/4` (`declarations.ex:67-89`) for did-you-mean on members, types,
  instances and `.lcf` names; `name?/1` (`declarations.ex:57`); `fits?/2`
  (`declarations.ex:92-93`, bool and dint only).

### 3.2 What is `ton`-specific, and must be generalised or kept apart

| Where | What | Pinned by |
|---|---|---|
| `fb_type.ex:66` | `builtins/0` is `%{"ton" => ton()}`; `ton/0` (`fb_type.ex:52-63`) | `runtime_test.exs:722-734` (surface) |
| `declarations.ex:349-364` | `fb_type/1` accepts only a type equal to its built-in, message `logex has Logex.FbType.ton()` | `validation_test.exs:1125-1152` |
| `declarations.ex:294`, `:346-347` | `unknown type …: logex has \`bool\`, \`dint\` and \`ton\``; `… :bool, :dint and Logex.FbType.ton()` | `validation_test.exs:416,505,661,1105,1740` |
| `declarations.ex:381-385` | an initial value on an instance: "its preset is the number on its `ton` instruction" | `api_contract_test.exs:104-123` (`@m16_diagnostics`) |
| `declarations.ex:341-342` | "`.` is kept for a member, as in a timer's `t1.dn`" | — |
| `declarations.ex:31,34-37,48` | type words and reservation come only from `@types` and `builtins/0`, with no per-compile types | naming_test (keywords) |
| `compiler.ex:649-652` | "only a timer has members" | `validation_test.exs:1607-1692`; `@m16_diagnostics` |
| `compiler.ex:533-541` | member lookup goes one level deep: `s1.t1.acc` is "goes too deep" | `@m16_diagnostics` |
| `warnings.ex:75-83` | the "no `ton` runs it" warning matches `name: "ton"` only; PLAN.md M2-5 says the user-type one must say `cal` | `validation_test.exs:1173,1347` |
| `compiler.ex:112-147` | the preset pass gives any `%FbType{}` tag a `ton` runs `initial: %{"pre" => …}` (a mistyped `ton s1 5` is already a diagnostic, so no program carries it) | — |
| `edit.ex:407,417-418,479-480,630-654` | every `%FbType{}` tag is a "timer" to the edit; a user block whose map has a `"pre"` key would meet the `.pre` rules, which move nothing while no `ton` runs it (inferred) | — |

`Logex.Tag`: `section` is `:var | :var_input | :var_output` (`tag.ex:19`); M2-4's
`var_external` is a fourth, a row in `Declarations.@sections` (`declarations.ex:18`)
per CLAUDE.md. `Tag.new!/4` (`tag.ex:39-46`) has no argument for known types, so a user
block instance cannot be declared from Elixir until `check/1` (`declarations.ex:316-323`)
takes them (measured: `check/1` refuses `var s1 seal` built as data).

---

## 4. `Logex.Compiler` and `Logex.Warnings`

### 4.1 The duplicated walks

| Walk | Compiler | Warnings | Edit |
|---|---|---|---|
| every instruction, legs included, newest first and reversed once | `compiler.ex:243-252` | `warnings.ex:45-54`, the same code | inside `rungs/1`, `edit.ex:489-518` |
| a symbol-to-signature map from `Compiler.instructions/0` | — | `warnings.ex:21` | `edit.ex:490`, the same code |
| a write operand found by zipping signature with operands | (in lowering) | `uses/2`, `warnings.ex:58-64` | `wrote/3`, `edit.ex:512-516` |
| the six comparisons | — | `@comparisons`, `warnings.ex:140` | — (and `runtime.ex:57`) |

A compile walks the instructions twice: `instructionize/2` at `compiler.ex:68` and
`Warnings.of/2` at `warnings.ex:22`. Both are linear (the growth tests,
`test/logex_test.exs:147-160`), so this is a structure problem, not a cost one.

**Does M2 need it first?** Not for M2-1 to M2-3. For M2-4 and M2-5, yes in effect:

- M2-4 needs the set of tags a program writes, public. Today it lives in two private
  walks with two counting rules (Warnings counts a member write as its instance's,
  `warnings.ex:66-67`; Edit counts only a `{:name, …}` write, `edit.ex:512-516`).
- M2-5's `cal` has a signature per instance type, not per mnemonic. `Warnings.of/2` and
  `Edit.accept/3` both raise `KeyError` on a lowered `{:cal, …}` (measured,
  `probe/walks.exs`), and `call/4` raises `FunctionClauseError` until it has the clause.

*Recommend* one module (B5's "`Instruction`"/"`Analyzer`", PLAN.md §4 B5) with the walk,
`signature(instruction, tags)` and `writes(program)`, landed as a refactor with no
behaviour change before M2-4. The alternative is three edits in M2-5 and a fourth walk in
M2-4.

### 4.2 What `instructionize/2` needs for `cal`

- **Lowering.** `lower_word/4` fetches a fixed signature and takes that many operands
  (`compiler.ex:284,294-307`). `cal` needs its first operand looked up first, then a
  signature built from the block type: `{:instance, type}`, then each var_input as a
  value and each var_output as a write, in declaration order (§4.3). The arity message
  §4.3 asks for names the formal (``operand 2 of `cal s1` is `stop` (var_input bool)``),
  unlike today's ``` `x` expects … ``` (`compiler.ex:364-370`).
- **Reservation.** `cal` must stop `take_operands/3` as every mnemonic does
  (`compiler.ex:345-358,828`) and be reserved in `.ld` (§4.8). If it is in
  `@instructions`, its entry cannot be an ordinary signature; if not, `mnemonic?/1`,
  `Declarations.reserved/1` (`declarations.ex:40-43`) and naming_test
  (`test/logex/naming_test.exs:34-47`) each need it from somewhere else. §4.3 says
  "`@instructions` and `naming_test.exs` stay the table of built-in mnemonics".
- **Refusals** (PLAN.md M2-5): `cal` of a non-instance, of a built-in type, an unknown
  type, recursion among types, and the warning for a block no `cal` runs.
- **The path rule.** A `ton` ends its path (`compiler.ex:149-238`); whether anything may
  follow a `cal` is settled by §4.3 (ENO is the power out), so the path pass leaves it
  alone (inferred).

### 4.3 What `instructionize/2` needs for `var_external`

A `@sections` row (`declarations.ex:18`), reserved in `.ld` only; `check_access`
(`compiler.ex:721-728`) is unchanged, since logic may write a `var_external` unless it is
bound to an input point, which only the configuration knows; and a `var_external` is not
a var_input, so the runtime's input check and the edit's `:input`/`:unread` rules
(`edit.ex:434-435`) leave it alone unless M2-4 says otherwise.

---

## 5. `Logex.Edit`, and what OE-2 needs from M2's shapes

- **Plans per program, switch and prune per instance** (fix F5): `plans/2`
  (`edit.ex:382-393`) is built at accept from the two programs alone; `switch/4`
  (`edit.ex:547-578`) and `prune/3` (`edit.ex:747-751`) are private functions of a plan,
  a record (`@record`, `edit.ex:204`) and one state. OE-2 calls them once per instance of
  a type, so M2 must keep each instance's state an ordinary `%Logex.Instance{}` whose
  `type` names its program (`instance.ex:28`), held flat by instance name (§4.9's list).
- **Reports name a tag** (`edit.ex:171`); from OE-2 an `instance.tag` path. M2-1's
  instance names must therefore be names, never positions.
- **Held outputs** are var_outputs today (`edit.ex:452-464`). OE-2 holds output *points*
  (§4.9), so M2-2's connections must be data OE-2 can read: which global each
  var_output drives.
- **One constructor**: `start/1` through `Runtime.instance/1` (F14), so an instance OE-2
  adds is built the same way.
- **A generation counter** in `%Logex.Runtime{}` is how OE-2 will detect the
  out-of-contract cases OE-1 documents (`edit.ex:178-187`); M2-1 should leave room for it
  in the opaque struct, nothing more.
- **Function blocks** (item 8 of section 0). `retyped/2` (`edit.ex:357-365`) refuses any
  `Tag.type` inequality, which for a user block means any change to its `%FbType{}`; if
  the type carries its body, any body edit is refused too. §4.9 refuses "the members of a
  function block type, until M2-5 brings the nested migration", which is narrower. The
  timer rules (`edit.ex:407,630-654`) and the one-shot rules (`edit.ex:489-543`) see only
  the program's own rungs and top-level tags, so a timer or `ons` inside a block is out of
  their reach (inferred). M2-5 should say which it is, and a test pin it.
- **F15** (2.3): the configuration edit must cite files, so the program or the
  configuration has to keep them.

---

## 6. Lexer and parser for `.lcf`

`Logex.Compiler.tokenize/1` on each line (measured, `probe/lcf_tokens.exs`, exit 0):

| Line | Tokens (`{kind, {line, column}, value}`) |
|---|---|
| `task fast interval 10 priority 1` | name `task` (1,1), name `fast` (1,6), name `interval` (1,11), int 10 (1,20), name `priority` (1,23), int 1 (1,32) |
| `var_global k1 bool at panel.q.0` | name `var_global` (1,1), name `k1` (1,12), name `bool` (1,15), name `at` (1,20), name `panel.q.0` (1,23) |
| `program m1 motor with fast` | names `program` (1,1), `m1` (1,9), `motor` (1,12), `with` (1,18), `fast` (1,23) |
| `m1.start pb_start_1` | name `m1.start` (1,1), name `pb_start_1` (1,10) |
| `m2.reset 0` | name `m2.reset` (1,1), int 0 (1,10) |
| `function_block seal` | name `function_block` (1,1), name `seal` (1,16) |
| `cal s1 a b q` | names `cal` (1,1), `s1` (1,5), `a` (1,8), `b` (1,10), `q` (1,12) |

Also measured: `task trip single estop priority 0`, `var_global sp_1 dint at drive.q.0`,
an indented `  m1.speed_sp sp_1` (column 3), `m1.t1.acc` and `var_config m2.speed_sp 900`
all lex; `at %ix0.0` is `{:illegal, "%"}` at column 4 (decision 6's fallback needs a
lexeme); `a.1b` is `missing_separator`. A six-line file with a `//` comment and
indentation parses to one rung per line, lines 2 to 6, the comment and blank margin gone.

**What can be reused.**

- The lexer, whole: positions, `//` comments, newline runs as one delimiter, the lone-CR
  rule (B8, `lexer.ex:46-50`, landed before any `.lcf` as §6.1 asked), and the `.` rule
  that makes `panel.q.0` and `m1.start` one name (`lexer.ex:121-138`).
- The parser, whole, as `Logex.Declarations` already uses it: a `.lcf` line is a rung of
  names and literals, read by its first word (`declarations.ex:143,169-172`). Indentation
  is cosmetic because whitespace is never emitted.
- What does not carry over: the parser keeps the line and drops the column
  (`parser.ex:95-99`), as a `:validate` diagnostic has none anyway; and it accepts `( | )`
  groups, which a `.lcf` reader must refuse as a line shape, as
  `declarations.ex:207,217,237-241` refuses one in a declaration.
- No new production, so neither the golden record (`test/fixtures/frontend_golden.txt`)
  nor the printer test's `@required_shapes` changes, unless decision 6's `%` fallback is
  taken.
- `Logex.Parser.well_formed!/1` (`parser.ex:65-70`) is the model for the configuration's
  data path: "the data API refuses what the text cannot say" (§4.9) means the Elixir
  constructor must refuse a name that would not lex as one name token, as `one_name!/2`
  does (`parser.ex:179-187`).

---

## 7. Tests M2 should follow, and what a configuration walk needs

| Pattern | Where | Use in M2 |
|---|---|---|
| whole diagnostic lists from source, formatted | `validation_test.exs:1835-1866` (`source_errors/2`, `source_warnings/1`) | `configuration_test.exs` (§6.2 M2-2): every configuration diagnostic as a whole formatted list, file and line included |
| Done-when through the public API, no IR tag in an assertion | `end_to_end_test.exs` (helpers `:15-46`, `drive/3` `:381-391`); "decision 6" two-rate test `:878-960`; OE-1 describe block `:1138-1370` | each item's Done-when; "decision 6" is the template for M2-3's 100-and-20 runs against one clock |
| a seeded walk with oracles, every call made twice, reach asserted | `api_contract_test.exs`: `@refusals` `:158-168`, `@edit_refusals` `:559`, `@report_kinds` `:570`, edit walk `:766-798` | a configuration walk (below) |
| growth in reductions, least of three, two sizes and two depths | `logex_test.exs:24-70,147-160`; `edit_test.exs:1376-1540`; CONTRIBUTING.md "Test a pass over the program for growth" | `cycle/3` linear in instances and connections; `Configuration.compile/3` linear in lines; the recursion check linear in types and in nesting depth; and, if item 2 lands, a scan's cost flat in unused tags |
| every mnemonic and declaration word surveyed | `naming_test.exs:34-61` reads `Compiler.instructions/0` and `Declarations.keywords/0` | the `.lcf` words need a third source it reads (a `keywords/0` on the configuration module), and `cal` must reach it (4.2) |
| exact public surface | `runtime_test.exs:688-735` | every new function and struct of M2 |
| the labels test | `edit_test.exs:1541-1603` | refuses `R` plus a number and "hazard B" in `lib/`, `test/` and CLAUDE.md, and any `F<n>` or "decision <n>" that §7 does not define. M2's own decisions must be in §7 before code cites them by number, and any other capital `F` and a number past 16 (a source's "Figure F20", say) trips it |
| front-end golden | `frontend_golden_test.exs` | unchanged by M2 unless the lexer changes |

**A configuration walk would need:**

- a generator of configurations from one vocabulary, as `edit_source/0` draws programs
  (`api_contract_test.exs:645-760`): two or three program types, one to four instances,
  periodic tasks with intervals and priorities (and, from M2-6, event tasks), globals bool
  and dint, located and not, and connections that obey the rules, plus deliberately broken
  ones for the diagnostics' reach;
- host operations: `cycle/3` with elapsed 0, small, and longer than an interval (overlap);
  input images valid and invalid (an undeclared point, a wrong type, an output point);
  `next_due_in/1`; `get/2` on good and bad paths; a restart if M2 defines one;
- oracles that do not restate the scheduler: each instance's scans replayed through
  `call/4` alone, from the walk's own image and the documented order, give the same
  outputs and state; run counts per task from due times the walk computes; the order of
  `{:ran, …}` events by priority, due time and declaration; `missed` as
  `div(now - next_due, interval)`; a global written by an earlier instance in a cycle seen
  by a later one and never the reverse; every cycle made twice gives the same result (the
  Milestone's "same outputs on every run");
- reach: every refusal, every event kind, every task kind, an overlap, and from M2-6 an
  edge in cycle 1;
- F14's test: an instance `start/1` builds equals `Runtime.instance/1`'s for its program.
  Through an opaque `%Logex.Runtime{}` that must be observed by behaviour (a first-scan
  `ons` suppressed), or `get/2`.

---

## 8. Documents each M2 item stales

| Item | Stales |
|---|---|
| every item | `PLAN.md` M2 status (`PLAN.md:1288-1373`); `docs/organisation.md` §4.1 stage column (`:195-210`), §6.2 (`:1353-1438`); `docs/naming.md` stanzas before code (§6.2); CLAUDE.md Key Files (`CLAUDE.md:20-128`); README "sixteen small modules" (`README.md:6`) |
| M2-1 | README stage paragraph "and a scheduler — the host calls one scan at a time" (`README.md:16-17`) and "which is what a scheduler will call" (`README.md:225-227`); `Logex.Runtime` moduledoc (`runtime.ex:1-53`); `Logex.Program.initial_env/1` doc "M2-1's `start/1` will start" (`program.ex:32-33`); `docs/organisation.md` §4.6 API block (`:669-681`); PLAN.md §8 item 2 (`PLAN.md:2046-2049`); CLAUDE.md Key Files `runtime.ex` line |
| M2-2 | README syntax list (`README.md:26-47`), a new example whose output is a real run, the "Documents" line for organisation.md (`README.md:479`); `test/logex_test.exs:270-278`; `Logex.compile_file/1` doc (`lib/logex.ex:76-83`); `Logex.Diagnostic` stages (`diagnostic.ex:9-17,24`) if a stage is added; F15's notes (`edit.ex:36`, `diagnostic.ex:14-17`, §4.9 "Known limits"); `docs/organisation.md` §8 "Not yet measured: the §4.4 diagnostics" (`:1704-1705`); CLAUDE.md Key Files and Tests (`configuration.ex`, `configuration_test.exs`) |
| M2-3 | README syntax list and example; §4.4 line-shape table if a spelling changes |
| M2-4 | README syntax list (sections), `Logex.Declarations` moduledoc (`declarations.ex:7-8`), `Logex.Tag` moduledoc and type (`tag.ex:2-11,19`), the Warnings moduledoc for the two-writer warning (`warnings.ex:2-15`) |
| M2-5 | README instruction table (a `cal` row, `README.md:92-120`), syntax list (type words, `function_block`), "Settled, not yet landed" (`README.md:131-146`); CLAUDE.md conventions on `evaluate/3` (`CLAUDE.md:134`), operands (`:136`) and "New instructions, step 2" (`:146-159`) if `cal` departs from them; `Logex.FbType` moduledoc (`fb_type.ex:1-25`); every `ton`-specific message in 3.2 and its pins; `docs/naming.md`'s `cal <routine>` row (`docs/naming.md:240`), superseded by an appended stanza (§4.3) |
| M2-6 | README syntax list; the `ton`-in-an-event-task warning §4.6 defers to M2-6 (`docs/organisation.md:650-652`); `Program.initial_env/1`'s exception list (`program.ex:41-42`) |

PLAN.md §5's organisation bullet (`PLAN.md:1894-1904`) carries the one-line summary
§6.2 asks for; B5's module list (`PLAN.md:1647-1661`) and B9's preconditions change with
the items that add modules.

---

## 9. Open questions for the maintainer

Each departs from nothing decided unless it says so.

1. **M2-1's data.** Does `%Logex.Configuration{}` hold globals and connections in M2-1, or
   only instances and tasks with M2-1's copy-in keyed by `instance.var_input`?
   *Recommend globals and connections from M2-1*, so the one checked constructor (§4.9)
   exists before M2-2's parser feeds it, and M2-2 adds only text.
2. **The per-scan tag walk** (1.7). Precompute the var_output names (a public field of
   `%Logex.Program{}`), or keep the walk and record the cost. *Recommend precomputing, in
   a commit of its own before M2-1, with a growth test.*
3. **How a `cal` finds its body** (1.5). A, B or C. *Recommend A*, the scan carries the
   types, so the IR keeps its shape. Needs a spike.
4. **A body's one-shots** (1.5). An empty block map inside a body until a block's
   migration exists, or block maps keyed by path. *Recommend the empty map*, stated in
   §4.9's known limits, since no switch can block a body's `ons` yet.
5. **`var_external` in a scan** (1.6, point 3). A globals argument merged in and split
   off around the rungs, or a mirror in the instance env. *Recommend the argument*: the
   mirror breaks §4.9's "one copy of each global's value".
6. **The IR walk extraction** (4.1). Before M2-4, or inside M2-4 and M2-5. *Recommend
   before M2-4*, as the rest of B5.
7. **`cal` in `@instructions`** (4.2). A special entry, or a separate reserved list that
   `mnemonic?/1`, `reserved/1` and naming_test also read. §4.3 says `@instructions` stays
   the built-in mnemonics, which favours the separate list. *Recommend the separate list*,
   one function every reader calls.
8. **A program's file** (2.3, F15). A `file` field on `%Logex.Program{}`, or the loader's
   map. *Recommend the field*: it closes F15 for `Logex.Edit` too.
9. **Block types in the compile API** (section 0 item 6). A `types:` option to
   `Logex.compile/2` (its pinned "no other option" message changes), or a separate entry
   point. *Recommend the option*, mirroring `Configuration.compile/3`.
10. **An edit and a user block** (5). Refuse every change to a block type, body included,
    until OE-2's nested migration; or compare schemas only. *Recommend refusing every
    change*, which needs §4.9 widened from "the members of a function block type" to the
    type, an explicit departure.
11. **`Runtime.get/2`'s reach.** Var_inputs, var_outputs and public members only, or also
    a program's plain `var`s (`m1.fault`), as the README reads `state.env["fault"]` today
    (`README.md:187-189`). *No recommendation*; §5 defers VAR_ACCESS.
12. **A `.lcf` printer.** PLAN.md §5 and §4.9 say the saved form is text "which printers
    write"; no item in M2 lists one, and no printer from `%Logex.Program{}` exists either
    (`lib/logex/printer.ex:14-18` prints the parse AST). Which item owes the
    configuration's printer, if any? *Recommend M2-2 owes a round trip from data to text
    and back*, or the data API's "refuses what the text cannot say" has nothing to be
    checked against.
13. **A configuration restart.** `restart/3` is per instance (`runtime.ex:106-117`). No
    M2 item says what restarting a resource does to globals, task phases and event
    triggers. *Recommend* M2-1's design states it, since each piece of new state owes a
    rule for a restart (CLAUDE.md "New state in an instance").

---

## 10. Receipts

- Copy: `m2/inv-readiness-work` (from `47319f7`); patch: `m2/inv-readiness.patch`,
  `git add -A && git diff --cached HEAD`, 614 lines: the spike in `lib/logex/program.ex`,
  `compiler.ex` and `runtime.ex`, and the probes under `probe/`.
- `probe/lcf_tokens.exs`: section 6.
- `probe/call_cost.exs`: a first count through interpreted closures (281 for the motor);
  superseded by `probe/call_cost2.exs`, which counts compiled calls (277). Both were run
  at HEAD, three times each, with identical figures.
- `probe/call_cost3.exs` (needs `probe/call_cost2_mod.exs`): the tag-count rows and the
  wall time, at HEAD and again on the spike.
- `probe/m2_words.exs`: M2 words in today's compiler, `compile_file/1` names, F15, the
  `outputs/2` comprehension alone.
- `probe/walks.exs`: a lowered `cal` in `Warnings.of/2`, `Edit.accept/3` and `call/4`;
  `FbType.initial/2` and `Declarations.check/1` on a user type.
- Run each with `source …/toolchain/env.sh && mix run probe/<file>` in the copy.
- Gate on the spike, judged by exit code: `mix format --check-formatted` 0;
  `mix compile --force --warnings-as-errors` 0; `MIX_ENV=test mix compile --force
  --warnings-as-errors` 0; `mix test --warnings-as-errors` 0, 430 tests (6 doctests).
- Unverified: wall-clock time per scan (noisy across runs); every "inferred" line above,
  in particular the shared one-shot key inside a block body (1.5) and the edit's reach into
  a block (5), which no probe ran because no user block can be compiled yet.
