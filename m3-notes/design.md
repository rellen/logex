# Milestone 3 — the missing instruction set: design pass

Written 2026-10-14 against `main` at `970dede` (932 tests green on Elixir 1.20.4 / OTP 28).
Nothing here has landed. The one spike is on the throwaway branch `backup/m3-design`
(the commit after `970dede`); §6 reports it.

Milestone 3 closes PLAN.md §8's instruction gaps: counters; the other three timers;
integer arithmetic; the coil one-shots `osr` and `osf`; and control flow. Each item
follows M1-6's model: survey the names first, then the semantics on an energised and a
de-energised rung, what the compiler refuses, the warnings, the rule across an online
edit for each piece of state, and the host-contract property.

"Decision N" means `docs/organisation.md` §7's. "§4.9" means that document's online-edit
section. "Conventional" is naming.md's unattributed column, and that policy holds here
too. A claim marked **unverified** was not checked against its source for this pass.

Contents: §1 what already carries the new instructions; §2 each item in landing order;
§3 cross-cutting questions; §4 the questions for the maintainer, each written twice;
§5 the milestone's structure; §6 the spike; §7 risks and what to spike next.

---

## 1. What the code already gives, and where it assumes `ton`

The model M1-6 built does generalise. A built-in function block is a `%Logex.FbType{}`
with `body: nil`, its members carry a role and a write flag, its state is a map in the
env, and its preset is the number on the instruction, which the compiler copies into the
tag's initial `pre`. The spike (§6) added a `ctu` as a second built-in. It counted, ran
inside a block, restarted, and was refused a type change, with no new mechanism.

The places below assume that every built-in is a `ton`. Before the first new built-in
can land, a refactor commit has to make each of them read the type:

| Where | The assumption | What it must become |
|---|---|---|
| `Logex.Compiler.presets/2`, `ton/1` | only `:ton` gives a timer its preset | every instruction with a `{:preset, _}` slot |
| `Logex.Compiler` path rule, `bears/3`, `follows/3` | only a `ton` ends its path; the message names `ton` | a set of instructions whose power out is unsettled, each named in its message (the spike crashed with a `FunctionClauseError` here) |
| `check_preset/5`, `preset/4` messages | "a number of milliseconds" | a time for timers, a count for counters |
| `Logex.Walk.timers/1` | the `ton`s, which feed both the edit's preset rule and M2-6's event-task warning | two facts: `presets/1`, every built-in instance with its instruction's preset, for the edit; and `timers/1`, the instances that keep time, for the configuration's warning. Widened alone, as in the spike, the event-task warning would fire on counters |
| `Logex.Warnings.unrun/2` | "`c` is a ton, but no `ton` runs it: it never times" for any built-in (the spike printed this for a `ctu`) | worded per type |
| `Logex.Edit.Plan` `facts/2`, `fit/1`, `member/5` | every `%FbType{body: nil}` is a timer | each built-in type states which state rules apply to it (below) |
| `Logex.Edit.Plan.done/3` | the `.dn` forecast reads a timer's `.en` | a forecast per type. Without one, an edit that changes a counter's preset raises `FunctionClauseError`, spiked |
| `Logex.Edit.Plan.resumed/4` | "timing" means `.en` 1 | timing per type: `.en` for `ton` and `rto`, `.tt` for `tof` and `tp` |
| `Logex.Edit.Plan` one-shot walk | only `ons` has an edge memory | every edge-sensing instruction (§3.3) |

The refactor needs no syntax change and changes no
behaviour for `ton`. A short, fixed description of each built-in can carry it: what
it times, which member is its edge memory, and how its `.dn` is forecast. That
description is plain data on the `%Logex.FbType{}` or a table beside `builtins/0`, so
the walks and the edit read it rather than match on names.

The edit's other rules carry over untouched: start a new tag at its initial value, keep
a removed one unused until assemble, refuse a type change, and move `.pre` by
decisions 23 and 27. The spike showed `.pre` moving 3 → 5 and reported as `:preset`;
`.pre` kept where logic had moved it, reported as `:preset_kept`; and a `ctu` removed
and restored, which left the count frozen and then set `.pre` outright, reported as
`:preset`.

---

## 2. The items, in landing order

### M3-1 · Counters: `ctu`, `ctd`, the type words `ctu` and `ctud`, and `res`

**IEC basis.** Ed 2 §2.5.2.3.3 Table 36: CTU f1a (typed CTU_DINT f1b), CTD f2a and CTUD
f3a. Ed 3's table number for counters was not recorded in instruction-sets.md and is
**unverified**; it is probably Table 45, after Ed 3 TON's Table 46. The pins are CU/CD,
R, LD and PV, giving Q (or QU and QD) and CV. CTD has no R pin. Each IEC body counts on
an edge of CU or CD, which MatIEC makes explicit with an internal R_TRIG, and bounds the
count with `CV < PVmax`, whose limit is implementation-dependent (Table 36 NOTE).

**Vendors.** Conventional: CTU and CTD on one COUNTER tag, `.PRE .ACC .CU .CD .DN .OV
.UN`, ladder only, and RES resets it. Siemens TIA: CTU, CTD and CTUD as IEC_COUNTER
instances; classic S_CU and S_CD, where classic Q means "count ≠ 0". CODESYS: CTU, CTD
and CTUD, with the pins renamed RESET and LOAD and PV/CV of type WORD. Mitsubishi:
native `OUT C`, FB CTU(_E), and RST as reset. LDmicro: CTU and CTD with an inline
threshold, and RES. ClassicLadder: one block, which wraps at 0 and 9999.

**Names.** Rule 1 gives `ctu` and `ctd`, the instructions, and IEC's type names: `ctu`
for a counter that only counts up, and `ctud` for one that counts both ways. Rule 2
gives `res`, the conventional set's and LDmicro's reset. IEC resets by a pin, so it has
no instruction to name. **Recommendation (Q1): no down-only type.** There is no `var c
ctd`; the `ctd` instruction runs only a `ctud`. §4 gives the reasons.

**Declaration.** `var boxes ctu` or `var stock ctud` is a `var`, with no initial value,
as `ton` is.

**Members** (the conventional COUNTER's, lowercased):

| Member | Type | Role | Logic may write | Meaning |
|---|---|---|---|---|
| `pre` | dint | input | yes | the preset; starts at the instruction's number |
| `acc` | dint | output | yes | the count |
| `cu` | bool | output | no | the power the `ctu` received last scan: its edge memory |
| `cd` | bool | output | no | `ctud` only: the same for its `ctd` |
| `dn` | bool | output | no | `acc >= pre`, set on every scan the counter runs |
| `ov` | bool | output | no | a count up was refused at the top limit; cleared by `res` |
| `un` | bool | output | no | `ctud` only: a count down was refused at the bottom limit; cleared by `res` |

The writable members follow decision 9: `.pre` and `.acc` may be written, as on a
timer. A `move 0 boxes.acc` clears the count without a `res`.

**Operands.** `ctu c 10` is `[{:instance, "ctu"|"ctud"}, {:preset, :dint}]` and
`ctd c 10` is `[{:instance, "ctud"}, {:preset, :dint}]`. An instance slot that accepts
more than one type is new, since today `{:instance, type}` names exactly one. The preset
is a literal from 0 to 2147483647, a count, not milliseconds. `res c` is
`[{:reset, builtins}]`, which is a new access kind: the walks count it as a write of the
instance, but not as a run. Otherwise a counter that only a `res` names would escape
the "nothing runs it" warning.

**Scan semantics.**
- `ctu`, energised. If `.cu` is 0, the scan is not the instance's first, and the
  counter is not on the block list (§3.3), then `.acc` gains 1. At 2147483647 it gains
  nothing and `.ov` is set instead (Q4). Then `.cu` = 1 and `.dn` = `.acc >= .pre`.
- `ctu`, de-energised. `.cu` = 0, `.dn` = `.acc >= .pre`, and `.acc` is unchanged.
- `ctd` mirrors `ctu` through `.cd`, down to −2147483648, where it sets `.un`.
- A `ctud` with both a `ctu` and a `ctd`: each counts its own edge. When both edges
  arrive in one scan they cancel, which is IEC CTUD's `NOT (CU AND CD)` and the
  conventional net zero, and away from the limits the two agree.
- `.dn` is recomputed by every run, so a `move` into `.pre` shows at the counter's next
  run, whatever its rung. The spike confirmed this.
- `res c`, energised: `.acc` = 0, `.ov` = `.un` = 0, `.dn` = `0 >= .pre`. It **keeps
  `.cu` and `.cd`** (Q3). De-energised, it does nothing. It passes on the power it
  receives, as `otu` does, and anything may follow it.

**Power out.** A counter passes on what it receives, but nothing may follow a
`ctu` or `ctd` on its path: what passes on after one is unsettled, as after
`ton` (Q6). `res` passes the rung on.

**The compiler refuses:**
- a second `ctu`, or a second `ctd`, on one counter, at its line, citing the first;
- a `ctd` on a `ctu`, with the hint "`var stock ctud`";
- a `ctu` and a `ctd` on one `ctud` whose presets differ, citing the first;
- a preset that is not a literal, or out of range, with the count wording;
- anything after a `ctu` or `ctd` on its path;
- `res` on anything but a built-in instance, including a user block;
- a write to `.cu .cd .dn .ov .un`, by decision 9's rule.

**Warnings:**
- a counter that no `ctu` or `ctd` runs: "it never counts". A `res` alone does not run
  it;
- a counter run under an event task (Q5, through `Logex.Configuration.check/1`).

**Across an online edit**, one row per piece of state:

| Case | Rule |
|---|---|
| preset changed (`ctu boxes 10` → `ctu boxes 12`) | `.pre` follows where logic left it, and a `.pre` that logic changed is kept (decisions 23 and 27). Reported `:preset` or `:preset_kept`, with a `.dn` forecast: certain at the counter's next run, since `.dn` is recomputed even on a false rung. Spiked. |
| type changed (`ctu` ↔ `ctud`, or ↔ any timer) | refused at accept: "a tag's type changes only with a restart". Spiked for `ton` → `ctu`. |
| instance added | starts at its initial value with `.pre` at the preset. If its rung is already true at the switch, the spike measured a phantom count. Its edge must be blocked (§3.3). The spike showed the block list doing this with a two-line change. |
| instance removed | kept unused until assemble, then pruned (as any tag) |
| `ctu` removed then restored | frozen, then `.pre` set to the new preset outright (decision 23). The count is kept. The restored `ctu` is blocked for one scan, since its rung is new. Spiked. |
| `ctu`'s rung changed | its edge is blocked until a scan runs it (§3.3). A change to the preset alone must not count as a changed rung. The spike blocked it, which loses a real box arriving at the switch, so the rung comparison must leave out the instruction's own preset. |
| inside a frozen block (a false `cal`) | everything is held. An edge that comes and goes while the block is frozen is never seen; the spike measured a missed box. This is decision 8's freeze, and the README must say so for counters. |

**`cal` and blocks.** A counter inside a block is a member, `s1.c`, which `Walk.presets`
reaches by path as `Walk.timers` reaches `s1.t1`. A frozen block holds its counters.

**Restarts.** `restart/3` and `restart/2`, cold or warm: `Logex.Program.initial_env/1`,
so `.acc` is 0 and `.pre` is the preset. `:warm` stays `:cold` until `retain` lands.

**Configuration.** `Logex.Configuration.check/1`'s M2-6 timer warning does not apply
to counters. Q5 proposes a warning of its own.

### M3-2 · The other timers: `tof`, `tp`, `rto`, and `res` on timers

**IEC basis.** Ed 2 §2.5.2.3.4 Table 37: TP f1, TON f2a, TOF f3a (Ed 3 Table 46). There
is no retentive timer in IEC, only `RETAIN` (Table 33 f3a), and so `rto` is rule 2.
**Vendors**, from naming.md's Timers table:
- `tof`: conventional TOF, with "the inverted `.DN` sense"; Siemens TOF, classic
  S_OFFDT; CODESYS TOF; Mitsubishi FX's STMR, and the TOF FB family.
- `tp`: no conventional pulse timer; Siemens TP and classic S_PULSE; CODESYS TP; the
  Mitsubishi FB TP family; LDmicro's THI, which is not named TP.
- `rto`: the conventional RTO; Siemens TONR. *Do not call it `tonr`*: the conventional
  TONR is a TON with a reset pin. Mitsubishi has an ST device; LDmicro has RTO.

**Names:** `tof`, `tp` (rule 1) and `rto` (rule 2), each both an instruction and a type
word, as `ton` is.

**Members:** the `ton` schema, `pre acc dn tt en last`, for each of the three, each a
separate type. `last` is internal, decision 5. Logic may write `.pre` and `.acc`.

**Operands:** `[{:instance, word}, {:preset, :dint}]`, in milliseconds, as `ton`.

**`tof t 5000`** (the conventional TOF; the parts marked **unverified** are where the
manual was not read):
- Energised: `.en` = 1, `.dn` = 1, `.tt` = 0, `.acc` = 0.
- De-energised, on the scan after an energised one (`.en` was 1): the off-delay starts.
  `.tt` = 1, `.dn` stays 1, and `.acc` gains nothing, as `ton`'s first scan adds
  nothing.
- De-energised while `.tt` is 1: `.acc` gains `now − last`, capped at `max(.pre, 0)`.
  At the cap, `.dn` = 0 and `.tt` = 0. With a preset of 0, `.dn` drops on the falling
  edge's own scan.
- De-energised and at rest: `.dn` = 0 and `.tt` = 0. `.acc` stays where timing left it,
  at `.pre` (conventional, **unverified**).
- `.en` = 0 on every de-energised scan, and `last` = `now` on every run, energised or
  not.
- Raising `.pre` after timing out does not start it again: the timer is at rest. Only
  while `.tt` is 1 is `.dn` recomputed against `.pre`.
- On the first scan with the rung false, `.en` is still at its initial 0, so there is no
  falling edge, and the fan is off at start.

**`tp t 3000`** (IEC TP):
- Energised, with a rising edge (`.en` was 0, the scan is not the first, and the
  timer is not on the block list): the pulse starts. `.tt` = 1 and `.acc` = 0.
- While `.tt` is 1, energised or not: `.acc` gains `now − last`. At `.pre`, `.tt` = 0,
  and `.dn` = 1 while the rung stays true. The pulse ignores the rung, and a new edge
  during the pulse does not retrigger it (IEC).
- De-energised and not pulsing: `.acc` = 0 and `.dn` = 0.
- `.en` = the rung on every run.
- **The pulse is `.tt`** (Q7). With a preset of 0 there is no pulse at all: it starts
  and ends in the same scan, so `.dn` = 1.

**`rto t 60000`** (the conventional RTO):
- Energised: as `ton`.
- De-energised: `.en` = 0 and `.tt` = 0. `.acc` and `.dn` are kept.
- Only `res` or a restart clears it (Q9).

**`res` on timers** (the widening of M3-1's slot):
- on `ton` or `rto`: `.acc` = 0, `.dn` = 0, `.tt` = 0. It keeps `.en`, so a true rung
  times from 0 at the next scan.
- on `tof`: it ends any off-delay. `.dn` = `.tt` = `.acc` = 0, so the fan stops now.
- on `tp`: it ends the pulse. It keeps `.en`, so a held rung gives no new pulse.

One rule covers all three: **`res` puts an instance at rest and keeps its edge
memory.**

**Power out:** nothing may follow `tof`, `tp` or `rto` on its path (Q6).

**The compiler refuses:** the same as `ton`. That is one instruction per timer, so a
`ton` and a `tof` on one `ton` timer is a type mismatch, and a second `tof` is a second
run. It also refuses anything after one of them on its path.

**Warnings:**
- a timer that no instruction of its type runs, in the type's own words;
- M2-6's event-task warning, widened to all four timers in their own words. A `tof` or
  `tp` under an event task finishes only when its task next runs, which is worse than
  `ton`'s case: a fan run on by a `tof` under the e-stop's event task runs on until the
  next e-stop.

**Across an online edit:**

| Case | Rule |
|---|---|
| preset changed | `.pre` rule as `ton` (decisions 23, 27). The `.dn` forecast is per type: `ton`/`rto` as now (fix F6); `tof` while timing, `.dn` drops if `.acc >= new pre`; `tp`, no `.dn` forecast, but `.tt` ends early if `.acc >= new pre` (a new kind or a reuse of `:dn_drops` naming `.tt`, decided at the commit) |
| type changed (`ton` → `tof` etc.) | refused, restart |
| added | initial; `tof` and `rto` need no block (no edge on a level); `tp`'s rising edge is blocked like a counter's (§3.3) |
| removed / restored | frozen, `.pre` outright on restore (decision 23); restored timing resumes from the switch (decision 23's resume, 56, 57), the resume trigger per type: `.en` 1 for `ton`/`rto`, `.tt` 1 for `tof`/`tp` |
| frozen block | `last` frozen, so each catches up when the block next runs (decision 8): a `tof` that was timing may finish on that run; a `tp` pulse may end on that run |
| back from aside (OE-2) | resumed from the switch (decision 57), with the per-type trigger |

**Restarts:** `restart/3` and `restart/2`, cold or warm: initial. That holds for `rto`
too, unless Q9 says otherwise.

### M3-3 · Integer arithmetic: `add sub mul div mod`, and `neg abs`

**IEC basis.** Ed 3 Table 29 f1–5 (`ADD MUL SUB DIV MOD`; Ed 2 Table 24 f12–18); `ABS`
Ed 3 Table 28 f1. IEC has no NEG function, only ST's unary minus (operator feature 4).
DIV truncates toward zero, `7/3 = 2, (-7)/3 = -2`; MOD is `IN1 - (IN1/IN2)*IN2`, and 0
when IN2 is 0. That is Elixir's `rem/2`, not `Integer.mod/2`.

**Vendors** are unanimous on ADD, SUB, MUL, DIV and MOD. Two differ on detail:
Mitsubishi's `/` writes the remainder to (d)+1, and CODESYS documents MOD as
"non-negative" (**unverified** against IEC's sign rule). NEG is conventional, Siemens
NEG and Mitsubishi NEG/DNEG. ABS is everywhere but native Mitsubishi.

**Names:** `add sub mul div mod abs` (rule 1) and `neg` (rule 2). **`sqrt` is
deferred:** IEC's SQRT takes ANY_REAL only, logex has no real type, and Mitsubishi has
no binary integer square root (Q12).

**Operands:** each of `add`, `sub`, `mul`, `div` and `mod` takes
`[{:value, :dint}, {:value, :dint}, {:write, :dint}]`, and `sub a b d` is a − b. `neg`
and `abs` take `[{:value, :dint}, {:write, :dint}]`. The destination may be a source,
as in `add total flow total`, because the sources are read before the write.

**Semantics:**
- Energised: compute, bring the result into a dint (Q10), write it, and pass power.
  Under Q10's and Q11's recommendation, an overflow or a zero divisor passes no power
  instead.
- De-energised: nothing is written and no power passes, as `move`.
- `neg` of −2147483648 and `abs` of −2147483648 overflow, and so does
  `div -2147483648 -1`.

**Why the result must be brought into a dint:** Elixir integers are unbounded. A
`mul` that is not brought back into a dint would put a bignum into the env. An edit's
first test then sees a tag "whose value does not fit its type", because
`Declarations.fits?/2` checks the range, and starts that tag again at its initial
value. The total would be lost without a word.

**The compiler refuses:**
- a literal 0 divisor to `div` or `mod`, which could never do anything;
- a destination that is a var_input, a literal or a non-writable member, which is
  already the rule.

**Warnings:**
- every source a literal: "its result never changes; `move` the value", as two compared
  literals get today.

**Negative literals land first in this item**, as decided in PLAN §5: one lexer rule,
`-?[0-9]+`. The same change widens `Logex.Parser.well_formed!/1` and
`Logex.Declarations.check/1` to allow negative values, and the golden record changes
exactly where `-` appears. Presets stay 0 or more.

**Edit, restarts, blocks, configuration:** arithmetic adds no state. A dint it writes
follows the existing rules, decision 29's included. Under event tasks there is nothing
to warn about.

### M3-4 · The coil one-shots: `osr`, `osf`

**IEC basis:** the positive and negative transition-sensing coils, Ed 2 Table 62 f8
and f9 (Ed 3 Table 76 f8 and f9): *"the state of the left link is always copied to the
right link."* IEC's coil hides its memory. There are also the R_TRIG and F_TRIG blocks
(Table 35). **Vendors:**
- Conventional: OSR and OSF, with a storage bit and an output bit; rung out follows
  rung in.
- Siemens TIA: `--(P)--` and `--(N)--`. Classic `( P )` is the RLO one-shot, which is a
  different thing.
- CODESYS: an R_TRIG or F_TRIG instance.
- Mitsubishi: PLS and PLF.
- LDmicro: OSR and OSF are inline elements, which is backwards from the conventional
  set, as the `ons` stanza says.

**Names:** `osr` and `osf`, by rule 2. The naming table already reserved them for the
coil form.

**Operands:** `osr s q` is `[{:write, :bool}, {:write, :bool}]`. The first operand is
the storage bit and the second the output bit; they must be different tags.

**Semantics:**
- `osr`, energised: `q` = 1 when `s` was 0, the scan is not the first and `s` is not on
  the block list. Otherwise `q` = 0. Then `s` = 1. It passes true.
- `osr`, de-energised: `s` = 0 and `q` = 0. It passes false.
- `osf`, energised: `s` = 1 and `q` = 0. It passes true.
- `osf`, de-energised: `q` = 1 when `s` was 1, the scan is not the first and `s` is not
  blocked. Then `s` = 0. It passes false.

**Power out:** the rung's power, settled, so anything may follow either one.

**The compiler refuses:**
- a second `ons`, `osr` or `osf` on one storage bit, which generalises the `ons` rule;
- the storage bit and the output bit as one tag.

**Warnings:**
- another writer of the storage bit, as for `ons`;
- the output bit: `osr` and `osf` write it every scan, as `ote` does, so they join the
  second-`ote` warning;
- the configuration's "storage bit of an `ons`" message for a global, widened.

**Across an online edit:** the storage bit joins the block list exactly as an `ons`
bit (decisions 21 and 32). The output bit is an ordinary bool.

**Restarts:** initial. **Frozen block:** both bits are held.

### M3-5 · Control flow: forward `jmp`/`lbl`, and no MCR

**IEC basis:**
- The jump, Ed 2 §4.1.4 Table 58 f1–4: *"A transfer of program control to the
  designated network label shall occur when the Boolean value of the signal line is 1."*
- The network label, §4.1.2.
- §4.1.3 rule 3: the rest of a network is evaluated even when it holds a jump.
- IL's JMP, JMPC and JMPCN went with IL in Ed 4.
- MCR: zero hits in Ed 2.

**Vendors** (naming.md's Program control table):
- Conventional: JMP and LBL, the label first on its rung; MCR is one mnemonic for
  both ends, zones cannot nest, and a program must not jump into one.
- Siemens: `( JMP )`, `( JMPN )` and LABEL; MCR is legacy S7-300/400 only, absent from
  S7-1200/1500.
- CODESYS: the Jump element and the Jump Label; no MCR.
- Mitsubishi: CJ and the P pointers; MC and MCR.
- LDmicro: GOTO, LABEL and MASTER_RELAY.

**Names:** `jmp` and `lbl` (rule 2; the table's planned names). MCR is not added: the
table's deferred `mcs … mce` becomes "do not add" (Q16).

**Operands:** `jmp done` and `lbl done` take `[{:label, nil}]`, a new slot kind. Labels
are their own namespace, routine-local, and never tags. A label may be no reserved
word, and two labels that differ only in case are refused, as tags are.

**Semantics:**
- `lbl` passes on what it receives and does nothing else, but it must be the first
  element of its rung.
- `jmp`, energised: it records the jump and passes true. The rest of its rung is still
  evaluated (IEC rule 3). When the rung ends, the rungs up to the label's rung are
  skipped.
- `jmp`, de-energised: nothing; it passes false.
- The evaluator's rung loop widens from `env` to `{skip, env}`, as PLAN §8 foresaw.
- Skipped rungs are not evaluated. Their outputs hold, counters and one-shots hold, and
  timers freeze and catch up when next run (Q15), exactly as in a false `cal`.

**The compiler refuses:**
- a backward jump, or a jump to its own rung;
- a label that does not exist, or one used twice;
- `lbl` anywhere but first on its rung;
- two `jmp`s in one rung, since which one wins would be arbitrary and refusing is the
  reversible choice;
- a jump inside a block's body to a label in the program, or the reverse: labels are
  routine-local.

**Warnings:** a label no `jmp` names.

**Edit:** no state. An edit that adds a jump over a section freezes it from the
switch, which is the state's ordinary rule.

**Cost:** the rung loop's extra state is the one change that touches every scan.
M1-6's 5.7% is the precedent; a growth test pins it.

---

## 3. Cross-cutting questions

### 3.1 dint overflow and divide by zero (Q10, Q11)

The options are:
- **Wrap**, two's complement. This is the conventional set's value (with a status
  flag, S:V, **unverified**), C's, and ClassicLadder's for counters.
- **Saturate** at ±2147483647. This is IEC's `CV < PVmax` for counters.
- **Fault.** logex has no fault, and the host contract lets nothing escape, so this is
  out.
- **A status bit.** logex has no status register, and adding one is a language
  feature, not an instruction.
- **ENO**: the instruction passes no power on the scan it overflows. This is IEC's EN/ENO
  model, under which an error gives ENO false (Ed 3 §6.6.1.5, which also makes the
  outputs implementer-specific).

**Recommendation:** saturate, and pass no power on that scan. The program can catch it
with `add total flow total ote total_ok`, and a total never jumps from +2 billion to −2
billion. For a zero divisor: write 0, IEC's MOD rule extended to DIV, and pass no power.
Counters saturate too and flag it in `.ov` and `.un`. This makes the arithmetic
instructions the first output instructions whose power out is not simply the rung's,
which the stanzas must say.

### 3.2 Reset: an instruction, or a member write?

**Both.** `res` is the conventional set's and LDmicro's instruction. A `move 0 c.acc`
already works, because `.acc` is writable (decision 9). `res` earns its place by doing
the whole reset in one place: `.ov`, `.un` and `.dn`, and a timer's bits, which no
logic may write. It keeps the edge memory (Q3), so a box sitting on the eye at a reset
is not counted twice.

### 3.3 Edges: on the first scan, and across an edit

**Count on an edge, not while true.** IEC (CTU's CU is R_EDGE), the conventional set,
MatIEC (an internal R_TRIG) and LDmicro all agree, so there is no question to ask.

**The first scan.** `ons` passes no power on an instance's first scan, the conventional
ONS rule. IEC's R_TRIG does the opposite: it fires at the first execution after a cold
restart. **Recommendation (Q2, Q8):** one rule for every edge-sensing instruction,
which is `ons`, `osr`, `osf`, `ctu`, `ctd` and `tp`: none fires on the first scan. That
is the rule logex already has, and it is the conventional prescan's for CTU too ("the
.CU bit is set to prevent invalid counts", **unverified**).

**Across an online edit.** Decision 21's block list today holds `ons` storage bits. The
spike showed a counter that an edit adds while its rung is true counting at once:
`count` read 1 on the first scan after the switch. Putting the counter's name on the
same list, with a two-line change, stopped that count and still counted the next real
edge. The rule therefore generalises to "an edge the edit makes is not an edge", for
every edge memory: an `ons`/`osr`/`osf` storage bit, a counter's `.cu`/`.cd`, and a
`tp`'s `.en`.

Three refinements fall out:
- A change to the instruction's own preset is not a changed rung. The spike blocked a
  preset-only change.
- An edge memory that no logic can write needs only the rung test, not the "written
  through nothing else" test. The spike's counter, cleared by `move 0 boxes.acc`,
  counted two writes to `boxes`, so it would have been blocked on every edit.
- The report kind is `:ons_blocked` today, carrying the storage bit's value. For a
  counter the spike printed the whole map. Either widen it to carry the memory's value
  by path (`boxes.cu`) or add `:edge_blocked`. The recommendation is to widen it and
  keep the field name `ons_blocked`, since `%Logex.Instance{}` is public.

### 3.4 What a timer or counter passes on (Q6)

M1-6 left open whether the power after a `ton` is the rung's, as after `ote`, or the
timer's `.dn`, IEC's Q, and refused anything after it as the reversible choice. Nothing
in this pass's sources settles it; the conventional behaviour is still **unverified**.
**Recommendation:** extend the refusal to `tof tp rto ctu ctd`. `res`, `osr`, `osf`,
`lbl` and `jmp` pass the rung on, which is settled, so anything may follow them.

### 3.5 JMP and MCR in a language with function blocks (Q14, Q16)

A false `cal` already freezes a section with a named boundary: nothing in, nothing out,
timers catching up. A forward jump over rungs does the same thing within a routine,
and conventional programmers expect it. IEC has it, and it is cheap, as PLAN §8 says.
**Recommendation:** land forward `jmp`/`lbl` last, where dropping it costs nothing else.

MCR has no IEC basis, the vendors disagree on its mnemonic and its semantics, and TIA
dropped it. Its effect is "every rung in the zone sees a false rung-in", which is a
contact at the head of each rung, or a block. **Recommendation:** do not add MCR, and
record that in naming.md.

### 3.6 RTO across `restart/2` and `restart/3` (Q9)

`:warm` is `:cold` until `retain` lands (`Logex.Runtime.restart/3`'s doc, and the
`retain` diagnostic). On a conventional controller an RTO's time survives a power cycle
because the controller's memory does, not because of anything RTO does. IEC's only
retention is RETAIN on any instance.

The options are:
- (a) an `rto` resets on every restart, until `retain` arrives and covers it like any
  tag (recommended);
- (b) a warm restart keeps the members of every `rto`, which is retention for one type,
  before the general rule;
- (c) land `retain` in M3.

**Recommendation (a):** "retentive" in `rto` means across rung drops, as its stanza
will say, and one restart rule stays one rule.

### 3.7 Event tasks (Q5)

M2-6 warns about a `ton` under an event task. The four timers all need it, in their own
words. Edge-sensing instructions have a worse pitfall that nothing warns about today.

Take a counter of e-stop presses run by the e-stop's own event task. The task runs only
on the trigger's rising edges, so the counter's rung is 1 at every run and never falls.
With the first-scan rule, the first run is the instance's first scan. The counter
therefore never counts at all.

**Recommendation:** a configuration warning for every edge memory (an `ons`, `osr` or
`osf` bit; a counter; a `tp`) of an instance under an event task. It is read from a
`Walk` fact as the timers are, and it is a warning, not a refusal.

### 3.8 The reserved words

Each new mnemonic is reserved in any case and breaks any program with a tag of that
name: `ctu ctd ctud res tof tp rto add sub mul div mod neg abs osr osf jmp lbl`. `res`
(a result), `tp` (a test point), `add`, `sub`, `div` and `mod` are plausible tag names.
Each commit says so, as CLAUDE.md requires. Nothing to decide: the policy is settled
(PLAN §5).

---

## 4. The questions, each twice, grouped by item and in landing order

Each question is written twice: the technical record, then the plain-language version
to put to the maintainer. The plain versions are repeated verbatim in the final report.

### M3-1 · Counters

**Q1 (technical).** The counter types. The options:
- (A) `ctu` and `ctud`, one schema each. `ctd` runs only a `ctud`, and there is no
  down-only counter.
- (B) A, plus a `ctd` type with IEC CTD's semantics: count from `.pre` down to 0, `.dn`
  at `acc <= 0`. That gives `.dn` two meanings and makes `res` reload to `.pre` on one
  type only.
- (C) One counter type for all, run by any `ctu` and `ctd`.

In every option, a change of kind is a type change and needs a restart. Under C there
is no kind to change. **Recommend A.**

> **Q1 (plain).** *What kinds of counter should there be?* Picture the box counter on
> the conveyor: a photo-eye adds one for each box. Picture also a buffer table, where
> boxes are added at one end and taken off at the other.
> - **Option 1:** two kinds. The programmer writes "this counter only counts up" for the
>   box counter, and "this counter counts up and down" for the buffer. A reader can tell
>   from the declaration which one it is. Turning an up-only counter into an up-and-down
>   one while the plant runs needs a restart, so the count goes back to zero.
> - **Option 2:** the same two, plus a third kind that only counts down, starting full
>   and finishing at zero, such as "portions left in the hopper". It is familiar to
>   anyone who knows the international standard. But "done" would then mean "reached
>   the target" on two kinds and "reached zero" on the third, and "reset" would mean
>   "back to zero" on two and "back to full" on the third.
> - **Option 3:** one kind of counter that can always count both ways. It never needs a
>   restart to add counting down, but the declaration no longer says which way it
>   counts.
>
> **Recommendation: Option 1.** Every counter then means the same thing by "done" and by
> "reset", and "portions left" is still one subtraction away.

**Q2 (technical).** The first scan: a `ctu` whose rung is true on an instance's first
scan does not count. That is `ons`'s rule and the conventional prescan's. IEC's R_TRIG
would count. **Recommend not counting**, one rule for every edge.

> **Q2 (plain).** *A box is already sitting on the photo-eye when the controller starts.
> Is it counted?*
> - **Not counted:** the counter waits for the next box to arrive. This is how the
>   existing one-shot instruction already behaves at start-up.
> - **Counted:** the box on the eye counts as one the moment the program starts. This is
>   what the international standard's edge detector does.
>
> **Recommendation: not counted.** Then nothing that reacts to a change ever sees a
> change just because the controller started, and the counter agrees with the
> one-shot.

**Q3 (technical).** `res` keeps `.cu` and `.cd`, so a rung still true after a reset
does not count again. The conventional RES clears `.CU` and `.CD`, **unverified**.
**Recommend keeping them.**

> **Q3 (plain).** *The operator presses "reset batch" while a box is still sitting on
> the photo-eye. Does that box become box 1 of the new batch?*
> - **No:** after the reset the count shows 0, and the next box to arrive is box 1. The
>   box on the eye was already counted in the old batch.
> - **Yes:** the reset makes the counter forget the eye was blocked, so it counts the
>   box on the eye again and shows 1 at once.
>
> **Recommendation: no.** A box should never be counted twice because someone pressed
> reset.

**Q4 (technical).** A count at the dint's limit: saturate and set `.ov`/`.un`, latched
until `res`; or wrap as the conventional set does, with `.OV` (**unverified**). **Recommend
saturate.** It is IEC's bound, and Q10 asks the same of arithmetic.

> **Q4 (plain).** *What should a counter do if it ever reaches its largest possible
> number, a little over two billion?*
> - **Stop there and raise an "overflow" flag** that stays on until someone resets the
>   counter.
> - **Roll over** to the most negative number and keep counting, raising the same flag.
>   Some controllers do this.
>
> **Recommendation: stop and flag it.** A count that suddenly turns hugely negative can
> fool every comparison below it, and stopping at the top cannot.

**Q5 (technical).** A configuration warning for every edge memory (`ons osr osf`, a
counter, a `tp`) of an instance under an event task. A counter whose rung is its event
task's own trigger never counts: the rung is true at every run, and the first run is the
first scan. **Recommend the warning.**

> **Q5 (plain).** *Should logex warn when a counter is put on an "event" task, the kind
> that runs only when a signal switches on?* Example: the e-stop's own task counts how
> many times the e-stop was pressed. That task runs only at the moment the e-stop
> switches on, so the counter only ever sees "pressed" and never "released". It
> therefore never sees a new press, and the count stays at zero for ever.
> - **Warn:** the configuration check points this out, and the plant still runs.
> - **Say nothing**, as today for the one-shot instruction.
>
> **Recommendation: warn.** The mistake is silent and easy to make, and the timers
> already get the same kind of warning.

**Q6 (technical).** Power out after `ctu ctd` (and `tof tp rto`): keep M1-6's refusal,
which leaves open whether the power passed on is the rung's or the done bit. The
options were the rung's (conventional, **unverified**), `.dn` (IEC's Q), or refuse.
**Recommend refusing.**

> **Q6 (plain).** *May the programmer put something directly after a counter or timer on
> the same line?* For example, "photo-eye → counter → lamp" on one line, rather than
> putting the lamp on the next line, worked by the counter's "done" bit.
> - **Not allowed** (as today for the on-delay timer). The program must say which it
>   means by reading "done" on the next line.
> - **Allowed, with the lamp following the photo-eye**, as it would after an ordinary
>   output.
> - **Allowed, with the lamp following "done"**, as the international standard draws
>   it.
>
> **Recommendation: not allowed, for now.** Programmers from different backgrounds
> expect the other two meanings, and refusing now still lets either be allowed later
> without breaking any program.

### M3-2 · The other timers

**Q7 (technical).** The member that is `tp`'s pulse. The options:
- (A) `.tt`, timing, with `.dn` = finished while the rung holds;
- (B) `.dn`, keeping ".dn is IEC's Q" in every timer, so `.dn` is 1 *during* the pulse;
- (C) a new `.q`.

**Recommend A.** Each member keeps its conventional meaning, and (B)'s "done while
running" reads backwards.

> **Q7 (plain).** *A horn should sound for 3 seconds when a fault appears. The pulse
> timer gives that 3-second pulse. Which of its signals should the horn use?*
> - **"Timing":** on for the 3 seconds. "Done" then comes on when the 3 seconds are
>   over. The words mean what they mean on every other timer.
> - **"Done":** on for the 3 seconds. Every timer's "done" is then the signal you wire
>   to the device, but here "done" is on while the timer is still running.
> - **A new signal name used only by this timer**, such as "output".
>
> **Recommendation: "timing".** Then "done" never means "still running" on any timer,
> and the horn is wired to the signal that is on while the pulse runs.

**Q8 (technical).** Confirm Q2's rule for `tp`: no pulse on the first scan, even with
the fault present at start. IEC TP pulses. **Recommend confirming.** An alarm present
at start-up is shown by its own alarm bit, not by the horn's pulse.

> **Q8 (plain).** *The fault is already present when the controller starts. Does the
> horn give its 3-second blast?*
> - **No:** the same rule as the box counter. Nothing that reacts to a change fires just
>   because the controller started. The fault lamp, driven directly by the fault, still
>   lights.
> - **Yes:** the horn sounds at start-up for any fault already present.
>
> **Recommendation: no.** One start-up rule for everything is easier to trust, and the
> fault lamp still shows the fault.

**Q9 (technical).** An `rto`'s members across a restart. The options:
- (a) reset by every restart until `retain` lands;
- (b) a warm restart keeps them;
- (c) land `retain` now.

**Recommend (a).**

> **Q9 (plain).** *A lubrication timer adds up how long the conveyor motor has run, so
> the line can be greased every 100 hours. The motor stopping does not clear it; only a
> "greased" button does. What happens to the hours when the controller is restarted?*
> - **They go back to zero** on any restart, for now. A later piece of work would let
>   the programmer mark what must survive a restart, for this timer or anything else.
> - **They survive a "warm" restart**, but only for this kind of timer, until that later
>   work arrives.
> - **Do that later work now**, before the new timers.
>
> **Recommendation: back to zero for now.** One restart rule for everything is easier to
> trust, and keeping values across restarts deserves its own careful design, for every
> kind of value rather than one timer.

### M3-3 · Arithmetic

**Q10 (technical).** dint overflow. The options:
- wrap (the conventional set's value, **unverified**);
- saturate silently;
- saturate and pass no power (ENO).

**Recommend saturate with ENO.**

> **Q10 (plain).** *The fill valve adds each delivery to a running total. If the total
> ever passes the largest number logex can hold, a little over two billion, what
> happens?*
> - **It wraps round** to a huge negative number. Many controllers do this, and the "has
>   the total reached the limit?" test then gives the wrong answer.
> - **It stops at the largest number, silently.**
> - **It stops at the largest number, and on that scan the "add" switches off whatever
>   the programmer put after it on the line**, so the program can light a "total
>   overflow" lamp.
>
> **Recommendation: stop, and switch off what follows.** The total stays sensible, and
> the program can tell the operator.

**Q11 (technical).** A zero divisor at run time. The options:
- 0 and no power (IEC's MOD rule extended);
- leave the destination unchanged, with no power.

A literal 0 divisor is a compile error either way. **Recommend 0 and no power.**

> **Q11 (plain).** *The line works out "boxes per minute" by dividing a count by the
> minutes run. Just after start-up, the minutes are zero. What should the division
> give?*
> - **Zero**, and the rest of that line switches off for that scan, so the program can
>   tell that the answer is not real. This follows what the international standard
>   says for the remainder.
> - **Keep the last answer**, with the rest of the line switched off. The display
>   freezes at its old value.
>
> **Recommendation: zero.** A frozen old number looks like a real one, and zero plus
> the signal is honest. Dividing by a written-in zero is refused before the program
> runs.

**Q12 (technical).** The operation set. The recommendation:
- `add sub mul div mod` now;
- `neg` and `abs`, which the README lists as settled, now, each a cheap pair of clauses;
- `sqrt` deferred until a real type exists, because IEC's SQRT is ANY_REAL;
- `expt` stays deferred.

> **Q12 (plain).** *Which calculations should arrive now?* Add, subtract, multiply,
> divide and remainder, certainly. Two small extras are already promised in the README:
> "negate" (turn 5 into −5) and "absolute value" (turn −5 into 5). The README also
> promises square root, but logex numbers are whole numbers only, and a square root of
> a whole number is rarely whole.
>
> **Recommendation:** all of the first seven now, and square root later, when logex has
> numbers with fractions. Each new word stops being usable as a tag name, so a program
> with a tag called "add" or "mod" would need renaming.

### M3-4 · Coil one-shots

**Q13 (technical).** Add `osr`/`osf`, the IEC P/N coils (Table 62 f8/f9) in the
conventional set's two-operand form; or rely on `ons` + `ote` and `xio … ons`. They
differ in what passes on: `osr` passes the rung, and `ons` passes the pulse.
**Recommend adding them.** The standard has the element, and their storage bits reuse
every `ons` rule.

> **Q13 (plain).** *Should there be "pulse coils" as well as the existing one-shot?*
> Today a programmer who wants a one-scan pulse when the start button is pressed uses
> the one-shot, and the rest of that line then only sees the pulse. A pulse coil instead
> sets a separate "pulse" bit for one scan while the rest of the line carries on seeing
> the button. There would be one for "switched on" and one for "switched off".
> - **Add both.** Programmers from most backgrounds know them, and the standard has
>   them.
> - **Leave them out**, since the one-shot can already do the job on its own line.
>
> **Recommendation: add both.** They are small, familiar and standard, and they follow
> every rule the one-shot already follows.

### M3-5 · Control flow

**Q14 (technical).** Forward `jmp`/`lbl`: land them as M3-5, or defer them on the
grounds that a false `cal` already freezes a section. **Recommend landing them, last.**

> **Q14 (plain).** *Should the programmer be able to "skip ahead": jump over a group of
> lines when, say, the line is in manual mode?*
> - **Yes, forward only.** The skipped lines simply do not run that scan: their outputs
>   stay as they were. Jumping backwards, which could loop for ever, is refused.
> - **No.** The programmer puts the manual-mode logic in its own block and turns that
>   block off, which already does the same thing with a name on it.
>
> **Recommendation: yes, forward only, and last in the milestone.** Ladder programmers
> expect it, the standard has it, and leaving it to the end means dropping it costs
> nothing else.

**Q15 (technical).** A timer in skipped rungs: catch up when next run, as in a frozen
block (decision 8); or resume, as an edit's restore does (decision 23). **Recommend
catching up**, the same as a false `cal`.

> **Q15 (plain).** *The fan's run-on timer is in the skipped section. The line spends 10
> seconds in manual mode with the timer half done, then returns to auto. Does the timer
> count those 10 seconds?*
> - **Yes:** it catches up at once, exactly as a timer inside a switched-off block does
>   today.
> - **No:** it carries on from where it was, as if the 10 seconds never happened.
>
> **Recommendation: yes.** Skipping lines and switching off a block are the same idea,
> and should behave the same way.

**Q16 (technical).** MCR: do not add it. naming.md's `mcs … mce` changes from deferred
to "do not add". **Recommend not adding.**

> **Q16 (plain).** *Some controllers have a "master control zone": one switch that
> forces a whole group of lines off.* The vendors disagree on its name and on what
> "off" means: some hold their outputs, some switch them off. The newest controllers of
> the vendor that made it popular have dropped it, and the standard does not have it.
> In logex the same effect is one extra contact at the start of each line in the group,
> or a block switched off as a whole.
> - **Leave it out, for good.**
> - **Add it later.**
>
> **Recommendation: leave it out.** Each line saying for itself what switches it off is
> clearer than a zone, and no one is misled into treating it as a safety stop, which it
> never is.

---

## 5. The milestone's structure

**The order:** the design record, then M3-1 to M3-5, in that order.
- Counters come first because §8 ranks them decisive. They also build the per-type
  refactor (§1) with a type that keeps no time, which keeps "has a preset" apart from
  "times" from the start.
- Timers next, reusing it.
- Arithmetic third. It is independent, but brings negative literals, which change the
  golden record.
- The coil one-shots fourth, reusing the generalised block list.
- Control flow last.

Each item surveys its words in `docs/naming.md` first and lands green under the full
gate, with its mutation rows in each commit's message: every rule it adds reverted
alone, the suite judged by exit code. Each item is built as a gated series on a copy
before it lands, as M2's were.

The **design record** (one commit) puts the answers to §4 in PLAN.md §3, "Milestone 3",
and §4.9's edit rules for the new state in `docs/organisation.md`, as decisions from 67.

**M3-1 · Counters.** *Done when* a box counter in a `.ld` file — a `ctu` on a photo-eye
whose `.dn` lights a "case full" lamp at its preset, cleared by `res` from a button —
counts every rising edge exactly once over N seeded scans, none on the first scan and
none for a box on the eye at a reset; a `ctud` buffer count agrees with an oracle that
knows nothing of logex; and an online edit that raises the preset while boxes are
counted keeps the count, moves `.pre`, forecasts `.dn`, and counts no box at the switch
that was not a real edge.
1. the stanzas `ctu`, `ctd`, `ctud`, `res`, and the Counters table's logex column;
2. the per-type refactor of §1: the compiler's preset and path rules over a set of
   instructions, `Walk.presets/1` beside `Walk.timers/1`, the warning's words, the
   plan's per-type `.dn` forecast, resume trigger and edge memory. No behaviour
   changes;
3. `var c ctu` and `var c ctud`, members, and `ctu`;
4. `ctd`, with the agreeing-presets rule;
5. `res`, with the `{:reset, _}` slot that the walks count as a write but not a run;
6. the edge rule across an edit: counters on the block list, a preset-only change not
   counted as a changed rung, and the report;
7. the event-task warning for edge memories (Q5);
8. the host-contract property: generators, and a counter oracle on every accepted scan
   and edit step;
9. the Done-when, end to end;
10. the documents: the README (an example, the instruction table, and clearing the
    "Settled, not yet landed" bullet in part), CLAUDE.md, §4.9's table, and PLAN.

**M3-2 · The other timers.** *Done when* a fan's `tof` runs it on for its preset after
the motor stops, and two instances on 10 ms and 50 ms tasks stop the fan at the same
logical time, as decision 6 measured `ton`; a `tp` sounds a horn for exactly its preset
from a fault's rising edge, whatever the fault does meanwhile; an `rto` lubrication
timer keeps its time across the motor stopping and loses it only to `res` and a
restart; and the event-task warning names each.
1. the stanzas `tof`, `tp`, `rto`, and `res` widened;
2. `tof`;
3. `tp`, its edge on the block list;
4. `rto`;
5. `res` on every timer;
6. the edit rules per timer type: the forecast and the resume trigger, with growth
   tests in the timers;
7. the event-task warning widened;
8. the property's oracles;
9. the Done-when, with the two-rate measurement;
10. the documents.

**M3-3 · Arithmetic.** *Done when* a fill valve's total, `add total flow total` on every
scan of a 100 ms task, agrees with an Elixir oracle over seeded flows, and closes the
valve at a setpoint read with `ge`. A total driven past 2147483647, a `div` by a tag
that is 0, and a `mod` of a negative operand each give what the stanzas say, and no
value outside a dint ever reaches an env.
1. the stanzas `add sub mul div mod neg abs`;
2. negative literals: a lexer clause, `well_formed!/1` and `Declarations.check/1`
   widened, and the golden record regenerated where `-` appears, its diff read;
3. `add`, `sub`, `mul`, with the overflow rule;
4. `div`, `mod`, with the zero rule and the literal-zero refusal;
5. `neg`, `abs`;
6. the literal-only warning;
7. the property, with an arithmetic oracle and a bound check on every env;
8. the Done-when;
9. the documents.

**M3-4 · Coil one-shots.** *Done when* `osr` and `osf` give, on seeded inputs, the
pulses that `ons` and `xio … ons` give on their own rungs, pass on the power they
receive, never fire on a first scan, and an edit that adds or changes one blocks it
until a scan runs it, as decision 21 blocks an `ons`.
1. the stanzas;
2. `osr`;
3. `osf`;
4. the storage-bit rules shared with `ons`: the compiler, the warnings, and the
   configuration's message;
5. the block list;
6. the property;
7. the documents.

**M3-5 · Control flow.** *Done when* a forward `jmp` over a manual-mode section freezes
that section's outputs, counters and timers exactly as a false `cal` freezes a block;
a backward jump, a missing label and a label not first on its rung are each a located
diagnostic; and a program with no `jmp` scans within a measured bound of its cost
before.
1. the stanzas `jmp` and `lbl`, and the Program control table's MCR row changed to "do
   not add";
2. labels: the `{:label, _}` slot, the namespace, and `lbl`;
3. `jmp`, and the rung loop's skip;
4. the diagnostics and the warning;
5. the scan-cost growth test;
6. the property;
7. the Done-when;
8. the documents.

**Milestone 3 is done when** a small bottling line written in `.ld` files runs under a
`.logex` configuration through `Logex.Runtime.cycle/3`, against an oracle that knows
nothing of logex. The line has:
- a conveyor whose `ctu` counts bottles into cases;
- a fan run on by a `tof` after the motor stops;
- a horn pulsed by a `tp` on a jam;
- a fill valve whose `add`ed total closes it at a setpoint;
- an `osr` that steps a case counter;
- a manual-mode section skipped by `jmp`.

While it runs, it is edited through `Logex.Configuration.Edit` to change the case size
and the run-on time, with no count lost, no phantom count and no timer reset. The
Done-when tests check each piece against its rule.

---

## 6. The spike: a built-in `ctu` with no new mechanism

On the work clone, branch `m3-spike`, pushed as `backup/m3-design`. It is one commit
after `970dede`, and it lands nothing.

**What was built:**
- `FbType.ctu/0`, with members `pre acc cu dn ov`, in `builtins/0`;
- `"ctu"` in `@instructions`;
- `presets/2`, the path rule and `Walk.timers/1` widened from `:ton` to
  `[:ton, :ctu]`;
- two `evaluate/3` clauses;
- a stub stanza;
- `test/logex/m3_spike_test.exs`, with 11 tests.

**Results:**
- **It counts with no new mechanism.** It counts rising edges, not on the first scan,
  with `.dn` at the preset. The preset comes from the instruction through the compiler
  into the tag's initial `pre`, unchanged. `restart/3` puts it back.
- **Inside a user block** it is a member and runs. A frozen block holds it, and the
  spike measured an edge that came and went while the block was frozen being missed
  (`[0,1,1,1,1,1,2]`).
- **A type change from `ton` to `ctu`** is refused by the existing check:
  "`t` is a ton in the running program and a ctu in the candidate: a tag's type changes
  only with a restart".
- **A preset change through `Logex.Edit`** raised `FunctionClauseError` in
  `Logex.Edit.Plan.done/3`, the `.dn` forecast, which reads a timer's `.en`. With a
  forecast clause for the counter, decisions 23 and 27 carry it:
  - 3 → 5 is reported `[{:preset, "boxes", {3, 5}}]`;
  - a `.pre` that logic moved to 9 is kept, `{:preset_kept, "boxes", {9, 5}}`;
  - a `ctu` removed keeps its count frozen, and restored at 4 it is reported
    `{:preset, "boxes", {9, 4}}`.
- **The path rule** crashed in `follows/3`, whose message is hard-coded to `ton`. With
  the message per instruction it works.
- **The warning** for a counter no `ctu` runs reads "`c` is a ton, but no `ton` runs
  it: it never times". It must be worded per type.
- **A counter added while its rung is true counts at once**: `count` read 1 on the first
  scan after the switch. With the counter's name on the existing `ons_blocked` list,
  which took two lines in the plan's walk and one in the evaluator:
  - the added counter counted nothing at the switch and 1 at the next real edge;
  - an untouched counter was not blocked, and counted an edge at the switch.
- **That same block list blocked a preset-only change**, because the rung's text
  changed, and reported `:ons_blocked` carrying the whole counter map (§3.3's
  refinements).
- **The full suite** with the spike: 936/939. The three failures are deliberate surface
  pins that a real landing updates: `FbType.builtins/0 == %{"ton" => …}`, `FbType`'s
  function list, and a test that every mnemonic appears in a compile's IR.
  `api_contract_test.exs` did not notice the counter at all, because its generators do
  not produce one, which is commit 8's work.

**What it settles:**
- `Logex.FbType` and the state rules carry a counter.
- The work is the §1 refactor, mostly in `Logex.Edit.Plan` and `Logex.Walk`, not new
  machinery.
- Decision 21's block list generalises to every edge memory.

---

## 7. Risks, and what to spike next

**Risks:**
1. **`Logex.Edit.Plan` treats every built-in as a timer.** It is the largest risk, and
   the spike found it: an edit raised. The refactor (M3-1 commit 2) must land with the
   property's walk covering a counter's edit, or the next built-in finds the next
   assumption the same way.
2. **`Walk.timers/1` serves two readers.** Widened for the edit, it makes M2-6's warning
   fire on counters. Split it before either reader changes.
3. **Unbounded integers.** An arithmetic result outside a dint, written to the env,
   makes an edit restart the tag without a word (`fits?/2`). Every arithmetic write must
   be brought into a dint, and the property should assert that no env value leaves its
   type.
4. **Reserved words** (§3.8). Plausible tag names, `res tp add sub div mod`, break
   programs. Each commit says so; the README's example tags should be checked.
5. **Negative literals change the golden record.** CLAUDE.md requires that commit to be
   its own, with the diff read.
6. **The property's growth.** M1-6's oracle work was the bulk of its commit 7. Five
   families of oracles, timers on two clocks included, could double the suite's 53 s.
   Bound each walk's size, and keep `max_cases` in mind (at most 3 suites at once).
7. **Scan cost** from the jump's rung loop, and from the per-type lookups the refactor
   adds to the evaluator, if any. The evaluator's clauses dispatch on the symbol and
   need no lookup. Pin both with growth tests, as M1-6 measured 5.7%.
8. **Unverified conventional behaviour.** The pass could not check the conventional
   set's CTU first-scan rule, RES clearing `.CU`, TOF's `.ACC` at rest, RTO's cap and
   overflow wrapping. Each stanza marks them `unverified` and states logex's own choice,
   as the `ton` stanza did.
9. **`ons_blocked` changes meaning.** It is a public field of `%Logex.Instance{}` and a
   report kind. Widening it to every edge memory, rather than renaming it, keeps hosts
   working; the moduledoc and §4.9 must say so.

**What to spike next**, before each item's gated series:
- **`tof` and `tp` at two task rates**, decision 6's measurement: do two instances agree
  at every common time? The spike should also read MatIEC's `lib/timer.txt` TP and TOF
  state machines against §2's semantics.
- **The per-type refactor alone**, applied to `ton` only, under the full suite and the
  property, to show that it changes no behaviour.
- **The jump's rung loop**, measured on the README motor with no `jmp`, against
  `970dede`.
- **The arithmetic oracle**, seeded `add`/`mul` chains near the limits, to confirm the
  saturate-and-no-power rule and that no env value leaves a dint.
- **An `osr` beside an `ons`** on one storage bit, and on two, through the edit's block
  list, to confirm the generalised storage-bit rule needs nothing beyond §2.
