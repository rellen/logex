# Instruction naming survey

Every logex instruction is named after surveying what IEC 61131-3 and the major vendors
call the same operation. This file is that survey: the reference tables first, then one
stanza per mnemonic, declaration word or word that heads a file. It is **append-only** — a
stanza with no implementation is fine and encouraged, so an instruction can be surveyed
long before it is built.

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
`unverified` rather than guessing. New stanzas go at the **end of the file**, under
`## Stanzas` — the file is append-only and the reference tables above stay where they are.
A stanza is owed by anything that becomes a key of `@instructions`, by each section or
type word of a declaration line, and by each word that heads a file of a kind other than a
program, `function_block` among them (`Logex.Declarations.kinds/0`); syntax tokens like the
branch delimiters are not words and need none. Read across stanzas with
`sed -n '/^## Stanzas/,$p' docs/naming.md | grep '^### '` — the reference tables above also
use `###` headings, so a bare grep matches those too.

````markdown
### `mnemonic` — one-line gloss

| Dialect | Name there | Notes |
|---|---|---|
| logex | `mnemonic ops` | what it does here |
| IEC 61131-3 | | element / FB / function name + clause and table number, or `—` and what the standard has instead |
| Conventional | | current mnemonic + expansion; former name if renamed |
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

The **Conventional** column is the mainstream mnemonic ladder vocabulary that logex's own
names were borrowed from; it is left unattributed deliberately, while the other three
vendors are named. **That is a project policy, not an accident of this table** — keep it
out of prose too, here and in the other documents, and do not "helpfully" restore it. Rule
2 below says to name which vendor a mnemonic came from; for this one column, "the
conventional set" is that name. It gives the **current** mnemonic, with the former spelling in
parentheses where the 2024 conformance sweep renamed it. Siemens splits into classic STEP 7
(S7-300/400) and TIA Portal (S7-1200/1500) wherever they differ — that split is real and is
the single most common source of wrong "Siemens says X" claims.

**Survey scope for the Conventional column.** Unless a row says otherwise, it was checked
against that vendor's **current** controller family: the Sept 2025 import/export reference
(385 pp) and ladder-diagram programming manual first, because those are the two that discuss
rung structure, then the 927-page instruction-set reference as a supporting check. The
vendor also has **earlier** families with their own mnemonics, and the Branch structure row
below is where that bit — a negative established only against the current family was written
as though it covered the vendor, and stood until someone who had used the earlier software
said otherwise. Name the generation in any row whose answer depends on it, and scope a
negative to what was actually read.

**And check that the document could have answered.** Grepping a reference for an absent
mnemonic proves nothing unless the same text mentions the *concept*. The instruction-set
reference is 927 pages about a ladder language whose extracted text contains the word
"branch" zero times — branch structure is not an instruction there, so it is a weak witness
on branch spelling however many pages it runs to. The import/export reference says "branch"
104 times and the ladder-diagram manual 15; those are the two whose silence means something.
Cite the document that had something to say.

### Contacts and coils

| Concept | IEC 61131-3 | Conventional | Siemens | CODESYS | Mitsubishi | logex | Notes |
|---|---|---|---|---|---|---|---|
| NO contact (test bit = 1) | **Normally open contact** `--\| \|--`, Ed2 T61.1 §4.2.3 / Ed3 T75 / Ed4 T74. Element, no mnemonic | XIC "Examine if Closed"; operand **Data bit, BOOL, tag** | classic `---\|  \|---`; TIA `---\| \|---` | Contact | LD "Load" (A contact); AND/OR in series/parallel position | **xic** (keep) | Only the conventional set names the physical contact rather than the bit test. Mitsubishi bakes rung *position* into the mnemonic — do not copy that; `( \| )` already expresses position |
| NC contact (test bit = 0) | **Normally closed contact** `--\|/\|--`, Ed2 T61.3 | XIO "Examine If Open"; BOOL tag | classic/TIA `---\| / \|---` | negated contact | LDI "Load inverse" (B contact); ANI/ORI | **xio** (keep) | IEC defines NC as strictly complementary to NO. logex's were two independent *positive* tests until M1-4 made `xio` the negation of `xic` |
| Non-retentive coil | **Coil** `--( )--`, Ed2 T62.1 §4.2.4: *"The state of the left link is copied to the associated Boolean variable **and to the right link**"* | OTE "Output Energize" — sets or clears on rung condition; cleared on false rung, prescan, postscan | classic `---(   )` Output Coil; TIA `---( )---` Assignment | Coil | OUT | **ote** (keep) | IEC's coil passes power flow through. logex's `ote` already does — so logex needs no Siemens-style midline output |
| Set / latch coil | **SET (latch) coil** `--(S)--`, Ed2 T62.3 | OTL "Output Latch"; false rung leaves the bit unchanged | classic `---( S )` Set Coil; TIA `---( S )---` Set output, SET_BF | Set Coil | SET | **otl** (keep) | The only row where IEC's own name contains the conventional set's word |
| Reset / unlatch coil | **RESET (unlatch) coil** `--(R)--`, Ed2 T62.4 | OTU "Output Unlatch" | classic `---( R )` Reset Coil — **its address may be a timer (T no.) or counter (C no.), reset to 0**; TIA `---( R )---`, RESET_BF | Reset Coil | RST — also the general device reset | **otu** (keep) | Classic Siemens' R coil is the closest vendor precedent for a standalone `res` |
| Negated coil | **Negated coil** `--(/)--`, Ed2 T62.2 | **none** — zero hits for "negated coil"/"OTN" in 927 pp of the instruction-set reference; the idiom is XIO | classic: **none** (place `---\|NOT\|---` before a coil); TIA `--( / )--` Negate assignment, a.k.a. "inverted output coil" | Negated coil | **none** — INV before OUT, or ALT to toggle | **otn** *(proposed)* | First concept where logex must coin: the standard has it, the conventional set has no mnemonic to copy |
| Invert power flow inline | **not in standard** — no NOT element in T61/T62. `NOT` was an IL operator only, and IL is gone in Ed 4 | **none** | classic `---\|NOT\|---` Invert Power Flow; TIA `--\|NOT\|--` Invert RLO / "NOT logic inverter" | negation is a modifier on a contact or coil, not an element | INV "Inverse" | **not** *(proposed)* | Useful, and the conventional set's vocabulary cannot name it — a reflex choice from that column would have produced nothing |
| Midline output | not a distinct element — an IEC coil already copies left link to right link | none; OTE serves | classic `---( # )---` Midline Output; **absent from TIA S7-1200/1500** | not verified | not verified | **(none)** | Recorded so nobody adds a `#`. Two cells unverified |
| Bistable, **set** dominant | **SR**, inputs **S1, R** → Q1 (Ed2 T34, §2.5.2.3.1) | none — dominance is OTL/OTU ordering | **RS** is the set-dominant latch (S1/R) | SR (IEC library) | none — SET/RST ordering | **(none)** | **Trap.** Pin convention agrees (the dominant input carries the "1") but the block **names are swapped**: IEC's set-dominant block is SR, Siemens' is RS |
| Bistable, **reset** dominant | **RS**, inputs **S, R1** → Q1 | none | **SR** is the reset-dominant latch (S/R1) | RS | none | **(none)** | Never copy the SR/RS letters blind |
| Retentive / memory coil | **not in any current edition** — Ed2 T62 NOTE: *"Features 5, 6 and 7 of the first edition are deleted in this edition"* | none; OTL/OTU are the retentive pair | none — retention is a property of the variable/DB | none — RETAIN is a variable qualifier | none — SET/RST plus latch relay (L) devices | **(none)** | The industry moved retention from the coil to the variable. Ed 1's deleted features are commonly said to be `--(M)--`/`--(SM)--`/`--(RM)--`; **unverified** — only the deletion note was checked |

### Edge detection and one-shots

| Concept | IEC 61131-3 | Conventional | Siemens | CODESYS | Mitsubishi | logex | Notes |
|---|---|---|---|---|---|---|---|
| Rising-edge contact on an operand | **Positive transition-sensing contact** `--\|P\|--`, Ed2 T61.5 | **none** | TIA `--\|P\|--`; classic POS box | LD editor command **"Edge Detection – Rising Edge"** applied to a contact (implicit R_TRIG) | LDP / ANDP / ORP | **(none)** — compose `xic aa ons s1` | Corrected: CODESYS's LD *does* have a contact-level edge modifier |
| Falling-edge contact | **Negative transition-sensing contact** `--\|N\|--`, Ed2 T61.7 | none | TIA `--\|N\|--`; classic NEG box | "Edge Detection – Falling Edge" | LDF / ANDF / ORF | **(none)** — `xio aa ons s1` | The rising edge of NOT `aa` *is* the falling edge of `aa` |
| Rising one-shot to an output bit | **Positive transition-sensing coil** `--(P)--`, Ed2 T62.8: variable ON for one evaluation on an OFF→ON left link; *"the state of the left link is always copied to the right link"* | OSR "One Shot Rising" — storage bit + output bit; rung-condition-out follows rung-condition-in | TIA `--(P)--` Set operand on positive signal edge; **classic `---( P )---` is the RLO one-shot, a different thing** | R_TRIG instance | PLS | **osr storage out** | **Corrected:** this *is* in the standard. The original survey said it was not |
| Falling one-shot to an output bit | **Negative transition-sensing coil** `--(N)--`, Ed2 T62.9 | OSF "One Shot Falling" | TIA `--(N)--`; classic NEG | F_TRIG instance | PLF | **osf storage out** | Same correction |
| One-shot on the accumulated **rung condition** (inline, gates power flow) | **not in standard** — the transition-sensing contact senses a named operand, not the rung result | ONS "One Shot" — one user-named storage bit; set true on prescan so the first scan cannot fire | TIA P_TRIG "Scan RLO for positive signal edge"; classic `---( P )---` | no inline element; R_TRIG instance | MEP | **ons storage** | The genuinely-not-in-IEC one. the conventional set's user-named storage bit is exactly the design logex wants: cross-scan state as an ordinary tag in the flat env |
| Falling inline one-shot | not in standard | **none** — the asymmetry is real | TIA N_TRIG; classic `---( N )---` | F_TRIG instance | MEF | **onf storage** *(coinage)* | Name it after Siemens/Mitsubishi and document it as a logex invention |
| Edge-detection function block | **R_TRIG / F_TRIG** — CLK → Q | OSRI / OSFI — FBD/ST only, *"not available in ladder diagram"* | R_TRIG / F_TRIG (instance DB) | R_TRIG / F_TRIG | R_TRIG(_E) / F_TRIG(_E) | **(none)** | logex has no function-block language; `ons`/`osr`/`osf` cover it |

### Timers

| Concept | IEC 61131-3 | Conventional | Siemens | CODESYS | Mitsubishi | logex | Notes |
|---|---|---|---|---|---|---|---|
| On-delay | **TON** — Ed2 T37 §2.5.2.3.4 (Ed3 T46); IN/PT → Q/ET | TON (ladder only). **TONR = TON *with a Reset pin*, FBD/ST only — not retentive** | TIA: IEC box TON + coil `---( TON )---`; classic S5: S_ODT / `---( SD )---` | TON | native `OUT T0 K100`; FB library TON/TON_E/TON_HIGH/TON_HIGH_E | **ton** | The one mnemonic every party spells identically |
| Off-delay | **TOF** — Ed2 T37 | TOF; note the inverted `.DN` sense | TIA TOF + `---( TOF )---`; classic S_OFFDT / `---( SF )---` | TOF | no off-delay *device*, but **FX has STMR (FNC 65)**, a native ladder instruction whose `(d)+0` is an off-delay output; FB library TOF family | **tof** | **Corrected:** the original survey said Mitsubishi has no native off-delay ladder instruction |
| Pulse | **TP** — Ed2 T37 | **none** — build from ONS + TON/TOF | TIA TP + `---( TP )---`; classic S_PULSE / `---( SP )---`, S_PEXT / `---( SE )---` | TP | no pulse *device*; **FX STMR** gives one-shot outputs; FBs TP/TP_E/TP_HIGH/TP_HIGH_E (FX: TP/TP_E/TP_10/TP_10_E) | **tp** | Two letters breaks logex's three-char habit; it is the standard name, so take it |
| Retentive / accumulating on-delay | **not in standard** — T37 defines only TP/TON/TOF. RETAIN is power-fail retention of an instance, not accumulate-across-drops | RTO "Retentive Timer On"; RTOR is the FBD/ST form | **TONR** "Time accumulator" (Siemens extension); distinct from classic S_ODTS / `---( SS )---`, which *latches the start* | **none** in the Standard library | retentive device ST (`OUT ST0 K3`); FB TIMER_CONT_FB_M | **rto** | **Do not call it `tonr`.** Siemens TONR accumulates; the conventional set TONR is a plain TON with a reset pin. Same four letters, opposite meanings |
| Reset a timer | **not in standard** — no reset FB, no R pin; a TON resets only by driving IN false | RES | TIA `---( RT )---` / RESET_TIMER; **classic `---( R )` Reset Coil accepts a timer** | none | RST | **res** | Fits logex's output-instruction shape (`otl`/`otu`) far better than an IEC-style pin |
| Preset | PT (TIME / LTIME) | `.PRE`, DINT milliseconds; the 2025 TIMER_T type adds a TIME-typed `.PRE` | PT; classic S5TIME (BCD) | PT | K constant in `OUT T0 K100`; PT on the FBs | **`.pre`, integer ms** | Copying the conventional set's DINT-ms preset avoids dragging `T#5m30s` literals into the lexer |
| Elapsed | ET | `.ACC` | ET; classic BI / BCD words | ET | TN0 device; FB ValueOut | **`.acc`** | `.acc` over IEC's `et` for consistency with counters and CONTROL |
| Done bit | Q | `.DN` — **inverted on TOF** | Q | Q | a contact on the T device (TS0) | **`.dn`** | |
| Timing-in-progress | **not in standard** | `.TT` | none | none | none | **`.tt`** | Vendor-specific invention, genuinely useful, free once the struct exists. Document as non-portable |
| Enable bit | **not in standard** | `.EN` | none | none | timer coil device TC0 / FB `.Coil` | **`.en`** | Only the conventional set and Mitsubishi expose the coil side, and Mitsubishi's is a reset handle |
| Time base / clock source | **deliberately unspecified**; PT/ET are TIME; Ed2 T37 NOTE makes the effect of changing PT mid-timing *"implementation-dependent"* | fixed 1 ms; `ACC = ACC + (current_time − last_time_scanned)`, with a 69-minute scan warning | TIME = 32-bit signed ms; LTIME to ns; classic S5TIME is BCD with a coarse base | TIME, 32-bit ms; effective resolution bounded by task cycle (*reasoning, not cited*) | per-device base: low-speed 100 ms default, high-speed 10 ms; 16-bit count caps the range | **integer ms, elapsed injected as a scan input** | the conventional set's delta-since-last-scan formula, with `now` supplied by the caller, is the only version that is a pure function of its inputs |
| Where state lives | an FB instance in a VAR block; `TMR1.Q`, `TMR1.ET` | a structured TIMER tag; `Timer_1.DN` | an IEC_TIMER in an instance DB; `#MyTimer.Q` | an FB instance; `TON1.Q` | a global device number split into TS0/TC0/TN0 | **named instance in env, dotted member access** | Three models exist; two of the three converge on `name.member`, which is what settles §4.3 |

### Counters

| Concept | IEC 61131-3 | Conventional | Siemens | CODESYS | Mitsubishi | logex | Notes |
|---|---|---|---|---|---|---|---|
| Up counter | **CTU** — Ed2 T36 §2.5.2.3.3: CU (R_EDGE), R, PV:INT → Q, CV; typed variants `_DINT/_LINT/_UDINT/_ULINT` | CTU (ladder only); COUNTER tag | TIA CTU (needs IEC_COUNTER instance); classic S_CU + `---( CU )` | CTU — **RESET not R, PV/CV are WORD not INT** | native `OUT C` (set value 0–65535); FB CTU(_E) | **ctu counter preset** | The most IEC-conformant vendor is the one that renamed the pins |
| Down counter | **CTD** — CD, LD, PV → Q (`CV <= 0`), CV. **No R input** | CTD — decrements `.ACC`; `.DN` still means `.ACC >= .PRE` | TIA CTD; classic S_CD + `---( CD )` | CTD — LOAD, Q when CV = 0 | none native; UDCNT1, or FB CTD(_E) | **ctd counter preset** | The zero test differs: IEC counts *down from PV*; the conventional set just decrements |
| Up/down counter | **CTUD** — CU, CD, R, LD, PV → QU, QD, CV | **not in ladder** — FBD/ST only (FBD_COUNTER) | TIA CTUD; classic S_CUD | CTUD | UDCNT1 / UDCNT2, or FB CTUD(_E) | **(none)** — `ctu` + `ctd` on one counter | the conventional set's own ladder skips it; that is the ladder-native idiom |
| Counter reset | **the R input** — not an instruction. CTD has no R; reload via LD | RES | the R input; **classic also `---( R )` applied to a C no.** | RESET input | RST — doubles as the general bit reset | **res counter** | the conventional set and Mitsubishi are the only ones with a standalone reset. Keeping `res` and `otu` separate, as the conventional set does, is the right call |
| Preset load (CV := PV) | **LD input on CTD/CTUD** — genuinely standard, but a *pin* | **no equivalent instruction** — MOV into `.PRE`/`.ACC` | classic: the S input / `---( SC )`; TIA: LD | LOAD input | none; the set value is an operand of `OUT C` | **(none)** — `move` into `.pre` | The pin most likely to be wrongly reported as absent from IEC |
| Preset / current / done | PV / CV / Q (QU, QD) | `.PRE` / `.ACC` / `.DN` | TIA: PV / CV / Q. **Classic Q means count ≠ 0** — not a comparison against the preset | PV / CV / Q | set value / current value / the C device's contact | **`.pre` `.acc` `.dn`** | Siemens classic's Q is the silent trap in this family: the same letter, a different predicate |
| Overflow / underflow | **not in standard.** The bodies bound counting with `CV < PVmax` / `CV > PVmin`, and the Table 36 NOTE makes *"the numerical values of the limit variables PVmin and PVmax … implementation-dependent"* | `.OV` / `.UN`, at ±2 147 483 647 | none | none | none | **(none)** | **Corrected:** IEC does *not* saturate at the data type's limits. The "nobody else has OV/UN" half is an absence argument — **partly unverified** |

### Comparison

| Concept | IEC 61131-3 | Conventional | Siemens | CODESYS | Mitsubishi | logex | Notes |
|---|---|---|---|---|---|---|---|
| = | **EQ** — a library *function* (Ed3 T33 p.91 / Ed4 T33 p.102), **not** an LD element; ST `=` | **EQ** (formerly EQU); LD + FBD, *"not available in structured text"*; Source A / Source B; also compares strings | TIA `CMP ==`, typed by operand data type; classic `CMP ==I / ==D / ==R` | EQ ("the IEC operator") | `LD=` / `AND=` / `OR=`, `_U` unsigned, `LDD=` 32-bit | **eq a b** | **The correction that matters most.** the conventional set renamed all six in that sweep *"to conform to IEC 61131-3 and PLCopen standards"* — the survey's implied conventional-vs-IEC contrast no longer exists |
| ≠ | **NE** — documented non-extensible | **NE** (formerly NEQ) | `CMP <>` | NE | `LD<>` | **ne a b** | |
| < | **LT** | **LT** (formerly LES) | `CMP <` | LT | `LD<` | **lt a b** | `lt aa bb` reads "aa < bb" — the conventional set, IEC and Mitsubishi all agree on that order |
| > | **GT** | **GT** (formerly GRT) | `CMP >` | GT | `LD>` | **gt a b** | |
| ≤ | **LE** | **LE** (formerly LEQ) | `CMP <=` | LE | `LD<=` | **le a b** | the instruction-set reference's LEQ page prints the rename as *"from LES to LE"* — a typo in the conventional set's own manual; the summary table gives LEQ→LE |
| ≥ | **GE** | **GE** (formerly GEQ) | `CMP >=` | GE | `LD>=` | **ge a b** | |
| Range test | **not in standard.** IEC's LIMIT (Ed3 T32) is a **clamp** returning a value, not a BOOL | **LIMIT** (formerly LIM); Low / Test / High. If Low > High the test wraps the signed number line and is true *outside* | TIA IN_RANGE (MIN/VAL/MAX); **none in classic** | none — compose GE and LE | ZCP band compare — an *output* instruction writing three bits | **in_range** *(deferred)* | **Trap sharpened by the fact-check:** the conventional set's current name `LIMIT` now collides head-on with IEC's LIMIT clamp. Avoid both `lim` and `limit` |
| Out-of-range | not in standard | none — LIMIT with inverted limits | TIA OUT_RANGE | none | ZCP result bits | **out_range** *(deferred)* | Only Siemens names it. the conventional set's operand-order trick is silently wrong when limits come from tags |
| Masked equal | not in standard — compose AND + EQ | MEQ (Source / Mask / Compare) | none | none | none (BKCMP is a *block* compare) | **meq** *(deferred, low)* | conventional-set-only. The three "none" cells argue from instruction lists — **partly unverified** |
| Expression compare | not in standard — an expression is ST syntax | CMP — **ladder only**; one Expression operand. Current operator list includes ACOS, ASIN, ATAN, ATAN2, BCD_TO, IsINF, IsNAN, SQRT, TRUNC and `&&`, `\|\|`, `^^`, `!` | none — SCL expression or chained boxes | none — write ST | **none on iQ-R.** FX's CMP is a different instruction | **defer** | Needs an expression sub-grammar with precedence — a language change, not an instruction |
| Three-way compare | not in standard | **none** — the conventional set's CMP is an expression box | none | none | **FX only:** CMP sets (d), (d)+1, (d)+2 for >, =, <. **Not on iQ-R or Q/L** | **do not add** | Listed so `cmp` is never given Mitsubishi's meaning by accident. Depends on consecutive-device addressing, which logex has not got |

### Arithmetic

| Concept | IEC 61131-3 | Conventional | Siemens | CODESYS | Mitsubishi | logex | Notes |
|---|---|---|---|---|---|---|---|
| Add | **ADD** (Ed3 T29, extensible); ST `+` | ADD | TIA ADD; classic ADD_I / ADD_DI / ADD_R | ADD | native `+`, `D+`, `B+`, `E+`; ADD(_E) | **add a b dst** | Unanimous. Fix arity at 3 — logex cannot mirror IEC's variadic ADD |
| Subtract | **SUB** (non-extensible); ST `-` | SUB | SUB | SUB | `-`, `D-`, `B-`; SUB(_E) | **sub a b dst** | |
| Multiply | **MUL** (extensible); ST `*` | MUL | MUL | MUL | `*`, `D*`, `B*`; MUL(_E) | **mul a b dst** | |
| Divide | **DIV**; ST `/`; integer division truncates toward zero | DIV | DIV | DIV | `/` — **writes the quotient to (d) and the remainder to (d)+1**; DIV(_E) | **div a b dst** (quotient only) | Names agree, semantics do not. Following IEC/the conventional set and Siemens here means *not* following MELSEC |
| Modulo | **MOD** (Ed3 T29; ST operator **feature 8**): `IF IN2=0 THEN OUT:=0 ELSE OUT := IN1-(IN1/IN2)*IN2` | MOD | TIA MOD; classic **MOD_DI only** | MOD — help says *"non-negative integer remainder"* | none native; MOD(_E) | **mod a b dst** | Name unanimous, **sign convention is not**. IEC's formula with truncating DIV is Elixir's `rem/2`, not `Integer.mod/2`. Put it in a test |
| Negate | **not a standard function** — only the ST unary minus (operator table **feature 4**) | NEG | TIA NEG "create twos complement"; classic NEG_I / NEG_DI / NEG_R | **none** — unary `-` in ST | NEG / DNEG | **neg src dst** | A three-vendor consensus with no standard function behind it. logex has no expression syntax to host a unary minus, so take the vendor name |
| Absolute value | **ABS** (Ed3 T28) | ABS | ABS | ABS | none native; ABS(_E) only | **abs src dst** | Mitsubishi reaches it only through the IEC library — itself evidence that IEC names win where no legacy mnemonic existed |
| Square root | **SQRT** (Ed3 T28) | **SQRT** (formerly SQR) | TIA SQRT — **and separately SQR, which means square (x²)** | SQRT | **no BIN integer sqrt at all.** iQ-R: ESQRT / EDSQRT (real), BSQRT / BDSQRT (BCD). Q/L: SQR / SQRD / BSQR / BDSQR. SQRT(_E) over REAL in the IEC library | **sqrt src dst** | **Never `sqr`**: before that sweep, conventional = root, Siemens = square. **Corrected:** the survey's "SQRT/DSQRT (BIN)" was a fabricated mnemonic |
| Power | **EXPT** (Ed3 T29; ST `**`, operator **feature 3**) | **EXPT** (formerly XPY) | TIA EXPT; `x^y` inside CALCULATE | EXPT | EXPT(_E) | **expt** *(deferred)* | Another that sweep rename toward IEC |
| Compute from an expression | not in standard — ST `:=` covers it | CPT — **ladder only** | CALCULATE — **LAD/FBD only, not SCL** | none | none | **defer** | These exist precisely because ladder has no expression syntax. **Corrected:** CALCULATE is not an SCL instruction |

### Bitwise and shift

| Concept | IEC 61131-3 | Conventional | Siemens | CODESYS | Mitsubishi | logex | Notes |
|---|---|---|---|---|---|---|---|
| Word AND | **AND** (Ed3 T31, symbol `&`) — overloaded over ANY_BIT | AND "Bitwise And"; separate **BAND** for BOOL in FBD | TIA AND under "Word logic operations"; classic WAND_W / WAND_DW | AND | WAND / DAND / BKAND; AND(_E) | **wand a b dst** | IEC can reuse `AND` only because it is strongly typed. logex's env is untyped integers, so the reader is the type checker — and *every* vendor that put this on a rung disambiguated somehow |
| Word OR | **OR** (T31, `>=1`) | OR; BOR | TIA OR; classic WOR_W / WOR_DW | OR | WOR / DOR / BKOR | **wor a b dst** | Worst collision of the four: a bare `or` in a rung would read as a *branch*, which `( \| )` already means |
| Word XOR | **XOR** (T31, `=2k+1`) | XOR; BXOR | TIA XOR; classic WXOR_W | XOR | WXOR / DXOR / BKXOR | **wxor a b dst** | Least ambiguous, but splitting the prefix convention would be worse than the redundancy |
| Word NOT | **NOT** (T31; ST operator **feature 5**, "Complement NOT") | NOT; BNOT | TIA **INV** "create ones complement" — deliberately not "NOT"; classic INV_I / INV_DI | NOT | CML / DCML (complement transfer) | **wnot src dst** | Widest divergence in the set: NOT vs INV vs CML. Siemens' NEG (two's complement, arithmetic) / INV (ones complement, bitwise) split is the cleanest distinction anyone draws |
| Shift left by N | **SHL** (Ed3 T30; zero fill) | **none** — no shift-by-N anywhere in the instruction set | TIA SHL; classic SHL_W / SHL_DW | SHL | SFL native; SHL(_E) | **shl src n dst** | Verified by enumerating the whole current instruction set: no SHL/SHR/ROL/ROR |
| Shift right by N | **SHR** (T30; **zero fill — logical**, not arithmetic) | **none** — BSR is the array shift register | TIA SHR; classic SHR_W, and **SHR_I / SHR_DI sign-extend** | SHR | SFR; SHR(_E) | **shr src n dst** | Follow IEC and zero-fill, and say so in the docs |
| Rotate left / right | **ROL / ROR** (T30; circular, no carry) | **none** | TIA ROL / ROR; classic ROL_DW / ROR_DW | ROL / ROR | ROL/ROR (no carry) and RCL/RCR (through carry); ROL(_E) | **rol / ror** | Forces the word-width question — rotation is meaningless without a fixed width. A prerequisite decision, not a naming one |
| Bit field distribute | **not in standard** — compose SHR + AND + OR | BTD (Source, Source bit, Dest, Dest bit, Length 1–32); BTDT adds a Target | none — word logic plus SHL/SHR | none | none direct. **NDIS/NUNI split/combine in arbitrary bit widths; DIS/UNI are the 4-bit (nibble) pair** | **defer** | conventional-set-only, five operands, and decomposes exactly into `shl` + `wand` + `wor` |
| Array bit shift register | not in standard | BSL / BSR — **edge-triggered, CONTROL structure, one position per scan, across an array** | none | none | BSFR/BSFL, SFTR/SFTL, DSFR/DSFL | **defer** | Listed separately so `BSL` is never mistaken for `SHL`. A sequencer, not a bitwise operator |

### Data movement and conversion

| Concept | IEC 61131-3 | Conventional | Siemens | CODESYS | Mitsubishi | logex | Notes |
|---|---|---|---|---|---|---|---|
| Scalar move | **MOVE** — a real standard function (selection functions): one `IN : ANY` → one `OUT : ANY`; ST `:=` | **MOVE** (formerly MOV); ladder only, *"not available in structured text"*; Source, Dest | TIA MOVE, `IN → OUT1`, SCL `out1 := in;`; classic L/T in STL | MOVE (IEC operator) | MOV / MOVP, DMOV | **`move src dst`** — rename from `mov` | Source-then-destination is unanimous, so logex's operand order was already right. The *name* was on the losing side of the that sweep drift |
| Operand order | source is MOVE's only argument, so in ST the destination lands on the **left** | source first, without exception: MOV, MVM, COP, CPS, FLL, SWPB | LAD boxes are source-in/dest-out; SCL uses named parameters | **split**: `dst := MOVE(src)`, but TwinCAT `MEMCPY(destAddr, srcAddr, n)` is **destination first** while CAA `MEM.Move(pSource, pDestination, n)` is **source first** | uniformly `(s)` then `(d)`; XCH is the exception because both operands are destinations | **source first, no exceptions** | The only reversals in the wild are ST assignment and C-derived pointer copies. Imitate neither |
| Masked move | not in standard — compose AND/OR/XOR | MVM (Source, Mask, Dest); MVMT adds a Target | none — word logic + MOVE | none | none (WAND/WOR; FX SMOV is digit-wise) | **`movm src mask dst`** *(deferred)* | the conventional set has the only first-class masked move; `movm` keeps the `mov`/`move` family readable |
| Block copy | not an instruction — Ed3 allows whole-array `:=` | COP(Source, Dest, Length) — **Length counts *destination* elements**; raw byte copy, no type conversion | MOVE_BLK(in, count, out); classic SFC20 BLKMOV | library only (MEMCPY, MEM.Move) — pointer-based, unchecked | BMOV (s)(d) n | **`copy src dst len`** *(deferred)* | Every vendor puts the count last. Document **which end** it counts — that is where the bugs are, not in the name |
| Fill | not in standard | FLL(Source, Destination, Length) | FILL_BLK / UFILL_BLK (in, count, out) | library only | FMOV (s)(d) n | **`fill value dst len`** *(deferred)* | Mitsubishi calls it FMOV, which reads like a move |
| Clear | not in standard — `x := 0` | CLR (Dest) — *"Clear Dest to 0"*; ladder only | none — MOVE a 0 | none | none — `MOV K0 (d)` | **`clr dst`** *(optional)* | `move 0 dst` already does the job; add only for readability of intent |
| Uninterruptible copy | not in standard | CPS | UMOVE_BLK / UFILL_BLK; classic SFC81 | none | none | **omit deliberately** | Exists only because real controllers preempt scans. logex has nothing to protect against |
| Byte swap / endianness | **in standard, as representation conversion**: Ed3 **Table 37 "Function for endianess conversion"** — TO_BIG_ENDIAN, TO_LITTLE_ENDIAN, FROM_BIG_ENDIAN, FROM_LITTLE_ENDIAN | SWPB(Source, Order Mode, Dest) — REVERSE / WORD / HIGHLOW | SWAP — `out := SWAP(in)` | library only | SWAP / DSWAP — **in place, one operand** | **`swpb src dst`** *(deferred)* | **Corrected:** the standard is not silent here. Take the conventional set and Siemens' src→dst shape, not Mitsubishi's in-place mutation |
| Exchange two variables | not in standard | none — temp tag + two moves | none | none | XCH (d1)(d2) / DXCH | **`xch a b`** *(deferred)* | This is why `swap` is a bad logex name for byte reversal: Siemens/Mitsubishi SWAP = reverse bytes, and *exchange* is XCH. Two operations, one English word |
| Numeric type conversion | **`<SOURCE>_TO_<TARGET>` is the standard scheme** (INT_TO_REAL, REAL_TO_INT); Ed3 adds overloaded `TO_<TARGET>` | no general instruction — implicit conversion, plus TRUNC, **TO_BCD**, **BCD_TO**, DEG, RAD | CONV box; SCL renders it literally as `out := <type>_TO_<type>(in)` | same `<type>_TO_<type>` scheme | one instruction per conversion: FLT/DFLT, INT/DINT, **DBL** (16→32) and **WORD** (32→16) | **`int_to_real src dst`** etc. *(deferred)* | Three of four ecosystems already use `<FROM>_TO_<TO>`. **Corrected:** there is no MELSEC `DWORD` conversion instruction |
| BCD ↔ binary | BCD_TO_** / **_TO_BCD forms | **TO_BCD** (formerly TOD), **BCD_TO** (formerly FRD); LD/FBD only | CONV with pseudo-types BCD16 / BCD32 | library | BCD/DBCD, BIN/DBIN | **`int_to_bcd` / `bcd_to_int`** *(deferred)* | FRD read like "from decimal" but converted *from BCD*. the conventional set fixed exactly this in that sweep |
| Real → integer rounding | TRUNC is standard. The REAL_TO_INT tie rule was **not verified** in the standard text | TRUNC (formerly TRN) — drops the fraction; no separate ROUND | ROUND = **nearest, ties to even** (`ROUND(10.5)=10`, `ROUND(11.5)=12`); TRUNC, CEIL, FLOOR | REAL_TO_INT documented as **half away from zero** — `REAL_TO_INT(-1.5) = -2` | INT/DINT rule **not verified** | **`trunc` `round` `ceil` `floor`** as separate instructions *(deferred)* | Two IEC-family systems give different answers for the same input. **Never hide a rounding mode inside a conversion name** |
| String move | MOVE / `:=` work on STRING like any type | MOVE handles String on 5380/5480/5580; COP/CPS elsewhere | **S_MOVE** — *"to copy a string, use S_MOVE"* | `:=` | `$MOV` | **`move` — no separate instruction** | Only Siemens and Mitsubishi split strings out, for memory-model reasons logex does not have |

### Program control

| Concept | IEC 61131-3 | Conventional | Siemens | CODESYS | Mitsubishi | logex | Notes |
|---|---|---|---|---|---|---|---|
| Conditional jump | **graphical only** — a Boolean signal line ending in a double arrowhead, `>>LABEL` (Ed2 §4.1.4, T58). IL had JMP/JMPC/JMPCN, **removed with IL in Ed 4** | JMP "Jump to Label" — ladder only | `---( JMP )`, "Jump if RLO = 1" (both classic and TIA); unconditional when placed on the left rail | "Jump" element | CJ (conditional), JMP (unconditional), SCJ; **classic ladder editor only** — the manual marks ST and FBD/LD "Not supported" | **`jmp <label>`**, forward-only at first | Stage the *capability*, not the name: reject a backward target with an explicit diagnostic rather than inventing a narrower mnemonic |
| Jump if false | **not in LD** — §4.1.4 transfers only when the line is 1. IL had JMPCN | none — condition with XIO | `---( JMPN )` "Jump-If-Not" (classic and TIA) | none | none — use an NC contact before CJ | **(none)** — `xio aa jmp done` | Only Siemens carries a distinct false-jump mnemonic; logex already has the polarity pair |
| Jump target / label | **"network label"**: an identifier or unsigned integer followed by `:` (Ed2 §4.1.2) — a property of the network, not an element | LBL — must be first on the rung; ≤ 40 chars | classic LABEL: **max 4 chars, first a letter**. **TIA: letters, or letters then digits; no documented length limit** | "Jump Label" | a pointer P0…Pn, shared with CALL and BREAK | **`lbl <name>`**, first on the rung | **Corrected:** the 4-character rule is classic STEP 7 only — an edition trap |
| Multi-way jump | not in standard — CASE is ST | none | TIA JMP_LIST, SWITCH | none | none | **(none)** | The one control-flow concept nobody else has |
| Subroutine call | no LD mnemonic — draw the block. IL had CAL (gone in Ed 4); ST is `Instance(args);` | **JSR** — a coinage of the conventional set alone | `---( CALL )`, CALL_FC / CALL_FB / CALL_SFC / CALL_SFB | "Box" element | CALL(P), FCALL, ECALL, EFCALL | **`cal <routine>`** *(deferred)* | IEC, Siemens, CODESYS and Mitsubishi all say some form of *call*. This is where the survey overturns the reflex answer |
| Subroutine entry / parameters | not an instruction — VAR_INPUT is the interface | SBR | none — the block's declaration table | none — the POU's declaration part | none — the pointer P; args are the caller's (s1)–(s5) | **(none)** — declare the interface | the conventional set needs SBR only because a that vendor routine has no parameter list. Do not import a workaround for a design you did not adopt |
| Return | **genuinely standard, three ways**: the `<RETURN>` LD element (Ed2 T58.5–8), ST `RETURN;`, IL RET | RET | `---( RET )` (classic and TIA) | "Return" element | RET — a **body terminator**, not a conditional early exit | **`ret`** | The one row where IEC and all four vendors agree on both the name and (mostly) the meaning |
| Temporary end | not in standard — RETURN is the mechanism | TND "Temporary End" | none (`---( RET )` exits; STP stops the CPU) | none | FEND, END, GOEND | **(none)** — `ret` does this | the conventional set's own description of TND is precisely RETURN |
| Master control zone | **not in standard** — full-text search of Ed 2 for "master control" returns zero hits | MCR — **the same mnemonic opens and closes**; zones cannot nest; you must not jump into one | classic `---( MCR< )` / `---( MCR> )`, armed by `---( MCRA )` / `---( MCRD )`. **Legacy S7-300/400 only**, not in the S7-1200/1500 set | none | MC (start, level N0–N14) / MCR (end); **also available in ST** | **`mcs … mce`** *(deferred)*, deliberately not `mcr` | `MCR` means "end the zone" to Mitsubishi and Siemens but "either end" to the conventional set. The disabled-zone *semantics* also differ per vendor |
| Always false | not in standard | AFI "Always False" — ladder only | none | none | none (the habit is NOP) | **(none)** | Artefact of graphical editors. In a text dialect, a comment does this more honestly. the conventional set verified; the three "none" cells are absence arguments — **partly unverified** |
| No operation | not in LD (ST's empty statement `;` is a different, syntactic thing) | NOP | none in LAD (STL has `NOP 0` / `NOP 1`) | none | NOP, NOPLF | **(none)** | Exists because a ladder program there is a fixed array of steps. logex is text; a blank line is the no-op |
| Counted loop | **ST only** — `FOR … END_FOR` (also WHILE, REPEAT). **No LD looping element** | FOR — repeatedly executes a *routine*, not inline rungs | none in LAD — backward jump, or SCL FOR | none in LD | **FOR … NEXT, inline in the ladder** | **`for <n> … nxt`** *(deferred)* | Two genuinely different shapes. Mitsubishi's inline one is the only one logex could express |
| Break | ST **EXIT** | BRK — plain break | none | none | BREAK(P) — **a break *and* a jump** | **`brk`** *(deferred)* | Take the plain form; leave jumping to `jmp` |

### Branch structure (the rung's parallel legs)

| Concept | IEC 61131-3 | Conventional | Siemens | CODESYS | Mitsubishi | logex | Notes |
|---|---|---|---|---|---|---|---|
| Parallel branch group | **graphical** — parallel horizontal links between vertical links (Ed2 §4.1.2, T60). PLCopen TC6 XML models a rung as a connection graph with no textual delimiters | **two spellings, one per controller generation.** *Current* family, L5K neutral text: brackets and commas, `N: XIC(conveyor_a)[,XIC(input_1) XIO(input_2) ]OTE(light_1);`. *Earlier* family, ASCII rung editor and library export: **`BST` / `NXB` / `BND`**, as `SOR BST XIC I:003/4 NXB XIO T4:5/DN BND XIC B3/10 TON T4:5 1.0 450 315 EOR` | graphical (TIA Openness XML: `<Part Name="Contact"/>`) | graphical | **no delimiters at all** — stack instructions ORB (OR Block), ANB (AND Block), MPS / MRD / MPP | **`( … \| … )`** | **`BST`, `NXB`, `BND` are that vendor's mnemonics after all — from the earlier generation.** They occur zero times in the current family's import/export reference (385 pp) and ladder-diagram programming manual, both of which discuss branching at length, and zero times in its 927-page instruction-set reference, which is the weakest of the three witnesses because branch structure is not an instruction there and its text never uses the word "branch" at all. An earlier version of this row led on that 927-page check and over-read it into "no vendor reference". Two documents of the *earlier* family carry the answer, and it takes both: its programming-software guide (Dec 2019) glosses the tokens `BST=branch start / NXB=next branch / BND=branch end` for the per-rung ASCII editor and prints library exports built from them, while its controller reference lists *branch start / next branch / branch end* in the instruction timing table at one word of memory and 0.16–0.8 µs each, depending on processor. No single document does both — that the timing table's three elements are the three tokens is an inference, and a safe one, but say that it is. The tokens are also live in the **current** family: its software has the same per-rung ASCII text area, and these are what you type into it. That is recorded here as first-hand testimony from this repository's owner, not as a citation — no vendor document reachable from here states the grammar that text area accepts, and the current family's *export* format remains the bracket-and-comma form. So logex's delimiters *were* **borrowed, not coined** — and are not any more: §4·B1 landed `( … \| … )` in their place, because the three words came from the same character set as tag names and one missing space fused `nxb` into a neighbouring identifier, turning a parallel group into a series one with no error anywhere. That is a deliberate divergence from a live vendor spelling rather than a coinage filling a gap, which is the more expensive kind and is why this row records both. The other textual precedent, `[ , ]`, is unavailable to logex because it works only alongside parenthesised operands |

**Topology, and the one place logex is more permissive.** The conventional set's ladder
programming manual (July 2022 revision, ch.1) defines a branch as *"two or more
instructions in parallel"*, says *"there is no limit to the number of parallel branch
levels that you can enter"*, and then: *"you can nest branches to as many as 6 levels."*
Parallel legs that **nest** — so a rung there is a tree, and the editor cannot draw a
non-series-parallel rung: no bridge, no two paths sharing an interior element, nothing
that would need a delimiter to close out of order. logex's `elem -> bst branches bnd` is
strictly nested too, so it is **topologically adequate** for every rung that dialect can
express. That is worth writing down because it is the one way a textual rung language can
fail that no amount of printer or syntax work repairs.

The divergence is the depth: that vendor stops at 6 levels, logex has no limit at all —
`( ( … ( xic aa ) … ) ) ote xx` parses and evaluates at nesting depth 1000, and the bound
is the machine's, not the language's. logex being *more* permissive is not a defect, but
it is an undocumented difference from the dialect it borrows from, and it is the kind that
only shows up when something tries to move a routine the other way. Pinned by "branch
nesting has no depth limit" in `end_to_end_test.exs`, which nests 50 deep in both power
states — so a future validator that quietly adds a limit goes red rather than silently
narrowing the language.

---


---

## Stanzas

One per mnemonic, declaration word or word that heads a file. The first six below are the
instructions logex shipped when this file was written; all were surveyed retrospectively,
in the commit that introduced it. `move` has since replaced `mov`. The five after it, `var`
to `dint`, are the words of `PLAN.md` M1-3's declaration lines, surveyed before their code.

### `xic` — examine if closed (normally-open contact)

| Dialect | Name there | Notes |
|---|---|---|
| logex | `xic aa` | Passes power when `aa` is 1. |
| IEC 61131-3 | **Normally open contact**, `--\| \|--` | Graphical element, no mnemonic. Ed 2:2003 §4.2.3 Table 61 feature 1; Ed 3 Table 75; Ed 4 Table 74. The standard defines it as strictly complementary to the normally-closed contact. |
| Conventional | **XIC** — Examine If Closed | Operand `Data bit \| BOOL \| tag`. Not renamed in that conformance sweep, because IEC has no mnemonic to conform to. (vendor instruction-set reference, Sept 2025ch. 2.) |
| Siemens STEP 7 / TIA Portal LAD | classic `---\| \|---`; TIA `---\| \|---` | No mnemonic — a graphical contact in both. |
| CODESYS | **Contact** | Element name, following IEC Table 61. |
| Mitsubishi GX Works | **LD** "Load" (A contact); **AND**/**OR** in series/parallel position | Mitsubishi bakes rung *position* into the mnemonic. logex must not copy that — `( \| )` expresses position structurally. |

**Chosen:** `xic`
**Why:** No IEC name exists to take (rule 2 applies). Of the vendor mnemonics, Mitsubishi's `LD` is positional and would collide with a future load or move; Siemens and CODESYS have no word at all. the conventional set's is the only usable token, and it keeps symmetry with `xio`. Grandfathered: see the note under `ote`.
**Checked:** 2026-08-30 — IEC 61131-3:2003 §4.2.3 Table 61; the vendor instruction-set reference (Sept 2025 revision); Mitsubishi MELSEC iQ-R Programming Manual SH(NA)-081266ENG.

### `xio` — examine if open (normally-closed contact)

| Dialect | Name there | Notes |
|---|---|---|
| logex | `xio aa` | Passes power when `aa` is 0. |
| IEC 61131-3 | **Normally closed contact**, `--\|/\|--` | Ed 2:2003 Table 61 feature 3. Defined as the strict complement of the NO contact. |
| Conventional | **XIO** — Examine If Open | Operand `Data bit \| BOOL \| tag`. |
| Siemens STEP 7 / TIA Portal LAD | `---\| / \|---` | Graphical in both. |
| CODESYS | **negated contact** | A modifier on a contact, not a separate element. |
| Mitsubishi GX Works | **LDI** "Load inverse" (B contact); **ANI**/**ORI** | Same positional problem as `LD`. |

**Chosen:** `xio`
**Why:** Rule 2, and symmetry with `xic`. **Known divergence:** IEC defines NC as the strict complement of NO; logex's `xic` and `xio` are two independent *positive* tests, so a tag holding anything outside `{0,1}` reads false for both. That is a defect, not a dialect choice — see `PLAN.md` M1-4. *(Fixed by M1-4: `xio` now reads the negation of `xic`'s test, so the two are complementary whatever a tag holds; M1-3 already let only a bool reach either.)*
**Checked:** 2026-08-30 — as `xic`.

### `ote` — output energize (non-retentive coil)

| Dialect | Name there | Notes |
|---|---|---|
| logex | `ote xx` | Writes 1 on a true rung, **0 on a false rung**; passes power through unchanged. |
| IEC 61131-3 | **Coil**, `--( )--` | Ed 2:2003 §4.2.4 Table 62 feature 1: *"The state of the left link is copied to the associated Boolean variable **and to the right link**."* Note the second half — an IEC coil passes power through, which is why logex needs no Siemens-style midline output. The textual equivalent is ST assignment `xx := …;`. IL's `ST` was the nearest mnemonic, and IL is gone as of Ed 4.0. |
| Conventional | **OTE** — Output Energize | *"sets or clears the data bit based on rung condition."* Cleared on a false rung, and on prescan and postscan. Not renamed in that sweep. |
| Siemens STEP 7 / TIA Portal LAD | classic **Output Coil** `---(   )`; TIA **Assignment** `---( )---` | Same false-rung behaviour. SCL equivalent `out := …;`. |
| CODESYS | **Coil** *(unverified)* | Expected to follow IEC Table 62. `content.helpme-codesys.com` returned HTTP 403 to automated fetches — do not repeat as fact until someone opens the help directly. |
| Mitsubishi GX Works | **OUT** | *"Outputs the operation result to the specified device."* Overloaded by operand type: `OUT T` is a timer, `OUT C` a counter. |

**Chosen:** `ote`
**Why:** All five dialects agree exactly on the semantics and share no name. There was no IEC name available — the standard's name for this is a picture, and its one textual mnemonic (`ST`) was removed in Ed 4.0 — so rule 2 applies. Siemens' *Assignment* is a phrase, not a token; Mitsubishi's `OUT` is overloaded across timers, counters and annunciators. `ote` keeps the three-way symmetry with `otl`/`otu`, which is the more valuable alignment: IEC itself names those two *"SET (latch) coil"* and *"RESET (unlatch) coil"*, so latch/unlatch is the one place logex and the standard already agree.

**Grandfathering note.** `xic xio ote otl otu` are a closed, deliberate borrowing from one vendor's mnemonic set, kept because the survey found nothing better to migrate to — IEC names them only as English phrases, Siemens and CODESYS have no mnemonics, and Mitsubishi's set is positional. They are **not** a precedent that the next instruction should also come from the conventional set; rule 1 governs everything new.
**Checked:** 2026-08-30 — IEC 61131-3:2003 §4.2.4 Table 62 (read directly); IEC 61131-3:2025 Ed 4.0 publisher preview (Scope, table list); the vendor instruction-set reference; Siemens A5E02486680 and the classic S7-300/400 LAD manual; Mitsubishi SH(NA)-081266ENG. CODESYS **unverified** (HTTP 403).

### `otl` — output latch (set coil)

| Dialect | Name there | Notes |
|---|---|---|
| logex | `otl xx` | Writes 1 on a true rung; leaves the tag unchanged on a false rung. |
| IEC 61131-3 | **SET (latch) coil**, `--(S)--` | Ed 2:2003 Table 62 feature 3. The only row where IEC's own name contains the conventional set's word. |
| Conventional | **OTL** — Output Latch | A false rung leaves the bit unchanged. |
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
| Conventional | **OTU** — Output Unlatch | |
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
| Conventional | **MOVE** (formerly **MOV**) | Renamed in the 2024 conformance sweep *"to conform to IEC 61131-3 and PLCopen standards"*. Operand order `MOVE(Source, Dest)`. |
| Siemens STEP 7 / TIA Portal LAD | **MOVE** | `IN` → `OUT`, i.e. source then destination. |
| CODESYS | **MOVE** | IEC standard function. |
| Mitsubishi GX Works | **MOV** | `MOV s d` — source then destination. |

**Chosen:** `mov` — **but see below.**
**Why:** `mov` came from a vendor mnemonic set that has since retired it. Every dialect surveyed, IEC included, now spells this `MOVE`; the operand order is source-then-destination everywhere, so logex's `mov 123 hh` is correct on the semantics that actually bite. Under rule 1 the name should be **`move`**: IEC names this operation, so the IEC name wins. Keeping `mov` pins logex's dialect to a spelling its own source has abandoned.

**Status: recommended, not applied.** Renaming is a source-language break and is deliberately not bundled with this survey. `PLAN.md` schedules it alongside the M1-2 validator, so the unknown-mnemonic diagnostic can carry *"did you mean `move`?"* — cheaper than an alias, and it exercises the validator.
**Checked:** 2026-08-30 — the vendor instruction-set reference (Sept 2025 revision), rename list and MOVE operand table; IEC 61131-3 standard function library; Siemens A5E02486680; Mitsubishi SH(NA)-081266ENG.

### `move` — move a value into a tag

| Dialect | Name there | Notes |
|---|---|---|
| logex | `move 123 hh`, `move aa hh` | Source then destination. Copies an integer literal or a tag into a tag. Replaces `mov`, which is now an unknown instruction whose diagnostic points here; there is no alias. |
| IEC 61131-3 | **MOVE** | A standard function, not a graphical element: Ed 2:2003 Table 24 feature 18 (arithmetic functions); Ed 3:2013 Table 29 feature 7 and Table 32 feature 1 (selection functions), reclassified between editions, per `docs/instruction-sets.md`. Ed 4 location `unverified`. ST assignment `:=` is the idiomatic form. |
| Conventional | **MOVE** (formerly **MOV**) | Renamed in the 2024 conformance sweep *"to conform to IEC 61131-3 and PLCopen standards"*. Operand order `MOVE(Source, Dest)`. |
| Siemens STEP 7 / TIA Portal LAD | **MOVE** | `IN` → `OUT`, i.e. source then destination. |
| CODESYS | **MOVE** | IEC standard function. |
| Mitsubishi GX Works | **MOV** | `MOV s d` — source then destination. |

**Chosen:** `move`
**Why:** Rule 1: IEC names this operation MOVE, so logex takes the IEC name lowercased. This is the rename the `mov` stanza above recommended and `PLAN.md` §5 settled; it landed with the M1-2 validator, so `mov` gets *"did you mean `move`?"* rather than an alias. The operand order was already source-then-destination and did not change. The rows above are the `mov` survey's findings, carried over unchanged.
**Checked:** 2026-08-30, by the `mov` stanza above (same sources); not re-checked for this stanza.

### `var` — declare an internal tag

| Dialect | Name there | Notes |
|---|---|---|
| logex | `var fault bool`, `var count dint 5` | A declaration line before the first rung: `<section> <name> <type> [<initial>]`. The tag is the program's own, neither supplied from outside nor produced for anyone. With no initial value it starts at 0. |
| IEC 61131-3 | **VAR** … END_VAR | Ed 2:2003 §2.4.3 Table 16a: *"Internal to organization unit"*; Ed 3:2013 §6.5.2.1 Figure 7: *"Internal to entity (function, function block, etc.)"*. Each declaration inside the block is `name : TYPE := init;`. Keywords match in any case and *"shall not be used for any other purpose, for example, variable names"* (Ed 2 §2.1.3; Ed 3 §6.1.3). |
| Conventional | **Local** usage — a *local tag* | No sections: one tag list per program, each tag with a Usage of Local, Input, Output, InOut or Public, Local the default (current online help, *Tag Editor columns*). The vendor's own spelling of the internal usage varies: "Local", "Local Tag" (tag-data manual, Nov 2023, p.65), "Local Parameter". An add-on instruction keeps its internal tags on a separate Local Tags tab, a `LOCAL_TAGS` block in the text export (import/export reference, Sept 2025, p.97). |
| Siemens STEP 7 / TIA Portal LAD | TIA **Static** (FBs, kept in the instance DB) and **Temp** (one cycle); in TIA's SCL textual view, `VAR` … `END_VAR` for static data; classic **stat** and **temp** | TIA Portal Information System, STEP 7 V21 (11/2025), *Overview of the block interface* and *Declaration sections*; classic: *Programming with STEP 7*, A5E41552389-AA (04/2017), §10.2.3 p.225. The tabular view is TIA's default; the textual view exists for SCL blocks. |
| CODESYS | **VAR** … END_VAR | *"Local variables are declared between the keywords VAR and END_VAR in the declaration part of programming objects."* (Development System help V3.5.22.0, *Variable: VAR*). |
| Mitsubishi GX Works | **VAR** label class | *"A label that can be used within the range of a declared POU. This label cannot be used in other POUs."* Picked from a pull-down in a tabular label editor, not written as text (MELSEC iQ-R Application SH(NA)-081264ENG-AR §23.3 p.421; GX Works3 SH(NA)-081215ENG-AN §5.2 p.235). iQ-F uses the same class names (JY997D55701M §4.2). |

**Chosen:** `var`
**Why:** Rule 1: IEC names the section, so logex takes `VAR` lowercased, as CODESYS, Mitsubishi's class names and TIA's textual view already spell it. What logex drops is the block. A section keyword starts every declaration line, so there is no `end_var` to close and no unclosed-block diagnostic. The `:`, `:=` and `;` go as they went for operands. Blocks would reserve `end_var`, so the choice is recorded in `PLAN.md` M1-3.
**Checked:** 2026-09-28. Sources: IEC 61131-3:2003 §2.1.3 and §2.4.3 Table 16a (p.39), and IEC 61131-3:2013 §6.1.3 and §6.5.2.1 Figure 7 (p.50), both read directly; the conventional family's tag-data manual (Nov 2023), import/export reference (Sept 2025) and current online help; TIA Portal Information System STEP 7 V21 (11/2025); Siemens A5E41552389-AA; CODESYS Development System help V3.5.22.0; Mitsubishi SH(NA)-081264ENG-AR, SH(NA)-081215ENG-AN and JY997D55701M.

### `var_input` — declare a tag supplied from outside

| Dialect | Name there | Notes |
|---|---|---|
| logex | `var_input start bool` | Supplied from outside the program before each scan: in Milestone 1 by the host, later by a configuration's connection (`docs/organisation.md` §4.4). Logic may read it but not write it: `ote`, `otl` or `otu` naming it, or `move` writing it as its destination, is a diagnostic. It takes no initial value. It says nothing about hardware: binding a tag to an I/O point is the configuration's `at` (`docs/organisation.md` §4.5). |
| IEC 61131-3 | **VAR_INPUT** … END_VAR | Ed 2:2003 §2.4.3 Table 16a: *"Externally supplied, not modifiable within organization unit"*; Ed 3:2013 §6.5.2.1 Figure 7: *"Externally supplied, not modifiable within entity"*. Location is separate: the `AT` keyword (Table 16a) and direct representation such as `%IX0.0` (§2.4.1.1). |
| Conventional | **Input** program parameter; **Input** add-on-instruction parameter | *"There are four types of program parameters. • Input • Output • InOut • Public"* (program-parameters manual, Mar 2022, p.11). Input values *"are refreshed before each scan of a program"*, and, against IEC's rule, *"A program can write to its own Input parameters"* (same, p.15). Whether an add-on instruction's logic may write its own Input parameter: `unverified`. A table in the online help's parameter-dialog topic bears on it, but can be read either way. |
| Siemens STEP 7 / TIA Portal LAD | TIA **Input**; SCL `VAR_INPUT`; classic **in** | *"Input parameters may only be read."* (TIA V21, *Rules for supplying block parameters*). For an FC, a write *"does not affect the actual parameter. Only the formal parameter is written."* (*Parameter assignment to functions*). Whether the compiler rejects such a write: `unverified`. |
| CODESYS | **VAR_INPUT** … END_VAR | Passed by value (*Variable: VAR_INPUT*). Declared `VAR_INPUT CONSTANT`, an input is read-only: *"You have read-only access to constant variables in an implementation."* (*Variable: CONSTANT*). For a plain input, no help page says the compiler rejects a write from inside; the optional Static Analysis rule SA0037 flags one: *"According to the IEC 61131-3 standard, an input variable must not be changed within a POU."* (Static Analysis help V5.2.0.0). |
| Mitsubishi GX Works | **VAR_INPUT** label class | *"This label receives a value, and the received value cannot be changed in a POU."* (SH(NA)-081264ENG-AR §23.3 p.421; iQ-F JY997D55701M §4.2 p.32 alike). Functions and function blocks only: a program block cannot declare one and shares data through global labels. How the tool enforces the rule: `unverified`. |

**Chosen:** `var_input`
**Why:** Rule 1, IEC's word lowercased. The no-write rule is IEC's own (*"not modifiable within organization unit"*), and Siemens and Mitsubishi state it too; the conventional family is the exception, and says so. logex rejects the write at compile time. An input is overwritten at the next copy-in, so a write to one is almost always a mistake, such as a seal-in coil pointed at its own button. That no initial value is allowed is logex's choice: allowing one later breaks nothing, and forbidding one later would. The section is not a hardware binding. IEC keeps `AT` separate, and so does logex, in the configuration.
**Checked:** 2026-09-28. Sources: IEC 61131-3:2003 §2.4.3 Table 16a, and IEC 61131-3:2013 §6.5.2.1 Figure 7, both read directly; the conventional family's program-parameters manual (Mar 2022) and add-on-instructions manual (Sept 2025); TIA V21 (11/2025); CODESYS Development System help V3.5.22.0 and Static Analysis help V5.2.0.0; Mitsubishi SH(NA)-081264ENG-AR and JY997D55701M.

### `var_output` — declare a tag produced for outside

| Dialect | Name there | Notes |
|---|---|---|
| logex | `var_output motor bool`, `var_output speed_sp dint 1200` | Produced by the program for the caller: in Milestone 1 the host reads it after each scan, later a configuration's connection copies it out. Logic reads and writes it freely; the seal-in rung reads `motor` to hold `ote motor`. |
| IEC 61131-3 | **VAR_OUTPUT** … END_VAR | Ed 2:2003 §2.4.3 Table 16a: *"Supplied by organization unit to external entities"*; Ed 3:2013 §6.5.2.1 Figure 7: *"Supplied by entity to external entities"*. Table 16a puts no restriction on reading one inside the unit. |
| Conventional | **Output** program parameter; **Output** add-on-instruction parameter | Program-parameters manual (Mar 2022), p.11; add-on-instructions manual (Sept 2025), p.34: *"In the Usage box, select Input, Output, or InOut."* |
| Siemens STEP 7 / TIA Portal LAD | TIA **Output**; SCL `VAR_OUTPUT`; classic **out** | *"Output parameters may only be written."* (TIA V21, *Rules for supplying block parameters*). Whether a read of one is rejected: `unverified`. |
| CODESYS | **VAR_OUTPUT** … END_VAR | *"The values of this variable are returned to the calling POU."* (*Variable: VAR_OUTPUT*). |
| Mitsubishi GX Works | **VAR_OUTPUT** label class | *"A label that outputs a value from a function or function block"* (SH(NA)-081264ENG-AR §23.3 p.421). Functions and function blocks only, as `var_input`. |

**Chosen:** `var_output`
**Why:** Rule 1, IEC's word lowercased. Reading an output inside the program is allowed, because ladder's commonest idiom, the seal-in, reads its own coil. IEC's table does not forbid the read. TIA's "may only be written" is the one rule that points the other way, and whether it is enforced is `unverified`.
**Checked:** 2026-09-28. Sources: IEC 61131-3:2003 §2.4.3 Table 16a, and IEC 61131-3:2013 §6.5.2.1 Figure 7, both read directly; the conventional family's program-parameters and add-on-instructions manuals; TIA V21 (11/2025); CODESYS Development System help V3.5.22.0; Mitsubishi SH(NA)-081264ENG-AR.

### `bool` — the Boolean type

| Dialect | Name there | Notes |
|---|---|---|
| logex | `var fault bool`, `var lamp bool 1` | Holds 0 or 1; there are no TRUE/FALSE literals. Starts at 0 unless given 0 or 1. `xic`, `xio`, `ote`, `otl` and `otu` take only a bool. |
| IEC 61131-3 | **BOOL** | Ed 2:2003 §2.3.1 Table 10 feature 1, "Boolean", 1 bit, footnote h: *"The possible values of variables of this data type shall be 0 and 1, corresponding to the keywords FALSE and TRUE, respectively."* Default initial value 0 (Ed 2 Table 13; Ed 3:2013 Table 10, "0, FALSE"). |
| Conventional | **BOOL** | *"BOOL 1-bit boolean 0 = cleared 1 = set"*, among *"the elementary data types defined in IEC 1131-3"* (general instruction reference, Sept 2025, p.873). The tag-data manual says to choose BOOL for a bit or a digital I/O point (Nov 2023, p.23). Default initial value not stated in the documents read: `unverified`. |
| Siemens STEP 7 / TIA Portal LAD | **BOOL** in TIA's reference, **Bool** in the S7-1200 manual; classic **BOOL** | TRUE or FALSE, typed literals `BOOL#0`/`BOOL#1` (TIA V21, *BOOL (bit)*). A tag with no default takes *"the predefined value for the indicated data type ... "false" is predefined for BOOL"* (*Layout of the block interface*). S7-1200 manual A5E02486680-AP §5.4.1. |
| CODESYS | **BOOL** | *"TRUE (1), FALSE (0)"*, 8 bits of memory (*Data Type: BOOL*). *"The standard initialization value for all declarations is 0."* (*Variable Initialization*). |
| Mitsubishi GX Works | display name **Bit**, keyword **BOOL** | *"0 (FALSE), 1 (TRUE)"* (SH(NA)-081264ENG-AR §23.4 p.422). GX Works3 lists its default initial value as FALSE (SH(NA)-081215ENG-AN §6.7 p.379). |

**Chosen:** `bool`
**Why:** Rule 1, and every dialect surveyed spells the keyword BOOL. logex writes its values 0 and 1, as IEC's own footnote does, and adds no TRUE/FALSE literals: `ote` already writes 1 and 0. It is reserved in any case, as IEC reserves keywords and as GX Works3 reserves type words, *"Characters are not case-sensitive"* (SH(NA)-081215ENG-AN Appendix 4).
**Checked:** 2026-09-28. Sources: IEC 61131-3:2003 Tables 10 and 13, and IEC 61131-3:2013 Table 10, both read directly; the conventional family's general instruction reference (Sept 2025) and tag-data manual (Nov 2023); TIA V21 (11/2025); Siemens A5E02486680-AP and A5E41552389-AA; CODESYS Development System help V3.5.22.0; Mitsubishi SH(NA)-081264ENG-AR and SH(NA)-081215ENG-AN.

### `dint` — the 32-bit signed integer type

| Dialect | Name there | Notes |
|---|---|---|
| logex | `var_output speed_sp dint 1200` | -2147483648 to 2147483647, starting at 0 unless given a value. `move` checks that a literal fits, and that its two operands have one type. It is logex's only integer type so far. |
| IEC 61131-3 | **DINT** | Ed 2:2003 Table 10 feature 4, "Double integer", N = 32, footnote c: the range is −2^(N−1) to 2^(N−1) − 1. Ed 3:2013 Table 10 feature 4, default initial value 0 (and Ed 2 Table 13). |
| Conventional | **DINT** | *"DINT 4-byte integer -2,147,483,648 to 2,147,483,647"* (general instruction reference, Sept 2025, p.873). The tag-data manual says to choose DINT for *"Integer (whole number)"* (Nov 2023, p.23), and the timer preset `.PRE` is DINT milliseconds (Timers, above). Default initial value: `unverified`. |
| Siemens STEP 7 / TIA Portal LAD | **DINT** in TIA's reference, **DInt** in the S7-1200 manual; classic **DINT**, literals `L#…` | *"32 bits ... a sign and a numerical value in the two's complement"*, -2_147_483_648 to +2_147_483_647 (TIA V21, *DINT (32-bit integers)*). TIA's predefined-value table lists Int 0 but no DInt row: its default is `unverified`. |
| CODESYS | **DINT** | -2147483648 to 2147483647, 32-bit (*Integer data types*); default 0, as `bool`. |
| Mitsubishi GX Works | display name **Double Word [Signed]**, keyword **DINT** | -2147483648 to 2147483647 (SH(NA)-081264ENG-AR §23.4 p.422); GX Works3 default initial value 0 (§6.7 p.379). "Word [Signed]" is the 16-bit INT. |

**Chosen:** `dint`
**Why:** Rule 1: DINT is IEC's name for a 32-bit signed integer, and all five dialects spell the keyword the same. logex has one integer type, and it has 32 bits rather than INT's 16. Two reasons settle it. The conventional family's native integer, and its timer preset, is DINT. And a 16-bit millisecond preset tops out at under 33 seconds. Before M1-3, logex integers had no bound at all, so a literal outside DINT's range, which used to be accepted, is now a diagnostic. Each further integer type gets its own stanza.
**Checked:** 2026-09-28. Sources: IEC 61131-3:2003 Tables 10 and 13, and IEC 61131-3:2013 Table 10, both read directly; the conventional family's general instruction reference (Sept 2025) and tag-data manual (Nov 2023); TIA V21 (11/2025); Siemens A5E02486680-AP and A5E41552389-AA; CODESYS Development System help V3.5.22.0; Mitsubishi SH(NA)-081264ENG-AR and SH(NA)-081215ENG-AN.

### `ons` — one-shot on the rung condition

| Dialect | Name there | Notes |
|---|---|---|
| logex | `xic go ons s1 ote pulse` | Passes power for the one scan in which the power reaching it rises from 0 to 1, and none otherwise. `s1` is its storage bit, an ordinary declared bool, a `var` or a `var_output`: it holds the power this `ons` received last scan. On an instance's first scan since it started or restarted it passes no power, whatever `s1` holds, so a rung already true at start does not fire. De-energised, it passes none and clears `s1`. After `xio`, it fires on a falling edge. |
| IEC 61131-3 | **none** | The transition-sensing contacts `--\|P\|--` and `--\|N\|--` (Ed 2 Table 61 features 5 and 7) sense a named operand, not the rung result, and the transition-sensing coils `--(P)--` and `--(N)--` (Table 62 features 8 and 9) write a variable; neither gates power on the accumulated rung condition. The function-block form is R_TRIG (Ed 2 §2.5.2.3.2, Table 35), `Q := CLK AND NOT M; M := CLK;` (`docs/instruction-sets.md` §3.2), whose NOTE says its Q *"will stand at BOOL#1 after its first execution following a “cold restart”"* (Ed 2 p.78, as `docs/organisation.md` §4.6 quotes it): the opposite of this instruction's first scan. |
| Conventional | **ONS** — One Shot | One user-named storage bit, *"set to true to prevent an invalid trigger during the first scan"* (general instructions ref., ONS, p.73, as `docs/organisation.md` §4.6 quotes it). OSR and OSF are the coil forms, with a storage bit and an output bit. Which tags its storage bit may be, and whether its verifier refuses one shared by two instructions: `unverified`. |
| Siemens STEP 7 / TIA Portal LAD | TIA **P_TRIG** "Scan RLO for positive signal edge"; classic `---( P )---` | Classic `---( P )---` is the RLO one-shot; TIA's `--(P)--` is a different thing, a coil that sets an operand on a positive edge. Whether P_TRIG suppresses an edge on the first cycle: `unverified`. |
| CODESYS | no inline element; an **R_TRIG** instance | |
| Mitsubishi GX Works | **MEP** | FX against iQ-R, and the first-cycle behaviour: `unverified`. |

**Chosen:** `ons`
**Why:** Rule 2: IEC has no element for a one-shot on the rung condition, so logex takes the clearest vendor mnemonic, the conventional set's ONS, whose user-named storage bit keeps the cross-scan state in an ordinary tag. The split between `ons` (inline) and `osr`/`osf` (coils) is the conventional set's and not universal: LDmicro's `ELEM_ONE_SHOT_RISING` and `_FALLING` are inline series elements and it has no ONS, and Beremiz makes an edge a modifier on a contact or coil, lowered to a hidden R_TRIG (`docs/instruction-sets.md` §8). A reader from LDmicro will expect `osr` to be the inline one; the Edge detection table keeps `osr` for the coil form. The first-scan suppression is the conventional ONS's, read from the scan's `first` rather than set by a prescan, which logex does not have (`PLAN.md` M1-6, decision 3); the one visible difference is that before its first scan the storage bit holds its declared initial value, not 1. It is the opposite of R_TRIG's first execution, and of the event-task trigger logex takes from MatIEC (`docs/organisation.md` §4.6). A second `ons` on one storage bit is an error, as a second `ton` on one timer is: the false one clears the bit on every scan, so the true one fires on every scan its rung is true, and no arrangement of two works. Any other write to the storage bit (`ote`, `otl`, `otu`, `move`) is a warning, as a second `ote` on one tag is: it makes the one-shot fire on the wrong scans, and logex cannot tell a deliberate re-arm from a mistake.
**Checked:** 2026-09-30, from this repository's survey only: the Edge detection and one-shots table above; `docs/instruction-sets.md` §3.2 (R_TRIG, Table 35), §7 and §8; `docs/organisation.md` §4.6 (the ONS quote and the R_TRIG NOTE). Not re-checked against IEC or a vendor manual for this stanza; the Siemens, CODESYS and Mitsubishi rows are the table's.

### `ton` — on-delay timer: the instruction, and the type word of a timer

| Dialect | Name there | Notes |
|---|---|---|
| logex | `var t1 ton`; `xic go ton t1 5000`; `xic t1.dn ote lamp`, `ge t1.acc 3000` | The type word declares a timer, a `var` with no initial value. The instruction runs it, and one `ton` runs a timer: rung power is its IN. Energised, `.acc` gains the milliseconds since this `ton` last ran, but nothing on the scan that first sees the rung true, and stops at `.pre`, where `.dn` is set; `.tt` is set while it times, `.en` while the rung is true. De-energised, `.acc .dn .tt .en` go to 0. `5000` is the preset, a literal of 0 to 2147483647 ms: the timer's `.pre` when its instance starts or restarts. Logic may `move` another value into `.pre` or `.acc`, and only the `ton` sets `.dn .tt .en`. Nothing may follow it on its path: read the timer with `xic t1.dn` on a rung below. |
| IEC 61131-3 | **TON** | A standard function block: Ed 2 §2.5.2.3.4 Table 37 feature 2a (Ed 3 Table 46), `IN : BOOL`, `PT : TIME` → `Q : BOOL`, `ET : TIME`; a false IN resets ET to 0 at once (`docs/instruction-sets.md` §3.2). An instance is declared as a variable of type TON: `VAR RETAIN TMR1: TON ; END_VAR` is Table 33 feature 3a's own example. The Table 37 NOTE makes the effect of changing PT mid-timing *"implementation-dependent"* (the Timers table above). In IL, the input operators `IN`, `PT` call it (Ed 2 Table 54, rows 11–13 for TP/TON/TOF, `docs/instruction-sets.md` §4). |
| Conventional | **TON** (ladder only); a **TIMER** tag | `.PRE` is DINT, *"(1 millisecond units)"* (general instructions ref., TIMER structure, p.132, as `docs/organisation.md` §3 quotes it); `.ACC`, `.DN`, `.TT`, `.EN`. `ACC = ACC + (current_time − last_time_scanned)`, with a 69-minute scan warning. Prescan clears `.ACC`, `.DN`, `.TT` and `.EN` (general instructions ref., TON, p.134, per `docs/organisation.md` §4.6). TONR is TON with a reset pin, FBD/ST only, and not retentive. That its preset operand is the stored `.PRE` and not re-applied each scan, that logic may `move` into `.PRE` and `.ACC`, which rung condition it passes on, whether it caps `.ACC` at `.PRE`, and what `.DN` does when `.PRE` is raised after done: `unverified`. |
| Siemens STEP 7 / TIA Portal LAD | TIA: IEC box **TON** and coil `---( TON )---`, an IEC_TIMER in an instance DB, `#MyTimer.Q`; classic S5: **S_ODT** / `---( SD )---` | |
| CODESYS | **TON**, an FB instance: `TON1.Q` | |
| Mitsubishi GX Works | native `OUT T0 K100`; FB library TON / TON_E / TON_HIGH / TON_HIGH_E | A global device number split into TS0 / TC0 / TN0. |

**Chosen:** `ton`, for the instruction and for the type word.
**Why:** Rule 1: IEC names the operation TON, and the Timers table finds it *"the one mnemonic every party spells identically"*. The type word is IEC's too: an instance is a variable of type TON, and logex drops the colon as it does in every declaration (`docs/organisation.md` §6.1). The conventional set's TIMER is a vendor word for the same thing, and rule 3 keeps logex from coining `timer`. One word as a mnemonic and a type is read by position, a mnemonic where an instruction starts and a type as a declaration's third word, and it is reserved in any case either way. The model is the conventional set's, not IEC's EN (`docs/organisation.md` §4.3): rung power is IN, and the members are the conventional TIMER's, lowercased, in integer milliseconds, which keeps `T#5s` literals out of the lexer. The rest is logex's own, and each part is said here because the conventional behaviour behind it is `unverified`. The preset literal is the timer's starting `.pre`, and the instruction never writes `.pre`, so a `move` into `.pre` holds until a restart: IEC's PT, an input copied at every call, would make that `move` do nothing. Timing starts at the scan that first sees IN true, as MatIEC's TON takes `START_TIME := CURRENT_TIME` on IN's rising edge and leaves ET at 0 on that call (its `lib/timer.txt`, `TON`). `.acc` stops at `.pre`, as MatIEC sets `ET := PT` when done, and comes down to `.pre` if logic lowers `.pre` below it, as MatIEC's does while counting. `.dn` is `.acc` against `.pre` on every energised scan, so raising `.pre` after done resumes timing where MatIEC's STATE 2 latches Q until IN falls. A negative `.pre` times as 0. A preset of 0 is done on the first energised scan, where MatIEC compares only on the calls after the one that starts the timer. Nothing may follow a `ton` on its path, in its leg or after a group one of whose legs ends in it. logex's output instructions all pass on the power they receive, where an IEC reader draws Q on the right of the block and would expect `.dn` there; which the conventional TON passes on is `unverified`. Refusing both readings leaves the question open, and is the reversible way to leave it: allowing either later breaks no program.
**Checked:** 2026-09-30, from this repository's survey only: the Timers table above, `docs/instruction-sets.md` §3.2, §4 and §7, `docs/organisation.md` §3, §4.3, §4.6 and §6.1; and MatIEC `lib/timer.txt`, `TON`, the file `docs/organisation.md` §8 cites at `7680ed8`, read for this stanza from a copy whose revision was not checked against it. Not re-checked against IEC or a vendor manual for this stanza.

### `eq` — equal

| Dialect | Name there | Notes |
|---|---|---|
| logex | `eq a b`, `eq t1.acc 0` | An input instruction: energised, it passes power when `a` equals `b`; de-energised, it passes none. It writes nothing. Each operand is a dint tag, a dint member or a literal that fits 32 bits; two literals compile, with a warning. |
| IEC 61131-3 | **EQ** | A standard comparison *function*, not an LD element: Ed 3 Table 33 features 1–6, p.91, and Ed 2 Table 28 features 5–10, p.62, list `GT GE EQ LE LT NE` (`docs/instruction-sets.md` §3.1); `docs/instruction-sets.md` §7 reads EQ as T33 f3 from that order, and which feature is which operator is not stated in the survey: `unverified`. ST `=`. Every comparison but NE is extensible: `OUT := (IN1>IN2) & (IN2>IN3) & …`. IL had them as operators, Ed 2 Table 52 rows 12–17, `GT GE EQ NE LE LT` (`docs/instruction-sets.md` §4.1), gone with IL in Ed 4. Which input types the standard admits was not recorded in this survey: `unverified`. |
| Conventional | **EQ** (formerly EQU) | LD and FBD, *"not available in structured text"*; Source A / Source B; also compares strings. Renamed in the 2024 conformance sweep *"to conform to IEC 61131-3 and PLCopen standards"*. Whether it takes BOOL operands: `unverified`. |
| Siemens STEP 7 / TIA Portal LAD | TIA `CMP ==`, typed by the operands' data type; classic `CMP ==I` / `==D` / `==R` | |
| CODESYS | **EQ** ("the IEC operator") | |
| Mitsubishi GX Works | `LD=` / `AND=` / `OR=`; `_U` unsigned; `LDD=` 32-bit | Rung position is part of the mnemonic, as with LD / AND / OR. |

**Chosen:** `eq`
**Why:** Rule 1: IEC names the operation EQ, and since the 2024 sweep the conventional set does too, so the old contrast between the two no longer exists. The arity is two, because logex has no variadic operands: a chain is comparisons in series. The operands are dints only: a bool is tested with `xic` and `xio`, and admitting bools later breaks no program, where narrowing would. Two literals are legal, as IEC's `EQ(1, 1)` is, but draw a warning, since the result never changes. The operand order is IEC's IN1, IN2 and the conventional Source A, Source B. LDmicro still spells it `EQU` (`docs/instruction-sets.md` §7).
**Checked:** 2026-09-30, from the Comparison table above and `docs/instruction-sets.md` §3.1, §4.1 and §7; not re-checked against their sources for this stanza.

### `ne` — not equal

| Dialect | Name there | Notes |
|---|---|---|
| logex | `ne a b` | As `eq`, passing power when `a` and `b` differ. It is `eq` negated, so the two are complementary whatever the env holds. |
| IEC 61131-3 | **NE** | As `eq`. The one non-extensible comparison: *"Inequality NE <> OUT := (IN1 <> IN2) (non-extensible)"* (`docs/instruction-sets.md` §3.1). |
| Conventional | **NE** (formerly NEQ) | |
| Siemens STEP 7 / TIA Portal LAD | `CMP <>` | |
| CODESYS | **NE** | |
| Mitsubishi GX Works | `LD<>` | |

**Chosen:** `ne`
**Why:** Rule 1, as `eq`.
**Checked:** 2026-09-30, as `eq`.

### `lt` — less than

| Dialect | Name there | Notes |
|---|---|---|
| logex | `lt a b` | As `eq`, passing power when `a` < `b`. |
| IEC 61131-3 | **LT** | As `eq`; `docs/instruction-sets.md` §7 reads it as T33 f5 from the list's order, `unverified`. |
| Conventional | **LT** (formerly LES) | |
| Siemens STEP 7 / TIA Portal LAD | `CMP <` | |
| CODESYS | **LT** | |
| Mitsubishi GX Works | `LD<` | |

**Chosen:** `lt`
**Why:** Rule 1, as `eq`. `lt aa bb` reads "aa < bb": the conventional set, IEC and Mitsubishi agree on that order.
**Checked:** 2026-09-30, as `eq`.

### `gt` — greater than

| Dialect | Name there | Notes |
|---|---|---|
| logex | `gt a b` | As `eq`, passing power when `a` > `b`. |
| IEC 61131-3 | **GT** | As `eq`. |
| Conventional | **GT** (formerly GRT) | |
| Siemens STEP 7 / TIA Portal LAD | `CMP >` | |
| CODESYS | **GT** | |
| Mitsubishi GX Works | `LD>` | |

**Chosen:** `gt`
**Why:** Rule 1, as `eq`, with the operand order of `lt`.
**Checked:** 2026-09-30, as `eq`.

### `le` — less than or equal

| Dialect | Name there | Notes |
|---|---|---|
| logex | `le a b` | As `eq`, passing power when `a` ≤ `b`. It is `gt` negated. |
| IEC 61131-3 | **LE** | As `eq`. |
| Conventional | **LE** (formerly LEQ) | The instruction-set reference's LEQ page prints the rename as *"from LES to LE"*, a typo; its summary table gives LEQ→LE (the Comparison table above). |
| Siemens STEP 7 / TIA Portal LAD | `CMP <=` | |
| CODESYS | **LE** | |
| Mitsubishi GX Works | `LD<=` | |

**Chosen:** `le`
**Why:** Rule 1, as `eq`, with the operand order of `lt`.
**Checked:** 2026-09-30, as `eq`.

### `ge` — greater than or equal

| Dialect | Name there | Notes |
|---|---|---|
| logex | `ge a b`, `ge t1.acc 3000` | As `eq`, passing power when `a` ≥ `b`. It is `lt` negated. |
| IEC 61131-3 | **GE** | As `eq`. |
| Conventional | **GE** (formerly GEQ) | |
| Siemens STEP 7 / TIA Portal LAD | `CMP >=` | |
| CODESYS | **GE** | |
| Mitsubishi GX Works | `LD>=` | |

**Chosen:** `ge`
**Why:** Rule 1, as `eq`, with the operand order of `lt`.
**Checked:** 2026-09-30, as `eq`.

### `function_block` — a function block's file: its header, and its kind

| Dialect | Name there | Notes |
|---|---|---|
| logex | `function_block seal`, a `.ld` file's first rung, comments and blank lines allowed before it | The file is a function block type, named on that line as its file is named: `seal.ld` holds `seal`. Its declarations are its members, in order: each `var_input` an input, each `var_output` an output, each `var` its own, an instance it holds included, which only its body names. Its rungs are its body. No `end_function_block`: the file ends it. `Logex.compile/2` returns it as a `%Logex.FbType{}`, which a program's compile takes in `types:`, and `Logex.compile_file/1` finds it beside the file that names it; an instance of it is declared as `var s1 seal` and run by `cal`. From outside, an instance's inputs and outputs are read, as `s1.run`, and nothing writes any of its members. The word is reserved in a function block's file, and recognised in any case as any file's first rung only. A block's name is spelled as a type word in the files that hold it, so it may be no reserved word, and it is matched exactly; it is not reserved itself, so `var seal seal` is legal. No block holds an instance of itself, at any depth. |
| IEC 61131-3 | **FUNCTION_BLOCK** … END_FUNCTION_BLOCK | Ed 2:2003 §2.5.2.2 rule 1, p.69: *"The delimiting keywords for declaration of function blocks shall be FUNCTION_BLOCK...END_FUNCTION_BLOCK"*; Table 33, p.71. Ed 3:2013 §6.6.3.2 rule 1, p.99: *"The keyword FUNCTION_BLOCK, followed by an identifier specifying the name of the function block being declared"*; Table 40 feature 1, p.100. Ed 3 lets inputs be initialised (rule 8), declares instances in every section but VAR_TEMP (rule 17), and makes a VAR PRIVATE unless declared PUBLIC (rule 11). Recursion: Ed 2 §2.5, p.45, *"Program organization units shall not be recursive"*; Ed 3 §6.6.1.1, p.58, *"Implementer specific"*. Ed 2 Table C.2 lists FUNCTION_BLOCK among its keywords. |
| Conventional | a **user-defined instruction** definition | Input, Output and InOut parameters, and local tags that *"are not accessible programmatically"* from outside (the family's manual for its user-defined instructions, Sept 2025, p.23); nested up to 16 levels (p.21); an existing one is edited offline only (design-considerations reference, Sept 2025, p.65). Whether one may hold an instance of itself, and the keyword of its text export: `unverified`. |
| Siemens STEP 7 / TIA Portal LAD | **FB**, a function block, with an instance data block per instance | Its SCL source keyword: `unverified` here. |
| CODESYS | **FUNCTION_BLOCK** … END_FUNCTION_BLOCK, a POU object | `unverified` for this stanza: no CODESYS page on the declaration was read. |
| Mitsubishi GX Works | **FB**, a function block POU | `unverified`. |

**Chosen:** `function_block`
**Why:** Rule 1: IEC's keyword, lowercased, as `var_input` takes VAR_INPUT. A header line rather than a second extension says the file's kind (`docs/organisation.md` §4.3 and decision 4) and keeps one extension for every POU. `end_function_block` is dropped as `end_var` was: one file is one block, so nothing needs closing. The name on the line must match the file's because state is keyed by name (`docs/organisation.md` §4.1): two names for one block would let a file be renamed under a running instance. Its members follow IEC's sections; the departures are logex's earlier ones: no initial value on an input (`var_input`), and an instance only in `var` (`ton`). A block's own `var` is hidden from outside, IEC Ed 3's PRIVATE default and the conventional family's local tags, so from outside an instance has no member deeper than one `.`. Recursion is refused as Ed 2 refuses it, which Ed 3 leaves to the implementer: one instance is one nested map. The word is reserved by file kind (`docs/organisation.md` §4.8), so a program keeps a tag named `function_block`; a program's file can never begin with it, since no instruction is so named.
**Checked:** 2026-10-02. IEC 61131-3:2003 §2.5 p.45, §2.5.2.2 p.69, Table 33 p.71 and Table C.2, and IEC 61131-3:2013 §6.6.1.1 p.58, §6.6.3.2 pp.99–100 and Table 40 p.100, read directly; the conventional family's manual for its user-defined instructions (Sept 2025) pp.21 and 23 and design-considerations reference (Sept 2025) p.65. The Siemens, CODESYS and Mitsubishi rows were not checked for this stanza.

### `cal` — run an instance of a user function block

| Dialect | Name there | Notes |
|---|---|---|
| logex | `var s1 seal`; `xic ready cal s1 start halt motor` | Runs `s1`, an instance of the user function block `seal`. The operands are positional: `seal`'s var_inputs, then its var_outputs, each in declaration order, IL's non-formal call. Rung power is the instance's EN, and the power `cal` passes on is its ENO, which no block can reset, so it is EN. Energised, each input operand is copied into its input, the block's rungs run over the instance's state, and each output is copied out to its operand. De-energised, nothing is copied in, the body does not run, and nothing is written out: the instance is frozen, and so is every tag its outputs name. A timer inside it keeps `.en` and `last` and catches up when it next runs; a one-shot inside it never sees the rung go false. A body runs on its program instance's clock and first scan, so an `ons` in a block first run after the first scan can fire on that run. One `cal` runs an instance; `cal` runs no built-in timer, which `ton t1 5000` runs. |
| IEC 61131-3 | **CAL**, with the C and N modifiers (IL) | Ed 2:2003 §3.2.3 and Table 52 feature 19, pp.125–126; Table 53 feature 1a, p.127, the non-formal call `CAL CMD_TMR(%IX5, T#300ms, OUT, ELAPSED)`. Ed 2's text on p.126 calls feature 1a the formal list and 1b the non-formal, the reverse of its table; logex follows the table, which Ed 3 confirms. The conditional call: *"All assignments in an argument list of a conditional function block invocation shall only be performed together with the invocation, if the condition is true"* (Ed 2 §3.2.3, p.126; Ed 3 §7.2.4.3, p.198). Ed 3: Table 68 feature 21, p.197, and Table 69 feature 1a, p.199. Ed 3 §7.2.1, p.195, marks IL deprecated, and Ed 4 removed it. ST calls an instance by its name (Ed 2 Table 56 item 2, p.132, as `docs/organisation.md` §4.3 quotes it); LD draws a block with EN and ENO (Ed 2 §2.5.2.1a), p.68; Ed 3 §6.6.1.5, pp.63–64). EN and ENO are keywords in Ed 2 Table C.2, and logex has no word for either. |
| Conventional | a **user-defined instruction**, by its own name on the rung; **JSR** for a routine | On a false rung it *"Does not execute any logic for the [instruction] and does not write any outputs. Input parameters are passed values."* (the family's manual for its user-defined instructions, Sept 2025, p.43); a one-shot inside one *"will not detect the rung-in transition to the false state"* (p.20). JSR "Jump to Subroutine" calls a routine, which IEC and logex do not have (the Program control table above). |
| Siemens STEP 7 / TIA Portal LAD | an FB box with its instance data block; classic `---( CALL )`, CALL_FB | As the Program control table above; not checked again for this stanza. |
| CODESYS | IL **CAL**; in LD and FBD a box with EN and ENO | *"When the EN input has the value FALSE at the time of the POU call, the operations defined in the POU are not executed. … The ENO output has the same value as the EN input."* (help, *FBD/LD/IL Element: Box with EN/ENO*, read 2026-10-02). Whether it copies inputs in, or outputs out, on a false EN: `unverified`. |
| Mitsubishi GX Works | CALL(P), FCALL, ECALL, EFCALL | As the Program control table above; how a function block instance is called: `unverified`. |

**Chosen:** `cal`, which supersedes the Program control table's `cal <routine>` row: logex has no routines (`docs/organisation.md` §5), and `cal` runs a function block instance.
**Why:** Rule 1, with its basis stated: IEC has three spellings of the call and `CAL` is the only word among them, and it rests on Ed 2 and Ed 3's IL, which Ed 4 removed (`docs/organisation.md` §4.3). ST's form, the instance's name as the call, would put a tag where an instruction starts, so the words that start an instruction would depend on each file's declarations; that undoes the rule that mnemonics are reserved and never tags. The positional operands are IL's non-formal call: the arity and type errors name the formal, and two swapped bool operands still compile, the price of the form. Rung power has two meanings, on purpose: on `ton` it is the timer's IN, and a false rung resets the timer, the conventional model; on `cal` it is the instance's EN, IEC's. What a false EN does is the implementer's to state under Ed 3 (§6.6.1.5 rule 4: outputs on a false ENO are *"Implementer specific"*), and logex states it: nothing in, nothing out, IEC Ed 3's "external implementation" (EXAMPLES 2 and 4, p.64) and IL's conditional call; MatIEC copies inputs in and the frozen outputs out (its "internal implementation", EXAMPLE 1 and 3), and the conventional family copies inputs in. One `cal` per instance, as one `ton` per timer: IEC lets an instance be called twice in a scan, which would run its body twice with its inputs replaced halfway, so logex refuses the second, which allowing later breaks no program. `cal` passes on the power it receives, so anything may follow it on its path.
**Checked:** 2026-10-02. IEC 61131-3:2003 §2.5.2.1a) p.68, §3.2.3 and Tables 52 and 53, pp.125–127, Table C.2; IEC 61131-3:2013 §6.6.1.5 pp.63–64, §7.2.1 p.195, §7.2.4.3 p.198, Tables 68 and 69, pp.197–199, read directly; the conventional family's manual for its user-defined instructions (Sept 2025) pp.20 and 43; CODESYS help, *FBD/LD/IL Element: Box with EN/ENO*; MatIEC at `3a41303`, `stage4/generate_c/generate_c.cc` and `generate_c_st.cc` (`fb_invocation_c`). The Siemens and Mitsubishi rows are the Program control table's.
