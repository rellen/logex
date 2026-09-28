# Program organisation: the IEC software model, in logex's dialect

**Status: decided, not yet implemented.** On 2026-09-28 the maintainer adopted the
direction in §1 (IEC's software model, in logex's dialect: the hierarchy, task-style
execution and I/O mapping), deferred routines, and took every decision in §7 as
recommended. `PLAN.md` records them: §5 the direction, M1-3, M1-5 and M1-6 the §6.1
changes, and §3's Milestone 2 the §6.2 items. The syntax below is decided, but each new
word still gets its `docs/naming.md` stanza before its code lands, and a stanza may still
change a spelling. It was written against `37b7932`; the rationale stays here, and the
plan of record is `PLAN.md`.

## 1. Why this document, and the direction

The maintainer's brief:

> I just want to make sure we are heading in a direction that implements a lot of the
> things in IEC (with a logex flavour) because we need the hierarchy and the different
> task-style execution, IO mappings, etc.

**What logex has today.** A `.ld` file is one routine. `evaluate/2` runs it once against a
flat `env`. There is no program name, no instance, no task and no scan loop. There is
nothing to mark which tags are physical inputs (`PLAN.md` M1-6). Milestone 1 adds typed
declarations (M1-3), a compiled `%Logex.Program{}` with a runtime (M1-5), and timers with
a scan loop (M1-6). None of those items says what sits above one program.

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
  - the *ladder-diagram programming manual* (July 2022).
- The spikes behind this design ran on copies of `37b7932`, on Elixir 1.20.4 / OTP 28. They
  are not in the repository. Their output is quoted as receipts and pins nothing.

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
| standard FB instance | `var t1 ton`, then `ton t1 5000` on a rung, and `t1.acc` | nested in the instance: `t1` | M1-6 |
| program instance, no task | M1: `Logex.Runtime.scan/2`. M2: `program m1 motor` | one state per instance | M1-5, M2-2 |
| CONFIGURATION, single resource | one `.lcf` file (the extension is a placeholder) | globals, instances, task clocks | M2-1, M2-2 |
| VAR_GLOBAL, located or not | `var_global k1 bool at panel.q.0`, `var_global estop bool` | the configuration | M2-2 |
| connections (Table 49 8b/9b) | `m1.start pb_start_1`, `m1.motor k1` | copied in and out per scan | M2-2 |
| TASK, periodic | `task fast interval 10 priority 1` | per task: next due time | M2-3 |
| VAR_EXTERNAL | `var_external estop bool` in a `.ld` | the configuration's global | M2-4 |
| FUNCTION_BLOCK type and instance | a file headed `function_block seal`; `var s1 seal`, `cal s1 …` | nested: `m1.s1.run` | M2-5 |
| TASK, event | `task trip single estop priority 0` | per task: last SINGLE value | M2-6 |
| access path | `m1.t1.acc`, read by `Logex.Runtime.get/2` | — | M1-6, M2 |

**Three rules hold from M1-3 onwards.**

1. **The compiled program is a named, stateless type.**
2. **Its state is one instance.** Instance state is a tree:
   - it maps each declared name to an integer, or to a nested instance (`t1`, `s1`);
   - M1-3's flat `%{String.t() => integer}` is a Milestone-1 fact, not an invariant;
   - it is keyed by declared tag name. That is what later lets a new program type replace
     an old one while each instance keeps its state (online edit, deferred).
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

**A function block type** is a `.ld` file whose first line names its kind:

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
The de-energised `evaluate` clause is mandatory for both (CLAUDE.md).

**`cal`'s signature comes from the FB type, not from `@instructions`.**
- The operands are positional, in declaration order: the var_inputs, then the var_outputs.
  This is IL's non-formal CAL, Ed 2 Table 53 feature 1a, p.127:
  `CAL CMD_TMR(%IX5, T#300ms, OUT, ELAPSED)`.
- An arity or type error names the formal, for example
  ``operand 2 of `cal s1` is `stop` (var_input bool)``.
- Two swapped bool operands still compile, which is the price of the positional form.
- `@instructions` and `naming_test.exs` stay the table of built-in mnemonics. The
  signatures of user FB types are built per compile.
- Reads of outputs such as `s1.run` work anywhere. Writes to an instance's members from
  outside it: reads anywhere, writes only to `.pre` and `.acc` (decision 9; M1-6).

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

### 4.4 The configuration

`plant.lcf` has two instances of one type on two periodic tasks, an event task, located
I/O and a shared global:

```
// plant.lcf -- two conveyors, one program type (motor.ld)
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
the trip, reading the output points back, which is allowed.

**Line shapes.** Every line is a keyword line, like M1-3's declarations, or a connection
line, which starts with a qualified name. Indentation is cosmetic.

| logex line | IEC | Notes |
|---|---|---|
| `task <n> interval <ms> priority <p>` | `TASK n (INTERVAL := t#<ms>ms, PRIORITY := p)` | PRIORITY is mandatory in IEC's grammar: `'PRIORITY' ':=' integer ')'` (Ed 2 Annex B.1.7, p.158; Ed 3 Annex A, p.226). So logex requires it. 0 is the highest |
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

**Checks.** All are decided. Each is marked as IEC's or logex's.

- **Input points.** An input point takes no initial value. Nothing may drive it: no output
  connection, and no write through a `var_external`. *(logex)*
- **One driver per sink.** A global or output point has at most one connection driving
  it. That is an error, because it is static and checkable. Two instances that write one
  global through `var_external` are only visible in the IR: that is a warning, in M1-5's
  `warnings:` channel. *(logex. IEC forbids neither.)*
- **Every var_input is connected**, to a global, a point or a constant. *(logex. No IEC
  rule on an unconnected program input was found.)* M1-3 gives a var_input no initial
  value, so an unconnected one would read 0 forever.
- **Types agree at both ends.** *(IEC for EXTERNAL/GLOBAL, Ed 2 §2.4.3; logex for
  connections)*
- **Only a var_input or var_output connects.** A `var` stays internal. *(logex)*
- **Unknown names.** An unknown task, program type, instance or member is a located
  diagnostic with a did-you-mean.
- **Tasks.** A task needs `interval` or `single`, and `interval` is at least 1. IEC reads
  INTERVAL 0 as "no periodic scheduling" (rule 2). MatIEC runs such a task every tick, so
  logex refuses the ambiguous case.
- **Events.** A `single` source must be a bool global. *(logex restriction. IEC's
  `data_source` also takes a constant, a program output or a direct variable, B.1.7,
  p.158.)*

A receipt: seven of the configuration spike's thirteen diagnostics for one deliberately
broken source, each line exact, pinned by no test:

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
knows each operand's write access.

**Loading.**
- `Logex.Configuration.compile(name, source, %{"motor" => program, …})` is the pure seam:
  compiled types in, `{:ok, config}` or `{:error, [%Logex.Diagnostic{}]}` out, and the
  core does no file I/O.
- A convenience loader resolves `motor` to `motor.ld` beside the `.lcf`.
- A constructor built from Elixir data runs the same checks, as `Tag.new!/4` does for
  M1-3.

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
   - **Event.** `single` is sampled once per cycle, and a 0→1 change since the last cycle
     makes the task due.
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

**Why not a per-instance `dt`?** A `dt` (time since the instance's last scan) equals the
per-timer formula only when the timer runs on every scan of its instance. A `ton` inside a
frozen `cal` (§4.3), or one a future `jmp` skips, loses the gap; both precedents catch it
up. Function blocks arrive in Milestone 2, so this cannot wait for `jmp`. This departs from
one reviewer, who preferred `dt` because it keeps a timer to its five public members; the
internal member costs one schema entry. Either way the increment is the actual time, not
the nominal interval: a 10 ms task stepped at 25 ms must still reach its preset on time.

**First scan.** M1-3's `initial_env/1` puts every declared tag at its initial value.
Extended to a timer, it clears `.acc`, `.dn`, `.tt` and `.en`, which is what the
conventional TON prescan does (general instructions ref., TON, p.134). `scan.first`
gives `ons` its settled behaviour, *"The storage
bit is set to true to prevent an invalid trigger during the first scan"* (general
instructions ref., ONS, p.73). `first` is per instance.

**Caveats to document.**
- A `ton` in an event-task program times across events. It should be an M1-5 warning.
- A `now` that goes backwards is an error, never a negative `.acc`.

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
Logex.Runtime.call(program, state, inputs, %Logex.Scan{}) :: {outputs, state}   # one scan: copy in, run, copy out
Logex.Runtime.scan(program, state) / scan(program, state, elapsed_ms)            # sugar: the implicit configuration
Logex.Runtime.start(config) :: rt
Logex.Runtime.cycle(rt, elapsed_ms, inputs) :: {rt, outputs, [event]}
Logex.Runtime.next_due_in(rt) :: non_neg_integer | :infinity                    # what the runner sleeps on
Logex.Runtime.get(rt, "m1.t1.acc")                                               # an access path, resource omitted
# event :: {:ran, task | :none, instance, now} | {:overlap, task, missed}
```

`scan/2` and a one-line configuration must give identical outputs for the README program.
A test pins that, or the two runtimes drift apart. PLAN M1-5 defines `scan/3` as "n
scans"; the elapsed-time `scan/3` above replaces that meaning, and M1-5 must say so.

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

No spike has yet run a real `ton` under two task rates. M1-6 owes that before this model is
called settled (§6.1).

### 4.7 One `.` token, three readings

PLAN §5's `QUALIFIED = {NAME}(\.({NAME}|{INT}))*` gives one lexer token. Position decides
what it means, and each wrong reading gets a diagnostic that names it:

| Reading | Where it is legal | Example |
|---|---|---|
| member of an instance or bit of a word | a `.ld` body | `t1.acc`, `s1.run`, `word.3` |
| instance path | a `.lcf` connection line; `Runtime.get/2` | `m1.start`, `m1.t1.acc` |
| location | only after `at` in a `.lcf` | `panel.i.0` |

A dotted name in a body that is not a declared member, such as `m2.fault` inside
`motor.ld`, is a located diagnostic, never a reach into another instance. PLAN §5 already
warns that `.` in the lexer is safe only while there are no float literals.

### 4.8 Reserved words, by file kind

| File kind | Reserved (in any case) |
|---|---|
| `.ld` program | the mnemonics (`cal` and `ton` among them); `var var_input var_output bool dint` (M1-3); `var_external` (M2-4) |
| `.ld` function block | as a program, plus `function_block` (M2-5) |
| `.lcf` | `task interval single priority program with var_global at bool dint`; later `var_config` |

A `var_external` name must be legal in both kinds, because it is declared again as a
`var_global`.

**This departs from IEC and from one reviewer**, who argued for reserving the Table C.2
words (`task program with at` …) everywhere, as IEC does (§2.1.3). logex reserves a word
for a different reason: to keep a line's reading unambiguous, as when `move src ote` must
not write a tag called `ote` (`PLAN.md` §5). That is a per-file-kind question. A program tag
named `task` or `with` appears in a `.lcf` only inside the qualified token `m1.task`.
Scoping by file kind breaks the fewest programs, and every keyword is still reserved in the
file kind that uses it. It also sidesteps an IEC inconsistency: Ed 2 Table C.2
(pp.163–164) lists TASK, WITH, AT and PROGRAM...WITH... but not INTERVAL, SINGLE or
PRIORITY, although §2.1.3 defines keywords by Annex B, which quotes all three as terminals.
Ed 3 has no keyword table.

Before the reservation lands, none of the configuration words is used as a tag in a
golden-record source, a test or `lib/`; they occur there only as English, in comments and
test names. Each commit must still name the words it reserves and the tag
names they break (CLAUDE.md step 2).

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
| Wall-clock runner, `Logex.IO` adapters, watchdog | target, after Milestone 2 | Outside the pure core. Nothing in M2 blocks them |
| VAR_CONFIG, RETAIN / warm restart, forcing | target | VAR_CONFIG: when two instances need different internal initial values. RETAIN: with M1-5's `restart`. Forcing: a force map applied after the input latch and before the output return, in `cycle/3` |
| VAR_ACCESS; a host write path | deferred | VAR_ACCESS serves IEC 61131-5 communication services. `Runtime.get/2` reads by the same path shape. A host write, if wanted, is limited to unlocated globals |
| STRUCT, arrays (data hierarchy) | deferred, as a named later stage | Independent of the organisation model. A TON instance is logex's first structured value, and M1-6's nested state is what a STRUCT will reuse |
| Namespaces, CLASS, METHOD, INTERFACE (Ed 3) | deferred | These are library and module tools, not runtime structure |
| VAR_IN_OUT, VAR_TEMP, CONSTANT, user FUNCTIONs, `T#` literals | deferred | Each gets its own naming survey. Integer ms stays |
| IEC textual paste-compatibility (`END_*` blocks, `:=`, `;`) | not adopted | logex is a dialect (`PLAN.md` §5) |
| Online edit (a new type, instances keep their state) | deferred | The constraint is recorded now: instance state stays keyed by declared tag name |

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

**M1-6 (TON, ONS, comparisons, scan loop).**
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
7. **Fix B8 (a lone CR) before any `.lcf` exists.** It would bite configuration files
   exactly as it bites programs.

### 6.2 Milestone 2: organisation (now `PLAN.md` §3, Milestone 2)

Each item surveys its own new words in `docs/naming.md` before its code lands, appending
the stanzas. Each lands green on its own. Every diagnostic is pinned by a test that
asserts whole diagnostic lists from source, like `validation_test.exs`. Each rule is
checked by reverting it (CLAUDE.md; PLAN §2·M0-4). For example:
- delete the one-driver check → a test fails;
- delete the input-point check → a test fails;
- drop priority ordering → a test fails.

**M2-1 · The scheduler, built from Elixir data. No syntax.**
- `%Logex.Configuration{}` with a pure, checked constructor.
- `Runtime.start/cycle/next_due_in/get`.
- Periodic and task-less instances, copy-in/copy-out, overlap events.
- *Acceptance: a configuration built in Elixir with a 10 ms task, a 30 ms task and a
  task-less instance, cycled for one simulated second by an injected clock, runs each
  instance exactly as often as its task dictates, in priority order; a late cycle yields
  one `{:overlap, …}` and no lost phase; the README program gives identical outputs through
  `scan/2` and through a one-instance configuration.*

**M2-2 · The configuration file, task-less.**
- `.lcf` lines: `var_global` (plain and located at `<dev>.i|q.<n>`), `program <inst>
  <type>`, and connections.
- The §4.4 checks, and `Configuration.compile/3` with a loader.
- Reserves `program var_global at bool dint` in `.lcf`.
- Adds `configuration_test.exs`.
- *Acceptance: two instances of one `.ld` program type, wired in a configuration file to
  different input and output points, run for N cycles from one input image and keep
  independent state; a mis-wired, unknown, undriven-input or mistyped connection is a
  located diagnostic naming its file and line.*

**M2-3 · Periodic tasks in text.**
- `task … interval … priority`, and `with`.
- Reserves `task interval priority with` in `.lcf`.
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

**M2-5 · User function blocks.**
- Needs M1-6 and B5 only, so it may move ahead of M2-1.
- `function_block <name>` files, `var s1 seal` instances, and nesting.
- `cal` with positional operands and the EN semantics of §4.3.
- Member reads, and the recursion diagnostic.
- The appended `cal` stanza.
- *Acceptance: a seal-in written once as a function block and instantiated three times
  in one program behaves as three independent seal-ins, `m1.s2.run` reads one of them, a
  false EN freezes only its own instance, and a recursive type, an unknown FB type or a
  `cal` of a non-instance is a located diagnostic.*

**M2-6 · Event tasks.**
- `single`, with the §4.6 edge rules, and `single` combined with `interval`.
- Reserves `single` in `.lcf`.
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
- CLAUDE.md's Key Files gets `configuration.ex` and `runtime.ex`, and its `evaluate`
  convention changes at M1-6.
- PLAN §5's organisation bullet carries the one-line summary: "a file is a POU type,
  state is an instance, a configuration instantiates, wires and schedules; no routines,
  no controller scope, no preemption."

---

## 7. Decisions

All fourteen were taken as recommended on 2026-09-28. They are kept with their options so
the reasons stay with them.

1. **Adopt this direction and Milestone 2's order** (M2-1…M2-6, with M2-5 free to move
   earlier). *Recommend yes.* Adopted.
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
   before M2-2, because a rename later is a migration.
4. **How an FB file declares its kind:** a required first line `function_block <name>`
   that matches the file name, or a second extension. *Recommend the first line.* It is
   IEC's word, and it keeps one extension for POUs.
5. **Connection spelling:** arrow-free `m1.start pb_start_1`, or IEC's `:=` / `=>`.
   *Recommend arrow-free.* It needs no grammar edit and matches M1-3's dropping of `:=`,
   and the direction is checked at both ends. `:=`/`=>` would cost two tokens and no golden
   entries. Decide before M2-2, or `.lcf` files will have two spellings.
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
   only to `.pre` and `.acc`, as the conventional family allows (from memory).*
10. **Reserved-word scope:** by file kind (§4.8), or IEC's everywhere. *Recommend by file
    kind.*
11. **Scheduling policies:**
    - PRIORITY required on every task, with 0 the highest;
    - ties go to the earlier due time, then declaration order;
    - missed periods are coalesced, counted and reported;
    - a SINGLE already true at start fires.

    *Recommend all four.*
12. **`cal` on a false EN:** writes nothing to its output operands. *Recommend yes*, which
    is IEC's "keep their states". The alternative, writing the frozen outputs again, does
    no harm but hides nothing either.
13. **Units:** `elapsed_ms` injected, `now` kept inside; `interval` in integer ms, not
    `t#`. *Recommend both.*
14. **What a watchdog fault does to outputs,** when the runner exists: stop scheduling,
    zero the output image once, report, and require an explicit restart. Holding the last
    outputs is the alternative. *Recommend zeroing; decide with the runner.*

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
- Ed 4 (2025) was not read beyond its publisher preview, so **its organisation clauses are
  unverified**.

**The conventional family.**
- The import/export reference, Sept 2025: ch.6 (tags), ch.8 (programs), ch.14 (tasks) and
  ch.15 (parameter connections).
- The general instructions reference, Sept 2025: the TASK object for GSV/SSV, TON
  (its TIMER structure and prescan), ONS, and a CPS example.
- The ladder-diagram programming manual, July 2022, ch.1.

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
  - any rule for an unconnected program input;
  - the meaning of W and D sizes for logex's `dint`, which does not arise under §4.5.
- **Absence claims are weaker for Ed 3.** Its text layer splits words ("ca nnot"), so
  "occurs zero times" there is weaker evidence than for Ed 2.
- **`.lcf`:** whether the extension clashes with an existing tool.
- **Not yet measured:**
  - a real `ton` under two task rates (§6.1);
  - the §4.4 diagnostics under any test. They are spike output only.
