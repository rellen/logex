# Instruction naming survey

Every logex instruction is named after surveying what IEC 61131-3 and the major vendors
call the same operation. This file is that survey: the reference tables first, then one
stanza per mnemonic, declaration word or configuration file's word. It is **append-only** — a stanza with no implementation is fine and
encouraged, so an instruction can be surveyed long before it is built.

`test/logex/naming_test.exs` fails if a mnemonic reaches `@instructions`, a declaration
word `Logex.Declarations`, or a configuration file's word `Logex.Configuration.Text`,
without a stanza here.

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
type word of a declaration line, and by each word of a configuration file's lines; syntax
tokens like the branch delimiters are not words and need none. Read across stanzas with
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

One per mnemonic or declaration word. The first six below are the instructions logex
shipped when this file was written; all were surveyed retrospectively, in the commit that
introduced it. `move` has since replaced `mov`. The five after it, `var` to `dint`, are the
words of `PLAN.md` M1-3's declaration lines, surveyed before their code.

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

### `program` — instantiate a program type in a configuration

| Dialect | Name there | Notes |
|---|---|---|
| logex | `program m1 motor`, `program m1 motor with fast` | A line of a configuration file (`.logex`): an instance `m1` of the program type `motor`, compiled from `motor.ld` beside it. The type is always the third word, and is named only there, so `program motor motor` is no clash. Without `with` the instance has no task and runs once in every cycle, after the tasks. Reserved, in any case, in a configuration file only (`docs/organisation.md` §4.8): a program's `.ld` file has no header line and never spells its own type. |
| IEC 61131-3 | **PROGRAM** … **WITH** … **:** | Ed 2 §2.7.1 Table 49 (p.112) features 6a, *"WITH construction for PROGRAM to TASK association"*, and 6c, *"PROGRAM declaration with no TASK association"*; Figure 20 (p.113): `PROGRAM P1 WITH SLOW_1 : F(x1 := %IX1.1) ;`. Ed 2 §2.5.3 (p.83): *"Programs can only be instantiated within resources"*. Ed 3 Table 62 (pp.178–179) and Figure 28 the same. Ed 2 Table C.2 lists `PROGRAM...WITH...`. |
| Conventional | a **program**, defined and scheduled at once | *"Programs can be scheduled under only one task."* and *"Scheduled programs must be defined."* (import/export reference, Sept 2025, p.63). That it has no type and instance apart is an inference (`docs/organisation.md` §8). |
| Siemens STEP 7 / TIA Portal LAD | no program instance: an organization block (OB) the operating system calls, which calls FBs and FCs | *"OBs are the interface between the operating system and the user program. They are called by the operating system"*; *"Several Main OBs can be created in a program. The OBs are processed sequentially by OB number."* (Siemens *Programming Guideline for S7-1200/S7-1500*, Entry ID 81318674, V1.5, 03/2017, §3.2.1, pp.43–44). No keyword. |
| CODESYS | a POU of type PROGRAM, in a task's list of program calls | *"You can configure the priority, the type with time behavior, and a watchdog. You can also add PROGRAM calls."* (*Object: Task*, help read 2026-10-02). |
| Mitsubishi GX Works | a **program block** in a program file | *"A program block is a unit for making up a program. Multiple program blocks can be created in a program file and executed in the order specified in the program file setting."* (Mitsubishi *MELSEC iQ-R Programming Manual (Program Design)*, SH(NA)-081265ENG-R, §3.1, p.12). GX Works3; no keyword names an instance of one. |

**Chosen:** `program`
**Why:** Rule 1, IEC's keyword lowercased, for the same thing: a program type instantiated in a configuration. The order of the words is logex's: IEC writes `PROGRAM inst WITH task : type`, and with the `:` dropped that order reads badly, so the type is always the third word and `with` comes last (`docs/organisation.md` §4.4).
**Checked:** 2026-10-02. IEC 61131-3:2003 §2.5.3, §2.7.1 Table 49 and Figure 20, Table C.2, and IEC 61131-3:2013 Table 62 and Figure 28, read directly; the conventional family's import/export reference (Sept 2025); CODESYS online help, *Object: Task*; Siemens *Programming Guideline for S7-1200/S7-1500*, Entry ID 81318674, V1.5, 03/2017; Mitsubishi *MELSEC iQ-R Programming Manual (Program Design)*, SH(NA)-081265ENG-R. Each quotation and page number checked again against the text of its source on 2026-10-04.

### `var_global` — declare a global of a configuration

| Dialect | Name there | Notes |
|---|---|---|
| logex | `var_global estop bool`, `var_global setpoint dint 900`, `var_global k1 bool at panel.q.0` | A line of a configuration file (`.logex`): a bool or a dint with one value for the whole configuration. Unlocated, it may take an initial value; located with `at` it is an input or an output point and takes none. Instances reach it through a connection, `m1.start estop`, or by name through `var_external`. Reserved, in any case, in a configuration file only (`docs/organisation.md` §4.8), so a program's `.ld` file may still name a tag `var_global`. |
| IEC 61131-3 | **VAR_GLOBAL** … END_VAR | Ed 2 Table 16a (p.39): *"Global variable declaration (2.7.1)"*; Table 49 (p.112) feature 2, *"VAR_GLOBAL...END_VAR construction within CONFIGURATION"*, and 7, *"Declaration of directly represented variables in VAR_GLOBAL"*; §2.4.3 (p.40): such variables *"are only accessible to a program organization unit via a VAR_EXTERNAL declaration"*. Ed 3 Figure 7 (p.50) and Table 62 features 2 and 7. |
| Conventional | a controller-scope tag | *"Controller tags are seen by routines in any program."* (import/export reference, Sept 2025, ch.8): no declaration is needed to reach one. |
| Siemens STEP 7 / TIA Portal LAD | a PLC tag, or a tag of a **global data block** | *"Variable data is located in data blocks that are available to the entire user program."*, *"All blocks in the user program can access global DBs."* (Siemens *Programming Guideline for S7-1200/S7-1500*, Entry ID 81318674, V1.5, 03/2017, §3.2.7, p.52); *"The global memory area is available for each block in the user program."* (§3.4, p.60). No VAR_GLOBAL keyword in that source. |
| CODESYS | **VAR_GLOBAL**, in a global variable list | *"You declare global variables in global variable lists or in the declaration part of programming objects between the keywords VAR_GLOBAL and END_VAR."* (*Variable: VAR_GLOBAL*, help read 2026-10-02). |
| Mitsubishi GX Works | a **global label**, class **VAR_GLOBAL** | *"A label that is valid for all the program data when multiple program data are created in the project."* (Mitsubishi *MELSEC iQ-R CPU Module User's Manual (Application)*, SH(NA)-081264ENG-AR, Terms, p.35); its class is VAR_GLOBAL, as for a global FB instance (Mitsubishi *MELSEC iQ-R Programming Manual (Program Design)*, SH(NA)-081265ENG-R, §3.3, p.24). |

**Chosen:** `var_global`
**Why:** Rule 1, IEC's keyword lowercased, spelled as `var_input` and `var_output` are. One declaration a line and no END_VAR, as M1-3's declarations. A global is a bool or a dint: a function block instance stays inside its program (`var t1 ton`).
**Checked:** 2026-10-02. IEC 61131-3:2003 §2.4.3, Table 16a and Table 49, and IEC 61131-3:2013 Figure 7 and Table 62, read directly; the conventional family's import/export reference (Sept 2025); CODESYS online help, *Variable: VAR_GLOBAL*; Siemens *Programming Guideline for S7-1200/S7-1500*, Entry ID 81318674, V1.5, 03/2017; Mitsubishi *MELSEC iQ-R Programming Manual (Program Design)*, SH(NA)-081265ENG-R; Mitsubishi *MELSEC iQ-R CPU Module User's Manual (Application)*, SH(NA)-081264ENG-AR. Each quotation and page number checked again against the text of its source on 2026-10-04, which corrected Ed 3's Table 62 features from 2 and 4 (a global in a resource) to 2 and 7.

### `at` — give a global a location

| Dialect | Name there | Notes |
|---|---|---|
| logex | `var_global k1 bool at panel.q.0`, `var_global sp_1 dint at drive.q.0`, `… at rack.i.2.7` | Makes a global a point: `i` an input point, set only from the input image, `q` an output point, returned in the output image. A location is a device's name, `i` or `q` in lowercase, then one whole-number field or more with no leading zero, the leftmost the highest, so each point has one spelling; it lexes as one name. One address holds one global, and two device names that differ only in case are refused, as two names are. What a device and an address mean is the host's (`docs/organisation.md` §4.5). Reserved, in any case, in a configuration file only (`docs/organisation.md` §4.8), so a program's `.ld` file may still name a tag `at`. |
| IEC 61131-3 | **AT** | Ed 2 §2.4.3.1 (p.41): *"The assignment of a physical or logical address to a symbolically represented variable shall be accomplished by the use of the AT keyword"*, *"in programs and VAR_GLOBAL declarations only"*. Ed 2 §2.4.1.1 (p.37): a direct representation is `%`, a location prefix (I, Q, M), a size prefix (X, B, W, D, L) and *"a hierarchical physical or logical address with the leftmost field representing the highest level of the hierarchy"*, as `%IX1.1`. Ed 2 Table C.2 lists AT. |
| Conventional | an alias tag on an I/O member | `tag_name [OF alias]` (import/export reference, ch.6, p.124), over I/O tags such as `Local:0:I.Data` (general instructions reference, p.563): no location keyword. |
| Siemens STEP 7 / TIA Portal LAD | a PLC tag with an absolute address, `%I0.0` | *"PLC tag of the type of the created PLC data type and start address of the I/O data area (%Ix.0 or %Qx.0, e.g., %I0.0, %Q12.0, …)"* (Siemens *Programming Guideline for S7-1200/S7-1500*, Entry ID 81318674, V1.5, 03/2017, §3.6.5, p.75). The word `AT` names something else there: an *"AT instruction"*, an access type of a non-optimized block (Table 2-6, p.18); what it does was not read in a primary source (`unverified`). |
| CODESYS | **AT** `%IX7.5` | *"The `AT` keyword in the variables declaration assigns to a project variable a specific input address, output address, or memory address of the controller which is configured in the device tree."* Syntax `<variable name> AT %<address>:<data type>;` (*AT Declaration*, help read 2026-10-02). |
| Mitsubishi GX Works | a global label assigned a device, `X0` an input, `Y0` an output | A global label is *"an optional label, which can be created for any specified device"*; *"Devices such as X, Y, M, D, and others are provided depending on the intended use."* (Mitsubishi *MELSEC iQ-R CPU Module User's Manual (Application)*, SH(NA)-081264ENG-AR, Terms, p.35). No keyword. |

**Chosen:** `at`, with the location `panel.q.0`.
**Why:** The keyword is rule 1, IEC's lowercased. The location is where this stanza strains rule 3, and says so: IEC has a standard form, `%QX0.0`, and logex coins `panel.q.0`, a named device where IEC writes `%`. It keeps what IEC standardises: `i` and `q` are Table 15's prefixes, lowercased, and the integer fields are IEC's hierarchical address. It drops two things for stated reasons: the size letter, since the declared type carries the size and logex has no BYTE or WORD; and `%`, since a logex host binds devices by name when it starts a runner, and IEC leaves an address's meaning to the manufacturer (§2.4.1.1). It also lexes as one name under the settled `.` rule, where `%` is an illegal character and would need a lexeme of its own. The cost is real: a reader who knows `%QX0.0` must learn that `panel.q.0` is an output on the device `panel`. The fallback, `at %ix0.0` after `at` only, stays open (`docs/organisation.md` decision 6). There is no `m`: memory is an unlocated global.
**Checked:** 2026-10-02. IEC 61131-3:2003 §2.4.1.1 and §2.4.3.1 and Table C.2, read directly; the conventional family's import/export and general instructions references, as `docs/organisation.md` §3 quotes them; CODESYS online help, *AT Declaration*; Siemens *Programming Guideline for S7-1200/S7-1500*, Entry ID 81318674, V1.5, 03/2017; Mitsubishi *MELSEC iQ-R CPU Module User's Manual (Application)*, SH(NA)-081264ENG-AR. Each quotation and page number checked again against the text of its source on 2026-10-04, the CODESYS page by fetching it again.

### `task` — declare a task in a configuration

| Dialect | Name there | Notes |
|---|---|---|
| logex | `task fast interval 10 priority 1` | A line of a configuration file (`.logex`): a periodic task `fast`, due every 10 ms, at priority 1. A task's inputs come in IEC's order, `single`, `interval`, `priority`, each once. Until event tasks bring `single` (M2-6, with its own stanza), a task needs `interval`, and it always needs `priority`, as IEC's grammar does. A program instance runs under it through `with`. A scan takes no logical time and nothing preempts it, so a task orders the scans of one cycle and nothing more (`docs/organisation.md` §4.6). A task that runs no instance is a warning. No edit adds or removes a task while it runs, until a rule for that is verified (decision 19). Reserved, in any case, in a configuration file only (`docs/organisation.md` §4.8). |
| IEC 61131-3 | **TASK** | Ed 2 §2.7.2 (pp.114–115): *"a task is defined as an execution control element which is capable of invoking, either on a periodic basis or upon the occurrence of the rising edge of a specified Boolean variable, the execution of a set of program organization units"*, and rules 1 to 4. Table 49 features 5a *"Periodic TASK construction"* and 5b *"Non-periodic TASK construction"* (p.112); Table 50 (p.116), whose general form gives SINGLE a BOOL, INTERVAL a TIME and PRIORITY a UINT; Figure 20 (p.113): `TASK FAST_1(INTERVAL := t#10ms, PRIORITY := 1) ;`. The grammar puts the inputs in the order `SINGLE`, `INTERVAL`, `PRIORITY`, the first two optional (Annex B.1.7, p.158). Ed 3: §6.8.2 (pp.180–182) gives the same rules as a) to d), and Table 62 features 5a and 5b (p.178), Table 63 (p.182) and Annex A (p.226) match. Ed 4: §6.8.2 *Tasks* (p.200) and Table 64 *Task* (p.201) by its contents pages; their text `unverified`. Ed 2 Table C.2 (p.164) lists TASK as a keyword. |
| Conventional | **TASK** … END_TASK in its text export; a task is Continuous, Periodic or Event | *"The controller runs only one task at one time."* (tasks manual, Sept 2025, p.8). The text export declares one as `TASK <task_name> [(Description := "text", Attributes)] <program_name>; END_TASK` (import/export reference, Sept 2025, p.312), and *"There can be only one continuous task."* (p.63). |
| Siemens STEP 7 / TIA Portal LAD | an **organization block** (OB) the operating system calls; a cyclic interrupt OB for a periodic one | *"OBs are the interface between the operating system and the user program. They are called by the operating system"* (*Programming Guideline for S7-1200/S7-1500*, Entry ID 81318674, V1.5, 03/2017, §3.2.1, p.43). *"In STEP 7, the organization blocks OB 30 to OB 38 are provided for the processing of cyclic interrupts."* (SIMATIC S7-1500 *Cycle and response times*, A5E03461504-02, 02/2014, p.21). |
| CODESYS | a **Task** object, of type Cyclic, Event, External, Freewheeling or Status | *"You configure the task in the object. You can configure the priority, the type with time behavior, and a watchdog. You can also add PROGRAM calls."* (*Object: Task*). |
| Mitsubishi GX Works | a program's **execution type**: initial, scan, fixed scan, event or standby | *"Set the execution condition of the program."* (MELSEC iQ-R CPU Module User's Manual (Application), SH(NA)-081264ENG-AR, §1.5, p.59, with a subsection for each type to p.69), set in [CPU Parameter] → [Program Setting] (p.61). iQ-R only; FX and iQ-F were not read. |

**Chosen:** `task`
**Why:** Rule 1, IEC's keyword lowercased; the conventional family's text export and CODESYS use the same word. The line is IEC's `TASK FAST_1(INTERVAL := t#10ms, PRIORITY := 1) ;` with the parentheses, `:=`, commas, `;` and `t#` gone, as a declaration line drops IEC's `:`, `:=` and `;` (the `var` stanza). The inputs keep IEC's names and the order of IEC's grammar, so a reader who knows IEC finds each where IEC puts it.
**Checked:** 2026-10-04. IEC 61131-3:2003 §2.7.2, Tables 49 and 50, Figure 20, Annex B.1.7 and Table C.2, and IEC 61131-3:2013 §6.8.2, Tables 62 and 63 and Annex A, read directly; IEC 61131-3:2025's contents pages, from the publisher preview; the conventional family's tasks manual and import/export reference (both Sept 2025); Siemens *Programming Guideline for S7-1200/S7-1500*, Entry ID 81318674, V1.5, and SIMATIC S7-1500 *Cycle and response times*, A5E03461504-02; CODESYS online help, *Object: Task*, as saved on 2026-10-02; Mitsubishi SH(NA)-081264ENG-AR.

### `interval` — a periodic task's period

| Dialect | Name there | Notes |
|---|---|---|
| logex | `task fast interval 10 priority 1` | A whole number of milliseconds, 1 to 2147483647, written as a literal. The task is due at the start, then at every whole interval after it, so its phase never drifts; a restart starts the count again from its own time. A cycle that spans several intervals runs the task once, counts the periods it missed and reports one `{:overlap, task, missed}` (`docs/organisation.md` §4.6). Once OE-2 edits a configuration, an interval may change while it runs (decision 19), and the task is then next due at `min(next_due, now + new interval)` (decision 40): a shorter interval takes effect within one new period, and no run is added at the switch. With `single` as well (M2-6), the task runs periodically only while the trigger is 0 (decision 39). Reserved, in any case, in a configuration file only (`docs/organisation.md` §4.8). |
| IEC 61131-3 | **INTERVAL**, an input of TASK | Ed 2 §2.7.2 rule 2 (p.114): *"If the INTERVAL input is non-zero, the associated program organization units shall be scheduled for execution periodically at the specified interval as long as the SINGLE input stands at zero (0). If the INTERVAL input is zero (the default value), no periodic scheduling of the associated program organization units shall occur."* A TIME (Table 50, p.116), written `t#10ms` (Figure 20, p.113). Optional in both grammars, its value a `data_source`: a constant, a global, a program output or a direct variable (Ed 2 Annex B.1.7, p.158; Ed 3 Annex A, p.226). Its resolution is one of the *"implementation-dependent parameters"* (Ed 2 §2.7.2, p.114). Ed 3 §6.8.2 b) (p.181) and Table 63 (p.182) the same. Not in Ed 2 Table C.2 (`docs/organisation.md` §4.8). |
| Conventional | a periodic task's **period**; **Rate** in its text export and on the task object | *"You can configure the time period from 0.1 ms…2000 s. The default is 10 ms."* (tasks manual, p.9). The text export writes it `Rate`, as in `TASK joe (Type := Periodic,  Priority := 8, Rate := 10000)` (import/export reference, p.315), and its attribute table gives the range as *"1.000...2,000,000.000 µs"* (p.313), where the tasks manual's 2000 s is 2,000,000 ms: the unit of the exported number is `unverified`. Logic reads and writes the task object's `Rate`, a DINT: *"Time is in microseconds."* (general instructions reference, Sept 2025, TASK object, p.276). |
| Siemens STEP 7 / TIA Portal LAD | a cyclic interrupt OB's **cycle** | *"With a cyclic interrupt, you can have a particular program processed in a defined cycle."* (SIMATIC S7-1500 *Cycle and response times*, A5E03461504-02, p.21), and *"The cycle of a cyclic interrupt is defined as the time from the call of a cyclic interrupt OB to the next call of a cyclic interrupt OB."* (p.22). |
| CODESYS | **Interval**, of a Cyclic task | *"Time span after which the task is restarted (task cycle time)"*, required, given as a TIME, `t#200ms`, or as a number whose unit is chosen beside it (*Object: Task*). |
| Mitsubishi GX Works | a fixed scan execution type program's **fixed scan interval** | Such a program is *"An interrupt program which is executed at a specified time interval."* (SH(NA)-081264ENG-AR §1.5, p.60), and its setting *"Sets the fixed scan interval to execute the fixed scan execution type program."*: 0.5 to 60000 ms in steps of 0.5 ms, or 1 to 60 s (p.61). |

**Chosen:** `interval`
**Why:** Rule 1, IEC's input name lowercased. The conventional family's `Rate`, Siemens' cycle and Mitsubishi's fixed scan interval are vendor words for it, and CODESYS spells it as IEC does. It is a whole number of milliseconds, not a TIME literal (decision 13), as a timer's preset is (the Timers table above), so the lexer reads no `t#10ms`; CODESYS's own field takes a bare number too. 0 is refused: IEC reads it as no periodic scheduling and MatIEC runs such a task every tick (`docs/organisation.md` §4.4), and a task-less instance already runs once every cycle. The upper bound is a dint's, as M2-1 checks it (`docs/organisation.md` §4.10). Only a constant is taken, where IEC's `data_source` also takes a variable; widening that later breaks no configuration (`docs/organisation.md` §4.6).
**Checked:** 2026-10-04. IEC 61131-3:2003 §2.7.2, Table 50, Figure 20 and Annex B.1.7, and IEC 61131-3:2013 §6.8.2, Table 63 and Annex A, read directly; the conventional family's tasks manual, import/export reference and general instructions reference (all Sept 2025); Siemens SIMATIC S7-1500 *Cycle and response times*, A5E03461504-02; CODESYS online help, *Object: Task*, as saved on 2026-10-02; Mitsubishi SH(NA)-081264ENG-AR. MatIEC's reading is `docs/organisation.md` §4.4's, not re-checked for this stanza.

### `priority` — a task's priority, 0 the highest

| Dialect | Name there | Notes |
|---|---|---|
| logex | `priority 1` | Required on every task: 0 to 65535, 0 the highest (decision 37). Due tasks run by priority, then the earlier due time, then declaration order (decision 11), and task-less instances after them. Nothing preempts a scan, so a priority orders the scans of one cycle and nothing more (`docs/organisation.md` §4.6). Once OE-2 edits a configuration, a priority may change while it runs (decision 19). Reserved, in any case, in a configuration file only (`docs/organisation.md` §4.8). |
| IEC 61131-3 | **PRIORITY**, an input of TASK | Ed 2 §2.7.2 rule 3 (p.114): *"with zero (0) being highest priority and successively lower priorities having successively higher numeric values"*; and for ties, rule 3 a) (p.115): *"the program organization unit with the longest waiting time at the highest scheduled priority shall be executed"*. A UINT in both editions, Ed 2's Table 50 (p.116) and Ed 3's Table 63 (p.182), which Table 10's note d makes 0 to 2^16 − 1 (Ed 2 p.31, Ed 3 p.32). Required by both grammars, Ed 2's `'PRIORITY' ':=' integer ')'` (Annex B.1.7, p.158) and Ed 3's `'PRIORITY' ':=' Unsigned_Int ')'` (Annex A, p.226), neither of which bounds it. Ed 3 §6.8.2 c) (p.181) the same words. Not in Ed 2 Table C.2. |
| Conventional | a task's **priority**, a lower number the higher; **Priority** in its text export | *"Assign a priority number that is less than (higher priority) the priority number of the other task."* (tasks manual, p.12); 15 levels on most controllers (p.11); the continuous task takes none and *"always runs at the lowest priority"* (p.13). The text export writes `Priority := 8`, *"Specify the priority of a periodic task (1...15)"* (import/export reference, pp.313, 315), and the task object's `Priority` gives *"Valid values 0...15."* (general instructions reference, pp.275–276). Tasks of one priority time-slice, 1 ms each (tasks manual, p.12). |
| Siemens STEP 7 / TIA Portal LAD | an OB's priority, **numbered the other way** | *"All cycle OBs always have the lowest priority of 1. The highest priority is 26."* (SIMATIC S7-1500 *Cycle and response times*, A5E03461504-02, p.9). A reader who knows S7-1500 will read `priority 1` backwards. Ties: *"If two pending tasks have the same priority, these tasks are processed in the order in which the tasks occurred."* (same page). |
| CODESYS | **Priority** | *"Possible values: 0..31, where 0 is the highest priority"* (*Object: Task*). Ties: *"the task which has been in the queue the longest is processed first"* (*Task Configuration*), though *Object: Task* says tasks of one priority are run *"by means of the round-robin time-slicing method"*. |
| Mitsubishi GX Works | an interrupt program's **interrupt priority**, 1 the highest to 8 the lowest | *"The interrupt programs are executed in the order of priority."* (SH(NA)-081264ENG-AR §1.7, p.75). A fixed scan execution type program sits at interrupt priority 4, which cannot be changed, after the internal-timer interrupts I31 to I28 when they occur together (§1.7, p.89). Scan execution type programs take no interrupt priority: the module runs them *"According to the program settings"* (§1.1, p.41). |

**Chosen:** `priority`
**Why:** Rule 1, IEC's input name lowercased, in IEC's direction, 0 the highest, which the conventional family, CODESYS and Mitsubishi's interrupt priorities share. Siemens numbers the other way and is named here so that a reader from it is warned. The range is IEC's own, a UINT's 0 to 65535 (decision 37), not a dint's: it starts strict, where relaxing later breaks no plant, and it is the standard's type, not one vendor's number as CODESYS's 0 to 31 would be. The conventional family's 15 levels and CODESYS's 32 fit inside it. The tie-break is IEC's rule 3 a), the longest waiting, read as the earlier due time, then declaration order, as CODESYS's *Task Configuration* also states it; scans that take no time cannot show the conventional family's time slice.
**Checked:** 2026-10-04. IEC 61131-3:2003 §2.7.2, Tables 10 and 50, Annex B.1.7 and Table C.2, and IEC 61131-3:2013 §6.8.2, Tables 10 and 63 and Annex A, read directly; the conventional family's tasks manual, import/export reference and general instructions reference (all Sept 2025); Siemens SIMATIC S7-1500 *Cycle and response times*, A5E03461504-02; CODESYS online help, *Object: Task* and *Task Configuration*, as saved on 2026-10-02; Mitsubishi SH(NA)-081264ENG-AR.

### `with` — schedule a program instance under a task

| Dialect | Name there | Notes |
|---|---|---|
| logex | `program m1 motor with fast` | The last two words of a `program` line (the `program` stanza): the instance runs under the task `fast`, once in each cycle in which `fast` is due, in the order of the `program` lines. Without `with`, an instance has no task and runs once in every cycle, after the tasks. An instance has one task or none, and no edit moves it to another while it runs (decision 19). An unknown task is a located diagnostic (`docs/organisation.md` §4.4). Reserved, in any case, in a configuration file only (`docs/organisation.md` §4.8). |
| IEC 61131-3 | **WITH** | Ed 2 Table 49 feature 6a, *"WITH construction for PROGRAM to TASK association"* (p.112), and Figure 20 (p.113): `PROGRAM P1 WITH SLOW_1 :`; the grammar `'PROGRAM' [RETAIN \| NON_RETAIN] program_name ['WITH' task_name] ':' program_type_name` (Annex B.1.7, p.158). Feature 6c, *"PROGRAM declaration with no TASK association"*, is a `program` line without `with`. Feature 6b, a function block instance WITH a task, is deferred (`docs/organisation.md` §5). Ed 3 Table 62 features 6a to 6c (p.178), Figure 28 (pp.179–180), Table 63 feature 3a (p.182) and Annex A (p.226) the same. Ed 2 Table C.2 (p.164) lists both `WITH` and `PROGRAM...WITH...`. |
| Conventional | no keyword: a program is listed in its task's block | *"The list of programs scheduled for a task are listed in the task declarations block, as shown above. The programs are executed in the order they are specified."* (import/export reference, p.315), under `TASK joe (…)`, as `sue;` and `betty;` before `END_TASK`. *"Programs can be scheduled under only one task."* (p.63). |
| Siemens STEP 7 / TIA Portal LAD | a call of an FB or FC from an OB | *"OBs are called by the operating system of the controller."*, and Figure 3-3, *"Using several Main OBs"*, draws each Main OB calling its FBs and FCs (*Programming Guideline for S7-1200/S7-1500*, Entry ID 81318674, V1.5, 03/2017, §3.2.1, p.44). |
| CODESYS | no keyword: a **program call** in the task's list | *"POUs (POU object with type PROGRAM) which are called by the task in succession"*, in *"the call order configured here from top to bottom"* (*Object: Task*, Program calls). |
| Mitsubishi GX Works | a program's execution type, set in [Program Setting] | *"Select the program name and set the execution type to "Fixed Scan"."* (SH(NA)-081264ENG-AR §1.5, p.61). |

**Chosen:** `with`
**Why:** Rule 1, IEC's keyword lowercased, for the same association. Where IEC writes `PROGRAM inst WITH task : type`, logex puts the type third and `with` last, because with the `:` dropped IEC's order reads badly (the `program` stanza; `docs/organisation.md` §4.4). None of the vendor documents read gives it a keyword: each lists a program under its task, or sets the program's execution itself.
**Checked:** 2026-10-04. IEC 61131-3:2003 Table 49, Figure 20, Annex B.1.7 and Table C.2, and IEC 61131-3:2013 Tables 62 and 63, Figure 28 and Annex A, read directly; the conventional family's import/export reference (Sept 2025); Siemens *Programming Guideline for S7-1200/S7-1500*, Entry ID 81318674, V1.5; CODESYS online help, *Object: Task*, as saved on 2026-10-02; Mitsubishi SH(NA)-081264ENG-AR.
