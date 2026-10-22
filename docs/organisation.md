# Program organisation: the IEC software model, in logex's dialect

**Status: decided; the Milestone-1 changes in §6.1 landed with M1-3, M1-5 and M1-6. How a
running controller is changed, §4.9, was decided on 2026-10-01, and its first step, OE-1's
edit of one program instance, was designed there (decisions 21–29) and landed as
`Logex.Edit` the same day. Milestone 2 was designed on 2026-10-02 (§4.10, decisions
30–40), and its first item, M2-1, landed the same day: configurations with periodic tasks,
globals at I/O points and connections, built from Elixir data (`Logex.Configuration`) and
run as one resource (`Logex.Runtime.start/1` and `cycle/3`). User function blocks, M2-5,
landed on 2026-10-04: a block's file, its instances run with `cal`, the blocks
`Logex.compile_file/1` loads from beside a program, and the online edit of a program that
holds them, by path (§4.3 and §4.10). The configuration file, `.logex`, read with the
program types beside it (`Logex.Configuration.compile_file/1`), landed with M2-2 and M2-3
on 2026-10-11, and globals shared through `var_external` and event tasks with M2-4 and
M2-6 on 2026-10-12, so Milestone 2 is done. OE-2, the staged edit of a running
configuration (`Logex.Configuration.Edit`), was designed and landed on 2026-10-13 (§4.9,
decisions 55–66). Milestone 3, the missing instruction set, was decided on 2026-10-14
(decisions 67–92) and landed by 2026-10-15: IEC's counters, the other timers, integer
arithmetic, the pulse coils and the forward jump, M3-1 to M3-5 (decisions 93–107). So
Milestones 1 to 3, OE-1 and OE-2 have landed. Milestone 4, the wall-clock runner, was
designed and decided on 2026-10-17 (§4.11, decisions 108–121), and its first item, M4-1,
the clocks, the adapter behaviour and the simulated device, landed the same day; its
review's answers followed on 2026-10-18 (decisions 122–126), with the maintainer's answer
on forces (decision 127); M4-2, M4-3 and M4-4, the watchdogs and the fault path, landed
the same day (decisions 128–131), and the findings of M4-4's review were fixed on
2026-10-19, §4.11's landing note, the maintainer answering its five questions the same
day (decisions 133–137); and M4-5, forcing and an online edit through the runner, landed
the same day, its review's findings fixed the same day, four of its readings put to the
maintainer and answered the same day (§4.11's landing note, decisions 138–141); and M4-6,
the contract walk over the runner, the same day, with the fix it found (decision 114's
note), and the question it raised answered by the maintainer on 2026-10-20 and built, a
restart that reads every device first (decision 142), and two calls of the lead's in
its verifications confirmed by the maintainer on 2026-10-20, a report-only reading kept
across a restart as a fix within decision 142, and a refused change's good points kept
(decision 143); and M4-7, the documents, the same day, the last of Milestone 4's items:
§4.5's adapter contract, §4.6's watchdog paragraph, §5's row and decision 14 annotated as
landed, and README's "Running a plant on the clock" and "What logex is not". Milestone 5,
data types, was designed and decided on 2026-10-21 (§4.12, decisions 144–160): IEC's
integer widths, signed and unsigned, overflow wrapping in every width (superseding
decision 77), the two reals, the bit strings and the bitwise instructions, arrays of up
to three dimensions, located too, typed counters and long timers; the record's ten
questions put back and its three open rules were answered by the maintainer the same day
(decisions 161–167, and notes on the decisions they settle); nothing of it is built
yet.** On 2026-09-28 the
maintainer adopted the direction in §1 (IEC's software model, in logex's dialect: the
hierarchy, task-style execution and I/O mapping), deferred routines, and took decisions
1–14 in §7 as recommended. `PLAN.md` records them: §5 the direction, M1-3, M1-5 and M1-6
the §6.1 changes, and §3's Milestone 2 the §6.2 items. The syntax below is decided, but
each new word still gets its `docs/naming.md` stanza before its code lands, and a stanza
may still change a spelling. It was written against `37b7932`; the rationale stays here,
and the plan of record is `PLAN.md`.

## 1. Why this document, and the direction

The maintainer's brief:

> I just want to make sure we are heading in a direction that implements a lot of the
> things in IEC (with a logex flavour) because we need the hierarchy and the different
> task-style execution, IO mappings, etc.

**What logex has today.** A `.ld` file is one program type. `Logex.compile_file/1` turns
it into a named `%Logex.Program{}` whose tags are declared and typed, with `var_input` and
`var_output` roles (M1-3). `Logex.Runtime` runs one instance of it, one scan per call, with
a clock and a first-scan bit the host advances (M1-5). There is no task, no configuration
and no loop: the host calls every scan. M1-6 added declared timers (`var t1 ton`), `ons`
and the comparisons, and OE-1 `Logex.Edit`, which changes the program a running instance
runs without a restart (§4.9). None of those items says what sits above one program.

*(When this document was written, on 2026-09-28, a `.ld` file was one routine that
`evaluate/2` ran once against a flat `env`, with no program name, instance or scan loop,
and nothing to mark which tags are physical inputs. §6.1's Milestone-1 changes are what
changed that.)*

**The direction.** logex follows IEC 61131-3's software model:

- a configuration contains resources;
- a resource runs program instances under tasks;
- program instances contain function-block instances;
- globals and I/O bindings connect them.

logex spells that model in its own dialect (`PLAN.md` §5):

- lowercase keyword lines, one declaration per line;
- no IEC punctuation (`:`, `:=`, `=>`, `;`, `( )`);
- IEC's names lowercased wherever IEC names the thing (naming rule 1);
- integer milliseconds in place of `T#` literals;
- time that the caller injects and that is never read from a clock.

**Routines are deferred by decision.** In the conventional family (below) a routine is a
subroutine that shares its program's scope, called with JSR. IEC has no such element (§2, §5).

**What this document is not.** It makes no conformance claim. Where logex departs from
IEC it says so and gives the reason. It records no naming decision either: each new word
still gets its own `docs/naming.md` stanza before its code lands (CLAUDE.md, step 1).

**Citations.**
- *Ed 2* is IEC 61131-3:2003 and *Ed 3* is IEC 61131-3:2013, the texts listed in
  `docs/instruction-sets.md` §9. Page numbers are each page's printed number.
- The mainstream vendor whose mnemonics logex borrows is called **the conventional
  family** here. `docs/naming.md` and `CONTRIBUTING.md` ("Do not restore vendor names")
  leave that vendor unattributed in every document, so its manuals are cited by title and
  date:
  - the *import/export reference* (Sept 2025);
  - the *general instructions reference* (Sept 2025);
  - the *design considerations reference* (Sept 2025);
  - the *add-on instructions manual* (Sept 2025);
  - the *ladder-diagram programming manual* (July 2022);
  - the *quick start* (Oct 2009).
- The spikes behind this design ran on copies of `37b7932`, those behind §4.9 on copies
  of `1984b07`, and OE-1's (§4.9, "OE-1's design") on copies of `730cb16`, all on Elixir
  1.20.4 / OTP 28. They are not in the repository. Their output is quoted as receipts and
  pins nothing.

---

## 2. The IEC model, top down

Ed 3 keeps Ed 2's model: *"This third edition is a compatible extension of the second
edition"* (Ed 3 Foreword, p.7). Its Table 62 repeats Ed 2's Table 49 and splits one feature
(VAR_CONFIG) in two.
Clauses are cited in Ed 2, with the Ed 3 equivalent wherever one is quoted.

**Containment.** *"A configuration contains one or more resources, each of which contains
one or more programs executed under the control of zero or more tasks. A program may
contain zero or more function blocks"* (Ed 2 §1.4.1, p.15).

| Element | What IEC says | Where |
|---|---|---|
| **Configuration** | The whole controller. It holds the globals, the resources, access paths (VAR_ACCESS) and instance-specific initial values (VAR_CONFIG) | Ed 2 §2.7.1; syntax Annex B.1.7, p.157 |
| **Resource** | A processor. *"The RESOURCE...ON...END_RESOURCE construction is not required in a configuration with a single resource."* | Ed 2 §2.7.1 NOTE, p.110 |
| **Task** | Has three inputs: SINGLE, INTERVAL and PRIORITY. SINGLE: *"scheduled for execution upon each rising edge of the SINGLE input of the task"* (rule 1). INTERVAL: *"periodically at the specified interval as long as the SINGLE input stands at zero (0)"* (rule 2). PRIORITY: *"zero (0) being highest priority"* (rule 3) | Ed 2 §2.7.2, p.114 |
| **Program with no task** | *"A program with no task association shall have the lowest system priority"*, and it *"shall be re-scheduled for execution as soon as its execution terminates"* (rule 4) | Ed 2 §2.7.2, p.115; Ed 3 §6.8.2 d), p.181 |
| **Program type and instance** | *"Programs can only be instantiated within resources, as defined in 2.7.1, while function blocks can only be instantiated within programs or other function blocks."* Otherwise *"The declaration and usage of programs is identical to that of function blocks"* | Ed 2 §2.5.3, p.83 |
| **Function block instance** | Its output and internal values *"shall persist from one execution of the function block to the next"* | Ed 2 §2.5.2, p.66 |
| **Variables** | *"VAR_INPUT Externally supplied, not modifiable within organization unit"*; VAR_OUTPUT is *"Supplied by organization unit to external entities"*; VAR_EXTERNAL is *"Supplied by configuration via VAR_GLOBAL"* | Ed 2 Table 16a, p.39; Ed 3 §6.5.2.1 Figure 7, p.50 |
| **Sharing** | Globals are *"only accessible to a program organization unit via a VAR_EXTERNAL declaration"*, and the two declarations' types *"shall agree"*. Programs communicate this way: *"These variables shall be declared as GLOBAL in the configuration, and as EXTERNAL in the programs"* | Ed 2 §2.4.3, p.40; §1.4.2, p.16 |
| **Connections** | A program instance's inputs and outputs connect to directly represented variables (8a, 9a) or to globals: *"8b Connection of GLOBAL variables to PROGRAM inputs"*, *"9b Connection of PROGRAM outputs to GLOBAL variables"*. There is no program-to-program connection | Ed 2 Table 49, p.112 |
| **Access paths** | *"the complete hierarchical concatenation of instance names, beginning with the name of the resource (if any)"* … *"separated by dots"* | Ed 2 §2.7.1, p.111 |
| **Physical I/O** | A direct representation such as `%IX1.1`, or a symbolic variable located with `AT`: *"shall be accomplished by the use of the AT keyword"*. What an address means is not standard: *"The manufacturer shall specify the correspondence between the direct representation of a variable and the physical or logical location"* | Ed 2 §2.4.3.1, p.41; §2.4.1.1, p.37 |
| **Network** | *"A network is defined as a maximal set of interconnected graphic elements"*. A network is local to its POU. Networks are evaluated top to bottom (§4.2.6, p.141) | Ed 2 §4.1.2, p.135 |

IEC's textual form, which logex respells in §4, is Ed 2 Figure 20, p.113 (four of its
lines, not contiguous, with the feature-number column dropped):

```
TASK FAST_1(INTERVAL := t#10ms, PRIORITY := 1) ;
PROGRAM P1 WITH SLOW_1 :
             F(x1 := %IX1.1) ;
TASK INT_2(SINGLE := z2,       PRIORITY := 1) ;
```

**Four facts that constrain logex.**

1. **No routine.** "Routine" occurs zero times in the extracted text of either edition.
   Ed 3 names what can be called: *"A call is used to execute a function, a function block
   instance, or a method of a function block or class"* (Ed 3 §6.6.1.4.1, p.60). A program
   is not callable.
2. **Addresses in POU bodies are deprecated.** Ed 3: *"The use of directly represented
   variables in the body of POUs and methods is deprecated functionality"*. The reason given
   is that such use *"limits the reusability of these program organization unit types"* (Ed 3
   §6.5.5.1, p.54).
3. **Keywords are reserved, in any case.** *"The case of characters shall not be
   significant in keywords"*, and *"The keywords listed in annex C shall not be used for
   any other purpose, for example, variable names"* (Ed 2 §2.1.3, p.24).
4. **Missing a deadline is an error, but reporting it is enough.** *"It shall be an error
   in the sense of subclause 1.5.1 if a task fails to be scheduled or to meet its execution
   deadline"* (Ed 2 §2.7.2, p.115). §1.5.1 d) lets an implementation handle such an error in
   either of two ways (p.21):
   - 1) *"there shall be a statement in an accompanying document that the error is not
     reported"*;
   - 4) *"the system shall report the error during execution of the program and initiate
     appropriate system- or user-defined error handling procedures"*.

---

## 3. The conventional family's hierarchy, mapped onto IEC

A user who arrives from the conventional family knows this tree, from its import/export
reference; the I/O tag spelling `Local:0:I.Data` is from the general instructions
reference (a CPS example, p.563). The IEC element is on the right. The row pairings are
this document's reading, not either source's.

```
CONTROLLER                                   CONFIGURATION (+ one implicit RESOURCE)
  MODULE tree, I/O tags Local:0:I.Data         (manufacturer-defined meaning of %I/%Q)
  user data types                              TYPE … STRUCT
  add-on instruction definitions               FUNCTION_BLOCK types
  controller-scope tags                        VAR_GLOBAL, reached only via VAR_EXTERNAL
  TASK Continuous | Periodic | Event           program with no task | INTERVAL | SINGLE
    [programs, run in the order listed]        PROGRAM inst WITH task : Type (…)
  PROGRAM (definition and scheduling at once)  PROGRAM type + its instances
    program tags (shared by every routine)     VAR of one POU
    Input/Output/InOut parameters              VAR_INPUT / VAR_OUTPUT / VAR_IN_OUT
    TIMER / COUNTER tags                       TON / CTU instances
    MAIN + routines, JSR/SBR/RET               one body; calls are to FBs and functions
      rung                                       network
  PARAMETER_CONNECTION                         none: output => global, global := input
```

| Conventional element | IEC | Fit | What differs |
|---|---|---|---|
| Continuous task | program with no task | close | *"There can be only one continuous task"* (import/export ref., ch.14, p.313). That it runs at the lowest priority is **from memory** *(Read 2026-10-17: "It always runs at the lowest priority. All other tasks interrupt the continuous task", the tasks, programs and routines manual, Sept 2025, p.13; and "When the continuous task completes a full scan, it restarts immediately", p.8. Milestone 4 runs it so, decisions 108 and 111.)* |
| Periodic task | TASK with INTERVAL | close | Priority *"(1...15)"* in the import/export reference (p.313). The general instructions reference says *"Valid values 0...15."* (TASK object, p.276). Neither says which end is higher |
| Event task | TASK with SINGLE | partial | The conventional family has a fixed list of hardware and software triggers. IEC has one Boolean rising edge |
| Watchdog, overlap count | none | none | "watchdog" occurs zero times in either edition. The family counts overlaps: *"The number of times that the task was triggered while it was still executing"* (general instructions ref., TASK object, p.275) *(Read 2026-10-17: each task has a watchdog of its own, 1 to 2,000,000 ms and 500 ms by default, timed from the task's start until all its programs have run, interruptions by other tasks included, the tasks, programs and routines manual, p.34. Milestone 4 takes it, decisions 109 and 110.)* |
| Program | program type **and** instance | partial | *"A program can be scheduled under one task only"* (import/export ref., p.315). That there is therefore no type/instance split is an inference: the family reuses logic through add-on instructions, not through programs |
| Controller-scope tag | VAR_GLOBAL | partial | *"Controller tags are seen by routines in any program"* (import/export ref., ch.8, p.204). IEC requires VAR_EXTERNAL |
| Program tags and routines | one POU's VAR, one body | none | Program tags *"are seen only by routines under that program"* (same page), so routines share a scope. IEC has no routine |
| Parameter connection | none | none | Shares data between programs *"without using controller-scope tags"* (ch.15, p.316). IEC goes through a global (Table 49 8b/9b) |
| Alias tag on an I/O member | located variable (`AT`) | partial | `tag_name [OF alias]` (ch.6, p.124). This is the pattern §4.5 adopts |
| TIMER tag | TON instance | close | `.PRE` is DINT, *"(1 millisecond units)"* (general instructions ref., TIMER structure, p.132). The member mapping `.pre`→PT, `.acc`→ET, `.dn`→Q is an inference |
| I/O sampling | not specified by IEC | — | *"I/O module data updates asynchronously to the execution of logic."* The manual's remedy: *"You can also use Input and Output program parameters which automatically buffer the data"* (ladder-diagram manual, ch.1, p.14) |

**What such a user will find, and what will surprise them.**

- **Found where expected:**
  - the continuous task, as a program with no `with`;
  - periodic tasks (`interval`) and event tasks (`single`);
  - timer members `.pre .acc .dn .tt .en` in integer ms, per `docs/naming.md` Timers.
- **Surprises:**
  - reuse comes from instantiating a program type, or from a function block, where this
    user would write an add-on instruction;
  - every program-to-program link needs a named global;
  - there are no controller-scope tags and no routines;
  - inputs are sampled once per cycle, not asynchronously.

---

## 4. The logex target

### 4.1 The hierarchy

| IEC element | logex form | Where the state lives | Stage (§6) |
|---|---|---|---|
| network | one rung, one line | — | done |
| PROGRAM type | one `.ld` file, named by its file: `motor.ld` is type `motor` | none. `%Logex.Program{}` is stateless | M1-3, M1-5 |
| VAR / VAR_INPUT / VAR_OUTPUT | `var fault bool`, `var_input start bool`, `var_output motor bool` | the instance | M1-3 |
| standard FB instance | `var t1 ton`, then `ton t1 5000` on a rung, and `t1.acc` | nested in the instance: `t1` | M1-6 (landed) |
| program instance, no task | M1: `Logex.Runtime.scan/2`. M2: `program m1 motor` | one state per instance | M1-5, M2-2 |
| CONFIGURATION, single resource | one configuration file, `.logex` (decision 35) | globals, instances, task clocks | M2-1, M2-2 |
| VAR_GLOBAL, located or not | `var_global k1 bool at panel.q.0`, `var_global estop bool` | the configuration | M2-2 |
| connections (Table 49 8b/9b) | `m1.start pb_start_1`, `m1.motor k1` | copied in and out per scan | M2-2 |
| TASK, periodic | `task fast interval 10 priority 1` | per task: next due time | M2-3 |
| VAR_EXTERNAL | `var_external estop bool` in a `.ld` | the configuration's global | M2-4 |
| FUNCTION_BLOCK type and instance | a file headed `function_block seal`; `var s1 seal`, `cal s1 …` | nested: `m1.s1.run` | M2-5 (landed) |
| TASK, event | `task trip single estop priority 0` | per task: last SINGLE value | M2-6 (landed) |
| access path | `m1.t1.acc`, read by `Logex.Runtime.get/2` | — | M1-6, M2 |

**Three rules hold from M1-3 onwards.**

1. **The compiled program is a named, stateless type.**
2. **Its state is one instance.** Instance state is a tree:
   - it maps each declared name to an integer, or to a nested instance (`t1`, `s1`);
   - M1-3's flat `%{String.t() => integer}` is a Milestone-1 fact, not an invariant;
   - it is keyed by declared tag name. That is what later lets a new program type replace
     an old one while each instance keeps its state (online edit, §4.9; `PLAN.md` OE-1 and OE-2).
3. **`var_input` and `var_output` are the program's interface.** A configuration binds that
   interface to the I/O image. In IEC the image is the `%I`/`%Q` area, and VAR_OUTPUT is
   only an interface. Making the declarations double as the image for a lone `.ld` is
   logex's simplification.

### 4.2 A program type: the README motor

This is `motor.ld` under the M1-3 tag design. The rungs are the README's, unchanged:

```
var_input start bool
var_input stop bool
var_input overtemp bool
var_input reset bool
var_output motor bool
var_output run_lamp bool
var_output speed_sp dint 1200
var fault bool

( xic start | xic motor ) xio stop ote motor
xic motor ote run_lamp
xic overtemp otl fault
xic reset otu fault
xic fault move 0 speed_sp
```

No `program motor` header line. The file name is the type name, and the type name never
appears in the body, so the tag `motor` and the type `motor` do not collide. A lone
`.ld` runs as the **implicit configuration**: one resource and one instance with no task,
whose var_inputs and var_outputs are the host's input and output image. That is IEC rule 4
and M1-5's `scan/2`, so PLAN's Milestone-1 done sentence stands.

### 4.3 Hierarchy inside a program: timers and function blocks

**A function block type** is a `.ld` file whose first line names its kind *(its first
rung, since 2026-10-02: comments and blank lines may come before it; §4.10, M2-5)*:

```
function_block seal
var_input start bool
var_input stop bool
var_output run bool

( xic start | xic run ) xio stop ote run
```

**The motor, rewritten to use it** (M2-5 form). `estop` is shared through the
configuration (§4.4):

```
var_input start bool
var_input stop bool
var_input overtemp bool
var_input reset bool
var_output motor bool
var_output run_lamp bool
var_output speed_sp dint 1200
var_output running_ms dint
var_external estop bool
var fault bool
var halt bool
var s1 seal
var t1 ton

xic estop otl fault
xic overtemp otl fault
xic reset otu fault
( xic stop | xic fault ) ote halt
cal s1 start halt motor
xic motor ote run_lamp
xic fault move 0 speed_sp
xic motor ton t1 5000
xic motor move t1.acc running_ms
```

**`cal`: rung power is EN.** In LD a block passes power: *"At least one Boolean input and
one Boolean output shall be shown on each block to allow for power flow through the
block"* (Ed 2 §4.2.5 item 2, p.141). So rung power is the instance's EN, and its ENO is
the power out. IEC's rules for a false EN (Ed 2 §2.5.2.1a), p.68):
- *"the operations defined by the function block body shall not be executed and the value
  of ENO shall be reset to FALSE (0)"*;
- since ENO is then FALSE, rule 3 applies: *"the values of the function block outputs
  (VAR_OUTPUT) keep their states from the previous invocation"*;
- input assignment on a false EN *"may or may not be made in an implementation-dependent
  fashion"*.

logex's choice (decision 12): on a false EN, `cal` copies nothing in and
writes nothing out. The instance is frozen, and so is every tag its output operands name.
That is why the example routes `estop` into `halt`, not in front of `cal`:
`xio estop cal s1 …` would freeze the motor running, not stop it.

**Built-in timers and counters keep the conventional model**, which is not IEC's EN. On
`ton t1 5000`, rung power is the timer's IN, and a false rung resets it (`docs/naming.md`
Timers). The two meanings of rung power are deliberate, and the `cal` stanza must say so.
The de-energised `evaluate` clause is mandatory for both (CLAUDE.md). What power a `ton`
passes on is left open: the rung's, as after `ote`, or the timer's `.dn`, IEC's Q, which
the item-2 rule above would have a reader expect on the right of the block. Until that is
settled nothing may follow a `ton` on its path, in its leg or after a group one of whose
legs holds one (M1-6), and a rung below reads `t1.dn`; allowing either reading later
breaks no program.

**`cal`'s signature comes from the FB type, not from `@instructions`.**
- The operands are positional, in declaration order: the var_inputs, then the var_outputs.
  This is IL's non-formal CAL, Ed 2 Table 53 feature 1a, p.127:
  `CAL CMD_TMR(%IX5, T#300ms, OUT, ELAPSED)`.
- An arity or type error names the formal, for example
  ``operand 2 of `cal s1` is `stop` (var_input bool)``.
- Two swapped bool operands still compile, which is the price of the positional form.
- `@instructions` and `naming_test.exs` stay the table of built-in mnemonics. The
  signatures of user FB types are built per compile. *(Milestone 2's design: `cal`'s own
  entry in `@instructions` is a marker, `{:cal, :block}`, so the table still reserves it;
  §4.10, M2-5.)*
- Reads of outputs such as `s1.run` work anywhere. Writes to an instance's members from
  outside it: reads anywhere, writes only to `.pre` and `.acc` (decision 9; M1-6).
  *(Changed 2026-10-02 by decision 33 for a user function block: its inputs and outputs
  are read anywhere, its own `var`s are hidden, and nothing outside it writes any of its
  members. `.pre` and `.acc` are a timer's.)*

**Why the word `cal`.** IEC has three spellings of the call, and `cal` is the only word
among them. ST calls an instance by its name (`CMD_TMR(IN:=%IX5, PT:=T#300ms) ;`, Ed 2
Table 56 item 2, p.132), and LD draws a block. `CAL` is the IL operator, from a language Ed 3
calls *"deprecated and will not be contained in the next edition of this standard"* (§7.2.1,
p.195) and Ed 4 removed. The `cal` stanza must say that its rule-1 claim rests on Ed 2/3 IL.
The ST form, with the instance name as the mnemonic, would put a tag in mnemonic position,
so the words that start an instruction would depend on each file's declarations. That
undoes the rule that mnemonics are reserved and never tags (`PLAN.md` §5).
`docs/naming.md` is append-only, so M2-5 appends a `cal` stanza that supersedes its
`cal <routine>` row and leaves the row in place.

**Recursion is a diagnostic.** Ed 2 §2.5, p.45: *"Program organization units shall not be
recursive"*. Ed 3 makes it *"Implementer specific"* (§6.6.1.1, p.58). logex forbids a
cycle among FB types, which fits a model where one instance is one nested map.

**As landed (M2-5, 2026-10-04; §4.10 gives its rules, `PLAN.md` M2-5 its commits).**
- *A block's file* compiles to `{:ok, %Logex.FbType{}}`. Its members are its
  declarations, each with a role: `:input`, `:output`, or `:local` for its own `var`, an
  instance it holds included. Its `body` is the `%Logex.Program{}` of its rungs, named
  after the block. `Logex.FbType.user?/1` holds for a type of the shape a compile gives,
  its body checked by `Logex.Compiler.lowered?/1`, the definition of a compiled body, so
  a type edited by hand into one no compile gives over its tag table is an
  `ArgumentError` where it is given. *(Narrowed 2026-10-04, after the check of M2-5's
  fixes, from "holds exactly for a type a compile could give": `user?/1` never compiles
  a body's source text again, so a rung edited into another that text could say, the
  text left as it was, passes as a version of its own, which only a compile that also
  holds the genuine one refuses, by `Logex.FbType.same?/2`. Whether `user?/1` is to
  compile the source again is left to the maintainer, `PLAN.md` M2-5.)* *(Since decision
  54, 2026-10-05: `user?/1` compiles each body's source text again and asks that it give
  the body given, so it holds exactly for a type `Logex.compile/2` gives for a block's
  text, and a type edited by hand is an `ArgumentError` where it is given, whether or not
  text could say what it holds.)*
- *Getting a block.* A source is given its blocks in `Logex.compile/2`'s `types:`, or
  `Logex.compile_file/1` finds each type word that could name one as `<word>.ld` beside
  the file that names it, compiles it first, once a call, and hands back its warnings
  after the program's own, each with its block's file (decision 34). One compile holds
  one version of each block name. A member that holds an instance of a block has the type
  `{:block, name}`, and the holder's body holds that type once. *(Since decision 53,
  2026-10-05: the outermost type, and a program, hold every type below them once, in one
  table, and every instance at any depth names its type.)*
- *Members* (decision 33): an instance's inputs and outputs are read anywhere, its own
  `var`s are named only inside its body, and nothing outside it writes any of its
  members.
- *Recursion* is refused at any depth: in a block's own file, through a type given, and
  through a chain of files the loader follows, at the line that closes the chain, which
  the message names.
- *The motor above* needs M2-4's `var_external`. With `estop` declared a `var_input`
  instead, and `seal.ld` beside it, it compiles with no warning and runs as described.
  *(M2-4 landed 2026-10-12: as written, `seal.ld` beside it, it compiles with no warning,
  and `end_to_end_test.exs` runs it, cut from this document, in §4.4's plant.)*

### 4.4 The configuration

`plant.logex` has two instances of one type on two periodic tasks, an event task, located
I/O and a shared global:

```
// plant.logex -- two conveyors, one program type (motor.ld)
task fast interval 10 priority 1
task slow interval 50 priority 2
task trip single estop priority 0

var_global estop      bool at panel.i.7
var_global pb_start_1 bool at panel.i.0
var_global pb_stop_1  bool at panel.i.1
var_global tt_1       bool at panel.i.2
var_global pb_start_2 bool at panel.i.3
var_global pb_stop_2  bool at panel.i.4
var_global tt_2       bool at panel.i.5
var_global pb_reset   bool at panel.i.6
var_global k1         bool at panel.q.0
var_global k2         bool at panel.q.1
var_global lamp_1     bool at panel.q.2
var_global lamp_2     bool at panel.q.3
var_global sp_1       dint at drive.q.0
var_global sp_2       dint at drive.q.1
var_global k1_at_trip bool
var_global k2_at_trip bool

program m1 motor with fast
  m1.start    pb_start_1
  m1.stop     pb_stop_1
  m1.overtemp tt_1
  m1.reset    pb_reset
  m1.motor    k1
  m1.run_lamp lamp_1
  m1.speed_sp sp_1

program m2 motor with slow
  m2.start    pb_start_2
  m2.stop     pb_stop_2
  m2.overtemp tt_2
  m2.reset    0
  m2.motor    k2
  m2.run_lamp lamp_2
  m2.speed_sp sp_2

program snap snapshot with trip
  snap.a     k1
  snap.b     k2
  snap.a_was k1_at_trip
  snap.b_was k2_at_trip
```

`motor` here is the §4.3 form: its `estop` reaches both instances through `var_external`,
not through a connection. `snapshot.ld` is four declarations (`var_input a bool`,
`var_input b bool`, `var_output a_was bool`, `var_output b_was bool`) and two rungs,
`xic a ote a_was` and `xic b ote b_was`. The `trip` task has priority 0, so on the cycle
the e-stop rises it runs before `m1` and `m2`. It records which contactors were closed at
the trip, reading the output points back, which is allowed. *(Worded more exactly
2026-10-04, decision 46: it runs before any instance due in that cycle. An instance sees a
global when it runs, so `m2`, on the 50 ms task, sees the e-stop only at its next scan, and
an e-stop must be held at least as long as the slowest interval that reads it, as a
maintained e-stop contact is: a 10 ms pulse never reaches `m2`.)* *(Landed with M2-4,
2026-10-12: `end_to_end_test.exs` cycles this plant, its `trip` task left out until M2-6,
with §4.3's motor; the e-stop raised at 50 ms, a cycle both tasks run, drops `k1` and `k2`
in that cycle, and a 10 ms pulse at 20 ms stops `m1` and never reaches `m2`.)* *(Landed
with M2-6, 2026-10-12: the plant as written reads, compiles with no warning and runs,
from text and from files on disk, its `trip` task among them; `trip` runs once per rising
edge of `estop`, before `m1` and `m2` in each cycle it runs, and in cycle 1 if `estop` is
already 1, and `snap` records the contactors as the cycle before left them.)*

**Line shapes.** Every line is a keyword line, like M1-3's declarations, or a connection
line, which starts with a qualified name. Indentation is cosmetic.

| logex line | IEC | Notes |
|---|---|---|
| `task <n> interval <ms> priority <p>` | `TASK n (INTERVAL := t#<ms>ms, PRIORITY := p)` | PRIORITY is mandatory in IEC's grammar: `'PRIORITY' ':=' integer ')'` (Ed 2 Annex B.1.7, p.158; Ed 3 Annex A, p.226). So logex requires it. 0 is the highest. *(Bounded 2026-10-02 by decision 37: 0 to 65535, IEC's UINT)* |
| `task <n> single <g> [interval <ms>] priority <p>` | `TASK n (SINGLE := g, …)` | With both inputs, rule 2 applies: periodic only while SINGLE is 0, plus a run on each edge |
| `var_global <n> <type> [<initial>]` | `VAR_GLOBAL n : TYPE := init;` | Table 49 f2 |
| `var_global <n> <type> at <dev>.i.<k>` or `… at <dev>.q.<k>` | `VAR_GLOBAL n AT %I… : TYPE;` or `AT %Q…` | An input or output point: a symbolic global given a location with `AT` (§2.4.3.1), with a logex location (§4.5) |
| `program <inst> <type> [with <task>]` | `PROGRAM inst WITH task : type` | Instance, then type, then task: the type is always the third word. IEC's order reads badly once `:` is dropped |
| `<inst>.<var_input> <global or constant>` | `inst(var_input := source)` | Copied in before each scan. IEC allows a constant source (`prog_data_source ::= constant \| …`, B.1.7, p.158). `m2.reset 0` is a tie-off |
| `<inst>.<var_output> <global>` | `inst(var_output => sink)` | Copied out after each scan. One line per sink |

**Connections carry no arrow.** The member's declaration already fixes the direction, and
IEC permits `:=` only on an input and `=>` only on an output. The point's `i` or `q` fixes
it too. A wrong direction is a diagnostic that names the member's section. Each connection
is a self-contained line with a qualified name, like VAR_CONFIG's full-path form, so there
is no block to close. (M1-3 rejected `end_var` blocks for the same reason.) IEC's `:=` and
`=>` were the fallback (decision 5).

**Checks.** All are decided. Each is marked as IEC's or logex's. *(Milestone 2's design
lands every check M2-1's data can express with M2-1, pinned from data, and M2-2 asserts
each again from source; §4.10.)*

- **Input points.** An input point takes no initial value. Nothing may drive it: no output
  connection, and no write through a `var_external`. *(logex)*
- **One driver per sink.** A global or output point has at most one connection driving
  it. That is an error, because it is static and checkable. Two instances that write one
  global through `var_external` are only visible in the IR: that is a warning, in M1-5's
  `warnings:` channel. *(logex. IEC forbids neither.)* *(Milestone 2's design carries
  this warning on the configuration's own `warnings`, `%Logex.Configuration{}.warnings`:
  a program's `warnings` sees one program, never two instances. §4.10, M2-4.)* *(Landed
  with M2-4, in decision 48's words, beside the warning for an instance that writes
  through `var_external` a global a connection drives.)*
- **Every var_input is connected**, to a global, a point or a constant. *(logex. No IEC
  rule on an unconnected program input was found.)* M1-3 gives a var_input no initial
  value, so an unconnected one would read 0 forever. *(Milestone 2's design pass found one,
  by inference from two clauses: a program's declaration and usage are a function
  block's (Ed 2 §2.5.3, p.83), and an unconnected function block input keeps its
  initialised value (Ed 2 §2.5.2, p.67). For logex's var_input, which has no initial
  value, that is 0 forever, this rule's reason, so the rule stands.)*
- **Types agree at both ends.** *(IEC for EXTERNAL/GLOBAL, Ed 2 §2.4.3; logex for
  connections)*
- **Only a var_input or var_output connects.** A `var` stays internal. *(logex)*
- **Unknown names.** An unknown task, program type, instance or member is a located
  diagnostic with a did-you-mean.
- **Tasks.** A task needs `interval` or `single`, and `interval` is at least 1. IEC reads
  INTERVAL 0 as "no periodic scheduling" (rule 2). MatIEC runs such a task every tick, so
  logex refuses the ambiguous case. *(Milestone 2's design bounds an interval at
  2147483647 ms, §4.10, and a priority at 65535, decision 37.)* *(Landed with M2-3 and
  M2-6: a task with neither is offered both, an event task's interval of 0 is told
  to leave it out, and a task with no priority is shown one of its own kind.)*
- **Events.** A `single` source must be a bool global. *(logex restriction. IEC's
  `data_source` also takes a constant, a program output or a direct variable, B.1.7,
  p.158.)* *(Landed with M2-6: a dint, another kind of name or no global is a diagnostic
  at the task's line, a name with `.` parts is told its reading, as a connection's global
  is, and a single is a use of its global.)*

A receipt: seven of the configuration spike's thirteen diagnostics for one deliberately
broken source, each line exact, pinned by no test. *(Milestone 2's design rewords four of
them: a line-shape mistake gains its column, and an em dash where it had `--`, as the
`.ld` compiler's did-you-means have; a did-you-mean where a name is near; the member's
section named; and no "declare it first", since names resolve over the whole file. The
words that land are the ones M2-2's tests pin, §4.10.)*

```
line 7: unknown configuration line `progam` -- did you mean `program`?
line 9: no task `medium`: declare it first, as `task medium interval <ms> priority <n>`
line 11: `m1` is a `motor`, which declares no `strat`
line 12: `pb` is an input point (line 2): `m1.motor` cannot drive it
line 14: `k` is already driven by `m1.run_lamp` (line 13)
line 15: `m1.fault` is internal to `motor` (declared `var`): only a var_input or var_output connects
line 16: `m1.speed_sp` is a dint, but `k` is a bool (line 3)
```

*(Landed with M2-2 and M2-3, 2026-10-11: the broken source, written out in
`configuration_test.exs`, gives exactly seven diagnostics, one on each of those lines, and
the test pins them word for word, each at `:configure`:)*

```
line 7, column 1: unknown configuration line `progam` — did you mean `program`?
line 9: no task `medium`: declare it with a `task` line, as in `task medium interval 10 priority 1`
line 11: `m1` is a `motor`, which declares no `strat` — did you mean `start`?
line 12: `pb` is an input point (line 2): `m1.motor`, a var_output, cannot drive it
line 14: `k` is already driven by `m1.run_lamp` (line 13)
line 15: `m1.fault` is internal to `motor` (declared `var`): only a var_input or var_output connects
line 16: `m1.speed_sp` is a dint, but `k` is a bool (line 3)
```

**Globals shared by name.** `var_external estop bool` in `motor.ld` binds to the
configuration's `var_global estop bool` (Ed 2 §2.4.3). During a scan it reads and writes
the global directly. Use it for what every instance shares, such as an e-stop. Per-instance
wiring stays a connection. A program that writes a `var_external` bound to an input point
is an error, so `%Logex.Program{}` records which tags it writes. M1-3's lowering already
knows each operand's write access. *(Milestone 2's design: which tags a program writes
is a public function over its IR, B5's one walk, not a field of `%Logex.Program{}`; §4.10,
M2-4.)* *(Landed with M2-4, 2026-10-12: `Logex.Walk.writes/1`, which
`Logex.Configuration.check/1` reads once a program type, at its first instance's line,
naming the type's file and the line of its first write; and `Logex.Runtime.get/2` reads
`m1.estop` as the global.)*

**Loading.**
- `Logex.Configuration.compile(name, source, %{"motor" => program, …})` is the pure seam:
  compiled types in, `{:ok, config}` or `{:error, [%Logex.Diagnostic{}]}` out, and the
  core does no file I/O.
- A convenience loader resolves `motor` to `motor.ld` beside the `.logex`. *(Milestone
  2's design: through the one loader M2-5 lands for function blocks, decision 34, with one
  memo for the whole configuration. M2-5 landed it on 2026-10-04, inside
  `Logex.compile_file/1`, one memo a call. M2-2 landed the configuration's on 2026-10-11,
  `Logex.Configuration.compile_file/1`, through `Logex.compile_files/1`, that loader over
  several files with one memo.)*
- A constructor built from Elixir data runs the same checks, as `Tag.new!/4` does for
  M1-3. *(Milestone 2's design: `Logex.Configuration.new!/1` raises every problem at once,
  a line each, where `Tag.new!/4` raises the first; §4.10, M2-1.)*

**Instance-specific initial values** (`var_config m2.speed_sp 900`) are target, not
scheduled. IEC: *"Instance specific initial values provided by the VAR_CONFIG...END_VAR
construction always override type specific initial values"* (Ed 2 §2.7.1, p.111). IEC
excludes VAR_TEMP, VAR_EXTERNAL, VAR CONSTANT and VAR_IN_OUT (same page). Refusing it on a
var_input is logex's rule, from M1-3. Leaving out the resource name follows IEC's prose
(*"beginning with the name of the resource (if any)"*). The B.1.7 production
`instance_specific_init ::= resource_name '.' program_name …` (p.158) does not make the
resource name optional, so IEC contradicts itself here.

### 4.5 I/O mapping

IEC has three ways to bind a program to physical I/O. logex adopts one:

| IEC mechanism | Example | logex |
|---|---|---|
| 1. A direct variable connected to a program input or output (Table 49 8a/9a) | `OFF_PB := %I0.0`, `CONTROL_LAMP => %Q4.0` (Ed 2 Annex F.7, Figure F.8, p.202) | **Not adopted.** A raw address in a connection gives the plant no I/O list, and each address would be spelled once per use |
| 2. A global given a location: a symbolic variable located with `AT`, allowed *"in programs and VAR_GLOBAL declarations only"* (§2.4.3.1, p.41), or a directly represented variable declared in VAR_GLOBAL (Table 49 f7). It is connected by 8b/9b or read through VAR_EXTERNAL | `AT %QW5 : INT` inside a VAR_GLOBAL (Figure 20, p.113) | **Adopted.** `var_global k1 bool at panel.q.0`. It is declared once and named, so the `var_global … at` lines are the plant's I/O list. The conventional family's alias tag has the same shape |
| 3. `AT %I*` in a program type, completed per instance by VAR_CONFIG | Ed 2 §2.4.1.1, p.36 | **Not adopted.** It puts a location in the type, which Ed 3 gives as the reason to deprecate addresses in POU bodies: they limit *"the reusability of these program organization unit types"* (§6.5.5.1, p.54). Connections already do the per-instance binding |

**The location `panel.q.0` keeps IEC's structure with a symbolic root.**
- `i` and `q` are Table 15's location prefixes (Ed 2 p.37), lowercased.
- The integer fields are IEC's hierarchical address, *"with the leftmost field
  representing the highest level of the hierarchy"* (§2.4.1.1, p.37).
- There is no size prefix (X/B/W/D). The declared type carries the size, and logex has no
  BYTE or WORD.
- It lexes as one `name` under PLAN §5's settled `.` rule, so no `%` token and no new AST
  leaf are needed.

The device root `panel` is a logex coinage where IEC has a standard form, `%`. That
strains naming rule 3, and the `at` stanza must argue it plainly. The fallback is `at
%ix0.0`, accepted only after `at` in a configuration (decision 6). It needs a `%`
lexeme, because today's lexer rejects `%` as an illegal character.

**What a device means is the host's job, as IEC leaves it to the manufacturer** (§2.4.1.1,
p.37).
- The pure core never touches a device. It takes an input map keyed by input-point name and
  returns an output map keyed by output-point name.
- Outside the core, a runner uses each point's `at` to route values to adapters.
- The adapter contract is OpenPLC v3's hardware layer: `initializeHardware`,
  `updateBuffersIn` and `updateBuffersOut` around `config_run__` (`webserver/core/ladder.h`,
  `main.cpp`):

```elixir
defmodule Logex.IO do          # used by the runner, never by Logex.Runtime
  @callback init(device :: String.t(), points :: [map], opts :: keyword) :: {:ok, term} | {:error, String.t()}
  @callback read(state :: term) :: {%{address :: term => integer}, term}
  @callback write(%{address :: term => integer}, state :: term) :: term
end
```

The host binds devices by name when it starts the runner, for example
`io: %{"panel" => Logex.IO.Sim, "drive" => {MyModbus, host: "10.0.0.5"}}`. Options such as
IP addresses stay in Elixir, where they can be written. An unbound device, or a bound
device with no points, is an error at start. This keeps the core deterministic. The
configuration spike called adapters from inside its tick, which is pure only for a
simulated device. *(Decided 2026-10-17 by Milestone 4's design, §4.11: every callback
gives `{:error, reason, state}` rather than raising, a point is a `%Logex.IO.Point{}` with
its name and type, an optional `report/2` passes a device's changes on as they come
(decisions 112 and 120), and an optional `close/1` is called once after the last write of
zeros; each device runs in a process of its own, and the two binding mistakes above are
the host's, raised at start. Added on 2026-10-18, after M4-1's review: an optional
`check/3` checks an adapter's own options in the host's process at start, so that a typo
in them is the host's mistake there too, and `Logex.IO.Sim`'s holds it to its sim,
`{Logex.IO.Sim, sim: panel}`, so the bare `Logex.IO.Sim` above is refused.)*
*(Landed with Milestone 4, M4-1 to M4-6, by 2026-10-20, as §4.11's "The adapter
behaviour" gives it: the sketch's `init/3` gives `{:ok, state}` or `{:error, reason}`, any
term; `read/1` gives `{:ok, values, state}`, some or all of the device's input points by
address, and `write/2`, given every output point by address, `{:ok, state}`; each fails as
`{:error, reason, state}`, never by raising; `report/2`, `close/1` and `check/3` are
optional. The host binds `%{device => module | {module, options}}`, checked by
`Logex.IO.bind!/2` in the host's process, every mistake a line of one `ArgumentError`,
an unbound device and a bound device with no points among them, so the binding above is
the landed form but for the bare `Logex.IO.Sim`. Each device runs in a process of its own
under the runner, which calls `init/3` there and reads it once at start; reads it every
poll period on a grid from its opening, passing each change on to the runner; writes it
where a round changed its outputs, and again at every poll, its last outputs, while its
last refresh's deadline has not passed (decision 130 as amended); at a trip writes it 0
once and latches it, open for `restart/2`'s release; and at a stop or the runner's death
writes it 0 once and closes it. A callback that gives an error,
raises, throws, exits, gives a result of no shape or a value that does not fit, or does
not answer in time, trips the runner, `{:io, device, cause}` (decision 114); a restart
reads every device again before its first round (decision 142); and a change refused for
one bad point keeps its other points (decision 143). The one adapter logex ships is
`Logex.IO.Sim`, the fixture of every runner test; an adapter for a card or a fieldbus,
such as the `MyModbus` above, is the host's.)*

### 4.6 Execution model

A resource is one value, `%Logex.Runtime{}`. Its clock is an integer `now` in
milliseconds, and nothing inside it reads a clock. **One cycle** is one call:

```elixir
Logex.Runtime.cycle(rt, elapsed_ms, inputs) :: {rt, outputs, events}
```

(IEC has no word for this unit. Here a *scan* is one execution of one instance, and a
*cycle* is one step of the resource.)

**Each cycle, in order:**

1. **Time.** `now` advances by `elapsed_ms`, which must be non-negative. The host injects
   elapsed time, as PLAN M1-6 says, and the runtime keeps the absolute `now`.
2. **Input image.** `inputs` is merged into a persistent image, so a host may send only
   what changed. Every scan in the cycle sees the same sample. An undeclared name raises:
   it is a host bug, not a PLC event. This is OpenPLC v3's cycle, `updateBuffersIn(); //read
   input image` … `config_run__(__tick++)` … `updateBuffersOut(); //write output image`
   (`main.cpp`), with the sleep removed. IEC says nothing about an image.
3. **Due tasks,** worked out once per cycle:
   - **Periodic.** Each task keeps a `next_due`, anchored at start. Every periodic task is
     due in the first cycle. After a run, `next_due` advances by whole intervals, so the
     phase never drifts. That is rule 2's *"periodically at the specified interval"*.
     *(An interval OE-2 changes moves `next_due` to `min(next_due, now + new interval)`,
     decision 40. Where the new interval brings `next_due` forward, the phase is then the
     switch's; otherwise the runs step by the new interval from the kept `next_due`.)*
   - **Event.** `single` is sampled once per cycle, and a 0→1 change since the last cycle
     makes the task due. *(Its due time, for the tie-break in step 4, is the cycle's
     `now`; with `interval` too, decision 39 applies. §4.10, M2-6.)*
     - A trigger that is already 1 in the first cycle counts as an edge. That is
       **MatIEC's reading, adopted by logex**: MatIEC puts a `static R_TRIG` on the SINGLE
       variable (`generate_c.cc`, `task_initialization_c` visitor). IEC's R_TRIG NOTE says
       the same of the R_TRIG block (*"its Q output will stand at BOOL#1 after its first
       execution following a “cold restart”"*, Ed 2 §2.5.2.3.2, p.78), but rule 1 itself is
       silent. This is the opposite of `ons`'s first-scan suppression, which logex keeps
       for `ons`.
     - A 1→0→1 pulse inside one host step cannot be seen. A trigger written by logic takes
       effect in the next cycle.
     - *(Landed with M2-6, 2026-10-12, as these rules, decision 39 and decisions 50 to 52
       say: each trigger sampled once, after the input merge and before any scan; the last
       sample 0 at `start/1` and by `restart/2`; `next_due_in/1` counting periodic due
       times only.)*
4. **Order and scans.** Due tasks run by priority, 0 first, then the earlier due time, then
   declaration order:
   - the due-time step is rule 3a, *"the program organization unit with the longest waiting
     time at the highest scheduled priority shall be executed"* (Ed 2 §2.7.2, p.115);
   - within a task, instances run in declaration order. IEC is silent; the conventional
     family does the same (*"The programs are executed in the order they are specified."*,
     import/export ref., p.315);
   - task-less instances run last, once each.

   Each scan copies the connected var_inputs in, runs the rungs, and copies the var_outputs
   out. MatIEC generates exactly that around each program call: `:=` connections, then
   `<type>_body__`, then `=>` connections (`generate_c.cc`, the `program_configuration`
   visitor). *(M2-4, landed 2026-10-12: each `var_external`'s global is merged into the
   instance's state with the copy-in and split off after the rungs, back into the global,
   before the copy-out (decision 47), so a resource holds one copy of each global, which
   MatIEC reaches through a pointer, written during the body, before its `=>`.)*
5. **Output image.** The output map is returned once, after every due scan.

**There is no preemption.** A scan runs to completion in zero logical time. IEC permits
this: priority *"can be used for preemptive or non-preemptive scheduling"* (Ed 2 §2.7.2,
p.114). MatIEC parses PRIORITY but ignores it. logex honours it for same-cycle order.
`docs/naming.md` already omits the uninterruptible copy CPS because logex has *"nothing to
protect against"*. **Visibility follows from the order:** an instance sees any global that
an earlier instance wrote in the same cycle, and never one that a later instance writes.

**Missed periods are reported, not replayed.** Execution takes no logical time, so a missed
period shows up only as a cycle whose `elapsed` spans more than one interval. That happens
both when the host was late and when a real cycle ran long. The task:
- runs once;
- adds `missed = div(now - next_due, interval)` to its overlap count;
- emits `{:overlap, task, missed}`;
- moves `next_due` past `now` without losing phase.

This is §1.5.1 d) 4)'s report-and-continue, and it matches the conventional family's
overlap count. Catch-up (one run per missed period) would give bursty outputs and unbounded
work after any pause.

**The watchdog lives outside the core.** IEC defines none. A pure function cannot time
itself, so the watchdog belongs to the wall-clock runner, the only code that reads
`System.monotonic_time/1`. When backward `jmp` lands (PLAN §8 item 5), add a deterministic
budget in the core: rung evaluations per scan. *(Decided 2026-10-17, §4.11: each task has
its own watchdog, 500 ms unless its line sets one, the continuous task's per round
(decisions 109–111), timed by the runner at the boundaries of the cycle's steps (decision
118), and each device's heartbeat zeroes its outputs if the runner stops refreshing it
(decision 119), by the deadline its last refresh carried (decision 125); a trip stops the
plant with every output off once, confirming decision 14 (decision 113).)* *(Landed with
Milestone 4 by 2026-10-20: a task's `watchdog` and the continuous task with M4-2, read
through `Logex.Configuration.watchdog/1`; the runner, M4-3, reading time through
`Logex.Runner.Clock`, whose monotonic clock is the one place logex calls
`System.monotonic_time/1`, and a manual clock a test moves; and with M4-4 the trips, a
timed task's run longer than its watchdog `{:watchdog, {:task, task, took, limit}}`, a
round of the continuous task longer than its own `{:watchdog, {:round, task, took, limit,
steps}}` (decision 126), a host's request served whole longer than the runner's idle
watchdog `{:watchdog, {:idle, ms}}` (decision 128), and a device that heard nothing by
its deadline `{:watchdog, {:device, device, ms}}` (decision 137), each before the round's
write. `Logex.Runtime` still reads no clock. The deterministic budget waits on a backward
`jmp`, which has not landed: M3-5's jump goes forward only.)*

**Where timers get their time.** Every scan receives a read-only `%Logex.Scan{now:,
first:}`, and `evaluate/3` threads it. Each timer instance keeps its own last-scanned time
as an internal member. That member is not addressable, and it is not one of `.pre .acc .dn
.tt .en`. `ton` adds `now − last_scanned` to `.acc` while its rung is true. This is the
conventional formula `docs/naming.md` settled: its Timers table gives
`ACC = ACC + (current_time − last_time_scanned)` and calls that delta formula, *"with `now`
supplied by the caller"*, *"the only version that is a pure function of its inputs"*. MatIEC's TON behaves the same
way: its `START_TIME := CURRENT_TIME` is absolute (`lib/timer.txt`, `TON`).

*As landed (M1-6):* the formula counts only from the scan that first sees the rung true.
Its last-scanned time is `last`, the time the `ton` last ran, set on every run, energised
or not, as `PLAN.md` M1-6's decision 5 words it. Energised, `ton` adds `now − last` where
its `.en` was already 1, and nothing on the scan that starts it, which is where MatIEC's
TON takes `START_TIME` on IN's rising edge. Without that edge, read from `.en`, the formula
would charge a timer for the scan before its rung went true, and decision 6's two-rate
test tells the readings apart: 6000 ms at both rates as landed, against 5990 and 5950 ms
(both measured). Do not "fix" this back to the literal formula. `.acc` is floored at 0
before the time is added, so a negative `.acc` written by logic counts from 0, and capped
at max(`.pre`, 0), so no gap takes it out of a dint; `.pre` starts at the preset on the
`ton`, which the instruction never rewrites. These hold right after the `ton` runs: a
member written on a rung below it takes effect at the next scan, and a host reading
`state.env` in between can see `.acc` past `.pre`. Nothing may follow a `ton` on its path
(§4.3).

**Why not a per-instance `dt`?** A `dt` (time since the instance's last scan) equals the
per-timer formula only when the timer runs on every scan of its instance. A `ton` inside a
frozen `cal` (§4.3), or one a future `jmp` skips, loses the gap; both precedents catch it
up. Function blocks arrive in Milestone 2, so this cannot wait for `jmp`. This departs from
one reviewer, who preferred `dt` because it keeps a timer to its five public members; the
internal member costs one schema entry. Either way the increment is the actual time, not
the nominal interval: a 10 ms task stepped at 25 ms must still reach its preset on time.

**First scan.** M1-3's `initial_env/1` puts every declared tag at its initial value.
Extended to a timer, it clears `.acc`, `.dn`, `.tt` and `.en`, which is what the
conventional TON prescan does (general instructions ref., TON, p.134), and starts `.pre`
at the preset on the timer's `ton` (M1-6). `scan.first`
gives `ons` its settled behaviour, *"The storage
bit is set to true to prevent an invalid trigger during the first scan"* (general
instructions ref., ONS, p.73). `first` is per instance.

**Caveats to document.**
- A `ton` in an event-task program times across events. It should be an M1-5 warning.
  *(M1-5 had neither a `ton` nor an event task to warn about. `ton` landed with M1-6; the
  warning waits for event tasks, M2-6.)* *(Milestone 2's design carries it on the
  configuration's `warnings`, not a program's, since only the configuration knows which
  task runs an instance; §4.10, M2-6.)* *(Landed with M2-6: one for each timer of each
  instance an event task runs, a block's by its path, at the instance's line, citing the
  `ton` in its own text, a block's read from no file by the block's name.)*
- A `now` that goes backwards is an error, never a negative `.acc`. *(Landed with M1-5:
  `Logex.Runtime.call/4` raises `ArgumentError` for a `%Scan{}` earlier than the
  instance's clock, and `scan/3` for a negative elapsed time.)*

**Deviations from IEC task semantics, labelled.**

| IEC | logex | Why |
|---|---|---|
| A task-less program is re-scheduled *"as soon as its execution terminates"* (rule 4) | once per cycle | In zero logical time, rule 4 is an infinite loop. The runner paces cycles. MatIEC also runs unbound instances once per tick. *(Decided 2026-10-17 by decision 108: on the clock the runner makes rounds back to back while task-less programs exist, a share kept for its own work, so rule 4 holds there, to the clock's millisecond, one round a millisecond at most, decision 122; a cycle still runs each once.)* |
| SINGLE and INTERVAL take any `data_source` (B.1.7) | SINGLE is a bool global. INTERVAL is an integer constant in ms | Simplest checkable form. It can widen later without breaking anything |
| Execution takes time, and preemption is allowed | zero-time, non-preemptive scans | Determinism. The Table 50 timelines therefore cannot be reproduced |
| Instance order within a task is not specified | declaration order | the conventional family's rule, quoted above |
| A missed deadline is an error (§2.7.2) | reported as `{:overlap, …}` and counted | §1.5.1 d) 4) |

**The API** (M1-5, then M2-1):

```elixir
Logex.Runtime.instance(program) :: state                                         # a %Logex.Instance{}, at its first scan
Logex.Runtime.call(program, state, inputs, %Logex.Scan{}) :: {outputs, state}   # one scan: copy in, run, copy out
Logex.Runtime.put_inputs(program, state, inputs) :: state                        # the sugar's input image
Logex.Runtime.scan(program, state) / scan(program, state, elapsed_ms)            # sugar: the implicit configuration
Logex.Runtime.restart(program, state, :cold | :warm) :: state                    # keeps the var_inputs and the clock
Logex.Runtime.start(config) :: rt
Logex.Runtime.cycle(rt, elapsed_ms, inputs) :: {rt, outputs, [event]}
Logex.Runtime.next_due_in(rt) :: non_neg_integer | :infinity                    # what the runner sleeps on
Logex.Runtime.get(rt, "m1.t1.acc")                                               # an access path, resource omitted
# event :: {:ran, task | :none, instance, now} | {:overlap, task, missed}
```

*(Milestone 2's design adds two functions to this block, by decision 38:
`Logex.Runtime.restart(rt, :cold | :warm) :: rt`, which restarts every instance through
`restart/3` and keeps the clock and the input image, and `Logex.Runtime.overlaps(rt) ::
%{task => non_neg_integer}`. Decision 37 bounds a task's priority at 0 to 65535.)*
*(Landed with M2-1 on 2026-10-02: `start/1`, `cycle/3`, `next_due_in/1`, `get/2`,
`restart/2` and `overlaps/1`, the configuration built with `Logex.Configuration.new!/1`.
`get/2` returns the value at the path, and raises `ArgumentError` for a path that names
no global, tag or public member, as every host mistake does.)* *(Changed 2026-10-04 by
decision 41: `get/2` gives `{:ok, value}` or `{:error, reason}`, and `get!/2` gives the
value or raises `ArgumentError` with that reason.)* *(Changed 2026-10-14 by decision 99,
M3-3: an event `{:fault, task | :none, instance, %Logex.Fault{}}` follows its scan's
`{:ran, ...}` for each minor fault the scan met, a zero divisor, and a lone instance's
state keeps its last scan's in `state.faults`.)*

`scan/2` and a one-line configuration must give identical outputs for the README program.
A test pins that, or the two runtimes drift apart. PLAN M1-5 defines `scan/3` as "n
scans"; the elapsed-time `scan/3` above replaces that meaning, and M1-5 must say so.
*(It did, and the first five lines landed with M1-5 on 2026-09-29, `scan/2` returning
`{outputs, state}` like `call/4`. `restart/3` keeps the var_inputs because they are the
host's input image, which a configuration's copy-in refreshes every scan anyway: that is
what keeps `scan/2` and the one-line configuration in agreement across a restart. Since
M1-6 it keeps only those whose values fit their types, which a recompile of the same name
may have changed.)* *(Since M2-4 a program with a `var_external` agrees too, given for each
an unlocated global of no initial value that no other instance uses: run alone, the
program keeps it as its own tag at 0, which its host cannot set and `restart/3` puts back
at 0. `scheduler_test.exs` pins the agreement over 400 seeded steps.)*

**Receipt.** The configuration spike ran an earlier form of the §4.4 plant: the §4.2
`motor`, no event task, no `estop` and no snapshot, and `m2.reset` wired to `pb_reset`
rather than tied to 0. It stepped every 10 ms on a GCD tick, which gives the same schedule
as the rules above at that step. This is its exact output (`t` is the time of the last cycle
run):

```
t=  0  idle                  k1=0 k2=0 sp_1=1200 sp_2=1200  m1.fault=0
t= 10  both starts pressed   k1=1 k2=0 sp_1=1200 sp_2=1200  m1.fault=0
t= 50  held 40 ms more       k1=1 k2=1 sp_1=1200 sp_2=1200  m1.fault=0
t=100  both released         k1=1 k2=1 sp_1=1200 sp_2=1200  m1.fault=0
t=110  tt_1 trips            k1=1 k2=1 sp_1=0 sp_2=1200  m1.fault=1
t=120  stop_1 pressed        k1=0 k2=1 sp_1=0 sp_2=1200  m1.fault=1
```

What it shows:
- At t=10 only `m1` has run. `m2`, on the 50 ms task, picks up its button at t=50.
- `m1`'s latched fault drops `sp_1` and leaves `m2` alone.

**Receipt: a real `ton` under two rates (M1-6).** One program type, `xic go ton t1 5000`,
two instances stepped through `call/4` every 10 ms and every 50 ms from one clock, `go`
rising at 1000 ms: both are done at 6000 ms with `.acc` 5000, and their outputs agree at
every time both scan; a third instance stepped at irregular times is not done at 5999 ms
and is at 6000 ms (`end_to_end_test.exs`, "decision 6"). The equality holds per rising
edge, when both instances see that edge at one time and the preset is a multiple of both
periods: with a 1030 ms preset they are done at 1030 and 1050 ms, `.acc` 1030 in both. A
timer that re-triggers itself, `xio t1.dn ton t1 1000`, is reset by the scan after it is
done and starts again on the scan after that, so it repeats every preset plus two task
periods, at 1020 ms steps on 10 ms scans and 1100 ms steps on 50 ms scans, as MatIEC's
TON does; per-edge equality does not make its rate independent of the task. So the model
is settled as §6.1 asked, and M2-3's acceptance should say how its inputs are timed.

### 4.7 One `.` token, three readings

PLAN §5's `QUALIFIED = {NAME}(\.({NAME}|{INT}))*` gives one lexer token. Position decides
what it means, and each wrong reading gets a diagnostic that names it:

| Reading | Where it is legal | Example |
|---|---|---|
| member of an instance or bit of a word | a `.ld` body | `t1.acc`, `s1.run`, `word.3` (a timer's members landed with M1-6, a function block's with M2-5; a bit is refused until bit access lands) |
| instance path | a `.logex` connection line; `Runtime.get/2` | `m1.start`, `m1.t1.acc`, `m1.s2.run` |
| location | only after `at` in a `.logex` | `panel.i.0` |

A dotted name in a body that is not a declared member, such as `m2.fault` inside
`motor.ld`, is a located diagnostic, never a reach into another instance. PLAN §5 already
warns that `.` in the lexer is safe only while there are no float literals. *(Decided
2026-10-21 for Milestone 5, §4.12: a bit is `word.3` or `word.[n]`, on every integer and
bit string, and an element `temps[3]` or `grid[1,7]`, each one token; a real literal has
digits before its `.`, and a name never does, so the two never meet; and `word` itself
becomes a type word, reserved.)*

### 4.8 Reserved words, by file kind

| File kind | Reserved (in any case) |
|---|---|
| `.ld` program | the mnemonics (`cal` and `ton` among them); `var var_input var_output bool dint` (M1-3); `var_external` (M2-4, landed) |
| `.ld` function block | as a program, plus `function_block` (M2-5, landed) |
| configuration (`.logex`) | `task interval single priority program with var_global at bool dint`; later `var_config` |

A `var_external` name must be legal in both kinds, because it is declared again as a
`var_global`. *(Landed with M2-4: `Logex.Declarations` refuses a configuration file's
keyword, `Logex.Configuration.Text.keywords/0` as M2-3 left it, as a `var_external`'s
name, in any case; M2-6's `single` joins the list when it lands.)* *(Landed with M2-6,
2026-10-12: `single` is a configuration file's word, and a `var_external` named `single`
is refused, in any case.)*

**This departs from IEC and from one reviewer**, who argued for reserving the Table C.2
words (`task program with at` …) everywhere, as IEC does (§2.1.3). logex reserves a word
for a different reason: to keep a line's reading unambiguous, as when `move src ote` must
not write a tag called `ote` (`PLAN.md` §5). That is a per-file-kind question. A program tag
named `task` or `with` appears in a `.logex` only inside the qualified token `m1.task`.
Scoping by file kind breaks the fewest programs, and every keyword is still reserved in the
file kind that uses it. It also sidesteps an IEC inconsistency: Ed 2 Table C.2
(pp.163–164) lists TASK, WITH, AT and PROGRAM...WITH... but not INTERVAL, SINGLE or
PRIORITY, although §2.1.3 defines keywords by Annex B, which quotes all three as terminals.
Ed 3 has no keyword table.

Before the reservation lands, none of the configuration words is used as a tag in a
golden-record source, a test or `lib/`; they occur there only as English, in comments and
test names. Each commit must still name the words it reserves and the tag
names they break (CLAUDE.md step 2).

**`var_external` is refused in a function block's file** (Milestone 2's design, §4.10,
M2-4). This departs from IEC, which allows it: Ed 2 Table 33 lists *"VAR_EXTERNAL
declarations within function block type declarations"* (features 10a and 10b), and the
grammars of both editions allow it in a function block. The departure is deliberate and
reversible. A block's body runs over its own instance's state, which holds no global, so
a block takes a global through a var_input operand instead. Binding it through the
program instance that holds the block would need a write path out of a body. *(Landed with
M2-4: a located diagnostic at its line, made before the block's type is built, and an
`ArgumentError` for one declared from Elixir.)*

### 4.9 Changing a running controller (online edit)

**Decided 2026-10-01** (§7, decisions 15–20); **OE-1's design, the edit of one program
instance, recorded the same day** ("OE-1's design" below; decisions 21–29), **and landed
the same day as `Logex.Edit`** (`PLAN.md` OE-1); **OE-2's design, the edit of a running
configuration, designed and decided 2026-10-13** ("OE-2's design" below; decisions 55–65),
and not yet landed (`PLAN.md` OE-2). The brief:
*"I would like to be able to modify the whole controller/configuration at runtime like in
[the conventional family], and I don't necessarily want to have to run that through an
Elixir compiler first."*

**One model, held as data.** A running controller holds values: a `%Logex.Program{}` per
program type and, from M2-1, one `%Logex.Configuration{}`. Their saved form is text,
`.ld` and `.logex`, which printers write. Every way of writing a controller (the text, a
plain-Elixir data API, any later macro) ends in the one validator and produces the same
values, and the data API refuses anything the text cannot say. When this was decided, the
data path still took two such things: a negative literal, which does not lex yet, and a
timer preset given only from Elixir (`Logex.Tag.new!/4` with `%{"pre" => ms}`). OE-1
refuses both, and every parse tree that `Logex.Parser.parse/1` could not have produced
(decisions 24 and 28; "The data path" below).

**No Elixir compiler on the edit path.** Nothing compiles a user's program to BEAM
(`PLAN.md` §6). Measured on 1.20.4 on 2026-10-01: `Logex.compile/2` takes about 45 µs for
the README motor and 31 ms for 2,000 rungs, and a tracer counted no call into the Elixir
compiler, from text or from a program built as data. Recompiling a Spark-defined
module through `Code.compile_string/2` took 74–95 ms for a 4-tag program and 0.5–0.7 s
for a 200-tag one, against 22 µs and 1.7 ms for `Logex.compile/2` on the same two
programs; it ran arbitrary code written in the edit; and an edit that failed validation
unloaded the module that was running, because Elixir purges a module whose compilation
raises. Spark is not adopted inside logex. An Elixir authoring package outside it may
come later, as a one-way seed that emits the same data (`PLAN.md` B9).

**The edit cycle is staged, as the conventional family's is.**
1. *Accept.* A candidate, the whole program (from M2, the whole configuration), is
   compiled and checked beside the running one. It does not run, and a candidate with an
   error goes no further; a warning does not stop it. *(Changed 2026-10-02 by Milestone
   2's design, §4.10: a configured plant is not edited until OE-2, which comes after
   Milestone 2, so the whole configuration is a candidate from OE-2.)* *(Designed
   2026-10-13, "OE-2's design" below: a `%Logex.Configuration{}`, accepted against the
   resource that runs the original.)*
2. *Test.* The candidate runs and the original is kept. The state is shared, moved to the
   candidate's shape by the rules below, and nothing is pruned.
3. *Untest.* The original runs again over the same state, moved back. Test and untest may
   repeat.
4. *Assemble.* The original is dropped, and state the candidate no longer declares is
   pruned.
5. *Cancel.* The candidate is dropped, from accept or after an untest.

Every switch happens between two scans, and from M2-1 between two cycles. *(Changed
2026-10-02 by Milestone 2's design, §4.10: a configured plant is not edited until OE-2, so
a switch between two cycles is OE-2's.)* *(OE-2's design below takes every step between
two cycles.)* The conventional family's documents do not say
whether its switch is atomic at a scan boundary; Beremiz states that its hot swap happens
"between two cycles, never inside one". Each step returns a report.

**State moves by name.** The defaults:

| Change | At test, and in reverse at untest | At assemble |
|---|---|---|
| Same name and type | kept | kept |
| An added tag | its declared initial value | — |
| A removed tag | kept, unused | pruned |
| A tag's or member's type | refused: the candidate is not accepted, and a restart re-initialises it, but keeps a var_input whose value fits its new type | — |
| A timer's preset | `.pre` follows the new preset where it still equals the old one, and is kept where logic changed it | — |
| A one-shot | an `ons` the edit adds does not fire at the switch | — |
| `now` and `first` | kept; `first` stays false, so no initialisation runs, as in CODESYS | — |

OE-1's design, below, gives the rules in full. It refines three of these rows: which
one-shots are blocked, a timer whose `ton` stops or returns, and a value a plain swap
left. It also adds three: a tag's section, a changed initial value, and the inputs a
switch makes live or leaves unread. *(Since M2-5, landed 2026-10-04, these rules hold
inside a function block instance too, member by member and by path, `s1.edge`
(decisions 31 and 32). A block's var_inputs are an exception to the inputs rule: its
`cal` copies them in, so a switch reports none of them as `:input` or `:unread`.)*

Left open for the design pass of `PLAN.md` OE-1, and settled by it:
- which `ons` storage bits are armed, and whether an existing `ons` whose condition the
  edit changes is armed too, at the cost of a genuine edge on the switch scan. A probe that
  armed only the storage tags an edit adds still pulsed for an `ons` added on an existing
  tag, and for one whose condition changed. **Settled (decision 21):** no bit is armed,
  because no switch writes a storage bit. An `ons` the edit adds, or whose rung changed
  (line numbers ignored), passes no power on the first scan after the switch, as every
  `ons` does on a first scan. An untouched `ons` keeps a genuine edge on that scan;
- a timer whose `ton` an edit removes and a later edit restores catches up the whole gap,
  because its `.en` and `last` froze. It must start timing at the edit instead.
  **Settled:** it resumes from the switch. Its `last` becomes the instance's `now`, and the
  gap is reported. Its `.pre` stays frozen while no `ton` runs it, and takes the new preset
  outright when one returns (decision 23);
- raising a done timer's preset drops `.dn` while its rung stays true, as raising `.pre`
  does from logic. The report must name it. **Settled:** it is reported as `:dn_drops`,
  and lowering a preset under a timing `.acc` is reported as `:dn_rises`. No latch is
  added;
- which steps depend on the live state, and so run when the step is taken, not when the
  candidate is accepted. **Settled:** test, untest, assemble and cancel each read the
  state when they are taken. Accept reads the two programs to build its plans, and reads
  the state only for a forecast, which is never applied (decision 27).

**An output that an edit leaves undriven holds its last value**, as the conventional
family's do: *"Outputs in the original logic stay in their last state unless executed by
the test edits (or other logic)"*, and the same on untest and on finalising (its quick
start, Oct 2009, pp.121 and 124). The report of every step lists each var_output, and
from M2-2 each output point, that no logic drives any more, with the value it holds.
*(Changed 2026-10-02 by Milestone 2's design, §4.10: a configured plant is not edited
until OE-2, so the output points are reported from OE-2, as "One rule for new state"
below says.)* *(OE-2's design below says which: each global the configuration stopped
drives and the one started does not, named beside the instance's own var_output, decision
58.)*

**Refused while running.** A restart, which may keep values by name, is the way to make
these changes:
- the type of a tag or a member;
- located I/O and devices: CODESYS, Siemens and Beremiz refuse a device change while
  running, the conventional family allows some within limits, and logex binds devices
  only at start (§4.5);
- moving a program instance to another task, which the conventional family refuses in Run
  mode; and adding or removing a task, until its rule for that is verified (§8); *(OE-2's
  design below keeps both refusals, and lets a retyped instance, a new one under an old
  name, run on another task, decision 61)*
- the members of a function block type, until M2-5 brings the nested migration: copy the
  members that match by name and type, as CODESYS does, and initialise the rest. *(Changed
  2026-10-02 by decision 31: M2-5 brings the migration, and a member whose type changes
  is refused, as a tag's is, not initialised. The members that match by name and type
  are copied, by path; a member added starts at its initial value. That copy is what
  Beremiz's hot swap states; the CODESYS help pages read do not say it. Landed with M2-5,
  2026-10-04, for the edit of one program instance.)*

Allowed while running: rungs; adding and removing tags, instances, globals and
connections; a tag's section, its value kept (decision 25); and a task's interval and
priority, which the conventional family lets logic write while it runs. *(OE-2's design
below adds the order of tasks and of instances, reported, decision 62.)* *(A changed
interval makes the task next due at `min(next_due, now + new interval)`: decision 40.
From M2-5, a function block's body and members, by decision 31, which landed with it on
2026-10-04.)*

**What Milestone 2 must keep, so that this needs no rework** (`PLAN.md` M2-1). *(Checked
against M2-1 as it landed, 2026-10-02: each item it can meet, it meets, as marked.)*
- the runtime value holds plain data only: no funs, pids or refs; *(met: a
  `%Logex.Runtime{}` is plain data at `start/1`, after cycles and after `restart/2`,
  which `scheduler_test.exs` pins)*
- every piece of runtime state is keyed by name, never by position; program instances are
  held flat, keyed by instance name, never nested under a task; execution order is a list
  in the configuration; *(met: globals, instances and tasks are each a map by name, and a
  task's instances run in the order of the configuration's `instances` list)*
- each M2 item writes its rule for a new piece of state once, used by `start/1` and by an
  edit that adds one, with the edit's exceptions listed: `ons`, an event task's trigger and
  `first`; *(met for M2-1's pieces: `Logex.Configuration.initial/1` for a global and
  `Logex.Runtime`'s one-rule section for the clock, an instance and a task; an event
  task's trigger is M2-6's)* *(met for M2-6's: the trigger's last sample in the same
  section, 0 from `start/1` and `restart/2`, kept by OE-2's switch, which refuses a changed
  `single` or an added or removed `interval`)*
- one checked constructor, which the configuration file's reader feeds; *(met:
  `Logex.Configuration.check/1`, which `new!/1` and `start/1` run; M2-2's reader feeds
  it, through `compile/3`, since 2026-10-11)*
- `start/1` builds each instance through the same constructor as `Runtime.instance/1`,
  so an instance's `first`, its one-shot block list and any field it gains later cannot
  drift between the two (OE-1; fix F14 in §7); *(met)*
- `%Logex.Runtime{}` is opaque, and its configuration changes only through the API;
  *(met: its type is `@opaque`, and nothing in M2-1 changes its configuration, so a
  configured plant is not edited until OE-2)*
- one copy of each global's value; *(met for M2-1's globals, one value each in the
  resource; M2-4's `var_external` keeps it by merging the global in around each scan)*
  *(met since M2-4: no instance's state holds a var_external between cycles, which a test
  pins by looking inside the resource, decision 49)*
- the events `cycle/3` returns are an open set, which a host must tolerate. *(met:
  `Logex.Runtime`'s moduledoc says so)*

**OE-1's design: a staged edit of one program instance.** Designed on 2026-10-01 against
`730cb16`, and landed the same day as `PLAN.md` OE-1, in the eight commits after
`730cb16`, with a ninth for what the review of them confirmed (`PLAN.md` OE-1); what
follows is the edit as it landed and was fixed, and `Logex.Edit`'s moduledoc gives the
same rules. A spike on a copy of `730cb16` ran the Done-when end to end. Two reviews of
it, one for correctness and one for fit with this section and the host contract, and the
spike's own report gave sixteen fixes, listed in §7 as F1–F16; decisions 21–29 settle what
the pass left to the maintainer. *What it fixes:* with no edit, the Done-when's candidate
scanned over the kept state (a *plain swap*) pulses its new `ons`, which moves `speed_sp`
to 900; keeps `t1` at `pre 5000, dn 1`; and starts the added `t2` at `pre 0`, so `t2` is
done on its first true scan.

*The API.* One module, `Logex.Edit`. The host holds a `%Logex.Edit{}` beside the
instance; the struct is opaque and holds plain data only.

```elixir
Logex.Edit.accept(running, candidate, state) ::
  {:ok, edit, forecast} | {:error, [%Logex.Diagnostic{stage: :edit}]}
Logex.Edit.test(edit, state)     :: {edit, state, report}
Logex.Edit.untest(edit, state)   :: {edit, state, report}
Logex.Edit.assemble(edit, state) :: {candidate, state, report}  # the edit ends
Logex.Edit.cancel(edit, state)   :: {original, state, report}   # the edit ends
Logex.Edit.running(edit) :: %Logex.Program{}                    # what the host scans now
Logex.Edit.stage(edit)   :: :accepted | :testing | :untested
```

- **Accept** takes the state and returns a forecast: the report a test taken now would
  give. It applies nothing (decision 27). A test taken later reads the state as it is
  then, so it sees a `.pre` that logic wrote after accept.
- **`running/1`** is the candidate under test and the original otherwise. It is the
  program that goes to `call/4`, `scan/2,3`, `put_inputs/3` and `restart/3` until the edit
  ends. After that, they take the program that assemble or cancel returned.
- **A restart during an edit** is allowed, through `running/1`, and keeps the edit's
  stage. It drops what only the other program declares; the next switch starts that
  again and reports it as `:added`, or a var_input as `:input`.
- **One edit per instance.** At accept the edit builds two plans from the two programs
  alone, one per direction: original to candidate, and back. It also keeps a record of one
  instance's switches. A switch and a prune are separate functions of one plan, that
  record and one state, so OE-2 can build one plan per program type and call them once for
  each instance (fix F5). In OE-1 each instance takes its own edit. *(OE-2's design below
  moves the plans, the switch and the prune to an internal module, `Logex.Edit.Plan`,
  which both edits call.)* A report names a tag;
  from OE-2 it names an `instance.tag` path. *(Since M2-5 a member inside a function
  block instance is named by its path in the program instance, `{:added, "s1.edge", 0}`.)*

*The stages.* Every step is taken between two scans.

| Step | Taken from | The host then scans | The state |
|---|---|---|---|
| accept | — | the original | read for the forecast, unchanged |
| test | accepted, untested | the candidate | switched to the candidate's shape |
| untest | testing | the original | switched back |
| assemble | testing | the candidate; the edit ends | pruned to the candidate's tags |
| cancel | accepted | the original; the edit ends | unchanged; the report is `[]` |
| cancel | untested | the original; the edit ends | pruned to the original's tags |

To finalise without scanning the candidate, the host takes test and assemble at one
boundary.

*Refusals.*
- **A source mistake** comes back from accept as `{:error, diagnostics}`, at stage
  `:edit`. Every tag both programs declare whose type differs is refused: any `Tag.type`
  inequality, whether bool and dint, a tag and a timer, or one function block schema and
  another. *(Changed 2026-10-02 by decision 31: from M2-5 a user function block's type,
  for the edit, is its name and its members' kinds, so a changed body or an added or
  dropped member is no type change; a member whose kind changes is refused by its path. A
  timer's schema is compared as before. Landed with M2-5, a member cited by its path at
  the line of the instance that holds it, as `Logex.Edit`'s moduledoc says: with
  `var s1 seal` on line 10, ``line 10: `s1.edge` is a bool in the running program and a
  dint in the candidate: a member's type changes only with a restart``.)* Each is cited at
  the candidate's declaration line, in line order, a tag declared from Elixir (which has
  no line) last: ``line 7: `speed_sp` is a dint in the running program and a bool in the
  candidate: a tag's type changes only with a restart``. A section change is not a type
  change (decision 25), and neither is a changed initial value (decision 29). *(Decided
  2026-10-21 for Milestone 5, decision 157: the rule holds for every type, so a width,
  a real's width, a bit string, an array's element type, its dimensions and its sizes
  change only with a restart, `usint` to `uint` and `int[8]` to `int[10]` refused as
  bool to dint is; no type change is a widening the edit allows; and decision 159 keeps a
  `var_external` bound to a global of exactly its type.)* A warning in
  the candidate does not stop it. An `:edit` diagnostic carries no file, because a
  `%Logex.Program{}` keeps none: a candidate from `Logex.compile_file/1` is cited as
  `line 7: …` without its path. The gap is documented, and Milestone 2's configuration
  edit must close it (fix F15). *(Milestone 2's design gives fix F15 to M2-5, the first
  item that meets it: `%Logex.Program{}` gains a `file`, §4.10. Landed with M2-5: a
  candidate from `compile_file/1` carries its path as its `file`, and every `:edit`
  diagnostic carries the candidate's.)*
- **A host mistake** raises `ArgumentError`, and a test pins each message:
  - something other than a program, at accept: the runtime's own message;
  - a candidate with another name: ``the candidate is `pump`, but the running program is
    `motor`: an edit keeps the program's name``. Two unnamed programs count as one name;
  - something other than an edit: `expected a %Logex.Edit{} from Logex.Edit.accept/3,
    got: …`;
  - a state that is not the running program's: the runtime's own messages;
  - a step at the wrong stage: `test takes an edit accepted or untested, but this one is
    under test`, and likewise for the other steps;
  - an instance whose one-shot block list is not a proper list of storage bit names
    (fix F8), or whose `switched` is not `true` or `false`: the runtime's messages,
    `state.ons_blocked must be a list of storage bit names, got: …` and
    `state.switched must be true or false, got: …`;
  - a `%Logex.Scan{}` whose block list the host filled in, since the runtime fills it from
    the instance.

  A step checks the edit, then the state, then the stage.
- **Outside the contract, and documented:** scanning the program the edit is not running;
  two edits of one instance at once; a step on an edit that has ended or been superseded;
  and accepting against a program the state is not running. The program the state is
  running is the one the last of `Runtime.instance/1`, `Runtime.restart/3`, a scan, or
  an edit's assemble or cancel left it with, so a test and an assemble at one boundary
  leave it running the candidate: another edit may be accepted against the candidate
  before any scan (fix F2), and none against the original. None of these is
  detected until OE-2's configuration carries a generation counter. *(Decided 2026-10-13
  by decision 60: only the configuration edit carries one, so for a lone instance these
  stay outside the contract, documented, the host's to avoid.)* A plain swap stays in
  the contract, as today (decision 26): it is a scan of the new program over the kept
  state, so the program it swaps in is then the one the state is running. Accepted before
  that scan, an edit would take the state for what the new program showed the host, which
  OE-1's contract walk found.

*A switch.* Test and untest each switch the state from the program they stop, F, to the
one they start, T: test from the original to the candidate, untest back. A switch reads
and writes only the state and the edit's record of the instance. Its plan was built at
accept from the programs alone, so the plan cannot go stale. A switch never prunes. Its
rules, in order:

| Rule | What the switch does | Report |
|---|---|---|
| Start what is missing | A tag T declares that the state lacks starts at its initial value: a tag the candidate adds, or one a restart during the edit dropped | `{:added, n, v}` |
| Start what the candidate adds | At the first test only (from accept), every tag the candidate adds starts at its initial value, over whatever a plain swap left under its name | `{:added, n, v}` |
| Restart what does not fit (decision 26) | At the first test only, every tag of the candidate whose value does not fit its declared type starts again at its initial value. Fit is `Declarations.fits?/2`, or for a timer its member keys | `{:added, n, v}` |
| Inputs (decision 22) | A var_input of T that was not one of F (added, back at untest, or made one by a section change) is reported with the value it reads now, and the host sends its real value before the next scan. A var_input of F that is not one of T (removed, or given another section) is reported with the value it holds, and the host stops sending it. A var_input whose value a rule above writes is reported here, not as `:added`, because its value is the host's | `{:input, n, v}`, `{:unread, n, v}` |
| `.pre`, undone first (fix F1) | Each switch records in the edit's record, for each timer F or T declares, the `.pre` it left and the `.pre` it found. The edit's next switch first restores the found value wherever `.pre` still equals the one left, so an untest gives back exactly the `.pre` its test found, a timer the candidate drops included. The two `.pre` rules below apply only where this one does not. A `.pre` an earlier edit's switch moved is not given back | `{:preset, t, {left, found}}` where it moves; `{:preset_kept, t, {pre, preset}}` where it does not, T runs the timer and `.pre` is not T's preset |
| `.pre`, both programs run a `ton` | For a timer F and T both run, with presets p0 and p1, a `.pre` still at p0 moves to p1. A `.pre` logic changed is kept, and reported where it differs from p1 | `{:preset, t, {p0, p1}}`, `{:preset_kept, t, {pre, p1}}` |
| `.pre`, a `ton` stopped or restored (decision 23) | A timer T runs no `ton` on keeps its `.pre` frozen. A timer T runs and F did not takes T's preset outright | `{:preset, t, {pre, p1}}` where it moves |
| `.dn` (fix F6) | After any move of the `.pre` of a timer T runs: with `.dn` 1 and `.acc` below the new preset, `.dn` drops at the next scan with its rung true, unless at least preset − acc ms have passed. With `.en` 1, `.dn` 0 and `.acc` at or past the preset, `.dn` rises at that scan. A negative `.acc` counts as 0, as `ton` counts it. No latch is added | `{:dn_drops, t, {acc, preset}}`, `{:dn_rises, t, {acc, preset}}` |
| Resume undone (fix F11) | Where this edit's last switch resumed a timer and no scan has run since (`switched`), a `last` still at `now` goes back to the one that switch found, before the rule below, so a test and an untest with no scan between leave the original's timers as they were. A resume an earlier edit's last switch made is not given back | `{:resume_undone, t, ms}` |
| Resume | A timer T runs and F did not, timing when last run (`.en` 1, its `last` before `now`), resumes from the switch: its `last` becomes `now`, so the time no `ton` ran it is not caught up. Every `ton` stamps `last` at every scan, so within the contract a `last` before `now` says F did not run it, and the switch reads no more. *(Changed 2026-10-02 by Milestone 2's design, §4.10, M2-5: a false `cal` freezes a timer inside a block, so a `last` before `now` no longer says F did not run it. The basis becomes F's text not running the timer, and F being the program that last scanned. The top level behaves as before. Landed with M2-5, which `edit_test.exs` and OE-1's contract walk confirm unchanged at the top level.)* | `{:resumed, t, ms}` |
| One-shots (decision 21) | Blocks an `ons` for the next scan: below | `{:ons_blocked, b, v}` |
| Held outputs (decision 20) | Records each output no logic drives any more: below | `{:held, o, v}` |
| Initial values (decision 29) | A bool or dint both programs declare, of one type, whose initial value (as `Program.initial_env/1` gives it) differs keeps its running value; the new one applies when a restart next starts it. Not reported where a rule above started it, nor for a var_input of the program started, whose value a restart keeps. *(From Milestone 5, decision 157: a tag of every type, an array element by element, compared exactly as declared, `0` and `0.0` two values, so `var x real 0` edited to `var x real 0.0` is reported though both start at 0.0.)* | `{:initial_changed, n, {old, new}}` |
| `now` and `first` | Never touched, so no switch makes a scan first | — |

**One-shots (decision 21; fixes F2, F3, F7, F9).** No switch writes a storage bit: a bit
armed by writing 1 echoes into any rung that reads it. Instead `%Logex.Instance{}` gains
`ons_blocked`, the storage bits its next scan blocks. The runtime gives that one scan a
map of the listed bits in `%Logex.Scan{}`, built once for the scan, and `ons` looks its
bit up in it as it reads `first`: an `ons` whose bit is listed passes no power, and still
writes its bit. A scan empties the list, and so does a restart. *(Changed 2026-10-02 by
decision 32: from M2-5 a scan keeps listed each bit inside a function block instance whose
body it did not run, under a false `cal` or none, and a switch after it lists that bit
again where the program it starts still has the `ons`. At the top level every rung then
ran, so a scan still emptied the list there. Landed with M2-5, 2026-10-04: a `cal` records
that its body ran, and the scan takes the record out.)* *(Changed 2026-10-15 by decision
106: from M3-5 a scan keeps listed too each memory on a rung a jump skipped, at the top
level and in a body that ran, a storage bit, a counter's edge memory or a pulse timer's,
until a scan runs its instruction; one that no rung of a routine the scan ran holds,
which only a plain swap can leave, is used up as before. Landed with M3-5: a skipped rung
marks each listed memory it holds in the scan's record, wherever on the rung its
instruction stands.)* A switch lists:
- each `ons` of T that is new, or whose rung differs with line numbers ignored, against
  the program that last scanned, and, since M3-1, with the preset of every `ton` and
  counter on it ignored too, which no power on the rung reads, so a preset changed alone
  blocks no `ons` (decision 87);
- each `ons` of T whose storage bit that program wrote through anything but an identical
  `ons`, such as an `otu` (fix F7).

An untouched `ons` is not listed, so it keeps a genuine edge on the switch scan. The
program that last scanned is F, unless no scan has run since the last switch. The
instance records whether one has, in its `switched` (below), and within one edit the edit
knows which program last scanned, recording it at each switch, so a test and an untest
with no scan between lose no real edge (fix F3). Where the program that last scanned is T
itself, the same one of the edit's two programs, as at an untest taken with no scan since
its test, the switch lists none of T's own: T's bits are as T left them, T's own other
writers included, so neither rule above applies. The rule of fix F7 guards against
another program's writes; read against T itself it would block, at every such untest, an
`ons` that T also writes another way, and the round trip below would no longer leave the
original as it was. Where the last switch was an earlier edit's, the edit does not know
that program. The switch then compares against F, and keeps listed every pending bit that
T still has an `ons` on, so a second edit taken before any scan cannot make a one-shot
fire (fix F2). Each listed bit is reported with its value, which the switch leaves alone.
The list is called `ons_blocked` and its report kind `:ons_blocked`, never "held": here
"held" means an output keeping its value (fix F9).

**Held outputs (decision 20; fix F4).** A var_output of F or of T that F drove (wrote
through a `:write` slot, an `ons` bit included) and T does not drive as a var_output
(removed, given another section, or no longer written) holds its value, and every step
reports it with a value:
- for an output the program that runs next still shows, a var_output none of its logic
  writes, the state's value, which that program's next scan gives the host, and which
  can differ from what the point holds until that scan (below);
- for one it does not show, the value its point last received, which the edit reports
  from its record of the instance, and at which the host holds the point.

The edit learns a point's value from the state only at a step taken while the program it
stops is the one that last scanned, with no restart since that scan. `%Logex.Instance{}`
gains `switched` for this: a switch sets it, a scan clears it, and a restart leaves it.
With `switched` and `first` both false, the state holds what the last scan showed the
host. With `switched` true, no scan has run since the last switch, so no point has
changed and the record stands. With `switched` false and `first` true, a restart has
cleared what the last scan showed, and the edit forgets it. So, for an output the program
that runs next does not show, the edit never re-reads a value a restart has since
cleared, or one that logic driving the tag as a var has since changed, and one whose
value it has not learnt is not reported. An output it does show is always reported, at
the state's value, which is what its next scan gives the host, and which can differ from
what the point holds until then: after a restart, or after the program stopped wrote the
tag as a var. Test, its forecast and assemble report the outputs the original drove and
the candidate does not; untest, and cancel after an untest, report the reverse. The
one-shot rules read `switched` too (fix F3).

**A member input no longer written (decision 96).** A member input logic writes, a
counter's `r`, `ld` or `pv`, an `rto`'s `r` or a timer's `.pre`, that F writes through an
instruction and T through none, of an instance T declares, keeps its value, as a held
output does, and each switch reports it by its path with that value, `{:unwritten,
"lube.r", 1}`: a reset held when the edit removes its rung stays on until a restart.

**Assemble and cancel** are not switches: they block no one-shot and move no `.pre`.
Assemble prunes the state to the candidate's tags, and cancel after an untest to the
original's. Each reports every tag it prunes, `{:pruned, n, v}` with the value it had,
and its direction's held outputs. Cancel from accept changes nothing and reports `[]`.

**The report.** A list of `{kind, name, detail}`, sorted, with at most one entry per kind
and name. The kinds are an open set, which a host must tolerate:

| Kind | Detail | Given by |
|---|---|---|
| `:added` | the initial value it started at | a switch |
| `:input` | the value it reads now; the host sends its real value before the next scan | a switch |
| `:unread` | the value it holds, 0 where the state lacks it, as after a plain swap; the host stops sending it | a switch |
| `:preset` | `{from, to}`, the move of `.pre` | a switch |
| `:preset_kept` | `{pre, preset}`: `.pre` kept where logic changed it, on a timer the program started runs | a switch |
| `:dn_drops`, `:dn_rises` | `{acc, preset}`: what `.dn` does at the next scan with its rung true, a negative `.acc` counted as 0; for a counter, `{cv, pv}`: what its `q` (a ctud's `qu`) becomes at its next run, unless that run counts, resets or loads (decision 88) | a switch |
| `:resumed` | the milliseconds not caught up | a switch |
| `:resume_undone` | the milliseconds of the resume this edit's last switch made, which `last` moves back by | a switch |
| `:ons_blocked` | the storage bit's value, unchanged | a switch |
| `:initial_changed` | `{old, new}` initial values; the running value is kept | a switch |
| `:held` | for an output the program that runs next still shows, the state's value, what its next scan gives, which can differ from what the point holds until then; otherwise the value the point last received | every step |
| `:unwritten` | the value it keeps: a member input logic writes, a counter's `r`, `ld` or `pv`, an `rto`'s `r` or a timer's `.pre`, that the program stopped writes and no logic of the program started writes, by its path (decision 96) | a switch |
| `:pruned` | the value it had | assemble, cancel |

The writes a report lists, applied to the state before its step, give the state after it,
exactly: `:added`, `:input`, `:preset`, `:resume_undone` (`last` given back), `:resumed`
(`last` set to `now`), `:pruned`, and `:ons_blocked` as the new block list, with
`switched`, which a switch sets. The other kinds state facts and forecasts.
`api_contract_test.exs`'s edit walk checks this.

**The host's duties during an edit** (fix F10; `Logex.Runtime`'s moduledoc gives the
first three, and `Logex.Edit`'s the rest):
- under test, send only the var_inputs of `Logex.Edit.running(edit)`. A host that sends
  its whole input image is refused once the candidate removes an input;
- resend every input a step reports as `{:input, …}` before the next scan. Across a
  switch, "a host sends only what changed" is no longer enough;
- stop sending each input a step reports as `{:unread, …}`;
- hold each point a step reports as `{:held, …}` at its value. One the program that runs
  next no longer shows is among no scan's outputs; one it still shows, a var_output it
  writes no more, is among them, and its next scan gives that value;
- scan, set inputs and restart through `running/1`, and tolerate a report kind it does
  not know.

**One rule for new state.** `Logex.Program.initial_env/1` stays the one rule.
`Runtime.instance/1`, `restart/3`, the edit's three start rules and, since M2-1,
`start/1` and `restart/2` all start a tag by it, and `start/1` builds each instance through the same
constructor as `instance/1` (fix F14). Its doc lists the edit's exceptions, for state an
instance already holds around the new piece:
- `first` stays false;
- an `ons` the edit adds or changes is blocked by `ons_blocked`, where a new instance
  relies on `first`;
- a counter's edge memory, `cu` or `cd`, whose instruction the edit adds or whose rung it
  changes, is blocked the same way, by its path, so the counter's next run counts no edge
  (M3-1, decision 87);
- so is a `tp`'s edge memory, `.en`, by its path, `horn_pulse.en`, so its next run starts
  no pulse (M3-2, decision 94);
- so is an `osr`'s or an `osf`'s storage bit, whose coil the edit adds or whose rung it
  changes, by its name as an `ons`'s is, so its next run sets no pulse (M3-4, decision 80);
- each of those blocks, on a rung a forward `jmp` skips, stays listed through every
  skipped scan until a scan runs its instruction, as one in a block whose `cal` is false
  does, and a rung is compared whole, its `lbl` and `jmp` among it (M3-5, decision 106);
- a var_input a switch makes live is reported as `:input`, because its value is the
  host's;
- at the first test, a tag the candidate adds, or one whose value does not fit its type,
  starts at its initial value over what a plain swap left;
- a kept bool or dint whose initial value changed keeps its value until a restart, and
  is reported as `:initial_changed`, except one a start rule starts, at its new initial
  value, and a var_input of the program started, whose value a restart keeps: neither is
  so reported;
- an event task's trigger is a resource's state, not a tag's: its rule is in
  `Logex.Runtime`'s one-rule section (M2-6, landed).

*Milestone 3's state* (decided 2026-10-14, decisions 67–92; M3-1's counters landed the same
day, and `Logex.Runtime`, `Logex.Instance` and `Logex.Edit` give their rules as built). A
counter, `ctu`, `ctd` or `ctud`, is a built-in function block instance, state of the
program instance that holds it, as a timer is:

| Piece | A new instance | A scan | `restart/3` | A switch: kept | added | removed, then restored |
|---|---|---|---|---|---|---|
| `cv`, `ov`, `un` | 0 | IEC's body for the side its `ctu` or `ctd` runs (decisions 69–71) | 0 | kept | 0, by `initial_env/1` | frozen, then kept |
| `pv` | the instruction's preset | written by logic, read at the next run | the preset | moved where logic left the old preset, else kept (decisions 23, 27), reported `:preset`, `:preset_kept`, with `q`'s forecast (decision 88); `:unwritten` where no logic writes it any more (decision 96) | the preset | frozen, then the new preset outright (decision 23) |
| `r`, `ld` | 0 | written by logic, read at the next run (decision 84) | 0 | kept; `:unwritten` where no logic writes it any more (decision 96) | 0 | frozen, then kept |
| `cu`, `cd`, the edge memories | 0 | the side's rung power | 0 | kept; blocked by path where its rung changed, the presets left out (decision 87) | 0, blocked | frozen, then blocked |
| `q`, `qu`, `qd` | 0 | set from `cv` at every run | 0 | kept, set at the next run | 0 | frozen, then set at the next run |

In a block whose `cal` is false everything is held, and an edge that comes and goes while
it is frozen is not counted (decision 89); a blocked memory there stays listed until a
scan runs it (decision 32). A counter keeps no time, so nothing resumes it, from a switch
or from aside. A type change, `ctu` to `ctud` among them, is refused at accept.

M3-2's timers, `tof`, `tp` and `rto`, landed on 2026-10-14 (decisions 93–95). Each is a
timer as a `ton` is, with its members, an `rto` with its reset `r` too, and every rule a
`ton`'s member has: started by `initial_env/1`, at its preset for `.pre` and 0 for the
rest; started again by `restart/3` and `restart/2`, warm or cold, an `rto`'s time among
them until `retain` lands (decision 76); `.pre` moved at a switch by decisions 23 and 27,
reported `:preset` or `:preset_kept`; a removed one frozen and a restored one given its
preset outright. What differs is by type:

| Piece | A scan | A switch: kept | added | removed, then restored |
|---|---|---|---|---|
| a `tof`'s members | IEC's TOF, `.dn` its Q (decision 93) | kept; `:dn_drops` where `.pre` moves at or below `.acc` during the delay, and where it moves to 0 while the rung is true, `.dn` then dropping at its next run with the rung false | at rest, nothing blocked | frozen, then resumed from the switch where `.tt` was set |
| a `tp`'s members | IEC's TP, its pulse `.tt` (decisions 74, 75, 94) | kept; `:dn_rises` where `.pre` moves at or below `.acc` during the pulse | 0 | frozen, then resumed where `.tt` was set |
| a `tp`'s `.en`, its edge memory | the rung's power | kept; blocked by path where its rung changed, the presets left out (decision 87) | 0, blocked | frozen, then blocked |
| an `rto`'s members | the conventional RTO, `.acc` and `.dn` kept across a false rung (decisions 76, 95) | kept; `:dn_drops` and `:dn_rises` at its next run with its rung true | 0 | frozen, then resumed where `.en` was set |
| an `rto`'s `r` | written by logic, read at the next run (decisions 90, 95) | kept; `:unwritten` where no logic writes it any more (decision 96) | 0 | frozen, then kept |

In a block whose `cal` is false each is held with the rest, `last` with it, and catches up
when the block next runs (decision 8). A timer in the rungs a forward `jmp` skips freezes
and catches up so too (decision 82, landed with M3-5).

M3-3's arithmetic, `add sub mul div mod neg abs`, landed on 2026-10-14 (decisions 77–79,
97–99), and keeps no state of its own: what it writes is its destination's, a dint tag or
a member logic may write, ordinary state under every rule above, started by
`initial_env/1`, kept by name across a switch, held and reported `:held` where it is an
output no rung drives any more. An edit that adds, changes or removes one blocks nothing
and reports nothing of its own. The one new piece is an instance's record of its last
scan's minor faults (decision 99):

| Piece | A new instance | A scan | `put_inputs/3`, `restart/3` | A switch | In a resource |
|---|---|---|---|---|---|
| `faults`, each a `%Logex.Fault{}` | `[]` | the scan's own, in order, `[]` for none | kept: neither is a scan | kept | reported as `{:fault, ...}` events by the cycle and dropped, so `[]` between cycles |

M3-4's pulse coils, `osr` and `osf`, landed on 2026-10-14 (decisions 80 and 100–103), and
keep no state of their own: their two bits are bools the program declares, a `var` or a
`var_output`, under every rule above, started by `initial_env/1` and kept by name across a
switch. What the coils add is each bit's part:

| Piece | A new instance | A scan | `restart/3` | A switch: kept | added | removed, then restored |
|---|---|---|---|---|---|---|
| a coil's storage bit | its declared value | the power the coil receives, at every run | its declared value | kept; blocked by name where its rung changed, its kind and pulse bit among it, the presets left out, or where the program that last scanned also writes it another way (decisions 21, 80 and 87) | its declared value, blocked | kept, unused, then blocked |
| a coil's pulse bit | its declared value | 1 on the run whose power rises (`osr`) or falls (`osf`), never on a first scan nor while its storage bit is blocked; 0 at every other run (decision 102) | its declared value | kept, and set at the coil's next run | its declared value | held, `:held` where it is a var_output (decision 20), then set at the next run |

In a block whose `cal` is false both bits are held, so a pulse given at the body's last run
stays on until it next runs (decision 102), and a blocked storage bit there stays listed
until a scan runs it (decision 32). A block whose first run comes after the instance's
first scan reads each storage bit as declared there, so an `osr` whose rung is true pulses,
and an `osf` whose storage bit is declared 1 pulses on a false rung (decision 102). A coil
under an event task is a configuration warning, as an `ons` is (decision 103, as the
maintainer answered it on 2026-10-15).

M3-5's forward jump, `jmp` and `lbl`, landed on 2026-10-15 (decisions 81–83 and 104–107),
and keeps no state of its own: the jump an energised `jmp` records lasts only until its
rung is done, and a label is a name, not a piece of state. What a jump adds is a rung that
does not run, which every piece above meets as it meets a block whose `cal` is false:

| Piece, on a rung a jump skips | A scan that skips it | A switch |
|---|---|---|
| a coil's target, an `ote`'s among them, and any tag or member it writes | held, written neither 1 nor 0 | kept by name, as any |
| a counter's side, a one-shot's storage bit, a `tp`'s `.en` | held, so an edge that comes and goes while it is skipped is never seen | blocked by name or path where its rung changed, its `lbl` and `jmp` among it, and kept listed through every skipped scan until a scan runs its instruction (decision 106) |
| a timer's members, `last` among them | held, so it catches up when its instruction next runs (decision 82) | kept, as any timer |
| a block instance its `cal` would run | frozen, its own block list kept (decision 32) | as any block instance |
| a zero divisor | no fault: its `div` or `mod` never runs | — |

A section skipped since the instance's first scan runs its edge instructions first on a
scan that is not a first scan, as a block does (decisions 89 and 102). Nothing else an
edit does turns on a jump: an edit that moves rungs leaves every jump as it was, one that
adds a `jmp` freezes its section from the switch, and one that removes it frees it, its
timers catching up and an edge that rose meanwhile seen at its first run, as in a block.

An instance a configuration's edit sets aside and brings back (decision 57) is not
"removed, then restored": it comes back as it was set aside, under the program it ran
then, each of these timers resumed from the switch where its timing member was set, `.tt`
for a `tof` and a `tp`, `.en` for an `rto`, as a `ton` is by `.en`. Nothing in it is
blocked, a `tp`'s `.en`, a counter's `cu` and `cd` and a pulse coil's storage bit alike:
no edit changed the rungs it runs, so each edge memory holds the power its rung last
received, and an input that rose while the instance was aside is a real edge, which its
first scan back pulses or counts.

*Milestone 2's state* (designed 2026-10-02, §4.10; M2-1's pieces landed with it on
2026-10-02, and `Logex.Runtime`'s moduledoc gives their rules as built, and M2-5's on
2026-10-04, whose rules `Logex.Program.initial_env/1`, `Logex.Instance` and
`Logex.Edit` give; the rest have not). From M2-5 a function
block instance is state of the program instance that holds it: `Program.initial_env/1`
starts it, recursively; an energised `cal` runs it and a false one leaves it alone;
`restart/3` starts it again; and a switch moves it member by member, by path (decisions 31
and 32). A resource's own state lives in the opaque `%Logex.Runtime{}`, which no host
builds, so a piece of it needs no entry check. Instead each piece gets a value from
`start/1` and a rule for a cycle, for `restart/2` and for OE-2's switch. A global's one
rule is `Logex.Configuration.initial/1`, its initial value or 0. Inside a resource each
`%Logex.Instance{}` keeps OE-1's rules unchanged. Three cells the design pass left to
OE-2 were decided on 2026-10-04 as it recommended (decisions 43–45); OE-2 builds them, and
no Milestone 2 commit depends on them. *(OE-2's design, below, decided 2026-10-13, gives
the whole table across its switch, its own pieces `generation` and `aside` among them, and
refines these OE-2 columns: an instance's `now` is set to the resource's at a switch,
decision 56; an instance removed is set aside, kept unused, and comes back with its timers
resumed, decision 57; and a restart during an edit drops what is set aside, decision 65.)*

| Piece | `start/1` | A cycle | `restart/2` | OE-2: kept | OE-2: added | OE-2: removed |
|---|---|---|---|---|---|---|
| `now` | 0 | advances by `elapsed_ms` | kept | never touched | — | — |
| an input point's value, the input image | 0 | the inputs merged in | kept, as `restart/3` keeps var_inputs | kept | refused: located I/O | refused |
| an output point's value | 0 | its driver's copy-out | 0 | kept; held and reported where nothing drives it any more (decision 20) | refused | refused |
| an unlocated global's value | `Configuration.initial/1` | copy-out, and writes through `var_external` | `Configuration.initial/1` | kept. reported as decision 29 reports a tag's (decision 44) | `Configuration.initial/1` | kept unused at test, pruned at assemble |
| a global's type or location | — | — | — | a change refused at accept | — | — |
| a program instance | `Runtime.instance/1` (fix F14) | its `call/4` | `restart/3` | moved by OE-1's per-instance switch, one plan per program type (fix F5) | `Runtime.instance/1` | kept at test, pruned at assemble; each global it drove is held and reported |
| an instance's type | — | — | — | a remove plus an add, both reported (decision 43) | — | — |
| an instance's task | — | — | — | a change refused (decision 19) | — | — |
| a task's `next_due` | 0, anchored at start | advances by whole intervals | the kept `now`, so due at the next cycle | kept; a changed interval gives `min(next_due, now + new interval)` (decision 40) | refused until verified (decision 19) | refused until verified |
| a task's overlap count | 0 | adds `missed` | 0 | kept | — | — |
| a `var_external` (M2-4) | none held; a lone instance's tag starts at 0 | merged in before its instance's scan, split off after | none held | the switch merges each global in by the running program's externals and splits it off by the candidate's, so the value kept is the one decision 25 keeps (decision 45) | binds to its global by name | — |
| an event task's last sample (M2-6) | 0, so a trigger already 1 fires | sampled once a cycle | 0 | kept, the edit's exception, so a switch fires no event; a changed `single`, or an `interval` added or removed, refused | refused until verified (decision 19) | refused until verified |

**The data path (decisions 24 and 28).** What the text cannot say is refused where data
enters, so accept needs no check of its own, and every program within the contract can be
written as text.
- `Logex.Compiler.instructionize/2` checks its routine on entry against exactly what
  `Logex.Parser.parse/1` can produce. One public function beside the parser,
  `Logex.Parser.well_formed!/1`, states that shape, and the parser's moduledoc calls it
  the definition of a well-formed tree:
  - `{:routine, {:rungs, rungs}}`, where `rungs` is a list;
  - a rung is `{:rung, elements}` with at least one element;
  - an element is `{:name, line, word}`, where `word` lexes as exactly one name token;
    `{:int_lit, line, n}`, where `n` is a non-negative integer *(landed with M3-3,
    2026-10-14, decision 97: `n` is any integer, since `-5` lexes)*; or
    `{:branches, legs}` with at least one leg, a leg being a list of elements, possibly
    empty;
  - every line is a positive integer. Every name and literal of one rung, inside its
    groups too, carries one line, and the lines of successive rungs strictly increase. A
    rung of nothing but empty groups, `( )`, carries no line, but stands on a line of its
    own, as it does in the text, so the next rung's line is past that one too.

  A tree outside that shape is a host mistake: an `ArgumentError` whose message names the
  offending node, pinned by a test. That covers an empty group or rung, a negative
  literal, a missing, zero, negative or non-integer line, two rungs on one line, and any
  malformed tuple, so no `FunctionClauseError` or `Protocol.UndefinedError` escapes. The
  check is linear in the tree's size. It widens when `PLAN.md` §5's negative literals and
  line continuations land. Until then the compiler code that handles either cannot be
  reached; it is kept, and documented, not deleted. *(Landed with M3-3, 2026-10-14, for
  negative literals, decision 97: the check takes any integer, so a negative literal is no
  longer among what it refuses, and a negative preset reaches the compiler from text,
  refused at its line as one too large is. Line continuations have not landed, and the
  code that cites an element at a line of its own is still unreached.)*
- `Logex.Tag.new!/4` refuses any initial value on an instance, with the message a
  declaration line gets. The `%{"pre" => ms}` map M1-6 allowed is withdrawn: where a `ton`
  runs the timer, its preset silently replaced the map, and where none does, no text could
  give that `.pre` (decision 24). `new!/4` also refuses a negative initial value, in the
  declaration line's style, until a negative literal lexes. *(Landed with M3-3,
  2026-10-14, decision 97: a negative literal lexes, so `new!/4` takes a dint's negative
  initial value, as `var tare dint -120` gives one, and a bool's is 0 or 1 as before.)*

**Cost.** Accept builds both plans once, in time linear in the two programs, and a switch
is linear in them too. *(Restated 2026-10-04, after the check of M2-5's fixes, for a
program that holds blocks: accept and a switch are linear in the two programs and in the
instances they nest, which is the state, since the forecast, the plans' one-shots and
timers and a switch's writes go by path, an entry per instance path. A program whose types
each hold two instances of the type below is linear in its width and depth, each type held
once (§4.10, "Held types"), but its instances grow as 2 to the power of the depth, and
accept and a switch with them: at 4 and 10 levels the program took 2,789 and 5,789 words
copied flat, its state 1,478 and 94,214, accept of the program against itself 20,263 and
748,898 reductions, accept of a change to the deepest timer's preset 23,782 and 1,001,698
with a forecast of 16 and 1,024 entries, and the switch 2,906 and 180,351. With one
instance per level, or no blocks, nothing changes.)* *(After the check of decisions 53 and
54: an edit, `%Logex.Edit{}`, copied flat, as a message to another process or by
`:erlang.term_to_binary/1`, grows with the instances its two programs nest, as its state
does. Its plans hold each block type as the program's one table holds it, and read it
inside that table only where a switch starts a block (§4.10, "Held types"). Decision 53
had them keep each type read inside the table, which a flat copy wrote out once per
instance and member planned: with w types at a level sharing a chain of 16 below them, an
edit of a program given them against itself took 715,694 and 4,443,950 words at w of 4
and 16, where before decision 53 it took 338,954 and 1,354,346, and now takes 62,576 and
202,544; in decision 53's diamond, 222,016 and 6,743,744 at 4 and 8 levels, now 35,504
and 412,752. In memory, where its types share the one table, an edit was linear and
still is.)* Two tests in reductions keep accept and every step linear (fix F16;
CONTRIBUTING.md, "Test a pass over the program for growth"): accept, test, untest, test
and assemble at 500 and 2,000 of each tag, and at 500 and 8,000 levels of nesting.
The spike needed them: its first plan of held outputs was quadratic, and accept took 2.4
s at 2,000 rungs until a probe found it. Two more, from the review of OE-1, keep the
scan right after a switch linear in the one-shots it blocks, and a second edit taken
before any scan linear in the blocks still pending (fix F2). *(Restated 2026-10-02 by
decision 32: a bit inside a function block is named by its path, so the scan right after
a switch is linear in the block list's bytes, and quadratic in the depth of nesting with a
one-shot at every level. At the top level, where a bit's name is one name, nothing
changes. As landed with M2-5, `function_block_test.exs` pins it in the block list's
bytes, which grow 16x for 4x the depth of a chain: a switch and the scan after it are
bound to 1.3x that growth, and measured 5.1x and 10.0x; the scan right after a switch at
16x the instances took 16.2x to 16.4x the reductions, and a second edit's steps at 16x
the pending nested bits 16.4x to 16.8x, each bound 24.)* Each figure moves by about 10%
from run to run, with garbage collection, so each is the range of the runs that
measured it on 1.20.4, not a limit: 48 runs of the four tests printing their own ratios,
after the review of the OE-1 fixes, and up to 63 more in the check of those fixes; a
mutant's, 10 to 25 runs: 4x the tags takes 4.3x to 4.6x the reductions (bound 6); 16x
the depth 14.4x to 14.6x (bound 18.5); 16x the blocked one-shots 16.4x to 17.9x the
reductions of that scan, where a walk of the block list for every `ons` took 65.4x to
65.8x; and 16x the pending blocks 16.2x to 17.8x the reductions of the second edit's
steps, where a walk of a list of the one-shots, built once, for every pending bit took
36.5x to 38.3x. The last two have the bound 24, a third above their highest runs: they
landed with 18.5 and 32, set from a few runs, and the first of those was only 3% above
the highest of the 48. The spike's cost probe, run on 1.20.4 on the landed code and on
the spike in turn (three runs each, every figure a median of 20),
gives at 2,000 rungs and 4,000 tags, landed against spike: accept 17–19 ms against 18–21;
a test 0.68–1.19 ms against 0.35–0.36; an untest 0.58–0.65 ms against 0.41–0.47; an
assemble 0.81–0.84 ms against 0.75–0.82; one scan 1.31–1.36 ms against 1.34–1.45; and the
candidate's compile, the entry check included, 98–107 ms against 72–75. A landed switch
does more than the spike's (the `.pre` record of fix F1, the one-shot blocks of F2 and
F3, the held values of F4) and still costs less than one scan.

**Tests.** Each rule gets a test that fails when that rule alone is reverted.
- `edit_test.exs`: every host-mistake message and the order of its checks, every `:edit`
  diagnostic, a test per rule, the four growth tests above, and a test of the labels
  that the code, the tests and CLAUDE.md cite. It refuses a label only the design pass's
  own notes define, a lettered hazard (`hazard B`, `hazards B to E`, `hazard (B)`) or a
  numbered review finding (`R` and a number), and a fix or decision whose number §7 does
  not define. It checks a decision by its number alone, which `PLAN.md` M1-6's design
  decisions, cited in places, share. Its programs are built within the contract: an
  unnamed one comes from `instructionize/2`, never from editing a struct (fix F12).
- `end_to_end_test.exs`: the Done-when, the type-change refusal and the data-built
  refusal. The Done-when's text is not changed. Its candidate's `ons` moves a setpoint, so
  it drives no new var_output; one that did would rightly be listed as held at untest,
  against the Done-when's "lists no undriven output".
- `api_contract_test.exs`: an edit walk, 400 walks of 60 operations, that landed with
  `Logex.Edit` (fix F11). It checks the refusals and that the listed writes rebuild the
  state, makes every accepted step twice, checks each report kind against its rule
  restated from the two programs' text, checks each held value the next program does not
  show against the walk's own image of the outputs it received, and each it does show
  against what that program's next scan gives, and checks that a forecast is the report a
  test taken at once gives. Right after a switch that resumed a timer it often switches
  back at once, and now and then restarts first. The timer and one-shot work each add
  their oracles, two of them independent of the rules: a one-shot pulses only if the
  previous scan ran the same `ons` rung text with its condition 0, wherever the program
  scanned writes its bit through the `ons` alone; and a test then an untest with no scan
  between leaves the original's tags and next outputs unchanged, a timer the test resumed
  included, but for what either switch started, which no untest undoes, found from the two
  programs' text and the state and never from the reports, and its block list too, but
  before a first scan, which blocks every `ons` anyway. The timer work adds two more: no
  scan lets a timer gain more than the scan's own time, as one caught up would, a plain
  swap's scan, which catches a frozen timer up as it always has, aside; and the scan right
  after a switch does to `.dn` what the switch forecast. Every property asserts its reach.
- The entry check: every tree in the front-end golden record, and every tree the printer
  test's generator produces, passes it (a property). The hand-built trees in the suite
  that the parser could never produce become `ArgumentError` tests: `validation_test.exs`'s
  negative preset and its rung over two lines, and `printer_test.exs`'s group with no legs.
  *(Landed with M3-3, 2026-10-14, decision 97: the parser can produce a negative preset
  now, so its `ArgumentError` test is gone, and `validation_test.exs` refuses `ton t1 -1`
  from source at its line instead, as one too large is; the rung over two lines is still
  an `ArgumentError` test.)*
  A seeded property in `printer_test.exs` breaks a generated tree at any one node and
  expects only `ArgumentError`.
- `runtime_test.exs`: the exact public surface, `Logex.Edit`'s and `Logex.Parser`'s
  included, the fields of `%Logex.Instance{}` and `%Logex.Scan{}`, and the messages of the
  block list and of `switched`. *(And since M3-3 the messages of `faults`, decision 99,
  checked before the state's owner, as the block list is.)*
- *(M2-5, landed 2026-10-04.)* `function_block_test.exs` holds a test per rule of the
  edit of a program that holds function blocks, by path (decisions 31 and 32), among them
  a block frozen by a false `cal` across a switch, and its growth tests;
- *(OE-2, landed 2026-10-13.)* `config_edit_test.exs` holds every host mistake and refusal
  of `Logex.Configuration.Edit`, the refusals as whole lists from source and from data, a
  test per rule of a step on §4.4's plant, and its growth tests; `api_contract_test.exs`
  a walk of a configuration's edit (its moduledoc); `end_to_end_test.exs` `PLAN.md` OE-2's
  Done-when, from text and from files on disk; and `scheduler_test.exs` the resource's
  `generation` and `aside` across a cycle and a restart;
  `api_contract_test.exs` adds an edit walk over programs that hold blocks two deep, with
  a one-shot oracle on every scan, from the programs' text.

**Known limits, documented.**
- A one-shot block left pending by an earlier edit stays wherever the program started has
  an `ons` on its bit, even when that `ons` matches the one that last scanned. At worst one
  genuine edge is lost; no false pulse is made.
- A restart during test puts `.pre` at the candidate's preset. Where logic had set `.pre`
  to exactly that value before the test, the untest that follows gives back logic's value,
  where a restart of the original would give the original's preset.
- An `:edit` diagnostic carries no file (above). *(Closed by M2-5's fix F15: a
  candidate from `Logex.compile_file/1` carries its path, and so does each of its `:edit`
  diagnostics; one from `Logex.compile/2` still has none.)*
- An edit's record starts empty. A new edit whose first test comes with no scan since an
  earlier edit's last switch knows no point's value yet, so it reports only the held
  outputs its candidate still shows; and it knows neither the `.pre` nor the `last` that
  switch found, so it gives back neither a `.pre` it moved (fix F1) nor a resume it made
  (fix F11).

**OE-2's design: a staged edit of a running configuration.** Designed on 2026-10-13
against `92431a9`, on Elixir 1.20.4 / OTP 28, and decided the same day: decisions 55–65
(§7), all as recommended. A throwaway spike on that commit built the switch from OE-1's
per-instance plan, switch and prune with decision 45's merge and split, and ran thirteen
probes on §4.4's plant; its figures are receipts, and pin nothing. `PLAN.md` OE-2 gives the
Done-when and the landing order. *(Landed 2026-10-13, as `PLAN.md` OE-2 records, in the
ten commits after this record and its spike; what follows is the edit as designed, and
`Logex.Configuration.Edit`'s moduledoc gives it as built. Readings the landing made, each
in its commit and pinned: the split drops, with the started program's var_externals, any
of the stopped program's that the started one does not declare at all, rather than keep a
copy of a global in the state until a prune, the one place it departs from decision 45's
words; `:joined` and `:left` are writes the resource shows, an own value dropped and an
own tag set, not facts; a global is held only where the configuration started declares
it, one it removes being pruned instead; a reorder of the tasks themselves is reported
under `:tasks`; a step checks the generation before the configuration the resource runs;
an instance back from aside keeps its `first`, `switched` and block list as set aside;
and two rules found dead were removed, an element with no line sorted last, since a
configuration's lines are all numbers or all nil, and a connection's member checked to be
a var_output, since no logic writes a var_input. The contract walk found that a test then
an untest with no cycle between leaves every instance's env as it was but for what either
switch started and three things decided rules change: a tag the test joined to its global
(decision 55), a timer of an instance back from aside (decision 57), and a timer whose
earlier resume the test gave back after the clock moved (decision 56's known limit,
below).)* *(Its round trip compared only each instance's env, the names set aside and
the original's globals, though this note claimed the whole resource, which the review of
the landing found on 2026-10-14. It now compares the rest too, and the resource is as it
was but for those and what a switch's own rules set: each instance's `now` the resource's
(decision 56), a kept one's `switched` true (OE-1), each instance set aside that the test
brought back with its `now` and timers as decision 57 left them, and a changed interval's
next due time, `min(next_due, now + new interval)` (decision 40), which the untest's own
`min` with the old interval moves no further back: `slow` from 100 ms to 30 at 10 ms is
next due at 40 ms after the round trip, where a plant never edited is due at 100.)*

*Already decided, and built on:* decision 43 (a retyped instance is a remove plus an add),
44 (a kept global's changed initial value is reported), 45 (merge by the running
program's var_externals, split by the candidate's), 40 (`min(next_due, now + new
interval)`), M2-6's trigger kept across a switch, §4.9's refusals while running, decision
20's held outputs, and the generation counter that detects an edit outside the contract.

*The API.* A second module, `Logex.Configuration.Edit` (decision 59), with OE-1's step
names, order and report shape, over an opaque `%Logex.Configuration.Edit{}`:

```elixir
Logex.Configuration.Edit.accept(runtime, candidate) ::
  {:ok, edit, forecast} | {:error, [%Logex.Diagnostic{stage: :edit}]}
Logex.Configuration.Edit.test(edit, runtime)     :: {edit, runtime, report}
Logex.Configuration.Edit.untest(edit, runtime)   :: {edit, runtime, report}
Logex.Configuration.Edit.assemble(edit, runtime) :: {candidate, runtime, report}  # ends
Logex.Configuration.Edit.cancel(edit, runtime)   :: {original, runtime, report}   # ends
Logex.Configuration.Edit.running(edit) :: %Logex.Configuration{}  # what the resource runs
Logex.Configuration.Edit.stage(edit)   :: :accepted | :testing | :untested
```

- **Accept takes the runtime alone**, since the resource carries the configuration it
  runs, so neither of OE-1's "scanning the program the edit is not running" nor
  "accepting against a program the state is not running" can arise. It reads the runtime
  only for the forecast, the report a test taken now would give (decision 27), and changes
  nothing.
- **Each step takes and returns the runtime.** Test installs the candidate in the
  resource, and from then on `Logex.Runtime.cycle/3` runs it: the host never chooses what
  to scan. `running/1` says what a cycle runs now.
- **Assemble and cancel return the configuration kept**, as OE-1 returns the program kept,
  for a host that saves the plant's text (`Logex.Configuration.Text.print/1`).
- **The per-instance half of `Logex.Edit`**, its type-change refusals, plans, switch,
  prune and empty record, moves to an internal module, `Logex.Edit.Plan`, which both edits
  call: fix F5 as it was meant, one plan per program type and direction, called once for
  each instance. A plan can be told that its programs' var_externals are globals, so that
  no start rule starts one.
- **`%Logex.Runtime{}` stays opaque and is written in `Logex.Runtime` alone:** the switch
  and the prune hand their results to an internal function of `Logex.Runtime`, so that the
  resource's invariants, decision 49's among them, stay in one module.

| Step | Taken from | `cycle/3` then runs | The resource |
|---|---|---|---|
| accept | — | the original | read for the forecast, unchanged |
| test | accepted, untested | the candidate | switched to the candidate: instances, globals, tasks and wiring |
| untest | testing | the original | switched back |
| assemble | testing | the candidate; the edit ends | pruned to the candidate: the instances set aside, the globals and tags only the original has |
| cancel | accepted | the original; the edit ends | unchanged but for its generation; the report is `[]` |
| cancel | untested | the original; the edit ends | pruned to the original |

Every step is taken between two cycles. To finalise without cycling the candidate, the
host takes test and assemble at one boundary, as in OE-1.

*The host's duties shrink.* OE-1's four duties fall away in a resource: the input image
is the resource's, kept across every step, and located I/O cannot change, so the same
input points are sent before and after; each var_input is copied in from its connection
before every scan, so a step's `:input` and `:unread` carry no duty (decision 22's "OE-2's
copy-in will then make it automatic"); and a held output point keeps its global's value,
which `cycle/3` returns every cycle, so the host holds it by writing the outputs it is
given, as always. What remains: take each step between two cycles, keep the runtime each
step returns, restart through `Logex.Runtime.restart/2`, which is allowed during an edit
and keeps its stage (decision 65), and tolerate a report kind it does not know.

*The report* is a list of `{kind, name, detail}`, sorted, at most one entry per kind and
name, the kinds an open set. A global, task or instance is named by its own name, since
they share one namespace that `check/1` keeps free of case twins; anything inside an
instance by its path, `m1.t1`, `m1.s1.edge`, as §4.9's "from OE-2 it names an
`instance.tag` path" says. OE-1's kinds come by path from each kept instance's switch or
prune, exactly as `Logex.Edit` gives them; `:input` and `:unread` stay, as facts with no
duty. The new kinds, and OE-1's given at the configuration's level:

| Kind | Name | Detail | Given by | Write or fact |
|---|---|---|---|---|
| `:instance_added` | instance | its program type | a switch | write: started as `Logex.Runtime.instance/1` starts it, holding no var_external |
| `:instance_stopped` | instance | its program type | a switch | write: set aside, its state kept unused |
| `:instance_back` | instance | its program type | a switch | write: back from aside, its state as it was set aside, its timers resumed (decision 57) |
| `:instance_pruned` | instance | its program type | assemble, cancel; a first test, what a superseded edit set aside (decision 66) | write: its state dropped |
| `:added` | global | its initial value | a switch | write: `Logex.Configuration.initial/1` |
| `:initial_changed` | global | `{old, new}` | a switch | fact: the running value is kept (decision 44) |
| `:pruned` | global | the value it had | assemble, cancel; a first test, what a superseded edit kept unused (decision 66) | write |
| `:held` | global | its value | every step | fact: nothing drives it any more (decision 20; decision 58) |
| `:interval` | task | `{old, new}` ms | a switch | fact |
| `:next_due` | task | `{from, to}` ms | a switch | write: decision 40 |
| `:priority` | task | `{old, new}` | a switch | fact |
| `:watchdog` | task | `{old, new}` ms, 500 for none (M4-2, decision 129) | a switch | fact |
| `:joined` | `instance.tag` | `{own, global}`: the instance's own value, nil where it had none, and the global's | a switch | write: the own value dropped, the instance reading the global from its next scan (decision 55) |
| `:left` | `instance.tag` | the global's value | a switch | write: a var_external become the instance's own tag, at the global's value (decision 45) |
| `:order` | task, `:none` for the task-less instances, or `:tasks` | the names in their new order, `:tasks` the timed tasks alone (decision 129) | a switch | fact (decision 62) |

The writes a report lists, applied to the resource before its step, give the resource
after it, exactly, with each instance's `switched` and block list as OE-1 states them and
its `now` as decision 56 sets it, a first test's `:instance_pruned` and `:pruned` written
before the rest (decision 66). `api_contract_test.exs`'s walk of a configuration's edit
checks it.

*Host mistakes* raise `ArgumentError`, each message pinned by a test. A step checks the
edit, then the runtime, then that the edit is current, its generation first and then the
configuration, then the stage, as OE-1 checks the edit, the state, then the stage.

| Mistake | Message |
|---|---|
| a runtime that is not a resource, at accept or a step | the runtime's own: ``expected a %Logex.Runtime{} from Logex.Runtime.start/1, got: …`` |
| a candidate that is not a configuration | `start/1`'s own: ``expected a %Logex.Configuration{} from Logex.Configuration.new!/1, got: …`` |
| a candidate with a problem `check/1` finds | `start/1`'s own: every diagnostic, a line each, as `Logex.Diagnostic.format/1` gives it, or `check/1`'s own raise for a host mistake no text can make (decision 63) |
| a candidate with another name | ``the candidate is `pump_house`, but the running configuration is `plant`: an edit keeps the configuration's name`` |
| something other than an edit | ``expected a %Logex.Configuration.Edit{} from Logex.Configuration.Edit.accept/2, got: …``, so a `%Logex.Edit{}` is refused here, and a `%Logex.Configuration.Edit{}` by `Logex.Edit`'s own message |
| a generation that has moved | ``this edit expects the resource at generation 3, but it is at generation 5: the edit has ended, or another edit has stepped since`` |
| a resource that runs another configuration than the edit's | ``this edit is of another configuration than the one the resource runs: accept the candidate against this resource`` |
| a step at the wrong stage | OE-1's words: ``test takes an edit accepted or untested, but this one is under test``, and so for untest, assemble and cancel |

*What may change while running.*
- **A task's interval**, a periodic task's or an event task's that has one, and its
  **priority**. A changed interval makes the task next due at `min(next_due, now + new
  interval)`, at test and again, with the old interval, at untest (decision 40), `now` the
  step's time, the resource's unless the host gives the milliseconds since its last cycle
  (decision 139), reported as `:interval` and, where it moves, `:next_due`. A priority is read at each cycle's
  sort, so it needs no state: `:priority`.
- **The order** of tasks and of instances, which is configuration, not state: allowed and
  reported, `:order` (decision 62).
- **Instances added and removed**, keyed by name. One only the configuration started runs
  is started as `Logex.Runtime.instance/1` starts it, its var_externals dropped as
  `start/1` drops them, `:instance_added`, or brought back from aside, `:instance_back`.
  One only the configuration stopped runs is set aside, its state kept unused,
  `:instance_stopped`, and pruned at assemble, or at cancel after an untest,
  `:instance_pruned`.
- **An instance's program type** (decision 43): a remove plus an add under one name, the
  old state set aside and the new one started, both reported; at untest they trade
  places. A retyped instance may run on another task (decision 61).
- **A program type changed:** each kept instance, of the same name and type name in both,
  moves through OE-1's per-instance switch, by one plan per program type and direction,
  built once at accept (fix F5), its reports by path. A type no instance runs in both is
  not planned.
- **A function block type changed for the whole configuration** (decision 31): each
  program type that holds it is a changed program type, moved by its own plan, its
  members by path, a member whose kind changes refused by its path in that type's file.
- **A tag's section**, a var_external's among them (decisions 25 and 45, below).
- **Globals, unlocated:** one added starts at `Logex.Configuration.initial/1`, `:added`,
  at the switch that first finds it missing; one removed is kept unused at test, so an
  instance set aside that reads it finds it if it comes back, and pruned at assemble,
  `:pruned`; a kept global whose initial value changed keeps its running value until
  `restart/2`, `:initial_changed` (decision 44).
- **Connections**, any of them: the resource's wiring is derived again from the
  configuration it switches to. A var_input's new connection is read at its instance's
  next scan; an output point that loses its driver holds (below).

*Refused at accept.* Each is an `%Logex.Diagnostic{stage: :edit}` in the candidate's
`file`, at its element's line, in line order, an element only the running configuration
has, with no line in the candidate, last; each message ends, as OE-1's do, with "… only
with a restart". A device exists only as its points' prefix (§4.5), so a device renamed
or added is a change of location. A candidate's warnings stop nothing.

| Change | Cited at | Message |
|---|---|---|
| a task added | its `task` line | ``task `extra` is added: a task is added only with a restart`` |
| a task removed | no line, last, naming its line in the running configuration | ``task `slow` (line 3 of the running configuration) is removed: a task is removed only with a restart`` |
| a task's `single` added, removed or changed | its `task` line | ``task `trip`'s single changes from `estop` to `pb_reset`: a task's single changes only with a restart`` |
| an event task's interval added or removed | its `task` line | ``task `trip` has a single, and its interval is added: an event task's interval is added or removed only with a restart`` |
| a task made continuous, or a continuous one made timed (M4-2, decision 129) | its `task` line, its one refusal | ``task `main` is continuous in the running configuration and periodic in the candidate: a task's kind changes only with a restart`` |
| a kept instance moved to another task, or to or from none, the continuous task named where declared and `with main` no move (decision 129) | its `program` line | ``` `m2` runs with `slow` in the running configuration and with `fast` in the candidate: an instance moves to another task only with a restart``` |
| a global's type | its `var_global` line | ``` `sp_2` is a dint global in the running configuration and a bool in the candidate: a global's type changes only with a restart``` |
| located I/O: a located global added, removed or moved, or a location added to or taken from a global | its line, or none for one removed | ``` `sp_2` is at `drive.q.1` in the running configuration and at `drive.q.2` in the candidate: located I/O changes only with a restart``` |
| a tag's or member's type, in a program type a kept instance runs | that type's own file and line (fix F15) | OE-1's own messages, once a type |

*Held outputs (decision 20).* A global the configuration stopped drives and the one
started does not holds its value, and every step reports it, `{:held, global, value}`,
the global's value in the resource, which is what the next cycle gives for an output
point. A configuration drives a global where a connection copies out a var_output its
program writes (`Logex.Walk.writes/1`), or a program writes the global through a
var_external. A connection whose var_output the program no longer writes copies out a
frozen value, so its point holds too: the spike found that a reading by connections alone
missed it. Each kept instance's own `:held` entries for its var_outputs come by path beside
it (decision 58).

*Shared globals across a switch (decisions 45, 47, 49 and 55).* For each kept instance, at
every switch: each global is merged into the instance's state by the var_externals of the
program the switch stops; the instance is switched by its type's plan, which knows the
started program's var_externals, so no start rule starts one; and each var_external of the
program started is split off the state again, with any var_external of the program stopped
that the one started does not declare at all. The global itself is never written by a
switch. So a var_external in both programs is merged, kept and split, the global untouched,
with no report; a var_external become a `var` is merged in and kept as the instance's own
tag at the global's value (decision 25), `{:left, "m1.estop", v}`; a `var` become a
var_external has its own value dropped at the split, the global left alone, and the
instance reads the global from its next scan, `{:joined, "m1.estop", {own, global}}`
(decision 55); and a var_external the candidate adds, of a name the running program never
declared, is bound to its global, `{:joined, "m1.alarm", {nil, global}}`, where a global
the edit adds starts at `Logex.Configuration.initial/1`, `{:added, "alarm", v}`. After
every step no instance's state holds a var_external (decision 49).

*The generation counter (decision 60).* A non-negative integer in `%Logex.Runtime{}`,
`generation`, counting the configuration edits' steps taken on the resource: `start/1`
gives 0, a cycle and `restart/2` keep it, and every step but accept moves it on by one,
cancel from accept included (decision 64), so an edit that has ended can never step
again. The edit records the generation it expects: the resource's at accept, and the new
one after each of its steps. It detects a step on an edit that has ended, on one
superseded by another that has stepped since, and on one of two edits accepted at once
after the other has stepped; with the check that the resource runs the edit's
configuration, it also refuses an edit taken to a resource that runs another. It cannot
detect two resources started from one configuration: they are equal, plain data with no
identity, so an edit accepted on one may be stepped on the other while their generations
agree. Its plans fit, and only its record of each instance (fixes F1, F3, F4 and F11) may
be wrong. That is outside the contract, and documented. A lone instance gains no
generation (decision 60).

*One rule for each piece of state across the switch,* extending "One rule for new state"
above and `Logex.Runtime`'s one-rule section:

| Piece | `start/1` | A cycle | `restart/2` | Switch: kept | Switch: added | Switch: removed | Assemble, cancel |
|---|---|---|---|---|---|---|---|
| the clock, `now` | 0 | `+ elapsed_ms` | kept | never touched | — | — | never touched |
| the input image | 0 | the inputs merged | kept | kept | refused: located I/O | refused | kept |
| an output point's value | 0 | its driver's write | 0 | kept; held and reported where nothing drives it | refused | refused | kept; held reported |
| an unlocated global | `Logex.Configuration.initial/1` | copy-out, var_external writes | `Logex.Configuration.initial/1` | kept; `:initial_changed` (decision 44) | `Logex.Configuration.initial/1`, `:added`, at the switch that first finds it missing | kept unused | pruned, `:pruned` |
| a task's `next_due` | 0 | whole intervals | the kept `now` | kept; a changed interval gives `min(next_due, now + new)` (decision 40) | refused | refused | kept |
| a task's overlap count | 0 | `+ missed` | 0 | kept | — | — | kept |
| an event task's last sample | 0 | sampled once | 0 | kept: no switch fires an event | refused | refused | kept |
| `generation` | 0 | kept | kept | `+ 1` | — | — | `+ 1` |
| the instances set aside, `aside` | none | kept, never scanned | dropped: the next switch starts each again, `:instance_added` (decision 65) | — | — | an instance only the configuration stopped runs, and a retyped one's old state, set aside | pruned, `:instance_pruned` |
| a kept instance's env | `Logex.Runtime.instance/1` | `call/4` | `restart/3` | OE-1's per-instance switch, by path, between decision 45's merge and split | — | — | OE-1's prune, by path |
| an added instance | — | — | — | — | as `Logex.Runtime.instance/1` starts it, var_externals dropped, or back from aside | — | — |
| an instance's `now` | 0 | the cycle's `now` at its scan | kept | the resource's `now` (decision 56), after fix F11's undo has read the one the last switch set | 0, as `start/1` gives; back from aside, the resource's `now` | — | kept |
| an instance's `first` | true | false after its scan | true | never touched | true; back from aside, as set aside | — | never touched |
| an instance's `ons_blocked` | `[]` | emptied, but for bits inside a block not run (decision 32) | `[]` | OE-1's rules, against the program that last scanned it | `[]`; back from aside, as set aside | — | OE-1's: kept, not added to |
| an instance's `switched` | false | false after its scan | kept | true | false; back from aside, as set aside | — | kept |
| a var_external | none held | merged in, split off | none held | decision 45, as above | bound by name | — | none held |
| an instance back from aside | — | — | — | — | its state as set aside, each timer that was timing resumed from the switch, `:resumed` by path (decision 57) | — | — |

Three points the table makes, which OE-1's lone instance never met:
- **An instance on a slow task is not scanned by every cycle.** Its `switched` stays true
  from a switch until its own next scan, however many cycles pass, which is what fix F3's
  "no scan since the last switch" needs, read per instance.
- **`restart/2` during an edit** restarts the instances of the configuration the resource
  runs, drops those set aside and the globals only the other configuration declares, and
  keeps the generation and the edit's stage: the next switch starts again what it dropped,
  `:instance_added` and `:added`, as OE-1's restart during an edit does for tags
  (decision 65).
- **An edit accepted while another is open supersedes it** once it steps: the generation
  then refuses the old one. The resource may then hold what the superseded edit left: an
  instance set aside, or a global only its candidate, or its original, declared, kept
  unused. At the new edit's first test the resource runs the new edit's original and
  holds nothing of the new edit's, so each of these, an instance set aside or a global the
  original does not declare, is dropped before the switch, `:instance_pruned` and
  `:pruned`, and a candidate that runs or declares it again starts it as `start/1` would,
  `:instance_added` and `:added` (decision 66). Cancel from accept leaves it, unused, for
  the next edit's first test or a restart to drop.

*The spike of OE-1's record across slow tasks* (2026-10-13, before any of OE-2's code,
`PLAN.md` OE-2's second step). A throwaway draft of the contract walk ran the design
spike's switch, with decision 56's clock, over a plant of three instances of one program
type, on a 10 ms task, a 50 ms task and none, through 300 walks of 80 operations: cycles
of 5 to 20 ms, and edits among four versions of the type, with and without its `ton`, its
preset changed and its `ons` rung changed. Its oracles knew nothing of the rules: no scan
let a timer gain more than the time since its instance's last scan; a one-shot passed
power only where the instance's last scan ran the same `ons` rung with its condition 0;
and a test then an untest with no scan of an instance between left that instance's state
as the test found it. It found one defect and one cost the record already accepts.
- **Fix F11's undo must read the instance's own clock.** Built as decision 56 first
  reads, a switch that set the instance's `now` to the resource's before OE-1's
  per-instance rules ran left the undo comparing a resumed timer's `last` with the
  resource's clock. Where a cycle came between a test and its untest, as one does for
  every instance its task did not scan, the `last` the test had set no longer equalled
  `now`, so the untest gave no resume back and left the timer's `last` at the test's time,
  unreported: the very defect fix F11 fixed. Every one of three seeds found it. The record
  settles the answer: fix F11 says a test and an untest with no scan between leave the
  original's timers as they were, and decision 56 says a switch resumes from the
  resource's clock. So a switch reads the instance's `now` for the undo, which, while
  `switched` is true, is the time the last switch set, then resumes from the resource's
  `now` and sets the instance's `now` to it. With that, the walk held at all three seeds:
  between 1,486 and 1,617 round trips over an instance no scan reached, and about 4,000
  one-shot pulses each, every one where the oracle allowed it.
- **A timer frozen by a switch loses the time since its instance's last scan,** up to one
  interval of the instance's task, when a later switch resumes it from the resource's
  clock: from a version that runs its `ton` to one that does not, and back, the time
  between the instance's last scan and the first switch was the running program's own,
  and is not counted. Decision 56's own measurement includes 20 ms of it (`m2` last
  scanned at 50 ms, frozen at 70 ms, resumed at 130 ms, 80 ms not caught up), and the
  decision was taken with it. It is a known limit, and the round trip a walk checks in a
  resource allows it: a timer the untest itself resumes ends at the untest's time.

*The forecast* is the report a test taken now would give: the switch computed over the
runtime as it is, and thrown away. A test taken later reads the resource as it is then
(decision 27).

*Routine choices,* taken as recommended with the decisions: a removed element is cited
with no line in the candidate, last, its line in the running configuration in the text,
the tasks removed before the located globals removed, each in the running
configuration's order, whatever their lines;
an instance's plan is built once per program type and direction, so a configuration of N
instances of one type builds two plans; and a global the candidate removes, still read by
an instance set aside, is kept unused until assemble, so the instance finds it if it
comes back.

*Known limits, documented.* Two resources started from one configuration are
indistinguishable (above). A candidate given as Elixir data may hold two versions of one
block across its program types, which the loader cannot give; each type is planned by its
own plan and the edit works, but a configuration edit does not enforce one version of a
block.

*Cost.* Accept builds two plans per program type a kept instance runs, and a switch is
linear in the instances' state, the wiring derived again at each switch, and the check
that the resource runs the edit's configuration linear in the configuration. Accept and
each step are held linear in the instances of one type, in the program types and in a
program's size by `config_edit_test.exs`'s growth tests in reductions (fix F16): over 32
runs, 4x each took 3.90x to 3.95x, 4.00x to 4.03x and 4.01x to 4.05x the reductions.

### 4.10 Milestone 2's design (designed 2026-10-02)

**Designed 2026-10-02; M2-1 landed the same day (`PLAN.md` M2-1), M2-5 on 2026-10-04
(`PLAN.md` M2-5), M2-2 and M2-3 on 2026-10-11 (`PLAN.md` M2-2 and M2-3), and M2-4 on
2026-10-12 (`PLAN.md` M2-4), and M2-6 the same day (`PLAN.md` M2-6), which completes
Milestone 2.** A design pass spiked Milestone 2 in three
tracks on copies of `47319f7`, on Elixir 1.20.4 / OTP 28: the scheduler from Elixir data
(M2-1); user function blocks (M2-5); and the configuration file, shared globals and event
tasks (M2-2, M2-3, M2-4, M2-6). Each track was reviewed for correctness and for fit with
this document and the host contract, then revised. Merged, the scheduler's and the
function blocks' spikes pass the full gate together. Decisions 30–40 (§7) are what the
pass left to the maintainer. The rules below are its routine choices, taken as
recommended on 2026-10-02, grouped by item in the order they land. Where a rule changes
decided text above, that text is annotated where it stands. `PLAN.md` §3's Milestone 2
gives the commits and what is owed. The spikes are not in the repository: their figures
are receipts, and pin nothing.

**Throughout.**
- **The order** is decision 30's: M2-1, M2-5, M2-2, M2-3, M2-4, M2-6.
- **One stage** for a configuration's problems, `:configure`, which M2-1 adds to
  `%Logex.Diagnostic{}`.
- **Each item reserves its own words** in the configuration file (`.logex`): M2-2
  `program var_global at` (`bool` and `dint` are reserved already), M2-3 `task interval
  priority with`, and M2-6 `single`. Elixir data does not refuse a word before its item
  lands, and a message that names a word lands with that word, so no message offers a line
  the reader still refuses.
- **One message per rule.** Where Elixir data and the configuration file meet one rule,
  the message is in the configuration file's words, since the text is the saved form.
- **A configured plant is not edited until OE-2.** This is forced: OE-2 comes after
  Milestone 2, and `%Logex.Runtime{}` is opaque and changes only through the API (§4.9).
  `Logex.Edit` still edits a lone instance. *(Designed 2026-10-13, §4.9's "OE-2's
  design", decisions 55–65, and landed the same day: `Logex.Configuration.Edit` edits a
  running plant, writing the resource through `Logex.Runtime` alone.)*

**M2-1 · The scheduler, from Elixir data.** *(Landed 2026-10-02, as these rules
say. Two readings the landing made, each in `Logex.Configuration`'s moduledoc and pinned:
`check/1` raises one `ArgumentError` with every host mistake, a line each, where
`new!/1` gives its own problems first, then those, then the diagnostics; and decision
36's line is drawn by what a configuration's text can hold, so a name, location, type or
task the lexer does not read as one token, a negative or non-integer number, a global's
type other than `:bool` or `:dint`, and a connection whose instance and member make no one
path are the host's, while a name with `.` parts, an interval or priority out of range or
missing, and every unknown name stay diagnostics. The review of the landing added two
more, each pinned: an element whose name is refused, a duplicate, a case twin or a name
with `.` parts, still has every other field checked, as a `.ld` declaration line does;
and a configuration or an element that lacks one of its struct's keys is the host's, as
any value that is not the struct is.)* *(Changed 2026-10-14 by decision 97, M3-3: a line
can say a negative number, so only a number that is not an integer is the host's, and a
negative interval or priority is a diagnostic, in the file's words, as one too large is.)*
- *The §4.4 checks land here.* Every check M2-1's data can express, over tasks, globals,
  located points, program instances and connections, lands with M2-1 in
  `Logex.Configuration.check/1`, the one validator, pinned by whole diagnostic lists from
  data. M2-2 asserts each again as a whole list from source, and adds what only the text
  has.
- *The constructor.* `Logex.Configuration.new!/1` takes a keyword list (`name:`,
  `programs:`, `tasks:`, `globals:`, `instances:`, `connections:`) and raises every
  problem in one `ArgumentError`, a line each. `programs:` is a list given to `new!/1`,
  and a map by name in the struct. Each element is a struct of its kind, among them
  `Logex.Configuration.Task`, a name kept although it shadows Elixir's `Task` where a host
  aliases it.
- *The configuration.* It must have a name, and one with no program instance is refused.
  Tasks, globals and program instances share one namespace: a name that differs from
  another only in case is refused, and the first in line order keeps a name. A program
  type is named only in type position, so `program motor motor` is no clash.
- *Points.* A location is a device of one name, `i` or `q` in lowercase, then one or more
  whole-number fields with no leading zero, so each point has one spelling. One address
  holds one global. An output point takes no initial value, as an input point takes none.
  The case of device names is the one check over points that lands later, with M2-2's
  port of the checks (below). *(Landed with it, 2026-10-11.)*
- *Lines.* The elements' lines are all nil, as from Elixir, or strictly rising, so the
  data path refuses an order no file gives and the printer's round trip is exact. A line
  on an element from Elixir is refused for that element, as in ``task `t1` from Elixir has
  no line, got: 3``, before the rising rule is checked. Both are host mistakes, raised
  (decision 36).
- *Tasks.* An interval is 1 to 2147483647 ms, and a priority 0 to 65535, 0 the highest
  (decision 37). Every phase is anchored at 0, `start/1`'s `now`, so a first cycle that
  advances the clock reports the periods it spans, as §4.6's "anchored at start" says.
- *Warnings.* `%Logex.Configuration{}` has a `warnings` field, which lands empty with
  M2-1. M2-2 is the first to fill it, then M2-3, M2-4 and M2-6, each with its own below.
  A warning for a global something reads and nothing writes waits for `var_config`: until
  then an unlocated global used as a fixed parameter is legitimate.
- *Starting.* `start/1` runs `check/1` again, and builds each instance through
  `Runtime.instance/1` (fix F14). `%Logex.Runtime{}` is defined in `Logex.Runtime`, as
  `%Logex.Edit{}` is in `Logex.Edit`.
- *Reading.* `get/2` reads a global, any declared tag of an instance, a `var` included,
  or a public member of a function block instance. It never reads an internal member, an
  instance whole, a task or the configuration, and a path that names one of those is told
  which it names: `get/2` as `{:error, reason}`, `get!/2` as an `ArgumentError` (decision
  41). How deep it reaches is decision 33's. `next_due_in/1` counts periodic
  tasks only, not task-less instances, which a runner paces itself *(decided 2026-10-17
  by decision 108: back to back)*. An
  `{:overlap, task, missed}` event comes just before its task's scans.
- *Restarting* (decision 38). `restart/2` restarts each instance through `restart/3`,
  keeps the clock and the input image, puts every other global back to its initial value
  and every overlap count to 0, and makes every task due at the next cycle. There is no
  restart of one instance inside a resource.
- *New state.* CLAUDE.md's rule for new state in an instance extends to
  `%Logex.Runtime{}`: each piece gets a value from `start/1` and a rule for a cycle, for
  `restart/2` and for OE-2's switch, with the edit's exceptions listed. A global's one
  rule is `Logex.Configuration.initial/1`, its initial value or 0, beside
  `Logex.Program.initial_env/1` for a tag, and `Logex.Runtime`'s moduledoc holds the rest
  in a one-rule section. §4.9's "One rule for new state" lists the pieces. OE-2 adds the
  generation counter; M2-1 does not reserve it. *(Designed 2026-10-13: `generation` in
  `%Logex.Runtime{}`, on the resource only, decision 60, with `aside`, the instances an
  edit sets aside, §4.9's "OE-2's design". Landed the same day, each in `Logex.Runtime`'s
  one-rule section.)*
- *Not taken.* No `outputs` field on `%Logex.Program{}`, which would spare each scan its
  walk of the tags. Revisit it with the runner. *(Revisited 2026-10-17, §4.11: still not
  taken.)*
- *Cost.* A cycle and `next_due_in/1` are linear in the tasks declared, whatever is due;
  a queue by due time is the runner's to add if it is ever wanted *(revisited 2026-10-17,
  §4.11: not yet)*. A refusal of many bad
  keys against many names takes time quadratic in the two, from its did-you-mean pass, as
  the `.ld` compiler's refusals already do. That is accepted and documented, since only a
  host's own mistake pays it. Its message is linear in its problems, because each list of
  names is given once.
- *A landed message changes.* `put_inputs/3` and `call/4`, refusing several undeclared
  keys, list the var_inputs once, on the first line that needs them, as every runtime
  refusal then does. The test that pins that order past 32 keys is rewritten.
- *Done-when.* "Cycled every 10 ms from 0 to 990 ms" replaces "cycled for one simulated
  second", so that the counts are exact: 100, 34 and 100 runs.

**M2-5 · User function blocks** (after M2-1: decision 30). *(Landed 2026-10-04, as these
rules say, in seven commits, the excusal of a declaration whose type is unknown the sixth
and the documents the seventh (`PLAN.md` M2-5). Readings the landing made, each in its
commit and pinned: a user block's instance is "an instance of `seal`" in every message,
with no article chosen by the name's first letter, while the built-in timer stays "a
ton", and the one block-type message says "through `ton`" for it; `get/2` tells a block's
own `var` it is "a `var` of `seal`, hidden outside it"; a switch reports none of a
block's var_inputs as `:input` or `:unread`, since `cal` copies them in, and reports a
block's var_output whose initial value changed as `:initial_changed` by its path;
`compile_file/1` hands back the program's own warnings first, then each loaded block's in
the order compiled, and a block's own file only its own; a broken block's file stops the
file that names it, but every block that file names is still loaded, so each broken one
is reported; and a directory with a block's name "cannot be read".)*
- *A block's file.* Its header, `function_block <name>`, is the file's first rung:
  comments and blank lines may come before it, and the name matches the file's.
  `function_block` is recognised in any case and names no block, but a block's own name is
  not reserved, so `var seal seal` is legal. A block's file compiles to
  `{:ok, %Logex.FbType{}}`, whose body is a `%Logex.Program{}` named after the block.
- *One message for a block type given where a program goes,* at every entry point (the
  runtime, `Logex.Edit.accept/3`, M2-1's `check/1` and `new!/1`, `compile/3` and the
  loader): ``` `seal` is a function block type, which runs inside a program through `cal`:
  an instance is of a %Logex.Program{}```, with the configuration's prefix ``the program
  under `<key>` is`` where a key and a name differ. Until M2-5 lands, M2-1 gives interim
  words without `cal`. *(Landed: `Logex.Declarations.not_a_program/1` gives it, at the
  runtime, `accept/3`, `check/1` and `new!/1`; for the built-in timer it says "through
  `ton`". `compile/3` and the configuration's loader are M2-2's, which give it there:
  `compile/3` raises it for a block type among its programs, and
  `Logex.Configuration.compile_file/1` gives it as a located diagnostic at a `program`
  line that names a block's file, since 2026-10-11.)*
- *Types given.* `Logex.compile/2` takes `types:` (decision 34), and its options message
  names it. A block's name is matched exactly, as a tag's is. One compile holds one
  version of each block name, across the types given, the types they hold and the types of
  tags declared from Elixir; two versions that differ only in their warnings are one.
  Every compile checks each type it is given at full depth, and exactly: its members are
  those its body declares, and its body's rungs lower again through the compiler's own
  checks to themselves, so a hand-edited type is an `ArgumentError` where it is given,
  never in the runtime or an edit. That is forced by decision 28 and by §4.9's "the data
  API refuses anything the text cannot say". No mark of an earlier check is trusted, so a
  chain of N blocks built one at a time costs O(N²). *(As landed, with the fix that
  followed M2-5's review: two versions are one where they differ only in their warnings
  or in the file their body was read from, under any spelling of its path, which stamps
  each warning; two whose source text differs, if only in a comment, are two.
  `Logex.FbType.same?/2` is that one definition, for a compile and for `user?/1` alike,
  so a block given both versions of a block it holds is a type a compile gives. Each
  distinct type is checked once a compile, an instance declared from Elixir included,
  and the tags declared from Elixir are one version with every block the types given
  hold, at any depth. Narrowed after the check of those fixes: a type edited by hand into
  one a compile gives over its tag table, a rung changed into another that text could say
  with its source text left as it was, is no `ArgumentError` where it is given, since
  `user?/1` checks the shape `Logex.Compiler.lowered?/1` defines and never compiles the
  source again; it is a version of its own, which the one-version check refuses beside the
  genuine one. Whether `user?/1` is to compile the source again is left to the
  maintainer, `PLAN.md` M2-5. Since decision 53, a type's one table holds each type
  once, so `user?/1` checks each once a call, and a compile given several types checks a
  type their tables share once, over the same types it names
  (`Logex.FbType.check/2`), so that it stays linear in the distinct types.)* *(Changed
  2026-10-05 by decision 54: "a hand-edited type is an `ArgumentError` where it is given"
  holds exactly. Each type a compile is given, and each type its one table holds, is
  compiled again from its body's source text, once a compile, as a block of its name,
  over the types its instances name as the table holds them, each compiled again before
  any type that names it, trusted and not checked again
  (`Logex.Compiler.recompiled/4`), and must be exactly what that compile gives: its
  members, and its body's name, rungs, tag table and warnings. The one thing the text
  cannot give is the file a body was read from, which is kept: none, or a path to a file
  named after the block, which stamps each warning. So a rung edited into another that
  text could say, a tag table edited into one declaration lines could give, a source text
  edited with its body left as it was, or a file that is no such path, is refused where
  it is given; a source text that gives that very body, a comment more, is the type a
  compile gives for it. *(Changed 2026-10-11 by the maintainer's answer: a block that
  `Logex.Compiler.instructionize/3` builds, its members perhaps declared from Elixir,
  keeps a source text with each rung printed on the line it was parsed from, and its
  members from Elixir, the tags with no line, are handed to the recompile again, so it is
  a type a compile takes, as M2-5's third commit had it. A type with no source text at
  all is refused where it is given.)* The shape check is gone from `user?/1`:
  `Logex.Compiler.lowered?/1` stays the definition of a compiled body, which a type
  given has, but nothing calls it on the way in. A compile given a type took 1.19x the
  reductions it took before for one block of 200 rungs, and 1.31x for a chain of 200
  types; both stay linear.)* *(Corrected after the check of decisions 53 and 54: "each
  distinct type is checked once a compile, an instance declared from Elixir included"
  held for the types given, whose checks share one memo (`Logex.FbType.check/2`), but each
  tag declared from Elixir checked its type with a memo of its own, so a type the tables
  of several tags' types shared was compiled again for each: 68 compiles again for tags of
  4 types sharing a chain of 16, 20 distinct types. The tags now share the compile's memo,
  after the types given, so the sentence, and decision 54's "once a compile, however many
  types and paths hold it", hold for them too: 20 compiles again. A tag's type that is,
  by value, the type given under its name, or the one a tag before it held, is known
  without a check; `Logex.Tag.new!/4`, a call of its own, checks its type again.)*
- *Held types.* A member that holds an instance names its type, `{:block, name}`, and the
  holder's body's tag table holds that type once, so a type copied flat is linear in its
  depth. A member's type gains that form. *(As landed, after M2-5's review found the type
  held once per instance tag, so that a body holding two instances of one block, nested,
  grew as the width to the power of the depth, and the maintainer's decision of 2026-10-04
  to build it as recorded: each instance's tag in the body names the type too, and the
  body's `%Logex.Program{}` holds each type once, by name, in `blocks` beside its tags,
  which `Logex.Program.typed_tags/1` reads back as the table a compile works over. A
  type copied flat then grows linearly in its depth, however many instances of the type
  below each level declares, as `function_block_test.exs` pins, wherever each type is
  reached through one holder. A type reached through more, as when each level has two
  types and each holds both of the level below, was written out once per path of
  holders, so copied flat it still grew as 2 to the power of the depth, as an instance's
  state does: 36,405 words at 6 levels and 2,354,805 at 12, against an instance's state
  of 176,118. "Linear in its depth" held for the first shape only. A block's compiled body
  run as a program is read through `typed_tags/1` too, by the runtime, `get/2` and an
  edit, as a compile reads it.)* *(Changed 2026-10-05 by decision 53: each type is held
  once per outermost type. The type a compile gives, and a program, hold every user block
  type their instances reach, at any depth, once, by name, in one table, `blocks`, each
  held with no table of its own (`Logex.FbType.held/1`), and every instance's tag at any
  depth, a program's own among them, names its type. A type copied flat then grows with
  the number of distinct types it holds, whatever the shape: 4,645 words at 6 levels of
  that diamond and 9,313 at 12. A type read inside the table, by
  `Logex.FbType.type_of/2` and `Logex.Program.typed_tags/1`, is given the table
  (`Logex.FbType.within/2`), so that the types below it are found there, and a `cal`
  hands its body the program's table. The built-in `ton` is in no table: each timer's tag
  holds it. A program's own tags no longer hold each type itself: a host reads a
  program's types in its `blocks`, and gives a compile the types a compile gave it, since
  a held type that holds instances carries no table of its own.)* *(After the check of
  decisions 53 and 54: a type read inside the table carries the whole table, shared in
  memory, so a value that keeps types so read, rather than reading them where it needs
  them, is written out once per type kept by a copy that keeps no sharing. An edit's
  plans kept them so, until that check; §4.9's "Cost" records it.)*
- *Declarations.* Members declared from Elixir come first in `cal`'s operand order, by
  name, then the declaration lines in order. The uses of a declaration whose type is
  unknown are excused, as a recursive declaration's are, so a misspelled block name gives
  one message; this lands in its own commit, after M2-5. *(Landed as M2-5's sixth commit,
  before its documents, a departure from "after M2-5" made so that the documents commit
  describes it with the rest: a line given the unknown-type message, or refused as
  recursive, excuses every use of its own name, as written; a line refused for another
  reason excuses nothing.)* *(Since decision 54 such a block is compiled again from the
  text `Logex.Compiler.instructionize/3` keeps for it, its members from Elixir handed to
  the recompile, so it stays a type a compile and `Logex.Tag.new!/4` take; this order
  holds for its members there too.)*
- *`cal`.* Its `@instructions` entry is the marker `{:cal, :block}`, so that table still
  reserves it and the naming test still sees it, and its signature is the block's, built
  per compile. `cal` is reserved in every `.ld`, in any case. One `cal` runs an instance:
  a second is refused at its line, citing the first.
- *Members:* decision 33.
- *Running a block.* The runtime fills a new `tags` field of `%Logex.Scan{}`, which a
  host may not fill, and `cal` hands its body the scan narrowed to its instance: the
  block's tag table and its own part of the blocked one-shots, with the program
  instance's `now` and `first`. So the scan is the same for every instruction of one
  routine run, not of one call. Since `first` is the program instance's, a block frozen
  on the first scan fires its one-shot the first time it runs, as `PLAN.md` M2-5's note
  from M1-6 says. *(Since the held types above landed, the scan also carries the routine's
  `blocks`, which a host may not fill either, and `cal` narrows both to its block's. Since
  decision 53, `blocks` is the program's one table, which `cal` hands its body whole.)*
- *Walks.* M2-5 adds one `cal` clause to each IR walk it meets. B5's one walk comes with
  M2-4. *(Landed as one lookup the walks share, `Logex.Compiler.signature/2`, an
  instruction's slots given its program's tag table, a `cal`'s its block's.)*
- *The edit, by path* (decisions 31 and 32). A block's type, for the edit, is its name
  and its members' kinds: its body may change, members may be added or dropped, and a
  member whose kind changes is refused by its path. Inside an instance both programs
  declare, each member moves by OE-1's rules, by path: a member the state lacks starts at
  its initial value, `{:added, "p.count", 7}`; a kept one whose initial value changed is
  reported as `:initial_changed`, decision 29 applied by path; assemble and cancel prune
  by path. Two rules are forced:
  - an `ons` inside a block is blocked where any rung on its chain, from the program's
    `cal` rung down to the body's `ons` rung, is new or changed, each `cal` keyed by its
    operands and the formals they fill. A calling rung is on that `ons`'s path, and
    comparing the body's rung alone gives the false pulse decision 21 prevents;
  - a timer inside a block resumes only where the program the switch stops does not run
    it, read from that program's text, and is the program that last scanned, as fix F3
    asks for one-shots. A timer both programs run that a false `cal` froze catches up when
    the block next runs (decision 8). At the top level this is what "a `last` before
    `now`" said, so OE-1's behaviour is unchanged.
- *Loading* (decision 34). The loader stops at a broken block file and reports its
  mistakes with its file; the file that names it is compiled no further, as a lex or
  parse error already stops a compile.
- *Fix F15* goes to M2-5, the first item that meets it: `%Logex.Program{}` gains a
  `file`, which `compile_file/1` sets and `Logex.Edit`'s diagnostics carry. Two
  conventions are stated together: a block file's diagnostics carry that file in `file`;
  a configuration's diagnostic stays in the configuration's file and names a program
  type's file and line in its text, as in `on line 8 of motor.ld`. *(Landed:
  `compile_file/1` sets `file` on a program and on a block's body, and every `:edit`
  diagnostic carries the candidate's. The configuration's half of the conventions lands
  with M2-2.)*
- *A landed message changes:* "only an instance of a function block has members" replaces
  "only a timer has members".
- *Naming.* The `function_block` and `cal` stanzas call the conventional family's
  reusable blocks "user-defined instructions", not by the family's own term.
- *Done-when* as decided, its `m1.s2.run` read through M2-1's `get/2`. *(Landed:
  `end_to_end_test.exs` asserts `Logex.Runtime.get(rt, "m1.s2.run") == {:ok, 1}` through
  a configuration, from text and from files on disk through `compile_file/1`.)*

**M2-2 · The configuration file, task-less.** *(Landed 2026-10-11, as these rules;
`PLAN.md` M2-2 gives the commits and the readings the landing made: the loader is
`Logex.Configuration.compile_file/1`, through `Logex.compile_files/1`.)*
- *The file* is a configuration file (`.logex`, decision 35), read by a recursive descent
  over `Logex.Lexer`'s tokens: a line-shape mistake has a column, and the `.ld` grammar,
  its golden record and the printer's shapes are untouched. A line ends at LF, CRLF or a
  lone CR, as the lexer gives it.
- *The seam* is `Logex.Configuration.compile(name, source, programs)`, as §4.4 decided,
  beside M2-1's `new!/1`. M2-2 lands a printer from a configuration to its text, with an
  exact round trip: an entry with a line is printed on that line.
- *The checks.* The configuration file's own checks become rows of M2-1's `check/1`, in
  the file's words, rule by rule, and every M2-1 check is asserted again as a whole list
  from source. An unconnected var_input gives one diagnostic per instance, listing its
  members. Two device names that differ only in case are refused, as two names that
  differ only in case are; this lands with the port of the checks, the one check M2-1's
  data can express that M2-1 does not land, and no spike built it.
- *Citing a program type.* A program type's mistake, such as a `var_external` with no
  global, is cited once a type, at its first instance's `program` line, with the type's
  `.ld` file named in the text.
- *Names.* Names resolve over the whole file, so a connection may come before its
  `program` line: the decided plant names `estop` before it declares it. A name refused
  as a keyword or for its `.` is reported once, and nothing that names it is reported
  again. A duplicate or a case twin is not recovered that way: its later uses are checked
  against the first declaration, as on a `.ld` declaration line.
- *Loading.* `Logex.compile_file/1` takes only a `.ld` path, exactly, as a gate in front
  of M2-5's loader. The configuration's loader resolves each program type through that
  loader, with one memo for the whole configuration, so a block two program types hold is
  read and compiled once; a `program` line that names a block's file gets the one
  block-type message, as a located diagnostic.
- *Warnings:* a global nothing uses; an output point that something reads and nothing
  drives.
- *A location in a `.ld` rung,* an operand shaped like one whose first part is not
  declared, is named as a location (§4.7).
- *Cost.* The configuration file's checks pay what M2-1's refusals pay: a source with many
  mistaken names against many declared ones takes time quadratic in the two, from the same
  did-you-mean pass, as the `.ld` compiler's refusals already do. That is accepted and
  documented, since only a mistake in the source pays it.

**M2-3 · Periodic tasks in text.** *(Landed 2026-10-11, as these rules; `PLAN.md`
M2-3.)*
- `task <n> interval <ms> priority <p>` and `with`. A task's inputs come in IEC's order,
  `single`, `interval`, `priority`, each once. A priority is 0 to 65535 (decision 37),
  and the `priority` stanza says that one vendor family numbers the other way.
- *Warning:* a task that runs no instance.
- *Done-when.* "Cycled every 10 ms from 0 to 990 ms" replaces "driven for one simulated
  second".
- Its documents state decision 40's rule, which OE-2 builds. *(They do: an interval OE-2
  changes makes its task next due at `min(next_due, now + new interval)`, in the
  `interval` stanza of `docs/naming.md` and in `Logex.Runtime`'s one-rule section, and
  nothing builds it before OE-2.)*

**M2-4 · Shared globals.** *(Landed 2026-10-12, as these rules; `PLAN.md` M2-4 gives the
commits. Readings the landing made, each pinned: the walk is `Logex.Walk`, whose
`writes/1` and `timers/1` reach into each block a `cal` runs by path, `p.s.t1`, with the
lines of the block's own text, each block type read once a call; the writer warnings'
storage-bit words are given wherever any writer's `ons` keeps its bit in the global,
whoever the other writer is, as a fact of the global; a `var_external` line refused for
its initial value declares nothing, as a `var_input`'s does; and a `var_external` never
names a global refused for its name, so decision 42's silence has no case here; one that
names a broken `var_global` line is silent, the line's diagnostic the one mistake, which
M5-1's review found raising and fixed.)*
- *One IR walk first.* B5's one walk of a program's IR lands as M2-4's first commit,
  before any check that reads a program's writes or timers. It answers "which tags a
  program writes" and "which timers it runs" as public functions over the IR, not as a
  field of `%Logex.Program{}` that a hand-built program could get wrong. It knows `cal`,
  counting a `cal`'s output operands as writes, and reaches block bodies.
- *One copy of each global.* The scheduler merges each `var_external`'s global into its
  instance's env before `call/4`, and splits it off after. `call/4` is unchanged, and
  between scans the only copy is the resource's. A program run alone keeps a
  `var_external` as its own tag, at 0, which its host cannot set. `get/2` reads
  `m1.estop` as the global.
- *Checks.* Each instantiated type's `var_external` has a global of its name and type,
  checked once a type, and nothing writes an input point through a `var_external`.
  Warnings: two instances that write one global through `var_external`; and an instance
  that writes through `var_external` a global a connection drives, a warning by §4.4's
  rule, since only the IR shows it.
- *In a block's file,* `var_external` is refused with a located diagnostic. That departs
  from IEC, which allows it, deliberately and reversibly (§4.8): a block takes a global
  through a var_input operand.
- *Settled by the run-time spike, 2026-10-04* (decisions 46–49 and these):
  - the copy-out of a connection lands after the `var_external` is split off (decision
    47), and visibility otherwise follows the scan order, with no rule of its own;
  - a `var_external` named in a connection gets its own message: it reaches the global
    itself, so only a var_input or var_output connects;
  - a lone instance's `var_external` is its own tag at 0, refused as an input and reset to
    0 by `restart/3`: exactly a one-instance configuration with an unlocated global of no
    initial value that no other instance uses, which `Logex.Runtime`'s moduledoc and §4.6
    say beside "`scan/2` and a one-line configuration give identical outputs";
  - the write check on an input point is made once a program type, at its first instance,
    naming the type's file and the line of the first write, so the IR walk gives each
    written tag its first line;
  - M2-2's warnings for a global nothing uses and an output point nothing drives count a
    `var_external` of an instantiated type as a use, and a write through one as driving;
  - `get/2` reads a `var_external`'s path as the global directly;
  - a `var_external` may not be named like a word the configuration file reserves, as
    `Logex.Configuration.Text`'s list stands when M2-4 lands; M2-6's commit names
    `var_external single` among the names it breaks; *(M2-6's fourth commit names it, and
    no name in the repository breaks)*
  - the two warnings go through M2-2's warnings pipeline, which `start/1` never reads,
    with each connection's instance found through an index made once, so checking stays
    linear in the instances;
  - "one copy" is pinned by a test that looks inside the resource (decision 49).

**M2-6 · Event tasks.** *(Landed 2026-10-12, as these rules say, in eight commits: the
survey, the data and the run time, the Done-when from data with the contract walk, the
task lines, the warning, the Done-when from source, Milestone 2's done sentence, and the
documents. The
readings the landing made, each in `Logex.Configuration`'s or `Logex.Runtime`'s
moduledoc and pinned: a task with neither an interval nor a single is offered both, its
example naming the task only where its name is one, and a task with no priority is shown
one of its own kind, named so too (since the review); an event task's interval of 0 is told
to leave it out; a single's value on a task line is any name token but an input's word;
the ton warning is one a timer, at its instance's line, citing the `ton`'s own file and
line, each program type's timers read once; and a decision-52 cycle counts the periods it
missed as any late periodic task does.)*
- *`single` with `interval`:* decision 39. A task with `single` alone never overlaps.
- *The tie-break.* An event task's due time, for the earlier-due-time tie-break, is the
  cycle's `now`, since §4.6 step 3 makes it due on the edge seen in this cycle. A late
  periodic task of the same priority therefore runs before it, and one due exactly at
  `now` ties and falls to declaration order. A test is owed: an event task and a late
  periodic task of one priority, both writing one global, asserting which write lands.
- *The trigger across a restart and an edit.* A restart sets an event task's last sample
  to 0, so a trigger already 1 fires again; an edit keeps it, so a switch fires no event.
  Changing a task's `single`, or adding or removing an event task's `interval`, is
  refused while running.
- *Warning:* a `ton` in a program an event task runs, whether the task has `single` alone
  or with `interval`, a `ton` inside a block the program's `cal`s run included (§4.6's
  caveat).
- *Settled by the run-time spike, 2026-10-04* (decisions 50–52 and these):
  - `next_due_in/1` counts periodic due times only, and the host's loop cycles at once
    after `start/1` and `restart/2` whatever it says (decision 50);
  - an edge run's due time, for the tie-break, is the cycle's `now`, also for a task with
    `interval` whose periodic due time came in the same cycle, since decision 39 skips
    that due time;
  - a late host's edge cycle skips, and does not count, the due times since the last
    sample (decision 51), and a falling cycle runs a due time that came while the image
    held 1 (decision 52);
  - the owed tie-break test is written in both forms: two writers of one global through
    `var_external` (M2-4 lands first) in `end_to_end_test.exs`, and, beside the rule
    tests, one instance writing a global that another copies to an output point; *(M2-4
    wrote the first form's shape in `end_to_end_test.exs`, two writers of one global
    through `var_external` in one task, the later write standing; the tie-break between
    an event task and a late periodic one waits for M2-6)* *(Landed with M2-6, in both
    forms: `end_to_end_test.exs`'s two writers of one global, and `scheduler_test.exs`'s
    copier.)*
  - `Logex.Configuration.Task` enforces `name` and `priority` only, and a test pins the
    enforced keys;
  - an unknown `single`'s did-you-mean is among the bool globals; an example in a message
    names the task only when its name is one; a dotted `single` gets M2-2's readings of a
    location or an instance path;
  - `overlaps/1` lists an event-only task at 0, and no new event kind is added;
  - a trigger nothing can raise, an unlocated global that nothing writes, fires once a
    start if its initial value is 1 and never otherwise; the documents say so, and the
    warning waits for the one for a global read and written by nothing, with `var_config`;
  - the one contract walk draws event tasks too, its oracle counting skipped periods, and
    asserts its reach;
  - the commits land data and run time first, then the text (PLAN M2-6).

### 4.11 Milestone 4's design: the wall-clock runner (decided 2026-10-17)

**Designed and decided 2026-10-17; M4-1 landed the same day** (`PLAN.md` M4-1): the
clocks, `Logex.IO` with `%Logex.IO.Point{}`, `points/1` and `bind!/2`, and `Logex.IO.Sim`.
A design pass on `d3931bd`, on Elixir 1.20.4 / OTP 28 on a four-core Linux container,
answered §5's "Wall-clock runner, `Logex.IO` adapters, watchdog", §4.5's adapter sketch,
§4.6's "the watchdog belongs to the wall-clock runner", §4.10's two notes to revisit with
the runner and decision 14's "decide with the runner". A throwaway spike built every
piece, on the branch `backup/runner-design` (`spike-runner/`), never to land: its figures
are receipts and pin nothing. The maintainer answered its questions on 2026-10-17,
changing three: rounds run back to back with a share kept for the runner's own work
(decision 108), and the watchdog is 500 ms unless set (109) and each task's own (110). Two
more the maintainer asked outside the questions put: a configuration may declare its
continuous task (111), and a device may report its inputs' changes (112); and on
2026-10-18 a third, forces kept in a file across a crash (127). The rest were taken as
recommended (113–117). Decisions 118–121 are this record's routine choices, each with the
alternative it passes over, and so are 122–126, taken on 2026-10-18 after M4-1's review
found the record silent on how rounds run on a clock that does not move, on a trigger
logic writes and on where a test waits, and loose on the heartbeat's margin and on what a
round's trip names; the rest of this section is routine too, each choice with its reason.
Where a rule changes decided text above, that text is annotated where it stands. `PLAN.md`
§3's Milestone 4 gives the items and their order.

**Words.** A *round* is a cycle the runner makes on the clock: it takes the inputs, runs
the timed tasks that are due and then the untimed programs through `cycle/3`'s rules, and
writes the outputs. A *timed task* is one with an interval, a single or both. The
*continuous task* is the one that runs the untimed programs, IEC's programs with no task
association (Ed 2 §2.7.2 rule 4) and the conventional continuous task. The runner's *own
work* is everything else it does: the host's calls, an edit's steps, the subscribers, and
the care of its devices, opening, refreshing and zeroing them.

**What it is.**

| Piece | Kind | What it does |
|---|---|---|
| `Logex.Runner` | GenServer, one per resource, under the host's supervisor | Owns the `%Logex.Runtime{}`, the clock, the rounds, the devices, the watchdogs, the forces, the subscribers and the current edit |
| `Logex.Runner.Device` | GenServer, one per bound device, linked to the runner, trapping exits; internal | Holds one adapter's state; reads it every poll period and takes its reports; writes each round's outputs; refreshes them; zeroes them once and latches on a trip, on its heartbeat, and when the runner dies |
| `Logex.IO` | behaviour, with `%Logex.IO.Point{}` | The adapter contract (below) |
| `Logex.IO.Sim` | adapter, with a small process of its own | An in-memory device for tests and demos, which can report its changes and act out each failure |
| `Logex.Runner.Clock` | behaviour | `now_ms/1`, `wake_at/4` and `cancel/2`, so that a test can move time |
| `Logex.Runner.Clock.Monotonic` | the default clock | `System.monotonic_time(:millisecond)` and `Process.send_after(pid, msg, at, abs: true)` |
| `Logex.Runner.Clock.Manual` | a clock a test moves | `advance/2` delivers each timer due on the way, in time order, and returns once each receiver has handled its message; `pass/2` moves time inside a step |

It lives in logex and uses only OTP and Elixir's standard library, so logex keeps no
dependencies; an adapter for real hardware, Modbus TCP or a GPIO board, needs libraries
and lives in the host's application or a package of its own, logex shipping only
`Logex.IO.Sim`. It starts no application (`mix.exs` has `application: []`, `PLAN.md` B6):
the host starts it under its own supervisor, its `child_spec/1` `restart: :temporary`
(decision 115). It logs nothing, since everything it knows goes to its subscribers.

**The core stays pure.** The runner is the only code in logex that reads a clock. It calls
`Logex.Runtime`'s public API, `Logex.Configuration.Edit`'s steps, and two public rules,
`Logex.Configuration.location/1`, to route each point to its device, and
`Logex.Declarations.fits?/2`, to check each value a device gives. The core gains two
things only: the configuration's words for a task's watchdog and the continuous task
(decisions 110 and 111), and the cycle in steps, internal as `edited/2` is, so that the
runner can time each task's run (decision 118). `cycle/3` and the host contract do not
change; a host that drives the resource itself loses nothing.

**The configuration's words** (decisions 109–111). A task line takes `watchdog <ms>`
after its priority, 1 to 2147483647 ms, an interval's range, and 500 ms where it has none:
`task fast interval 10 priority 1 watchdog 50`. One line may declare the continuous task,
`task main continuous`, with a watchdog or none and no interval, single or priority; a
program with no `with` runs in it, and one may name it, `program boxes counter with main`,
meaning the same. Each word owes its `docs/naming.md` stanza before its code (CLAUDE.md,
step 1), and a stanza may still change a spelling. *(Landed with M4-2, 2026-10-18, as
written, the spellings unchanged: `continuous` straight after the task's name and before
IEC's inputs, `watchdog` after them, each once; `Logex.Configuration.watchdog/1` the one
rule for a task's watchdog; a continuous task's instances run in a cycle with the
task-less ones, last, under its name, never due and listed at 0 by `overlaps/1`; and a
watchdog's rule across an online edit is decision 129's.)*

**Rounds** (decisions 108 and 122).
- While the configuration has untimed programs, rounds run back to back, in all the time
  the timed tasks leave, as IEC's rule 4 and the conventional continuous task have it, to
  the clock's resolution (decision 122): a round starts at a millisecond of the runner's
  clock, and the next starts at the millisecond after the one it began in, or at once
  where it took a millisecond or more, a wake on the clock either way. So at most one
  round runs a clock millisecond, on the monotonic clock and the manual one alike, and on
  the manual clock `advance(clock, n)` runs exactly n rounds; up to one core is kept busy,
  all of it only where rounds fill their milliseconds.
- A share of the time, `overhead:`, 20% unless set, is kept for the runner's own work,
  the conventional system overhead time slice's rule (the tasks, programs and routines
  manual, pp.31–33): of the time the runner spends on the continuous task's programs and
  on its own work while both have work, its own work gets the share, the timed tasks' runs
  left out of both, as the conventional rule leaves out periodic and event tasks (p.13).
  It is served in slots: after C ms of the continuous task's rounds the runner serves its
  own work for up to S ms, C = max(1, round((100 − p)/p)) and S = max(1, round(p/(100 −
  p))) for a share of p%, 9 and 1 at 10%, 4 and 1 at 20%, 1 and 1 at 50%, 1 and 9 at 90%,
  the conventional table (the design considerations reference, p.35). A round counts from
  its start to the next round's, a millisecond at least; a request is served whole, so a
  slot can run over by one request; with nothing of its own to serve the runner goes back
  to rounds at once (p.33); and in the rest of a millisecond a round did not fill it
  serves its own work freely. On the manual clock a round fills no time unless something
  passes time inside it, so own work waiting is served before the next round.
- A due timed task runs at the start of the next round, its first step, never preempting
  one, since logex never preempts (§4.6): a round is one `cycle/3`, its due timed tasks
  first and then the untimed programs, each once. A task that falls due while a round is
  in progress waits for it to end, so a long untimed round delays a due timed task; a
  delay of a whole interval or more is counted and reported as an overlap, as any late
  period is.
- With no untimed program a round comes only when a timed task is due or an event's
  trigger changes (decisions 112, 120 and 123), and the share has no effect, as the
  conventional one has none without a continuous task (p.31): the runner serves its
  mailbox whenever it waits.
- The first round runs at once after start and after a restart, whatever `next_due_in/1`
  says (decision 50).
  *(Landed with M4-3, 2026-10-18, as these bullets say, with two readings the record
  left: a slot serves its first request whatever the time, so that a slot whose start
  is read late still serves one, "each served whole"; and a host's request is served at
  once where no round is owed, so that on the manual clock one made while a round is
  owed, after a round that passed time, waits for its slot. `stop/2` is served at once,
  whatever the share. After M4-3's review the same day: the slot comes at the end of the
  round that completes its C ms, so that on the manual clock it comes in the advance
  that runs that round, `advance(clock, 0)` among them, never later, and a test makes
  such a call from another process (decision 131); every device is refreshed before the
  runner serves its own work, in the rest of a millisecond too where a request waits;
  and "a round counts from its start to the next round's" is built as from its start to
  its end, a millisecond at least, the two the same but where the runner's own work, a
  request served in the rest of a millisecond, runs past the millisecond: that time is
  the runner's own, and counting it as the round's would bring the next slot sooner and
  give its own work more than its share. A continuous line that runs no instance times
  no round, its watchdog timing nothing, as decision 111 says, so a round of timed tasks
  alone is no round of the continuous task's, which M4-4's round watchdog reads.)*
- The runner keeps `anchor`, the monotonic millisecond its clock counts from, and
  `logical`, the sum of the `elapsed_ms` it has passed, the resource's `now`. Each round
  passes `elapsed = (wall - anchor) - logical`, never negative, so rounding to whole
  milliseconds never accumulates; it sleeps to absolute deadlines, `anchor + next`,
  never relative ones, which drifted 7% in the spike; and after a stop or a trip it sets
  `anchor = wall - logical`, so the stopped time is not counted and the first round after
  a restart gets 0 ms, rather than reporting every period of the outage as missed.

**Devices** (decisions 112, 114 and 120). A point is a global with `at`: its device is the
location's first part, its direction `i` or `q`, its address the integer fields, read by
`Logex.Configuration.location/1`. OE-2's accept refuses a location added, removed or
moved, so the binding is fixed for the runner's life (§4.9, "logex binds devices only at
start"). The host binds each device by name, `io: %{"panel" => MyApp.PanelIO, "drive" =>
{MyApp.ModbusIO, host: "10.0.0.5"}}`; a device the points name that no adapter is bound to,
and a bound device no point is at, are the host's mistakes at start (§4.5).
- **Reading.** Each device's process reads its adapter every poll period, 10 ms unless
  set, and an adapter that can report a change as it happens passes each one on between
  reads, as the conventional input module sends its data at its requested packet interval
  and on a change of state (decision 120). The device passes what changed on to the
  runner by a call (decision 124); the runner checks each value with `fits?/2` and its
  address against the device's input points, and merges them into the next round's
  inputs, taken as the round starts whatever the share, so every round sees one sample of
  every device. A change of an event task's trigger that a device reports makes a round
  at once where none is running, each change its own round, and the runner answers the
  device once that round has run and its outputs are written, otherwise once the change
  is merged; while it waits the device answers the runner's own requests to it, so that
  neither waits on the other. A change of a trigger that logic writes, read after each
  round, makes its round at the next clock millisecond, a wake as a back-to-back round
  is, so that two event tasks that write each other's trigger cannot hold the runner in
  rounds that take no time (decision 123).
- **Writing.** After each round the runner gives each device whose outputs changed its
  output points, every one by address, and waits for its answer, which the device gives
  once its adapter has written them; every device is refreshed with the outputs it last
  had, without a wait, before every step and at least once a poll period while the runner
  waits, each refresh carrying its next deadline (decision 125), so a device's own
  loss-of-master state is never reached while the runner runs. *(Landed with M4-3,
  2026-10-18: a refresh is a message to the device's process carrying its deadline, and
  calls no adapter; the adapter is written where its outputs changed and read every poll
  period. Whether a refresh should also write the adapter again, so that a device whose
  outputs never change still hears from its master, was put to the maintainer, who
  answered the same day, decision 130: each device writes its last outputs again at its
  poll, while its last refresh's deadline has not passed, a device never written, one
  with no output point among them, writing nothing; so the refresh carries the deadline
  and the poll the outputs. After M4-3's verification decision 132 made a poll in a
  round's millisecond leave its write to the round; the maintainer answered it the same
  day, "Fixed timer as Logix", superseding it and decision 130's "where nothing was
  written within a poll period": each device writes its last outputs again at every poll,
  on its poll grid, whether or not a round wrote to it within the period, as Logix
  re-sends outputs at the RPI, and the rounds write as before, so a device costs one
  adapter write a poll period beside each round's.)*
- **Order.** Devices are opened, written and zeroed in device-name order, one after
  another, so a run is deterministic; in parallel is later, once a real network adapter
  has been measured. *(A tie, noted after M4-3's review: a device's poll that changes an
  event task's trigger and a round due at the same millisecond come in the order their
  wakes were set on the clock, which the refreshes' wakes shift, so either may go first;
  both orders keep every rule here, and a run on the manual clock still repeats exactly,
  the order being the same from fresh processes.)*
- **Failing.** Each callback runs in its device's process, guarded, so a raise, a throw or
  an exit is an `{:error, ...}` there. An error returned, a raise, a value that does not
  fit, an unknown address, no answer within the device's deadline, the one its last
  refresh carried (decision 125), and its process going down are each an I/O fault, which
  trips the runner (decision 114). A device stuck inside its adapter is killed and opened
  again at the next restart; its outputs cannot be zeroed from software, and are what the
  device does on losing its master.

**The adapter behaviour**, §4.5's sketch revised so that every callback can fail without
raising, a device can report its changes and be closed:

```elixir
defmodule Logex.IO do
  @type address :: [non_neg_integer]           # panel.i.1.3 -> [1, 3]: location/1's third part
  @type values :: %{address => integer}
  # %Logex.IO.Point{name: "pb_start_1", direction: :input, address: [0], type: :bool}

  @callback init(device :: String.t(), [Logex.IO.Point.t()], opts :: keyword) :: {:ok, state} | {:error, reason}
  @callback read(state) :: {:ok, values, state} | {:error, reason, state}
  @callback write(values, state) :: {:ok, state} | {:error, reason, state}
  @callback report(message :: term, state) :: {:ok, values, state} | {:error, reason, state}
  @callback close(state) :: :ok
  @callback check(device :: String.t(), [Logex.IO.Point.t()], opts :: keyword) :: [String.t()]
  @optional_callbacks report: 2, close: 1, check: 3
end
```

- `init/3` runs in the device's process, which is what an adapter that reports arranges
  to be sent its device's messages to: a port's, a socket's, a process of its own.
- `read/1` gives values for some or all of the device's input points; the image keeps
  them, so an adapter may give only what changed (§4.6, step 2).
- `write/2` is given every output point of the device, by address, a snapshot, so an
  adapter may skip those that did not change; it returns its state, so a connection can
  be opened again inside it.
- `report/2` is called with each message the device's process receives that is not the
  runner's, and gives the inputs it says changed, `%{}` for one it does not know; an
  adapter without it is only read.
- `close/1`, optional, is called once, after the last write of zeros.
- `check/3`, optional, is given what `init/3` will be, in the host's process, when the
  bindings are checked at start (`Logex.IO.bind!/2`), and gives the host's mistakes in the
  options, a line each; it reaches no device, so a typo in a host's options is an
  `ArgumentError` in the host's process rather than `{:io_init, ...}` or an I/O fault, the
  plant's state. *(Added on 2026-10-18, after M4-1's review, which found `{Logex.IO.Sim, []}`
  taken at bind time and refused only inside `init/3`, in the device's process.)*

**The simulated device.** `Logex.IO.Sim` is an adapter whose device is a small process the
test owns, `Logex.IO.Sim.start_link/1`, bound as `{Logex.IO.Sim, sim: sim}`: `set/2` and
`set/3` set its inputs, `outputs/1` gives the last value written to each output,
`writes/1` every write in order, so that "zeroed once" can be asserted, `reads/1` the
reads made, and `closed?/1` whether it was closed. Started with `reports: true` it
reports each change of an input to the device that opened it, the inputs one `set/2`
changes as one report, and an input set to the value it had is no change. `fail/3` acts
out one failure on the next call of the callback it names: an error, a raise, a throw, an
exit, a hang, a delay, on the manual clock it was started with or else in real time, or,
for a read or a report, a value of the test's choosing. A sim is one device's: another
device's process opens it only once the first has closed it or gone down, which its
`check/3` says at start where it can and its `init/3` where two open it at once. It is
the fixture of every runner test, and README's example runs on it. *(Corrected on
2026-10-18, after M4-1's review, which found that this paragraph said the sim reports
each input it is set to, where it reports changes, and a value of the test's choosing for
a read alone, where a report takes one too; and which found one sim bound to `panel` and
`drive` taken, its reports reaching the last device to open it and the two devices'
outputs written over each other, which is refused now.)*

**The watchdogs** (decisions 109, 110, 111, 119, 125 and 126). Each task has its own
watchdog time, 500 ms unless its line sets one, `task fast interval 10 priority 1 watchdog
50`; the continuous task's is on its own line, `task main continuous watchdog 200`, or 500
ms.
- **What is timed.** A timed task's run, from the start of its first instance's scan to
  the end of its last, on the runner's clock, read at the boundaries of the cycle's steps
  (decision 118); and each round of the continuous task, from the round's start, when it
  takes its inputs, to the end of its last program's scan, the timed tasks run in that
  round included, as the conventional watchdog counts the time of the tasks that
  interrupt its task (the tasks, programs and routines manual, p.34), its trip naming each
  step with its time, so that the slow one is seen (decision 126). A task's wait for the
  round in progress is not in its time.
- **The runner's check.** After each step the runner compares the time against the
  task's watchdog; over it, it trips (decision 113) before the round's outputs are
  written, so a round that ran too long never reaches the plant. This replaces the
  design's one gap between two writes, which had one watchdog to measure against.
- **Each device's heartbeat** (decision 125). Every refresh carries a deadline, the time
  by which the device must hear from the runner again. The runner refreshes every device
  before every step of a round, the deadline that step's task's watchdog plus one poll
  period from the step's start, and before it serves its own work, writes a round's
  outputs or waits, the runner's own idle watchdog, `idle:` (500 ms unless set), plus
  one poll period (decision 128, which replaced the continuous task's watchdog here),
  refreshing again at least once a poll period while it waits. A device that hears nothing by the deadline its last
  refresh carried writes 0 to every output once, latches and tells the runner, which
  trips when it next runs, `{:watchdog, {:device, device, time}}`; one a trip latched
  already tells it nothing, so that a restart that waited while its deadline passed
  finds no notice from before it. A runner that is well
  never misses one, each step ending within its watchdog or tripping and the poll period
  the margin, and a runner stuck in the conveyor's 50 ms step leaves every device that
  answers at 0 within 50 ms and a poll period, not within the plant's longest watchdog.
  Without preemption a step holds every refresh, so the deadline is the step's, carried
  to every device; one for each device, from the tasks that drive its points, would latch
  the panel under a fan run that is well.

**A trip** (decisions 113 and 114) has one path, whatever caused it: the runner stops
scheduling, its wake cancelled and a stale one ignored; every output is written 0 once,
through each device that answers, which latches and writes nothing more until a restart; it
reports `{:trip, reason}` to each subscriber and `status/1` gives the reason until a
restart; it keeps the resource as the last round computed it, which `get/2` reads, outputs
the plant never received among them where the round tripped before its write; and it waits
for `restart(runner, :cold | :warm)`, which releases every latch, reads every device once,
as a start does, opening again each device that went down (decision 142), calls
`Logex.Runtime.restart/2`, which keeps the input image and puts every other global back to
its initial value, and runs the first round at once, on what the devices read, the clock
not counting the stopped time. `:warm` is `:cold` until `retain` lands. A trip's reason is
one of:
- `{:watchdog, {:task, task, took_ms, limit_ms}}`, a timed task's run;
- `{:watchdog, {:round, task, took_ms, limit_ms, steps}}`, a round of the continuous task,
  `task` its name, or `:none` where the configuration declares none, as an event names it,
  and `steps` each step the round ran, in the order run, `{task, ms}`, the continuous
  task's programs under its own name, so that a timed task's slow run is seen (decision
  126);
- `{:watchdog, {:device, device, time_ms}}`, a device's heartbeat;
- `{:io, device, cause}`, `cause` one of `:timeout`, `{:error, term}`, `{:raised,
  message}`, `{:thrown, term}`, `{:exited, term}`, `{:bad_value, address, value}`,
  `{:unknown_address, address}` and `{:down, reason}`;
- `{:internal, message}`, an exception out of the core, which the host contract says
  cannot happen: tripping rather than crashing keeps the state for diagnosis, and zeroes
  the outputs either way. No host can cause it, so a test reaches it through one seam, a
  hidden option of `start_link/1` that stands a module of the test's in for
  `Logex.Runtime`'s steps (`PLAN.md` M4-4).
- *(Decided 2026-10-21 for Milestone 5, decisions 153 and 160:)* `{:fault, task,
  instance, fault}`, a major fault, an index or a tag bit number out of range, the
  round's first, at the end of the step that raised it and before its write (§4.12, "The
  major fault"; decision 153's note).

*(Landed with M4-4, 2026-10-18, as this section says, with the readings the record left,
five of them put to the maintainer and answered on 2026-10-19 as decisions 133 to 137,
each as built: the hidden option is `steps:`, a module with `cycle_steps/3`,
`cycle_step/2` and `cycle_outputs/1`, each call of the three guarded, an exception's
`message` its own and a throw's or an exit's its banner; a restart of a runner that is
running is the host's mistake (decision 133); a device whose own callback failed is zeroed
through its adapter too, where it still takes a write, so that every output that can still
be written is, the table's "every other device zeroed" read as the others besides it
(decision 135); `{:watchdog, {:device, device, ms}}` names the time from the device's last
refresh to its deadline, the heartbeat it was given (decision 137); a result of no shape
`Logex.IO` gives is `{:raised, message}`, a message saying so, the cause list having no
word of its own for it; a device that answers after its deadline on the runner's clock is
`:timeout`, and, having answered, is not killed but written its 0 by the trip (since
M4-4's review); a device stuck inside its own read or report, which decision 114 already
makes a fault, is seen by its polls stopping (since M4-4's review): each device tells the
runner after every read and report, whatever its result, and at each poll while it waits
on the runner, that it is back from its adapter, a message a device a poll period, a
round's write answered in time counting too, and the runner, as each round begins and at
each wait's refresh, kills and trips `{:io, device, :timeout}` on the first device in
device-name order not heard within the idle watchdog and a poll period, the time it gives
any call of its own to a device (decision 134); a device's notices that waited for the
runner are taken together, in the order of the time each was raised, ties in device-name
order, so that a run on the manual clock trips for one reason; a restart releases every
latch first, a device that does not answer killed, and then reads every device once, in
device-name order, opening again every device down, so a device that hung or died while
the runner was tripped is opened again by the same restart, and one that cannot be opened,
or whose read fails or gives a value that does not fit, leaves the runner tripped with its
first reason and every device that answers latched again, written 0 once more, as a
restart that trips again does (decisions 136 and 142); a release forgets
what the device last wrote, so that no poll writes the outputs from before the trip again
before the restart's first round writes its own; a close answered while a device waits on
the runner for its own change stops it closed, so that it is zeroed and closed once;
init/3's own `{:error, reason}` is given as `{:io_init, device, reason}`, as M4-3 gave it,
and an init/3 or first read that raised, threw, exited, hung or gave a value that does not
fit as its cause; a clock that goes down or fails stops the runner, a shutdown, its
devices zeroed and closed as at a stop; a host's request is timed from its start to its
end against the idle watchdog, a restart not, and trips once it is answered; a tripped
runner keeps its first reason and merges a device's changes into the next round's inputs,
so the restart's first round takes them; and a test makes time pass inside a task's run
through the seam, a stand-in that passes the manual clock or, for a stuck runner, advances
it from inside the runner, which the manual clock allows a receiver handling a message,
its timers on the way delivered to the devices.)*

**What fails, and what happens.**

| What fails | How it is seen | What happens |
|---|---|---|
| A task's run or a round outlasts its watchdog | the runner's check after each step | trip before the round's write |
| The runner is stuck | each device's deadline, which its last refresh carried | the devices zero and latch; the runner trips when it next runs |
| An adapter's callback fails, or gives a bad value or address | guarded in the device's process; the runner's checks | trip, every other device zeroed |
| An adapter hangs | no answer within the device's deadline; inside its own read or report, not heard from within `idle:` and a poll period | trip; the device's process killed, its outputs left to the device; opened again at a restart, as one that hangs or dies while the runner is tripped is |
| A device's process dies | the runner traps the exit | trip; opened again at a restart |
| The runner crashes or is killed | each device traps its parent's exit | each device zeroes its outputs and closes; nothing starts it again (decision 115); its forces stay in their file, for the runner the host starts next (decision 127) |
| The runner is stopped | `stop/2` | every output zeroed once, every device closed, before `stop/2` returns (decision 116) |
| A subscriber is slow | — | nothing: events are sent, never awaited, so its own mailbox grows; `:ran` and `:round` are opt-in for that reason |
| The VM, the machine or the power dies | — | nothing in software can act: outputs are what the I/O does on losing its master, which a plant should set to off |

**Forcing** (decisions 117 and 127). `force(runner, point, value)` makes the runner see an
input point at `value` whatever its device says, merged over the device's values before
each round, after the input latch, as §5 places forcing; it stays until `unforce/2` or
`unforce_all/1`, across a restart and, kept in a file, across a crash and a fresh start,
and `status/1` lists every force. `unforce/2` puts back the device's last value, which the
runner keeps for each input point, and `unforce_all/1` takes every force off. A force of
a trigger is a change of it, its round at once (decisions 120 and 138). An output point, or a value that does not
fit, is the host's mistake. Output forcing waits for §5's forcing in `cycle/3`, which
`force/3` will then call.
- *The file* is the host's to name, `forces:` a path, an option of `start_link/1`; a
  runner started without one takes no force, so that every force there is survives a
  crash. Each force and unforce writes the whole set before it returns, to a file beside
  it, flushed to the disk and renamed over it, so a crash leaves the old set or the new;
  a write that fails changes nothing and returns `{:error, {:forces, reason}}`. Its format
  is M4-5's, text a person can read: one force a line, `name value` (M4-5), read exactly
  so (decision 140).
- *It is read at every start,* by `start_link/1` in the caller before anything starts,
  and by `restart/2`; a file that does not exist is no force. A force the configuration
  cannot take, on a point it no longer has, on an output point or of a value that does
  not fit, or a file that cannot be read, is the host's mistake at start, every such
  force named, and the runner does not start; at a restart it stays tripped. A host
  clears every force with `unforce_all/1`, or, with no runner, by deleting the file.

**Edits.** Each step of a `Logex.Configuration.Edit` is a call to the runner, served
between two rounds in its share; the runner holds the edit, one at a time, a second accept
superseding the first as decision 66 allows, and its next round runs the resource the step
returns. A step may be taken while tripped, so a program can be fixed and then restarted.
Accept's work, which grows with the programs, is done in the caller's process, against the
resource the runner hands it, so that no step costs a round more than a switch.
*(Landed with M4-5, 2026-10-19, forcing and the edits as these paragraphs say, with the
readings the record left: the forces file holds one force a line, `name value`, in name
order, the empty file for none, written to `<path>.tmp` beside it, flushed and renamed
over it, and read back exactly so, a last line with no newline read, anything else
refused at the start, `<path>: line <n>: ...` a line each in `force/3`'s words (decision
140); a restart
reads it before it releases anything, a point it no longer forces reading its device's
last value again; the runner keeps each input point's last value from its device, the
input image's until a device gives one; a force or an unforce that changes what a trigger
reads makes its round at once, before the call returns, timed by its steps and not the
idle watchdog, each trigger one changes its own round, as `unforce_all/1` may change
several, in device-name and then address order, each reading those before it at their
new values and those after it as they were (since the review), and a device's change of
a forced trigger makes none (decision 138); a runner started without `forces:` refuses `unforce/2` and
`unforce_all/1` in `force/3`'s words, and an unforce of a point not forced writes the set
again (decision 140); the edit's steps give `{:ok, report}`, accept asking the runner for
its resource with the count of steps it has taken and the step's time, the edit it gives
held only where no step came between and otherwise accepted again (decision 141), a
refused accept leaving the edit held as it was; after each step the rounds read each
task's watchdog and the untimed programs of the configuration the resource runs, a step
that leaves none serving at once, in order, every request that waited for the share's
slot, which no slot would serve again (since the review), and the next round is planned
again from the last; and decision 40's `now` is the step's time on the runner's clock,
given to the switch, so that with no untimed program a cut served long after the last
round is counted from the edit, no period missed and no round added (decision 139). The
maintainer answered the four readings the record left on 2026-10-19, decisions 138 to
141.)*

**Its API**, every call through the runner's mailbox, so each runs between two rounds:

| Function | Notes |
|---|---|
| `start_link(opts)`, `child_spec(opts)` | `configuration:`, `io:`, and optionally `clock:` (`{module, clock}`, the monotonic one unless set), `poll:` (ms, 10), `overhead:` (percent, 20, 10 to 90), `idle:` (ms, 500, the idle watchdog, decision 128), `forces:` (a path, decision 127) and `name:` (decision 121). Checks every option, `Logex.Runtime.start/1`'s refusals, the bindings and the forces file in the caller, before anything starts; opens every device, reads each once, and runs the first round at once. `{:ok, pid}`, or `{:error, {:io_init, device, reason}}` for a device that cannot be opened, which is the plant's state, not a host mistake |
| `stop(runner, reason \\ :normal)` | zeroes every output once and closes every device before it returns |
| `status(runner)` | `:running` or `:tripped`; `now`; the rounds run; the trip's reason; each task's overlaps; the forces, always, every one with its value, those read from the file at a start among them; the edit's stage; each task's longest run against its watchdog, the latest wake, and the longest wait between two refreshes, in ms |
| `get(runner, path)`, `get!(runner, path)` | as `Logex.Runtime.get/2` and `get!/2`, of the last round computed |
| `subscribe(runner, kinds)`, `unsubscribe(runner)` | `{Logex.Runner, runner, event}` for each event of a kind named; a subscriber is monitored and dropped when it dies |
| `force(runner, point, value)`, `unforce(runner, point)`, `unforce_all(runner)` | input points only; each writes the forces file whole before it returns, `{:error, {:forces, reason}}` where it cannot, and a runner started without `forces:` takes no force (decision 127) |
| `restart(runner, :cold \| :warm)` | `:ok`, or `{:error, {:io_init, device, reason}}` for a device it cannot open or read (decisions 136 and 142) |
| `accept(runner, candidate)`, `test/1`, `untest/1`, `assemble/1`, `cancel/1` | the edit's steps |

Its events are an open set: the resource's own `{:overlap, task, missed}` and `{:fault,
task, instance, fault}`, `{:trip, reason}`, `{:restart, :cold | :warm}` and `{:edit, step,
report}`, sent by default; and, for a live display, the resource's `{:ran, task, instance,
now}` and the runner's `{:round, now, outputs}`, sent only to a subscriber that names
them.

**Host mistakes** raise `ArgumentError` in the host's own process, with a message a test
pins, and never crash the runner. At start: a missing or unknown option; a configuration
`Logex.Runtime.start/1` refuses, in its words; a device the points name that no adapter is
bound to, ``no adapter is bound to the device `drive`, which `sp_1` (drive.q.0) and `sp_2`
(drive.q.1) are at``; a bound device no point is at, ``the device `panle` is bound, but no
point is at it — did you mean `panel`?``; an adapter that does not implement `Logex.IO`;
options its adapter's `check/3` refuses; a poll period or a share out of its range; a
clock that does not implement `Logex.Runner.Clock`; a forces file that cannot be read, or
holds a force the configuration cannot take (decision 127). In a call, the runner rescues
the `ArgumentError`, replies `{:raise, exception}`, and the function raises it in the
caller: a path that names nothing, an output point or a value that does not fit forced, a
force on a runner started without `forces:`, a step with no edit accepted, a restart that
is neither cold nor warm, and at a restart a forces file it can no longer take.

**How a test drives it.** The manual clock replaces the monotonic one and `Logex.IO.Sim`
the plant, so a run is deterministic and repeats exactly from fresh processes. On §4.4's
plant:

```elixir
{:ok, clock} = Logex.Runner.Clock.Manual.start_link()
{:ok, panel} = Logex.IO.Sim.start_link(reports: true)
{:ok, drive} = Logex.IO.Sim.start_link()

{:ok, runner} =
  Logex.Runner.start_link(
    configuration: plant,
    io: %{"panel" => {Logex.IO.Sim, sim: panel}, "drive" => {Logex.IO.Sim, sim: drive}},
    clock: {Logex.Runner.Clock.Manual, clock}
  )

Logex.IO.Sim.set(panel, [0], 1)                  # pb_start_1, at panel.i.0
Logex.Runner.Clock.Manual.advance(clock, 10)     # each timer due on the way, in time order
assert Logex.IO.Sim.outputs(panel)[[0]] == 1     # k1, at panel.q.0
```

`advance/2` runs in the test's process. It takes each timer due on the way from the clock,
earliest first and ties in the order they were set, sets the clock to its time, sends its
message, and then calls the receiver through `:sys`, from the same process, so that it
returns once the receiver has handled the message: the order holds by construction, one
sender to one receiver, never by the order in which two senders' messages arrive, which the
spike's clock relied on. What a receiver sends others while it handles one is its own to
finish, as a call finishes, before it returns. A timer set while one is handled is
delivered in the same `advance/2` where it falls inside it. Time that passes inside a step,
as a slow device's, is `pass/2`, which delivers nothing until the next `advance/2`.
`Logex.IO.Sim.set/3` returns once the device that opened the sim has handled its report,
and the device passes a change on by a call the runner answers once the round it causes
has run, so `set/3` returns after that round and its writes, by construction, and a test
that presses the e-stop then reads the outputs `trip` wrote (decision 124); a change that
makes no round is merged by the time `set/3` returns, and the next round, which the
next `advance/2` brings, takes it. Rounds back to back come one a clock millisecond
(decision 122), so a run repeats exactly from fresh processes.
*(Landed with M4-1, 2026-10-17, as this paragraph says. The monotonic clock brings a time
already past to now, since the VM refuses an absolute time from before it started, which
its liveness test found; and a simulated device's `set/3` reports from the caller, which
then waits through `:sys` for the device to handle the report, so that the sim's own
process never waits on a device, which may be calling it.)*

**What it can promise**, to be said plainly in README *(said, M4-7, in README's
"Running a plant on the clock", with a run on the real clock)*: exact replay, since the runner adds
nothing to the logic and a cycle is a function of its arguments, so a recorded run replays
(`Logex.Runtime`'s moduledoc, "What it may rely on", item 6); no drift, every deadline
absolute; lateness reported, as an overlap; and outputs at 0 when the runner trips, stops,
dies or stops refreshing a device, wherever the device still answers. **What it cannot:**
no hard deadline and no bounded jitter, since the BEAM runs on a general-purpose operating
system and shares its schedulers; no edge shorter than the gap between two of its device's
reads, unless the device reports it, and of one reported, none that falls before a round
runs while it holds, unless it is an event task's trigger, since the runner keeps only
each input's latest value; and nothing once the VM stops. A host helps by giving
the controller cores of its own, keeping heavy work out of its VM, and setting each task's
watchdog from a soak on the target machine, which `status/1`'s longest runs make easy.
Operating-system real-time priority and the VM's scheduler flags are left unmeasured, and
their effect is **unverified**.

**Receipts, the spike's**, each on the real §4.4 plant (`spike-runner/timing.exs`,
`soak.exs` and `size.exs`), at the design's steady 10 ms beat, which decision 108 replaced,
and so evidence of the BEAM's lateness rather than of rounds back to back, which M4-3
measures:
- absolute timers, idle: p50 0.19 ms late, p99 0.58 ms, max 3.4 ms, no early wake in
  6,000; beside a full test suite p50 1.8 ms, p99 126 ms, max 196 ms; at process priority
  `:high` the median better and the tail not, the competition being another operating
  system process; relative timers, `send_after(10)` after each cycle: 11 ms a cycle,
  1,067 ms of drift in 1,000 cycles and 106 periods falsely reported missed;
- the longest gap between two output writes: under 20 ms idle over 20 s; under 100 ms
  beside one test suite over 40 s; beside two, at a load of 8.4 on 4 cores, three over
  500 ms, the latest wake 692 ms late;
- the runner's own cost, from wake to the last write, two devices read and written: p50
  0.21 to 0.24 ms, p99 0.52 to 0.57 ms, p99.9 2.3 to 4.0 ms, in all three runs; `cycle/3`
  alone 9 to 26 µs per instance of §4.3's motor, 2.0 ms for 100 and 27 ms for 1,000.

**Routine choices, each with what it passes over:**
- the runner holds the edit, over the host passing `%Edit{}` in, which allows a step
  against a stale edit that only the generation catches;
- host mistakes relayed and raised in the caller, over raising in the server, which would
  crash the plant for a typo;
- a hung device killed and opened again, its outputs left to the device, over waiting on
  it, which would wedge the runner;
- an exception out of the core trips, over crashing, which loses the state;
- `get/2` reads the resource after a trip, over reading the zeroed devices;
- `:ran` and `:round` opt-in, over sending every event, which grows a slow subscriber's
  mailbox at thousands a second;
- no logging, over Logger, which B6 keeps out;
- the timing arithmetic private to the runner and tested through the manual clock, over a
  pure pacing module, one more public surface for a run that is already deterministic;
- §4.10's two notes, revisited and still not taken: no `outputs` field on
  `%Logex.Program{}`, since `cycle/3` already returns the output points and the runner's
  whole cycle measured 0.2 ms; and no queue of tasks by due time, `next_due_in/1` being
  linear in the tasks and called once a round, until a plant of hundreds of tasks is seen.

**What logex is not**, to be stated in README, in `Logex.Runner`'s moduledoc and here
*(stated in the moduledoc with M4-3, and in README's "What logex is not" with M4-7, which
adds, each checked against the code, that logex compiles nothing to BEAM, ships one
adapter, `Logex.IO.Sim`, is a ladder dialect and not IEC 61131-3's text, and has one
resource a configuration, bool and dint only, a forward jump only, no retained values and
no output forcing)*.
logex is not a safety controller, and must not implement a safety function: an emergency
stop, a guard interlock, a light curtain, two-hand control, burner or pressure protection
belong in hardwired circuits or a safety-rated controller designed and validated to the
functional-safety standards that apply, against which logex makes no claim. The e-stop in
§4.4's plant is a signal the program reads, which records the contactors at the trip; the
e-stop that cuts their power must be wired to work with logex stopped, crashed or never
started. logex is not hard real-time, its watchdogs being a backstop, not a guarantee, and
it is not certified for any industrial use. The common deaths of a runner go to outputs
off, a crash, a kill, a stop, a stuck runner and a device fault; a hung device and a dead
VM do not, and the documents say so.

**The contract walk** *(M4-6, landed 2026-10-19).* `api_contract_test.exs`'s runner walk,
`Logex.ApiContractTest.RunnerWalk`, runs the runner on the manual clock over seeded
configurations, about three in four with untimed programs, devices that report and that are only read,
waits, presses, forces, edits, restarts, a crash, and injected faults, through the hidden
seam `steps:`, which tells the walk each round's elapsed time and inputs. It is checked
against `cycle/3` called with those, every round's events, outputs and resource, and
against the rules restated: when each scheduled round comes, what each input reads, and
which trip each fault gives. Its reach is every event kind and every trip reason but
`{:internal, message}`. It found one bug, a device that took a change the runner refused
(decision 114's note), and one question, whether a restart reads every device first,
which the maintainer answered on 2026-10-20: it does, as a start does (decision 142).

**Risks.**
- *Real time in CI*: every rule is tested on the manual clock, and a test on the real
  clock asserts only liveness, with bounds a fifth above the two-suite soak's, since CI
  shares its cores and CONTRIBUTING.md forbids skipping or quarantining a test.
- *A suspended machine* (**unverified**): the BEAM here reads `CLOCK_MONOTONIC`
  (`erlang:system_info(os_monotonic_time_source)`), which by clock_gettime(2)'s definition
  does not count a suspension, so a laptop that sleeps would wake with no trip and no
  overlap, its devices' heartbeats on the same clock. It must be tried on a real machine
  before README says what a sleep does.
- *A long request*: one the runner serves whole and that takes longer than the
  runner's idle watchdog and a poll period trips the plant, which is why accept runs
  in the caller (decisions 119, 125 and 128).
- *Plants larger than their watchdogs*: 1,000 motors cost 27 ms a cycle, so README gives
  the measured cost per instance for a programmer to size each watchdog.
- *Determinism of real devices*: exact replay holds given the same inputs, and a real
  device samples when its adapter does.
- *Not spiked, and worth a spike during the milestone*: a real network adapter outside
  logex, for the cost of a device on a network and of reading devices in parallel;
  operating-system real-time priority and the VM's flags against the tail; a suspended
  laptop; and rounds back to back with the share, which the spike's steady beat did not
  build.

### 4.12 Data types (Milestone 5)

**Designed and decided 2026-10-21; its first item, M5-1, the one table of types, landed
the same day, changing nothing a program, a configuration, a host or an edit sees**
(`PLAN.md` §3, Milestone 5). A design pass on `0c55e36` answered the maintainer's request: *"More data types. 1, 2,
4, 8 byte integers (how does IEC and vendors handle signed?), 32/64 bit reals, arrays of
all others, what else does IEC and vendors have."* It read IEC 61131-3 Ed 2:2003 and Ed
3:2013 in full and Ed 4:2025 from its publisher preview only; the conventional family's
general instructions reference (1756-RM018A, Sept 2025), its data and programming manuals
(1756-RM094N, PM004L, PM013H, PM014O, PM015Q, PM020I), the 32.04 and 33.01 release notes
and the v38.01 help; Siemens TIA V21 and the S7-1200 system manual (A5E02486680-05);
CODESYS's online help; Schneider Control Expert; and MatIEC and OpenPLC
(`iec_std_functions.h`). Its review ran the BEAM's float behaviour on the pinned Elixir
1.20.4 / OTP 28, found two of the draft's float assumptions wrong, corrected six more
facts and added a question (decision 159). The maintainer answered on 2026-10-21. Eleven
answers are the recommendation (decisions 144, 145, 147, 149, 150, 152, 153, 154, 157,
159 and 160, the last put as a follow-up); six are not, and each says so in §7: integer
overflow **wraps**, in every width, the dint's included, where decision 77 saturated
(146); conversions take IEC's typed names, `real_to_int`, keeping `docs/naming.md`'s
"never hide a rounding mode inside a conversion name" (148); arrays have up to **three
dimensions** (151); the **bit strings** come now, with the bitwise instructions, which
work on bit strings and integers alike (155); **arrays may be located** (156); and the
timers and counters get **typed variants**, the long timers counted in nanoseconds
(158). Where a rule changes decided text above or in §7, that text is annotated where it
stands, never rewritten. `PLAN.md` §3's Milestone 5 gives the items and their order.
The record then put ten readings back to the maintainer and left three rules open ("Put
to the maintainer", below), all thirteen answered on 2026-10-21: seven readings as the
record took them, each a note on the decision it settles; three otherwise, a real too
large for its integer target **rounded, then wrapped** (decision 161), the truncations
named in IEC's typed form, **`real_trunc_int`** (162), and **`ctu_dint`, `ctd_dint` and
`ctud_dint`** taken as aliases of `ctu`, `ctd` and `ctud` (163); and the three rules,
`sqrt` of a negative source a minor fault, `:negative_sqrt` (164), a shift or rotate
count out of range no fault (165), and an integer at a real point stored as the nearest
real (166).

**Words.** An *integer type* is one of IEC's eight, signed or unsigned. A *real* is one of
IEC's two floating-point types, `real` and `lreal`. A *bit string* is IEC's BYTE, WORD,
DWORD or LWORD: a row of bits with no arithmetic. *Widening* converts a value into a type
that holds every value of the type it came from; *narrowing* is the reverse. *Wrapping*
keeps a result's low bits, so 127 + 1 in a `sint` gives −128; *saturating* brings a
result to the nearer limit, as decision 77 did for a dint and as a real still does. An
*index* is a subscript, the 3 in `temps[3]`; a *bit number* the 3 in `status.3`. A *minor
fault* is one the scan reports and the plant runs on through (decision 99); a *major
fault* is one after which the runner trips (decision 153).

The example plant is the record's: a conveyor with its motor, its fan, a box counter and
the run lamp, with a drive card that reports the fan's speed and an analog card that
reports zone temperatures.

**How IEC and the vendors handle signed and unsigned.** Every system read uses the same
names, IEC's, and keeps signed and unsigned as **separate types**: SINT, INT, DINT and
LINT are signed, USINT, UINT, UDINT and ULINT unsigned, of 1, 2, 4 and 8 bytes. Signed
values are two's complement: Siemens says so in words (TIA V21, *SINT (8-bit integers)*:
*"a sign and a numerical value in the two's complement"*), Logix shows it (RM018A p.872,
DINT 65,665 truncated to SINT 16#81 = −127; p.871, 16#FFFF read as −1 by sign extension),
and IEC never says it but gives exactly the two's-complement ranges (Ed 3 Table 10
footnote c, p.32: −2^(N−1) to 2^(N−1)−1; footnote d: 0 to 2^N−1). They differ in three
places:

1. **Converting between signed and unsigned.** IEC never does it implicitly, nor between
   an unsigned type and a signed type of the same width (Ed 3 Figure 11, p.67): USINT
   widens into INT, DINT or LINT, never into SINT. Siemens refuses it too while the
   per-block "IEC check", on by default, is set (TIA V21 *Overview of data type
   conversion*), and allows it by bit pattern without it (DINT −1 → USINT 255). CODESYS
   allows it with a warning, C0195 or C0196. Logix converts freely: *"If the source value
   is too big to fit into destination, the controller stores what it can and may produce
   an overflow"* (RM018A p.874); what it stores for a negative value put into an unsigned
   type is **unverified**. MatIEC refuses every implicit conversion.
2. **What overflow does.** IEC calls it an error and leaves the handling to the
   implementer (Ed 3 §6.6.2.5.8 p.87; Ed 2 §2.5.1.5.2 p.56 and §1.5.1 d) p.21, which
   allows "not reported"). Every vendor whose manual says what it stores wraps (the
   S7-1500's stored value is **unverified**, and Schneider Control Expert sets %S18, its
   stored value **unverified**): Logix sets S:V, and raises minor fault 4/4 where overflow
   faults are reported, and the rung goes on (RM018A p.868, PM015Q p.57, PM014O p.25); the
   S7-1200 returns *"the least significant part of the result that fits"* with ENO 0
   (A5E02486680-05 Table 7-40 p.188); CODESYS wraps at the width it stores into, with
   wider intermediates and no flag (CODESYS help, *Operators*). Until Milestone 5 logex
   saturates with no power (decision 77), a conforming handling no vendor uses; from it,
   logex wraps with no power, the S7-1200's reading (decision 146).
3. **Mixing them in one instruction.** IEC wants one type across an instruction's inputs
   and output and leaves anything else to the implementer (Ed 3 §6.6.1.7.2 p.70); it has
   no C-style "the signed operand becomes unsigned" rule. Siemens without the IEC check
   computes SINT + USINT in INT. Logix ranks the operands SINT to LREAL (RM018A p.870) and
   converts. CODESYS's result type for a mixed pair is **unverified**.

The types, side by side ("5x70" is CompactLogix 5370 and ControlLogix 5570; "5x80" is
CompactLogix 5380 and 5480, ControlLogix 5580 and 5590; "S7-1200" is the classic family,
not the G2):

| Type | Bytes | Range | IEC Ed 2 / Ed 3 | Logix 5x70 | Logix 5x80 | S7-1200 | S7-1500 | CODESYS |
|---|---|---|---|---|---|---|---|---|
| BOOL | 1 bit | 0, 1 | yes / yes (T10 f1) | yes, 4 bytes alone | yes | yes | yes | yes, 8 bits |
| SINT | 1 | −128 … 127 | yes / yes (f2) | yes | yes | yes | yes | yes |
| INT | 2 | −32,768 … 32,767 | yes / yes (f3) | yes | yes | yes | yes | yes |
| DINT | 4 | −2,147,483,648 … 2,147,483,647 | yes / yes (f4) | yes | yes | yes | yes | yes |
| LINT | 8 | −2^63 … 2^63−1 | yes / yes (f5) | **copy only** (help v38.01: *"You cannot add, subtract, multiply, or divide"*) | yes; read as an LDT where it meets a time (RM018A p.878) | **no** | yes | yes |
| USINT | 1 | 0 … 255 | yes / yes (f6) | no | yes, since v32 | yes | yes | yes |
| UINT | 2 | 0 … 65,535 | yes / yes (f7) | no | yes, since v32 | yes | yes | yes |
| UDINT | 4 | 0 … 4,294,967,295 | yes / yes (f8) | no | yes, since v32 | yes | yes | yes |
| ULINT | 8 | 0 … 2^64−1 | yes / yes (f9) | no | yes, since v32 | **no** | yes | yes |
| REAL | 4 | IEEE 754 single: ±1.1754944E−38 … ±3.4028235E38 normal, about 7 digits, every integer to 2^24 exact | yes / yes (f10, IEC 60559 single) | yes | yes | yes | yes | yes |
| LREAL | 8 | IEEE 754 double: ±2.2250738585072014E−308 … ±1.7976931348623157E308, about 16 digits, every integer to 2^53 exact | yes / yes (f11) | no | yes, since v32 | yes | yes | yes, but some targets compile it as REAL |
| BYTE, WORD, DWORD, LWORD | 1, 2, 4, 8 | bit strings, compared as unsigned | yes / yes (f18–21) | none for programs; DWORD only as a CIP type code (PM020I p.12) | the same | yes | yes, LWORD too | yes |

Sources: IEC Ed 3 Table 10 pp.31–32 and Ed 2 Table 10 pp.30–31; Logix RM018A pp.873–874
and, for LINT's range, RM094N p.24 (RM018A and PM004L print LINT as "0 to
32,535,129,599,999,999", the date and time display range, which RM094N contradicts). The
v32 date is the 33.01 release notes', which say the types *"were introduced in version
32"*; the v32 notes themselves were not reached, and RM018A's operand tables list the new
types for the 5x80 controllers only. Siemens from TIA V21 *Data types* and
A5E02486680-05 Tables 4-17 and 4-18 p.88; CODESYS from its help, *Integer data types* and
*REAL / LREAL*. Logix flushes denormals and −0.0 to 0.0 (RM018A p.882). IEC leaves
results with denormals, infinity or NaN to the implementer (Ed 3 Table 10 footnotes e and
f). IEC's bit strings compare as unsigned integers (Ed 3 §6.6.2.5.10 p.90).

Overflow, side by side:

| | Result | Power or ENO | Reported | Source |
|---|---|---|---|---|
| IEC | not specified: "an error" | not specified | the implementer's choice, "not reported" allowed in Ed 2 | Ed 3 §6.6.2.5.8 p.87; Ed 2 §1.5.1 d) p.21, Annex E p.167 |
| Logix, ladder | wraps (*"adding 1 to a SINT … goes from 127 through -128"*) | rung-out is rung-in | S:V set; minor fault 4/4 on each cleared-to-set S:V, if Report Overflow Faults is on | RM018A p.868, p.308; PM015Q p.57; PM014O p.25 |
| S7-1200 | wraps (*"least significant part … that fits"*) | ENO 0 | ENO only | A5E02486680-05 Table 7-40 p.188 |
| S7-1500 | **unverified** (the V20 ADD page says only ENO 0) | ENO 0 | ENO only | TIA V20 *ADD: Add* |
| CODESYS | wraps at the stored width; intermediates at the CPU's width | no ENO documented (**unverified**) | none | CODESYS help, *Operators* |
| MatIEC / OpenPLC | C's: narrow types wrap; DINT and LINT overflow undefined | ENO = EN | none | `iec_std_functions.h` |
| logex to Milestone 4 | saturates at the dint's nearer limit | no power | none | decisions 77, 98 and 99 |
| logex from Milestone 5 | wraps, in every integer width; a real saturates | no power | none | decisions 146 and 150 |

**What else they have, and what logex takes.**

| Kind | IEC | Logix | Siemens TIA | CODESYS | logex (Milestone 5) |
|---|---|---|---|---|---|
| Bit strings BYTE, WORD, DWORD, LWORD | yes, Ed 2 and Ed 3 Table 10 f18–21; bitwise AND OR XOR NOT and SHL SHR ROL ROR take them only (Ed 3 Tables 30, 31); partial access `w.3`, `w.%B1` new in Ed 3 (Table 17 pp.59–60) | none; bit access on any integer instead (RM018A pp.884–885), and AND, OR, XOR, NOT on integers (RM018A pp.494ff) | yes; LWORD on S7-1500 | yes, and BIT in structures | **take**: the four types, the bitwise instructions on them and on integers, bit access `x.3` and `x.[n]` on both (decisions 155 and 160); IEC's byte, word and double-word partial access, `w.%B1`, deferred |
| TIME, LTIME | TIME's size the implementer's; LTIME signed 64-bit ns, new in Ed 3 (T10 f12a/b) | TIME32, TIME, LTIME on 5x80 (RM094N p.13) | TIME signed 32-bit ms; LTIME on S7-1500; S5TIME | TIME unsigned 32-bit ms; LTIME | **defer the types**; presets stay dint ms, and the long timers count lint nanoseconds (decision 158) |
| DATE, TOD, DT and their L forms | yes; L forms new in Ed 3, ns from 1970 | DT, LDT on 5x80; LINT doubles as LDT | DATE, TOD, DT, LTOD, LDT, DTL (a 12-byte structure) | yes | **defer**: no calendar clock in the core |
| STRING, WSTRING, CHAR, WCHAR | STRING, WSTRING in Ed 2; CHAR, WCHAR new in Ed 3; UCHAR, USTRING (UTF-8) in Ed 4 (definition 3.16; body **unverified**) | STRING of 82 characters (PM013H p.13), custom 1–65,535 (RM094N p.90) | STRING to 254, WSTRING to 16,382 | STRING default 80, WSTRING UCS-2 | **defer**: a milestone of its own |
| Enumerations | yes, Ed 2 and Ed 3 Table 11 f1 | **unverified**: none found in the manuals read | named value types, S7-1500 only | yes | **defer** |
| Named values | new in Ed 3 (T11 f2), open | none found | the same, S7-1500 | yes | **defer** |
| Subranges | yes, integer base only (T11 f3) | none found | **unverified** | yes; saturates only with `CheckRangeSigned` | **defer** |
| Arrays | yes, multi-dimensional, bounds may be negative (T11 f4); of FB types new in Ed 3 (f5); `ARRAY[*]` for parameters only (Table 15) | up to 3 dimensions, zero-based, 1-D only inside a UDT, 2 MB (PM004L p.34; RM094N p.85) | up to 6 dimensions, no array of arrays | multi-dimensional, arrays of arrays | **take** Logix's form, up to three dimensions, of every elementary type and of instances, located too (decisions 151–156); IEC's bounds deferred |
| Structures, UDTs | yes (T11 f6; `AT`, `OVERLAP` new in Ed 3, f8, f9) | UDTs, 500 members, 2 MB, offline edits only (RM094N pp.87–88) | STRUCT, PLC data types, 8 deep | STRUCT, `EXTENDS` | **defer**: a user function block's members already give named, nested state |
| Directly derived types | yes (T11 f11) | none found | none found | yes | **defer** |
| References, pointers | `REF_TO`, `REF()`, `^`, new in Ed 3 (Table 12) | none for programs (**unverified**) | VARIANT, POINTER, ANY, parameters only | POINTER TO, REFERENCE TO | **not adopted**: a ladder operand names a tag |
| Unions | only as `AT … OVERLAP` in a structure (T11 f9) | none found | none on S7-1200 | UNION | **not adopted** |
| Generic types ANY_INT and the rest | the standard library's input types (Figure 5) | none | ANY, VARIANT for parameters | ANY, ANY_<type> | **inside the compiler only**, as the signatures' slot types (decision 147) |
| Target-width integers `__XINT` | no | no | no | yes | **not adopted** |

**The types** (decisions 144 and 145). Each is a row of one table in
`Logex.Declarations`, its word, kind, width, range, zero and article, which every message,
guard, `fits?/2` and the configuration text's type words read (a routine choice below):

| Word | Kind | Bytes | Range | Zero | In a message |
|---|---|---|---|---|---|
| `bool` | Boolean | — | 0, 1 | 0 | a bool |
| `sint` `int` `dint` `lint` | signed integer | 1 2 4 8 | −2^(N−1) … 2^(N−1)−1 | 0 | an sint, an int, a dint, an lint |
| `usint` `uint` `udint` `ulint` | unsigned integer | 1 2 4 8 | 0 … 2^N−1 | 0 | a usint, a uint, a udint, a ulint |
| `real` `lreal` | real | 4 8 | normal IEEE 754 single or double values and 0.0 | 0.0 | a real, an lreal |
| `byte` `word` `dword` `lword` | bit string | 1 2 4 8 | 0 … 2^N−1, no arithmetic | 0 | a byte, a word, a dword, an lword |

Every value is an Elixir integer or float, so a width is a range row and an unsigned type
costs no more than a signed one. Bit 7 of an `sint` is its sign bit, read and written in
two's complement.

**Overflow wraps** (decision 146, superseding decision 77). An integer instruction's result
is computed exactly and then brought into its destination's width by keeping its low N
bits, two's complement for a signed type: 127 + 1 in an `sint` gives −128, 0 − 1 in a
`usint` 255, 2147483647 + 1 in a `dint` −2147483648; a product keeps its low bits however
far it passed; `div` of a type's minimum by −1, and `neg` and `abs` of the minimum, give
the minimum. On the scan where the stored value is not the exact one the instruction
passes no power, IEC's ENO (decision 98), and nothing else: no fault, no event (decision
99). A zero divisor is unchanged: 0, no power and the minor fault (decisions 78 and 99).
`neg` into an unsigned destination is refused when the program compiles (decision 145).
A real does not wrap: a real result beyond its type saturates (decision 150). A
conversion from a real into an integer rounds to the nearest, a tie to the even
neighbour, and a rounded value that does not fit is wrapped, with no power and no fault
(decisions 146, 148 and 161): `real_to_int` of 40000.7 rounds to 40001 and wraps to
−25535; a truncation, `real_trunc_int`, truncates toward zero and then wraps. The counters
are not arithmetic: IEC's CTU and CTD bodies stop counting at a limit (`CV < PVmax`,
`CV > PVmin`, Ed 3 Table 45), as decision 71 has logex's do, and decision 146 names only
decision 77, so a counter stops at its type's limit with `ov` or `un` latched, as before;
Logix's COUNTER rolls over instead (RM018A p.94, p.104), and the maintainer kept the
stop (§4.12's fifth question, decision 158's note).

*What this changes for programs that run today.* Every dint result that passes a limit
gives a different value. The README's fill valve, `add total flow total`, stopped at
2147483647, `total_ok` off for as long as the meter ran wild; from decision 146 the total
goes to −2147483648 and counts on from there, and `total_ok` is off only on the one scan
that wrapped, so a program that read a lamp after `add` as "the total is real" must latch
it, a second rung `xio total_ok otl overflow` after the first, and its README section
says so.
A total that came back in with the next flow now never left. The suite pins the old rule
in `arithmetic_test.exs` (`add`, `sub` and `mul` past either limit, a product far past a
limit, `div` of the minimum by −1, and `neg` and `abs` of the minimum),
`end_to_end_test.exs`'s M3-3 Done-when (a total driven past 2147483647, its oracle's
`clamp`), `api_contract_test.exs`'s arithmetic oracle, `docs/naming.md`'s `add`, `sub`,
`mul`, `div`, `neg` and `abs` stanzas, and README's instruction table and "Arithmetic",
whose run prints the wild meter at 2147483647. `PLAN.md`'s M5-2 changes all of them on
purpose, in one item, before any new width lands, so that logex never has two overflow
rules at once.

**Mixed types** (decision 147). An instruction computes in its destination's type, as
IEC's typed function of that type, `ADD_DINT`, whose inputs Ed 3's rule 2 (p.66) lets
convert implicitly (Table 21 Example 2, `ADD_REAL(A, B)` with an INT `A`). Each source
widens into the destination's type only where Ed 3 Figure 11 (p.67) marks the cell "i":

| Source | Widens implicitly into |
|---|---|
| `sint` | `int dint lint real lreal` |
| `int` | `dint lint real lreal` |
| `dint` | `lint lreal` (not `real`) |
| `lint` | nothing |
| `usint` | `uint udint ulint int dint lint real lreal` (not `sint`) |
| `uint` | `udint ulint dint lint real lreal` |
| `udint` | `ulint lint lreal` |
| `ulint` | nothing |
| `real` | `lreal` |
| `lreal` | nothing |
| `bool` | `byte word dword lword` |
| `byte` | `word dword lword` |
| `word` | `dword lword` |
| `dword` | `lword` |
| `lword` | nothing |

Any other source is refused when the program compiles, naming the conversion to use:
`move day_total small_count` with a `dint` source and an `int` destination is told
`dint_to_int`. A comparison has no destination: two integers compare by value whatever
their types, which is exact on the BEAM, with none of C's signed and unsigned surprises;
an integer with a real compares only where Figure 11 widens the integer into the real's
type, and two reals by value; a bit string compares with a bit string as an unsigned
integer (Ed 3 p.90), and with an integer tag only through a conversion, refused naming
it (the ninth question put to the maintainer, answered as recorded, decision 147's
note). `move` takes the
arithmetic rule. The departure is plain and said in the `add` stanza when it lands: IEC
computes an overloaded `INT + INT` as an INT even when stored into a DINT (Ed 3 p.70,
Example 3), and Siemens documents the trap (`INT#1 + 50000` gives −15,535, TIA V21
*Calculating with constants in SCL*), so a program ported from Siemens or CODESYS that
counted on the narrow overflow behaves differently in logex, where the computation is the
destination's. A literal is judged by its slot (decision 97): an integer literal in a real
slot is the value it spells, and is refused where the slot's type cannot hold it exactly,
the nearest it can named (`move 16777217 fan_speed` into a `real`); a real literal in an
integer slot is refused, never rounded; a based literal is the number it spells. Where the
rule reaches beyond an instruction is decision 159.

**Conversions** (decision 148). IEC's typed names, `<from>_to_<to>` (Ed 3 Table 22 feature
1a), lowercased, two operands, `real_to_int fan_pct drive_sp`:
- **the 90 numeric conversions** of Ed 3 Table 23, every ordered pair of the ten numeric
  types, of which IEC lacks none: 56 between the integer types, 32 between a real and an
  integer type, and `real_to_lreal` and `lreal_to_real`;
- **`real_trunc_<integer>` and `lreal_trunc_<integer>`**, sixteen, IEC's typed
  truncation (Table 22 feature 2b; decision 162), each from the real type it names to
  each of the eight integer types, toward zero, `real_trunc_int` of −1.6 giving −1
  (footnote c's `TRUNC_INT(-1.6)` = −1); IEC's overloaded `TRUNC_<integer>` (feature 2c)
  is not taken;
- **the bit-string conversions**, binary transfers (Ed 3 §6.6.2.5.4–6.6.2.5.5, Tables 24
  and 25): the 12 between the four bit strings and the 64 between a bit string and an
  integer type, a widening filling 0 on the left, a narrowing keeping the rightmost bytes,
  never a sign extension, so an `int` −1 into a `dword` is 16#0000FFFF.

That is 182 mnemonics, each reserved and each owing its survey. A real into an integer
rounds to the nearest, a tie to the even neighbour (Table 22 footnote b, both editions:
`REAL_TO_INT(2.5)` = 2, `(-2.5)` = −2, `(1.6)` = 2; Logix the same, RM018A p.872), an
unsigned target too (Table 23 rows 6–9 and 15–18); Elixir's `round/1` and
`Float.round/1` round a tie away from zero (verified on 1.20.4/OTP 28), so the
implementation must not call them. A rounded value outside its target is wrapped, with
no power (decisions 146 and 161, the maintainer's answer to the first question): one
rounding everywhere, so `real_to_int` of 32767.6 and of 32768.4 give −32768, of 40000.7
−25535 and of 70000.4 4464, IEC's own case, the order of IEC's procedure (Ed 3
§6.6.2.5.3 p.79: the source extended to LREAL, converted to LINT, which rounds, and only
then to the target, the stored value left to the implementer) and of Logix's (*"rounds the fractional part and truncates the
upper portion of the non-fractional part"*, RM018A p.875); a truncation truncates and
then wraps; `lreal_to_real` beyond a real's
range saturates, with no power (decision 150); an integer into a real rounds to the
nearest value the real holds. **`docs/naming.md`'s principle is kept**: *"Never hide a
rounding mode inside a conversion name"*. `real_to_int` hides none logex chose, since IEC
fixes its rounding in the standard that names it, and the one other mode logex takes,
truncation, has its own names, `real_trunc_<integer>` and `lreal_trunc_<integer>`, as
the principle asks (the fourth question, answered as recorded, decision 148's note); `round`, `ceil`
and `floor`, which IEC does not have (none occurs in Ed 3's text), stay deferred, each a
name of its own when a plant asks. Ed 3's overloaded `to_<type>`, which the design
recommended, is not taken. Deferred with them: `BOOL_TO_*` and `*_TO_BOOL` (Tables 24
and 25; a contact and a coil do the work, and `bool` already widens into a bit string);
the four real and bit-string binary transfers, `DWORD_TO_REAL`, `REAL_TO_DWORD`,
`LWORD_TO_LREAL` and `LREAL_TO_LWORD` (Table 25), since a bit pattern may be an infinity
or a NaN, which decision 150 keeps out of every state; the BCD conversions (Table 22
features 3 and 4); and every conversion between a real and a bit string that IEC lacks,
`REAL_TO_WORD` and `BYTE_TO_LREAL` among them (Figure 11 marks DWORD to LREAL and LWORD to
REAL "-", no conversion defined).

**Literals** (decision 149). A real is digits, a `.`, digits, and an optional exponent,
`37.5`, `-0.25`, `1.5e3`, `1.5E-3`; `1.`, `.5` and `1e5` are refused, as IEC's grammar
refuses them (Ed 3 Annex A p.222, Table 5 features 2 and 3), and so is `1.5e+3`, since
logex keeps `+` out (decision 97). A based integer is `16#ff`, `16#FF` or `2#1010_0000`,
with no sign and no octal, which Ed 3 deprecates (Table 5 features 4–6, NOTE 2). A single
`_` may stand between two digits, `1_000_000` (Ed 3 p.26), and not after a `#`, `16#_ff`,
which IEC's grammar allows and its prose does not. Typed literals, `int#5` and `real#1.5`
(Table 5 feature 9), and octal are deferred; Logix's suffixes, `5U`, `5L`, `1.5L` (RM018A
p.870), stay B2's mistyped lexeme. A based literal is the number it spells, `16#ffff`
65,535, which fits a `uint` and is refused for an `int`, where Logix stores −1 and sets S:V
(RM018A p.869) and IEC reads a bit-string literal (p.26). `1.5` cannot be a name path,
since a name starts with a letter or `_`, so `PLAN.md` §5's "`.` in the lexer is safe only
while there are no float literals" is answered by the rule that digits before a `.` make a
number. A new leaf, `{:real_lit, line, float}`, goes into the parser,
`Logex.Parser.well_formed!/1`, the printer, `printer_test.exs`'s generator and
`@required_shapes`, and curated golden sources, before it lands (CLAUDE.md).

**Reals** (decision 150). No infinity and no NaN ever reaches a state, an output, a
`get/2` answer or the forces file. A zero divisor gives 0.0, no power and the minor fault
`:divide_by_zero`, as an integer's (decisions 78 and 99), and a literal `0.0` or `-0.0`
divisor is refused when the program compiles; a result beyond the type's largest finite
value saturates there, with no power, the sign kept; −0.0 is written as 0.0, as Logix
does (RM018A p.882); a value below the type's normal range is flushed to 0.0, as Logix
treats denormals (p.882); and every write to a `real` rounds to the nearest IEEE single
(Ed 3 Table 10 footnote e). `mod` stays integer-only, IEC's MOD being ANY_INT (Table 29
footnote e), and `div` of reals is real division. On the BEAM a float holds no infinity or
NaN, and an overflowing product or sum, a float zero divisor, `0.0 / 0.0`,
`:math.fmod(1.0, 0.0)` and `:math.sqrt(-1.0)` each raise `ArithmeticError` (verified on
1.20.4/OTP 28), which must not leave a scan; `<<x::float-32>>` does **not** raise past the
single's range but encodes infinity (`<<127, 128, 0, 0>>`), which no float-32 match reads
back, so a write saturates **before** it encodes; a subnormal single encodes (`1.0e-45`
gives 1.4e−45), so the flush is logex's own; and `0.0 === -0.0` is false, a match on
`0.0` missing −0.0, which is why one zero is kept (all verified on 1.20.4/OTP 28).
`sqrt`, which decision 79 kept for a real, lands with the reals; a negative source,
which raises on the BEAM, writes 0.0, passes no power and raises the minor fault
`:negative_sqrt` (decision 164), the source checked before the BEAM's square root is
called, as a divisor is checked before it divides.

**Bit strings, the bitwise instructions and bit access** (decisions 155 and 160). `byte
word dword lword` are types of their own, IEC's, with no arithmetic: `add` of a `word` is
refused, IEC's arithmetic taking ANY_NUM, which holds no bit string (Ed 3 Figure 5). The
bitwise instructions are IEC's, lowercased (Ed 3 Tables 30 and 31), and take bit strings
**and** integers, the maintainer's "Logix-friendly" (Logix's AND, OR, XOR and NOT take
SINT to LREAL, RM018A pp.494–496): `and a b dst`, `or a b dst`, `xor a b dst`, `not src
dst`, and `shl src n dst`, `shr`, `rol` and `ror`. Each computes in its destination's
type by decision 147, so its operands are all bit strings or all integers, a mix
refused naming the conversion (the second question, answered as recorded, decision 155's
note), and on an
integer it works on the two's-complement pattern of the destination's width. `shr` fills 0
on the left, a logical shift, as IEC's (*"zero-filled on left"*, Table 30) and unlike the
classic Siemens `SHR_I`, which sign-extends; `rol` and `ror` are circular within the
destination's width. `n` is a literal or an integer tag; a shift of the width or more
gives 0, by IEC's zero-fill definition, with its power in; a rotate of n rotates by n
modulo the width (IEC's text says only "circular", **unverified** for n at or past the
width); a negative literal `n` is refused when the program compiles, IEC calling it an
error (Table 30 footnote a); and a tag `n` that is negative at run time acts as a count
of 0, the source written unshifted, with no power out and no fault (decision 165). Apart
from that one case a bitwise instruction cannot fail, so its power out is its power in,
as Logix's rung-out (a routine choice below). `docs/naming.md` planned `wand wor wxor wnot`,
reasoning that *"logex's env is untyped integers, so the reader is the type checker"*;
the types end that premise, and rule 1 takes IEC's words (its note is amended); its other
worry, that a bare `or` would read as a branch, does not arise, since `or` stands where a
mnemonic stands and a branch is `(`, `|` and `)` (B1).

A bit is `status.3`, a literal from 0 to the width less one, or `status.[n]`, an integer
tag of any integer type, as Logix writes it (RM094N p.86: *"MyDint.[Index]"*), never an
expression and never an element, on every integer type and every bit string, usable
wherever a bool is (RM018A pp.884–885). A literal bit past the width is refused when the
program compiles; a tag's past it at run time is a major fault (decision 160). A bit of a
`bool` and a bit of a real are refused. A coil on `status.3` writes `status`:
`Logex.Walk.writes/1` records it as a write of `status`, at the bit's path, so that a
`var_external` whose bit a rung writes is a writer of its global (decision 48's warnings),
a bit of a located input point written is refused as a write to an input is, and `move x
status` beside `ote status.3` draws the second-`ote` warning in its words. A one-shot's
storage bit, and each of a pulse coil's two bits, may be a bit with a literal number,
named by its path, never `status.[n]` (decision 154's rule); Logix 32.04 refused bit
addresses of its 64-bit and unsigned types in ONS, OSR and OSF (release notes), and logex
need not, since a storage bit is looked up by its path. IEC defines partial access on bit
strings only, `By.7` with `%X` omitted (Ed 3 Table 17), so a bit of an integer and a tag
bit number are Logix's, rule 2's.

**Arrays** (decisions 151 to 154). `var temps real[8]`, `var grid int[4,8]`, `var cube
int[2,3,4]`: Logix's form (PM004L pp.34–36), a count for each dimension, one to three
dimensions, each subscript from 0, the rightmost varying fastest (PM004L p.35), so that
the elements have one order, which a located array's addresses and an initial list
follow. An element is `temps[3]` or `grid[1,7]`; each subscript is a literal or an integer
tag of any integer type, `weights[slot]`, never an expression and never an element,
IEC's rule for the graphical languages (*"single-element variables or integer
literals"*, Ed 3 §6.4.4.5.1 p.39). An array starts at its element type's zero, or with
one literal for every element, `var limits int[3] 10 20 30`; a list of another length is
refused, where IEC truncates or fills with a warning (pp.39–40). It may be a `var`,
`var_input`, `var_output`, `var_external` or `var_global`, located or not (decision 156).
A literal subscript outside its dimension is refused when the program compiles; a tag
subscript outside it at run time is a major fault (decision 153), checked where the
element is read or written, as Logix checks it, so a de-energised `otl` writes nothing
and checks nothing (RM018A pp.86–87), and a rung a jump skips and a block whose `cal` is
false check nothing (decision 82's frozen state). An array may hold instances, `var
lane_t ton[4]`, `var lanes seal[4]` (decision 154): every instruction that runs one,
`ton lane_t[2] 500`, `ctu`, `cal` and the rest, and every one-shot's storage bit or pulse
bit on an element, `ons edge[2]`, takes a literal subscript, so that each element is its
own instance with its own path, `lane_t[2]`, under M1-6's one-run rule, decision 85's two
counter rungs and the edit's block list (decisions 32, 87 and 106); a member is read or
written through a tag subscript, `xic lane_t[slot].dn`. `get/2` and a connection line name
an element `m1.temps[3]`; a host's value for an array `var_input` is a list of the
declared length, a list of lists for more dimensions, each element checked by `fits?/2`,
any other an `ArgumentError` whose message a test pins; `get/2` gives a whole array the
same shape. Size limits are a spike's to measure (a proposal: 1 to 65,536 elements in
all); Logix's is 2 MB (RM094N p.85).

**The major fault** (decisions 153 and 160, amending decisions 99 and 113). An index or a
tag bit number out of range is a major fault. The instruction does nothing, each as the
record states it instruction by instruction: a contact passes no power, a coil and a
one-shot write nothing and pass no power, a `move`, an arithmetic, a bitwise or a
conversion instruction writes nothing and passes no power, and the rest of the rung runs
on that power; the scan finishes. `%Logex.Fault{}` gains `severity`, `:minor` for a zero
divisor and for a negative square root, `:negative_sqrt` (decision 164), and `:major` for
the new kinds, `:index_out_of_range` and `:bit_out_of_range`, and
the subscripts or bit number read; it is placed as decision 99 places a fault, in a lone
instance's `state.faults` and as a cycle's `{:fault, task, instance, fault}` event after
its scan's `{:ran, ...}`. `Logex.Runner` trips on the round's first major fault at the end
of the step that raised it, one task's run or the untimed instances' run (`cycle_step/2`,
decision 118), as it checks a timed task's watchdog when the step is done: the step's own
run scans every instance it holds, and none of the round's later steps runs (the tenth
question put to the maintainer, answered as recorded, decision 153's note). It trips before it writes the round's
outputs, on decision 113's one path, every output 0 once, its reason `{:fault, task,
instance, fault}`, so that the trip names the instance, the file, the line and the index,
and `get/2` reads each later task's instances as the round before left them. A host that
drives the resource itself through `cycle/3`, which runs every due step, sees the event
and decides. Logix raises major fault 4/20 for a subscript out of range (RM018A p.869,
p.884; PM014O p.20) and halts logic (PM014O p.9), where logex runs the faulting step on:
the outputs are not written either way, and only the state `get/2` reads after the trip
differs. The S7-1500 goes to STOP; the S7-1200 stays in RUN with a diagnostic entry (TIA
V21 *Addressing ARRAY components*); CODESYS checks only with `CheckBounds`; no vendor
clamps or wraps an index.

**I/O points** (decision 156). Every elementary scalar type may be located, and so may an
array: `var_global temps real[8] at card.i.0` occupies `card.i.0` to `card.i.7`, in the
elements' order, each element a point of its own, read, written and forced by its name,
`temps[3]`; the range may not overlap another point, and a configuration that overlaps is
told both names. An adapter's `check/3` refuses a type its device cannot carry. A value a
device, a host's `put_inputs/3` or a force gives is checked by
`Logex.Declarations.fits?/2`: an integer point takes only an integer that fits, a float
refused; a real point takes a float or an integer, stored as the nearest value of its
width, an integer's lost precision silent, as Logix's is, so that 16,777,217 at a `real`
point is 16777216.0, and only a value beyond the type's range a bad value (decision
166), where decision 147 refuses a literal the slot cannot hold exactly; a bit
string takes an integer from 0 to 2^N−1, as the unsigned integer IEC compares it as (a
reading of decision 156's integer rule). A refused device value trips the runner as a bad
value (decision 114). The forces file spells a real so that it reads back exactly, as
decision 140's strict reading needs: an `lreal` in its shortest round-trip form, and a
`real` in the shortest decimal that rounds to the same **single**, which logex writes
itself, since `Float.to_string/1` spells the double that holds the rounded single, 0.1
forced into a `real` giving `0.10000000149011612` (verified on 1.20.4/OTP 28); the
configuration file's `print/1` of a real global's initial value and constant takes the
same rule for its exact round trip. IEC's directly represented variables carry a size
prefix and are bit strings (`%IW215`, Ed 3 Table 16); logex's location has none, since the
declared type carries the size (§4.5).

**An online edit** (decision 157). A tag's, member's or global's type, an array's element
type, its dimensions and its sizes, change only with a restart, as §4.9's type rule has it
for every type: `boxes` from `usint` to `uint`, or `temps` from `int[8]` to `int[10]`, is
refused at accept, in the words of §4.9's refusal. Decision 29's report of a changed
initial value is widened to every type, a real's, a bit string's and an array's, element
by element, and the declared values are compared exactly, so that an initial `0` and `0.0`
are two values, where `!=` finds them equal (`Logex.Edit.Plan.changed/2` guards on
`[:bool, :dint]` today and compares with `!=`): `var x real 0` edited to `var x real 0.0`
is reported, `{:initial_changed, "x", {0, 0.0}}`, the running value kept, although a new
instance starts at 0.0 under either (a real's zero is 0.0 in every state, a routine choice
below), since the edit compares what the two programs declare, not what
`Program.initial_env/1` makes of it; decision 44 takes the same for a global. Logix
changes an array's size or type offline only (RM094N p.85), and IEC says nothing of online
edit.

**Timers and counters** (decision 158). The counters take IEC's typed variants, one for
each integer type Ed 3 Table 45 gives a counter, INT, LINT, UDINT and ULINT, the type
words `ctu_int ctu_lint ctu_udint ctu_ulint`, `ctd_int ctd_lint ctd_udint ctd_ulint` and
`ctud_int ctud_lint ctud_udint ctud_ulint`, their `pv` and `cv` of that type, each
stopping at its type's limits with `ov` or `un` latched (decision 71 by width); `ctu`,
`ctd` and `ctud` stay IEC's CTU_DINT, CTD_DINT and CTUD_DINT (features 1b, 2b, 3b), where
IEC's plain CTU is CTU_INT (feature 1a), a departure logex has made since M3-1; and
`ctu_dint`, `ctd_dint` and `ctud_dint`, IEC's typed names for those three, are aliases
of them (decision 163), the same types, so that an instance declared with either word is
one type, named in every message and warning by the plain word. The
instructions stay `ctu` and `ctd`, each running every counter of its kind, as `ctu` runs a
`ctud` (M3-1), its preset judged in its instance's type (a routine choice below). The long
timers are IEC's `ton_ltime`, `tof_ltime` and `tp_ltime` (Ed 3 Table 46 features 2c, 3c
and 1c), and `rto_ltime`, the "rto equivalent if fitting" the maintainer allowed, taken
(the seventh question, answered as recorded, decision 158's note), run by `ton`, `tof`,
`tp` and `rto`: their `pre`
and `acc` are `lint` counts of **nanoseconds**, as IEC's LTIME is (*"a signed 64-bit
integer with unit of nanoseconds"*, Ed 3 Table 10 footnote m), and the preset on the
instruction is in nanoseconds, 0 to 2^63−1, about 292 years. The TIME and LTIME types
themselves stay deferred, so a preset is a plain integer, ms for the `ton` family and ns
for the `_ltime` one. **The resolution is a millisecond.** `Logex.Runtime`'s `now` and
every `elapsed_ms` it is given are whole milliseconds, and `Logex.Runner` reads its clock
in milliseconds (§4.11), so a long timer's `acc` moves in steps of 1,000,000 ns, and one
whose preset is not a whole number of milliseconds is done at the first scan whose `acc`
reaches it, at the millisecond after; the compiler warns of such a preset (a routine
choice below). A finer clock would put nanoseconds into the core's `now`, a later item.

**Widening beyond an instruction** (decision 159). A `cal`'s inputs and a connection's
copy-in widen as an instruction's sources do, and a `cal`'s outputs and a connection's
copy-out as a destination does (IEC rules 4 and 5, p.66: *"may be applied for the
assignment of an input parameter … of an output parameter"*), anything else refused
naming the conversion, so a connection's copy-out that narrows is refused, as a `move`
that narrows is; a `var_external` binds only to a global of exactly its type, an array's
element type and dimensions included, since it *is* the global (decision 49's one copy),
as IEC's rule 6 forbids implicit conversion for in-out parameters.

**Reserved words.** Each word below becomes reserved in any case where its kind is
(§4.8), owes its `docs/naming.md` stanza before its code, and is named in the commit that
reserves it with the tags, labels, globals and instances it breaks: the type words `sint
int lint usint uint udint ulint real lreal byte word dword lword`, in every `.ld` and
`.logex` file, `int`, `real`, `byte` and `word` the likeliest to break a tag; the twelve
typed counters, the three aliases `ctu_dint ctd_dint ctud_dint` (decision 163) and the
four long timers, in every `.ld` file; and the mnemonics, in every `.ld` file, `and or
xor not shl shr rol ror`, the 182 conversions and `sqrt`. A family of
conversions may share one stanza that names each member, `naming_test.exs` reading the
family's names as data (a routine choice below).

**Routine choices, each with the alternative it passes over.**
- *One table of types* in `Logex.Declarations`, each type's word, kind, width, range,
  zero and article, read by every message, guard and `fits?/2`, and by
  `Logex.Configuration.Text`'s type words and did-you-mean; over the nine `type in [:bool,
  :dint]` guards and thirteen hand-written range messages of today. *(Landed with M5-1,
  2026-10-21: `Logex.Declarations.table/0`, read through `is_elementary/1`, `fits?/2`,
  `a_type/1`, `misfit/2`, `initial_misfit/2`, `values/1` and `either/1`, its width kept in
  bits, the record's "Bytes" times eight, and its kinds `:boolean` and `:signed` so far.)*
- *A real's zero is 0.0 in every state*, never 0, from `initial_env/1` and
  `Configuration.initial/1`; `get/2` gives a float for a real; over a zero that is an
  integer until first written.
- *An instruction's destination type is looked up in the routine's table, `scan.tags`, at
  run time*, which `cal` already reads, so the IR, `lowered?/1`, `Logex.Walk` and the
  edit's rung comparison keep their shape; over a typed IR symbol, the fallback should
  the spike find the lookup dear.
- *An array's value in a state is a tuple* (a tuple of tuples for more dimensions), read
  in constant time and copied on a write; over a map keyed by subscripts. A growth test in
  reductions settles it.
- *A write through a tag subscript is a write of the whole array* in
  `Logex.Walk.writes/1`, so two coils on `lamps[slot]` and `lamps[2]` draw the
  second-`ote` warning; a literal subscript is its element's path, `lamps[2]`; over
  writes that no rule could see.
- *A bitwise instruction's power out is its power in*, since it cannot fail; over no
  power where a shift drops a 1, which IEC does not call an error. *(Amended by decision
  165: a shift or rotate whose count is a tag negative at run time passes no power.)*
- *A counter's or timer's instruction runs every typed variant of its kind*, `ton` a
  `ton_ltime`, `ctu` a `ctu_int`, its preset judged in its instance's type and unit; over
  an instruction for each variant, `ton_ltime lt 30000000000`, twelve more mnemonics in
  the signatures for no rule of their own. Its cost: the rung does not say the unit, which
  is the declaration's, so the same rung `ton t 2000000` is 2,000,000 ms, about 33
  minutes, where `t` is a `ton` and 2 ms where it is a `ton_ltime`, and a declaration
  changed from one to the other while the line is stopped compiles with every preset a
  million times off; the warning below catches a long timer's preset that is not a whole
  number of milliseconds, `ton t 2000` on a `ton_ltime`, and not this one, a valid preset
  either way. The alternative passed over would say the unit on the rung, `ton_ltime t
  2000000`, and refuse the rung whose mnemonic is not its instance's type. Each stanza and
  the README's timer section say the unit is the instance's.
- *A long timer's preset that is not a whole number of milliseconds is warned of*,
  "times as the next whole millisecond"; over silence.
- *`status.[n]` lexes as one name token*, as PLAN §5 made `t1.dn` one, `QUALIFIED` grown
  by `\.\[{NAME}\]` and the subscripts by `\[({NAME}|{INT})(,({NAME}|{INT})){0,2}\]`; over
  tokens and a grammar production, which would change every operand's shape.
- *A family stanza for the conversions*, one for each IEC table, each member named;
  over 182 stanzas that say the same thing 182 times.
- *The oracles in `api_contract_test.exs` restate every range, wrap and rounding rule in
  Elixir* without calling `Logex.Declarations`, as they do for the dint today.

**Left open, for the item that meets it, and answered by the maintainer on 2026-10-21**,
each a decision of its own:
- `sqrt` of a negative source (it raises on the BEAM; decision 150 rules out a NaN): 0.0,
  no power and a minor fault, `:negative_sqrt`, decision 99's kinds grown by one
  (decision 164).
- A shift or rotate whose `n` is a tag that is negative at run time (IEC: an error, Table
  30 footnote a): it acts as a count of 0, the source written unshifted, with no power;
  a count of the width or more shifts everything out, 0; a rotate takes its count modulo
  the width; no fault in any case (decision 165).
- An integer at a real point, from a device, a host or a force: stored as the nearest
  real, its precision lost silently, as Logix does; only a value beyond the real's range
  is a bad value, and trips (decision 166).

**Put to the maintainer, where two answers meet or an answer leaves a reading open, and
answered on 2026-10-21.** Each question gives the reading the record took and the
maintainer's answer: seven as the record read them, each a note on the decision it
settles, and three otherwise, each a decision of its own.
1. *Real to integer, in range and out of it* (decisions 146 and 148). The record read
   "truncate, then wrap" as a second rounding at the range's edge: where the rounded
   value does not fit, the real truncated toward zero instead and the truncated value
   wrapped, 32767.6 giving 32767 and 40000.7 −25536. **Answered otherwise: round, then
   wrap, as IEC and Logix do** (decision 161): one rounding everywhere, the rounded value
   wrapped with no power, 32767.6 → −32768, 32768.4 → −32768, 40000.7 → −25535, and IEC's
   own case, 70000.4 → 4464 (Ed 3 §6.6.2.5.3 p.79; RM018A p.875).
2. *Bitwise on integers, and mixed types* (decisions 155 and 147). Read: an instruction
   is all bit strings or all integers, `and status 16#00ff speed`, a `word` with an `int`
   destination, refused naming `word_to_int`. **Answered as recorded** (decision 155's
   note).
3. *Typed conversions with an overloaded truncation* (decision 148). Read: `trunc_int`,
   IEC's overloaded TRUNC (Table 22 feature 2c), eight names. **Answered otherwise:
   IEC's typed form, `real_trunc_int`** (feature 2b), sixteen names, `real` and `lreal`
   each to the eight integer types, and not `trunc_int` (decision 162).
4. *"Never hide a rounding mode inside a conversion name"* (decision 148). Read: kept,
   `real_to_int` rounding as IEC fixes it and truncation named apart; the alternative
   refused `real_to_int`. **Answered as recorded: kept with `real_to_int`** (decision
   148's note).
5. *Counters and the wrap* (decisions 146 and 158). Read: decision 146 replaces decision
   77 alone, and the counters stop at their type's limits, decision 71 by width, where
   Logix's roll over. **Answered as recorded** (decision 158's note).
6. *`ctu` and IEC's CTU* (decision 158). Read: no `ctu_dint`, `ctd_dint` or
   `ctud_dint`, one spelling for one thing. **Answered otherwise: the three exist, as
   aliases of `ctu`, `ctd` and `ctud`, which are the same thing**, each owing its own
   stanza (decision 163, which says how a message and a warning name an instance
   declared with either spelling).
7. *`rto_ltime`* (decision 158). Read: IEC's suffix on the vendor's mnemonic, so taken.
   **Answered as recorded: taken** (decision 158's note).
8. *"Wrap, as the vendors do", with no power* (decision 146). Read: the S7-1200's, no
   power, where Logix's ladder passes power. **Answered as recorded: a wrap passes no
   power** (decision 146's note).
9. *A bit string compared with an integer* (decisions 147 and 155). Read: a comparison
   of a bit string with an integer tag, `eq drive_status fault_code`, refused naming
   `int_to_word` and `word_to_int`, a literal judged by its slot, so that `eq
   drive_status 16#0004` is taken. **Answered as recorded** (decision 147's note).
10. *When the runner trips on a major fault* (decision 153). Read: at the end of the step
    that raised the round's first major fault, that step scanning every instance it
    holds and no later step of the round running, before the round's write; the
    alternative ran every due step and tripped after the last. **Answered as recorded:
    at the end of the step that raised it** (decision 153's note).

**Unverified.**
1. CODESYS's tie rule for `REAL_TO_INT`: its page's one example, −1.5 → −2, and ABB's
   mirror, 1.5 → 2, fit ties-to-even and ties-away alike, so `docs/naming.md`'s "half away
   from zero" is unproven; and the S7-1200's Table 7-40 for 0.0/0.0, where its
   zero-divisor row (0 returned) and its 0/0 row (NaN) overlap.
2. What Logix stores when a negative value goes into an unsigned type (RM018A p.874);
   which rounding Logix uses for a DINT into a REAL (p.872 says to nearest even, p.874
   that the low bits are truncated); what the S7-1500 stores on overflow; CODESYS's ENO on
   overflow and the type of a mixed signed and unsigned result.
3. IEC Ed 4's body: UCHAR and USTRING's details, whether octal literals were removed, and
   whether Ed 3's overflow and conversion rules changed.
4. Whether Logix has enumerations, subranges, references or unions for programs: none was
   found in the manuals read, which is not a proof of absence.
5. Whether Logix Designer forces a BOOL array's size to a multiple of 32 (only
   third-party pages say so; RM094N p.84 says only that it is stored in 32-bit words).
6. The version that brought Logix's TIMER_T and time types.
7. That two's complement is required by IEC anywhere: no clause read says it.
8. IEC's ROL and ROR for a count at or past the width (logex's rule is decision 165's
   either way), and the typing of ST's unary minus
   on an unsigned operand (Ed 3 Table 71), neither read.
9. That Logix has no shift-by-N instruction for integers: the survey found none
   (`docs/naming.md`, "Bitwise and shift"), and RM018A's shift instructions are BSL and
   BSR over a bit array (Chapter 9).

**Deferred**, each a later item or milestone: TIME, LTIME, the dates and `T#` literals;
strings and characters; enumerations, named values and subranges; structures and UDTs and
directly derived types; typed literals and octal; references; IEC's array bounds,
`ARRAY[*]`, an initial list with repeats, more than three dimensions, and whole-array
`copy` and `fill`; IEC's byte, word and double-word partial access, `w.%B1`; online
widening of a type or an array (decision 157's second option); `round`, `ceil` and
`floor`; the BOOL, BCD and real-to-bit-pattern conversions; and nanoseconds in the core's
clock. **Not adopted:** pointers, unions, target-width integers and Logix's literal
suffixes.

---

## 5. Decided now, and deferred

| Item | Status | Reason |
|---|---|---|
| Routines (subroutines that share their program's scope), JSR/SBR/RET | **deferred, by decision** | IEC has no routine. Its callable units are FB instances, functions and methods (Ed 3 §6.6.1.4.1). `cal` on a function block covers factoring. Revisit only if FB calls prove too heavy for splitting a large program |
| Controller-scope (reach-anywhere) tags | not adopted | IEC scopes globals through VAR_EXTERNAL (Ed 2 §2.4.3) |
| Program-to-program parameter connections | not adopted | IEC has no counterpart. Link through a named global (Table 49 8b/9b) |
| Several resources (`RESOURCE … ON`) | deferred | The single-resource form is legal (Ed 2 §2.7.1 NOTE). One resource is one runtime value, and later one process. MatIEC's back end has the same limit: *"C code generation currently only allows a single configuration"* (`generate_c.cc`) |
| Preemption | not adopted | It gives up determinism, and nothing is observable in zero logical time (§4.6) |
| FB-to-task association (`FB1 WITH SLOW_1`, Table 49 f6b) | deferred | Rarely needed. It splits an FB's execution from its program's scan |
| Direct representation `%IX0.0` and raw addresses in connections | not adopted; the fallback for §4.5 | One declared, named I/O list instead |
| Wall-clock runner, `Logex.IO` adapters, watchdog | **landed**, `PLAN.md`'s Milestone 4: designed and decided 2026-10-17 (§4.11, decisions 108–121, and 122–128 after M4-1's review, 2026-10-18), built as M4-1 to M4-6 from 2026-10-17 to 2026-10-20 (decisions 129–143), and documented by M4-7 on 2026-10-20: `Logex.Runner`, `Logex.Runner.Clock` with its monotonic and manual clocks, `Logex.IO` and `Logex.IO.Sim`, the one adapter shipped | Outside the pure core. Nothing in M2 blocks them. A queue of tasks by due time, if a plant with many tasks wants one, is the runner's (§4.10). *(The core gains only the cycle in steps, decision 118, and the configuration's `watchdog` and `continuous`, decisions 110 and 111.)* |
| Restarting one program instance inside a resource | not adopted (Milestone 2's design, §4.10) | `restart/2` restarts the whole resource (decision 38). Restarting one instance would be another rule for the input image and the tasks, for a need no decided text states |
| `var_external` in a function block's file | refused (Milestone 2's design, §4.8) | A deliberate, reversible departure from IEC: a block takes a global through a var_input operand |
| VAR_CONFIG, RETAIN / warm restart, forcing | target | VAR_CONFIG: when two instances need different internal initial values, and with it a warning for a global something reads and nothing writes (§4.10). RETAIN: on M1-5's `restart/3`, which landed without it (`:warm` is `:cold` until then). Forcing: a force map applied after the input latch and before the output return, in `cycle/3`. *(Input forcing comes first, in the runner, decision 117, its forces kept in a file across a crash, decision 127; output forcing waits for this.)* *(Input forcing landed with M4-5 on 2026-10-19, `Logex.Runner.force/3`, decisions 138–140; VAR_CONFIG, RETAIN and output forcing are still targets, and `:warm` is still `:cold`.)* |
| VAR_ACCESS; a host write path | deferred | VAR_ACCESS serves IEC 61131-5 communication services. `Runtime.get/2` reads by the same path shape. A host write, if wanted, is limited to unlocated globals |
| Data types beyond `bool` and `dint` | **decided for Milestone 5**, 2026-10-21 (§4.12, decisions 144–160, and 161–167 answering the record's questions the same day; `PLAN.md` §3, Milestone 5), none built yet | IEC's eight integer widths, signed and unsigned, wrapping on overflow; `real` and `lreal`; `byte word dword lword` with `and or xor not shl shr rol ror` on bit strings and integers; bit access `x.3` and `x.[n]`; IEC's typed conversions; arrays of up to three dimensions, of instances and at I/O points; typed counters; long timers in ns. Deferred: TIME, LTIME and the dates, `T#` literals, strings, enumerations, named values, subranges, structures, typed literals, octal, references |
| STRUCT, arrays (data hierarchy) | deferred, as a named later stage *(arrays decided for Milestone 5, 2026-10-21, decisions 151–156; STRUCT still deferred)* | Independent of the organisation model. A TON instance is logex's first structured value, and M1-6's nested state is what a STRUCT will reuse |
| Namespaces, CLASS, METHOD, INTERFACE (Ed 3) | deferred | These are library and module tools, not runtime structure |
| VAR_IN_OUT, VAR_TEMP, CONSTANT, user FUNCTIONs, `T#` literals | deferred | Each gets its own naming survey. Integer ms stays. *(Kept by Milestone 5, decision 158: the TIME and LTIME types and `T#` stay deferred, a preset stays a plain integer, ms for the `ton` family and ns for the long timers.)* |
| IEC textual paste-compatibility (`END_*` blocks, `:=`, `;`) | not adopted | logex is a dialect (`PLAN.md` §5) |
| Online edit (a new type, instances keep their state) | **OE-1 landed 2026-10-01** (§4.9): the staged edit of one program instance, `Logex.Edit`; OE-2, a configuration's, after Milestone 2, designed, decided and **landed 2026-10-13** as `Logex.Configuration.Edit` (§4.9, "OE-2's design"; decisions 55–65); the edit of a program that holds function blocks (decisions 31 and 32) landed with M2-5 on 2026-10-04 | Instance state stays keyed by declared tag name, which is what lets an edit move it by name. A *plain swap*, a recompile of the same name scanned over a kept instance with no edit, stays in the contract (decision 26) and does what it did before OE-1, since a state's values are not checked each scan: the instance keeps its values until a restart. So it keeps its old `.pre` under a changed preset; a tag the recompile adds reads 0, not its initial value, so an added timer starts at a `.pre` of 0 and is done at its first true scan; a tag whose type it changes keeps its old value, so a timer recompiled as a `var_output` gives its map as an output; and an `ons` it adds fires on its first scan if its condition is already true (`end_to_end_test.exs` pins all but the type change). A restart puts the values right, keeping only the var_inputs whose values fit their types. `Logex.Edit` moves the state by rule instead: a switch moves `.pre` where it still holds the old preset, starts what is added at its initial value, at the first test restarts a value that does not fit its type, and blocks an added or changed `ons` for one scan; accept refuses a type change. |

---

## 6. The road

### 6.1 Change these Milestone 1 items now, or they get redone

Each is a field or a sentence now and a migration later.

**M1-3 (tag table).** Keep the design panel's recommended design, and add four points.
`PLAN.md` M1-3 records the design with all four.
1. **Write the section and type words as data tables.** Then `var_external` is one more
   row, and M1-6's `var t1 ton` and M2-5's `var s1 seal` resolve through the same type
   lookup. No second declaration parser is needed.
2. **State that the file is the POU's scope, and that there is no controller scope.**
3. **Cite what is now quotable, instead of marking it `unverified`:**
   - VAR_OUTPUT's spelling (Ed 2 Table 16a; Ed 3 Figure 7);
   - that logic must not write a var_input. That is IEC's rule, *"not modifiable within
     organization unit"*, not only logex's;
   - DINT's 32 bits (Ed 2 Table 10, p.30);
   - the default initial value 0 (Table 13, p.34);
   - keyword case-insensitivity and reservation (§2.1.3).
4. **Say that the flat integer env is a Milestone-1 fact.** No M1-3 check should depend on
   it.

**M1-5 (public API).**
1. **`%Logex.Program{name:, tags:, rungs:, source:, warnings:}`.** The name comes from
   `Logex.compile_file("motor.ld")`, which uses the basename, or from
   `Logex.compile(source, name: "motor")`. A configuration refers to types by name, so this
   is the field Milestone 2 cannot do without.
2. **Make the core the instance call:** `Runtime.call(program, state, inputs, scan)`.
   Unknown or non-input keys in `inputs` are errors. `scan/2` and `scan/3` stay as sugar
   for one task-less instance.
3. **Widen `%Logex.Diagnostic{}` once, with `file:`, `stage:` and `column:` together.** A
   configuration's errors span several files, and a second widening would touch every
   diagnostic test again.
4. **`Runtime.restart(program, state, :cold | :warm)`** is the RETAIN hook that M1-3
   already assigns here. The M1-3 design panel sketched `restart(program, env)`; the
   `:cold | :warm` argument is this document's addition, and `PLAN.md` M1-5 records the
   three-argument form.
5. **Amend the Milestone-1 done sentence:** "…compiled once into a *named, stateless* value
   you can hold, run for N scans *as an instance* against a typed tag table…".
6. **Land B5 immediately after.** Every recursive `evaluate` clause becomes a `defp`. An FB
   call re-enters rung evaluation for another body, and it must not do so through a
   public clause.

*Landed 2026-09-29, all six; `PLAN.md` M1-5 records the design the maintainer took and
where the landing departs from it. Beyond the six: `%Logex.Diagnostic{}` also gained
`severity:`, for the three warnings M1-3 deferred; an instance is a `%Logex.Instance{type:,
env:, now:, first:}` that holds no program and is matched to one by name; and `restart/3`
keeps the var_inputs, with `:warm` equal to `:cold` until `retain` lands. B5 went in just
before M1-5's documents rather than just after them.*

**M1-6 (TON, ONS, comparisons, scan loop).** *(The scan loop is not M1-6's after all:
since M1-5 the host calls each scan, scheduling is M2-1's, and the wall-clock runner comes
after Milestone 2, §5.)*
1. **`evaluate/3` with a read-only `%Logex.Scan{now:, first:}`.** This changes CLAUDE.md's
   `evaluate/2` convention. The accumulator stays `{power_flow, env}`. Every existing
   clause gains an ignored third argument.
2. **Declared instances:** `var t1 ton`, IEC's `T1 : TON` without the colon. A timer used
   without a declaration gets M1-3's "not declared" diagnostic.
3. **Nested instance state**, with a schema per FB type such as `%Logex.FbType{name:
   "ton", members: …}`. User FBs in M2-5 reuse that schema. Reword PLAN M1-6's "a struct
   per timer instance" and §5's "a struct per instance" as "a per-instance record".
   `ton` keeps its internal last-scanned time
   there (§4.6), and `ons` reads `scan.first`.
4. **Member writes (decision 9).** Members are readable anywhere; logic may write only
   `.pre` and `.acc`. IEC forbids passing an FB output as a VAR_IN_OUT, *"to prevent the
   inadvertent modifications of such outputs"* (Ed 2 §2.5.2.2, p.70); no general
   read-only rule was found. That the conventional family lets logic `move` into `.pre`
   and `.acc` is **from memory**. A dotted name that is not a declared member is a
   diagnostic.
5. **Spike a real `ton` before calling this model settled:** one program type, two
   instances on 10 ms and 50 ms tasks, with an assertion that `.acc` reaches the preset at
   the same logical time in both.
6. **Land the settled `.` and `//` rules exactly as written.**
   - `a.1b` must be a lex error. The settled rule stops at `a.1`, and B2's rule that
     digits running into a letter are one mistyped lexeme rejects the rest. The
     configuration spike's looser `.` clause accepted `a.1b` as one name.
   - `ote a // note⏎ote b` must parse as two rungs.
   - The golden record changes in exactly two entries, `"ote a.b"` and `"ote aa //
     note"`, which move from `{:lex_error, 1}` to parsed ASTs. The commit reads that diff.

   *(Landed 2026-09-30, as written: two commits, one entry each. A declared tag's name may
   not have a `.`.)*
7. **Fix B8 (a lone CR) before any `.logex` exists.** It would bite configuration files
   exactly as it bites programs. *(Landed 2026-09-30.)*

*Landed 2026-09-30, points 1 to 5 as written; `PLAN.md` M1-6 records the design and where
it goes beyond them. Beyond the five: the schema is `%Logex.FbType{}` carried inline as a
tag's type, with members that have a role and a write flag; a member is lowered to
`{:member, line, path}`; the preset is the timer's starting `.pre`, not rewritten by
`ton`; one `ton` runs a timer, and one `ons` uses a storage bit; nothing may follow a
`ton` on its path (§4.3); and the first true scan adds no time, with `last` stamped on
every run (§4.6).*

### 6.2 Milestone 2: organisation (now `PLAN.md` §3, Milestone 2)

*(Designed 2026-10-02: §4.10 gives each item's rules, and `PLAN.md` §3 the order,
decision 30, and each item's commits. The notes below mark where the design changes this
section.)*

Each item surveys its own new words in `docs/naming.md` before its code lands, appending
the stanzas. Each lands green on its own. Every diagnostic is pinned by a test that
asserts whole diagnostic lists from source, like `validation_test.exs`. *(M2-1 has no
source, so it pins the §4.4 checks it lands by whole lists from data, and M2-2 asserts
each again from source; §4.10.)* Each rule is checked by reverting it (CLAUDE.md; PLAN
§2·M0-4). For example:
- delete the one-driver check → a test fails;
- delete the input-point check → a test fails;
- drop priority ordering → a test fails.

**M2-1 · The scheduler, built from Elixir data. No syntax.** *(Landed 2026-10-02;
`PLAN.md` M2-1.)*
- Keeps §4.9's constraints, so online edit needs no rework.
- `%Logex.Configuration{}` with a pure, checked constructor.
- `Runtime.start/cycle/next_due_in/get`.
- Periodic and task-less instances, copy-in/copy-out, overlap events.
- *(Designed 2026-10-02: also every §4.4 check its data can express, moved here from
  M2-2, and `restart/2` and `overlaps/1`, decision 38.)*
- *Acceptance: a configuration built in Elixir with a 10 ms task, a 30 ms task and a
  task-less instance, cycled for one simulated second by an injected clock, runs each
  instance exactly as often as its task dictates, in priority order; a late cycle yields
  one `{:overlap, …}` and no lost phase; the README program gives identical outputs through
  `scan/2` and through a one-instance configuration.* *(Worded 2026-10-02: "cycled every
  10 ms from 0 to 990 ms" in place of "cycled for one simulated second".)*

**M2-2 · The configuration file, task-less.** *(Landed 2026-10-11; `PLAN.md` M2-2.)*
- `.logex` lines: `var_global` (plain and located at `<dev>.i|q.<n>`), `program <inst>
  <type>`, and connections.
- The §4.4 checks, and `Configuration.compile/3` with a loader. *(Designed 2026-10-02:
  the checks land with M2-1, on data, and M2-2 asserts each again from source and ports
  its own into M2-1's `check/1`; the loader is M2-5's, decision 34. Landed: the loader is
  `Logex.Configuration.compile_file/1`.)*
- Reserves `program var_global at bool dint` in `.logex`.
- Adds `configuration_test.exs`. *(M2-1 added it on 2026-10-02, pinning every check from
  data; M2-2 asserts each again from source.)*
- *Acceptance: two instances of one `.ld` program type, wired in a configuration file to
  different input and output points, run for N cycles from one input image and keep
  independent state; a mis-wired, unknown, undriven-input or mistyped connection is a
  located diagnostic naming its file and line.*

**M2-3 · Periodic tasks in text.** *(Landed 2026-10-11; `PLAN.md` M2-3.)*
- `task … interval … priority`, and `with`.
- Reserves `task interval priority with` in `.logex`.
- *(Designed 2026-10-02: a priority is 0 to 65535, decision 37; the acceptance is
  "cycled every 10 ms from 0 to 990 ms"; and its documents state decision 40.)*
- *Acceptance: the §4.4 plant without its event task, its `motor` the §4.2 one plus `var
  t1 ton` and a rung `xic motor ton t1 5000` (so no `estop`, `var_external` or `cal`, which
  arrive with M2-4 and M2-5), driven for one simulated second, runs `m1` 100 times and
  `m2` 20 times, and each instance's `t1` times against the one clock.*

**M2-4 · Shared globals.** *(Landed 2026-10-12; `PLAN.md` M2-4.)*
- `var_external` in `.ld`, reserved there.
- The type-agreement check (Ed 2 §2.4.3), the input-point write check, and the
  two-writer warning.
- *Acceptance: an e-stop declared once as a `var_global` and read by two instances
  through `var_external` stops both in the same cycle; a `var_external` with no matching
  global, or of another type, is a located diagnostic.*

**M2-5 · User function blocks.** *(Landed 2026-10-04; `PLAN.md` M2-5.)*
- Needs M1-6 and B5 only, so it may move ahead of M2-1. *(Ordered 2026-10-02 by decision
  30: after M2-1, before M2-2. It also brings the edit of a program that holds blocks, by
  path, decisions 31 and 32, and the loader, decision 34.)*
- `function_block <name>` files, `var s1 seal` instances, and nesting.
- `cal` with positional operands and the EN semantics of §4.3.
- Member reads, and the recursion diagnostic.
- The appended `cal` stanza.
- *Acceptance: a seal-in written once as a function block and instantiated three times
  in one program behaves as three independent seal-ins, `m1.s2.run` reads one of them, a
  false EN freezes only its own instance, and a recursive type, an unknown FB type or a
  `cal` of a non-instance is a located diagnostic.*

**M2-6 · Event tasks.** *(Landed 2026-10-12; `PLAN.md` M2-6.)*
- `single`, with the §4.6 edge rules, and `single` combined with `interval` *(decision
  39)*.
- Reserves `single` in `.logex`. *(Landed 2026-10-12.)*
- *Acceptance: an event task triggered from an input point runs once per rising edge,
  before lower-priority tasks due in the same cycle, and runs in cycle 1 if its trigger is
  already true.*
- *(Landed 2026-10-12, `PLAN.md` M2-6. With it Milestone 2 is done: `logex_test.exs`
  walks the sentence below from files on disk.)*

**Milestone 2 is done when** a configuration file on disk does all of the following:
- instantiates one `.ld` program type twice, with a function block inside it;
- wires the instances to declared I/O points and to a shared global;
- schedules them under a periodic task, an event task and no task;
- runs deterministically for N cycles from an injected clock and input image, with the
  same outputs on every run;
- reports every wiring, typing or scheduling mistake as a located diagnostic that names
  its file and line.

**Documents each stage stales.**
- `README.md` gets a syntax-list entry and an example that is re-run.
- `PLAN.md` has the Milestone 2 section and a §8 entry ("program organisation"); each
  stage still updates B5's module list and B9's preconditions.
- CLAUDE.md's Key Files gets `configuration.ex` and `runtime.ex` (`runtime.ex` since
  M1-5), and its `evaluate` convention changes at M1-6.
- PLAN §5's organisation bullet carries the one-line summary: "a file is a POU type,
  state is an instance, a configuration instantiates, wires and schedules; no routines,
  no controller scope, no preemption."

---

## 7. Decisions

The first fourteen were taken as recommended on 2026-09-28. Decisions 15–29 were taken on
2026-10-01: 18, 28 and 29 against their recommendations, 19 with none to follow, the
others as recommended. Decisions 21–29 are OE-1's design (§4.9), and the work cites them
as E1–E9. Decisions 30–40 are Milestone 2's design (§4.10), taken on 2026-10-02: all as
recommended but 35, the configuration file's extension, where the maintainer chose
`.logex`, outside the options offered. Decisions 41–45 were taken on 2026-10-04, after
M2-1 landed: 41 outside the options recommended, the others as recommended, 42 with no
preference stated. Decisions 46–52 were taken the same day, all as recommended, from two
throwaway spikes of the run-time pieces no design spike had built, one copy of a global
(M2-4) and event tasks (M2-6). Decisions 53–54 were taken on 2026-10-05, as recommended,
from the check of M2-5's fixes. Decisions 55–65 were taken on 2026-10-13, all as
recommended, from OE-2's design (§4.9, "OE-2's design"). Decision 66 was taken on
2026-10-14, as recommended, from the review of OE-2's landing, which found the case it
answers. Decisions 67–89 were taken on 2026-10-14 from Milestone 3's design (below):
67, 68 and 78 against their recommendations, the others as recommended, 84–89 M3-1's own
routine choices. Decisions 90–92 were taken the same day, after M3-1's review, from three
questions the maintainer was asked then: 90 one M3-2 had left open, 91 and 92 confirming
what M3-1 built. Decisions 93–95 are M3-2's own routine choices, taken as it landed on
2026-10-14, 93 confirmed by the maintainer the same day, after M3-2's review. Decision 96
was taken the same day, after M3-2's review, from a question the maintainer was asked
then. Decisions 97–99 are M3-3's own routine choices, taken as it landed on 2026-10-14,
99 the shape of the report decision 78 left to M3-3, and 98's reading of a `mod` by zero
confirmed by the maintainer the same day, after M3-3's review. Decisions 100–103 are
M3-4's own routine choices, taken as it landed the same day, 102 confirmed by the
maintainer on 2026-10-15, after M3-4's review, and 103's "no warning" superseded by the
maintainer's answer the same day. Decisions 104–107 are M3-5's own routine choices, taken
as it landed on 2026-10-15, 106's rung compared whole and 107's warning confirmed by the
maintainer the same day, after M3-5's review. Decisions 108–121 were taken on
2026-10-17 from Milestone 4's design (§4.11, and below): 108–117 the maintainer's
answers, 108, 109 and 110 against their recommendations, 111 and 112 asked by the
maintainer outside the questions put, the rest as recommended; and 118–121 the record's
own routine choices. Decisions 122–126 were taken on 2026-10-18, after M4-1's review
(below), the record's own routine choices on what the review found the record left open
or loose, 125 superseding 119 in its rule and its cost; and decision 127 is the
maintainer's answer of the same day, forces kept in a file across a crash, given outside
any question put, with the record's choices on how; and decision 128 the maintainer's
answer of that day on the runner's own bound between steps. Decision 129 is M4-2's own
routine choice, taken as it landed on 2026-10-18, the rule across an online edit that
decision 110 left to it. All one hundred and twenty-nine are kept with their options so
the reasons stay with them.

1. **Adopt this direction and Milestone 2's order** (M2-1…M2-6, with M2-5 free to move
   earlier). *Recommend yes.* Adopted. *(Ordered 2026-10-02 by decision 30: M2-1, M2-5,
   M2-2, M2-3, M2-4, M2-6.)*
2. **Take the §6.1 Milestone-1 changes:**
   - a named `%Program{}`;
   - `call/4`;
   - one Diagnostic widening that includes `file:`;
   - `evaluate/3` with `%Scan{}`;
   - declared, nested timer instances.

   *Recommend all.* Each is cheap only before the code it touches exists.
3. **A separate configuration file.** *Recommend yes*, because IEC makes a configuration its
   own library element, distinct from program types (Ed 2 Annex B.0). The extension `.lcf`
   is a placeholder, and whether it clashes with an existing tool is unverified. Choose it
   before M2-2, because a rename later is a migration. *(Chosen 2026-10-02 by decision 35:
   `.logex`. The placeholder was found to clash with four other tools.)*
4. **How an FB file declares its kind:** a required first line `function_block <name>`
   that matches the file name, or a second extension. *Recommend the first line.* It is
   IEC's word, and it keeps one extension for POUs. *(Changed 2026-10-02 by Milestone 2's
   design, §4.10, M2-5: the header is the file's first rung, so comments and blank lines
   may come before it. The lexer drops them before the parser sees a line.)*
5. **Connection spelling:** arrow-free `m1.start pb_start_1`, or IEC's `:=` / `=>`.
   *Recommend arrow-free.* It needs no grammar edit and matches M1-3's dropping of `:=`,
   and the direction is checked at both ends. `:=`/`=>` would cost two tokens and no golden
   entries. Decide before M2-2, or configuration files (`.logex`) will have two spellings.
6. **I/O point spelling:** `at panel.q.0` or `at %qx0.0`. Raw addresses in connections are
   excluded either way. *Recommend `panel.q.0`*, stated honestly as a coinage that keeps
   IEC's I/Q prefixes and hierarchical integers.
7. **Every var_input connected, as an error.** *Recommend yes.* Relaxing it later breaks
   nothing, and tightening it later breaks plants.
8. **Timer time source:** per-timer last-scanned time (this document) or per-instance `dt`
   (the execution design). *Recommend per-timer*, because it catches up in the frozen-FB
   case (§4.6).
9. **Instance state:** nested maps with an `FbType` schema, plus the M1-6 member-write
   rule. *Recommend the nested maps. On member writes, recommend reads anywhere and writes
   only to `.pre` and `.acc`, as the conventional family allows (from memory).* *(For a
   user function block, decision 33 narrows "reads anywhere": its inputs and outputs are
   read anywhere, its own `var`s are hidden, and nothing outside it writes any of its
   members. A timer's rule is unchanged.)*
10. **Reserved-word scope:** by file kind (§4.8), or IEC's everywhere. *Recommend by file
    kind.*
11. **Scheduling policies:**
    - PRIORITY required on every task, with 0 the highest;
    - ties go to the earlier due time, then declaration order;
    - missed periods are coalesced, counted and reported;
    - a SINGLE already true at start fires.

    *Recommend all four.* *(Decision 37 bounds PRIORITY at 0 to 65535, IEC's UINT;
    decision 39 settles SINGLE with INTERVAL; and Milestone 2's design gives an event task
    the cycle's `now` as its due time for the tie-break, §4.10, M2-6.)*
12. **`cal` on a false EN:** writes nothing to its output operands. *Recommend yes*, which
    is IEC's "keep their states". The alternative, writing the frozen outputs again, does
    no harm but hides nothing either.
13. **Units:** `elapsed_ms` injected, `now` kept inside; `interval` in integer ms, not
    `t#`. *Recommend both.*
14. **What a watchdog fault does to outputs,** when the runner exists: stop scheduling,
    zero the output image once, report, and require an explicit restart. Holding the last
    outputs is the alternative. *Recommend zeroing; decide with the runner.* *(Confirmed
    2026-10-17 by decision 113, with the five refinements of Milestone 4's design,
    §4.11.)* *(Landed with M4-4 on 2026-10-18, its review's fixes on 2026-10-19: a trip,
    whatever its reason, stops scheduling, writes every output 0 once through each device
    that answers, which latches and writes nothing more, sends `{:trip, reason}`, keeps the
    resource for `get/2`, and runs nothing again until `Logex.Runner.restart/2`, cold or
    warm (decisions 113 and 133 to 137), which since M4-6 reads every device first
    (decision 142). A stop zeroes every output once too (decision 116), and a runner that
    crashes or is killed is gone, each device writing its outputs 0 once as it goes
    (decision 115). A device that hangs is killed, its outputs left to the device, and a
    VM that stops writes nothing: README's "What logex is not" says so.)*
15. **Declaring a controller from Elixir:** a Spark or macro DSL as the model, or one model
    held as data with text as its saved form. *Recommend data*: whatever a DSL declares is
    compiled into a module, so it cannot be the copy a running controller edits. Adopted,
    with the data API refusing what the text cannot say.
16. **The Elixir compiler on the edit path:** allowed, or never. *Recommend never* (§4.9's
    measurements). Adopted, and recorded in `PLAN.md` §6.
17. **Spark:** inside logex, as a separate authoring package, or not at all. *Recommend not
    inside logex*; a separate package, a one-way seed, stays open. Adopted.
18. **Online edit:** applied at once in its first version, or staged from the start
    (accept, test, untest, assemble, cancel), with §4.9's migration defaults. *Recommended
    applied at once, staging later.* The maintainer chose staging from the start.
19. **Task changes while running:** refuse all, as CODESYS does, or allow what the
    conventional family allows. *Either was open.* The maintainer chose the conventional
    family's: interval and priority may change; moving an instance to another task is
    refused; adding or removing a task is refused until its rule is verified.
20. **Outputs an edit leaves undriven:** hold their last value, or go to 0. *Recommend
    hold, as the conventional family does, with every step's report listing each one and
    the value it holds.* Adopted.
21. **One-shots across a switch (E1):**
    - arm the storage bits the edit adds, by writing them;
    - arm every storage bit;
    - hold every `ons` on the scan after a switch;
    - or block, for that one scan, each `ons` the edit adds or whose rung changed (line
      numbers ignored), through a block list on the instance, never by writing the bit.

    *Recommend the block list.* Arming by writing 1 echoes into a rung that reads the bit.
    Arming only the added bits still pulsed for an `ons` added on an existing tag, and for
    one whose condition changed. Holding every `ons` loses a genuine edge on rungs the
    edit never touched. Adopted: an untouched `ons` behaves normally. *(Changed 2026-10-02
    by decision 32: "for that one scan" becomes "until a scan runs it". At the top level
    every rung then ran, so nothing changed there; inside a function block a false `cal`
    leaves its `ons` unrun.)* *(Changed 2026-10-14 by decision 87: "whose rung changed"
    is read with the preset of every `ton` and counter on the rung ignored too, so a
    `ton`'s preset changed alone no longer blocks an `ons` on its rung.)* *(Changed
    2026-10-15 by decision 106: a rung a forward `jmp` skips leaves its `ons` unrun too, at
    the top level as in a block, so the block holds there until a scan runs it.)*
22. **Inputs across a switch (E2):** report each var_input that becomes live,
    `{:input, name, value}`, and each one the running program no longer reads,
    `{:unread, name, value}`, the host sending the real value of each live one before the
    next scan; or require those inputs as an argument of test and untest. *Recommend
    report*, the input side of decision 20. OE-2's copy-in will then make it automatic.
    Adopted. *(OE-2's design: it does, so `:input` and `:unread` stay in a configuration
    edit's report as facts, with no duty, §4.9.)*
23. **A timer whose `ton` the switched-to program does not run (E3):** its `.pre` goes to
    that program's preset for it, 0, and comes back by the preset rule; or it stays
    frozen, and a switch that restores a `ton` the stopped program did not run sets `.pre`
    to the new preset outright, reported as `:preset`. *Recommend frozen.* Going to 0
    turned an output on under test (`ge t1.acc t1.pre ote early`, with `.acc` at 3000),
    and nothing in the report predicted it. Frozen, then set outright, still gives a
    remove, assemble and restore the preset a restart gives. Adopted.
24. **`Logex.Tag.new!/4`'s preset map (E4):** withdraw it, refusing any initial value on
    an instance with the message a declaration line gets; or refuse it only where no `ton`
    runs the timer. *Recommend withdrawing it.* Where a `ton` runs the timer, its preset
    silently replaced the map; where none does, no text could say it. Adopted: M1-6's
    `%{"pre" => ms}` from Elixir is withdrawn.
25. **Section changes while running (E5):** allowed, the value kept, and reported through
    `:held`, `:input` and `:unread`; or refused, as a type change is. *Recommend allowed*:
    §4.9 refuses only type changes, and every consequence of a section change is in the
    report. Adopted.
26. **The plain swap (E6):** scanning a recompiled program over a kept instance, with no
    edit, stays in the contract as today, and an edit's first test re-initialises, at its
    declared initial value, any tag whose value does not fit its declared type
    (`Declarations.fits?/2`, or a timer's member keys), reported as `:added`; or the plain
    swap is ruled out. *Recommend keeping it, with that re-initialisation, and leaving a
    version check to OE-2's generation counter.* A review found a plain swap that left a
    dint's 7 under a tag the next program declares a timer; an edit then passed it
    silently, and the timer was done 10 ms into a 5000 ms preset. Adopted. *(Decision 60
    gives the counter to the configuration edit only.)*
27. **Accept and the state (E7):** `accept/2`, from the programs alone; or `accept/3`,
    which takes the state and returns a forecast, the report a test taken now would give,
    with nothing applied. *Recommend `accept/3`*, so that every step returns a report,
    accept included. Adopted.
28. **What the data path refuses (E8):**
    - the narrow refusal of four cases: a negative literal (a `:validate` diagnostic), a
      negative initial value and the preset map from Elixir, and an empty group or rung
      (`ArgumentError`), with the rest of a hand-built tree declared outside the contract;
    - or the full entry check: `instructionize/2` checks its routine against exactly what
      `Logex.Parser.parse/1` can produce, stated in one function beside the parser, and
      refuses anything else as `ArgumentError`.

    *Recommended the narrow refusal.* The maintainer chose the full entry check. A review
    had found that `instructionize/2` took a missing, zero or negative line, giving a
    diagnostic that `Logex.Diagnostic`'s line rule does not allow; took two rungs on one
    line, losing the second-`ote` warning the text gives; and raised `FunctionClauseError`
    or `Protocol.UndefinedError` on a malformed tuple. `Tag.new!/4` refuses a negative
    initial value and, by decision 24, the preset map. *(Landed with M3-3, 2026-10-14,
    decision 97: a negative literal lexes, so the entry check takes a negative integer and
    `Tag.new!/4` a dint's negative initial value; of the two it refused here, only the
    preset map is left.)*
29. **A changed initial value of a kept bool or dint (E9):** it keeps its running value
    either way, and the new value applies at the next restart. Say nothing, or report it
    at every switch as `{:initial_changed, name, {old, new}}`, sorted with the rest of the
    report. *Recommended saying nothing.* The maintainer chose to report it. *As built
    (§4.9): not at every switch. A tag a start rule starts, at its new initial value, is
    reported as `:added`, or as `:input` where it is a var_input, not as
    `:initial_changed`; and a var_input of the program started is not reported as
    `:initial_changed`, since a restart keeps its value, so the new one never applies. It
    is still reported as `:input` (decision 22).* *(Widened 2026-10-21 by decision 157:
    from Milestone 5 the report is for a kept tag or member of every type, the new
    widths, the reals, the bit strings and an array, element by element, and values are
    compared exactly, so that an initial `0` and `0.0` are two values, the declared values compared and
    not `Program.initial_env/1`'s, which starts a real at 0.0 under either, where
    `Logex.Edit.Plan.changed/2` guards on bool and dint and compares with `!=`; decision
    44's report for a global is widened the same way.)*

**The fixes, accepted with decisions 21–29.** OE-1's spike had two reviews, one for
correctness and one for fit with §4.9 and the host contract. Their fixes, and one from the
spike's own report (F16), were all accepted. The work cites them as F1–F16:
- **F1.** Untest restores exactly the `.pre` its test found. Each switch records, per
  timer, the `.pre` it left and the one it found; the next switch first restores the found
  value wherever `.pre` still equals the one left, and otherwise the preset rules apply,
  so a value logic writes after accept is still respected. *As built (§4.9): the next
  switch of the same edit. A new edit's record starts empty, so it gives back no `.pre`
  an earlier edit's switch moved.*
- **F2.** A pending one-shot block survives a second edit taken before any scan, wherever
  the program started still has an `ons` on the bit, and is reported as `:ons_blocked`.
- **F3.** Switches with no scan between them lose no real edge: blocks are worked out
  against the program that last scanned, so the instance records whether a scan has run
  since the last switch.
- **F4.** `{:held, output, value}` reports the value the output last showed, recorded at
  the switch that stopped driving it, never a value re-read after a restart cleared it;
  and only for an output whose value is known. *As built (§4.9): this is the rule for an
  output the program that runs next does not show; one it still shows, a var_output it
  writes no more, is reported at the state's value, what its next scan gives the host.*
- **F5.** A plan per program, built at accept, and a switch and a prune per instance,
  which OE-2 can call once for each instance. OE-1 documents one edit per instance.
- **F6.** `:dn_drops` means `.dn` drops at the next scan with its rung true, unless at
  least preset − acc ms have passed; the documents say so.
- **F7.** An `ons` whose storage bit the program that last scanned wrote through anything
  other than an identical `ons` is blocked too.
- **F8.** The instance's block list is checked as a proper list of storage bit names, with
  a pinned message.
- **F9.** Names: the block list is `ons_blocked` and its report kind `:ons_blocked`, never
  "hold", since held means an output keeping its value; the rules that start a tag are
  named for what they do, never by a letter the one-shot probes already use.
- **F10.** `Logex.Runtime`'s moduledoc gains two host duties: under test, send only the
  var_inputs of `Logex.Edit.running(edit)`; resend every input a step reports.
- **F11.** `api_contract_test.exs`'s edit walk lands with `Logex.Edit` (its refusals, the
  rule that the listed writes rebuild the state, every accepted step made twice), and
  gains the timer and one-shot oracles with their work, two of them independent of the
  rules. Every property asserts its reach. *As fixed after the review of OE-1 (§4.9): the
  round trip first held only with two exemptions no fix approved, a timer the test
  resumed and every write the reports listed as `:added` or `:input`. An untest now gives
  a resume back, `:resume_undone`, and the round trip exempts only what a switch starts,
  found from the two programs' text and the state.*
- **F12.** Tests build an unnamed program within the contract, through
  `Compiler.instructionize/2`, never by editing a struct.
- **F13.** When decisions 24 and 28 land, `CLAUDE.md`'s "one validator" wording is
  corrected if checks made only from Elixir move outside `Declarations.check/1`, and
  `PLAN.md` M1-6's record notes that the preset map from Elixir is withdrawn.
- **F14.** `PLAN.md` M2-1 records that `start/1` builds each instance through the same
  constructor as `Runtime.instance/1`.
- **F15.** An `:edit` diagnostic carries no file, since a `%Logex.Program{}` keeps none.
  The gap is documented; Milestone 2 needs it closed.
- **F16.** A test in reductions keeps accept and a switch linear at two program sizes,
  because a quadratic step got into the spike.

**Milestone 2's design, decided 2026-10-02.** A design pass spiked Milestone 2 in three
tracks on copies of `47319f7`: the scheduler (M2-1); user function blocks (M2-5); and the
configuration file, shared globals and event tasks (M2-2, M2-3, M2-4, M2-6). Each track was
reviewed for correctness and for fit with this document, then revised. Decisions 30–40 are
what the pass left to the maintainer. Its routine choices, all taken as recommended, are
the rules in §4.10.

30. **Milestone 2's order:**
    - M2-1 first, then M2-5, then M2-2, M2-3, M2-4 and M2-6;
    - or M2-5 first, then M2-1, as decision 1 allows.

    *Recommend M2-1 first.* It is decision 1's default, and it keeps M2-5's Done-when as
    written: M2-5's own test reads `m1.s2.run` through M2-1's `get/2`, which the two
    spikes, merged, answer with `{:ok, 1}`. *(As built with M2-1, §4.6: `get/2` returns
    the value at the path and raises `ArgumentError` for a path that names nothing it
    reads. The `{:ok, 1}` was the probe's own wrapper around the call, so M2-5's test
    asserts `Logex.Runtime.get(rt, "m1.s2.run") == 1`. Decision 41 then made `get/2` give
    `{:ok, value}` after all, so that test asserts `{:ok, 1}`, or `get!/2`'s `1`.)* With M2-5 before M2-2, the
    configuration file's reader, its loader and the IR walk are written against `cal` from
    their first commit. In the other order a hand merge of the spikes failed at four
    seams: the configuration's walk of what a program writes raised on `cal`; its loader
    put a function block type among the programs; a block's `var_external` raised
    `FunctionClauseError`; and there were two loaders. M2-5 first would settle the nested
    state and the edit's changes while OE-1 is fresh, at the cost of rewording its
    Done-when. The code does not choose: the two spikes conflict in the same three files
    in either order, and their union passes. Adopted.
31. **What may change in a function block type while a program that holds it runs
    (M2-5):**
    - nothing: any change to a block type is refused, line numbers ignored, and editing
      a block needs a restart, as the conventional family edits its user-defined
      instructions offline only; the nested migration waits for OE-2;
    - the body only, with the one-shot and timer rules applied by path, and no member
      migration;
    - the full nested migration, which §4.9 gives to M2-5: the body may change and
      members may be added or dropped, each instance migrated member by member, by path,
      under OE-1's rules; a member whose type changes is refused, as a tag's is;
    - or the same migration, with a member whose type changes started at its initial
      value and reported `:added`, reading §4.9's "initialise the rest" literally.

    *Recommend the full migration, a member's type change refused.* The documents give
    the migration to M2-5, and the spike's walks found no rebuild, prune or one-shot
    failure once the reviews' fixes were in. Refusing keeps one rule for a type change at
    every depth; starting the member again would restart a value inside a running block
    without a restart. Beremiz's hot swap also copies values by path and type. The cost is
    that `Logex.Edit` roughly doubles. Adopted: a block's type, for the edit, is its name
    and its members' kinds.
32. **How long an edit blocks a one-shot inside a function block (M2-5):**
    - until a scan runs its `ons`: a scan keeps in the instance's block list each bit
      inside an instance whose body it did not run, under a false `cal` or none, and a
      switch after such a scan lists it again where the program it starts still has that
      `ons`;
    - or the next scan, as at the top level.

    And what §4.9's cost rule then says, since a bit inside a block is named by its path:
    the scan right after a switch is linear in the block list's bytes, and so quadratic in
    the depth of nesting; or the instance's block list becomes a tree, linear in the
    one-shots.

    *Recommend until a scan runs it, with the cost restated in bytes.* With the next scan,
    a frozen block uses its block up unseen, and its `ons` then compares a changed rung
    against the bit the old rung wrote: the false pulse decision 21 exists to prevent. A
    tree would reshape a field the host sees, for a cost only absurd depths show: at the
    conventional family's 16 levels a path is at most the 16 levels' instance names and
    the bit's own. Adopted.
33. **What a user function block shows outside it (M2-5):**
    - its inputs: read anywhere, as decision 9 and §4.3 say; or not, as IEC forbids
      (Ed 2 Table 32, Ed 3 Figure 13), so only its outputs are read;
    - its own `var`s, the instances it holds included: hidden, so no path from outside
      goes deeper than one member and `Runtime.get/2` owes no growth test in depth; or
      readable, and part of `get/2`'s contract;
    - writes from outside: none; or to its inputs, taking effect at the next call, as IEC
      Ed 3 allows; or to its inputs and outputs, as the conventional family does, by
      inference.

    *Recommend inputs and outputs read, its `var`s hidden, nothing written.* A positional
    `cal` passes every input from a tag the caller already holds, so reading one is
    harmless. Hidden `var`s are IEC Ed 3's PRIVATE default and the conventional family's
    local tags. A written input is overwritten by the next `cal`, so it matters only while
    the block is frozen, and a written output is seen by a body that reads its own output,
    as a seal-in does. Each can be relaxed later without breaking a program. Adopted.
34. **How a program gets its function blocks from files, and their warnings (M2-5):**
    - `Logex.compile/2` takes `types:`, and `Logex.compile_file/1` loads `<word>.ld`
      beside the file that names a type word, compiling each once a call; a loaded
      block's warnings stay in its type;
    - the same loader, with `compile_file/1` handing back each loaded block's warnings
      among the program's, once a call, each stamped with its block's file, while
      `compile/2`, whose host compiled each block, gives only the program's;
    - or `types:` only, on `compile/2` and a `compile_file/2`, the loader waiting for
      M2-2.

    *Recommend the loader, with the blocks' warnings handed back.* One loader is designed
    once, and M2-2's configuration loader goes through it; the Done-when then runs from
    files on disk. A program's `warnings` is the host's one warning channel (M1-5), so a
    block loaded on the host's behalf reports there. Adopted. No spike built the warnings
    handed back.
35. **The configuration file's extension**, decision 3's placeholder (M2-2):
    - `.lxcf`, "logex configuration file": no file found on GitHub, and no entry in
      fileinfo.com, filext.com, file-extension.info or GitHub Linguist;
    - `.ldcfg` or `.ldcf`, which pairs with `.ld`: no use found, but "ld" is the GNU
      linker's name, so it may read as a linker's configuration;
    - or keep `.lcf`, which CodeWarrior's linker command files, CudaText, Loon and Archicad
      already use, in 5,264 files on GitHub.

    *Recommended `.lxcf`.* The maintainer chose `.logex`, none of the options offered. A
    check on 2026-10-02 found it free. fileinfo.com, filext.com, file-extension.info and
    solvusoft.com have no page for it, where each has one for the placeholder; GitHub
    Linguist, Vim 9.1, freedesktop's shared-mime-info, the VS Code Marketplace and Open
    VSX give it no language or type; and Sourcegraph's index of public code holds no
    `*.logex` file and no quoted `".logex"`, against 532 files of the placeholder's in 93
    repositories. About a dozen other things are called logex (logging libraries, an
    Ethereum client, an installer plug-in, a logic tutor, companies), and none has a file
    type; the name is free on Hex. GitHub's own code search was not used; two registries
    refused the requests, and a third lists neither extension, the placeholder included,
    so proves nothing. Two costs are recorded. A file named only `.logex`
    reads as logex's own settings file, so the loader's refusal of a bare dotfile reads
    "`.logex` names no configuration", and the name is no longer free for a settings file.
    And a `*.log*` glob matches `plant.logex`, though no `github/gitignore` template
    ignores it by name. Prose says "a configuration file (`.logex`)", since "a logex file"
    could also mean a `.ld` program.
36. **A host mistake no text can say, in the configuration validator (M2-1):** a
    configuration's name that is not a string, a function block type among its programs,
    lines that do not rise, a list that is not proper.
    - `Logex.Configuration.check/1` raises `ArgumentError`, as `instructionize/2` raises
      on a tree no text could say (decision 28);
    - or it returns a `:configure` diagnostic with no line, so that `check/1` is total over
      the struct's fields.

    *Recommend raising.* A mistake in the source is a diagnostic and a host's mistake an
    `ArgumentError` (CLAUDE.md); none of these is in a configuration file's text, and a
    raise keeps it out of the diagnostics a user reads for the file. `new!/1` and
    `start/1` raise `check/1`'s problems either way. Adopted.
37. **A task's priority bound (M2-1, M2-3):**
    - 0 to 2147483647, a dint's range;
    - 0 to 65535, IEC's own: both editions type PRIORITY as UINT, Ed 2 in its Table 50
      (p.116) and Ed 3 in its Table 63 (p.182), and Table 10's note d makes a UINT 0 to
      2^16 − 1 (Ed 2 p.31, Ed 3 p.32). Only the grammars differ, Ed 2's `integer` and Ed
      3's `Unsigned_Int`, and neither bounds it;
    - or 0 to 31, one vendor's (CODESYS's help).

    *Recommend 0 to 65535.* Decision 7's reasoning is to start strict where relaxing later
    breaks no plant. The case for a dint's range was that any tighter bound is one
    vendor's number, which holds for 0 to 31 but not for IEC's own type. 0 stays the
    highest. Adopted.
38. **`restart/2` and `overlaps/1`, beyond §4.6's API (M2-1):**
    - both: `Runtime.restart(rt, :cold | :warm)` restarts every instance through
      `restart/3`, keeping the clock and the input image, so `scan/2` with `restart/3`
      and a one-instance configuration agree across a restart with nothing resent; and
      `Runtime.overlaps(rt)` gives each task's overlap count by name;
    - neither: `start/1` is the cold restart, the host resending its whole input image,
      and an overlap count is read from the events alone;
    - or both deferred, to the runner or to OE-2.

    *Recommend both.* A resource keeps each task's overlap count, and a host has no other
    way to read it; and without `restart/2` a host restarting a plant must rebuild and
    resend its input image. Adopted.
39. **A task with both `single` and `interval` (M2-6):**
    - the phase anchored at start: at most one run a cycle; due on an edge, or when the
      trigger samples 0 and a periodic due time has come; while the trigger is 1, a
      periodic due time that comes is skipped, not counted as an overlap, and the next is
      on the same phase; an edge run does not move the phase;
    - the phase re-anchored when the trigger falls;
    - or the periods under a high trigger counted as overlaps.

    *Recommend the anchored phase, its periods under a high trigger skipped and not
    counted.* §4.6's periodic phase never drifts, and rule 2 suspends periodic runs while
    SINGLE is 1 rather than counting them missed. There is no free-software precedent:
    MatIEC ignores INTERVAL when SINGLE is given, and Beremiz's editor cannot express
    both. Adopted. *(Landed 2026-10-12.)*
40. **A task's next due time when OE-2 changes its interval (M2-3 states it; OE-2 builds
    it):**
    - `min(next_due, now + new interval)`: a shorter interval takes effect within one new
      period, and a longer one runs once more on the old phase; no run is added at the
      switch. Where the new interval brings `next_due` forward, the phase is then the
      switch's, and otherwise the runs step by the new interval from the kept `next_due`,
      so in neither case is it the anchor's;
    - `next_due` kept, the next run stepping by the new interval: no run is added or lost,
      but a shortened interval waits out the old period; in a probe a 60000 ms task cut
      to 10 ms at 20 ms ran no time in the next 1000 ms, where the first option ran it 100
      times;
    - the next multiple of the new interval from the anchor, which keeps the anchored
      phase but needs the anchor kept beside `next_due`, a new piece of state;
    - or the phase re-anchored at the switch, which adds a run or leaves a gap.

    *Recommend `min(next_due, now + new interval)`.* It bounds the wait by the new
    interval, adds no run and adds no state. §4.6's "the phase never drifts" describes
    steady running, and no decided text fixes `next_due` across an interval change.
    Adopted. *(Since decision 139, 2026-10-19, `now` is the step's time: the resource's
    own and the milliseconds since its last cycle a host gives, 0 unless given, and
    through `Logex.Runner` the time the edit is taken by its clock.)*

**After M2-1 landed, decided 2026-10-04.** Four questions M2-1's landing and its reviews
left open: one about the API that landed, one for M2-2, and two that §4.9's table had left
to OE-2.

41. **What `Runtime.get/2` returns (M2-1):**
    - the value, raising `ArgumentError` for a path that names nothing it reads, as
      landed, since a host mistake raises (CLAUDE.md);
    - `{:ok, value}` or `:error`, so that a host can probe a path without rescuing;
    - or both: `get/2` gives `{:ok, value}` or `{:error, reason}`, and `get!/2` the value
      or `ArgumentError` with that reason, as Elixir's `Map.fetch/2` and `Map.fetch!/2`.

    *Recommended the value, as landed.* The maintainer chose both. `reason` is the message
    `get!/2` raises. A string that names nothing `get/2` reads is not a host mistake to
    `get/2`, which a host calls to find out; something other than a resource, or a path
    that is not a string, still raises from both.
42. **A refused name's uses (M2-2):** a global refused for its name, `a.b`, and a
    connection that names it: report the refusal once, its uses silent, as the `.ld`
    compiler excuses the uses of a recursive declaration; or report each use too, as M2-1
    does, "`m.start` is connected to `a.b`, which is not a global". *Recommend once.* The
    maintainer stated no preference, so the recommendation stands. It lands with M2-2's
    port of the checks; until then M2-1 reports each use. *(Landed 2026-10-11.)*
43. **An instance whose program type an edit changes (OE-2):** a remove plus an add, the
    old instance pruned and the new one started by `Runtime.instance/1`, both reported;
    or a refusal, as a tag's type change is refused. *Recommend the remove plus an add,*
    since instances may be added and removed while running and state is keyed by name.
    Adopted. *(As designed for OE-2, §4.9: the old state is set aside at test, kept
    unused, and pruned at assemble, and the new instance may run on another task,
    decision 61.)*
44. **A kept global whose initial value an edit changes (OE-2):** report it as
    `{:initial_changed, name, {old, new}}`, its running value kept, as decision 29 reports
    a tag's; or say nothing. *Recommend reporting it,* one rule for two kinds of state,
    which extends decision 29 to globals. Adopted.
45. **How an edit's switch sees a configured instance's `var_external`s (OE-2),** when
    the two programs declare different ones (the running program reads `estop` through
    `var_external`, the candidate declares `estop` as a `var`):
    - the switch merges each global into the instance's state by the running program's
      externals before `Logex.Edit`'s per-instance switch, and splits it off by the
      candidate's after, so a tag both declare keeps its value whatever its section, as
      decision 25 keeps it, and the global itself is untouched;
    - only the candidate's externals both ways, so a `var_external` the candidate turns
      into a `var` is never merged in and starts at its initial value, against decision
      25;
    - or an edit that adds or removes a `var_external` on a configured instance refused,
      stricter than a tag's section change at the top level.

    *Recommend the running program's in, the candidate's out.* It keeps decision 25's one
    rule for a section change and leaves the global alone. How OE-2 reports the write into
    a shared global when a `var` becomes a `var_external` stays OE-2's to design. Adopted.
    *(Decided 2026-10-13 by decision 55: no switch writes the global, and the instance's own
    value is dropped and reported.)*

**From the spikes of M2-4's and M2-6's run time, decided 2026-10-04.** Two throwaway
spikes on `025199a` built the pieces of Milestone 2 no design spike had: one copy of a
global at run time, and event tasks at run time, each against an independent model, every
rule reverted alone and red. They found the record right in its rules and silent or wrong
in the places below. Their routine answers are §4.10's rules under M2-4 and M2-6.

46. **The e-stop Done-when (M2-4).** PLAN M2-4's "stops both in the same cycle" holds only
    in a cycle where both instances run: on §4.4's plant `m1` runs every 10 ms and `m2`
    every 50 ms, and a 10 ms e-stop pulse never reaches `m2`.
    - Keep the words and test them on §4.4's plant with the e-stop raised at a cycle both
      tasks are due, 50 ms, beside a test that pins the sampling; §4.4 says an e-stop must
      be held at least the slowest interval that reads it;
    - reword the Done-when to "each instance stops at its next scan";
    - or add a mechanism that reaches every reader in the cycle the e-stop rises, which no
      decided text asks for.

    *Recommend the first.* It keeps the decided words true of the decided plant and
    documents what they do not say. Adopted. *(Landed 2026-10-12.)*
47. **A write through a `var_external` and a connection's copy-out to one global, in one
    scan (M2-4):** the copy-out lands last, after the `var_external` is split off, as
    IEC and MatIEC write an external during the body and `=>` after it; or the write
    through the `var_external` lands last; or a global one instance both writes through a
    `var_external` and drives by a connection is refused. *Recommend the copy-out last,*
    stated in `Logex.Runtime`'s cycle steps and in the warning's words; a refusal would
    refuse what IEC allows and §4.4 makes a warning. Adopted. *(Landed 2026-10-12.)*
48. **The two writer warnings' words (M2-4).** The design's "the later of the two in a
    cycle wins" is false for two instances that only latch one alarm, for an `ons` whose
    storage bit is a `var_external` shared by two instances (the second never fires on the
    same edge), and for one instance that writes a global both ways (its copy-out wins
    whatever the order).
    - One wording true of all, "each scan reads what the other last wrote, and the later
      write in a cycle stands", with the same-instance case in its own words ("its own
      copy-out, after the scan, stands") and the shared storage bit in the one-shot
      warning's words;
    - warn only where a writer writes every scan (`ote`, `move`, `ons`), sparing latches;
    - or, as the first, and refuse an `ons` on a `var_external` storage bit in `.ld`.

    *Recommend the first,* keeping the two decided warnings and their scope; the refusal
    stays a later tightening, since refusing later breaks programs and warning now does
    not. Adopted. *(Landed 2026-10-12.)*
49. **How "one copy of each global" is pinned (M2-4).** It cannot be seen through the
    public API: reverting any of the three places that drop a global from an instance's
    state left the spike's whole suite green. Pin it by a test that looks inside the
    opaque `%Logex.Runtime{}` on purpose, as the plain-data test does; or only through
    OE-2's switch, when it lands; or let the state keep a stale copy, overwritten at
    every merge. *Recommend the test that looks inside:* the drops are one line each and a
    refactor can lose them, and decision 45's switch depends on them. Adopted. *(Landed 2026-10-12.)*
    *(Amended 2026-10-21 by decision 159: since a `var_external` is its global, one copy,
    it binds only to a global of exactly its type, Milestone 5's widths, reals, bit
    strings and arrays among them, an array's element type and every dimension, while a
    `cal`'s parameters and a connection widen as an instruction's operands do.)*
50. **`next_due_in/1` with event tasks, and the host's loop (M2-6).** It counts periodic
    tasks only, so a configuration of event tasks, or of task-less instances alone, as on
    main already, answers `:infinity`, against the moduledoc's "`next_due_in/1` is 0 after
    `start/1` and after `restart/2`".
    - Periodic due times only, and the host's loop restated: a runner cycles at once after
      `start/1` and `restart/2`, whatever `next_due_in/1` says; a trigger written by logic
      fires at the next cycle the runner makes;
    - the same, and 0 after `start/1` and `restart/2` for an event-only task;
    - or 0 whenever an edge is pending, which a task-less instance raising two triggers in
      turn holds at 0 for ever, a livelock in zero time.

    *Recommend periodic due times only, the loop restated.* A pending edge's hazard is a
    runner's concern, and the runner is not designed. Adopted. *(Landed 2026-10-12. The
    hazard closed on 2026-10-18 by decision 123: the runner makes a trigger logic writes
    its round at the next clock millisecond, so two that raise each other's triggers
    round once a millisecond and leave the runner serving its mailbox between.)*
51. **A late host's edge cycle (M2-6).** For a task with `single` and `interval`, the
    periodic due times that came between the last cycle, whose sample was 0, and this
    one, whose sample is 1: skipped and not counted, as decision 39 reads by this cycle's
    sample; or counted as missed periods. *Recommend skipped, not counted.* It hides a
    host's lateness only while the trigger is 1, when rule 2 owes no periodic run anyway.
    Adopted. *(Landed 2026-10-12.)*
52. **A late host's falling cycle (M2-6).** A periodic due time that came while the input
    image still held 1, in a cycle that samples 0: it runs, since the sample decides; or
    it is skipped, since the image held 1 until this cycle's merge. *Recommend it runs:*
    one rule for every source of trigger, since only the sample is known both for a
    trigger written by logic and for an input point. Adopted. *(Landed 2026-10-12.)*

**From the check of M2-5's fixes, decided 2026-10-05.** A check of the commits that fixed
what the review of M2-5 confirmed, each finding reproduced, left questions the record
did not answer. Their answers are annotated in §4.10 where they stand.

53. **How often a compiled type holds a block type (M2-5).** §4.10's "Held types" records
    each type held once per body: a body's `blocks` holds the type of each instance it
    declares, and that type holds its own body's in turn. Where each type is reached
    through one holder, a type copied flat is linear in its depth. Where it is reached
    through two holders at every level, as when each level has two types and each holds
    both of the level below, a copy that keeps no sharing (`:erlang.term_to_binary/1`, or
    a message to another process) writes it out once per path of holders: 36,405 words at
    6 levels and 2,354,805 at 12, against an instance's state of 176,118.
    - Once per body, as built, its documents saying that a flat copy is linear only where
      each type has one holder;
    - once per outermost type: one table of block types on the outermost compiled type,
      and on a program, every instance at any depth naming its type, so that a flat copy
      grows with the number of distinct types whatever the shape;
    - or no type held at all: a type names the types it holds, and the runtime, an edit
      and a configuration resolve each name through a library given beside the program.

    *Recommend once per outermost type.* It goes beyond §4.10's "once per body", but every
    type a compile gives stays whole, a value a host can give to a compile or send to
    another process as one term, which the third gives up, and the cost of a copy follows
    what the type is, not how its holders are drawn. Adopted.
54. **Whether a type given is the one its source text gives (M2-5).** §4.10's "Types
    given" says a hand-edited type is an `ArgumentError` where it is given. As built,
    `Logex.FbType.user?/1` checked a type's shape, its body one a compile gives over its
    tag table (`Logex.Compiler.lowered?/1`), and never compiled the body's source text
    again. So it took a rung edited into another that text could say, the text left as it
    was, a source text or file edited, or a key added to a tag: each a version of its own,
    which only a compile that also held the genuine type refused, by the one-version check.
    - The shape, as built, its documents saying what it checks;
    - compile each body's source text again through `Logex.compile/2`, given the types it
      holds, so that each of those is checked again in turn: a type is then compiled again
      once for each path of holders down to it, as 2 to the power of the depth in decision
      53's diamond;
    - or compile each body's source text again once a compile, over the types it names as
      the one table holds them (decision 53), trusted as checked, each before any type
      that names it, and ask that it give the body given, the file it was read from aside.

    *Recommend the third.* "A hand-edited type is an `ArgumentError` where it is given"
    then holds exactly, in the spirit of decision 28's full entry check, and a type is
    compiled again once a compile, however many types and paths hold it, so a compile given
    a type stays linear in the text of the types it holds, as the shape check was. Adopted.

**OE-2's design, decided 2026-10-13.** A design pass on `92431a9` built a throwaway spike
of a configuration's switch from OE-1's per-instance plan, switch and prune, with decision
45's merge and split, and ran thirteen probes on §4.4's plant (§4.9, "OE-2's design").
Decisions 55–62 answer the eight questions it left to the maintainer, and 63–65 are three
of its routine choices, each with an alternative the record keeps. Its other routine
choices are §4.9's rules.

55. **The write into a shared global when a `var` becomes a `var_external` (OE-2),** which
    decision 45 left to OE-2: the merge does not bring the global in, the switch keeps the
    instance's own value (decision 25), and the split must do something with it.
    - Drop it: the global is untouched, the instance reads the global from its next scan,
      and `{:joined, "m1.estop", {own, global}}` reports the value dropped;
    - write it into the global, `{:written, "estop", {from, to}}`, which every reader sees
      at its next scan, and which is impossible where the global is an input point, the
      host's, or is driven by another instance's connection;
    - or refuse a `var` become a `var_external` on a configured instance, stricter than
      decision 25.

    *Recommend dropping it.* No switch writes shared state, as no switch writes a storage
    bit (decision 21); decision 45 already says "the global itself is untouched"; and
    writing it could release a pressed e-stop for the whole plant from an edit. The spike
    built it and needed no special case. Adopted: the shared global wins, the instance's
    private value is dropped and reported, and no switch writes a global.
    *(Landed 2026-10-13.)*
56. **Which clock a timer resumes from, in an instance its task does not scan every cycle
    (OE-2).** OE-1's resume sets a restored timer's `last` to the instance's `now`, its last
    scan's time, and in a resource an instance on a slow task last scanned up to one
    interval before the switch.
    - The resource's `now`: a switch gives each instance it moves the resource's clock, so
      `last` is the switch's time and nothing is caught up;
    - or the instance's own `now`, OE-1's rule untouched, so the next scan catches up the
      time between the instance's last scan and the switch, which no program with that
      `ton` ran.

    *Recommend the resource's.* It is what OE-1's resume means, "it resumes from the
    switch". The spike measured it: `m2` on a 50 ms task, last scanned at 100 ms and
    switched at 130 ms, resumed 80 ms by the first, and by the second 50 ms, with 30 ms then
    caught up at the next scan. §4.9's "`now` and `first` never touched" becomes "`first`
    never touched, and an instance's `now` set to the resource's at a switch", which is
    never earlier and which no scan reads otherwise. Adopted. *(Refined by the spike of
    OE-1's record across slow tasks, §4.9's "OE-2's design": the switch reads the
    instance's own `now` for fix F11's undo, the time the last switch set, before it sets
    `now` to the resource's, or a cycle between a test and its untest would leave a
    resumed timer's `last` at the test's time, unreported.)* *(Landed 2026-10-13.)*
57. **An instance brought back from aside: whether its timers catch up (OE-2).** An instance
    set aside, removed at test or the old state of a retyped one, comes back at untest, or
    at a second test for one only the candidate runs; its timers that were timing kept
    `.en` 1 and a stale `last`.
    - Resume each from the switch, reported `:resumed` by path, as decision 23 resumes a
      `ton` an edit restores;
    - or let them catch up the time set aside, as a block frozen by a false `cal` catches
      up (decision 8).

    *Recommend resuming.* The edit stopped the instance, not its logic, which is decision
    23's case, not decision 8's. Its one-shots need no block: their bits hold what they
    last received, so an edge they see on return is a real one. Adopted: an instance back
    from aside carries on from where it stopped, its timers do not catch up, and the report
    says so. *(Landed 2026-10-13.)*
58. **How a held output is named in the report (OE-2).** A var_output a kept instance no
    longer writes gives OE-1's `{:held, "m1.run_lamp", v}` by path, and the output point
    it is connected to, `lamp_1`, holds too, `{:held, "lamp_1", v}`.
    - Both;
    - the point only, dropping the instance's `:held` in a resource, since no host holds a
      var_output there;
    - or the instance's only.

    *Recommend both.* The point is what the operator sees, the instance's output what the
    programmer changed, and keeping OE-1's entries means the per-instance switch is used
    unchanged and the walk can check both. Adopted. *(Landed 2026-10-13.)*
59. **One edit or two (OE-2):** `Logex.Edit` extended, with `accept/2` over a runtime beside
    `accept/3` over an instance and each step dispatching on its struct; or a new module,
    `Logex.Configuration.Edit`, with the same step names and report shape, the per-instance
    plan shared through an internal module. *Recommend the new module.* `Logex.Edit`'s
    moduledoc and its pinned host-mistake messages describe one instance, and two kinds of
    edit in one struct would make every message say which it means; the cost is one more
    public module in the surface test. Adopted: `Logex.Edit` stays the edit of a lone
    instance. *(Landed 2026-10-13.)*
60. **The generation counter for a lone instance (OE-2).** OE-1's undetected cases, a step
    on an ended or superseded edit and two edits at once, stay undetected for `Logex.Edit`.
    Give `%Logex.Instance{}` a generation too, a new field with its check, message, value
    from `instance/1` and rules for a scan, `restart/3` and a switch; or not now, the
    counter on the resource only. *Recommend not now:* a lone instance is the bench and the
    test harness, and a running controller is a resource, which gets it. Adopted: only the
    configuration edit gets the counter, and for a lone instance a stale edit stays the
    host's duty, documented as a known limit. *(Landed 2026-10-13.)*
61. **Whether a retyped instance may run on another task (OE-2).** Decision 19 refuses
    moving an instance to another task, and decision 43 makes a retyped instance a remove
    plus an add. Allow it, since the new instance is a new one and an added instance may go
    on any task that exists; or refuse it, so that a name keeps its task whatever its type.
    *Recommend allowing it:* it follows from decision 43, and a refusal would make the host
    rename the instance to get the same effect. Adopted. *(Landed 2026-10-13.)*
62. **Reordering tasks or instances while running (OE-2).** The order of `instances` is the
    execution order within a task, and the order of `tasks` breaks ties of priority and due
    time (decision 11). Neither is state, but a reorder changes behaviour: an instance moved
    earlier no longer sees, in the same cycle, what the one it now precedes writes.
    - Allowed and reported, `{:order, task, names}`;
    - allowed silently;
    - or refused.

    *Recommend allowing and reporting it:* nothing about it needs a restart, and the report
    is where a change in behaviour belongs. Adopted. An instance's order is reported by its
    task, or `:none` for the task-less instances, wherever the instances both
    configurations run there change their order among themselves, its detail every
    instance's name there in the new order; a task's order by `:tasks`, wherever the tasks
    change theirs, its detail every task's name in the new order. *(Landed 2026-10-13.)*
63. **A candidate that `Logex.Configuration.check/1` refuses, at accept (OE-2):** the host's
    mistake, raised as `Logex.Runtime.start/1` raises it; or `:edit` diagnostics. *Recommend
    raising:* a candidate from text reaches accept only through `compile/3` or
    `compile_file/1`, which return its problems first, so one that still has them was
    built by the host, and `start/1` raises the same. One rule for handing a configuration
    to a running resource. Adopted. *(Landed 2026-10-13.)*
64. **Cancel from accept and the generation (OE-2):** cancel from accept moves the
    generation on, as every step but accept does, so that an edit that has ended can never
    step; or it leaves the resource exactly as it was, its generation included, so that an
    edit cancelled from accept could still be tested. *Recommend moving it:* an edit ends
    at cancel, and a counter that a cancel leaves alone could not refuse a step on it.
    Adopted. *(Landed 2026-10-13.)*
65. **`restart/2` during a configuration edit (OE-2):** it restarts the instances of the
    configuration the resource runs, drops the instances set aside and the globals only the
    other configuration declares, and keeps the generation and the edit's stage, the next
    switch starting again what it dropped, `:instance_added` and `:added`, as OE-1's restart
    during an edit does for tags; or it keeps the instances set aside as they are. *Recommend
    dropping them:* a restart starts the plant again, and an instance kept aside across it
    would come back with state no restart touched. Adopted. *(Landed 2026-10-13.)*
66. **What an edit superseded by another left in the resource (OE-2).** An edit accepted
    while another is open supersedes it (§4.9): once the new one steps, the generation refuses
    the old one, so it never assembles or cancels, and nothing prunes what it left. On
    §4.4's plant: the first try adds a horn instance `h` and a `dint` global `lvl`, is
    tested and untested, `h` set aside and `lvl` kept unused at 50; the corrected
    candidate, accepted without a cancel, gives `h` a 3 s on-delay and makes `lvl` a `bool`.
    Its test found `h` aside under its name and brought it back, unmigrated, its timer's
    `.pre` 0, so the horn sounded at once, not after 3 s, and kept `lvl` at 50 as a bool.
    - Drop it at the new edit's first test: the resource then runs the new edit's original
      and holds nothing of the new edit's, so every instance set aside, and every global
      the original does not declare, is the superseded edit's, dropped before the switch
      and reported, `:instance_pruned` and `:pruned`, and a candidate that runs or declares
      it again starts it as `Logex.Runtime.start/1` would;
    - start over it at the first test, as decision 26 starts again a tag the candidate
      adds over what a plain swap left, an instance or global the candidate names again
      started and reported as added, the rest left unused until assemble or cancel prunes
      it;
    - or refuse an accept while the resource holds anything a superseded edit left, so
      that the host must untest and cancel first.

    *Recommend dropping it.* It makes true what §4.9 already says, that an instance comes
    back from aside only where an earlier switch of this edit set it aside; the report
    names what is lost, so its writes still rebuild the resource; and starting over it
    would keep, unused until assemble, state that no program of either configuration
    declares. A refusal would take away the supersede §4.9 supports, and make the host
    untest and cancel an edit it has given up on. A first test's prunes are written
    before its other writes, since the switch may start again what they drop under the
    same name. Cancel from accept still changes nothing but the generation (decision 64),
    so what it leaves waits for the next edit's first test or a restart. Adopted.
    *(Landed 2026-10-14.)*

**Milestone 3's design, decided 2026-10-14.** A design pass on `970dede` surveyed the
missing instruction set (`PLAN.md` §8: counters, the other timers, integer arithmetic,
the coil one-shots and control flow) and built a throwaway spike of an up counter through
`Logex.FbType`, the walks and the edit. Decisions 67–83 are the maintainer's answers to
its sixteen questions and to one follow-up, in the order the milestone lands them: three
against the recommendation, 67, 68 and 78, the rest as recommended. Each is given with the
plain-language example the maintainer was asked. Decisions 84–89 are M3-1's own routine
choices, taken when 67 and 68 sent its design back to IEC's counter model, each with an
alternative the record keeps. Decisions 90–92 are the maintainer's answers to three
questions asked after M3-1's review, the same day.

67. **Which kinds of counter (M3-1).** Picture a photo-eye on a conveyor that adds one for
    each box, a buffer table where boxes are added at one end and taken off at the other,
    and a hopper, loaded with its preset when it is filled, that counts portions down to
    empty.
    - Two kinds, an up counter `ctu` and an up-and-down counter `ctud`, where the `ctd`
      instruction runs only a `ctud`;
    - IEC's three, `ctu`, `ctd` and `ctud` (Ed 3 §6.6.3.5.4, Table 45; Ed 2 Table 36):
      the down counter starts empty, at 0 and done, counts down from its preset once its
      load puts it there, and is done at 0;
    - or one kind that always counts both ways.

    *Recommended: two kinds*, so that "done" and "reset" meant one thing on every counter.
    **Taken: IEC's three.** `ctu` counts up and its `q` is on when `cv >= pv`, its reset `r`
    putting `cv` to 0; `ctd` counts down, its load `ld` putting `cv` to `pv`, and its `q`
    is on when `cv <= 0`; `ctud` counts both ways, `qu` on when `cv >= pv` and `qd` when
    `cv <= 0`, with both `r` and `ld`. Each is a type word, `var hopper ctd`, and a change
    of kind is a type change, which needs a restart. A new `ctd` starts empty, `cv` 0 and
    `q` already on, until `ld` loads it, as IEC's CTD does. *(Landed with M3-1,
    2026-10-14.)* *(Corrected 2026-10-14, after M3-1's review: the option above had read
    "the down counter starts from its preset, loaded", and the picture "a hopper that
    starts full", where IEC's CTD, and M3-1 as built, start a new `ctd` empty. The
    maintainer confirmed IEC's behaviour on 2026-10-14, after the review: a new down
    counter starts empty.)*
68. **What a counter's members are called (M3-1),** a follow-up to 67. The design gave the
    conventional COUNTER's members, `.pre .acc .dn` with `.cu .cd .ov .un`, beside the
    timer's `.pre .acc .dn`.
    - The conventional names;
    - or IEC's pin names, lowercased.

    *Recommended: the conventional names*, as the timer has. **Taken: IEC's, lowercased:**
    `cv` the count, `pv` the preset, `q` done (`qu` and `qd` on a `ctud`), `cu` and `cd`
    the count inputs, and the reset and load as inputs, `r` and `ld`. IEC has no overflow
    flag, so they come from the vendors by `docs/naming.md`'s rule 2: `ov` and `un`, the
    conventional set's, the only family that has them (decision 71). Logex's timers keep
    `.pre .acc .dn`: a counter reads `xic boxes.q`, a timer `xic t1.dn`. *(Landed with M3-1, 2026-10-14.)*
69. **The first scan, for everything edge-driven (M3-1, M3-2, M3-4).** A box is already
    on the photo-eye when the controller starts.
    - Not counted: the counter waits for the next box, as the one-shot `ons` already
      waits;
    - or counted at once, as IEC's R_TRIG fires at its first execution after a cold
      restart (Ed 2 Table 35 NOTE).

    *Recommend not counted.* Adopted, as one start-up rule: **nothing edge-driven fires on
    an instance's first scan** since it started or restarted, `ons`, `ctu` and `ctd` now,
    `tp` (decision 75), `osr` and `osf` when they land. It is the conventional prescan's
    for a counter, which sets `.CU` true *"to prevent invalid increments during the first
    program scan"* (general instructions ref., CTU, p.99). *(Landed with M3-1 for the counters, 2026-10-14.)* *(Landed with M3-2 for `tp`, 2026-10-14.)* *(Landed with M3-4 for `osr` and `osf`, 2026-10-14: neither sets its pulse bit on a first scan, whatever its storage bit holds.)*
70. **A reset or load while the count input is high (M3-1).** The operator presses
    "reset batch" while a box is still on the photo-eye.
    - The box is not counted again: after the reset the count shows 0, and the next box to
      arrive is box 1. A reset or load leaves the counter's memory of its count input,
      `cu` and `cd`, as it was;
    - or the reset makes the counter forget that the eye was blocked, so the box on the eye
      counts at once.

    *Recommend not counted again.* Adopted: the edge memory is kept, as IEC's own bodies
    keep it, an R_TRIG called before the reset is tested (MatIEC `lib/counter.txt`). The
    conventional RES clears the counter's status bits, its `.CU` and `.CD` among them
    (general instructions ref., RES, pp.107–108), so a box on the eye would count again
    there. *(Landed with M3-1, 2026-10-14.)*
71. **A counter at the dint's limit (M3-1).** A counter reaches its largest possible
    number, a little over two billion.
    - It stops there and raises an overflow flag, which stays on until someone resets it;
    - or it rolls over to the most negative number and keeps counting, raising the same
      flag, as the conventional family's up/down counter does (general instructions ref.,
      CTUD, p.104: *"The counter then rolls over to -2,147,483,648"*).

    *Recommend stopping.* Adopted: at 2147483647 a count up adds nothing and sets `ov`, and
    at −2147483648 a count down subtracts nothing and sets `un`. Each flag stays on until a
    reset or a load: `r` clears `ov` on a `ctu`, `ld` clears `un` on a `ctd`, and either
    clears both on a `ctud`. IEC bounds its bodies by `PVmax` and `PVmin`, whose values are
    *"Implementer specific"* (Ed 3 Table 45 NOTE); logex's are the dint's. *(Landed with M3-1, 2026-10-14.)*
    *(Kept 2026-10-21 for every width: the typed counters of decision 158 stop at their
    type's limits, decision 146's wrap replacing decision 77 alone, as the maintainer
    answered §4.12's fifth question; `ctu_dint` and its siblings, decision 163, are this
    decision's counters under another word.)*
72. **A counter under an event task (M3-1).** The e-stop's own event task counts how many
    times the e-stop was pressed. The task runs only when the e-stop switches on, so the
    counter only ever sees "pressed", never a new press, and its count stays at 0.
    - Warn: the configuration's check points it out, and the plant still runs;
    - or say nothing, as for a one-shot today.

    *Recommend warning.* Adopted: a counter a program instance runs, at any depth, under a
    task with a `single`, alone or with an interval, is a warning on the configuration's
    `warnings`, as M2-6 warns for a `ton`, citing the counter's instruction. A one-shot
    under an event task is still not warned about. *(Landed with M3-1, 2026-10-14.)*
    *(Changed 2026-10-15 by decision 103, as the maintainer answered it after M3-4's
    review: a one-shot under an event task, an `ons`, an `osr` or an `osf`, is a warning
    too, in its own words, after the counters.)*
73. **What follows a counter or timer on its line (M3-1, M3-2).** "Photo-eye, then counter,
    then lamp" on one line, rather than the lamp on the next line worked by the counter's
    done bit.
    - Not allowed, as after `ton` today, so the program reads the done bit on a line below;
    - allowed, the lamp following the photo-eye, as after an ordinary output;
    - or allowed, the lamp following the done bit, as IEC draws its Q.

    *Recommend not allowed, for now.* Adopted: nothing may follow a `ctu`, a `ctd` or any
    timer on its path. Refusing keeps either reading open to a later change that breaks no
    program. For the record, the conventional CTU and CTD set rung-condition-out to
    rung-condition-in (general instructions ref., pp.95 and 99). *(Landed with M3-1 for the counters, 2026-10-14.)* *(Landed with M3-2 for the timers, 2026-10-14: the conventional TOF and RTO pass rung-condition-in too, general instructions ref., pp.113 and 124.)*
74. **Which signal is a pulse timer's pulse (M3-2).** A horn should sound for 3 seconds
    when a fault appears.
    - Its "timing" bit, `.tt`, on for the 3 seconds, with `.dn` coming on when the pulse
      ends;
    - its "done" bit, `.dn`, on for the 3 seconds, IEC's Q;
    - or a new member of its own.

    *Recommend `.tt`.* Adopted: a `tp`'s pulse is `.tt`, and `.dn` comes on when the pulse
    ends, so "done" never means "still running" on any timer. *(Landed with M3-2,
    2026-10-14, `.dn` set as the pulse ends while the rung holds, decision 94. A `tof`'s
    `.dn` is IEC's Q, on through its delay, decision 93, the one exception to these words,
    confirmed by the maintainer on 2026-10-14.)*
75. **A pulse timer on the first scan (M3-2).** The fault is already present when the
    controller starts. Does the horn sound?
    - No, by decision 69's one start-up rule; the fault lamp, driven by the fault itself,
      still lights;
    - or yes, as IEC's TP would.

    *Recommend no.* Adopted: a `tp` does not fire on the first scan. *(Landed with M3-2,
    2026-10-14.)*
76. **A retentive timer across a restart (M3-2).** A lubrication timer adds up how long
    the conveyor motor has run, so the line is greased every 100 hours; the motor stopping
    does not clear it.
    - Back to zero on every restart, until a later "retain" feature lets the programmer
      mark what survives one, for this timer or anything else;
    - kept across a warm restart, for this kind of timer only;
    - or that retain work first.

    *Recommend back to zero.* Adopted: an `rto` starts again at every restart, warm or
    cold, as every tag does, until `retain` lands. *(Landed with M3-2, 2026-10-14.)*
77. **Arithmetic past the dint's limit (M3-3).** The fill valve adds each delivery to a
    running total, and the total passes the largest number logex holds.
    - It wraps round to a huge negative number;
    - it stops at the limit, silently;
    - or it stops at the limit, and on that scan the instruction passes no power, so the
      program can light an "overflow" lamp after it.

    *Recommend stopping and passing no power.* Adopted: a result outside a dint is brought
    to the nearer limit, and the instruction passes no power on that scan. No value
    outside a dint ever reaches a state. *(Landed with M3-3, 2026-10-14: the power out is
    IEC's ENO, so anything may follow, decision 98; the result is computed exactly and then
    brought in, so a product far past a limit stops at the limit of its sign; and an
    overflow is not reported as a fault, only a zero divisor is, decision 99.)*
    *(Superseded 2026-10-21 by decision 146, for every integer width, the dint's
    included: a result outside its destination wraps, its low bits kept in two's
    complement, with no power and no fault, so a dint result past a limit no longer stops
    there and a value may again jump to the other end of the range, the first option
    above. Programs that run today change: the README's fill valve total goes from
    2147483647 to −2147483648 and counts on, its `total_ok` off for the one scan that
    wrapped. The tests and the README examples pinned the saturation, `arithmetic_test.exs`'s
    limits, `end_to_end_test.exs`'s M3-3 Done-when and its oracle's `clamp`,
    `api_contract_test.exs`'s arithmetic oracle, the arithmetic stanzas of
    `docs/naming.md`, and README's instruction table and "Arithmetic", and `PLAN.md`'s
    M5-2 changes them on purpose, before any new width lands (§4.12, "Overflow wraps").
    Until M5-2 lands, the rule above is what runs.)*
78. **Dividing by zero (M3-3).** The line works out "boxes per minute", and just after
    start-up the minutes are 0.
    - The division gives 0 and passes no power on that scan;
    - or it keeps its last answer and passes no power.

    *Recommended: 0 and no power.* **Taken, with a report added:** a zero divisor gives 0
    and no power on that scan, and the cycle reports it to the host as an event, a minor
    fault naming the instance, the file and the line. The plant keeps running. A literal
    zero divisor is refused when the program compiles. The event's shape is M3-3's to
    design; this records only the rule. *(Landed with M3-3, 2026-10-14, for `div` and
    `mod` alike, where MatIEC's MOD keeps ENO TRUE: the event is `{:fault, task,
    instance, %Logex.Fault{}}` after its scan's `{:ran, ...}`, and a lone instance's
    `state.faults`, decision 99.)*
79. **Which calculations (M3-3).** Add, subtract, multiply, divide and remainder, the
    README's promised negate and absolute value, and square root.
    - All eight now;
    - the first seven now, and square root when logex has numbers with fractions, since
      IEC's SQRT takes a real.

    *Recommend the seven.* Adopted: `add sub mul div mod neg abs` now, `sqrt` later. Each
    new word stops being a tag name: a program with a tag called `add` or `mod` is renamed.
    *(Landed with M3-3, 2026-10-14, after negative literals, decision 97.)* *(Amended
    2026-10-21: `sqrt` lands with Milestone 5's reals, decision 150, a real in and a real
    out; what it does with a negative source, which raises on the BEAM and which
    decision 150 keeps from becoming a NaN, is put to the maintainer before it lands,
    §4.12.)* *(Answered 2026-10-21 by decision 164: a negative source writes 0.0, passes
    no power and raises the minor fault `:negative_sqrt`.)*
80. **Pulse coils (M3-4).** A programmer wants a one-scan pulse when the start button is
    pressed, while the rest of the line carries on seeing the button.
    - Add both, `osr` for "switched on" and `osf` for "switched off", IEC's transition-
      sensing coils (Ed 2 Table 62 features 8 and 9) in the conventional set's form, a
      storage bit and a pulse bit;
    - or leave them out, since `ons` on a line of its own does the job.

    *Recommend adding both.* Adopted: `osr` and `osf`, each storage bit under every rule
    an `ons` bit has. *(Landed with M3-4, 2026-10-14: each passes on the power it receives,
    decision 100; its pulse bit may be a member logic may write, decision 101; `osf` pulses
    on its false rung's run, and a frozen block holds both bits, decision 102; and neither
    is warned about under an event task, as `ons` is not, decision 103.)* *(Changed
    2026-10-15 by the maintainer's answer to decision 103: each is a warning under an
    event task, as an `ons` now is.)*
81. **Skipping ahead (M3-5).** Jump over a group of lines while the line is in manual mode.
    - Yes, forward only: the skipped lines do not run that scan, and their outputs stay as
      they were; a backward jump, which could loop for ever, is refused;
    - or no: the manual-mode logic goes in a block, switched off as a whole.

    *Recommend forward only, last in the milestone.* Adopted: a forward `jmp` to a `lbl`.
    *(Landed with M3-5, 2026-10-15: `jmp done` and `lbl done`, the label first on its rung,
    a jump back or to its own rung refused at its line; where they stand and what they pass
    on, decision 104, and what a label is, decision 105.)*
82. **A timer in skipped lines (M3-5).** The fan's run-on timer is in the skipped section;
    the line spends 10 seconds in manual mode with the timer half done.
    - It catches up the 10 seconds when it next runs, as a timer in a switched-off block
      does (decision 8);
    - or it carries on from where it was.

    *Recommend catching up.* Adopted: skipped rungs freeze as a false `cal` freezes a
    block, and a timer in them catches up when next run. *(Landed with M3-5, 2026-10-15: a
    skipped rung runs nothing, so its outputs hold, an `ote`'s among them, its counters and
    one-shots keep their edge memory, a pulse bit stays as it was, a block its `cal` would
    run stays frozen with its one-shots' blocks, and a timer, whose `last` only its own run
    stamps, catches up; an edge that comes and goes while its rung is skipped is never
    seen, and a section skipped since the first scan runs its edge instructions first on a
    scan that is not a first scan, as a block does (decisions 89 and 102). An online edit's
    block list keeps a skipped rung's memories, decision 106.)*
83. **A master control zone (M3-5).** One switch that forces a group of lines off. The
    vendors disagree on its name and on what "off" means, the newest controllers of the
    family that made it popular have dropped it, and IEC does not have it.
    - Leave it out, for good: a contact at the head of each line, or a block switched off;
    - or add it later.

    *Recommend leaving it out.* Adopted: logex has no MCR, and `docs/naming.md`'s deferred
    `mcs … mce` becomes "not added". *(Landed with M3-5, 2026-10-15: the Program control
    table's row says so.)*
84. **How a ladder program drives a counter's count, reset and load (M3-1),** the rework
    67 and 68 asked for, under IEC's model. IEC lets a block's inputs be assigned apart
    from its call, *"These separate assignments shall become effective with the next call
    of the function block"* (Ed 3 §6.6.3.4.1, rule 3b; Table 42 features 6a and 6b,
    `r--| MOVE |--YourCTU.CU` drawn beside the box), and logex's text has one power input
    per instruction.
    - The count input is the rung's power into the counter's instruction, `xic eye ctu
      boxes 12`; the reset, the load and the preset are input members, written by any
      instruction that writes a bool or a dint, `xic reset_pb ote boxes.r`, `move 20
      boxes.pv`, which the counter reads when its instruction next runs;
    - a `res` instruction, the conventional set's, which IEC does not have (reset is a
      pin);
    - or the reset as an operand of the instruction, `ctu boxes reset_pb 12`, a tag in
      place of IEC's wired pin.

    *Taken: the input members.* They are IEC's pins by IEC's own rule, need no new
    instruction or slot, and take any rung condition. What an operator sees: while the
    reset button is held the count stays at 0, and a box that arrives meanwhile is not
    counted (IEC's R before the count); the reset shows on the scan the button is pressed
    where its rung comes above the counter's, and on the next where it comes below, as the
    rule says. *(Landed with M3-1, 2026-10-14. When a reset or load acts was confirmed by
    decision 91, and an `rto` is cleared by an input member the same way, decision 90.)*
85. **A `ctud`'s two count inputs, from two rungs (M3-1).** IEC's CTUD is one call with
    both inputs; a ladder rung has one power flow.
    - Two instructions on one `ctud`: `xic infeed ctu stock 50` on one rung drives its
      `cu`, `xic outfeed ctd stock 50` on another its `cd`, each running IEC's body for its
      own side where it stands in the scan, the reset and load included, its presets
      agreeing;
    - one `ctud` instruction whose power is `cu`, its `cd` an input member written on
      another rung by a coil;
    - or one instruction with the two inputs as operands.

    *Taken: the two instructions,* the conventional ladder's idiom of a `CTU` and a `CTD`
    on one counter, which keeps the two inputs symmetrical. Away from the limits, two edges
    in one scan net zero, as IEC's `NOT (CU AND CD)` gives; at a limit the side that would
    leave the dint is refused and flagged, and the other counts. `ctud` is a type word
    only, and a `ctu` or `ctd` on a counter of the other kind, or two `ctu`s on one, is
    refused. *(Landed with M3-1, 2026-10-14.)*
86. **Which members logic may write (M3-1).** IEC's outputs are read, never written, from
    outside a block.
    - The inputs `r`, `ld` and `pv`; never `cv`, `q`, `qu`, `qd`, `ov` or `un`, which
      only the counter sets, nor `cu` and `cd`, which its rungs' power sets;
    - or `cv` too, as decision 9 lets logic write a timer's `.acc`.

    *Taken: the inputs only.* The count changes through `r` and `ld`, which also clear the
    flags, so no write can leave `ov` on at a count of 3. Decision 9 stands for timers. *(Landed with M3-1, 2026-10-14. Confirmed by decision 92.)*
87. **A counter across an online edit (M3-1),** from the spike: a counter an edit adds
    while its rung is true counted at once, and the block list blocked a preset-only
    change.
    - Each counter instruction's edge memory joins decision 21's block list, by its path,
      `boxes.cu`, so that the next scan that runs it counts no edge: one the edit adds, or
      whose rung it changes, a rung compared without the preset of any counter or timer on
      it, which no power on the rung reads; no "written through nothing else" test, since
      no logic writes an edge memory; reported `:ons_blocked`, with the memory's value. The
      field keeps its name, since `%Logex.Instance{}` is public;
    - or a list and a report kind of their own.

    *Taken: decision 21's list.* A `ctud` blocks each side alone, so an edit of its infeed
    rung loses no outfeed edge. *(Landed with M3-1, 2026-10-14.)* *(Added 2026-10-14,
    after M3-1's review: the comparison without presets is decision 21's for every entry
    of the list, an `ons`'s storage bit among them, not only a counter's edge memory, and
    a `ton`'s preset is left out as a counter's is. That changes what came before M3-1: an
    edit that moves only the preset of a `ton` on a rung that holds an `ons`, `xic a ons b
    ton t1 500` to `ton t1 600`, blocked the `ons` until M3-1 and blocks it no more, so
    its next real edge is no longer lost. It loses fewer real edges and makes none up,
    since the preset is read by no power on the rung, and was kept. M3-1's step 3 made the
    change without saying so; this note owns it, and `edit_test.exs` pins it.)*
88. **A counter's forecast after its preset moves (M3-1).** A `.pv` moved by decisions 23
    and 27 changes `q` (`qu` on a `ctud`) at the counter's next run, whatever its rung,
    unless that run counts, resets or loads. *(Corrected 2026-10-14, after M3-1's review,
    which had read "certain": the run sets `q` from the `cv` it leaves, so a box counted or
    a reset at that run can keep `q` where it was, as a timer's forecast holds unless
    enough time has passed.)*
    - Report it as `:dn_drops` and `:dn_rises`, read as "the done output", `{cv, pv}`;
    - or two new report kinds.

    *Taken: the existing kinds,* documented as a counter's `q` where the instance is a
    counter, so a host that knows them knows a counter's. *(Landed with M3-1, 2026-10-14.)*
89. **A counter in a frozen block (M3-1).** A block whose `cal` is false holds everything
    in it (decision 8): a counter there neither counts nor sees its rung, so a box that
    comes and goes while the block is frozen is never counted, and one still on the eye
    when the block next runs counts then if the counter last saw the eye clear. The spike
    measured the missed box.
    - Keep decision 8's freeze, and say so where a counter is described;
    - or run a frozen block's counters.

    *Taken: the freeze,* one rule for everything in a block. *(Landed with M3-1, 2026-10-14.)*
90. **How a retentive timer is cleared (M3-2),** asked after M3-1's review. Picture
    decision 76's lubrication timer, adding up how long the conveyor motor has run: once
    the line has been greased, its time must go back to zero.
    - A reset input member, `.r`, written by any rung as a counter's `r` is (decision 84):
      `xic greased ote lube.r`, as Siemens' TONR has an `R` pin;
    - or a `res` instruction, the conventional set's RES: `xic greased res lube`.

    The design had cleared an `rto` with `res`; once 84 dropped `res`, `PLAN.md`'s M3-2
    left the choice open, with no recommendation. **Taken: the reset input member.** An
    `rto` is cleared by `xic greased ote lube.r`, written like a counter's reset and read
    when its instruction next runs, so a program clears everything that keeps a count one
    way. There is no `res` instruction, for a timer or a counter. What else `.r` clears
    beside the time, and its rule across an edit, are M3-2's design. *(Landed with M3-2,
    2026-10-14; what `.r` clears and its rule across an edit, decision 95.)*
91. **When a counter's reset or load acts (M3-1),** asked after M3-1's review, to confirm
    what decision 84 built. The operator presses "reset batch", its rung above the box
    counter's, or below it.
    - When the counter's own rung runs, as IEC's separate-assignment rule has it (Ed 3
      §6.6.3.4.1, rule 3b): a reset rung above the counter clears the count on the same
      scan, one below it a scan later, and while the reset is held no edge is counted;
    - or at the moment a rung writes `r` or `ld`, wherever the counter's rung stands.

    **Taken, as built: when the counter's own rung runs.** Confirmed as wanted on
    2026-10-14. It is IEC's rule, and how M3-1 runs a counter (decision 84).
92. **Whether logic may write a counter's count (M3-1),** asked after M3-1's review, to
    confirm decision 86. An operator wants to correct a count by hand.
    - `cv` read-only to logic: a count changes only by counting, by `r`, and by `ld`,
      which puts `cv` to a `pv` logic may write first;
    - or `cv` writable, as decision 9 lets logic write a timer's `.acc`.

    **Taken, as built: `cv` stays read-only to logic.** Confirmed on 2026-10-14. IEC's
    outputs are never written from outside a block, and the flags `ov` and `un` stay
    consistent with the count, cleared by the same reset or load that moves it.

**M3-2's own choices, 2026-10-14.** Decisions 93–95 are M3-2's routine choices, where
neither the record nor IEC left a question for the maintainer, each with the alternative
the record keeps. After M3-2's review the maintainer confirmed 93, the same day.

93. **An off-delay timer's done bit and its delay (M3-2).** A fan runs on for 30 seconds
    after the motor stops: `xic motor tof run_on 30000`, the fan worked by a rung below.
    - `.dn` is IEC's Q and the conventional TOF's `.DN`: set while the rung is true and
      through the delay, off once it ends, so the fan is wired to `xic run_on.dn`; `.tt` is
      set only while the delay runs;
    - or `.dn` means "the delay is over", set once it ends, as decision 74's words read
      for a pulse timer, the fan then wired to the rung's own contact and `.tt` in parallel.

    *Taken: IEC's Q.* IEC's TOF and the conventional TOF agree, and §8 maps `.dn` to Q for
    every timer but a `tp`; a `tof`'s "done" is then on while it still runs its delay, which
    is what both families mean by it, where decision 74 chose for a pulse alone. The delay
    is IEC's and MatIEC's: the first de-energised run after an energised one starts it,
    adding nothing, as a `ton`'s rising scan adds nothing; each de-energised run while `.tt`
    is set adds the time since the timer last ran, stopping at `.pre`, where `.dn` and `.tt`
    drop; a rung true again ends the delay with `.dn` still set. At rest `.acc` stays at
    `.pre`, as IEC's ET does, and raising `.pre` there starts nothing, as MatIEC's state 2
    holds; a new instance starts at rest with every member at its initial value, `.acc` 0,
    one rule for new state, where the conventional prescan sets `.acc` to `.pre`. The
    falling edge is read from `.en`, which every start and restart puts at 0, so no first
    scan sees one (decision 69). Across an online edit a `tof` is a timer as a `ton` is
    (decision 23): its `.pre` moves by decisions 23 and 27, a change of type needs a
    restart, and one restored resumes from the switch where it was timing, which for a `tof`
    is `.tt` set, not `.en`. A moved `.pre` changes `.dn` during the delay: where `.acc` is
    at or past the new `.pre` there, `:dn_drops` says `.dn` drops at the timer's next run,
    unless that run finds its rung true. It changes it too where the rung was true at the
    timer's last run, `.en` set, and `.pre` moves to 0: the delay then ends on the falling
    edge's own scan, so `:dn_drops`, `{0, 0}`, says `.dn` drops at the timer's next run with
    its rung false, however many runs with its rung true come first, as a `ton`'s and an
    `rto`'s forecasts are for a run with the rung true. Its falling edge needs no place on
    decision 21's block list: an edit that turns its rung false starts the delay, `.dn`
    staying set through it, as the rung falling would, where blocking it would stop the fan
    at once. *(Corrected 2026-10-14, after M3-2's review, which had read "only during the
    delay": the fan's run-on moved from 30 s to 0 while the motor runs stops the fan the
    moment the motor stops, where the original runs it on 30 s more, and the edit forecast
    nothing. It now forecasts `:dn_drops`.)* *(Noted 2026-10-14, after M3-2's review: at a
    preset of 0 the delay is IEC's and not MatIEC's. MatIEC's `TOF` (`lib/timer.txt`) enters
    state 1 on the falling edge's call and tests the end only on a later call, in its `ELSE`
    branch, so its Q, `IN OR (STATE = 1)`, stays TRUE for that call; logex drops `.dn` on
    the falling edge's own scan, a delay of 0 ms, as IEC's diagram draws it, and
    timer_test.exs pins it. At any other preset no run that starts the delay can end it, and
    the two agree.)* *(Confirmed by the maintainer on 2026-10-14, after M3-2's review: a
    `tof`'s `.dn` follows IEC, on while the rung is true and through the run-on, and the fan
    is wired to `.dn`. The maintainer was asked knowing what it means: "done" is on while
    the timer still counts the run-on, so a `tof` is the one exception to decision 74's
    "done never means still running" on any timer, which decision 74 took for a pulse and
    which every other timer keeps.)*
94. **A pulse timer's pulse, start to end (M3-2),** following decisions 74 and 75. A horn
    sounds for 3 seconds from a fault's rising edge: `xic fault tp horn_pulse 3000`, the
    horn worked by `xic horn_pulse.tt` on a rung below.
    - The pulse runs its preset whatever the rung does, as IEC's diagram draws it: a new
      edge during the pulse starts nothing, a pulse once ended starts again only after the
      rung falls and rises, and `.dn`, set as the pulse ends with the rung true, stays set
      while the rung holds, as IEC's ET stays at PT; a pulse that ends with the rung false
      leaves `.dn` and `.acc` at 0;
    - or a new edge during the pulse starts it again from 0, a retriggerable pulse, as
      Siemens's classic S_PEXT extends one.

    *Taken: IEC's.* The pulse is IEC's TP, MatIEC's body read step for step but at a preset
    of 0 (below): it starts on a rising edge, `.en` 0 from the timer's last run, never on a
    first scan (decision 75) nor where an online edit's block list holds `.en`, `.acc` at 0
    and adding nothing on that scan; each run while `.tt` is set adds the time since the
    timer last ran, its rung true or false, and at `.pre` the pulse ends. With a preset of 0
    it starts and ends on one scan, `.tt` never set and `.dn` set. Raising `.pre` once the
    pulse has ended starts nothing. Its edge memory `.en` joins decision 21's block list by
    its path, `horn_pulse.en`, as a counter's does (decision 87): a `tp` an edit adds while
    its rung is true, or one whose rung it changes, sounds no horn at the switch, and one
    whose preset alone changes keeps a real edge. Across a switch it is a timer by decision
    23, resumed where its pulse was running, `.tt` set. A moved `.pre` changes its pulse
    only while it runs: where `.acc` is at or past the new `.pre` there, `:dn_rises` says
    the pulse ends at the timer's next run, `.tt` dropping and `.dn` rising, unless that run
    finds its rung false, when `.dn` stays at 0 as the pulse ends. *(Noted 2026-10-14, after
    M3-2's review: at a preset of 0 the pulse is IEC's and not MatIEC's. MatIEC's `TP`
    (`lib/timer.txt`) sets Q TRUE on the rising edge's call and tests the end only on a
    later call, in its `ELSIF (STATE = 1)` branch, so its Q is TRUE for that one call; logex
    starts and ends the pulse on the rising edge's own scan, a pulse of 0 ms, `.tt` never
    set, and timer_test.exs pins it. At any other preset the two agree.)*
95. **What a retentive timer's reset clears, and its rule across an edit (M3-2),** which
    decision 90 left to M3-2. Decision 76's lubrication timer adds up the motor's running
    time, `xic motor rto lube 360000000`, and `xic greased ote lube.r` clears it.
    - `r` clears the time and the status bits `.dn` and `.tt`, and keeps `.pre`; `.en`
      takes the rung's power as on every run, where the conventional RES, which sets
      `.ACC` to 0 and a TIMER's *"control status bits to false"* (general instructions
      ref., RES, p.107), clears `.EN` too. While `r` is held the timer stays at 0, adding
      nothing, and it times again from the last scan that saw `r`. Across an online edit
      `r` is a member like a counter's `r`: kept with its instance, 0 in a new one;
    - or `r` also clears `.en`, as the conventional RES does, so the first scan after `r`
      is released adds nothing, as a `ton`'s first scan with its rung true adds nothing.

    *Taken: the first,* a departure from the conventional RES that logex owns. `.en` is the
    rung's power when the instruction last ran, as the conventional TIMER's `.EN` is, so a
    reset leaves it what the rung made it, as a counter's reset keeps its edge memory
    (decision 70), where RES clears a counter's `.CU` and `.CD` too; the time from the last
    scan that saw `r` to the next is counted, at most one scan more than the other reading
    would give. `r` acts when the timer's own instruction runs, as a counter's does
    (decisions 84 and 91): a reset rung above the timer clears it on the same scan, one
    below it a scan later. Every restart, warm or cold, starts it again at 0 (decision 76).
    Across a switch it is a timer by decision 23, resumed where its rung was true, `.en`
    set, as a `ton` is; a change of type, a `ton` made an `rto`, needs a restart. A moved
    `.pre` changes `.dn` at the timer's next run with its rung true, since a false rung
    keeps `.dn` as it was: `:dn_drops` where `.dn` is set and `.acc` below the new `.pre`,
    unless at least `.pre` − `.acc` ms of true rung pass by then; `:dn_rises` where `.dn` is
    0 and `.acc` at or past the new `.pre`, whether or not its rung was true at the switch,
    unless that run finds `r` set. *(Corrected 2026-10-14, after M3-2's review, which had
    read "as the conventional RES does" of `.acc`, `.dn` and `.tt` alone: RES clears every
    status bit of a TIMER, `.EN` among them, and logex keeps `.en`.)*

**After M3-2's review, 2026-10-14.** Decision 96 is the maintainer's answer to a question
asked after M3-2's review the same day, which decision 95's rule across an edit raised:
what becomes of a block's input that an online edit leaves no rung writing.

96. **A block's input an edit stops writing while it is on (M3-1, M3-2),** asked after
    M3-2's review. Decision 76's lubrication timer is being greased, the "greased" button
    held and `lube.r` on, when an online edit removes the rung `xic greased ote lube.r`. No
    rung writes `lube.r` any more, so it stays on, and the timer stays at 0 until a
    restart. A counter's `r` or `ld`, or a preset logic moved into a `pv` or a `.pre`, is
    left so too.
    - It keeps its value, as an output an edit stops driving does (decision 20), and the
      edit's report names it as no longer written, so whoever made the edit sees it;
    - it keeps its value, and nothing says so, as M3-2 built it;
    - or the switch puts it back to 0, a write no logic made, which decision 21 keeps a
      switch from making to a storage bit.

    **Taken: kept, and reported.** A member input logic writes, a counter's `r`, `ld` or
    `pv`, an `rto`'s `r` or a timer's `.pre`, of a built-in instance the program started
    declares, at any depth, that the program stopped writes through an instruction
    (`Logex.Walk.member_writes/1`) and the program started writes through none, keeps its
    value, and a switch reports it by its path, `{:unwritten, "lube.r", 1}`, with the
    value it keeps, whatever it is; so the forecast, the report a test taken now would
    give, lists it too, and in a configuration each kept instance's come by path,
    `{:unwritten, "m1.lube.r", 1}`. No existing kind fits: `:held` is an output's, a
    point the host holds at its value at every step, and `:unread` a var_input's, which
    the host stops sending; a member input is neither and asks nothing of the host, so it
    is a kind of its own, `:unread`'s mirror, in `Logex.Edit`'s table and §4.9's. A
    timer's `.acc`, which logic may write too (decision 9), is its own output, set at
    every run, and is not reported. Nothing is blocked or written: the counter or timer
    reads its kept input at its next run, as decision 91 reads any. *(Landed 2026-10-14. Its scope confirmed by the maintainer the same day: the report names the member whatever its value, not only when it is on, since nothing resets the counter or timer any more either way, and a `pv` or `.pre` is reported beside `r` and `ld`.)*

**M3-3's own choices, 2026-10-14.** Decisions 97–99 are M3-3's routine choices, where
neither the record nor IEC left a question for the maintainer, each with the alternative
the record keeps; 99 is the shape of the report decision 78 asked for and left to M3-3.

97. **How a negative literal is written, and where one goes (M3-3),** `PLAN.md` §5's rule
    landing first in M3-3. A level setpoint below a sensor's zero, `move -5 offset`, or a
    tare written on a declaration, `var tare dint -120`.
    - `-5`, the sign glued to the digits, one token, located at the `-`, as `PLAN.md` §5
      settled; a `-` with no digit straight after it stays illegal, so `- 5` and `--5`
      do not lex, and there is no `+`. A sign begins a lexeme, so a name or a number
      running straight into one, `a-5`, `t1.dn-5` or `5-3`, is one mistyped lexeme,
      named whole from its start, as B2 names `1bst`, and a signed number running into a
      letter, `-5a`, is B2's own. `-0` is 0, and prints as 0;
    - or `a-5` read as the tag `a` and then the literal `-5`, a silent split of the kind
      B2 closed for `1bst`.

    *Recommend the first.* Adopted. IEC's integer literal takes a sign, `-12` and `+986`
    (Ed 3 Table 5 feature 1, p.27; Annex A, `Signed_Int`), and logex keeps `+` out, as
    `PLAN.md` §5 has it. A negative literal goes wherever a literal goes, each slot's own
    check then judging it: a `move`'s source, a comparison's operand, an arithmetic
    operand, a `cal`'s var_input, a dint's initial value, and in a configuration file a
    global's initial value, a var_input's constant, an interval and a priority. A bool's
    0 or 1 and a preset's 0 to 2147483647 are unchanged, so `ton t1 -1` is refused at its
    line, as `ton t1 2147483648` is, and a negative interval or priority is refused in the
    configuration file's words, as one too large is, where `Logex.Configuration.check/1`
    raised one as the host's mistake until a line could say it (decision 36).
    `Logex.Parser.well_formed!/1`, `Logex.Declarations.check/1` and
    `Logex.Configuration.Text.entries!/1` widen with it, as `PLAN.md` §5 said they would.
    The golden record gains a source for each case and changes none of its entries, since
    no source in it held a `-` before a digit. logex has no infix operator, so a `-` can
    only be a sign; when infix arithmetic arrives, the sign moves to the grammar.
    *(Landed 2026-10-14.)* *(Extended 2026-10-21 by decision 149: from Milestone 5 a
    literal may be a real, `37.5`, `-0.25` or `1.5e3`, digits on both sides of its point,
    `1.`, `.5` and `1e5` refused; a based integer, `16#ff` or `2#1010`, with no sign and
    no octal; and any number may hold a single `_` between two digits, `1_000`. `+` stays
    out, in an exponent too, so `1.5e+3` is refused. Each is still judged by its slot, a
    real literal refused in an integer slot and a based one the number it spells (decision
    147), and `well_formed!/1`, `Logex.Declarations.check/1` and
    `Logex.Configuration.Text.entries!/1` widen with each, as above.)*
98. **What an arithmetic instruction passes on, and what may follow it on its line
    (M3-3),** following decisions 73, 77 and 78. The fill valve's total, with a lamp on the
    same line that shows the total is real: `xic fill add total flow total ote total_ok`.
    - The power out is IEC's ENO, rung power its EN (Ed 3 §6.6.1.5, p.63; Table 18
      feature 4, p.65, an ADD in LD whose ENO drives a coil): true where the result is a
      dint's, false where it left the dint (decision 77) or the divisor was 0 (decision
      78), and false on a false rung. It is settled, so anything may follow on its path,
      the lamp here, or a second arithmetic instruction, which then runs only where the
      first succeeded;
    - rung-condition-in, as the conventional ladder passes it on, true or false, which
      decisions 77 and 78 rule out by name;
    - or nothing after it, as after a counter or a timer (decision 73).

    *Recommend the first.* Adopted. Decision 73 refuses what follows an instruction whose
    power out is not settled, so that either reading stays open to a later change; this
    one's is settled by decisions 77 and 78, and IEC draws the very rung. What is warned
    about stays small: every source a literal, `add 2 3 x`, compiles with a warning, as two
    compared literals do (M1-6), since its result never changes; a destination that is a
    source, `add total flow total`, is the instruction's commonest use and draws none; nor
    does a divide by a literal 1, which is harmless. *(Landed 2026-10-14. That a `mod` by
    zero behaves as a `div` by zero, writing 0, passing no power and reporting its fault
    (decisions 78 and 99), where MatIEC's MOD keeps ENO TRUE, was confirmed by the
    maintainer on 2026-10-14, after M3-3's review.)* *(Amended 2026-10-21 by decision
    146: from M5-2 the power out is false where the result wrapped, its stored value not
    the exact one, in place of "where it left the dint"; a real's is false where it
    saturated or its divisor was 0.0 (decision 150), and a conversion's where its value did
    not fit (decision 148). It stays settled, so anything may still follow. The bitwise
    instructions, which cannot fail, pass on their power in (§4.12).)* *(Amended
    2026-10-21 by decisions 164 and 165: `sqrt`'s power out is false where its source was
    negative, and a shift's or a rotate's where its count, a tag, was negative.)*
99. **How a zero divisor is reported to the host (M3-3),** the event's shape decision 78
    left to M3-3. The line works out "boxes per minute", `div boxes minutes per_minute`,
    and just after start-up the minutes are 0: the division gives 0, passes no power, and
    the host is to be told, the plant running on. The host runs the plant through
    `Logex.Runtime.cycle/3`, whose events are a log, or one program alone through
    `call/4` and `scan/2`, which return `{outputs, state}` and no events.
    - A fault is data, `%Logex.Fault{kind: :divide_by_zero, instruction: :div | :mod,
      path:, file:, line:}`, `path` nil on the program's own rungs or the block instance
      it ran in, `"s1"` or `"s1.inner"`, and `file` and `line` the routine's own, the
      block's file for a block's, as a diagnostic cites them. A cycle reports each as an
      event, `{:fault, task | :none, instance, fault}`, just after its scan's `{:ran, task,
      instance, now}`, in the order they happened, `instance` the program instance's name,
      so `"m1"` and `"s1"` place one at `m1.s1`; a lone instance's state carries its last
      scan's in a new field, `state.faults`, `[]` for none, replaced by every scan, which
      a host reads after the scan that returned it. A resource keeps none in its states:
      the events are the record, as the resource is the one copy of each global (decision
      49);
    - the same, but a fault as a tuple, `{:divide_by_zero, :div, path, file, line}`, which
      fits a report's or an event's style and names nothing;
    - or `call/4` and `scan/2,3` returning a third element, the scan's events, which every
      host and test of a lone instance would have to change for.

    *Recommend the first.* Adopted. The events are an open set (`Logex.Runtime`), so a host
    that tolerates a kind it does not know runs on unchanged, and `:fault`'s fault has its
    own open `kind`, for any later minor fault. A fault names what decision 78 asks, the
    instance, the file and the line, and what the host needs to find the instruction: its
    mnemonic, and the block instance's path, since a line alone is the block's file's. The
    field is new state in an instance, with its rule: `instance/1` gives `[]`; each scan
    replaces it; `put_inputs/3`, `restart/3` and an edit's switch keep it, since none is a
    scan, as each keeps `switched`; the runtime checks it, a proper list of
    `%Logex.Fault{}`, with a message a test pins, and looks no further, since the next scan
    replaces it. A cycle reports the faults and then drops them from the state it keeps,
    so a resource's state, its restart and a configuration edit carry none. Only a zero
    divisor is a fault: a result brought to a dint's limit passes no power and is not
    reported (decision 77), as the conventional set reports an overflow only where a
    controller is set to, and logex has no such setting. The conventional DIV and MOD
    raise a minor fault, type 4 code 4, for a zero divisor, and the controller runs on;
    logex's event is that, located. *(Landed 2026-10-14.)* *(Amended 2026-10-21 by
    decisions 153 and 160: a zero divisor is no longer the only fault. `%Logex.Fault{}`
    gains `severity`, `:minor` for a zero divisor, an integer's or a real's, and `:major`
    for two new kinds, `:index_out_of_range` and `:bit_out_of_range`, which carry the
    subscripts or bit number read; a major fault is placed as this decision places a
    fault, in `state.faults` and as the cycle's event, and the runner trips on it
    (decision 113's note). A wrap is still no fault (decision 146), as "a result brought
    to a dint's limit" was not.)* *(Amended 2026-10-21 by decision 164: a minor kind more,
    `:negative_sqrt`, `instruction: :sqrt`, so that the kinds are `:divide_by_zero` and
    `:negative_sqrt`, minor, and `:index_out_of_range` and `:bit_out_of_range`, major.)*

**M3-4's own choices, 2026-10-14.** Decisions 100–103 are M3-4's routine choices for the
pulse coils decision 80 adopted, each with the alternative the record keeps; where the
record answers one, 103, it says which decisions do.

100. **What a pulse coil passes on, and what may follow it on its line (M3-4),**
     following decisions 73 and 98. A start button steps a sequence once a press, and the
     same line lights a lamp while it is held: `xic start_pb osr s1 step ote held_lamp`.
     - The power it receives, as `ote` passes it: IEC's coil, *"The state of the left link
       is always copied to the right link"* (Ed 2 Table 62 features 8 and 9, p.142; Ed 3
       Table 76, pp.218–219), and the conventional OSR and OSF, *"Set Rung-condition-out
       to Rung-condition-in"* (general instructions ref., pp.74–81). It is settled, so
       anything may follow on its path, the lamp here, which sees the button, not the
       pulse;
     - the pulse, as `ons` passes it, so the rest of the line sees one scan only;
     - or nothing after it, as after a counter or a timer (decision 73).

     *Recommend the first.* Adopted. Decision 73 refuses what follows an instruction
     whose power out is not settled; IEC and the conventional set agree on this one, which
     is what parts a coil from `ons`: the one-shot gates the line, and the coil lets it
     run on. A program that wants the pulse on the same line reads the pulse bit after
     it, `xic start_pb osr s1 step xic step …`. *(Landed 2026-10-14.)*
101. **A pulse coil's two bits (M3-4).** The coil keeps the power it last received in a
     storage bit and sets a pulse bit: `osr s1 step`.
     - The storage bit first, then the pulse bit, the conventional order, each a bool the
       coil writes, so neither a var_input; the storage bit a tag of the routine, under
       every rule an `ons` bit has (decision 80), so never a member, since the block list
       names it as a tag (decision 21); the pulse bit a tag or a member logic may write,
       `osr s1 boxes.r` a one-scan reset, and never the storage bit, which would hold
       only the power and never pulse; and, since each run writes the pulse bit as `ote`
       writes its tag, a second coil on it, an `ote` among them, the second-`ote`
       warning, the later one told the first in its words;
     - or the pulse bit a tag only, as the storage bit is, and a second coil on it
       refused.

     *Recommend the first.* Adopted. A one-scan pulse into a counter's reset or load is
     the coil's commonest job after stepping a sequence, and a member logic may write is
     written by `ote` already; nothing an edit keeps names a pulse bit. Two coils on one
     pulse bit compile, as two `ote`s on one tag do, since only the last in the scan
     decides it and a warning says so. A second one-shot on a storage bit, an `ons`, an
     `osr` or an `osf`, is an error in the words of the two, and a storage bit and pulse
     bit that are one tag an error at the coil's line. *(Landed 2026-10-14.)* *(Added
     2026-10-15, after M3-4's review, which found `PLAN.md` crediting it to decisions
     100–103 and none of them recording it: an online edit compares a coil's rung whole,
     the presets of any counter or timer on it left out (decision 87), and its pulse bit is
     part of it, so an edit that changes only the pulse bit, `xic start_pb osr s1 step` to
     `xic start_pb osr s1 next`, blocks the coil until a scan runs it. The cost is one real
     press: a press that rises on the first scan after the switch sets no pulse, though the
     storage bit holds the power the coil last received and an unblocked coil would set its
     new pulse bit, and the next press pulses. Decision 87's reason for leaving presets
     out, fewer real edges lost and none made up, would leave the pulse bit out too; it is
     kept in for one rule with `ons`, whose rung is compared whole, what its pulse drives
     among it, so an `ons` whose rung changes only in that, `ote step` to `ote next`, is
     blocked too, and a storage bit's block never turns on which operand of its rung
     changed. `edit_test.exs` pins it.)*
102. **When `osf` sees its edge, and a coil in a frozen block (M3-4).** A "box left the
     eye" pulse, `xic eye osf s2 gone`, and the same coil inside a block whose `cal` is
     false while the box leaves.
     - `osf` sees the fall on its run with its rung false, as IEC's element is evaluated
       with its left link OFF as with it ON: the pulse bit is set where the storage bit
       holds 1, then the storage bit cleared; a true rung clears the pulse bit and sets
       the storage bit. A coil in a block whose `cal` is false does not run, so both its
       bits are held, as everything in a frozen block is (decisions 8 and 89): a pulse set
       at the body's last run stays on until it next runs, and an edge that comes and
       goes while it is frozen is never seen;
     - or a frozen block's pulse bits cleared, so no pulse outlives a scan.

     *Recommend the first.* Adopted: one rule for everything in a block, which a block's
     own `ote` already meets, its tag held by a false `cal`; a program that must not see a
     held pulse reads the block's enable beside it. *(Landed 2026-10-14.)* *(Added
     2026-10-15, after M3-4's review, which found it unrecorded: decision 69's first scan
     is the instance's, so a block whose `cal` is first true after it runs its coils for
     the first time on a scan that is not a first scan, and each reads its storage bit as
     declared. An `osr` whose rung is true there pulses, a button held since start
     stepping once at the block's first run, as an `ons` fires there and a counter counts
     (decision 89); and an `osf` whose storage bit is declared 1 pulses on a false rung, a
     fall that never happened, the one way a declared value makes an edge. A block an
     online edit adds has its coils' storage bits on the block list by path until a scan
     runs its body (decision 32), so its first run pulses neither. The behaviour is kept,
     one rule with `ons` and the counters, and `pulse_coil_test.exs` pins the `osf`'s
     pulse and the `osr`'s.)* *(Confirmed by the maintainer on 2026-10-15, after M3-4's
     review: a pulse inside a block whose `cal` is false freezes, its pulse bit staying on
     until the block runs again, as everything in a frozen block holds. It is what M3-4
     built, and `pulse_coil_test.exs` pins it.)*
103. **A pulse coil under an event task (M3-4).** The e-stop's own event task pulses a
     "pressed" bit, `xic estop osr s1 pressed`; the task runs only when the e-stop
     switches on, so the coil sees "pressed" at every run and never pulses after the
     first, which is the instance's first scan.
     - No warning, as for an `ons`: decision 72 warns of a counter under an event task and
       leaves a one-shot unwarned, and decision 80 puts a coil's storage bit under every
       rule an `ons` bit has;
     - or a warning, in the coil's words, as for a counter (decision 72) and every timer,
       a `tp` among them (M3-2), which would then leave `ons` the one edge-driven
       instruction unwarned.

     *Taken: no warning,* as decisions 72 and 80 read together, and the reversible way: a
     warning stops nothing, and adding one later breaks no program. Whether one-shots,
     `ons` with them, should be warned about as counters are is the maintainer's to
     decide. *(Landed 2026-10-14.)* *(Confirmed by the maintainer on 2026-10-15, after
     M3-4's review, superseding "no warning": a warning for all three one-shots, `ons`
     with the coils, as for a counter, each in its own words. The e-stop's own event task
     runs `xic estop osr s1 pressed`; the configuration now tells it that an osr sees its
     rung only at the task's runs, so a pulse between two runs is never seen, the pulse it
     sets stays on until the task's next run, and a rung that is the task's trigger, as
     `estop` is here, is true at every run and never pulses. An `ons` is told that a pulse
     between two runs never fires it, and an `osf` that a drop between two runs is never
     seen. Each one-shot a program instance runs under a task with a `single`, alone or
     with an interval, at any depth, is a warning on the configuration's `warnings` at the
     instance's line, a block's by its storage bit's path, `e.s`, after the instance's
     timers and counters, citing the instruction's own file and line, from
     `Logex.Walk.one_shots/1`, read once a program type as the timers are. It changes what
     decision 72 said of an `ons`, and decision 80's landed note. Landed 2026-10-15.)*


**M3-5's own choices, 2026-10-15.** Decisions 104–107 are M3-5's routine choices for the
forward jump decisions 81 and 82 adopted, each with the alternative the record keeps; where
the record answers one, it says which part of it does.

104. **Where `jmp` and `lbl` stand, what they pass on, and when the jump is taken (M3-5),**
     following decisions 73, 98 and 100. A line in manual mode skips its automatic rungs,
     and the same line lights a lamp: `xic manual jmp manual_end ote manual_lamp`, the
     section ending at `lbl manual_end`.
     - The jump is taken once its rung is done, as IEC has it, *"The evaluation of a
       network is not complete until the outputs of all of its elements have been
       evaluated, even if the network contains one of the execution control elements"*
       (Ed 2 §4.1.3 rule 3; Ed 3 §8.1.5 rule c): the rest of its rung runs, and then the
       rungs after it up to the labelled one are skipped, and the labelled rung runs. A
       `jmp` passes on the power it receives, as `ote` does, so anything may follow it, the
       lamp here, and stands anywhere on its rung, a branch's leg among the places; a rung
       holds one, since which of two would win is not settled. A `lbl` stands first on its
       rung, as the conventional LBL must and as IEC writes a network label at its head,
       and passes on the power it receives, always its rung's;
     - or nothing after a `jmp` on its path, as IEC draws a jump at the end of its line,
       the reversible refusal decision 73 makes after a counter or a timer;
     - or the jump taken at once, the rest of its rung not run, as ClassicLadder's jump coil
       ends its rung (`docs/instruction-sets.md` §5.4).

     *Taken: the first,* the reading Milestone 3's design took and called settled: IEC's
     rule 3 settles when the jump is taken, and a `jmp` on a line read as IEC's coils on
     one vertical link, each seeing the line the jump sees, settles what follows it: an
     `ote` after `jmp manual_end` in series sees what it would see beside the jump in a
     branch, the power that reached the jump. The conventional set's execution table says
     nothing of rung-condition-out after a JMP, nor of the rest of its rung (general
     instructions ref., pp.673–675), `unverified` in `docs/naming.md`. De-energised, a
     `jmp` does nothing and passes no power. A jump back, or to its own rung, is refused at
     its line, so a scan stays one pass over the rungs (decision 81). The rung loop is one
     recursion over a routine's rungs, a program's or a block body's, which a jump turns
     into a skip that ends at its label's rung; a scan of a program with no jump costs
     fewer reductions than before M3-5, 308 against 319 for the README motor and 39,126
     against 41,126 for 1,000 rungs, the least of 50 scans each. *(Landed 2026-10-15.)*
105. **What a label is (M3-5).** The manual section ends at `lbl manual_end`, and the
     program has a tag `manual_end` too, the lamp that shows the section is done.
     - A label is a name, never an integer, of a namespace of its own, so it may share a
       tag's name, since no operand of a `jmp` or a `lbl` is ever a tag; no reserved word,
       a mnemonic, a section word or a type word, which the next word of a rung would be
       read as; one rung to a label in a routine, and two labels that differ only in case
       refused, as two tags are, a `jmp` naming one in another case told of it. A label is
       its routine's own, IEC's *"local to the program organization unit"* (Ed 2 §4.1.2),
       so a jump in a function block's body goes to a label in that body, and a `jmp` that
       names no label of its routine is refused at its line. A label no `jmp` names
       compiles, with a warning: nothing jumps to its rung;
     - or labels in the tags' namespace, so that `lbl manual_end` and the tag
       `manual_end` cannot both be declared.

     *Taken: the first,* as Milestone 3's design has it: a label and a tag are never read
     in one place, IEC refuses a shared identifier only for a connector (Ed 2 §4.1.1, Ed 3
     §8.1.3), and the conventional set's rule, unique within a routine, is about labels
     alone. IEC also allows an unsigned integer, which logex would read as a literal; the
     conventional set's labels are names, as logex's are. *(Landed 2026-10-15.)* *(Added
     2026-10-15, after M3-5's review, which found `lbl function_block` and `jmp
     function_block` taken in a block's body: the word that heads a block's file is
     reserved in one, in any case (§4.8), so it names no label there, as it names no tag,
     each `lbl` and `jmp` that names it an error at its line, and a program's file takes it
     as a label as it takes it as a tag. `validation_test.exs` pins it.)*
106. **What a skipped rung leaves on an online edit's block list (M3-5),** following
     decisions 21, 32 and 87. The line runs in auto, the manual section skipped, when an
     online edit changes the rung of the section's step one-shot, `xic jog_pb ons s1 ote
     step` to `xic jog_pb xio auto ons s1 ote step`; the switch blocks `s1` (decision 21).
     - The block holds until a scan runs the one-shot: a storage bit, a counter's edge
       memory or a pulse timer's, listed by a switch, on a rung a jump skips stays listed,
       as one in a block whose `cal` is false does (decision 32), so the one-shot's first
       run, when the line next goes to manual, passes no power. A scan marks each listed
       memory a skipped rung holds, and keeps it; one its routine ran, and one no rung of
       a routine that ran holds, which only a plain swap can leave, is used up as before;
     - or the first scan uses the block up, as every scan used up the program's own bits
       until M3-5: the one-shot's first run then compares its changed rung against the
       bit the old rung wrote, the false pulse decision 21 prevents.

     *Taken: the first,* decision 32's rule at the grain of a rung: the next scan that runs
     the instruction blocks it. A ctud's two sides are kept or used up each by its own
     rung, so a side a jump skips stays blocked while the other's runs. Nothing else an
     edit does turns on a jump: labels are names, so a rung that moves leaves every jump as
     it was; a `jmp` an edit adds freezes its section from the switch, and one it removes
     frees it, by decision 82, its timers catching up and an edge that rose meanwhile seen
     at its first run, as in a block; and a rung is compared whole, its `lbl` and `jmp`
     among it, as decision 101 compares a coil's, so an edit that labels a one-shot's rung,
     or adds a `jmp` to it, blocks the one-shot, losing at most one real edge.
     *(Landed 2026-10-15.)* *(Confirmed by the maintainer on 2026-10-15, after M3-5's
     review: an edit that only adds a `lbl` or a `jmp` to a one-shot's rung or a pulse
     coil's blocks it once. It is the rung compared whole, one rule with decision 101,
     whose cost is one possible press: a press that rises on the first scan after the
     switch sets no pulse, though nothing the coil reads changed, and the next press
     pulses. Leaving the `lbl` and `jmp` out of the compare would save that press, at the
     price of a second part of a rung that a block does not turn on, beside decision 87's
     presets. `edit_test.exs` pins it for an `ons` and an `osr`.)*
107. **What the walks and the warnings make of a skipped rung (M3-5).** The manual section
     and the automatic one each drive the conveyor's motor, `ote motor` in each, a `jmp`
     skipping one or the other on every scan.
     - A rung a jump may skip is a rung: its writes are writes, `Logex.Walk`'s and the
       configuration's checks by them, a write through a var_external to an input point
       refused wherever it stands; the two `ote`s on one tag are the second-`ote` warning,
       which says the last one in the scan decides it, the one that ran last; and a timer
       or counter in a section is run by its instruction;
     - or the walks read the jumps, so that two writers in sections that two jumps make
       exclusive are not warned about.

     *Taken: the first.* The walks read a program's text, not its runs, and which rungs a
     scan skips is a fact of its inputs, so a walk that read the jumps would still guess;
     a warning stops nothing. A program that wants one writer gives the motor one rung,
     fed from each section's own bit.
     *(Landed 2026-10-15.)* *(Confirmed by the maintainer on 2026-10-15, after M3-5's
     review: two coils on one tag in sections that jump over each other keep the
     second-`ote` warning. The checks read the program's text, not which rungs run, as
     this decision has it. `validation_test.exs` pins it.)*

**Milestone 4's design, decided 2026-10-17.** A design pass on `d3931bd` designed the
wall-clock runner (§4.11) and built a throwaway spike of it on the branch
`backup/runner-design`, never to land. Decisions 108–117 are the maintainer's answers to
its questions, each given with the plain-language example the maintainer was asked, the
plant in every one being the design's: a conveyor motor with a start button, a stop button
and an emergency stop; a cooling fan that runs on for a minute after the conveyor stops; a
photo-eye that counts boxes, and a "case full" lamp that lights at 12; a speed setting
sent to the conveyor's drive over the network; the conveyor's logic due every 10 ms, the
fan's twice a second, and the box counting and the lamp with no timing of their own. A
*round* is the controller reading its inputs, running the logic once and writing its
outputs. Three were taken against the recommendation, 108, 109 and 110; 111 and 112 the
maintainer asked outside the questions the design put, as the conventional family does
them; 113–117 as recommended. Decisions 118–121 are the record's own routine choices, taken
the same day where the answers left a choice open, each with the alternative it passes
over.

108. **How often rounds happen (Milestone 4).** The conveyor's logic is due every 10 ms
     and the fan's twice a second, but the box counter and its lamp should respond
     quickly.
     - A steady beat of the controller's own, every 10 ms unless the programmer picks
       another, each timed job done when it is due: a box counted, and the lamp lit,
       within about 10 ms whatever else the plant has, at about 2% of one core;
     - a round only when a timed job is due: here still every 10 ms, for the conveyor, but
       a plant with only the fan would check boxes twice a second, and one with no timed
       job would need a beat set, as MatIEC insists;
     - or rounds flat out, one after another, as IEC's rule 4 and the conventional
       continuous task: the fastest response, and one core kept busy.

     *Recommended: the steady beat.* **Taken: rounds back to back, with a share kept for
     the controller's own work.** The box counter and the lamp run again as soon as their
     round ends, IEC's *"shall be re-scheduled for execution as soon as its execution
     terminates"* (Ed 2 §2.7.2 rule 4, p.115; Ed 3 §6.8.2 d)), as the conventional
     continuous task does: *"The continuous task runs all the time. When the continuous
     task completes a full scan, it restarts immediately"* (the tasks, programs and
     routines manual, p.8). The runner's own work, the host's calls, the care of its
     devices, an edit's steps and the subscribers, is kept a share of the time, 20%
     unless set, one setting for the controller (decision 121), as the conventional
     system overhead time slice is: *"the percentage of time (excluding the time for
     periodic or event tasks) that the controller devotes to unscheduled communication"*,
     and *"The controller performs unscheduled communication for up to 1 ms at a time and
     then resumes the continuous task"* (p.13), at 20% four milliseconds of the continuous
     task to one of the rest (p.32), and back to the continuous task at once when nothing
     waits, its default (p.33). The conveyor's
     and the fan's tasks run between rounds when due, never inside one, since logex never
     preempts (§4.6). The cost, recorded: a long untimed round delays a due timed task, by
     up to the round's length, and a delay of a whole interval or more is reported as an
     overlap. While untimed programs exist, one core is kept busy. A configuration with no
     untimed program makes a round only when a timed task is due or an event's trigger
     changes (decision 112), and there the share has no effect, as the conventional one
     has none *"if there is no continuous task"* (p.31). So a round is one `cycle/3`, its
     due timed tasks and then the untimed programs once each, and rounds come back to
     back; §4.6's row for rule 4 is annotated. *(Taken 2026-10-17. Amended 2026-10-18,
     after M4-1's review, by decision 122: rounds back to back are one a clock millisecond
     at most, so that they are defined on the manual clock, the share is served in slots
     whose formula covers 10% to 90% and is a share of the continuous task's time and the
     runner's own, the timed tasks' runs left out, and the conveyor's and the fan's tasks
     run "at the start of the next round when due, never preempting one" where this
     decision says "between rounds when due, never inside one"; one core is kept busy
     only where rounds fill their milliseconds.)*
109. **The watchdog's default time (Milestone 4).** If the computer gets too busy, or
     something gets stuck, the controller stops itself with everything switched off: the
     watchdog. On the test computer the longest the controller went without updating its
     outputs was 20 ms when it was otherwise idle, a tenth of a second beside one heavy
     job, and about seven tenths beside two.
     - No default: whoever sets up the controller writes down a time, or "no watchdog",
       and it will not start without one;
     - half a second unless set, which on a very busy computer could still stop the plant
       now and then;
     - a tenth of a second unless set, which on a busy computer may stop the plant now and
       then for no fault of the program;
     - or no watchdog unless set.

     *Recommended: no default.* **Taken: half a second unless set, as the conventional
     family's**: *"A watchdog time can range from 1…2,000,000 ms (2000 seconds). The
     default is 500 ms."* (the tasks, programs and routines manual, p.34). It is set on
     each task's line (decision 110), the continuous task's on its own (decision 111), a
     whole number of milliseconds from 1 to 2147483647, an interval's range, since logex's
     milliseconds are a dint's where the conventional range stops at 2,000,000. There is
     no "no watchdog": every task has one, as every conventional task has. *(Taken
     2026-10-17.)*
110. **One watchdog for each task (Milestone 4).** The conveyor's outputs matter within a
     twentieth of a second; the fan could wait two seconds.
     - One time for the whole controller, set where the controller is started;
     - a time for each task, written in the configuration file next to it: "the
       conveyor's task must be done within 50 milliseconds, the fan's within 2 seconds",
       `task fast interval 10 priority 1 watchdog 50`;
     - or both.

     *Recommended: one for the controller, since a cycle writes every output together.*
     **Taken: one for each task, as the conventional family's**: *"Each task contains a
     watchdog timer that specifies how long a task can run before triggering a major
     fault"*, and *"The watchdog timer begins to run when the task is initiated and stops
     when all the programs within the task have run … (The time includes interruptions by
     other tasks.)"* (p.34). In logex a timed task's run is timed from the start of its
     first instance's scan to the end of its last, on the runner's clock, which counts
     whatever time the machine took from the runner meanwhile, as the conventional count
     includes what interrupts the task; its wait for the round in progress, decision 108's
     cost, is not in it, the run being timed from its start. An event task's line takes
     one, as a periodic task's does. A task that outlasts its watchdog trips the
     controller (decision 113) before its round's outputs reach the plant, and the trip
     names the task. `watchdog` owes its `docs/naming.md` stanza before its code; IEC has
     none (§3), so it is a vendor's word, by naming rule 2. A watchdog's rule across an
     online edit, whether one may change while the plant runs as an interval may (decision
     19), is M4-2's to settle with that survey. *(Taken 2026-10-17. Settled with M4-2 on
     2026-10-18 by decision 129: it may, and a switch reports it.)*
111. **The continuous task (Milestone 4).** The box counter and the lamp have no timing of
     their own, and their programmer wants them watched more closely than half a second.
     Asked by the maintainer, as the conventional family has it: the configuration may
     declare its one continuous task as a task line of its own, `task main continuous
     watchdog 200`, and without the line the continuous task's watchdog is 500 ms
     (decision 109). The conventional defaults are taken: one continuous task at most,
     *"If used, there can be only one continuous task"* (p.8); no interval, single or
     priority on it, *"You do not assign a priority to the continuous task. It always runs
     at the lowest priority"* (p.13); the share controller-wide, never on its line
     (decision 108); and a program with no timed task runs in it with no `with`, IEC's
     program with no task association.

     **Taken,** with three choices the record settles, each with the alternative it passes
     over:
     - *A `with` that names it* is taken, `program boxes counter with main`, and means
       what no `with` means: it is the conventional programmer's way of putting a program
       in the continuous task, and IEC's rule-4 program either way. The configuration
       keeps what was written, so its text prints back as it was read, and an online edit
       that adds `with main` or takes it away moves no instance to another task (decision
       19). Refusing it, so that a program has one spelling, would turn a conventional
       line away for no change in what runs.
     - *Its name in events.* Where the line declares it, every instance it runs is
       reported under its name, `{:ran, "main", "boxes", now}`, with `with main` or none,
       and a trip of its watchdog names it; where none is declared, `:none`, as now, so no
       configuration that runs today reports otherwise. Keeping `:none` everywhere would
       give one task two names.
     - *Its watchdog, per round.* Each round is timed from its start, when it takes its
       inputs, to the end of the continuous task's last program's scan, the timed tasks
       run in that round included, as the conventional continuous task's watchdog
       restarts with each full scan (p.8) and counts the tasks that interrupt it (p.34).
       So, where untimed programs exist, it bounds the whole round, from the inputs taken
       to the outputs computed. Timing its programs alone would leave a round that grows
       with the timed tasks in it unwatched as a whole.

     A continuous line that runs no instance is the warning a task that runs no instance
     is (M2-3), its watchdog then timing nothing; adding or removing the line while the
     plant runs is adding or removing a task, refused while running (decision 19).
     `continuous` owes its stanza before its code: IEC names no such task, so it is the
     conventional family's word, by naming rule 2. *(Taken 2026-10-17. After M4-1's
     review, 2026-10-18: a round's trip names each of its steps with its time, so that a
     timed task's slow run in it is seen where the round's watchdog counts it (decision
     126); and a continuous line that runs no instance still sets the deadline the runner's
     refreshes carry while it serves its own work or waits (decision 125), so its watchdog
     times no round but bounds the runner's time between them.)* *(Landed with M4-2,
     2026-10-18, in the configuration and the core: the line, one at most, no interval,
     single or priority, `with main` meaning no `with`, its runs reported under its name,
     and its line added or removed refused while running; decision 129 adds that a task
     made continuous or timed is refused too, and that `with main` added or taken away
     moves nothing.)*
112. **Plants of event tasks alone, and devices that report changes (Milestone 4).** A
     plant of the fan's half-second task and the e-stop's event task, with no untimed
     program: between the fan's runs the controller has nothing to do until the e-stop
     changes. Asked by the maintainer, as the conventional family does it:
     - a device may tell the runner when an input changes, and an event task whose trigger
       changed then runs at once, between rounds and never inside one, as the conventional
       change-of-state trigger runs an event task when an input module reports a point
       turning on or off (*"Module Input Data State Change"*, the tasks, programs and
       routines manual, pp.37–42);
     - a device that cannot report changes is read by the runner at a steady rate, its
       poll period, 10 ms unless set, as the conventional input module sends its data at
       its requested packet interval (p.42).

     **Taken.** So `Logex.IO` gains an optional `report/2` (§4.11), and `Logex.IO.Sim`
     reports its changes where it is started to, so that a test drives it on the manual
     clock. A change of a trigger is a rise or a fall, and each makes a round, so that the
     resource samples the 0 between two rises and the second is an edge (decision 39's
     sample). How reading and reporting mix in one plant is decision 120. *(Taken
     2026-10-17. "At once, between rounds and never inside one" reads, after M4-1's
     review, at once where no round is running, and otherwise at the start of the next
     round, never preempting one (decision 122); a trigger logic writes rounds at the next
     clock millisecond (decision 123), and a device passes its changes on by a call
     (decision 124).)*
113. **What a watchdog trip does (Milestone 4),** decision 14 asked again now that the
     details are known.
     - Everything goes off, once: the conveyor stops, the fan stops, the lamp goes out and
       the drive's speed setting goes to zero; the controller then does nothing until
       someone restarts it, and the last count and the last state of every signal can
       still be read, to see what happened; the cost, the fan stops too, though it was
       meant to run on;
     - or everything stays as it was, the conveyor running at its speed and the lamp lit,
       with no logic in control, until someone notices and restarts.

     *Recommend the first.* **Adopted, confirming decision 14**: every output written 0
     once, through each device that answers, scheduling stopped, the trip reported, an
     explicit restart required, and the last state readable through `get/2`. Off is the
     safe state of a plant wired to de-energise to trip, and holding leaves machines
     running with nothing watching them; OpenPLC v3 zeroes every output when its runtime
     stops (`disableOutputs(); updateBuffersOut();`, `main.cpp` and `utils.cpp` at
     `b5d4135`), and IEC asks the system to *"initiate appropriate system- or
     user-defined error handling procedures"* (Ed 2 §1.5.1 d) 4)), of which this is one.
     Five refinements, as the design gave them: "once" is through each device's write, so
     a hung device is left to its own state on losing its master; the resource is not
     zeroed, so `get/2` reads the last round computed, outputs the plant never received
     among them where the round tripped before its write, which `status/1` and README
     say; one path serves a trip, a device fault, a stop and the runner's death; a
     restart is cold or warm, never a resume, the clock not counting the stopped time;
     and no output has a fault value of its own, a fan that should keep running being a
     later item if a plant needs one. *(Taken 2026-10-17.)* *(Amended 2026-10-21 by
     decisions 153 and 160: an index or a tag bit number out of range is a major fault,
     and the runner trips on a round's first one before it writes the round's outputs, on
     this decision's one path, with a new reason, `{:fault, task, instance, fault}`, which
     names the instance, the file, the line and the index or bit number; §4.11's list of
     reasons, and the runner walk's "every trip reason", gain it with `PLAN.md`'s M5-9.)*
     *(Settled 2026-10-21, the maintainer answering §4.12's tenth question as recorded:
     the runner trips at the end of the step that raised the round's first major fault,
     no later step of the round running, decision 153's note.)*
114. **A device that fails or is lost (Milestone 4).** The drive's network cable comes
     loose, or an input card stops answering.
     - It is treated as the watchdog is: everything off, and wait for a restart;
     - the controller carries on with the last values it read from that card for a short
       grace time, a second say, then stops as in the first if the card is still silent:
       a blip on the network does not stop the line, but during that second a press of
       stop on that card is not seen;
     - or it carries on with the last values for as long as it takes, and reports the
       problem.

     *Recommend the first.* **Adopted**: the controller cannot know whether someone
     pressed stop, or the e-stop, on the card it can no longer hear, so it does not go on
     driving the conveyor from what it last saw. An error returned, a raise, a throw or an
     exit in an adapter, a value that does not fit its point, an address that is no
     point's, no answer within the device's deadline and its process going down are each
     an I/O fault, `{:io, device, cause}`, through decision 113's path. A grace time stays
     a later option, for a plant on a flaky network. *(Taken 2026-10-17. Built with M4-4;
     since its review a device that hangs inside its own read or report, which no request
     of the runner's reaches while its outputs do not change, is seen by its telling the
     runner after each read and report that it is back from its adapter, the bound the
     idle watchdog and a poll period, decision 134. Since M4-6, whose walk found it, a
     change the runner refuses, a value that does not fit or an address that is no input
     point's, is not taken by the device either, so that its next read passes it on again:
     a card that goes on giving a bad value trips the runner again after each restart,
     where until then it tripped it once and the runner ran on with the last value it had
     taken, and a good change refused beside a bad one is read at the first read after the
     restart. Whether a restart should read every device before its first round was put
     to the maintainer, `PLAN.md` M4-6, who answered that it should, decision 142: since
     then a card still giving a bad value leaves each restart refused with its fault, the
     runner tripped and nothing switched on, and the restart's own read takes the good
     change, so the device's not taking a refused change no longer shows in any run. And
     a change refused for one bad point keeps its other good points, passed on with the
     device's next reading (since M4-6's eighth verification, which the maintainer
     confirmed on 2026-10-20, decision 143).)*
115. **After a crash (Milestone 4).** The controller software itself crashes; whichever is
     chosen, every output goes off on the way down.
     - It stays stopped until someone starts it again, as after the watchdog;
     - it starts again by itself straight away, from the beginning: the conveyor stays off
       until someone presses start, but anything switched straight from a held switch,
       a fan wired to a "fan on" switch, comes straight back on;
     - or it starts again by itself, but waits with everything off until someone presses
       restart on a screen.

     *Recommend the first.* **Adopted**: `Logex.Runner`'s child spec is `restart:
     :temporary`, so its supervisor does not start it again, and each device, trapping the
     runner's exit, zeroes its outputs and closes. It is a trip's rule: nothing starts
     again that no person asked to start. A host that wants a restart by itself may say so
     in its own child spec, knowing that a cold start runs the program from its initial
     values. *(Taken 2026-10-17.)*
116. **A normal shutdown (Milestone 4).** Someone shuts the controller down normally, for
     maintenance.
     - Everything is switched off first, then it shuts down: the conveyor stops and the
       lamp goes out;
     - or the outputs are left as they were, the cards keeping whatever they were last
       told or doing what they do when they lose contact.

     *Recommend the first.* **Adopted**: `stop/2` writes 0 to every output once and
     closes every device before it returns, as OpenPLC v3's runtime does, so a controller
     that has shut down leaves no conveyor running behind it. The spike first left the
     zeroing to the devices' own exit, and its `stop` returned while the panel still held
     its contactor on. *(Taken 2026-10-17.)*
117. **Forcing a signal for testing (Milestone 4).** A technician wants to check the "case
     full" lamp without loading 12 boxes, so they make the controller see the photo-eye
     as blocked and unblocked from a laptop, whatever the real eye says. Forcing an
     output, telling the lamp to light whatever the program says, is the other kind.
     - Forcing of inputs now: a forced input stays forced until it is taken off, even
       across a restart, and the controller's status always lists what is forced; forcing
       of outputs later, with the rest of forcing;
     - forcing of inputs and outputs together, later;
     - or no forcing at all, testing using a simulated card instead of the real one.

     *Recommend the first.* **Adopted**: forcing an input only changes what the controller
     reads, which the runner already supplies, merged over the device's values after the
     input latch, as §5 places forcing, so it comes now and is not redone later.
     `unforce/2` puts back the device's last value, which the runner keeps for each input
     point; a force of a trigger is a change of it (decision 120); an output point, or a
     value that does not fit, is the host's mistake. Output forcing waits for §5's forcing
     in `cycle/3`. *(Taken 2026-10-17. Extended on 2026-10-18 by the maintainer's answer,
     decision 127: forces are kept in a file the host names, so that a forced input comes
     back forced after a crash and a fresh start, not only after a restart.)*
118. **How a task's run is timed (Milestone 4),** following decision 110. One round runs
     the conveyor's task, the fan's and the box counter, and the runner must tell how long
     each took.
     - The cycle in steps: `cycle/3` cut where each task's run ends, the steps internal to
       `Logex.Runtime` as `edited/2` is, so that the runner reads its clock at the
       boundary of each step; the steps composed are `cycle/3` exactly, which a test pins,
       and the host contract does not change;
     - or the whole cycle timed, and checked against the least watchdog of the tasks that
       ran in it.

     *Taken: the steps.* The second would trip the conveyor's 50 ms watchdog for a round
     whose time went on the box counter, naming a task that was not slow. The core still
     reads no clock: a step is a pure function of the resource, and only the runner times
     it. *(Taken 2026-10-17. M4-1's review found decision 111's watchdog for each round
     doing what this argument rejects, tripping `main` for a round whose time went on a
     slow timed task in it; decision 126 reconciles the two on 2026-10-18, the round's
     trip naming each step with its time, the steps being this decision's.)*
119. **How the watchdogs fit the outputs' refresh and each device's heartbeat (Milestone
     4),** following decisions 110 and 111. The runner is stuck, by a bug or a machine
     that has stopped giving it time, while the conveyor runs: its contactor must still go
     off.
     - The runner's own check, after each step against its task's watchdog and before the
       round's outputs are written, in place of the design's one gap between two writes;
       and a heartbeat in each device, which hears from the runner at least once a poll
       period, between rounds, between two steps of a round and while the runner waits,
       its refresh the outputs the device last had where nothing changed: a device that
       hears nothing for its heartbeat time, the longest watchdog of any task the
       configuration runs plus one poll period, writes 0 to every output once, latches and
       tells the runner, which trips when it next runs, `{:watchdog, {:device, device,
       time}}`;
     - or the heartbeat at the sum of every task's watchdog, with no refresh between two
       steps;
     - or the design's gap check between two writes kept beside the watchdogs, at a time
       of its own.

     *Taken: the first.* No step may outlast the longest watchdog without tripping the
     runner, and the runner looks for a refresh due only between steps, so a runner that
     is well never misses a heartbeat, and one stuck anywhere, in a round, a request or a
     bug, leaves every device that answers at 0 within that time. A device whose adapter
     gives no answer within the same time is a fault (decision 114), so a device is given
     as long to answer as the runner is to refresh it. The costs: the plant's longest
     watchdog sets every device's heartbeat, so a fan task given two seconds leaves the
     conveyor's contactor on for up to two seconds and a poll period when the runner is
     stuck, though the conveyor's own watchdog still trips at 50 ms whenever the runner
     runs; and a request the runner serves whole between rounds that takes longer than the
     heartbeat time trips the plant, so accept's work, which grows with the programs, is
     done in the caller's process. The sum is slower to zero, and a gap check of its own
     is a second time for one rule. *(Taken 2026-10-17. Superseded on 2026-10-18, after
     M4-1's review, by decision 125, in its rule and its cost: every device is refreshed
     before every step, each refresh carrying that step's own deadline, its watchdog plus a
     poll period, so the margin is a poll period and a stuck conveyor's step zeroes every
     device at its own 50 ms, not at the plant's longest watchdog. Its first refinement
     stands: a device is given as long to answer as its deadline.)*
120. **How reading and reporting mix in one plant (Milestone 4),** following decision 112.
     The panel's card reports each button as it changes; the drive's cannot report.
     - Every device is read every poll period, and one that reports passes each change on
       as it comes, between reads, as the conventional input module sends its data at its
       packet interval and on a change of state: *"You must specify an RPI regardless of
       whether you enable COS. If a change does not occur within the RPI, the module sends
       its data at the RPI"* (the tasks, programs and routines manual, p.42);
     - or a device that reports is never read, only one that cannot being read.

     *Taken: the first.* A report shortens the wait for a change, and the steady read puts
     right a report that was lost and shows that the device still answers, so an input
     card that stops answering is a fault (decision 114) whether or not it reports. Each
     device's process does its own reading and takes its own reports, and sends the
     runner what changed; the runner merges every device's changes into the next round's
     inputs as the round starts, so every round sees one sample of every device, and a
     change to any other input is merged to its latest value. A change of a trigger is
     kept as itself: each makes a round of its own, in the order it came, so a press and
     release of the e-stop between two rounds still runs its event task once, IEC's
     *"upon each rising edge of the SINGLE input"* (Ed 2 §2.7.2 rule 1); and a trigger
     that logic writes is read after each round, a change of it making a round at once,
     the next cycle the runner makes of `Logex.Runtime`'s rule 1. A pulse shorter than the
     poll period on a device that cannot report is not seen; the conventional manual's
     nearest warning is of an overlap, for an input under change of state shorter than its
     task's scan: *"Make sure the duration of the input is longer than the scan time of
     the task. Otherwise an overlap could occur"* (p.46). One poll period serves the
     plant, a runner option (decision 121); one for each device, as the conventional
     packet interval is each module's, is later, if a plant needs it. *(Taken
     2026-10-17. Amended 2026-10-18, after M4-1's review: a change of a trigger that logic
     writes makes its round at the next clock millisecond, not at once (decision 123); and
     a device passes what changed on by a call, answered once the change is merged or its
     round has run, not by a message (decision 124). Corrected the same day: its
     paraphrase of p.46 said the conventional manual warns of an input shorter than its
     task's scan going unseen, where p.46 warns of an overlap, and it now quotes it.)*
121. **Where the share and the poll period are set (Milestone 4).** The plant runs on one
     machine in the lab and on another on the line.
     - Options of the runner, in Elixir, where its devices are bound: `overhead:`, the
       share in percent, 20 unless set, 10 to 90, the span of the conventional table
       (p.32), and `poll:`, in milliseconds, 10 unless set;
     - or lines of the configuration file, each a new word with its survey.

     *Taken: the runner's options.* Each says how this machine and its devices run the
     plant, not what the plant does: a configuration's text is the plant's logic and its
     schedule, and replays exactly on any machine, as §4.5 keeps a device's address and
     options in Elixir. A task's watchdog is on its line (decision 110), since it is the
     task's own. The conventional share's own range is **unverified** beyond its table.
     *(Taken 2026-10-17.)*

**After M4-1's review, decided 2026-10-18.** The review of M4-1's landing found the
record silent on four things the runner must do the same way on either clock, and loose
on others. Decisions 122–124 are the record's own routine choices on what it left open,
and 125 and 126 on a heartbeat with a millisecond of margin and a round's trip that names
a task that was not slow, each with the alternative it passes over, the plant the
design's: the conveyor's logic
due every 10 ms, the fan's twice a second, the e-stop's event task, and the box counter
and the "case full" lamp with no timing of their own.

122. **How rounds run back to back on a clock, and the share's slots (Milestone 4),**
     following decision 108. The box counter and the lamp run round after round. On the
     test's clock, which moves only when the test moves it, a round takes no time at all:
     "start the next round as soon as the last ends" runs rounds without end while the
     clock stands still, and "after each 4 ms of rounds, up to 1 ms for the runner's own
     work" counts time that never passes. On that clock a receiver that set its next
     round for the time it was at took 49,989 deliveries in a second without the clock
     moving, and rounds set for themselves after one `advance/2` came out 19,772, 2,658
     and 2,658 in three fresh runs.
     - Each back-to-back round a wake on the runner's clock at the millisecond after the
       one the round before began in, or at once where that round took a millisecond or
       more: at most one round a clock millisecond, on the monotonic clock and the manual
       one alike, `advance(clock, n)` running n;
     - rounds flat out on the monotonic clock, and one a millisecond on the manual one,
       which would test a rule the runner does not run;
     - or a round each poll period, the steady beat decision 108 passed over.

     *Taken: the first.* A round's time is whole milliseconds, its `elapsed_ms` too, so a
     second round inside one millisecond runs the logic again on the same time and the
     same inputs but for a device's change, and a change of a trigger already makes a
     round of its own (decisions 112, 120 and 124). IEC's rule 4 and the conventional
     continuous task are kept to the clock's resolution: a round that fills its
     millisecond is followed at once, one that does not by the next millisecond. So the
     cost decision 108 recorded, one core kept busy, becomes up to one core: rounds of
     0.2 ms keep a fifth of one, and only rounds that fill their milliseconds keep one
     busy. A run on the manual clock repeats exactly, the rounds an advance runs being the
     milliseconds it moves on. The share is a share of the time the runner spends on the
     continuous task's programs and on its own work while both have work, the timed
     tasks' runs left out of both, as the conventional rule leaves out *"the time for
     periodic or event tasks"* (p.13), and it is served in slots: after C ms of the
     continuous task's rounds, up to S ms of the runner's own work, C = max(1, round((100
     − p)/p)) and S = max(1, round(p/(100 − p))) for a share of p percent, 10% giving 9
     and 1, 20% 4 and 1, 25% 3 and 1, 33% 2 and 1, 50% 1 and 1, 66% 1 and 2, 75% 1 and 3,
     80% 1 and 4 and 90% 1 and 9, the conventional table, *"ContinuousTime=(100/
     SystemOverheadTimeSlice%) - 1"*, the continuous task given *"at least 1 ms of
     execution time"* (the design considerations reference, p.35). A round counts from
     its start to the next round's, so a millisecond at least (read, after M4-3's review,
     as from its start to its end, a millisecond at least: the runner's own work that runs
     past a millisecond is not the round's, §4.11's landing note), and a request is served
     whole, so a slot can run over by one request; with nothing of its own to serve the
     runner goes back to rounds at once (p.33), and in the rest of a millisecond a round
     did not fill it serves its own work freely, time no round wants. On the manual clock
     a round fills no time unless something passes time inside it, so own work waiting is
     served before the next round. And "between rounds" is said plainly: a due timed task
     runs at the start of the next round, never preempting one (§4.6), the first steps of
     that round. *(Taken 2026-10-18, after M4-1's review. After M4-3's review the same
     day: a slot comes at the end of the round that completes its C ms, so that on the
     manual clock it comes in the advance that runs that round, decision 131.)*
123. **A trigger that logic writes (Milestone 4),** following decisions 50 and 120. A
     plant of two event tasks and no untimed program, each task's program setting the
     other's trigger and clearing its own: each round changes a trigger, and under
     decision 120, a change logic writes making a round at once, the runner would round
     for ever without waiting, every cycle at an elapsed 0 and `next_due_in/1`
     `:infinity`, and serve no host's call, no edit and no stop: the livelock in zero
     time decision 50 named and left to the runner.
     - A change of a trigger that logic writes makes its round at the next clock
       millisecond, a wake as a back-to-back round is (decision 122), not at once; one a
       device reports, or a force, still makes its round at once;
     - at once, with the share applied to event rounds, which has no effect where no
       untimed program exists (decision 108) and would be a second rule for one hazard;
     - or at once, the configuration's author trusted not to write such a pair.

     *Taken: the first.* Such rounds then come one a clock millisecond at most, the runner
     serving its mailbox between them, so the two tasks toggle once a millisecond and a
     host's call is served; on the manual clock `advance(clock, n)` runs n of them. IEC's
     rule 1 runs an event task *"upon each rising edge of the SINGLE input"* (Ed 2 §2.7.2),
     sampled when the resource next evaluates it, which logex's resource does at each
     cycle, so the round a millisecond on is the next cycle the runner makes, as decision
     120 and `Logex.Runtime`'s rule 1 have it. The cost: a millisecond more for an event
     task whose trigger logic sets. A device's change and a force come from outside and
     stay at once, one round each, as many as there are changes. Decision 50's hazard is
     closed. *(Taken 2026-10-18, after M4-1's review.)*
124. **How a device passes on what changed, and where a test waits (Milestone 4),**
     following decision 120. A test presses the e-stop on the simulated panel, and the
     e-stop's event task must run at once: the test must know when that round has run
     before it looks at the outputs. `Logex.IO.Sim.set/3` returns once the panel's device
     process has handled the report, but under decision 120 the device then sent the
     runner a message, which the runner took in its own time, so the test had nothing to
     wait on: in a model, a loop of 200 sets, each followed by a read of the outputs,
     found 33 of the 200 rounds run when it ended.
     - The device passes each change on by a call to the runner, which answers once it has
       merged the change into the next round's inputs and, for a change of an event
       task's trigger, once the round it makes has run and its outputs are written; while
       it waits the device answers the runner's own requests to it, a write, a refresh or
       a zeroing, so that neither waits on the other, and its wait is bounded by the
       deadline its last refresh carried (decision 125). So `set/3` returns once the runner
       has taken the change and run the round it causes, by construction, as `advance/2`
       returns once each receiver has handled its message;
     - a message, as decided, and `settle/1`, a call of the runner's a test makes after a
       set, answered once each device has passed on what it had, by a marker each device
       sends after it, one sender to one receiver;
     - or a message, and the test waits for the round's event.

     *Taken: the first.* It defines a real run's order as well as a test's: a device's
     changes reach the runner one at a time, in the order the device saw them, each taken
     before the next is passed on, so each change of a trigger is its own round by
     construction (decision 120), and a burst of reports waits in the device's mailbox
     rather than the runner's. `settle/1` would be a call only tests make, and would leave
     a real run's order between a device's changes and the runner's rounds to two
     mailboxes; an event comes only for a change that makes a round. The cost: a device
     that reports is held while the runner takes each change, a round at most, so a
     flood of changes is taken at the pace the runner can use them. *(Taken 2026-10-18,
     after M4-1's review.)*
125. **The heartbeat: a deadline each refresh carries (Milestone 4),** following decision
     119, which it supersedes in its rule and its cost. The runner is stuck while the
     conveyor's task runs, and the conveyor's contactor must go off. Under decision 119 a
     device's heartbeat was the plant's longest watchdog plus a poll period, refreshed
     only when a refresh was due and only between steps: in a model, a step that took
     exactly its watchdog, starting 9 ms after the last refresh, left 1 ms before the
     device latched; and a runner stuck in the conveyor's 50 ms task kept the contactor on
     for the fan's 2 s and a poll period.
     - Every device refreshed before every step, the refresh carrying that step's own
       deadline, its task's watchdog plus one poll period from the step's start; and
       before the runner serves its own work, writes a round's outputs or waits, the
       continuous task's watchdog plus one poll period, the continuous task being the one
       whose share that time is (decision 122), refreshed again at least once a poll
       period while it waits; a device that hears nothing by the deadline its last refresh
       carried writes 0 to every output once, latches and tells the runner;
     - a heartbeat for each device from the watchdogs of the tasks that drive its points,
       the panel's from the conveyor's 50 ms and the drive's from the fan's 2 s;
     - or decision 119 as taken.

     *Taken: the first.* A runner stuck in the conveyor's step leaves every device that
     answers at 0 within 50 ms and a poll period of the step's start, in the fan's step
     within 2 s and a poll period, and in its own work or a wait within the continuous
     task's watchdog, 500 ms unless its line sets one (decision 111), and a poll period. A
     runner that is well never misses a deadline: each step ends within its watchdog or
     trips, the next refresh comes before the next step, and the poll period is the
     margin, never less. A heartbeat for each device fails because logex never preempts:
     while the fan's task runs, for up to its 2 s, no refresh reaches the panel either, so
     a panel deadline of 50 ms and a poll period would latch it under a fan run that is
     well; the deadline must cover whatever step the runner is in, so it is that step's,
     carried to every device. The costs: a refresh, a message to each device, before every
     step, so a round of three steps and two devices sends six, at one round a millisecond
     at most, which M4-3 measures; a stuck fan's step still holds the conveyor's contactor
     for the fan's 2 s, since no step can run while another does, and the conveyor's
     watchdog does not count its wait (decision 110); and a request the runner serves
     whole that takes longer than the continuous task's watchdog and a poll period trips
     the plant, so accept's work stays in the caller's process (decision 119). Decision
     119's cost, the plant's longest watchdog setting every device's heartbeat whatever
     step the runner is in, is gone. *(Taken 2026-10-18, after M4-1's review. Its bound
     between steps, the continuous task's watchdog, was replaced the same day by the
     runner's own idle watchdog, decision 128. The outputs decision 119 has a refresh
     carry are, since M4-3's review, written again by each device at its poll, at most
     once a poll period, decision 130.)*
126. **What a round's watchdog trip names (Milestone 4),** following decisions 111 and 118.
     One round runs the conveyor's task, the fan's and the box counter; the fan's run
     takes 300 ms, well within its own 2 s, and the round outlasts the continuous task's
     200 ms watchdog. Decision 118 passed over timing the whole cycle against the least
     watchdog because it would trip naming a task that was not slow, and decision 111's
     watchdog for each round trips for the fan's time just so, naming `main`.
     - The trip names the round's steps, `{:watchdog, {:round, task, took_ms, limit_ms,
       steps}}`, `task` the continuous task's name or `:none` and `steps` each step the
       round ran, in the order run, `{task, ms}`, the timed tasks' runs and the continuous
       task's programs under its own name, so that the slow one is seen;
     - the trip names the continuous task alone, as decided, decision 111 owning that its
       count includes the timed tasks', as the conventional one includes *"interruptions
       by other tasks"* (p.34);
     - or the timed tasks' runs left out of the round's time, which leaves a round that
       grows with them unwatched, decision 111's own reason against it.

     *Taken: the first.* The continuous task's watchdog still counts the timed tasks' runs
     in its round, as the conventional one does, so it trips where a round as a whole runs
     too long; and the trip says where the time went, what decision 118 asked of a
     watchdog, while a timed task's own trip, `{:watchdog, {:task, task, took_ms,
     limit_ms}}`, names the task that was slow. The steps cost nothing new: the runner
     times each step already (decision 118). *(Taken 2026-10-18, after M4-1's review.)*

**The maintainer's answer on forces, 2026-10-18.** Given after M4-1's review, outside any
question put, as decisions 111 and 112 were.

127. **Forces after a crash (Milestone 4),** following decisions 115 and 117. The
     technician has forced the photo-eye "blocked" to check the "case full" lamp, and the
     controller software crashes. Decision 115 keeps it down until someone starts it
     again, and decision 117 keeps a force across a restart; but a restart is the same
     runner's, and after a crash the host starts a new one, whose forces would be none, so
     the photo-eye would come back reading the real eye. **Answered by the maintainer:
     forces survive a crash, kept in a file, as the conventional family does.** A forced
     input is kept outside the controller, so after a crash and a fresh start it comes
     back still forced, and the status lists it. IEC 61131-3 says nothing of forcing:
     "forc" occurs in the extracted text of neither edition. That the conventional family
     keeps forces in the project through a power cycle, with a "forces on" indicator, is
     the maintainer's account and **unverified**: of the conventional manuals saved for
     this record, the design considerations reference lists *"I/O force tables"* among a
     controller's I/O memory (p.31), and neither it nor the tasks, programs and routines
     manual says what a power cycle does to them or names an indicator. *(Checked
     2026-10-20: the indicator and where forces are kept are **verified**, a power cycle
     **not found**. The I/O and tag data manual: *"FORCE Status Indicator ... Flashing: At
     least one tag contains a force value. I/O forces are inactive (disabled). Solid: I/O
     forces are active (enabled)"*, and of a force "Installed", *"At least one force of
     this type exists in the project"* (1756-PM004L, Nov 2023, p.52); *"I/O forces are held by the
     controller and not by the programming workstation. Forces remain even if the
     programming workstation is disconnected"* (p.53). None of the manuals saved says what
     a power cycle does to them.)*

     **Taken,** with the record's choices on how, each with the alternative it passes
     over:
     - *Who names the file:* the host, `forces:` a path, an option of `start_link/1`, as
       `poll:` and `overhead:` are the runner's (decision 121): where a machine keeps its
       state is the machine's, not the plant's logic, and logex writes no file it is not
       told to. A runner started without one takes no force, `force/3` then the host's
       mistake, "the runner keeps no forces file, so a force would not survive a crash:
       start it with forces: a path", so that every force there is survives a crash, as
       the answer says. Forces held in memory alone where no file is named, decision 117
       as taken, would let a force vanish with a crash, the case the answer rules out.
     - *How it is written:* on each force and each unforce, before the call returns, the
       whole set written to a file beside it, flushed to the disk, and renamed over it,
       so that a crash at any moment leaves the old set or the new, never part of one,
       rename being atomic within one file system. A write that fails changes nothing,
       the force not taken or not taken off, and the call returns `{:error, {:forces,
       reason}}`, the plant's state, as a full disk is, not a host mistake. Its format is
       M4-5's to settle: text a person can read, one force a line, written by the runner
       alone. Writing at a stop alone would lose every force a crash came before.
     - *When it is read:* at every start, `start_link/1` reading it in the caller before
       anything starts, and `restart/2`, so that the file is what is forced at each start;
       a file that does not exist is no force. A restart reads what the runner last wrote,
       so it keeps the forces it had, as decision 117 keeps them.
     - *A force the configuration cannot take,* on a point it no longer has, on one that
       is an output, or of a value that does not fit its point, and a file that cannot be
       read: refused at start as the host's mistake, every such force named in one
       `ArgumentError`, the runner not started; at `restart/2` the same refusal is raised
       in the caller and the runner stays tripped. Reported and dropped, the alternative,
       would take off a force a technician set, with no one at the plant told but a
       subscriber, the input going from the forced value to the real one at a start
       nobody watched. The configuration a file was written for is not recorded in it:
       a point is a force's by its name.
     - *Clearing every force:* `unforce_all/1`, which takes every force off, each input
       back to its device's last value, and writes the file empty; with no runner, the
       host deletes the file, a file that does not exist being no force.
     - *The status always lists them:* `status/1`'s forces, every one with its value,
       empty when none, from the first round after a start, those read from the file
       among them, so that a display can show "forces on" while any is.

     It is recorded only: forcing is built in its own item, M4-5 (`PLAN.md`). *(Answered
     and taken 2026-10-18. The maintainer confirmed the same day that a runner started
     without `forces:` refuses to force, and that a force the configuration cannot take
     refuses the start, as recorded above. Built with M4-5, 2026-10-19, its format one
     force a line, `name value`, read exactly as written, decision 140.)*

128. **The bound on the runner's own time between steps (Milestone 4),** following
     decision 125, asked after M4-1's review. Between rounds the runner waits, serves a
     screen's request or writes outputs, and no task's step is running, so no task's
     watchdog is the deadline each device's refresh carries then. If the runner freezes
     there while the fan's task waits for its next run, the conveyor's contactor stays on
     until that deadline. A fixed short bound would trip a busy machine for no fault: the
     spike measured wakes up to 692 ms late under load.
     - The continuous task's watchdog plus one poll period, 510 ms by default, as decision
       125 had it;
     - the shortest watchdog of any task, the conveyor's 50 ms, tighter but tripping a
       busy machine more often;
     - or a setting of its own.

     **Taken: a setting of its own,** as the maintainer answered on 2026-10-18. The runner
     takes `idle:`, in milliseconds, 500 unless set, an option of the runner beside
     `poll:` and `overhead:` (decision 121), since how long a machine may keep the runner
     from its own work is the machine's, not the plant's: each device's deadline between
     steps is `idle:` plus one poll period, and a request the runner serves whole that
     takes longer trips the plant, `{:watchdog, {:idle, time}}`. The continuous task's
     watchdog bounds its rounds alone (decision 111). Neither IEC nor the Logix pages
     read cover this. *(Taken 2026-10-18; built with the runner, M4-3 and M4-4. The
     maintainer confirmed the same day decision 122's one round a millisecond at most, on
     the real clock as on the manual one, and M4-4's one hidden start option through which
     a test reaches `{:internal, message}`.)*
129. **A watchdog and the continuous task across an online edit (M4-2),** following
     decisions 19, 40, 62, 110 and 111, which left a watchdog's rule to M4-2 (decision
     110). The conveyor's task runs with a 50 ms watchdog, and its programmer, having
     watched `status/1`'s longest runs, wants 30 ms without stopping the plant; another
     edit gives the box counter's program `with main`, which it ran in already, or moves
     it onto the conveyor's task.
     - A watchdog changed only with a restart, as CODESYS refuses any change to its task
       configuration in an online change (*Command: Online Change*, Table 106);
     - or changed while the plant runs, as an interval and a priority are (decision 19,
       the conventional family's rules), and reported.

     **Taken: changed while running, and reported,** the record's choice, since decision
     19 took the conventional family's rules for a running task and the conventional
     family changes a task's watchdog while the controller runs: logic writes it, the
     task object's `Watchdog` taking SSV (the general instructions reference, Sept 2025,
     TASK object, p.276). A watchdog is configuration the runner reads at each step of a
     round, with no state in the resource, as a priority is read at each cycle's sort
     (decision 62), so a switch writes nothing for it and reports it, `{:watchdog, task,
     {old, new}}`, each in milliseconds and 500 for a line that sets none, so that
     `watchdog 500` written on a line that had none reports nothing; the round after the
     switch is timed against the new one, as the conveyor's next run would be. Its
     forecast is a test's report, as every kind's is. The continuous task's rules follow
     decision 111's and decision 19's, each with what it passes over:
     - *its line added or removed* while the plant runs is adding or removing a task,
       refused at accept in the words of any task's (decision 111), over taking it as
       naming what already ran, which would change the name every event reports;
     - *a task made continuous, or a continuous task made timed,* keeping its name, is
       refused at accept, *"task `main` is continuous in the running configuration and
       periodic in the candidate: a task's kind changes only with a restart"*, as a
       `single` added or removed is (§4.9), since every instance on it would move to or
       from the untimed programs, which decision 19 refuses for one instance;
     - *`with main` added or taken away* moves nothing, as decision 111 says, and reports
       nothing: an instance with no `with` and one `with main` run in one place in one
       order, so accept compares each instance's task as it runs, the continuous task's
       instances and the task-less ones one, and decision 62's order is reported under the
       continuous task's name, or `:none` where none is declared, the two together;
     - *an instance moved between the continuous task and a timed one* is moved to or
       from no task, refused as decision 19 refuses any move, in its words, the continuous
       task named where it is declared, *"with `main`"*, and *"with no task"* where not.

     Neither IEC, which has no watchdog and declares no task for the untimed programs, nor
     the conventional pages read say what an online edit of a continuous task's type or of
     its programs' order does. *(Taken 2026-10-18, with M4-2.)*

     *Note, after M4-2's review the same day:* the continuous task's place among the task
     lines is no order of the tasks. Decision 62 reports the tasks' order because it
     breaks ties of priority and due time (decision 11), and the continuous task is never
     due and takes part in no tie, so `{:order, :tasks, names}` compares the timed tasks
     alone and names them alone: a candidate that only moves the continuous line reports
     nothing, and its test and untest leave the plant as it was. As landed, the line moved
     was reported as a reorder of every task, which `scheduler_test.exs` already said was
     no order of its own.

**The maintainer's answers after M4-3's review, 2026-10-18.** M4-3 put two questions as it
landed; its review recommended an answer to each, and the maintainer answered both the
same day.

130. **Writing each device's outputs again every poll period (Milestone 4),** following
     decisions 119 and 125, asked as M4-3 landed. The conveyor runs for an hour with its
     contactor on and the drive's speed steady. No output changes, so the runner, which
     writes a device only where its outputs changed, writes neither after the first
     round; a drive or a remote I/O card that turns its outputs off when it has heard
     nothing from its master for a while, as many do, stops the conveyor while logex is
     well. Decisions 119 and 125 said a device is refreshed "with the outputs it last
     had", which as landed was not so: a refresh was a message to the device's process,
     carrying its deadline, which called no adapter.
     - Each device writes its outputs again, the values it last wrote, at most once a
       poll period, when nothing was written to it within one: an operator sees the same
       outputs, and a device that watches for its master hears from it at least once a
       poll period, as long as the runner is well;
     - every refresh writes the device again, as decision 119's words read: the same
       outputs, but a write before every step of every round, thousands a second while
       rounds run back to back, each one over the network for a real adapter;
     - or a device written only where its outputs changed, as landed, so a quiet plant
       says nothing to its I/O for as long as it stays quiet, and the host must set each
       device's own timeout longer than the plant ever stays quiet, which may be hours.

     IEC 61131-3 says nothing of how a controller talks to its I/O, and so nothing of a
     repeated write. The conventional family sends a module's data cyclically at its
     requested packet interval, the RPI, whether or not it changed, *"If a change does not
     occur within the RPI, the module sends its data at the RPI"* (the tasks, programs
     and routines manual, p.42, of an input module, decision 120); that a controller's
     outputs go out at the RPI in the same way, and that an output module drops them when
     several RPIs pass with nothing heard, is the maintainer's account, and was
     **unverified** for outputs in the manuals saved for this record. *(Checked
     2026-10-20: the first is **verified**, *"An owner-controller sends output data to an
     output module when either one of two things occurs: At the end of every one of its
     tasks (local chassis only); At the rate specified in the module RPI"* (1756-UM058L,
     Sept 2026, p.24), a remote module's *"When the RPI timer expires"* (p.25), sends tied
     to the RPI's timer rather than to a change; the second is **verified** as a module's
     configured fault state on a communication fault, *"If a module loses its connection
     to the controller, outputs go to their configured faulted state"* (1756-PM015Q, Sept
     2025, p.12; 1756-UM058L, p.123, FaultMode, *"configure the state of outputs when a
     communication fault occurs"*), which the manuals tie to the connection's loss and do
     not phrase as a number of RPIs.)*

     **Taken: the first,** as the maintainer answered, "Re-write each poll", in the form
     the review refined it: the write again is made by the device's own process at its
     poll, after its read, never by a refresh, so it costs one adapter write a poll period
     for a device whose outputs do not change, and nothing more for one a round writes
     within each poll period *(superseded, below: a fixed timer)*; a device with no
     output point is never written; a device
     that has not yet been written, before the first round's write, has nothing to write
     again; and a device whose last refresh's deadline has passed writes nothing again,
     so that it never holds a stuck runner's outputs past the deadline decision 125 gives
     it, which M4-4's latch then acts on. So "refreshed with the outputs it last had",
     decisions 119 and 125, holds, the refresh carrying the deadline and the poll the
     outputs, and a device's own loss-of-master time, set longer than a poll period, is
     never reached while the runner is well. *(Answered and taken 2026-10-18, after M4-3's
     review.)*

     **Amended: a fixed timer,** the maintainer, 2026-10-18, after M4-3's verification
     (decision 132), "Fixed timer as Logix", superseding "where nothing was written
     within a poll period" and "nothing more for one a round writes within each poll
     period" above. Each device writes the outputs it last wrote again at every poll, on
     its poll grid, after its read, whether or not a round wrote to it within the
     period; the rounds write a device where its outputs changed, as before, with no
     pairing of a poll with a round, no write skipped and no word from the runner to a
     device after a round. The rest stands: a device never written, one with no output
     point among them, writes nothing at a poll; one whose last refresh's deadline has
     passed writes nothing again, so a stuck runner's outputs are not held past the
     deadline M4-4's latch acts on; and at a stop every output is written 0 once, the
     last write. IEC 61131-3 says nothing of a controller's traffic with its I/O. Logix
     sends a module's data at its RPI whether or not it changed, which the manual saved
     for this record says of an input module (p.42, above), and re-sends a controller's
     outputs at the RPI in the same way, as the maintainer answers, since **verified**
     (1756-UM058L, Sept 2026, pp.24–25, above); that an output module falls back to its
     safe state after missing several RPIs stayed **unverified**, by the maintainer's
     answer "Leave unverified", and is since **verified** as a fall to its configured
     fault state on a communication fault (1756-PM015Q, Sept 2025, p.12; 1756-UM058L,
     p.123), not phrased in RPIs. The cost: one adapter
     write a device a poll period, plus each round's; a poll in a round's millisecond,
     handled first, writes the last value just before the round writes the new one, as
     the maintainer accepts. *(Answered and taken
     2026-10-18, after M4-3's verification.)*
131. **A host's call on the manual clock waits for its slot (Milestone 4),** following
     decision 122, asked as M4-3 landed. A test runs the box counter on the manual clock
     with a slow drive whose every write passes 3 ms, and calls `get!/2` from the test's
     own process: a round is owed, so the call waits for the share's slot, and the slot
     comes only as the clock moves, which nothing moves while the test waits in its call.
     The test hangs. As landed, a slot came at the start of the wake after the round that
     completed its C ms of rounds, so even `advance(clock, 0)`, which ran that round, left
     the call waiting for another advance (the review's F3).
     - The rule kept: a call waits for its slot on the manual clock as on the monotonic
       one, a test making it from another process and moving the clock on until it is
       answered, and a slot coming at the end of the round that completes its C ms, in the
       advance that runs that round, never at a later one;
     - a call that comes while a round is owed runs the owed round at once, the round's
       wake going stale, and is then served by the slot rules, as the review proposed: the
       same on the monotonic clock, and on the manual clock no call waits for an advance;
     - or every call served at once on the manual clock, a rule the monotonic clock does
       not run.

     IEC 61131-3 says nothing of a controller's communication with its programming
     station or its host. The conventional family serves unscheduled communication in the
     system overhead time slice, after the continuous task's share of time, and goes back
     to the continuous task at once where nothing waits (the tasks, programs and routines
     manual, pp.31–33, decisions 108 and 122); it has no clock a test moves.

     **Taken: the rule kept,** as the maintainer answered, "Keep the rule": a run on the
     manual clock follows the monotonic clock's rules, one rule for both, so that a test
     tests the rule the plant runs, and the hang is a test's to avoid, which `Logex.Runner`'s
     moduledoc and README's "Running a plant on the clock" (so named since M4-7) say
     how: make the call from another process, `Task.async/1`, and advance the clock until it is answered, at most C rounds, 4 at
     20%. The defect the review found is fixed with it: the slot is served at the end of
     the round that completes C ms, in the advance that runs that round, `advance(clock,
     0)` among them, so a call whose slot has come never waits for a later advance. The
     cost: a call that comes just after a slot waits C ms of rounds for the next, where as
     landed it was served at the next wake, a difference of no time on the monotonic
     clock, whose next wake is at once. *(Answered and taken 2026-10-18, after M4-3's
     review.)*

**After M4-3's verification, 2026-10-18.** The verification of the fixes to M4-3's review
found one rule of decision 130's that its words did not hold at a boundary.

132. **A poll's write again in a round's millisecond (Milestone 4),** *superseded
     2026-10-18 by the maintainer's answer, "Fixed timer as Logix", decision 130's
     amendment: no poll leaves its write to a round, and the mechanism below,
     `Device.due/2`, the runner's cast after each round and the wake at the poll's
     millisecond, is gone; its text is kept as it was taken.* Following decision 130. A
     toggle runs on a 10 ms task and the panel is polled every 10 ms, the default.
     Each round falls in the millisecond of a poll, which is handled first; a poll period
     has passed since the last round's write, so the device wrote its old outputs again,
     and the round then wrote the new ones: twice the writes the device needs, each a
     value about to be replaced (21 rounds gave 41 writes, 20 of them stale), against
     decision 130's "nothing more for one a round writes within each poll period".
     - A poll that finds a round due, come due less than a poll period before it and not
       yet run, leaves its write to that round: the runner tells every device, after each
       round, when the next is due, which also tells it that the round has ended, after
       the round's writes; and the device then writes its outputs again only where the
       round wrote nothing to it since the poll and its deadline has not passed, the
       write counted from the poll, so that the next comes a poll period after it, on the
       grid;
     - the rule as landed, a write again at every poll where nothing was written within a
       poll period, with its cost stated, a stale write before each round that falls on a
       poll;
     - or a write again only where more than a poll period has passed, which an idle
       device then hears every second poll.

     IEC 61131-3 says nothing of how a controller talks to its I/O (decision 130).

     **Taken: the first.** One cast a device a round, which calls no adapter; a round due
     longer than a poll period ago, a runner stuck in a step, is not waited for, so a stuck
     runner's device still writes again until its deadline, decision 130's rule; a round
     that never comes costs that one poll's write. On the manual clock the device sets a
     wake at the poll's own millisecond, after the round's, so that the round's end is
     taken before `advance/2` goes on, by construction; on the monotonic clock a round
     whose wake comes after the poll's in the same millisecond, the common case, is waited
     for, and the stale writes go: a 20 ms task on a 10 ms poll ran 51 rounds in a second
     with 102 writes, the zeros and the 50 between rounds that decision 130 asks for among
     them, where 150 came, 98 of them repeats, and a 10 ms task 101 rounds with 102
     writes, none repeated.
     *(Taken 2026-10-18, after M4-3's verification; the maintainer may choose the second.
     The maintainer answered the same day with neither: a fixed timer, decision 130's
     amendment, which supersedes this decision.)*

**The maintainer's answers after M4-4's review, 2026-10-19.** M4-4 landed with five
readings the record left open, the builder's three of 2026-10-18, with the review's view
of each, one the review's fixes raised and one the builder left among its choices, each
put to the maintainer as a question (`PLAN.md` M4-4). The maintainer answered all five the
same day, each with the option recommended, which is what was built. The plant is §4.4's:
a conveyor on the panel card, a fan, and the "case full" lamp, with the conveyor's speed
on the drive.

133. **A restart while nothing has tripped (Milestone 4),** following decisions 113 and
     115. The conveyor and the fan are running and the lamp is lit, and an engineer's
     program calls `restart/2`.
     - Refused: the engineer's program is told "the runner is running", and the plant
       runs on untouched;
     - a trip and a restart in one: for a moment every output goes off, the conveyor and
       the fan stop and the lamp goes out, and then the program starts from its initial
       values, the conveyor staying off until start is pressed;
     - or the program's values reset without the outputs switched off first: the conveyor
       drops out on the next round, as its seal-in resets, the fan goes off if its program
       starts it off, and nothing is written 0 in between.

     IEC 61131-3 describes a cold and a warm restart as ways a resource starts, and says
     nothing of one that is already running. The conventional family has no restart of a
     running controller, the nearest being a change to Program mode and back (from
     memory, **unverified** in the manuals saved for this record), its outputs in their
     Program-mode state meanwhile: that state is **verified** (2026-10-20), each output
     module's ProgMode and ProgValue *"configure output state when the controller is in
     Program mode"* (1756-UM058L, Sept 2026, p.123).

     **Taken: refused,** the host's mistake, raised in the caller as `ArgumentError`,
     *"the runner is running: restart/2 starts a runner again once it has tripped"*, the
     runner left as it was (the maintainer, 2026-10-19). A host that wants the plant
     started again from its initial values while it runs stops it and starts a new one,
     every output going to 0 on the way, as decision 116 says.
134. **How soon a device stuck inside its own read is a fault (Milestone 4),** following
     decisions 114, 119 and 128. The panel card's adapter hangs in the middle of reading
     the buttons while the conveyor runs steadily and no output changes, so no request of
     the runner's reaches the card. Decision 114 makes it a fault; what is left is how
     soon it is seen.
     - Once the runner has not heard from the card within the idle watchdog and a poll
       period, 510 ms by default: the conveyor, the fan and the lamp go off about half a
       second after the card stuck, a press of stop on that card unseen until then; the
       same time the runner gives any call of its own to a card, so a card has as long to
       answer as its deadline, but a busy machine that holds a card's read back by more
       than that trips the plant;
     - a count of missed reads: the plant stops after four poll periods without a read,
       40 ms by default, sooner, but a machine that holds a card's process back for 40 ms
       trips the plant;
     - or a time set for each device in its binding: the panel's could be 50 ms and a slow
       network drive's two seconds, at the cost of one more setting a plant must get
       right.

     Each costs one message from each card to the runner each poll period, 100 a second a
     card at 10 ms. IEC 61131-3 says nothing of how a controller talks to its I/O. The
     conventional family faults a connection that misses its timeout, which the record
     gave, from memory, as the RPI times a multiplier of 4 by default, matching the
     second. **Contradicted** (checked 2026-10-20): *"The minimum timeout period that,
     once expired without communication, causes a timeout is 100 ms. The timeout period
     can be greater, depending on the RPI of the application. For example, if your
     application uses the default RPI = 20 ms, the timeout period is 160 ms"* (1756-UM001Q,
     Dec 2024, p.158), eight RPIs, not four; *"If communication with a device in the I/O
     configuration of the controller does not occur for 100 ms, the communication times
     out"* (1756-PM015Q, Sept 2025, p.11); and the digital I/O manual speaks of *"4/8/16 x
     RPI"* only for redundant systems, *"For non-redundant ControlLogix applications, the
     CIP connection timeout delay minimum is 100 ms"* (1756-UM058L, Sept 2026, p.79). No
     default multiplier is stated. So Logix's timeout is a time with a floor of 100 ms,
     which grows with the RPI, nearer the first option's one time for every card than the
     second's count of four missed reads.

     **Taken: the idle watchdog and a poll period,** one time for every call to a card,
     until a plant needs a time of its own for a device (the maintainer, 2026-10-19).
     Each device tells the runner it is back from its adapter after every read and
     report, whatever its result, and at each poll while it waits on the runner, a
     round's write answered in time counting too; the runner, as each round begins and at
     each wait's refresh, kills and trips `{:io, device, :timeout}` on the first device in
     device-name order not heard within `idle:` and a poll period. The cost is the
     message a device a poll period.
135. **The device that failed, at its trip (Milestone 4),** following decisions 113 and
     114. The drive's network cable comes loose and the runner's write of the drive's
     speed fails; the record's table says "every other device zeroed".
     - The drive is written its 0 too where it still takes a write, as well as the panel,
       so that where the cable is only flaky the drive's speed goes to 0;
     - or the failed device is left alone, the panel alone written 0, the drive's outputs
       left to what it does when its master goes quiet: the drive keeps its last speed
       until its own timeout.

     IEC 61131-3 says nothing of it. In the conventional family a faulted module's
     outputs go to the fault state configured on the module, the module doing it rather
     than the controller. **Verified** (2026-10-20): *"If a module loses its connection
     to the controller, outputs go to their configured faulted state"* (1756-PM015Q, Sept
     2025, p.12), the state set on the module's own configuration, FaultMode, *"configure
     the state of outputs when a communication fault occurs"*, *"0 = Use FaultValue (Off
     or On) 1 = Hold Last State"* (1756-UM058L, Sept 2026, p.123), so a module may hold its
     last state rather than go off, which logex's 0 written to the failed device, where it
     still takes a write, does not leave to it.

     **Taken: the failed device written its 0 too,** where it still takes a write, so that
     every output that can still be written is written 0, the milestone's done sentence,
     and the table's "every other device zeroed" is read as the others besides it (the
     maintainer, 2026-10-19). A device that does not answer at all is killed, its outputs
     left to what it does on losing its master, as decision 114 says.
136. **A restart that cannot open a device (Milestone 4),** following decisions 113 and
     114. The drive was unplugged while the plant was tripped, and the operator presses
     restart: the panel answers, the drive cannot be opened, and the plant stays tripped,
     the conveyor, the fan and the lamp off.
     - The panel, released for the restart and then latched again, is written its 0 once
       more, as it is when a restart's first round trips again: nothing visible changes
       on a healthy panel, its outputs already off, but a panel that reset itself
       meanwhile, or a card opened again in the same restart, is told 0;
     - or the panel latched again without a second 0, every output written 0 exactly once
       a trip whatever the restarts in between: the same on a healthy panel, and a card
       opened again in that restart left to whatever it does at power-up until the next
       restart.

     IEC 61131-3 says nothing of it. The conventional family writes each module's
     outputs every RPI, so a module hears its state again and again: **verified**
     (2026-10-20), *"An owner-controller sends output data to an output module when
     either one of two things occurs: At the end of every one of its tasks (local chassis
     only); At the rate specified in the module RPI"* (1756-UM058L, Sept 2026, p.24), and
     to a remote chassis *"When the RPI timer expires"* (p.25); "in every mode" is not
     stated, though a module has a configured Program-mode state, ProgMode, *"configure
     the state of outputs when the controller is in Program mode"* (p.123).

     **Taken: written its 0 once more,** a 0 heard once more rather than a card left
     unsaid (the maintainer, 2026-10-19): the runner stays tripped with its first reason,
     `restart/2` gives `{:error, {:io_init, device, reason}}`, and every device that
     answers is latched again and written 0 once more, as a restart that trips again is.
137. **What time a device's own deadline trip reports (Milestone 4),** following decision
     125. The runner is stuck for 3 s inside the conveyor's step, whose watchdog is 50 ms;
     the panel hears nothing by its deadline, 50 ms and a poll period after the step
     began, switches the conveyor, the fan and the lamp off itself, and the runner, back
     after 3 s, trips `{:watchdog, {:device, "panel", ms}}`.
     - `ms` the heartbeat the panel was given, 60, from the refresh it last heard to its
       deadline: the operator reads "the panel heard nothing for 60 ms", the time after
       which the plant went off, the same on every run;
     - the time the runner was gone, about 3,000, read when it came back: "the controller
       was stuck for 3 s", which says how long, but varies from run to run on the real
       clock and says nothing of when the plant went off;
     - or no time at all, `{:watchdog, {:device, "panel"}}`, the reason naming only the
       card.

     IEC 61131-3 says nothing of it. In the conventional family a module whose connection
     times out shows a connection fault code with no time in it, and a task's watchdog
     fault names the task (from memory, **unverified** in the manuals saved for this
     record).

     **Taken: the heartbeat the device was given,** the time after which the plant
     actually went off, the same on every run (the maintainer, 2026-10-19).

**The maintainer's answers after M4-5's review, 2026-10-19.** M4-5 landed with four
readings the record left open, each the option closest to the record and to Logix, the
review agreeing with each, put to the maintainer as a question (`PLAN.md` M4-5). The
maintainer answered all four the same day: three with the option built, and the second
with the option recommended, which was then built. The plant is §4.4's: a conveyor on the
panel card, its fan's task every 50 ms, the e-stop that runs the `trip` task, and the
photo-eye that counts boxes.

138. **When a forced trigger runs its task (Milestone 4),** following decisions 117, 120
     and 127. The conveyor runs, and a technician forces the e-stop on from a laptop to
     test the trip lamp.
     - The `trip` task runs once, at once, when the force changes what the controller
       reads, off to on, before the laptop's call returns, so the lamp is lit by the time
       the laptop says "done"; forcing it on again while it already reads on runs
       nothing, and presses of the real button change nothing while it is forced; where
       one call changes several triggers, as "unforce all" can, each runs its own round,
       one after the other, before the call returns, first by the device's name and then
       by the input's address on it, each round seeing the triggers before it at their
       new values and those after it as they were;
     - every force of a trigger makes a round at once, even to the value it already
       reads: an extra round in which nothing new happens, the round counter moving;
     - or a force waits for the controller's next round on its schedule, the trip lamp
       lighting up to one fan period, 50 ms, later, after the laptop's call has returned;
       and for several triggers in one call, one round in which all of them change
       together, their tasks then running in priority order.

     IEC 61131-3 says nothing of forcing, and an event task in IEC runs on its trigger's
     rising edge, whatever caused it. In the conventional family a force changes the
     input as the program sees it at once: **verified** (2026-10-20), *"If forces are
     enabled and you install a force, the new force immediately takes effect"*, and a
     force *"Overrides the value regardless of the value of the physical device"*
     (1756-PM004L, Nov 2023, pp.51 and 54). Whether an event task triggered by a forced
     input runs at once, or in what order several do, is **not found**: the event
     triggers of the tasks, programs and routines manual (1756-PM005M) are a module's
     change-of-state data, and neither it, the I/O and tag data manual (1756-PM004L) nor
     the white paper "Using Event Tasks with Logix5000 Controllers" (LOGIX-WP003A, June
     2003) mentions forcing an input.

     **Taken: at once, a round for each trigger changed,** in device-name and then
     address order, before the call returns, a force that changes nothing making no round
     (the maintainer, 2026-10-19), as built: several triggers one call changes are the
     several changes from one device decision 120 already rounds one at a time.
139. **A task's interval cut while no untimed program runs (Milestone 4),** following
     decisions 40, 108 and 119. The fan's task runs every 50 ms, last at 50, so it is
     next due at 100; the plant has no continuous task, so the controller's own clock
     stands at 50, the fan's last run, until its next run. At 95 ms by the wall clock an
     engineer cuts the fan to 20 ms, and decision 40 sets the next due time to the earlier
     of the one it had and "now plus the new interval".
     - "Now" read on the controller's own clock, 50: the earlier of 100 and 70, which the
       wall clock has passed, so the fan runs at once, at 95, and the status screen shows
       one missed period, though nothing ran late;
     - "now" the wall clock's, 95, the runner first bringing the controller's clock up to
       it by a round that runs no program: the fan runs at 100 as it would have, no missed
       period shown, and one round more in the log;
     - or "now" the wall clock's, 95, given to the edit's switch as a new argument: next
       due at the earlier of 100 and 115, 100, unchanged, no missed period and no extra
       round.

     With an untimed program, as §4.4's box counter in the continuous task, rounds come
     every millisecond, the controller's clock keeps up with the wall clock, and the three
     agree. IEC 61131-3 says nothing of a task's interval changed while running. In the
     conventional family a periodic task's period may be changed while it runs:
     **partly verified** (2026-10-20), the TASK object's Rate, which GSV and SSV read and
     write in a standard task, is *"The time interval between executions of the task.
     Time is in microseconds"* (1756-RM018A, Sept 2025, p.276), so logic may write it at
     runtime; whether the Task Properties dialog changes it online, and when the new one
     takes effect, is **not found** in the manuals saved (a Rockwell help page, seen only
     through a search's summary, says a safety task's period cannot be modified online).

     **Taken: the wall clock's, given to the switch** (the maintainer, 2026-10-19): the
     screen shows no alarm the edit itself made, and no round is added.
     `Logex.Configuration.Edit`'s `test/3` and `untest/3` take the step's time as `elapsed_ms`,
     the milliseconds since the resource's last cycle, counted as `Logex.Runtime.cycle/3`
     counts them and refused in its words, and `accept/3` takes it for its forecast;
     decision 40's `now` is the resource's `now` plus it. The step moves no clock: the
     resource's `now`, which the next cycle's `elapsed_ms` counts from, and the time a
     timer resumes from (decision 56) stay the resource's. Used alone, without the
     runner, `elapsed_ms` is 0 unless given, so decision 40's `now` is the resource's
     own, as it has been since OE-2: a host that cycles the resource itself holds the
     only clock there is, and says where it stands if it wants to. `Logex.Runner` gives
     each step the time since its last round on its clock, the time the edit is taken,
     and 0 while tripped, its clock not counting the time it is stopped; accept, done in
     the caller, is given it with the resource it is handed.
140. **The forces file a person reads (Milestone 4),** following decision 127. The file
     sits beside the plant's files, one force a line, `eye_1 1`, the photo-eye held on.
     - Read exactly as the runner writes it: a person who opens it sees every force, but
       one who adds a comment or a blank line, or writes `eye_1 01`, finds the next start
       refused, the line named, the plant not started, until the line is put right or the
       file deleted; a last line with no newline is read;
     - or comments and blank lines read and passed over, so that a person may annotate
       it, though the runner's next write, at the next force, drops what was added.

     Beside it, either way: a runner started with no file refuses "unforce" and "unforce
     all" as it refuses a force, in the same words, though it has nothing to take off;
     and an unforce of an input that is not forced is accepted and writes the set again.
     IEC 61131-3 says nothing of forcing. In the conventional family forces are kept in
     the project and changed only through the programming software, never by editing a
     file: the first half **verified** (2026-10-20), *"I/O forces are held by the
     controller and not by the programming workstation"* and a force *"exists in the
     project"* (1756-PM004L, Nov 2023, pp.52–53), the rest **not found**.

     **Taken: read exactly as the runner writes it,** and an unforce of a point not
     forced accepted (the maintainer, 2026-10-19), as built: a strict file is the safest
     for a list that decides what the plant reads.
141. **Two engineers stepping one edit (Milestone 4),** following decisions 60, 66 and
     119. Engineer A accepts a change to the fan's interval from one laptop while
     engineer B, from another, takes a step of the edit the controller already holds.
     - A's accept is worked out on A's laptop against the plant as it was; if B's step
       came first, the controller says so, and A's accept is worked out again against the
       plant as it is now, so that A's laptop shows a forecast that is true when the edit
       is held, and B's edit is replaced by A's, as a second accept replaces a first;
       where B's step was a test, the plant now runs B's new version, which A's edit
       takes as its "old" version, the one A's untest would bring back; a change the
       controller refuses leaves whatever edit was held as it was;
     - or A is told the plant moved on, and accepts again by hand, seeing the plant as it
       now is before choosing.

     IEC 61131-3 says nothing of online edits. The record gave, from memory, that the
     conventional family's programming software lets one workstation at a time edit a
     controller online: **not found, and probably contradicted** (checked 2026-10-20).
     Rockwell's help, seen only through a search's summaries and not fetched, says pending
     edits are kept in the workstation and *"visible only to the person performing those
     edits"*, while test edits *"can be viewed by all workstations"*, and release notes fix
     an anomaly *"when multiple users perform online edits on the same controller"*; no
     locking rule was found. So two engineers stepping edits on one controller, which
     this decision provides for, is likely Logix's case too.

     **Taken: an overtaken accept redone against the plant as it now is** (the
     maintainer, 2026-10-19), as built: it gives exactly what the same steps taken over
     the resource directly give, a second accept superseding the first (decision 66).

**The maintainer's answer after M4-6's walk, 2026-10-20.** M4-6 landed with one reading
the record left open, built as the record said, and put to the maintainer as a question
(`PLAN.md` M4-6). The maintainer answered it on 2026-10-20 with the option recommended,
which was then built. The plant is §4.4's: a conveyor on the panel card, its fan, its
run lamp, and a drive whose card gives the conveyor's speed.

142. **Whether a restart reads every device before its first round (Milestone 4),**
     following decisions 113, 114 and 136. The conveyor runs, the fan with it and the
     run lamp lit, and the drive's card starts giving a speed no dint holds. The
     controller trips: the conveyor, the fan and the lamp go off. The operator presses
     restart without the card mended.
     - The restart lets every card go and runs its first round at once on the last
       values the controller took, so the conveyor's contactor and the fan pull in and
       the lamp lights; at the drive card's next read, within a poll period, the bad
       value trips the controller again and everything goes off: the plant starts and
       stops again in 10 ms, a click of the contactors, and the trip screen again;
     - or the restart reads every card once before its first round, as a start does,
       and one whose read fails or gives a value that does not fit leaves the controller
       tripped with its first reason, the restart answered with that card's fault, as a
       card that cannot be opened again answers it (decision 136): nothing switches on,
       and the operator is told which card is at fault;
     - or the restart is taken as in the first, but the first round's outputs are held
       back until every card has been read once since: nothing switches on, and the
       restart is taken and then trips again within a poll period.

     IEC 61131-3 says nothing of a restart after an I/O fault. Logix (**verified**,
     1756-PM015Q, Sept 2025, p.12), for a module set to "Major Fault On Controller If
     Connection Fails While in Run Mode": the controller *"Must be connected to the
     module during the Program transition to Run mode. During the Program to Run mode
     transition, there can be a 20-second delay. During this delay, the controller makes
     one attempt to connect to a module. If Major Fault On Controller…Run Mode is
     selected and no connection occurs during the 20-second delay, a fault occurs because
     at least one required connection is not established before going to Run mode. This
     is a 3/23 type fault code"*; and in Run it *"Registers a fault if the connection is
     dropped while in Run mode. A required I/O module connection failed, creating a 3/16
     type fault."* A module without that setting is not waited for: *"If a module loses
     its connection to the controller, outputs go to their configured faulted state. The
     controller and other I/O modules continue to operate based on old data from the
     module"* (the same page). Every device of logex's trips the runner when it fails
     (decision 114), so each is a module with that setting, and the second option is
     Logix's one attempt at the transition to Run.

     **Taken: read cards first** (the maintainer, 2026-10-20), then built: `restart/2`
     reads every device once, in device-name order, after every latch is released, one
     that went down opened again and read as its opening reads it, each read checked as a
     start's first reads are; the first that fails, an error, a raise, a throw, an exit,
     a value that does not fit, an address that is no input point's, no answer within the
     idle watchdog and a poll period (the device then killed and opened again at the next
     restart) or a process gone down, leaves the runner tripped with its first reason and
     answers `{:error, {:io_init, device, cause}}`, the one answer a restart gives a
     device it cannot bring up, a start's too, and every device that answers is latched
     again and written 0 once more, as decision 136 has it; otherwise every value read is
     the first round's input, as at a start. A read the restart refuses leaves nothing in
     the device: what a device read is what it last passed on only once the runner has
     taken it, so that the same fault read again later is passed on again and trips. And
     a change a device read before the restart, waiting in the runner's mailbox behind
     it, is stale, taken as nothing: each change carries the count of restarts it was
     read under, as a notice does, so that a reading from before the restart trips
     nothing after one answered `:ok` and overwrites nothing the restart's read gave
     (since M4-6's third verification, 2026-10-20). The count alone did not close it: a
     device heard the new count at its release, which comes before every device's
     reread, so a reading it took while the runner read the devices before it carried
     the new count and was taken after the restart. So from its release until the runner
     has taken its reread a device passes nothing on, a reading from before its reread
     dropped and one after it held and passed on against the image the reread leaves
     (since M4-6's fourth verification, 2026-10-20). And a report that came before a
     device's reread, which the device handles only after the restart because it waited
     on the runner for its own change meanwhile, taking nothing but the runner's answers
     and requests, is dropped too: a reread that answers sends the device a fence, and a
     report handled before it is older than the reread (since M4-6's fifth verification,
     2026-10-20), the fence sent just before the reread reads, so that a report the
     device is sent while its adapter reads, which may give what the read's sample
     missed, is held and passed on (since M4-6's sixth verification, 2026-10-20). A
     reading between a device's release and its reread is held, not dropped: an
     adapter's read may give some of its points and a report the rest (`Logex.IO`), so
     the reread supersedes it only for the points it gives, and gives it with its answer
     for each point it leaves out, which the runner checks as the restart's own read, a
     bad one refusing the restart with that device's fault, a good one among what the
     first round reads (since M4-6's seventh verification, 2026-10-20, which the lead
     treated as a bug fix within this decision, not a new policy, and the maintainer
     confirmed on 2026-10-20). That still lost a reading of a point the
     reread leaves out three ways: a change passed on before the release and answered
     `:stale`, a report the fence dropped whole, and what a device held when a restart
     was refused, on its own reread or another device's, the zero ending the hold. So a
     device keeps each point's newest reading the runner has not taken: its reread is
     the read merged over all of them, a stale change's among them; a report the fence
     marks as older than the reread is dropped only for the points the reread, or a poll
     since, gives; a reread the runner refuses drops the refused point's reading and
     holds the rest, the runner telling the device the cause; and a zero that ends a
     hold passes on what was held, as a change read while tripped is. A change the
     runner refuses in a round keeps its other points in the same way, passed on at the
     device's next reading, so that only a read that gives the refused point again passes
     it on again (since M4-6's eighth verification, 2026-10-20, decision 143).

**The maintainer's confirmation after M4-6's eighth verification, 2026-10-20.** Two of
the verifications' fixes were the lead's calls, built before the maintainer was asked:
that a report-only input's newest untaken reading survives a restart, a bad one refusing
the restart with its card's fault and a good one going into the first round, which the
lead treated as a bug fix within decision 142, not a new policy; and what a change the
runner refuses for one bad point does to its other points, outside a restart. The
maintainer confirmed both on 2026-10-20, the first in decision 142's note and the second
recorded here. The plant is §4.4's, as for decision 142.

143. **A change refused for one bad point (Milestone 4),** following decisions 114 and
     124. The conveyor runs. The drive's card reports the conveyor's speed and its load
     together, in one change, and the speed is a value no dint holds, the load a good
     one. The controller trips on the bad speed (decision 114), the card's fault is
     cleared, and the operator restarts.
     - The good load is kept: the card's change is refused for its bad speed alone, and
       the load goes on to the controller with the card's next reading, so that the load
       the first round after a restart reads is the one the card last gave, not an older
       one;
     - or the whole change is dropped: the controller goes on holding the load it had
       before the change, until the card gives the load again, which a card that reports
       only what changes may not do for as long as the load holds steady.

     The two differ only from the restart on. While tripped no round runs, so the screen,
     `get/2`, shows the load from before the change under either. And a card still bad
     gives the bad speed again with each reading, each refused as the first was, so the
     load is passed on at no reading while it stays bad, and its restart is refused for
     the speed, as decision 142's is (corrected after M4-6's ninth verification,
     2026-10-20: the record said the kept load was the one on the screen).

     IEC 61131-3 says nothing of an input refused in part. Logix's manual (1756-PM015Q,
     Sept 2025, p.11) says, of a connection lost, not of a module faulted, and the two
     quotes **verified** word for word: *"If the controller loses communication with a
     module, data from that device does not update. When this occurs, the logic acts on
     the data in ways that may or may not be correct,"* and *"Outputs respond to the
     last, non-faulted state of the controlling inputs."* That a module's data, so not
     updated, holds its last value rather than going to zero is our reading of
     "does not update"; the page does not speak of zeroing. The manual says nothing of a
     module's data that is good in part, and whether a Logix connection can deliver such
     data is **unverified**.

     **Taken: keep the good points** (the maintainer, 2026-10-20), as built since M4-6's
     eighth verification: the device drops the refused point's reading alone and keeps
     the rest, passed on with its next reading, so that only a reading that gives the
     refused point again passes it on again.

**Milestone 5's decisions, 2026-10-21** (§4.12). Decisions 144–160 are the questions the
design put to the maintainer, numbered as it numbered them, so that 158, put eighth, keeps
its number, and 160 is the follow-up on a bit number held in a tag. The maintainer
answered all of them on 2026-10-21; where an answer is not the recommendation, the
decision gives both. The questions the record found where two answers meet, or an answer
leaves a reading open, are §4.12's "Put to the maintainer"; the maintainer answered them,
and the three rules §4.12 left open, the same day, decisions 161–167 below and notes on
the decisions the rest settle.

144. **What the new types are called (Milestone 5).** The programmer declares the box
     count as a small whole number, the drive's register as a 16-bit unsigned number and
     the fan's speed as a number with a fraction.
     - IEC's words, lowercased: `sint int dint lint usint uint udint ulint real lreal`,
       written `var boxes uint`, `var fan_speed real`;
     - width words, `i8 i16 u16 f32`, as a modern language spells them;
     - or Logix's, which are IEC's.

     IEC names every one (Ed 3 Table 10, pp.31–32; Ed 2 Table 10, pp.30–31); Logix
     (RM018A pp.873–874), Siemens and CODESYS spell them IEC's way, so the naming rule's
     first and third steps apply. The cost: each word is reserved in any case in every
     `.ld` and `.logex` file, so a tag, label, global or instance named `int`, `Real` or
     `lint` stops compiling, and the commit that reserves each says so; each word gets its
     own stanza, and `dint`'s "It is logex's only integer type so far" is amended.

     **Taken: IEC's words, lowercased, each with its stanza and reserved in any case** (the
     maintainer, 2026-10-21), as recommended. Decision 155's `byte word dword lword` follow
     the same rule.
145. **Whether the unsigned types come too (Milestone 5).** The drive card reports the
     fan's speed as a 16-bit register, 0 to 65,535, and the box counter can never be
     negative.
     - All four, `usint uint udint ulint`;
     - none: a register fits a `dint`, so the programmer keeps using a wider signed type;
     - or the three below 64 bits, as the classic S7-1200 has them.

     IEC has all four in both editions (Table 10 features 6–9). Logix added them in v32,
     for the 5x80 controllers only (33.01 release notes); Siemens has USINT, UINT and
     UDINT on the S7-1200 and ULINT on the S7-1500; CODESYS all four. In logex a width is a
     range row, so the unsigned types cost no more than the signed. `neg` into an unsigned
     destination has only 0 and an overflow for results, since decision 147 gives an
     unsigned destination only unsigned sources.

     **Taken: all four; `neg` into an unsigned destination refused when the program
     compiles** (the maintainer, 2026-10-21), as recommended. An unsigned result below 0
     wraps (decision 146): 0 − 1 in a `usint` is 255, with no power.
146. **What overflow does, in every width (Milestone 5).** The box counter's tag is a
     `usint`, `add boxes 1 boxes`, and the 256th box arrives; the fan ramp, `add speed 10
     speed`, is an `int` and passes 32,767.
     - It stops at the limit, and the instruction passes no power on that scan, so an
       "overflow" lamp after it lights: the count shows 255 and stays there (decision 77,
       for every width);
     - it wraps and passes no power: the count shows 0 and the lamp lights for that scan,
       as the S7-1200 does;
     - or it wraps and passes power: the count shows 0 and nothing lights, as Logix's
       ladder does, S:V set and minor fault 4/4 only where overflow faults are reported,
       and as CODESYS does.

     IEC says overflow is an error and leaves its handling to the implementer (Ed 3
     §6.6.2.5.8 p.87; Ed 2 §1.5.1 d) p.21 allows "not reported"), so each is conforming.
     Logix wraps (RM018A p.868, *"adding 1 to a SINT generates an overflow when the value
     goes from 127 through -128"*), sets S:V, and raises 4/4 on each cleared-to-set S:V if
     Report Overflow Faults is on (PM015Q p.57, PM014O p.25), its rung-out its rung-in;
     the S7-1200 returns *"the least significant part of the result that fits"* with ENO 0
     (A5E02486680-05 Table 7-40 p.188). Changing the rule for the new widths alone would
     give one program two rules; changing it for `dint` too breaks decision 77 and the
     programs and tests built on it.

     *Recommended: stop at the limit with no power, for every integer type.* **Taken:
     wrap, as the vendors do, with no power out of the instruction, replacing decision
     77's saturation for the dint too** (the maintainer, 2026-10-21): 127 + 1 in an `sint`
     gives −128 and no power. Follow-up, "No fault; real wraps": no fault is recorded for a
     wrap, which shows only as no power out; and a real too big for its integer
     destination is truncated to an integer and then wrapped as an integer is. A real
     destination saturates (decision 150). What this changes for programs and tests that
     run today is §4.12's "Overflow wraps"; `PLAN.md`'s M5-2 changes them first, on
     purpose. *(Settled 2026-10-21, the maintainer answering §4.12's eighth question as
     recorded: a wrap passes no power, the S7-1200's reading, not Logix's ladder's. The
     follow-up's "truncated to an integer and then wrapped" is, for a conversion that
     rounds, rounded and then wrapped, decision 161, which the maintainer answered
     otherwise than the record read it; a truncation, `real_trunc_int`, truncates and
     then wraps.)*
147. **Arithmetic and comparison across types (Milestone 5).** The day's total is a
     `dint`, the shift's count a `uint`: `add day_total shift_count day_total`. The fan's
     speed is a `real` and its limit an `int`: `gt fan_speed fan_limit`.
     - Every operand of one type, as Ed 2 required (§2.5.1.4 p.53) and MatIEC does: the
       programmer writes a conversion first;
     - the instruction computes in its destination's type, each source widening into it
       where Ed 3's Figure 11 allows (it keeps every value: `uint` into `dint`, `int` into
       `real`), any other refused when the program compiles with the conversion named;
       two integers compare by value whatever their types, and an integer with a real
       only where Figure 11 widens the integer into the real's type;
     - or any numeric operands converted freely, narrowing and changing sign, as Logix
       does (RM018A p.870, ranked SINT to LREAL; p.872, narrowing truncates and sets S:V).

     IEC Ed 3 allows only value-preserving implicit conversions (Figure 11, p.67; rule 1,
     p.66), and its typed `ADD_REAL(A, B)` with an INT `A` converts A implicitly (Table 21
     Example 2), which is the second option: `add` computes as `add_<destination type>`.
     For an overloaded `INT + INT` stored into a DINT IEC computes in INT (§6.6.1.7.2,
     p.70, Example 3), so logex's `add i1 i2 d` cannot overflow where IEC's can; a program
     ported from Siemens or CODESYS that counted on it behaves differently. Logix converts
     anything into anything, setting S:V where it narrows.

     **Taken: compute in the destination's type, each source widening only where Ed 3
     Figure 11 allows, anything else refused at compile time naming the conversion; two
     integers compare by value whatever their types** (the maintainer, 2026-10-21), as
     recommended, with its two literal rules: an integer literal a real slot cannot hold
     exactly refused, the nearest it can named, and a real literal in an integer slot
     refused. *(Settled 2026-10-21, the maintainer answering §4.12's ninth question as
     recorded: a bit string compared with an integer tag is refused, naming the
     conversion, `int_to_word` or `word_to_int`; a literal is judged by its slot, so that
     `eq drive_status 16#0004` is taken.)*
148. **Converting a real to an integer, and what the conversions are called (Milestone
     5).** The fan's speed is worked out as a `real` percentage and written to the drive
     as an `int`: 37.5 becomes 38 or 37? 36.5 becomes 36 or 37? And a real of 40,000.0
     into an `int`?
     - Round to nearest, a tie to the even neighbour: 37.5 → 38, 36.5 → 36, 2.5 → 2,
       −2.5 → −2;
     - round to nearest, a tie away from zero: 36.5 → 37, −2.5 → −3;
     - or drop the fraction: 37.5 → 37, −1.6 → −1.

     And the names: IEC's typed `<from>_to_<to>` (Ed 3 Table 22 feature 1a), 90 of them
     (Table 23); its overloaded `TO_<type>` (feature 1b), ten; with truncation as
     `TRUNC_<integer>` (feature 2c) or `REAL_TRUNC_INT` (2b). IEC rounds ties to even
     (Table 22 footnote b, both editions: `REAL_TO_INT(2.5)` = 2, `(-2.5)` = −2), unsigned
     targets too (Table 23), and leaves a value outside the target to the implementer
     (§6.6.2.5.3 p.79). Logix does the same rounding (RM018A p.872: 2.5 → 2, 3.5 → 4,
     −2.5 → −2), and keeps the low bits of a value too large (p.875); MatIEC rounds to
     even too. Elixir's `round/1` rounds ties away from zero (verified on 1.20.4/OTP 28).
     `docs/naming.md` chose `<from>_to_<to>` and wrote *"Never hide a rounding mode inside
     a conversion name"*, planning `trunc round ceil floor` apart.

     *Recommended: ties to even, saturating out of range, under Ed 3's overloaded names
     `to_<type>` and `trunc_<integer>`, retiring `docs/naming.md`'s note.* **Taken: IEC's
     explicit `<from>_to_<to>` names, `real_to_int` and the rest, keeping `docs/naming.md`'s
     "never hide a rounding mode inside a conversion name"; rounding to nearest, ties to
     even, and `trunc_<integer>` beside them; out of range, decision 146's follow-up:
     truncate, then wrap** (the maintainer, 2026-10-21). §4.12's "Conversions" lists the
     names, 90 numeric, 16 truncations (decision 162) and, with decision 155, 76 for the
     bit strings, 182 in all, and how the principle is kept. *(Settled 2026-10-21 by the
     maintainer's answers to §4.12's first, third and fourth questions: out of range, a
     conversion rounds and then wraps, decision 161, not as the record read "truncate,
     then wrap"; the truncations are IEC's typed `real_trunc_<integer>` and
     `lreal_trunc_<integer>`, sixteen, decision 162, not `trunc_<integer>`; and "never
     hide a rounding mode inside a conversion name" is kept with `real_to_int`, as
     recorded.)*
149. **How literals are written (Milestone 5).** The fan setpoint is 37.5, a mask is hex
     FF, a batch is a million boxes.
     - Reals `37.5`, `-0.25`, `1.5e3`, `1.5E-3`, digits on both sides of the point; `1.`,
       `.5` and `1e5` refused, as IEC's grammar refuses them (Ed 3 Annex A p.222, Table 5
       features 2 and 3); `1.0E+6`, which IEC takes, refused, as decision 97 keeps `+` out;
     - based integers `16#ff`, `2#1010_0000`, no sign, no octal, which Ed 3 deprecates
       (Table 5 features 4–6, NOTE 2);
     - `_` between digits, `1_000_000` (Ed 3 p.26);
     - typed literals, `int#5` (Table 5 feature 9), deferred; Logix's suffixes `5U`, `5L`,
       `1.5L` (RM018A p.870) refused, being no IEC form.

     Logix reads `16#ffff` as 65,535 (zero-fill, RM018A p.869) and stores it into an INT
     as −1 with S:V set; IEC reads a based number as a bit-string literal (p.26).

     **Taken: reals `37.5` and `1.5e3`, with `1.`, `.5` and `1e5` refused; `16#` and `2#`;
     `_` separators; `+` kept out, so no `1.5e+3`; typed literals and octal deferred; the
     vendors' suffixes refused** (the maintainer, 2026-10-21), as recommended. A based
     literal is the number it spells, judged by its slot, so `16#ffff` fits a `uint` and
     is refused for an `int`.
150. **What a real does with a zero divisor, an overflow, NaN and −0.0 (Milestone 5).**
     The fan's speed per box is `div fan_speed boxes_per_min rate`, and just after
     start-up `boxes_per_min` is 0.0; elsewhere `mul big big product` passes 3.4E38 in a
     `real`.
     - IEC 60559's answers stored: +Inf from the division and the product, NaN from
       0.0/0.0, every later comparison with a NaN false;
     - decisions 78's and 77's: the zero divisor writes 0.0, passes no power and raises
       the minor fault `:divide_by_zero`; the product stops at the real's largest finite
       value with no power; no Inf and no NaN ever reaches a state;
     - or the destination keeps its last value, with no power.

     IEC leaves infinity and NaN to the implementer (Ed 3 Table 10 footnotes e and f). The
     S7-1200 returns zero with ENO 0 for a zero divisor (Table 7-40 p.188). Logix raises
     4/4 on a zero divisor (RM018A p.449), shows a NaN as `1.#NAN` (p.882), and flushes
     −0.0 and denormals to 0.0 (p.882). On the BEAM a float holds neither infinity nor
     NaN, and the operations that would give one raise (verified on 1.20.4/OTP 28), so the
     first option would put atoms in every state, answer and adapter write.

     **Taken: a zero divisor gives 0.0 with no power and the `:divide_by_zero` minor
     fault; an overflow saturates at the type's largest finite value with no power; no Inf
     or NaN ever; −0.0 written as 0.0; subnormals flushed to 0.0; every real write rounded
     to single precision** (the maintainer, 2026-10-21), as recommended, with a literal
     `0.0` or `-0.0` divisor refused as decision 78 refuses `0`, and `mod` kept integer
     only.
151. **How an array is declared and written (Milestone 5).** The oven conveyor has eight
     zone temperatures, `temps`; a reject lamp for each of four lanes; a grid of
     setpoints by zone and recipe.
     - Logix's form, a count and zero-based subscripts: `var temps real[8]`, the zones
       `temps[0]` to `temps[7]` (PM004L pp.34–36);
     - IEC's form, bounds: `var temps real[1..8]`, or `real[-2..5]` (Ed 3 Table 11
       feature 4, p.53);
     - or both; and, either way, one dimension, or more.

     Logix allows three dimensions, one only inside a UDT (RM094N p.84), rightmost fastest
     (PM004L p.35); Siemens six; IEC leaves the number to the implementer (p.39) and
     truncates or fills an initial list of the wrong length with a warning (pp.39–40).

     *Recommended: Logix's form, counted from 0, one dimension, no initial values or one
     for each element.* **Taken: Logix's form, `var temps real[8]`, from 0, up to three
     dimensions, `real[4,8]` and `real[2,3,4]`; no initial values, or one for every
     element; `var_external` arrays allowed** (the maintainer, 2026-10-21). An initial
     list follows the elements' order, the rightmost subscript fastest, and one of another
     length is refused.
152. **What may go inside the brackets (Milestone 5).** The box counter stores each box's
     weight in `weights[slot]`, `slot` stepping 0 to 7.
     - A literal only, `weights[3]`;
     - a literal or an integer tag, `weights[slot]`;
     - or an expression, `weights[slot + 1]`, as Logix allows (PM004L p.44; RM018A
       pp.883–884).

     IEC restricts a subscript in the graphical languages to *"single-element variables or
     integer literals"* (Ed 3 §6.4.4.5.1 p.39), and logex has no expression syntax. Logix
     does not take an element as a subscript directly (RM094N p.87).

     **Taken: a literal or an integer tag, never an expression** (the maintainer,
     2026-10-21), as recommended, of any integer type, each subscript of a dimension; a
     literal outside its dimension refused when the program compiles.
153. **An index out of range while running (Milestone 5).** A rung that resets `slot` was
     edited wrongly, and `slot` reaches 8 in `weights`, an `int[8]`.
     - A major fault: the scan runs on with that instruction doing nothing, and the
       runner trips before it writes the round's outputs: the conveyor, the fan and the
       lamp go off, and the trip names the instance, file, line and index;
     - a minor fault: the read gives the element's zero, the write is dropped, the plant
       runs on;
     - the index clamped to the nearest end, `weights[7]` overwritten and nothing said;
     - or wrapped, `weights[0]` overwritten.

     IEC calls it an error, found only at run time for a computed index (Ed 3 p.39). Logix
     raises major fault 4/20 (RM018A p.869, p.884; PM014O p.20) when the instruction runs,
     not on a false OTL (RM018A pp.86–87), and halts logic (PM014O p.9). The S7-1500 goes
     to STOP; the S7-1200 stays in RUN with a diagnostic entry; no vendor clamps or wraps.

     **Taken: a major fault; the scan finishes with that instruction doing nothing, then
     the runner trips before it writes outputs, amending decisions 99 and 113** (the
     maintainer, 2026-10-21), as recommended. §4.12's "The major fault" gives the fault's
     shape and the trip's reason, and the reading put back to the maintainer, §4.12's
     tenth question, of when in a round the runner trips: at the end of the step that
     raised the fault, no later step of the round running. *(Settled 2026-10-21, the
     maintainer answering that question as recorded: the runner trips at the end of the
     step that raised the round's first major fault.)*
154. **Arrays of timers, counters and blocks, and one-shots on elements (Milestone 5).**
     Each lane has its own reject timer, `var lane_t ton[4]`, and its own one-shot, `var
     edge bool[4]`.
     - Elementary arrays only in this milestone, instances later;
     - arrays of instances, with a literal index on every instruction that runs one, `ton
       lane_t[2] 500`, and on every one-shot's storage bit or pulse bit; a member read or
       written through a tag index, `xic lane_t[slot].dn`;
     - or tag indexes everywhere, the static rules weakened.

     IEC allows arrays of FB instances since Ed 3 (Table 11 feature 5, `ARRAY[1..50] OF
     TON`), Logix arrays of TIMER (RM094N p.85). logex's static rules need a fixed path:
     one instruction of its type for each built-in instance (M1-6, decision 85), one
     one-shot for each storage bit (M1-6, M3-4, decision 101), and the edit's block list by
     path (decisions 32, 87 and 106); `ons edge[slot]` would fire for whichever element
     `slot` names, which no rule can check and no edit can block.

     **Taken: allowed, with a literal index on whatever runs an instance and on a
     one-shot's storage or pulse bit** (the maintainer, 2026-10-21), as recommended; the
     same literal rule holds for a bit of a word as a one-shot's bit (decision 160).
155. **Bit strings and bit access (Milestone 5).** Bit 3 of the drive's status word is "at
     speed", and the run lamp should follow it: `xic drive_status.3 ote run_lamp`.
     - IEC's way: `byte word dword lword` as types of their own, no arithmetic on them,
       bit access and the bitwise and shift instructions only on them (Ed 3 Table 17
       pp.59–60, Tables 30 and 31), an explicit conversion between them and the integers
       (Figure 11);
     - Logix's way: no bit-string types; bit access `x.3` on every integer type (RM018A
       pp.884–885), bitwise logic on integers (RM018A pp.494–496);
     - or both.

     PLAN §5 settled `word.3` as bit access, refused with its own message until it lands
     (§4.7). Reserving `byte` and `word` breaks plausible tag names.

     *Recommended: Logix's way now, bit access on every integer type, the bit-string types
     deferred.* **Taken: add them now, `byte word dword lword`, with the bitwise
     instructions** (the maintainer, 2026-10-21). Follow-up, "Logix-friendly": bit access
     and the bitwise instructions, `and or xor not shl shr rol ror`, work on both bit
     strings and integers; a coil on `status.3` counts as a write of `status`; a bit of a
     real is refused. Arithmetic on a bit string stays refused, as IEC's; `docs/naming.md`'s
     planned `wand wor wxor wnot` give way to IEC's words (its note is amended).
     *(Settled 2026-10-21, the maintainer answering §4.12's second question as recorded: a
     bitwise instruction's operands are all bit strings or all integers, a mix refused
     naming the conversion. Decision 165 gives a shift's or a rotate's count out of range
     its rule.)*
156. **What types an I/O point may have, and what a device gives (Milestone 5).** The
     drive card gives the fan's speed as a 16-bit register, the analog card the eight zone
     temperatures as reals, the panel the lamp's bool.
     - Every elementary scalar type may be located, `var_global fan_hz uint at
       drive.i.2`, each adapter's `check/3` refusing a type its device cannot carry, and a
       located array later;
     - points stay `bool` and `dint`, other types reached by a `move`;
     - or scalars and arrays, `var_global temps real[8] at card.i.0`.

     IEC's directly represented variables carry a size prefix and are bit strings
     (`%IW215`, Ed 3 Table 16); a Logix module's data is a tag of its own, often an array.

     *Recommended: every elementary scalar type at a point; a located array waiting.*
     **Taken: every elementary scalar type may be located, and arrays too** (the
     maintainer, 2026-10-21). Follow-up, as recommended then: a located array takes
     consecutive addresses, `var_global temps real[8] at card.i.0` occupying `card.i.0` to
     `card.i.7`, each element a point, read and forced as its own point, `temps[3]`; the
     range must not overlap another point. An integer point takes only an integer that
     fits; a real point a float or an integer; the forces file spells reals so that they
     read back exactly.
157. **An online edit that changes a type or an array's size (Milestone 5).** The box
     counter's `usint` overflows at 255, so the programmer edits it to a `uint` while the
     line runs; two zones are added, `temps` from `int[8]` to `int[10]`.
     - Refused, as every type change is today (§4.9, `Logex.Edit.Plan.retyped/2`);
     - a widening that keeps every value allowed, an array grown with new elements at
       zero, a narrowing and a shrink refused;
     - or any change allowed, values converted.

     Logix changes an array's size or type offline only (RM094N p.85), a UDT too (p.88);
     IEC says nothing of online edit. Decision 29's report of a changed initial value is
     for a bool or a dint today, compared with `!=`, under which `0` and `0.0` are equal.

     **Taken: refused; decision 29's "initial value changed" widened to every type, with 0
     and 0.0 treated as different** (the maintainer, 2026-10-21), as recommended. The
     declared values are compared, so `var x real 0` edited to `var x real 0.0` is
     reported, `{:initial_changed, "x", {0, 0.0}}`, the running value kept, although a
     real starts at 0.0 under either (§4.12, "An online edit").
158. **Whether timers and counters change type (Milestone 5).** A timer longer than 24.8
     days, or a box count past 2,147,483,647.
     - `.pre`, `.acc`, `.pv` and `.cv` stay `dint`, presets in milliseconds;
     - `lint` members for every timer and counter;
     - or typed variants, IEC's `CTU_LINT`, `CTU_UDINT`, `CTU_ULINT` (Ed 3 Table 45
       features 1c–1e) and its LTIME timers (Table 46), as further types.

     IEC's counters come typed, CTU_INT (which is CTU), CTU_DINT, CTU_LINT, CTU_UDINT and
     CTU_ULINT, and CTD's and CTUD's the same (Table 45); its timers take TIME or LTIME,
     TON_LTIME among them (Table 46 features 1c, 2c, 3c), LTIME a signed 64-bit count of
     nanoseconds (Table 10 footnote m). Logix's TIMER and COUNTER are DINT (RM018A p.111,
     pp.93–94); its LTIME is 64-bit nanoseconds on the 5x80 (RM094N p.13).

     *Recommended: every timer and counter member `dint`.* **Taken: typed variants**
     (the maintainer, 2026-10-21): IEC's typed counters for each integer type Table 45
     gives, `ctu_int`, `ctu_lint`, `ctu_udint`, `ctu_ulint`, and the same for `ctd` and
     `ctud`, `ctu` staying CTU_DINT; and the long timers, `ton_ltime`, `tof_ltime`,
     `tp_ltime`, and an `rto` equivalent if fitting, their members `lint`, counted in
     **nanoseconds**, as IEC's LTIME is ("Long timers in ns"), the TIME and LTIME types
     themselves deferred. Since `Logex.Runtime`'s `now` and the runner's clock are whole
     milliseconds, a long timer's resolution is one millisecond, its `acc` stepping by
     1,000,000 ns (§4.12, "Timers and counters"). *(Settled 2026-10-21 by the
     maintainer's answers to §4.12's fifth, sixth and seventh questions: the counters stop
     at their type's limits, decision 71 by width, as recorded; `ctu_dint`, `ctd_dint` and
     `ctud_dint` exist as aliases of `ctu`, `ctd` and `ctud`, decision 163, otherwise
     than the record read it; and `rto_ltime` is taken, as recorded.)*
159. **Where decision 147's widening applies beyond an instruction (Milestone 5),** added
     by the review. The shift's count is a `uint` and the block `seal` takes a `dint`
     input: `cal s1 shift_count`; the configuration connects a `uint` global to a
     program's `dint` var_input; and a program declares `var_external estop_count dint`
     where the global is a `uint`.
     - A `cal`'s inputs and a connection's copy-in widen as an instruction's sources do,
       its outputs and the copy-out as a destination does, and a `var_external` binds
       only to a global of exactly its type;
     - every one of them of exactly one type, as today;
     - or every one widening, the `var_external` included.

     IEC's rules 4 and 5 (p.66) allow implicit conversion for an input and an output
     parameter, and rule 6 forbids it for an in-out parameter; a `var_external` that
     widened would be a second copy, which decision 49 rules out.

     **Taken: `cal` parameters and connections widen as instructions do; a `var_external`
     must match its global's type exactly** (the maintainer, 2026-10-21), as recommended,
     an array's element type and every dimension included.
160. **A bit number held in a tag (Milestone 5),** following decision 155. The drive's
     fault word has sixteen bits, and a lamp shows the bit an operator selects, `xic
     drive_faults.[sel] ote fault_lamp`; `sel` reaches 16.
     - A literal bit number only, `status.3`, as IEC's partial access (Ed 3 Table 17,
       *"an integer literal (0 to max)"*);
     - a literal or an integer tag, `status.[n]`, as Logix writes it (RM094N p.86,
       *"MyDint.[Index]"*; RM018A p.885, `variable3.[4]`), never an expression; a bit
       number outside the type's width a major fault that trips the plant, as an index
       out of range is (decision 153);
     - or a tag bit number with the number taken modulo the width.

     Logix lets an expression stand in the brackets (RM018A p.885) and requires the
     number within the integer's bits (PM004L p.44); the design had deferred a tag bit
     number to a later item (decision 155's first draft).

     **Taken: literal `status.3`, or an integer tag `status.[n]`, never an expression; a
     bit number outside the type's width a major fault, tripping the plant as an index
     out of range does** (the maintainer, 2026-10-21), as recommended in the follow-up. A
     one-shot's storage bit, or a pulse coil's bit, on a bit takes a literal number
     (decision 154).

**The answers to Milestone 5's questions put back, 2026-10-21** (§4.12, "Put to the
maintainer"). Decisions 161–163 are the three of §4.12's ten questions the maintainer
answered otherwise than the record read them, and 164–166 the three rules §4.12 left
open for the item that meets them. The other seven answers keep the record's reading and
are notes on the decisions they settle: 146 (the eighth question), 147 (the ninth), 148
(the fourth), 153 (the tenth), 155 (the second) and 158 (the fifth and seventh).

161. **A real too large for its integer target (Milestone 5),** following decisions 146
     and 148. The fan's speed is worked out as a `real` and has run to 40,000.7 when it
     is written to the drive as an `int`, whose top is 32,767.
     - Round, and where the rounded value does not fit, truncate the real toward zero
       instead and wrap the truncated value, with no power: 32767.6 gives 32767, 32768.4
       −32768 and 40000.7 −25536 (the record's reading of decision 146's follow-up,
       "truncated, then wrapped");
     - or round, and wrap the rounded value, with no power: one rounding everywhere,
       32767.6 giving −32768, 32768.4 −32768 and 40000.7 −25535.

     Both give IEC's own case, 70000.4, 4464, with no power. IEC converts a numeric source
     by extending it to the largest type of its category, then converting it to LINT,
     which rounds, and only then to the target, and leaves the stored value of
     `REAL_TO_INT(70_000.4)` to the implementer (Ed 3 §6.6.2.5.3 p.79); Logix *"rounds the
     fractional part and truncates the upper portion of the non-fractional part"* (RM018A
     p.875). The first changes the rounding mode at the range's edge, which neither does.

     **Taken: round, then wrap, as IEC and Logix do** (the maintainer, 2026-10-21),
     reversing the record's reading. Every `<real>_to_<integer>` conversion rounds to the
     nearest, a tie to the even neighbour (decision 148), and a rounded value outside its
     target keeps its low bits, two's complement for a signed target (decision 146),
     passing no power, as a wrap does (§4.12's eighth question, answered as recorded):
     `real_to_int` of 32767.6 is −32768, of 32768.4 −32768, of 40000.7 −25535 and of
     70000.4 4464, each with no power, and of 32767.4, which rounds to 32767, 32767 with
     power. A truncation, `real_trunc_int` (decision 162), truncates toward zero and then
     wraps, with no power where the truncated value does not fit, so `real_trunc_int` of
     40000.7 is −25536. No fault is recorded for either (decision 146's follow-up).
162. **What the truncations are called (Milestone 5),** following decision 148.
     Converting the fan's speed for a display that must never show a value it has not
     reached, the programmer drops the fraction: 37.9 shown as 37.
     - `trunc_<integer>`, IEC's overloaded TRUNC (Ed 3 Table 22 feature 2c), eight names,
       `trunc_int` from either real (the record's reading of the answer);
     - or IEC's typed truncation (feature 2b), `real_trunc_int` and `lreal_trunc_int`,
       sixteen names, each naming its source as `real_to_int` does.

     **Taken: IEC's typed form, `real_trunc_int`, not `trunc_int`** (the maintainer,
     2026-10-21): sixteen names, `real_trunc_<integer>` and `lreal_trunc_<integer>` for
     each of `sint int dint lint usint uint udint ulint`, each from the real type it
     names, toward zero (Table 22 footnote c, `TRUNC_INT(-1.6)` = −1, so `real_trunc_int`
     of −1.6 is −1), out of range wrapped with no power (decision 161). Every conversion's
     name then says both its types, as decision 148's `<from>_to_<to>` does. The
     conversions are 182: the 90 numeric, the 16 truncations and the 76 of the bit
     strings (decision 155), each reserved in every `.ld` file and named in a family
     stanza (§4.12, "Reserved words"); `trunc_int` is no mnemonic.
163. **`ctu_dint`, `ctd_dint` and `ctud_dint` (Milestone 5),** following decision 158.
     A programmer used to IEC's typed counters declares `var boxes ctu_dint`, beside a
     colleague's `var cases ctu`.
     - No such word: `ctu` is IEC's CTU_DINT and its one spelling, the typed words being
       `ctu_int`, `ctu_lint`, `ctu_udint` and `ctu_ulint` (the record's reading);
     - or the three as aliases, second words for the very types `ctu`, `ctd` and `ctud`
       declare.

     IEC names the DINT counters CTU_DINT, CTD_DINT and CTUD_DINT (Ed 3 Table 45 features
     1b, 2b and 3b), and its plain CTU is CTU_INT (feature 1a); logex's `ctu` has been
     CTU_DINT since M3-1.

     **Taken: the three exist, as aliases of `ctu`, `ctd` and `ctud`, which are the same
     thing** (the maintainer, 2026-10-21). Each is a type word, reserved in any case in
     every `.ld` file and named in the commit that reserves it, and owes its own
     `docs/naming.md` stanza, which `naming_test.exs` checks as for any type word, each
     saying it is its plain word's alias, CTU_DINT's IEC name. A declaration with either
     word gives one type, `Logex.FbType.ctu/0` and its two siblings, and keeps no
     spelling, so `var boxes ctu_dint` and `var boxes ctu` compile to the same program.
     *Reading (the record's):* every message and warning names an instance by its type's
     plain word, whichever spelling declared it: `Logex.Declarations.instance_of/1`'s "a
     ctu", which every message that names an instance's type reads, the compiler's
     refusals of a counter (decisions 73 and 85, a counter of the other kind told to
     declare a `ctud` among them), the warning for a counter no instruction runs, the
     event task's counter warning (decision 72) and an edit's refusal of a type change;
     and an
     edit from one spelling to the other changes no type, so it is neither refused nor
     reported. The cost is a message that names a word the declaration does not hold,
     which each alias's stanza and README's counter section say once. The alternative, a
     message in the declaration's own word, would put the spelling into the tag's type,
     so that two declarations of one thing would differ as data and `Logex.FbType.same?/2`
     and the edit's type comparison would have to excuse it.
164. **`sqrt` of a negative source (Milestone 5),** left open by §4.12 and decision 79's
     note. The fan's vibration is worked out as `sqrt fan_var fan_dev`, and a rounding in
     the subtraction before it leaves `fan_var` at −0.25 for one scan.
     - 0.0, no power and a minor fault;
     - 0.0 and no power, with no fault, as a wrap;
     - or a major fault, which trips the plant.

     On the BEAM `:math.sqrt(-1.0)` raises (verified on 1.20.4/OTP 28), and decision 150
     keeps a NaN, IEC 60559's answer, out of every state; IEC's SQRT takes a real
     (decision 79), and the record read no clause of IEC's on a negative input.

     **Taken: 0.0, no power and a minor fault, `:negative_sqrt`** (the maintainer,
     2026-10-21): decision 99's fault kinds grow by one, a `%Logex.Fault{kind:
     :negative_sqrt, instruction: :sqrt}` of `severity: :minor` (decision 153), placed as
     a zero divisor's is, in a lone instance's `state.faults` and as a cycle's `{:fault,
     task, instance, fault}` event after its scan's `{:ran, ...}`, the plant running on.
     The source is checked before the BEAM's square root is called, so no
     `ArithmeticError` leaves a scan. A literal negative source, `sqrt -4.0 x`, is
     refused when the program compiles (decision 167).
165. **A shift or rotate count out of range (Milestone 5),** left open by §4.12. The
     drive's status word is shifted by `shl status n mask`, `n` an `int` tag an operator
     sets, which reaches −1, or 40 for a 16-bit `word`.
     - A count negative at run time passes no power and writes nothing;
     - or it is a minor fault;
     - or a major one, which trips the plant.

     IEC calls a negative count an error (Ed 3 Table 30 footnote a), fills a shift with
     zeros (Table 30) and says of a rotate only that it is circular.

     **Taken: a negative shift or rotate count acts as 0, no shift, with no power out; a
     count of at least the width shifts everything out, 0; a rotate takes its count
     modulo the width; no fault** (the maintainer, 2026-10-21). *Reading (the record's),
     in each case:* a negative count writes the source, unshifted and unrotated, into the
     destination in the destination's type (decision 147), as a count of 0 writes it,
     and passes no power, so that a lamp after it shows it; a `shl` or `shr` count of
     the destination's width or more writes 0 and passes its power in, as §4.12 had it;
     a `rol` or `ror` count of 0 or more rotates by the count modulo the width, with its
     power in; and none raises a fault or an event. A negative literal count stays
     refused when the program compiles (§4.12), and an unsigned tag is never negative.
     This amends §4.12's routine choice that a bitwise instruction's power out is its
     power in, for this one case, and decision 98's note.
166. **An integer at a real I/O point (Milestone 5),** left open by §4.12. The analog
     card's driver gives a zone temperature as the integer 16,777,217 to a `real` point,
     or a host forces 10^40 onto it.
     - An integer beyond the real's range refused as a bad value, which trips the runner
       from a device (decision 114);
     - or saturated at the real's largest finite value, as decision 150 saturates a
       result.

     A `real` holds every integer to 2^24 exactly and an `lreal` every integer to 2^53
     (§4.12's table); Logix stores an integer put into a REAL at the REAL's precision,
     the rounding it uses there **unverified** (§4.12, "Unverified", its second item).

     **Taken: an integer at a real point is stored as the nearest real, its precision
     lost silently, as Logix does; only a value beyond the real's range is a bad value,
     and trips** (the maintainer, 2026-10-21). 16,777,217 at a `real` point is stored as
     16777216.0, with no message, and 2^53 + 1 at an `lreal` point as 2^53. *Reading
     (the record's):* "beyond the range" is a value, integer or float, whose nearest value
     of the type would lie past its largest finite value, 3.4028235E38 for a `real`, so
     that 2^128 is beyond and 3.4028235E38 is not; the rule is `Logex.Declarations.fits?/2`'s,
     one check for a device's value, a host's `put_inputs/3` and a force (§4.12, "I/O
     points"), so a device's value beyond the range trips the runner as a bad value
     (decision 114), a host's is an `ArgumentError` and a force is refused, each in the
     type's words. A literal is judged otherwise: one a real slot cannot hold exactly is
     refused when the program compiles, the nearest it can named (decision 147), since
     the programmer can write the nearest and a device cannot.

167. **A literal negative square root (Milestone 5),** left open by decision 164. A rung
     says `sqrt -4.0 root`: its source is negative on every scan, so the minor fault of
     decision 164 would be raised on every scan for as long as the program runs.
     - Refused when the program compiles, a diagnostic at its line, as decision 78
       refuses a literal zero divisor of `div` or `mod`;
     - or compiled, giving 0.0, no power and `:negative_sqrt` on every scan.

     IEC says nothing of a constant argument outside a function's domain; Logix's
     verifier is not known to refuse it (unverified). *Recommended and taken: refused when
     the program compiles, as decision 78* (the maintainer, 2026-10-21). A negative
     source held in a tag stays decision 164's minor fault at run time; `-0.0`, which is
     no negative number, is taken.

---

## 8. Sources, and what is unverified

**IEC 61131-3.**
- Ed 2:2003 and Ed 3:2013, the texts in `docs/instruction-sets.md` §9.
- Clauses read for this document:
  - Ed 2: §1.4.1–1.4.2, §1.5.1, §2.1.3, §2.4.1.1, §2.4.3–2.4.3.1, §2.5, §2.5.2,
    §2.5.2.1a), §2.5.2.2, §2.5.3, §2.7.1–2.7.2, §4.1.2, §4.2.5–4.2.6; Tables 10, 13, 15,
    16a, 49, 53 and 56; Figure 20; Annexes B.0 and B.1.7; Table C.2; Annex F.7 with Figure F.8.
  - Ed 3: Foreword; §6.1.3; §6.5.2.1 Figure 7; §6.5.5.1; §6.6.1.1; §6.6.1.4.1; §6.8.2;
    §7.2.1; Annex A.
  - For Milestone 2's design (§4.10, decisions 30–40): Ed 2 §2.5.2 (Table 32) and
    Table 33 with Annex B.1.5.2, Table 10 note d (p.31) and Table 50 (p.116); Ed 3
    Table 10 note d (p.32), §6.6.3.2 rule 11 (p.100, PRIVATE the default), §6.6.3.4.2
    with its Figure 13 (p.108) and Table 63 (p.182).
  - For decision 127, searched on 2026-10-18: "forc" occurs in the extracted text of
    neither Ed 2 nor Ed 3, so IEC 61131-3 says nothing of forcing; the other parts of IEC
    61131 were not read.
- Ed 4 (2025) was not read beyond its publisher preview, so **its organisation clauses are
  unverified**.

**The conventional family.**
- The import/export reference, Sept 2025: ch.6 (tags), ch.8 (programs), ch.14 (tasks) and
  ch.15 (parameter connections).
- The general instructions reference, Sept 2025, 1756-RM018A (served at the 1756-RM003
  address): the TASK object for GSV/SSV (p.276, its Rate, decision 139), TON (its TIMER
  structure and prescan), ONS, and a CPS example.
- The ladder-diagram programming manual, July 2022, ch.1.
- For Milestone 4's design (§4.11, decisions 108–132): the tasks, programs and routines
  manual, Sept 2025, 1756-PM005M, p.8 (the continuous task, one at most, restarting at
  once), p.13 (its
  lowest priority, and the system overhead time slice), pp.31–33 (the time slice, its
  table and its default), p.34 (each task's watchdog) and pp.37–46 (event tasks, the change
  of state and the requested packet interval, p.46 its warning of an overlap, decision
  120); and the design considerations reference, Sept 2025, 1756-RM094N, pp.19, 24 and
  34–36 (the
  newest controllers run communications on a core of their own, with no time slice; p.35
  the time slice's formula and table, decision 122) and p.31 (the I/O force tables among
  a controller's I/O memory, decision 127). **Unverified:** that the conventional family
  keeps forces through a power cycle, which no manual saved says (decision 127; the
  indicator and the forces held in the controller, verified since, below).
- Read on 2026-10-20, for decision 142 and to check the record's other claims of the
  conventional family's I/O, forces and online edits (the PDFs current at
  `literature.rockwellautomation.com`, page numbers the printed ones):
  - *Information and Status*, 1756-PM015Q, Sept 2025: p.11 (a connection's 100 ms
    timeout, data that does not update, the logic acting on old data, outputs
    responding to the last non-faulted state of their inputs; decision 143), p.12 (Major Fault
    On Controller If Connection Fails While in Run Mode, its one attempt to connect
    during the Program to Run transition, faults 3/23 and 3/16, and a module's outputs
    going to their configured faulted state without it; decisions 130, 135 and 142) and
    p.14 (the controller re-establishing a connection);
  - *Major, Minor, and I/O Faults*, 1756-PM014O, Sept 2024: p.9 (a major fault halts
    logic and the controller goes to faulted mode);
  - *I/O and Tag Data*, 1756-PM004L, Nov 2023: pp.51–54 (a force taking effect at once,
    the FORCE status indicator, forces held by the controller and kept in the project,
    a force overriding the physical device; decisions 127, 138 and 140);
  - *ControlLogix 5570 and 5560 Controllers*, user manual, 1756-UM001Q, Dec
    2024: p.158 (the I/O connection's timeout, 100 ms at least, 160 ms at the default
    20 ms RPI; decision 134) and p.161 (where the major-fault checkbox is set);
  - *ControlLogix Digital I/O Modules*, user manual, 1756-UM058L, Sept 2026: pp.24–25
    (outputs sent at the end of each task, locally, and at the RPI; decisions 130 and
    136), p.67 (the major-fault checkbox), p.79 (the connection timeout, 100 ms at least
    where not redundant; decision 134) and p.123 (FaultMode, FaultValue, ProgMode and
    ProgValue; decisions 130, 133, 135 and 136);
  - *ControlLogix 5590 Controller User Manual*, 1756-UM900B, Nov 2025: p.132 (at least
    100 ms to see a connection lost), p.240 (the controller's state with the checkbox and
    without) and p.242 (a major fault sends the outputs to their configured fault state);
  - *Using Event Tasks with Logix5000 Controllers*, LOGIX-WP003A, June 2003 (no word of
    forcing a trigger; decision 138).
  - **Not found** in them: whether a forced input fires the event task it triggers
    (decision 138); when a task's period changed online takes effect (decision 139); and
    any rule that one workstation at a time edits online, which Rockwell's help, seen
    only through a search's summaries, probably contradicts (decision 141).
- For Milestone 2's design: the add-on instructions manual, Sept 2025, p.21 (instructions
  nested up to 16 levels deep, decision 32; the design considerations reference says the
  same on p.15), p.23 (local tags not reachable from outside, decision 33) and p.79 (a
  parameter read or written from outside logic, decision 33).

**Free software, cited by symbol (CONTRIBUTING.md, "Anchor on names, not line
numbers").**
- MatIEC, `stage4/generate_c/generate_c.cc`:
  - `calculate_common_ticktime_c` (the GCD tick);
  - the `task_initialization_c` visitor (`static R_TRIG` on SINGLE; `!(tick % N)`; an
    INTERVAL of 0 is emitted as `1`, so the task runs every tick);
  - the `program_configuration` visitor (the copy-in and copy-out around each call);
  - the single-configuration and periodic-task errors.
- MatIEC `lib/timer.txt`, `TON`, at `7680ed8`.
- OpenPLC v3 `webserver/core/main.cpp` (the cycle), `webserver/core/ladder.h` (the
  hardware layer) and `utils/glue_generator_src/glue_generator.cpp` (`updateTime`), at
  `b5d4135`; for Milestone 4's design, `webserver/core/utils.cpp` too (`sleep_until`, an
  absolute `clock_nanosleep`, and `disableOutputs`).
- Beremiz `editors/ResourceEditor.py`, the task editor, whose Interval cell is editable
  only when a task's triggering is cyclic and whose Single cell only when it is an
  interrupt (decision 39), at `5e3a749`.

**CODESYS, for Milestone 2's design.**
- Its online help, "Object: Task", read on 2026-10-02: a priority of 0 to 31, 0 the
  highest (decision 37).

**Online edit (§4.9), read on 2026-10-01.**
- The conventional family: its quick start (Oct 2009), pp.120–124, for the edit cycle and
  the three output sentences (verified again on 2026-10-01); its current online-editing
  help (pending, accept, test, untest, assemble); its *design considerations reference*
  (Sept 2025, 1756-RM094N), p.65
  (partial import online, and rescheduling a program refused in Run mode) and pp.85, 88
  and 91 (a tag's data type, or an existing user-defined type, changed offline only); and the TASK object of its general
  instructions reference (1756-RM018A, p.276), whose rate and priority logic may write at
  runtime.
- CODESYS online help: "Online Change" (Table 106, what forces a full download) and
  `FB_Init`/`FB_Reinit` (how an instance's data is copied).
- Siemens: the S7-300/400/1200/1500 comparison list for programming languages (11/2019).
- Beremiz, "PLC logic hot-swap" (2026-09-12).
- Spark 2.7.3 (hex tarball), read and probed.
- **Unverified:** whether the conventional family's switch is atomic at a scan boundary;
  whether it can create a task online (a third-party guide says offline only, and no first
  party source was found); when CODESYS and Siemens switch within a cycle.

**Unverified or from memory. Do not repeat these as fact.**
- **From memory:**
  - that the conventional family's continuous task runs at the lowest priority and is
    preempted by periodic and event tasks *(read since, 2026-10-17: the tasks, programs
    and routines manual, p.13)*;
  - that a lower priority number is higher there;
  - that an unscheduled program does not run;
  - that its logic may `move` into a timer's `.pre` and `.acc`;
  - what its controller does to outputs on a watchdog fault *(the tasks, programs and
    routines manual says only that a major fault occurs and that, depending on the
    controller's fault handler, the controller might shut down, p.34; read since,
    2026-10-20: *"A major fault on the controller causes the outputs to go to their
    configured fault state"*, 1756-UM900B, Nov 2025, p.242)*.
- **Not tried:** what a machine that suspends does to the runner's monotonic clock and its
  devices' heartbeats (§4.11, "Risks").
- **Inferred, not stated by the sources:**
  - that the conventional family has no program type/instance split, inferred from *"A
    program can be scheduled under one task only"*;
  - the timer member mapping `.pre`→PT, `.acc`→ET, `.dn`→Q, except a `tp`'s, whose Q is
    `.tt` (decision 74).
- **Not found in IEC:**
  - any rule for an unconnected program input *(found since by inference, §4.4)*;
  - the meaning of W and D sizes for logex's `dint`, which does not arise under §4.5.
- **Absence claims are weaker for Ed 3.** Its text layer splits words ("ca nnot"), so
  "occurs zero times" there is weaker evidence than for Ed 2.
- **The configuration file's extension:** settled by decision 35, `.logex`, checked on
  2026-10-02 against the extension registries, GitHub Linguist, editors, MIME tables,
  marketplaces and Sourcegraph's index of public code, and found free. Not checked:
  GitHub's own code search, and two registries that refused the requests (a third lists
  neither extension, the placeholder included). The placeholder it replaces clashed with
  four tools.
- **Not yet measured:** the §4.4 diagnostics under any test. They are spike output only.
  *(A real `ton` under two rates was measured with M1-6: §4.6's receipt.)*
