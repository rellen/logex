# Instruction naming survey

Every logex instruction is named after surveying what IEC 61131-3 and the major vendors
call the same operation. This file is that survey: the reference tables first, then one
stanza per mnemonic. It is **append-only** — a stanza with no implementation is fine and
encouraged, so an instruction can be surveyed long before it is built.

`test/logex/naming_test.exs` fails if a mnemonic reaches `@instructions` without a stanza
here.

## Why survey at all

logex is its own dialect and claims no conformance, so the survey is not a compliance
exercise — it is how the project avoids naming things by reflex. Two findings explain why
it has to be done rather than assumed:

- **IEC 61131-3 defines ladder contacts and coils as graphical elements with English
  names** — "Normally open contact", "SET (latch) coil" — and gives them no mnemonics at
  all (Ed 2:2003 §4.2.3–4.2.4 Tables 61/62; Ed 3:2013 Tables 75/76; Ed 4:2025 Tables
  74/75). For `xic` or `ote` there is no standard name to conform to.
- **Edition 4.0 (2025) removed Instruction List from the standard entirely.** Its Scope
  now reads *"This suite consists of the textual language structured text (ST), and the
  graphical languages, ladder diagram (LD) and function block diagram (FBD)"*, against
  Ed 3's *"two textual languages, Instruction List (IL) and Structured Text (ST)…"*.

So a mnemonic ladder language is *necessarily* a dialect. The point of surveying is to
know precisely what you are diverging from.

## The naming rule

Applied in order:

1. **If IEC 61131-3 names the operation** — as a standard function or standard function
   block — **use the IEC name, lowercased.** `ton tof tp`, `ctu ctd`, `eq ne lt gt le ge`,
   `move`, `add sub mul div mod`, `abs sqrt expt`, `shl shr rol ror`.
2. **If IEC supplies only a graphical element, use the clearest vendor mnemonic and say
   which one.** This keeps `xic xio ote otl otu`, and gives `ons osr osf rto res`.
3. **Never invent a readable word for a thing that already has a standard name.**
   `on_delay`, `rising` and `equal` are new names for old things: every reader who knows
   ladder has to translate, and every manual they own uses the other word. Readability is
   bought with comments and documentation, not by renaming the domain.

The two tiers are not imposed — they fall out of the data. A 2024 conformance sweep in a
mainstream vendor toolchain renamed sixteen ladder mnemonics *"to conform to IEC 61131-3
and PLCopen standards"*, and every one moved to the IEC name: ACS→ACOS, ASN→ASIN, ATN→ATAN, EQU→EQ,
FRD→BCD_TO, GEQ→GE, GRT→GT, LEQ→LE, LES→LT, LIM→LIMIT, MOV→MOVE, NEQ→NE, SQR→SQRT,
TOD→TO_BCD, TRN→TRUNC, XPY→EXPT. What was *not* renamed: XIC, XIO, OTE, OTL, OTU —
because IEC gives those only a picture.

## Adding a stanza

Copy the template, fill every dialect row, and mark anything you could not check
`unverified` rather than guessing. Read across instructions with
`grep -A9 '^### ' docs/naming.md`.

````markdown
### `mnemonic` — one-line gloss

| Dialect | Name there | Notes |
|---|---|---|
| logex | `mnemonic ops` | what it does here |
| IEC 61131-3 | | element / FB / function name + clause and table number, or `—` and what the standard has instead |
| North American convention | | current mnemonic + expansion; former name if renamed |
| Siemens STEP 7 / TIA Portal LAD | | classic and TIA separately wherever they differ |
| CODESYS | | element or operator name |
| Mitsubishi GX Works | | mnemonic + the manual's phrasing; note FX vs iQ-R where they differ |

**Chosen:** `mnemonic`
**Why:** what the alternatives were and what decided it.
**Checked:** YYYY-MM-DD — sources, with document numbers.
````

---

## Reference tables

Legend for the logex column: **bold** = the name to use; *(deferred)* = surveyed and named, not scheduled; *(none)* = deliberately not added, with the reason in notes.

The North American column gives the **current** mnemonic, with the former spelling in
parentheses where the 2024 conformance sweep renamed it. Siemens splits into classic STEP 7
(S7-300/400) and TIA Portal (S7-1200/1500) wherever they differ — that split is real and is
the single most common source of wrong "Siemens says X" claims.

### Contacts and coils

| Concept | IEC 61131-3 | North American | Siemens | CODESYS | Mitsubishi | logex | Notes |
|---|---|---|---|---|---|---|---|
| NO contact (test bit = 1) | **Normally open contact** `--\| \|--`, Ed2 T61.1 §4.2.3 / Ed3 T75 / Ed4 T74. Element, no mnemonic | XIC "Examine if Closed"; operand **Data bit, BOOL, tag** | classic `---\|  \|---`; TIA `---\| \|---` | Contact | LD "Load" (A contact); AND/OR in series/parallel position | **xic** (keep) | Only the North American set names the physical contact rather than the bit test. Mitsubishi bakes rung *position* into the mnemonic — do not copy that; `( \| )` already expresses position |
| NC contact (test bit = 0) | **Normally closed contact** `--\|/\|--`, Ed2 T61.3 | XIO "Examine If Open"; BOOL tag | classic/TIA `---\| / \|---` | negated contact | LDI "Load inverse" (B contact); ANI/ORI | **xio** (keep) | IEC defines NC as strictly complementary to NO. logex's are two independent *positive* tests — PLAN M1-4 |
| Non-retentive coil | **Coil** `--( )--`, Ed2 T62.1 §4.2.4: *"The state of the left link is copied to the associated Boolean variable **and to the right link**"* | OTE "Output Energize" — sets or clears on rung condition; cleared on false rung, prescan, postscan | classic `---(   )` Output Coil; TIA `---( )---` Assignment | Coil | OUT | **ote** (keep) | IEC's coil passes power flow through. logex's `ote` already does — so logex needs no Siemens-style midline output |
| Set / latch coil | **SET (latch) coil** `--(S)--`, Ed2 T62.3 | OTL "Output Latch"; false rung leaves the bit unchanged | classic `---( S )` Set Coil; TIA `---( S )---` Set output, SET_BF | Set Coil | SET | **otl** (keep) | The only row where IEC's own name contains the North American convention's word |
| Reset / unlatch coil | **RESET (unlatch) coil** `--(R)--`, Ed2 T62.4 | OTU "Output Unlatch" | classic `---( R )` Reset Coil — **its address may be a timer (T no.) or counter (C no.), reset to 0**; TIA `---( R )---`, RESET_BF | Reset Coil | RST — also the general device reset | **otu** (keep) | Classic Siemens' R coil is the closest vendor precedent for a standalone `res` |
| Negated coil | **Negated coil** `--(/)--`, Ed2 T62.2 | **none** — zero hits for "negated coil"/"OTN" in 927 pp of the instruction-set reference; the idiom is XIO | classic: **none** (place `---\|NOT\|---` before a coil); TIA `--( / )--` Negate assignment, a.k.a. "inverted output coil" | Negated coil | **none** — INV before OUT, or ALT to toggle | **otn** *(proposed)* | First concept where logex must coin: the standard has it, the North American convention has no mnemonic to copy |
| Invert power flow inline | **not in standard** — no NOT element in T61/T62. `NOT` was an IL operator only, and IL is gone in Ed 4 | **none** | classic `---\|NOT\|---` Invert Power Flow; TIA `--\|NOT\|--` Invert RLO / "NOT logic inverter" | negation is a modifier on a contact or coil, not an element | INV "Inverse" | **not** *(proposed)* | Useful, and the North American convention's vocabulary cannot name it — a the North American convention-reflex choice would have produced nothing |
| Midline output | not a distinct element — an IEC coil already copies left link to right link | none; OTE serves | classic `---( # )---` Midline Output; **absent from TIA S7-1200/1500** | not verified | not verified | **(none)** | Recorded so nobody adds a `#`. Two cells unverified |
| Bistable, **set** dominant | **SR**, inputs **S1, R** → Q1 (Ed2 T34, §2.5.2.3.1) | none — dominance is OTL/OTU ordering | **RS** is the set-dominant latch (S1/R) | SR (IEC library) | none — SET/RST ordering | **(none)** | **Trap.** Pin convention agrees (the dominant input carries the "1") but the block **names are swapped**: IEC's set-dominant block is SR, Siemens' is RS |
| Bistable, **reset** dominant | **RS**, inputs **S, R1** → Q1 | none | **SR** is the reset-dominant latch (S/R1) | RS | none | **(none)** | Never copy the SR/RS letters blind |
| Retentive / memory coil | **not in any current edition** — Ed2 T62 NOTE: *"Features 5, 6 and 7 of the first edition are deleted in this edition"* | none; OTL/OTU are the retentive pair | none — retention is a property of the variable/DB | none — RETAIN is a variable qualifier | none — SET/RST plus latch relay (L) devices | **(none)** | The industry moved retention from the coil to the variable. Ed 1's deleted features are commonly said to be `--(M)--`/`--(SM)--`/`--(RM)--`; **unverified** — only the deletion note was checked |

### Edge detection and one-shots

| Concept | IEC 61131-3 | North American | Siemens | CODESYS | Mitsubishi | logex | Notes |
|---|---|---|---|---|---|---|---|
| Rising-edge contact on an operand | **Positive transition-sensing contact** `--\|P\|--`, Ed2 T61.5 | **none** | TIA `--\|P\|--`; classic POS box | LD editor command **"Edge Detection – Rising Edge"** applied to a contact (implicit R_TRIG) | LDP / ANDP / ORP | **(none)** — compose `xic aa ons s1` | Corrected: CODESYS's LD *does* have a contact-level edge modifier |
| Falling-edge contact | **Negative transition-sensing contact** `--\|N\|--`, Ed2 T61.7 | none | TIA `--\|N\|--`; classic NEG box | "Edge Detection – Falling Edge" | LDF / ANDF / ORF | **(none)** — `xio aa ons s1` | The rising edge of NOT `aa` *is* the falling edge of `aa` |
| Rising one-shot to an output bit | **Positive transition-sensing coil** `--(P)--`, Ed2 T62.8: variable ON for one evaluation on an OFF→ON left link; *"the state of the left link is always copied to the right link"* | OSR "One Shot Rising" — storage bit + output bit; rung-condition-out follows rung-condition-in | TIA `--(P)--` Set operand on positive signal edge; **classic `---( P )---` is the RLO one-shot, a different thing** | R_TRIG instance | PLS | **osr storage out** | **Corrected:** this *is* in the standard. The original survey said it was not |
| Falling one-shot to an output bit | **Negative transition-sensing coil** `--(N)--`, Ed2 T62.9 | OSF "One Shot Falling" | TIA `--(N)--`; classic NEG | F_TRIG instance | PLF | **osf storage out** | Same correction |
| One-shot on the accumulated **rung condition** (inline, gates power flow) | **not in standard** — the transition-sensing contact senses a named operand, not the rung result | ONS "One Shot" — one user-named storage bit; set true on prescan so the first scan cannot fire | TIA P_TRIG "Scan RLO for positive signal edge"; classic `---( P )---` | no inline element; R_TRIG instance | MEP | **ons storage** | The genuinely-not-in-IEC one. the North American convention's user-named storage bit is exactly the design logex wants: cross-scan state as an ordinary tag in the flat env |
| Falling inline one-shot | not in standard | **none** — the asymmetry is real | TIA N_TRIG; classic `---( N )---` | F_TRIG instance | MEF | **onf storage** *(coinage)* | Name it after Siemens/Mitsubishi and document it as a logex invention |
| Edge-detection function block | **R_TRIG / F_TRIG** — CLK → Q | OSRI / OSFI — FBD/ST only, *"not available in ladder diagram"* | R_TRIG / F_TRIG (instance DB) | R_TRIG / F_TRIG | R_TRIG(_E) / F_TRIG(_E) | **(none)** | logex has no function-block language; `ons`/`osr`/`osf` cover it |

### Timers

| Concept | IEC 61131-3 | North American | Siemens | CODESYS | Mitsubishi | logex | Notes |
|---|---|---|---|---|---|---|---|
| On-delay | **TON** — Ed2 T37 §2.5.2.3.4 (Ed3 T46); IN/PT → Q/ET | TON (ladder only). **TONR = TON *with a Reset pin*, FBD/ST only — not retentive** | TIA: IEC box TON + coil `---( TON )---`; classic S5: S_ODT / `---( SD )---` | TON | native `OUT T0 K100`; FB library TON/TON_E/TON_HIGH/TON_HIGH_E | **ton** | The one mnemonic every party spells identically |
| Off-delay | **TOF** — Ed2 T37 | TOF; note the inverted `.DN` sense | TIA TOF + `---( TOF )---`; classic S_OFFDT / `---( SF )---` | TOF | no off-delay *device*, but **FX has STMR (FNC 65)**, a native ladder instruction whose `(d)+0` is an off-delay output; FB library TOF family | **tof** | **Corrected:** the original survey said Mitsubishi has no native off-delay ladder instruction |
| Pulse | **TP** — Ed2 T37 | **none** — build from ONS + TON/TOF | TIA TP + `---( TP )---`; classic S_PULSE / `---( SP )---`, S_PEXT / `---( SE )---` | TP | no pulse *device*; **FX STMR** gives one-shot outputs; FBs TP/TP_E/TP_HIGH/TP_HIGH_E (FX: TP/TP_E/TP_10/TP_10_E) | **tp** | Two letters breaks logex's three-char habit; it is the standard name, so take it |
| Retentive / accumulating on-delay | **not in standard** — T37 defines only TP/TON/TOF. RETAIN is power-fail retention of an instance, not accumulate-across-drops | RTO "Retentive Timer On"; RTOR is the FBD/ST form | **TONR** "Time accumulator" (Siemens extension); distinct from classic S_ODTS / `---( SS )---`, which *latches the start* | **none** in the Standard library | retentive device ST (`OUT ST0 K3`); FB TIMER_CONT_FB_M | **rto** | **Do not call it `tonr`.** Siemens TONR accumulates; the North American convention TONR is a plain TON with a reset pin. Same four letters, opposite meanings |
| Reset a timer | **not in standard** — no reset FB, no R pin; a TON resets only by driving IN false | RES | TIA `---( RT )---` / RESET_TIMER; **classic `---( R )` Reset Coil accepts a timer** | none | RST | **res** | Fits logex's output-instruction shape (`otl`/`otu`) far better than an IEC-style pin |
| Preset | PT (TIME / LTIME) | `.PRE`, DINT milliseconds; the 2025 TIMER_T type adds a TIME-typed `.PRE` | PT; classic S5TIME (BCD) | PT | K constant in `OUT T0 K100`; PT on the FBs | **`.pre`, integer ms** | Copying the North American convention's DINT-ms preset avoids dragging `T#5m30s` literals into the lexer |
| Elapsed | ET | `.ACC` | ET; classic BI / BCD words | ET | TN0 device; FB ValueOut | **`.acc`** | `.acc` over IEC's `et` for consistency with counters and CONTROL |
| Done bit | Q | `.DN` — **inverted on TOF** | Q | Q | a contact on the T device (TS0) | **`.dn`** | |
| Timing-in-progress | **not in standard** | `.TT` | none | none | none | **`.tt`** | Vendor-specific invention, genuinely useful, free once the struct exists. Document as non-portable |
| Enable bit | **not in standard** | `.EN` | none | none | timer coil device TC0 / FB `.Coil` | **`.en`** | Only the North American set and Mitsubishi expose the coil side, and Mitsubishi's is a reset handle |
| Time base / clock source | **deliberately unspecified**; PT/ET are TIME; Ed2 T37 NOTE makes the effect of changing PT mid-timing *"implementation-dependent"* | fixed 1 ms; `ACC = ACC + (current_time − last_time_scanned)`, with a 69-minute scan warning | TIME = 32-bit signed ms; LTIME to ns; classic S5TIME is BCD with a coarse base | TIME, 32-bit ms; effective resolution bounded by task cycle (*reasoning, not cited*) | per-device base: low-speed 100 ms default, high-speed 10 ms; 16-bit count caps the range | **integer ms, elapsed injected as a scan input** | the North American convention's delta-since-last-scan formula, with `now` supplied by the caller, is the only version that is a pure function of its inputs |
| Where state lives | an FB instance in a VAR block; `TMR1.Q`, `TMR1.ET` | a structured TIMER tag; `Timer_1.DN` | an IEC_TIMER in an instance DB; `#MyTimer.Q` | an FB instance; `TON1.Q` | a global device number split into TS0/TC0/TN0 | **named instance in env, dotted member access** | Three models exist; two of the three converge on `name.member`, which is what settles §4.3 |

### Counters

| Concept | IEC 61131-3 | North American | Siemens | CODESYS | Mitsubishi | logex | Notes |
|---|---|---|---|---|---|---|---|
| Up counter | **CTU** — Ed2 T36 §2.5.2.3.3: CU (R_EDGE), R, PV:INT → Q, CV; typed variants `_DINT/_LINT/_UDINT/_ULINT` | CTU (ladder only); COUNTER tag | TIA CTU (needs IEC_COUNTER instance); classic S_CU + `---( CU )` | CTU — **RESET not R, PV/CV are WORD not INT** | native `OUT C` (set value 0–65535); FB CTU(_E) | **ctu counter preset** | The most IEC-conformant vendor is the one that renamed the pins |
| Down counter | **CTD** — CD, LD, PV → Q (`CV <= 0`), CV. **No R input** | CTD — decrements `.ACC`; `.DN` still means `.ACC >= .PRE` | TIA CTD; classic S_CD + `---( CD )` | CTD — LOAD, Q when CV = 0 | none native; UDCNT1, or FB CTD(_E) | **ctd counter preset** | The zero test differs: IEC counts *down from PV*; the North American convention just decrements |
| Up/down counter | **CTUD** — CU, CD, R, LD, PV → QU, QD, CV | **not in ladder** — FBD/ST only (FBD_COUNTER) | TIA CTUD; classic S_CUD | CTUD | UDCNT1 / UDCNT2, or FB CTUD(_E) | **(none)** — `ctu` + `ctd` on one counter | the North American convention's own ladder skips it; that is the ladder-native idiom |
| Counter reset | **the R input** — not an instruction. CTD has no R; reload via LD | RES | the R input; **classic also `---( R )` applied to a C no.** | RESET input | RST — doubles as the general bit reset | **res counter** | the North American convention and Mitsubishi are the only ones with a standalone reset. Keeping `res` and `otu` separate, as the North American convention does, is the right call |
| Preset load (CV := PV) | **LD input on CTD/CTUD** — genuinely standard, but a *pin* | **no equivalent instruction** — MOV into `.PRE`/`.ACC` | classic: the S input / `---( SC )`; TIA: LD | LOAD input | none; the set value is an operand of `OUT C` | **(none)** — `move` into `.pre` | The pin most likely to be wrongly reported as absent from IEC |
| Preset / current / done | PV / CV / Q (QU, QD) | `.PRE` / `.ACC` / `.DN` | TIA: PV / CV / Q. **Classic Q means count ≠ 0** — not a comparison against the preset | PV / CV / Q | set value / current value / the C device's contact | **`.pre` `.acc` `.dn`** | Siemens classic's Q is the silent trap in this family: the same letter, a different predicate |
| Overflow / underflow | **not in standard.** The bodies bound counting with `CV < PVmax` / `CV > PVmin`, and the Table 36 NOTE makes *"the numerical values of the limit variables PVmin and PVmax … implementation-dependent"* | `.OV` / `.UN`, at ±2 147 483 647 | none | none | none | **(none)** | **Corrected:** IEC does *not* saturate at the data type's limits. The "nobody else has OV/UN" half is an absence argument — **partly unverified** |

### Comparison

| Concept | IEC 61131-3 | North American | Siemens | CODESYS | Mitsubishi | logex | Notes |
|---|---|---|---|---|---|---|---|
| = | **EQ** — a library *function* (Ed3 T33 p.91 / Ed4 T33 p.102), **not** an LD element; ST `=` | **EQ** (formerly EQU); LD + FBD, *"not available in structured text"*; Source A / Source B; also compares strings | TIA `CMP ==`, typed by operand data type; classic `CMP ==I / ==D / ==R` | EQ ("the IEC operator") | `LD=` / `AND=` / `OR=`, `_U` unsigned, `LDD=` 32-bit | **eq a b** | **The correction that matters most.** the North American convention renamed all six in that sweep *"to conform to IEC 61131-3 and PLCopen standards"* — the survey's implied the North American convention-vs-IEC contrast no longer exists |
| ≠ | **NE** — documented non-extensible | **NE** (formerly NEQ) | `CMP <>` | NE | `LD<>` | **ne a b** | |
| < | **LT** | **LT** (formerly LES) | `CMP <` | LT | `LD<` | **lt a b** | `lt aa bb` reads "aa < bb" — the North American convention, IEC and Mitsubishi all agree on that order |
| > | **GT** | **GT** (formerly GRT) | `CMP >` | GT | `LD>` | **gt a b** | |
| ≤ | **LE** | **LE** (formerly LEQ) | `CMP <=` | LE | `LD<=` | **le a b** | the instruction-set reference's LEQ page prints the rename as *"from LES to LE"* — a typo in the North American convention's own manual; the summary table gives LEQ→LE |
| ≥ | **GE** | **GE** (formerly GEQ) | `CMP >=` | GE | `LD>=` | **ge a b** | |
| Range test | **not in standard.** IEC's LIMIT (Ed3 T32) is a **clamp** returning a value, not a BOOL | **LIMIT** (formerly LIM); Low / Test / High. If Low > High the test wraps the signed number line and is true *outside* | TIA IN_RANGE (MIN/VAL/MAX); **none in classic** | none — compose GE and LE | ZCP band compare — an *output* instruction writing three bits | **in_range** *(deferred)* | **Trap sharpened by the fact-check:** the North American convention's current name `LIMIT` now collides head-on with IEC's LIMIT clamp. Avoid both `lim` and `limit` |
| Out-of-range | not in standard | none — LIMIT with inverted limits | TIA OUT_RANGE | none | ZCP result bits | **out_range** *(deferred)* | Only Siemens names it. the North American convention's operand-order trick is silently wrong when limits come from tags |
| Masked equal | not in standard — compose AND + EQ | MEQ (Source / Mask / Compare) | none | none | none (BKCMP is a *block* compare) | **meq** *(deferred, low)* | the North American convention-only. The three "none" cells argue from instruction lists — **partly unverified** |
| Expression compare | not in standard — an expression is ST syntax | CMP — **ladder only**; one Expression operand. Current operator list includes ACOS, ASIN, ATAN, ATAN2, BCD_TO, IsINF, IsNAN, SQRT, TRUNC and `&&`, `\|\|`, `^^`, `!` | none — SCL expression or chained boxes | none — write ST | **none on iQ-R.** FX's CMP is a different instruction | **defer** | Needs an expression sub-grammar with precedence — a language change, not an instruction |
| Three-way compare | not in standard | **none** — the North American convention's CMP is an expression box | none | none | **FX only:** CMP sets (d), (d)+1, (d)+2 for >, =, <. **Not on iQ-R or Q/L** | **do not add** | Listed so `cmp` is never given Mitsubishi's meaning by accident. Depends on consecutive-device addressing, which logex has not got |

### Arithmetic

| Concept | IEC 61131-3 | North American | Siemens | CODESYS | Mitsubishi | logex | Notes |
|---|---|---|---|---|---|---|---|
| Add | **ADD** (Ed3 T29, extensible); ST `+` | ADD | TIA ADD; classic ADD_I / ADD_DI / ADD_R | ADD | native `+`, `D+`, `B+`, `E+`; ADD(_E) | **add a b dst** | Unanimous. Fix arity at 3 — logex cannot mirror IEC's variadic ADD |
| Subtract | **SUB** (non-extensible); ST `-` | SUB | SUB | SUB | `-`, `D-`, `B-`; SUB(_E) | **sub a b dst** | |
| Multiply | **MUL** (extensible); ST `*` | MUL | MUL | MUL | `*`, `D*`, `B*`; MUL(_E) | **mul a b dst** | |
| Divide | **DIV**; ST `/`; integer division truncates toward zero | DIV | DIV | DIV | `/` — **writes the quotient to (d) and the remainder to (d)+1**; DIV(_E) | **div a b dst** (quotient only) | Names agree, semantics do not. Following IEC/the North American convention/Siemens here means *not* following MELSEC |
| Modulo | **MOD** (Ed3 T29; ST operator **feature 8**): `IF IN2=0 THEN OUT:=0 ELSE OUT := IN1-(IN1/IN2)*IN2` | MOD | TIA MOD; classic **MOD_DI only** | MOD — help says *"non-negative integer remainder"* | none native; MOD(_E) | **mod a b dst** | Name unanimous, **sign convention is not**. IEC's formula with truncating DIV is Elixir's `rem/2`, not `Integer.mod/2`. Put it in a test |
| Negate | **not a standard function** — only the ST unary minus (operator table **feature 4**) | NEG | TIA NEG "create twos complement"; classic NEG_I / NEG_DI / NEG_R | **none** — unary `-` in ST | NEG / DNEG | **neg src dst** | A three-vendor consensus with no standard function behind it. logex has no expression syntax to host a unary minus, so take the vendor name |
| Absolute value | **ABS** (Ed3 T28) | ABS | ABS | ABS | none native; ABS(_E) only | **abs src dst** | Mitsubishi reaches it only through the IEC library — itself evidence that IEC names win where no legacy mnemonic existed |
| Square root | **SQRT** (Ed3 T28) | **SQRT** (formerly SQR) | TIA SQRT — **and separately SQR, which means square (x²)** | SQRT | **no BIN integer sqrt at all.** iQ-R: ESQRT / EDSQRT (real), BSQRT / BDSQRT (BCD). Q/L: SQR / SQRD / BSQR / BDSQR. SQRT(_E) over REAL in the IEC library | **sqrt src dst** | **Never `sqr`**: pre-that sweep the North American convention = root, Siemens = square. **Corrected:** the survey's "SQRT/DSQRT (BIN)" was a fabricated mnemonic |
| Power | **EXPT** (Ed3 T29; ST `**`, operator **feature 3**) | **EXPT** (formerly XPY) | TIA EXPT; `x^y` inside CALCULATE | EXPT | EXPT(_E) | **expt** *(deferred)* | Another that sweep rename toward IEC |
| Compute from an expression | not in standard — ST `:=` covers it | CPT — **ladder only** | CALCULATE — **LAD/FBD only, not SCL** | none | none | **defer** | These exist precisely because ladder has no expression syntax. **Corrected:** CALCULATE is not an SCL instruction |

### Bitwise and shift

| Concept | IEC 61131-3 | North American | Siemens | CODESYS | Mitsubishi | logex | Notes |
|---|---|---|---|---|---|---|---|
| Word AND | **AND** (Ed3 T31, symbol `&`) — overloaded over ANY_BIT | AND "Bitwise And"; separate **BAND** for BOOL in FBD | TIA AND under "Word logic operations"; classic WAND_W / WAND_DW | AND | WAND / DAND / BKAND; AND(_E) | **wand a b dst** | IEC can reuse `AND` only because it is strongly typed. logex's env is untyped integers, so the reader is the type checker — and *every* vendor that put this on a rung disambiguated somehow |
| Word OR | **OR** (T31, `>=1`) | OR; BOR | TIA OR; classic WOR_W / WOR_DW | OR | WOR / DOR / BKOR | **wor a b dst** | Worst collision of the four: a bare `or` in a rung would read as a *branch*, which `( \| )` already means |
| Word XOR | **XOR** (T31, `=2k+1`) | XOR; BXOR | TIA XOR; classic WXOR_W | XOR | WXOR / DXOR / BKXOR | **wxor a b dst** | Least ambiguous, but splitting the prefix convention would be worse than the redundancy |
| Word NOT | **NOT** (T31; ST operator **feature 5**, "Complement NOT") | NOT; BNOT | TIA **INV** "create ones complement" — deliberately not "NOT"; classic INV_I / INV_DI | NOT | CML / DCML (complement transfer) | **wnot src dst** | Widest divergence in the set: NOT vs INV vs CML. Siemens' NEG (two's complement, arithmetic) / INV (ones complement, bitwise) split is the cleanest distinction anyone draws |
| Shift left by N | **SHL** (Ed3 T30; zero fill) | **none** — no shift-by-N anywhere in the instruction set | TIA SHL; classic SHL_W / SHL_DW | SHL | SFL native; SHL(_E) | **shl src n dst** | Verified by enumerating the whole current instruction set: no SHL/SHR/ROL/ROR |
| Shift right by N | **SHR** (T30; **zero fill — logical**, not arithmetic) | **none** — BSR is the array shift register | TIA SHR; classic SHR_W, and **SHR_I / SHR_DI sign-extend** | SHR | SFR; SHR(_E) | **shr src n dst** | Follow IEC and zero-fill, and say so in the docs |
| Rotate left / right | **ROL / ROR** (T30; circular, no carry) | **none** | TIA ROL / ROR; classic ROL_DW / ROR_DW | ROL / ROR | ROL/ROR (no carry) and RCL/RCR (through carry); ROL(_E) | **rol / ror** | Forces the word-width question — rotation is meaningless without a fixed width. A prerequisite decision, not a naming one |
| Bit field distribute | **not in standard** — compose SHR + AND + OR | BTD (Source, Source bit, Dest, Dest bit, Length 1–32); BTDT adds a Target | none — word logic plus SHL/SHR | none | none direct. **NDIS/NUNI split/combine in arbitrary bit widths; DIS/UNI are the 4-bit (nibble) pair** | **defer** | the North American convention-only, five operands, and decomposes exactly into `shl` + `wand` + `wor` |
| Array bit shift register | not in standard | BSL / BSR — **edge-triggered, CONTROL structure, one position per scan, across an array** | none | none | BSFR/BSFL, SFTR/SFTL, DSFR/DSFL | **defer** | Listed separately so `BSL` is never mistaken for `SHL`. A sequencer, not a bitwise operator |

### Data movement and conversion

| Concept | IEC 61131-3 | North American | Siemens | CODESYS | Mitsubishi | logex | Notes |
|---|---|---|---|---|---|---|---|
| Scalar move | **MOVE** — a real standard function (selection functions): one `IN : ANY` → one `OUT : ANY`; ST `:=` | **MOVE** (formerly MOV); ladder only, *"not available in structured text"*; Source, Dest | TIA MOVE, `IN → OUT1`, SCL `out1 := in;`; classic L/T in STL | MOVE (IEC operator) | MOV / MOVP, DMOV | **`move src dst`** — rename from `mov` | Source-then-destination is unanimous, so logex's operand order was already right. The *name* was on the losing side of the that sweep drift |
| Operand order | source is MOVE's only argument, so in ST the destination lands on the **left** | source first, without exception: MOV, MVM, COP, CPS, FLL, SWPB | LAD boxes are source-in/dest-out; SCL uses named parameters | **split**: `dst := MOVE(src)`, but TwinCAT `MEMCPY(destAddr, srcAddr, n)` is **destination first** while CAA `MEM.Move(pSource, pDestination, n)` is **source first** | uniformly `(s)` then `(d)`; XCH is the exception because both operands are destinations | **source first, no exceptions** | The only reversals in the wild are ST assignment and C-derived pointer copies. Imitate neither |
| Masked move | not in standard — compose AND/OR/XOR | MVM (Source, Mask, Dest); MVMT adds a Target | none — word logic + MOVE | none | none (WAND/WOR; FX SMOV is digit-wise) | **`movm src mask dst`** *(deferred)* | the North American convention has the only first-class masked move; `movm` keeps the `mov`/`move` family readable |
| Block copy | not an instruction — Ed3 allows whole-array `:=` | COP(Source, Dest, Length) — **Length counts *destination* elements**; raw byte copy, no type conversion | MOVE_BLK(in, count, out); classic SFC20 BLKMOV | library only (MEMCPY, MEM.Move) — pointer-based, unchecked | BMOV (s)(d) n | **`copy src dst len`** *(deferred)* | Every vendor puts the count last. Document **which end** it counts — that is where the bugs are, not in the name |
| Fill | not in standard | FLL(Source, Destination, Length) | FILL_BLK / UFILL_BLK (in, count, out) | library only | FMOV (s)(d) n | **`fill value dst len`** *(deferred)* | Mitsubishi calls it FMOV, which reads like a move |
| Clear | not in standard — `x := 0` | CLR (Dest) — *"Clear Dest to 0"*; ladder only | none — MOVE a 0 | none | none — `MOV K0 (d)` | **`clr dst`** *(optional)* | `move 0 dst` already does the job; add only for readability of intent |
| Uninterruptible copy | not in standard | CPS | UMOVE_BLK / UFILL_BLK; classic SFC81 | none | none | **omit deliberately** | Exists only because real controllers preempt scans. logex has nothing to protect against |
| Byte swap / endianness | **in standard, as representation conversion**: Ed3 **Table 37 "Function for endianess conversion"** — TO_BIG_ENDIAN, TO_LITTLE_ENDIAN, FROM_BIG_ENDIAN, FROM_LITTLE_ENDIAN | SWPB(Source, Order Mode, Dest) — REVERSE / WORD / HIGHLOW | SWAP — `out := SWAP(in)` | library only | SWAP / DSWAP — **in place, one operand** | **`swpb src dst`** *(deferred)* | **Corrected:** the standard is not silent here. Take the North American convention/Siemens' src→dst shape, not Mitsubishi's in-place mutation |
| Exchange two variables | not in standard | none — temp tag + two moves | none | none | XCH (d1)(d2) / DXCH | **`xch a b`** *(deferred)* | This is why `swap` is a bad logex name for byte reversal: Siemens/Mitsubishi SWAP = reverse bytes, and *exchange* is XCH. Two operations, one English word |
| Numeric type conversion | **`<SOURCE>_TO_<TARGET>` is the standard scheme** (INT_TO_REAL, REAL_TO_INT); Ed3 adds overloaded `TO_<TARGET>` | no general instruction — implicit conversion, plus TRUNC, **TO_BCD**, **BCD_TO**, DEG, RAD | CONV box; SCL renders it literally as `out := <type>_TO_<type>(in)` | same `<type>_TO_<type>` scheme | one instruction per conversion: FLT/DFLT, INT/DINT, **DBL** (16→32) and **WORD** (32→16) | **`int_to_real src dst`** etc. *(deferred)* | Three of four ecosystems already use `<FROM>_TO_<TO>`. **Corrected:** there is no MELSEC `DWORD` conversion instruction |
| BCD ↔ binary | BCD_TO_** / **_TO_BCD forms | **TO_BCD** (formerly TOD), **BCD_TO** (formerly FRD); LD/FBD only | CONV with pseudo-types BCD16 / BCD32 | library | BCD/DBCD, BIN/DBIN | **`int_to_bcd` / `bcd_to_int`** *(deferred)* | FRD read like "from decimal" but converted *from BCD*. the North American convention fixed exactly this in that sweep |
| Real → integer rounding | TRUNC is standard. The REAL_TO_INT tie rule was **not verified** in the standard text | TRUNC (formerly TRN) — drops the fraction; no separate ROUND | ROUND = **nearest, ties to even** (`ROUND(10.5)=10`, `ROUND(11.5)=12`); TRUNC, CEIL, FLOOR | REAL_TO_INT documented as **half away from zero** — `REAL_TO_INT(-1.5) = -2` | INT/DINT rule **not verified** | **`trunc` `round` `ceil` `floor`** as separate instructions *(deferred)* | Two IEC-family systems give different answers for the same input. **Never hide a rounding mode inside a conversion name** |
| String move | MOVE / `:=` work on STRING like any type | MOVE handles String on 5380/5480/5580; COP/CPS elsewhere | **S_MOVE** — *"to copy a string, use S_MOVE"* | `:=` | `$MOV` | **`move` — no separate instruction** | Only Siemens and Mitsubishi split strings out, for memory-model reasons logex does not have |

### Program control

| Concept | IEC 61131-3 | North American | Siemens | CODESYS | Mitsubishi | logex | Notes |
|---|---|---|---|---|---|---|---|
| Conditional jump | **graphical only** — a Boolean signal line ending in a double arrowhead, `>>LABEL` (Ed2 §4.1.4, T58). IL had JMP/JMPC/JMPCN, **removed with IL in Ed 4** | JMP "Jump to Label" — ladder only | `---( JMP )`, "Jump if RLO = 1" (both classic and TIA); unconditional when placed on the left rail | "Jump" element | CJ (conditional), JMP (unconditional), SCJ; **classic ladder editor only** — the manual marks ST and FBD/LD "Not supported" | **`jmp <label>`**, forward-only at first | Stage the *capability*, not the name: reject a backward target with an explicit diagnostic rather than inventing a narrower mnemonic |
| Jump if false | **not in LD** — §4.1.4 transfers only when the line is 1. IL had JMPCN | none — condition with XIO | `---( JMPN )` "Jump-If-Not" (classic and TIA) | none | none — use an NC contact before CJ | **(none)** — `xio aa jmp done` | Only Siemens carries a distinct false-jump mnemonic; logex already has the polarity pair |
| Jump target / label | **"network label"**: an identifier or unsigned integer followed by `:` (Ed2 §4.1.2) — a property of the network, not an element | LBL — must be first on the rung; ≤ 40 chars | classic LABEL: **max 4 chars, first a letter**. **TIA: letters, or letters then digits; no documented length limit** | "Jump Label" | a pointer P0…Pn, shared with CALL and BREAK | **`lbl <name>`**, first on the rung | **Corrected:** the 4-character rule is classic STEP 7 only — an edition trap |
| Multi-way jump | not in standard — CASE is ST | none | TIA JMP_LIST, SWITCH | none | none | **(none)** | The one control-flow concept nobody else has |
| Subroutine call | no LD mnemonic — draw the block. IL had CAL (gone in Ed 4); ST is `Instance(args);` | **JSR** — a the North American convention-only coinage | `---( CALL )`, CALL_FC / CALL_FB / CALL_SFC / CALL_SFB | "Box" element | CALL(P), FCALL, ECALL, EFCALL | **`cal <routine>`** *(deferred)* | IEC, Siemens, CODESYS and Mitsubishi all say some form of *call*. This is where the survey overturns the reflex answer |
| Subroutine entry / parameters | not an instruction — VAR_INPUT is the interface | SBR | none — the block's declaration table | none — the POU's declaration part | none — the pointer P; args are the caller's (s1)–(s5) | **(none)** — declare the interface | the North American convention needs SBR only because a that vendor routine has no parameter list. Do not import a workaround for a design you did not adopt |
| Return | **genuinely standard, three ways**: the `<RETURN>` LD element (Ed2 T58.5–8), ST `RETURN;`, IL RET | RET | `---( RET )` (classic and TIA) | "Return" element | RET — a **body terminator**, not a conditional early exit | **`ret`** | The one row where IEC and all four vendors agree on both the name and (mostly) the meaning |
| Temporary end | not in standard — RETURN is the mechanism | TND "Temporary End" | none (`---( RET )` exits; STP stops the CPU) | none | FEND, END, GOEND | **(none)** — `ret` does this | the North American convention's own description of TND is precisely RETURN |
| Master control zone | **not in standard** — full-text search of Ed 2 for "master control" returns zero hits | MCR — **the same mnemonic opens and closes**; zones cannot nest; you must not jump into one | classic `---( MCR< )` / `---( MCR> )`, armed by `---( MCRA )` / `---( MCRD )`. **Legacy S7-300/400 only**, not in the S7-1200/1500 set | none | MC (start, level N0–N14) / MCR (end); **also available in ST** | **`mcs … mce`** *(deferred)*, deliberately not `mcr` | `MCR` means "end the zone" to Mitsubishi and Siemens but "either end" to the North American convention. The disabled-zone *semantics* also differ per vendor |
| Always false | not in standard | AFI "Always False" — ladder only | none | none | none (the habit is NOP) | **(none)** | Artefact of graphical editors. In a text dialect, a comment does this more honestly. the North American convention verified; the three "none" cells are absence arguments — **partly unverified** |
| No operation | not in LD (ST's empty statement `;` is a different, syntactic thing) | NOP | none in LAD (STL has `NOP 0` / `NOP 1`) | none | NOP, NOPLF | **(none)** | Exists because a ladder program there is a fixed array of steps. logex is text; a blank line is the no-op |
| Counted loop | **ST only** — `FOR … END_FOR` (also WHILE, REPEAT). **No LD looping element** | FOR — repeatedly executes a *routine*, not inline rungs | none in LAD — backward jump, or SCL FOR | none in LD | **FOR … NEXT, inline in the ladder** | **`for <n> … nxt`** *(deferred)* | Two genuinely different shapes. Mitsubishi's inline one is the only one logex could express |
| Break | ST **EXIT** | BRK — plain break | none | none | BREAK(P) — **a break *and* a jump** | **`brk`** *(deferred)* | Take the plain form; leave jumping to `jmp` |

### Branch structure (the rung's parallel legs)

| Concept | IEC 61131-3 | North American | Siemens | CODESYS | Mitsubishi | logex | Notes |
|---|---|---|---|---|---|---|---|
| Parallel branch group | **graphical** — parallel horizontal links between vertical links (Ed2 §4.1.2, T60). PLCopen TC6 XML models a rung as a connection graph with no textual delimiters | current L5K neutral text uses **brackets and commas**: `N: XIC(conveyor_a)[,XIC(input_1) XIO(input_2) ]OTE(light_1);` | graphical (TIA Openness XML: `<Part Name="Contact"/>`) | graphical | **no delimiters at all** — stack instructions ORB (OR Block), ANB (AND Block), MPS / MRD / MPP | **`( … \| … )`** | **`BST`, `NXB`, `BND` appear zero times in 927 pages of the instruction-set reference and are not the North American convention neutral-text spelling** (see §3). The one textual precedent, `[ , ]`, is unavailable to logex because it works only alongside parenthesised operands |

---


---

## Stanzas

One per mnemonic. The six below are the instructions logex ships today; all were
surveyed retrospectively, in the commit that introduced this file.

### `xic` — examine if closed (normally-open contact)

| Dialect | Name there | Notes |
|---|---|---|
| logex | `xic aa` | Passes power when `aa` is 1. |
| IEC 61131-3 | **Normally open contact**, `--\| \|--` | Graphical element, no mnemonic. Ed 2:2003 §4.2.3 Table 61 feature 1; Ed 3 Table 75; Ed 4 Table 74. The standard defines it as strictly complementary to the normally-closed contact. |
| North American convention | **XIC** — Examine If Closed | Operand `Data bit \| BOOL \| tag`. Not renamed in that conformance sweep, because IEC has no mnemonic to conform to. (vendor instruction-set reference, Sept 2025ch. 2.) |
| Siemens STEP 7 / TIA Portal LAD | classic `---\| \|---`; TIA `---\| \|---` | No mnemonic — a graphical contact in both. |
| CODESYS | **Contact** | Element name, following IEC Table 61. |
| Mitsubishi GX Works | **LD** "Load" (A contact); **AND**/**OR** in series/parallel position | Mitsubishi bakes rung *position* into the mnemonic. logex must not copy that — `( \| )` expresses position structurally. |

**Chosen:** `xic`
**Why:** No IEC name exists to take (rule 2 applies). Of the vendor mnemonics, Mitsubishi's `LD` is positional and would collide with a future load or move; Siemens and CODESYS have no word at all. the North American convention's is the only usable token, and it keeps symmetry with `xio`. Grandfathered: see the note under `ote`.
**Checked:** 2026-08-30 — IEC 61131-3:2003 §4.2.3 Table 61; the vendor instruction-set reference (Sept 2025 revision); Mitsubishi MELSEC iQ-R Programming Manual SH(NA)-081266ENG.

### `xio` — examine if open (normally-closed contact)

| Dialect | Name there | Notes |
|---|---|---|
| logex | `xio aa` | Passes power when `aa` is 0. |
| IEC 61131-3 | **Normally closed contact**, `--\|/\|--` | Ed 2:2003 Table 61 feature 3. Defined as the strict complement of the NO contact. |
| North American convention | **XIO** — Examine If Open | Operand `Data bit \| BOOL \| tag`. |
| Siemens STEP 7 / TIA Portal LAD | `---\| / \|---` | Graphical in both. |
| CODESYS | **negated contact** | A modifier on a contact, not a separate element. |
| Mitsubishi GX Works | **LDI** "Load inverse" (B contact); **ANI**/**ORI** | Same positional problem as `LD`. |

**Chosen:** `xio`
**Why:** Rule 2, and symmetry with `xic`. **Known divergence:** IEC defines NC as the strict complement of NO; logex's `xic` and `xio` are two independent *positive* tests, so a tag holding anything outside `{0,1}` reads false for both. That is a defect, not a dialect choice — see `PLAN.md` M1-4.
**Checked:** 2026-08-30 — as `xic`.

### `ote` — output energize (non-retentive coil)

| Dialect | Name there | Notes |
|---|---|---|
| logex | `ote xx` | Writes 1 on a true rung, **0 on a false rung**; passes power through unchanged. |
| IEC 61131-3 | **Coil**, `--( )--` | Ed 2:2003 §4.2.4 Table 62 feature 1: *"The state of the left link is copied to the associated Boolean variable **and to the right link**."* Note the second half — an IEC coil passes power through, which is why logex needs no Siemens-style midline output. The textual equivalent is ST assignment `xx := …;`. IL's `ST` was the nearest mnemonic, and IL is gone as of Ed 4.0. |
| North American convention | **OTE** — Output Energize | *"sets or clears the data bit based on rung condition."* Cleared on a false rung, and on prescan and postscan. Not renamed in that sweep. |
| Siemens STEP 7 / TIA Portal LAD | classic **Output Coil** `---(   )`; TIA **Assignment** `---( )---` | Same false-rung behaviour. SCL equivalent `out := …;`. |
| CODESYS | **Coil** *(unverified)* | Expected to follow IEC Table 62. `content.helpme-codesys.com` returned HTTP 403 to automated fetches — do not repeat as fact until someone opens the help directly. |
| Mitsubishi GX Works | **OUT** | *"Outputs the operation result to the specified device."* Overloaded by operand type: `OUT T` is a timer, `OUT C` a counter. |

**Chosen:** `ote`
**Why:** All five dialects agree exactly on the semantics and share no name. There was no IEC name available — the standard's name for this is a picture, and its one textual mnemonic (`ST`) was removed in Ed 4.0 — so rule 2 applies. Siemens' *Assignment* is a phrase, not a token; Mitsubishi's `OUT` is overloaded across timers, counters and annunciators. `ote` keeps the three-way symmetry with `otl`/`otu`, which is the more valuable alignment: IEC itself names those two *"SET (latch) coil"* and *"RESET (unlatch) coil"*, so latch/unlatch is the one place logex and the standard already agree.

**Grandfathering note.** `xic xio ote otl otu` are a closed, deliberate borrowing from one vendor's mnemonic set, kept because the survey found nothing better to migrate to — IEC names them only as English phrases, Siemens and CODESYS have no mnemonics, and Mitsubishi's set is positional. They are **not** a precedent that the next instruction should also come from the North American convention; rule 1 governs everything new.
**Checked:** 2026-08-30 — IEC 61131-3:2003 §4.2.4 Table 62 (read directly); IEC 61131-3:2025 Ed 4.0 publisher preview (Scope, table list); the vendor instruction-set reference; Siemens A5E02486680 and the classic S7-300/400 LAD manual; Mitsubishi SH(NA)-081266ENG. CODESYS **unverified** (HTTP 403).

### `otl` — output latch (set coil)

| Dialect | Name there | Notes |
|---|---|---|
| logex | `otl xx` | Writes 1 on a true rung; leaves the tag unchanged on a false rung. |
| IEC 61131-3 | **SET (latch) coil**, `--(S)--` | Ed 2:2003 Table 62 feature 3. The only row where IEC's own name contains the North American convention's word. |
| North American convention | **OTL** — Output Latch | A false rung leaves the bit unchanged. |
| Siemens STEP 7 / TIA Portal LAD | classic **Set Coil** `---( S )`; TIA **Set output** `---( S )---`, `SET_BF` | |
| CODESYS | **Set Coil** | |
| Mitsubishi GX Works | **SET** | |

**Chosen:** `otl`
**Why:** Rule 2, and symmetry with `ote`/`otu`. IEC's parenthetical *"(latch)"* is the strongest available evidence that "latch" is the shared word for this concept.
**Checked:** 2026-08-30 — as `ote`.

### `otu` — output unlatch (reset coil)

| Dialect | Name there | Notes |
|---|---|---|
| logex | `otu xx` | Writes 0 on a true rung; leaves the tag unchanged on a false rung. |
| IEC 61131-3 | **RESET (unlatch) coil**, `--(R)--` | Ed 2:2003 Table 62 feature 4. |
| North American convention | **OTU** — Output Unlatch | |
| Siemens STEP 7 / TIA Portal LAD | classic **Reset Coil** `---( R )` — its address **may be a timer or counter**, reset to 0; TIA `---( R )---`, `RESET_BF` | The closest vendor precedent for a future standalone `res`. |
| CODESYS | **Reset Coil** | |
| Mitsubishi GX Works | **RST** | Also the general device reset. |

**Chosen:** `otu`
**Why:** Rule 2, and symmetry with `otl`.
**Checked:** 2026-08-30 — as `ote`.

### `mov` — move a value into a tag

| Dialect | Name there | Notes |
|---|---|---|
| logex | `mov 123 hh`, `mov aa hh` | Source then destination. Copies an integer literal or a tag into a tag. |
| IEC 61131-3 | **MOVE** | A standard function, not a graphical element. ST assignment `:=` is the idiomatic form. |
| North American convention | **MOVE** (formerly **MOV**) | Renamed in the 2024 conformance sweep *"to conform to IEC 61131-3 and PLCopen standards"*. Operand order `MOVE(Source, Dest)`. |
| Siemens STEP 7 / TIA Portal LAD | **MOVE** | `IN` → `OUT`, i.e. source then destination. |
| CODESYS | **MOVE** | IEC standard function. |
| Mitsubishi GX Works | **MOV** | `MOV s d` — source then destination. |

**Chosen:** `mov` — **but see below.**
**Why:** `mov` came from a vendor mnemonic set that has since retired it. Every dialect surveyed, IEC included, now spells this `MOVE`; the operand order is source-then-destination everywhere, so logex's `mov 123 hh` is correct on the semantics that actually bite. Under rule 1 the name should be **`move`**: IEC names this operation, so the IEC name wins. Keeping `mov` pins logex's dialect to a spelling its own source has abandoned.

**Status: recommended, not applied.** Renaming is a source-language break and is deliberately not bundled with this survey. `PLAN.md` schedules it alongside the M1-2 validator, so the unknown-mnemonic diagnostic can carry *"did you mean `move`?"* — cheaper than an alias, and it exercises the validator.
**Checked:** 2026-08-30 — the vendor instruction-set reference (Sept 2025 revision), rename list and MOVE operand table; IEC 61131-3 standard function library; Siemens A5E02486680; Mitsubishi SH(NA)-081266ENG.
