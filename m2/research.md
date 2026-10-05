# Milestone 2: the external facts, checked against primary sources

Label: inv-sources. Written 2026-10-02 against logex `main` at `47319f7`. Nothing in
`/home/user/logex` was changed, and no spike was run, so there is no patch. Every source
read is kept under `scratchpad/m2/inv-sources-src/` (section 10).

**How to read this.** Each fact has an id (`EXT-`, `IEC-`, `MAT-`, `OPL-`, `CDS-`, `CNV-`,
`SIE-`), the claim, an exact quote, where the quote is, and a verdict against what
`docs/organisation.md` (cited as "org §x, line n") or `PLAN.md` says:

- **Confirms**: the source says what the repository says.
- **Contradicts**: the source says something else; the repository text needs a change.
- **Extends**: the repository says nothing about it, or less, and M2 needs it.

"Unverified" means no primary source was found. "From memory" means the same. Page numbers
are the document's own printed numbers; in every PDF used here they matched the PDF page
except where a line says otherwise.

**The conventional family.** Its documents are cited by title (the family's name removed),
publication number, date and page. Their URLs are withheld, because every one names the
vendor; this follows `docs/instruction-sets.md` §9. Each can be found by publication number
in the vendor's literature library. Quotes from them have been checked to name no product.

---

## 0. The findings that change something

| Id | Finding | Verdict | Where |
|---|---|---|---|
| EXT-1..6 | `.lcf` is taken: CodeWarrior linker command files, CudaText lexers, Loon proxy configs, Archicad libraries; 5,264 files on GitHub | Contradicts the hope in org §8 line 1703; settles it | §1 |
| EXT-8 | Five extensions are free on every registry checked: `.ldcfg`, `.ldcf`, `.lxcf`, `.lxcfg`, `.ldcon` | Extends PLAN M2-2 line 1314 | §1 |
| EXT-7 | logex's own `.ld` is GNU's linker-script extension on GitHub and fileinfo.com | Extends | §1 |
| IEC-9 | Ed 3 changed EN/ENO rule 3: with ENO false, outputs are "Implementer specific", not "keep their states" | Extends org §4.3 (cites Ed 2 only) | §2 |
| IEC-10 | Ed 3's "external implementation" example is exactly decision 12: nothing copied in, the output assignment skipped | Confirms decision 12 | §2 |
| IEC-11, IEC-12 | IEC forbids reading an FB **input** from outside (Ed 2 Table 32, Ed 3 Figure 13); Ed 3 allows **writing** one from outside, taking effect at the next call | Extends org §4.3 line 328 and PLAN M2-5 line 1352 (open question) | §2 |
| IEC-14 | IEC does give an unconnected program input a rule, by two clauses together: it keeps its initial value | Contradicts org §4.4 line 434 and §8 line 1699 ("not found") | §2 |
| IEC-6 | Ed 3 makes writing a VAR_INPUT an error outright | Confirms logex's refusal (`lib/logex/compiler.ex:720-723`) | §2 |
| MAT-2 | MatIEC ignores INTERVAL when SINGLE is given, and Beremiz's editor cannot even express both | Extends M2-6 (PLAN line 1354): no free-software precedent for the combined task | §3 |
| MAT-4 | MatIEC runs programs in declaration order across all tasks, never by priority | Extends org §4.6 line 587 | §3 |
| MAT-7 | MatIEC copies FB inputs in on a false EN, and copies the frozen outputs out again | Extends decision 12 (the alternative it rejected is MatIEC's) | §3 |
| MAT-9 | Beremiz, when late, advances the tick past missed periods and runs once, so a task whose due tick was skipped does not run at all that round | Extends org §4.6 line 592 | §3 |
| OPL-2 | OpenPLC times on nominal ticks, not elapsed time: a late cycle stretches every timer | Extends org §4.6 line 638 (logex uses actual time) | §4 |
| OPL-5 | OpenPLC zeroes the output image once on stop (but not its 32- and 64-bit outputs) | Extends decision 14 (line 1493): a precedent | §4 |
| CDS-6 | CODESYS refuses any task-configuration change online | Confirms decision 19's description of CODESYS (line 1507) | §5 |
| CDS-7 | CODESYS allows I/O mapping changes online | Extends org §4.9 line 861 ("refuse a device change") | §5 |
| CDS-8 | CODESYS's help does not say it copies FB members "by name and type" | Contradicts the attribution at org §4.9 line 867 (unverified as stated) | §5 |
| CNV-2..4 | The conventional family: the continuous task is lowest; a lower number is higher; same-priority tasks time-slice | Confirms two from-memory items in org §8 (lines 1688-1690) and org §3 line 165's open point | §6 |
| CNV-9 | Its major fault sends outputs to each module's configured fault state | Verifies a from-memory item (org §8 line 1693); informs decision 14 | §6 |
| CNV-13 | On a false rung its add-on instruction copies inputs in and writes no outputs | Extends decision 12 (a third behaviour) | §6 |
| CNV-14 | A one-shot inside a disabled add-on instruction never sees its rung go false | Extends PLAN M2-5 line 1352 (`ons` in a frozen block) | §6 |
| CNV-17 | Existing add-on instructions are edited offline only | Confirms org §4.9's refusal of FB member changes online | §6 |
| CNV-19 | Logic may write a timer's preset, which the timer never rewrites | Verifies a from-memory item (org §8 line 1692) | §6 |
| SIE-1 | Siemens numbers priorities the other way: 1 lowest, 26 highest | Extends; matters for the `priority` naming stanza | §7 |

---

## 1. The `.lcf` extension (org §7 decision 3, line 1457; §8 line 1703; PLAN M2-2 line 1314)

**Method.** For each extension: fileinfo.com, filext.com and file-extension.info (an HTTP
404 is "not listed"); GitHub code search through the GitHub API (`extension:<ext>`, which
counts indexed files on default branches only, so a count is evidence, not a census);
GitHub Linguist's `languages.yml` at `5fbdfcb` (the registry GitHub uses to recognise a
language by extension); and a web search for the quoted extension. Run on 2026-10-02.

**EXT-1. CodeWarrior (NXP, formerly Freescale) linker command files use `.lcf`, and its
linker requires it.**
> "Linker command files must end in .lcf. They may be simply added to the link line"

*CodeWarrior Development Studio for Power Architecture Processors Build Tools Reference
Manual*, CWPABTR Rev. 10.x, 06/2015, §2.4 "File Name Extensions", p.44,
https://www.nxp.com/docs/en/user-guide/CWPABTR.pdf. Also NXP AN4498, *CodeWarrior Linker
Command File (LCF) for Kinetis*: "Ensure you edit PK60N512_flash.lcf." (p.6),
https://www.nxp.com/docs/en/application-note/AN4498.pdf. This is embedded tooling, the
neighbourhood logex's users work in. **Contradicts** the hope that `.lcf` is free.

**EXT-2. CudaText and SynWrite (text editors) keep each syntax lexer in a `.lcf` file.**
> "Line comments: in lexer file data/lexlib/*.lcf."

`wiki/cudatext_plugins.wiki` at `66c8b2d`,
https://github.com/Alexey-T/CudaText/blob/66c8b2d57cc928abe322393404c246c50185c63c/wiki/cudatext_plugins.wiki;
its add-on manager lists lexers with `i.endswith('.lcf')` (`app/py/cuda_addonman/work_local.py`).
**Contradicts.** A logex `.lcf` opened in CudaText would be taken for a lexer.

**EXT-3. Loon, an iOS and macOS proxy client, names its configuration files `.lcf`.**
The example repository `Loon0x00/LoonExampleConfig` (README: "Loon example configuration")
ships `example2.lcf`, https://github.com/Loon0x00/LoonExampleConfig; GitHub code search
`extension:lcf Loon` finds 113 files. That `.lcf` stands for "Loon configuration file" is a
search engine's summary, **unverified**. **Contradicts.**

**EXT-4. Graphisoft Archicad's library container is `.lcf`, the only use fileinfo.com lists.**
> "An LCF file is a library container file that stores a complete hierarchy of libraries
> used by GRAPHISOFT Archicad, an architectural design program."

https://fileinfo.com/extension/lcf. file-extension.info and filext.com list it first too.
**Contradicts.**

**EXT-5. Further uses listed by one aggregator each, not checked elsewhere (unverified).**
filext.com (https://filext.com/file-extension/LCF): LoggerNet logger data, Camtasia
"Lipika Color Format", a *Command & Conquer: Generals* launcher setting, a Folio Views
infobase, an HP-95LX datacomm script. file-extension.info
(https://www.file-extension.info/format/lcf): "Norton Guides compiler - Linker Control
File". Prover's railway-signalling "Layout Configuration Format" is called LCF
(https://www.prover.com/lcf-layout-configuration-format/) but the page names no file
extension.

**EXT-6. Counts.** GitHub code search `extension:lcf`: **5,264** files on 2026-10-02 (the
first page: CodeWarrior `linker.lcf`, CudaText lexers, Loon configs). Linguist registers no
language for `.lcf`. So `.lcf` would not be highlighted wrongly on GitHub, but it is
already four other tools' file.

**EXT-7. logex's existing `.ld` is already GNU's linker-script extension.** Linguist
`languages.yml` at `5fbdfcb`, line 4411: `Linker Script:` with extensions `".ld"`,
`".lds"`, `".x"`; fileinfo.com, https://fileinfo.com/extension/ld: "An LD file is a script
written in the GNU "linker command language."" GitHub will colour a logex `.ld` as a linker
script. The `.ld` choice is settled and this pass does not reopen it; but it means a
configuration named `.lcf` would pair two linker-file extensions, GNU's and CodeWarrior's.
Linguist has no IEC 61131-3 language under any name (no match for `61131`, `Structured
Text` or `ladder`). **Extends.**

**EXT-8. Free alternatives.** Every row below was absent from fileinfo.com, filext.com
and file-extension.info (HTTP 404 on each), absent from Linguist, had zero GitHub
code-search results, and its quoted web search returned only other extensions.

| Candidate | Reading | GitHub | Registries | Web search | Note |
|---|---|---|---|---|---|
| `.ldcfg` | "ld configuration": the sibling of `.ld` | 0 | none | none (only `ldcfg.exe`, a gaming-mouse utility, and `ldconfig` pages) | close to `ldconfig`, Linux's linker cache tool |
| `.ldcf` | the same, four letters | 0 | none | none | — |
| `.lxcf` | "logex configuration file" | 0 | none | none | no linker association |
| `.lxcfg` | the same, spelled out | 0 | none | none | "lx" may suggest Linux or LXC |
| `.ldcon` | "ld configuration" | 0 | none | none (only `.ld`, `ldconfig`) | reads as "console" too |

Checked and **taken**, so not proposed: `.ldc` (Lattice Radiant's synthesis constraints,
per latticesemi.com search results, not opened; Sound Open Firmware log dictionaries in
`thesofproject/sof-bin`; 578 files on GitHub; filext.com ties it to TwinCAT 3, a PLC
environment, **unverified**), `.lxc` (297 files with "lxc" in them; libvirt AppArmor
templates), `.lcfg` (125 files, Analog Devices' `study-watch-sdk`; also the name of
Edinburgh's LCFG configuration system), `.ldg` (128, ledger journals), `.ldp` (5,440, PCB
Gerber layers), `.lcx` (157, CDE help), `.ldk` (5), `.lcnf` (1), `.lgc` and `.ldw` (listed
on fileinfo.com).

Choosing among the five is the maintainer's call (decision 3). If a recommendation helps:
`.ldcfg` says "the configuration of `.ld` files" most plainly, at the cost of looking like
`ldconfig`; `.lxcf` avoids every linker association. Either way PLAN M2-2's
`compile_file/1` rule ("the extension says what kind of file it is") holds.

---

## 2. IEC 61131-3

Texts: Ed 2:2003, https://d1.amobbs.com/bbs_upload782111/files_31/ourdev_569653.pdf (226
pp); Ed 3:2013,
https://raw.githubusercontent.com/martingleich/Iec61131/master/Specification/IEC%2061131-3_2013%20Ed3.pdf
(231 pp); Ed 4:2025 publisher preview,
https://cdn.standards.iteh.ai/samples/iec/iec-61131-3-2025/147ba9c730934a119d196fa0473464f8/iec-61131-3-2025.pdf
(15 pp). These are the copies `docs/instruction-sets.md` §9 lists.

### Tasks

**IEC-1. The four task rules, and non-preemptive order, are as org §2 and §4.6 quote.**
Ed 2 §2.7.2, pp.114-115:
> "1) The associated program organization units shall be scheduled for execution upon each
> rising edge of the SINGLE input of the task.
> 2) If the INTERVAL input is non-zero, the associated program organization units shall be
> scheduled for execution periodically at the specified interval as long as the SINGLE
> input stands at zero (0). If the INTERVAL input is zero (the default value), no periodic
> scheduling of the associated program organization units shall occur.
> 3) The PRIORITY input of a task establishes the scheduling priority of the associated
> program organization units, with zero (0) being highest priority and successively lower
> priorities having successively higher numeric values. As shown in table 50, the priority
> of a program organization unit (that is, the priority of its associated task) can be used
> for preemptive or non-preemptive scheduling."

> "a) In non-preemptive scheduling, processing power becomes available on a resource when
> execution of a program organization unit or operating system function is complete. When
> processing power is available, the program organization unit with highest scheduled
> priority shall begin execution. If more than one program organization unit is waiting at
> the highest scheduled priority, then the program organization unit with the longest
> waiting time at the highest scheduled priority shall be executed."

> "4) A program with no task association shall have the lowest system priority. Any such
> program shall be scheduled for execution upon “starting” of its resource, as defined in
> 1.4.1, and shall be re-scheduled for execution as soon as its execution terminates."

Ed 3 §6.8.2 a)-d), p.181, has the same words. **Confirms** org §2 (table "Task", "Program
with no task") and §4.6 line 572 (rule 3a as the due-time tie-break).

**IEC-2. Missing a deadline is an error; Ed 3 drops the pointer to §1.5.1.**
Ed 2 p.115: "It shall be an error in the sense of subclause 1.5.1 if a task fails to be
scheduled or to meet its execution deadline because of excessive resource requirements or
other task scheduling conflicts." Ed 3 §6.8.2, p.182: "It shall be an error if a task fails
to be scheduled or to meet its execution deadline because of excessive resource
requirements or other task scheduling conflicts." **Confirms** org §2 fact 4 for Ed 2.
**Extends:** under Ed 3 the report-and-continue reading (org §4.6 "Missed periods") rests
on Ed 3's own error-handling clause, which this pass did not read (**unverified**).

**IEC-3. Limits are the implementer's.** Ed 2 p.114: "The maximum number of tasks per
resource and task interval resolution are implementation-dependent parameters." Ed 3 p.180
says "Implementer specific". **Extends:** logex's integer-ms interval and unbounded task
count are within the standard.

**IEC-4. A rising edge is defined as a change, which leaves the first cycle open.** Ed 2
§1.3.69, p.13: "rising edge: the change from 0 to 1 of a Boolean variable." (Ed 3 §3.83,
p.16, the same). A SINGLE that is 1 at start has not changed, so read strictly no edge has
occurred; read against the variable's initial value of 0, one has. **Confirms** org §4.6
line 562 that rule 1 is silent and logex adopts MatIEC's reading (MAT-5).

**IEC-5. The grammar.** Ed 2 Annex B.1.7, pp.157-158:
```
single_resource_declaration ::=
{task_configuration ';'}
program_configuration ';'
{program_configuration ';'}
task_initialization ::=
'(' ['SINGLE' ':=' data_source ',']
    ['INTERVAL' ':=' data_source ',']
    'PRIORITY' ':=' integer ')'
data_source ::= constant | global_var_reference
| program_output_reference | direct_variable
prog_cnxn ::= symbolic_variable ':=' prog_data_source
| symbolic_variable '=>' data_sink
prog_data_source ::=
constant | enumerated_value | global_var_reference | direct_variable
data_sink ::= global_var_reference | direct_variable
```
Ed 3 Annex A, p.226: `Single_Resource_Decl : ( Task_Config ';' )* ( Prog_Config ';' )+;`
and `'PRIORITY' ':=' Unsigned_Int ')'`. **Confirms** org §4.4's table (PRIORITY mandatory,
a constant connection source, IEC's wider `data_source`). **Extends** with two points:
- a configuration must declare **at least one program** in both editions; nothing in org
  §4.4 says whether a `.lcf` with no `program` line is an error;
- Ed 3 types PRIORITY as an unsigned integer, so a negative priority is not IEC.

### Globals, externals, configuration

**IEC-6. VAR_EXTERNAL must agree in type with its VAR_GLOBAL; Ed 3 adds that writing a
VAR_INPUT is an error.** Ed 2 §2.4.3, p.40: "Such variables are only accessible to a
program organization unit via a VAR_EXTERNAL declaration. The type of a variable declared
in a VAR_EXTERNAL block shall agree with the type declared in the VAR_GLOBAL block of the
associated program, configuration or resource." Ed 3 §6.5.2.2, p.51, the same, then: "It
shall be an error if: • any program organization unit attempts to modify the value of a
variable that has been declared with the CONSTANT qualifier or in a VAR_INPUT section".
Ed 2 Table 16a, p.39: "VAR_EXTERNAL Supplied by configuration via VAR_GLOBAL (2.7.1) Can
be modified within organization unit". **Confirms** org §2 "Sharing", §4.4 "Types agree
at both ends", and logex's refusal of a write to a var_input
(`lib/logex/compiler.ex:720-723`).

**IEC-7. VAR_EXTERNAL takes no initial value, and Ed 3 warns about shared writers.**
Ed 2 p.43: "Initial values cannot be given in VAR_EXTERNAL declarations." Ed 3 §6.5.2.1
Figure 8, p.51, NOTE: "The use of the VAR_EXTERNAL section in a contained element may lead
to unanticipated behaviors, for instance, when the value of an external variable is
modified by another contained element in the same containing element." **Extends** M2-4:
the first is a check `var_external` needs (refuse an initial value); the NOTE is IEC's own
reason for the two-writer warning (org §4.4 "One driver per sink").

**IEC-8. VAR_CONFIG and access paths, as org §4.4 says.** Ed 2 §2.7.1, p.111: "Instance
specific initial values provided by the VAR_CONFIG...END_VAR construction always override
type specific initial values. It shall not be possible to define instance specific
initializations to variables which are declared in VAR_TEMP, VAR_EXTERNAL, VAR CONSTANT or
VAR_IN_OUT declarations." Same page: "Access to variables that are declared CONSTANT or to
function block inputs that are externally connected to other variables shall be
READ_ONLY." and "NOTE The effect of using READ_WRITE access to function block output
variables is implementation-dependent." Ed 3 Annex A, p.226, still requires the resource
name: `Config_Inst_Init : Resource_Name '.' Prog_Name '.' …`. **Confirms** org §4.4
"Instance-specific initial values", including IEC's self-contradiction, which Ed 3 keeps.
**Extends** the deferred host write path (org §5): IEC makes a connected input read-only
to communication services and leaves writing an FB output to the implementer.

### Function blocks

**IEC-9. EN/ENO: Ed 2 freezes outputs; Ed 3 leaves them to the implementer.** Ed 2
§2.5.2.1a), p.68:
> "1) If the value of EN is FALSE (0) when the function block instance is invoked, the
> assignments of actual values to the function block inputs may or may not be made in an
> implementation-dependent fashion, the operations defined by the function block body
> shall not be executed and the value of ENO shall be reset to FALSE (0) by the
> programmable controller system. […]
> 3) If the ENO output is evaluated to FALSE (0), the values of the function block outputs
> (VAR_OUTPUT) keep their states from the previous invocation."

Ed 3 §6.6.1.5, p.63:
> "1. If the value of EN is FALSE then the POU shall not be executed. In addition, ENO
> shall be reset to FALSE. The Implementer shall specify the behavior in this case in
> detail, see the examples below. […]
> 4. If the ENO output is evaluated to FALSE (0), the values of all POU outputs
> (VAR_OUTPUT, VAR_IN_OUT and function result) are Implementer specific.
> 5. The input EN shall only be set as an actual value as a part of a call of a POU."

**Confirms** org §4.3 for Ed 2. **Extends:** under Ed 3 decision 12's freeze is one
permitted choice, no longer the required one, and Ed 3 requires the implementer to state
it, which the `cal` stanza and README should do.

**IEC-10. Ed 3's "external implementation" is decision 12.** Ed 3 §6.6.1.5, p.64:
> "EXAMPLE 2 External implementation
> The input EN is evaluated outside the POU. If EN is False, only ENO is set to False and
> the POU is not called. The input and in-out parameters are not evaluated and not set in
> the instance of the POU."

> "EXAMPLE 4 External implementation
> IF cond THEN myInst (A:= v1, C:= v3, B=> v2, ENO=> X)
> ELSE X:= 0; END_IF;"

The output assignment `B=> v2` sits inside the `THEN`, so on a false EN `v2` is not
written. EXAMPLE 3, the "internal implementation", calls `myInst (EN:= cond, …, B=> v2,
…)`, which does write `v2` (with the frozen value). **Confirms** decision 12 (line 1488):
"copies nothing in and writes nothing out" is IEC's EXAMPLE 2/4 exactly; the rejected
alternative is EXAMPLE 1/3, which is MatIEC's (MAT-7).

**IEC-11. From outside an FB, IEC lets code read outputs and forbids reading inputs.**
Ed 2 §2.5.2, p.67: "Assignment of a value to an output variable of a function block is not
allowed except from within the function block. The assignment of a value to the input of a
function block is permitted only as part of the invocation of the function block.
Unassigned or unconnected inputs of a function block shall keep their initialized values
or the values from the latest previous invocation, if any." Table 32, p.68 (column "Outside
function block"): "Input read … Not allowed (Notes 1 and 2)", "Input assignment …
FB_INST(IN1:=A,IN2:=B);", "Output read … C := FB_INST.OUT;", "Output assignment … Not
Allowed (Note 1)"; "NOTE 1 Those usages listed as “not allowed” in this table could lead
to implementation-dependent, unpredictable side effects." **Extends** org §4.3 line 328
("Reads of outputs such as `s1.run` work anywhere … reads anywhere"): IEC does not allow
reading an instance's *input* from outside. `Logex.FbType.public/1` already hides internals
(CLAUDE.md, `fb_type.ex`); whether it should also hide var_inputs from outside reads is a
question for M2-5.

**IEC-12. Ed 3 adds a separate input assignment from outside, effective at the next call.**
Ed 3 §6.6.3.4.2, p.108: "This assignment to input and in-out parameters shall become
effective with the next call of the FB." Figure 13, row 2, outside: "// Separate
assignment (NOTE 4) FB_INST.In := A;" (permitted); row 1 "Input read … Not allowed"; row 4
"FB_INST.Out:= B; Not Allowed". The figure cites a NOTE 4 that the extracted text does not
contain; only NOTES 1-3 are printed. Ed 3 §6.6.3.2, p.100, rule 11: "Variables of the VAR
section (static) may be declared PUBLIC or PRIVATE. The access specifier PRIVATE is
default." **Extends** PLAN M2-5 line 1352 ("which of a user block's members logic may
write is open"). The IEC answer is: inputs, by separate assignment, effective at the next
call; never outputs; internals only if PUBLIC (Ed 3). logex has no PUBLIC. The
conventional family's answer differs (CNV-12).

**IEC-13. Unconnected FB inputs keep their values.** Ed 3 §6.6.3.4.1, p.105: "c)
unassigned or unconnected inputs of a function block shall keep their initialized values
or the values from the latest previous call, if any." Ed 2 says the same (IEC-11).
**Extends** M2-5: `cal` is positional and takes every var_input (org §4.3), so this never
arises in a `cal`; it would arise if logex ever allowed a member write from outside.

**IEC-14. By two clauses together, an unconnected program input keeps its initial value.**
Ed 2 §2.5.3, p.83: "The declaration and usage of programs is identical to that of function
blocks as defined in 2.5.2.1 and 2.5.2.2, with the additional features shown in table 39
and the following differences". None of the four listed differences concerns inputs. Ed 3
§6.6.4, p.117, says the same. With IEC-11/IEC-13's rule for FB inputs, an unconnected
program input keeps its initial value. This is an **inference**, stated as one.
**Contradicts** org §4.4 line 434 ("No IEC rule on an unconnected program input was
found") and §8 line 1699. It does not undo decision 7: IEC lets a VAR_INPUT carry an initial
value, logex's does not (M1-3), so the IEC rule would give logex 0 forever, which is the
reason line 435 gives for making it an error.

**IEC-15. Programs in resources, FBs in programs or FBs.** Ed 2 §2.5.3, p.83: "3) Programs
can only be instantiated within resources, as defined in 2.7.1, while function blocks can
only be instantiated within programs or other function blocks." Ed 3 §6.6.4, p.117, the
same. **Confirms** org §2.

**IEC-16. Recursion.** Ed 2 §2.5, p.45: "Program organization units shall not be
recursive; that is, the invocation of a program organization unit shall not cause the
invocation of another program organization unit of the same type." Ed 3 §6.6.1.1, p.58:
"The recursive call of POUs and methods is Implementer specific." **Confirms** org §4.3.

**IEC-17. Keywords.** Ed 2 Table C.2, pp.163-164, lists `AT`, `CONFIGURATION`, `EN, ENO`,
`FUNCTION_BLOCK`, `PROGRAM...WITH...`, `RESOURCE...ON...`, `TASK`, `VAR_CONFIG`,
`VAR_EXTERNAL`, `VAR_GLOBAL`, `WITH`, and not `INTERVAL`, `SINGLE` or `PRIORITY`.
**Confirms** org §4.8. **Extends:** IEC also reserves `EN` and `ENO`. logex has no EN/ENO
words (rung power is EN, org §4.3), so this matters only for the `cal` stanza, which
should say so.

**IEC-18. Instruction List was marked deprecated in Ed 3's own clause.** Ed 3 §7.2.1,
p.195: "This language is outdated as an assembler like language. Therefore it is
deprecated and will not be contained in the next edition of this standard." The Ed 4
preview's contents list clause 7 as "7.1 Common elements … 7.2 Structured text (ST)",
with no IL. **Confirms** org §4.3 ("Why the word `cal`"). **Resolves**
`docs/instruction-sets.md` §10 item 4 (line 933), which says this sentence was unread.

**IEC-19. Ed 4's organisation clauses exist but were not read.** Preview contents: "6.8
Configuration elements … 195", "6.8.2 Tasks … 200", "Table 64 – Task … 201", "Table 18 –
Execution control graphically using EN and ENO … 70", and a section Ed 3 lacks: "6.9
Synchronization of concurrent execution … 205", "6.9.2 Mutex … 206", "6.9.4 Semaphore …
209". The Foreword: "Annex B contains a comprehensive list of features that have been
added, removed or deprecated in comparison to IEC 61131-3:2013." The text of §6.8.2 is
**unverified**, as org §8 already says. **Extends:** Ed 4 adds mutexes and semaphores for
concurrent execution, which logex's no-preemption rule (org §5) makes unnecessary; the
`task` stanza should cite Ed 4 §6.8.2 as unread.

---

## 3. MatIEC and Beremiz

Read at MatIEC `3a41303` (`github.com/beremiz/matiec`, 2026-09-22) and Beremiz `5e3a749`
(`github.com/beremiz/beremiz`). Org §8 cites MatIEC symbols without a commit; these are
the current heads. Cited by symbol, per CONTRIBUTING.md.

**MAT-1. The GCD tick and `!(tick % N)`, as org §8 says.** `calculate_common_ticktime_c`
in `stage4/generate_c/generate_c.cc` folds every task's INTERVAL into a GCD, and the
`task_initialization_c` visitor emits, for a task without SINGLE:
```c
s4o.print("!(tick % ");
s4o.print(time / common_ticktime);
```
and `"1"` when the interval is 0 or absent. **Confirms** org §8 lines 1660-1662 and §4.4
"Tasks" (MatIEC runs an INTERVAL-0 task every tick).

**MAT-2. With SINGLE given, MatIEC ignores INTERVAL.** Same visitor, `run_dt` case:
`if (symbol->single_data_source != NULL) { … R_TRIG … task = R_TRIG.Q }` `else { … interval
… }`. The INTERVAL branch is only reached when SINGLE is absent. Beremiz's task editor
makes the two exclusive (`editors/ResourceEditor.py`): the Interval cell is read-only
unless `Triggering` is `"Cyclic"`, the Single cell read-only unless it is `"Interrupt"`.
**Extends** M2-6 (PLAN line 1354) and org §4.4's row `task <n> single <g> [interval <ms>]`:
IEC rule 2's combination has no precedent in MatIEC or Beremiz, so logex's test for it
can only be checked against IEC's text.

**MAT-3. SINGLE must be a global variable.** The same visitor casts
`((global_var_reference_c *)(symbol->single_data_source))->global_var_name` and looks it up
in the resource, then the configuration, else `ERROR`. Beremiz's Single cell offers
`self.Parent.VariableList`. **Confirms** org §4.4 "Events" (a bool global): MatIEC
supports no other `data_source` either.

**MAT-4. Programs run in declaration order, across tasks; PRIORITY is never used.** The
resource's run function prints "(C.2) Task management" (every task flag) and then "(C.3)
Program run declaration", visiting `program_configuration_list` in order; each program is
wrapped `if (<task>) { … }`. `priority_data_source` appears in `generate_c.cc` only in the
comment `//SYM_REF4(task_initialization_c, single_data_source, interval_data_source,
priority_data_source, unused)`. **Confirms** org §4.6 line 587 ("MatIEC parses PRIORITY
but ignores it"). **Extends:** MatIEC's order is program declaration order, *not* grouped
by task, so it is no precedent for logex's priority-first order; it is one for
"declaration order" as a tie-break, and for evaluating every trigger before any program
runs (a SINGLE written by logic is seen next tick, as org §4.6 says).

**MAT-5. The SINGLE edge detector fires in the first tick if the trigger is already 1.**
`lib/edge_detection.txt`: `FUNCTION_BLOCK R_TRIG … VAR M: BOOL; END_VAR Q := CLK AND NOT
M; M := CLK;`. `M` starts FALSE, and the task's `static R_TRIG` is initialised by
`R_TRIG_init__(&<task>_R_TRIG, retain)`. **Confirms** org §4.6 line 562 and decision 11.

**MAT-6. Copy-in and copy-out wrap the program call, inside the task's `if`.** The
`program_configuration_c` visitor, `run_dt`: prints `if (<task>) {`, then the `:=`
connections (`wanted_assigntype = assign_at`), then `<type>_body__(&<inst>);`, then the
`=>` connections (`send_at`), then `}`. **Confirms** org §4.6 step 4 and its MatIEC
citation.

**MAT-7. On a false EN, MatIEC copies inputs in and the frozen outputs out.** The parser
adds EN and ENO to every function and FB (`stage1_2/iec_bison.yy`:
`add_en_eno_param_decl_c::add_to($$); /* add EN and ENO declarations, if not already
there */`, unless `disable_implicit_en_eno`). The FB body begins (`generate_c.cc`, "//
Control execution"): `if (!__GET_VAR(data__->EN)) { __SET_VAR(data__->,ENO,,FALSE);
return; } else { … ENO … TRUE }`. The caller (`generate_c_st.cc`, `fb_invocation_c`)
assigns every input, EN among them, before the call, and assigns every output after it,
unconditionally. Beremiz lowers an LD box to `name(EN := …, …);` and reads each output as
`"%s.%s" % (name, output_parameter)` downstream (`PLCGenerator.py`). So a coil after a
disabled Beremiz block is rewritten each scan with the frozen value. **Extends** decision
12: MatIEC and Beremiz take Ed 3's EXAMPLE 1/3 (IEC-10), the alternative decision 12
rejected; logex's choice is IEC's EXAMPLE 2/4. Both are conformant.

**MAT-8. VAR_EXTERNAL is a pointer to the global.** `lib/C/accessor.h`:
`#define __DECLARE_EXTERNAL(type, name) __IEC_##type##_p name;`, `__INIT_EXTERNAL` sets
`name.value = __GET_GLOBAL_##global();` (the global's address), `#define
__GET_EXTERNAL(name, ...) ((*(name.value)) __VA_ARGS__)`, and `__SET_EXTERNAL` writes
`(*(prefix name.value)) suffix = new_value` unless the external or the global is forced.
**Confirms** org §4.4 "During a scan it reads and writes the global directly." **Extends**
the deferred forcing (org §5): a forced global refuses writes through every external.

**MAT-9. Beremiz, when late, skips ticks rather than coalescing them.**
`targets/plc_main_head.c`, `PLC_run(unsigned int periods_passed)`: `__tick +=
periods_passed;` then one `config_run__(__tick);`. `targets/Linux/plc_Linux_main.c`
counts the periods that passed during a long cycle and logs "PLC execution time is longer
than requested PLC cyclic task interval. %d cycles skipped". With MAT-1's `!(tick % N)`, a
task whose multiple of N fell in the skipped ticks does not run that round; it waits for its
next multiple. **Extends** org §4.6 "Missed periods are reported, not replayed": logex runs
such a task once and counts the miss; Beremiz may not run it and counts cycles, not
per-task misses. Both keep phase.

**MAT-10. Beremiz's timers read the wall clock.** `PLC_run` starts with
`PLC_GetTime(&__CURRENT_TIME);`, and MatIEC's TON compares `__CURRENT_TIME` against its
`START_TIME` (`lib/C/iec_std_FB_impl.h`). **Confirms** org §4.6's "the increment is the
actual time" for Beremiz. OpenPLC differs (OPL-2).

**MAT-11. Beremiz's hot swap matches state by path and type, and starts a changed type
fresh.** "PLC logic hot-swap", Edouard Tisserant, 12 September 2026,
https://beremiz.org/2026/09/12/plc-logic-hotswap.html:
> "leaves that exist in both trees with the same type are paired into a copy operation; a
> variable that only exists in the new program keeps its initial value; one that
> disappeared is simply dropped."

> "The swap happens between two cycles, never inside one."

> "It only replaces logic. Any change to the IO configuration, to an extension’s C code,
> or to anything else that lands in the IOs .so requires a stop.
> A variable that changed type between the two versions is not carried over; it starts
> from its initial value."

The article says nothing about tasks, intervals, priorities or outputs. **Confirms** org
§4.9 line 809 (between two cycles) and its I/O refusal. **Extends:** Beremiz *accepts* a
type change and restarts the variable; logex refuses one at accept. Whether a hot swap can
change a task: **unverified** (the PLC thread reads the common tick once, at start, in
`PLC_thread_proc`, which suggests not, but no text says so).

**MAT-12. MatIEC's state backup is positional.** `generate_c_backup_config_c`
(`generate_c.cc`) emits, per program, `_backup__(&<inst>, sizeof(<inst>), buffer, maxsize)`
and the matching `_restore__`: raw bytes of each instance struct. **Extends** org §4.9:
the only state transfer in MatIEC itself is by position and size, which is why Beremiz's
hot swap walks the instance tree by path instead.

---

## 4. OpenPLC v3 (`thiagoralves/OpenPLC_v3` at `b5d4135`)

**OPL-1. The cycle and the hardware layer, as org §4.5 says.** `webserver/core/main.cpp`:
```c
updateBuffersIn(); //read input image
pthread_mutex_lock(&bufferLock); //lock mutex
…
updateBuffersIn_MB(); //update input image table with data from slave devices
handleSpecialFunctions();
config_run__(__tick++); // execute plc program logic
updateBuffersOut_MB(); //update slave devices with data from the output image table
pthread_mutex_unlock(&bufferLock); //unlock mutex
updateBuffersOut(); //write output image
updateTime();
…
sleep_until(&timer_start, common_ticktime__);
```
`webserver/core/ladder.h` declares `void initializeHardware(); void finalizeHardware(); void
updateBuffersIn(); void updateBuffersOut();`. **Confirms** org §4.5 (the adapter contract)
and §4.6 step 2. **Extends:** a Modbus slave layer runs inside the lock, between the
hardware read and the program, so OpenPLC's input image has two sources each cycle.

**OPL-2. OpenPLC's clock is nominal, so a late cycle stretches every timer.**
`utils/glue_generator_src/glue_generator.cpp` emits `void updateTime() {
__CURRENT_TIME.tv_sec += common_ticktime__ / 1000000000ULL; __CURRENT_TIME.tv_nsec +=
common_ticktime__ % 1000000000ULL; … }`, called once per cycle, and `config_run__(__tick++)`
never skips a tick. **Extends** org §4.6 line 638 ("Either way the increment is the actual
time, not the nominal interval"): OpenPLC is the counter-example, and the reason that
sentence matters. Beremiz (MAT-10) takes actual time.

**OPL-3. Located variables are `%I/%Q/%M` with a size letter, mapped by name.** The glue
generator parses MatIEC's located names (`__IX<byte>_<bit>`, `__QW<n>` …) in
`findPositions` and `glueVar`: `I` and `Q` with `X`, `B`, `W`, `D`, `L`; `M` with `W`, `D`,
`L`; buffers of `BUFFER_SIZE` 1024 (`ladder.h`), bits `[1024][8]`. A bit index of 8 or
more prints `***Invalid addressing on located variable…***` and the mapping is emitted
anyway. `%QL` is mapped to `lint_input`, a defect at this commit. **Extends** org §4.5:
the IEC-style address OpenPLC uses is the fallback logex rejected (decision 6); its
silent acceptance of a bad bit index is a reason logex's `at` should be checked at
compile time.

**OPL-4. Every periodic task runs in the first cycle.** `config_run__(__tick++)` starts at
tick 0, and `!(0 % N)` is true for every N (MAT-1); Beremiz's first `PLC_run(0)` does the
same. **Confirms** org §4.6 line 557 ("Every periodic task is due in the first cycle").

**OPL-5. On stop OpenPLC zeroes its outputs once.** `main.cpp`: `printf("Disabling
outputs\n"); disableOutputs(); updateBuffersOut(); finalizeHardware();`.
`webserver/core/utils.cpp`, `disableOutputs`, writes 0 to every mapped `bool_output`,
`byte_output` and `int_output`, and not to `dint_output` or `lint_output`. **Extends**
decision 14 (line 1493): a free-software precedent for "zero the output image once", with
a gap logex should not copy (it covers every type).

---

## 5. CODESYS online help (content.helpme-codesys.com, read 2026-10-02)

**CDS-1. Task types and priority.** "Object: Task",
https://content.helpme-codesys.com/en/CODESYS%20Development%20System/_cds_f_reference_task.html:
> "Priority … Possible values: 0..31, where 0 is the highest priority"

> "Type: Event … Global variable (Boolean type) … The task starts as soon as the variable
> value switches from 0 to 1."

> "If the sampling rate of the task scheduler is too low, then the rising edge of the event
> can remain unnoticed."

The page also defines "Cyclic", "External", "Freewheeling" and "Status" (a status task
"runs until the variable gets the value FALSE … In contrast to the event task, no event can
be missed in this way"). On a single core: "If a lower priority task is running and a
higher priority task needs to be run, the lower priority task will be interrupted", and
same-priority tasks run "by means of the round-robin time-slicing method". **Confirms**
logex's 0-highest priority, its bool-global event trigger (org §4.4 "Events") and its
caveat that a pulse inside one host step is lost (org §4.6). **Extends:** CODESYS's
"Status" task is the known remedy for lost edges, if M2-6 ever needs one.

**CDS-2. Order: priority, then longest waiting, then the configured call order.** "Task
Configuration",
https://content.helpme-codesys.com/en/CODESYS%20Development%20System/_cds_f_task_configuration.html:
> "If multiple tasks fulfill the condition for processing at the same time, then the tasks
> with the highest priority are processed first.
> If multiple tasks with the same priority level fulfill the condition for processing at the
> same time, then the task which has been in the queue the longest is processed first.
> The program calls are processed in the order they appear in the configuration dialog of
> the task."

This page and CDS-1 disagree for equal priorities (longest waiting, against round-robin
time slicing); for logex, whose scans take no time, only the first is observable.
**Confirms** org §4.6 step 4 (priority, then earlier due time, then declaration order).

**CDS-3. The watchdog halts the application and may reset outputs.** Same "Object: Task"
page: "If the task exceeds the currently set time of the watchdog, then the task is halted
with an error status (exception). The application in whose task the error occurred and
its child applications are also halted." and "If you activate the option Update I/Os in
the PLC Settings of the PLC, then CODESYS resets the outputs to the defined default
values." **Extends** decision 14: CODESYS's choice is per-PLC and goes to configured
defaults, not necessarily 0.

**CDS-4. VAR_EXTERNAL.** "Variable: VAR_EXTERNAL",
https://content.helpme-codesys.com/en/CODESYS%20Development%20System/_cds_vartypes_var_external.html:
> "If the global variable does not exist, then an error message is printed."
> "CODESYS does not require you to declare a global variable as external in order to use
> it in a POU. The keyword exists only for maintaining compliance with IEC 61131-3."
> "Initialization is not permitted."

**Confirms** M2-4's "a `var_external` with no matching global … is a located diagnostic"
and IEC-7. **Extends:** CODESYS reaches globals without `VAR_EXTERNAL`, as the
conventional family's controller scope does; logex follows IEC (org §5).

**CDS-5. A box with EN/ENO.** "FBD/LD/IL Element: Box with EN/ENO",
https://content.helpme-codesys.com/en/CODESYS%20LD%20FBD/_cds_fbd_ld_il_element_box_en_eno.html:
> "When the EN input has the value FALSE at the time of the POU call, the operations
> defined in the POU are not executed. Otherwise, these operations are executed when EN is
> TRUE. The ENO output has the same value as the EN input."

Whether CODESYS copies inputs in, or writes outputs out, on a false EN is not stated
(**unverified**; a forum answer says outputs stay frozen, not a first-party source).

**CDS-6. Any change to the task configuration prevents an online change.** "Command:
Online Change",
https://content.helpme-codesys.com/en/CODESYS%20Development%20System/_cds_cmd_online_change.html,
Table 106, "Actions and changes in different areas of an application which prevent an
online change": "Task Configuration — Change in the configuration settings". **Confirms**
decision 19 (line 1507), "refuse all, as CODESYS does".

**CDS-7. The same table lets I/O mapping change online, and refuses type changes between
derived types.** Table 106: "Device configuration — Change in the device tree … Note: I/O
mapping to variables is possible by means of an online change." and "Data Type — Change of
the data type of a variable from one custom data type to another custom data type (for
example, from TON to TOF)" with the workaround "always change the name of the variable
together with the data type. Then the variable is initialized as a new variable and the old
one is removed." **Confirms** org §4.9's refusal of device changes and of type changes.
**Extends** org §4.9 line 861: CODESYS refuses a device change but allows re-mapping I/O
to variables online; logex refuses both (decided). The same page: "When an online change
is performed, the application-specific initializations (example: homing) are not executed
because the machine retains its status." **Confirms** org §4.9's "`first` stays false … as
in CODESYS".

**CDS-8. CODESYS copies a changed FB's instances; "by name" is not stated.** "Method:
FB_Init, FB_Reinit, FB_Exit",
https://content.helpme-codesys.com/en/CODESYS%20Development%20System/_cds_method_fb_init_fb_reinit.html:
> "If no changes were made to the declaration part of a function block in the application
> before login, but in the implementation only, then the data areas are not replaced. Only
> code blocks are replaced."

> "Copy operation: copy … copy(&old_inst, &new_inst); Existing values remain unchanged. For
> this purpose, they are copied from the old instance into the new instance."

The order is `old_inst.FB_Exit(bInCopyCode := TRUE)`, `new_inst.FB_Init(bInitRetains :=
FALSE, bInCopyCode := TRUE)`, the copy, then `FB_Reinit`. "Attribute: no_copy" says "the
variable is re-initialized in the course of an online change". None of the pages read
says how members are matched. **Contradicts** org §4.9 line 867 ("copy the members that
match by name and type, as CODESYS does") as a citation: matching by name and type is
**unverified** for CODESYS; Beremiz does state it (MAT-11), by path and type. Suggest
citing Beremiz there.

---

## 6. The conventional family

Documents read (titles without the family's name; all "Original Instructions"):

| Short name | Title | Publication | Date |
|---|---|---|---|
| tasks manual | *Tasks, Programs, and Routines* programming manual | 1756-PM005M-EN-P | Sept 2025 |
| add-on manual | *Add-On Instructions* programming manual | 1756-PM010N-EN-P | Sept 2025 |
| parameters manual | *Program Parameters* programming manual | 1756-PM021E-EN-P | March 2022 |
| faults manual | *Major, Minor, and I/O Faults* programming manual | 1756-PM014O-EN-P | Sept 2024 |
| general instructions | *General Instructions* reference manual | 1756-RM018A-EN-P | Sept 2025 |
| import/export | *Import/Export* reference manual | 1756-RM014D-EN-P | Sept 2025 |
| design considerations | *Design Considerations* reference manual | 1756-RM094N-EN-P | Sept 2025 |
| testing article | knowledgebase article "Testing Applications within a [conventional family] Controller" | ID 52497 | last updated 29 May 2008 |

The library now serves the general instructions reference as 1756-RM018A and the
import/export reference as 1756-RM014D; org §8 cites both by title only, and their page
numbers there (pp.73, 132, 134, 275-276, 313, 315) match these editions where checked.

### Tasks and programs

**CNV-1. Three task types; one task runs at a time.** Tasks manual pp.8-9: "The controller
runs only one task at one time. • Another task can interrupt a task that is running and
take control. • In any given task, only one program runs at one time." A periodic task:
"Interrupts any lower priority tasks. • Runs one time. • Returns control to where the
previous task left off." "You can configure the time period from 0.1 ms…2000 s. The
default is 10 ms." The event trigger "can be a: • Change of a digital input. • New sample of
analog data. • Certain motion operations. • Consumed tag. • EVENT instruction."
**Confirms** org §3's table.

**CNV-2. The continuous task is always the lowest priority.** Tasks manual p.13: "You do
not assign a priority to the continuous task. It always runs at the lowest priority. All
other tasks interrupt the continuous task." **Verifies** the from-memory item at org §8
line 1688 and org §3 line 164; both can drop "from memory".

**CNV-3. A lower number is a higher priority.** Tasks manual p.12: "This task to interrupt
another task — Assign a priority number that is less than (higher priority) the priority
number of the other task." p.11: "The number of priority levels depends on the
controller", 15 for most. **Verifies** org §8 line 1690, and answers org §3 line 165
("Neither says which end is higher").

**CNV-4. Equal priorities time-slice.** Tasks manual p.12: "This task to share controller
time with another task — Assign the same priority number to both tasks. — The controller
switches back and forth between each task and runs each task for 1 ms." **Extends** org
§4.6 step 4: the family's tie-break is time-slicing, which zero-time scans cannot show;
logex's earlier-due-then-declaration order is IEC's (IEC-1), not this family's.

**CNV-5. An overlap drops the trigger.** Tasks manual p.15: "An overlap is a condition
where a task (periodic or event) is triggered while the task is still running from the
previous trigger. IMPORTANT: If an overlap occurs, the controller disregards the trigger
that caused the overlap." **Confirms** org §4.6 "Missed periods are reported, not
replayed".

**CNV-6. Programs: one task each, run in the order listed.** Import/export p.63: "There
can be only one continuous task. • Programs can be scheduled under only one task. • There
can be a maximum of 1000 programs under a task. • Scheduled programs must be defined."
p.315: "The programs are executed in the order they are specified." **Confirms** org §3
and §4.6 line 574.

**CNV-7. Logic may write a task's rate and priority.** General instructions pp.275-276,
TASK object: `Priority INT GSV SSV … Relative priority of this task as compared to the
other tasks. Valid values 0...15.` and `Rate DINT GSV SSV … The time interval between
executions of the task. Time is in microseconds.` Tasks manual p.79 shows an SSV setting
the `Rate` of an event task (its timeout) "when the controller enters Run mode".
**Confirms** decision 19's basis and org §4.9 "Allowed while running". Whether the
programming software changes a task's period or priority online, and whether a task can
be created or deleted online, remain **unverified**: none of these documents says.

**CNV-8. A watchdog timeout is a major fault.** Tasks manual p.34: "Each task contains a
watchdog timer that specifies how long a task can run before triggering a major fault."
"A watchdog time can range from 1…2,000,000 ms (2000 seconds). The default is 500 ms."
**Confirms** org §3's watchdog row.

**CNV-9. A major fault stops logic and sends outputs to their configured fault state.**
Faults manual p.21: "The controller changes to the Program mode and stops executing the
logic. ◦ Sets the outputs to their configured state or value for faulted mode." p.22: "When
the major fault occurs, the controller enters faulted mode. Outputs go to the faulted
state." The testing article p.4 gives a module's fault states as "(On, Off or Hold)".
**Verifies** org §8 line 1693 ("what its controller does to outputs on a watchdog fault").
**Extends** decision 14: this family's answer is per-module and configurable (off, on or
hold), like CODESYS's defaults (CDS-3); zeroing once is OpenPLC's (OPL-5).

**CNV-10. An inhibited task is still prescanned.** Tasks manual p.24: "If a task is
inhibited, the controller still prescans the task when the controller transitions from
Program to Run or Test mode." **Extends:** a precedent for initialising every instance at
`start/1`, scheduled or not.

**CNV-11. Program parameters: inputs refreshed before the scan, outputs pushed after it,
and a program may write its own inputs.** Parameters manual p.15: "Input parameter values
are refreshed before each scan of a program. The values do not change during the logic
execution, so you do not need to write code to buffer inputs. • A program can write to its
own Input parameters." and "Input parameters (including members) can only support one
sourcing connection." p.19: "Output parameter values are refreshed after each scan of a
program. They maintain the value from the previous scan until the program execution is
complete." **Confirms** org §4.6's copy-in, scan, copy-out. **Extends:** "one sourcing
connection" per input is this family's counterpart of a var_input connected once (org
§4.4); and writing one's own input is allowed here but refused by IEC (IEC-6) and logex
(`compiler.ex:720-723`), so a user from this family will meet that refusal.

**CNV-12. Program parameters can be added, edited and deleted online, with exceptions.**
Design considerations p.58: "Standard (non-Safety) parameters can be created, edited, and
deleted while online with the controller. The following exceptions apply: • Parameters
cannot be deleted while online if they are connected/bound to other parameters, or if the
control logic references them." **Extends** org §4.9 "Allowed while running" (connections):
the family refuses deleting a connected parameter online; logex's rule for removing a
connected var_input in an OE-2 edit is not yet written.

### Add-on instructions (the family's function blocks)

**CNV-13. A false rung runs no logic, writes no outputs, and copies inputs in.** Add-on
manual p.43, default scan modes: "False — Does not execute any logic for the Add-On
Instruction and does not write any outputs. Input parameters are passed values." p.48:
"If the EnableInFalse routine is not enabled, the only action performed for the Add-On
Instruction in the false condition is that the values are passed to any required Input
parameters in ladder logic." p.49: "If the EnableIn parameter of the instruction is False
(0), the logic routine is not executed and the EnableOut parameter is set False (0)."
**Extends** decision 12: a third behaviour, between logex's (nothing in, nothing out) and
MatIEC's (everything in, everything out).

**CNV-14. A one-shot inside a disabled add-on instruction never sees its rung go false.**
Add-on manual p.20: "When used in an Add-On Instruction, these instructions will not detect
the rung-in transition to the false state. When the EnableIn bit is false, the Add-On
Instruction logic routine no longer executes, thus the transitional instruction does not
detect the transition to the false state." The examples given start "ONS, MSG, …".
**Extends** PLAN M2-5 line 1352 ("an `ons` inside a block frozen on the first scan is not
held back"): the family documents the same consequence of freezing and leaves it to the
user, so the `cal` stanza and README can state it as known behaviour rather than a logex
defect.

**CNV-15. Logic outside may read or write an instance's parameters; local tags are
hidden.** Add-on manual p.23: "The parameters of an Add-On Instruction are directly
accessible in the controller's programming through this instruction-defined tag within the
normal tag-scoping rules. Local tags are not accessible programmatically through this
tag." p.79: "Use another instruction, an assignment, or an expression to read or write to
the tag name of the parameter. Use this format for the tag name of the parameter:
Add_On_Tag.Parameter", with the example "The first rung sets the Jog bit of
Motor_Starter_LD = Jog_PB" (an Input parameter written from outside). The per-parameter
"External Access" setting (Read/Write, Read Only, None; p.35) is not about logic: "External
Access defines the level of access that is allowed for external devices, such as an HMI,
to see or change tag values." (p.30). That writing an *Output* parameter from outside logic
is allowed is an **inference** from "read or write to the tag name of the parameter"; no
example shows it. **Extends** PLAN M2-5's open question: this family allows writing
inputs (and, by its wording, outputs) from outside; IEC allows inputs only, at the next
call (IEC-12); decision 9 allows only a timer's `.pre` and `.acc`.

**CNV-16. Nesting is limited to 16 levels.** Add-on manual p.21: "The instructions can be
nested up to 16 levels deep." Neither the add-on manual nor the design considerations
reference says, in the text read, that an add-on instruction may not call itself
(**unverified**). **Extends** M2-5: logex's nesting has no stated depth (org §4.3 forbids
only cycles), as its branch nesting has none (`docs/naming.md`, Branch structure).

**CNV-17. Existing add-on instructions are edited offline only.** Design considerations
p.65: "Existing Add-On Instructions can only be edited offline. New Add-On Instructions
can be created online or offline." and "Import online with a running controller: • Add
programs, routines, and Add-On Instructions • Existing programs and routines can be
replaced … • The data values in the controller are maintained and new tags have their
values initialized from the import file". **Confirms** org §4.9's refusal of a function
block's members while running (until M2-5), and its "partial import online" citation.

**CNV-18. Prescan runs the main logic with parameters passed.** Add-on manual p.44:
"Prescan — Executes the main logic routine of the Add-On Instruction in Prescan mode. Any
required Input and Output parameters' values are passed." **Extends** nothing logex has
(logex has no prescan; `first` and `initial_env/1` stand for it, org §4.6 "First scan").

### Timers and online edits

**CNV-19. Logic may write a timer's preset, which the timer never rewrites.** General
instructions p.876, "Pseudo-operand initialization": "Pseudo-operands are initialized when
the application is downloaded and never again, unless modified by the application." and
"Preset (PRE) is used by the TON to determine when the DN bit should be set. The
instruction does not change the PRE member." with "Position (POS) and Accumulator (ACC) are
initialized as described but they are also overwritten by the instruction when it
executes." **Verifies** org §8 line 1692 for `.pre` ("unless modified by the application")
and, less directly, for `.acc`. **Confirms** org §4.6 "`.pre` … which the instruction
never rewrites".

**CNV-20. An untested edit leaves outputs in their last state.** Testing article p.4:
"During Program/Phase Edits, “untest” edits leaves the outputs in their last state unless
commanded by the original logic (or other logic in the controller). For complete details
about Program/Phase Edits, refer to Publication: 1756-QS001, Page 120." **Confirms** org
§4.9's held-output rule from a second first-party source. The current 1756-QS001 from the
library is a one-page pointer to online help, so the Oct 2009 edition org §8 cites was not
re-read here.

**CNV-21. What happens to a program removed online: no first-party source found.** A
third-party knowledge-base site (URL withheld: it names the family) says a program cannot
be deleted online, only unscheduled and emptied. **Unverified.** Org §8's "that an
unscheduled program does not run" also remains **unverified**: no document read states it.

---

## 7. Siemens

**SIE-1. S7-1500 numbers priorities upward: 1 is the lowest.** *SIMATIC S7-1500 Cycle and
response times*, Function Manual 02/2014, A5E03461504-02, p.9,
https://cache.industry.siemens.com/dl/files/558/59193558/att_112303/v1/s71500_cycle_and_reaction_times_function_manual_en-US_en-US.pdf:
> "All cycle OBs always have the lowest priority of 1. The highest priority is 26."
> "If two pending tasks have the same priority, these tasks are processed in the order in
> which the tasks occurred."

p.21: "In STEP 7, the organization blocks OB 30 to OB 38 are provided for the processing of
cyclic interrupts." **Extends:** IEC, CODESYS and the conventional family put 0 or 1 at the
top; Siemens puts 1 at the bottom. The `priority` stanza in `docs/naming.md` must say so,
since a Siemens user will read `priority 1` backwards. The equal-priority rule agrees with
IEC's rule 3a.

---

## 8. Corrections this suggests to the repository's documents

None was made; each is for the design pass to take or leave.

1. `docs/organisation.md` §8 line 1703 (`.lcf` unverified): settled, it clashes (EXT-1..6);
   decision 3 and PLAN M2-2 line 1314 can choose from EXT-8.
2. §3 line 164 and §8 lines 1688 and 1690: verified (CNV-2, CNV-3); §3 line 165's "Neither
   says which end is higher" is answered.
3. §8 line 1692 (`.pre`) and line 1693 (outputs on a watchdog fault): verified (CNV-19,
   CNV-9). Line 1691 (unscheduled program) stays unverified.
4. §4.4 line 434 and §8 line 1699: an IEC rule for an unconnected program input exists by
   inference (IEC-14); the logex rule stands, with a different reason.
5. §4.3 (EN rules) cites Ed 2 only; add Ed 3 §6.6.1.5 (IEC-9) and note decision 12 is Ed
   3's EXAMPLE 2/4 (IEC-10).
6. §4.3 line 328 ("reads anywhere"): IEC forbids reading an FB's inputs from outside
   (IEC-11); M2-5 should decide whether `s1.start` is readable.
7. §4.9 line 867: "as CODESYS does" for name-and-type matching is not supported by the
   CODESYS pages read; Beremiz states it (CDS-8, MAT-11).
8. §4.9 line 861: CODESYS allows I/O re-mapping online (CDS-7); the sentence is right about
   devices only.
9. `docs/instruction-sets.md` §10 item 4 (line 933): resolved by Ed 3 §7.2.1 (IEC-18).
10. §4.6 line 587: add that MatIEC's program order ignores tasks as well as priority (MAT-4).

---

## 9. Still unverified after this pass

- The text of Ed 4 §6.8 and §6.8.2 (only its contents page was read), and Ed 3's §1.5.1
  equivalent for handling a missed deadline.
- Whether CODESYS writes a disabled block's outputs, or copies its inputs, on a false EN;
  whether a CODESYS event task fires at start when its variable is already TRUE; how
  CODESYS matches members when it copies an instance.
- Whether the conventional family's software can change a task's period or priority
  online (logic can, CNV-7), create or delete a task online, or delete a program online;
  that an unscheduled program does not run there; whether its add-on instructions may
  recurse; whether logic may write an add-on instruction's Output parameter.
- Whether Beremiz's hot swap can change a task or the common tick.
- That `.lcf` means "Loon configuration file" (EXT-3), and the single-aggregator uses in
  EXT-5; that filext.com's TwinCAT association for `.ldc` is real.
- Org §8's other open items not touched here: whether the conventional family's switch is
  atomic at a scan boundary, and when CODESYS and Siemens switch within a cycle.

---

## 10. Where the sources are kept

Under `/tmp/claude-0/-home-user-logex/f07aea59-53a1-5b8d-b560-6e6d2e330709/scratchpad/m2/inv-sources-src/`:

- `iec-ed2.pdf`, `iec-ed3.pdf`, `iec-ed4-preview.pdf`, and their text `ed2.txt`, `ed3.txt`,
  `ed4p.txt` (each page headed `=== pdfpage N ===`; the printed number is on the next
  line).
- `matiec/` (a shallow clone at `3a41303`), `beremiz/` (`targets/plc_main_head.c`,
  `targets/Linux/plc_Linux_main.c`, `editors/ResourceEditor.py`, `PLCGenerator.py` at
  `5e3a749`), `beremiz-hotswap.txt`, `openplc/` (at `b5d4135`).
- `codesys/` (each help page as `.html` and `.txt`).
- `conv/` (the conventional family's manuals as `.pdf` and `.txt`; file names are the
  numbers requested, so `1756-rm003.*` holds 1756-RM018A and `1756-rm084.*` holds
  1756-RM014D; `kb52497.*` is the testing article).
- `siemens/s71500-cycle.*`, `nxp-cwpabtr.pdf`, `cwpabtr.txt`, `nxp-an4498.pdf`,
  `an4498.txt`, `linguist-languages.yml`, and the registry pages `fi-*.html` (fileinfo),
  `fx-*.html` (filext), `fei-*.html` (file-extension.info).
- `mu2txt.py` extracts a PDF with PyMuPDF, installed into `pylib/`; `pdf2txt.py` uses
  pypdf with its cryptography import disabled, which reads the IEC copies but not the
  encrypted Ed 4 preview.
