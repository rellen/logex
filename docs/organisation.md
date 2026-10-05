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
holds them, by path (§4.3 and §4.10). The rest of the organisation, the configuration
file, shared globals and event tasks, is not yet implemented.** On 2026-09-28 the
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
| Continuous task | program with no task | close | *"There can be only one continuous task"* (import/export ref., ch.14, p.313). That it runs at the lowest priority is **from memory** |
| Periodic task | TASK with INTERVAL | close | Priority *"(1...15)"* in the import/export reference (p.313). The general instructions reference says *"Valid values 0...15."* (TASK object, p.276). Neither says which end is higher |
| Event task | TASK with SINGLE | partial | The conventional family has a fixed list of hardware and software triggers. IEC has one Boolean rising edge |
| Watchdog, overlap count | none | none | "watchdog" occurs zero times in either edition. The family counts overlaps: *"The number of times that the task was triggered while it was still executing"* (general instructions ref., TASK object, p.275) |
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
| TASK, event | `task trip single estop priority 0` | per task: last SINGLE value | M2-6 |
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
maintained e-stop contact is: a 10 ms pulse never reaches `m2`.)*

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
  a program's `warnings` sees one program, never two instances. §4.10, M2-4.)*
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
  2147483647 ms, §4.10, and a priority at 65535, decision 37.)*
- **Events.** A `single` source must be a bool global. *(logex restriction. IEC's
  `data_source` also takes a constant, a program output or a direct variable, B.1.7,
  p.158.)*

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

**Globals shared by name.** `var_external estop bool` in `motor.ld` binds to the
configuration's `var_global estop bool` (Ed 2 §2.4.3). During a scan it reads and writes
the global directly. Use it for what every instance shares, such as an e-stop. Per-instance
wiring stays a connection. A program that writes a `var_external` bound to an input point
is an error, so `%Logex.Program{}` records which tags it writes. M1-3's lowering already
knows each operand's write access. *(Milestone 2's design: which tags a program writes
is a public function over its IR, B5's one walk, not a field of `%Logex.Program{}`; §4.10,
M2-4.)*

**Loading.**
- `Logex.Configuration.compile(name, source, %{"motor" => program, …})` is the pure seam:
  compiled types in, `{:ok, config}` or `{:error, [%Logex.Diagnostic{}]}` out, and the
  core does no file I/O.
- A convenience loader resolves `motor` to `motor.ld` beside the `.logex`. *(Milestone
  2's design: through the one loader M2-5 lands for function blocks, decision 34, with one
  memo for the whole configuration. M2-5 landed it on 2026-10-04, inside
  `Logex.compile_file/1`, one memo a call.)*
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
simulated device.

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
   visitor).
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
budget in the core: rung evaluations per scan.

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
  task runs an instance; §4.10, M2-6.)*
- A `now` that goes backwards is an error, never a negative `.acc`. *(Landed with M1-5:
  `Logex.Runtime.call/4` raises `ArgumentError` for a `%Scan{}` earlier than the
  instance's clock, and `scan/3` for a negative elapsed time.)*

**Deviations from IEC task semantics, labelled.**

| IEC | logex | Why |
|---|---|---|
| A task-less program is re-scheduled *"as soon as its execution terminates"* (rule 4) | once per cycle | In zero logical time, rule 4 is an infinite loop. The runner paces cycles. MatIEC also runs unbound instances once per tick |
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
value or raises `ArgumentError` with that reason.)*

`scan/2` and a one-line configuration must give identical outputs for the README program.
A test pins that, or the two runtimes drift apart. PLAN M1-5 defines `scan/3` as "n
scans"; the elapsed-time `scan/3` above replaces that meaning, and M1-5 must say so.
*(It did, and the first five lines landed with M1-5 on 2026-09-29, `scan/2` returning
`{outputs, state}` like `call/4`. `restart/3` keeps the var_inputs because they are the
host's input image, which a configuration's copy-in refreshes every scan anyway: that is
what keeps `scan/2` and the one-line configuration in agreement across a restart. Since
M1-6 it keeps only those whose values fit their types, which a recompile of the same name
may have changed.)*

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
warns that `.` in the lexer is safe only while there are no float literals.

### 4.8 Reserved words, by file kind

| File kind | Reserved (in any case) |
|---|---|
| `.ld` program | the mnemonics (`cal` and `ton` among them); `var var_input var_output bool dint` (M1-3); `var_external` (M2-4) |
| `.ld` function block | as a program, plus `function_block` (M2-5, landed) |
| configuration (`.logex`) | `task interval single priority program with var_global at bool dint`; later `var_config` |

A `var_external` name must be legal in both kinds, because it is declared again as a
`var_global`.

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
program instance that holds the block would need a write path out of a body.

### 4.9 Changing a running controller (online edit)

**Decided 2026-10-01** (§7, decisions 15–20); **OE-1's design, the edit of one program
instance, recorded the same day** ("OE-1's design" below; decisions 21–29), **and landed
the same day as `Logex.Edit`** (`PLAN.md` OE-1). The brief:
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
   Milestone 2, so the whole configuration is a candidate from OE-2.)*
2. *Test.* The candidate runs and the original is kept. The state is shared, moved to the
   candidate's shape by the rules below, and nothing is pruned.
3. *Untest.* The original runs again over the same state, moved back. Test and untest may
   repeat.
4. *Assemble.* The original is dropped, and state the candidate no longer declares is
   pruned.
5. *Cancel.* The candidate is dropped, from accept or after an untest.

Every switch happens between two scans, and from M2-1 between two cycles. *(Changed
2026-10-02 by Milestone 2's design, §4.10: a configured plant is not edited until OE-2, so
a switch between two cycles is OE-2's.)* The conventional family's documents do not say
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
below says.)*

**Refused while running.** A restart, which may keep values by name, is the way to make
these changes:
- the type of a tag or a member;
- located I/O and devices: CODESYS, Siemens and Beremiz refuse a device change while
  running, the conventional family allows some within limits, and logex binds devices
  only at start (§4.5);
- moving a program instance to another task, which the conventional family refuses in Run
  mode; and adding or removing a task, until its rule for that is verified (§8);
- the members of a function block type, until M2-5 brings the nested migration: copy the
  members that match by name and type, as CODESYS does, and initialise the rest. *(Changed
  2026-10-02 by decision 31: M2-5 brings the migration, and a member whose type changes
  is refused, as a tag's is, not initialised. The members that match by name and type
  are copied, by path; a member added starts at its initial value. That copy is what
  Beremiz's hot swap states; the CODESYS help pages read do not say it. Landed with M2-5,
  2026-10-04, for the edit of one program instance.)*

Allowed while running: rungs; adding and removing tags, instances, globals and
connections; a tag's section, its value kept (decision 25); and a task's interval and
priority, which the conventional family lets logic write while it runs. *(A changed
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
  task's trigger is M2-6's)*
- one checked constructor, which the configuration file's reader feeds; *(met:
  `Logex.Configuration.check/1`, which `new!/1` and `start/1` run; M2-2's reader is to
  feed it)*
- `start/1` builds each instance through the same constructor as `Runtime.instance/1`,
  so an instance's `first`, its one-shot block list and any field it gains later cannot
  drift between the two (OE-1; fix F14 in §7); *(met)*
- `%Logex.Runtime{}` is opaque, and its configuration changes only through the API;
  *(met: its type is `@opaque`, and nothing in M2-1 changes its configuration, so a
  configured plant is not edited until OE-2)*
- one copy of each global's value; *(met for M2-1's globals, one value each in the
  resource; M2-4's `var_external` keeps it by merging the global in around each scan)*
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
  each instance (fix F5). In OE-1 each instance takes its own edit. A report names a tag;
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
  change (decision 25), and neither is a changed initial value (decision 29). A warning in
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
  detected until OE-2's configuration carries a generation counter. A plain swap stays in
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
| Initial values (decision 29) | A bool or dint both programs declare, of one type, whose initial value (as `Program.initial_env/1` gives it) differs keeps its running value; the new one applies when a restart next starts it. Not reported where a rule above started it, nor for a var_input of the program started, whose value a restart keeps | `{:initial_changed, n, {old, new}}` |
| `now` and `first` | Never touched, so no switch makes a scan first | — |

**One-shots (decision 21; fixes F2, F3, F7, F9).** No switch writes a storage bit: a bit
armed by writing 1 echoes into any rung that reads it. Instead `%Logex.Instance{}` gains
`ons_blocked`, the storage bits its next scan blocks. The runtime gives that one scan a
map of the listed bits in `%Logex.Scan{}`, built once for the scan, and `ons` looks its
bit up in it as it reads `first`: an `ons` whose bit is listed passes no power, and still
writes its bit. A scan empties the list, and so does a restart. *(Changed 2026-10-02 by
decision 32: from M2-5 a scan keeps listed each bit inside a function block instance whose
body it did not run, under a false `cal` or none, and a switch after it lists that bit
again where the program it starts still has the `ons`. At the top level every rung runs,
so a scan still empties the list there. Landed with M2-5, 2026-10-04: a `cal` records
that its body ran, and the scan takes the record out.)* A switch lists:
- each `ons` of T that is new, or whose rung differs with line numbers ignored, against
  the program that last scanned;
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
| `:dn_drops`, `:dn_rises` | `{acc, preset}`: what `.dn` does at the next scan with its rung true, a negative `.acc` counted as 0 | a switch |
| `:resumed` | the milliseconds not caught up | a switch |
| `:resume_undone` | the milliseconds of the resume this edit's last switch made, which `last` moves back by | a switch |
| `:ons_blocked` | the storage bit's value, unchanged | a switch |
| `:initial_changed` | `{old, new}` initial values; the running value is kept | a switch |
| `:held` | for an output the program that runs next still shows, the state's value, what its next scan gives, which can differ from what the point holds until then; otherwise the value the point last received | every step |
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
- a var_input a switch makes live is reported as `:input`, because its value is the
  host's;
- at the first test, a tag the candidate adds, or one whose value does not fit its type,
  starts at its initial value over what a plain swap left;
- a kept bool or dint whose initial value changed keeps its value until a restart, and
  is reported as `:initial_changed`, except one a start rule starts, at its new initial
  value, and a var_input of the program started, whose value a restart keeps: neither is
  so reported;
- M2-6 will add an event task's trigger.

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
no Milestone 2 commit depends on them.

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
    `{:int_lit, line, n}`, where `n` is a non-negative integer; or `{:branches, legs}`
    with at least one leg, a leg being a list of elements, possibly empty;
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
  reached; it is kept, and documented, not deleted.
- `Logex.Tag.new!/4` refuses any initial value on an instance, with the message a
  declaration line gets. The `%{"pre" => ms}` map M1-6 allowed is withdrawn: where a `ton`
  runs the timer, its preset silently replaced the map, and where none does, no text could
  give that `.pre` (decision 24). `new!/4` also refuses a negative initial value, in the
  declaration line's style, until a negative literal lexes.

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
instance per level, or no blocks, nothing changes.)* Two tests in reductions keep accept
and every step linear (fix F16; CONTRIBUTING.md, "Test a pass over the program for
growth"): accept, test, untest, test and assemble at 500 and 2,000 of each tag, and at 500
and 8,000 levels of nesting.
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
  A seeded property in `printer_test.exs` breaks a generated tree at any one node and
  expects only `ArgumentError`.
- `runtime_test.exs`: the exact public surface, `Logex.Edit`'s and `Logex.Parser`'s
  included, the fields of `%Logex.Instance{}` and `%Logex.Scan{}`, and the messages of the
  block list and of `switched`.
- *(M2-5, landed 2026-10-04.)* `function_block_test.exs` holds a test per rule of the
  edit of a program that holds function blocks, by path (decisions 31 and 32), among them
  a block frozen by a false `cal` across a switch, and its growth tests;
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

### 4.10 Milestone 2's design (designed 2026-10-02)

**Designed 2026-10-02; M2-1 landed the same day (`PLAN.md` M2-1), and M2-5 on
2026-10-04 (`PLAN.md` M2-5); nothing else has.** A design pass spiked Milestone 2 in three
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
  `Logex.Edit` still edits a lone instance.

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
any value that is not the struct is.)*
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
  port of the checks (below).
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
  tasks only, not task-less instances, which a runner paces itself. An
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
  generation counter; M2-1 does not reserve it.
- *Not taken.* No `outputs` field on `%Logex.Program{}`, which would spare each scan its
  walk of the tags. Revisit it with the runner.
- *Cost.* A cycle and `next_due_in/1` are linear in the tasks declared, whatever is due;
  a queue by due time is the runner's to add if it is ever wanted. A refusal of many bad
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
  `ton`". `compile/3` and the configuration's loader are M2-2's, which is to give it
  there.)*
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
  (`Logex.Compiler.recompiled/3`), and must be exactly what that compile gives: its
  members, and its body's name, rungs, tag table and warnings. The one thing the text
  cannot give is the file a body was read from, which is kept: none, or a path to a file
  named after the block, which stamps each warning. So a rung edited into another that
  text could say, a tag table edited into one declaration lines could give, a source text
  edited with its body left as it was, or a file that is no such path, is refused where
  it is given; a source text that gives that very body, a comment more, is the type a
  compile gives for it. A type with no source text, which only
  `Logex.Compiler.instructionize/3` gives, a block whose members are declared from Elixir
  among them, has none to compile again, and is refused where it is given too, as
  `Logex.compile/2`'s doc asked of a type given. The shape check is gone from `user?/1`:
  `Logex.Compiler.lowered?/1` stays the definition of a compiled body, which a type
  given has, but nothing calls it on the way in. A compile given a type took 1.19x the
  reductions it took before for one block of 200 rungs, and 1.31x for a chain of 200
  types; both stay linear.)*
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
  a held type that holds instances carries no table of its own.)*
- *Declarations.* Members declared from Elixir come first in `cal`'s operand order, by
  name, then the declaration lines in order. The uses of a declaration whose type is
  unknown are excused, as a recursive declaration's are, so a misspelled block name gives
  one message; this lands in its own commit, after M2-5. *(Landed as M2-5's sixth commit,
  before its documents, a departure from "after M2-5" made so that the documents commit
  describes it with the rest: a line given the unknown-type message, or refused as
  recursive, excuses every use of its own name, as written; a line refused for another
  reason excuses nothing.)* *(Since decision 54, a block whose members are declared from
  Elixir, which only `Logex.Compiler.instructionize/3` gives, has no source text to
  compile again, and is no type a compile or `Logex.Tag.new!/4` takes: the order above
  holds for its members, but only a block's text gives a type to declare instances of.)*
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

**M2-2 · The configuration file, task-less.**
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

**M2-3 · Periodic tasks in text.**
- `task <n> interval <ms> priority <p>` and `with`. A task's inputs come in IEC's order,
  `single`, `interval`, `priority`, each once. A priority is 0 to 65535 (decision 37),
  and the `priority` stanza says that one vendor family numbers the other way.
- *Warning:* a task that runs no instance.
- *Done-when.* "Cycled every 10 ms from 0 to 990 ms" replaces "driven for one simulated
  second".
- Its documents state decision 40's rule, which OE-2 builds.

**M2-4 · Shared globals.**
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
    `var_external single` among the names it breaks;
  - the two warnings go through M2-2's warnings pipeline, which `start/1` never reads,
    with each connection's instance found through an index made once, so checking stays
    linear in the instances;
  - "one copy" is pinned by a test that looks inside the resource (decision 49).

**M2-6 · Event tasks.**
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
    tests, one instance writing a global that another copies to an output point;
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
| Wall-clock runner, `Logex.IO` adapters, watchdog | target, after Milestone 2 | Outside the pure core. Nothing in M2 blocks them. A queue of tasks by due time, if a plant with many tasks wants one, is the runner's (§4.10) |
| Restarting one program instance inside a resource | not adopted (Milestone 2's design, §4.10) | `restart/2` restarts the whole resource (decision 38). Restarting one instance would be another rule for the input image and the tasks, for a need no decided text states |
| `var_external` in a function block's file | refused (Milestone 2's design, §4.8) | A deliberate, reversible departure from IEC: a block takes a global through a var_input operand |
| VAR_CONFIG, RETAIN / warm restart, forcing | target | VAR_CONFIG: when two instances need different internal initial values, and with it a warning for a global something reads and nothing writes (§4.10). RETAIN: on M1-5's `restart/3`, which landed without it (`:warm` is `:cold` until then). Forcing: a force map applied after the input latch and before the output return, in `cycle/3` |
| VAR_ACCESS; a host write path | deferred | VAR_ACCESS serves IEC 61131-5 communication services. `Runtime.get/2` reads by the same path shape. A host write, if wanted, is limited to unlocated globals |
| STRUCT, arrays (data hierarchy) | deferred, as a named later stage | Independent of the organisation model. A TON instance is logex's first structured value, and M1-6's nested state is what a STRUCT will reuse |
| Namespaces, CLASS, METHOD, INTERFACE (Ed 3) | deferred | These are library and module tools, not runtime structure |
| VAR_IN_OUT, VAR_TEMP, CONSTANT, user FUNCTIONs, `T#` literals | deferred | Each gets its own naming survey. Integer ms stays |
| IEC textual paste-compatibility (`END_*` blocks, `:=`, `;`) | not adopted | logex is a dialect (`PLAN.md` §5) |
| Online edit (a new type, instances keep their state) | **OE-1 landed 2026-10-01** (§4.9): the staged edit of one program instance, `Logex.Edit`; OE-2, a configuration's, after Milestone 2, so a configured plant is not edited until OE-2; the edit of a program that holds function blocks (decisions 31 and 32) landed with M2-5 on 2026-10-04 | Instance state stays keyed by declared tag name, which is what lets an edit move it by name. A *plain swap*, a recompile of the same name scanned over a kept instance with no edit, stays in the contract (decision 26) and does what it did before OE-1, since a state's values are not checked each scan: the instance keeps its values until a restart. So it keeps its old `.pre` under a changed preset; a tag the recompile adds reads 0, not its initial value, so an added timer starts at a `.pre` of 0 and is done at its first true scan; a tag whose type it changes keeps its old value, so a timer recompiled as a `var_output` gives its map as an output; and an `ons` it adds fires on its first scan if its condition is already true (`end_to_end_test.exs` pins all but the type change). A restart puts the values right, keeping only the var_inputs whose values fit their types. `Logex.Edit` moves the state by rule instead: a switch moves `.pre` where it still holds the old preset, starts what is added at its initial value, at the first test restarts a value that does not fit its type, and blocks an added or changed `ons` for one scan; accept refuses a type change. |

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

**M2-2 · The configuration file, task-less.**
- `.logex` lines: `var_global` (plain and located at `<dev>.i|q.<n>`), `program <inst>
  <type>`, and connections.
- The §4.4 checks, and `Configuration.compile/3` with a loader. *(Designed 2026-10-02:
  the checks land with M2-1, on data, and M2-2 asserts each again from source and ports
  its own into M2-1's `check/1`; the loader is M2-5's, decision 34.)*
- Reserves `program var_global at bool dint` in `.logex`.
- Adds `configuration_test.exs`. *(M2-1 added it on 2026-10-02, pinning every check from
  data; M2-2 asserts each again from source.)*
- *Acceptance: two instances of one `.ld` program type, wired in a configuration file to
  different input and output points, run for N cycles from one input image and keep
  independent state; a mis-wired, unknown, undriven-input or mistyped connection is a
  located diagnostic naming its file and line.*

**M2-3 · Periodic tasks in text.**
- `task … interval … priority`, and `with`.
- Reserves `task interval priority with` in `.logex`.
- *(Designed 2026-10-02: a priority is 0 to 65535, decision 37; the acceptance is
  "cycled every 10 ms from 0 to 990 ms"; and its documents state decision 40.)*
- *Acceptance: the §4.4 plant without its event task, its `motor` the §4.2 one plus `var
  t1 ton` and a rung `xic motor ton t1 5000` (so no `estop`, `var_external` or `cal`, which
  arrive with M2-4 and M2-5), driven for one simulated second, runs `m1` 100 times and
  `m2` 20 times, and each instance's `t1` times against the one clock.*

**M2-4 · Shared globals.**
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

**M2-6 · Event tasks.**
- `single`, with the §4.6 edge rules, and `single` combined with `interval` *(decision
  39)*.
- Reserves `single` in `.logex`.
- *Acceptance: an event task triggered from an input point runs once per rising edge,
  before lower-priority tasks due in the same cycle, and runs in cycle 1 if its trigger is
  already true.*

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
from the check of M2-5's fixes. All fifty-four are kept with their options so the reasons
stay with them.

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
    outputs is the alternative. *Recommend zeroing; decide with the runner.*
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
    every rung runs, so nothing changes there; inside a function block a false `cal`
    leaves its `ons` unrun.)*
22. **Inputs across a switch (E2):** report each var_input that becomes live,
    `{:input, name, value}`, and each one the running program no longer reads,
    `{:unread, name, value}`, the host sending the real value of each live one before the
    next scan; or require those inputs as an argument of test and untest. *Recommend
    report*, the input side of decision 20. OE-2's copy-in will then make it automatic.
    Adopted.
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
    silently, and the timer was done 10 ms into a 5000 ms preset. Adopted.
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
    initial value and, by decision 24, the preset map.
29. **A changed initial value of a kept bool or dint (E9):** it keeps its running value
    either way, and the new value applies at the next restart. Say nothing, or report it
    at every switch as `{:initial_changed, name, {old, new}}`, sorted with the rest of the
    report. *Recommended saying nothing.* The maintainer chose to report it. *As built
    (§4.9): not at every switch. A tag a start rule starts, at its new initial value, is
    reported as `:added`, or as `:input` where it is a var_input, not as
    `:initial_changed`; and a var_input of the program started is not reported as
    `:initial_changed`, since a restart keeps its value, so the new one never applies. It
    is still reported as `:input` (decision 22).*

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
    both. Adopted.
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
    Adopted.

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
    port of the checks; until then M2-1 reports each use.
43. **An instance whose program type an edit changes (OE-2):** a remove plus an add, the
    old instance pruned and the new one started by `Runtime.instance/1`, both reported;
    or a refusal, as a tag's type change is refused. *Recommend the remove plus an add,*
    since instances may be added and removed while running and state is keyed by name.
    Adopted.
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
    documents what they do not say. Adopted.
47. **A write through a `var_external` and a connection's copy-out to one global, in one
    scan (M2-4):** the copy-out lands last, after the `var_external` is split off, as
    IEC and MatIEC write an external during the body and `=>` after it; or the write
    through the `var_external` lands last; or a global one instance both writes through a
    `var_external` and drives by a connection is refused. *Recommend the copy-out last,*
    stated in `Logex.Runtime`'s cycle steps and in the warning's words; a refusal would
    refuse what IEC allows and §4.4 makes a warning. Adopted.
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
    not. Adopted.
49. **How "one copy of each global" is pinned (M2-4).** It cannot be seen through the
    public API: reverting any of the three places that drop a global from an instance's
    state left the spike's whole suite green. Pin it by a test that looks inside the
    opaque `%Logex.Runtime{}` on purpose, as the plain-data test does; or only through
    OE-2's switch, when it lands; or let the state keep a stale copy, overwritten at
    every merge. *Recommend the test that looks inside:* the drops are one line each and a
    refactor can lose them, and decision 45's switch depends on them. Adopted.
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
    runner's concern, and the runner is not designed. Adopted.
51. **A late host's edge cycle (M2-6).** For a task with `single` and `interval`, the
    periodic due times that came between the last cycle, whose sample was 0, and this
    one, whose sample is 1: skipped and not counted, as decision 39 reads by this cycle's
    sample; or counted as missed periods. *Recommend skipped, not counted.* It hides a
    host's lateness only while the trigger is 1, when rule 2 owes no periodic run anyway.
    Adopted.
52. **A late host's falling cycle (M2-6).** A periodic due time that came while the input
    image still held 1, in a cycle that samples 0: it runs, since the sample decides; or
    it is skipped, since the image held 1 until this cycle's merge. *Recommend it runs:*
    one rule for every source of trigger, since only the sample is known both for a
    trigger written by logic and for an input point. Adopted.

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
- Ed 4 (2025) was not read beyond its publisher preview, so **its organisation clauses are
  unverified**.

**The conventional family.**
- The import/export reference, Sept 2025: ch.6 (tags), ch.8 (programs), ch.14 (tasks) and
  ch.15 (parameter connections).
- The general instructions reference, Sept 2025: the TASK object for GSV/SSV, TON
  (its TIMER structure and prescan), ONS, and a CPS example.
- The ladder-diagram programming manual, July 2022, ch.1.
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
  `b5d4135`.
- Beremiz `editors/ResourceEditor.py`, the task editor, whose Interval cell is editable
  only when a task's triggering is cyclic and whose Single cell only when it is an
  interrupt (decision 39), at `5e3a749`.

**CODESYS, for Milestone 2's design.**
- Its online help, "Object: Task", read on 2026-10-02: a priority of 0 to 31, 0 the
  highest (decision 37).

**Online edit (§4.9), read on 2026-10-01.**
- The conventional family: its quick start (Oct 2009), pp.120–124, for the edit cycle and
  the three output sentences (verified again on 2026-10-01); its current online-editing
  help (pending, accept, test, untest, assemble); its *design considerations reference* (Sept 2025), p.65
  (partial import online, and rescheduling a program refused in Run mode) and pp.85, 88
  and 91 (a tag's data type, or an existing user-defined type, changed offline only); and the TASK object of its general
  instructions reference, whose rate and priority logic may write at runtime.
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
    preempted by periodic and event tasks;
  - that a lower priority number is higher there;
  - that an unscheduled program does not run;
  - that its logic may `move` into a timer's `.pre` and `.acc`;
  - what its controller does to outputs on a watchdog fault.
- **Inferred, not stated by the sources:**
  - that the conventional family has no program type/instance split, inferred from *"A
    program can be scheduled under one task only"*;
  - the timer member mapping `.pre`→PT, `.acc`→ET, `.dn`→Q.
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
