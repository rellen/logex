# Instruction sets: what IEC 61131-3 specifies, and what free software implements

## 1. What this document is

[`docs/naming.md`](naming.md) answers "what does the wider world call this operation?" by
surveying IEC 61131-3 against four commercial toolchains. It has no free-software coverage
at all — grep it for OpenPLC, Beremiz, MatIEC, ldmicro or ClassicLadder and you get zero
hits. This document is the complement, and it answers two different questions:

1. **What does the standard actually specify for ladder diagram**, at the level of clause
   and table numbers, rather than at the level of "IEC says X"; and
2. **what do free and open-source PLC projects actually implement**, read out of their own
   source trees.

It does not restate naming.md's vendor tables. Where a row here touches one, it points at
it. naming.md remains the place a mnemonic decision is recorded; this is the reference a
contributor reads *before* writing that stanza, to know what the standard requires and
what the free-software world already calls the thing.

**Method.** Every entry cites either an edition, clause and table/feature number, or a
repository file path with a line or symbol, and carries a short verbatim quote from that
location. Everything that could not be sourced is in [§10 Unverified](#10-unverified) —
including the places where two sources disagree and neither could be made to win.

**A caution about the citations themselves.** Upstream line numbers drift, so this document
prefers a durable anchor wherever one exists — a constant's *value*, a function name, a
table and feature number — over a line number, which is this repository's own rule in
`CONTRIBUTING.md` ("Anchor on names, not line numbers"). Treat any line number as of the
commit named beside it. That rule was earned here: reviewing this document caught fifteen
citation defects and **not one fabricated instruction** — every failure was a real
mnemonic pointed at the wrong line, page or constant family. One of them was in the review
itself, which "corrected" ClassicLadder's `ELE_COMPAR` from line 153 to 183; current
LinuxCNC master has it at 153, so the original was right and the correction was the error.
That is why the ClassicLadder tables below cite constant values and function names instead.

---

## 2. What IEC 61131-3 specifies for LD

### 2.1 The finding, stated plainly: there are no mnemonics

The LD element tables have a **Symbol** column and a **Description** column. They have no
mnemonic column, and no two-to-four letter mnemonic appears anywhere in them. The element
names are English phrases — "Normally open contact", "SET (latch) coil", "Positive
transition-sensing coil". This was checked by reading Ed 2:2003 Tables 57–62 in full,
not by taking naming.md's word for it; it independently confirms naming.md's central
claim, and it is why rule 2 of the naming rule exists at all.

Ladder in IEC 61131-3 is a **connection graph of graphical elements**, not an instruction
stream. That is also how the standard's own interchange format models it (see
[§6](#6-plcopen-xml--iec-6113110)).

### 2.2 The graphical elements

Ed 2:2003 numbering is confirmed from the standard's own text. Ed 3:2013 numbering is
confirmed from a secondary source — the conventional set's own IEC-compliance tables,
which cite table *and* feature numbers (see [§9](#9-sources) for why that document is
cited without a URL).

| Element | Ed 2:2003 | Ed 3:2013 | What the standard says |
|---|---|---|---|
| Left power rail | §4.2.1 T59 f1 | T74 f1 | *"The state of the left rail shall be considered ON at all times."* |
| Right power rail | §4.2.1 T59 f2 | T74 f2 | *"No state is defined for the right rail."* — it may be implicit |
| Horizontal link | §4.2.2 T60 f1 | T74 f3 | *"transmits the state of the element on its immediate left to the element on its immediate right"* |
| Vertical link | §4.2.2 T60 f2 | T74 f4 | inclusive OR of the horizontal links on its **left**, copied only rightward — see §2.3 |
| Normally open contact | §4.2.3 T61 f1 | T75 f1 | AND of the left link with a function of the associated variable |
| Normally closed contact | §4.2.3 T61 f3 | T75 f2 | *"The state of the left link is copied to the right link if the state of the associated Boolean variable is OFF."* |
| Positive transition-sensing contact | §4.2.3 T61 f5 | T75 f3 | right link ON for one evaluation on an OFF→ON transition of the variable *while the left link is ON* |
| Negative transition-sensing contact | §4.2.3 T61 f7 | T75, feature number **unverified** | ON→OFF mirror of the above |
| Coil | §4.2.4 T62 f1 | T76 f1 | *"A coil copies the state of the link on its left to the link on its right without modification, and stores an appropriate function of the state or transition of the left link into the associated Boolean variable."* |
| Negated coil | §4.2.4 T62 f2 | T76, inferred **f2**, unverified | *"The state of the left link is copied to the right link. The inverse of the state of the left link is copied to the associated Boolean variable."* |
| SET (latch) coil | §4.2.4 T62 f3 | T76 f3 | set ON when the left link is ON, *"and remains set until reset by a RESET coil"* |
| RESET (unlatch) coil | §4.2.4 T62 f4 | T76 f4 | reset OFF when the left link is ON, until set by a SET coil |
| Positive transition-sensing coil | §4.2.4 T62 f8 | T76 f8 | variable ON for one evaluation on a left-link OFF→ON; *"The state of the left link is always copied to the right link."* |
| Negative transition-sensing coil | §4.2.4 T62 f9 | T76 f9 | ON→OFF mirror |
| Jump | §4.1.4 T58 f1–4 | — (not checked) | *"A transfer of program control to the designated network label shall occur when the Boolean value of the signal line is 1 (TRUE); thus, the unconditional jump is a special case of the conditional jump."* |
| Return | §4.1.4 T58 f5–8 | — (not checked) | conditional (Boolean input), or unconditional via the physical end of the POU or a RETURN wired to the left rail |
| Network label | §4.1.2 | — (not checked) | *"a network label delimited on the right by a colon (:)"* — an identifier or unsigned decimal integer; a **property of the network**, not an element |

Two structural notes. First, the Ed 2 Table 62 feature numbers skip 5, 6 and 7 — deleted
from Ed 1, the row naming.md already records under "retentive / memory coil". Second, the
gap pattern in the Ed 3 compliance table (features 1, 3, 4, 8, 9 listed for T76; 2, 5, 6,
7 absent) exactly matches Ed 2's Table 62, which is strong but not conclusive evidence
that Ed 3 kept Ed 2's feature numbering inside renumbered tables. The two inferred cells
above are flagged in §10 rather than asserted.

### 2.3 The evaluation rules, verbatim

These are the rules a ladder evaluator has to get right, and they are easy to lose in
paraphrase.

**Power flow direction** (§4.1.2):

> Power flow in the LD language shall be from left to right.

**Element ordering** (§4.1.3 — common to LD *and* FBD, not LD-only). Usually paraphrased
as "no element is evaluated until its inputs are known"; it is actually three rules:

> 1) No element of a network shall be evaluated until the states of all of its inputs have
> been evaluated. 2) The evaluation of a network element shall not be complete until the
> states of all of its outputs have been evaluated. 3) The evaluation of a network is not
> complete until the outputs of all of its elements have been evaluated, even if the
> network contains one of the execution control elements defined in 4.1.4.

Rule 3 is the one that matters for logex: a jump does not excuse the rest of the network
from being evaluated.

**Network order** (§4.2.6 — this one *is* LD-specific):

> Within a program organization unit written in LD, networks shall be evaluated in top to
> bottom order as they appear in the ladder diagram, except as this order is modified by
> the execution control elements defined in 4.1.4.

**The vertical link is one-directional** (§4.2.2):

> the state of the vertical link shall represent the inclusive OR of the ON states of the
> horizontal links on its left side … The state of the vertical link shall not be copied
> to any of the attached horizontal links on its left.

**A contact modifies the link, never the variable** (§4.2.3). The asymmetry is the rule:

> A contact is an element which imparts a state to the horizontal link on its right side
> which is equal to the Boolean AND of the state of the horizontal link at its left side
> with an appropriate function of an associated Boolean input, output, or memory variable.
> A contact does not modify the value of the associated Boolean variable.

Two independent free-software implementations reimplement exactly these two rules in code:
ClassicLadder's `StateOnLeft()` walks connected cells and ORs their outputs — the
vertical-link rule — and its `CalcTypeInput()` computes `State = StateElement &&
DynamicInput`, contact-as-AND (`src/hal/classicladder/calc.c`). These are not
committee prose; they are what working ladder engines converge on.

---

## 3. The IEC standard library

Functions live in Ed 3:2013 §6.6.2.5 (Ed 2:2003 §2.5.1.5); function blocks in Ed 2's
§2.5.2.3. Ed 3 renumbered heavily; both numbers are given where both were read. Page
numbers are Ed 3 printed pages.

### 3.1 Functions, by family

| Family | Ed 3:2013 | Ed 2:2003 | Members |
|---|---|---|---|
| Type conversion (naming scheme) | T22 f1a–4b, p.78 | T22, p.55 | `*_TO_**` (typed); `TO_**` (overloaded, **new in Ed 3**); `TRUNC` / `*_TRUNC_**` / `TRUNC_**`; `*_BCD_TO_**` / `**_TO_BCD_*` |
| Numeric conversions (per pair) | T23, pp.80–82 | — (no equivalent) | 90 numbered rows, `LREAL_TO_REAL` … `USINT_TO_UINT`, each with its rounding/range rule |
| Bit-string conversions | T24, p.82 | — | zero-padded on widen, truncated on narrow |
| Mixed bit/numeric | T25, p.85 | — | e.g. `DINT_TO_LWORD` — a raw binary transfer, **not** a value-preserving conversion |
| Date/time conversions | T26, pp.85–86 | T30 rows 13a/14a, p.65 | `DT_TO_TOD`, `LDT_TO_LTOD`, … |
| String/char conversions | T27, p.86 | — | `STRING_TO_WSTRING` etc.; WCHAR/WSTRING do not exist in Ed 2 |
| Numerical | T28 f1–12, p.87 | T23 f1–11, p.57 | `ABS SQRT LN LOG EXP SIN COS TAN ASIN ACOS ATAN` + **`ATAN2` (new in Ed 3)** |
| Arithmetic | T29 f1–7, p.88 | T24 f12–18, p.58 | `ADD MUL SUB DIV MOD EXPT MOVE` |
| Bit shift | T30 f1–4, p.89 | T25 f1–4, p.59 | `SHL SHR ROL ROR` — Ed 2 lists ROR as f3 and ROL as f4, the **reverse** of Ed 3 |
| Bitwise Boolean | T31 f1–4, p.89 | T26 f5–8, p.60 | `AND OR XOR NOT` |
| Selection | T32 f1–6, pp.90–91 | T27 f1–4, p.61 | `MOVE SEL MAX MIN LIMIT MUX` |
| Comparison | T33 f1–6, p.91 | T28 f5–10, p.62 | `GT GE EQ LE LT NE` |
| String | T34 f1–9, pp.92–93 | T29 f1–9, pp.63–64 | `LEN LEFT RIGHT MID CONCAT INSERT DELETE REPLACE FIND` |
| Time/duration arithmetic | T35 f1a–11c, pp.93–94 | T30 f1–11, pp.64–65 | `ADD`/`ADD_TIME`, `SUB`/`SUB_DATE_DATE`, `MUL_TIME`, `DIV_TIME` (Ed 2 spells the last two `MULTIME`/`DIVTIME`) |
| Date/time construction | T36, pp.94–96 | T30 f12, p.65 | `CONCAT_DATE_TOD`; **new in Ed 3:** `CONCAT_DATE/TOD/DT`, `SPLIT_DATE/TOD/DT`, `DAY_OF_WEEK` |
| Endianness | T37 f1–4, p.98 | — (absent) | `TO_BIG_ENDIAN`, `TO_LITTLE_ENDIAN`, `FROM_BIG_ENDIAN`, `FROM_LITTLE_ENDIAN` |
| Enumerated types | T38, p.98 | T31, p.66 | no new mnemonics — records that `SEL`, `MUX`, `EQ`, `NE` also apply to enumerated types |
| Validate | T39 f1–2, p.99 | — (absent) | `IS_VALID`, `IS_VALID_BCD` |

Five facts from these tables that a contributor will otherwise get wrong:

- **`MOVE` changed families between editions.** Ed 2 lists it as arithmetic-function T24
  f18; Ed 3 lists it *twice* — T29 f7 and T32 f1, the selection-functions table. Same
  function, reclassified.
- **`MOD` is `rem`, not `mod`.** Both editions define it with truncating `DIV`:
  `IF (IN2 = 0) THEN OUT:=0; ELSE OUT:=IN1 - (IN1/IN2)*IN2; END_IF`. Integer division
  truncates toward zero: *"7/3 = 2 and (-7)/3 = -2."*
- **`NE` is the one non-extensible comparison** — *"Inequality NE <> OUT := (IN1 <> IN2)
  (non-extensible)"*. The other five chain: `OUT := (IN1>IN2) & (IN2>IN3) & …`.
- **There is no canonical list of legal `*_TO_**` pairs.** Table 22's note says a
  conformance statement *"shall include a list of the specific type conversions
  supported"*. Ed 3's T23–T27 are the closest thing to an enumeration.
- **Table 37 contradicts itself.** Its Description column names features 3–4
  `BIG_ENDIAN_TO` / `LITTLE_ENDIAN_TO` while the graphical box and the ST usage example
  both say `FROM_BIG_ENDIAN` / `FROM_LITTLE_ENDIAN`.

### 3.2 Function blocks — full pin signatures

These are what logex needs next, so they are given in full. Ed 2:2003 clause and table
numbers, read from the standard's own text.

**Timers** — §2.5.2.3.4, Table 37; timing diagrams in Table 38. Table 37 lists **exactly
three** features and nothing else.

| FB | T37 | Inputs | Outputs | Behavior |
|---|---|---|---|---|
| `TP` | f1 | `IN : BOOL`, `PT : TIME` | `Q : BOOL`, `ET : TIME` | Q true for exactly PT from IN's rising edge, unaffected by IN during the pulse |
| `TON` | f2a | `IN : BOOL`, `PT : TIME` | `Q : BOOL`, `ET : TIME` | Q true PT after IN's rising edge; a false IN resets ET to 0 immediately — **no memory of partial elapsed time** |
| `TOF` | f3a | `IN : BOOL`, `PT : TIME` | `Q : BOOL`, `ET : TIME` | Q follows IN's rising edge at once; on a falling edge Q holds for PT |

**There is no retentive timer type in Part 3.** The standard's only route to "retentive" is
the `RETAIN` qualifier on an ordinary instance — §2.5.2.2 item 2, Table 33 feature 3a,
whose own example is `VAR RETAIN TMR1: TON ; END_VAR`. That makes the *state survive a
warm restart*; it does not make TON accumulate across drops of IN. logex's `rto` is
therefore not an IEC name, and cannot be made into one.

**Counters** — §2.5.2.3.3, Table 36.

| FB | T36 | Inputs | Outputs | Body (verbatim) |
|---|---|---|---|---|
| `CTU` | f1a | `CU : BOOL`, `R : BOOL`, `PV : INT` | `Q : BOOL`, `CV : INT` | `IF R THEN CV := 0 ; ELSIF CU AND (CV < PVmax) THEN CV := CV+1; END_IF ; Q := (CV >= PV) ;` |
| `CTU_DINT` | f1b | as CTU, `PV/CV : DINT` | | *"Same as 1a"*; siblings f1c `CTU_LINT`, f1d `CTU_UDINT`, f1e `CTU_ULINT` |
| `CTD` | f2a | `CD : BOOL`, `LD : BOOL`, `PV : INT` | `Q : BOOL`, `CV : INT` | `IF LD THEN CV := PV ; ELSIF CD AND (CV > PVmin) THEN CV := CV-1;` — **there is no R input on this block** |
| `CTUD` | f3a | `CU`, `CD`, `R`, `LD`, `PV : INT` | `QU`, `QD`, `CV : INT` | `IF R THEN CV := 0 ; ELSIF LD THEN CV := PV ; ELSE IF NOT (CU AND CD) THEN …` — priority R > LD > count; simultaneous CU and CD suppresses counting for that scan |

CTD's missing reset pin is confirmed twice over: the standard's own pin diagram, and
MatIEC's compilable `VAR_INPUT CD : BOOL; LD : BOOL; PV : INT; END_VAR`.

**Bistables** — §2.5.2.3.1, Table 34. `SR` (f1) is `S1, R → Q1`, set-dominant.
`RS` (f2) is `S, R1 → Q1`, reset-dominant. naming.md already records the trap that
Siemens swaps these names; MatIEC's executable bodies confirm the IEC algebra —
`Q1 := S1 OR ((NOT R) AND Q1);` for SR, `Q1 := (NOT R1) AND (S OR Q1);` for RS.

**Edge detection** — §2.5.2.3.2, Table 35. The standard gives these as compilable ST, so
MatIEC's library file and the standard's text are identical rather than merely equivalent:

```
FUNCTION_BLOCK R_TRIG      Q := CLK AND NOT M;        (* T35 f1 *)
                           M := CLK;
FUNCTION_BLOCK F_TRIG      Q := NOT CLK AND NOT M;    (* T35 f2 *)
                           M := NOT CLK;
```

**Communication function blocks** — §2.5.2.3.5, p.83. Part 3 names the category and
defers the definitions: *"Standard communication function blocks for programmable
controllers are defined in IEC 61131-5."* There is no pin table to survey in Part 3, and
Part 5 was not opened.

---

## 4. Instruction List: the only standard mnemonic vocabulary, now withdrawn

IL is the one place IEC ever specified mnemonics. Ed 4:2025 removed it. Its Scope now
reads:

> This document specifies the syntax and semantics of a unified suite of programming
> languages for programmable controllers (PCs). This suite consists of the textual
> language structured text (ST), and the graphical languages, ladder diagram (LD) and
> function block diagram (FBD).

**A correction worth making explicitly.** A claim repeated across the trade press — and
produced by web search — says Ed 3:2013 already "demoted IL to an informative annex" or
"retained it only in Annex C". Ed 3's own Scope says otherwise:

> This suite consists of two textual languages, Instruction List (IL) and Structured Text
> (ST), and two graphical languages, Ladder Diagram (LD) and Function Block Diagram (FBD).

and Ed 3's table of contents places IL at normative clause 7.2 (7.2.1–7.2.4) with its own
**Table 68 "Instruction list operators"**, beside clause 7.3 ST. Ed 3's annexes are A
("Formal specification of the languages elements", p.221) and B ("List of major changes and
extensions of the third edition", p.228). **Ed 3 has no Annex C at all.** The removal is
an Ed 4 event, not an Ed 3 one.

### 4.1 The operator set — Ed 2:2003 Table 52, pp.125–126

| # | Operator | Modifiers | Description |
|---|---|---|---|
| 1 | `LD` | N | Set current result equal to operand |
| 2 | `ST` | N | Store current result to operand location |
| 3 | `S` / `R` | — | Set / reset operand if current result is Boolean 1 (operand must be BOOL, footnote e) |
| 4 | `AND` | N, ( | Logical AND |
| 5 | `&` | N, ( | Logical AND (a distinct token from `AND`) |
| 6 | `OR` | N, ( | Logical OR |
| 7 | `XOR` | N, ( | Logical exclusive OR |
| 7a | `NOT` | — | Logical negation (one's complement) of the current result |
| 8–11a | `ADD` `SUB` `MUL` `DIV` `MOD` | ( | Addition, subtraction, multiplication, division, modulo-division |
| 12–17 | `GT` `GE` `EQ` `NE` `LE` `LT` | ( | Comparison `>` `>=` `=` `<>` `<=` `<` |
| 18 | `JMP` | C, N | Jump to label (operand is a label, footnote b) |
| 19 | `CAL` | C, N | Call function block (see Table 53; operand is an FB instance name) |
| 20 | `RET` | C, N | Return from called function, function block or program (no operand) |
| 21 | `)` | — | Evaluate deferred operation |

**The modifiers** (§3.2.2, p.124; Table 51 b) note, p.125):

- `N` — *"bitwise Boolean negation (one's complement) of the operand"*. Worked example:
  *"the instruction ANDN %IX2 is interpreted as result := result AND NOT %IX2"*.
- `C` — *"the associated instruction shall be performed only if the value of the currently
  evaluated result is Boolean 1 (or Boolean 0 if the operator is combined with the 'N'
  modifier)"*.
- `(` — *"indicates that evaluation of the operator shall be deferred until a right
  parenthesis operator ')' is encountered"*. This is IL's answer to the same
  operator-grouping problem that ladder solves with parallel legs.

**The accumulator** (§3.2.2): IL has one implicit *current result*.

> Unless otherwise defined in table 52, the semantics of the operators shall be
> result := result OP operand … It shall be an error in the sense of subclause 1.5.1 if
> the current result and operand are not of same data type, or if the result of a
> numerical operation exceeds the range of values for its data type.

### 4.2 The fused forms — Annex B.2.2, pp.159–160

The formal grammar spells the modified operators as single terminals, not as
operator-plus-modifier:

```
il_simple_operator ::= 'LD' | 'LDN' | 'ST' | 'STN' | 'NOT' | 'S' | 'R'
                     | 'S1' | 'R1' | 'CLK' | 'CU' | 'CD' | 'PV' | 'IN' | 'PT'
                     | il_expr_operator
il_expr_operator   ::= 'AND' | '&' | 'OR' | 'XOR' | 'ANDN' | '&N' | 'ORN' | 'XORN'
                     | 'ADD' | 'SUB' | 'MUL' | 'DIV' | 'MOD'
                     | 'GT' | 'GE' | 'EQ' | 'LT' | 'LE' | 'NE'
il_jump_operator   ::= 'JMP' | 'JMPC' | 'JMPCN'
il_call_operator   ::= 'CAL' | 'CALC' | 'CALCN'
il_return_operator ::= 'RET' | 'RETC' | 'RETCN'
il_assign_out_operator ::= ['NOT'] variable_name '=>'
```

The eight names inside `il_simple_operator` that are neither loads nor stores — `S1`,
`R1`, `CLK`, `CU`, `CD`, `PV`, `IN`, `PT` — are the **standard function-block input
operators** of Table 54 (p.129): a one-instruction shorthand for a `CAL` whose argument
list contains only that pin. Table 54 pairs them with their blocks: `S1,R → SR` (row 4),
`S,R1 → RS` (5), `CLK → TRIGGER` (6), `CU,R,PV → CTU` (8), `CD,PV → CTD` (9),
`CU,CD,R,PV → CTUD` (10), `IN,PT → TP/TON/TOF` (11–13). Its NOTE 1 explains an absence:

> LD is not necessary as a Standard Function Block input operator, because the LD
> functionality is included in PV.

**IL is alive in free software after its removal from the standard.** MatIEC's lexer keeps
the full set as literal tokens (`stage1_2/iec_flex.ll` `<il_state>` block, lines
1718–1776: `LD`/`LDN`/`ST`/`STN`, `ANDN`/`&N`/`ORN`/`XORN`, `CAL`/`CALC`/`CALCN`,
`RET`/`RETC`/`RETCN`, `JMP`/`JMPC`/`JMPCN`, plus `S1 R1 CLK CU CD PV IN PT`), with `&`
and `&N` deliberately kept distinct from `AND`/`ANDN` (`%token AND2 /* character '&' in
the source code*/`, `%token ANDN2`). echidna reproduces the same vendor-neutral set in its
own flex lexer. Both are described in §5.

---

## 5. Free-software instruction sets

### 5.1 MatIEC and Beremiz

**MatIEC** (`github.com/beremiz/matiec`) is an IEC 61131-3 compiler that emits C; GPLv3;
its own readme identifies it as *"based on the FINAL DRAFT - IEC 61131-3, 2nd Ed.
(2001-12-10)"*, copyright 2003–2012 Mario de Sousa. It is the compiler under both Beremiz
and OpenPLC.

**The surprise: MatIEC does not parse ladder at all.** Its readme:

> Of the above 5 languages, the standard defines textual representations for IL, ST and
> SFC. It is these 3 languages that we target, and we currently support all three, as long
> as they are expressed in the textual format as defined in the standard.

Its grammar has zero occurrences of "coil" or "contact". LD is authored graphically in
**Beremiz** (GPLv2/LGPLv2 Python IDE) and lowered to ST *before* MatIEC sees it. The
lowering rules are in `beremiz/PLCGenerator.py`, class `PouProgramGenerator`:

| LD construct | How it is compiled | Location |
|---|---|---|
| Negated contact/coil | wrap the expression in `NOT(...)` | `ExtractModifier`: `if variable.getnegated(): return [("NOT(", …)] + expression + [(")", ())]` |
| Set coil | `IF <rung> THEN <var> := TRUE; (*set*) END_IF` — no `ELSE`, so a false rung leaves the tag alone | `ExtractModifier`: `return [("TRUE; (*set*)\n" + self.CurrentIndent + "END_IF", ())]` |
| Reset coil | same shape, `FALSE; (*reset*)` | `ExtractModifier` |
| Rising/falling edge | instantiate a hidden `R_TRIG`/`F_TRIG` instance — **not** an inline test | `ExtractModifier`: `return self.AddTrigger("R_TRIG", expression, …)` |
| Parallel legs | join each leg's expression with the literal string `" OR "`, parenthesizing joined groups | `FactorizePaths` / `ComputePaths`: `JoinList([(" OR ", ())], vars)` |

Negation, storage and edge are mutually exclusive modifiers on one element in this model —
the same shape as the interchange schema in §6.

**Function blocks.** `lib/timer.txt`, `lib/counter.txt`, `lib/bistable.txt`,
`lib/edge_detection.txt` implement `TP TON TOF`, `CTU (+_DINT/_LINT/_UDINT/_ULINT) CTD
CTUD`, `SR RS`, `R_TRIG F_TRIG` as separately named FUNCTION_BLOCKs with the standard's own
algebra. Two implementation details worth noting: the graphical `CU` edge arrow becomes an
explicit internal `R_TRIG` instance (`CU_T(CU); … ELSIF CU_T.Q AND (CV < PV) THEN CV :=
CV+1;`), and the timers are 3-state machines driven by an injected time value
(`STATE : SINT := 0;  (* internal state: 0-reset, 1-counting, 2-set *)`). Every generated
C struct in `lib/C/iec_std_FB.h` carries `EN`/`ENO` as its first two fields, ahead of the
block's own IEC pins.

**What MatIEC calls "standard" is broader than the standard.** `lib/standard_FB.txt`
(header: *"This is the library containing the standard function blocks defined in the
standard."*) also pulls in `pid_st`, `ramp_st`, `hysteresis_st`, `integral_st`,
`derivative_st` and `rtc`; `sema.txt` is included under its own comment *"Not in the
standard, but useful nonetheless."* Beremiz's own PLCopen XML disagrees with that grouping:
`plcopen/Standard_Function_Blocks.xml` carries `SR RS SEMA R_TRIG F_TRIG CTU… TP TON TOF`,
while `PID RAMP HYSTERESIS INTEGRAL DERIVATIVE RTC` live in
`plcopen/Additional_Function_Blocks.xml`. The compiler and the IDE built on it draw the
line in different places — and `SEMA` lands on the "standard" side in the IDE despite
MatIEC's own comment saying it is not.

**MatIEC is frozen at roughly Ed 2.** Checked against its 432-entry
`stage1_2/standard_function_names.c`: it implements `ABS SQRT LN LOG EXP SIN COS TAN ASIN
ACOS ATAN`, `EXPT MOVE`, `SEL MAX MIN LIMIT MUX`, `SHL SHR ROR ROL`, `AND OR XOR NOT`, the
comparisons, the string family, `TRUNC`, and a `BCD_TO_*`/`*_TO_BCD` family narrowed to the
four unsigned integer types. Every Ed 3-only addition is **absent**: no `ATAN2`, no
`TO_BIG_ENDIAN`/`FROM_*`, no `IS_VALID`/`IS_VALID_BCD`, no `SPLIT_DATE/TOD/DT`, no
`DAY_OF_WEEK`. `MOVE` sits between `EXPT` and the time functions in that array — Ed 2's
Table 24 placement, not Ed 3's move into the selection table.

### 5.2 OpenPLC

OpenPLC has two generations, and they no longer share a compiler.

**v3** (`thiagoralves/OpenPLC_v3`) — its README opens *"This project has reached End of Life
and is no longer maintained. It has been replaced by OpenPLC Runtime v4."* It vendors
MatIEC's source at `utils/matiec_src` (not a submodule), builds it in
`background_installer.sh` (`install_matiec`: `autoreconf -i && ./configure && make`, then
`cp ./iec2c "$OPENPLC_DIR/webserver/"`), and compiles user programs with
`./iec2c -f -l -p -r -R -a ./st_files/"$1"` (`webserver/scripts/compile_program.sh`). Note
what that path implies: **the shipped v3 workflow only ever hands MatIEC Structured Text.**

The **editor** is a Beremiz fork, stated in its own README: *"OpenPLC Editor repository
contains modified versions of Beremiz (GPLv2/LGPLv2) and MatIEC (GPLv3)"*, pulled in as
submodules `thiagoralves/editor` and `thiagoralves/matiec`, with a maintained
`diff_from_beremiz.txt`. Its LD model is Beremiz's, unchanged:

| Thing | Value | Location (`thiagoralves/editor`) |
|---|---|---|
| Languages offered for a new POU | `["IL", "ST", "FBD", "LD", "SFC"]` — **IL still offered**, after Ed 4 removed it | `plcopen/definitions.py:38`; `dialogs/PouDialog.py:128` |
| Contact modifiers | `CONTACT_NORMAL, CONTACT_REVERSE, CONTACT_RISING, CONTACT_FALLING` | `graphics/GraphicCommons.py:69` |
| Coil modifiers | `COIL_NORMAL, COIL_REVERSE, COIL_SET, COIL_RESET, COIL_RISING, COIL_FALLING` | `graphics/GraphicCommons.py:70` |
| Dialog labels | `Normal`, `Negated`, + `Set`/`Reset` for coils only, + `Rising Edge`, `Falling Edge` | `dialogs/LDElementDialog.py:72-79` |
| LD toolbar | power rail, rung, branch, coil, contact, block, connection, variable, comment | `IDEFrame.py:272-296` (`EditorToolBarItems["LD"]`) |

This is **1:1 parity with all four IEC contact features and all six coil features** — more
complete than any vendor column in naming.md.

The block palette is far larger than IEC's. `plcopen/definitions.py` registers eleven XML
libraries: two IEC (`Standard_Function_Blocks.xml` — `SR`:20, `RS`:51, `SEMA`:82,
`R_TRIG`:121, `F_TRIG`:155, `CTU`:189, `CTD`:454, `CTUD`:719, `TP`:1119, `TON`:1232,
`TOF`:1349 — plus the flat function list in `plcopen/iec_std.csv`, e.g. `ADD`:33,
`MOVE`:39, `AND`:66, `GT`:75), and nine of OpenPLC's own with no IEC pedigree:
`Additional_Function_Blocks.xml` (`INTEGRAL`:108, `DERIVATIVE`:183, `PID`:259, `RAMP`:375,
`HYSTERESIS`:475, `RTC`:20) plus Arduino (`DS18B20`:20, `PWM_CONTROLLER`:325,
`ARDUINOCAN_READ`:561), Microver/CAN, Communication, P1AM (`P1_16CDR`:39), Synergy, MQTT
(`MQTT_CONNECT`:122), Sequent Microsystems, Jaguar and SL-RP4. Almost all of the
non-standard additions are I/O-module and communications wrappers.

**v4** (`Autonomy-Logic/openplc-runtime`, `openplc-editor`) **has dropped MatIEC as the
primary compiler.** The editor's own migration doc: *"STruC++ is the editor's ST compiler
today … The editor no longer ships or invokes a local `iec2c` binary."* STruC++
(`Autonomy-Logic/STruCpp`, GPL-3.0) is a from-scratch TypeScript ST→C++17 compiler. The v4
runtime enforces the break — `scripts/compile.sh` refuses MatIEC-era artifacts:
*"core/generated contains MatIEC files (Config0.c / glueVars.c). This runtime no longer
supports MatIEC programs."* MatIEC survives on the compatibility path: the v4 editor still
uploads plain `program.st` to a v3 runtime, which recompiles it on-device.

### 5.3 LDmicro

`github.com/LDmicro/LDmicro`, commit `5b058e0` (release/5.4.1.1). A ladder editor,
simulator and compiler targeting 8-bit microcontrollers directly — *"LDmicro is a ladder
logic editor, simulator and compiler for 8-bit microcontrollers"* — emitting PIC/AVR hex,
ANSI C, or a portable bytecode. GPL. It makes no IEC conformance claim, and it has no
textual language: the element set is 108 live `#define ELEM_*` constants in
`ldmicro/circuit.h` (a `#define` table, **not** an enum in `lang.h` — see §10), with 11
more commented out and two (`ELEM_COPY_BIT` 0x1c83, `ELEM_XOR_COPY_BIT` 0x1c84) defined
but unreachable: they appear nowhere but their own `#define` and the `CASE_LEAF` macro.

**Contacts and coils are one element type each, with mode flags** — the design that most
distinguishes LDmicro from IEC's per-symbol table:

```c
typedef struct ElemContactsTag { char name[MAX_NAME_LEN]; bool negated; bool set1; } ElemContacts;   /* circuit.h:308 */
typedef struct ElemCoilTag { char name[MAX_NAME_LEN]; bool negated; bool setOnly;
                             bool resetOnly; bool ttrigger; } ElemCoil;                               /* circuit.h:314 */
```

`ELEM_CONTACTS` is 0x10 (`circuit.h:50`) and `ELEM_COIL` 0x11 (`:51`). The manual documents
each flag combination as its own instruction — `COIL, NORMAL` (`manual.txt:434`),
`NEGATED` (:445), `SET-ONLY` (:457), `RESET-ONLY` (:469), `T-TRIGGER` (:481) — and
`coildialog.cpp:61,64,67,70,73` exposes them as five radio buttons. The **T-trigger** coil
is a toggle/RS/RST flip-flop with no IEC and no vendor-mnemonic counterpart:
*"If used only the R and S inputs you get classic RS-trigger. If add T input you get
'newest' RST-trigger."* LDmicro has no SR/RS block at all; set- vs reset-dominance is a
wiring choice on one coil.

**Timers and counters** (`circuit.h`; behavior from `manual.txt`):

| Mnemonic | `ELEM_` | Location | Meaning |
|---|---|---|---|
| `TON` | 0x12 | `circuit.h:52`; `manual.txt:508` | Turn-on delay; preset is a literal on the rung, no `PT` pin and **no `ET` output** |
| `TOF` | 0x13 | `circuit.h:53`; `manual.txt:541` | Turn-off delay |
| `RTO` | 0x14 | `circuit.h:54`; `manual.txt:629` | **Retentive** — *"keeps track of how long its input has been true(HI) … This timer must therefore be reset manually, using the reset instruction."* |
| `RTL` | 0x1401 | `manual.txt:666` | Retentive, accumulating *low* time |
| `THI` | 0x1410 | `manual.txt:575` | On a rising edge, output forced true for the delay — a pulse timer, not called TP |
| `TLO` | 0x1420 | `manual.txt:601` | On a falling edge, output forced false for the delay |
| `TCY` | 0x1201 | `manual.txt:696` | Cyclic/astable square wave — no IEC counterpart |
| `RES` | 0x15 | `manual.txt:748` | *"TON and TOF timers are automatically reset … RTO timers and CTU/CTD counters are not reset automatically, so they must be reset by hand using a RES instruction."* |
| `CTU` / `CTD` | 0x23 / 0x24 | `manual.txt:1303` | Counters with the **threshold written inline** (`--[CTU >= 5]--`) — no PV pin, no Q output, no reset pin |
| `CTC` / `CTR` | 0x25 / 0x2501 | `manual.txt:1318` | Circular counters: *"after reaching its upper limit, it resets its counter variable back to 0"* — no IEC counterpart |

**Edge handling is inline, not coil-shaped** — the finding that matters most to logex:

| Mnemonic | `ELEM_` | Location | Meaning |
|---|---|---|---|
| `OSR` | `ELEM_ONE_SHOT_RISING` 0x16 | `circuit.h:63`; `manual.txt:789` | *"If the instruction's input is true during this scan and it was false during the previous scan then the output is true."* Drawn `--[_/ OSR_/ \_]--` — a **series element gating the rung** |
| `OSF` | `ELEM_ONE_SHOT_FALLING` 0x17 | `circuit.h:64`; `manual.txt:801` | Falling-edge sibling |
| `ODR` / `ODF` | 0x1702 / 0x1701 | `manual.txt:867, 909` | "One drop": normally-true elements that drop false for one scan — the inverse-output twins. `manual.txt:909`: *"The previous name is ONE-SHOT LOW LEVEL(renamed in v5.4.1.0)."* |
| `OSC` | — | `manual.txt:953` | Free-running oscillator at `F=1/(2*Tcycle)` while its input is true |

**Structure, math and control.** `ELEM_SERIES_SUBCKT` 0x02 and `ELEM_PARALLEL_SUBCKT` 0x03
(`circuit.h:45-46`) are explicit branch/parallel-group elements — the first free-software
rows available for naming.md's otherwise empty "Branch structure" table.
`ELEM_MASTER_RELAY` 0x2c (`circuit.h:125`) implements the MCR zone that naming.md found
absent from IEC entirely: *"If a master control relay instruction is executed with a
rung-in condition of false, then the rung-in condition for all following rungs becomes
false."* Program control is `ELEM_LABEL` 0x2c20, `ELEM_GOTO` 0x2c21, `ELEM_SUBPROG` 0x2c22,
`ELEM_RETURN` 0x2c23 (`circuit.h:134`; `manual.txt:1978`), `ELEM_ENDSUB` 0x2c24,
`ELEM_GOSUB` 0x2c25 — each of the first three carrying the source comment
`// operate with rung only`.

The math/bitwise palette is `ELEM_ADD SUB MUL DIV MOD` (`circuit.h:72-76`),
`AND OR XOR NOT NEG` (`:83-87`), `SHL SHR SR0 ROL ROR` (`:91-95`), and
`MOVE BIN2BCD BCD2BIN SWAP OPPOSITE` (`:67-71`). (`ldmicro/ldmicro.h` carries a parallel
`MNU_INSERT_*` constant for each — those are the menu commands that insert an element, not
the element definitions.) Two of them are not what their names suggest. `OPPOSITE` is a
**full bit-order reversal**, not a negation of any kind: `int opposite(int val, int sov)`
at `simulate.cpp:1449` loops `sov * 8` times doing `ret = ret << 1; ret |= val & 1;
val = val >> 1`. `SR0` is a logical right shift distinct from `SHR`'s arithmetic one, with
zero shifted into the MSB and the last bit out kept as a carry — the manual draws it,
`manual.txt:1184-1195`: *"0 -> x -> x -> .... -> x -> x -> C"*, annotated *"Logical shift
to left is equivalent to SHL arithmetic shift to left."* There is no `SEL`/`MAX`/`MIN`/`LIMIT`/`MUX`, no trig or `SQRT`, and no string
family anywhere in the palette; on an 8-bit target with no float support, that is expected.

**Comparisons use the pre-rename spellings.** `circuit.h:97-102` defines
`ELEM_EQU NEQ GRT GEQ LES LEQ` (0x1d–0x22) — the exact six that the conventional set's 2024 conformance
sweep renamed to `EQ NE GT GE LT LE`. LDmicro never followed. Whatever else it shows, this
is direct evidence that the old spellings are a living free-software dialect and not a
superseded vendor artifact.

### 5.4 ClassicLadder

A ladder and Grafcet engine; the copy read here is the one embedded in LinuxCNC
(`LinuxCNC/linuxcnc`, `src/hal/classicladder/`, version string `0.8.10-LinuxCNC`), with
the author's standalone tree (`MaVaTi56/classicladder`, copyright 2001–2020 Marc Le
Douarain) checked alongside. Of the projects here it is the closest in spirit to IEC's own
per-symbol table: one named constant per graphical symbol.

| Constant | Value | Meaning | Evaluated in |
|---|---|---|---|
| `ELE_INPUT` | 1 | NO contact — `State = StateElement && …DynamicInput;` | `calc.c CalcTypeInput()` |
| `ELE_INPUT_NOT` | 2 | NC contact | same, `IsNot=TRUE` |
| `ELE_RISING_INPUT` | 3 | Rising-edge contact | `PrepareRungs()` precomputes the previous scan into `DynamicVarBak` |
| `ELE_FALLING_INPUT` | 4 | Falling-edge contact | `PrepareRungs()` (inverts before comparing) |
| `ELE_CONNECTION` | 9 | Plain wire cell — there is **no branch element**; parallel legs are grid geometry plus a per-cell `ConnectedWithTop` flag | `CalcTypeConnection()`, `StateOnLeft()` |
| `ELE_TIMER` | 10 | Legacy timer, Enable + Control inputs, no mode field; kept under `#ifdef OLD_TIMERS_MONOS_SUPPORT` | `CalcTypeTimer()` |
| `ELE_MONOSTABLE` | 11 | Legacy non-retriggerable one-shot | `CalcTypeMonostable()` |
| `ELE_COUNTER` | 12 | **One** block with `InputReset`, `InputPreset`, `InputCountUp`, `InputCountDown` → `OutputDone`, `OutputEmpty`, `OutputFull` | `CalcTypeCounter()` |
| `ELE_TIMER_IEC` | 13 | **One** block; `TimerMode` selects `TIMER_IEC_MODE_ON`(0) / `_OFF`(1) / `_PULSE`(2) | `CalcTypeTimerIEC()` |
| `ELE_REGISTER` | 14 | FIFO/LIFO shift register — **present only in the standalone tree**, absent from the LinuxCNC copy | `CalcTypeRegister()` |
| `ELE_COMPAR` | 20 | Compare — a free-text expression box, evaluated **every scan** and then ANDed with the incoming power | `CalcTypeCompar()` → `EvalCompare()` |
| `ELE_OUTPUT` | 50 | Coil | `CalcTypeOutput()` |
| `ELE_OUTPUT_NOT` | 51 | **Negated coil** — `if (IsNot) State = !State; WriteVarForElement(…)` | `calc.c:385,394-396` |
| `ELE_OUTPUT_SET` / `_RESET` | 52 / 53 | Latch / unlatch — `/* Elements : -(S)- and -(R)- */` | `CalcTypeOutputSetReset()` |
| `ELE_OUTPUT_JUMP` | 54 | Jump coil; sets `JumpToRung` and aborts the rung's refresh immediately | `CalcTypeOutputJump()` |
| `ELE_OUTPUT_CALL` | 55 | Sub-section call | `CalcTypeOutputCall()` |
| `ELE_OUTPUT_OPERATE` | 60 | Operate — an expression box that runs **only when the rung is true** | `CalcTypeOutputOperate()` → `MakeCalc()` |
| `ELE_SEQ_STEP` / `_TRANSITION` / `_COMMENT` | 1 / 2 / 3 | Grafcet step, transition, comment (separate `sequential.h` namespace) | `calc_sequential.c` |

Three findings:

- **ClassicLadder is the only implementation in this survey — free software or vendor —
  that has a negated coil as its own named element.** naming.md's `otn` proposal had no
  precedent; `ELE_OUTPUT_NOT` is one.
- **Comparison and arithmetic collapse into two generic expression boxes.** There is no
  `GT`/`ADD`/`SHL` element. Both `ELE_COMPAR` and `ELE_OUTPUT_OPERATE` feed the same
  hand-written recursive-descent evaluator (`arithm_eval.c`), precedence low to high:
  `|` > `^` (Xor) > `&` > `+ -` > `* / %` > `^` (Pow) > Term. Terms are parenthesized
  sub-expressions, decimal/hex(`$`)/char(`'`) constants, `@`-prefixed variables, `!`-negated
  terms, or one of four named functions — `ABS`, `MINI`, `MAXI`, and average, whose source
  reads `if ( !strcmp(tcFonc, "MOY") /*original french term!*/ || !strcmp(tcFonc, "AVG")
  /*added latter!!!*/ )`. No IEC standard function defines an average at all. There is no
  shift or rotate operator anywhere in the grammar. This is the same "expression box"
  design naming.md attributes only to vendor CMP/CALCULATE instructions, arrived at
  independently.
- **Counters wrap rather than saturate.** `CalcTypeCounter()`:
  `if ( CurrentValue>9999 ) CurrentValue = 0;` and `if ( CurrentValue<0 ) CurrentValue =
  9999;`. That is a concrete data point for naming.md's row noting that IEC leaves
  `PVmin`/`PVmax` implementation-dependent.

Addressing is not mnemonic-shaped at all: `vars_names_list.c`'s `TableConvIdVarName[]`
defines `%B` (mem bit), `%I`/`%Q` (physical in/out bit), `%W`, `%IW`/`%QW`, `%IF`/`%QF`
(float I/O), `%T`(.D/.R/.P/.V), `%TM`(.Q/.P/.V), `%C`(.D/.E/.F/.P/.V), `%M`, `%X`(.A/.V),
`%E`, `%S`, `%SW` — closer to a Siemens/Schneider `%`-address scheme than to any ladder
mnemonic set. (The `%` itself is prepended by `vars_names.c`; the table strings read
`"I%d"`.)

### 5.5 The modern compilers

Four newer projects, none descended from MatIEC.

**PLC-lang/rusty** — an ST compiler to LLVM; LGPL-3.0 workspace, `libs/stdlib` LGPL-2.1;
actively developed. Its standard library is split into two visibly different tiers:

- *ST source* under `libs/stdlib/iec61131-st/`: `TON`(`timers.st:93`, plus `TON_TIME`:120
  and `TON_LTIME`:147), `CTU`(`counters.st:13`) with five hand-written typed siblings,
  `CTD`(:175), `SR`(`bistable_functionblocks.st:11`) and `RS`(:31),
  `R_TRIG`(`flanks.st:10`) and `F_TRIG`(:31), `ROL`(`bit_shift_functions.st:11`) and
  `ROR`(:28). `TON` is declared `{external}` — the interface is ST, the timing is native.
- *Compiler intrinsics* in `src/builtins.rs`: `SEL`(:210, lowered to an LLVM `select`),
  `MOVE`(:265), `ADD`(:369, declared genuinely variadic — `args: {sized} T...` — and never
  called as a function: `unreachable!("ADD is not generated as a function call")`),
  `GT`(:556), `GE`(:580), `EQ`(:604), `LE`(:628), `LT`(:652), `NE`(:676), `SHL`(:701),
  `SHR`(:732).

`SHR` is the one to read carefully: it selects arithmetic vs logical shift on
`is_signed_int()`, so a signed operand **sign-extends**. IEC's `SHR` (Ed 3 T30 f2) is
specified as *"right-shifted by N bits, zero-filled on left"* regardless of sign. This is a
free-software IEC compiler choosing the vendor convention over the letter of the standard,
for exactly the instruction logex plans to call `shr`.

**ironplc/ironplc** — an IEC 61131-3 compiler in Rust; MIT; actively developed. It reaches
the same two-tier split from the other direction, and writes the boundary down.
`specs/adrs/0042-library-functions-over-compiler-intrinsics.md` restricts the intrinsic
path to function blocks whose retained state cannot be expressed in plain IEC ST — and the
enumerated set is exactly `SR RS R_TRIG F_TRIG CTU CTD CTUD TON TOF TP`. Everything else,
including vendor-compatibility libraries, must arrive as ordinary ST source
(`compiler/analyzer/src/intermediates/stdlib_function_block.rs`: `build_sr`:115,
`build_f_trig`:162, `build_r_trig`:147, `build_ctu_variant`:178, `build_ctd_variant`:200,
`build_ctud_variant`:218, `build_ton`:273, `build_tof`:287, `build_tp`:303). Counters are
generated per integer width by a Rust helper rather than duplicated in ST — a different
engineering answer to the same problem rusty solves with five hand-written blocks.

Vendor names are quarantined into referenced libraries: `Tc2_Math`, `Tc2_BuiltIns`,
`Tc2_Utilities` (Beckhoff TwinCAT compatibility, clean-room ST, headed *"not affiliated
with, endorsed by, or sponsored by Beckhoff Automation GmbH"*). `LTRUNC`'s own doc comment
states the divergence it embodies: *"unlike the IEC TRUNC (ANY_INT result), inputs beyond
any integer type's range truncate exactly, without clamping."*

**mbuesch/awlsim** — a Siemens S7 AWL/STL simulator in Python; GPL-2.0-or-later. Its
mnemonic tables (`awlsim/core/instructions/types.py`) are a **bilingual** instruction set:
a German `name2type_german` dict and an `english2german` translation dict in one file.

| German | English | Meaning | Location |
|---|---|---|---|
| `U` / `UN` / `O` | `A` / `AN` / `O` | AND / AND-NOT / OR on the VKE | `types.py:214,215,216`; `:415,418` |
| `U(` `UN(` `O(` `ON(` `X(` `XN(` | — | open a nested boolean sub-expression; closed by a bare `)` | `types.py:220` |
| `S` / `R` | `S` / `R` | set / reset (R also resets a timer or counter operand) | `types.py:229,228` |
| `SI` | `SP` | pulse timer (≈ IEC TP) | `types.py:347,392`; `timers.py run_SI` |
| `SV` | **`SE`** | extended pulse | `types.py:348,410`; `run_SV` |
| `SE` | `SD` | on-delay (≈ IEC TON) | `types.py:349,391`; `run_SE` |
| `SA` | `SF` | off-delay (≈ IEC TOF) | `types.py:351,390`; `run_SA` |
| `ZV` / `ZR` | `CU` / `CD` | up / down counter | `types.py:274,275`; `:421,422`; `core/counters.py` |

Note the collision: **the letters `SE` mean on-delay in the German mnemonic set and
extended pulse in the English one**, inside a single project. It also corroborates
naming.md's classic-STEP 7 coil suffixes (SP/SD/SS/SF) — those are the *English* STL
spellings; the German set is a different alphabet for the same five concepts.

**61131/echidna** — an IEC 61131-3 IL compiler and bytecode VM in C; BSD-2-Clause; last
commit December 2024, markedly less active than the other three. It matters here as the
vendor-neutral counterpart to awlsim: `src/lexer.l`'s parallel string/token tables carry
the standard spellings — `LD`(:67,142), `LDN`, `ST`(:69,144), `STN`(:70,145), `S`(:72,147),
`R`, `AND`(:82,157), `ANDN`(:85,160), `OR`, `ORN`, `XOR`, `XORN`, `ADD SUB MUL DIV MOD`
(88–92), `GT GE EQ LT LE NE` (93–98), `CAL CALC CALCN` (99–101), `JMP JMPC JMPCN`
(:106,181), `RET RETC RETCN`. So the same AND operation is spelled three different ways
across two free implementations — `U` (awlsim German), `A` (awlsim English), `AND`
(echidna) — which is precisely why naming.md treats "the conventional set" as one specific
vocabulary rather than a universal one. Its function blocks are registered in C at
`src/standard/std_timers.c:150-152` (`.Name = "tp"/"ton"/"tof"`),
`std_bistable.c:73,81` (`"sr"`/`"rs"`), `std_counters.c:438,448` (`"ctd"`/`"ctu"` plus
typed rows) and `std_edge.c:96,98` (`"f_trig"`/`"r_trig"`), with a ~100-entry function
registration table in `src/standard.c`.

---

## 6. PLCopen XML / IEC 61131-10

PLCopen TC6 XML v2.01 (`targetNamespace http://www.plcopen.org/xml/tc6_0201`) is the
interchange format that actually moves ladder between Beremiz, the OpenPLC editor and any
other PLCopen-capable tool; it is the basis of IEC 61131-10. Everything below is from the
schema file itself (`tc6_xml_v201.xsd`, line numbers consistent across the Beremiz-bundled
copy and two independent mirrors).

An LD body is an **unordered choice**, not a sequence of rungs:

```xml
<xsd:element name="LD"><xsd:complexType><xsd:choice minOccurs="0" maxOccurs="unbounded">
  <xsd:group ref="ppx:commonObjects"/><xsd:group ref="ppx:fbdObjects"/><xsd:group ref="ppx:ldObjects"/>
```
(L426–434.) A rung is not a schema unit at all: it is the emergent shape of one
`leftPowerRail`'s outputs threading through elements to a `rightPowerRail`.

**Only four elements are LD-only.** The `ldObjects` group (L1376) documents itself as
*"Collection of objects which are defined in ld and are an extension to fbd"*, and contains
exactly `leftPowerRail` (L1381 — `connectionPointOut` sockets only, no input),
`rightPowerRail` (L1411 — `connectionPointIn` only, `maxOccurs="unbounded"`), `coil`
(L1433) and `contact` (L1460). Everything else on a rung — `block` (L1125, *"a call
statement"*, with `typeName` required and `instanceName` optional), `inVariable` (L1228,
*"Expression used as producer"*), `outVariable` (L1257, *"Expression used as consumer"*),
`inOutVariable` (L1286), `jump` (L1337), `label` (L1319), `return` (L1356), comments and
connectors — is shared with FBD.

**And there are no mnemonics.** There is **one** contact element type and **one** coil
element type, parameterized by orthogonal attributes:

| Attribute | Type | Values | On |
|---|---|---|---|
| `negated` | `xsd:boolean`, default `false` | — | contact, coil, inVariable, outVariable |
| `edge` | `ppx:edgeModifierType` (L1717–1726) | `none`, `falling`, `rising` | contact, coil, variables, block pins |
| `storage` | `ppx:storageModifierType` (L1727–1736) | `none`, `set`, `reset` | **coil only** |

Those three attributes cover **all four IEC contact features and all six coil features** as
combinations on two element types: normal / negated / rising / falling contacts; normal /
negated / set / reset / rising / falling coils. `inOutVariable` doubles the modifier set
into `negatedIn`/`edgeIn`/`storageIn` and `negatedOut`/`edgeOut`/`storageOut`. Beremiz's
editor constants mirror the ten cases one-for-one (`graphics/GraphicCommons.py:69-70`).

`label` is the sharpest structural note: it has no `connectionPointIn` or
`connectionPointOut` at all, so it participates in no wire graph — a `jump` finds it by
matching the label string, not by `localId` reference.

**Three designs, not two.** Across this whole survey, ladder element vocabularies fall
into three shapes: *one name per operation* (IEC's own tables, ClassicLadder), *borrow
vendor mnemonics* (logex, LDmicro), and *one element type plus a small closed set of
orthogonal modifiers* (PLCopen XML, and — apparently independently — LDmicro's internal
flag structs).

---

## 7. Cross-cutting comparison

Concept down the side. `—` means the concept is genuinely absent from that system with
evidence for the absence; `?` means not established. The IEC IL column maps the nearest
*operation*, not a graphical element. Cell locations are the ones given in §2–§6; the logex
column is naming.md's, not a new decision.

| Concept | IEC LD | IEC IL | MatIEC / Beremiz ᵃ | LDmicro | ClassicLadder | logex ᵇ |
|---|---|---|---|---|---|---|
| NO contact | Normally open contact, T61 f1 | `LD` T52.1 | `<contact>` negated=false; `CONTACT_NORMAL` | `ELEM_CONTACTS` negated=0 | `ELE_INPUT` | `xic` |
| NC contact | Normally closed contact, T61 f3 | `LDN` Annex B.2.2 | negated=true; `CONTACT_REVERSE` | `ELEM_CONTACTS` negated=1 | `ELE_INPUT_NOT` | `xio` |
| Rising-edge contact | Positive transition-sensing contact, T61 f5 | — | `edge="rising"`; `CONTACT_RISING` | — ᶜ | `ELE_RISING_INPUT` | (none) — `xic aa ons s1` |
| Falling-edge contact | T61 f7 | — | `edge="falling"`; `CONTACT_FALLING` | — ᶜ | `ELE_FALLING_INPUT` | (none) — `xio aa ons s1` |
| Coil | Coil, T62 f1 | `ST` T52.2 | `<coil>`; `COIL_NORMAL` | `ELEM_COIL` (all flags 0) | `ELE_OUTPUT` | `ote` |
| Negated coil | Negated coil, T62 f2 | `STN` | negated=true; `COIL_REVERSE` | `ELEM_COIL` negated | `ELE_OUTPUT_NOT` | `otn` *(proposed)* |
| Set / latch coil | SET coil, T62 f3 | `S` T52.3 | `storage="set"`; compiled to `IF … THEN v := TRUE; END_IF` | `ELEM_COIL` setOnly | `ELE_OUTPUT_SET` | `otl` |
| Reset / unlatch coil | RESET coil, T62 f4 | `R` T52.3 | `storage="reset"` | `ELEM_COIL` resetOnly | `ELE_OUTPUT_RESET` | `otu` |
| Rising one-shot to a bit | Positive transition-sensing coil, T62 f8 | — | `edge="rising"` on coil; `COIL_RISING` | `ELEM_ONE_SHOT_RISING` — **inline, not a coil** | — | `osr` |
| Falling one-shot to a bit | T62 f9 | — | `COIL_FALLING` | `ELEM_ONE_SHOT_FALLING` — inline | — | `osf` |
| One-shot on the rung condition | — | — | — | `ELEM_ONE_SHOT_RISING/FALLING`; inverse twins `ODR`/`ODF` | — | `ons` |
| Toggle coil | — | — | — | `ELEM_COIL` ttrigger | — | (none) |
| Series | Horizontal link, T60 f1 | implicit accumulator | connection graph | `ELEM_SERIES_SUBCKT` | grid geometry | juxtaposition |
| Parallel branch | Vertical link, T60 f2 (inclusive OR) | `(` … `)` T52.21 | connection graph, no delimiter; lowered by joining legs with `" OR "` | `ELEM_PARALLEL_SUBCKT` | grid + `ConnectedWithTop` | `( … \| … )` |
| On-delay timer | a `block` on the rung | `IN`,`PT` T54.12 | `TON` | `ELEM_TON` | `ELE_TIMER_IEC` mode `_ON` | `ton` |
| Off-delay timer | " | `IN`,`PT` T54.13 | `TOF` | `ELEM_TOF` | mode `_OFF` | `tof` |
| Pulse timer | " | `IN`,`PT` T54.11 | `TP` | `THI` (not named TP) | mode `_PULSE`; legacy `ELE_MONOSTABLE` | `tp` |
| Retentive timer | — (only `RETAIN`, T33 f3a) | — | — | `ELEM_RTO`, `ELEM_RTL` | — | `rto` |
| Cyclic / astable timer | — | — | — | `ELEM_TCY`, `OSC` | — | (none) |
| Up counter | a `block` | `CU`,`R`,`PV` T54.8 | `CTU` (+4 typed) | `ELEM_CTU`, inline threshold | `ELE_COUNTER` `InputCountUp` | `ctu` |
| Down counter | " | `CD`,`PV` T54.9 | `CTD` | `ELEM_CTD` | `InputCountDown` on the same block | `ctd` |
| Up/down counter | " | `CU,CD,R,PV` T54.10 | `CTUD` | — (two elements on one name) | one block covers it | (none) — `ctu`+`ctd` |
| Circular counter | — | — | — | `ELEM_CTC` / `ELEM_CTR` | — | (none) |
| Counter reset | the `R` **pin** (CTD has none) | `R` T54.8 | `R` pin | `ELEM_RES` (a separate instruction) | `InputReset` field | `res` |
| Counter bound behavior | implementation-dependent `PVmin`/`PVmax` (T36 NOTE) | — | `CV < PV` guard | ? | **wraps at 0 / 9999** | ? |
| Edge-detect FB | `R_TRIG` / `F_TRIG`, T35 | `CLK` T54.6 | `R_TRIG`/`F_TRIG` (also injected for edge modifiers) | — (inline elements instead) | edge *contacts* instead | (none) |
| Set-dominant bistable | `SR`, T34 f1 | `S1`,`R` T54.4 | `SR` | — (one coil; wiring decides) | — (S/R coils) | (none) |
| Reset-dominant bistable | `RS`, T34 f2 | `S`,`R1` T54.5 | `RS` | — | — | (none) |
| Compare `=` | `EQ` as a function block on the rung, T33 f3 | `EQ` T52.14 | `EQ` | `ELEM_EQU` — spelled **`EQU`** | `ELE_COMPAR`, expression box | `eq` |
| Compare `<` | `LT`, T33 f5 | `LT` T52.17 | `LT` | `ELEM_LES` — **`LES`** | `ELE_COMPAR` | `lt` |
| Add | `ADD`, T29 f1 (extensible) | `ADD` T52.8 | `ADD` (variadic) | `ELEM_ADD` (fixed arity) | `ELE_OUTPUT_OPERATE`, infix `+` | `add a b dst` |
| Move | `MOVE`, T32 f1 / T24 f18 | `LD`+`ST` | `MOVE` | `ELEM_MOVE` — **`MOV`** | `ELE_OUTPUT_OPERATE` | `move` |
| Shift left | `SHL`, T30 f1 | — | `SHL` | `ELEM_SHL` | — (no shift operator in the grammar) | `shl` |
| Shift right | `SHR`, T30 f2 — **zero fill** | — | `SHR` | `ELEM_SHR` + `SR0` | — | `shr` (zero fill) |
| Absolute value | `ABS`, T28 f1 | — | `ABS` | — | `ABS()` in the expression grammar | `abs` |
| Average | — | — | — | — | `MOY` / `AVG` | (none) |
| Jump | Jump element, T58 f1–4 | `JMP`/`JMPC`/`JMPCN` | `<jump>` L1337 | `ELEM_GOTO` | `ELE_OUTPUT_JUMP` | `jmp` *(planned)* |
| Label | Network label, §4.1.2 | `label:` Annex B.2.1 | `<label>` L1319 | `ELEM_LABEL` | rung number as the target | `lbl` *(planned)* |
| Subroutine call | draw the block | `CAL`/`CALC`/`CALCN` | `<block>` | `ELEM_SUBPROG` / `ELEM_GOSUB` | `ELE_OUTPUT_CALL` | `cal` *(deferred)* |
| Return | RETURN element, T58 f5–8 | `RET`/`RETC`/`RETCN` | `<return>` L1356 | `ELEM_RETURN` | — | `ret` |
| Master control zone | — (zero hits in Ed 2) | — | — | `ELEM_MASTER_RELAY` | — | `mcs`…`mce` *(deferred)* |
| SFC / sequential | separate language | — | SFC is a MatIEC target language | — | `ELE_SEQ_STEP` / `_TRANSITION` (Grafcet, no action qualifiers) | (none) |

ᵃ MatIEC has no LD front end. Contact/coil/rail/branch cells are Beremiz's editor and the
PLCopen schema; function/FB cells are MatIEC's own libraries.
ᵇ From [`docs/naming.md`](naming.md); *(proposed)*, *(planned)* and *(deferred)* are its
markings. `xic`/`xio` are two independent positive tests, not IEC's strict complement.
ᶜ LDmicro's `ElemContacts` struct has only `negated` and `set1` — no edge field. Its
edge handling is the separate inline one-shot elements.

---

## 8. What this means for logex

- **Half the planned set takes an IEC name verbatim, and can be cited by table and
  feature.** `ton` `tof` `tp` are Ed 2 T37 f1/f2a/f3a; `ctu` `ctd` are T36 f1a/f2a;
  `eq ne lt gt le ge` are Ed 3 T33 f1–6 (Ed 2 T28 f5–10); `add sub mul div mod` are Ed 3
  T29 f1–5; `abs` and `sqrt` are Ed 3 T28 f1–2. When the naming rule says "use the IEC
  name", these are the rows it is talking about, and the stanzas can now cite the feature
  number rather than the family.
- **Three planned mnemonics have no standard behind them, and the reasons differ.** `rto`
  is not IEC because Table 37 defines exactly three timers and the standard's only
  retention mechanism is the `RETAIN` qualifier on an instance (T33 f3a) — power-fail
  retention, not accumulate-across-drops. `res` is not IEC because reset is a *pin* (and
  CTD has not even got one), not an instruction. `neg` is not IEC because the standard has
  only the ST unary minus. All three are vendor names, and now all three have free-software
  precedent as well: LDmicro ships `ELEM_RTO` with exactly logex's accumulate-and-manual-
  reset semantics, and `ELEM_RES` as a standalone instruction whose manual states the same
  split logex assumes — *"TON and TOF timers are automatically reset … RTO timers and
  CTU/CTD counters are not reset automatically."*
- **`ons`/`osr`/`osf` is where free-software practice contradicts the vendor practice
  naming.md recorded.** In the conventional set, `OSR`/`OSF` name the *coil* form (a
  storage bit plus an output bit) and `ONS` names the inline rung-condition one-shot.
  LDmicro puts the names the other way up: `ELEM_ONE_SHOT_RISING`/`_FALLING` are drawn and
  evaluated as **inline series elements** gating the rung (`--[_/ OSR_/ \_]--`), it has no
  `ONS` at all, and it adds an inverse-output pair `ODR`/`ODF` nobody else has. Beremiz
  and PLCopen take a third position: edge is a *modifier* on any contact or coil, lowered
  to a hidden `R_TRIG`/`F_TRIG` instance. So logex's three-mnemonic split is a
  conventional-set convention, not a universal one — worth saying in the `ons` stanza,
  because a reader arriving from LDmicro will expect `osr` to be the inline one.
- **The negated coil finally has an implementation precedent.** naming.md proposed coining
  `otn` because IEC has the element (T62 f2) and no vendor names it. Free software has it
  three times: ClassicLadder as its own element constant (`ELE_OUTPUT_NOT` 51), LDmicro as
  a flag on the single coil struct, and PLCopen/Beremiz as `negated="true"` on
  `<coil>`. None of them coins a mnemonic — two treat it as a modifier — but the concept is
  clearly load-bearing in practice, which strengthens the case for shipping `otn` rather
  than leaving it proposed.
- **Two decisions logex has already made get external support, and one gets a warning.**
  Support: ClassicLadder's evaluator independently reimplements IEC's vertical-link OR and
  contact-as-AND rules in code, so logex's power-flow model is the converged one; and
  ClassicLadder's counters *wrap* at 0/9999, a concrete instance of the
  implementation-dependence naming.md flagged, so logex should write its own bound behavior
  down rather than assume one. Warning: **rusty's `SHR` sign-extends for signed integer
  types**, choosing vendor semantics over IEC's specified zero fill. naming.md already says
  logex should follow IEC and zero-fill "and say so in the docs" — this is evidence that a
  serious IEC compiler went the other way, so the docs sentence needs to be explicit and
  the test needs a negative operand.
- **The stateful-FB boundary is now empirical, and it matches logex's flat-env problem.**
  IronPLC's ADR-0042 restricts compiler intrinsics to blocks whose retained state cannot be
  expressed in ST, and enumerates exactly `SR RS R_TRIG F_TRIG CTU CTD CTUD TON TOF TP`;
  rusty reaches the same split from the other side (`{external}` FB declarations plus
  `builtins.rs`); MatIEC solves the same problem inside ST by embedding an `R_TRIG` instance
  in `CTU`/`CTD`/`CTUD`. Every one of those is a list of *the instructions that need
  cross-scan state* — which in logex means ordinary tags in the flat env, and which is
  exactly the set whose `evaluate/2` clauses will need a storage operand. It is also a
  reminder that a mandatory de-energized clause is not optional for any of them.

---

## 9. Sources

**IEC 61131-3, primary text.** Both editions were downloaded in full and their text layers
extracted locally; page numbers cite each page's own printed number.

- Ed 2:2003 — `https://d1.amobbs.com/bbs_upload782111/files_31/ourdev_569653.pdf`
  (226 pp). Clauses 3.2.1–3.2.3, 4.1.2–4.1.4, 4.2.1–4.2.6, 2.5.1.5, 2.5.2.2–2.5.2.3.5;
  Tables 22–31, 33–38, 51a/51b, 52–54, 57–62; Annex B.2.1–B.2.2; Annex C.1.
- Ed 3:2013 — `https://raw.githubusercontent.com/martingleich/Iec61131/master/Specification/IEC%2061131-3_2013%20Ed3.pdf`
  (231 pp). §6.6.2.5.2–6.6.2.5.15, Tables 22–39.
- Ed 3:2013 official publisher preview (15 pp: Foreword, Scope, full ToC) —
  `https://cdn.standards.iteh.ai/samples/16899/c7907e9a7e624f2185ff1f8d94e93f9f/IEC-61131-3-2013.pdf`
- Ed 4:2025 official publisher preview (15 pp: Foreword, Scope, partial ToC) —
  `https://cdn.standards.iteh.ai/samples/iec/iec-61131-3-2025/147ba9c730934a119d196fa0473464f8/iec-61131-3-2025.pdf`

**IEC 61131-3 Ed 3 table numbers, secondary.** The conventional set's own IEC-compliance
tables (a vendor programming manual, p.27), which list table *and* feature numbers.
**URL deliberately withheld:** the URL names the vendor that
[`docs/naming.md`](naming.md) leaves unattributed as a matter of project policy, and that
policy explicitly covers prose in the other documents. It is the same vendor whose
instruction-set reference the Conventional column draws on.

**PLCopen TC6 XML v2.01 schema** — read from three copies, consistent line numbers:
`https://raw.githubusercontent.com/actility/ong/master/drivers/iec61131/bin/tc6_xml_v201.xsd`,
`https://raw.githubusercontent.com/fekaputra/gloze-x/master/tc6_xml_v201.xsd`, and Beremiz's
bundled `plcopen/tc6_xml_v201.xsd`. Not fetched from plcopen.org.

**MatIEC / Beremiz** — `github.com/beremiz/matiec` (`readme`; `lib/timer.txt`,
`counter.txt`, `bistable.txt`, `edge_detection.txt`, `sema.txt`, `standard_FB.txt`,
`standard_functions.txt`, `lib/C/iec_std_FB.h`, `lib/C/iec_std_functions.h`,
`stage1_2/standard_function_names.c`, `stage1_2/iec_flex.ll`, `stage1_2/iec_bison.yy`);
`github.com/beremiz/beremiz` @ `effe6529` (`PLCGenerator.py`, `ProjectController.py`,
`graphics/GraphicCommons.py`, `graphics/LD_Objects.py`, `plcopen/Standard_Function_Blocks.xml`,
`plcopen/Additional_Function_Blocks.xml`); `openplcproject.gitlab.io/matiec/`.

**OpenPLC** — `github.com/thiagoralves/OpenPLC_v3` @ `b5d4135` (`README.md`, `install.sh`,
`background_installer.sh`, `webserver/scripts/compile_program.sh`,
`webserver/core/hardware_layers/*`, `utils/matiec_src/*`);
`github.com/thiagoralves/OpenPLC_Editor` @ `2b4add4` (`README.md`, `.gitmodules`);
`github.com/thiagoralves/editor` @ `6a8e930` (`diff_from_beremiz.txt`, `IDEFrame.py`,
`dialogs/LDElementDialog.py`, `dialogs/PouDialog.py`, `graphics/GraphicCommons.py`,
`plcopen/definitions.py`, `plcopen/iec_std.csv`, the FB-library XMLs);
`github.com/thiagoralves/OpenPLC_v2` (`core/lib/iec_std_lib.h`);
`github.com/Autonomy-Logic/openplc-runtime` @ `f264872` (`README.md`, `scripts/compile.sh`,
`webserver/version.py`, `docs/EDITOR_INTEGRATION.md`);
`github.com/Autonomy-Logic/openplc-editor` @ `82f6154`
(`docs/strucpp-migration/00-overview.md`); `github.com/Autonomy-Logic/STruCpp`
(`README.md`, `LICENSE`); `openplcproject.github.io` @ `fb1b89e` (archived reference
pages, since redirected).

**LDmicro** — `github.com/LDmicro/LDmicro` @ `5b058e0` (`ldmicro/circuit.h`,
`ldmicro/ldmicro.h`, `ldmicro/plcprogram.h`, `ldmicro/manual.txt`, `ldmicro/loadsave.cpp`,
`ldmicro/simpledialog.cpp`, `ldmicro/coildialog.cpp`, `ldmicro/contactsdialog.cpp`,
`ldmicro/maincontrols.cpp`, `ldmicro/simulate.cpp`, `ldmicro/intcode.h`, `ldmicro/README.txt`).

**ClassicLadder** — `github.com/LinuxCNC/linuxcnc` master
(`src/hal/classicladder/classicladder.h`, `calc.c`, `calc_sequential.c`, `sequential.h`,
`arithm_eval.c`, `arithm_eval.h`, `vars_names.c`, `vars_names_list.c`, `Submakefile`);
`github.com/MaVaTi56/classicladder` @ `cce0bb6` (`src/classicladder.h`, `src/calc.c`).

**Modern compilers** — `github.com/PLC-lang/rusty` (`README.md`, `Cargo.toml`,
`libs/stdlib/iec61131-st/*.st`, `libs/stdlib/LICENSE`, `src/builtins.rs`);
`github.com/ironplc/ironplc` (`README.md`, `LICENSE`,
`compiler/analyzer/src/intermediates/stdlib_function_block.rs` and `stdlib_function.rs`,
`compiler/sources/resources/libs/Tc2_*/`, `docs/reference/standard-library/function-blocks/sr.rst`,
`specs/adrs/0042-library-functions-over-compiler-intrinsics.md`);
`github.com/mbuesch/awlsim` (`awlsim/core/instructions/types.py`, `core/timers.py`,
`core/counters.py`, `awlcompiler/insntrans.py`, `COPYING.txt`);
`github.com/61131/echidna` (`README.md`, `src/lexer.l`, `src/standard.c`,
`src/standard/std_{timers,bistable,counters,edge}.c`, `LICENSE`).

**In-repository** — [`docs/naming.md`](naming.md), read in full before this document was
started, and grep-confirmed to contain no free-software coverage.

---

## 10. Unverified

The repository's rule is to mark what could not be checked. Every item below was reached
by at least two people — a survey pass and an independent verification pass that re-fetched
the primary sources — and survived both.

**Standard text nobody could reach.**

1. **Ed 3:2013 Table 75 feature 4** (negative transition-sensing contact) and **Table 76
   feature 2** (negated coil). Inferred from the feature-number gaps in the conventional
   set's compliance table, which lists only the features it implements. The Ed 3 table
   itself was not read.
2. **Ed 4:2025 table numbers** for rails, links, contacts and coils, and the **clause
   number of the LD subclause in Ed 3 and Ed 4's restructured numbering**. The free preview
   stops at clause 3. Two web searches for a secondary confirmation returned mutually
   contradictory AI-generated summaries with no traceable primary quote; both were
   discarded as noise. **Related open question inside this repository:**
   naming.md's own Ed 4 citations disagree with each other — its introduction says
   "Ed 4:2025 Tables 74/75" for contacts and coils, while the `xic` stanza cites "Ed 4
   Table 74" for the contact table alone. Neither could be resolved without the Ed 4 text.
3. **Ed 4:2025 Annex B**, the itemized list of what was added, removed and deprecated
   (document p.249). Only its existence and title are confirmed, from the Foreword.
4. **Whether Ed 3:2013 clause 7.2's own prose** (p.195) contains an internal note marking
   IL deprecated. Only its table-of-contents placement was read, which is what falsifies
   the "moved to an annex" claim; a NOTE inside the clause body cannot be ruled out.
5. **Whether Ed 3's Table 68 is row-for-row identical to Ed 2's Table 52.** Both exist as
   normative, non-annexed tables with matching titles; Ed 3's rows were not opened.
6. **IEC 61131-5** was not opened, so the communication function blocks Part 3 defers to it
   are unsurveyed.
7. **PLCopen TC6 XML v2.01 ≡ IEC 61131-10:2019** — asserted by the sources used, not
   verified against the IEC 61131-10 text. The schema itself was read from third-party
   mirrors and Beremiz's bundled copy, not from plcopen.org.

**Free-software behavior that needs a fuller trace.**

8. **Whether ClassicLadder coils pass power flow through to the right link at all.**
   IEC T62 f1 requires it. `CalcTypeOutput()` sets `DynamicInput` and `DynamicState` but
   was not observed assigning `.DynamicOutput` — and `StateOnLeft()`, which every element
   uses to read its left-link input, reads the *predecessor's* `.DynamicOutput`. On the
   traced path, coils do not appear to propagate state by the mechanism downstream elements
   consult. Other consumers of `.DynamicState` were not exhaustively ruled out, so this is
   a lead, not a finding.
9. **Whether ClassicLadder's `ELE_COMPAR` supports IEC's extensible chained comparison**
   (`IN1 > IN2 > IN3 …`). It is confirmed expression-based (`CalcTypeCompar()` calls the
   same `EvalCompare()` evaluator as the Operate block, not a fixed N-ary primitive), but
   whether `arithm_eval.c`'s grammar accepts a chain was not resolved.
10. **`Xor()`'s bitwise-XOR branch in `arithm_eval.c` may be unreachable.** `Pow()` sits
    between `MulDivMod` and `Term` and greedily consumes a following `^` before control can
    return to `Xor()`'s own `^` check. This is a reading of the control flow; the parser was
    not built or executed.
11. **ClassicLadder's license** was not checked, and the date at which `ELE_TIMER_IEC` was
    introduced relative to the legacy `ELE_TIMER` is not known — both structs simply
    coexist in the tree read.
12. **LDmicro's `ELEM_COPY_BIT` / `ELEM_XOR_COPY_BIT` are dead in current master** (grep
    finds them only in their own `#define` and the `CASE_LEAF` macro). Whether an older or
    newer release ever wired them up was not checked.
13. **LDmicro's `SET_PWM_SOFT` / `PWM_OFF_SOFT` are unimplemented stubs**, not merely
    undocumented: the only UI hook for the former reads `"TODO: Insert Software &PWM (AVR136
    AppNote)"` and the latter's menu id is never referenced by any `AppendMenu` call. Their
    intended semantics remain unknown.
14. **MatIEC's fork lineage** was not diffed against anything. `nucleron/matiec`, named as a
    second fork worth checking, is unreachable — 404 from github.com, raw.githubusercontent.com
    and jsdelivr alike — so it was never opened.
15. **OpenPLC v4's server-side compile path.** Whether the v4 REST API drives STruC++
    end-to-end for a full LD program was not confirmed; the migration doc marks the
    runtime `.so` integration (its phases 5–9) as in progress. Two v4 sources disagree:
    `docs/EDITOR_INTEGRATION.md` still describes the old pipeline (*"ST is transpiled to C
    code using iec2c"*) while `scripts/compile.sh` and `webserver/version.py` state the
    opposite. The code was trusted over the prose doc, and the disagreement is recorded
    rather than resolved.
16. **echidna's README claim** to support *"all IEC 61131-3 standard functions, function
    blocks and configuration elements"* is substantially but not completely checked: the IL
    token set, the ~100-entry function registration table in `src/standard.c` and the FB
    registrations in `src/standard/*.c` were read; configuration elements were not.
17. **Beremiz's IDE block-palette labels** were not compared against MatIEC's internal
    library names, and **whether OpenPLC Runtime v4 still vendors MatIEC unmodified** was
    checked only against v2/v3 trees.

**Corrections — claims that are commonly made and are wrong.**

18. **"IEC 61131-3 Ed 3 (2013) demoted Instruction List to an informative annex / Annex C."**
    False, and repeated widely enough that it is worth naming. Ed 3's Scope names IL as one
    of two textual languages; IL is normative clause 7.2 with its own Table 68; Ed 3's
    annexes are A and B, and there is no Annex C. The removal is Ed 4:2025.
19. **"LDmicro's element set is an `enum ELEM_*` in `ldmicro/lang.h`."** It is a flat set
    of `#define` constants in `ldmicro/circuit.h`; `lang.h` holds menu-string and
    translation tables.
20. **"MatIEC is the IEC 61131-3 compiler behind OpenPLC's and Beremiz's ladder."** MatIEC
    has no LD front end at all — zero occurrences of "coil" or "contact" in its grammar.
    Ladder is lowered to ST by the editor first.
21. **Ed 3's Table 37 is internally inconsistent about its own function names**, printing
    `BIG_ENDIAN_TO` / `LITTLE_ENDIAN_TO` in the Description column while the graphical box
    and ST example both read `FROM_BIG_ENDIAN` / `FROM_LITTLE_ENDIAN`. Whether Ed 4 fixed
    this is unknown (item 2).

**Citation defects found and corrected during verification**, listed so they are not
reintroduced from older notes: two LDmicro secondary citations to `maincontrols.cpp` (lines
443 and 408) point at lines that do not contain the identifiers claimed and have been
dropped in favor of the `circuit.h` primaries; LDmicro `DIV` is documented at
`manual.txt:1034`, not 1050; `RETURN` at `circuit.h:134` / `manual.txt:1978`, not
`manual.txt:1946`; `NPULSE_OFF` at `circuit.h:165` / `loadsave.cpp:1108`, not
`loadsave.cpp:1249`; the Arduino FB library's `PWM_CONTROLLER` and `ARDUINOCAN_READ` are at
lines 325 and 561, not line 20 (which is `DS18B20`); Ed 3 Table 35 is on pp.93–94, not
87–88; Ed 3 Table 24's first row is on p.82, not p.81. ClassicLadder's `ELE_COMPAR` and
`ELE_OUTPUT_OPERATE` shifted by +30 lines in LinuxCNC master on 2026-08-21 (a header-guard
commit), which is why this document cites them by symbol and value rather than by line.