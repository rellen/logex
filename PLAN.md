# Logex — development plan

Status of this document: written 2026-08-30 against commit `c9c7f51`, revised after an
adversarial review of the plan itself, and brought current after Milestone 0 was
implemented and merged (PRs #3 and #4). §3 onward, and every reference to
`CLAUDE.md`, anchors on function, clause and bullet names rather than line numbers —
deliberately: line numbers in this file have gone stale three times, most recently because
the commit that fixed the `compiler.ex` ones then edited `CLAUDE.md` and shifted those.
§1 and §2 keep their numbers; §2 is explicitly historical. It records the findings of a full
review of the codebase and turns them into an ordered plan.

**Keeping this document true.** Landing work stales it: §1's counts, §7's Status column and
any "Settled, not yet landed" bullet in the README all go out of date. The repo's practice
is a separate audit pass rather than editing this file in the same commit — but the pass
has to happen, or the next reader inherits a plan that disagrees with the code.

**§2 (Milestone 0) is complete.** It is kept as the record of what was wrong and why each
fix took the shape it did, so its present tense describes the code *before* those commits.
§1, §3·M1-1 to M1-6, §3's OE-1, §3's M2-1, §3's M2-5, §3's M2-2 and M2-3, §3's M2-4,
§3's M2-6, §3's OE-2, §3's M3-1, M3-2, M3-3, M3-4 and M3-5, and §3's Milestone 4 have been brought current. Milestone 2 was designed on 2026-10-02 (§3), its
first item, M2-1, landed the same day, M2-5 on 2026-10-04, M2-2 and M2-3 on 2026-10-11,
and M2-4 and M2-6 on 2026-10-12, so Milestone 2 is done; OE-2 was designed and landed on
2026-10-13 (§3), and Milestone 3 was designed and decided on 2026-10-14, its first four
items, M3-1, M3-2, M3-3 and M3-4, landing the same day and its last, M3-5, on 2026-10-15,
so Milestone 3 is done (§3, "Milestone 3"). Milestone 4, the wall-clock runner, was
designed and decided on 2026-10-17 (§3, "Milestone 4"), its first item, M4-1, landing the
same day, its second, M4-2, on 2026-10-18, and its third, M4-3, the same day, with the
answers to its review and the maintainer's two answers, decisions 130 and 131, the
answers to the verification of those, decision 132, and the maintainer's answer to that,
a fixed timer, which amends decision 130 and supersedes decision 132; and its fourth,
M4-4, the watchdogs and the fault path, the same day, its review's findings fixed on
2026-10-19, with five questions put to the maintainer, who answered them the same day,
each with the option recommended and built, decisions 133 to 137 (§3, M4-4); and its
fifth, M4-5, edits and forcing through the runner, on 2026-10-19, its review's
findings fixed the same day, four of its choices put to the maintainer, who answered them
the same day, decisions 138 to 141, the second with the option recommended, then built
(§3, M4-5); and its sixth, M4-6, the contract walk over the runner, the same day, with a
fix to the devices it found and one question put to the maintainer, its review's
findings fixed on 2026-10-20, and the maintainer's answer the same day, a restart that
reads every device first, decision 142, then built (§3, M4-6), and the maintainer's
confirmation the same day of two calls the lead made in its verifications, a report-only
reading kept across a restart, a fix within decision 142, and a refused change's good
points kept, decision 143; and its seventh and last, M4-7, the documents, the same day,
so every item of Milestone 4 has landed, its done sentence checked clause by clause
against the tests (§3, after M4-7): every clause is pinned by a test on the manual
clock, but the three of timing on the real clock, rounds back to back one a millisecond
at most, the share and the grid with its missed periods, are met there only under the
milestone's own rule, timing tested on the manual clock and a test on the real clock
asserting liveness, the plant's 2 s run asserting no more rounds than milliseconds and
nothing finer, a reading the maintainer accepted on 2026-10-20, so Milestone 4 is done.
Milestone 5, data types, was designed and decided on 2026-10-21 (§3, "Milestone 5";
`docs/organisation.md` §4.12 and decisions 144–160), the maintainer answering its sixteen
questions and a follow-up the same day, six of them otherwise than recommended, among
them integer overflow wrapping in every width, which supersedes decision 77; the
record's ten questions put back to the maintainer and its three open rules were answered
the same day (decisions 161–167, and notes on the decisions the rest settle), three of
the ten otherwise than the record read them: a real too large for its integer target
rounded and then wrapped (161), the truncations named `real_trunc_int` (162), and
`ctu_dint`, `ctd_dint` and `ctud_dint` aliases of `ctu`, `ctd` and `ctud` (163); its
sixteen items, M5-1 to M5-16, are planned, and the first, M5-1, one table of types, landed
the same day with no behaviour changed (§3, M5-1), and the second, M5-2, on 2026-10-22:
the dint wraps, decision 77's saturation superseded on purpose (§3, M5-2); the
maintainer's four answers to their reviews' questions landed the same day (decisions
168–171, §3 after M5-2): a program type named with no article, a hand-edited program's
port holding an instance the host's mistake, the type table's width in bits, and a value
a state holds outside its tag's type refused where the state is handed in; and the third,
M5-3, the same day: IEC's eight integer widths declared everywhere a dint is, `move` and
literals by Figure 11, and the 56 integer conversions (§3, M5-3); and the maintainer's
eight answers to M5-3's and decision 171's questions the same day (decisions 172–179, §3
after M5-3): a value a state holds that is no integer refused as one outside its type is,
a conversion's source widening into its `from` type, every width's misfit told its range,
and a conversion of a literal warned, the other four confirmed as built; and the fourth,
M5-4, the same day: arithmetic and comparison over every integer width, computed in the
destination's type, each source widening into it by Figure 11 (§3, M5-4), its review's
four findings fixed the same day; and the maintainer's seven answers to M5-4's four
questions and to the three decision 173's answers left (decisions 180–186, §3 after
M5-4) the same day: a `neg` into an unsigned destination told a signed type to declare,
a program edited by hand whose arithmetic destination has no integer type refused where
it is handed in, a literal compared with a tag its type cannot hold refused, and an
instance's tag that holds no map and a timer's `last` that is no integer refused as every
value outside its type is, the other two confirmed as built. And the fifth, M5-5, the same day: IEC's
typed counters, `ctu_int` to `ctud_ulint`, run by `ctu` and `ctd` and each stopping at its
type's limits, and `ctu_dint`, `ctd_dint` and `ctud_dint` the very types of `ctu`, `ctd`
and `ctud` (§3, M5-5), with three questions put to the maintainer, its review's seven
findings fixed the same day; and the maintainer's seven answers to M5-5's three questions
and to the four readings decisions 180–186 left (decisions 187–193, §3 after M5-5) the same day: a
comparison whose literal sits at its tag's type limit warned, a timer's `last` later than
`now` refused, a literal `neg` source told the type its negation fits, decision 182's
check made once where a program is handed in, a scan costing what it did before it, a
signed counter's preset negative too, and a counter slot naming every word it runs, the
unknown type's list kept. And the sixth, M5-6, the same day: the long timers, `ton_ltime`,
`tof_ltime`, `tp_ltime` and `rto_ltime`, run by `ton`, `tof`, `tp` and `rto`, their `.pre`
and `.acc` lint nanoseconds, each millisecond of the clock adding 1,000,000, a preset
that is no whole number of milliseconds warned of (§3, M5-6), with three questions put to
the maintainer; and M5-6's review's three findings fixed the same day, a plain timer's
scan brought back within about 3% of its cost before long timers, with one more question;
and the maintainer's eight answers to M5-6's four questions and to the four readings
decisions 187–193 left (decisions 194–201, §3 after M5-6) the same day: a literal taken
beside a long timer's `.pre` or `.acc` that is no whole number of milliseconds warned, as
a preset is, each timer's unit carried in the compiled program so that a plain timer's
run costs what it did before long timers, and an edit's accept checking the program
running as well as its candidate, the other five confirmed as built. And the seventh,
M5-7, the same day: based literals, `16#ff` and `2#1010_0000`, and `_` between digits,
`1_000`, each the number it spells, judged by its slot, so that `16#ffff` fits a `uint`
and is refused for an `int`, with one question put to the maintainer (§3, M5-7); and
M5-7's review's five findings fixed the same day, two rules of decisions 196 and 200
pinned and a based number with a second `#` named whole; and the maintainer's answers to
M5-7's two questions (decisions 202 and 203, §3, M5-7) on 2026-10-23: a rung keeps a
literal's spelling, so `16#00ff` prints back as typed and every message quotes a literal
as written, its value still what every stage computes with, and a second `#` refused as
built, with two more questions. And the eighth, M5-8, the same day: IEC's bit strings,
`byte word dword lword`, declared everywhere an integer is, located too, with no
arithmetic; the bitwise instructions `and or xor not shl shr rol ror` on bit strings and
integers alike, in the destination's type; literal bit access, `status.3`, read by a
contact and written by a coil; and the 76 bit-string conversions, binary transfers, with
four questions put to the maintainer (§3, M5-8); and M5-8's review's six findings fixed
the same day, four rules pinned, a bit quoted as written, a member's bit warned beside a
whole write of the member, decision 187's warning given for a bit string, and a program
of no bit strings compiling in what it did before M5-8, with two more questions; and the
maintainer's answers to M5-8's six questions (decisions 204 to 209, §3, M5-8) the same
day, five confirming what was built and one a change: a `bool` is a bitwise operand, as
IEC's ANY_BIT holds BOOL, so `and left right both` of three bools is the AND of two
switches and a bool widens into a bit string, never into an integer. And the ninth,
M5-9, the same day: a bit whose number a tag holds, `status.[n]`, read by a contact and
written by a coil, its number out of the word's bits the first major fault, the
instruction doing nothing and the scan running on, on which `Logex.Runner` trips at the
end of the step that met it, before the round's write, with four questions put to the
maintainer, and its review the same day, a warning grown, a bracket's lex error named
whole and five tests that were missing, with a fifth (§3, M5-9); and the maintainer's
answers to its five questions (decisions 210 to 214, §3, M5-9) the same day, three
confirming what was built and two changes: a literal in brackets, `status.[4]`, is the
very bit `status.4`, so that text pasted from Logix compiles, and `not` and the shifts
follow IEC's typing, computing in their source's type, so `not left mask` of a bool into
a `word` is 16#0000 or 16#0001. And the tenth, M5-10, the same day: the reals, `real` and
`lreal`, declared everywhere an integer is, every write rounded to its type's nearest
value, a `real`'s a single, so `move 0.1 x` reads back as 0.10000000149011612, with no
infinity, NaN, −0.0 or subnormal ever held; real literals, `37.5` and `1.5e3`; the
arithmetic and comparisons by Figure 11; `sqrt`, a negative source 0.0 and a minor fault;
the 34 real conversions, rounding a tie to even and then wrapping, and the 16
truncations; and real points and forces, the forces file spelling a real so that it reads
back exactly, with four questions put to the maintainer (§3, M5-10); and its review the
same day, a real literal read as the real its slot computes in, so that a setpoint moved
into a `real` equals the very literal, and six tests that were missing, with a fifth
question (§3, M5-10); and the maintainer's answers to its five questions (decisions 215
to 219, §3, M5-10) the same day, two confirming what was built and three changes: a real
literal outside its real's normal range is refused in both directions, `move 1.0e-40
fan_speed` as well as `move 1.0e39 fan_speed`; a forces file's real point takes any number
that reads as a value of its type, `fan_hz 37.50` as 37.5; and a real literal its real
rounds visibly, `16777217.0` in a `real`, compiles with a warning naming what it is held
as. And the eleventh, M5-11, the same day: arrays of an elementary type, one
to three dimensions, `var weights int[8]` and `var grid int[4,8]`, an initial list in the
elements' order, each element named by literal subscripts, `weights[3]` and `grid[1,7]`,
checked against its dimension when the program compiles; a one-shot on an element; a
host's array input a list of its shape; an edit refusing a size changed and reporting an
initial list element by element; and in a configuration unlocated global arrays,
`var_external` arrays bound exactly, connections whole and by element and `get/2` paths,
with four questions put to the maintainer (§3, M5-11), and its review's fixes the same
day, with two more (questions 5 and 6); and the maintainer's answers to those six and to
M5-10's three follow-ups the same day (decisions 220 to 228, §3, M5-10 and M5-11), three
confirming what was built and six changes: a bit of an array element, `faults[2].3` and
`faults[2].[n]`, wherever a tag's bit goes; a host setting one element of an input array,
`%{"steps[3]" => 5}`; an element of a global array at a connection's far end, `m2.speed
speeds[1]`; a forces file's integer or bool line in any spelling of a number, `level
16#ff`; a rounded real initial value warned of, `var sp real 16777217.0`; and a literal
too near 0.0 for an lreal, `move 1.0e-310 big`, refused by its slot naming the
instruction and the tag. And the twelfth, M5-12, on 2026-10-24: a subscript held in an
integer tag, `weights[slot]`, checked as the element is read or written, one out of its
dimension the major fault `:index_out_of_range`, on which the runner trips (§3, M5-12),
with its review's fixes the same day; and the maintainer's answers to M5-11's four
follow-ups and M5-12's four questions the same day (decisions 229 to 236, §3, M5-11 and
M5-12), three confirming what was built and five changes: `1.0e-400` refused by its
slot; an edit reporting each element no longer driven held by name; an index fault's
`read` a tuple, `{8}`; a write through a tag subscript beside a coil on a bool array's
element warned; and a configuration's writer warning naming the element two writers may
share, with four questions put to the maintainer. And the thirteenth, M5-13, the same
day: a located array, `var_global temps real[8] at card.i.0`, one point an element at
consecutive addresses, read, written and forced by its name, `temps[3]` (§3, M5-13),
with four questions put to the maintainer, and its review's fixes the same day, with
three more; and the maintainer's answers to those seven and M5-12's four follow-ups the
same day (decisions 237 to 247, §3, M5-12 and M5-13), five confirming what was built and
six changes: `1.0e-400` refused in a configuration line in its global's words and held at
0.0 in the forces file; the elements an instance writes named on one warning line;
`eq 1.0e-400 0.0` refused; a located array named whole taking a list, as an input, a
force, an unforce and a forces file's line; a located array grown refused once, for its
range; and a coil beside another write of the very element through the very tag warned of
nothing, with three questions put to the maintainer. And the fourteenth, M5-14, the same
day: arrays of timers, counters and blocks, `var lane_t ton[4]`, each element run by
literal subscripts and its members read and written through a tag subscript (§3, M5-14),
with four questions put to the maintainer; its review answered on 2026-10-25, M4-6's
runner walk, which M5-14's code commit had deleted, put back, an edit of a large array of
instances made linear in wall time, four surviving mutants pinned, and two questions put
to the maintainer; and the maintainer's answers to those six and M5-13's last three on
2026-10-26 (decisions 248 to 256, §3, M5-13 and M5-14), five confirming what was built and
four changes: a subnormal literal beside a literal, `gt 1.0e-310 0.0`, refused; a member
through a tag subscript beside a literal element's, `ote lane_c[i].r` and `ote
lane_c[1].r`, the second-`ote` warning; a block's member retyped in an array of its
instances refused once, for the array; and a forces file's bad value quoted as written and
as read, with three questions put to the maintainer. And the fifteenth, M5-15, the walks'
cross-type reach, the same day (§3, M5-15): every pair of types through `move`, each
conversion's two slots, `add`, `and` and a connection, and programs, resources and the
runner walk that mix every type, against oracles that restate each rule; the one defect it
found, a truncation's misfit told the rounding conversion, fixed, with two questions put
to the maintainer; and its review's findings fixed the same day: four surviving mutants
pinned, the walks' reach raised to the rules they met only by chance, which found a
defect, `not` and the shifts of a user block's member computed in the destination's type,
fixed, the runner walk's two failing families traced to its model and fixed, its seed back
at `{2026, 10, n}` with its draws raised, a loosened check scoped back, and three
questions put to the maintainer. And the sixteenth and last, M5-16, the documents, the
same day (§3, M5-16): README's every example run again, its "What logex is not" and
"Settled, not yet landed" made true, CLAUDE.md's Key Files tightened, `docs/naming.md`'s
`bool`, `dint` and `at` stanzas and its deferred and rounding rows amended,
`docs/organisation.md` §4.1, §4.5, §4.7, §4.8, §4.12 and §5 annotated as landed, and
the head of decisions 144 to 256 so too, the Logix and IEC claims of Milestone 5's record checked against the extracts, each
citation and claim found false corrected where it stands, so every item of Milestone 5
has landed, its done sentence checked clause by clause against the tests and put to the
maintainer (§3, after M5-16); and its review's findings fixed the same day: the one plant
the done sentence names built as a test, every elementary type, a `ctud_int` box counter,
the fan's `real`, the oven's located `real[8]` and `weights[slot]` from files on disk
through `Logex.Runner` against an oracle, `Logex.Tag`'s and `Logex.Edit`'s docs made true,
three IEC page citations corrected, and the eight questions still open on Milestone 5's
provisional readings gathered in one list (§3, M5-16's review).

Every claim below was reproduced by executing code against a scratch copy of the
repository (Erlang/OTP 25, Elixir 1.14). Where a fix is proposed it was applied to that
copy and the result checked, including `mix test` and, for grammar changes, a yecc
conflict check. Where a proposed fix turned out not to work as first written, the
corrected version is what appears here. Claims that ran on the pinned Elixir 1.20.4 /
OTP 28 instead say so; the yecc conflict check went with yecc (§6).

---

## 1. Where we stand

Logex is a Ladder Logic compiler and interpreter using a conventional ladder instruction
vocabulary. Its code is all hand-written — `lib/`, `test/` and `mix.exs`; the one
generated file is the golden record, `test/fixtures/frontend_golden.txt` — and it has no
dependencies. The front end is `Logex.Lexer` and `Logex.Parser` (§6
says why they are hand-written); `Logex.Compiler` delegates `tokenize/1` and `parse/1` to
them and holds the validating lowering; `Logex.Printer` turns a parse AST back into source.
Since M1-5 a host calls none of those stages: `Logex.compile/2` and `Logex.compile_file/1`
run the first three and return one error type, and `Logex.Runtime` runs the scans, through
an evaluator that is private to it (B5). The stage functions stay public for the tests.

```
 source string
   │  Logex.Compiler.tokenize/1        Logex.Lexer              binary pattern matching
   ▼  {:ok, tokens, endline}
 [{:name,{1,1},"xic"}, {:name,{1,5},"aa"}, {:bst,{1,8}}, {:name,{1,10},"mov"}, {:int_lit,{1,14},123}, …]
   │  Logex.Compiler.parse/1           Logex.Parser             recursive descent
   ▼  {:ok, ast}
 {:routine, {:rungs, [{:rung, [{:name, 1, "xic"}, {:name, 1, "aa"}, {:branches, [[…]]}]}]}}
   │  Logex.Compiler.instructionize/2  declarations to a tag table (Logex.Declarations);
   │                                   lowering, checked against each operand signature
   │                                   and each tag's declaration
   ▼  {:ok, program} | {:error, [%Logex.Diagnostic{line:, message:}]}
 %Logex.Program{rungs: [{:rung, [{:xic, 3, [{:name, 3, "aa"}]}, {:ote, 3, [{:name, 3, "bb"}]}]}],
                tags: %{"aa" => %Logex.Tag{type: :bool, section: :var_input, …}, …}}
   │  Logex.Runtime.call/4             the evaluate/3 clauses, private: a {power_flow, env} fold
   │                                   with the scan's read-only %Logex.Scan{now:, first:}
   ▼  {outputs, %Logex.Instance{env: %{"aa" => 1, "bb" => 1}, …}}
```

### What works

- Series contacts, parallel branches to arbitrary nesting depth.
- `xic`, `xio`, `ote`, `otl`, `otu`, `move` with **correct** latch/unlatch retention semantics.
- Multi-rung routines, with power flow correctly reset per rung.
- Driven one scan at a time through `Logex.Runtime` (M1-5), a correct seal-in motor circuit.
- `ton` on the injected clock, `ons`, and `eq ne lt gt le ge` (M1-6); a timer is a declared
  instance, `var t1 ton`, whose members `t1.dn` and `t1.acc` are read anywhere.
- A staged online edit of one running instance (OE-1): `Logex.Edit` accepts a candidate
  beside the running program, then tests, untests, assembles or cancels it between two
  scans, moving the state by name and reporting every step.
- A configuration built from Elixir data (M2-1): `Logex.Configuration` holds program
  types, periodic tasks, globals located at input and output points or not, program
  instances and their connections, checked by one validator, and `Logex.Runtime` runs it
  as one resource, a cycle at a time on the injected clock, by priority, with missed
  periods counted and reported.
- User function blocks (M2-5): a file headed `function_block seal` compiles to a
  `%Logex.FbType{}`, which `Logex.compile/2` takes in `types:` and `Logex.compile_file/1`
  loads from beside the file that names it; a program declares instances, `var s1 seal`,
  runs each with `cal`, rung power its EN, and reads its outputs, `s1.run`, anywhere.
  Blocks nest, a block never holds itself, and an online edit moves a block's members by
  path.
- A configuration file (M2-2, M2-3): `plant.logex` declares periodic tasks, globals at
  input and output points or not, program instances and arrow-free connections, and
  `Logex.Configuration.compile_file/1` reads it, loads each program type from its `.ld`
  file beside it, and checks it with M2-1's one validator, every mistake a diagnostic at
  its file and line in the configuration file's words; `Logex.Configuration.Text` prints
  a configuration back to its text, exactly. `Logex.compile_file/1` takes a `.ld` file
  only.
- Globals shared by name (M2-4): `var_external estop bool` in a program's `.ld` file
  names the configuration's `var_global estop bool`, bound by name and type and checked
  once a program type; a scan reads and writes the global itself, one copy in the
  resource, and two writers of one global are warnings. `Logex.Walk` is the one walk of a
  program's IR that the checks read.
- IEC's counters (M3-1): `var boxes ctu`, `var hopper ctd` and `var stock ctud`, run by
  `ctu boxes 12` and `ctd hopper 40`, a `ctud` by one of each on two rungs; a rising edge
  counts, never on a first scan; the reset `r` and load `ld` are inputs a rung writes; the
  count stops at the dint's limits with `ov` or `un` latched; and an online edit moves a
  counter's `pv`, forecasts its `q` and blocks an edge it would otherwise make.
- The other timers (M3-2): IEC's off-delay `tof`, `.dn` on through its delay, and pulse
  `tp`, its pulse `.tt` from a rising edge, never on a first scan, and the conventional
  retentive `rto`, keeping its time across a false rung and cleared by its `r` input; each
  a timer by every rule a `ton` keeps, its forecast and resume by its own type across an
  online edit, a `tp`'s edge blocked as a counter's is, and each warned of under an event
  task in its own words.
- Integer arithmetic (M3-3): `add sub mul div mod neg abs` on dints, the result brought to
  the nearer limit with no power on that scan, IEC's ENO, and since M5-2 wrapped instead,
  its low 32 bits kept, with no power and no fault (decision 146); a zero divisor 0 and no power,
  reported to the host as a minor fault, a `%Logex.Fault{}` in a lone instance's state and
  a `{:fault, ...}` event of a cycle; and negative literals, `-5`, a sign glued to its
  digits.
- The pulse coils (M3-4): IEC's transition-sensing coils in the conventional set's form,
  `osr s1 pulse` and `osf s1 pulse`, a pulse for one scan on the rise or the fall of the
  power the coil receives, never on a first scan, that power passed on, the storage bit
  under every rule an `ons` bit keeps.
- A forward jump (M3-5): `jmp auto`, once its rung is done, skips the rungs after it up to
  the one `lbl auto` heads, which runs; a skipped rung runs nothing, frozen as a block
  whose `cal` is false is, a timer in it catching up when next run; a jump back, to its
  own rung or to a label its routine lacks, and a label not first on its rung, are each a
  located diagnostic; and a label is a name of its routine's own, never a tag.
- A staged online edit of a running configuration (OE-2): `Logex.Configuration.Edit`
  accepts a candidate configuration against the resource that runs the original, refusing
  what changes only with a restart at its line, then tests, untests, assembles or cancels
  it between two cycles: each kept instance moved by its program type's one plan,
  instances started, set aside and brought back, globals started and held, every step
  reported, and a stale edit refused by the resource's generation.
- Watchdogs and the continuous task (M4-2): a task line takes `watchdog <ms>` after its
  priority, 500 ms unless set, and one line may declare the continuous task, `task main
  continuous watchdog 200`, which runs every instance with no timed task, `with main` or
  none, after the due tasks, each run reported under its name; a watchdog changes while
  the plant runs, and the runner reads it, below.
- The wall-clock runner (M4-1, M4-3 to M4-6): `Logex.Runner` runs a configuration's
  resource on a clock, `Logex.Runner.Clock`'s monotonic one or a manual one a test moves,
  through devices bound to adapters (`Logex.IO`, with `Logex.IO.Sim` the one shipped),
  its untimed programs back to back, one round a clock millisecond at most, a share kept
  for its own work, and each timed task on its grid; a watchdog on every task, a device's
  deadline and an idle watchdog trip it, every output 0 once, until a cold or warm
  restart, which reads every device first; a stop and its death zero every output too;
  inputs are forced, kept in a file across a crash; and an online edit is stepped
  through it between rounds. README's "Running a plant on the clock" runs it, and "What
  logex is not" says what it is not, a safety controller first.
- Data types (Milestone 5, M5-1 to M5-16): IEC's eight integer widths, `sint` to
  `ulint`, a result past its width wrapping with no power, with the 56 conversions between
  them; based literals, `16#ff`, and `1_000`; the four bit strings, `byte word dword
  lword`, with `and or xor not shl shr rol ror`, bit access `status.3` and `status.[n]`
  and the 76 bit-string conversions; the reals, `real` and `lreal`, every write rounded to
  its type's nearest value, with `sqrt`, the 34 real conversions and the 16 truncations;
  IEC's typed counters and long timers in nanoseconds; and arrays of one to three
  dimensions, of every elementary type and of instances, by literal subscripts or ones a
  tag holds, located too. An index or a bit number out of range is a major fault, on
  which the runner trips; a zero divisor and a negative square root are minor faults; a
  mixed operand Figure 11 does not widen is refused naming its conversion; and an online
  edit refuses a changed type or size and reports a changed initial value. README's
  sections from "Arithmetic" to "Arrays of instances" run each.

These were each verified directly:

```
OTE de-energises on a false rung      xic gg ote xx  gg=0,xx=1  ->  %{"xx" => 0}
OTL is retentive on a false rung      xic gg otl xx  gg=0,xx=1  ->  %{"xx" => 1}
branches OR, env threads in order     ( xic gg ote mm | xic mm ote zz )
                                                     gg=0,mm=1  ->  mm=0, zz=0
no short-circuit — every branch runs  ( xic aa ote p1 | xic bb ote p2 ) ote res
                                       aa=1,bb=0,p2=1 -> p1=1, p2=0, res=1
nested branch = a AND (b OR c)        xic aa ( xic bb | xic cc ) ote res
                                       aa=1,bb=0,cc=1 -> res=1
rung independence (flow resets)       xic gg ote r1\note r2   gg=0  ->  r1=0, r2=1
```

The grammar, left-factored as `Logex.Parser` implements it, is LL(1) — every decision is
made on the next token — for a language with arbitrary branch nesting. Nothing checks that
mechanically since yecc went (§6); the golden record and the printer's round-trip
generator stand in. On 1.20.4, `mix format --check-formatted` and
`mix compile --force --warnings-as-errors` both exit 0.

### What does not work

The three things this section listed before Milestone 0 — `mov` with an integer literal,
any source read from a file, and single-character tag names — all work now; M0-1, M0-5 and
M0-4 closed them. Of the three listed below, two gave *wrong answers* silently and one an
unusable error; all three are closed now.

- **`xic` and `xio` were not complementary.** ***Closed — M1-3 and M1-4.*** Two
  independent *positive* tests, so a tag holding anything outside `{0,1}` — or no value at
  all — read false for both. M1-3 made it unreachable from source: `move 250 sp xic sp ote
  hi`, which gave `hi=0`, is a compile error however `sp` is declared. M1-4 closed it for an
  env the host builds by hand: `xio` is now the negation of `xic`, whatever the value.
- **A missing space before `nxb` silently turned OR into AND.** ***Closed — §4·B1.***
  `bst xic aa nxb xic bb bnd ote dd` with `aa=0,bb=1` gave `dd=1`; deleting the one space
  before `nxb` gave `dd=0`, with no error anywhere. The delimiters are `(` `|` `)` now,
  which are outside `NAME` and cannot fuse.
- **There was no validation of any kind.** ***Closed — M1-2.*** An unknown mnemonic, a
  wrong-case mnemonic or a wrong operand count survived to `instructionize/1` or
  `evaluate/2` and raised a bare `MatchError` or `FunctionClauseError` naming neither the
  mnemonic nor the line, and `mov src ote` wrote a tag called `ote` with no error at all.
  Each is now a located diagnostic, `XIC aa` is simply `xic aa`, and every mistake in a
  routine is reported, not just the first.

### The gap that let this happen — now closed

There was no test anywhere that ran a source string through to an environment. Each
stage's test hand-typed its own input, so a mismatch at a stage boundary was invisible: the
two downstream fixtures **disagreed with each other** — `instructionize_test.exs:38` said
`int_lit:`, `evaluation_test.exs:13` said `lit_int:` — and both were green.

M0-2 closed this with `test/logex/end_to_end_test.exs` (`03c10e0`), which drives source to
an environment and names no IR tag in any assertion — its one AST match is the
`{:routine, {:rungs, _}}` wrapper used to count rungs — so no fixture in it can encode a
stage-boundary mismatch. M0-1 (`690fc2d`) reconciled the fixtures on `:int_lit` —
`evaluation_test.exs:19` and `:69` now read `{:move, 2, [{:int_lit, 2, 123}, …]}`, the 3-tuple since M1-1
(`a22bf39`) — and the `:lit_int` atom appears nowhere in the tree.

---

## 2. Milestone 0 — make a green test run mean something — DONE

**All five items are landed and merged; nothing in this section is waiting to be done.**
M0-1 `690fc2d`, M0-2 `03c10e0`, M0-3 `dde8c1d`, M0-4 `3f3b104` (PR #3, merge `22bc81a`);
M0-5 `b65e756` (PR #4, merge `863af6f`). Re-verified on `main` after M1-1: `mix test` →
`27 tests, 0 failures`. M1-1 to M1-6 and §3's OE-1, a staged edit of one program
instance, have landed since; the next unstarted work is Milestone 2, designed on
2026-10-02.

The items are kept in full because their diagnoses are the record of *why* the code looks
the way it does — why the parser drops empty rungs, why `CLAUDE.md` once documented an
`rm -f src/*.erl && rm -rf _build` loop, why `end_to_end_test.exs` names no IR tag.
**Apart from each item's Status line, everything from here to the end of §2 describes the
tree as it stood *before* these commits: read the present tense as historical, and the
`.xrl` / `.yrl` / `CLAUDE.md` line numbers as pre-M0 ones.** The Status lines were current
when written, but the front end has since been rewritten by hand (§6): their `.xrl` and
`.yrl` references name files that no longer exist, and each rule or production they cite
is now code in `Logex.Lexer` or `Logex.Parser`.

### M0-1 · Fix the transposed literal atom `:lit_int` → `:int_lit`

**Status: DONE — `690fc2d` (PR #3).** `get_arg/2`'s literal clause now reads
`defp get_arg(_env, {:int_lit, _, val}), do: val` (the `_` line slot since M1-1), and both
`evaluation_test.exs` fixtures (`:14` and `:59`) say `{:int_lit, 2, 123}`. The scratch `e2e.exs` below was never committed; the
permanent check is `test/logex/end_to_end_test.exs`. Two refs in the diagnosis moved when
M0-5 landed: the `{INT}` rule is now `ladder_lexer.xrl:20` and `elem -> int_lit` is now
`ladder_parser.yrl:32`. The `1 doctest, 5 tests` in the acceptance block is this item's own
contemporaneous run; the suite was 27 tests when M1-1 landed.

**Severity: high.** `lib/logex/compiler.ex:119` matches `{:lit_int, val}`. The lexer
emits `int_lit` (`src/ladder_lexer.xrl:18`), the parser preserves it
(`src/ladder_parser.yrl:19`), and `instructionize/1` passes operands through untouched
(`compiler.ex:35`). Since `mov` is the only instruction taking a literal, the entire
integer-literal feature is dead end to end.

Reproduce with a scratch `e2e.exs` in the project root — the initial env is load-bearing,
since with an empty env the movs write `nil` and the failure looks different:

```elixir
run = fn src, env ->
  try do
    {:ok, toks, _} = Logex.Compiler.tokenize(src)
    {:ok, ast} = Logex.Compiler.parse(toks)
    ast |> Logex.Compiler.instructionize() |> Logex.Compiler.evaluate({true, env})
  rescue
    e -> {:RAISED, Exception.message(e) |> String.split("\n") |> hd()}
  end
end

show = "( mov aa bb | mov cc dd | mov ee ff ( mov 123 hh ) ) ( ote xx | ote yy )"
IO.inspect(run.(show, %{"aa" => 1, "cc" => 2, "ee" => 3}), label: "showcase")
IO.inspect(run.("mov 123 dd", %{"dd" => 0}), label: "mov literal")
IO.inspect(run.("mov aa dd", %{"aa" => 7}), label: "mov tag->tag")
```

```
$ mix run e2e.exs
showcase:     {:RAISED, "no function clause matching in Logex.Compiler.get_arg/2"}
mov literal:  {:RAISED, "no function clause matching in Logex.Compiler.get_arg/2"}
mov tag->tag: {true, %{"aa" => 7, "dd" => 7}}
```

The suite is green because `evaluation_test.exs:13` and `:56` hand-write the same
misspelling into their input, so the typo appears on both sides and cancels.
`git log -S` shows the clause, the wrong fixture, and a *correct* `int_lit` fixture in
the sibling file were all introduced in `ec0534a` — whose suite was already red from an
unrelated lexer bug, so the fixture cannot have been transcribed from real output.

**Fix as three coordinated sites in one commit.** Changing only `compiler.ex` turns a
green suite red (2 failures), which invites a revert.

```diff
--- a/lib/logex/compiler.ex
+++ b/lib/logex/compiler.ex
@@ -119 +119 @@
-  defp get_arg(_env, {:lit_int, val}), do: val
+  defp get_arg(_env, {:int_lit, val}), do: val

--- a/test/logex/evaluation_test.exs
+++ b/test/logex/evaluation_test.exs
@@ -13 +13 @@   (and identically at :56)
-             [{:xic, [name: "bit0"]}, {:mov, [lit_int: 123, name: "dd"]}]
+             [{:xic, [name: "bit0"]}, {:mov, [int_lit: 123, name: "dd"]}]
```

**Acceptance** — verified on a scratch copy, same `e2e.exs`:

```
$ mix run e2e.exs        # after the fix
showcase:     {true, %{"aa" => 1, "bb" => 1, "cc" => 2, "dd" => 2, "ee" => 3,
                       "ff" => 3, "hh" => 123, "xx" => 1, "yy" => 1}}
mov literal:  {true, %{"dd" => 123}}
mov tag->tag: {true, %{"aa" => 7, "dd" => 7}}
$ mix test
1 doctest, 5 tests, 0 failures
```

The showcase case becomes the first seed of `test/logex/end_to_end_test.exs` in M0-2,
after which the permanent check is just `mix test` and `e2e.exs` can be deleted.

### M0-2 · Add an end-to-end test that never names an IR tag

**Status: DONE — `03c10e0` (PR #3).** `test/logex/end_to_end_test.exs` exists: 14 tests,
none of whose *assertions* names an IR tag (one helper matches the
`{:routine, {:rungs, _}}` wrapper to count rungs). It carries all four seeds described
below plus rung counts, an empty program, jumper legs and unbalanced-branch rejection —
14 of the suite's 24 tests as it landed; it was 18 of 27 when M1-1 landed.

**Severity: medium.** Without this, M0-1 recurs. The test must drive source → env so
that no fixture can encode a stage-boundary mismatch.

```elixir
defp run(src, env) do
  {:ok, t, _} = Logex.Compiler.tokenize(src)
  {:ok, ast}  = Logex.Compiler.parse(t)
  ast |> Logex.Compiler.instructionize() |> Logex.Compiler.evaluate({true, env})
end

test "mov of a literal, source to env" do
  assert {_, %{"dd" => 123}} = run("mov 123 dd", %{"dd" => 0})
end
```

Seed `test/logex/end_to_end_test.exs` with two reproductions and two regression guards —
**not four failures.** Only two of the four fail today.

Broken today: the `lex_and_parse_test.exs:6` showcase string (green once M0-1 lands), and
a source with a trailing newline. Already correct, and seeded so they stay that way: the
multi-rung routine from §1, `"xic gg ote r1\note r2"` with `gg=0` → `%{"gg" => 0,
"r1" => 0, "r2" => 1}`; and a seal-in circuit, which needs three `run/2` calls because one
call is one scan and retention is only visible across scans:

```
seal = "( xic start | xic motor ) xio stop ote motor"
scan 1  start=1                  -> %{"motor" => 1, "start" => 1, "stop" => 0}
scan 2  start=0 (seal holds)     -> %{"motor" => 1, "start" => 0, "stop" => 0}
scan 3  stop=1  (drops out)      -> %{"motor" => 0, "start" => 0, "stop" => 1}
```

**The trailing-newline case could not pass until M0-5, three items later.** It was tagged
`@tag :skip` so M0-3 and M0-4 landed against a green suite — CLAUDE.md's `mix test` bullet says tests must
pass before committing, and M0-3's whole subject is a build trap that a trustworthy
`mix test` is what catches. That happened as planned: `b65e756` dropped the tag, no
`@tag :skip` remains anywhere in `test/`, and the case is green and unskipped.

### M0-3 · Untrack the generated scanners, and correct `CLAUDE.md`

**Status: DONE — `dde8c1d` (PR #3), and since moot: the front end is hand-written (§6), so
there are no generated scanners to track or untrack.** At the time, `git ls-files src/`
listed only the `.xrl` and the `.yrl`, `.gitignore` carried `/src/*.erl`, and a fresh clone
ran leex and yecc. (`.gitignore` carries it again, for a checkout built before §6: see
CONTRIBUTING's "The test output will lie to you".)
`CLAUDE.md` was rewritten in the same commit (31 lines before it), so every `CLAUDE.md:`
number below — and in §7's row — is a pre-M0 one. What shipped is slightly *stronger* than
the wording proposed here: it bolds the `rm -f` step, says the edit **is** silently ignored
rather than "may be", and names the tell ("`mix compile` prints nothing and `mix test`
stays green"). The Key Files bullet was rewritten too, and gained rows for
`end_to_end_test.exs` and `PLAN.md`.

**Severity: medium.** CLAUDE.md's `mix compile` bullet said it "regenerates `.erl` from
`.xrl`/`.yrl`". It does not. Mix's leex/yecc compilers are mtime-gated at whole-second
granularity, and `git clone` writes the `.xrl` and the tracked `.erl` inside the same
second. On a fresh clone `mix compile` prints `Compiling 2 files (.erl)` — leex never
runs, `git status` stays clean, and the **committed** scanners are the build input.

Combined with the then-current Key Files bullet ("edit these, not the generated `.erl`
files"), the doc instructed a workflow that produced silently-dead commits. That bullet is
now reads "The generated `src/*.erl` are build artifacts, not
tracked; never edit them." The full loop, as reproduced before the fix:

```
$ sed -i 's/^NAME = .*/NAME = [a-zA-Z_][a-zA-Z0-9_]*/' src/ladder_lexer.xrl
$ git commit -am "fix NAME regex (edited .xrl only, per CLAUDE.md:14)"
$ git clone . ../clone2 && cd ../clone2
$ sed -n '5p' src/ladder_lexer.xrl
NAME = [a-zA-Z_][a-zA-Z0-9_]*            # the fix IS in the clone
$ mix compile
Compiling 2 files (.erl)                 # leex never runs
$ mix run -e 'IO.inspect Logex.Compiler.tokenize("ote a")'
{:error, {1, :ladder_lexer, {:illegal, 'a'}}, 1}   # …and has no effect
$ touch src/ladder_lexer.xrl && mix compile
Compiling 1 file (.xrl)
$ mix run -e 'IO.inspect Logex.Compiler.tokenize("ote a")'
{:ok, [{:name, 1, "ote"}, {:name, 1, "a"}], 1}
```

**Fix.** `git rm -f src/ladder_lexer.erl src/ladder_parser.erl` — note `-f`, **not**
`--cached`. `git rm --cached` leaves the files in the working tree, and mix then still
compiles them as `.erl` inputs; verified:

```
$ git rm --cached src/ladder_lexer.erl src/ladder_parser.erl
$ ls -1 src/*.erl
src/ladder_lexer.erl
src/ladder_parser.erl
$ mix compile
Compiling 2 files (.erl)     # leex still never runs
```

Then add `/src/*.erl` to `.gitignore`. An absent target regenerates, so this removes the
*fresh-clone* case — **but not the class.** leex and yecc write `src/*.erl` back into the
working tree, so from the first `mix compile` onward the whole-second gate is live again:
an `.xrl`/`.yrl` edit whose mtime lands in the same wall-clock second as the previously
generated `.erl` is silently skipped — `mix compile` prints nothing, `mix test` stays
green, and `git status` offers the dead edit for commit. Copying a built tree (`cp -r`)
reintroduces the same collision. The reliable edit loop for `src/*.xrl` / `src/*.yrl` is
therefore permanently:

```
rm -f src/*.erl && rm -rf _build && mix compile
```

Untracking also removes ~700 lines of cross-OTP churn: the
generated files embed absolute `/nix/store/…erlang-26.2.1/…` paths
(`src/ladder_lexer.erl:1`, `src/ladder_parser.erl:7`), so regenerating under a different
OTP produces a 699-line diff of pure prelude boilerplate.

**Tradeoff worth accepting.** Untracking makes the build depend on leex and yecc being
present, which they are not always: on Debian/Ubuntu they ship in `erlang-parsetools`,
a package separate from `erlang-base`.

```
$ dpkg -S $(erl -noshell -eval 'io:format("~s",[code:which(leex)]),halt().')
erlang-parsetools: /usr/lib/erlang/lib/parsetools-2.4.1/ebin/leex.beam
```

Today the tracked `.erl` masks that — a slim image with only `erlang-base` still builds.
Nix's `pkgs.erlang` bundles parsetools, so the dev shell is unaffected; the constraint
lands on whatever CI image M0/§4 introduces, which must install `erlang-parsetools` or
use a full Erlang image.

CLAUDE.md's `mix compile` bullet was then corrected to read (the landed wording is slightly stronger than
this draft):

> - `mix compile` — compile. leex/yecc regenerate `src/*.erl` from `.xrl`/`.yrl` only
>   when the `.erl` is absent or at least one whole second older. After editing a
>   `.xrl`/`.yrl`, run `rm -f src/*.erl && rm -rf _build` first, or your edit may be
>   silently ignored.

Done. The new-instruction recipe — CLAUDE.md's "New instructions, step 2" bullet — omitted that the de-energised `{false, env}` clause is **mandatory**;
following it literally yielded code that worked on an energised rung and raised
`FunctionClauseError` the moment a contact opened. It now states the mandate and names that
consequence. (§4's guard-clause collapse does not retire the underlying *code* trap: see
the Style bullet.)

### M0-4 · Fix the `NAME` regex — one line, two bugs

**Status: DONE — `3f3b104` (PR #3).** `src/ladder_lexer.xrl:5` now reads
`NAME = [a-zA-Z_][a-zA-Z0-9_]*`. The line number did *not* move, so the broken regex quoted
below is what line 5 used to say, not what it says now. Verified at the time:
`tokenize("ote a")` → `{:ok, [{:name, 1, "ote"}, {:name, 1, "a"}], 1}`. Since §6 the rule
is `Logex.Lexer`'s `is_name_start`/`is_name_char` guards and tokens carry a column; on
1.20.4, `{:ok, [{:name, {1, 1}, "ote"}, {:name, {1, 5}, "a"}], 1}`.

`3f3b104` shipped with no regression coverage — it touched `src/ladder_lexer.xrl` and
nothing else, and no test used a single-character tag or a bracketed name, so reverting the
regex in full left `mix test` green. Closed by `b8fc743`, which adds one test per bug in
`end_to_end_test.exs`, each failing only for its own half of the regex:

```
NAME = [a-zA-Z_][a-zA-Z0-9_]*   (as shipped)   0 failures
NAME = [a-zA-Z_][a-zA-Z0-9_]+   quantifier     1) single-character tag
NAME = [a-zA-Z_][a-zA-z0-9_]*   char class     1) brackets
NAME = [a-zA-Z_][a-zA-z0-9_]+   both           1) and 2)
```

**Severity: low** — the failure is loud and total, never a wrong answer; it is in M0
only because it is one character. `src/ladder_lexer.xrl:5` reads
`NAME = [a-zA-Z_][a-zA-z0-9_]+`.

- The `+` requires two characters, so single-letter tags — ordinary in ladder — are a
  hard lex error: `tokenize("ote a")` → `{:error, {1, :ladder_lexer, {:illegal, 'a'}}, 1}`.
- `a-zA-z` is a lowercase-`z` typo spanning ASCII 91–96, so ``[ \ ] ^ ` `` are legal
  inside identifiers. `ote a[3]` lexes as one name `"a[3]"` — it looks like array
  indexing works, but it is a weirdly-spelled scalar.

**Fix:** `NAME = [a-zA-Z_][a-zA-Z0-9_]*`. Keyword precedence was preserved — verified at
the time that `bst` still lexed as `{:bst,1}` while `bstx` lexed as a name. §4·B1 has since
made the delimiters punctuation, so there is no word keyword left to lose to `NAME`:
`tokenize("bst")` is now `{:ok, [{:name, {1, 1}, "bst"}], 1}` and the precedence question
is moot.

### M0-5 · Grammar: make newlines and empty branches derivable

**Status: DONE — `b65e756` (PR #4).** `src/ladder_parser.yrl:8` carries the empty-rung
filter and `:21` the `branch -> '$empty'` production; `ladder_lexer.xrl:10` and `:19` carry
`RND = (\r?\n)` and `({WHITESPACE}*{RND})+`. Two refs in the diagnosis are pre-M0 —
`rungs -> rung rnd rungs` is now `yrl:12` and `branch -> elems` is now `yrl:16`; both old
numbers are blank lines today. Since §6 the filter is `keep/2` in `Logex.Parser`, the empty
leg is `branch/2`'s last clause, and a newline run is `Logex.Lexer`'s two `?\n` clauses:
the second emits the `rnd`, the first swallows each newline after it.

This item originally opened by ordering M0-3 first and requiring
`rm -f src/*.erl && rm -rf _build` before every compile in M0-4 and M0-5. The sequencing is
spent, and so is the `rm -f` half. It outlived M0-3, which removed the fresh-clone case but
not the mtime gate, and lived in CLAUDE.md's `mix compile` bullet until the generated front
end went (§6). CONTRIBUTING's "The test output will lie to you" records what is left for
`.ex` files.

**Severity: medium.** `rungs -> rung rnd rungs` (`src/ladder_parser.yrl:9`) makes the
newline a mandatory *infix* separator, and `branch -> elems` (`:13`) via `elems -> elem`
requires every branch leg to be non-empty. Both are the same root cause: nothing can
derive empty.

```
"ote xx"            -> {:ok, …}
"ote xx\n"          -> {:error, {1, :ladder_parser, ['syntax error before: ', []]}}
"\note xx"          -> {:error, {1, …, ['syntax error before: ', 'rnd']}}
"ote xx\n\note yy"  -> {:error, {2, …, ['syntax error before: ', 'rnd']}}
""                  -> {:error, {999999, …}}
"bst xic aa nxb bnd ote xx"  -> {:error, {1, …, 'bnd'}}   # a plain jumper leg
```

One production plus one lexer rule fixes all six, with zero conflicts and no evaluator
change:

```diff
--- a/src/ladder_parser.yrl
+++ b/src/ladder_parser.yrl
@@ -5 +5 @@
-routine -> rungs : {routine, {rungs, '$1'}}.
+routine -> rungs : {routine, {rungs, [R || R = {rung, E} <- '$1', E =/= []]}}.
@@ -13 +13,2 @@
 branch -> elems : '$1'.
+branch -> '$empty' : [].

--- a/src/ladder_lexer.xrl
+++ b/src/ladder_lexer.xrl
@@ -10 +10 @@
-RND = (\n)
+RND = (\r?\n)
@@ -17 +17 @@
-{RND} : {token, {rnd, TokenLine}}.
+({WHITESPACE}*{RND})+ : {token, {rnd, TokenLine}}.
```

**Why the first hunk is not optional.** `rung -> branch` sits directly above
`branch -> '$empty'`, so allowing an empty branch leg also makes an empty *rung*
derivable. Without the filter, a leading or trailing newline materialises a phantom
`{rung, []}` — and a trailing newline is the most common shape a file on disk has:

```
"ote xx\n"             -> 2 rungs: [rung: [name: "ote", name: "xx"], rung: []]
"\note xx"             -> 2 rungs: [rung: [], rung: [name: "ote", name: "xx"]]
"ote xx\n\n\note yy\n" -> 3 rungs, the last empty
""                     -> 1 rung, empty
```

It is inert in today's `evaluate/2` (`{:rung, []}` folds to `{true, env}` unchanged),
which is exactly why it would go unnoticed — until M1-2's rung-scoped diagnostics and
M1-5's `%Logex.Program{rungs:}` start numbering rungs and every count is off by one. The
comprehension drops only top-level empty rungs; empty *branch legs* — the
`( xic aa | )` jumper — are untouched and still pass power. Equivalently the filter
can live in `instructionize/1`, which is more in keeping with §6's preference for a
newline-naive grammar; pick one. **Settled: the grammar.** The filter's boundary is
`E =/= []` on the *element* list, so `"( )"` survives as `{rung, [branches: [[]]]}` —
after this filter "empty rung" means *no tokens*, not *no effect*. Such a rung still
occupies a rung number, which is what M1-2's rung-scoped diagnostics and M1-5's
`%Logex.Program{rungs:}` will see.

The `RND = (\r?\n)` hunk is belt-and-braces: `\r` is already in `WHITESPACE`, so CRLF
lexed correctly before this change too. Keep it for explicitness, but the CRLF line in the
acceptance block below is earned by `branch -> '$empty'`, not by this hunk.

**Acceptance** — verified on a scratch copy. These transcripts predate §4·B1 and are left
verbatim, so their branches read `bst … nxb … bnd` where the language now writes
`( … | … )`; the same applies to the error block above.

```
$ erl -noshell -eval 'io:format("~p~n",[yecc:file("src/ladder_parser.yrl",[{report,true},{return,true}])]),halt().'
{ok,"…",[]}                    # empty warning list = zero conflicts
$ mix test
0 failures. The total is higher than M0-1's 5 — M0-2 added end_to_end_test.exs —
so read the failure count, not the total.

"ote xx\n"                 -> {:ok, %{"xx" => 1}}
"\note xx"                 -> {:ok, %{"xx" => 1}}
"ote xx\n\n\note yy\n"     -> {:ok, %{"xx" => 1, "yy" => 1}}
"ote xx\r\note yy\r\n"     -> {:ok, %{"xx" => 1, "yy" => 1}}
"bst xic aa nxb bnd ote xx" aa=0 -> %{"xx" => 1}    # jumper passes power
"xic aa bnd"               -> still correctly rejected

# rung counts — the env projection above cannot see these, so assert them too
"ote xx\n"  parses to {:routine, {:rungs, [rung: [name: "ote", name: "xx"]]}}   # 1, not 2
""          parses to {:routine, {:rungs, []}}
```

> **Trap.** The obvious alternative newline fix — adding `rungs -> rung rnd : ['$1'].`
> — is *individually* conflict-free but **conflicts with `branch -> '$empty'`**: yecc
> reports `0 shift/reduce, 1 reduce/reduce` and returns `{error, …}`, emitting **no
> parser at all**, so that variant does not build. After `rung rnd` at `$end` it cannot
> decide between a trailing separator and an empty final rung. Use the version above,
> which needs no trailing-separator production because the empty branch already covers it.

**With M0-1 … M0-5 landed, a green `mix test` means something:** every stage boundary is
exercised from source, and the three things §1 listed as broken — integer literals, sources
read from a file, single-character tags — all work, and all three are *guarded*: reverting
M0-1, M0-4's `NAME` regex, or M0-5's empty-rung filter each turns the suite red. That was
the *testability* gate, not the correctness gate. Three med-severity defects that produce
silently wrong answers survived all of M0 (§7): `xic`/`xio` non-complementarity (M1-4),
`nxb` fusion turning OR into AND on a missing space (§4·B1, **closed**), and the absence of
any validation (M1-2). M1-2 and M1-4 are the correctness gate.

---

## 3. Milestone 1 — a routine you can run

The ordering here matters: each item is cheaper now than after the one below it lands.

### M1-1 · Keep the token line in the AST

**Status: DONE — `a22bf39`, coverage completed in `1b1b1df`.** An elem is
`{kind, line, value}`. At `a22bf39` it was the token itself — the yecc `elem -> name` and
`elem -> int_lit` productions passed `'$1'` through and the `Erlang code.` block went.
Since §6 tokens carry `{line, column}`, and `Logex.Parser`'s `branch/2` builds the elem
with the line alone. The operand sites named below destructure the 3-tuple as
`{kind, _, value}`; since M1-2 they are the `evaluate/2` and `get_arg/2` heads, and the
lowering binds the line to cite it. The `{branches, legs}` node carries
no line of its own — the opening `(` token's line is dropped in the parser. Instruction
tuples were `{symbol, args}` until M1-2 widened them to `{symbol, line, operands}`.

Two sides to guard. The *producer* side — the parser keeping the right line — is held by
two tests in `lex_and_parse_test.exs` that assert lines other than 1: "lexes and parses
two rungs" (line 2, names and a literal) and "every elem carries the line it was read
from" (lines 1, 3, 6 across blank lines, indentation and a CRLF, with a branch group and a
bare elem sharing line 6). The *consumer* side — the ten `_` slots really being wildcards —
is held by "no stage depends on an instruction sitting on line 1" in `end_to_end_test.exs`
(every instruction, both power states, literal and tag operands, from line 3 down,
asserting values), with the per-stage fixtures on lines 4/9 and 2 so no constant satisfies
them. `a22bf39` landed with only the producer side; an adversarial review found eight of the
ten slots could be a literal `1` with the suite green, and `1b1b1df` closed that. Checked by
mutating, not by reasoning — fresh copy per row:

```
as shipped                                                    27 tests, 0 failures
elem -> name : setelement(2, '$1', 1).     shape kept, line 1  27 tests, 2 failures   the two producer tests
elem -> int_lit : setelement(2, '$1', 1).  shape kept, line 1  27 tests, 2 failures   the same two
elem -> name : {name, element(3, '$1')}.   line dropped        27 tests, 17 failures
branches legs rebuilt with every line 1    group only          27 tests, 1 failure    "every elem …" alone
instructionize/1 rewriting operand lines   lowering            27 tests, 1 failure    "instructionizes an AST" alone
instructionize/1 head: `_` -> 1            one slot            27 tests, 4 failures
evaluate/2 ote-false head: `_` -> 1        one slot            27 tests, 2 failures   "no stage depends …" + fixture
evaluate/2 otl-true head: `_` -> 1         one slot            27 tests, 2 failures
get_arg/2 int_lit clause: `_` -> 1         one slot            27 tests, 3 failures
get_arg/2 name clause: `_` -> 1            one slot            27 tests, 1 failure    "no stage depends …" alone
```

The "shape kept, line 1" rows are the ones that matter: with the shape right and every
line wrong, only the line-asserting tests fail. Without those tests every row but "line
dropped" would be green.

The diagnosis, as written before it landed:

`extract_token/1` (the `Erlang code.` block of `src/ladder_parser.yrl`) discarded the line. The lexer produces
correct `TokenLine` on every token; the parser throws it away, so the AST is
position-free and **no stage after parsing can cite a location**. Every error the
compiler will want to report — unknown mnemonic, bad arity, undefined tag, duplicate
coil — originates downstream of here.

Today this is four lines of Erlang in the parser, plus an AST elem shape change that
reaches ten pattern sites in `lib/logex/compiler.ex` — the `[{:name, name} | tail]` clause
of `instructionize/1`, the six `[name: arg]` `evaluate/2` clause heads, the
`{:mov, [arg1, {:name, arg2}]}` clause, and both `get_arg/2` clauses — plus the elem fixtures in the three per-stage
test files. `end_to_end_test.exs` asserts only on source, rung counts and env maps; its one
AST match is the `{:routine, {:rungs, _}}` wrapper, which the elem change does not touch. The
`compiler.ex` edits are mechanical one-liners but unavoidable: a 3-tuple elem stops being
a keyword pair. Do not reach for the pair-preserving alternative (`{name, {Line, Value}}`)
to dodge them — it compiles clean under `--warnings-as-errors` and then feeds a tuple to
`Map.get(@instructions, name)`.

After a validator, a formatter and a language server exist this touches all of them.
**Do this before M1-2, not after.**

### M1-2 · A validation pass

**Status: DONE — `e569113` (the validation pass) and the `mov` → `move` rename after it.**
`instructionize/1` returned `{:ok, ir}` or `{:error, diagnostics}`: every
`%Logex.Diagnostic{line:, message:}` in the routine, in source order. `@instructions` maps
each mnemonic to an operand signature (`"move" => {:move, [:value, :tag]}` then; M1-3 made
each operand `{access, type}`), and every case
in the table below is a located diagnostic, each pinned in `validation_test.exs`. The open
call at the end of this item was decided for the instruction tuple: it is
`{symbol, line, operands}` now, so a later pass can cite a line too. One decision was
added: **mnemonics are reserved words**, in any case (§5), which is what closes
`mov src ote`. Mnemonics are matched case-insensitively (§5). `%Program{}` stayed with
M1-5: `ir` is the same routine tuple as before. *(M1-3 brought `%Logex.Program{rungs:,
tags:}` forward: `instructionize/2` returns `{:ok, %Logex.Program{}}`, and since M1-5 its
`warnings:` too.)* What follows is the item as written.

`instructionize/1` validates nothing. `{symbol, args} = Map.get(@instructions, name)`
in the `[{:name, _, name} | tail]` clause of `instructionize/1` destructures `nil` for any
unrecognised name, and the `Enum.take(tail, args)` beside it truncates silently when operands run out:

```
"zzz aa"          -> MatchError: no match of right hand side value: nil  (no name, no line)
"XIC aa"          -> MatchError: …                       (case, same path)
"xic aa bb"       -> MatchError: …                       (extra *name* operand read as opcode)
"xic aa 7 ote bb" -> FunctionClauseError in instructionize/1   (extra *literal* operand)
"123 aa"          -> FunctionClauseError in instructionize/1   (literal in opcode position)
"ote"             -> {:ote, []} accepted, then FunctionClauseError in evaluate/2
"mov src ote"     -> no error at all: %{"ote" => 9}       (mnemonic eaten as an operand)
```

Every case but the last one raises. **The last is the worst, and it is not the
truncation case:** nothing was truncated — `Enum.take(tail, 2)` found exactly two tokens,
the second being the *next instruction's mnemonic*, so `mov` completed with `ote` as its
destination tag. A coil became a tag name, on an energised rung, with no exception and no
diagnostic. It needs neither a short operand list nor a de-energised rung, so it bites
where the reader is least likely to look.

The truncation case is the next worst: because several `evaluate/2` clauses use a
wildcard for `{false, env}`, a truncated instruction is *silently accepted* when power
flow is already false, and crashes only when a tag flips.

Both are the same root cause and the same fix — arity is a number in a map, consulted
after parsing, so the grammar cannot tell an operand from a mnemonic. Note that §4·B1
does **not** help here: it made the *delimiters* unfusable, and this is the same failure
shape one level down, on the operand list. The operand-signature table below is what
closes it.

Widen `@instructions` from an arity to an operand signature — `"mov" => {:mov, [:value, :tag]}`,
`"ote" => {:ote, [:tag]}` — and drive validation from the table rather than from
`evaluate/2`'s clause heads. Produce `{:ok, %Program{}} | {:error, [%Diagnostic{}]}`
rather than raising. Duplicate-coil and undefined-tag warnings belong here later.

**Two §5 decisions are scheduled into this item**, and they are cheaper together than
separately: the `mov` → `move` rename (so the unknown-mnemonic diagnostic can carry *"did
you mean `move`?"* rather than needing an alias) and the `String.downcase/1` that makes
mnemonics case-insensitive. See §5. The third, the `bst` → `( … | … )` migration hint,
shipped with B1 rather than waiting for this item: it is a guard clause on
`instructionize/1`'s name head that raises before `Map.get/2` can return `nil`, so it
names the word and its line. It should become a `%Diagnostic{}` like the rest when this
item lands.

The last two cases above never reach `@instructions` at all, so **a table-driven
validator alone does not cover them**. `instructionize/1` has list clauses for a
`{:branches, _}` head, a `{:name, _, _}` head and `[]`, and nothing
else — while the `elem -> int_lit` production makes a literal in opcode position
perfectly legal AST, so it falls off the end of the function before the table is
consulted. The pass also needs a catch-all clause over the element list reporting
`expected an instruction mnemonic, found <token>` for any head that is neither a name nor
a branch group.

**Open — decide it here, when a diagnostic first needs it.** Only operands carry a line.
The `{branches, legs}` node drops the opening `(` token's line in the parser, and
`instructionize/1` drops the mnemonic's own line when it builds `{symbol, args}`. So an
"unknown mnemonic" or "bad arity" diagnostic must take its line from the mnemonic's
`{:name, line, _}` *before* lowering, or the instruction tuple must grow a line. Widening
the branches node touches its two `{:branches, _}` clauses and the three per-stage
fixtures; widening the instruction tuple touches all ten operand sites. M1-1 left both as
they were on purpose rather than guess which M1-2 wants.

### M1-3 · A tag table with types

**Status: DONE — landed 2026-09-28**, in the six commits listed at the end of this item;
124 tests pass on Elixir 1.20.4, and the messages of steps (3) to (5) record their
mutation tables; (2) is a refactor with none. An adversarial review then added tests for
the mutants those tables missed, and fixed what it found; its commit follows (6). Where
the landing departs from the text below: the note for a program with no declaration line
reads "each is now declared before the first rung", naming no plan item; it is given only
when there is no declaration line at all, not when every declaration was wrong, and it
offers `bool` or `dint` rather than guessing; an undeclared tag cites its operand's own
line; and `%Logex.Tag{}` keeps `initial: nil` when none was declared, which
`Logex.Program.initial_env/1` reads as 0. Every recommendation of the design panel was
adopted, together with `docs/organisation.md` §6.1's four additions. A spike of this
design on a copy of `37b7932`, on Elixir 1.20.4 / OTP 28, passed 90 tests (76 migrated, 14
new) with the README output byte-identical; it is a receipt, not code in the repository.

The problem: no declarations, no BOOL/DINT distinction, no scope. That is what makes M1-4
possible and what makes a typo'd tag name a silent dead rung rather than a compile error.

**Where and how.** Declarations live in the `.ld` file, before the first rung, one per
line: `<section> <name> <type> [<initial>]`, with section `var`, `var_input` or
`var_output` and type `bool` or `dint`. They take IEC's words lowercased (naming rule 1;
each word gets its `docs/naming.md` stanza before its code). IEC's `VAR_INPUT start :
BOOL; END_VAR` loses its punctuation, as logex drops it elsewhere, and a keyword on every
line replaces the block, so there is no `end_var`. Blocks were rejected: they need
unclosed, nested and stray-block diagnostics and a recovery heuristic, and adding them
later would reserve `end_var`. The README program becomes:

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
…
```

- **No grammar edit.** A declaration line parses as an ordinary rung: names, with an
  `int_lit` last when it has an initial value. A `Logex.Declarations` pass at the top of
  `instructionize/2` takes the leading lines whose first word is a section keyword; the
  lexer, parser, printer and golden record do not change. A declaration after the first
  rung is a diagnostic, but still declares its tag.
- **Section and type words are data tables,** so M2-4's `var_external` is one more row,
  and M1-6's `var t1 ton` and M2-5's `var s1 seal` resolve through the same type lookup:
  no second declaration parser. (A user function block's name is built per compile, not a
  row, so it is not reserved.)
- **Reserved in any case, in `.ld` files:** `var var_input var_output bool dint`. The commit
  that reserves them says so.
- **Strict.** Every tag a rung uses must be declared. An undeclared tag is a located
  diagnostic at its first use, with a did-you-mean; a program that declares nothing says
  once how to declare. Strict-only-when-declared was rejected: deleting the last
  declaration would silently bring the dead-rung defect back.
- **Types.** `bool` holds 0 or 1; `dint` is 32-bit (Ed 2 Table 10). The default initial
  value is 0 (Ed 2 Table 13). Other types, arrays and STRUCT wait, each an `unknown type`
  diagnostic *(since Milestone 5, 2026-10-26, the type table's fifteen elementary types,
  arrays of them and of instances, each its own `docs/naming.md` stanza; STRUCT still
  waits)*. `var retain r bool` is a diagnostic until M1-5's `restart` gives a tag
  something to survive; `retain` itself stays unreserved. *(M1-5 landed `restart/3` and
  left `retain` out, for scope; the diagnostic now says a warm restart, like a cold one,
  starts every tag but the `var_input`s at its initial value.)*
- **Roles.** `var_input` is supplied from outside: logic may read it but not write it —
  IEC's own rule, *"Externally supplied, not modifiable within organization unit"* (Ed 2
  Table 16a) — and it takes no initial value. `var_output` is produced for the caller.
  `var` is internal. Binding any of them to physical I/O is the configuration's job, never
  the program's (`docs/organisation.md` §4.5).
- **Scope.** The file is the program's scope. There is no controller scope; sharing comes
  later through `var_global`/`var_external` (M2-4).
- **Typed operand signatures.** Each operand is `{access, type}`: `xic`/`xio`
  `{:read, :bool}`; `ote`/`otl`/`otu` `{:write, :bool}`; `move`
  `[{:value, :any}, {:write, :any}]`, whose two `:any` operands must agree, as IEC's MOVE is
  `IN : ANY` → `OUT : ANY` (`docs/naming.md`, Scalar move). M1-2's messages stay
  byte-identical. *(Since M5-3, 2026-10-22, `move`'s two operands meet by Ed 3 Figure 11,
  the source widening into the destination's type, decision 147; and since M5-4 a slot's
  type may be one of IEC's generic types, `:any_int`, `:any_num`, `:any_bitwise`,
  `:any_elementary` and `:any_real`, as data.)*
- **Data.** `%Logex.Tag{name:, type:, section:, initial:, line:}`;
  `%Logex.Program{rungs:, tags:}` (M1-5 adds `name:`, `source:`, `warnings:`);
  `Logex.Program.initial_env/1` builds the first env from the declared initial values. The
  env stays `%{name => integer}` — a Milestone-1 fact, not an invariant: M1-6 nests timer
  instances in it, and no M1-3 check may depend on it being flat.
- **The Elixir-side declarer.** `instructionize(ast, declared)` takes `%Logex.Tag{}` values
  built with `Logex.Tag.new!/4`, validated by the same checks as a declaration line. It is
  the seam `docs/defladder.md` §11's M1-3 row asks for, and M1-5's `compile/2` does not
  expose it. defladder.md §15's decisions stay open; its decision 3 (head declarations in
  the DSL's output) stays B9's.
- **Deferred:** warnings (declared but unused, a `var_output` never written, duplicate
  coil) go to M1-5's `warnings:`; a declaration-inferring migration aid is not built.
  *(All three landed with M1-5, `a34fa87`.)*

**Diagnostics** (the spike's wording): `` `strat` is not declared — did you mean
`start`? `` · `` `xic` reads a bool, but `speed_sp` is a dint (declared on line 7) `` ·
`` `ote` writes `start`, a var_input (declared on line 1): logic must not write an
input `` · `` `move` takes operands of one type: … `` · a literal that does not fit its
destination · a keyword or type where a tag must go · on declaration lines: declared twice,
two names differing only in case (§5), a missing or unknown type, an initial value that
does not fit, an initial value on a `var_input`, a reserved word as a name, a declaration
after the first rung.

**Landed in commits, each green; (3) to (5) each with a test that fails when its change is
reverted:** (1) the `docs/naming.md` stanzas for the five words, `d818cd8`; (2) typed
operand signatures, no behaviour change — a refactor: the M1-2 messages stay
byte-identical and reverting it leaves the suite green, which its commit says rather than
inventing a failing test — `2a65aef`; (3) declaration lines and `%Logex.Program{}`, not
yet enforced, `5b63a9f`; (4) strictness — undeclared tags are errors — with the suite and
README migrated (35 of the 76 earlier tests went red without it), `efa1d13`; (5) type and
role checks on operands, `2b093de`; (6) documents, the commit after.

### M1-4 · Make `xic` and `xio` complementary by construction

**Status: DONE — landed 2026-09-28.** The strict half came with M1-3 (`2b093de`). The
`bit/2` half is the sketch below with one correction: `xic` reads `bit/2`, `xio` its
negation, and `get_arg/2` defaults a missing tag to 0, but `bit/2` reads a number by value
(`!= 0`) and a boolean as itself, with `nil` and a missing tag open. The sketch's
`not in [0, nil]` matched strictly, so `0.0` and `false` read *closed* — a regression for
`0.0`, which the old `== 0` read correctly, and a `false` from a host would have closed an
`xic`. `end_to_end_test.exs` pins complementarity for 0, 1, 5, -3, 0.0, -0.0, 2.5, `false`,
`true`, `nil` and a missing tag, and `move` from a missing tag (and, since M1-5's second
review, an atom and a string, which read closed). Reverting either contact, the
`get_arg/2` default, or `bit/2`'s treatment of floats, `false`, `nil` or a missing tag, or
`bit/2` becoming `== 1`, each turns it red. What follows is the item as written.

the `{:xic, _, [{:name, _, arg}]}` clause tests `== 1` and `{:xio, …}` tests `== 0` — two independent *positive*
tests, so any value outside `{0,1}` reads false for both:

```
tag=0     -> hi=0 lo=1     ok
tag=1     -> hi=1 lo=0     ok
tag=5     -> hi=0 lo=0     wrong: neither closed nor open
undefined -> hi=0 lo=0     wrong: (Map.get default nil)
```

A bit that answers false to both "is it set?" and "is it clear?" is unrepresentable on
real hardware — an interlock guarded by `xio` simply never fires, silently. This is
reachable from source **today** via an undefined tag, and becomes reachable via
`move 250 setpoint` (then `mov`) since M0-1 landed in `690fc2d`: it stores `250`, and then both
`xic setpoint` and `xio setpoint` read false.

```elixir
# Replaces the two {true, env} clauses of {:xic, …} and {:xio, …} ONLY. Keep their
# {false, env} clauses; deleting them makes any de-energised xic/xio raise
# FunctionClauseError while `mix test` stays green.
def evaluate({:xic, _, [{:name, _, a}]}, {true, env}), do: {bit(env, a), env}
def evaluate({:xio, _, [{:name, _, a}]}, {true, env}), do: {not bit(env, a), env}

# ...and these at the BOTTOM of the module, beside get_arg/2. A defp placed between the
# evaluate/2 clauses splits the clause group: Elixir warns "clauses with the same name
# and arity should be grouped together" and `mix compile --warnings-as-errors` exits 1.
defp bit(env, name), do: Map.get(env, name, 0) not in [0, nil]

# REPLACES the existing `defp get_arg(env, {:name, _, name})` clause — not an addition.
# Pasted as a second clause it compiles with warnings, leaves the old clause first,
# and `mix test` stays green because nothing covers `move` from an undefined tag.
defp get_arg(env, {:name, _, name}), do: Map.get(env, name, 0)
```

Verified with the above applied (after M1-1, against the 3-tuple elem):

```
t=0       xic=0  xio=1   ok        t=absent  xic=0  xio=1   ok
t=1       xic=1  xio=0   ok        t=nil     xic=0  xio=1   ok
t=5       xic=1  xio=0   ok        mov nosuch dst -> %{"dst" => 0}
```

Two things this block decides, neither obvious. **(a)** `Map.get/3`'s default only covers
an *absent* key, and absent is not the only way a non-bit reaches `env`: `get_arg/2`
(its `{:name, _, name}` clause) is a bare `Map.get/2`, so `move undefined_tag dst` stores `nil` today.
With a plain `!= 0` the sketch reads such a tag as a **closed** `xic` contact — trading a
contact that never closes for one that closes on a typo — so harden both sites together,
as above. **(b)** `not in [0, nil]` is nonzero-is-true, which is a *dialect choice*, not a
bug fix: every dialect surveyed takes a BOOL operand and rejects a numeric one at
verification. **§5 settles this:** keep the coercion as a totality guarantee so `xic`/`xio`
cannot disagree, and reject it as a *language* rule — once M1-3's tag table exists, a
non-BOOL operand becomes a located diagnostic rather than a silent coercion. The escape
hatch is bit addressing, `xic setpoint.3`.

**Landing order — §5 settles this, and it is narrower than it first reads.** Land the
`bit/2` half **now**: it makes `xic`/`xio` complementary by construction, which is a pure
improvement and needs nothing from M1-3. What waits for M1-3 is the *second* half — turning
a non-BOOL operand into a located diagnostic instead of a coercion — because the `0`
default is only safe once an undeclared tag is a compile error rather than a silent zero.
So: `bit/2` now, strictness after M1-3. (§5's M1-4 bullet says the same thing; if the two
ever disagree, §5 is the decision of record.)

**The strict half landed with M1-3** (`2b093de`): a `dint` on `xic`, `xio` or a coil is a
located diagnostic, and an undeclared tag, `move undefined_tag dst` included, can no longer
reach `env`. What was left of M1-4 was `bit/2`, for values the host supplies — an env built
by hand rather than by `Logex.Program.initial_env/1` can still hold a 5 or leave a tag out
— and that has landed too (status above).

### M1-5 · A real public API

**Status: DONE — landed 2026-09-29**, in the nine commits listed at the end of this item;
184 tests pass on Elixir 1.20.4 (6 of them doctests), and each commit's message records
its mutation table. Where the landing departs from the text below: B5 landed before the
documents, not after, so the documents could describe the finished surface once; a second
`ote` on the same rung is reported as "already has an `ote` in this rung" rather than
citing its own line; and the seeded property also requires every refusal's message to
begin with one of the pinned prefixes, so a crash with the wrong message cannot pass as a
refusal. A `scan/3` that accepted a negative `elapsed_ms` would be caught by
`runtime_test.exs` and not by the property alone: the property does pass one, but the
scan's own time check then refuses it with a documented message. A clock that goes
backwards in `call/4` is caught by both. The Milestone-1 done sentence is met, and
`test/logex_test.exs` runs it as written.

An adversarial review of the ten commits (six lenses, and a skeptic reproducing each
finding) confirmed 26 findings, 21 once the ones found twice are merged, and refuted 3.
Its fixes are the commit after the documents, and the suite is at 194 tests (6
doctests). One was a defect: the warnings walked every use for every tag, so compiling
was quadratic (16,000 tags took 7.5 s); a test now bounds the growth in reductions. One
was a false message: step 5 reworded M1-3's `retain` diagnostic to say a warm restart
starts *every* tag at its initial value, which `restart/3` contradicts for the
`var_input`s. Four were stale passages in these documents. The other fifteen were rules
no test failed without, each now pinned and checked by reverting it: among them series
AND after an open contact, the power each coil passes on (step 7 had dropped the one
assertion that guarded a de-energised `ote`'s), the state and program checks at every
entry point, and the edges of the name rule.

A second round (five lenses over the fixed code, a skeptic per finding) confirmed 27 findings,
23 once merged, and refuted 6; its fixes are the commit after `b8a9bd8`, and the suite is at
196 tests (6 doctests). One was a defect: `Logex.Declarations.validate!/1` let a tag
declared from Elixir carry a `line`, and the warnings then took it for one declared in
source; it now raises. Seven were rules no test failed without (among them a use in a
group nested in another group, "anything else is closed", the did-you-mean's 0.8 cut-off,
and how a file's name becomes the program's). Two were the property's own claims: it
checked that a refusal was documented but never that a mistake was refused or a good call
accepted, and it never reached a dint `var_input`, a bad state outside `call/4`, or two of
its nine refusal kinds. It now has that oracle and asserts its reach, and by itself catches
twelve rule-breaks the old one missed. Six were stale passages. Seven were practices, now
in `CONTRIBUTING.md`: among them the commit gate's `mix test --warnings-as-errors`, since
`mix compile` never sees a warning in a test file.

**Decided 2026-09-28, from `docs/organisation.md` §6.1** (its rationale is there):
1. `%Logex.Program{name:, tags:, rungs:, source:, warnings:}`, named and stateless. The name
   is the file's basename (`Logex.compile_file("motor.ld")`) or `compile(source, name:)`;
   a configuration refers to program types by it. `%Logex.Program{rungs:, tags:}` came
   forward with M1-3; M1-5 adds `name:`, `source:` and `warnings:`.
2. The core is the instance call, `Logex.Runtime.call(program, state, inputs, scan)`;
   `scan/2` and `scan/3` are sugar for one task-less instance. `scan/3` takes elapsed
   milliseconds, **not** "n scans" as written below. Unknown or non-input keys in
   `inputs` are errors.
3. `%Logex.Diagnostic{}` is widened once, with `file:`, `stage:` and `column:` together.
4. `Logex.Runtime.restart(program, state, :cold | :warm)` is the RETAIN hook.
5. The Milestone-1 done sentence below is amended accordingly.
6. B5 lands straight after: every recursive `evaluate` clause becomes a `defp`.

**Designed and decided 2026-09-29.** A design panel built three designs (the smallest
surface, one shaped for M1-6 and M2-1, one built around the error model and the host
contract), each spiked on a copy of `36fa3b5`; two judges scored them, a synthesis was
spiked as nine commits (188 tests on Elixir 1.20.4, every rule reverted and caught), and
two refuters checked it. The maintainer took every recommendation, including two where the
refuters overturned the synthesis (program names, and restart keeping the inputs). The
design:

- **Compiling.** `Logex.compile(source, name: name)` and `Logex.compile_file(path)` return
  `{:ok, %Logex.Program{}}` or `{:error, [%Logex.Diagnostic{}]}`. The name is required, so
  there is no `compile/1`, and there is no raising `compile!/1`. `compile_file/1` names the
  program after the file's basename and stamps `file:` on every diagnostic. `source:` holds
  the text. A lex or parse error is one diagnostic with its column; every later mistake is
  reported, in line order, with M1-2's and M1-3's messages unchanged.
  `Logex.Compiler.tokenize/1` and `parse/1` keep their own error shapes, for the golden
  record. *(Milestone 2's design, 2026-10-02: from M2-5, `compile/2` also takes `types:`,
  a function block's file compiles to `{:ok, %Logex.FbType{}}`, and `compile_file/1`
  loads the blocks a program names from beside its file; `docs/organisation.md`
  decision 34. Landed with M2-5, which also gave `%Logex.Program{}` a `file`, fix F15.)*
- **One diagnostic.** `%Logex.Diagnostic{stage:, line:, message:, file:, column:,
  severity:}`: `stage` is `:file | :lex | :parse | :validate`, and `severity` is `:error`
  or `:warning`. `severity` goes beyond the decided three fields on purpose, in the same one
  widening. `format/1` gives `motor.ld: line 3, column 5: message`, dropping what is nil,
  and puts `warning: ` before a warning's message.
- **File problems.** An unreadable file is a `:file` diagnostic, not a `File.Error`. A
  basename that is not shaped like a name (a letter or `_`, then letters, digits or `_`) is
  a `:file` diagnostic, and the source is still compiled. Names are checked for shape only:
  reserved words are scoped by file kind (`docs/organisation.md` decision 10), and a program
  type's name is never spelled in a `.ld` body, so the `.logex` words wait for M2-2.
  *(Landed with M2-2 and M2-3: they are reserved in a configuration file only, and
  `compile_file/1` now takes a `.ld` file only.)*
- **Warnings**, only when the program compiles, never for a tag declared from Elixir: a tag
  declared but used by no rung; a `var_output` no rung writes ("it stays at" its initial
  value); a second `ote` on one tag.
- **Running.** `Logex.Runtime.instance(program) :: %Logex.Instance{type:, env:, now:,
  first:}`, which holds no program; `call(program, state, inputs, %Logex.Scan{now:,
  first:}) :: {outputs, state}`; `put_inputs(program, state, inputs) :: state`, the checked
  way into the task-less sugar's input image; `scan(program, state, elapsed_ms \\ 0) ::
  {outputs, state}`; `restart(program, state, :cold | :warm) :: state`. `%Logex.Scan{}`
  lands now and is checked, and nothing reads it until M1-6.
- **The host contract.** A mistake in the source is a returned diagnostic; a mistake by
  the host raises `ArgumentError` (§4.6: "it is a host bug"), with every input problem in
  one raise and a did-you-mean. Only a declared `var_input` may be set, by its string name,
  with a value that fits its type exactly (a bool is 0 or 1, a dint 32 bits), and inputs
  merge into a persistent image. Outputs are every `var_output`. Time never goes backwards
  for an instance; `first` is per instance, and a `%Scan{}` that disagrees with it raises.
  A state is matched to its program by name, and its values are not checked each scan, so
  M1-4's totality stays reachable. A `%Program{}` or `%Instance{}` built by hand is outside
  the contract.
- **Restart** puts every tag but the `var_input`s back to its initial value, marks the next
  scan first, and keeps the clock. The `var_input`s are the host's input image: IEC leaves
  inputs *"initialized in an implementation-dependent manner"* (Ed 2 §2.4.2 rule 4, p.38),
  and keeping them is what makes `scan/2` agree with a one-instance configuration, whose
  copy-in refreshes them every scan (§4.6). `:warm` equals `:cold` until `retain` exists;
  `retain` does not land in M1-5, for scope — nothing needs it yet, and it owes a naming
  stanza (Ed 2 Table 33 f3a) first.
- **B5.** The evaluator moves into `Logex.Runtime`, private; `Logex.Compiler.evaluate/2`
  goes. The stage functions stay public. A test pins the exact public surface of `Logex`,
  `Logex.Runtime` and `Logex.Compiler`.

**Landing, in commits, each green and each with a test that fails when its change is
reverted:** (1) the diagnostic widening; (2) `Logex.compile*`, the named program and
`doctest Logex`; (3) the warnings; (4) `Logex.Runtime` with `Instance` and `Scan`; (5)
`restart/3`; (6) a seeded property over the host contract; (7) the suite run through the
public API rather than `evaluate/2` (test-only); (8) documents; (9) B5.

**Landed as:** (1) `6d57d19`; (2) `cb5049e`; (3) `a34fa87`; (4) `ee91fe5`; (5) `88ba3ab`;
(6) `02d555e`; (7) `72bee33`; (9) B5, `d0870b3`; (8) the documents, the commit after.

The item as written follows.

There is no `Logex` module at all: the `mix new` stub and its doctest were deleted
rather than left standing in for an API. So every consumer must know the stage order and
unwrap two different `:ok` tuple shapes. There is no `compile/1`, no scan loop, and nothing
representing "a compiled routine".

Two related shape problems:

- **`{power_flow, env}` leaked into the public signature.** It is exactly right as a
  *rung-internal* accumulator and exactly wrong as the shape a caller sees — the
  routine clause ignores the incoming boolean and hard-codes `{true, new_env}`
  (the `{:routine, {:rungs, rungs}}` clause of `evaluate/2`), so callers pass a meaningless
  `true` and discard a constant.
- **There is no compiled-program value.** The closest thing is a raw
  `{:routine, {:rungs, …}}` tuple with no identity, no tag table, no source reference,
  and no way to distinguish it from an un-instructionized AST. `%Logex.Program{rungs:,
  tags:, source:, warnings:}` is ~20 lines now; later it is a change to every
  consumer's pattern match.

Target surface: `Logex.compile/1`, `Logex.Runtime.scan(program, env) :: env`,
`Logex.Runtime.scan/3` for n scans. Keep `evaluate/2` internal at
`{power_flow, env} -> {power_flow, env}`, and make the seal-in circuit the README
example.

*Since the hand-written front end (§6): `Logex.Lexer` and `Logex.Parser` return the same
two shapes, now with `{line, column}` locations and Elixir binaries rather than charlists,
and each has a tested `format_error/1` — an unclosed group is reported at the innermost
`(` still open, and an unexpected token names what was expected. Nothing outside the tests
calls them yet; the single `%Logex.Error{}` below is still this item's to design, and can
now carry a column. M1-2 added `%Logex.Diagnostic{line:, message:}` for lowering: make that
the one error type, widened with a stage and a column, rather than add a second. The
`%Logex.Program{rungs:, tags:}` below came forward with M1-3, and `instructionize/2`
returns it; naming it, and `source:` and `warnings:`, are still this item's.* As first written: normalise errors while here: `tokenize/1` returns
leex's 3-tuple, `parse/1` yecc's 2-tuple, `instructionize/1` a bare value that raises. Raw Erlang charlists leak, and
`format_error/1` is exported by both generated modules and called by neither — the
lexer's is genuinely useful (`{:illegal, ~c"@"}` → `illegal characters "@"`). Empty input
reported yecc's internal sentinel as a line number (`{:error, {999999, …}}`) *until M0-5*:
that sentinel is emitted from exactly one site in the generated parser, reachable only
from an empty token list, and M0-5 — landed in `b65e756` — made the empty program a legal
parse: `parse([])` now returns `{:ok, {:routine, {:rungs, []}}}`. So by the time
M1-5 lands there is no empty-token special case to write. One
`%Logex.Error{stage:, line:, message:}`, and nothing more.

The repository has no doctest since the stub was deleted, and no `test/logex_test.exs`.
Put the seal-in example in an `@doc` on `Logex.compile/1` and restore that file as
`doctest Logex` — the example is then executable documentation rather than prose the README
can silently outlive.

### M1-6 · TON and ONS

**Status: DONE — landed 2026-09-30**, as the eight commits of the landing order below: (1)
the naming stanzas, `a64e42f`; (2) `evaluate/3`, `cd83e71`; (3) `ons`, `6775890`; (4) the
comparisons, `d73886d`; (5) `var t1 ton` and members, `260a02d`; (6) `ton`, `8d6ea80`; (7)
the host-contract property, `615d5ea`; (8) the documents, the commit after it. 307 tests
pass on Elixir 1.20.4 (6 of them doctests), up from 214. The messages of (3) to (6) record
their mutation tables, every rule reverted alone and the full suite judged by exit code,
each red; (7) records its `lib/` mutants against the property alone; (1), (2) and (8) are
documents and a refactor. The maintainer's five changes to the synthesis landed in the
commits the design below names, each with a test that fails when it is reverted: a second
`ons` in (3); `last`, a negative `.acc` and nothing after a `ton` in (6); decision 6 per
rising edge in (6), with a test of a timer that re-triggers itself. So did the second
refuter's fixes: every malformed schema or initial value raises `ArgumentError` from
`Logex.Tag.new!/4` and `split/2` ((5) and (6)); a `ton` or two compared literals in a group
nested in another is found ((4), (6)); a `ton` with a wrong preset, or none, still counts,
so a second `ton` is reported too, and one on a declared tag that is not a timer runs
nothing; `var_input ton` is told a ton is declared with `var`; a dotted input key is called
a member only when it is one; and a timer declared from Elixir starts at a `.pre` of 0 to
2147483647 ms, what the preset slot takes. *(Withdrawn by OE-1 on 2026-10-01:
`Logex.Tag.new!/4` no longer takes a timer's `%{"pre" => ms}`, nor any initial value on an
instance, which gets the message a declaration line does. A `ton` silently replaced the
map, and with none no text could give that `.pre`; `docs/organisation.md` §7, decision 24.)*
No departure from the design. Beyond its text: an
element after a `ton` is reported once, at its own line, citing the first `ton` on its path,
and a group after one as "a branch group"; an `ons` on anything but a declared bool, like a
`ton` on anything but a declared timer, is left to the diagnostic it already has. Measured
at the landing: compiling 4x the tags takes 4.2x the reductions, and a scan of the README
motor 280.9 reductions against 265.7 at `19868d4`, the 5.7% the design records.

An adversarial review of the eight commits (five lenses, and a skeptic reproducing each
finding) confirmed 22 findings, 19 once the ones found twice are merged, and refuted 5.
Its fixes are the commit after the documents, and the suite is at 317 tests (6
doctests). Two were defects. The path pass copied what it had found in a group at every
level of nesting, so a rung 8,000 groups deep with a `ton` innermost took 205 million
reductions and 2.9 s; it, and the instruction and warning walks, which copied in the same
way, now gather newest first and reverse once, and a second growth test bounds compiling
in depth as the first does in size. And a timer line broken after its type word, `var
t1 ton 5 6`, declared nothing, against the design's "a misdeclared timer is still
declared"; it is now declared, and its uses are not reported as undeclared. Five were
misleading messages: the `move` a tag preset is told to write and the `xic t1.dn` a path
error names are given only where they would compile; a timer first met in a program that
declares nothing is shown `var t1 ton`, not `bool` or `dint`; `ton.dn` is a member of an
instruction, not an undeclared name; `t1.acc.3` is bit access, not a path too deep; and a
starting `pre` out of range from Elixir is told the range, which -5, a dint, is not (a
message withdrawn with the map, above). Five
were rules no test failed without: which `ton` a group with two cites, a bool member's
too-deep message, the preset range's upper end, the section check on a timer from
Elixir, and that a `last` which is not an integer adds nothing. One was the property's
claim: operation 6's `scan/2` skipped the oracle, which now checks all 245 accepted scans
of a timed program at the seed, not 233 (490 oracle runs, not 466, since each accepted
call is made twice). Six were stale passages: `Logex.Tag.new!/4`'s
doc, CLAUDE.md's rule for a type word, instruction-sets.md's "flat env", defladder.md's
`bit/2`, and two things the contract did not say about a state kept across a recompile
of the same name, now in `Logex.Runtime`'s moduledoc and organisation.md's online-edit
row, with a test of the second: a tag whose type the recompile changes keeps its old
value, a timer's map reaching the outputs; and a tag it adds reads 0 until a restart, so
an added timer starts at a `.pre` of 0 and is done at its first true scan.

A second round (four lenses over those fixes, among them a comparison of both compilers'
output on generated programs, and a skeptic per finding) confirmed 18 findings, 14 once
merged, and refuted 2. Its fixes are the commit after `77d1b01`, and the suite is at 320
tests (6 doctests). Six were messages: the hints still named a `move` or an `xic t1.dn`
that never compiles where the timer and the preset are one name (`ton b b`) or where a
name differs from a declared tag only in case; a timer first used as a member or as a
bool, and run by a `ton`, was not shown `var t1 ton`; `bool.3` was called a member, and
is now, like `ton.dn`, a name that "begins with `bool`, a type, which cannot name a tag";
`t1.acc.3.x` had become bit access, and goes too deep again; and a bool's bit, `a.0` or
`t1.dn.0`, was told bit access is "not supported yet", where a bool has no bits. One was
the contract: `restart/3` kept a var_input whose type a recompile had changed, against
the new sentence that a restart puts a kept state right; it keeps only the var_inputs
whose values fit their types now. Four were rules no test failed without: the salvaged
timer's line and its name check, the order of path errors across legs and nested groups,
and the walk that finds the first rung's line for a declaration after it, which the depth
test's programs never reached. Finding that line once, not once per late declaration,
also removes an older quadratic cost, from M1-3. Three were documents: the growth
figures, the 490 above, which counted each accepted call twice, and instruction-sets.md's
"flat-env" heading. The depth test now takes the least of three counts and a bound of
18.5, where the fixed compile measures about 16x and the copying walks 20x or more
(`2c8cfea`'s message says 15.7x and 21x to 29x, which the third round below corrects):
one refuted finding reported a single run of the earlier test at 18.0x, which 582 runs
could not reproduce.

A third round (three lenses over `2c8cfea`, a skeptic per finding) confirmed 9 findings,
6 once merged, and refuted 3. Its fixes are the commit after `2c8cfea`; the suite stays
at 320 tests. One was a regression: the twin check walked the whole tag table on each
lookup miss, so many hints after one undeclared timer compiled quadratically (8,000 of
them beside 8,000 tags took 24 s). The declared names are indexed by their lowercase form once per
compile now, and the size test's program runs a timer no line declares, so it reaches
that lookup. Two were messages: `ton b B` still hinted `move B b.pre`, where two names
that differ only in case cannot both be declared; and `d.3.x` on a plain tag was still
bit access, and goes too deep now, as `t1.acc.3.x` does. One was a message the restart
change made stale, the `retain` diagnostic's "starts every tag but the var_inputs". One
was a rule no test failed without: a twin declared in capitals and used in lowercase.
And the growth figures, which the test itself does not give as quoted: reductions count
garbage collection, so a mutant's ratio moves from run to run, and CONTRIBUTING now says
to quote the fixed compile's figure and the lowest mutant's.

A fourth round (two lenses over `2afed5a`, a skeptic per finding) confirmed 3 findings and
refuted none, all about that commit's own figures and claims; the code was left as it was.
Its message gives the fixed compile 15.5x and D2b, the compiler's two copying walks as at
`b30ab18`, 29x "as the test itself runs them": the committed test gives 16.1x, and D2b 50x
to 61x. Both wrong figures came from a copy of the test that also
timed 2,000 levels after 8,000, which moved the garbage collection the counts include;
CONTRIBUTING now records that. And its row Q1 says both growth tests catch the walk on
each miss, but the Q1 mutant walked the table on every lookup, hits included: reverted
faithfully, as a walk on a miss only, the walk is caught by the size test alone, since the
depth test's timer is declared and its hints never miss.

**Decided 2026-09-28, from `docs/organisation.md` §6.1 and §4.6:**
1. `evaluate/3` threads a read-only `%Logex.Scan{now:, first:}`; the accumulator stays
   `{power_flow, env}`. CLAUDE.md's `evaluate/2` convention changes with it. *(Since M1-5
   the `%Scan{}` exists and `Logex.Runtime.call/4` checks and receives it; the evaluator
   is `Logex.Runtime`'s, private, so `evaluate/3` is a change inside that module.)*
2. Timers are declared instances, `var t1 ton`; an undeclared one gets M1-3's diagnostic.
3. Instance state nests: a per-instance record with a schema per FB type
   (`%Logex.FbType{}`), which M2-5's user function blocks reuse. `ons` reads
   `scan.first`.
4. Members are readable anywhere; logic may write only `.pre` and `.acc`. A dotted name
   that is not a declared member is a diagnostic.
5. A timer adds `now − last_scanned` to `.acc`, keeping its last-scanned time as an
   internal member (the delta formula `docs/naming.md` Timers settles), not a per-instance
   `dt`, so a timer in a frozen function block catches up.
6. Before calling the model settled, spike a real `ton`: one program type, two instances
   on 10 ms and 50 ms tasks, and an assertion that `.acc` reaches the preset at the same
   logical time in both.
7. The settled `.` and `//` lexer rules land exactly as written: `a.1b` is a lex error,
   `ote a // note⏎ote b` is two rungs, and the golden record changes in exactly two
   entries. B8 is fixed before any configuration file exists. *(All three landed
   2026-09-30. The golden record changed in exactly those two entries for the two rules,
   and in the 165 entries B8 predicted.)*

**Designed and decided 2026-09-30.** A design panel built three designs (the conventional
reading, one shaped for Milestone 2, one built around the error model and the host
contract), each spiked on a copy of `da2159b`; two judges scored them, and a synthesis
took the contract design's semantics and error model, the Milestone-2 design's data model,
and the conventional design's decision-6 test, and was spiked as eight commits (290 tests
on Elixir 1.20.4, 128 rules each reverted and caught). Two refuters checked it. The
maintainer took every recommendation, including five where the refuters changed the
synthesis (a second `ons`, `last`, what follows a `ton`, decision 6's wording, and a
negative `.acc`). The design:

- **Surface.** Eight mnemonics, reserved in any case: `ons`, `eq ne lt gt le ge`, `ton`
  (a program with a tag of any of those names stops compiling). `ton` is a type word too.
  No syntax change: `t1.dn` has lexed as one name since `46f17f0`.
- **`evaluate/3`** threads the checked `%Scan{}`, read-only, to every instruction; only
  `ons` reads `first` and only `ton` reads `now`.
- **`ons s1`**, `[{:write, :bool}]`: power on the one scan in which the power reaching it
  rises, never on an instance's first scan (it reads `scan.first`, which stands for the
  conventional prescan). `s1` is an ordinary `var` or `var_output` bool. A second `ons` on
  one storage bit is an error at its line, citing the first: the false one clears the bit
  every scan, so the true one fires every scan, and no arrangement of two works. Another
  writer (`ote`, `otl`, `otu`, `move`) is a warning citing the `ons`, since a deliberate
  re-arm cannot be told from a mistake; the second-`ote` warning skips a storage bit.
- **Comparisons**, `[{:value, :dint}, {:value, :dint}]`: dint tags, members or literals
  that fit 32 bits, `lt a b` meaning a < b. They are input instructions and pass no power
  de-energised; `ne ge le` are the negations of `eq lt gt`, so each pair is complementary.
  Two literals compile, with a warning that the result never changes.
- **Timers.** `var t1 ton`, in `var` only, with no initial value; a misdeclared timer is
  still declared, so its uses do not cascade. `%Logex.FbType{}` is the schema, carried
  inline as the tag's type, with members that have a role and a write flag; M2-5 reuses
  it. State nests: `env["t1"]` is `%{"pre", "acc", "dn", "tt", "en", "last"}`, every key a
  string. `last` is internal: no name reaches it, and it is the time of the timer's last
  run, as decision 5 has it.
- **Members** are typed by the schema (`.pre .acc` dint, `.dn .tt .en` bool, all
  case-sensitive), read anywhere, written only to `.pre` and `.acc`, and lowered to
  `{:member, line, path}` in the IR, so the runtime never splits a name. Every other
  dotted name is a located diagnostic of its own: an unknown member (a did-you-mean on the
  member's name, else the member list), a member of a non-instance, bit access (`word.3`,
  not supported yet), a path too deep, an undeclared instance (named once), and an
  instance named whole where a value belongs.
- **`ton t1 5000`**, `[{:instance, "ton"}, {:preset, :dint}]`. The preset is a literal of 0
  to 2147483647 ms and the timer's starting `.pre`: the compiled tag carries it, and
  `instance/1` and `restart/3` restore it. The instruction never writes `.pre`, so a
  `move` into it holds. One `ton` runs a timer; a second is an error. Energised, `.en` is 1
  and `.acc` gains `now − last` if `.en` was already 1, nothing on the first true scan;
  `.acc` is floored at 0 before the time is added and capped at `max(.pre, 0)`; `.dn` is
  `.acc` at the cap, recomputed each true scan, so a raised `.pre` resumes timing; `.tt`
  is `1 − .dn`. De-energised, `.acc .dn .tt .en` are 0. `last` is set to `now` on every
  run. **Nothing may follow a `ton` on its path** (in its leg, or after a group one of whose
  legs ends in it): whether the power after a `ton` is the rung's, as after `ote`, or the
  timer's `.dn`, IEC's Q, is left open, and refusing is the reversible way to leave it.
  A timer no `ton` runs is a warning.
- **The host contract** is M1-5's, unchanged: a member as an input key is refused with its
  own `input …` message, values are not checked each scan, and the evaluator is total on a
  hand-built env, a timer entry of any shape included.
- **Decision 6, measured.** One program type, two instances stepped through `call/4` every
  10 ms and every 50 ms, `go` rising at 1000 ms with a 5000 ms preset: both are done at
  6000 ms and agree at every time both scan. The equality holds per rising edge, when both
  instances see that edge at one time and the preset is a multiple of both periods (a
  1030 ms preset is done at 1030 ms and 1050 ms). A timer that re-triggers itself repeats
  every preset plus two task periods, as MatIEC's TON does, so its period differs at 10 and
  50 ms.
- **Known costs, recorded.** After `move 3000 t1.pre` the rung still reads 5000 until a
  restart. An instance kept running under a recompiled program of the same name keeps its
  old `.pre` until a restart, which organisation.md's online-edit row must answer when that
  lands. A scan costs about 5.7% more reductions, nearly all of it `evaluate/3`'s threading.
  *(The review above found two more for that row: a tag the recompile adds, or whose type
  it changes. OE-1 answers all three, 2026-10-01: `Logex.Edit` moves `.pre` where it still
  holds the old preset, starts what is added, and refuses a type change, and a plain swap
  still does what is recorded here.)*

**Landing, in commits, each green and each with a test that fails when its change is
reverted:** (1) the eight naming stanzas; (2) `evaluate/3`, a refactor; (3) `ons`; (4) the
comparisons; (5) `var t1 ton` and members; (6) `ton`; (7) the host-contract property over
all of it; (8) the documents. A new backlog item, B10, records that
`Logex.Warnings.second_otes/2` orders warnings that share a line by a map, never by rung.

The item as written follows.

Both need per-instance cross-scan state, so they are the proof that M1-5's architecture
is right. TON is what turns this from an expression evaluator into something
recognisable as a PLC: it needs a per-instance struct (`.PRE/.ACC/.DN/.TT/.EN`)
persisting across scans plus an elapsed-time source. Comparisons (`eq ne lt gt le ge`,
per `docs/naming.md`) ride along in the same pass for nearly free — they are pure input instructions
with exactly the existing rung-condition contract.

**§5 has settled the addressing question:** member access is `.`, added as one lexer rule
producing a single `name` token, with no grammar edit — so `t1.dn` and `t1.acc` lex, and
`env` holds a per-instance record rather than flat `"t1.dn"` keys, because `.acc`
and `.dn` must update together in one scan. That work is a prerequisite for this item, not
a follow-up. Take the elapsed time as an *injected scan input* rather than an internal
clock read, or the runtime stops being deterministic and testable. **ONS** is the smaller
half and worth doing first: it needs one bit of cross-scan state and no time source at
all, which makes it the cheapest possible proof of the per-instance state design.

Note there is currently no scan loop at all: `evaluate/2` runs exactly one pass, with no
repeat, no scan counter, no first-scan bit, and no separation of input image from output
image — so nothing marks which tags are physical inputs that logic must not write. The
semantics are correct; only the driver is missing, and it is roughly an `Enum.reduce`.
*(Since M1-3 a `var_input` is declared and logic may not write it; since M1-5 an instance
carries its clock and first-scan bit, and `put_inputs/3` keeps the input image apart from
the `var_output`s a scan returns. There is still no loop: the host calls each scan, and
scheduling is Milestone 2's.)*

**Milestone 1 is done when a seal-in circuit written in a `.ld` file on disk can be
compiled once into a named, stateless value you can hold, run for N scans as an instance
against a typed tag table, and report a located diagnostic — ``seal.ld: line 3: unknown
instruction `xyz` `` — instead of raising.** (Amended 2026-09-28 per M1-5, and its example
2026-09-29 to the message `Logex.compile_file/1` really gives.) **Met with M1-5:**
`test/logex_test.exs` compiles `seal.ld` from disk, runs it for four scans as an
instance, and asserts that message for a broken file, which `format/1` prefixes with the
path as it was given. That single sentence
exercises M1-1 through M1-5; M1-6 is what proves the design was right rather than merely
plausible. *(M1-6 landed 2026-09-30: decision 6's two-rate test is its proof.)*

### Milestone 2 — program organisation

**Decided 2026-09-28** (§5; design and rationale in `docs/organisation.md`, whose §7
decisions were all taken as recommended). *(Its §7 has since gained decisions 15–29, on
online edit, taken on 2026-10-01: 18, 28 and 29 depart from their recommendations and 19
had none; see "Online edit — decided 2026-10-01".)* Each item surveys its new words in
`docs/naming.md` first, lands green, and pins every rule with a test that fails when the
rule is reverted. M2-5 needs only M1-6 and B5, so it may move ahead of M2-1. *(Ordered
2026-10-02 by decision 30, below: M2-5 lands after M2-1.)*

**Designed 2026-10-02** (`docs/organisation.md` §4.10, "Milestone 2's design", and its §7
decisions 30–40; "decision N" in this section is that §7's). A design pass spiked
Milestone 2 in three tracks on copies of `47319f7`: the scheduler (M2-1); user function
blocks (M2-5); and the configuration file, shared globals and event tasks (M2-2, M2-3,
M2-4, M2-6). Each track was reviewed for correctness and for fit, then revised, and each
reverted every rule it adds alone under its full suite: 113 rules in the scheduler's
spike, 88 in the function blocks' and 127 in the configuration file's, every one red but
one (owed below). The scheduler's and the function blocks' spikes, merged, pass together:
582 tests on Elixir 1.20.4. The maintainer took decisions 30–40 as recommended but 35,
the configuration file's extension, choosing `.logex`, outside the options offered; the
pass's routine choices, the rules of §4.10, were all taken as recommended. M2-1 landed
on 2026-10-02, M2-5 on 2026-10-04, M2-2 and M2-3 on 2026-10-11, and M2-4 and M2-6 on
2026-10-12 (below), which completes Milestone 2.

**The order (decision 30):** the design record, then M2-1, M2-5, M2-2, M2-3, M2-4 and
M2-6.
- **M2-1 first**, decision 1's default. M2-5's Done-when then stands as written: its
  `m1.s2.run` is read through M2-1's `get/2`.
- **M2-5 before M2-2,** so the configuration file's reader, its loader and the IR walk
  are written against `cal` from their first commit. In the other order a hand merge of
  the spikes failed at four seams: a walk of a program's writes that raised on `cal`, a
  loader that put a function block type among the programs, a block's `var_external` that
  raised `FunctionClauseError`, and two loaders.
- **Then the text items in turn:** M2-3's task lines build on M2-2's reader, M2-4's checks
  on the IR walk that is its first commit, and M2-6's event tasks on M2-3's task lines.
  The walk lands before the first check that reads a program's writes or timers.

Each commit lands green under the full gate, with its mutation rows in its message, every
rule it adds reverted alone. M2-1's and M2-5's commits were built as gated series; the
configuration file's must be built that way before they land.

- **M2-1 · The scheduler, from Elixir data, no syntax.** `%Logex.Configuration{}`,
  `Logex.Runtime.start/cycle/next_due_in/get`, periodic and task-less instances,
  copy-in/copy-out, overlap events. *Done when* a configuration built in Elixir with a 10
  ms task, a 30 ms task and a task-less instance, cycled every 10 ms from 0 to 990 ms by an
  injected clock, runs each instance exactly as often as its task dictates, in priority
  order; a late cycle yields one `{:overlap, …}` and no lost phase; the README program
  gives identical outputs through `scan/2` and through a one-instance configuration.
  *(Worded 2026-10-02: "cycled every 10 ms from 0 to 990 ms" was "cycled for one
  simulated second", which did not say how the clock is stepped. The counts are 100, 34
  and 100 runs.)*
  *(Online edit, 2026-10-01: M2-1 also keeps `docs/organisation.md` §4.9's constraints,
  so OE-2 needs no rework: the runtime value holds plain data only; state is keyed by name,
  program instances are held flat and never nested under a task, and execution order is a
  list; each item's rule for a new piece
  of state serves both `start/1` and an edit that adds one, with the edit's exceptions
  listed; one checked constructor, which M2-2's parser feeds; an opaque
  `%Logex.Runtime{}`; one copy of each global; and an open set of events. OE-1's design
  adds one: `start/1` builds each instance through the same constructor as
  `Runtime.instance/1`, so an instance's `first`, its one-shot block list and any field it
  gains later cannot drift between the two.)*

  *Designed 2026-10-02* (`docs/organisation.md` §4.10, M2-1). The scope widens twice,
  each annotated where it was decided: every `docs/organisation.md` §4.4 check that M2-1's
  data can express, over tasks, globals, located points, instances and connections, lands
  here in `Logex.Configuration.check/1`, pinned from data, where M2-2 had them; and
  `restart/2` and `overlaps/1` join §4.6's API (decision 38). A host mistake no text can
  say raises `ArgumentError` (decision 36), and a priority is 0 to 65535 (decision 37).
  `CLAUDE.md`'s rule for new state extends to `%Logex.Runtime{}`. A configured plant is
  not edited until OE-2: `Logex.Edit` edits a lone instance, and `%Logex.Runtime{}`
  changes only through the API. It lands as:
  1. `Logex.Configuration` and the `:configure` stage: the element structs, `check/1`,
     `new!/1`, `location/1` and `initial/1`;
  2. the resource with periodic tasks: `%Logex.Runtime{}`, `start/1`, `cycle/3`,
     `next_due_in/1`, `overlaps/1` and `get/2`;
  3. `restart/2`;
  4. the contract walk over a configuration, in `api_contract_test.exs`;
  5. the Done-when end to end, with the walks of the README's examples;
  6. the documents, among them the README's "Changing a running program", which says that
     a configured plant is not edited until OE-2.

  The first five are built as a gated series on copies of `47319f7`: 466, 504, 509, 510
  and 514 tests, from 430, each commit's rules red in its own tree. The second's prose
  names `restart/2` early and is trimmed when it lands.

  **Status: DONE — landed 2026-10-02**, as the six commits of its landing order: (1)
  `Logex.Configuration` and the `:configure` stage, `44bb4dd`; (2) the resource with
  periodic tasks, `5a7db68`; (3) `restart/2`, `0216b96`; (4) the contract walk over a
  configuration, `31bbf6a`; (5) the Done-when end to end, `cedfdb3`; (6) the documents,
  the commit after it, among them the README's "A configuration", whose output is a real
  run, and its "Changing a running program", which says that a configured plant is not
  edited until OE-2: `Logex.Edit` edits a lone instance, and `%Logex.Runtime{}` changes
  only through its API. 522 tests pass on Elixir 1.20.4 (8 of them doctests), up from
  430. The messages of (1) to (3) record their mutation tables, every rule each adds
  reverted alone in its own tree and the full suite judged by exit code: 148 rules (89,
  52 and 7), every one red. (4) and (5) add no rule; each reverted the 65 rules of (1) to
  (3) a configuration runs on in its own tree, every one red, the walk failing 50 of them
  and the Done-when 19. The walk passed with its full reach under seeds 1 to 30 besides
  its own. (1) applies what the spike did not follow: decision 36, `check/1` raising one
  `ArgumentError` with every host mistake, a line each, the line between a host's mistake
  and a diagnostic drawn by what a configuration's text can hold, its message deciding
  each of the spike's messages by it; decision 37's bound; and the record's rule on
  lines. Two words differ from the spike besides: an instance named whole is "a program
  instance of `motor`", and a negative initial value is refused for a bool as for a dint.
  Every growth bound was read over 32 runs; the cycle at 16x the instances now has 20.5,
  where the spike's 19.5 sat less than a fifth above the measured top.

  A review of the six commits (three lenses, correctness, fit and tests, and a skeptic
  reproducing each finding) confirmed 22 findings, 20 once the two found twice are
  merged. Their fixes are the commit after (6), and the suite is at 527 tests (8
  doctests). Three were in `lib/`'s behaviour. `check/1` checked no other field of an
  element whose name it refused, a duplicate, a case twin or a name with `.` parts, where
  a `.ld` declaration line checks them; it now checks every field of such an element and
  refuses only its name. A configuration or an element that lacked one of its struct's
  keys escaped `check/1`, `new!/1` and `start/1` as a `KeyError` or a
  `FunctionClauseError`; it is now the host's mistake, as any value that is not the
  struct is (decision 36). And `get/2` told a path to an internal member, `m1.t1.last`,
  that it was no member, where §4.10 says such a path is told what it names; it is now
  told the member is internal. One was words: three new messages put "a" before a
  program's name, "`m1` is a `outer`", the form the Owed list below calls a defect; they
  say "a program instance of `outer`". Ten were rules no test failed without, each now
  with one: `cycle/3` refusing a struct as its inputs, and its key order past 32 keys;
  `get/2`'s did-you-mean offering an instance; `check/1` refusing a program whose tags or
  rungs are junk, a dint var_input's constant past 32 bits, a second connection of a
  var_input first tied to a constant, a connection to a name with `.` parts as a
  diagnostic, a mistyped var_output driving nothing, the declaration order of unconnected
  var_inputs, and the configuration's name before its programs among the host's
  mistakes. The rest were documents: the runtime's one-rule section said a task an edit
  keeps keeps its due time, against decision 40; decision 30's `{:ok, 1}`, the probe's
  own wrapper; §6.2's "Adds `configuration_test.exs`"; `Logex.Diagnostic`'s moduledoc on
  who returns diagnostics and sets `file`; a test comment citing fix F8 for decision 36's
  rule; and two comments in `Logex.Configuration` claiming one message per host mistake,
  which `new!/1` does not keep where a bad name leaves a var_input unconnected, now
  stating the rule the code keeps: a bad name is not recovered, as on a `.ld` line.

  A check of those fixes confirmed four findings, three once the two found twice are
  merged, all in what the tests saw and none in `lib/`'s behaviour; the commit after the
  fixes pins each. No test held a use of a duplicate global's name to the global that
  kept the name. The filter that keeps an element named by the host's mistake out of
  every diagnostic was pinned as a whole, not for a task's interval and priority, a
  global's location and address, or an instance's task alone. And no test gave `check/1`
  a plain map or another struct, or gave it or `new!/1` an element that lacks a key and
  has another in its place. The suite is at 528 tests (8 doctests).
- **M2-2 · The configuration file, task-less.** A separate `.logex` file (the extension
  was a placeholder until decision 35 chose it on 2026-10-02): `var_global`, plain and
  located (`at panel.q.0`), `program <inst> <type>`, arrow-free connections (`m1.start
  pb_start_1`), every `var_input` connected, one driver per sink. *Done when* two instances
  of one `.ld` program type, wired in a configuration file to different input and output
  points, run for N cycles from one input image and keep independent state; a mis-wired,
  unknown, undriven-input or mistyped connection is a located diagnostic naming its file
  and line. *Also decided 2026-09-30:* the extension says what kind of file it is, so
  `Logex.compile_file/1` refuses anything but `.ld` with a `:file` diagnostic. Until
  then it names a program after its basename less the last extension, whatever that is,
  and `test/logex_test.exs` pins that; its `seal.txt` assertion flips with this item.
  *(Flipped with it, 2026-10-11: `seal.txt` is a `:file` diagnostic.)*

  *Designed 2026-10-02* (§4.10, M2-2). Two departures from the scope above, each annotated
  where it was decided: the §4.4 checks M2-1's data can express land with M2-1, and M2-2
  asserts each again as a whole diagnostic list from source; and the loader is M2-5's, one
  memo per configuration. The file is read by a recursive descent over `Logex.Lexer`'s
  tokens and printed back with an exact round trip. It reserves `program var_global at`
  in the configuration file. It lands as:
  1. the `program`, `var_global` and `at` stanzas;
  2. `compile_file/1` takes only `.ld`, as a gate in front of M2-5's loader;
  3. `Logex.Configuration.Text`: the reader, the text's own definition of what a line can
     say, and the printer; it reserves the words, and each message that names a word
     lands with it;
  4. the configuration file's checks as rows of M2-1's `check/1`, in the file's words,
     with one diagnostic per instance for its unconnected var_inputs;
     `Configuration.compile/3`; every M2-1 check asserted again from source; the
     public-surface pin of `Logex.Configuration` rewritten once;
  5. the configuration's loader, through M2-5's with one memo per configuration, refusing
     a block's file on a `program` line;
  6. the round trip, totality and growth;
  7. a location in a `.ld` rung named as one;
  8. the Done-when on M2-1's `cycle/3`, and the documents.

  The fourth is the largest piece no spike built (owed, below).

  **Status: DONE — landed 2026-10-11**, as nine commits, gated alone, each with its
  mutation table in its message, every rule it adds reverted alone and the full suite
  judged by exit code. The first five were built on `025199a`, before M2-5, and rebased
  onto `732c0b6`, the last three after M2-3's commits, a departure from the record's order
  made because they need M2-5's loader: (1) the survey, `f2929d4` (the record's 1); (2) the
  reader and printer, `Logex.Configuration.Text`, `be90e26` (3); (3) the checks as rows of
  `check/1`, with `Configuration.compile/3`, `3a17ecd` (4); (4) the round trip, totality
  and growth, `2e015cb` (6); (5) a location in a rung, `82bb5af` (7); then, after M2-3's,
  (6) `compile_file/1` takes only `.ld`, `20ff260` (2); (7) the configuration's loader,
  `4d2aac1` (5); (8) the Done-when from files on disk, `229a45a` (8); (9) the documents,
  the commit after it (8). 770 tests pass on Elixir 1.20.4 (8 of them doctests), up from
  675 on `732c0b6`. The mutation tables of (1) to (5) were run before the rebase, on
  `025199a`, 154 rules (9, 55, 59, 20 and 11), every one red; (5)'s eleven were run again
  on the rebased tree, since M2-5 changed the compiler's lookup most, and all are red.
  (6) and (7) add 29 rules (6 and 23), every one red on their own trees; (8) adds none
  and reverted twelve the Done-when relies on, every one red. The rebase kept both sides
  of every conflict: M2-5's `function_block` words beside the configuration file's in
  `docs/naming.md`, `naming_test.exs` and `CLAUDE.md`, M2-5's describes in
  `end_to_end_test.exs`, and M2-5's one block-type message, which `compile/3` raises and
  whose words the totality property now pins, a user block's among them.

  Readings the landing made, each stated in its commit and pinned:
  - the loader is `Logex.Configuration.compile_file/1`, beside `compile/3` as
    `Logex.compile_file/1` is beside `compile/2`, and M2-5's private loader is opened as
    `Logex.compile_files/1`, several `.ld` files through one memo; so the public-surface
    pins of `Logex` and of `Logex.Configuration` are each rewritten again, where the
    record's fourth item rewrote Configuration's once;
  - the configuration is named after its file, `plant.logex` being `plant`; a bare
    `.logex` "names no configuration" (decision 35), and any other extension, a file
    that cannot be read and a name that is none are `:file` diagnostics, the text still
    compiled after a refused name; `compile_file/1` tells a `.logex` file whose it is;
  - a `program` line's type that gives no program type is cited once, at its first
    instance's line, its other instances silent: a missing `<type>.ld` as an unknown
    program type, with a did-you-mean among the `.ld` files beside the configuration; a
    block's file with the one block-type message; a file that does not compile by name,
    with the files its mistakes are cited in, and those diagnostics after the
    configuration's, each with its own file and line, each once, in the order the types
    are named (so worded after the review below);
  - a program type's warnings stay in its program, a block's handed back once a
    configuration, by the first program type that holds it and compiles (so worded
    after the review below); the configuration's own stay
    in its `warnings`;
  - a type that is no name, or a keyword, is not looked for.
  Growth: the reader, the printer and `compile/3`, read over 44 runs, 4.20x to 4.59x,
  4.01x to 4.06x and 4.25x to 4.95x for 4x the input, bounds 5.6, 5.0 and 6.0; the
  loader, over 36, 4.007x to 4.025x for 4x the program types, bound 4.9.

  A review of M2-2's and M2-3's commits confirmed findings fixed in the commits after
  `a5b4e62`, each with a test that fails when its fix alone is reverted:
  - `Logex.compile_files/1` keeps which blocks a program has handed back apart from its
    memo, so a block's own file before a program that holds it no longer takes the
    warnings of the blocks below it from that program; and a result a cycle gave is not
    kept past its path, so each path's result is its own `compile_file/1`'s.
  - `Logex.Configuration.compile_file/1` lists a block's mistakes once, though several
    program types hold it, and a program type that does not compile names the files its
    mistakes are cited in, a block's among them, where it named the type's own; and a
    test pins that the types' diagnostics come in the order the types are named.
  - a `program` line broken before its instance's name, `program 5 motor`, `program`
    alone or `( program m1 motor`, declares a program it cannot name, a placeholder
    `Logex.Configuration.Text.read/1` gives with no name, so the configuration is given
    the line's diagnostic only, not "declares no `program`" after it.
  - README's list of the public API, and its syntax list and "A configuration file",
    name `Logex.compile_files/1`, the loader a configuration's program types go through.

  775 tests pass on Elixir 1.20.4 (8 of them doctests), up from 770 on `a5b4e62`.
- **M2-3 · Periodic tasks in text.** `task <n> interval <ms> priority <p>` and `with`.
  *Done when* the plant of `docs/organisation.md` §4.4 without its event task, its `motor`
  the §4.2 one plus `var t1 ton` and a rung `xic motor ton t1 5000` (so no `estop`,
  `var_external` or `cal`, which arrive with M2-4 and M2-5), cycled every 10 ms from 0 to
  990 ms, runs `m1` 100 times and `m2` 20 times, and each instance's `t1` times against
  the one clock. *(Worded 2026-10-02: "cycled every 10 ms from 0 to 990 ms" was "driven
  for one simulated second".)*
  *(M1-6: that motor compiles without a warning and times. Say how the
  inputs are timed: an instance sees an edge when a scan copies it in, so the equality
  holds per rising edge, when two instances see that edge at one time and the preset is a
  multiple of both periods. A timer that re-triggers itself repeats every preset plus two
  task periods, so its rate differs between tasks, as MatIEC's TON does.)*

  *Designed 2026-10-02* (§4.10, M2-3). A priority is 0 to 65535 (decision 37), and the
  item's documents state decision 40's rule for an interval OE-2 changes. It reserves
  `task interval priority with`, and lands as: (1) the `task`, `interval`, `priority` and
  `with` stanzas; (2) task lines and `with` turned on, with the warning for a task that
  runs no instance; (3) the Done-when, on M2-1's scheduler, and the documents. The reader
  is spiked.

  **Status: DONE — landed 2026-10-11**, as three commits between M2-2's fifth and sixth,
  built on `025199a` and rebased onto `732c0b6` without a conflict but in the Done-when's
  test file, with the documents in M2-2's last commit: (1) the survey, `0668643`; (2)
  task lines and `with`, the warning for a task that runs no instance, and the §4.4
  receipt's seven diagnostics word for word, `bd6980f`; (3) the Done-when, `4fa6cbc`:
  §4.4's plant without its event task, read by `Configuration.compile/3`, cycled every 10
  ms from 0 to 990 ms, runs `m1` 100 times and `m2` 20 times, and each `t1` times against
  the one clock, the inputs timed as the record asks. (2)'s 51 rules and the 21 the
  Done-when relies on, reverted on `025199a` before the rebase, are every one red.
  Decision 40's rule for an interval OE-2 changes, `min(next_due, now + new interval)`,
  is stated in the `interval` stanza of `docs/naming.md` and in `Logex.Runtime`'s
  one-rule section; nothing builds it before OE-2.
- **M2-4 · Shared globals.** `var_external` in `.ld`; type agreement (Ed 2 §2.4.3); no
  writes to an input point; a two-writer warning. *Done when* an e-stop declared once as
  a `var_global` and read by two instances through `var_external` stops both in the same
  cycle; a `var_external` with no matching global, or of another type, is a located
  diagnostic.

  *Designed 2026-10-02* (§4.10, M2-4). One copy of each global: the scheduler merges each
  `var_external`'s global into its instance's state before `call/4` and splits it off
  after. A function block's file refuses `var_external`, a deliberate, reversible
  departure from IEC. The two-writer warnings ride on the configuration's `warnings`. It
  lands as: (1) B5's one IR walk, with public functions for which tags a program writes
  and which timers it runs, knowing `cal` and reaching block bodies, and no change in
  behaviour; (2) `var_external`: its stanza, the section and its `.ld` rules, and its
  refusal in a block's file with a located diagnostic; (3) the binding checks and the two
  writer warnings, from the walk, into M2-1's `check/1`; (4) one copy of a global at run
  time, the Done-when and the documents. The walk, the block-file refusal and the
  run-time copy are not spiked. *(A throwaway spike of the run-time copy, 2026-10-04,
  built it on `025199a` against a model with no merge or split, every rule red when
  reverted; decisions 46–49 and §4.10's rules settled what it found. The Done-when is
  tested on §4.4's plant at a cycle both tasks are due, 50 ms, with a second test that a
  pulse shorter than `m2`'s interval never reaches it (decision 46). The survey is
  committed first, on its branch, since CLAUDE.md asks for the survey before the code.)*

  **Status: DONE — landed 2026-10-12**, as six commits on `fd8fda8`, the record's four
  with the survey first and the documents last, each green under the full gate on Elixir
  1.20.4 / OTP 28: (1) the `var_external` stanza, ported from the backup of 2026-10-04 and
  its quotations checked again, `c057553`; (2) B5's one walk, `Logex.Walk`, whose
  `instructions/1`, `uses/2`, `writes/1` and `timers/1` the compiler, `Logex.Warnings` and
  `Logex.Edit` read in place of their own walks, `writes/1` and `timers/1` reaching into
  each block a `cal` runs by path, with no change in behaviour, the suite of `c057553`
  passing whole against its `lib/` and every traced call of that suite agreeing,
  `2a03b52`; (3) the section, its `.ld` rules, a configuration file's keywords refused as
  a var_external's name, and its refusal in a block's file, `c9087ca`; (4) the binding,
  the input-point write check, a var_external in a connection, M2-2's two warnings brought
  to it and decision 48's two writer warnings, in `check/1`, `b71b780`; (5) one copy of
  each global at run time, decisions 46, 47 and 49, the Done-when from text and from files
  on disk, the sampling test, the rule tests and the contract walk against a model of one
  map of globals, `6f91512`; (6) the documents, the commit after it. The messages of (2) to
  (5) record their mutation tables, every rule each adds reverted alone in its own
  worktree and the full suite judged by its exit code: 61 rules (22, 9, 22 and 8), every
  one red. 821 tests pass on Elixir 1.20.4 (8 of them doctests), up from 775.

  Readings the landing made, each pinned by a test, and in §4.10's M2-4 note: the walk
  gives a path inside a block the lines of the block's own text, each block type read
  once a call, its paths put from the top down, since putting them level by level was
  cubic in a chain's depth; the storage-bit words of the writer warnings are given
  wherever any writer's `ons` keeps its bit in the global, whoever the other writer is;
  a var_external line refused for its initial value declares nothing, as a var_input's
  does; and the binding needs neither a sort of the instances nor decision 42's silence,
  since `check/1` holds lines rising and no var_external can be named as a refused global
  is. The tie-break test §4.10 owes M2-6 now has the form M2-4 gives it, two writers of one
  global through `var_external` in `end_to_end_test.exs`; the event task's half waits for
  M2-6. Growth bounds are a fifth above the highest of 32 or more runs, half of them
  beside three full suites; the walk's depth test and M2-2's loader test each failed once
  in the 39 full suites the mutation rows ran four at once on four cores, the load "Costs
  to keep in view" records.
- **M2-5 · User function blocks.** `function_block <name>` as a file's first line,
  matching the file name; *(its first rung since 2026-10-02: comments and blank lines may
  come before it, §4.10)*
  instances (`var s1 seal`); `cal` with positional operands, rung power as EN, and nothing
  copied on a false EN; nesting; recursion is a diagnostic. *Done when* a seal-in written
  once as a function block and instantiated three times in one program behaves as three
  independent seal-ins, `m1.s2.run` reads one of them, a false EN freezes only its own
  instance, and a recursive type, an unknown FB type or a `cal` of a non-instance is a
  located diagnostic. *(From M1-6, for this item: `Logex.FbType` already recurses into a
  member whose type is a type, and `public/1` leaves a `:local` role out by default; a
  frozen instance must leave a timer's `.en` and `last` alone, so a timer that was timing
  catches up; the "no `ton` runs it" warning must say `cal` for a user type; `first` is
  the program instance's, so an `ons` inside a block frozen on the first scan is not held
  back when it first runs; which of a user block's members logic may write is open; and
  `cal` on a built-in type should be refused.)* *(Answered 2026-10-02: no member of a user
  block is written from outside it, by decision 33, and `cal` of a `ton` is refused,
  naming the `ton` that runs it; the other notes stand as written.)*

  *Designed 2026-10-02* (§4.10, M2-5). It lands after M2-1 (decision 30), so its
  Done-when stands as written and its own test reads `get(rt, "m1.s2.run")`. The scope
  above leaves out three things the design gives it, each annotated where it was decided:
  the nested migration that `docs/organisation.md` §4.9 and OE-2 below assign to it, so a
  program that holds blocks may change while it runs, by path (decision 31), a one-shot
  inside a block blocked until a scan runs it (decision 32); the loader, ahead of M2-2,
  `compile_file/1` finding `<word>.ld` beside the file and handing back the loaded blocks'
  warnings (decision 34); and `types:` on `Logex.compile/2`, a block's file compiling to
  `{:ok, %Logex.FbType{}}`. Fix F15 lands here: `%Logex.Program{}` gains a `file`. It
  lands as:
  1. the survey: the `function_block` and `cal` stanzas, and
     `Logex.Declarations.kinds/0` with its naming test;
  2. the IR walks learn a signature per instruction, with no change in behaviour;
  3. blocks and `cal`, reserving `cal` in every `.ld`, in any case, and `function_block`
     in a block's file; fix F15; the Done-when, through `get/2`; one message for a block
     type given where a program goes, at every entry point, M2-1's `check/1` included;
  4. the edit by path (decisions 31 and 32), in one push with the third, whose edit refuses
     every change to a block;
  5. the loader (decision 34);
  6. the documents.

  The spike holds the first five, not cut into commits. Fix F15, the `get/2` assertion,
  the one message in `check/1` and the warnings of decision 34 are not built. A separate
  commit after M2-5 excuses the uses of a declaration whose type is unknown.

  **Status: DONE — landed 2026-10-04**, as seven commits: the first five of its landing
  order, then the excusal the record put after M2-5, then the documents, a departure from
  the record's order made so that the documents describe the excusal with the rest; an
  eighth that fixes what a review of the seven confirmed, `4fc8587`; a ninth that holds
  each block type once per body, `9ff76f6`; a tenth that fixes what a check of the
  eighth, the ninth and `4230f65` confirmed, `4d006d6` (below); an eleventh that holds
  each block type once per outermost type, decision 53, `1a16b1d` (below); a twelfth that
  compiles each type given again from its source text, decision 54, `dafb5a0` (below);
  and a thirteenth, the commit after `0183bf2`, that fixes what a check of the eleventh
  and the twelfth confirmed (below). `4230f65`, which gives three older walks more draws,
  and `0183bf2`, which corrects this plan's note on M2-4's and M2-6's run time, are not
  part of M2-5. (1) The survey,
  `4db37b1`; (2) one lookup of an instruction's slots for the walks,
  `Logex.Compiler.signature/2`, with no change in behaviour, `e8a55b6`; (3) blocks and
  `cal`, `969a5a4`; (4) the edit by path, `a87edcc`; (5) the loader, `2c3c609`; (6) the
  uses of a declaration whose type is unknown excused, so a misspelled block name is one
  message, `776a810`; (7) the documents, the commit after it, among them the README's "A
  function block", whose output is a real run. 643 tests pass on Elixir 1.20.4 (8 of them
  doctests), up from 529. The messages of (1) to (6) record their mutation tables, every
  rule each adds reverted alone in its own tree and the full suite judged by exit code:
  214 rules (2, 3, 125, 46, 30 and 8), every one red. (2) also traced every call the suite
  makes to `Logex`, `Logex.Runtime`, `Logex.Edit`, `instructionize` and
  `Logex.Warnings.of/2`, under the old code and the new, and the two digests are one. (3)
  and (4) are to land in one push: (3)'s edit refuses any change to a block.

  The landing built what the spike did not: fix F15, a `file` on `%Logex.Program{}` that
  `compile_file/1` sets, on a block's body too, and that every `:edit` diagnostic carries;
  one message for a block type given where a program goes,
  `Logex.Declarations.not_a_program/1`'s, from the runtime, `Logex.Edit.accept/3` and
  `Logex.Configuration`'s `check/1` and `new!/1`, in place of M2-1's interim words
  (`Configuration.compile/3` and the configuration's loader, which M2-2 lands, are the
  entry points left; *landed with M2-2, which gives it at both*); the Done-when reading
  `Logex.Runtime.get(rt, "m1.s2.run") == {:ok, 1}` through a configuration, from text and
  from files on disk; decision 34's warnings handed back by `compile_file/1`; a test for
  every check inside `Logex.Compiler.lowered?/1`, so the owed rising-lines check below is
  closed; and "an instance of `outer`" for a user block's instance, so the owed "a outer"
  below is too. (6) is new besides: the spike kept M1-3's report of each use of a
  misspelled type's tag.

  Readings the landing made, each stated in its commit and pinned: a user block's name
  takes no article, "an instance of `seal`", since one chosen by its first letter gets
  "user" and "hour" wrong, while the built-in timer stays "a ton", and the block-type
  message says "through `ton`" for it; `get/2` calls a block's own `var` "a `var` of
  `seal`, hidden outside it"; a switch never reports a block's var_inputs as `:input` or
  `:unread`, since `cal` copies them in, and reports a block's var_output whose initial
  value changed as `:initial_changed` by its path; `compile_file/1` hands back the
  program's own warnings first, then each block's in the order compiled, and a block's
  own file only its own; a broken block's file stops the file that names it, but every
  block that file names is still loaded, so each broken one is reported; and a directory
  with a block's name "cannot be read". It reserves `cal` in every `.ld`, in any case,
  and `function_block` in a block's file; no test, `lib/` file or fixture names a tag
  either. Growth is pinned in reductions: a type given is checked once a compile, not once
  an instance (16 instances cost 1.05x one; declared from Elixir, 1.04x, since the
  review's fix); a switch and the scan after it grow with the block list's bytes, bound
  1.3x their growth; the scan right after a switch at 16x the instances took 16.2x to
  16.4x, and a second edit's steps at 16x the pending nested bits 16.4x to 16.8x, each
  bound 24. The edit walk over blocks in
  `api_contract_test.exs` passed with its full reach under seeds 1 to 30 besides its own,
  the rarest of what it asserts it reaches at least 6 times a run.

  A review of the seven commits confirmed 23 findings, and the eighth commit fixes 21,
  each fix a test can see with a test that fails when that fix alone is reverted.
  `Logex.FbType.same?/2` is now the one definition of a version of a block, which a
  compile and `user?/1` share, so a block given two versions of a block it holds that the
  compile took as one is a type the next compile takes; it compares the source text, as
  §4.10 says. `user?/1` and `lowered?/1` are total over warnings that are not a proper
  list and a struct for tags, `lowered?/1` checks each operand's line, `types:` must be a
  proper list, and a tag declared from Elixir is one version with every block the types
  given hold. Accept, a compile's lookup of a member, and the check of a type that
  instances declared from Elixir hold are linear, as growth tests in a block's members and
  in such instances pin. Tests now pin what had none: nothing copied out on a false EN, a
  body's tag table, recursion through a tag two levels down, a block's name matched
  exactly, the loader's case and its section lines, a nested `:preset_kept` (in the walk
  too), the order of the bits a scan keeps blocked and of several kind changes on one
  line, and a `cal` with one operand too many. It left two questions, which the maintainer
  decided on 2026-10-04. A body holding two instances of one block held its type twice,
  once per tag, so a copy that keeps no sharing grew as the width to the power of the
  depth: each block type is to be held once per body, its instances' tags naming it, as
  §4.10's "Held types" records, which `9ff76f6` builds, the type held in the body's
  `blocks` and read back by `Logex.Program.typed_tags/1`. And three walks that predate
  M2-5 each missed one atom of their reach under one seed of a family they were not
  measured under: they get more draws until their reach holds under 60 seeds of more than
  one family, measured on seeds they were not tuned on, which `4230f65` builds, 2,000
  sources, 150 programs and 400 configurations a run, up from 600, 40 and 150.

  A check of `4fc8587`, `9ff76f6` and `4230f65` confirmed 15 findings, 11 once the four
  found twice are merged, and `4d006d6` fixes them, but for the two
  questions below. A block's compiled body run as a program started each instance it holds
  at 0 and ran it wrong, and `get/2` and `Logex.Edit.accept/3` raised errors that are no
  `ArgumentError` on it: the runtime, `get/2` and the edit now read a program's tags
  through `typed_tags/1`, as a compile does. Tests now pin what had none: a timer's tag in
  a section no line gives it, each rung on one line inside a group, a nested group and
  past an instruction's first operand, `same?/2`'s rungs and every held type it compares,
  `user?/1` checking each type once however many paths reach it (a diamond of types), and
  accept reading a block's body once however many instances run it: 661 tests pass on
  Elixir 1.20.4 (8 of them doctests), up from 654. Documents that claimed more than the
  code does are narrowed: a type copied flat is linear in its depth where each type is
  reached through one holder; §4.9's cost for a program that holds blocks is linear in its
  instances too; `user?/1` checks a type's shape, not that its body is the one its source
  text gives; and `lowered?/1` is total over the tag tables it expects. Two are left for
  the maintainer. Where each level has two types and each holds both of the level below, a
  type copied flat is written out once per path and grows as 2 to the power of the depth,
  as an instance's state does: is each user type to be held once per outermost type,
  beyond §4.10's once per body, so that it stays linear there too? And `user?/1` takes a
  type whose rung was edited into another that text could say, its source text left as it
  was, as a version of its own, which only a compile that holds the genuine one too
  refuses: is `user?/1` to compile a body's source text again and ask that it give that
  body, so that §4.10's "a hand-edited type is an `ArgumentError` where it is given" holds
  for it?

  The maintainer answered the first on 2026-10-05: each block type is held once per
  outermost type, decision 53, which `1a16b1d` builds. The type a compile
  gives, and a program, hold every user block type their instances reach, at any depth,
  once, in one table, `blocks`, each held with no table of its own
  (`Logex.FbType.held/1`), and every instance's tag at any depth, a program's own among
  them, names its type, which `Logex.FbType.type_of/2` and `Logex.Program.typed_tags/1`
  give read inside the table (`Logex.FbType.within/2`); a `cal` hands its body the
  program's table, and the edit reads each type's body once from it. In the diamond of
  two types a level, each holding both of the level below, a type copied flat took 4,645
  and 9,313 words at 6 and 12 levels, where it took 36,405 and 2,354,805, and 18,678 and
  37,411 bytes as `term_to_binary/1`, where it took 147,620 and 9,546,257. With w types at
  a level sharing a chain of 16 below them, a program given the w types took 5,216 and
  8,984 words at w of 4 and 16, where it took 16,854 and 67,158, and a compile given them
  46,607 and 112,240 reductions, where it took 115,510 and 458,709: a compile now checks a
  type the tables of the types given share once, over the same types it names
  (`Logex.FbType.check/2`). Growth tests pin the diamond and the width, in words, bytes
  and reductions, and a compile's one-version check walking a type's table once however
  many instances hold it. A program's own tags no longer hold each type itself, so the
  tests that read a program's types read its `blocks`. 665 tests pass on Elixir 1.20.4
  (8 of them doctests), up from 661.

  The maintainer answered the second the same day: a type given is to be the one its
  source text compiles to, decision 54, which `dafb5a0` builds.
  `Logex.FbType.user?/1` compiles again each type a value holds, the outermost and every
  type in its one table, once a call, each before any type that names it, as a block of
  its name over the types it names as the table holds them, trusted and not checked again
  (`Logex.Compiler.recompiled/4`), and asks that the result be the type given, its members
  and its body's name, rungs, tag table and warnings, with the file the body was read
  from, none or a path to a file named after the block, which stamps each warning;
  `Logex.FbType.check/2` compiles a type that the tables of several types given share
  once. So a rung edited into another that text could say, a tag table edited into one
  declaration lines could give, a source text edited with its body left as it was, and a
  file that is no such path are each an `ArgumentError` where the type is given, §4.10's
  "a hand-edited type is an `ArgumentError` where it is given" holding exactly; a source
  text that gives the same body, a comment more, is the type a compile gives for it. A
  compile given one block of 50 and 200 rungs took 70,113 and 275,398 reductions, where
  it took 58,806 and 231,598, and given a chain of 50 and 200 types 113,959 and 446,194,
  where it took 87,334 and 340,188: a growth test pins both linear. It left a block that
  `Logex.Compiler.instructionize/3` builds with no source text to compile again, so a
  block whose members are declared from Elixir was refused; on 2026-10-11 the maintainer
  chose to keep such a block a type a compile takes, and the commit after the check's fix
  gives it a source text, each rung printed on its line, and hands its members from
  Elixir to the recompile. `user?/1` no longer calls `Logex.Compiler.lowered?/1`, which a
  body equal to its text's compile satisfies, so nothing in `lib/` calls it; it is kept,
  public and tested, as the definition of a compiled body the record names. 670 tests pass on
  Elixir 1.20.4 (8 of them doctests), up from 665.

  A check of `1a16b1d`, `dafb5a0` and `0183bf2` confirmed 21 findings, 17 once the four
  found twice are merged, and the commit after `0183bf2` fixes them all. Two were in the
  code. Each tag declared from Elixir checked its type with a memo of its own, so a type
  the tables of several tags' types shared was compiled again for each, against decision
  54's "once a compile": the tags now share the compile's memo, after the types given
  (`Logex.Declarations.split/4`), and tags of 4 types sharing a chain of 16 compile 20
  types again, not 68. And an edit's plans kept each block type read inside the program's
  table, so an edit copied flat wrote the table out once per instance and member planned,
  4,443,950 words with 16 types at a level sharing a chain of 16: the plans keep each type
  as the table holds it, and an edit copied flat grows with the instances its programs
  nest, 202,544 words there (§4.9, "Cost"). Tests now pin what had none: a tag built by
  hand of a type edited in its warnings or its file, given beside the genuine type; a
  held instance's initial value in `Logex.Compiler.lowered?/1`; a block's file of any
  extension, or none; two tags of two versions of one block; two types given whose tables
  disagree, whichever the source declares; a tag of an older version of the block itself;
  a table holding an older version of its outermost type; the version a program's table
  holds where one is given; and the check's memo keeping every version of what a type
  names. The M2-5 compile walk takes 7,500 sources, up from 3,000, sized from its rarest
  atom, and its reach held under 300 seeds of three families it was not sized on. Every
  growth figure was read again over 96 runs of the suite, 32 alone, 32 two at once and 32
  four at once, and each bound less than a fifth above the highest raised to a fifth
  above it, the size tests of `logex_test.exs` and `edit_test.exs` among them. Documents
  that claimed more than the code does are narrowed: a program holding a hand-edited block
  body may raise in the runtime. 675 tests pass on Elixir 1.20.4 (8 of them doctests), up
  from 670.
- **M2-6 · Event tasks.** `task <n> single <g> [interval <ms>] priority <p>`, fired by a
  rising edge, and in the first cycle if the trigger is already true; with `interval` too,
  it runs periodically only while the trigger is 0, plus a run on each edge (IEC rule 2). *Done when* an event task triggered
  from an input point runs once per rising edge, before lower-priority tasks due in the
  same cycle, and runs in cycle 1 if its trigger is already true.

  *Designed 2026-10-02* (§4.10, M2-6). `single` with `interval` is decision 39; an event
  task's due time, for the tie-break, is the cycle's `now`; a restart sets a trigger's
  last sample to 0, and an edit keeps it. The warning for a `ton` in a program an event
  task runs, on the configuration's `warnings`, covers a task with `interval` too and a
  `ton` inside a block. It reserves `single`, and lands as: (1) `single`: its stanza, its
  task lines, the warning from the walk, and `single` on `Logex.Configuration.Task`; (2)
  edges at run time, the Done-when and the documents. The reader and the checks are
  spiked; the edges at run time are not. *(Reordered 2026-10-04: a throwaway spike of the
  edges at run time, on `025199a`, found that after (1) `cycle/3` raises
  `ArithmeticError` on an event task, against the host contract. So the stanza comes
  first, then the data and the run time (the field, `check/1`'s rows, the edges, the
  Done-when from data, the contract walk), then the text (the task lines, `single`
  reserved, the warning from the walk, the Done-when from source) and the documents.
  Decisions 50–52 and §4.10's rules settled what the spike found.)*

  **Status: DONE — landed 2026-10-12**, as eight commits on `f75f1f1`, the reordered
  record's with the survey first, Milestone 2's done sentence walked before the documents
  and the documents last, each green under the full gate on Elixir 1.20.4 / OTP 28: (1)
  the `single` stanza, ported from the backup of 2026-10-04, its quotations
  checked again against the saved sources and the stanza brought to M2-2's to M2-4's
  keywords and to decisions 50 to 52, `0e86384`; (2) `single` on
  `Logex.Configuration.Task`, `check/1`'s rows, the edges at run time, decision 39 and
  decisions 50 to 52, the trigger's last sample in `Logex.Runtime`'s one-rule section, the
  rule tests and a growth test, `48eb735`; (3) PLAN M2-6's Done-when from data, the owed
  tie-break with two writers of one global, and M2-1's contract walk drawing event tasks
  against a model of decision 39 in phase points, `8ee4a33`; (4) the task line, `single`
  reserved, every check asserted again from source, `81cde64`; (5) the warning for a
  `ton` in a program an event task runs, from `Logex.Walk.timers/1`, `b967e77`; (6) the
  Done-when from source, §4.4's plant whole from text and from files on disk, `bbe68f5`;
  (7) Milestone 2's done sentence walked in `logex_test.exs`, `40ab59c`; (8) the
  documents, the commit after it. The messages of (2), (4) and (5) record their mutation
  tables, every rule each adds reverted alone in a worktree of its commit and the full
  suite judged by its exit code: 49 rules (27, 13 and 9), every one red; (3), (6) and (7)
  add tests only, and record which earlier rows they turn red. 860 tests pass on Elixir
  1.20.4 (8 of them doctests), up from 821.

  Readings the landing made, each pinned by a test, and in §4.10's M2-6 note: until the
  reader read `single`, a task with neither input kept M2-3's message, and since then it
  is offered both, its example naming the task only where its name is one, as a task with
  no priority, shown one of its own kind since the review, is named; an event
  task's interval of 0 is told to leave it out; a single counts as a use of its global; a
  single's value on a task line is any name token but an input's word; the ton warning is
  one a timer, at its instance's line, citing the `ton`'s own file and line, each program
  type's timers read once; and a decision-52 cycle counts the periods it missed as any
  late periodic task does. The contract walk took 500 configurations, up from 400, its
  reach held at 300 seeds of three families, and since the review takes 1000. Growth bounds are a fifth above the highest
  of 32 runs, half of them beside three full suites or in a full suite.

  Its review's fixes, each a commit after the documents', each green under the full gate
  and with its mutation table in its message: the ton warning cites each timer once a
  program type, each routine's typed tags read once, where a timer inside a block read
  the program's tags once a timer, quadratic in the timers, now pinned by a growth test in
  reductions with its timers inside blocks; and a block's timer from types read from no
  file is cited by the block's name, "on line 5 of block `inner`", where "on its line 5"
  read as the program's line; and a task with no priority is shown a task line of its own
  kind, `task e single trig priority 1` for an event task, where every task was shown a
  periodic one, named by the rule the interval's examples use, so a refused `u.v` is
  shown `task t …`; and a dint single, a diagnostic, counts no use of its global, a
  branch no warning could show, since a configuration with a diagnostic gives none; and
  the contract walk takes 1000 configurations, the maintainer's choice, up from 500, its
  reach measured again at the same 300 seeds, every atom reached by 11 configurations a
  run or more (`:due_time_order`), where 500 gave 2. 864 tests pass on Elixir 1.20.4 (8
  of them doctests), up from 860.

The scheduling rules are decided too: PRIORITY on every task, 0 the highest; ties go to
the earlier due time, then declaration order; no preemption; missed periods coalesced,
counted and reported; time injected in milliseconds, never read from a clock; reserved
words scoped by file kind. Once a wall-clock runner exists, a watchdog fault is to stop
scheduling, zero the output image once, report, and require an explicit restart: the
recommended choice, confirmed when the runner is designed (`docs/organisation.md` §7,
decision 14). *(Confirmed 2026-10-17 by decision 113, Milestone 4's design.)* *(Since 2026-10-02 a priority is 0 to 65535, decision 37, and an event
task's due time, for the tie-break, is the cycle's `now`.)*

**Milestone 2 is done when** a configuration file on disk instantiates one `.ld` program
type twice, with a function block inside it; wires the instances to declared I/O points
and to a shared global; schedules them under a periodic task, an event task and no task;
runs deterministically for N cycles from an injected clock and input image, with the same
outputs on every run; and reports every wiring, typing or scheduling mistake as a located
diagnostic naming its file and line. *(Done 2026-10-12, with M2-6: `test/logex_test.exs`,
"Milestone 2's done sentence, as written in PLAN.md", walks it clause by clause from files
on disk through `Logex.Configuration.compile_file/1`. "Schedules them" is read as the
configuration's instances: the one type's two run under the periodic task and no task,
and the event task runs a snapshot, as §4.4's plant has it, since two instances cannot run
under three schedules.)*

**Owed, from the design (2026-10-02).**
- **The port of the configuration checks into one validator.** The configuration
  spike's checks stand in a validator of their own, which cannot be merged with M2-1's:
  both add `lib/logex/configuration.ex`. M2-2's fourth commit ports them into M2-1's
  `check/1` as rows, rewrites the public-surface pin once, and asserts every M2-1 check
  again from source. Two device names that differ only in case are refused there, the one
  check M2-1's data can express that M2-1 does not land; no spike built it. *(Closed by
  M2-2's third commit, `3a17ecd`, the device names' case among its rows.)*
- **The seams between M2-5 and the configuration file** are planned, not built: the
  configuration spike has no `cal`. Each commit at a seam checks it on the composed tree:
  a `cal`'s outputs among a program's writes, a block's `ton` among its timers, a block's
  file on a `program` line, a block's `var_external`, and one loader. *(M2-5 has landed,
  so each is now checked against its code: the walks read a `cal`'s slots through
  `Logex.Compiler.signature/2`, the loader is `Logex.compile_file/1`'s private `load/3`,
  which M2-2 is to open for one memo per configuration, and the one block-type message is
  `Logex.Declarations.not_a_program/1`.)* *(Two of the five are closed by M2-2: one
  loader, `Logex.compile_files/1`, which the configuration's loader goes through, and a
  block's file on a `program` line, given the one block-type message. The other three,
  a `cal`'s outputs among a program's writes, a block's `ton` among its timers and a
  block's `var_external`, are M2-4's.)* *(Closed by M2-4: `Logex.Walk.writes/1` counts a
  `cal`'s outputs as writes and `timers/1` names a block's `ton` by its path, its second
  commit, and a block's file refuses `var_external` at its line, its third.)*
- **Two run-time pieces were not spiked by the design:** M2-4's one copy of a global, and
  M2-6's edges with `single` and `interval`. Their rules were the design's text alone. A
  test of the event task's tie-break is owed: an event task and a late periodic task of
  one priority, both writing one global, asserting which write lands. *(Both were spiked
  on 2026-10-04, as M2-4 and M2-6 above record: throwaway spikes on `025199a` built the
  run-time copy and the edges at run time, each against an independent model, every rule
  red when reverted, and decisions 46–52 and `docs/organisation.md` §4.10's rules under
  M2-4 and M2-6 settled what they found. The tie-break test is still owed, and §4.10 now
  says how it is written: in both forms, two writers of one global through
  `var_external` in `end_to_end_test.exs`, once M2-4 has landed, and, beside the rule
  tests, one instance writing a global that another copies to an output point.)* *(Closed
  by M2-6, in both forms: `end_to_end_test.exs` and `scheduler_test.exs`, `48eb735` and
  `8ee4a33`.)*
- **The untested rising-lines check.** M2-5 checks that a block's body given in `types:`
  is one a compile gives, its rungs among them on rising lines, each on one line, after
  its declarations. Reverted alone, that line check left the function blocks' spike green,
  and three more calls in the same check (to the compiler's `shared_bits/2`, `calls/1` and
  `path/2`) have no revert at all. Each gets a test that fails when it is reverted, or the
  check goes. *(Closed by M2-5's third commit, `969a5a4`: each check inside
  `Logex.Compiler.lowered?/1`, those four among them, has a test that fails when it alone
  is reverted. All but one: the review of M2-5 found that two declarations on one line
  were refused twice, by a check of their own and by the rising lines, so the first could
  not fail alone; the fix after the documents drops it, and a test pins the second for
  them. It also checks each operand's line, which the rising-lines check missed.)*
- **Messages.** M1-6's member messages put "a" before a type's name, which reads "a outer"
  for a block so named. M2-1's `get/2` follows them for a function block instance
  ("`m1.t1` is a ton", "is not a member of `m1.t1`, a ton") and owes the same. Its
  messages that named an instance's program that way now say "a program instance of
  `motor`". *(Closed by M2-5's third commit, `969a5a4`: every message that names a user
  block's instance, the compiler's, the runtime's, `get/2`'s and the edit's, says "an
  instance of `outer`", through `Logex.Declarations.instance_of/1`; the built-in timer is
  still "a ton".)*
- **Costs to keep in view.** Every compile checks each block type it is given at full
  depth: 2,486 reductions for a small block against 244 before, and 138,358,875 for a
  chain of 400 files built one at a time. A refusal of many bad keys is quadratic in its
  keys and the names, and so is the configuration file's check of a source with many
  mistaken names, from the same did-you-mean pass as the `.ld` compiler's; only a mistake
  pays it. Three of the suite's existing growth tests in reductions, `logex_test.exs`'s
  "compiling stays linear in the program's size" and two of `edit_test.exs`'s F16 tests,
  failed now and then under a load average near 40 while the spikes ran, and pass run
  alone; a CI runner that shares cores could see that. *(As M2-5 landed, the full-depth
  check of each type given stands, as §4.10 decided, and runs once a compile, however many
  instances declare the type, which a growth test pins: for instances declared from Elixir
  only since the review's fix, before which each checked it again. The three growth tests
  failed now and then again while M2-5's mutation rows ran three copies at a time, and
  passed in every gate. After the check of decisions 53 and 54 every growth bound was read
  over 96 runs, 32 alone, 32 two at once and 32 four at once, and set a fifth or more
  above the highest, so that each of the 96 passes, four suites at once among them,
  where the edit's size test reached 6.06x against its old bound of 6; a load like the
  spikes' may still raise one past its bound.)*

### Online edit — decided 2026-10-01

**Decided 2026-10-01** (§5; design, measurements and sources in `docs/organisation.md`
§4.9, decisions 15–20 in its §7, and OE-1's design decisions 21–29). A running controller
is changed the way the conventional family's is: a candidate is accepted beside the
running program, tested, untested, and assembled or cancelled, with state moved by name,
and never through the Elixir compiler. Each item surveys any new word in `docs/naming.md`
first, lands green, and pins every rule with a test that fails when the rule is reverted.

- **OE-1 · A staged edit of one program instance, before M2-1.** Accept, test, untest,
  assemble and cancel over one `%Logex.Instance{}` and two programs of one name, with
  §4.9's migration defaults and a report from every step. Its design pass first settles
  the four questions §4.9 leaves open: which `ons` bits are armed, a timer whose `ton` an
  edit restores, the report for a done timer whose preset rises, and which steps read the
  live state. It also gives the rules for a new piece of state that M2-1's `start/1` will
  share. *Done when* an instance of the README motor plus `var t1 ton` and a rung `xic motor ton
  t1 5000` (M2-3's motor), running with `t1` done, takes a candidate that raises `t1`'s
  preset, adds a second timer, adds an `ons` and removes the rung that drives a var_output
  (keeping the motor's own rung, so `t1`'s rung stays true): test runs the candidate with
  the decided `.pre`, initial values and no one-shot pulse, and its report names the held
  output and the dropped `.dn`; untest runs the original over the same state, and its
  report lists no undriven output; assemble prunes, and its report names the held output;
  a type change is refused at accept; and a program built from data that the text cannot
  say is refused. *(Designed 2026-10-01, the four questions answered:
  `docs/organisation.md` §4.9, "OE-1's design", and its §7 decisions 21–29 and fixes
  F1–F16.)*

  **Status: DONE — landed 2026-10-01**, as the eight commits of its landing order: (1) the
  design record in `docs/organisation.md` §4.9 and §7, `1e3efc1`; (2) the data path
  refuses what the text cannot say, decisions 24 and 28, `a619e90`; (3) the instance's
  one-shot block list, `48e1299`; (4) `Logex.Edit`, with its stages, refusals, start
  rules, inputs, held outputs, initial values, forecast and prune, and the contract walk,
  `3e45ea8`; (5) timers across a switch, `c1e5d54`; (6) one-shots across a switch,
  `1a39feb`; (7) the Done-when end to end, `a4a35b3`; (8) the documents, the commit after
  it, among them the README's "Changing a running program", whose output is a real run.
  420 tests pass on Elixir 1.20.4 (6 of them doctests), up from 320. The messages of (2)
  to (6) record their mutation tables, every rule each adds reverted alone and the full
  suite judged by exit code: 187 rules, every one red. By the messages' own totals the
  tables hold 188 (35, 17, 78, 40 and 18), because (4)'s mutant E46, red only from (5),
  which added the test that fails without it, is in both; as rows they hold 186 (35, 18,
  75, 40 and 18), because (3)'s row X1 is a behaviour its total leaves out and (4)'s row
  E10–E13 is four rules. A table's labels are its own, and (4)'s mutants E1–E71 are not
  decisions E1–E9. (7) adds no rule; it
  reverted 20 that the Done-when relies on, each red, and `end_to_end_test.exs` alone
  fails 19 of them. (1) and (8) are documents. Each of decisions 21–29 and fixes F1–F16 is
  cited by name in the commit that landed it. Where the design left a gap, a commit
  records its reading and §4.9 states it: a var_input a start rule writes is reported as
  `:input`, not `:added`; fix F7's program is fix F3's, the one that last scanned, and a
  switch blocks none of the started program's own one-shots when that program scanned
  last; an output the next program still shows is held at the state's value, and one it
  does not show at a value the edit learnt only while `switched` and `first` were both
  false; `:preset_kept` is reported wherever a timer the started program runs keeps a
  `.pre` that is not its preset; and fix F1's record covers every timer either program
  declares. Departures, each recorded in its commit: `%Logex.Instance{}` gains `switched`
  in (4), not (6), because fix F4 needs it too; decision 24's refusals sit inside
  `Logex.Declarations.check/1`, so it stays the one validator and now refuses a compiled
  timer's tag; a rung of nothing but empty groups takes a line in the rung order, as it
  does in the text; an edit accepted before a plain swap's scan is outside the contract;
  the switch and prune are built per instance for OE-2 but stay private until it calls
  them; and the Done-when's assemble follows a second test at the same boundary, since
  assemble is taken under test. Measured at the landing: accept and its steps take 4.4x
  the reductions for 4x the tags and 14.4x to 14.6x for 16x the depth; compiling costs
  about 17% more reductions, since the entry check lexes every name again, and stays
  linear; and at 2,000 rungs and 4,000 tags a test takes 0.68–1.19 ms against 1.31–1.36 ms
  for one scan (`docs/organisation.md` §4.9, "Cost").

  An adversarial review of the eight commits (three lenses, correctness, contract and
  mutation, and a skeptic reproducing each finding) confirmed 15 findings, 14 once the one
  found twice is merged. Its fixes are the commit after (8), and the suite is at 430 tests
  (6 doctests). Two were defects. The scan right after a switch looked each `ons` up in
  the block list by walking it, so 16x the blocked one-shots cost 65x the reductions of
  that scan, which comes when a controller most needs to stay on time; the scan now makes
  the list a map once, and a growth test counts that scan. And a test then an untest with
  no scan between left a timer the test resumed with its `last` moved, unreported, so a
  later plain swap caught it up from the test's switch; the untest now gives the `last`
  back, as fix F1 gives back `.pre`, and reports it as `:resume_undone`, a new report
  kind. One was a report's meaning: `:initial_changed`, "the running value is kept", was
  also given for a tag a start rule had just started, and for a var_input of the program
  started, whose new initial value a restart never applies; neither is reported now.
  Four were rules no test failed without: a restart after a switch, with no scan since,
  leaves the record of held outputs standing; the pending-block filter of fix F2, now
  bounded by a growth test of a second edit taken before any scan; `:unread`'s value, read
  after the start rules; and accept's check that a program's tags are a map and its rungs
  a list. One was the walk: its round trip took its exemptions from the reports under
  test, so an edit that reset an input whose section changed passed it; it now finds what
  a switch starts from the programs' text and the state, and checks decision 25. The rest
  were documents: fix F4's wording against an output the next program still shows (§7
  gains an as-built note, and the walk now checks such an output against its next scan);
  "the program the state is running", now defined once, which had shut fix F2's case out
  of the contract and let in an accept against the original after an assemble; labels
  (lettered hazards, numbered refuter findings) that only the design notes defined, now
  replaced by decision and fix names, with a test that refuses them; a stale test comment;
  and the rule count above. Step (7)'s message ends with a paragraph after its mutation
  table, against the house shape; history is not rewritten, and the fix commit says so.

  A review of that fix commit, `d05d4a2`, confirmed 14 findings, fixed in the commit
  after it; the suite stays at 430 tests. None was in `lib/`'s behaviour. The walk's
  generator never reached decision 29's two exceptions, nor a restart between a switch
  that resumed a timer and the switch back, so the walk's restatements of them decided
  nothing; it now reaches both and asserts it. The two new growth tests had bounds set
  from a few runs, and over 48 the one-shot test came within 3% of its bound; both bounds
  are now 24. The labels test missed a hazard in the plural or in brackets, and now also
  checks each fix and decision number cited against §7. The rest were documents: decision
  29's exceptions in `Program.initial_env/1`'s doc, §4.9 and §7; `:held` for an output the
  next program shows, the state's value, which can differ from the point's; the undo of a
  `.pre` or a resume, which holds only within one edit; the map a scan is given; and the
  row count above. History is not rewritten, so three earlier messages stay wrong:
  `3e45ea8`'s "Contract:" paragraph, which `d05d4a2`'s item 5 supersedes (after a test
  and an assemble at one boundary an edit is accepted against the candidate, not the
  original); `1e3efc1`'s "29 (E9) {:initial_changed, ...} at every switch"; and
  `d05d4a2`'s ranges for those growth tests, 16.4x to 16.5x and 16.3x to 16.8x, which 48
  runs put at 16.4x to 17.9x and 16.2x to 17.5x, and the check of those fixes, 63 more
  runs of the second, at up to 17.8x.
- **OE-2 · A staged edit of a configuration, after Milestone 2.** The same cycle over the
  whole `%Logex.Configuration{}` and `%Logex.Runtime{}`, switched between two cycles, with
  each M2 item's rule for new state; a task's interval and priority changed while running;
  moving an instance to another task, adding or removing a task, located I/O, devices and
  a function block's members refused (adding or removing a task until its rule is
  verified, a function block's members until M2-5); output points
  left undriven held and reported. *Done when* §4.4's plant, from text and from files on
  disk, running with both motors sealed in and `t1` timing, takes a candidate that raises
  `t1`'s preset and adds an `ons` in `motor.ld`, adds a member to `seal.ld`, shortens
  `slow`'s interval from 50 to 20 ms, removes `snap`, and adds an unlocated global `alarm`
  with an initial value, which the motor reads through `var_external`: test switches the
  resource between two cycles with no instance restarted, no one-shot pulsed and no event
  fired, `m1` and `m2` keeping their state by path with the decided `.pre`, `slow` next due
  within 20 ms, and its report names each instance's preset move and added member, the
  added global, `alarm` joined in each instance, the interval, `snap` stopped and
  `k1_at_trip` held; untest runs the original over the same resource, `snap` back from
  the state it was set aside with, its timers carrying on from where they stopped; assemble
  prunes `snap` and its report names it; a changed `single`, an added task, an instance
  moved to another task, a moved output point and a changed tag type are each refused at
  accept, at their line in `plant.logex` or `motor.ld`; and a step on an edit that has
  ended is refused by the generation counter. (`trip` then runs no instance, a warning,
  which stops nothing. The candidate's `ons` moves no output, so it drives no new point, as
  OE-1's Done-when keeps its own.)

  *Designed 2026-10-13* against `92431a9` (`docs/organisation.md` §4.9, "OE-2's design"),
  from a throwaway spike of the switch on §4.4's plant, and decided the same day, every
  question as recommended (decisions 55–65): the shared global wins when a `var` becomes a
  `var_external`, the instance's own value dropped and reported (55); a timer resumes from
  the resource's clock, an instance's `now` set to it at a switch (56); an instance back
  from aside carries on from where it stopped, its timers not caught up (57); a held output
  is named both as its point and as the instance's var_output (58); a second module,
  `Logex.Configuration.Edit`, beside `Logex.Edit` (59); the generation counter on the
  resource only, a stale edit of a lone instance the host's duty, documented (60); a
  retyped instance may run on another task (61); a reorder of tasks or instances allowed
  and reported as `:order` (62); a candidate `check/1` refuses is the host's mistake, raised
  as `start/1` raises it (63); cancel from accept moves the generation (64); and
  `restart/2` during an edit drops what is set aside and what only the other configuration
  declares, the next switch starting it again (65). It reserves no word, so it owes no
  survey and no `docs/naming.md` stanza. Its landing order, each commit gated alone by
  `mix format --check-formatted`, `mix compile --force --warnings-as-errors` in both
  environments and `mix test --warnings-as-errors`, judged by exit code on Elixir 1.20.4,
  and each rule it adds reverted alone and red:
  1. the design record: `docs/organisation.md` §4.9's "OE-2's design" and §7's decisions
     55–65, each "until OE-2" annotated where it stands, and this Done-when;
  2. before the code that depends on it, a spike in the contract walk of OE-1's record of
     each instance across instances on slow tasks, which skip cycles, and what it finds:
     *(done 2026-10-13: fix F11's undo must read the instance's own clock, before decision
     56 moves it to the resource's; and a timer frozen by a switch loses the time since its
     instance's last scan when a later switch resumes it, which decision 56 accepted, a
     known limit; `docs/organisation.md` §4.9, "OE-2's design")*
  3. the per-instance half of `Logex.Edit` moved to an internal `Logex.Edit.Plan`, with no
     change in behaviour, shown as M2-4 showed it for `Logex.Walk`;
  4. the resource's new state, `generation` and `aside`, with their rules in
     `Logex.Runtime`'s one-rule section;
  5. `Logex.Configuration.Edit`'s accept and its refusals;
  6. test, untest, assemble and cancel;
  7. held outputs;
  8. shared globals across a switch;
  9. the report kinds;
  10. the contract walk in `api_contract_test.exs`, with an oracle that knows nothing of
      the implementation;
  11. the Done-when in `end_to_end_test.exs`, from text and from files on disk;
  12. the documents: README's "Changing a running program" with a real run, CLAUDE.md's
      Key Files, `Logex.Runtime`'s one-rule section, `docs/organisation.md` and this
      status.

  **Status: DONE — landed 2026-10-13**, as the twelve commits of its landing order: (1)
  the design record, `626bbae`; (2) the spike's record, `2ec04d9`; (3)
  `Logex.Edit.Plan`, `d237f15`; (4) the resource's `generation` and `aside`, `7812d4e`; (5)
  accept and its refusals, `abd2f39`; (6) the steps, `c00f3f2`; (7) held outputs,
  `08a339c`; (8) a shared global's section change, `ac95a73`; (9) the report kinds,
  `2a15d9b`; (10) the contract walk and the growth tests, `e739834`; (11) the Done-when,
  `9c2e732`; (12) the documents, the commit after it, among them README's "A running
  plant", whose output is a real run. 931 tests pass on Elixir 1.20.4 (8 of them
  doctests), up from 864: 923 at the landing, and eight more with the review's fixes below. The messages of (3) to (9) record their mutation tables, every
  rule each adds reverted alone and the full suite judged by its exit code: 107 rules, 8,
  6, 43, 28, 8, 7 and 7, every one red, (6)'s row 6.11 once a test was added for it, the
  one survivor; and two rules found dead, an element with no line sorted last in (5) and
  a connection's member checked to be a var_output in (7), were removed and say why. (10)
  and (11) add no rule: rows of the earlier commits applied alone turn the walk red on 25
  of 25, and the Done-when on 12 of 13, the thirteenth decision 56's clock, which its plant
  does not reach. (1), (2) and (12) are documents.

  The spike of (2) found one defect in the design as written, decided by the record: fix
  F11's undo must read the instance's own `now`, before decision 56 moves it to the
  resource's; and one cost decision 56 accepted, a timer frozen by a switch not counting
  the time since its instance's last scan, a known limit. The walk of (10) found no
  defect in `lib/`; it found that a test then an untest with no cycle between changes
  three things decided rules change (decisions 55, 57 and 56's limit), which it allows by
  name, in every instance's env (the review below found the rest of the resource
  unchecked). Readings and departures, each in its commit: the split drops a var_external
  the started program does not declare at all, rather than keep a copy of a global unused,
  against decision 45's words, which decision 49 forbids (6); `:joined` and `:left` are
  writes, not the facts the design's table called them (8); a held global is one the
  configuration started declares (7); a reorder of the tasks is reported under `:tasks`
  (9); a step checks the generation before the configuration the resource runs (5); an
  instance back from aside keeps its `first`, `switched` and block list (6); the design's
  steps 5 to 7, kept and added instances and the globals, were split by what each commit's
  tests could see, the forecast needing the switch at (5) and the resource after a step at
  (6), with merge and split in (5) and (6) and their reports in (8); and the growth tests
  landed with the walk. Measured at the landing: accept and its steps take 3.90x to 3.95x
  the reductions for 4x the instances of one type, 4.00x to 4.03x for 4x the types and
  4.01x to 4.05x for 4x a program's size, over 32 runs; the walk takes about 9 s alone,
  and the full suite 23.4 s, up from 18.0 s.

  *The review of the landing* (2026-10-14, against `eff585d`) found one defect, fixed in
  the commits after the landing, each with a test that fails when the fix alone is
  reverted: an edit accepted while another was open, superseding it, brought back an
  instance the old edit had set aside, unmigrated under a newer version of its program,
  and kept a global the old edit had kept unused at its value, under another type. At an
  edit's first test both are now dropped before the switch and reported, `:instance_pruned`
  and `:pruned`, so the candidate starts what it names again afresh (decision 66, taken
  with the fix); the contract walk now accepts while an edit is open, superseding it,
  against a fresh start of the candidate. It also found rules no test pinned, each now
  pinned: a timer inside a block an instance holds, resumed by its path when the
  instance comes back from aside; no resume of an instance back at the time it was set
  aside; accept's refusals in line order from a text that puts globals before tasks; and
  the order of the elements only the running configuration has, its tasks and then its
  located globals, which a comment had given as their order there.
  And it found the round trip's claim, here and in §4.9, wider than the walk's check,
  which compared each instance's env, the names set aside and the original's globals
  alone: the walk now compares every state, each set aside, the globals and the tasks,
  allowing by name what a switch's own rules set, an instance's `now` (decision 56), a
  kept one's `switched`, one brought back from aside (decision 57) and a changed
  interval's next due time (decision 40), and both claims say so.

  *From Milestone 2's design (2026-10-02; `docs/organisation.md` §4.9, "One rule for new
  state", and §4.10).* M2-5 brings the edit of a function block's members, by path
  (decision 31), so OE-2 refuses them no longer *(landed with M2-5, 2026-10-04, for the
  edit of one program instance)*; a block type changed for the whole
  configuration changes each program type that holds it, by that type's own plan. A
  changed interval makes the task next due at `min(next_due, now + new interval)`
  (decision 40). An event task's trigger keeps its last sample across a switch, and a
  changed `single`, or an event task's `interval` added or removed, is refused. OE-2 adds
  the generation counter that detects an edit outside the contract; Milestone 2 does not
  reserve it. Until OE-2 lands, a configured plant is not edited. **OE-2 decides** three
  questions Milestone 2 leaves it, none of which an M2 commit depends on. *(All three
  were decided on 2026-10-04 as recommended, `docs/organisation.md` decisions 43, 44 and
  45; how OE-2 reports the write into a shared global when a `var` becomes a
  `var_external` stays OE-2's.)* *(That one was decided on 2026-10-13 by decision 55, with
  OE-2's design: no switch writes the global.)*
  - an instance whose type an edit changes: recommended as a remove plus an add, the old
    instance pruned and the new one started by `Runtime.instance/1`, over a refusal,
    since instances may be added and removed while running and state is keyed by name;
  - a kept global whose initial value changed: recommended reported, as decision 29
    reports a tag's, one rule for two kinds of state; since that extends decision 29, it
    is the maintainer's call;
  - how a switch sees an instance's `var_external`s: recommended, the configuration's
    switch merges each global into the instance's state by the running program's
    externals before `Logex.Edit`'s per-instance switch, and splits it off by the
    candidate's after, so the value kept is the one decision 25 keeps. How OE-2 reports
    the write into a shared global when a `var` becomes a `var_external` is OE-2's to
    design.

### Milestone 3 — the missing instruction set

**Designed and decided 2026-10-14** (`docs/organisation.md` §7, decisions 67–92;
"decision N" in this section is that §7's). §8's domain gaps, in its order: counters, the
other three timers, integer arithmetic, the coil one-shots `osr` and `osf`, and control
flow. A design pass on `970dede` surveyed each item and built a throwaway spike of an up
counter through `Logex.FbType`, the walks and the edit (never landed). The spike counted
with no new mechanism and found six places that assume every built-in is a `ton`:
`Logex.Edit.Plan` raised `FunctionClauseError` on a counter's preset change, reading a
timer's `.en`; the path rule's message in `Logex.Compiler` names `ton`; the unrun warning
says "is a ton"; `Logex.Walk.timers/1` feeds both the edit's preset rule and M2-6's
event-task warning, so widened alone it would warn about counters; a counter an edit adds
while its rung is true counted at once; and a counter in a frozen block misses an edge
that comes and goes while it is frozen. The maintainer took the questions as recommended
but three: IEC's three counter kinds (decision 67), IEC's member names (68), and a zero
divisor reported to the host as a minor fault (78). 67 and 68 sent M3-1 back to IEC's
counter model, whose routine choices are decisions 84–89. After M3-1's review the
maintainer answered three more questions the same day: an `rto` is cleared by an `r`
input member, with no `res` (decision 90); a counter's reset or load acts when its own
rung runs, as IEC's rule has it (91, confirmed as built); and `cv` stays read-only to
logic (92, confirmed).

Each item surveys its words in `docs/naming.md` first, before any code, and lands as a
gated series, each commit gated alone by `mix format --check-formatted`, `mix compile
--force --warnings-as-errors` in both environments and `mix test --warnings-as-errors`,
judged by exit code on Elixir 1.20.4, with its mutation table in its message, every rule
it adds reverted alone and the suite judged by exit code, every survivor given a test.
Each new mnemonic is reserved in any case, and each commit that adds one says which tag
names it breaks. Growth tests are in reductions.

**The order:** this design record, then M3-1 to M3-5.
- **M3-1 first**, decisive by §8, and the item that makes every built-in stop being a
  `ton`, with a type that keeps no time, so "has a preset" and "times" part from the
  start.
- **M3-2 next**, reusing that refactor.
- **M3-3 third.** It is independent, but brings negative literals, which change the
  golden record.
- **M3-4 fourth**, reusing the edge rules M3-1 generalises.
- **M3-5 last**, where dropping it would cost nothing else.

- **M3-1 · Counters: `ctu`, `ctd`, and the type words `ctu`, `ctd` and `ctud`.** IEC's
  three counters (decision 67), with IEC's members lowercased (decision 68): `var boxes
  ctu`, `var hopper ctd`, `var stock ctud`, each a `var` with no initial value. Rung power
  into `ctu boxes 12` is its count input `cu`, into `ctd hopper 40` its `cd`; the number is
  the preset, the `pv` an instance starts with. The reset `r`, the load `ld` and `pv` are
  input members, written by any instruction (`xic reset_pb ote boxes.r`) and read when
  the counter's instruction next runs (decision 84); a `ctud` is run by one `ctu` and one
  `ctd`, from two rungs, their presets agreeing (decision 85). Logic writes only `r`, `ld`
  and `pv` (decision 86). A count needs a rising edge, never on the first scan (decision
  69); a reset or load keeps the edge memory (70); the count stops at the dint's limits,
  setting `ov` or `un` until a reset or load (71); nothing may follow a counter on its path
  (73); a counter under an event task is a configuration warning (72); across an online
  edit each counter's edge memory joins decision 21's block list by path, a rung compared
  without its presets (87), and a moved `pv` forecasts `q` as `:dn_drops` and `:dn_rises`
  (88); and a frozen block holds its counters (89). *Done when* a box counter in a `.ld`
  file, a `ctu` on a photo-eye whose `q` lights a "case full" lamp at its preset and whose
  `r` a button drives, counts every rising edge exactly once over seeded scans, none on the
  first scan and none for a box on the eye at a reset; a `ctud` buffer count, `ctu` on the
  infeed eye and `ctd` on the outfeed, and a `ctd` hopper loaded through `ld`, agree with
  an oracle that knows nothing of logex; a count driven to the dint's top stops there with
  `ov` on until a reset; and an online edit that raises the preset while boxes are
  counted keeps the count, moves `pv`, forecasts `q`, and counts no box at the switch that
  was not a real edge. Its landing order:
  1. the survey: the stanzas `ctu`, `ctd` and `ctud`, and the Counters table's logex
     column, IEC's model and names;
  2. the refactor that stops treating every built-in as a `ton`, with no change in
     behaviour, shown as M2-4 showed it for `Logex.Walk`: each built-in type described as
     data, its instructions, preset member, done member and edge memories; the compiler's
     preset, run and path rules over those instructions, each message in its instruction's
     words; `Logex.Walk.presets/1` beside `Logex.Walk.timers/1`, the edit reading the
     first, M2-6's warning the second; the unrun warning in its type's words; and the
     edit's plan reading each type's preset member and forecast;
  3. the counter types, their instructions and rules, the compiler's refusals and
     warnings, the event-task warning, and the edit's rules for a counter;
  4. the contract walk's generators gaining counters, with an oracle that knows nothing
     of the implementation;
  5. the Done-when in `end_to_end_test.exs`, from text and from files on disk;
  6. the documents: README's instruction table and an example with a real run, CLAUDE.md's
     Key Files, `docs/organisation.md` §4.9's rules for the new state, and this status.

  **Status: DONE — landed 2026-10-14**, as the six commits of its landing order, after the
  design record: (0) the design record, `89dba29`; (1) the survey, `4571826`;
  (2) the refactor that stops treating every built-in as a `ton`, `2edd634`; (3) the
  counters, `eb7ba9c`; (4) the contract walk, `e1fb841`; (5) the Done-when, `84be063`; (6)
  the documents, the commit after it, among them README's "A counter" and the counter in
  "Changing a running program", whose output is a real run. 974 tests pass on Elixir
  1.20.4 (8 of them doctests), up from 932. (2) changes no behaviour: the suite is
  unchanged, and a differential probe of 3,000 seeded programs and 600 seeded edits gives
  identical hashes in its tree and its parent's. (3)'s message records its mutation
  table, every rule it adds reverted alone and the full suite judged by its exit code: 54
  rules, 52 red at once and two survivors, each given a test and red with it. (4) and (5)
  add no rule: (3)'s rows that touch a scan or the edit turn the walk alone red on 28 of
  34, and the Done-when alone on 26, each of the rest red in the full suite and named in
  its commit.

  Readings and departures, each in its commit and its decision: IEC's model sent the
  design back (decisions 67 and 68), so there is no `res`, a counter's reset and load being
  its `r` and `ld` inputs, written by any rung and read at its next run (decision 84); a
  `ctud` is run by a `ctu` and a `ctd` (85); `cv` is read-only, where decision 9 lets logic
  write a timer's `.acc` (86); the conventional RES clears `.CU`, and logex keeps the edge
  memory (70); the conventional CTUD rolls over, and logex stops (71). Two rules the design
  did not name came with the counters: an `ons` on a counter's `r` or `ld`, the first bool
  members logic may write, is refused, since the edit's block list names a storage bit as
  a tag; and a second `ote` is told by its target's path, a ctud's `r` and `ld` being two
  bits. The unknown-type message for a type given from Elixir now names
  `Logex.FbType.builtins/0`, not `Logex.FbType.ton()`. The walk found no defect in `lib/`.

  M3-1's review found no defect in the counters, against IEC and the decisions, and its
  fixes are the commits after (6). Step 3 had changed one rule of OE-1's without saying
  so: a rung is compared without the preset of any `ton` on it too, so an edit that moves
  only a `ton`'s preset no longer blocks an `ons` on its rung. The change loses fewer real
  edges and makes none up, so it was kept, owned by decision 87 and pinned in
  `edit_test.exs`. No test pinned a `ctud`'s forecast, on its `qu`, and one does now. A
  counter's forecast was said to be certain, and holds only unless the run it forecasts
  counts, resets or loads, as decision 88 now says, pinned both ways. Decision 67's words
  had a new `ctd` start from its preset, loaded, where IEC's CTD and M3-1 start it empty,
  `cv` 0 and `q` on until `ld` loads it; the maintainer confirmed IEC's on 2026-10-14, and
  decision 67 and README now say so, as `docs/naming.md` did. The one-rule lists now name
  a counter's blocked edge memory, and README's `ctu` row no `ld`. The maintainer's
  answers to three questions asked after the review are decisions 90–92: an `rto`'s clear
  for M3-2, and two confirmations of what M3-1 built, a reset or load acting at the
  counter's own run and `cv` read-only. The suite is at 977 tests (8 doctests).
- **M3-2 · The other timers: `tof`, `tp`, `rto`.** Each an instruction and a type word, as
  `ton` is, with the `ton`'s members `.pre .acc .dn .tt .en` (decision 68 keeps them for
  timers), in milliseconds. `tp`'s pulse is `.tt`, `.dn` coming on as it ends (decision
  74), and it fires on a rising edge, never on the first scan (75), its edge memory on the
  block list as a counter's is (87); an `rto` keeps `.acc` across a false rung and starts
  again at every restart until `retain` lands (76); nothing may follow any of them (73);
  M2-6's event-task warning is widened to every timer, in its own words; and across an
  edit each has its `.dn` forecast and resume trigger by type. An `rto` is cleared by its
  reset input member, `xic greased ote lube.r`, written like a counter's reset, and there
  is no `res` instruction (decision 90, decided 2026-10-14 after M3-1's review, where this
  was open); what else `.r` clears, and its rule across an edit, are M3-2's design. *Done
  when* a fan's `tof` runs it on for its preset after the motor stops, two instances on 10
  ms and 50 ms tasks stopping the fan at the same logical time, as decision 6 measured
  `ton`; a `tp` sounds a horn for exactly its preset from a fault's rising edge, whatever
  the fault does meanwhile, and not for a fault present at start; an `rto` lubrication
  timer keeps its time across the motor stopping and loses it only to its clear and a
  restart; and the event-task warning names each.

  **Status: DONE — landed 2026-10-14**, as eight commits, M3-1's landing order with step 3
  one commit per timer: (1) the survey, the stanzas `tof`, `tp` and `rto`, `e34712f`; (2)
  the refactor that stops reading every timer as a `ton`, `64fe3d4`; (3) `tof`, `39e0261`,
  `tp`, `795150e`, and `rto`, `6740d16`; (4) the contract walk, `a3e0c33`; (5) the
  Done-when, `035ddae`; (6) the documents, the commit after it, among them README's "Three
  more timers", whose output is a real run. 1032 tests pass on Elixir 1.20.4 (8 of them
  doctests), up from 977. (2) changes no behaviour: the suite is unchanged, and a
  differential probe of 4,000 seeded programs and 600 seeded edits gives identical hashes in
  its tree and its parent's. Each of (3)'s messages records its mutation table, every rule
  it adds reverted alone and the full suite judged by its exit code: 89 rules, 82 red at
  once and seven survivors, each given a test and red with it. (4) and (5) add no rule:
  (3)'s 82 rows that touch a scan or the edit turn the walk alone red on 66, and the
  Done-when alone on 31, each of the rest red in the full suite and named in its commit.

  Readings and choices, each in its commit and its decision: a `tof`'s `.dn` is IEC's Q
  and the conventional TOF's `.DN`, on through its delay (decision 93), where decision 74's
  words, "done never means still running on any timer", would read otherwise for a `tof`,
  as the maintainer confirmed after the review, knowing "done" is then on while the run-on
  still counts;
  a `tp` is IEC's TP, its edge memory `.en` on decision 21's block list by path (decision
  94); an `rto`'s `r` clears `.acc`, `.dn` and `.tt`, keeping `.pre`, and `.en` stays
  the rung's, where the conventional RES clears `.EN` too, and is a member kept across an
  edit (decision 95), so a reset held at a switch under a candidate that writes `r` no
  more stays held until a restart, which since decision 96 the switch reports
  `:unwritten`. A `tof` blocks nothing: an edit that turns its rung false starts its delay. A
  new `tof` starts at rest with `.acc` 0, where the conventional prescan sets `.acc` to
  `.pre`. The forecasts reuse `:dn_drops` and `:dn_rises`, a `tp`'s `:dn_rises` its pulse
  ending, as decision 88 reused them for a counter. The walk found no defect in `lib/`.

  M3-2's review found one defect in `lib/`, and its fixes are the commits after (6). A
  `tof`'s `.pre` moved to 0 while its rung is true changed `.dn` with no forecast: its
  delay then ends on the falling edge's own scan, where the original's runs on. The edit
  now forecasts `:dn_drops`, `{0, 0}`, at its next run with its rung false, as decision 93
  now says, pinned in `edit_test.exs` and the contract walk. No test brought a `tof` or a
  `tp` back from aside, where each resumes by `.tt`, not `.en`, and the reviewer's mutant
  reading `.en` for every timer survived: `config_edit_test.exs` now sets aside a `tof` in
  its delay and a `tp` in its pulse, their rungs false, and the configuration-edit walk
  draws `t1` as any of the four timers. An unknown type's two messages named only `ton`
  among the built-in types, from a declaration line and from Elixir: each now lists every
  type word, `Logex.FbType.builtins/0`'s among them, and suggests the nearest, `tpp` told
  of `tp` and `:tof` of `Logex.FbType.tof()`. The messages called an `rto` "a rto": a
  type word's article is now by how it is said, from a table of logex's own type words, so
  "an rto", and a user block's name still takes none of its own. The rest were the
  record's words. §4.9's M3-2 table read a `tp` back from aside as blocked, which it is not,
  as a counter is not: an input that rose while it was aside is a real edge. The one-rule
  lists now name a `tp`'s blocked `.en`. Decisions 93 and 94 claimed MatIEC's bodies step
  for step, and at a preset of 0 MatIEC holds Q one call longer than logex, as each now
  notes. Decision 95 and `docs/naming.md`'s `rto` said `r` clears what the conventional
  RES clears, which clears `.EN` too: logex keeps `.en`, a departure each now owns. §8 maps
  `.dn` to Q but for a `tp`. Asked after the review, the maintainer confirmed decision 93,
  a `tof`'s `.dn` IEC's Q through the run-on, the one exception to decision 74's words.
  Asked too what an edit does to a block's input it leaves no rung writing while it is on, a
  reset held when its rung goes, the maintainer chose decision 96: it keeps its value, as an
  output an edit stops driving does, and each switch reports it by its path, `{:unwritten,
  "lube.r", 1}`, a new kind in `Logex.Edit`'s table and §4.9's, read from the new
  `Logex.Walk.member_writes/1`, for a counter's `r`, `ld` and `pv`, an `rto`'s `r` and a
  timer's `.pre`, in a configuration by each kept instance's path. The suite is at 1044
  tests (8 doctests).
- **M3-3 · Integer arithmetic: `add sub mul div mod neg abs`.** IEC's names, and `neg`
  the vendors' (decision 79); `sqrt` waits for a real type. A result outside a dint is
  brought to the nearer limit and the instruction passes no power on that scan (decision
  77); a zero divisor gives 0 and no power, and the cycle reports it to the host as an
  event, a minor fault naming the instance, the file and the line, the plant running on
  (78), the event's shape M3-3's to design; a literal zero divisor is refused. Negative
  literals land first, a lexer rule with `Logex.Parser.well_formed!/1` and
  `Logex.Declarations.check/1` widened and the golden record regenerated where `-`
  appears, its diff read. *Done when* a fill valve's total, `add total flow total` on
  every scan of a 100 ms task, agrees with an Elixir oracle over seeded flows and closes
  the valve at a setpoint read with `ge`; a total driven past 2147483647, a `div` by a tag
  that is 0, which the cycle reports as its event, and a `mod` of a negative operand each
  give what their stanzas say; and no value outside a dint ever reaches a state.

  **Status: DONE — landed 2026-10-14**, as nine commits, M3-1's landing order with the
  negative literals first, as this item says, and step 3 one commit per family: (1) the
  survey, the stanzas `add`, `sub`, `mul`, `div`, `mod`, `neg` and `abs`, `68e638b`; (2)
  negative literals, with the front end, the printer's generator and the golden record,
  `7445d57`; (3) `add sub mul`, `c9d383e`, `div mod`, `941861a`, and `neg abs`,
  `9220d63`; (4) the divide-by-zero report, `747b27b`; (5) the contract walk, `7837ea0`;
  (6) the Done-when, `1858bc3`; (7) the documents, the commit after it, among them README's
  "Arithmetic", whose output is a real run. 1115 tests pass on Elixir 1.20.4 (8 of them
  doctests), up from 1044. Each of (2), (3) and (4)'s messages records its mutation
  table, every rule it adds reverted alone and the full suite judged by its exit code:
  97 rules, 93 red at once and four survivors, each given a test and red with it (a
  divisor a hand-built env holds as no integer, a bool divisor and `mod`'s destination
  refused, and a block's record of its faults left in its instance's map). A row whose
  first failure was a load-sensitive growth bound or a timeout was run again and judged
  by what failed then. (5) and (6) add no rule: (3) and (4)'s 58 rows that touch a scan
  turn the walk alone red on 48 and the Done-when alone on 22, each of the rest red in the
  full suite and named in its commit. The golden record gained 24 entries, each a new
  source with a `-`, and changed none.

  Readings and choices, each in its commit and its decision: a negative literal is its
  sign glued to its digits, one token, and a sign begins a lexeme, so `a-5` and `5-3` are
  each one mistyped lexeme, named whole, as B2's `1bst` is, never a silent split; it goes
  wherever a literal goes, a preset staying 0 or more, and a configuration file's numbers
  with it, where a negative interval or priority is now a diagnostic in the file's words,
  no longer the host's mistake (decision 97). The power out is IEC's ENO, settled, so
  anything may follow an arithmetic instruction on its path, where decision 73 refuses
  what follows a counter or a timer (decision 98). A result is computed exactly and then
  brought to the nearer limit, so a product far past it stops at the limit of its sign;
  `div` truncates toward zero and `mod` takes the dividend's sign, Elixir's `div/2` and
  `rem/2`, where CODESYS documents a non-negative remainder. A zero divisor gives 0 and no
  power for `mod` as for `div`, where MatIEC's MOD keeps ENO TRUE, as the maintainer
  confirmed after the review, and only a zero
  divisor is reported, an overflow not (decisions 77 and 78). The report is plain data,
  `%Logex.Fault{}`, in a new instance field, `faults`, its last scan's, which a scan
  replaces and `put_inputs/3`, `restart/3` and a switch keep, and a cycle's new event,
  `{:fault, task, instance, fault}`, after its scan's `{:ran, ...}`, a resource keeping no
  fault in its states (decision 99). Every source a literal draws a warning, as two
  compared literals do; a destination that is a source, and a divide by 1, draw none.
  Arithmetic keeps no state of its own: what it writes is a tag's, under every rule an
  edit keeps. The walk found no defect in `lib/`. A commit before the nine, `0a3832a`,
  sets `function_block_test.exs`'s bound on accept reading a block's body once a fifth
  above its figure again, 1.64: the figure had grown from 1.12x, which set the bound of
  1.35, to about 1.35x by decision 96, on the bound, and CI failed it from (4) on, where
  M3-3 moved it about 0.005x higher. M3-3 reads no body more than once: each rung costs
  accept about the same at 100 and 400 instances, and a body read again for each instance
  gives 3.20x.

  M3-3's review found no defect in `lib/`, and its fixes are the commits after (7). Eight
  of the arithmetic's operand slots were pinned by no test, each widened from a dint to
  any type with the suite green: `add`'s second source and destination, the first source
  of `sub`, `mul` and `div`, `mod`'s second source and destination, and `neg`'s
  destination, where `neg d b` wrote -5 to a bool. `validation_test.exs` puts a bool in
  every slot of every arithmetic instruction, each refused at its line. Two of decision
  98's warning rules were pinned by no test: a warning added for a divide by a literal 1,
  and none given for a `mul` of two literals, each left the suite green; the warnings
  test now holds `div d 1 d` and `mod d 1 d`, which draw none, and `mul 2 3 d`, which
  draws its warning. `state.faults`'s message was missing from `runtime_test.exs`'s table
  of every message the runtime raises, and its check could move after the owner's with
  the suite green: the table now holds it, and a state of another program whose faults
  are no list raises the faults' message, as the block list's does. CLAUDE.md still said
  four things M3-3 made untrue: that `Logex.Configuration.check/1` raises a negative
  number as the host's mistake, that `Logex.Declarations.check/1` and `Logex.Tag.new!/4`
  refuse a negative initial value, and that `well_formed!/1` takes a literal of 0 or more;
  each now says what is, and its Key Files give a fault's fields, the `faults` field's
  rule at every step and its check before the owner's, and a `-` that still does not lex.
  `docs/organisation.md` §4.9's "The data path" still read as before negative literals, a
  literal of 0 or more, a negative initial value refused from Elixir and an `ArgumentError`
  test of a negative preset that M3-3 removed; each is annotated as landed with M3-3, as
  are M2-1's landing note and decision 28. The golden record's header named the commit
  under (2) before the series was rebased, `c48bba5`, which is not in its history; it now
  names `68e638b`, and the record regenerated on top of `68e638b` with (2) is byte for
  byte the one committed. Asked after the review, the maintainer confirmed that a `mod` by
  zero behaves as a `div` by zero, 0, no power and a reported fault, noted on decision 98.

  `0a3832a`'s bound held the right figure the wrong way: comparing accept at 50 and 200
  rungs of a body at 100 instances weighs what accept does once a type against what it
  does for each instance, so the type's walks, 67 reductions a rung at `d5df77e` and 436
  after decision 96, moved it with no instance costing more, and another 2x of them would
  have failed 1.64 with no regression. The test now compares accept's cost per rung of the
  body at 100 and at 400 instances, (200 rungs less 50) over 150, which an instance's cost
  drops out of and a type's is the same in: 0.99x to 1.31x over 48 runs, 16 alone and 32
  four at once, bound 1.57; a body read again for each instance gives 3.87x, its
  instructions alone walked again 3.5x, and the type's body read eight times, which
  failed the old ratio at 1.77x, 1.02x to 1.13x. `logex_test.exs`'s "compiling stays
  linear in the program's size" reached 6.88x at main and 7.29x at the tip with four
  suites at once, over its bound of 6.8, and 6.84x in the 48 runs taken to re-measure it.
  What drives it is garbage collection, not the compile: with a heap so large that none
  runs, compiling 4x the tags takes 4.04x to 4.09x the reductions, at `d5df77e`, at main
  and at the tip alike; collection, 65 major ones at 2,000 tags to 13 at 500, each copying
  a heap that holds the program built so far, takes it to about 4.5x in a VM of its own;
  and a busy VM charges the same collections more, 5% more beside eight busy processes, so
  in the suite the count at 2,000 tags rises with the compile's time, 28.4M reductions at
  2.0 s to 44.3M at 10.8 s, while 500's stays at 6.2M to 6.7M. With nothing in logex to
  fix, the bound is now a fifth above the highest figure seen, the review's 7.29x: 8.75,
  which the warnings' old quadratic pass, 13.5x to 13.7x, still fails. The suite is at
  1115 tests (8 doctests).
- **M3-4 · The coil one-shots: `osr`, `osf`.** IEC's transition-sensing coils in the
  conventional form, a storage bit and a pulse bit (decision 80), which pass on the power
  they receive; each storage bit under every rule an `ons` bit has, on decision 21's block
  list, never firing on the first scan (69). *Done when* `osr` and `osf` give, on seeded
  inputs, the pulses `ons` and `xio … ons` give on their own rungs, pass on the power they
  receive, never fire on a first scan, and an edit that adds or changes one blocks it until
  a scan runs it, as decision 21 blocks an `ons`.

  **Status: DONE — landed 2026-10-14**, as M3-1's landing order with no refactor, a tidy
  of two load-sensitive tests from M3-3's review before it: (0) the tidy, `b4be654`; (1)
  the survey, the stanzas `osr` and `osf`, `2460ea0`; (2) the coils, `28470f9`; (3) the
  contract walk, `082632a`; (4) the Done-when, `138f51d`; (5) the documents, the commit
  after it, among them README's "Two pulse coils", whose output is a real run. 1159 tests
  pass on Elixir 1.20.4 (8 of them doctests), up from 1115. (2)'s message records its
  mutation table, every rule it adds reverted alone and the full suite judged by its exit
  code: 41 rules, 41 red at once, no survivor. (3) and (4) add no rule: (2)'s 22 rows that
  touch a scan or the edit turn the walk alone red on 20 and the Done-when alone on 20, the
  other two, a storage bit a hand-built env holds as anything but 0 or 1, red in the full
  suite. (0) measures "compiling stays linear in the program's size" in a process whose
  heap starts at 4M words, where 2,000 tags take one major collection and not 61: 4.07x
  to 4.36x over 32 runs, 16 alone and 16 four at once, so its bound is 5.24, down from
  8.75, which the quadratic mutant, 13.46x, still fails, and the large heap reverted alone
  fails it four at once; and gives the configuration-edit walk a timeout of 300 s, its
  draws kept, after it passed 60 s twice in M3-3's mutation runs.

  Readings and choices, each in its commit and in decisions 100–103: the coils are IEC's
  transition-sensing coils in the conventional set's form, `osr s1 pulse`, the storage bit
  first, each run writing the pulse bit and then the storage bit with the power it
  receives; the power out is that power, settled by IEC and the conventional set alike,
  so anything may follow a coil (decision 100), where nothing follows a counter or a timer;
  the pulse bit may be a member logic may write, never the storage bit, and a second coil
  on it is the second-`ote` warning (decision 101); `osf` sees its fall on its false rung's
  run, and a frozen block holds both bits, so a pulse given at its body's last run stays on
  until it next runs (decision 102); and a coil under an event task is not warned about, as
  an `ons` is not, the record's reading of decisions 72 and 80, left to the maintainer
  (decision 103), who chose a warning after the review (below). Every rule of an `ons`
  storage bit is a coil's: one one-shot of the three to a bit, never a member, any other
  write a warning, the configuration's writer warning naming its one-shot, and decision
  21's block list by name, the whole rung compared without presets, so a coil whose pulse
  bit alone changes is blocked too. The walk's first draft found a gap in its own oracle,
  a restart's fresh bits, and none in `lib/`.

  M3-4's review found no defect in `lib/`, and its fixes are the commits after (5). One
  rule of the block list was pinned for an `ons` and by no test for a coil: a storage bit
  the program that last scanned also writes another way is blocked, and a coil's taken for
  a counter's edge memory, which no logic writes, left the suite green, so that an untest
  gave a pulse no edge made. `edit_test.exs` now holds an `osr` and an `osf` whose storage
  bit the candidate also writes, each blocked at the untest. A coil in a block whose `cal`
  is first true after the instance's first scan reads its storage bit as declared at the
  block's first run, so an `osf` declared 1 pulses there on a false rung, a fall that never
  happened, and an `osr` held true since start pulses, where README and `docs/naming.md`
  said a button held at start steps nothing and called the declared value the one visible
  difference from the conventional prescan. The behaviour is kept, one rule with `ons` and
  the counters (decision 89): decision 102 now records it, README, the two stanzas and the
  runtime's comment on `cal` say so, and `pulse_coil_test.exs` pins the `osf`'s pulse and
  the `osr`'s. `logex_test.exs`'s "compiling stays linear in the program's size" has
  measured since (0) in a heap so large that its collections barely run, where a copy
  costs few reductions: a `Logex.Walk.instructions/1` that appends each rung with `++`,
  12x to 15x the time at 4x the tags, grew 5.27x to 6.42x there and passed its bound of
  5.24 in three of five runs of the suite. The test is now two, the large heap's at 5.24
  and the VM's own heap's, which grew 4.40x to 4.67x alone and 4.87x to 6.19x four at once
  over 32 runs, bound 7.43: the `++` walk grows 12.4x to 12.9x there, the warnings'
  quadratic pass 13.4x in either heap, a linear search for a one-shot's storage bit 7.2x
  in the large heap and 7.6x in the VM's, and a count of the rungs at every rung 6.4x in
  the large heap, each failing at least one. A `++` in `Logex.Warnings.of/2` alone, 4.3x
  and 5.8x to 6.0x, still passes both. Over the same 32 runs the large heap's figure
  reached 4.50x four at once, 16% under its bound of 5.24, so on landing the bound was
  set a fifth above it, 5.40, as CONTRIBUTING's growth practice asks. The readings
  above credited decisions 100–103 with a coil's rung compared whole, so that one whose
  pulse bit alone changes is blocked, which none of them recorded: decision 101 now does,
  with its cost, one real press, where the press rises on the first scan after the switch,
  and why it is kept though decision 87's reason for leaving presets out would leave the
  pulse bit out too: one rule with `ons`, whose rung is compared whole, what its pulse
  drives among it. README's coil under an edit says so. Asked after the review, the
  maintainer confirmed decision 102's frozen pulse: a pulse inside a block whose `cal` is
  false stays on until the block runs again, as everything in a frozen block holds, which
  M3-4 built; decision 102 and §7's opening record it, and `pulse_coil_test.exs`'s frozen
  block now reads the block's own pulse bits beside the program's tags, which the
  decision's alternative, a false `cal` clearing them, had changed with only the contract
  walk red. Asked too whether a one-shot under an event task should be warned of, as a
  counter is, the maintainer chose a warning for all three, `ons` with the coils,
  superseding decision 103's "no warning" and what decision 72 said of an `ons`: each
  one-shot a program instance runs under a task with a `single`, at any depth, is a
  warning on the configuration's `warnings` in its own words, after the instance's timers
  and counters, a block's by its storage bit's path, citing its instruction's own file and
  line, from a new fact, `Logex.Walk.one_shots/1`, read once a program type as the timers
  are, so that the e-stop's own coil, `xic estop osr s1 pressed`, is told it never pulses.
  `configuration_test.exs` pins it from text, from Elixir and from files on disk, and
  `walk_test.exs` the fact, whose two growth tests walk it too, their bounds again a fifth
  above the highest of 48 runs, 1.82 and 19.0. Two of the record's words were stale:
  `docs/instruction-sets.md` §2.2 still had Ed 3's numbering from a secondary source
  alone, where M3-4's survey read Table 76's features 8 and 9 in the standard, and it now
  says so, in §10 too; and CLAUDE.md said the compiler and `Logex.Edit` read
  `Logex.Walk.storage_bits/1`, where they read `one_shots/0` and only `Logex.Warnings` and
  the configuration's writer warnings read the bits. CLAUDE.md's Key Files now say which
  reads which, and bring the review's rules in: a block's later first run, the frozen
  pulse confirmed, a pulse bit edited alone, `one_shots/1` and the one-shot event-task
  warning. The suite is at 1167 tests (8 doctests).
- **M3-5 · Control flow: forward `jmp` and `lbl`, and no MCR.** A forward jump only, a
  label first on its rung, labels a routine's own namespace (decision 81); skipped rungs
  freeze as a false `cal` freezes a block, a timer in them catching up when next run (82);
  and no master control zone, ever (83). *Done when* a forward `jmp` over a manual-mode
  section freezes that section's outputs, counters and timers exactly as a false `cal`
  freezes a block; a backward jump, a missing label and a label not first on its rung are
  each a located diagnostic; and a program with no `jmp` scans within a measured bound of
  its cost before.

  **Status: DONE — landed 2026-10-15**, as M3-1's landing order with a refactor before
  the jump, as M3-1 and M3-2 had, and Milestone 3's done sentence walked before the
  documents: (1) the survey, the stanzas `jmp` and `lbl` and the master control zone's
  row, "not added, for good", `47b5d46`; (2) one rung loop for a program's rungs and a
  block's body, with no change in behaviour, `8dda93b`; (3) the jump, `dcadb6d`; (4) the
  contract walk, `5035307`; (5) the Done-when, `7a514e7`; (6) Milestone 3's done sentence
  in `logex_test.exs`, `825bb81`; (7) the documents, the commit after it, among them
  README's "A forward jump", whose output is a real run. 1223 tests pass on Elixir 1.20.4
  (8 of them doctests), up from 1167. (3)'s message records its mutation table, every
  rule it adds reverted alone and the full suite judged by its exit code: 59 rules, 58 red
  at once and one survivor, a `tp`'s mark on a skipped rung, whose rule was deleted, since
  one `tp` runs its instance and a skipped one leaves the instance out of the scan's
  record, which keeps all the instance holds. (2) adds no rule: a differential probe of
  3,000 seeded programs, 852 of them compiling, and 800 seeded edits gave identical hashes
  in its tree and its parent's. (4), (5) and (6) add no rule either: (3)'s 21 rows that
  touch a scan turn the walk alone red on 15, the Done-when alone on 8 and the done
  sentence alone on 6, the rest red in the full suite, by `jump_test.exs`'s programs built
  by hand and its growth tests. A scan of a program with no jump costs fewer reductions
  than before M3-5, the least of 50 scans: 308 against 319 for the README motor and 39,126
  against 41,126 for 1,000 rungs. The Done-when bounds the rung loop's cost per rung
  beside its instructions' at 1.207, the ratio a loop a fifth dearer than before would
  give: 1.179 at `16d47ed` and 1.141 at (5), over 32 runs each.

  Readings and choices, each in its commit and in decisions 104–107: the jump is taken
  once its rung is done, IEC's rule 3, and `jmp` passes on the power it receives, so
  anything may follow it, anywhere on its rung, one a rung (decision 104); a label is a
  name, never a tag nor an integer, of its routine's own namespace, a twin in another case
  refused and one no `jmp` names a warning (105); a memory an edit's switch blocks on a
  rung a jump skips stays listed until a scan runs its instruction, as decision 32 keeps
  one in a frozen block, and a rung is compared whole, its `lbl` and `jmp` among it (106);
  and the walks and the warnings read a rung a jump may skip as any rung, so two `ote`s on
  one tag in sections a jump makes exclusive are still the second-`ote` warning (107). The
  contract walk's first draft found a gap in its own oracle, a restart between a test and
  an untest leaving every memory fresh, and none in `lib/`. `jmp` and `lbl` are reserved
  in any case, so a program with a tag of either name no longer compiles.

  M3-5's review, on 2026-10-15, found a rule no test pinned, a host mistake the runtime
  ran on, a word a block's body took as a label, a suggestion of a jump back, and words
  gone stale, its own and older, and its fixes and the maintainer's two answers after it
  are the commits after (7). A skipped rung marks each listed memory wherever on it its
  instruction stands, a group's legs among the places, and a mark of its top-level series
  alone left the suite green. `jump_test.exs` now holds a one-shot on a group's second
  leg, one two groups deep, and a ctud's side on a leg while its other side runs, each
  kept listed through the skip and blocked at its first run; and the contract walk puts
  the one-shot, each side and the `cal` on a leg of a group now and then, first or second,
  whose other leg passes no power, its edits moving a memory into a group or out. The
  walk's draw of a program with no jump, `1..0`, which Elixir reads as two steps down,
  gave two jumps, so that no program was drawn without one, and gives none now. A host's
  env holding a key the runtime keeps a scan's records under changed the run: `%{jump:
  "nowhere"}` skipped every rung after the first, and `%{faults: [div: 3]}` gave a fault
  no divisor met, a tolerance `fault_test.exs` and `function_block_test.exs` had pinned
  for `:faults` and `:ran`. Every entry point that takes a state, `Logex.Edit`'s steps
  among them, now refuses one whose env holds `:faults`, `:jump` or `:ran`, all it holds
  named in one message `runtime_test.exs`'s table pins, checked with the env's shape,
  before the clock and the owner: no state that `instance/1`, a scan, `restart/3`, an
  edit's switch or a resource gives holds one, nor any key but a tag's name. A `cal` drops
  them from its instance's map before its body runs, since the values in a state are not
  checked each scan and an instance is one, read whatever it holds. The check is three
  lookups in a guard, so the README motor's scan still costs 308 reductions; a key no tag
  is but none of those is never read, and stays unchecked, since a check of every key
  would cost each scan a step a tag. A block's body took `lbl function_block` and `jmp
  function_block`, where the word that heads a block's file is reserved in one, in any
  case (`docs/organisation.md` §4.8), as README and decision 105 say: each is now an error
  at its line, `Function_Block` among the spellings, as the word is for a tag there, a
  program's file still taking it, and `Logex.Compiler.lowered?/1` holds a body to it. A
  `jmp` that names no label was told the nearest label of its routine, one on an earlier
  rung or its own among them, which followed gives "jumps back"; the nearest on a later
  rung alone is suggested now. Five passages still said every rung runs at the top level:
  `call/4`'s doc, two comments in `Logex.Edit.Plan`, on the bits a scan leaves pending and
  on a timer's `last`, and in `docs/organisation.md` §4.9's block-list paragraph and
  decision 21's note, each now saying what a skipped rung leaves, the two notes with a
  dated one of decision 106. Older words were stale too: `docs/organisation.md`'s Status
  said the configuration file, shared globals and event tasks were not yet implemented,
  and now says Milestones 1 to 3, OE-1 and OE-2 have landed; `docs/instruction-sets.md` §7
  had `cal` deferred, a `res` that decision 84 dropped, `ret`, `shl` and `shr` with no
  marking though none exists, the up/down counter as none and a counter's bounds unknown,
  and §8 called `res` planned; and `docs/naming.md`'s Program control table had `cal`
  deferred and `ret` unmarked, which are corrected in place, as each survey since M3-1 has
  corrected that table's logex cells, the stanzas being what the file keeps append-only,
  and its `shl` and `shr` are marked deferred with them, so that §7's column stays
  naming.md's. Asked after the review, the maintainer confirmed two of M3-5's choices,
  which decisions 106 and 107 and §7's opening record, dated: two coils on one tag in
  sections that jump over each other keep the second-`ote` warning, since the checks read
  the program's text, not which rungs run (decision 107); and an edit that only adds a
  `lbl` or a `jmp` to a one-shot's or a pulse coil's rung blocks it once, the rung
  compared whole, one rule with decision 101, at the cost of one possible press (decision
  106), which `edit_test.exs` now pins for an `osr` beside the `ons` it pinned, a press
  that rises on the first scan after the switch pulsing nothing and the next one pulsing.
  The suite is at 1231 tests (8 doctests).

**Milestone 3 is done when** a small bottling line written in `.ld` files runs under a
`.logex` configuration through `Logex.Runtime.cycle/3`, against an oracle that knows
nothing of logex: a conveyor whose `ctu` counts bottles into cases, reset through its `r`
when a case leaves; a buffer whose `ctud` counts bottles in and out; a fan run on by a
`tof` after the motor stops; a horn pulsed by a `tp` on a jam; a fill valve whose `add`ed
total closes it at a setpoint, a zero divisor in its rate reported as a minor fault while
the line runs on; an `osr` that steps a case counter; and a manual-mode section skipped by
`jmp`. While it runs it is edited through `Logex.Configuration.Edit` to change the case
size and the run-on time, with no count lost, no phantom count and no timer reset, and the
Done-when tests check each piece against its rule. *(Done 2026-10-15, with M3-5:
`test/logex_test.exs`, "Milestone 3's done sentence, as written in PLAN.md", walks it
clause by clause from files on disk through `Logex.Configuration.compile_file/1`: a
conveyor and a filler on a 10 ms and a 100 ms task, 1,200 seeded cycles against a model
of the line in plain Elixir, every cycle's outputs, events and bottle count exact, edited
after cycle 600 to a case of 24 and a run-on of 500 ms, the count kept, a bottle on the
eye across the switch counted once, and the run-on in progress at the switch ending 500
ms after the motor stopped. "The Done-when tests" are read as M3-1's to M3-5's in
`end_to_end_test.exs`, beside each item's own test file.)*

### Milestone 4 — the wall-clock runner

**Designed and decided 2026-10-17** (`docs/organisation.md` §4.11 and §7, decisions
108–121, and 122–128 after M4-1's review; "decision N" in this section is that §7's). §8's
second domain gap: a runner that runs a configuration's resource on the real clock,
through device adapters, with a watchdog, the one piece of logex that reads a clock. A
design pass on `d3931bd` designed it and built a throwaway spike of every piece, on the
branch `backup/runner-design` (`spike-runner/`), never landed. The maintainer changed
three of its answers: rounds run back to back while untimed programs exist, a share of the
time, 20% unless set, kept for the runner's own work, as IEC's rule 4 and the conventional
continuous task with its system overhead time slice (decision 108), not on a steady beat;
a watchdog is 500 ms unless set (109), not required; and each task has its own, on its
line (110), not one for the controller. Two the maintainer added, outside the questions
put: a configuration may declare its one continuous task, `task main continuous watchdog
200` (111); and a device may report its inputs' changes, an event task whose trigger
changed running at once between rounds, a device that cannot report read every poll
period, 10 ms unless set (112). The rest the maintainer took as recommended: a watchdog
trip zeroes every output once, stops, reports and waits for a restart, the last state
readable, confirming decision 14 (113); a failing device trips (114); a crashed runner
stays down (115); a normal stop zeroes every output first (116); and input forcing comes
now, kept across a restart and listed in the status (117). Decisions 118–121 are the
record's routine choices where the answers left one open: the cycle in steps, so that the
runner times each task's run (118); each device's heartbeat at the longest watchdog plus a
poll period, the runner refreshing every device at least once a poll period (119); every
device read every poll period, a reporting one passing its changes on between reads, and
each change of a trigger its own round (120); and the share and the poll period options of
the runner, not words of the configuration file (121). After M4-1's review, on 2026-10-18,
the record took three more where it had been silent: rounds back to back one a clock
millisecond at most, so that they are defined on a clock that does not move, and the share
served in the conventional table's slots, a share of the continuous task's time and the
runner's own, from 10% to 90% (122); a trigger logic writes rounding at the next
millisecond, which closes decision 50's livelock (123); and a device passing its changes
on by a call the runner answers once the round they cause has run, so that a test's
`Logex.IO.Sim.set/3` returns after that round by construction (124). Two more replace
looser rules: every device refreshed before every step, each refresh carrying that step's
own deadline, its watchdog plus a poll period, which supersedes decision 119's rule and
its cost (125); and a round's watchdog trip naming each of its steps with its time, so
that a slow timed task in the round is seen (126). And the maintainer answered once more
the same day, outside any question put: forces survive a crash, kept in a file, as the
conventional family does, so that a runner started after a crash comes back with every
input that was forced still forced and listed (127), with the record's choices on how.

Each item lands as a gated series, each commit gated alone by `mix format
--check-formatted`, `mix compile --force --warnings-as-errors` in both environments and
`mix test --warnings-as-errors`, judged by exit code on Elixir 1.20.4, with its mutation
table in its message, every rule it adds reverted alone in a copy of its commit and the
suite judged by its exit code, every survivor given a test. Throughout:
- **`Logex.Runtime` stays pure** and never reads a clock; nothing compiles to BEAM; a host
  mistake raises an `ArgumentError` whose message a test pins; and each new public module
  joins `runtime_test.exs`'s exact-surface pin.
- **Every rule is tested on the manual clock.** A test on the real clock asserts liveness
  only, short, with bounds far from what load can reach, since CI shares its cores and
  CONTRIBUTING.md forbids skipping or quarantining a test.
- **Growth is tested in reductions**: a round's work linear in the points and the tasks,
  `start_link/1`'s checks linear in the devices and points, but for a sort of the names,
  n log n, and a refusal's did-you-mean, quadratic in the names it is told against and the
  devices, which only a host's mistake pays, as §4.10 accepts for a configuration's.
- **A configuration file's new words** (M4-2) are surveyed first, and carried through the
  reader, the printer, the round trip, its totality and growth tests,
  `configuration_text_test.exs` and `naming_test.exs`.

**The order:** this design record, then M4-1 to M4-7. M4-1 first, since it needs nothing;
M4-2 next, the configuration's words the runner reads; M4-3 the runner on them; M4-4 its
watchdogs and faults; M4-5 its edits and forcing; M4-6 the contract walk over all of it;
and M4-7 the documents.

- **M4-1 · The clock, the I/O contract and the simulated device.**
  `Logex.Runner.Clock`, the behaviour a clock implements, `now_ms/1`, `wake_at/4` and
  `cancel/2`, with two clocks: `Logex.Runner.Clock.Monotonic`, `System.monotonic_time/1`
  in milliseconds and `Process.send_after/4` to an absolute time; and
  `Logex.Runner.Clock.Manual`, a process a test moves, its `advance/2` delivering each
  timer due on the way in time order, ties in the order they were set, and returning once
  each receiver has handled its message, by a call to the receiver from the process that
  sent it, and its `pass/2` moving time inside a step and delivering nothing.
  `Logex.IO`, the adapter behaviour, `init/3`, `read/1`, `write/2`, and the optional
  `report/2` and `close/1`, each failing by returning `{:error, reason, state}` rather than
  raising, with `%Logex.IO.Point{}`, a point's name, direction, address and type.
  `Logex.IO.Sim`, an in-memory device in a process of its own: its inputs set, its outputs
  and every write recorded, its reads counted, its changes reported to the device that
  opened it where it was started to, and one failure acted out on the call it names: an
  error, a raise, a throw, an exit, a hang, a delay on the manual clock, or a value of the
  test's choosing. And the grouping of a configuration's located points by device,
  `Logex.IO.points/1`, with `Logex.IO.bind!/2`, a host's bindings checked against it,
  every mistake at once, as `start_link/1` will check them. *Done when* the manual clock
  delivers timers in time order, ties in the order they were set, a timer set while one is
  handled within the same advance, and returns from `advance/2` only once each receiver
  has handled its message, by construction; the monotonic clock wakes a process no sooner
  than its time, live; `Logex.IO.Sim` reads, writes, records every write, reports each
  change to the device that opened it and acts out each failure; and §4.4's plant's
  points, from files on disk, group as `panel` with eight inputs and four outputs and
  `drive` with two outputs, each binding mistake raised with its pinned message. Its
  landing order:
  1. the clock;
  2. the behaviour and the simulated device;
  3. the grouping, with its host mistakes pinned;
  4. the documents: CLAUDE.md's Key Files and this status.

  **Status: DONE — landed 2026-10-17**, as the four commits of its landing order, after
  the design record: (1) the clock, `587ac41`; (2) the behaviour and the simulated device,
  `29c23c5`; (3) the grouping, `5d09f89`; (4) the documents, the commit after it. 1284 tests
  pass on Elixir 1.20.4 (8 of them doctests), up from 1231. Each of (1) to (3) records its
  mutation table, every rule it adds reverted alone in a worktree of its commit and the
  full suite judged by its exit code: (1) 31 rules, 30 red and one survivor, a timer set
  relative to now rather than absolute, kept on an argument M4-1's review found half
  right, corrected below; (2) 55, all red; (3) 28, all red. `Logex.Runtime` is
  unchanged.

  Found while landing, each in its commit: the VM refuses an absolute timer from before it
  started, so the monotonic clock brings a time already past to now, as the behaviour says
  a past time is sent at once; `{:ok, %{}, ^state} =` in an assertion matches any map,
  which let a mutant through, and the tests compare values whole; and a wait shorter than
  its default is caught by slow receivers only while the machine keeps up, so each default
  wait is pinned by a test that waits it out. Chosen while landing, beyond the design: the
  simulated device's `set/3` reports from the caller, not from the sim's own process, so
  that the sim never waits on a device that may be calling it, by construction rather
  than for a deadlock seen; the reporting callback is `report/2`, not `handle_info/2`, so
  that an adapter that is also a GenServer meets no clash; the manual clock's `wait:` and
  `pending/1`, the simulated device's `wait:` and `reads/1`; and `bind!/2`'s order of
  mistakes, a key that is no device's name first.

  M4-1's review, on 2026-10-17, found host mistakes taken or misread, rules no test
  pinned and words gone loose in its design record, and its fixes are the commits after
  (4). A `wait:` longer than the VM waits for an answer, 2^32 − 1 ms, was taken by the
  manual clock and the simulated device, and then escaped `advance/2` and `set/3` as an
  `ErlangError`; each refuses it at start now, in its words, and takes 4294967295. A
  receiver of the manual clock, or a device a sim reports to, that went down with the
  reason `:timeout` while it handled its message was told it had not answered, since its
  exit has a wait's shape, and the advance stopped there, its later timers undelivered;
  each is passed over now, as one down for any other reason is, and only one still alive
  that has not answered is the mistake. Eight of the review's mutants left the suite
  green, each a rule no test reached: an input never set taken as changed when set to 0,
  a delay acted out after its call rather than before, an adapter's module not loaded
  before its callbacks were looked for, `pending/1` in the reverse of delivery order, the
  clock's `wait:` and the sim's ignored for 5000 ms, and the clock and the sim started
  unlinked; a test now kills each, the waits by a receiver that answers after a second,
  well within 5000 ms, and the delay by a write found asleep with nothing written. (1)'s
  survivor was kept as firing when the absolute timer does, but for the microseconds
  between the read of now and the call. That holds for a relative timer that reads now
  once, `max(at - now, 0)`, which shows only drift, never more than the time from the
  read to the call: it survives still, since only a trace of the call, which sees
  `[abs: true]` given to `:erlang.send_after/4`, can tell it, and such a test would pin the
  implementation rather than a behaviour. The mutant (1) tabled read now twice, `max(at,
  now) - now`, which comes out a millisecond below 0 wherever the tick falls between the
  two reads, and the VM refuses it, so a wake raised: 9 of 200,000 at a past time in the
  review's probe. `clock_test.exs` now wakes a process at a past time for 200 ms of the
  clock and finds no raise, which that mutant fails in every run. (1)'s commit message
  stands as landed, and this is its correction. An adapter's own options could not be
  checked when the bindings were: `{Logex.IO.Sim, []}` and `{Logex.IO.Sim, sim: :x}` each
  bound, and were refused only inside `init/3`, in the device's process, where §4.11 makes
  a raise `{:io_init, ...}` or an I/O fault, a host's typo reported as the plant's state.
  `Logex.IO` has a sixth callback, `check/3`, optional, given what `init/3` will be, which
  `bind!/2` calls in the host's process for an adapter that implements the behaviour and
  has keyword options, each line it gives one of the one `ArgumentError`, and a check that
  gives no list of messages told so; `Logex.IO.Sim`'s holds its options to `sim:` alone, a
  sim that runs, and `init/3` raises the first of the same. One sim bound to two devices
  passed `bind!/2`, its reports reaching only the device that opened it last and both
  devices' outputs written over each other, a takeover `io_test.exs` had pinned; a sim
  is one device's now: another device's process may open it only once the first has
  closed it or gone down, the process that opened it may open it again, `check/3` refuses
  a sim another device holds open, and the sim refuses an open that came second, in one
  message naming the device that holds it. One `bind!/2` that binds one sim to two
  devices still passes, since neither has opened it, and the second device's `init/3`
  raises. `Logex.IO.points/1`'s doc said a configuration `Logex.Runtime.start/1` refuses
  raises in its words, but a value that is no configuration was refused in
  `Logex.Configuration.check/1`'s; `start/1` itself refuses it now, so `points/1` and
  `bind!/2` give its words, which `io_test.exs` pins for a value that is no struct, a map
  and a struct that lacks its keys. `bind!/2`'s refusal of many devices bound that no
  point is at took time quadratic in them and the devices, its did-you-mean's and a sort
  of the devices' names for each, 1,000 of each in 1.28 s and 2,000 in 5.6 s, though PLAN
  said linear and the doc said nothing; it sorts the names once a call now, its doc says
  what the did-you-mean costs, as `Logex.Configuration`'s does, and the plan's growth rule
  above is qualified. A growth test with names no did-you-mean is looked for pins the rest
  at n log n: 16x the devices and bindings take 16.8x the reductions, bound at 24, where
  the sort for each took 38.4x. The suite is at 1303 tests (8 doctests).

  The review also found the design record silent on four things the runner must do the
  same way on either clock, and its answers are decisions 122–124, taken on 2026-10-18
  with M4-3's Done-when and landing order above changed to match. Rounds back to back had
  no defined behaviour on the manual clock, where a round takes no time: a receiver that
  set its next wake for the time it was at took 49,989 deliveries in a second with the
  clock at 0, and rounds after one `advance/2` came out 19,772, 2,658 and 2,658 in three
  fresh runs. A back-to-back round is now a wake at the millisecond after the one the
  round before began in, or at once where it took a millisecond or more, so at most one
  round runs a clock millisecond, on either clock, and `advance(clock, n)` runs n; the
  share is served in slots by the conventional formula, from 10% to 90%, a share of the
  continuous task's time and the runner's own with the timed tasks' runs left out, as the
  conventional rule quoted leaves out periodic and event tasks; and "between rounds" reads
  "at the start of the next round, never preempting one", where the record had also said
  a round runs its due timed tasks first (122). Two event tasks that write each other's
  trigger rounded at once for ever in zero time under decision 120, the livelock decision
  50 left to the runner; a change logic writes now makes its round at the next
  millisecond (123). And a round a report causes gave a test nothing to wait on: in a
  model, 200 sets each followed by a read of the outputs found 33 rounds run; a device now
  passes each change on by a call the runner answers once the change is merged or the
  round it makes has run and been written, so `Logex.IO.Sim.set/3` returns after that
  round by construction, and a real run takes each device's changes one at a time, in
  order (124). Decision 119's heartbeat refreshed a device only when a refresh was due and
  only between steps, so in a model a step that took exactly its watchdog, 9 ms after the
  last refresh, left 1 ms before the device latched, and a runner stuck in the conveyor's
  task held its contactor for the fan's 2 s; every device is now refreshed before every
  step, each refresh carrying that step's own deadline, so a stuck conveyor's step zeroes
  every device at its 50 ms and a poll period, the poll period the margin, and the record
  says why a heartbeat for each device fails with no preemption (125, superseding 119's
  rule and cost, with M4-4's Done-when). Decision 118 passed over timing the whole cycle
  because it would trip naming a task that was not slow, which decision 111's watchdog
  for each round does when a timed task in it is slow; a round's trip now names each of
  its steps with its time (126). M4-6's Done-when asked for every trip reason, among them
  `{:internal, message}`, which the host contract makes unreachable; it is left out of the
  walk, and M4-4 reaches it through one hidden option, a seam named there. The
  milestone's done sentence had a stopped or killed runner restarted, though such a
  runner is gone, and asked for each timed task "on its grid as closely as the machine
  allows", which no test can check; it says the host starts a new runner, and that no
  run comes before its grid time and that runs and periods reported missed together make
  one for each grid time. And §4.11 said the simulated device reports each input it is
  set to, where it reports changes, and gives a value of the test's choosing for a read
  alone, where a report takes one too, and decision 120 paraphrased p.46 as a warning of
  a pulse unseen, where it warns of an overlap; each is corrected. Asked nothing, the
  maintainer answered once more on 2026-10-18: forces survive a crash, kept in a file, as
  the conventional family does (127). It is recorded, with M4-5's Done-when and the done
  sentence to match, and built with M4-5: the host names the file, `forces:`, and a runner
  without one takes no force; each force and unforce writes it whole and atomically;
  every start reads it, a force the configuration cannot take refused there as the host's
  mistake; `unforce_all/1` clears it; and the status always lists every force. IEC 61131-3
  says nothing of forcing, and the conventional family's keeping of forces through a
  power cycle, with a "forces on" indicator, is unverified in the manuals saved *(checked
  2026-10-20, decision 127: the FORCE status indicator and forces held by the controller
  are verified, 1756-PM004L pp.52–53; a power cycle is not found)*.
- **M4-2 · Watchdogs and the continuous task in a configuration.** The survey first: the
  stanzas `watchdog` and `continuous` in `docs/naming.md`, then the words in
  `Logex.Configuration.Text.keywords/0` and `naming_test.exs`'s pinned list. A task line
  takes `watchdog <ms>` after its priority, 1 to 2147483647 ms, 500 unless set (decisions
  109 and 110); one line may declare the continuous task, `task main continuous`, with a
  watchdog or none and no interval, single or priority, a second refused (decision 111).
  `Logex.Configuration.Task` gains `watchdog` and `continuous`, `name` alone enforced,
  since a continuous task has no priority, and `check/1` says what a line can say, from
  Elixir data as from text, a task with no priority still shown one of its own kind. A
  program with no `with` runs in the continuous task, and `with main` means the same
  (decision 111). In the core, a continuous task's instances run with the task-less ones,
  last, once a cycle, reported under its name; `next_due_in/1` counts it not; and
  `overlaps/1` lists it at 0, as an event-only task. `Logex.Configuration.Edit` refuses the
  line added or removed while running, as any task, moves nothing for `with main` added or
  taken away, and settles a watchdog's rule across an edit, with its report if one may
  change. *Done when* §4.4's plant, every task line with a watchdog and a box counter in
  its continuous task, `task main continuous watchdog 200` and `program boxes counter`,
  reads, prints back exactly, compiles with no warning and cycles as before, the box
  counter's runs reported under `main`; each refusal is pinned as a whole list from source
  and from data; the round trip, its totality and its growth hold with the new words; and
  an online edit that adds `with main` moves nothing.

  **Status: DONE — landed 2026-10-18**, as seven commits, M2-6's pattern: (1) the two
  stanzas and decision 129, the rule across an edit that decision 110 left to M4-2,
  `8fefe54`; (2) the fields, `check/1`'s rows and the core from Elixir data, `06a81d2`;
  (3) the reader, `entries!/1`, the printer and the reserved words, every check again
  from source, `f68cc25`; (4) the round trip, totality and growth with the new words,
  `847a091`; (5) the edit rules, with the contract walk, `6499982`; (6) the Done-when from
  text and from files on disk, `1e8047d`; (7) the documents, the commit after it. 1331
  tests pass on Elixir 1.20.4 (9 of them doctests), up from 1303. Each of (2), (3) and (5)
  records its mutation table, every rule it adds reverted alone in a worktree of its
  commit and the full suite judged by its exit code: (2) 26 rules, 25 red and one
  equivalent survivor, the continuous task among a cycle's timed tasks, which its own
  rule of no due time never lets run; (3) 24, all red; (5) 12, all red, each failing the
  contract walk too. `Logex.Runtime` changed as this item says, and no more: a
  continuous task's instances run with the task-less ones under its name, it is never
  due, and it is listed at 0; it reads no watchdog.

  Chosen while landing, each in its commit: `Logex.Configuration.watchdog/1`, the one rule
  for a task's watchdog, as `initial/1` is a global's, joining the public surface;
  `continuous` straight after the name, a word with no value, and `watchdog` after the
  priority, each once, out of order shown a line with it in place; a continuous task
  given inputs told them all in one diagnostic; a task whose `continuous` is the host's
  mistake read as neither kind; a task with no interval, single or priority offered the
  continuous task where none is declared; a task that needs a priority shown its own
  watchdog; and, decision 129, a watchdog changed while running, reported in ms, 500 for
  none, the continuous line's change a task's, a task's kind change its one refusal, and
  the untimed instances one place and one order under the continuous task's name. Found
  while landing: the contract walk's new draws moved its seeded stream, and its old seed
  no longer reached a `tp`'s resume in 500 configurations, so it takes another that
  reaches every kind; and a test helper named as one of `end_to_end_test.exs`'s own made
  the suite abort on its warnings with every test green, which the gate's exit code
  caught.

  M4-2's review, on 2026-10-18, found an edit's cost grown with the continuous task, and
  its fixes are the commits after (7). Decision 62's orders looked for the continuous
  task, in the original and in the candidate, once an instance, so accept, test and
  untest took time in the tasks times the instances: 4x of both took 10.09x the
  reductions in the review's probe, 3.98x before M4-2. Each is looked for once an edit
  now, and `config_edit_test.exs`'s growth tests gain the tasks and instances grown
  together, bound at 4.83. A mutant of `check/1` that skipped the watchdog of a task
  whose `continuous` is the host's mistake left the suite green, since the one task
  pinned had a watchdog that is a host's mistake too; a task with `continuous: "yes"` and
  a watchdog of 0 is now told both. The continuous line moved among the task lines
  was reported as a reorder of every task, `{:order, :tasks, names}`, though it is never
  due and takes part in no tie, decision 62's reason for reporting the tasks' order; the
  tasks' order is the timed tasks' now, a note on decision 129, and such a move reports
  nothing. `Logex.Configuration.watchdog/1` gave back a watchdog of 0 or -5, which no
  check had passed, as a task's; it raises for one outside 1 to 2147483647 ms now, as for
  one that is no integer, since every caller reads a checked task. The suite is at 1333
  tests (9 doctests).
- **M4-3 · The runner: start, rounds, devices, stop, read, subscribe.** *Done when* §4.4's
  plant with M4-2's box counter, loaded from files on disk through
  `Logex.Configuration.compile_file/1`, runs through `Logex.Runner` on the manual clock and
  two simulated devices, the panel reporting its changes and the drive only read, over a
  seeded sequence of presses and waits, and every round's outputs, events and `get/2`
  values equal those of `Logex.Runtime.cycle/3` called directly with the same
  `elapsed_ms` and inputs, an oracle that knows nothing of the runner. The run must also:
  - repeat exactly from fresh processes;
  - run its first round at once after start;
  - run one round each clock millisecond while the box counter exists, `advance(clock,
    n)` running exactly n (decision 122), the runner's own work served within its share,
    its slots, C ms of rounds and then up to S ms of its own work, pinned at 10%, 20%, 50%
    and 90% where rounds fill their milliseconds, a slow drive's write passing time inside
    them; and with the box counter taken out, round only at due times and at each change
    of `estop`, a press and release between two due times running `trip` once, at once,
    each `Logex.IO.Sim.set/3` returning once its round has run and its outputs are
    written (decision 124);
  - make the round of a trigger logic writes at the next clock millisecond, two event
    tasks that write each other's trigger rounding once a millisecond and a host's call
    served between (decision 123);
  - keep 100,000 periodic rounds on their grid with no drift;
  - leave every output at 0, written once, when stopped (decision 116);
  - raise every host mistake of §4.11, with its pinned message, in the caller, with the
    runner still alive.

  A real-clock test runs the plant for 2 s and asserts liveness and an orderly stop. Its
  landing order:
  1. the cycle in steps (decision 118), internal to `Logex.Runtime`, its composition
     pinned against `cycle/3` over seeded configurations;
  2. `start_link/1` and its host mistakes, relayed calls among them;
  3. the device processes: reading every poll period, reports passed on by a call the
     runner answers once the round they cause has run (decision 124), writes and
     refreshes, each refresh carrying its deadline (decisions 120 and 125);
  4. the rounds (decisions 108 and 122), one a clock millisecond with the share's slots,
     between due times otherwise, each change of a trigger its own round, at once from a
     device and at the next millisecond from logic (decision 123);
  5. stop, status, `get/2` and subscriptions;
  6. the oracle test from files on disk.

  **Status: DONE — landed 2026-10-18**, as seven commits, the six of its landing order
  and the documents: (1) the cycle in steps, `7d0da34`; (2) `start_link/1` and its host
  mistakes, `da746ee`; (3) the devices, `f7fd5de`; (4) the rounds, `7d37c85`; (5) stop,
  status and subscriptions, `56bf766`; (6) the oracle test from files on disk, with the
  real-clock test and the growth test, `a8819a8`; (7) the documents, the commit after it.
  1382 tests pass on Elixir 1.20.4 (9 of them doctests), up from 1333. Each of (1) to (5)
  records its mutation table, every rule it adds reverted alone in a worktree of its
  commit and the full suite judged by its exit code: (1) 12 rules, all red; (2) 24, all
  red; (3) 30, 29 red and one equivalent, a round's inputs kept for the next, which the
  image holds already; (4) 27, 25 red and two equivalent, C without its floor of 1,
  which the count of at least 1 at every wake makes no slot of, and a count kept with
  no untimed program, which no slot reads; (5) 25, all red. Eight survivors of the first
  runs were each given a test in its commit and are red: a value read again passed on as
  a change, a device with no output zeroed by an empty write, one round for two triggers
  in one report, C truncated rather than rounded, an earlier wake not cancelled, a stale
  wake taken, the status's overlaps and its longest refresh gap. The growth test bounds
  the runner's reductions over 20 rounds at 4.33 for 4x the instances and the devices,
  4.24 for the instances and 1.28 for the devices, a fifth above the highest of 32 runs,
  half beside three suites, 3.605, 3.533 and 1.066. `Logex.Runtime` changed as (1) says
  and no more: `cycle/3` is the composition of three hidden steps.

  Chosen while landing, each in its commit: the devices opened by a call once the runner
  is running, since a refusal from `init/1` kills the linked caller, so a device that
  cannot be opened stops the runner normally; `get/2` and `get!/2` in (2), the relayed
  calls it pins, ahead of (5); a refresh is a message to the device's process carrying its
  deadline and calls no adapter, which is written where its outputs changed and read
  every poll period, put to the maintainer; a device with no output point is never
  written nor zeroed; a slot serves its first request whatever the time, since one that
  looked first served nothing on a clock whose reading takes time; a host's request is
  served at once where no round is owed and always with no untimed program, so on the
  manual clock one made while a round is owed waits for the advance that runs it;
  `stop/2` is served at once; subscribing to a kind that is none of the seven is the
  host's mistake; anything else sent to the runner changes nothing; and the status's
  keys, `status`, `now`, `rounds`, `trip`, `overlaps`, `forces`, `edit`, `runs`,
  `latest_wake` and `refresh_gap`. Left as PLAN gives them: the trips, every I/O fault and
  the runner's death, a deadline acted on, `restart/2` and the hidden seam are M4-4's;
  `forces:`, forcing and the edit's steps through the runner M4-5's, `forces:` until then
  an unknown option. A device's callback that fails, a value that does not fit and an
  unknown address crash the runner until M4-4 trips on them.

  **Its review, and the maintainer's two answers, 2026-10-18.** A review of `a2ad82c`
  matched the rounds, events and writes against an independent scheduler over 1,600
  random plants, the 8 that differed all one tie, and found five defects and eleven
  surviving mutants;
  the maintainer answered M4-3's two questions the same day. Six commits on it, each
  gated and each with its mutation table:
  (1) `46714c3`, the devices opened inside `init/1` rather than by a call after start, so
  a host's call by the runner's name that came first no longer crashed the runner and
  its starter (F1, 33 of 300 starts in the review's probe), and a stop that came first
  gives `{:ok, pid}` and then stops; each request still queued at a stop, or left
  unanswered as the runner goes down, raises that the runner is not running (F2); a cast
  or a message is passed over and a call none of its functions makes is the caller's
  mistake (F5); 6 rules, all red;
  (2) `935193c`, an improper list of kinds and a repeated option each told in their own
  words (F4); 3 rules, all red;
  (3) `67be539`, decisions 130 and 131 recorded, and a slot served at the end of the
  round that completes its C ms, so that on the manual clock a call whose slot a round
  completes is answered in the advance that runs that round, `advance(clock, 0)` among
  them (F3, kept apart from the rule decision 131 keeps), with a refresh before the rest
  of a millisecond is served where a request waits; 6 rules, 5 red and 1 equivalent;
  (4) `9fd1270`, decision 130 built: each device writes its last outputs again at its
  poll, at most once a poll period, where nothing was written within one and its last
  deadline has not passed; 6 rules, 5 red and 1 red with the next commit's test;
  (5) `20f885e`, a test for each of the review's survivors, and a continuous line that
  runs no instance timing no round, as decision 111 says, so M4-4's round watchdog reads
  only rounds that run untimed programs; 12 rules, 11 red and 1 equivalent, the elapsed
  time's clamp at 0, which a monotonic clock never needs;
  (6) the documents, the commit after it: decision 122's "a round counts from its start
  to the next round's" read as from its start to its end, a millisecond at least, which
  the code did, since the runner's own work that runs past a millisecond is its own and
  counting it as the round's would give its own work more than its share; and §4.11's
  sentence on a tie, a poll that changes a trigger and a round due in the same
  millisecond going in either order, a run still repeating exactly.
  1404 tests pass on Elixir 1.20.4 (9 of them doctests), up from 1382. The review's three
  equivalences hold for M4-3 and are to be looked at again when M4-5's forcing and edits
  through the runner land: a round's inputs kept, C's floor of 1, and the share's count
  with no untimed program.

  **Its verification, 2026-10-18.** A verification of those six commits re-ran the
  review's probes and 27 mutants, 26 red and the elapsed time's clamp equivalent, and
  found two low defects. Two commits on it, each gated and with its mutation table:
  (1) `a5d0b1a`, a call that reached the runner unanswered as `stop/2` stopped it with a
  reason of its own, `:abandoned`, exited its caller, an exit escaping the API: every
  reason the runner goes down with is now the runner not running, as the moduledoc says;
  1 rule, red;
  (2) `7cbe97b`, decision 132: a poll in the millisecond a round is due wrote the old
  outputs again just before the round wrote the new ones, twice the writes a 10 ms task
  on the default poll needs; a poll that finds a round due, come due less than a poll
  period before it and not yet run, now leaves its write to that round, the runner
  telling every device after each round when the next is due, and the device writing
  again at the round's end only where the round wrote nothing, counted from the poll;
  9 rules, all red. 1408 tests pass on Elixir 1.20.4 (9 of them doctests), up from 1404.
  Decision 132 was taken without the maintainer, who may prefer its second option, the
  rule as landed with its cost stated.

  **The maintainer's answer, 2026-10-18,** "Fixed timer as Logix", replacing decision
  132: each device re-sends its last outputs every poll period on its poll grid, whether
  or not a round wrote to it within the period, as Logix re-sends outputs at the RPI, and
  the rounds write as before. Two commits on it, each gated:
  (1) `2203fa1`, decision 132's mechanism removed, `Device.due/2`, the runner's cast
  after each round and the wake at the poll's millisecond, and decision 130's skip with
  it: a device writes again at every poll once written, while its last refresh's
  deadline has not passed, one with no output point never written; tests that count a
  device a round writes every millisecond, 31 + 3 writes over 30 ms, and every 5, 10 or
  20 ms exactly, a device's process never written writing nothing at its polls, and busy
  devices' 201 writes each over 1,000 ms at 1, 4 and 16 devices beside the idle ones'
  101; 9 rules, all red;
  (2) the documents, the commit after it: decision 130 amended and 132 marked
  superseded in `docs/organisation.md` §7, with IEC's silence on a controller's I/O
  traffic, Logix's re-send at the RPI, an output module's fallback after missed RPIs
  left unverified *(both verified on 2026-10-20, 1756-UM058L pp.24–25 and 1756-PM015Q
  p.12, the fallback as a configured fault state on a communication fault, not phrased in
  RPIs; decision 130)*, and the cost, one adapter write a device a poll period, plus each
  round's; §4.11, the moduledocs, README's "On the clock", re-run, its output the same,
  and CLAUDE.md brought to it. 1407 tests pass on Elixir 1.20.4 (9 of them doctests),
  down from 1408: decision 132's four tests gone, three new.
- **M4-4 · The watchdogs and the fault path.** *Done when* each of these is a test on the
  manual clock, a hung device's deadline in real time and short:
  - a timed task whose run outlasts its watchdog trips before its round's write, naming
    it, and so does a round that outlasts the continuous task's (decisions 110 and 111),
    naming each of its steps with its time, a slow timed task's among them (decision
    126);
  - a stuck runner's devices zero themselves by the deadline their last refresh carried,
    a runner stuck in the conveyor's 50 ms step within 50 ms and a poll period of its
    start, not the plant's longest watchdog, and one stuck in its own work within its
    idle watchdog, `idle:`, and a poll period (decision 128), a step that takes exactly its watchdog
    leaving a poll period's margin (decision 125);
  - each kind of I/O fault trips, naming its device (decision 114);
  - a killed runner's devices zero and close (decision 115);
  - a hung device is killed, and opened again at a restart;
  - an exception out of the core trips `{:internal, message}`, reached through one hidden
    option of `start_link/1` that stands a module of the test's in for `Logex.Runtime`'s
    steps, the one seam the runner has for a fault no host can cause.

  In each, every device that answers is written 0 exactly once and nothing after; the
  resource is kept for `get/2`; and `restart/2`, cold and warm, resumes with the first
  round at once and the clock not counting the stopped time (decision 113). The manual
  clock gains what it needs to make time pass inside a task's run, where M4-1's `pass/2`
  cannot reach it. Its landing order:
  1. the trip and restart;
  2. each task's watchdog and the continuous task's per round;
  3. the devices' deadlines, carried by every refresh (decision 125);
  4. the I/O faults;
  5. the runner's death.

  **Status: DONE — landed 2026-10-18**, as seven commits, the five of its landing order,
  the manual clock's rule and the documents: (1) the trip and restart, with the hidden
  seam, `ef03273`; (2) each task's watchdog, the continuous task's round and the idle
  watchdog, `eddad44`; (3) the devices' deadlines, `9b0df68`; (4) the I/O faults,
  `b38dc72`; (5) the runner's death, with the trip's growth test, `58636bc`; (6) the
  manual clock advanced by a receiver as it handles a message, `3057a81`; (7) the
  documents, the commit after it. 1453 tests pass on Elixir 1.20.4 (9 of them doctests),
  up from 1409, most of them in `test/logex/trip_test.exs`. Each of (1) to (5) records its
  mutation table, every rule it adds reverted alone in a worktree of its commit and the
  full suite judged by its exit code: (1) 30 rules, 29 red and one equivalent there, a
  zero of a latched device writing 0 again, which nothing could do until (3)'s deadlines
  latch a device before a trip, and red there; (2) 16, all red; (3) 16, all red; (4) 28,
  27 red and one equivalent there, a close's raise not caught, red with (5)'s
  `terminate/2`; (5) 7, all red. Six survivors of the first runs were each given a test in
  their commit and are red: a trigger's change while tripped, a trip no wake brought, a
  stuck step after a device's wake had moved on, a device waiting on the runner for its
  own change (on the real clock, short), a device's own fault zeroing it with the runner
  suspended, and a clock that exits as it is read; and two pieces of code no rule needed
  were taken out of (1), a release that forgot what its device last wrote and the share's
  count set to 0 at a restart (the first back since the review, below). The growth test
  bounds a trip's work at 5.08 for 4x the devices, a fifth above the highest of 38 runs,
  4.233; M4-3's round test of the devices alone is bound at 1.39 now, a fifth above 1.156,
  the highest of 32 runs, since each device's write is answered within its deadline.
  `Logex.Runtime` is unchanged.

  Chosen while landing, each in its commit and in §4.11's landing note: the hidden option
  is `steps:`, a module with `cycle_steps/3`, `cycle_step/2` and `cycle_outputs/1`, an
  exception's message its own and a throw's or an exit's its banner; a test makes time
  pass inside a task's run through it, a stand-in that passes the manual clock, or, for a
  runner stuck in a step, advances it from inside the runner, which (6) makes the clock's
  rule; a tripped runner merges a device's changes into the next round's inputs, so the
  restart's first round takes them, keeps its first reason, and refreshes no device; a
  round that trips is not counted among the rounds; a request is timed against the idle
  watchdog from its start to its end, reading the clock twice, so M4-3's slot test on a
  clock whose every reading takes a millisecond serves three requests a 9 ms slot where it
  served nine, and a restart is not timed so; a device's refresh carries the time it was
  sent, `{:watchdog, {:device, device, ms}}` naming the span from it to the deadline; a
  device keeps one wake on its deadline, set again only where a refresh brings it sooner;
  a round's first act is to take a device's notice that waited, so a runner back from
  being stuck trips before it runs anything; a result of no shape `Logex.IO` gives is
  `{:raised, message}`; a device that answers after its deadline on the runner's clock is
  `:timeout` and killed (since the review, written its 0 instead); an init/3 or first read
  that raises, throws, exits, hangs or gives a value that does not fit is `{:io_init,
  device, cause}`, init/3's own reason given as before; a clock that goes down or fails
  stops the runner and each device as a shutdown, `{:shutdown, {:clock, reason}}`, which
  also ends a test's runner quietly when the test's manual clock goes down with it; and a
  device whose adapter was never opened is neither zeroed nor closed as it stops. Found
  while landing: a test that traced a device after the runner's start could see a refresh
  sent before it, still in the device's queue, and failed 2 of about 15 full runs under
  load; each trace now passes over what was sent before it. And the waits for an
  asynchronous event in `trip_test.exs` take 5 s, not ExUnit's 100 ms, which a killed
  runner's devices outlasted beside three suites.

  **Review, 2026-10-19, and its fixes.** An adversarial review of the seven commits found
  four defects, a process fault and the rules no test held, each fixed in a commit of its
  own after them, every commit gated by its exit code and backed up: (0) found while
  fixing them, a test that failed 3 of 20 runs alone at `da7e4df`, two devices latching in
  one millisecond on the manual clock, their notices reaching the runner in whichever
  order their processes ran: each notice now carries the time it was raised, and the
  runner takes every notice waiting together, by that time, ties in device-name order,
  `7f5222a`; (1) a cold restart could switch the conveyor back on for a moment, each
  poll's write again inside the restart's first round sending the outputs from before the
  trip, the code the landing's (1) took out as "no rule needed": a release forgets what
  the device last wrote, `3635a3a`; (2) a stop or a crash while a device waited on the
  runner for its own change zeroed and closed it twice: the close's state now comes out of
  the wait, `47682cd`; (3) a device that hung or died while the runner was tripped was
  dropped by the restart, which ran on without it: a restart releases first and then opens
  again every device down, one that does not answer its release among them, and one that
  cannot be opened leaves every device latched again, written 0 once more, `2f35bad`; (4)
  a device hung inside its own read or report was never seen while its outputs did not
  change, which decision 114 already makes a fault: each device tells the runner after
  every read and report that it is back from its adapter, and the runner trips `{:io,
  device, :timeout}` on one not heard within the idle watchdog and a poll period, checked
  as each round begins and at each wait's refresh, `2f1576d`; (5) a device that answered a
  round's write after its deadline on the runner's clock was killed, its outputs left at
  what it had just written: it is `:timeout` still, and written its 0 by the trip,
  `3fe9f97`; and (6) each rule the review found untested a test, `e6f6ca4`. A
  verification of the fixes then found (6) had taken out one piece of code that a rule
  needs, a latched device sending no notice at its later deadline, called equivalent
  below: a device the trip latched still told the runner once its last deadline passed,
  which a tripped runner passes over, but which a host's restart waiting in a busy
  runner's mailbox meanwhile is taken before, so that the restart answered `:ok` and its
  first round tripped `{:watchdog, {:device, device, ms}}` on a deadline from before it,
  on the manual clock every time and on the real clock 6 restarts in 800; (7) puts the
  clause back with that case as its test. A second verification then found the wider
  case (7) left: a restart a trip serves from its queue, one the host asked for while a
  round was owed, is answered inside that trip, and a latch or a fault raised by a device
  not yet latched as the trip began, taken with the notice that made it or come in while
  it ran, tripped the restarted runner after `restart/2` had answered `:ok`; and a "back"
  taken with the trip's notice, acted on only after the restart's first round, left its
  device unheard there, killed as hung, `{:io, device, :timeout}`, on the manual clock
  every time and on the real clock 20 restarts in 20. (8) gives every notice the count of
  restarts its device was released for, 0 from its opening, the runner passing over one
  from before its last restart, and acts on every notice taken together before the trip;
  the count makes (7)'s clause a rule's second place, so (8) takes it out. Its mutation
  table, each mutant judged by the full suite's exit code, one at a time: the count not
  checked, red in two tests, the notice that came in while the trip ran and (7)'s; the
  trip made inside the batch, red in the "back" taken with it; the runner's count not
  moved at a restart, red in the same two as the first; a release that does not give the
  device the count, red in a device latching after a restart; a device opened again at a
  restart given 0, red in its fault after it; and the whole fix reverted, red in the three
  new tests. 1474 tests pass on Elixir 1.20.4 (9 of them doctests), up from 1453.

  The mutation tables of the landing's (1) to (5), above, overstate: three of their rows
  counted red only because a slow test timed out under load beside a parallel mutation
  run, runner_test's 100,000 rounds at ExUnit's 60 s or M4-3's 2 s on the real clock, and
  each survived run alone: (1)'s T2, a latched device still taking a round's write, (3)'s
  D3, a device latching a millisecond early, and (4)'s F25, a device opened again whose
  values were not merged. Each now has a test, as has each rule the review's own mutants
  found untested: a zero's time to answer, which of two faults in one read is named, a
  poll's write again at its deadline's millisecond, a device opened again whose first read
  does not fit, and a notice from a process that is not its device's. Every mutation row
  of the fixes' commits was judged by `trip_test.exs`'s exit code alone, one mutant at a
  time, and all thirty again by the full suite's, one mutant at a time, at the fixes' (6):
  every one red, each failing the test its row names, none red by a slow test alone. Three
  pieces of code were taken out as equivalent, each a rule's second place: a device marked
  down in a write that timed out or went down, where the trip's zero finds it so (the
  review's N10, in the fixes' (5)), a release's forgotten deadline, and a device latching
  itself on a round's write that failed, which the trip that write makes latches at once
  (each in the fixes' (6)). (6) took out a fourth, a latched device's later wake, as
  equivalent too, and it is not, as (7) above gives; and the fixes' (4) left out a
  fifth, the silent device marked down, for the same reason. Its table gives its B11, a
  "back" from a process no longer its device's, as equivalent; (6) gives it a test, and it
  is red there. The trip's growth test stays at 5.08, its highest of 48 runs 4.168;
  runner_test's round bounds go to 4.38 for both together and 1.40 for the devices, each a
  fifth above its highest of 48 runs, 3.643 and 1.165, since each round begins by checking
  every device heard. README's `a_trip.exs` re-run, its status fields now printed as a
  keyword list in the order named, since a map's keys came out in a different order on a
  re-run (the review's finding 8); and its status asked before its events are read, since the
  events, read straight from the mailbox, came empty once in some sixty re-runs, the trip
  made by the runner after the advance that failed the read had returned, and the status
  call is answered only once the runner has taken the panel's notice and tripped.

  **Answered by the maintainer, 2026-10-19,** each question below with its option (a),
  the one recommended and the one built, so nothing changes in the code: a restart of a
  runner that is running is the host's mistake (question 1, decision 133); a device hung
  inside its own read or report, a fault by decision 114, is tripped once not heard
  within the idle watchdog and a poll period, 510 ms by default, at the cost of a message
  a device a poll period (question 2, decision 134); a device whose own callback failed
  is zeroed through its adapter too, where it still takes a write (question 3, decision
  135); a restart that cannot open a device stays tripped and writes every other device
  its 0 once more (question 4, decision 136); and `{:watchdog, {:device, device, ms}}`
  names the heartbeat the device was given, from its last refresh to its deadline
  (question 5, decision 137).

  *Questions for the maintainer, 2026-10-19,* the builder's three of 2026-10-18 with the
  review's view of each, one the fixes raised and one the builder had left among its own
  choices, each answered (a) the same day, decisions 133 to 137. Words used: a *trip* is
  the runner stopping itself after a fault, every output switched off once and nothing run
  until a *restart*, the host's call that starts it again from the program's initial
  values; a *device* is one I/O card or drive the runner talks to through its *adapter*,
  the code for that hardware; a *poll period* is how often the runner's process for a
  device reads it, 10 ms unless set; the *idle watchdog*, `idle:`, is how long the runner
  may spend on its own work between steps, 500 ms unless set (decision 128); the plant is
  §4.4's, a conveyor on the panel card, a fan, and the "case full" lamp, with the drive's
  speed on the drive.
  1. *A restart while nothing has tripped.* The conveyor and the fan are running and the
     lamp is lit, and an engineer's program calls `restart/2`. (a) As built: refused, the
     engineer's program told "the runner is running", and the plant runs on untouched.
     (b) A trip and a restart in one: for a moment every output goes off, the conveyor and
     the fan stop and the lamp goes out, and then the program starts from its initial
     values, the conveyor staying off until start is pressed. (c) The program's values
     reset without the outputs being switched off first: the conveyor drops out on the
     next round, as its seal-in resets, the fan goes off if its program starts it off, and
     nothing is written 0 in between. IEC 61131-3 describes a cold and a warm restart as
     ways a resource starts, and says nothing of one already running; the conventional
     family has no restart of a running controller, the nearest being a change to Program
     mode and back, its outputs in their Program-mode state meanwhile (from memory,
     **unverified** in the manuals saved; the Program-mode state verified on 2026-10-20,
     1756-UM058L p.123, decision 133). The review agrees. Recommended: (a).
  2. *How soon a card stuck while it is read is a fault.* The panel card's adapter hangs in
     the middle of reading the buttons, while the conveyor runs steadily and no output
     changes. Decision 114 already makes it a fault, as the review pointed out, so the
     runner now trips on it; what is left is how soon. (a) As built: once the runner has
     not heard from the card for the idle watchdog and a poll period, 510 ms by default,
     the conveyor, the fan and the lamp go off about half a second after the card stuck,
     a press of stop on that card unseen until then; the same time the runner gives any
     call of its own to a card, so a card is given as long to answer as its deadline
     (decision 119's refinement); a busy machine that delays a card's read by more than
     that trips the plant. (b) A count of missed reads, Logix's way: the plant stops after
     four poll periods without a read, 40 ms by default, sooner, but a machine that holds
     a card's process back for 40 ms trips the plant. (c) A time set for each device in
     its binding: the panel's could be 50 ms and a slow network drive's two seconds, at
     the cost of one more setting a plant must get right. Either way the cost is one
     message from each card to the runner each poll period, 100 a second a card at 10 ms.
     IEC 61131-3 says nothing of how a controller talks to its I/O; the conventional
     family faults a connection that misses its timeout, its RPI times a multiplier of 4
     by default, which (b) matches (from memory, **unverified** in the manuals saved;
     **contradicted** on 2026-10-20: a timeout of 100 ms at least, 160 ms at the default
     20 ms RPI, 1756-UM001Q p.158, no default multiplier stated, decision 134).
     Recommended: (a), one time for every call to a card, until a plant needs (c).
  3. *The card that failed.* The drive's network cable comes loose and the runner's write
     of the drive's speed fails; the record's table says "every other device zeroed". (a)
     As built: the drive is written its 0 too where it still takes a write, as well as
     the panel, so where the cable is only flaky the drive's speed goes to 0. (b) The
     failed device is left alone, its outputs to what the drive does when its master goes
     quiet, the panel alone written 0: the drive keeps its last speed until its own
     timeout. IEC 61131-3 says nothing of it; in the conventional family a faulted
     module's outputs go to the fault state configured on the module, the module doing it
     rather than the controller (from memory, **unverified**; verified on 2026-10-20,
     1756-PM015Q p.12 and 1756-UM058L p.123, decision 135). The review agrees.
     Recommended: (a), every output that can still be written at 0, the milestone's done
     sentence.
  4. *A restart that cannot open a card.* The drive was unplugged while the plant was
     tripped, and the operator presses restart: the panel answers, the drive cannot be
     opened, and the plant stays tripped, the conveyor, fan and lamp off. (a) As built:
     the panel, released for the restart and then latched again, is written its 0 once
     more, as it is when a restart's first round trips again: nothing visible changes on a
     healthy panel, its outputs already off, but a panel that reset itself meanwhile, or
     one opened again in the same restart, is told 0. (b) The panel latched again without
     a second 0, every output written 0 exactly once a trip whatever the restarts in
     between: the same on a healthy panel, and a card opened again in that restart left
     to whatever it does at power-up until the next restart. IEC 61131-3 says nothing of
     it; the conventional family writes each module's outputs every RPI in every mode,
     so a module hears its state again and again (from memory, **unverified**; every RPI
     verified on 2026-10-20, 1756-UM058L pp.24–25, "in every mode" not stated, decision
     136). Recommended: (a), a 0 heard once more rather than a card left unsaid.
  5. *What time a card's own timeout reports.* The runner is stuck for 3 s inside the
     conveyor's step, whose watchdog is 50 ms; the panel hears nothing by its deadline,
     50 ms and a poll period after the step began, switches the conveyor, fan and lamp
     off itself, and the runner, back after 3 s, trips `{:watchdog, {:device, "panel",
     ms}}`. (a) As built: `ms` is the heartbeat the panel was given, 60, from the refresh
     it last heard to its deadline, so the operator reads "the panel heard nothing for
     60 ms", the time after which the plant went off, the same on every run. (b) The time
     the runner was gone, about 3,000, read when it came back: "the controller was stuck
     for 3 s", which says how long, but varies from run to run on the real clock and says
     nothing of when the plant went off. (c) No time at all, `{:watchdog, {:device,
     "panel"}}`, the reason naming only the card. IEC
     61131-3 says nothing of it; in the conventional family a module whose connection
     times out shows a connection fault code with no time in it, and a task's watchdog
     fault names the task (from memory, **unverified** in the manuals saved).
     Recommended: (a), the time after which the plant actually went off, the same on
     every run.
- **M4-5 · Edits and forcing through the runner.** *Done when* §4.4's plant, edited while
  it runs through `Logex.Runner`'s accept, test, untest, assemble and cancel, gives every
  report and every round's outputs that the same steps give taken over the resource
  directly; `slow` cut to 20 ms moves its next due time as decision 40 says, with no round
  lost or added; accept's work is done in the caller's process (decision 119); and
  forcing (decision 117) holds a forced input against its device and across a restart,
  a forced trigger making a round, refuses an output point or a value that does not fit
  in the caller, lists every force in the status, and on `unforce/2` puts back the
  device's last value. Forces are kept in a file (decision 127): `start_link/1` takes
  `forces:`, a path, and a runner started without it refuses `force/3` as the host's
  mistake; each force and unforce writes the whole set before it returns, to a file
  beside it, flushed and renamed over it, a write that fails changing nothing and
  returning `{:error, {:forces, reason}}`; every start reads it, `start_link/1` in the
  caller and `restart/2`, a file that does not exist being no force, so that a runner
  killed while the photo-eye is forced, and started again from the same file, comes back
  with it forced and listed in `status/1`; a force in the file on a point the
  configuration no longer has, on an output point or of a value that does not fit, and
  a file that cannot be read, are refused at start as the host's mistake, every such
  force named, the runner not started, and at `restart/2` raised in the caller with the
  runner left tripped; and `unforce_all/1` takes every force off and writes the file
  empty, a host with no runner deleting the file. The file's format, text a person can
  read, is this item's to settle.

  **Status: DONE — landed 2026-10-19**, as five commits: (1) forcing through the runner,
  `forces:`, `force/3`, `unforce/2` and `unforce_all/1`, the file written whole before
  each call returns, `a3b7971`; (2) the file read at every start, `start_link/1` in the
  caller and `restart/2`, a force it cannot take refused, `b659f00`; (3) an online edit's
  steps through the runner, accept's work in the caller, `26a4d08`; (4) the Done-when on
  §4.4's plant from files on disk, with the growth tests, `9206c02`; (5) the documents,
  the commit after it. 1519 tests pass on Elixir 1.20.4 (9 of them doctests), up from
  1474, most of them in `test/logex/force_test.exs` and `test/logex/runner_edit_test.exs`.
  Each of (1) to (3) records its mutation table, every rule it adds reverted alone in a
  worktree of its commit and the full suite judged by its exit code: (1) 21 rules, all red,
  two of them, an unforce's value for a point no device had given one and the file
  written in place rather than renamed over, red only once a test of their own was added;
  (2) 11, all red; (3) 14, 13 red and one equivalent, the configuration a step runs
  written into the runner's own state, which nothing read again, taken out, an
  overtaken accept not done again red only once the test of an accept another host's
  cancel overtakes was added. Each red row fails a test of its own file that names its
  rule; run three or four at a time, some rows also failed a slow runner test by its
  timeout, which is not counted. M4-3's review left three mutants equivalent until
  forcing and edits landed, and (4) judges them again: a round's inputs kept for the
  next and C without its floor of 1 are still equivalent; the share's count kept with
  no untimed program is not, since an edit that adds an untimed program would find the
  count the timed rounds left, and a test now kills it. The growth tests bound a force's
  write and 20 rounds merging every force at 4.0 and 4.61 for 4x the forces, and the
  runner's own work for an accept at 1.70 for 4x the instances, each a fifth above the
  highest of 52 runs, 18 beside two suites, 3.333, 3.844 and 1.416. `Logex.Runtime` and
  `Logex.Configuration.Edit` are unchanged.

  **Its review** (2026-10-19, at `3ee6e69`) found one blocking bug and three rules with no
  test, each fixed the same day in a commit of its own with its mutation table, every row
  red on the full suite by its exit code:
  (1) an edit's step that took away the last untimed program left the requests queued
  behind it for the share's slot unanswered for good, a slot never coming again: now,
  with no untimed program, every request that waited is served at once, in order, as
  each is from then on (decision 108), and so is the rest of a millisecond's that a step
  ran past, `c358efb`; (2) `unforce_all/1` that changed several triggers made one round
  for all of them, where decision 120 makes each change of a trigger its own round: now
  one round each, in device-name and then address order, each reading those before it at
  their new values and those after it as they were, `3ce7f57`; (3) the review's three
  surviving mutants each a test, a device opened again at a restart kept as its last
  value, a step's event sent while tripped, and the forces listed in the status before
  a first round that trips, with the growth bounds raised to a fifth above the highest
  of 118 runs, the review's 16 and 50 more among them, 3.391, 3.852 and 1.450, to 4.07,
  4.63 and 1.74, `c77030e`; and (4) these documents, question 2's arithmetic put right
  (counted from the edit, the fan's next run stays at 100), question 1 given the order
  of several triggers' rounds, and question 4 the edit another engineer's test leaves.
  1524 tests pass on Elixir 1.20.4 (9 of them doctests). The review's probes, re-run on
  the fixes, hold: the queued status answered, and two triggers unforced two rounds.

  Chosen while landing, each in its commit and in §4.11's landing note: the forces
  file's format, which the record left to this item, one force a line, `name value`, in
  name order, the empty file for none, written to `<path>.tmp` beside it, flushed and
  renamed over it (the directory is not synced after the rename); a refusal at a start
  names each problem `<path>: line <n>: ...`, a line each, in `force/3`'s words; a
  restart reads the file before it releases anything; an edit's steps give `{:ok,
  report}`, the design spike's shape; accept asks the runner for its resource with the
  count of steps it has taken, and the runner holds the edit accept gives only where no
  step came between; and after each step the rounds read the watchdogs and the untimed
  programs of the configuration the resource runs, and the next round is planned again
  from the last. Four more, the record silent, were built as the option closest to the
  record and to Logix and put to the maintainer below: a forced trigger's round, and
  since the review the order of several triggers' rounds across devices; decision 40's
  `now` with no untimed program; the forces file a person reads; and two hosts stepping
  one edit. The maintainer answered all four on 2026-10-19, decisions 138 to 141 (below).

  **Questions for the maintainer** (answered 2026-10-19, each answer after its question).
  In each, a *round* is one pass of the controller over
  its programs, reading the inputs, running the programs that are due and writing the
  outputs; a *trigger* is the input an *event task* watches, a task that runs when its
  trigger goes from off to on, here the e-stop button that runs the `trip` task, which
  stops the conveyor and lights the trip lamp; to *force* an input is to make the
  controller read a value of the technician's choosing, whatever the real signal says,
  until the force is taken off (*unforced*); a *periodic task* runs every so many
  milliseconds, its *interval*, here the fan's task every 50 ms; an *untimed program* is
  one in no periodic or event task, run again and again as fast as the controller can,
  here a box counter in the continuous task; and an *online edit* changes the programs or
  tasks of a plant while it runs, in steps: *accept* (checked, nothing changed yet),
  *test* (the new version running), *untest* (the old one back), *assemble* (the new one
  kept) and *cancel* (the edit dropped).
  1. *When a forced trigger runs its task.* The conveyor runs, the fan's task every 50 ms,
     and a technician forces the e-stop on from a laptop to test the trip lamp. (a) As
     built: the `trip` task runs once, at once, when the force changes what the
     controller reads, off to on, before the laptop's call returns, so the lamp is lit by
     the time the laptop says "done"; forcing it on again while it already reads on runs
     nothing; while it is forced, presses of the real e-stop button change nothing the
     controller reads and run nothing. Where one call changes several triggers, as
     "unforce all" can, say the e-stop and a guard door's switch on the panel and a lift
     limit switch on the drive, each runs its own round, one after the other, before the
     call returns, as several changes from one device already do: first by the device's
     name, then by the input's address on it (here the drive's lift first, then the
     panel's e-stop and door in address order), each round seeing the triggers before it
     at their new values and those after it as they were; the operator sees each task's
     lamp or alarm come on in that order, in the same instant. (b) Every force of a
     trigger makes a round at once, even to the value it already reads: an extra round in
     which nothing new happens, since a task runs on its trigger's rising edge; the round
     counter on the status screen moves, nothing else. (c) A force waits for the
     controller's next round on its schedule, so the trip lamp lights up to one fan
     period, 50 ms, later, and the laptop's call returns before it. For several triggers
     in one call, the alternative to (a)'s order is one round in which all of them change
     together, their tasks then running in priority order, which is what the builder
     first built and what a device's several changes do not do. IEC 61131-3 says nothing
     of forcing, and an event task in IEC runs on its trigger's rising edge, whatever
     caused it. In Logix a force changes the input as the program sees it from the next
     scan, and whether an event task triggered by a forced input runs at once, or in what
     order several do, is not in the manuals saved (**unverified**; checked on 2026-10-20,
     decision 138: a force *"immediately takes effect"*, 1756-PM004L p.51, and an event
     task fired by a force is not found). Recommended: (a), the
     review agreeing, with one round per trigger changed. *Answered: (a), as built, one
     round per trigger changed, in device-name then address order, a force that changes
     nothing making no round (decision 138).*
  2. *A task's interval cut while no untimed program runs.* The fan's task runs every
     50 ms, last at 50 ms, so it is next due at 100; the plant has no continuous task, so
     the controller's own clock stands at 50, the fan's last run, until its next run. At
     95 ms by the wall clock an engineer cuts the fan to 20 ms. Decision 40 sets the next
     due time to the earlier of the one it had and "now plus the new interval". (a) As
     built, "now" read on the controller's own clock, 50: the earlier of 100 and 50 + 20 =
     70, which the wall clock has passed, so the fan task runs at once, at 95, and the
     status screen shows one missed period, an overlap, though nothing ran late. (b)
     "Now" the wall clock's, 95, the runner first bringing the controller's clock up to
     it by a round that runs no program: the earlier of 100 and 95 + 20 = 115 is 100, so
     the fan runs at 100 as it would have, no missed period shown, and one round more
     appears in the log. (c) "Now" the wall clock's, 95, given to the edit's switch as a
     new argument, `Logex.Configuration.Edit` changed: next due at 100, unchanged, no
     missed period and no extra round. With §4.4's box counter in the continuous task, as
     in the Done-when, rounds come every millisecond, the controller's clock keeps up with
     the wall clock, and the three agree. IEC 61131-3 says nothing of a task's interval
     changed while running. In Logix a periodic task's period may be changed online, and
     when the new one takes effect is not in the manuals saved (**unverified**; partly
     verified on 2026-10-20, decision 139: the TASK object's Rate, which logic may write,
     1756-RM018A p.276, its taking effect not found).
     Recommended: (c), the screen showing no alarm the edit itself made and no round
     added, if a change to the edit's switch is acceptable, the review agreeing; (a) is
     what the record's rule says as written, and stays built until the maintainer says.
     *Answered: (c), then built (decision 139): the step's time on the runner's clock,
     given to the switch; used alone, `Logex.Configuration.Edit`'s `now` is the
     resource's unless the host gives the milliseconds since its last cycle.*
  3. *The forces file a person reads.* The file sits beside the plant's files, one force
     a line, `eye_1 1`, the photo-eye that counts boxes on the conveyor held on. (a) As
     built: the runner reads exactly what it writes, so a person who opens it sees every
     force, but one who adds a comment or a blank line, or writes `eye_1 01`, finds the
     next start refused, the line named, the plant not started, until the line is put
     right or the file deleted; a last line with no newline is read. (b) Comments and
     blank lines read and passed over, so a person may annotate it, though the runner's
     next write, at the next force, drops what was added. Beside it: a runner started
     with no file refuses "unforce" and "unforce all" as it refuses a force, in the same
     words, though it has nothing to take off; and an unforce of an input that is not
     forced is accepted and writes the set again. IEC 61131-3 says nothing of forcing. In
     Logix forces are kept in the project and changed only through the programming
     software, never by editing a file (**unverified**; forces held by the controller and
     kept in the project verified on 2026-10-20, 1756-PM004L pp.52–53, decision 140).
     Recommended: (a), the review
     agreeing: a strict file is the safest for a list that decides what the plant reads.
     *Answered: (a), as built, and an unforce of a point not forced accepted (decision
     140).*
  4. *Two engineers stepping one edit.* Engineer A accepts a change to the fan's
     interval from one laptop while engineer B, from another, takes a step of the edit
     the controller already holds. (a) As built: A's accept is worked out on A's laptop
     against the plant as it was; if B's step came first, the controller tells A's laptop
     so, and A's accept is worked out again against the plant as it is now, so A's
     laptop shows a forecast that is true when the edit is held, and B's edit is
     replaced by A's, as a second accept replaces a first. If B's step was a test, the
     plant as it is now runs B's new version, so A's edit takes B's tested version as
     its "old" version, the one A's untest would bring back: A would see B's change as
     already part of the plant. A change the controller refuses, a task added, leaves
     whatever edit was held as it was. (b) A is told the plant moved on, and accepts again
     by hand, seeing the plant as it now is before choosing. IEC 61131-3 says nothing of
     online edits. Logix's programming software lets one workstation at a time edit a
     controller online (**unverified**; not found, and probably contradicted, on
     2026-10-20, decision 141). Recommended: (a), the review agreeing, since it
     gives exactly what the same steps taken over the resource directly give
     (`Logex.Configuration.Edit`'s rule that a second accept supersedes the first).
     *Answered: (a), as built: an overtaken accept is redone against the plant as it
     now is (decision 141).*

  **The maintainer's answers** (2026-10-19), recorded as decisions 138 to 141 in
  `docs/organisation.md` §7, decision 40 amended to point to 139. Questions 1, 3 and 4
  were answered with what was built. Question 2's (c) was built in one commit, `5792089`:
  `Logex.Configuration.Edit`'s `accept/3`, `test/3` and `untest/3` take the step's time
  as `elapsed_ms`, the milliseconds since the resource's last cycle, counted and refused
  as `Logex.Runtime.cycle/3`'s, checked after the runtime, and decision 40's `now` is the
  resource's `now` plus it, the step moving no clock, a resumed timer's time still the
  resource's (decision 56). Used alone it is 0 unless given, so a direct call keeps the
  resource's `now`, the reading since OE-2, the record's answer for a host that holds the
  only clock; through `Logex.Runner` each step and accept's forecast are given the time
  since the last round on the runner's clock, 0 while tripped. The maintainer's example
  is a test on the manual clock, the fan cut to 20 ms at 95 next due at 100 with no
  overlap and no extra round, and the test that pinned the missed period now pins the
  cut counted from the edit. Its mutation table, every rule reverted alone in a copy of
  the tree and the full suite judged by its exit code, three at a time: 11 rules, all
  red, each failing a test of its own that names it (decision 40 reading the resource's
  `now`; accept's forecast, test's and untest's time ignored, each alone; the time not
  checked; untest checking the generation before it, and accept the candidate before it;
  the runner's step time 0 while running, read on the clock while tripped, not handed to
  accept, and not passed to a step); run three at a time, some rows also failed a slow
  real-clock test by its timeout, as an unmutated copy did once, which is not counted.
  Its verification found two rules no row reverted alone: test checking the generation
  before the time, and the runner passing the step time to a test but not to an untest,
  whose untest the existing tests took where both times give one answer. Each now has a
  test that fails on that mutant, which the full suite judges red, as it does untest's
  order and the runner passing no step time to either again. 1529 tests pass on Elixir
  1.20.4 (9 of them doctests), up from 1524.
- **M4-6 · The contract walk.** `api_contract_test.exs` gains a runner walk on the manual
  clock: seeded configurations with and without untimed programs, simulated devices that
  report and that do not, random waits and presses, injected faults, edits, forces and
  restarts, checked against a model that calls `cycle/3` directly with the recorded times
  and inputs, and a model of the watchdogs and the trip that knows nothing of the runner.
  *Done when* its reach is asserted, every event kind and every trip reason reached but
  `{:internal, message}`, which the host contract makes unreachable from a walk and M4-4
  reaches through its seam.

  **Status: DONE — landed 2026-10-19**, as three commits: (1) the fix the walk found,
  `81fedcb`; (2) the walk, `c591faa`; (3) these documents. 1531 tests pass on Elixir
  1.20.4 (9 of them doctests), up from 1529.

  The walk is `Logex.ApiContractTest.RunnerWalk`, a module of its own in
  `api_contract_test.exs`, so that it runs beside `Logex.ApiContractTest` rather than
  after its eleven walks: 30 seeded configurations of a fast task, now and then a slow
  one, an event task on a panel's or a drive's input, one on a trigger logic writes and
  the continuous task, about three in four with an untimed counter (22 of the 30 at its
  seed); each device reporting or only read;
  a forces file or none; and 70 steps each of waits, presses, forces and unforces, an
  online edit's steps, host mistakes, restarts, a crash and a fresh start from the forces
  file, and injected faults, a step slow by about a watchdog, a slow request, the runner
  stuck, a device killed or hung, and every way `Logex.IO.Sim` fails a read, a report or
  a write. The hidden seam, `steps:`, stands in a module that runs each step as the core
  does and tells the walk the elapsed time and inputs the runner gave the core; the model
  calls `cycle/3` with them, and each round's events, outputs and resource, each edit's
  report at the step's time, each restart and, after every step, `status/1`, `get/2` and
  each device's outputs must be the model's. The times and inputs are checked too, by
  the rules restated: the elapsed time the clock's since the last round, a forced input
  its force, a reporting device's input its value now and a read device's one it held
  within two poll periods, a scheduled round exactly when decisions 122 and 123 or the
  next due time put it, and a force of a trigger its round at once (decision 138). A
  model of the watchdogs and the trip gives each injected fault's reason, and every
  output is 0 once at a trip and nothing is written until the restart. The first walk
  runs again from fresh processes and repeats exactly. Its reach is asserted: every event
  kind, every trip reason but `{:internal, message}`, and 41 kinds of round, step, fault
  and mistake. No step reads the real clock, but the runner's waits for its devices are
  in real time (decision 125), which its review found the walk's margins too thin for;
  the times and seed families as its review left them are below. At this seed every
  atom is reached.

  Its mutation table (`c591faa`'s message): 58 mutants of `lib/`, each applied alone in a
  copy and the full suite judged by its exit code, 57 red and one green, equivalent (a
  round's inputs kept for the next, merged again at the same values). The walk fails 47
  of them, and every one but one also fails a per-rule test, mostly in `trip_test.exs`,
  `runner_test.exs`, `force_test.exs` and `runner_edit_test.exs`, which the table names;
  the one only the walk catches is a round that trips the continuous task's watchdog
  recording no longest run in `status/1`. The fix's three rules, reverted, fail the walk
  alone once the fix's own test is taken out *(until decision 142, since which they are
  equivalent, below)*. The ten it misses are each caught by a
  per-rule test, most of them out of the walk's reach by design: a write delayed, a
  host's call waiting for a slot, two bad addresses in one read, or equivalent on the
  manual clock.

  **The bug it found** (fixed in `81fedcb`, with a test in `trip_test.exs` that fails on
  its parent). A device took every change it passed on into the image it compares its
  reads with, whether the runner took the change or refused it as an I/O fault (decision
  114). So a card that goes on giving a value that does not fit, a broken encoder on the
  drive, tripped the runner once; after the restart its reads matched that image, nothing
  was passed on, and the runner ran on with the last speed it had taken, never tripping
  again. And a report refused for one bad value lost the good change beside it for good.
  The runner now answers a refused change `{:error, cause}`, and the device takes only a
  change the runner answered `:ok`, so its next read passes a refused one on again.
  Decision 114 makes each read's bad value a fault, so the record was not silent.

  **Its review** (of `e6b7410`, fixed 2026-10-20, four commits, these documents and a
  fifth commit, the last, which the fixes' own load runs called for):
  1533 tests pass on Elixir 1.20.4 (9 of them doctests), up from 1531.
  1. *The walk could fail under load* (`763503a`). The runner waits for an open or a
     close for the idle watchdog and a poll period, in real time, and the walk drew an
     idle watchdog of 60 or 80 ms: beside three suites an open missed its wait, `{:io_init,
     "drive", :timeout}`, once in about 24 runs. It now draws 400 or 500 ms, and in about
     one start in six makes the first device opened late by 100 ms in real time, as a
     loaded machine is, which must trip nothing; with the old draws that stand-in fails
     as the review's run did. A hung device, whose trip waits up to that long, is injected
     in a third of the walks. The first fix, 300 or 400 ms with a stand-in of 150 ms,
     failed once in 6 runs of three suites at once on 4 cores, and once more, with the
     trip tests below, in 9 such runs instrumented: under that load an open alone took up
     to about 240 ms, the start of two devices 478 ms, so the fifth commit took the
     margin to 400 or 500 ms. The moduledoc states each real-time wait and its margin; a
     round's write keeps the least, what its step's deadline leaves on the manual clock,
     a poll period, 3 to 8 ms, where a step takes its watchdog exactly, which no load run
     missed and which a margin of the walk's cannot widen without changing the rule it
     tests.
  2. *A restart's refusal lost no reason the suite saw* (`98126e0`). Every restart a
     device refused said `:refused`, so a runner that answered `{:io_init, device,
     :refused}` whatever the device said passed. `trip_test.exs` now restarts past a
     device that answers `:unplugged` and then `{:no_route, 3}`, and the walk draws the
     reason; that mutant fails both.
  3. *Older real-time windows* (`d056e00`). Beside the walk, under load, three older
     tests failed now and then: `trip_test.exs`'s device that cannot be opened at start,
     at `idle: 20` (now 300; under six CPU burners the old test failed 3 runs of 3 with
     `:timeout`, the new one passed 3 of 3); `runner_edit_test.exs`'s traced accept, at
     ExUnit's 100 ms, which it takes 106 ms for alone (now 5 s); and `runner_test.exs`'s
     100,000 rounds, about 15 s alone, at ExUnit's 60 s (now 300 s). The walk stays
     async, so it adds no module to the suite's critical path. The fixes' load runs
     found two more of the kind in `trip_test.exs`, a device hung inside its read on the
     real clock at `idle: 50`, which tripped on the panel's heartbeat instead, and a
     device that cannot be opened again after the others' release at `idle: 30`, whose
     drive's open timed out; the fifth commit gives them and the two other tests of a short
     real-time deadline at `idle: 30` 300 ms. At its tip 9 runs of three suites at once
     on 4 cores all passed.
  4. *The input check loosened for good* (`fada5ca`). A read device's input was allowed
     two poll periods and the most time ever passed inside a step, which an idle
     injection raised to four times its lag for the rest of the walk. Each pass on the
     manual clock is now recorded with its time, and a check allows two poll periods and
     the time of each pass that ended within the window, which widens it in turn, and no
     more. A test of the check's own gives the core a read device's change late, from the
     first pass, by that pass's time less 10 ms, never later than the old allowance but
     later than two poll periods once the pass is behind it: it is caught in its first
     walk, and with the running maximum put back in none of 20.
  5. *Two numbers* (these documents). "Half with untimed programs" was about three in
     four, 22 of the 30 at the seed. The suite's time, measured three times each on one
     machine, one after another: 62.2, 65.2 and 68.1 s at `c7b0d1a`, 68.0, 70.3 and
     68.5 s at the fixes' tip before the fifth commit, so the review's fixes cost about
     3 s of wall time, within the runs' spread; after it the walk alone takes 5.6 to
     10.6 s over 31 seed families, 7.1 s at its own, most of it hung devices' real-time
     waits, and the check's own test about 1 s. Over 30 other seed families every walk
     passed and 22 reached every atom, the rest missing one: an interval cut a while
     after the last round (decision 139) in eight and a step taken while tripped in
     one.

  **A question for the maintainer** (answered 2026-10-20: (b), "Read cards first", then
  built, decision 142; it had been built as (a), as the record said). A
  *trip* stops the plant: every output switched off once, nothing run until a person
  presses restart. A *round* is one pass of the controller over its programs: the inputs
  read, the programs run, the outputs written. A *device* is an I/O card the controller
  reads and writes; one that cannot report its changes is read every *poll period*, 10 ms
  unless set.
  1. *Whether a restart reads every device before its first round.* The conveyor runs,
     the fan with it and the run lamp lit, and the drive's card starts giving a speed no
     dint holds. The controller trips: the conveyor, the fan and the lamp go off. The
     operator presses restart without the card mended. (a) As built: the restart lets
     every card go and runs its first round at once on the last values the controller
     took, so the conveyor's contactor and the fan pull in and the lamp lights; at the
     drive card's next read, within a poll period, the bad value trips the controller
     again and everything goes off. The operator sees the plant start and stop again in
     10 ms, a click of the contactors, and the trip screen again. (b) A restart reads
     every card once before its first round, as a start does, and one whose read fails or
     gives a value that does not fit leaves the controller tripped with its first reason,
     the restart answered with the card's fault, as a card that cannot be opened again
     answers it now (decision 136): nothing switches on, and the operator is told which
     card is at fault. (c) As (a), but the first round's outputs held back until every
     card has been read once since the restart: nothing switches on, the restart is taken
     and then trips again within a poll period. IEC 61131-3 says nothing of a restart
     after an I/O fault. In Logix a module whose connection faulted is reconnected before
     its inputs are used, and a major fault is cleared before the controller goes back to
     run (from memory, **unverified** in the manuals saved; since **verified** for a
     module set to "Major Fault On Controller If Connection Fails While in Run Mode": at
     the transition from Program to Run *"the controller makes one attempt to connect to
     a module"*, and where none occurs *"a fault occurs because at least one required
     connection is not established before going to Run mode. This is a 3/23 type fault
     code"*, 1756-PM015Q, Sept 2025, p.12; a module without that setting is not waited
     for). Recommended: (b), the same rule as a start, which the record has; nothing is
     switched on from a value the controller knows may be bad.
     *Answered: (b), "Read cards first"* (the maintainer, 2026-10-20), then built
     (decision 142): a restart reads every device once, in device-name order, as a start
     does, before its first round; one whose read fails, an error, a raise, a throw, an
     exit, a value that does not fit, an address that is no input point's, no answer in
     time or a process gone down, leaves the runner tripped with its first reason, the
     restart answered `{:error, {:io_init, device, cause}}`, the answer a device a restart
     cannot open gives (decision 136), and every device that answers latched again and
     written 0 once more, as decision 136 has it.

  **Decision 142, built** (2026-10-20), as two commits: (1) the code, its tests and the
  walk, with decision 142's record, `0cb2b61`; (2) these documents, with the record's
  claims of Logix checked against the manuals (below). 1538 tests pass on Elixir 1.20.4
  (9 of them doctests), up from 1533. `restart/2` releases every latch and then reads
  every device once, in device-name order: one up through its process's `reread/1`, one
  down opened again. `trip_test.exs` pins a card still bad leaving the runner tripped and
  written only 0, cold and warm, a card put right letting it run on what it gives now,
  read by no poll, each kind of read fault in the card's words, a card hung in the read
  killed and opened again at the next restart, and the first in device-name order; the
  walk refuses a restart now and then through a device up whose read fails, and holds a
  start's and a restart's first round to every device as it is then. Its mutation table
  (`0cb2b61`'s message): 13 mutants, each applied alone in a copy and the full suite
  judged by its exit code; the ten of decision 142's rules all red, the walk alone failing
  four of them, one, a device that kept its old image after the reread, the walk only; and
  M4-6's fix's three rules (above) green, equivalent since: a refusal always trips, and a
  restart now reads every device whole, so a device's image after a refusal no longer
  shows in any run, and the fix's own test now pins decision 142. Two rules first written
  were equivalent mutants and taken out: the runner marking down a device that did not
  answer its read, which its trapped exit does, and moving its heard time, which its
  "back" notices do.

  **Decision 142, verified** (2026-10-20, M4-6's third verification): the claim above that
  M4-6's fix's three rules were equivalent was false, and so was `0cb2b61`'s message,
  which made it. A device still took a restart's read as what it had passed on before the
  runner checked it, so an address that is no input point's, which no good read gives
  again, stayed in its image after the restart was refused, and the same fault read
  later was never passed on; and with any of the fix's three rules reverted a poll's
  refused change did the same across a restart. And a change a device read before a
  restart, waiting in the runner's mailbox behind it, was taken after the restart: a bad
  one tripped the runner just after a restart answered `:ok`, a good one put an older
  value over what the restart read, in the runner and in the device. Now what a device
  read at a restart is what it last passed on only once the runner has taken it, by a
  cast, `taken/2`, and each change carries the count of restarts it was read under, as a
  notice does, one from before the last restart answered `:stale` and taken by neither.
  `trip_test.exs` pins each, and a restart's read as the value an unforce puts back,
  which no test checked. Its mutation table, each applied alone in a copy, the full suite
  judged by its exit code: the fix's three rules, F1 to F3, now red; the reread taken
  before it is checked, red; no `taken/2`, red (the walk too); a stale change taken, red;
  the device taking a stale change, red; a restart's read not kept as each point's last
  value, red; a change carrying no count, red (the walk too); and `taken/2` replacing the
  image rather than merging into it, green, equivalent with `Logex.IO.Sim`, whose every
  read gives every input point (with an adapter that reads some, a point the restart's
  read left out would be passed on again once, unchanged). The walk, under the seed
  families `{2027, 3}` and `{2031, 7}` that found the first, passes all 30 walks. 1542
  tests pass on Elixir 1.20.4 (9 of them doctests), up from 1538.

  **Decision 142, verified again** (2026-10-20, M4-6's fourth verification): the count
  of restarts a change carries did not close the window it was for. A device heard the
  new count at its release, and the runner releases every device before it reads any
  again, so a reading a device took while the runner read the devices before it carried
  the new count, waited behind the restart and was taken after it, over the device's own
  newer reread: a bad one tripped the runner just after the restart answered `:ok`, on
  the manual clock and the real one. And a poll a device handled between its reread's
  answer and `taken/2` was compared against the image from before the restart, so a
  reading that differed only from the reread was lost. Now, from its release until the
  runner has taken its reread, a device passes nothing on, by a poll or a report: a
  reading before its reread is dropped, older than it, and one after it held, merged
  with any other, and passed on against the image the reread leaves once `taken/2`
  comes; a zero, a refused restart's, ends the hold. `trip_test.exs` pins each repro, a
  bad and an older reading in that window by a poll and by a report, on the manual
  clock and the real one, a reading between the reread and its taking, two of some
  points each merged, a restart's read of some points keeping the rest of the device's
  image with an adapter that reads some (so that `taken/2` replacing the image, which
  the paragraph above found equivalent with `Logex.IO.Sim`, is red), and a device whose
  restart is refused passing its changes on while tripped. README's "On the clock" now
  prints the status fields as a keyword list in a fixed order, the run repeated ten
  times from a built tree, every output the same. Its mutation table, each applied alone
  in a copy, the full suite judged by its exit code, every one red, and only by the new
  tests: the whole fix reverted (three tests); a reading before the reread passed on
  (two); a reading after it passed on at once, against the old image (one); `taken/2`
  replacing the image (one, the partial adapter's); a zero not ending the hold (one);
  `taken/2` passing nothing held (two); held readings replaced rather than merged (one);
  a report passed on unheld (one); a poll passed on unheld (three); and a release that
  starts no hold (two). 1548 tests pass on Elixir 1.20.4 (9 of them doctests), up from
  1542.

  **Decision 142, verified a third time** (2026-10-20, M4-6's fifth verification): the
  hold did not reach a report that waited in a device's mailbox while the device waited
  on the runner for its own change. That wait takes only the runner's answers and
  requests, so a report sent before the restart, or after the device's release and
  before its reread, was overtaken by the release, the reread and `taken/2`, handled
  once the stale change was answered, with the hold over, and passed on over what the
  reread read, the input wrong until the next poll, on the manual clock every run and on
  the real clock 200 runs in 200. It was there before the fourth verification's fix too.
  Now a reread that answers sends the device a fence, a message to itself behind every
  one already in its mailbox, and a report the device handles before that fence is
  older than the reread and dropped, the adapter's state kept; a fence an older reread
  sent, overtaken by a second restart's, is passed over. `trip_test.exs` pins it, the
  report sent before the release, before the reread, and before a refused restart that
  a second follows while the device waits throughout, with a report after the restart
  still passed on. Its mutation table, each applied alone in a copy, the full suite
  judged by its exit code, every one red by the new test: the fix reverted, a report
  before the fence passed on; the fence never lifted, red by the runner walk and a
  forces test too; an older fence given to the adapter as a report; and the fence sent
  at the release rather than at the reread.
  1549 tests pass on Elixir 1.20.4 (9 of them doctests), up from 1548.

  **Decision 142, verified a fourth time** (2026-10-20, M4-6's sixth verification): the
  fence was sent once the reread had read, so a report the device was sent while its
  adapter read, a message that may give what the read's sample missed, came before the
  fence and was dropped as older than the read, the input wrong until the next poll, and
  for good where the read does not give that point; with an adapter that is sent such a
  message as it reads, every run in 200 on the real clock. Now the reread sends the fence
  just before it reads, so a report in the mailbox before it was sent before the read
  began and is dropped, and one sent while the adapter reads is held and passed on once
  the reread is taken. `trip_test.exs` pins it on the manual clock. Its mutation table,
  each applied alone in a copy, the full suite judged by its exit code: the fence sent
  once the read is done, red by the new test alone; the fence sent but not kept, red by
  the fifth verification's test; no fence sent, the device waiting on one, red (four
  tests, the runner walk and a forces test among them); and a reread that fails keeping
  its fence too, green, since that only drops a report handled before it by a runner the
  refused restart leaves tripped, which the next restart's read replaces for every point
  the read gives. And the trip test whose 509 ms half found the runner tripped under load
  was a real-time margin, not a race: the panel, written after the drive's 509 ms write,
  had the shared deadline's last millisecond to answer in, a millisecond of real time on
  the manual clock, and tripped `{:io, "panel", :timeout}` 6 runs in 3000 under load; the
  half now writes the drive alone, 0 runs in 3000 under a heavier load, and still fails
  where an answer a millisecond early is judged late. 1550 tests pass on Elixir 1.20.4 (9
  of them doctests), up from 1549.

  **Decision 142, verified a fifth time** (2026-10-20, M4-6's seventh verification): a
  device dropped every reading between its release and its reread, safe only for the
  points the reread gives; `Logex.IO`'s `read/1` gives some or all of a device's points,
  so a report of a point the adapter's read leaves out, arriving in that window, was lost
  for good, the input wrong until that point was reported again. The lead treated it as a
  bug fix within decision 142, not a new policy, which the maintainer confirmed on
  2026-10-20: a device now holds every reading
  from its release, merged, and its reread answers with the read merged over them, so
  the read supersedes a reading for each point it gives, and each point it leaves out is
  given with its answer, which the runner checks as the restart's own read, a bad one
  refusing the restart with that device's fault, `{:io_init, device, cause}`, a good one
  among what the first round reads. `trip_test.exs` pins the verifier's repro, a bad
  report-only reading in the window (a value that does not fit and an address that is no
  input point's) refusing the restart, a report-only reading passed on before the release
  still stale, and an adapter whose reread gives one point, the other, both or neither,
  each against reports of both. Its mutation table, each applied alone in a copy, the
  full suite judged by its exit code: the window's readings dropped again, red (three
  tests); the reread answering its read alone, red (three); the readings merged over the
  read, red (two, the fourth verification's among them); the readings passed on after
  `taken/2` instead of with the answer, red (four); the runner taking a stale change, red
  (three, the new stale test among them); and the device taking a stale change into its
  image, red (three). The fence and its drop were kept as they were, so a report the
  device handles late, having waited on the runner, of a point the reread leaves out, was
  still lost, which the sixth verification below closes. 1554 tests pass on Elixir 1.20.4
  (9 of them doctests), up from 1550.

  **Decision 142, verified a sixth time** (2026-10-20, M4-6's eighth verification): a
  report-only reading was still lost three ways, in an ordinary race around a restart on
  the real clock in 200 runs of 200: a change passed on before the release, answered
  `:stale`, was dropped although the reread did not give its point; a report the device
  handled late, before the fence, was dropped whole, whether sent before the release or
  after it; and a restart refused, on the device's own reread or another device's, ended
  the hold and dropped what it held, though the same reading a moment before the
  release was taken while tripped. Two of the fifth verification's tests pinned the loss
  as correct. Now a device keeps each point's newest reading the runner has not taken,
  and passes on what of it differs from what the runner last took: its reread answers
  with the read merged over all of them; a report before the fence is dropped only for
  the points the reread, or a poll since, gives; a reread the runner refuses is told its
  cause, `Device.refused/2`, the refused point's reading dropped and the rest held; a
  zero that ends a hold passes on what was held; and a change refused in a round keeps
  its other points, passed on at the next reading, only a read that gives the refused
  point passing it on again, a call of the lead's that the maintainer confirmed on
  2026-10-20, decision 143. `trip_test.exs` pins the three losses (the stale change now
  given with the read, reports handled late against a reread of none or one of their
  points, a restart refused on another device with and without a stale change, a bad
  report in the window now keeping its good point) and the refused change's rest; the
  verifier's real-clock repros lose none in 200. Its mutation table, each applied alone
  in a copy, the full suite judged by its exit code: the reread answering its read
  alone, red (four decision-142 tests); a report before the fence dropped whole, red
  (two); a poll's read while the fence is up not marking its points, red (one, the new
  poll-and-fence test); a zero ending a hold without passing it on, red (two, and the
  runner walk); the runner not telling the device a refused reread's cause, red (one);
  the device keeping the refused point's reading from a refused reread, red (one); a
  change refused in a round keeping its refused point, red (two, and the runner walk);
  the device's untaken readings not set aside at its reread, red (seven); and a reading
  passed on while held, red (six, and the runner walk). A held device's passing on at
  the zero's message, checked against a hold since, was green, equivalent, since that
  message comes before any later release, and is now one clause. 1558 tests pass on
  Elixir 1.20.4 (9 of them doctests), up from 1554.

  **The lead's two calls, confirmed** (2026-10-20): the maintainer confirmed both calls
  the lead made in the verifications above, each already built: a report-only input's
  newest untaken reading surviving a restart, a bad one refusing it with its card's
  fault and a good one going into the first round, a bug fix within decision 142; and,
  outside a restart, a change refused for one bad point keeping its other good points,
  passed on with the device's next reading, recorded as decision 143
  (`docs/organisation.md` §7). No code changed. The contract walk, whole, under the seed
  families {2026, 10}, {2027, 3}, {2029, 1}, {2031, 7} and {2033, 12}: 14 tests of 14
  pass in each, the runner walk's reach whole in 2026 and 2033 and missing only
  `:next_due_from_step` in the other three, as in the runs before it. 1558 tests
  pass on Elixir 1.20.4 (9 of them doctests), unchanged.

  **The record's claims of Logix, checked** (2026-10-20, against the manuals' current
  PDFs, `docs/organisation.md` §8): verified, outputs sent at the RPI (1756-UM058L
  pp.24–25, decisions 130 and 136), an output module's configured fault state on a
  communication fault (1756-PM015Q p.12, 1756-UM058L p.123, decisions 130 and 135), a
  force taking effect at once (1756-PM004L p.51, decision 138), the FORCE status
  indicator and forces held by the controller (1756-PM004L pp.52–53, decisions 127 and
  140), a module's Program-mode output state (1756-UM058L p.123, decision 133) and a
  major fault's outputs (1756-UM900B p.242); contradicted, a connection's timeout of four
  RPIs by default (1756-UM001Q p.158: 100 ms at least, 160 ms at the default 20 ms RPI,
  decision 134); partly verified, a task's period changed online (the TASK object's Rate,
  1756-RM018A p.276, decision 139); and not found, a forced input firing its event task
  (decision 138) and one workstation editing online at a time, which Rockwell's help
  probably contradicts (decision 141). No decision's outcome changed.

  **The ninth verification** (2026-10-20, on the record above) found decision 143's first
  option overstated: it said the kept load is the one on the screen, but while tripped no
  round runs and `get/2` reads the resource, so the screen shows the load from before the
  change under either option, and a card still bad gives the bad speed again with each
  reading, so the load passes on at no reading and the restart is refused. The option and
  its scenario now say so, the two differing only from the restart on, and the decision's
  Logix paragraph now marks verified only the two quotes of p.11, which speak of a lost
  connection: that the data holds its last value, not 0, is a reading, and whether a
  connection delivers data good in part unverified. No decision's outcome changed, and no
  code. `trip_test.exs` pins the corrected scenario, the card good on its polls and still
  bad: the load shown from before the change while tripped, taken while tripped only from
  a card good again, and a still-bad card's restart refused. Its mutation table, each
  applied alone and judged by the full suite: a tripped runner's `get!/2` reading the
  runner's merged inputs, red 2, the new test and the hidden seam's while-tripped test; a
  device keeping a refused point's reading, red 3; one dropping the whole change, red 2;
  and one passing the rest on at once, not at its next reading, red 2: the new test red
  under each, the refused-change test beside it under the last three. 1559 tests pass on
  Elixir 1.20.4 (9 of them doctests).
- **M4-7 · The documents.** README's "Running a plant on the clock", with a real run, and
  "What logex is not", plainly; CLAUDE.md's Key Files; `docs/organisation.md` §4.5's
  adapter contract, §4.6's watchdog paragraph, §5's row and decision 14's annotation, as
  landed; and this status.

  **Landed** (2026-10-20), as three commits and a fourth for its review, no code in
  `lib/` changed. README: "On the clock" is
  "Running a plant on the clock", its three runs on the manual clock re-run on the tip,
  their output unchanged, and a fourth, `on_the_real_clock.exs`, the plant on the
  machine's clock: start pressed, three boxes passed, a second's run and a stop, its
  keyword list the same in five runs of five and its figures, said to be that run's,
  1,227 rounds in 1,231 ms, no period reported missed, and no more rounds than
  milliseconds, an average the rule needs but which does not prove it; with the spike's lateness and
  cost figures, for sizing a watchdog, and what is not guaranteed. A new section, "What
  logex is not": not a safety controller, not hard real-time, not certified, not a full
  guarantee of outputs off (a hung device's are the device's, and a VM that stops writes
  nothing), not a compiler to BEAM, no adapter for real I/O but the host's, not IEC
  61131-3's text, and what a controller has that logex lacks (one resource, bool and dint
  only, a forward jump only, no retained values, no output forcing), each checked against
  the code. The "Settled, not yet landed" bullet that still said M4-4 and M4-5 were to
  land is gone, and the intro names the runner. `docs/organisation.md`: §4.5, §4.6, §5's
  two rows, the runner's and forcing's, and decision 14 annotated as landed, and §4.11's
  two paragraphs for README marked said. CLAUDE.md's Key Files: README's sections and
  what stales them, and the status of `docs/organisation.md`. 1559 tests pass on Elixir
  1.20.4 (9 of them doctests), unchanged.

  Its review's fixes (2026-10-20): README's "What logex is not" and §4.6 say that a
  reported pulse is missed too, unless it is an event task's trigger or a round runs
  while it holds, the runner keeping only each input's latest value; §4.5's note says a
  trip latches a device, open for `restart/2`, and a stop or the runner's death closes
  it; README's real-clock run prints `no_more_rounds_than_milliseconds` for what it
  checks, run again, and says which real-clock tests the suite has; §5's row groups
  decision 128 with M4-1's review; and three tests check more, the plant's 2 s run on the
  real clock no more rounds than milliseconds, and a continuous round's watchdog trip and
  a report's fault each every output 0 once and nothing after, so that the table below
  cites no test for what it does not check.

  **Milestone 4's done sentence, checked** (2026-10-20, on M4-7's tip), clause by clause,
  with the test that shows each; a test named here is in `test/logex/`.

  | Clause | Shown by |
  |---|---|
  | §4.4's plant, from files on disk with a box counter in its continuous task, runs on the real clock through bound devices | `end_to_end_test.exs`, "on the real clock the plant runs for 2 s and stops in order": liveness only, running and untripped, 20 rounds at least, `now` 500 ms at least, `k1` on, and every output's last write 0 at the stop. README's `on_the_real_clock.exs` is a run, not a test |
  | its untimed programs back to back, one round a clock millisecond at most | on the manual clock, `runner_test.exs`, "while untimed programs exist, one round each clock millisecond, advance(n) running n, the first at once", "a round that takes a millisecond or more is followed at once, a wake on the clock" and "a round counts a millisecond at least". On the real clock only on average: the 2 s test asserts 20 rounds at least and no more rounds than milliseconds, `rounds <= now + 1`, as README's run prints; **no test asserts it round by round on the real clock** |
  | with the runner's share kept | on the manual clock, `runner_test.exs`, "the share's slots: after C ms of rounds that fill their milliseconds the runner serves the requests that waited, at 10%, 20%, 50% and 90%", "a slot serves the runner's own work for up to S ms, each request whole" and "the timed tasks' runs are left out of the share's count". None on the real clock |
  | each timed task's runs never before their times on its grid | on the manual clock, `api_contract_test.exs`'s runner walk, `Logex.ApiContractTest.RunnerWalk`, which checks after every step when each scheduled round comes, never before a step it waited; and `runner_test.exs`, "rounds on a periodic task keep their grid, absolute, a slow write's time not counted: 100,000 rounds, every one on time", which counts the rounds and checks none missed, not when each came; on the real clock only the clock's own rule, `clock_test.exs`, "wakes a process once, no sooner than its time, and a time already past at once". **No test runs a timed task on the real clock and checks its times** |
  | its runs and the periods it reports missed together one for each grid time passed | on the manual clock, the 100,000 rounds above, every grid time a run and none missed, and `runner_test.exs`, "subscribe/2: the resource's overlaps and faults by default, …", a 25 ms write making the run at 25 and `{:overlap, "fast", 1}` for the grid time at 20; and the runner walk against `cycle/3`. **None on the real clock** |
  | a host test drives the same plant on a manual clock with simulated devices, one reporting its changes and one only read, its outputs and events exactly those `cycle/3` gives for the same times and inputs | `end_to_end_test.exs`, "M4-3's Done-when: the plant through the runner on the manual clock, round for round the oracle's, from files on disk, repeating exactly", 600 seeded presses and waits; and `api_contract_test.exs`'s runner walk, `Logex.ApiContractTest.RunnerWalk`, over seeded configurations |
  | with no untimed program the plant rounds only when a task is due or a trigger changes | `runner_test.exs`, "with no untimed program, a round only at a due time or a trigger's change", on a configuration of a 10 ms relay and an event task over a panel that reports and a drive only read, **not §4.4's plant itself**, whose box counter is untimed; and the runner walk's configurations with no untimed program, about one in four |
  | a task that outlasts its watchdog leaves every output that can still be written at 0, written once | `trip_test.exs`, "a timed task's run that outlasts its watchdog trips before its round's write, naming it; one that takes exactly its watchdog does not", its panel's writes exactly the two zeros, and "a round that outlasts the continuous task's watchdog trips, naming each step with its time, …", its panel's output 0 once after the last count and nothing after (checked since M4-7's review) |
  | a device that fails does too | `trip_test.exs`, "each kind of fault in a poll's read trips, naming its device, every device written 0 once and nothing after", "a report's fault trips, naming its device, every device written 0 once and nothing after" (checked since M4-7's review) and "a round's write that fails trips, the devices after it not written, and the device that failed zeroed where it still takes a write" |
  | a runner that is stopped does too | `runner_test.exs`, "stop/2 writes every output 0 once and closes every device before it returns (decision 116)" |
  | a runner stuck does too | `trip_test.exs`, "a runner stuck in the conveyor's 50 ms step leaves every device at 0 within 50 ms and a poll period of the step's start, not before" and "a runner stuck in its own work leaves every device at 0 within its idle watchdog and a poll period, …" |
  | a runner killed does too | `trip_test.exs`, "a killed runner's devices write every output 0 once and close" and "a runner that crashes zeroes and closes every device, and its supervisor does not start it again" |
  | a tripped runner runs nothing again until the host restarts it | `trip_test.exs`, "while tripped a device's change is merged and makes no round, and a host's request is served at once", "a latched device writes nothing again at its polls, and a tripped runner refreshes no device" and "cold and warm each release the latches, restart the resource and run the first round at once, the clock not counting the stopped time" |
  | one stopped or killed is gone, its child spec `restart: :temporary` | `runner_test.exs`, "its child spec starts it once: restart: :temporary (decision 115)"; `trip_test.exs`, the crash test above, its supervisor starting nothing again |
  | a forced input holds across a restart and, kept in its file, across a crash and a fresh start | `end_to_end_test.exs`, "M4-5's Done-when: the photo-eye forced, against its device, across a restart, a crash and a fresh start from its forces file"; `force_test.exs`, "a runner killed while an input is forced, started again from the same file, comes back with it forced and listed, from its first round" |
  | an online edit is stepped through the running runner between rounds | `end_to_end_test.exs`, "M4-5's Done-when: the plant edited through the runner, every report and round the same steps give over the resource directly, from files on disk"; `runner_edit_test.exs` |

  So every clause is shown by a test on the manual clock, and the three of timing on the
  real clock, rounds back to back one a millisecond at most, the share and the grid with
  its missed periods, are not: the done sentence puts them on the plant's run on the
  real clock, and they are met there only under the milestone's own rule ("every rule is
  tested on the manual clock"; a test on the real clock "asserts liveness only"), the
  real clock's own wake no sooner than its time and the 2 s run's no more rounds than
  milliseconds aside. They are not claimed of the real clock beyond that, nor beyond
  README's one run; and the clause of a plant with no untimed program is shown on a
  smaller configuration than §4.4's plant. Whether that reading of the done sentence
  stands is the maintainer's. *(The maintainer accepted it on 2026-10-20, "Done as is":
  timing proven on the manual clock, the real clock checked for liveness, as the
  milestone's own rule says, so Milestone 4 is done.)*

**Milestone 4 is done when** §4.4's plant, loaded from files on disk with a box counter in
its continuous task, runs on the real clock through bound devices, its untimed programs
back to back, one round a clock millisecond at most, with the runner's share kept, and
each timed task's runs never before their times on its grid, its runs and the periods it
reports missed together one for each grid time passed; a host test drives the same plant
on a manual clock with simulated devices, one reporting its changes and one only read, and
its outputs and events are exactly those `cycle/3` gives for the same times and inputs;
with no untimed program the plant rounds only when a task is due or a trigger changes; a
task that outlasts its watchdog, a device that fails, and a runner that is stopped, stuck
or killed each leave every output that can still be written at 0, written once; a tripped
runner runs nothing again until the host restarts it, and one stopped or killed is gone,
its child spec `restart: :temporary`, so that the host starts a new one; a forced input
holds across a restart and, kept in its file, across a crash and a fresh start; and an
online edit is stepped through the running runner between rounds. *(Reworded 2026-10-18,
after M4-1's review: "each timed task on its grid as closely as the machine allows" could
not be tested, and "nothing runs again until the host restarts it" said a stopped or
killed runner could be restarted.)*

### Milestone 5 — data types

**Designed and decided 2026-10-21** (`docs/organisation.md` §4.12 and §7, decisions
144–167; "decision N" in this section is that §7's). The maintainer asked for 1-, 2-, 4-
and 8-byte integers, how IEC and the vendors handle signed ones, 32- and 64-bit reals,
arrays of all the others, and what else IEC and the vendors have. A design pass on
`0c55e36` read IEC 61131-3 Ed 2 and Ed 3 in full, the conventional family's manuals,
Siemens, CODESYS, Schneider and MatIEC, mapped where logex assumes bool and dint, and ran
the BEAM's float behaviour on Elixir 1.20.4 / OTP 28; its review corrected eight facts
and added decision 159. The maintainer took eleven answers as recommended and changed six:
integer overflow wraps with no power, in every width, the dint's included, superseding
decision 77's saturation (146); conversions take IEC's typed names, `real_to_int`, keeping
`docs/naming.md`'s "never hide a rounding mode inside a conversion name" (148); arrays
have up to three dimensions (151); the bit strings `byte word dword lword` come now, with
`and or xor not shl shr rol ror` on bit strings and integers alike (155); arrays may be
located, one point an element at consecutive addresses (156); and the counters and timers
get typed variants, IEC's `ctu_int` to `ctud_ulint` and long timers in nanoseconds (158).
A bit number may be a tag, `status.[n]`, and one out of range trips the plant, as an index
out of range does (160, 153). §4.12 then put ten readings back to the maintainer, where
two answers meet or an answer leaves a reading open, and left three rules open for the
item that meets them, all thirteen answered on 2026-10-21: seven readings as the record
took them, each a note on its decision; three otherwise, a real too large for its
integer target rounded and then wrapped, `real_to_int` of 40000.7 giving −25535 (161),
the truncations IEC's typed `real_trunc_int` and its fifteen siblings, not `trunc_int`
(162), and `ctu_dint`, `ctd_dint` and `ctud_dint` as aliases of `ctu`, `ctd` and `ctud`
(163); and the three rules, `sqrt` of a negative source 0.0 with no power and the minor
fault `:negative_sqrt` (164), a negative shift or rotate count acting as 0 with no
power, a count of the width or more shifting everything out and a rotate's count taken
modulo the width, with no fault (165), and an integer at a real point stored as the
nearest real, only a value beyond the real's range a bad value (166).

Each item lands as Milestones 3 and 4 did: its words surveyed in `docs/naming.md` first,
before any code, each new word reserved in any case and its commit naming what programs
and configurations it breaks; a gated series, each commit gated alone by `mix format
--check-formatted`, `mix compile --force --warnings-as-errors` in both environments and
`mix test --warnings-as-errors`, judged by exit code on Elixir 1.20.4, with its mutation
table in its message, every rule it adds reverted alone and the suite judged by exit
code, every survivor given a test. Throughout:
- **Each item extends `api_contract_test.exs`'s walks with its own rules as it lands**,
  as every item since M1-6 has, its oracles restating each range, wrap and rounding rule
  in Elixir without calling `Logex.Declarations`; M5-15 is only the walks' cross-type
  reach.
- **Each item brings README and `docs/naming.md` with it**: the syntax list, the
  instruction table and an example whose output is real, re-run, and "What logex is not"
  wherever it stops being true (CLAUDE.md: "Any change to the language stales it").
- **The data API refuses what the text cannot say, and widens in the same commit as the
  syntax** (decision 97's rule): `Logex.Tag.new!/4`, `Logex.Configuration.new!/1` and
  `Logex.Parser.well_formed!/1`.
- **A new syntax form** goes into `printer_test.exs`'s generator and `@required_shapes`
  before it lands, and the golden record is regenerated only in that commit, its diff
  read.
- **No float exception and no bad index or bit number leaves a scan**: a host mistake is
  an `ArgumentError` whose message a test pins, a source mistake a diagnostic.
- **Growth is tested in reductions** where a rule walks something: an element's read and
  write against a tag's, a per-element rule against the elements, a conversion family's
  checks against the program.
- **New state** states its rule across an online edit (`Logex.Program.initial_env/1`,
  `Logex.Configuration.initial/1`, §4.9's "One rule for new state").

Sizes use the design pass's key: **S** under about 30 lines of `lib/` and its
tests, **M** 30 to 150, **L** 150 to 500, **XL** more, or a spike first.

**The order** keeps every item gated by the ones before it, and every refusal naming only
what exists: the type table first, changing nothing; the wrap next, on the one width that
exists, so that logex never has two overflow rules; the widths with the integer conversions their refusals name, then their arithmetic; the typed counters and long
timers, which need only the widths; the based literals, which a bit mask wants; the bit
strings, and then the first major fault, on a bit number, before arrays need it; the
reals; then arrays, static before run time, their points, and their instances; and last
the walks' cross-type reach and the documents.

| Item | What | Decisions | Needs | Size |
|---|---|---|---|---|
| M5-1 | One table of types, no behaviour changed | 144 (the table) | — | M |
| M5-2 | The dint wraps: decision 77 superseded on purpose | 146 | M5-1 | M |
| M5-3 | The integer widths, declared everywhere, `move` and literals by Figure 11, and the 56 integer conversions | 144, 145, 147, 148, 156, 157, 159 | M5-2 | L |
| M5-4 | Arithmetic and comparison over every width | 145, 146, 147 | M5-3 | L |
| M5-5 | Typed counters, and `ctu_dint`, `ctd_dint` and `ctud_dint` as aliases | 158, 163 | M5-4 | M |
| M5-6 | Long timers in nanoseconds | 158 | M5-3 | M |
| M5-7 | Based literals and `_` separators | 149 | M5-3 | M |
| M5-8 | Bit strings, located too, the bitwise instructions, literal bit access, the 76 bit-string conversions | 147, 148, 155, 156, 165 | M5-4, M5-7 | L |
| M5-9 | A bit number in a tag, and the major fault, the runner tripping at the end of its step | 160, 153 (the fault), 99, 113 | M5-8 | L |
| M5-10 | Reals: literals, arithmetic, faults, points, forces, the 34 real conversions, the 16 truncations `real_trunc_<integer>` and `lreal_trunc_<integer>`, `sqrt`, a real's bit refused | 147–150, 155, 156, 157, 161, 162, 164, 166 | M5-4, M5-7, M5-9 | XL |
| M5-11 | Arrays of elementary types, up to three dimensions, literal subscripts | 151, 154 (bits), 157, 159 | M5-10 | XL |
| M5-12 | Tag subscripts and the index fault | 152, 153 | M5-9, M5-11 | L |
| M5-13 | Located arrays | 156 | M5-11 | M |
| M5-14 | Arrays of instances | 154 | M5-12 | L |
| M5-15 | The contract walk's cross-type reach | all | M5-14 | L |
| M5-16 | The documents' closing pass | all | M5-15 | S |

- **M5-1 · One table of types.** `Logex.Declarations` gains the type table (§4.12, "The
  types"), with only `bool` and `dint` in it, and every range message, article, guard and
  `fits?/2` in `lib/` reads it; `Logex.Configuration.Text` reads it for its type words and
  its did-you-mean; `Logex.Edit.Plan.word/1` goes through the articles. *Done when* the
  suite passes with no pinned message changed, `lib/` holds no `[:bool, :dint]` guard and
  no hand-written "32 bits" outside the table, a test grepping for both, and each message
  built from the table is pinned for both types. *Size M.*

  **Status: DONE — landed 2026-10-21**, as two commits, the code with its tests and then
  the documents. `Logex.Declarations.table/0` holds `bool` and `dint`, each its word, its
  value in a tag, its kind (`:boolean`, `:signed`), its width in bits, its range, its zero
  and its article; `is_elementary/1`, a guard, replaces the nine `type in [:bool, :dint]`
  guards; `fits?/2` is a clause per row; `a_type/1`, `misfit/2`, `initial_misfit/2`,
  `values/1` and `either/1` build every range message and article the thirteen
  hand-written ones gave, in `Logex.Compiler`, `Logex.Configuration`, its `Text` and
  `Edit`, `Logex.Edit.Plan` (whose `word/1` goes through the articles), `Logex.Runtime`
  and `Logex.Runner`; `Logex.Configuration.Text`'s type words, keywords and did-you-mean
  are the table's, and `Logex.Program.initial_env/1` and `Logex.Configuration.initial/1`
  read its zero. `type_table_test.exs` pins the table, `fits?/2` at each limit, every
  builder, and every message built from the table for both types, each as main gave it,
  and greps `lib/` for a `[:bool, :dint]` guard, for "32 bits", "0 or 1", ":bool or
  :dint", "a `bool` or a `dint`", "-2147483648 to" and "is a dint" in code, for the
  dint's lower limit outside `Logex.Declarations`, and for an article written by hand
  before a type; 60 of its 64 mutants are red, the four survivors equivalent while every
  row has its values (a literal slot of another type, the zeros, the printed word). No pinned message changed: the suite passed
  before a test was added. A differential run, outside the repository, ran the same
  generated programs (mostly refused, so their diagnostics are compared), programs that
  compile scanned with inputs that fit and that do not, Elixir declarations, online edits
  accepted, tested, assembled and untested, configurations from text and from data,
  started, cycled, read by `get/2`, printed and edited through `Logex.Configuration.Edit`,
  against `main` and this branch: ten seeds of 2,000 draws each, 698,809 results,
  each a SHA-256 of its `:erlang.term_to_binary/1`, byte-identical, every changed message
  reached; one message changed by a space made 36,888 of one seed's results differ. It
  found, on `main` as here, an `UndefinedFunctionError` that escapes
  `Logex.Configuration.compile/3` where a program's `var_external` names a global whose
  `var_global` line is broken (`var_global estop boo`), left to its own fix.

  *M5-1's review* (2026-10-22) found no regression and three things to mend, each its
  own commit after the item's two: that `UndefinedFunctionError`, reached by any broken
  `var_global` line a `var_external` names (no type, an unknown one, an instance's, a
  location missing), now passed over so the broken line's own diagnostic is the one
  mistake (decision 42), with the text's totality property given a program type that
  reads a global through a `var_external` and a source whose line for it is broken; the
  one article still written by hand, `Logex.Configuration`'s `"a #{name}"` for a connected
  member that holds an instance, which no text reaches but a program edited by hand does,
  now `Logex.Declarations.instance_of/1`'s, "an rto"; and the grep for a hand-written
  article, widened to an article before a backticked interpolation and to `"a " <>`, its
  allowed articles a section, a configuration element's kind, a program type's name and
  a one-shot's mnemonic. It noted for M5-3 the messages that name two types as an
  example, below, and that a `put_inputs/3` of 400 inputs costs about a tenth more
  reductions for the table's lookup, still linear.
- **M5-2 · The dint wraps.** Decision 146 on the one width there is, before any other
  lands: `add`, `sub`, `mul`, `div`, `neg` and `abs` keep a result's low 32 bits, two's
  complement, and pass no power where the stored value is not the exact one, with no fault
  and no event; a zero divisor is unchanged. The change is on purpose and breaks what
  pinned the old rule, each changed in this item and named in its commit:
  `arithmetic_test.exs`'s limits (`add`, `sub` and `mul` past either limit, a product far
  past one, `div` of −2147483648 by −1, `neg` and `abs` of −2147483648), the M3-3
  Done-when in `end_to_end_test.exs` (a total driven past 2147483647, its oracle's
  `clamp`), `api_contract_test.exs`'s arithmetic oracle, the `add sub mul div neg abs`
  stanzas' logex rows (an amendment line each, the stanzas being append-only), and README's
  instruction table and "Arithmetic", the wild meter's run re-run and its bullet saying
  that the total now wraps and that a lamp after `add` is off for the one scan, so a
  program that must remember latches it. *Done when* each of those pins the wrap, a test
  of each instruction at each limit fails when the wrap is reverted to the old
  saturation, the fill valve's oracle in `end_to_end_test.exs` wraps where it clamped,
  decision 77's note says the rule changed with this commit, and no other behaviour
  changes. *Size M.*

  **Status: DONE — landed 2026-10-22**, as two commits, the code with its tests and the
  stanzas' amendments, then the documents. `Logex.Runtime`'s one rule, `wrapped/1`,
  replaces `bounded/1`: a result inside the dint is itself, with power; any other keeps
  its low 32 bits, read signed, the width from the type table's row through a new
  `Logex.Declarations.width/1`, with no power, and no fault is recorded, so `add`, `sub`,
  `mul`, `div` (the minimum by −1), `neg` and `abs` (the minimum) all wrap; a zero
  divisor and the counters, which stop at a limit (decision 71), are unchanged. Changed on
  purpose, each pinning the wrap where it pinned the stop: `arithmetic_test.exs`'s limits
  (`add`, `sub` and `mul` past either limit, a product far past one, 65536 × 65536 giving
  0, `div` of −2147483648 by −1, `neg` and `abs` of −2147483648, a total run on past the
  top, a branch group, a block's body), with two tests added, a sum that wraps to 0
  passing no power and a wrap raising no fault; `end_to_end_test.exs`'s M3-3 Done-when,
  its oracle's `clamp` now `wrap`, `Integer.mod/2` over 2^32, its total driven past
  2147483647 giving −1294967296 with `total_ok` off for that one run, the oracle checked
  against the wild run too; `api_contract_test.exs`'s arithmetic oracle, which restates
  the wrap as a remainder by 2^32 taken back into the range, independent of the code's
  bit syntax, with a reach, `:far_past`, a result more than 2^32 out; the six stanzas'
  amendment lines; and README's instruction table and "Arithmetic", whose `fill.ld`
  gains `xio total_ok otl overflow` and whose run was re-run. The mutation table, 24
  mutants each judged by the full suite's exit code, every one red: saturation put back
  (15 tests), for `add sub mul` alone (12), `div` alone (2), `neg abs` alone (3), and for
  one instruction at one limit, each of the nine (2 to 8 each); a wrap passing power (15),
  read unsigned (13), not wrapped at all (15), kept to 31 bits (14) or 64 (15), its power
  judged by the stored value (14), recorded as a fault (2); the contract oracle clamping
  (1) or leaving its remainder out of range (1), the fill oracle clamping (2), and the
  `:far_past` reach dropped (1). No growth test: the wrap is one comparison and, past a
  limit, one binary match, whatever the program. 1577 tests (9 doctests), up from 1575.

  *M5-2's review* (2026-10-22) found the wrap right against an oracle of its own, a run
  against the parent and the README re-run, 32 of its 33 mutants red, and three things
  to mend, one commit for the test and one for the documents: a source a hand-built env
  holds outside the dint, read as the integer it is, the result computed exactly and then
  wrapped, was pinned by nothing, a mutant clamping it first green, now pinned in
  `arithmetic_test.exs` (5000000000, −5000000000 and 2^70 in `add v 0 r ote k` giving
  705032704, −705032704 and 0, no power and no fault), the reading provisional, a
  question for the maintainer; the Arithmetic survey table's Add row in
  `docs/naming.md`, which still said a result stops at the nearer limit, now amended
  under the table; and this status, which counted ten single-limit mutants for nine.
  1578 tests (9 doctests).
- **The maintainer's answers of 2026-10-22** to four questions M5-1's and M5-2's
  reviews left (`docs/organisation.md` §7, decisions 168 to 171), landed the same day as
  two commits, the code with its tests and the decisions, then the documents:
  - *168, a program type's name takes no article*: "`m1` runs `motor`, which declares no
    `strat`", as a user block's type is named; its entry is gone from
    `type_table_test.exs`'s allow-list, and every other message naming a program type was
    checked and takes none already.
  - *169, a var_input or var_output that holds an instance is the host's mistake*: one
    `ArgumentError` at the configuration check, a line a tag, the program left out of
    every diagnostic; on `main` a constant or an undeclared global connected to one let a
    `FunctionClauseError` or a `Protocol.UndefinedError` escape `check/1`, now refused.
  - *170, the type table's width is in bits*: §4.12's column renamed, 1 for a bool.
  - *171, a value a state holds outside its tag's type is the host's mistake*, refused
    where the state is handed in, after its owner, every such value a line of one
    message in path order, at any depth, through a guard built from the table,
    `Logex.Declarations.is_fitting/2`: linear in the state, about five reductions a tag, a
    growth test holding 4x the tags under 4.8x; paid on every scan, so M3-5's growth test
    of a skipped rung, 0.23 of running it, is 0.30 now, its bound moved on purpose. M5-2's
    test of a source computed exactly then wrapped is replaced by its refusal, and the
    tests that pinned an integer outside a bool read by value (M1-4's contacts, a
    one-shot's and a pulse coil's storage bit, a timer's `.en`), a plain swap's narrowed
    7 (decision 26's tests, the restart under a recompile) and the edit walk's plain swap
    (now `:swap_outside`, refused, the rule restated in the walk) are changed on purpose,
    each keeping what it pinned with a value that is no integer.

  The mutation table, 17 mutants each judged by the full suite's exit code, every one
  red: no value check (12 tests), the upper limit unchecked (12) or the lower (6), a
  built-in's members not looked into (2), a user block's body (1) or its held type (1),
  the lines unsorted (2), the values checked before the owner (1), the check made
  quadratic (9, the new growth test among them, 15.8x for 4x), a value that is no integer
  refused too (20); the port check gone (1), a var_output's unchecked (1), a held user
  block unnamed (1), the refused program kept for the diagnostics (1); the article put
  back (11); and the walk's swap oracle never (1) or always (1) saying outside. 1586
  tests (9 doctests), up from 1578.

  **Questions for the maintainer** (each taken provisionally as written, the closest
  reading to the record and to Logix; answered 2026-10-22, decisions 172 to 174: the
  first and third kept, the second changed, a value that is no integer refused too):
  1. *A var_input or var_output holding an instance that nothing connects* (decision
     169). A *var_input* is a program's input, filled from a global by a *connection*
     line, `m1.run g`. The answer named the connected one; the record refuses the
     program whatever its connections, since no text could have compiled it either way.
     On the conveyor: a hand-edited `motor` whose `run` lamp output holds a timer is
     refused at start even if no line connects `m1.run`, so the operator's plant never
     starts with it, rather than starting and showing the lamp as never driven. IEC and
     Logix have no such program. The other reading refuses only a connected one and
     gives the unconnected one the usual "leaves its var_input unconnected" diagnostic.
  2. *A value that is no integer* (decision 171). The answer refuses a value outside its
     tag's type; the record refuses an integer outside the type's range, 5 in a bool or
     5,000,000,000 in a dint, and still reads a value that is no integer as before: a
     contact reads 2.5 as closed and `nil` as open, `add` reads `"x"` as 0 (M1-4, M3-3).
     On the conveyor: a host that hands in the fan's `speed` as 37.5 sees the fan run as
     if 0 were written, rather than an `ArgumentError`. IEC has no such value; Logix
     cannot store one. The other reading refuses every value `fits?/2` refuses, an
     `ArgumentError` for 37.5 too, retiring M1-4's totality for a state handed in.
  3. *Where a resource is checked* (decision 171). A `%Logex.Runtime{}` the host builds
     by hand is checked as each scan takes an instance, inside `cycle/3`, not on every
     call that takes a runtime, so a configuration edit's steps, which scan nothing,
     carry a bad value to the next cycle, which refuses it; and a global that no instance
     reads is never checked. On the conveyor: nothing an operator sees changes, since the
     runner never takes a runtime from a host; a test that hands `cycle/3` a doctored
     runtime gets the `ArgumentError` from that cycle. Checking every call would cost a
     walk of the whole resource every cycle, including the instances not due.
- **M5-3 · The integer widths.** The stanzas first, `sint int lint usint uint udint
  ulint`, `dint`'s amended (decisions 144 and 145). Each is declarable everywhere a dint
  is: a tag, a block's member, each section, `var_external` among them, a global, a
  located point (decision 156), a host's input, a value of `Logex.IO.Sim`, a force and the
  forces file. `move` and every literal follow decision 147, a refusal naming its
  conversion; the 56 conversions between integer types, `dint_to_int` and the rest
  (decision 148), each truncating and wrapping where its value does not fit, with no
  power, land here, their family stanza first, so that every refusal names one that
  exists; a `cal` formal and a connection widen, and a `var_external` binds exactly
  (decision 159); an edit of a width is refused and a changed initial value of each width
  reported (decision 157). *Done when* §4.4's plant reads its drive's speed as a `uint`
  point through the sim and moves it into a `dint`; each refusal, a literal that does not
  fit, a narrowing `move`, a sign change, a host's or a device's or a force's value that
  does not fit, a `cal` formal, a connection and a `var_external` of another width, is
  pinned in its type's words; an edit of a width is refused at its line; the messages that
  give two types as an example, "needs a type: `x bool` or `x dint`" (`Logex.Declarations`,
  `Logex.Compiler`, `Logex.Configuration.Text`) and the literal "a bool" in two of
  `Logex.Compiler`'s, are read again so that none reads as if bool and dint were every
  type there is (M5-1's review); the contract walk
  draws every width's limits, its oracle restating each range; `dint_to_sint` of 129
  gives −127 with no power, as Logix's truncation does (RM018A p.872); and the commit
  names what the seven reserved words and the 56 conversions break. *Size L.*

  **Status: DONE — landed 2026-10-22**, as four commits: the stanzas first, `sint int
  lint usint uint udint ulint` and one family stanza for the 56 conversions, its
  `**Members:**` line read as data by `naming_test.exs`, `dint`'s and `move`'s stanzas
  amended; then the code with its tests; then a test pinning the two articles below;
  then the documents. The type table holds `bool` and the eight integer widths, each row
  its kind (`:signed`, `:unsigned`), width, range, zero, article and `widens`, Figure
  11's "i" cells, read by `Logex.Declarations.widens?/2`, with `conversion/2` and
  `integers/0`. Each width is declared everywhere a dint is: a tag of each section,
  `var_external` among them, a block's member, a global from text and from data, a
  located point, a host's input, a device's value through the sim, a force and the
  forces file, every refusal in its type's words, a signed width's "does not fit in N
  bits" and an unsigned one's "is outside 0 to max". `move` computes in its
  destination's type, its source of that type or one Figure 11 widens into it, every
  other pair refused naming its conversion and a bool with an integer told that logex
  has none; a literal is judged by its slot. The 56 conversions are generated from the
  table in `Logex.Compiler` and `Logex.Runtime`, each writing its value where it fits,
  with power, and its low bits otherwise, two's complement where signed, with no power
  and no fault: `dint_to_sint` of 129 gives −127. A `cal` formal and a connection widen,
  a refusal naming the conversion, and a `var_external` binds only to a global of
  exactly its type, told so. An edit from `usint` to `uint` is refused at its line and a
  changed initial value of every width reported. The messages that gave two types as an
  example read as examples, "needs a type, as in `var x bool` or `var x dint`", logex's
  type words are listed in the table's order, a global's every width, and the two "a
  bool" of `Logex.Compiler` come from the table. The Done-when is
  `end_to_end_test.exs`'s "the integer widths in the plant (M5-3)": §4.4's plant from
  files on disk, `var_global fan_hz uint at drive.i.0` read through the sim into a
  `dint`, each value up to 65,535 whole, a force held to the uint and read back from the
  forces file, and 65,536 from the device tripping the plant as a bad value.
  `integer_width_test.exs` holds every rule above from source, among them `move` over
  all 64 ordered pairs, the 56 conversions over their limits against a wrap restated,
  and a point of each width through the runner, with the conversions' growth in
  reductions (400 against 100 rungs under 4.8x); the runtime contract walk draws
  programs of every width and a program of each width at each of its edges, its oracle
  restating each range and the wrap as a remainder by 2^N, reaching both limits of every
  width at every one of 13 seeds tried. Changed on purpose, each pinning the new rule:
  every message listing logex's type words, the configuration's keywords and its
  reserved-name refusal, `move`'s refusal of a bool and a dint (no longer "takes operands
  of one type"), the "needs a type" wording, and the tests that used `int` as an unknown
  type word (now `dintt`, or `:real` from Elixir, which M5-10 will change again).

  The mutation table, 35 mutants each judged by the full suite's exit code, every one red
  at the item's tip: `widens?/2` true for every pair (22 tests) or the same type only
  (7); a Figure 11 cell dropped (5), a narrowing (3), a sign change (3) or an unsigned
  into a signed of its width added (3); a `usint` range one too high (15), the `lint`'s
  one short (12), an `sint` article "a" (14), an unsigned misfit in signed words (8); a
  conversion's unsigned bits read signed (4) or signed read unsigned (19), passing power
  on a wrap (21), saturating (21), writing de-energised (2), wrapping into its source
  type (6), one missing (4); a `cal` var_output widened the wrong way (1) or a formal
  exact (1); a connection's copy-in exact (1), copy-out exact (1) or widened the wrong
  way (1); a `var_external` that widens bound (4); the preset hint for a dint alone (1);
  a non-integer input for an unsigned width told its range (2); no conversion named for a
  fixed slot (1), a conversion's slot given the generic hint (1), `move` naming none
  (2); the type words sorted (14); "needs a type" as before (5); each of the two "a
  bool" written by hand (1 each), the first green until the third commit pinned it, its
  change of no message seen by no test; `naming_test.exs` reading no family members (1);
  and the contract walk's oracle clamping (1) or widening an unsigned range by one (1).
  1614 tests (9 doctests), up from 1586.

  *Provisional readings* (each a question for the maintainer, below): the arithmetic and
  comparison slots stay dints until M5-4, another width there refused with the
  conversion that bridges it; a conversion's source is exactly its `from` type; an
  unsigned width's refusal is "is outside 0 to max"; a conversion of a literal draws no
  warning; and logex's type words are listed in the table's order.

  **Questions for the maintainer** (each taken provisionally as written; answered
  2026-10-22, decisions 175 to 179: the first and fifth kept, the second, third and
  fourth changed, a conversion's source widening, the range for every width, and a
  conversion of a literal warned):
  1. *Another width in an `add` or a comparison before M5-4.* A *slot* is the place an
     instruction takes an operand; `add`'s and `eq`'s read dints. The record puts `move`
     and literals in M5-3 and the arithmetic's widening in M5-4, so M5-3 refuses `add
     fan_hz 10 speed` with a `uint` `fan_hz`, telling the programmer to convert it first,
     `uint_to_dint`. On the conveyor: an engineer who adds a fan's `uint` register to a
     dint offset gets a compile error naming the conversion and writes one extra rung
     until M5-4; the operator sees nothing different. The other reading lets a `uint`
     into a dint slot now, as decision 147 would once M5-4 lands, which is what IEC's
     `ADD_DINT` and Logix's ranking both do.
  2. *A conversion's source of a narrower type.* `dint_to_int` is IEC's typed function
     DINT_TO_INT; Ed 3's rule 2 lets a typed function's input convert implicitly, so an
     `sint` could be given to `dint_to_int`. M5-3 takes the source as exactly the type
     the name says and tells the programmer the one that does the job, `sint_to_int`.
     On the conveyor: the box-count trim, an `sint`, put through `dint_to_int` is a
     compile error naming `sint_to_int`, rather than compiling and doing the same thing.
     Logix has no conversion instructions (MOV converts anything); MatIEC requires the
     exact type. *(Corrected by M5-16, 2026-10-26: Logix has no typed conversion between
     two numeric types, its MOV converting by the ranking of 1756-RM018A p.870, but it has
     TRUNC, whose destination may be any integer or real (pp.827–829), and TO_BCD and
     BCD_TO.)*
  3. *How an unsigned value that does not fit is told.* A signed width says "`40000`
     does not fit in 16 bits", as the dint always has; for an unsigned one that wording
     misleads, since −1 fits in 8 bits as a pattern, so M5-3 says "`-1` is outside 0 to
     255". On the conveyor: a host that writes −1 to the lamp-count `usint` sees "input
     `count` is a usint: -1 is outside 0 to 255". The alternative is one wording for
     both kinds, the range for every width ("is outside -32768 to 32767"), which would
     change every pinned dint message.
  4. *A conversion of a literal.* `dint_to_sint 129 trim` compiles and always writes
     −127 with no power, as `add 1 2 x` compiles with a warning that its result never
     changes. M5-3 gives the conversion no such warning. On the conveyor: an engineer who
     converts a constant by mistake sees the trim stuck at −127 and the "fits" lamp off,
     with nothing said at compile time. The other reading warns, as an all-literal
     arithmetic instruction does; IEC and Logix say nothing either way.
  5. *How `move` between a bool and an integer is refused.* Before M5-3, `move b d` with
     a bool `b` and a dint `d` was told "`move` takes operands of one type"; M5-3 tells
     it "a bool does not widen into a dint, and logex has no conversion between them",
     in the words every other narrowing `move` is told, since the record defers IEC's
     `BOOL_TO_*` and `*_TO_BOOL` (Tables 24 and 25: a contact and a coil do the work).
     The record does not ask for this wording; it was the builder's choice. On the
     conveyor: an engineer who moves the photo-eye's bool into the box count reads that
     there is no conversion, and writes `xic eye move 1 count` instead; the operator
     sees nothing different. The other reading keeps the older sentence for this one
     pair. IEC has `BOOL_TO_INT` and its kin; Logix's MOV takes no BOOL.

  **M5-3's review**, fixed on 2026-10-22, each with a test that fails when its fix is
  reverted, judged by the full suite: (1) a global a connection copies in is checked
  against its own type before the copy-in, which since decision 159 may widen into its
  var_input, so that a hand-built runtime holding 70000 in a `uint` global read by a dint
  var_input is refused by `cycle/3`, "runtime.globals holds `a` outside its type: it is a
  uint, and 70000 is outside 0 to 65535", a line each in name order, a global read twice
  told once, rather than copied on into a wider global (decision 171's reading; before
  M5-3 the two types were one, so the var_input's check covered it); its mutants, the
  check gone, the lines unsorted and a global read twice told twice, each red (1 test);
  (2) the forces file's test puts every width one past each of its limits, a file for
  each end, so that a forced `ulint` out of range in the file is refused, the review's
  surviving mutant, red now (1 test); (3) `integer_width_test.exs`'s reserved-word test
  is titled for what it checks, the type words no tag or global and the conversions no
  tag or label, a conversion being reserved in `.ld` files only, as every mnemonic is,
  and checks each conversion in upper case too. The review's other notes are for later
  items or need nothing: `Logex.Edit.Plan.changed/2`'s `!=` is noted in M5-10, and
  `dint_to_dint`, told "unknown instruction", is told as every unknown mnemonic is.
  1615 tests (9 doctests), up from 1614.
- **The maintainer's answers of 2026-10-22** to M5-3's five questions and decision 171's
  three (`docs/organisation.md` §7, decisions 172 to 179), landed the same day as two
  commits, the code with its tests and the decisions, then the documents:
  - *172, decision 169 kept*: a hand-edited program whose var_input or var_output holds
    an instance is refused whether or not it is connected; no code changed.
  - *173, a value that is no integer is the host's mistake*: 37.5, `nil`, `"x"` or a map
    in a bool or an integer tag or member is refused with decision 171's message, "it is
    a dint, and its value must be an integer, found 37.5", a bool's "only 0 or 1 fit,
    found nil", a resource's global as each scan takes it too, retiring M1-4's lenient
    reading for a state handed in; the walk is decision 171's, a guard a value, so
    linear. Changed on purpose, each keeping what it pinned with a value inside its type
    and pinning the refusal of what it read before: M1-4's contacts, the comparisons on
    a hand-built env, the one-shots' and pulse coils' storage bits, a timer's `.en` and
    hand-built bits, the arithmetic's sources and divisor that read 0, a hand-built
    timer's members, the restart under a recompile, a plain swap's map under a bool or a
    dint (now refused at its next call, where an edit's first test started it again,
    decision 26, which an integer under an instance's tag still reaches), and the edit
    walk's swap oracle.
  - *174, the checking place kept*, and *175, decision 147 kept until M5-4*: no code
    changed.
  - *176, a conversion's source widens*: `dint_to_int` takes any source Figure 11 widens
    into a dint, a tag's or a member's, and only one that does not is refused, told the
    conversion from its own type or `move`; the destination stays exact.
  - *177, every width's misfit gives its range*: "`128` is outside -128 to 127",
    "`5000000000` is outside -2147483648 to 2147483647", replacing "does not fit in N
    bits", every pinned message changed on purpose.
  - *178, a conversion of a literal warns*: "`dint_to_sint` reads a literal, `129`: its
    result never changes".
  - *179, M5-3's wording for `move` between a bool and an integer kept*: no code changed.

  The mutation table, 17 mutants each judged by the full suite's exit code, every
  one red: a value that is no integer read as before (17 tests), a global that is none
  passed (1), an integer type's told its range (8), a bool's shown unquoted (4), a
  built-in's members not looked into for one (4); the signed misfit in bits (34), with no
  value shown (6), a lint's alone (7); no conversion source widening (1), every integer
  source taken (2), the widening read backwards (1), the destination widening too (1,
  green until a test of a destination of another width was added), a member source
  never widening (1), every value slot of every instruction widening (1); no
  conversion warned (1), only the dint's (1); and the edit walk's swap oracle reading a
  value that is no integer as inside (1). One more, every read slot widening, is green
  and equivalent: every read slot takes a bool, which widens into nothing. 1617 tests (9 doctests), up from 1615. The README's `drive.exs` was run
  again and prints what the README shows.

  **Questions for the maintainer** (each taken provisionally as written, the closest
  reading to the record and to Logix; answered 2026-10-22: the first and the third
  otherwise, refused, decisions 184 and 186, the second as written, decision 185):
  1. *An instance's tag that holds no map* (decision 173). The answer refuses a value
     that is no integer in a bool or an integer tag or member. A tag that holds an
     *instance* of a function block, a timer `run_on`, is a map of its members, and one
     a host hands in holding 5 or `nil` is still read as a fresh instance, each member 0,
     as a plain swap from a dint `k` to a timer `k` leaves it (an edit's first test then
     starts it again, decision 26). On the conveyor: a host that hands in the fan's
     run-on timer as `nil` sees it read as a timer just started, its time and its done
     bit 0, so a run-on already under way starts over, rather than an `ArgumentError`. The other reading refuses it too, so
     that only a map reaches an instance's tag and a plain swap from a dint to a timer is
     refused at its next call. IEC and Logix have no such state.
  2. *How a value that is no integer is told in an integer type* (decision 173). logex
     says "it is a dint, and its value must be an integer, found 37.5", the words an input
     that is no integer is told, rather than decision 177's range, "37.5 is outside
     -2147483648 to 2147483647", which reads as if 37.5 were not between them. On the
     conveyor: a host that hands in the fan's speed as 37.5 reads that a dint's value must
     be an integer. A bool's says "only 0 or 1 fit, found 37.5" either way.
  3. *A built-in's internal member* (decision 173). A timer's `last`, the time it last
     ran, is no bool or integer member a program can name, so the check does not look at
     it, and one that is no integer adds no time, as before. On the conveyor: a host that
     hands in a timer whose `last` is `nil` sees it count from that scan. The other
     reading refuses a `last` that is no non-negative integer as the host's mistake.
- **M5-4 · Arithmetic and comparison over every integer width.** The signatures' slots take a type class, ANY_INT or ANY_NUM as data,
  unified across every operand of an instruction, so a three-operand `add` is checked
  whole; each computes in its destination's type, sources widened by decision 147, and
  wraps there (decision 146); `neg` into an unsigned destination is refused (decision
  145); `div` and `mod` keep decisions 78 and 99 in every width; comparisons of integers
  are by value. *Done when* `arithmetic_test.exs` holds every rule at
  every width's two limits, 127 + 1 in an `sint` giving −128 and 0 − 1 in a `usint` 255,
  each with no power; a three-operand mismatch fails when the unification is reverted;
  comparisons of a signed with an unsigned operand are exact at their limits; and the
  contract walk's arithmetic
  oracle covers every width from its own ranges. *Size L.*

  **Status: DONE — landed 2026-10-22**, as three commits: the stanzas' amendments first,
  the Arithmetic table, `add` with the departure decision 147 asks it to state, `sub`,
  `mul`, `div`, `mod`, `neg`, `abs`, `eq` and the seven type stanzas from `sint` to
  `ulint`; then the code with its tests; then the documents. The slots of `add sub mul div
  neg abs` and the six comparisons take IEC's ANY_NUM and `mod`'s ANY_INT, generic types
  as data in `Logex.Declarations`, each the kinds of rows it holds (`is_class/1`,
  `in_class?/2`, `a_class/1`, `class_range/1`), so that a real joins ANY_NUM by its row.
  `Logex.Compiler`'s `classed/3` holds an instruction's operands together: where it
  writes a destination of its class it computes in that type, each source tag of a type
  Figure 11 widens into it, any other told "`add` computes in `s`'s type, an sint, but `d`
  is a dint (declared on line 1): a dint does not widen into an sint, so convert it
  first, with `dint_to_sint`", and a literal source must fit it; `neg` into an unsigned
  destination is refused, told that alone; a comparison's two integers need nothing of
  each other. `Logex.Runtime` wraps each result into its destination's type, found at
  each scan in the routine's tag table (`type_at/2`), a member's by its built-in's
  schema, as a counter's kind is found, the IR unchanged; a comparison reads Elixir's
  integers, exact by value. The fixed integer slots the arithmetic and comparisons had
  are gone, and with them the hints "convert it first" and "write a dint and convert it"
  for a fixed slot. The Done-when is `arithmetic_test.exs`'s two new groups: every rule
  at every width's two limits, `add sub mul div mod` over each width's limits in its own
  type and `neg` and `abs` over the signed ones, against each range, Figure 11 and the
  wrap restated from IEC's tables, 127 + 1 in an `sint` giving −128 and 0 − 1 in a
  `usint` 255, each with no power; every Figure 11 pair computed in the destination's
  type and every other pair refused naming its conversion; the three-operand mismatch
  `add d i s`, red with the unification reverted; a literal source at each width's limits
  and one past them; `neg` into each unsigned width refused; the zero divisor and the
  minimum by −1 at every width and the remainder's sign at every signed one; a member's
  and a block's destination; the comparisons of all 64 ordered pairs of widths over their
  limits, exact by value; and the arithmetic's growth in reductions, 4x the instructions
  and tags under 4.8x. The contract walk's arithmetic gives every tag a width drawn from
  the eight, each source of a width Figure 11 widens into its destination's, its oracle
  wrapping in the destination's width, its reach a widened source and a wrap in each
  width, held at its seed and at {n, 10, 333}, n from 1 to 30, after a dividend and a
  divisor drawn for a width's minimum by −1. Changed on purpose: every message that said
  an arithmetic or comparison slot "reads a dint" says "reads a number", `mod`'s "an
  integer"; a literal source's misfit is told in its destination's type, "`add` computes
  in `d`'s type, a dint: …"; a comparison literal past a dint, `gt n 3000000000`, now
  compiles, and the compile walk's fragment is a literal past 2^64; and
  `integer_width_test.exs`'s test of another width in a dint slot pins the widening.
  Found on the way: the M5-3 contract walk drew widths from `Map.keys(@widths)`, an
  atom-keyed map whose keys come in the order of the atoms' indexes in the atom table, so
  its draws differed between a run of the one file and of the whole suite; every draw now
  reads a list, `@width_types`. README's `drive.exs` gained a `uint` doubled in a `uint`,
  an `add` and a `neg` refused, and was run again; its output is the README's.
  The mutation table, 24 mutants each judged by the full suite's exit code, every
  one red: the unification reverted (11 tests), every integer source taken (3), the
  widening read backwards (7), a literal source never held to the destination (4) or held
  to the dint (2), a literal with no type known never checked (3) or held to the dint (2);
  `neg` into an unsigned type taken (1), `abs` refused there too (3), a refused `neg` told
  its sources as well (1); a generic slot taking a bool tag (4) or member (3), `mod`
  ANY_NUM (1), no member suggested for an instance named whole (3), a bool read as of a
  class (7), the class range the signed types' alone (2); the runtime wrapping every
  result into a dint (7), a member's into a lint (1), a division's (4) or `neg`'s and
  `abs`'s (2) into a dint, a comparison read as 64 bits unsigned (2), the destination's
  type found by a linear walk of the tags (1, the growth test); the walk's oracle wrapping
  into a dint (1) and drawing no source of another width (1).
  1632 tests (9 doctests), up from 1617.

  *Provisional readings* (each a question below): a literal compared with a tag is taken
  by value whatever the tag's type, two literals each within −2^63 to 2^64 − 1; the slots'
  word in a message is the generic type's, "a number" for ANY_NUM before the reals land;
  and a `neg` refused for its unsigned destination is told that alone.

  **Questions for the maintainer** (each taken provisionally as written, the closest
  reading to the record and to Logix; answered 2026-10-22: the first otherwise, refused,
  decision 183, the second as written, decision 180, the third otherwise, a signed type
  named, decision 181, and the fourth below otherwise, refused, decision 182):
  1. *A literal compared with a narrower tag.* A comparison reads two integers by value
     whatever their types (decision 147); a literal is "judged by its slot", and a
     comparison's slot has no type of its own. logex takes `lt trim 200` with an `sint`
     `trim`, which can hold only −128 to 127, so the comparison always passes power. On
     the conveyor: an engineer who compares the fan's `sint` trim with 200 sees the lamp
     after it always lit, and nothing is said when the program compiles. The other
     readings refuse it, "`200` is outside -128 to 127", as IEC's typed `GT_SINT` would,
     its literal an SINT; or compile it with the warning a comparison of two literals
     gets, its result never changing. Logix takes it, converting both to the wider type
     and comparing.
  2. *The word for the arithmetic's slots in a message.* `add b 1 d` with a bool `b` is
     told "`add` reads a number, but `b` is a bool", and `mod b 2 d` "`mod` reads an
     integer", IEC's ANY_NUM and ANY_INT in words. Until the reals land a number is an
     integer, so the words differ only for the operator who reads them both. On the
     conveyor: an engineer who adds the photo-eye's bool into the box count reads that
     `add` reads a number. The other reading says "an integer" for both until M5-10, and
     changes `add`'s message when the reals come.
  3. *What a `neg` into an unsigned destination is told.* `neg level count` with a `usint`
     `count` is told "`neg` writes `count`, a usint, which holds no negative value: `neg`
     writes a signed type", and nothing of its source, whatever it is. On the conveyor: an
     engineer who negates the level into the box count is told to write a signed type, and
     on the next compile, if the level is a `dint` and the new destination an `int`, is
     told that the dint does not widen. The other reading names a signed type the source
     widens into, "write an int or wider", or tells both problems at once. IEC has no
     NEG; Logix's NEG into an unsigned tag is `unverified`.

  **M5-4's review**, fixed on 2026-10-22, each with a test that fails when its fix is
  reverted, judged by the full suite: (1) the destination's type is found totally, so a
  program edited by hand after it compiled, its destination's tag taken out of the
  table, retyped as a bool, or its member's instance taken out, retyped or left without
  the member, runs as it did before M5-4, computing in the dint, rather than raise
  `KeyError`, `MatchError` or `FunctionClauseError` out of `call/4` (provisional, the
  fourth question below); `runtime_test.exs`'s "a program edited by hand after it
  compiled", red with any one lookup's fallback reverted; (2) the arithmetic's growth
  is measured as two tests, the compile and the scan apart, since a scan is about 4% of
  the two together and the review's quadratic scan, a walk of the tag's keys at each
  lookup, stayed green inside the sum, red now; (3) `mul`'s amendment in
  `docs/naming.md` said that two `usint`s at 255 into an `int` give 65,025 with power, past
  an int's 32,767: they give it into a `dint`, and wrap to −511 with no power in an
  `int`, as it now says, and `neg`'s quoted refusal names the line its destination is
  declared on, as the compiler does; every worked example of the arithmetic and
  comparison amendments is a test in `arithmetic_test.exs`; (4) a `div` and a
  `mod` whose divisor is narrower than its destination, or of another kind, are pinned in
  the destination's type, an int's −32768 by an sint's −1 wrapping to −32768 with no power
  and an int's −7 mod a usint's 3 giving −1, so that a division wrapped in its divisor's
  type, the review's V7, which only the contract walk caught, is red in
  `arithmetic_test.exs`. The comment by `@sums` now says a source "outside its
  type". The review's other notes need nothing: a dint-only scan costs about 22% more
  reductions than before M5-4 and is still linear, and the real-clock tests that failed
  under three suites at once predate M5-4. The mutation table, 8 mutants each judged by
  the full suite's exit code, every one red: the name's lookup strict, the member's
  instance's lookup strict, and each of the four fallbacks, a tag's, a member's
  instance's, a member's and a type that is no integer's, gone; the review's quadratic
  scan; and its V7. 1641 tests (9 doctests), up from 1632.

  4. *A program edited by hand whose destination has no integer type.* A program is
     compiled from text; a host that changes the compiled `%Logex.Program{}`, retyping
     `d` from an `sint` to a bool or deleting it from the tag table, hands the runtime a
     program no text could give. logex runs it, computing `add 100 100 d` in the dint,
     as every arithmetic instruction did before M5-4, so `d` takes 200 with power; a value
     that then sits outside a retyped tag is refused at the next call (decision 171). On
     the conveyor: a tool that rewrites the box counter's tag table between scans sees
     the count keep counting as a dint, and the next scan refused if the count no longer
     fits. The other reading refuses such a program where it is handed in, a pinned
     `ArgumentError` naming each destination whose type is no integer, as decision 169
     refuses a hand-edited port holding an instance, at the cost of a walk of the
     program's arithmetic on every call. IEC and Logix have no compiled program a host
     can edit: Logix downloads a project whose tags and code are checked together
     (**unverified** in the extracts read, M5-16).
- **The maintainer's answers of 2026-10-22** to M5-4's four questions and to the three
  decision 173's answers left (`docs/organisation.md` §7, decisions 180 to 186), landed
  the same day as two commits, the code with its tests and the decisions, then the
  documents:
  - *180, "a number" and "an integer" kept* for the generic slots: no code changed.
  - *181, a `neg` into an unsigned destination names a signed type*: "… `neg` writes a
    signed type, so declare `count` a dint", the narrowest signed type its source widens
    into by Figure 11, or a literal source fits; a `ulint` source told to convert first,
    with `ulint_to_lint`, and declare an `lint`.
  - *182, a program edited by hand whose arithmetic destination has no integer type is
    refused where it is handed in*: "`m`'s `add` on line 7 computes in the type of `d`, a
    bool, which is no integer type: `m` was edited by hand after it compiled", a line each,
    the program's rungs in order and then each body by its block's name, by every entry
    point of `Logex.Runtime` that takes a program, `Logex.Edit.accept/3` and, after
    decision 169's ports, `Logex.Configuration.check/1`. `Logex.Program.destination/2` is
    the one rule the scan and the check (`Logex.Program.unwritable/1`) read; M5-4's
    review's fallback to the dint is gone, its tests turned into refusal tests. The cost,
    measured against `23a5136`: a scan of 2,000 contact rungs 13% more reductions, of
    2,000 `add`s 28% more, linear (a growth test), and `jump_test.exs`'s skipped rungs
    0.373 of running them where they were 0.303, its bound moved to 0.448.
  - *183, a literal compared with a tag its type cannot hold is refused*: "`lt` compares
    `200` with `s`, an sint (declared on line 1), which never holds it: `200` is outside
    -128 to 127", one rule for the six comparisons, either side, a member's type its
    schema's; a literal at the type's own limit compiles; two literals as M5-4 has them.
  - *184, an instance's tag that holds no map is refused*: "it is a ton, and its value
    must be a map of its members, found 5", a user block's "an instance of `seal`", at any
    depth, so a plain swap from a dint to a timer is refused at its next call and decision
    26's restart is reached only by a map that lacks members.
  - *185, "its value must be an integer, found 37.5" kept*: no code changed.
  - *186, a timer's `last` that is no integer is refused*: "it is a clock, and its value
    must be an integer, found nil"; any integer is taken.

  Changed on purpose: M5-4's review's hand-edited program tests (now refusals); a
  comparison literal past its tag's type in `validation_test.exs` and
  `arithmetic_test.exs`, `gt d 3000000000` refused again; `neg`'s refusal at every
  unsigned width; M1-6's timers and members on a hand-built env, a `last` that is no
  integer and a timer's tag that holds no map, in `end_to_end_test.exs`; decision 26's
  tests in `edit_test.exs` and `function_block_test.exs`, a plain swap now leaving a
  counter's map under a timer; a hand-built state with no map where an instance goes,
  now refused by every step of an edit; and the edit walk's swap oracle. docs/naming.md's
  `neg` and `eq` stanzas are amended, their worked examples tests. The README's
  `drive.exs` gained `lt hz 70000` refused and was run again.

  The mutation table, 27 mutants each judged by the full suite's exit code, 26 red and
  one equivalent: no signed type suggested (2 tests), the widest suggested (2), a literal
  always told an sint (1), a `ulint` source told nothing (2); the runtime checking no
  program (4), the edit (3), the configuration (1), held bodies not walked (1), a tag's
  own body not walked (1), a bool taken as an integer type (4), an instance of no
  built-in taken (1), a member the built-in lacks taken (1), an undeclared tag taken (2),
  the lines reversed (1), a group's legs not walked (1), a body walked at each `cal` (1),
  an undeclared member's instance taken (1); a literal beside a tag held to the class
  only (3), on the left not held (2), on the right not held (3), a literal beside a bool
  not held to the class (1, green until a test was added); a built-in's instance that is
  no map passed (7), a user block's (5); a `last` that is no integer passed (2), a
  negative `last` refused (1); and the edit walk's oracle reading an integer under a
  timer as inside (1). The equivalent: a literal beside a tag of no elementary type not
  held, which no operand reaches. 1646 tests (9 doctests), up from 1641. One gate of the
  working tree failed once on `trip_test.exs`'s "a tripped runner killed closes its
  devices", a real-clock race (`:noproc` before `:killed`) under the mutation run's load,
  green on five reruns alone and on the next gate.

  *Provisional readings* (each a question below): a comparison literal at its tag's
  type's limit compiles with no warning; a timer's `last` takes any integer; a literal
  `neg` source names the type the literal fits; and the check's cost is paid on every
  call.

  **Questions for the maintainer** (each taken provisionally as written, the closest
  reading to the record and to Logix):
  1. *A comparison whose literal is its tag's limit* (decision 183). `ge count 0` with a
     `usint` `count` always passes power, and `lt count 0` never does, though 0 is a
     value of the type, as `gt trim 127` with an `sint` `trim` never does. logex compiles
     each with no word. On the conveyor: an engineer who lights the "boxes counted" lamp
     with `ge count 0` sees it always lit, and nothing is said when the program compiles.
     The other readings warn, as two literals are warned, "its result never changes", or
     refuse it as a literal outside the type is. IEC's `GE_USINT(count, 0)` and Logix's
     GEQ take it.
  2. *A timer's `last` that is negative or later than now* (decision 186). `last`, the
     time a timer last ran on the scan's clock, takes any integer: one later than the
     scan's `now` adds no time, and a negative one adds the time from it, capped by the
     preset. On the conveyor: a host that hands in the fan's run-on timer with `last` of
     -1000 sees it count a second it never ran, at most its preset. The other reading
     refuses a `last` outside 0 to the instance's `now`, as `state.now` must be a
     non-negative integer of milliseconds. IEC and Logix have no such member a host hands
     in.
  3. *What a literal `neg` source names* (decision 181). `neg 5 count` into a `usint` is
     told "declare `count` an sint", the narrowest signed type 5 fits, and `neg 200 count`
     "an int"; `neg -128 count` "an sint", where −(−128) wraps to −128 with no power. On
     the conveyor: an engineer who negates a fixed -128 offset follows the advice and sees
     the result wrap on every scan, its lamp off. The other reading names the narrowest
     signed type the negated literal fits too, "an int" for -128. IEC has no NEG; Logix's
     is `unverified`.
  4. *The check's cost on every call* (decision 182). Every call that takes a program
     walks its rungs once for a destination with no integer type, about 5 reductions a
     rung of contacts and 15 an arithmetic instruction, so a scan costs 13% to 28% more.
     On the conveyor: a runner scanning the plant every 10 ms spends that much more of each
     scan checking a program no text can give. The other readings check only where a
     program first meets the runtime, `instance/1`, `Logex.Runtime.start/1` and an edit's
     accept, leaving a program swapped in by hand to a later scan, or keep a mark of
     programs checked, which the runtime, holding no state between calls, cannot. IEC and
     Logix check a program once, at download (**unverified** in the extracts read,
     M5-16).
- **M5-5 · Typed counters.** The stanzas, then `ctu_int ctu_lint ctu_udint ctu_ulint`,
  `ctd_*` and `ctud_*` of the same four (decision 158), rows of `Logex.FbType.rules/1`
  run by `ctu` and `ctd`, a preset judged in its instance's type, each stopping at its
  type's limits with `ov` or `un` latched, decision 71 by width, as the maintainer
  answered §4.12's fifth question; and `ctu_dint`, `ctd_dint` and `ctud_dint`, aliases of
  `ctu`, `ctd` and `ctud`, which are the same thing (decision 163), each a type word with
  its own stanza, which `naming_test.exs` checks, a declaration with either word giving
  the one type and keeping no spelling, so that every message and warning names the
  instance by the plain word. *Done when* a `ctu_int` count stops at 32,767 with `ov` on
  and a `ctd_udint` at 0 with `un` on, a `ctu_ulint` counts past 2^63, a preset outside
  its type is refused at its line, an edit that changes a counter's width is refused, its
  edge memory is on the block list as a `ctu`'s, the event task's warning names each, and
  the contract walk's counter oracle draws every width; `var boxes ctu_dint` and `var
  boxes ctu` compile to equal programs, `ctd_dint` and `ctud_dint` likewise, a test that
  fails when an alias is made a type of its own; an instance declared `ctu_dint` is named
  `ctu` in its unrun warning, its article (`instance_of/1`), the compiler's refusal of a
  second `ctu` on it, the event task's counter warning and an edit's refusal of a change to `ctu_int`, each
  pinned; an edit from `ctu` to `ctu_dint` is accepted with no report; and the commit
  names what the fifteen reserved counter words break. *Size M.*

  **Status: DONE — landed 2026-10-22**, as three commits: the fifteen stanzas first, one a
  type word, `ctu_int` to `ctud_ulint` and `ctu_dint`, `ctd_dint` and `ctud_dint`, each
  alias saying it is its plain word's; then the code with its tests; then the documents.
  The twelve typed counters are built-in types, `Logex.FbType.ctu_int/0` to
  `ctud_ulint/0`, each its kind's members with `pv` and `cv` of its integer type, named
  by its word, and each a row of `Logex.FbType.rules/1`: its kind's row with its
  `family`, the kind an instruction's slot takes (`Logex.FbType.family/1`), and its
  `counts`, the type of its `pv` and `cv`, `:dint` for the three plain counters and nil
  for a timer. The instructions stay `ctu` and `ctd`: an instance slot names kinds, so a
  `ctu` runs every up counter, and a counter of the other kind is told the up-down counter
  of its own type, "a ctd_lint only counts down; declare it `var c ctud_lint` to count
  both ways". A preset is judged in its instance's type, 0 to its top, "`ctu` takes a
  preset of 0 to 32767 for a counter of ints, found `40000`", a dint's message as before,
  and a preset from a tag is told the `move` where the tag widens into the `pv`;
  `Logex.Declarations.preset?/1`, which held a preset to the dint, is gone. The runtime
  reads a counter's kind and its limits from its type's rules, so a `ctu_int` stops at
  32767 with `ov` set and a `ctd_udint` at 0 with `un` set, decision 71 by width, at a
  cost of 2.5% more reductions a counter's run (83,277 to 85,347 for 400 counters).
  `ctu_dint`, `ctd_dint` and `ctud_dint` are keys of `Logex.FbType.builtins/0` whose
  values are the very types of `ctu`, `ctd` and `ctud` (decision 163), so a declaration
  with either word gives one type and keeps no spelling: every message and warning names
  the instance `a ctu`, its article, the compiler's refusals, the unrun warning, the event
  task's counter warning and an edit's refusal of a change to `ctu_int`, each pinned; and
  an edit from `ctu` to `ctu_dint` is accepted with no report. An unknown type's message
  lists the fifteen words among logex's type words, in order, and from Elixir names each
  alias once, as its plain word's value. The Done-when is `typed_counter_test.exs`: a
  `ctu_int` stopping at 32,767 with `ov` on until `r` and a `ctd_udint` at 0 with `un` on
  until `ld`; a `ctu_ulint` counting past 2^63; every kind of every width at its own two
  limits against Table 10 restated; a preset at each typed width's top taken and one past
  it, or a negative one, refused at its line; an edit of a width refused in its type's
  words and of an alias accepted with no report; a typed counter's edge memory on the
  block list, `c.cu`, a real edge counting after; the event task's counter warning for a
  typed counter and an alias's; `var boxes ctu_dint` and `var boxes ctu` compiling to
  equal programs, `ctd_dint` and `ctud_dint` likewise, in any case, red with an alias
  made a type of its own; a typed counter's state outside its type refused; one in a
  block; the fifteen words reserved as a tag's and a label's name; and the counters'
  growth in reductions, 4x the counters under 4.8x to compile and to scan, and a typed
  counter's scan within 1.2x a dint's. `end_to_end_test.exs` runs M5-5's Done-when from
  files on disk: a plant whose `ctud_int` stock stops at 32767 with `ov` on and whose
  `ctd_udint` hopper stops at 0 with `un` on, through `cycle/3`, against an oracle that
  knows nothing of logex, and its `ctu_dint` box counter the very `ctu`. The contract
  walk's counter oracle draws each counter's word from the six, `_dint` among them, and
  stops each at its width's limits restated, its reach a count in each width and in the
  alias, an unsigned counter stopped at 0, an edit of a width refused and of the alias
  accepted. Changed on purpose: the unknown type's lists in `validation_test.exs`,
  `function_block_test.exs` and `end_to_end_test.exs`, the articles test, and
  `Logex.FbType`'s surface and `builtins/0` in `runtime_test.exs`. README's "A counter"
  gained `stock.ld` and `stock.exs`, run; its output is the README's. The fifteen words
  are reserved in every `.ld` file, in any case, as the code commit names; a `.logex`
  file's global may still be named one, as it may be named `ctu`.

  The mutation table (`m5/mut55.log` in the work's scratchpad), 18 mutants of `lib/`,
  each applied alone in a copy, which differed from the code commit's only in the dead
  `preset?/1` it still held, and judged by the full suite's exit code, every one red: a
  typed counter's `pv` and `cv` left dints (10 tests); its rules counting in a dint (9);
  the runtime stopping every counter at the dint's limits (8); an up counter stopping one
  past its top (7) and a down counter one past its bottom (7); an alias made a type of
  its own (15) or `ctu_dint` missing (25); an instance slot matched by a type's name, not
  its family (18); a preset always judged as a dint (2), a negative one taken (2), its
  refusal naming no type (2); the other kind's hint dropping the width (1); the `move`
  hint judged against a dint (1); an alias named twice in the Elixir list (3) or by its
  own word (3); a typed counter's family its own word (20); the runtime's kind the
  side's own, ignoring the family (12); and the typed counters left out of
  `builtins/0` (38). 1671 tests (9 doctests), up from 1646.

  *Provisional readings* (each a question below): a typed counter's preset is never
  negative; a counter slot's message names the plain words alone; and an unknown type's
  message lists every counter word.

  **Questions for the maintainer** (each taken provisionally as written, the closest
  reading to the record and to Logix):
  1. *A negative preset on a signed counter* (decision 158). A *preset* is the number on
     the instruction, `ctd stock 50`, the `pv` an instance starts and restarts with. logex
     takes 0 to the counter's type's top, so `ctu offset -10` on a `ctu_int` is refused at
     its line, as every preset has been since M1-6, though a `move -10 offset.pv` compiles
     and runs. On the conveyor: an engineer counting a reject chute's balance with a
     `ctud_int`, its done lamp `qu` meant to light at −10, sees the program refused and
     writes the `move` on a rung above instead. The other reading takes the type's whole
     range, −32768 to 32767 for a `ctud_int`, the lamp then lit by the preset alone. IEC's
     PV is of the counter's type, any INT (Ed 3 Table 45); Logix's `.PRE` is any DINT.
  2. *What a counter slot's refusal names* (decision 163). `xic e ctu c 1` with `c` a
     `ctd_lint` is told "`ctu` runs a ctu or a ctud, but `c` is a ctd_lint …", the slot
     named by its kinds' plain words, though a `ctu` runs a `ctu_lint` too. On the
     conveyor: an engineer who declared the hopper `ctd_lint` reads that `ctu` takes a
     dint counter only, and may change the width as well as the kind. The other readings
     say "an up counter or an up-down counter, of any width", or list all ten words. IEC
     and Logix have no such message.
  3. *An unknown type's list* (decision 163). A misspelt type, `var c ctu_itn`, is told
     every one of logex's type words, 31 now, the twelve typed counters and the three
     aliases among them, with the nearest suggested. On the conveyor: the engineer reads a
     long line to find `ctu_int`, which the did-you-mean names anyway. The other readings
     list the plain words and say "and the typed counters", or leave the aliases out,
     which a declaration still takes. IEC and Logix have no such message.

  **M5-5's review**, fixed on 2026-10-22, each code fix with a test that fails when it is
  reverted, judged by the full suite: (1) a `neg` into an unsigned destination whose
  source is a bool, a tag's or a member's, was told to convert it "with ``", an empty
  conversion's name, where decision 181 says such a source adds nothing: the hint now
  reads the source's class, and `arithmetic_test.exs` pins a bool tag, a bool member and
  an undeclared source (`8d34f84`); (2) `Logex.FbType.builtins/0` rebuilt its 22
  entries on every call, and each type word's lookup and reservation called it, so a
  program that uses none of M5-5's types compiled in 3.3x the reductions it took before
  M5-5 (279k to 913k for 200 bool rungs, 1.20M to 5.43M for 800 `ctu`s), which the
  growth tests, ratios of sizes, could not see, and this entry reported the scan's cost
  alone: the table is now built once as logex compiles, by an internal module,
  `Logex.FbType.Builtins`, from `built/0`, hidden, a lookup about 24 reductions where it
  was about 1,100, and `typed_counter_test.exs` bounds each word's lookup under 200
  reductions and its reservation under 300 (33 and 61 at most over 30 runs) and 400 bool
  rungs' compile under 20x their own parse (11.2x over 30 runs, 40x with the table
  built on each call) (`f598ba6`); (3) nothing pinned `Logex.Declarations.keywords/0`,
  the list `naming_test.exs` checks for stanzas, so the three aliases dropped from it,
  the review's R8, kept their reservation and lost their survey's check: the list is now
  pinned whole and every key of `builtins/0` held to be in it and reserved (`b9f5a45`);
  (4) two lines no test could tell from their mutants, the review's R5 and R7, are gone:
  the typed counters' article rows, each `a`, the default, and a `move` hint's type for
  a name not declared, never read; neither can have a test that fails when it is put
  back, and the claim above that the table's mutants were all red is true of its 18,
  not of these two lines, which it did not hold (`f4a133f`); (5) a ctud's preset
  disagreement named every counter "a ctud", where every other message names a typed
  counter by its own word: it now names the instance's own ctud, a `ctud_int`'s, a
  `ctud_dint` the plain `ctud`, and a counter of one kind the ctud of its width, and
  README's syntax list gives a counter's preset range as its `pv`'s type's, not
  0 to 2147483647 (`351c056`); (6) the counter walk missed a forecast one way or the
  other under 4 of 20 fresh seeds, and an alias's edit under 1: a preset now moves in 5
  draws of 18, to 0 now and then, and `u`'s width moves to its alias as often as to any
  width, and in a copy that prints what each seed misses 81 seeds, 1 to 80 and the
  committed 314, reach everything, every exactness assertion holding (`64c34ac`); and
  (7) three of `trip_test.exs`'s real-clock tests had margins of about 100 ms that a
  busy machine crossed, failing 6 of 15 runs under eight busy loops on four cores: each
  is widened, keeping its point, and none of 15 runs failed under the same load, and
  `CONTRIBUTING.md` now says a mutant red only on a real-clock test is run again alone
  before it counts (`8cef95b`). The mutation table, 8 mutants each judged by the full
  suite's exit code, every one red: a bool source told to convert, by the class read as
  true or its false clause sent to the true one; `builtins/0` built on each call; the
  aliases left out of `keywords/0`; the preset message's ctud plain, and the instance's
  own word in its place; the `move` hint judged in a dint; and a zero's deadline the idle
  watchdog alone, against the widened test. 1673 tests (9 doctests), up from 1671. No
  question for the maintainer: each fix follows the record as written.
- **The maintainer's answers of 2026-10-22** to the questions M5-4's answers and M5-5 put
  (`docs/organisation.md` §7, decisions 187 to 193), landed the same day as two commits,
  the code with its tests and the decisions, then the documents:
  - *187, a comparison whose literal sits at its tag's type limit is warned of* where its
    result never changes, in the all-literal warning's words: "`ge` compares `count` with
    `0`, and a usint holds nothing below `0`: its result never changes". The pairs are
    eight, at every width: `ge x lo` and `le x hi` always pass power, `lt x lo` and `gt x
    hi` never, and their mirrors with the literal on the left, `le lo x` and `ge hi x`
    always, `gt lo x` and `lt hi x` never; `eq` and `ne` at a limit, the other four at a
    limit and every literal inside the range can go either way.
  - *188, a timer's `last` later than the instance's `now` is refused*: "it is a clock,
    and 5000 is later than the instance's now, 1000"; any integer up to `now` is taken.
  - *189, a literal `neg` source names the narrowest signed type its negation fits*:
    `neg -128 count` is told "an int".
  - *190, decision 182's check runs once, where a program is first handed in*:
    `Logex.Runtime.instance/1`, `Logex.Edit.accept/3` for its candidate and
    `Logex.Configuration.check/1`, so `start/1`, `new!/1`, `compile/3` and a
    configuration edit's accept, each program type once; `start/1` and a configuration
    edit's switch make each instance with the internal `Logex.Runtime.fresh/1`. Every
    other entry point checks only a program's shape. What it gives up: a program swapped
    in by hand after its check is trusted. A scan costs what it did at `23a5136`: 2,000
    contact rungs 78,195 reductions where `23a5136` took 78,168 and decision 182 88,198,
    and 2,000 `add`s 116,171 where they took 116,168 and 148,762; `jump_test.exs`'s
    skipped rungs are 0.303 of running them again, its bound decision 171's 0.364.
  - *191, a counter's preset is any value of its type*, as IEC's PV is: `ctu offset -10`
    on a `ctu_int` compiles, "`ctu` takes a preset of -32768 to 32767 for a counter of
    ints", the dint counters' from -2147483648; an unsigned counter's is 0 to its top and
    a timer's 0 to 2147483647 ms, as before. The done lamps, a load, the edit's preset
    rules and its forecast hold at a negative preset, each pinned, and the counter walk
    draws one.
  - *192, a counter slot names every word it runs*, in a fixed order: "`ctu` runs a ctu,
    ctud, ctu_int, ctud_int, ctu_lint, ctud_lint, ctu_udint, ctud_udint, ctu_ulint or
    ctud_ulint, but `c` is a ctd_lint …", the hint "declare it `var c ctud_lint`" kept.
  - *193, the unknown type's list of 31 words kept*: no code changed.

  Changed on purpose: `runtime_test.exs`'s hand-edited program, refused now only where it
  is handed in, its trust and the scan's raise pinned, and the check traced at each entry
  point; `jump_test.exs`'s bound back to 0.364; `end_to_end_test.exs`'s `a `last` later
  than now` and `runtime_test.exs`'s `last` of 2^70, now refused against a `now` before
  them; `validation_test.exs`'s `lt 2147483647 i`, now `lt 2147483646 i`, which no dint
  makes fixed; every counter preset message's range and every counter slot message in
  `validation_test.exs` and `typed_counter_test.exs`. `docs/naming.md`'s `neg` stanza is
  amended, its worked example a test. README's `stock.exs` was run again, its preset
  line now -32768 to 32767, and the `ctd` on an up counter's refusal; `drive.exs` gives
  what it gave.

  The mutation table (`m5/mut187.log` in the work's scratchpad), 27 mutants of `lib/`, each
  applied alone in a copy and judged by the full suite's exit code, every one red: no
  limit warning (2 tests), the right side's lowest pair `ge`/`le` (2), the left side's
  lowest unwarned (2), the left's highest taken as the right's (2), `eq` warned at the
  lowest (2), a member's type unread (1), the sides swapped in the words (2); a `last`
  later than `now` taken (2), one equal to `now` refused (274), `now` + 1 taken (1); the
  literal's own type named (2), its negation's alone (2), the none-holds words swapped
  (1); `instance/1` checking nothing (5), an edit's candidate unchecked (4), `call/4`
  checking again (3), `start/1` checking each instance (1), a configuration edit's switch
  checking (1), a trusted bad destination computed in the dint (1), a bool destination
  passed to the wrap (1), an edit checking the program running too (2); a counter's preset
  from 0 (9), a timer's negative (6); the slot's old words (4), the plain words not first
  (4), the aliases listed (4), a width's kinds reversed (4). 1681 tests (9 doctests), up
  from 1673; the counter walk reaches a negative preset under ten other seeds.

  *Provisional readings* (each a question below): a scan that reaches a trusted program's
  bad destination raises there; `neg 128` names the type the literal fits too; every
  message that names a counter slot lists its words; and an edit's accept checks its
  candidate only.

  **Questions for the maintainer** (each taken provisionally as written, the closest
  reading to the record and to Logix; answered on 2026-10-22, decisions 194, 195, 201 and
  200, the fourth otherwise than taken, below):
  1. *A trusted program a scan finds broken* (decision 190). A *program edited by hand* is
     a compiled `%Logex.Program{}` a host changed after it compiled, its box count `d`
     retyped from an `sint` to a bool. Since decision 190 nothing walks it after its
     check, so a scan that reaches its `add 100 100 d` raises an `ArgumentError` there,
     "a scan's `add` on line 7 computes in the type of `d`, a bool, …", and a scan whose
     rung is false runs on. On the conveyor: a runner whose host swapped such a program
     in sees no fault until a box arrives and the `add`'s rung goes true, and then the
     scan stops with that message, the outputs of that scan never written. The other
     readings compute it in the dint, as M5-4's review did, so the lamp lights and the
     count is wrong, or skip the instruction, no power and nothing written. IEC and Logix
     have no compiled program a host can edit.
  2. *`neg 128` into an unsigned tag* (decision 189). The narrowest signed type -128, the
     negation of 128, fits is an `sint`, but 128 itself is no sint's, and a literal is
     judged in its destination's type, so `neg 128 count` declared an sint would still be
     refused. logex tells it "an int", the narrowest that holds both, the one change that
     makes it compile. On the conveyor: an engineer negating a fixed 128 mm offset into a
     `usint` is told to declare an `int`, and it compiles. The other reading names the
     sint, as the answer reads word for word, and the engineer is then told 128 does not
     fit an sint. IEC has no NEG; Logix's is unverified.
  3. *The slot's words in the other messages* (decision 192). The answer listed every
     word where a counter of the wrong kind is given; logex lists them wherever a message
     names the slot, a bool given to `ctu` ("`ctu` runs a ctu, ctud, …, but `a` is a
     bool"), a literal ("`ctu` expects a ctu, ctud, …, found `5`") and a missing operand
     ("(a ctu, ctud, …, then a preset)"), since each reads one description of the slot.
     On the conveyor: an engineer who typed `ctu 5 5` reads the ten words on a line. The
     other reading lists them only for a counter of the wrong kind and keeps "a ctu or a
     ctud" elsewhere, a message that says less than it means. IEC and Logix have no such
     message.
  4. *Which program an edit's accept checks* (decision 190). `Logex.Edit.accept/3` takes
     the program running and the candidate; logex checks the candidate only, the program
     running having been checked where its instance was made, so a running program
     swapped in by hand is trusted there too. On the conveyor: nothing an operator sees
     changes unless a host edited the running program by hand. The other reading checks
     both, as decision 182 did, once an accept, which no scan pays. IEC and Logix check a
     program once, at download (**unverified** in the extracts read, M5-16).
- **M5-6 · Long timers in nanoseconds.** The stanzas, then `ton_ltime tof_ltime tp_ltime`
  and `rto_ltime` (decision 158, its last taken as the maintainer answered §4.12's
  seventh question), run by
  `ton`, `tof`, `tp` and `rto`, their `pre` and `acc` `lint` nanoseconds, the preset on
  the instruction in nanoseconds, 0 to 2^63−1, each scan's elapsed milliseconds counted as
  1,000,000 ns each, so that the resolution is a millisecond, said in each stanza, with a
  warning for a preset that is not a whole number of milliseconds; each stanza and
  README's timer section say that a preset's unit is its instance's, so that one rung's
  preset is a million times longer on a `ton` than on a `ton_ltime` (§4.12's routine
  choice). *Done when* a `ton_ltime` with a preset of 30 days in ns is done at exactly 30
  days of scans and never before, a preset of 1,500,000 ns is done at the 2 ms scan and
  warned of, the one rung `ton t 2000000` is done at 2,000,000 ms with `t` a `ton` and at
  2 ms with `t` a `ton_ltime`, a test that fails when either unit is taken for both, each
  long timer's rules of M3-2 hold for it from source through `call/4`, an edit resumes one
  by its type's `times` member, an edit from `ton` to `ton_ltime` is refused, and the
  contract walk's timer oracle draws them. *Size M.*

  **Status: DONE — landed 2026-10-22**, as three commits: the four stanzas first, each a
  type word, `ton_ltime`, `tof_ltime`, `tp_ltime` and `rto_ltime`, each saying its unit
  is the nanosecond, its resolution a millisecond and a preset's unit its instance's;
  then the code with its tests; then the documents. The four long timers are built-in
  types, `Logex.FbType.ton_ltime/0` to `rto_ltime/0`, each its kind's members with `pre`
  and `acc` lints, named by its word, and each its kind's row of `Logex.FbType.rules/1`
  under its kind's `family`, its `counts` `:lint` and a new field, `per_ms`, 1,000,000,
  what a millisecond adds to its `acc`; a plain timer's `counts` is now `:dint`, where it
  was nil, and its `per_ms` 1, a counter's `per_ms` nil. The instructions stay `ton`,
  `tof`, `tp` and `rto`: a timer's slot names its kind, `{:instance, ["ton"]}`, so each
  runs both of its kind, and every message that names the slot names both words, by
  decision 192's rule, "`ton` runs a ton or ton_ltime, but `a` is a bool", changed on
  purpose in `validation_test.exs`, `function_block_test.exs`, `typed_counter_test.exs`,
  `api_contract_test.exs` and `end_to_end_test.exs`; a counter given to a timer's slot is
  told no `ctud`, which the list would otherwise have offered it. A long timer's preset is
  judged 0 to 2^63−1 ns, "`ton` takes a preset of 0 to 9223372036854775807 ns for a
  ton_ltime, found `-1`", never negative, as decision 191 leaves every timer's, and one
  from a tag is told its unit, "`ton` takes its preset as a number of nanoseconds for a
  ton_ltime, found `sp`", with the `move` where the tag widens into a lint. The runtime
  reads each timer's `per_ms` from its type's rules in the routine's tag table and
  multiplies each scan's elapsed milliseconds by it, so a long timer's `.acc` moves in
  steps of 1,000,000 ns and its catch-up in a frozen block or on a skipped rung is its
  kind's; `last` stays the clock's ms. `Logex.Warnings` warns of a long timer's preset
  that is no whole number of milliseconds at its instruction's line, "`ton` gives `t` a
  preset of 1500000 ns, which is no whole number of milliseconds: a ton_ltime counts whole
  milliseconds, so it times as the next whole millisecond, 2 ms". The event task's timer
  warning reads the timer's kind from its rules and names it by its word, "a ton_ltime
  times across the task's runs". The four words are reserved in every `.ld` file in any
  case, and the unknown type's list grows to 35. The Done-when is `long_timer_test.exs`:
  a `ton_ltime` of 30 days in ns done at exactly 30 days of scans, one ms short not done;
  1,500,000 ns done at the 2 ms scan and warned of, a whole-ms preset and a `ton`'s not;
  the one rung `ton t 2000000` done at 2,000,000 ms on a `ton` and at 2 ms on a
  `ton_ltime`; each of the four scanned beside its plain timer over seeded rungs, resets,
  elapsed times and restarts, holding its members exactly with `.pre` and `.acc` a million
  times theirs; each kind's own rules in ns; a frozen block's and a skipped rung's
  catch-up; an edit to or from a plain timer refused at its line, a preset moved and
  forecast in ns, a resume by the type's `times` member, `{:resumed, "t", 500}` in the
  clock's ms, and a `tp_ltime`'s `.en` on the block list; the presets at 0 and 2^63−1 and
  refused at −1 and 2^63; the messages, warnings and reserved words; a state's `t.acc`
  past the lint refused; the event task's warning for each; a cycle and the runner on the
  manual clock counting whole milliseconds, 2,000,000 ns lit at 2 ms; and a long timer's
  scan within 1.2x a plain one's, 4x the timers under 4.8x. `end_to_end_test.exs` runs it
  from files on disk: a press whose 30-day `ton_ltime` and whose one rung on a `ton` and
  a `ton_ltime` light their lamps as an oracle that knows nothing of logex says, through
  `cycle/3` over 400 seeded presses and waits. The contract walk's timer oracle draws each
  of its `tof`, `tp` and `rto` a long timer half the time, its preset in ns and each
  millisecond adding 1,000,000 restated, an edit of the `tof`'s unit refused, its reach a
  long timer timing and the unit's refusal, under eight other seeds. README's "Long
  timers" is the run of `cure.exs`, and its unknown-type example was run again.
  The mutation table: 22 mutants of `lib/`, each judged by the full suite's exit code,
  all 22 red: per_ms ignored in the elapsed time, read as 1, or 1,000; a long timer's
  members left dints, its family its own word, its types out of `builtins/0`, its counts
  a dint; the `ton` and the `tp` slot back to one word; the preset messages in ms; the
  ctud hint on every slot; a negative timer preset; the warning dropped, its next
  millisecond one short, or given for a whole millisecond too; the event warning in the
  plain word; `an rto_ltime`'s article; and each of `ton`, `tof`, `tp` and `rto` alone
  ignoring per_ms. 1710 tests (9 doctests), up from 1681.

  *Provisional readings* (each a question below): a timer slot's messages name both words;
  a value logic writes into a long timer's `.pre` or `.acc` is in ns and never warned of;
  an edit's report gives a moved preset and a forecast in ns and a resume's gap in ms; and
  the warning's next millisecond is the one after the preset, at its instruction's line.

  **Questions for the maintainer** (each taken provisionally as written, the closest
  reading to the record and to Logix; answered on 2026-10-22, decisions 198, 196 and 199,
  the second otherwise than taken, below):
  1. *What a timer's slot is told* (decision 192, applied to timers). A slot is the place
     on an instruction where its timer goes; `ton` now runs a `ton` and a `ton_ltime`.
     Decision 192 has a counter's slot name every type word it runs, so logex tells a
     `ton` given a bool "`ton` runs a ton or ton_ltime, but `a` is a bool", and every
     timer slot message changed so, the fan's `tof` "a tof or tof_ltime". On the conveyor:
     an engineer who typed `xic eye ton lamp 500` reads both words. The other reading
     names the plain word alone, "`ton` runs a ton", as before M5-6, which hides that a
     long timer would do. IEC's overloaded TON takes either; Logix has one TIMER.
     *(Corrected by M5-16, 2026-10-26: on the 5380, 5580 and 5590 controllers Logix's
     timer instructions also take a TIMER_T, whose preset and accumulator are TIMEs in
     microseconds, beside the DINT-millisecond TIMER, 1756-RM018A pp.110–111; the
     question's options are unchanged by it.)*
  2. *A long timer's `.pre` or `.acc` written by logic* (§4.12's routine choice). A preset
     on the instruction that is no whole number of ms is warned of; a `move 1500000
     cure.pre` on a rung, the literal moved by logic, is not, nor is a comparison `ge
     cure.acc 3000` that a rung ported from a `ton` still reads as 3 s and is now 3 µs. On
     the oven: the cure lamp's comparison lights 3 µs into the cure, not 3 s, with no
     warning. The other readings warn of a literal moved into a long timer's `.pre` or
     `.acc` that is no whole ms, or of any literal compared with a long timer's member
     below 1,000,000. IEC types PT as LTIME, so `T#3s` says its unit; Logix has no such
     timer.
  3. *The units of an edit's report on a long timer* (decision 158 with §4.9). An edit
     that moves the oven's 36 h preset reports `{:preset, "cure", {129600000000000, ...}}`
     and its forecast in ns, a member's own unit, and a timer resumed after the edit
     reports the time it was not run, `{:resumed, "cure", 500}`, in ms, the clock's unit,
     as for every timer. An operator reading the report sees ns beside ms. The other
     reading gives the gap in ns too, a million times larger. IEC and Logix have no such
     report.

  **M5-6's review**, fixed on 2026-10-22, each with a test that fails when it is
  reverted, judged by the full suite: (1) every run of a `ton`, `tof`, `tp` or `rto`
  walked its type's rules for its `per_ms`, a look-up of its tag, `FbType.rules/1` and a
  match, about 10 reductions, plain timers too and a `tp` on a false rung, so a plain
  timer's scan grew 8 to 10% dearer, which the claim above, a long timer's scan within
  1.2x a plain one's, hid by measuring against a plain timer that had grown too: what a
  type's millisecond adds is now settled when logex compiles, a clause of the runtime's
  `per_ms/1` for each built-in type whose unit is not 1 ms, generated from the rules as
  `wrapped/2` is from the type table, so a run pays one look-up of its tag and one match
  of its type's word. For 2,000 timers, fewest reductions of 7 scans, before long timers
  (`6a15701`), at M5-6 (`d860484`) and now: `ton` energised 224,621, 246,012, 232,780;
  `tof` de-energised 238,597, 256,316, 244,268; `tp` energised 255,710, 275,837, 262,244;
  `tp` de-energised 220,563, 238,185, 227,068; `rto` energised 253,928, 274,341, 260,175;
  `rto` de-energised 237,088, 256,255, 244,354; a `ton`'s de-energised run, which reads
  no clock, unchanged throughout. What is left, 2.4 to 3.6%, is the look-up of each
  timer's tag on each run, which only a unit carried in the compiled program could
  remove (question 4 below). `long_timer_test.exs` bounds a plain `ton`'s energised run
  over its de-energised one under 26.5 reductions a timer, about 21 before long timers,
  24 now and 29 at M5-6 (`e480a76`); (2) `Logex.Compiler.run_words/1`'s comment said a
  timer's slot names its one word, where since M5-6 it names both, "a ton or ton_ltime"
  (`042aff2`, a comment, so no test); and (3) the review's mutant R17, a `ctu`'s `q` read
  as CV >= max(PV, 0), left the suite green: it differs only at a count below a negative
  preset, which a lone up counter reaches only from a state the host built, since it
  counts from 0 and logic cannot write its `cv` (decision 86); `typed_counter_test.exs`
  now counts a `ctu_int` up from -5 to a preset of -3, its `q` lit at -3 (`22108aa`).
  Each fix's revert, judged by the full suite's exit code, is red: the rules walked on
  each run again fails the bound, and R17 fails the new test. 1712 tests (9 doctests), up
  from 1710.

  **Question for the maintainer** after M5-6's review (answered on 2026-10-22, decision
  197, otherwise than taken, below):
  4. *Where a timer's unit is settled* (decision 158 and the scan's cost). A timer's unit
     is what each millisecond of the clock adds to its accumulated time: 1 for a `ton`,
     counted in ms, and 1,000,000 for a `ton_ltime`, counted in ns. logex now looks each
     timer's tag up on each run to learn its unit, so a program of plain timers, the
     conveyor's 2,000 `ton`s, scans about 3% slower than before long timers existed, and
     never wrong. The other reading carries each timer's unit in the compiled program, so
     the scan reads it with the instruction and a plain timer costs exactly what it did,
     at the price of a field in `%Logex.Program{}` or in the instruction's IR that every
     walk, edit and hand-built program must keep in step with the tag table. Taken
     provisionally: the look-up, no change of the compiled program's data. IEC says
     nothing of a scan's cost; Logix's TIMER has one unit, the millisecond, so it makes
     no such choice. *(Corrected by M5-16, 2026-10-26: its TIMER_T, on the 5x80 and 5590,
     is a second, in microseconds, 1756-RM018A p.111; how its controller looks the unit up
     is **unverified**.)*
- **The maintainer's answers of 2026-10-22** to M5-6's four questions and to the four
  readings decisions 187–193 left (`docs/organisation.md` §7, decisions 194 to 201),
  landed the same day as two commits, the code with its tests and the decisions, then the
  documents:
  - *194, a trusted program a scan finds broken*: confirmed, the scan raises a pinned
    `ArgumentError` where it reaches the instruction, and, since 197, where it reaches a
    timer whose unit is no positive whole number or units that are no map.
  - *195, `neg 128` into an unsigned tag*: confirmed, "an int".
  - *196, a literal taken beside a long timer's time is warned of*, as a preset is: "`ge`
    compares `cure.acc` with `3000`, where `cure.acc` is a ton_ltime's time in
    nanoseconds: 3000 ns is no whole number of milliseconds, and a ton_ltime counts whole
    milliseconds". The slots: `move` and the 56 conversions writing it into a long timer's
    `.pre` or `.acc`, the six comparisons on either side, and `add` and `sub` adding it to
    one, taking it from one or writing their sum into one, each literal that is no whole
    number of milliseconds a warning of its own; `mul`, `div`, `mod`, `neg` and `abs`,
    whose literal is no time, and a plain timer's members, are not looked at.
  - *197, each timer's unit carried in the compiled program*: `%Logex.Program{}`'s
    `units`, each timer whose unit is not the millisecond by its name, nil where the
    routine holds none, settled by the compiler from the tag table (`Logex.Program.units/1`,
    the one rule), a block's body holding its own; the scan carries the running routine's,
    a `cal` narrowing it as it does `tags`, and each clause that reads a clock matches
    `units: nil` in its head first, so a routine of plain timers pays no look-up. Not the
    IR, whose timer instructions every walk reads as two operands. A plain timer beside a
    long one pays the look-up, as every timer did before. A guard on the key,
    `is_map_key/2`, cost two reductions a run, measured, so the head matches nil instead,
    and the clock's tuple, whose allocation the garbage collector counts, gave way to two
    arguments. A program whose units its tags do not give is refused where it is handed
    in, a line each, each routine's before its rungs (`Logex.Program.edited_by_hand/1`,
    which replaces `unwritable/1`), `Logex.Compiler.lowered?/1` holding a body's to the
    rule too. A scan of 400 timers, in a process whose heap the collector never visits,
    costs exactly what it did at `6a15701`, every clause: `ton` 63,774 energised and
    56,174 not, `tof` 56,174 and 66,175, `tp` 69,775 and 62,576, `rto` 71,773 and 68,573;
    the fewest of seven with the collector running are within 1% either way.
  - *198, a timer's slot names both words*: confirmed.
  - *199, an edit's report keeps mixed units*: confirmed, presets in ns, gaps in ms.
  - *200, an edit's accept checks the program running too*: `Logex.Edit.accept/3` checks
    the program running and then its candidate, and `Logex.Configuration.Edit.accept/3`
    each program type the resource runs, after the runtime and before its `elapsed_ms`.
  - *201, the full word list in every counter-slot message*: confirmed.

  Changed on purpose: `runtime_test.exs`'s edit accept of a program running edited by
  hand, trusted until now and refused since decision 200, and its traced checks, two at
  an edit's accept and two at a configuration edit's; the struct surface, `%Logex.Scan{}`
  and `%Logex.Program{}` each gaining `units`; and `long_timer_test.exs`'s bound on a
  plain timer's energised run, 26.5 reductions a timer over its de-energised one, now 19,
  exactly what it was before long timers, measured in a process the collector never
  visits, as the new per-clause test is. README's `cure.exs` was run again, its second
  compile reading the cured lamp from a comparison ported from a `ton`, `ge cure.acc
  3000`, warned of.

  The mutation table (`m5/mut194/run.log` in the work's scratchpad), 31 mutants of
  `lib/`, each applied alone in a copy and judged by the full suite's exit code, every one
  red: each of the six clauses that read a clock never taking the plain path, the look-up
  raising on nil (201, 25, 22, 22, 19 and 15 tests), and again with the look-up giving 1 for
  nil, so that only the cost differs (1, 1, 1, 2, 1 and 1: the per-clause cost test and the
  bound); a program's units unset by the compiler (27), a body's (4), a recompiled body's
  (3); `lowered?/1` not holding a body's units (1); a `cal` not narrowing the scan's units
  (1); a host's `scan.units` taken (1); units that are no map read as none (1); a unit of 0
  taken (1); a plain timer given a unit by the rule (7); a routine's unit lines dropped (2);
  nil read as no table at all (1,105); an edit's accept not checking the program running
  (7); a configuration edit's not checking the program types it runs (3); the warning
  dropped (2), its comparisons (3), its conversions (1), `mul`, `div` and `mod` looked at
  (1), a whole millisecond warned of (3), and `sub`'s operands swapped in its words (1).
  1725 tests (9 doctests), up from 1712.

- **M5-7 · Based literals and separators.** `16#`, `2#` and `_` (decision 149), through
  the lexer, `well_formed!/1`, the printer, the generator and curated golden sources.
  *Done when* each form is in the golden record's curated sources, an entry that held
  `1_000` or `16#…` before changes and its diff is read, `16#ffff` is 65,535 in a `uint`
  and refused in an `int`, and `8#17`, `16#-1`, `16#_ff`, `1__0`, `1_`, `_1` (a name, not
  a number) and `1.5_` are pinned refusals or readings, and Logix's suffixes `5U` and `5L`
  pinned as B2's mistyped lexeme at their columns (decision 149, the vendors' suffixes
  refused), each a test that fails when its lexer clause is reverted. *Size M.*

  **Status: DONE — landed 2026-10-22**, as three commits: the 38 curated golden sources
  first, recorded by the front end before the rules, every one a lex error but `"move _1
  aa"`, a name, so that the next commit's diff is exactly what the rules change
  (`dcc41b9`); then the lexer with its tests (`e7a11ef`); then the documents. No word is
  added, so no stanza is owed. `Logex.Lexer` reads a based number in base 16 or 2, `16#ff`,
  `16#FF`, `2#1010_0000`, with no sign, and a single `_` between two digits of any number,
  `1_000` and `-1_000`, one `int_lit` token holding the value it spells, a plain decimal
  still read by `String.to_integer/1` at the cost it had; each mistake is a located lex
  error naming the number whole at its start, `8#17`, `10#5`, `016#ff` and `1_6#ff` another
  base, `16#-1` and `-16#1` a sign, `16#_ff`, `16#ff_`, `1__0`, `1_` and `7_` a `_` out of
  place, `16#`, `2#102` and `16#fg` a digit outside the base; Logix's `5U` and `5L` are
  B2's mistyped lexeme at their columns, `_1` a name, and `1.5_` and `1.5L` an illegal `.`
  as before, reals being M5-10's. `mov 7_ aa`, which B2 named a mistyped lexeme, is the
  separator refusal now, changed on purpose. The golden record's diff on landing is 13 of
  the 38, each a lex error become the tree of the value it spells, `"move 16#ff aa"` 255
  and `"move 1_000 aa"` 1000 among them, the other 25 lex errors still on their lines, and
  no other entry. `printer_test.exs`'s generator spells every literal of its corpus in
  decimal, with `_`, in base 16 in either case or in base 2, each read back as the tree,
  its `@required_shapes` gaining the three spellings. The Done-when is
  `integer_width_test.exs`'s: `16#ffff` 65,535 in a `uint`, refused in an `int` as a move
  and a declaration, every width's top in base 16 and 2, and a program spelled with `_` and
  bases compiling to the one its decimal spelling gives; `frontend_test.exs` pins each
  token and column, each refusal and message, and the lexer's cost in reductions; and a
  configuration file's numbers take each form. The mutation table: 27 mutants of
  `lib/logex/lexer.ex`, each judged by the full suite's exit code, every one red (the
  second commit's message lists them). 1738 tests (9 doctests), up from 1725.

  **M5-7's review**, fixed on 2026-10-22, each with a test that fails when it is
  reverted. No correctness bug; two rules the record words exactly had no test, and three
  small lexer points. (1) Decision 196's "the first long timer's member among the
  operands is the one named": `add c2.acc 5 cure.pre`, a `tof_ltime`'s member before a
  `ton_ltime`'s, names `c2.acc` and its tof_ltime, and the mirror `cure.acc`
  (`long_timer_test.exs`, `b0b467c`). (2) Decision 200's "in name order": 33 program
  types edited by hand, past the 32 at which a map's keys stop coming in name order, are
  named in name order in one message (`runtime_test.exs`, `b0b467c`). (3) A `#` after a
  based number's digits is in the number, so `16#ff#`, Ada's spelling, `2#1#1`,
  `16#ff#1` and `16##1` are each one lex error at the number's start, `{:hash, run}`,
  "a based number holds one `#`, between its base and its digits, `16#ff`", where they
  failed at the second `#` as an illegal character, provisional in its words (`90242e4`).
  (4) A signed based number's base is judged before its sign, so `-8#17` is told that
  logex reads no other base, `-16#1` still that a based number takes no sign. (5) The
  base-16 digits message says "a to f, in either case". The golden record keeps an
  error's line, so no entry changes. The mutation table, each judged by the full suite's
  exit code: B2 (operands reversed before the search) red; B4 (`Enum.sort(:desc)`) red;
  B4b (no sort) red; H1 (`based_run` stops at `#`) red; H2 (the sign judged first) red;
  H3 (the old wording) red; H4 (`#` in the digits a digit refusal) red; H5 (`#` first a
  digit refusal) red; H6 (`{:hash, …}` given as `{:digits, …}`) red. 1740 tests (9
  doctests), up from 1738.

  *Provisional readings*: the parse tree keeps a literal's value, not its spelling, so
  `well_formed!/1` takes what it took, the printer writes `16#ff` as `255`, and a
  message cites `65535` for `16#ffff` (the question below, changed by decision 202); a
  base is `16#` or `2#`
  exactly, so `016#ff` and `1_6#ff` are refused as another base; a digit outside the
  base, `2#102` or `16#fg`, is that refusal and not B2's mistyped lexeme, and so is `16#`
  with no digit; `7_`, a `_` with no digit after it, is the separator refusal where B2
  named it before; and a based number of any length is read, a slot judging what fits.

  **Questions for the maintainer**, both answered on 2026-10-23 (decisions 202 and 203,
  below):
  1. *Whether a rung keeps a literal's spelling* (decision 149 with the printer). A
     literal's spelling is how it was typed, `16#00ff` or `2#1010_0000`; its value is the
     number, 255 or 160. logex keeps the value alone, so a rung printed back, as an
     editing box shows it, reads `and status 255 speed` where the engineer typed `and
     status 16#00ff speed` for a mask on the fan's status word, and a refusal says
     "`move` writes `65535` into `i`" where `move 16#ffff i` was written. The other
     reading keeps the spelling in the tree, a new leaf that every stage reading a
     literal takes, so the box shows `16#00ff` and a message quotes it as written. IEC
     defines a literal's value, and Ed 3 p.26 reads `16#ffff` as a bit-string literal,
     not how a tool shows it; how Logix shows an immediate typed as `16#00FF` back in a
     rung is `unverified`.
  2. *What a based number with a second `#` is told* (M5-7's review, provisional). Ada
     and some engineers write hex as `16#FF#`, closing it with a `#`. IEC has no closing
     `#` (Ed 3 Table 5), and logex refuses it either way; the reading taken names the
     number whole at its start, `"16#FF#" is no number: a based number holds one `#`,
     between its base and its digits, `16#ff``, so an engineer typing `move 16#FF# fan_mask`
     sees the whole number marked and the spelling to use. The other options: tell it as a
     digit outside base 16, the message `16#fg` gets; or take `16#FF#` as 255, which IEC
     does not define. Logix's reading of a closing `#` is `unverified`.

  **The maintainer's answers**, 2026-10-23 (decisions 202 and 203). (1) *Changed*: a rung
  keeps a literal's spelling (decision 202). A literal written as the plain decimal of its
  value, `Integer.to_string/1`'s, stays the three-element leaf, `{:int_lit, line, 255}`;
  one written any other way, `16#00ff`, `2#1010_0000`, `1_000`, `007` or `-0`, is the
  four-element leaf `{:int_lit, line, 255, "16#00ff"}`, in the lexer's token, the parse
  tree and the IR alike. Chosen over a value wrapped with its spelling because a fourth
  element leaves every reader of the third, its guards, its arithmetic and its messages,
  as it was for every plain literal, so existing trees, tests and walks are untouched;
  `well_formed!/1` states it exactly, the spelling the one text that lexes as one literal
  token of its value that holds it (`Logex.Parser.spelled?/2`), and `Logex.Parser` gives
  the guard `is_int_lit/1`, `value/1` and `spelling/1`. The printer writes each literal as
  typed; every message that quotes a literal quotes it as written, the compiler's, the
  warnings', a declaration's, a `cal` formal's and a configuration file's reader's,
  "`move` writes `16#ffff` into `i`, an int: it is outside -32768 to 32767"; the runtime
  reads its value; an edit compares a literal by its value, as presets are compared, so
  `16#ff` for `255` leaves its rung the same rung, blocking no one-shot and reporting
  nothing. The golden record was regenerated on purpose and its diff read: 251 entries,
  each a literal's leaf gaining its spelling and nothing else, M5-7's 13 based or
  separated sources, `"mov 007 aa"`, `"move -0 aa"`, `"move -007 aa"` and 235 generated
  sources whose `042` keeps its leading zero. The decimal fast path's cost, in reductions
  against `f546772`: 200 lines of `mov 1234 hh` lex in 6,624 before and after; a program
  of 400 instructions with a plain literal each compiles in 417,811 before and after and
  scans in 4,367; a spelled literal costs its one lex more in `well_formed!/1`, about 58
  reductions where it was 18, linear (`integer_width_test.exs`, `frontend_test.exs`).
  (2) *Confirmed as built*: `16#FF#` is one lex error naming the number whole and the
  spelling to use (decision 203); no code changed.

  The commit (`a71bd7e`) holds the code, its tests and decisions 202 and 203.
  `printer_test.exs`'s generator draws a leading zero too, its spelled trees in every
  round-trip property and its `@required_shapes` gaining `:padded_int_lit`, each spelled
  tree printing back exactly as written; `well_formed!/1` refuses a spelled leaf broken
  three ways, its spelling the plain decimal, another value's or no binary. The mutation
  table, each judged by the full suite's exit code: 49 mutants, S1 to S48 and S7b, across the lexer, the parser, the printer, the compiler, the warnings, the declarations, the configuration text, the walk, the runtime and the edit plan, each taking a spelling away or quoting a value where the spelling is due, every one red; three survived the first run and are red since a test of their own in `integer_width_test.exs`, an instruction a message shows whole quoting its literal's value (S11), an unknown word's spelled operand not passed over (S29) and the walk reading a spelled preset as none (S32). 1753 tests (10 doctests), up from 1740.

  *Provisional readings* (the record's, questions below): a number a message computes or
  gives as a quantity is a value, written in decimal, a negation, "none holds `128`, its
  negation", or a preset in ns, "a preset of 1500000 ns", where every literal the message
  quotes in backticks is as written; and a configuration file's entries hold the value
  alone, being the data a configuration built from Elixir holds, so its reader's messages
  quote a number as written but `Logex.Configuration.Text.print/1` writes it in decimal.

  **Questions for the maintainer** (taken provisionally as written, the closest reading to
  the record):
  1. *Whether a quantity a message gives keeps the spelling too* (decision 202). The oven's
     cure timer is `ton cure 1_500_000` on a `ton_ltime`; the warning reads "`ton` gives
     `cure` a preset of 1500000 ns, which is no whole number of milliseconds: … it times
     as the next whole millisecond, 2 ms". The literal is not quoted there but named as a
     quantity, beside the 2 ms logex computed, so it is written in decimal. The other
     reading writes it as typed, "a preset of 1_500_000 ns", and `16#16e360` would read
     "a preset of 16#16e360 ns". IEC says nothing of messages; how Logix words its
     verification errors for an immediate is `unverified`.
  2. *Whether a configuration file keeps a number's spelling* (decision 202). A plant's
     configuration file says `var_global speed_limit uint 16#ffff`; its reader quotes
     `16#ffff` in a refusal, but its entries hold 65535, so a configuration printed back
     by `Logex.Configuration.Text.print/1` reads `var_global speed_limit uint 65535`. The
     other reading gives each entry's number a spelling too, which a configuration built
     from Elixir would leave nil, so an operator's file printed back would read as typed.
     A configuration file is logex's own (decision 35); Logix keeps its configuration in
     its project, not in text, so there is nothing to compare.
- **M5-8 · Bit strings, the bitwise instructions and literal bit access.** The stanzas
  first: `byte word dword lword`, `and or xor not shl shr rol ror`, and the bit-string
  conversions' family stanzas, `docs/naming.md`'s `wand` rows amended (decision 155). The
  four types, with no arithmetic, comparing as unsigned, each declarable everywhere an
  integer is (M5-3): a tag, a block's member, each section, `var_external` among them, a
  global and a located point (decision 156), its value from a device, a host's
  `put_inputs/3`, `Logex.IO.Sim` and a force an integer from 0 to 2^N−1, checked by
  `fits?/2`, and the forces file spelling it as the integer; the eight instructions on bit
  strings and integers alike, computed in the destination's type, operands all of one kind,
  a mix refused naming its conversion (decision 147, §4.12's second question answered as
  recorded); a shift or rotate whose tag count is negative at run time acting as a count
  of 0, the source written unshifted, with no power out, a `shl` or `shr` count of the
  width or more writing 0 with its power in, and a rotate by its count modulo the width,
  none of them a fault (decision 165); a comparison of a bit string with an integer tag
  refused naming its conversion, a literal judged by its slot (§4.12's ninth question,
  answered as recorded); the 12 conversions between bit strings and the 64
  between a bit string and an integer, binary transfers; and `x.3` on every integer and
  bit string, read by a contact and written by a coil, a one-shot's storage bit and a
  pulse coil's two bits among them, the number checked against the width when the program
  compiles; a coil on a bit a write of its word in `Logex.Walk.writes/1`, the writer
  warnings and the input-point refusal; a bit of a `bool` refused, and a bit of a real
  with the reals (M5-10). *Done when* `shr` of an `int` −2 by 1 gives 32,767 (zero fill),
  `rol` of a `byte` 2#1001_0001 by 1 gives 2#0010_0011, a shift by the width gives 0, a
  negative literal shift count is refused, `shl` of a `word` 16#00ff by an `int` tag at
  −1 writes 16#00ff with no power and no fault and by 16 and by 40 writes 0 with its
  power in, `rol` of a `byte` by 9 gives what a rotate by 1 gives, and `ror` by an `int`
  tag at −3 writes its source with no power, each a test that fails when its rule is
  reverted (the count taken as its bit pattern, the power passed, a fault raised), every width's top bit is read and written in
  two's complement, `add` of a `word`, `and` of a `word` with an `int` destination and
  `eq` of a `word` with an `int` tag are pinned refusals naming what to use, a coil on a
  bit of a located input point is refused and one on a bit of a `var_external` makes it a
  writer of its global, `ote status.3` beside `move x status` draws the second-`ote`
  warning, an edit of a rung with `ons status.3` blocks it once; §4.4's plant reads the
  drive's status as a `word` point, `var_global drive_status word at drive.i.4`, through
  the sim, its `drive_status.3` lighting the run lamp against an oracle that knows nothing
  of logex; 65,536, −1 and a float for that point are pinned refusals from the device (a
  bad value that trips the runner, decision 114), a host's `put_inputs/3` and a force,
  each in the `word`'s words; a `word` force of 65,535 reads back from the forces file
  across a restart and a fresh start; a `bool`'s bit is a pinned refusal; and the contract
  walk draws bit strings, their points, bitwise instructions and bits. The commit names
  what `and`, `or`, `not`, `byte` and `word` break. *Size L.*

  **Status: DONE — landed 2026-10-23**, as six commits, each gated by the full suite's
  exit code: the stanzas first (`c9eeeac`), `byte word dword lword`, the eight mnemonics
  and two family stanzas, `byte_to_word` for the 12 conversions between bit strings and
  `word_to_int` for the 64 between a bit string and an integer, with `docs/naming.md`'s
  `wand` rows amended (decision 155); then the four types, their conversions, the
  comparisons and the arithmetic's refusal (`c784078`); then the bitwise instructions
  (`bb7dab7`); then literal bit access (`e46ede4`); then §4.4's plant and the contract walks
  (`4bd5ce9`); then the documents. The words `byte word dword lword and or xor not shl shr
  rol ror` and the 76 conversions are reserved in any case in every `.ld` file, and the
  type words in every `.logex` file, so a program with a tag named `and`, `or`, `not`,
  `byte` or `word`, a word an engineer may well have used for a status register or a
  mask, stops compiling, told the word is reserved.

  `Logex.Declarations`'s table gains four rows of kind `:bit_string`, 8 to 64 bits, 0 to
  2^N − 1, a `bool` widening into each and each into a wider one by Figure 11, never
  into or out of an integer; `convertible/0` is the integers and the bit strings, over
  which the conversions are generated, `conversion/2` names one and `unsigned_of/1`
  gives the unsigned integer of a bit string's width. An arithmetic slot refuses a bit
  string, "`add` reads a number, but `status` is a word (declared on line 1): a word is
  a bit string, not a number: convert it first, with `word_to_uint`", and one written,
  "compute in an integer and convert the result, with `uint_to_word`"; a comparison's
  slot is `:any_elementary`, two bit strings or two integers, a bit string beside an
  integer tag refused naming both conversions, "`eq` compares `status`, a word …, with
  `code`, an int …: a bit string compares only with a bit string, so convert one of them
  first, with `int_to_word` or `word_to_int`", a literal judged by the tag's type. The 76
  conversions are binary transfers: the source's pattern, two's complement where signed,
  kept to the destination's width and read as its type, `int_to_dword` of −1 giving
  16#0000ffff and `word_to_int` of 16#ffff −1, each always with power (provisional
  below). `and or xor not` take `:any_bitwise`, all bit strings or all integers, a source
  widening into the destination's type and any other told its conversion, computed on the
  pattern and written in the destination's type, always with power; `shl shr rol ror`
  take a count of `:any_int`, its own class, so a `sint` count shifts a `word`, a
  negative literal refused, "`shl` shifts by the literal `-1`: a count is never negative,
  so a negative literal one is refused", and at run time a shift of the width or more
  writes 0 with power, a rotation turns by the count modulo the width, and a negative tag
  count writes the source unshifted with no power and no fault (decision 165).
  `status.3` is a bit of a tag or member of an integer or bit-string type: its number a
  literal checked against the width, "`w.16` names bit 16 of `w`, a word (declared on
  line 1), which has bits 0 to 15", a bool's refused, "which has no bits"; read and
  written in place, every other bit kept, the top bit of a signed type its sign; a
  one-shot's storage bit in a bit of a tag of its own, never of a member, blocked across
  an edit by its name, `status.3`; a write of a bit a write of its word, for the writer
  warnings, a `var_external`'s global and the input-point refusal; a coil on a bit and a
  whole-word write of its word the second-`ote` warning, either first; and an edit that
  changes a one-shot's rung on a bit blocks it once, as an `ons` on a bool.

  The Done-when is `bit_string_test.exs`'s, rule by rule: `shr` of an `int` −2 by 1
  32767, `rol` of a `byte` 2#1001_0001 by 1 2#0010_0011, a shift by the width 0, a
  negative literal count refused, `shl` of a `word` 16#00ff by an `int` at −1 16#00ff with
  no power and no fault and by 16 and 40 0 with power, `rol` of a `byte` by 9 as by 1,
  `ror` by −3 the source with no power, every width's top bit read and written in two's
  complement, the three refusals, the coil on a located input's bit and a
  `var_external`'s bit, the second-`ote` warning, the edit's block and a `bool`'s bit;
  and `end_to_end_test.exs`'s, §4.4's plant from files on disk with `var_global
  drive_status word at drive.i.4` and a lamp program `xic status.3 ote lamp` through the
  sim and the runner on the manual clock against an oracle that knows nothing of logex,
  65536, −1 and 37.5 refused from the device, from `put_inputs/3` and as a force in the
  word's words, a force of 65535 read back from the forces file across a restart and a
  fresh start. `api_contract_test.exs`'s host walk draws the bitwise instructions and
  bits over every integer width and bit string against an oracle restated in Elixir, its
  reach a shift past the width, a negative count and a bit written, and its configuration
  walk word points, read, forced, refused and read by bit, each reach held over 10 and 6
  seeds. A bitwise scan's cost in reductions is linear and a `word` destination costs
  within 5% of a `uint`'s; a bit read or written is linear too.

  The mutation table, each judged by the full suite's exit code. The types (`c784078`): B1
  (`bool` widening into no bit string), B2 (a `byte`'s range 0..127), B3 (`lword`'s
  article), B4 (`conversion/2` over the integers only), B5 (a transfer's pattern read
  signed), B6 (a conversion passing no power), B7 (the arithmetic's bit-string refusal
  gone), B8 (the written refusal's conversion reversed), B9 (a mixed comparison taken),
  B10 (`eq`'s slot `:any_num`), B11 (a bit string's non-integer value taken), B12 (the
  unsigned of a width chosen signed), B13 (`word` an unsigned row), B14 (a `byte` not
  widening into a `word`), B15 (the warnings' conversions over the integers only), B16
  (a transfer keyed by the source's width), B17 (`:any_elementary` gone) and B18 (a mixed
  comparison's conversions in the other order) red; B19 (`class_range/1` over every row)
  equivalent, every class range read being an integer class's, so the code was taken
  back. The bitwise instructions (`bb7dab7`): X1 (`and` an OR), X2 (`not` the identity), X3
  (a negative count passing power), X4 (a negative count writing 0), X5 (a shift past the
  width keeping bits), X6 (a rotation not taken modulo the width), X7 (`ror` turning
  left), X8 (`not` of the unmasked pattern), X9 (a bitwise instruction passing no power),
  X10 (no negative-literal refusal), X11 (every operand held to one class), X12 (a bit
  string no bitwise destination), X13 (no hand-edit check of a bitwise destination), X14
  and X15 (no all-literal warning for the binary and for `not`), X16 (a bit-string
  destination found by its fallback, a cost only), X17 (a count of `:any_bitwise`), X18
  (`not` writing its unmasked value), X19 (`shr` by one more) and X20 (`:any_bitwise`
  the bit strings only) red, X16 since the test that a `word` destination costs within 5%
  of a `uint`'s. Bit access (`e46ede4`): Y1 (bit N of an N-bit type taken), Y2 (no signed
  top-bit mask), Y4 (a 0 clearing every other bit), Y5 (a written bit clearing its word),
  Y6 (a bit storage bit never blocked), Y7 (a frozen block's bit storage not held), Y8
  (the block tree's bit leaves), Y9 and Y10 (the walk's bit use and storage bit gone),
  Y11 (a second one-shot on one bit taken), Y12 (a member's bit refused as unwritable),
  Y13 and Y14 (the second-`ote` warning's two orders), Y15 (the storage-write warning by
  the word), Y16 (an edit's bit storage not blocked), Y17 (an edit's report giving a
  bit's value as 0), Y18 (an edit blocking on any write of the word), Y19 (`bit_writes/1`
  empty), Y20 (the bit lowering's mask), Y21 (`lowered?/1` taking no bit), Y22 (the
  width message's top bit) and Y23 (a member's bit unchecked) red, Y17 and Y21 since a
  test of their own, the report's bit value 1 and a block body's bit held to
  `lowered?/1`; Y3 (a bit read as `band(value, mask) == mask`) equivalent, the two
  readings agreeing for every value in range, which the entry check holds every value to.
  The plant and the walks (`4bd5ce9`) are tests. 1800 tests (10 doctests), up from 1753.

  *Provisional readings* (the record's, the questions below the first four): (1) a
  bit-string conversion always passes power, no pattern being out of range of another;
  (2) the arithmetic's refusal names the unsigned integer of the bit string's width,
  `word_to_uint`, not every integer it could be read as; (3) a comparison's slot is named
  "a number or a bit string"; (4) a `bool` is refused as a bitwise operand, IEC's ANY_BIT
  holding it; (5) a shift's count is an integer tag of any width or a literal, a bit
  string refused, and a literal count of the width or more taken, writing 0; (6) a
  bitwise instruction of literals draws the all-literal warning; (7) `status.03` is bit
  3, its number read by its value; (8) a member's bit is read where the member is read
  and written where logic writes the member, and refused as a one-shot's storage bit;
  (9) a coil on a bit and a whole-word write of its word draw the second-`ote` warning in
  either order, and another write to a word holding a one-shot's storage bit draws the
  storage-write warning; (10) an edit blocks a one-shot on a bit where the program that
  last scanned writes its word another way, as it does for a bool; (11) every new
  message's words; and (12) a configuration's writer warning names no one-shot on a bit
  of a shared word, only the word's first writer.

  **Questions for the maintainer**, answered on 2026-10-23 (decisions 204 to 207, below):
  1. *Whether a bit-string conversion passes power always* (decision 148). A drive's
     status `word` read 16#1234 is cut into a `byte` for a lamp panel by `word_to_byte`,
     which writes 16#34. An integer conversion that keeps low bits passes no power, so a
     lamp after it shows the value did not fit; a bit-string conversion keeps the low
     bits too, but nothing about a pattern is "out of range", so logex passes power
     always, and the lamp after `word_to_byte` stays lit. The other reading passes no
     power where a bit above the destination's width is set, as the integer conversions
     do. IEC's binary transfers (Ed 3 Tables 24 and 25) raise no error; Logix has no
     bit-string types, and a value put into a narrower integer has "the upper portion of
     the larger integer" truncated and "generates an overflow" (1756-RM018A, Data type
     conversions, p.874).
  2. *What a comparison's slot is called in a message.* `eq` on a `bool` is refused,
     "`eq` reads a number or a bit string, but `b` is a bool (declared on line 1)". IEC's ANY_ELEMENTARY
     takes more than numbers and bit strings, times and strings, which logex has not
     landed; the other readings name it "an elementary value" or list every type word.
  3. *Whether a `bool` may be a bitwise operand.* IEC's ANY_BIT holds BOOL, so `and a b
     c` on three bools is IEC's AND of bools; logex refuses it, since a bool's AND is a
     series of contacts, `xic a xic b ote c`, the ladder way, and a `bool` widens into a
     `word` with `move`. Logix's AND takes SINT to LREAL, never a BOOL (1756-RM018A,
     pp.494–496, its operands SINT to LREAL). The other reading takes bools as one-bit
     strings.
  4. *Whether a coil on a bit and a write of its whole word warn.* A conveyor's status
     word is written by `move status_in status` and its bit 3 by `ote status.3`; whichever
     comes later wins that bit each scan, so logex warns as for two `ote`s on one tag. The
     other reading warns only where two coils meet one bit, as a program that builds a
     word whole and then sets one bit is common.

  **M5-8's review**, fixed on 2026-10-23, each with a test that fails when it is
  reverted. No wrong result; four rules with no test, two warnings missing, a compile
  cost nobody recorded, and two small points. (1) Four of the review's mutants survived
  the full suite, each now a test in `bit_string_test.exs` (`f4da93e`, tests only): a coil
  on a bit of a member keeps the member's other bits, `ote c.pv.3` on a `pv` of 100
  giving 108 (R11); an edit that moves a one-shot's rung from `s.3` to `s.4` blocks it
  once, `{:ons_blocked, "x", 0}`, so the edge the edit makes fires no pulse (R6); an edit
  that stops writing a member's bit forecasts and reports the member `{:unwritten,
  "c.pv", 10}` (R7, decision 96); and a literal shift count of 0 is taken, each of `shl
  shr rol ror` writing its source with power (R8). (2) Decision 187's warning is given for
  a bit string, which compares as unsigned: `ge w 0`, `lt w 0`, `le w 65535` and `gt 0 w`
  on a `word` are warned, "and a word holds nothing below `0`", at each bit string's two
  limits (provisional, question 5 below; `7658181`). (3) M5-8 made a program of no bit
  strings 1.13x to 1.18x dearer to compile, its reductions counted where the collector
  never runs: each name was split twice as it lowered, every instruction's operands were
  grouped by class, and the warnings looked for whole writes and storage-bit writes in
  every program. Now each name is split once, an instruction whose operands hold one
  class is checked with no grouping, and the warnings look for no whole write where no
  coil names a bit, nor for a storage bit's writes where no one-shot keeps one: 200 rungs
  of `add a 1234 d` compile in 157,250 reductions, 164,442 before M5-8 (`ebf44ee`) and
  194,053 as it landed, and a test holds six programs, `add`, `move`, a comparison,
  contacts, a conversion and a member, to their ratio of compile to parse before M5-8
  (`7658181`). The spelling commit's smaller rise the review measured, a lone `0` lexing
  in 8,286 reductions for 8,002, is the collector's: counted where it never runs, 200
  lines of `move 0 hh` lex in 6,222 reductions and parse in 8,631 at `f546772` and now
  alike, and `frontend_test.exs` already holds `0` to a name's cost plus 2. (4) A coil on a
  bit of a member and a write of the member whole, `ote c.pv.3` and `move x c.pv`, either
  first, are the second-`ote` warning, as for a tag's bit (provisional reading 9
  extended; `7658181`). (5) README's "Bit strings" cites decision 155 for a signed type's
  top bit, where it cited 156. (6) A bit is quoted as written, `w.03`, in every warning and
  refusal that names it, the IR's bit carrying its name, `{:bit, line, path, n, mask,
  name}`, keyed everywhere by its number's value, and `lowered?/1` holding the name to the
  bit (provisional, question 6 below; `7658181`). The mutation table, each judged by the
  full suite's exit code: on `f4da93e` the review's R6, R7, R8 and R11 red; on `7658181`
  the same four restated on the new IR red, N1 (no bit string at decision 187) red, N2 (a
  member's whole write not looked for) red, N3 (a coiled bit quoted by its value) red, N4
  (a second one-shot's bit by its value) red, N5 (a pulse bit that is its storage bit by
  its value) red, N6 (a member's storage bit by its path) red, N7 (a storage bit's write
  quoted by its value) red once its test wrote `s.002` beside `ons s.02`, where it
  survived when the two spelled the bit alike, N8 (a whole write's storage bit unquoted)
  red, N9 (a bit relowered from its value) red, N10 (a bit's name unchecked by
  `lowered?/1`) red, and the four cost mutants, C1 (a name split twice), C2 (every
  instruction's operands grouped), C3 (whole writes looked for always) and C4 (storage
  writes looked for always), red, each on the cost test alone. The whole of `7658181`'s
  `lib/` reverted fails its five new tests. 1808 tests (10 doctests), up from 1800.

  *Provisional readings* (M5-8's review): (13) decision 187's warning for a bit string,
  at 0 and 2^N − 1; (14) a bit quoted as written, its number keyed by its value; and (9)
  extended to a member's bit beside a whole write of the member.

  **Questions for the maintainer** (M5-8's review), answered on 2026-10-23 (decisions 208
  and 209, below):
  5. *Whether a comparison of a bit string at its limit is warned of* (decision 187). An
     engineer lights a "drive status present" lamp with `ge drive_status 0`, where
     `drive_status` is a `word`, a 16-bit pattern read from the drive. A word holds 0 to
     65535, so the comparison always passes power and the lamp is always lit, whatever the
     drive sends. logex warns of it, "`ge` compares `drive_status` with `0`, and a word
     holds nothing below `0`: its result never changes", as it warns of `ge count 0` on a
     `usint`; the other reading gives no warning, as decision 187 named only the integer
     types, so the engineer sees the lamp always lit and no message. IEC defines no
     warnings; Logix has no bit-string types, and whether
     Studio 5000 warns of a comparison that never changes is `unverified`.
  6. *Whether a message quotes a bit as typed.* An engineer writes `ote conveyor.03` for
     bit 3 of a conveyor's status word, and `ote conveyor.3` on another rung. logex warns
     at the second, "`conveyor.3` already has an `ote` on line 5", and quotes each bit as
     its rung spells it, `conveyor.03` where it was typed so, as a literal is quoted
     (decision 202); bit 3 is one bit however it is written. The other reading quotes every
     bit by its number's value, `conveyor.3`, so the engineer searching for the text of
     the message finds no `conveyor.3` on the rung it names. IEC writes a bit's number as
     an integer, and Logix's tag syntax gives a bit of an integer as `tag.bit` (1756-PM004L,
     p.45); whether either takes or shows a leading zero is `unverified`.
  **The maintainer's answers**, 2026-10-23 (decisions 204 to 209). (1) *Confirmed*: a
  bit-string conversion always passes power (decision 204). (2) *Kept, the lead's
  reading*: a comparison's slot is "a number or a bit string" in a message, the
  maintainer confirming the answers as a whole without taking it up separately (decision
  205). (3) *Changed*: a `bool` is a bitwise operand, as IEC's ANY_BIT holds BOOL (Ed 3
  Figure 5, Tables 30 and 31; decision 206), superseding provisional reading (4).
  `:any_bitwise` holds the bool, named "a bool, a bit string or an integer"; each
  instruction still computes in its destination's type, so `and left right both` of three
  bools computes in a bool and `not at_speed slow` writes the inverse; a bool source widens
  into a bit-string destination by Figure 11, `not ready mask` into a `word` writing
  16#fffe for 1; a bool beside an integer, and a bit string into a bool, are refused, "a
  bool does not widen into an int, and logex has no conversion between them", and a
  literal into a bool must be 0 or 1. A shift or rotate of a bool is one of a one-bit
  pattern under decision 165's rules, a shift by 1 or more writing 0 and a rotate writing
  it back (provisional: IEC's Table 30 types IN as ANY_BIT and states no rule of its own
  for a BOOL); the count stays ANY_INT, a bool count refused. A bit, `w.3`, and a bool
  member logic may write, a counter's `r`, are bools there too, `Logex.Program.destination/3`
  giving a bit `:bool` for `:bitwise`. A bitwise write of a bool is a write as `move`'s,
  no coil, so beside an `ote` on the same bool it draws no second-`ote` warning
  (provisional). Logix's AND takes no BOOL (1756-RM018A p.496), so this is IEC's reading.
  Two messages change: the slot's words, and the member offered for an instance named
  whole, now `c.r` for a counter where it was `c.pv`. (4) *Confirmed*: a coil on a bit and
  a whole write of its word, or of a member, warn in either order (decision 207). (5)
  *Confirmed*: decision 187's warning holds for a bit string (decision 208). (6)
  *Confirmed*: a message quotes a bit as typed, `conveyor.03` (decision 209). No code
  changed for the five.

  The commit (`ebf0363`) holds the code, its tests and decisions 204 to 209.
  `bit_string_test.exs` drops M5-8's bool refusals and adds decision 206's rules, three
  bools at each of their values, a bool widening into each bit string and refused beside
  each integer either way, a bool's shifts and rotates at counts −3, −1, 0, 1, 2 and 17, a bit
  and a counter's `r` read and written, the slot's words, a bit edited in by hand as an
  arithmetic destination, quoted as written, and a bool destination's scan within 5% of a
  `uint`'s; `api_contract_test.exs`'s host walk draws a bool among the types, its oracle
  restating a one-bit pattern, and reaches a bool's two values and a bit inverted into a
  bool and each bit string. A program with no bool bitwise operand compiles and scans in
  exactly the reductions it took at `83cbf3e`, an `and` into a `word`, a `shl` into a
  `uint`, 200 `add`s and 200 rungs of contacts measured. The mutation table, each judged
  by the full suite's exit code: A1 (no bool in the class), A2 (a bool no bitwise
  destination), A3 (a bit no destination), A4 (a bool destination found by the fallback,
  red on the cost test alone), A5 (no transfer into a bool), A6 (a missing conversion's
  message naming an empty one), A7 (the slot's old words), A8 (a bit destination shown
  unquoted), A9 (a bit an arithmetic destination too), A10 (a bool kept to 8 bits) and A11
  (every refusal's conversion dropped), all 11 red, A1, A5 and A10 by the host walk's
  oracle too. 1814 tests (10 doctests), up from 1808.

- **M5-9 · A bit number in a tag, and the major fault.** `status.[n]` (decision 160), an
  integer tag of any width, never an expression, refused on a one-shot's bit; a number
  outside the width at run time the first major fault: `%Logex.Fault{}` gains `severity`,
  `:minor` for a zero divisor, `:major` for `:bit_out_of_range`, with the number read,
  decision 99's placement, and `Logex.Runner` trips on the round's first major fault at
  the end of the step that raised it, running no later step of the round, before its
  write, `{:fault, task, instance, fault}`, on decision 113's one path (§4.12's "The major
  fault", its tenth question answered as recorded). *Done when* the run lamp follows `drive_faults.[sel]` in
  §4.4's plant on the manual clock against an oracle that knows nothing of logex; `sel` at
  16 in a `word` trips the runner with every output 0 once and nothing after, the trip
  naming the instance, file, line and number; a round whose first due task raises the
  fault runs none of its later steps, a later task's instance read through `get/2` after
  the trip as the round before left it, while a second instance of the faulting task's run
  is scanned, a test that fails when the runner runs the round's every step; a lone
  instance's `state.faults` holds the major fault and the scan ran on, the instruction
  doing nothing as §4.12 states it, a test per kind of instruction; a rung a jump skips
  and a block whose `cal` is false with `sel` at 16 raise nothing (decision 82);
  `fault_test.exs` pins the severity on both kinds; every host's pattern on
  `%Logex.Fault{}` in README and the tests is brought to the new field; the runner walk
  reaches the new trip reason, its model running a tripping round's steps up to the one
  that raised it; and an element read stays within a measured bound of a tag's in
  reductions. *Size L.*
  *(Landed 2026-10-23, in four gated commits and one of documents.)* `80f55e6` records 23 curated sources in
  the front end's golden record, each a lex error before M5-9, the commit that lands the
  syntax changing 9 of them, the seven that now lex and two whose error moves to the
  parser, the diff read. `deae114` gives `%Logex.Fault{}` an enforced `severity`, `:minor`
  for a zero divisor, and `read`, the number read out of range, nil for a zero divisor,
  every test's pattern on it brought to the field. ``1cb3a31`` lands `status.[n]`: a name's last
  part a tag's name in brackets, one name token, put into `printer_test.exs`'s generator
  and `@required_shapes` as `:tag_bit_name` in the same commit, a literal in the brackets
  and anything glued after the `]` a located lex error; the bit resolved as a bool, its
  word an integer, a bit string or a member of one, its tag declared and of an integer
  type, any width; lowered to `{:bit_at, line, path, tag, {width, top}, name}`; refused as
  a one-shot's storage bit and as a pulse coil's pulse bit; read and written by the scan
  through a mask from the number read, a number outside the word's bits thrown to the
  instruction's own catch, which only an instruction with such a bit among its first
  three operands and every `cal` have, the instruction doing nothing and passing no power,
  its `%Logex.Fault{severity: :major, kind: :bit_out_of_range}` placed as decision 99
  places a zero divisor's, a block's by its path and in its body's file; `Logex.Walk`'s
  two uses, the warnings' whole-word coil and the edit's rung by its tag. ``0e73741`` trips
  `Logex.Runner` at the end of the step whose run met the round's first major fault,
  before any later step and the round's write, on decision 113's one path, the reason
  `{:fault, task, instance, fault}`; `cycle/3` is unchanged, every due step run and the
  fault an event. Done when: §4.4's plant from files on disk lights its run lamp from
  `drive_faults.[sel]` over 60 seeded readings against an oracle that knows nothing of
  logex, and `sel` at 16 trips it at the fast task's step as the slow task falls due,
  every output 0 once and nothing after, the trip naming `lamp1`, `selected.ld`, line 5
  and 16, the slow task's step never run (`end_to_end_test.exs`); `trip_test.exs`'s round
  of a lamp, a counter after it in the faulting task and a slow task, the counter scanned
  and the slow task's instances read as the round before left them, which fails when the
  runner runs the round's every step (R2 below); a lone instance's faults through
  `call/4`, a test for each kind of instruction, a contact, a coil energised and not,
  `move`, a bitwise instruction and a shift, and a `cal`; a rung a jump skips and a block
  whose `cal` is false raising nothing; `fault_test.exs` pins both severities; every
  pattern on `%Logex.Fault{}` in the tests and README brought to the new field, README's
  "Arithmetic" output re-run; the runner walk reaches `{:fault, ...}` among its trip
  reasons, a program whose bit number is the panel's dint, its model tripping a step whose
  run met a major fault at its end, no later step run; and a bit read through a tag costs
  35 reductions a rung against a literal bit's 27 and a bool's 24, within 8 of the first
  and 1.5x the second (`tag_bit_test.exs`). Cost against `1ee676b`: a program of no bit a
  tag numbers scans rung for rung in exactly what it did, contacts, a literal bit and a
  `move` measured, and a `cal` one reduction more a run, its catch, which a test pins
  (a `try` costs a reduction on the BEAM, measured); every program compiles in fewer
  reductions than before, `Logex.Walk.uses_of/2` now a recursion over the slots and
  operands where it zipped them, 1.4% fewer for 200 `add`s.

  The mutation table, each judged by the full suite's exit code (`mut3/run.log`,
  `mut4/run.log`): on `1cb3a31`, T1 (no bracket in a name), T2 (a glued `]`
  taken), T3 (a bracketed literal taken), T4 (no tag bit resolved), T5 (its tag
  unchecked), T6 (a bit-string tag taken), T7 (no member's tag bit), T8 (lowered as a
  member), T9 and T10 (a one-shot's storage bit, a pulse bit, through a tag taken), T11 (an
  unsigned top bit for a signed word), T12 (the top bit out of range), T13 (no number out
  of range), T14 (power passed on a fault), T15 (the fault dropped), T16 (the fault
  minor), T17 and T19 (no catch for a second or a third operand), T18 (no catch for a
  `cal`), T20 (the tag no use), T21 (a member's bit no member write), T22 to T24 (a coil,
  a write and a storage bit not the word's whole), T25 (an edit's rung blind to the tag),
  T26 (no destination type), T27 and T28 (no IR operand or unlowering for `lowered?/1`)
  and T29 (a negative number in range), all red, T18, T27 and T28 on tests added for them
  after they survived, T18 at first on the cost test alone; T30 (no declaration note for
  the tag) survived, its clause dead, no program that declares nothing reaching the tag,
  and was removed. On `0e73741`, R1 (no major fault trips), R2 (the trip at the end of the
  round, every step run, the test that fails when the runner runs the round's every step),
  R3 (the watchdog named before the fault) and R4 (a minor fault trips too), all red. 1855
  tests (10 doctests), up from 1814.

  *M5-9's review (2026-10-23), in two gated commits and one of documents.* The review found
  no defect in the code and five gaps in the tests, of which three were mutants that
  survived the suite. ``6c77d60`` pins what was right, tests only: a step that meets two
  major faults, `l` then `l2` in one task, trips for the first, in the order its instances
  run (`trip_test.exs`, killing N3, the trip named for the step's last major fault, which
  had failed only on a real-clock test and passed alone); a `cal` operand's bit number
  checked as any instruction's, `cal b1 w.[x] y` told "`x` is not declared" and `w.[f]` of
  a bool told it is no integer, on a var_input and on a var_output (killing N11, the check
  removed); an edit that changes a one-shot's rung only by its bit's word, `s.[n]` to
  `t.[n]`, blocking the one-shot (killing N13, the rung compared without the word); and a
  `cal` whose copy-out is out of range dropping its body's minor faults with its run,
  `state.faults` holding the `cal`'s major fault alone, which provisional reading 2 now
  says. ``6f7d49c`` changes two things. A coil on a bit a tag numbers, `ote w.[n]`,
  beside any write of its word whole, `move 5 w`, `and k k w`, or a member's, `move x
  c.pv` beside `ote c.pv.[n]`, is the second-`ote` warning in either order, as decision
  207 has it for `ote w.3`, where neither order warned, the coil never counted as one on
  a bit of the word (provisional reading 4, grown; the third question grown with it). And
  the lexer names a bracket's run whole through its `]` on the line: `s.[16#3]`, cut at
  its `#`, and `s.[-1]` are `{:bracketed, run}`; brackets no one name fills and closes,
  `s.[]`, `s.[n`, `s.[n.m]` and `s.[ n ]`, `{:bracket, run}`; and a bracket held apart
  from its name's `.`, `s. [n]` and `s .[n]`, `{:detached, run}`, each until then a bare
  illegal `.` (provisional reading 8); the golden record unchanged, each source failing
  on its line as before. A program with no coil on a bit a tag numbers compiles in no more
  reductions than at `6c77d60`, 25 literal bit coils beside 25 whole writes in 7 more,
  and every source tokenizes in exactly what it did; README's `selected.exs` and
  `fill.exs` re-run byte-identical. The mutation table, each judged by the full suite's
  exit code (`rv9/run.log`): N3, N11 and N13 red on the tests above; on ``6f7d49c``,
  W0 (the warnings' fix reverted whole), W1 (a coil on `w.[n]` not counted among the
  coiled words), W2 (a whole write before it not looked at), W3 (it not a coiled bit for
  a later whole write), W4 (it not a whole write for a later `ote w.3`), L0 (the lexer's
  fix reverted whole), L1 (no `.[` beginning a lexeme), L2 (`s.[-1]` no literal), L3 (no
  look past a `.` and a space), L4 (nothing glued after a closed bracket), L5 (an open
  bracket's run cut at the `[`) and L6 (a bracketed literal cut at its `#`), all red. The
  first question now cites the Add-On Instruction, which a `cal` is
  closer to, and says where Logix differs inside the body; decision 206's `not` of a bool
  into a word is annotated as IEC's departure and put as a fifth question. 1859 tests
  (10 doctests), up from 1855.

  *Provisional readings* (M5-9): (1) the fault's field for the number read is `read`, and
  the fault names no operand, its file and line finding it; (2) a `cal` whose operand's
  number is out of range runs nothing, its body's run dropped, whether its copy-in or its
  copy-out met the number, and with it, since M5-9's review, the minor faults of a body
  that ran before its copy-out met the number; (3) a step that met a major fault and outlasted its watchdog
  trips for the fault; (4) a coil on `w.[n]` is a coil on its word whole, two of them,
  one beside a coil on a bit of the word or, since M5-9's review, one beside any write of
  the word whole, `move 5 w`, either first, the second-`ote` warning, and any write of one
  a write of each storage bit in the word; (5) a literal in the brackets, `w.[3]`, is a
  lex error told to write `w.3`; (6) a bit-string tag as a bit number is refused, told
  `word_to_uint`; (7) a member's bit through a tag, `t1.acc.[n]`, is taken, as
  `t1.acc.3` is; and (8), since M5-9's review, a bracket the lexer cannot read is named
  whole through its `]` on the line, `s.[16#3]` and `s.[-1]` as a literal in brackets,
  `s.[ n ]` as brackets no one name fills and closes, and `s. [n]` and `s .[n]` as a
  bracket held apart from its name's `.`.

  **Questions for the maintainer** (M5-9), answered on 2026-10-23 (decisions 210 to 214,
  below):
  1. *What a block call does when its bit number is out of range.* A conveyor's lamp
     block is called `cal lamp1 drive_faults.[sel] lamp`, and `sel` reaches 16. As built,
     the call does nothing on that scan: the block's body does not run, so its timers do not
     move and its outputs keep last scan's values; the runner then trips, every output off.
     The other reading runs the body with that one input left as it was, so a timer in the
     block moves on. Under the runner the operator sees the same thing, every output off;
     only a host that runs the program itself sees the difference, in the block's own
     values. IEC says nothing. In Logix a faulted instruction *"does not run"* (1756-PM014O
     p.9), a JSR whose input parameter is out of bounds *"aborts (the subroutine does not
     run)"* (p.9), and so does an Add-On Instruction, which is closer to a `cal`, an
     instance with its own state; that is the reading built. Logix and logex differ inside
     the block, though: *"When a fault occurs inside an Add-On Instruction, the remainder
     of the Add-On Instruction aborts"* (pp.9–10), where logex's body does nothing at the
     faulting instruction and runs on, as a program's rungs do, so a lamp block whose first
     rung faults still sets its second rung's output in logex and, where a fault routine
     clears the fault, not in Logix. Under the
     runner the operator sees every output off either way. A block that ran and then met
     the number on its way out, `cal lamp1 go lamps.[sel]`, drops its whole run, the minor
     faults it met among it, a zero divisor in the block reported by no event.
  2. *Which reason a trip names when one step both faults and runs too long.* The fast
     task's step reads `drive_faults.[sel]` with `sel` at 16 and also takes 60 ms against
     its 50 ms watchdog. As built, the trip names the fault, "bit 16 of `drive_faults` on
     line 5 of `selected.ld`", which is the cause the engineer must fix; the other reading
     names the watchdog, "task fast took 60 ms", which is what a scan timer measured last.
     Either way every output goes off once. IEC says nothing; Logix halts logic at the
     faulting instruction (1756-PM014O p.9), so its watchdog never sees that scan end.
  3. *Whether two coils on bits a tag numbers warn.* A program lights `ote lamps.[a]` on
     one rung and `ote lamps.[b]` on another, `a` and `b` set by two selector switches.
     As built, the second is warned of, "`lamps.[b]` already has an `ote` on line 4: the
     last one in the scan decides it", since either may write the bit the other does, as
     a coil on `lamps.3` beside `move x lamps` is; the other reading warns of nothing,
     since the two are often meant to be different bits. Since M5-9's review the same goes
     for `ote lamps.[sel]` beside `move panel lamps`, either first, which decision 207
     already warns of for `ote lamps.3`: both drive the lamp, and the later rung wins every
     scan. The plant runs the same either
     way; only the engineer's list of warnings differs. IEC defines no warnings; whether
     Studio 5000's verify reports a duplicate destructive bit for an indirect address is
     `unverified`.
  4. *Whether `status.[4]`, a literal in brackets, is taken.* Logix writes a bit both ways,
     `variable3.[4]` (1756-RM018A p.885) and `variable1.2` (p.884). As built, logex
     refuses `status.[4]` with a message telling the engineer to write `status.4`, so that
     one bit has one spelling and an online edit compares rungs by it; the other reading
     takes it as the very bit `status.4`, so text pasted from a Logix export compiles
     unchanged. Nothing the operator sees differs. IEC writes only `status.%X4` or
     `status.4` (Ed 3 Table 17).
  5. *Whether `not` of a bool into a word inverts the word's every bit.* Decision 206 took
     a bool as a bitwise operand. A lamp panel's `word` is set from one switch with `not
     left mask`. As built, `mask` is 16#fffe while `left` is made and 16#ffff while it is open: logex computes in the
     destination's type (decision 147), so the bool's one bit is widened to 16#0001 and the
     word inverted, every lamp but the first lit, as IEC's `NOT(BOOL_TO_WORD(left))`
     gives. The other reading is IEC's own typing of `mask := NOT(left)`: `NOT` of a BOOL
     is a BOOL, 0, widened into the word, 16#0000, every lamp off, and 16#0001 while
     `left` is open. IEC's Table 31 overloads NOT on ANY_BIT, its result the input's type
     (Ed 3 p.89); Logix's NOT takes no BOOL (1756-RM018A pp.494–496). The decision's
     record now says it departs from IEC there; nothing changed.

  **The maintainer's answers**, 2026-10-23 (decisions 210 to 214). (1) *Confirmed*: a
  `cal` whose bit number is out of range runs no body that scan, as Logix's faulted JSR
  and Add-On Instruction do not run (decision 210). (2) *Confirmed*: a step that both
  faults and overruns its watchdog trips naming the fault (decision 211). (3)
  *Confirmed*: coils on bits a tag numbers warn, beside each other and beside a whole
  write of the word (decision 212). (4) *Changed*: `status.[4]`, a literal in brackets,
  is accepted as the very bit `status.4`, so that text pasted from Logix compiles
  (1756-RM018A pp.884–885; decision 213), superseding provisional reading (5): the
  brackets hold any one number the lexer reads, `status.[16#4]`, `status.[1_0]` and
  `status.[04]` among them, a negative one, `status.[-1]`, lexing and refused when the
  program compiles as outside the word's bits, as `status.16` is (provisional; whether
  Logix takes a based or a negative literal there is unverified); brackets that begin as a
  number and hold no one number, `status.[8#3]` or `status.[3x]`, a lex error naming the
  run whole; the bit quoted as written and keyed by its number, so an edit that only
  respells `status.4` as `status.[4]` changes no rung. (5) *Changed*: `not` and the
  shifts follow IEC's typing, computing in their source's type and widening the result
  into the destination by value (decision 214), so `not left mask` of a bool into a
  `word` gives 16#0000 for a made `left` and 16#0001 for an open one, superseding decision
  206's 16#fffe; `rol` of a byte into a word rotates within 8 bits; `not` of a `usint` 5
  into an `int` is 250 and `shr` of an `sint` −2 by 1 into an `int` 127, IEC's implicit
  conversion between integers being by value, where Logix's logical instructions widen by
  zero fill (1756-RM018A p.871), its NOT of a SINT −1 into a DINT 16#ffffff00; `and`, `or`
  and `xor` keep computing in the destination, the two readings agreeing bit for bit,
  since widening by value is a zero or a sign extension, each commuting with them, and for
  mixed source widths IEC's widest common type gives the same bits again; a literal
  source computes in the destination's type, as its slot judges it (provisional).

  In two gated commits and one of documents. `0779f5d` records 20 curated sources in the
  front end's golden record, each a lex error before decision 213. `d9317d5` lands both
  changes with decisions 210 to 214: the lexer reads a literal in brackets as the name's
  last part, one token kept as written, through `in_brackets/3`, its `{:bracketed, run}`
  now brackets that begin as a number and hold no one number; `printer_test.exs`'s
  generator draws `status.[4]`, `w.[16#a]`, `t1.acc.[03]` and `s.[-1]`, a new shape,
  `:literal_bit_name`, in `@required_shapes`; the golden record regenerated, its diff
  read, 11 sources changed, the nine new ones that lex and M5-9's `xic s.[3]` and `xic
  s.[-1]`, every other unchanged; `Logex.Compiler` reads the literal's value through the
  lexer (`literal_number/1`) and resolves and lowers the bit as `status.4`, a negative
  number refused at its line; the runtime's `not` and shifts look their source's type up
  (`source_bits/3`) and widen the result (`widened/3`). Tests: `tag_bit_test.exs`'s
  decision 213, every type's bits in four spellings read and written, a member's and a
  one-shot's, the refusals quoted as written, the warning keyed by number and an edit
  that only respells; `bit_string_test.exs`'s decision 214, the lamp, IEC's own cases,
  every pair Figure 11 widens over `not` and each shift and rotate at counts about the
  source's width, `and`, `or` and `xor` of mixed widths against both typings, a literal
  source with a rotate that only the destination's width gives, a bit and members, and
  the cost; `frontend_test.exs`'s tokens and round trip; and `api_contract_test.exs`'s
  host walk, its oracle restating `not bb bv` in the bool's bit and drawing `not` and a
  shift of the drawn type into a wider one, its reach each type with a wider one. Cost
  against `a281a15`: a `not` or a shift costs 4 reductions more, its source's type looked
  up, a narrower source 3 more again; a program of neither scans in exactly what it did; a
  program of no bit in brackets lexes and compiles in exactly what it did, 200 `add`s,
  contacts, members and literal bits measured, and one of 200 tag bits compiles in 0.8%
  more. README's `status.exs` and `selected.exs` re-run, the first showing a bool's
  inverse in a `word` and the second a literal in brackets read and one past the bits
  refused. The mutation table, each judged by the full suite's exit code
  (`a8/mut/run.log`): I1 (`not` computed in the destination's type), I2 (a shift in the destination's width),
  I3 and I4 (a bit, `s.3` or `s.[n]`, computed in the destination's type), I5 (a member
  so), I6 (the result widened without being read as the source's type, a signed one
  zero-extended), I7 (a bool so), I8 (a literal computed in the widest type, red on a
  literal rotate added for it), I9 (the signed integers in the destination's type); L1
  (a literal in brackets still refused), L2 (any byte taken for its `]`), L3 (any
  number taken, `s.[8#3]`), L4 (nothing glued after the `]` looked at), L5 (a negative
  literal refused); C1 (the literal read as a tag's name), C2 and C3 (a negative number
  taken, a tag's and a member's), C4 (no member's literal bit), C5 (lowered as the next
  bit), C6 (a bool's literal bit told it has no members) and C7 (a negative number
  lowered as a bit), all 21 red, I4 and I8 on tests added after they survived; and
  C1's first spelling did not compile and was replaced. 1872 tests (10 doctests), up from 1859.

- **M5-10 · Reals.** A spike first, on Elixir 1.20.4 and OTP 28, throwaway: the cost of a
  destination lookup and a single-rounding write, and the shortest spelling of a single
  that reads back to it, written and tested. Then the stanzas `real` and `lreal`, the 34
  real conversions, the 16 truncations `real_trunc_<integer>` and
  `lreal_trunc_<integer>` (decision 162) and `sqrt` (decisions 148 and 79); the literal
  (decision 149, its spelling kept by decision 202's rule wherever it is not the plain
  text of its value) through the lexer, the parser, `well_formed!/1`, the printer, the
  generator, `@required_shapes` and curated golden sources; arithmetic, comparisons and
  `move` (decision 147); decision 150's zero divisor, saturation, −0.0, subnormals and
  single rounding; a real's zero, 0.0; host, device and force values, the forces file's
  spelling and the configuration file's `print/1` (decision 156); real points; and a bit
  of a real, `fan_speed.3` or `fan_speed.[sel]`, refused (decision 155); a real into an
  integer rounded and then wrapped, with no power, where the rounded value does not fit
  (decision 161); `sqrt` of a negative source 0.0, no power and the minor fault
  `:negative_sqrt`, decision 99's kinds grown by one (decision 164); and an integer at a
  real point stored as the nearest real, silently, only a value beyond the real's range a
  bad value (decision 166). A literal negative source, `sqrt -4.0 x`, is refused when the
  program compiles, at its line, as decision 78 refuses a literal zero divisor (decision
  167). *Done when* no float exception leaves a scan
  under a seeded walk of values near each real's limits, at zero divisors and at
  subnormals; no state, output, `get/2` answer or forces file ever holds −0.0, an
  infinity's bits or a subnormal, each pinned by a test that fails when its guard is
  reverted (a `real` write of 3.5e38 the one that encodes an infinity silently); every
  write to a `real` rounds to the nearest single, `move 0.1 x` reading back through
  `get/2` as 0.10000000149011612 in a `real` and 0.1 in an `lreal`, and `add 16777216 1.0
  x` giving 16777216.0 in a `real` and 16777217.0 in an `lreal`, each failing when the
  rounding is reverted; a literal `0.0` or `-0.0` divisor and a `mod` of a real are
  refused at their lines; `1.`, `.5`, `1e5`, `1.5e+3` and Logix's `1.5L` are pinned
  refusals at their columns, each failing when its lexer clause is reverted; `fan_speed.3`
  and `fan_speed.[sel]` on a `real` and an `lreal` are pinned refusals at their lines;
  IEC's examples are tests, `real_to_int` of 1.5, 2.5, −1.5, −2.5, 1.6 and 1.4 giving 2,
  2, −2, −2, 2 and 1 and of 0.5 and 3.5 giving 0 and 4, so that a ties-away
  implementation, Elixir's `round/1`, fails them, `real_trunc_int` and `lreal_trunc_int`
  of −1.6 giving −1 and `trunc_int` a pinned unknown mnemonic; a value outside the target
  is rounded and then wrapped (decision 161), `real_to_int` of 32767.6 giving −32768, of
  32768.4 −32768, of 40000.7 −25535 and IEC's own case, 70000.4, 4464, each with no power,
  and of 32767.4 32767 with power, a test that fails when the value is truncated before
  it wraps, as the record first read it (32767.6 then giving 32767 and 40000.7 −25536),
  and `real_trunc_int` of 40000.7 giving −25536 with no power; `sqrt` of −0.25 writes 0.0
  with no power, its fault `:negative_sqrt`, minor, `instruction: :sqrt`, in a lone
  instance's `state.faults` and as a cycle's `{:fault, ...}` event, `fault_test.exs`
  pinning its kind and severity, a test that fails when the source is not checked; an
  integer of 16,777,217 at a `real` point, from the sim, a host's `put_inputs/3` and a
  force, reads back through `get/2` as 16777216.0 with no trip and no refusal, and 2^128
  at a `real` point trips the runner as a bad value from the sim and is refused from a
  host and a force, in the `real`'s words, while 2^53 + 1 at an `lreal` point reads back
  as 2^53, each a test that fails when its rule is reverted; a `real` forced
  or printed as `0.1` reads back exactly; a changed real initial value is reported as
  `:initial_changed`, `var x real 0` edited to `var x real 0.0` among them, `{0, 0.0}`,
  the running 0.0 kept (decision 157), a test that fails when the comparison is `!=`
  (`Logex.Edit.Plan.changed/2`'s, `!=` at M5-3, under which 0 and 0.0 are one value, as
  M5-3's review noted, so it becomes `!==`); the
  configuration file's round trip holds with reals; the contract walk's arithmetic oracle
  covers both reals; and the fan's speed in §4.4's plant is a `real` read from the sim,
  against an oracle that knows nothing of logex. *Size XL.*
  *(Landed 2026-10-23, in four gated commits and one of documents.)* A spike first,
  throwaway (`m510/spike`): a destination looked up in `move` cost two reductions a rung,
  17 to 19, 12%, and a match on the scan in a clause's head none, so the reals follow
  decision 197's pattern rather than §4.12's routine choice of a look-up at run time
  (provisional reading 1); the BEAM's `<<x::float-32>>` rounds to the nearest single but
  encodes infinity's bits past a single's range, which no match reads back, and an integer
  rounded through a double rounds twice, `2^60 + 2^36 + 1` coming out at `2^60` where its
  single is `2^60 + 2^37`; and the shortest decimal that rounds back to a single, tried at
  1 to 9 significant digits, read back exactly over 50,000 random singles and 20,000
  doubles. `360cb6a` surveys `real`, `lreal`, the 34 real conversions and the 16
  truncations as two family stanzas, and `sqrt`, its conventional row from 1756-RM018A
  pp.470–475, where Logix roots the absolute value of a negative source (p.474), and
  `naming_test.exs` counts the five families, 182 mnemonics. `e10436d` records 30 curated
  sources in the front end's golden record, each a lex error before M5-10. `a6c0a75`
  lands the reals: the literal through the lexer, the parser, `well_formed!/1`, the
  printer, `printer_test.exs`'s generator and `@required_shapes` (`:real_lit`,
  `:negative_real_lit`, `:exponent_real_lit`, `:spelled_real_lit`), the golden record
  regenerated and its diff read, 15 sources changed, the ones that now lex; `real` and
  `lreal` as rows of the type table, declared everywhere an integer is, their zero 0.0;
  `Logex.Real`, internal, the one place a real's value is made, read and spelled;
  `move`, the arithmetic, the comparisons, `sqrt`, the 34 conversions and the 16
  truncations, each through `Logex.Real.stored/2`, so that every write into a real is its
  type's nearest value, saturated before it encodes, −0.0 and a subnormal 0.0; the zero
  divisor's 0.0, the negative root's fault, a literal negative root and a literal `0.0`
  divisor refused, a real's bit refused; a host's, a connection's and a state's reals held
  to decision 166's and 150's rules; an edit's initial values compared with `!==`; and a
  configuration's real globals and constants, `print/1` spelling a real as the shortest
  text that reads back to it. `5f64be8` takes the reals to the plant: a real point's value
  from the sim any number, stored as its nearest real; a force held at that value and
  written to the forces file in the same spelling, read back only as written; the fan in
  §4.4's plant from files on disk; the contract walk's real arithmetic; and README's
  "Reals", its output a real run. The shortest spelling of the largest single crashed a
  force of it until a candidate past a single's range was passed over, a fix the force
  test pins.

  Done when: a seeded walk of 2,000 scans of every arithmetic instruction, conversion,
  truncation and root over values near each real's limits, at zero divisors and at
  subnormals, raises nothing and leaves no state holding −0.0, a subnormal or a value no
  single is (`real_test.exs`), and the contract walk's 120 programs, alone, across a
  restart and an edit and in a resource, every state compared exactly against IEEE 754's
  rounding and IEC's rules restated, reach a saturation and a flush in each real, −0.0, a
  tie and a wrap (`api_contract_test.exs`); `lreal_to_real` of 3.5e38, the value the 32-bit
  encoding turns silently into an infinity's bits, is the single's largest with no power;
  `move 0.1 x` is 0.10000000149011612 in a `real` and 0.1 in an `lreal`, and `add
  16777216 1.0 x` 16777216.0 and 16777217.0, R1 below failing them; a literal `0.0` or
  `-0.0` divisor and a `mod` of a real are refused at their lines (R11); `1.`, `.5`, `1e5`,
  `1.5e+3` and `1.5L` are refused at column 6 of `move … x`, each failing when its lexer
  clause is reverted (L1 to L5); `fan_speed.3` and `fan_speed.[sel]` on a `real` and an
  `lreal` are refused at their lines; IEC's examples, `real_to_int` of 1.5, 2.5, −1.5,
  −2.5, 1.6 and 1.4 giving 2, 2, −2, −2, 2 and 1 and of 0.5 and 3.5 0 and 4, Elixir's
  `round/1` failing them (R2), `real_trunc_int` and `lreal_trunc_int` of −1.6 −1, and
  `trunc_int` a pinned unknown instruction; `real_to_int` of 32767.6 −32768, of 32768.4
  −32768, of 40000.7 −25535 and of 70000.4 4464, each with no power, of 32767.4 32767
  with power, a truncation before the wrap failing it (R7), and `real_trunc_int` of
  40000.7 −25536 with no power (R8); `sqrt` of −0.25 writes 0.0 with no power and
  `%Logex.Fault{severity: :minor, kind: :negative_sqrt, instruction: :sqrt, read: -0.25}`
  in `state.faults` and as a cycle's event, `fault_test.exs` pinning its kind and severity,
  the source unchecked failing it (R6); 16,777,217 at a `real` point from the sim, a
  host's `put_inputs/3` and a force reads back as 16777216.0, 2^128 trips the runner from
  the sim and is refused from a host and a force in the real's words, and 2^53 + 1 at an
  `lreal` point reads back as 2^53 (R5, R15, F1, F5); a `real` forced or printed as `0.1`
  reads back exactly (F2, F3); `var x real 0` edited to `var x real 0.0` is
  `{:initial_changed, "x", {0, 0.0}}`, the running 0.0 kept, `!=` failing it (R9); the
  configuration file's seeded round trip draws real globals; and the fan's speed in §4.4's
  plant is a `real` read from the sim, against an oracle that knows nothing of logex,
  through a restart and a fresh start from the forces file (`end_to_end_test.exs`).

  Cost against `5eac41f`: a program of no reals scans rung for rung in exactly what it
  did, 21 programs measured, contacts, branches, timers, counters, one-shots, jumps, a
  `cal`, every integer instruction and bit (`m510/cost_base.txt` and `cost_now.txt`), and
  compiles in no more reductions, 28 to 727 fewer, and every source tokenizes in exactly
  what it did; `real_test.exs` pins `move` of a dint at 17 reductions a rung, `add` at 34
  and `gt` at 27, as before. A real's `move` costs 29 a rung on a scan measured alone, as
  the review found, and 35.45 in `real_test.exs`'s harness, which hands the inputs to each
  call, an lreal's 29 in both, within 2.5x a dint's (the figure 35 recorded here before the
  review was the harness's), its `add` and `sqrt` 46 and 36, within 1.5x a dint's `add`; a
  dint's
  `move` in a program that holds a real 21, its destination looked up; and a program of
  reals compiles and scans in linear reductions.

  The mutation table, each judged by the full suite's exit code (`m510/mut/run.log`), on
  `a6c0a75`: R1 (a `real`'s write not rounded to its single), R2 (a tie rounded away
  from zero), R3 (a saturation passing power), R4 (no subnormal flushed), R5 (an integer
  into a `real` rounded through a double), R6 (no negative root checked), R7 (a
  conversion truncating before it wraps), R8 (a truncation rounding), R9 (the edit's
  `!=`), R10 (a literal negative root taken), R11 (a literal real zero divisor taken), R12
  (an integer literal taken in a real that does not hold it exactly), R13 (`-0.0` lexed as
  itself), R14 (`move` into a real not rounded), R15 (a host's real input not rounded),
  R16 (a host's `scan.reals` taken), R17 (any float taken in a state's real), R18 (a
  real's zero divisor writing the integer 0) and R19 (`sqrt`'s destination message
  dropped), all red; R20 (an integer's tie between two singles rounded down) survived, and
  is red on a test added for it, 16777219 into a `real` 16777220.0, the even single; and,
  run on `5f64be8`, whose lexer is `a6c0a75`'s, L1 (`.5` not refused), L2 (`1.` not
  refused as a point), L3 (`1.5e+3` not refused for its `+`), L4 (`1e5` not refused for
  its missing point) and L5 (`1.5L` taken as `1.5` and a name), all red; on `5f64be8`: F1 (a force not held at its nearest real), F2 (a force spelled as the double that
  holds the single), F3 (a real point's line read as any number), F4 (a single's
  spelling trying a candidate past its range) and F5 (the sim refusing a float), all red. 1928 tests (10 doctests), up from 1872.

  *Provisional readings* (M5-10): (1) a compiled program carries `reals`, each real tag by
  name to its type, nil where its routine holds none, as decision 197 carries `units`,
  which `move`'s first clause and a zero divisor's match as nil, where §4.12's routine
  choice was a look-up of the destination in `scan.tags` at run time, which the spike
  found 12% dearer for every `move`; (2) `sqrt` writes a real, an integer destination
  refused, and reads any number Figure 11 widens into its destination's real, an `int`
  into a `real`, as `add` reads, the first question; (3) a real literal past its slot's
  range, `move 1.0e39 x` into a `real`, is refused when the program compiles, told the
  range, and one below the normal range, `1.0e-40`, taken and stored as 0.0, the second;
  (4) a result too small to be normal is written as 0.0 **with** power, as a rounding is,
  the third; (5) a real point's line in the forces file is read only as the runner writes
  it, `fan_hz 0.10000000149011612` and `big 3` refused, told the line it would write, the
  fourth; (6) the negative root's `read` is the source as held, an `int`'s −4 an integer;
  (7) a configuration line's real initial value is read as its nearest, `var_global sp
  real 0.1` holding 0.10000000149011612 and printing back `0.1`, and one given from Elixir
  that is no value of its type refused by `entries!/1`; (8) `16#ff.3` is named whole as a
  digit outside base 16, and `1.5L` and `1.5.2` as a mistyped lexeme "after a real"; (9)
  a state handed in whose real tag holds an integer, `0` for 0.0, is refused, a real's
  zero being 0.0; (10) the class-check names `sqrt`'s destination "a real", "so
  declare it a real or an lreal", a member among them; and (11), since M5-10's review, a
  real literal is a value of the real its slot computes in, a conversion's source its
  `from` type's, `move`'s, the arithmetic's and `sqrt`'s their destination's, a
  comparison's the other operand's, two literals the doubles they lex as, rounded
  silently, `eq r 16777217.0` reading 16777216.0, the fifth question; a `cal` formal's
  copy-in rounding it as before.

  **Questions for the maintainer** (M5-10), each taken provisionally as written, the
  closest reading to the record, answered on 2026-10-23 (decisions 215 to 219, below):

  1. *`sqrt` and integers.* The fan's vibration is `sqrt fan_var fan_dev`; a programmer
     with an `int` count wants `sqrt boxes side` into an `int`. As built, the source may
     be any number that widens into the destination's real, an `int` into a `real`, and
     the destination must be a `real` or an `lreal`, so `sqrt boxes side` with an `int`
     `side` is refused at compile time, "so declare it a real or an lreal"; the operator
     sees the same values either way, the difference is which programs compile. The
     options: (a) as built; (b) IEC's strict ANY_REAL in and out, `sqrt boxes x` refused
     too, told `int_to_real`; (c) Logix's, any integer or real on either side, an integer
     destination rounded from the real root (1756-RM018A pp.471–472 and p.474). IEC's
     SQRT is ANY_REAL in and out (Ed 3 Table 28).
  2. *A real literal outside a real's range.* `move 1.0e39 fan_speed` into a `real`: as
     built, refused when the program compiles, told the real's range, the operator never
     seeing it run; a literal too small to be normal, `move 1.0e-40 fan_speed`, compiles
     and writes 0.0, the operator seeing 0.0. The options: (a) as built; (b) both
     refused, the second told it is written as 0.0; (c) both taken, the first saturated at
     3.4028235e38 with no power on every scan, as a result past the range is. IEC says
     nothing of a constant outside a type's range; what Logix's editor does with one is
     **unverified**.
  3. *A flushed result's power.* `mul a a speed` with `a` at 1.0e-30 gives 1.0e-60, too
     small for a `real`: as built, `speed` is 0.0 and the rung's lamp after the `mul`
     stays lit, as for any rounding; a result past the range lights no lamp. The options:
     (a) as built, power passed; (b) no power, the lamp out for the scan, as for a
     saturation. Logix treats denormalized numbers and −0.0 as 0.0 (1756-RM018A p.882)
     and says nothing there of a status bit; IEC leaves it to the implementer (Ed 3 Table
     10 footnotes e and f).
  4. *A hand-edited forces file.* An engineer edits the forces file before a start,
     writing `fan_hz 37.50` or `fan_hz 3` for a `real` point: as built, the start is
     refused, "`fan_hz` is a real, whose force the runner writes as `fan_hz 37.5`", so the
     plant does not run until the line is put right, decision 140's strict reading kept
     for reals. The options: (a) as built; (b) any number that reads as a value of the
     point's type taken, the file rewritten in the runner's spelling at the next force or
     unforce. Logix keeps forces in the project, not in a text file, so it offers no
     precedent (**unverified** for any file form).
  5. *A real literal its slot rounds.* Asked after M5-10's review, below. The setpoint is
     `move 37.1 sp` into a `real` and the lamp `ge sp 37.1 ote lamp`. A `real` holds only
     singles, numbers of 24 significant bits, and 37.1 is none, so it holds
     37.099998474121094. As built since the review, a real literal is a value of the real
     its slot computes in, so the `37.1` in `ge sp 37.1` is the same single and the lamp
     lights; and a literal the single rounds visibly, `eq r 16777217.0` or `move
     16777217.0 r`, compiles silently, reading as 16777216.0, where the integer `16777217`
     in the same slot is refused, told its nearest (decision 147). The options: (a) as
     built, every real literal rounded to its slot's real silently, the operator seeing
     the lamp light; (b) as built, with a warning where a literal written with more
     significant digits than a single keeps, nine, is rounded, so `16777217.0` is warned
     and `0.1` and `37.1` are not; (c) Logix's literal rule, an unsuffixed real literal
     always a REAL, so in an `lreal`'s slot too `0.1` is the single, and `eq l 0.1` of an
     `lreal` that was given the double 0.1 is false, where as built it is the double there
     and true. What type IEC gives an untyped real literal in an instruction is
     **unverified** (the review read it as the context's, which is (a)); Ed 3 gives a
     typed literal, `REAL#0.1`, to name one (p.27, Table 5 feature 9, deferred by decision
     149). Logix stores an unsuffixed floating-point immediate as a REAL and one suffixed
     `L` as an LREAL (1756-RM018A p.870); what Logix's editor shows of a literal it rounds
     is **unverified**.

  *M5-10's review (2026-10-23), in two gated commits and one of documents.* The review
  found one defect and five gaps in the tests, the gaps six mutants that survived the
  suite. ``e4b13eb`` pins what was right, tests only: a block's formals compared with
  `===` and scanned twice, an `int` 7 into a `real` formal 7.0 and an `int` formal into a
  `real` tag 3.0, where `==` took 3 for 3.0, and a real literal into a `real` formal its
  single (killing X1, the copy-out not rounded, and X2, the copy-in not rounded, each of
  which left an integer in a real for the next scan to refuse); `eq i a` of an `int` 3 and
  a `real` 3.0 true, either side (X9, `===`); an `lreal` `sub` past its range, `sub
  -1.7e308 1.7e308`, saturating at −max with no power and its mirror at +max (X5, the sign
  taken from the subtrahend); a host's input of 2^128 − 2^103, the least magnitude with no
  finite single, refused in the pinned words, either sign, and the double below it taken
  as the single's largest (X3, `<=`, under which it raised a `MatchError`); and a single
  whose shortest spelling takes nine digits, 104.696724 for 104.69672393798828, printed so
  by a configuration (X7, eight digits at most). ``e9286b0`` fixes the defect: a real
  literal stayed the double it lexed as wherever no write rounded it, so after `move 37.1
  sp` into a `real` `eq sp 37.1` and `ge sp 37.1` were false on every scan and `div a 0.1
  r` divided by the double 0.1, then rounded again. It is now a value of the real its slot
  computes in (provisional reading 11), settled by the compiler: a literal its slot rounds
  lowers to `{:real_lit, line, single, spelling}`, quoted as written, `lowered?/1` reading
  it back from its spelling, so a hand edit of its value is no compiled body; and the
  contract walk's oracle types its literals so, `sqrt 1.0e-40 y0` the root of 0.0. Each
  instruction's operands are lowered by a recursion of their own in place of a zip, so a
  program of no real literal compiles in 9 to 1210 fewer reductions than at `64a47d1`, 25
  programs measured (`rv10/cost_base.txt` and `cost_now.txt`), and scans in exactly what
  it did; a program of real literals compiles in 0.6% to 3.8% more and scans in what it
  did; a compile refused for a literal zero divisor, the review's sixth finding, now takes
  4 fewer reductions than at `64a47d1` and 2 fewer than at `5eac41f`; and every source
  tokenizes in what it did. README's `fan.exs`, `status.exs` and `selected.exs` re-run
  byte-identical. The mutation table, each judged by the full suite's exit code
  (`rv10/mut/run.log`): on ``e4b13eb``, X1, X2, X3, X5, X7 and X9 red; on ``e9286b0``, N1
  (the fix reverted whole, a real literal lowered as it lexed; the contract walk red too),
  N2 (a conversion's source slot not read as its `from` type), N3 (the destination not
  read, a comparison's rule used for every instruction), N4 (a comparison's other operand
  not read), N5 (no literal settled in an lreal's slot, a subnormal kept), N6 (a literal
  its slot does not change rewritten with a spelling), N7 (a real literal not read back
  from its spelling as `lowered?/1` lowers a body again), N8 (`lowered?/1` holding a
  spelled real literal's value to its spelling, as before) and N9 (a literal past its
  slot's range rounded, which raised), all red. 1935 tests (10 doctests), up from 1928.

  **The maintainer's answers**, 2026-10-23 (decisions 215 to 219). (1) *Confirmed*:
  `sqrt` reads any number that widens into its destination's real and writes only a
  `real` or an `lreal` (decision 215). (2) *Changed*: a real literal outside its slot's
  real's normal range is refused when the program compiles in both directions, 0.0
  itself taken however it is written (decision 216), superseding provisional reading
  (3)'s second half: `move 1.0e-40 fan_speed` into a `real` is told "it is too near 0.0
  for a real, whose smallest above 0.0 is 1.1754943508222875e-38: it would be written as
  0.0", judged by the literal's nearest single, so `1.1754943e-38`, which rounds up to the
  smallest normal, is taken, in every slot the literal rules judge and as an initial
  value; and an lreal's slot is held to its own normal range, a literal nearer 0.0 than
  2.2250738585072014e-308 no number logex holds, a lex error at its column, as one past an
  lreal's largest is (provisional words), Logix's stated ranges being exactly the normal
  ones and 0.0 (1756-RM018A pp.873–874). (3) *Confirmed*: a result flushed to 0.0 passes
  power (decision 217). (4) *Changed*: a forces file's real point takes any number the
  lexer reads as one literal, `fan_hz 37.50`, `3.75e1`, `37`, `16#25` or `3_7.5`, held at
  its nearest value, the next force or unforce rewriting the file in the runner's
  spelling, a value outside the type still refused (decision 218), superseding
  provisional reading (5); an integer or bool point's line keeps decision 140's plain
  decimal (provisional), and a force's 1.0e-40 is 0.0, a force being no literal
  (provisional). (5) *Changed, the lead's recommendation*: rounding as built, and a
  warning where a real literal has more digits than its slot's real keeps (decision 219).
  The rule settled: with H the value held and S the shortest decimal whose nearest value
  of the type is H, a literal is warned of where the number its text writes, exactly, is
  neither H nor S's, "`16777217.0` has more digits than a real keeps: it is held as
  16777216.0", `0.1` and `37.1` not; the maintainer's two conditions as worded, the
  decimal differing from H and more significant digits than 9 or 17, would not have warned
  `16777217.0`, which has eight, so the count is replaced by S, which has at most 9 or
  17, and every literal the two conditions warn is still warned. Two literals compared and
  a declaration's initial value are not looked at (provisional).

  **Questions for the maintainer** (the answers' open readings), each taken
  provisionally as written, the closest reading to the record:

  1. *An integer point's line in a hand-edited forces file.* The engineer who may now
     write `fan_hz 37.50` for the fan's `real` frequency writes `eye_1 01` or `level
     16#ff` for the photo-eye's `bool` and the tank's `dint`. As built, those lines are
     still refused at the start, "is no force", decision 140's strict reading kept for
     every point but a real one, so the plant does not start until the line is put right.
     The options: (a) as built; (b) any number the lexer reads that fits the point, `01`
     as 1 and `16#ff` as 255, as a real point's is now taken, the file rewritten at the
     next force. Logix keeps forces in the project (1756-PM004L pp.52–53), so it offers
     no precedent for a file (**unverified** for any file form); IEC says nothing of
     forcing.
  2. *A rounded initial value.* `var_output sp real 16777217.0` declares a setpoint the
     `real` holds as 16777216.0, as `move 16777217.0 sp` does. As built, the `move` is
     warned of (decision 219) and the declaration is not, nor a configuration's
     `var_global sp real 16777217.0`, since a tag table keeps a value and not its
     spelling, so the engineer reading the warnings sees one and not the other. The
     options: (a) as built; (b) the declaration and the global warned of too, in the same
     words, which needs each declaration's spelling kept. IEC and Logix say nothing that
     was found; what Logix's editor shows of a rounded constant is **unverified**.
  3. *A literal nearer 0.0 than an lreal holds.* `move 1.0e-310 big` into an `lreal` is
     refused as the program is read, "`1.0e-310` is no number logex holds: an lreal's
     smallest above 0.0 is 2.2250738585072014e-308", at its column, the words of `1.0e400`
     past an lreal's largest, where `move 1.0e-40 speed` into a `real` is refused naming
     the instruction and the tag, "too near 0.0 for a real … it would be written as 0.0".
     The operator never sees either run. The options: (a) as built, the one an lreal
     cannot hold refused as no number at all, in any slot; (b) both refused naming the
     instruction and the tag, the lexer taking `1.0e-310` and the slot refusing it.
     Logix states the LREAL range as its normal values and 0.0 (1756-RM018A p.874); what
     its editor does with such a constant is **unverified**.

  **The maintainer's answers** to these three, 2026-10-23 (decisions 226 to 228), all
  three changes, landed with M5-11's in the commits below: (1) an integer or bool point's
  line takes any number spelling the lexer reads as one literal, `eye_1 01` and `level
  16#ff`, held to the point's type, one outside it refused, the next force writing it in
  plain decimal (decision 226); (2) a rounded initial value is warned of in decision 219's
  words at the declaration's line, a program's read from the parse tree's literal, which
  keeps its spelling where the tag table keeps its value, and a configuration line's from
  its tokens (decision 227); (3) `move 1.0e-310 big` into an `lreal` is refused when the
  program compiles, "`move` writes `1.0e-310` into `big`, an lreal: it is too near 0.0 for
  an lreal, whose smallest above 0.0 is 2.2250738585072014e-308: it would be written as
  0.0", the lexer reading a literal whose double is subnormal as that double, and only one
  no double holds but 0.0, `1.0e-400`, still a lex error (decision 228, provisional for
  that one).

  In three gated commits and one of documents. `396c459` records 11 curated sources in the
  front end's golden record, real literals nearer 0.0 than an lreal's smallest normal
  value and their edges, recorded by the front end before decision 216. `770ea48` lands
  the three changes with decisions 215 to 219: the lexer's `{:real_small, run}` for a
  literal whose digits are not all 0 and whose double is nearer 0.0 than an lreal's
  smallest normal, the golden record regenerated, its diff read, 7 of the 11 changed, each
  now a lex error, and every other source unchanged; `Logex.Real.flushed?/2`, read by
  `Logex.Declarations.holds?/2`, the literal rules, and by a configuration line's real
  global, which is kept as written for `check/1` to refuse; the runner's forces file read
  through the lexer, `Logex.Real.read/2` gone; `Logex.Compiler.literal_real/4`, the slot's
  real, shared by the lowering and `Logex.Warnings`, whose pass over literals,
  `by_literal/2`, tells an instruction holding a real literal by its clause's guard; and
  `Logex.Real.held_as/3`, the rule, each number compared exactly as a fraction of two
  integers. Tests: `real_test.exs`'s three new groups, a literal a write would flush in
  every slot and as each kind of initial value, its edge at the smallest normal single,
  one below an lreal's a lex error in four spellings, a forces file's real point read
  in eleven spellings and rewritten by the next force, its refusals, and the warning, its
  cases, a block's formal before and after its third operand and a block's real member,
  and the rule restated over 1500 seeded texts, a hundred warned and a hundred not in
  each real, with the cost of a program of none pinned at what it was at `a8a4f8f`;
  `force_test.exs`'s integer point spelled `16#ff` still no force and a real at a bool
  point told it does not fit; and the contract walk's real literals drawn within a
  single's normal range. Cost against `a8a4f8f`, 25 programs (`a9/cost_base.txt` and
  `a9/cost_now.txt`): a program of no real literal compiles in exactly what it did, or 2
  to 4 reductions fewer, scans in exactly what it did, and every source tokenizes in
  exactly what it did; one of 200 real literals compiles in 6% to 13% more, each literal
  its slot rounds spelled and compared for the warning. README's `fan.exs` re-run, a
  literal too near 0.0 refused and `16777217.0` warned of. The mutation table, each judged
  by the full suite's exit code (`a9/mut/run.log`), on `770ea48`:
  D1 to D9 (decision 216: the lexer's lreal edge, its zero spellings, `flushed?/2` and its reading by the literal rules and a configuration
  line's global) all red; F1 to F5 (decision 218: a spelled real force taken, held at
  its nearest, refused outside its type, and the integer point's strict reading) all
  red; W1, W2, W5 to W7 and W9 to W11 (decision 219: the pass's guards, the rule's two
  comparisons, the exponent, a member's real and a text that lexes as no literal) red,
  and W3, W4 and W8 (a cal's literal at its third operand and past it, and a negative
  literal's sign) survived, so `526e18e` pins a cal's one real literal at each of its
  operands and `-0.100000001490116119384765625` not warned of, after which all three
  are red on it.
  1949 tests (10 doctests), up from 1935.
- **M5-11 · Arrays of elementary types, literal subscripts.** A spike first, throwaway:
  the representation (a tuple, §4.12's routine choice) and the size limit, measured. Then
  decision 151 with literal subscripts only, one to three dimensions: the syntax through
  the front end (the two golden sources that hold `[` change, the diff read), the
  declaration and its initial list in the elements' order, the IR's element operand, the
  compile-time bound check, `Logex.Walk` and the warnings with a literal subscript as its
  element's path, every one-shot's storage bit and every pulse coil's two bits on an
  element (decision 154), the edit (a type, dimension or size change refused, elements
  moved by path, a changed initial list reported element by element, decision 157),
  `get/2` and connection paths, a host's array input checked, unlocated array globals and
  `var_external` arrays bound exactly (decision 159). *Done when* `weights[3]` and
  `grid[1,7]` run in a program from source against an oracle that knows nothing of logex;
  `weights[8]` in an `int[8]`, a declaration of four dimensions, `var cells int[2,2,2,2]`,
  refused at its line, an initial list of the wrong length, a host's list of the wrong
  length or shape and a `var_external` of another size or dimension are pinned refusals;
  an edit of a rung with `ons edge[2]` blocks it once; growth tests in reductions hold an
  element's read and write within a measured bound of a tag's; and the contract walk draws
  arrays of one, two and three dimensions with literal subscripts. *Size XL.*
  *(Landed 2026-10-23, in three gated commits and one of documents.)* A spike first,
  throwaway (`m511/spike`), on Elixir 1.20.4 and OTP 28: an element read from a tuple cost
  9 reductions against a tag's 8 and a write 11 against 7, a map's 11 and 11; a write
  copies the tuple of each dimension it passes through, about 1 ns an element, 1 µs into
  an `int[1024]`, 4.6 µs into an `int[4096]`, 81 µs into an `int[16384]` and 0.2 ms into
  an `int[65536]`, where an `int[256,256]` costs 2.8 µs; the state check of an
  `int[65536]` some 1 ms a call. So an array's value is a tuple, a tuple of tuples for
  more dimensions, and its limit 65,536 elements in all, §4.12's proposal (provisional
  reading 1, question 1). `f43d82a` records 41 curated sources in the front end's golden
  record. `printer_test.exs`'s generator and `@required_shapes` were given an element and
  a sized type word (`:element_name`, `:subscripted_name`) in `fb31749`, together with the
  syntax, not before it as CLAUDE.md asks; an earlier version of this paragraph said
  `f43d82a`, which M5-11's review found untrue (`git log -- test/logex/printer_test.exs`). `fb31749` lands arrays in
  a program: the lexer reads a name and one pair of brackets as one name token, so the
  parser, `well_formed!/1` and the printer are unchanged, the golden record regenerated
  and its diff read, 25 sources changed, the 23 that lex and `ote a[3]` and `xic s[n]`,
  and the two mistakes named whole at their columns; `Logex.Array`, internal, the one
  place an array's shape and values are read and made; the declaration and its initial
  list in the elements' order, the rightmost subscript fastest (1756-PM004L p.35), four
  dimensions, a dimension of 0, more than 65,536 elements, a list of the wrong length, an
  array of instances and one sized by a tag each refused at its line; the IR's element
  operand, `{:element, line, array, index, name}`, its type the elements', its subscripts
  checked against each dimension, `weights[8]` in an `int[8]` refused at its line, a tag
  subscript refused until M5-12; `Logex.Walk` and the warnings naming an element by its
  subscripts' values; a one-shot's storage bit and a pulse coil's two bits on an element
  (decision 154); the host contract, an array var_input a list of its shape, an array
  var_output given as one, a state's tuple checked; and the edit, a type, dimension or
  size change refused (Logix too changes one only offline, 1756-RM094N p.85), elements
  moved by path, a changed initial list reported element by element (decision 157).
  `0dcdab8` lands arrays in a configuration: an unlocated global array from its line and
  from Elixir, printed back exactly; a `var_external` array bound to a global array of
  exactly its type and sizes (decision 159); a connection naming an array whole, to a
  global array of its sizes whose elements widen, or an element, `m1.temps[3]`; `get/2`
  naming an array whole, as a list, and an element, `m1.grid[1,7]` or `limits[2]`; a
  configuration edit reporting an array global's initial list element by element; the
  Done-when's checkweigher from files on disk, `weights[3]` and `grid[1,7]` against an
  oracle that knows nothing of logex; and the contract walk's arrays of one, two and
  three dimensions. Cost against `f228105` (`m511/cost_base.txt`, `m511/cost_now.txt`):
  25 programs of no array scan in exactly what they did and compile in 2 to 6 reductions
  more or fewer, every source tokenizes in exactly what it did; a cycle of 20 connected
  instances costs exactly what it did, a restart 2.7% more, its var_externals' globals
  put into each state it checks, and a start 2.2% more. An element's read costs no more
  than a tag's, its write a reduction more, a 2-D element's read two more and its write
  six, a 3-D element's write nine, each pinned in `array_test.exs`. README's `weigh.exs`
  run. The mutation table, each mutant judged by the full suite's exit code: on `fb31749`
  (`m511/mut/run.log`), A1 to A4 (the lexer's subscripts), D1 to D11 (the declaration's
  dimensions, limit, sizes, initial list and recovery), C1 to C8 (the compiler's bound,
  count, element resolution, one-shots, order of subscripts and block formals), R1 to R14
  but R6 (the runtime's reads, writes, outputs, inputs and state check), W1 to W6 (the
  walk and the warnings), E1 to E7 (the edit's element-wise reports and refusals) and P1
  to P5 (the program's `arrays` and a block's member) red; R6 (a real array's host input
  not rounded to its single), R15 (a real element's check any float) and W7 (an
  unwritten var_output array's warning) survived, each pinned by `0dcdab8`; and E8, the
  edit's fit of an array value reduced to a tuple test, is equivalent, since every state
  an edit takes is checked first. On `0dcdab8`
  (`m511/mut/run3.log`), K1 to K34, the configuration's rules (an array global's sizes,
  dimensions, initial list and location, a name with brackets, an element's bound, count
  and tag subscript, a constant into an array, an array's connections typed and widened,
  a `var_external` array bound exactly, the sources of an array var_input whole and by
  element, the copy-in's order, the copy-out's widening, a host-built global's check,
  `get/2`'s paths, a restart's externals, the edit's reports, and the text's initial list,
  type word and sizes), and R6, R15 and W7 again, all red but K4, a located array's
  location taken as a point, which changed no message a test read; the documents' commit
  pins it, a point at a located array's location no second point there, after which K4
  is red.
  2002 tests (10 doctests), up from 1949.

  *M5-11's review (2026-10-23), in one gated commit and one of documents.* The review
  found five inputs that raised outside the public API, a cost question 1 understated,
  a forces reader that took more than decision 218 records, a false writer warning, five
  wrong messages, a label spelled as an element, a claim of this item's untrue, and three
  gaps in the tests. ``a87010f`` fixes them: a dotted name with a subscript, `t.acc[0]`,
  `x.y[0]` or `s.e[1]` into a block, is a member's diagnostic at its line, where the
  lowering raised a `FunctionClauseError` (the lexer reads brackets after any name part,
  so 120 to 155 of the review's every 4,000 fuzzed sources reached it, none after); `cal
  e` of an array is told it runs no array, where a message interpolated a tuple; a
  literal written into an array whole, `move 1 w`, is told the instruction takes an
  element, as a tag source is, where the literal was judged as a value of the array's
  type; a task's single that is an array is refused by `check/1`, "is an array of 2
  bools (line 1): a single is a bool global", where `cycle/3` raised; and sizes from
  Elixir that are no proper list, `[2 | 3]`, are refused in the pinned words. A label is
  a name with no subscript, `jmp a[0]` refused (provisional reading 10). Decision 48's
  writer warnings read an array global by element (`written_of/2`), so two instances
  writing different elements of one through their `var_external`s, which each keep
  theirs, `g` reading `[1, 2]` after one cycle, are told nothing, and two writing one
  element are told it by name, `g[0]` (provisional reading 11). A global named by an
  element where a global is wanted, a connection's far end or a task's single, is told
  "`ws[0]` names an element of `ws`, a global array of 3 ints (line 1): a global is named
  here whole, never by one of its elements", or with no such array "no global `ws[0]`:
  …", where it was offered a `var_global ws[0] bool` that is itself refused. A host's
  list is shown as a list, `found [72, 105]`, never `~c"Hi"`; an array's misfits, a
  host's, a state's or an initial list's, are listed to ten in the elements' order, then
  one line counting the rest (provisional reading 12), where 65,536 bad elements made a
  message of 4 MB; an array of one element is "an array of 1 int"; and decision 219's
  warning reads "is more precise than a real keeps", true of every literal its rule
  warns, `1.1754943e-38` among them (provisional, question 5). A force's value is the
  number's text alone, so `n 1//c`, `hz 1.5//c` and a value followed by a tab, which the
  lexer passes over, are no force again, as at `a8a4f8f`; and a real point's value that a
  float holds nearer 0.0 than an lreal's smallest normal, `hz 1.0e-310`, which the lexer
  refuses as a literal, is held as 0.0 as `hz 1.0e-40` is, a force being no literal
  (decision 216's last bullet), `1.0e-400`, which no float holds, still no force
  (provisional reading 13). A state's integer, bit-string or bool array is checked by one
  guard an element, its shape looked at only on a misfit, where every element was checked
  twice through a function: holding an `int[65536]` costs 65,701 reductions a scan and
  about 0.3 ms, where it cost 458,920 at `79dbc1d` measured the same way, one scan in a
  fresh process (`fx11/big.exs`; the review counted 917,727 by its own script); an
  `int[4096]` 4,261, where it cost 28,840; a `real[65536]` 532,516, about 6 ms, where it
  cost 729,126, its elements judged by their rule. And `instance/1` settles a program's tags once
  for its units, reals and arrays, comparing nothing where a routine holds none, so it
  costs 144 to 224 reductions on the review's small programs where it cost 253 to 367 at
  `79dbc1d` and 197 to 298 at `f228105`, before arrays. Every scan of those programs and
  of the review's six others costs exactly what it did at `79dbc1d`, and each compiles in
  what it did to within 4 reductions (`fx11/cost_parent.txt`, `fx11/cost_now.txt`).
  README's `weigh.exs` re-runs byte-identical and `fan.exs` changes only in the warning's
  words. The mutation table, each mutant judged by the full suite's exit code
  (`fx11/mut/run.log`): on ``a87010f``, V1 (the lowering's member clause for a subscripted part removed), V2
  (an array named whole typed as a tag), V3 (`cal`'s array clause), V4 (a single's array
  read as a host's mistake), V5 (sizes read by `Enum.all?/2`), V6 (a subscripted label
  taken), V7 (a var_external array's writers by the array), V8 and V19 (a connection's
  subscripted global offered a line, or told no array), V9 (a single's so), V10 (a list
  inspected as a charlist), V11 and V17 (no cap, a host's and a state's, and an initial
  list's), V12 (a force's text read through a comment), V13 and V18 (a subnormal force
  refused, or `1.0e-400` taken), V14 (the state check through a function, the growth
  test red), V15 (the tags settled three times, the growth test red), V16 (`an array of 1
  ints`), and the review's X2, X3 and X13 with X3b (the guard's own row count), all red. 2013 tests (10 doctests), up from 2002.

  *Provisional readings* (M5-11): (1) an array's value is a tuple of tuples, at most
  65,536 elements in all, the spike's measure; (2) a bit of an element, `faults[2].3`, is
  refused at its line, "move it into a tag of its own to reach its bits"; (3) an array is
  never a function block's var_input or var_output, which a `cal` fills with one value,
  though a block's own `var` may be one, as Logix takes an array into an Add-On
  Instruction only as an InOut parameter (1756-RM094N p.59); (4) a host sets an array
  var_input whole, a key naming one element refused; (5) a subscript may be written any
  way a literal is, `w[16#a]` or `w[01]`, read by its value and quoted as written, its
  element named by value, `w[10]`, as a bit is (decision 213); (6) an array reaches a host
  as a list, a list of lists for more dimensions, in outputs, `get/2` and every edit report;
  (7) a state that lacks an array is refused, where a missing bool or integer tag reads 0,
  so that a write of an element always finds its array; (8) an array var_input in a
  configuration is connected whole or at every element, a constant fills an element
  alone, and a connection's far end is a global whole, never an element of a global
  array, `no global "g[2]"`; (9) a var_output array no rung writes is warned to stay "at
  its initial values"; and since M5-11's review (10) a label is a name with no subscript,
  `jmp a[0]` refused, as a dotted one is; (11) decision 48's writer warnings take an
  array global by element, so two instances writing different elements of one are told
  nothing; (12) an array's misfits are listed to ten, the rest counted (question 6); and
  (13) a forces file's value is the number's text alone, and a real point's value a float
  holds nearer 0.0 than an lreal's smallest normal is held as 0.0, as decision 216's last
  bullet holds a force that is no literal, within decision 218.

  **Questions for the maintainer** (M5-11), each taken provisionally as written, the
  closest reading to the record:

  1. *How big an array may be.* A line that weighs every box keeps a history of the last
     weights in one array, `var history int[65536]`, and writes the newest weight into it
     each scan. Two costs come with it. Every scan checks every element of the state it
     is handed (decision 171's rule, a guard an element since M5-11's review), so merely
     holding the array costs each scan whether or not anything writes it; and a write
     copies the row it writes. Measured after the review on Elixir 1.20.4, the best of
     five runs of 200 scans each on the last's state (`fx11/wr.exs`): holding an
     `int[65536]` takes about 0.31 ms a scan (65,701 reductions), and writing one element
     of it each scan about 0.1 ms more; an `int[4096]` about 19 µs, a write 1.6 µs more; a
     grid of 256 by 256 about 0.3 ms to hold, as the flat array, its write a row's copy,
     too small to see; and a `real[65536]` about 5 ms to hold, its elements judged by the
     real rule (532,516 reductions). In a resource each instance holding one pays it every
     cycle. The operator sees a longer scan, and a task's watchdog trips sooner, for every
     program that holds such an array, not only one that writes it; an earlier version of
     this question said 0.2 ms a write and "only where a program writes", which the
     review found untrue. The options: (a) as built, up to 65,536 elements in all,
     whatever the shape; (b) a smaller limit, 4,096 elements in all, so no array costs a
     scan more than some 20 µs of an integer type, or 0.3 ms of a real; (c) the limit as
     built, but a dimension of more than 4,096 refused, so a large array must be a grid,
     which makes its write cheap but not its holding. IEC sets no limit; Logix limits an
     array to 2 MB of data (1756-RM094N p.85), some 500,000 dints, and says a
     one-dimension array executes faster than two or three (p.85).
  2. *A bit of an element.* A drive's fault words are kept in `var faults word[4]`, and a
     lamp shows bit 3 of the third, `xic faults[2].3 ote lamp`. As built this is refused at
     its line, told to move the element into a tag of its own, `move faults[2] f`, and read
     `f.3`. The options: (a) as built; (b) a literal bit of an element read and written as
     a bit of a word is, `faults[2].3`, its storage bit for a one-shot named so too; (c)
     (b) and a bit number in a tag as well, `faults[2].[n]`. Logix names a bit of an
     array element so, the tag-name format `Name[Element].Bit` (1756-PM004L p.44); IEC
     allows partial access of an element's bits (Ed 3 §6.4.4.5.1, unverified here).
  3. *A host setting one element.* An operator's panel changes one step of a recipe held
     in `var_input steps int[10]`. As built a host sends the whole list, all ten steps,
     each time; a key naming one element, `"steps[3]"`, is refused, told to send the array
     whole. The options: (a) as built; (b) a host may set one element by its name, the
     rest kept. In a configuration a connection may already fill an array var_input
     element by element. Logix has no host in this sense; an HMI writes a tag or an
     element by its name over the network (unverified here).
  4. *An element of a global array at a connection's far end.* A plant keeps every
     line's speed in `var_global speeds int[4]`, and the second line's program reads its
     own, `m2.speed speeds[1]`. As built a connection's far end is a global whole, so this
     is refused, "no global `speeds[1]`", and the program must take the array whole or the
     plant keep one global a line. The options: (a) as built; (b) an element of a global
     array may be a connection's far end, read or driven as a global of the elements'
     type, one connection at most driving each element. IEC connects a program's variable
     to a global or an element of one by an access path (Ed 3 §6.5.2.2, unverified here);
     Logix maps a program parameter to a tag or an element of one (1756-PM004L, unverified
     here).
  5. *The words of decision 219's warning.* A programmer writes `move 16777217.0 count`
     into a `real`, which holds 16777216.0, and the compile warns of it. Decision 219
     quoted the warning as "`16777217.0` has more digits than a real keeps: it is held as
     16777216.0", but its rule also warns `move 1.1754943e-38 r`, held as 1.1754944e-38,
     a literal of exactly as many digits as the value held, of which "more digits" is
     untrue (and `16777217.0` and 16777216.0 have the same count too). As built after the
     review it reads "`16777217.0` is more precise than a real keeps: it is held as
     16777216.0", the rule unchanged. The options, by what the programmer reads: (a) as
     built, one wording for every literal warned; (b) decision 219's words, as quoted,
     loose where the digits are no more; (c) two wordings, "has more digits than a real
     keeps" where the literal has more significant digits than the value held's shortest
     text, and "is no value of a real" otherwise. IEC says nothing of such a warning, and
     what Logix's editor shows of a constant it rounds is **unverified** (1756-RM018A
     p.870 says only that an unsuffixed immediate is stored as a REAL).
  6. *How many of an array's bad values a refusal lists.* An HMI sends a recipe of
     `var_input steps sint[64]` with every step at 500, which no sint holds. Decision
     171 lists every value of a state outside its type a line each, and M5-11 listed every
     element so, which for 65,536 bad elements made a message of 4 MB. As built after the
     review a refusal lists the first ten elements in the elements' order, then one line,
     "input `steps` is an array of 64 sints, with 54 more elements outside its type, not
     listed", and so for a state's array and an initial list. The options: (a) as built,
     ten; (b) every element, a line each, as decision 171 reads; (c) a count alone with
     the first element named. IEC and Logix have no host contract of this kind
     (unverified).
  **The maintainer's answers**, 2026-10-23 (decisions 220 to 225). (1) *Confirmed*: up
  to 65,536 elements in all, of any shape, the cost the engineer's (decision 220). (2)
  *Changed*: a bit of an element, `faults[2].3` and `faults[2].[n]`, wherever the same bit
  of a plain tag is, by every rule of a tag's bit, a one-shot's storage bit a literal one
  only (decision 221), superseding provisional reading 2. (3) *Changed*: a host may set
  one element of an input array, `%{"steps[3]" => 5}`, the rest kept (decision 222),
  superseding provisional reading 4; the record settles a multi-dimensional key, one
  subscript a dimension, `"grid[1,2]"`, a subscript out of range a pinned
  `ArgumentError`, and a whole key beside an element key in one call refused
  (provisional). (4) *Changed*: a connection's far end may be an element of a global
  array, `m2.speed speeds[1]`, widening by Figure 11, the writer warnings element by
  element (decision 223), superseding provisional reading 8's last clause. (5)
  *Confirmed*: "is more precise than a real keeps" (decision 224). (6) *Confirmed*: ten
  bad elements, then a count (decision 225).

  *The answers landed (2026-10-23), with M5-10's three follow-ups (decisions 226 to 228),
  in three gated commits and one of documents.* `a97371e` records 16 curated sources in the
  front end's golden record, a bit of an element in every spelling a bit takes and the
  shapes that stay refused, recorded by the front end before the answer, which already
  read them as one name token, and gives the printer's generator `faults[2].3` and
  `grid[1,2].[n]` and `@required_shapes` `:element_bit_name`. `0a2d8f5` lands the nine
  decisions with their tests: decision 221 in the compiler (an element bit's container
  the element's own operand in the IR, told from a tag's by its container's last byte in
  `bit_ir_of/4`'s head), the runtime, `Logex.Walk` (a new `element_writes/1`), the
  warnings, the edit's plan (its comparison by element and number, and its block list,
  which blocks a storage bit in an element the program that last scanned writes whole)
  and a configuration's writers; decision 222 in `merge!/3`; decision 223 in `check/1`,
  the runtime's wiring, `{:at, array, index}`, and the configuration edit's held
  globals; decision 226 in the forces reader, its dead path for a subnormal removed;
  decision 227 in `Logex.Warnings.initials/2`, the compiler and `lowered?/1`, and
  `Logex.Configuration.Text.read_rounded/1`; and decision 228 in the lexer, the golden
  record regenerated on purpose and its diff read, five of decision 216's eleven sources,
  each a subnormal double, now parsing and nothing else changed, the printer's generator
  drawing a subnormal, `:subnormal_real_lit`, with the lexer that reads it, since before
  it no subnormal parsed. Tests: `element_bit_test.exs` (new), `array_test.exs`'s limit in
  every shape and a host's element key, `array_configuration_test.exs`'s far end,
  `force_test.exs`'s spelled integer lines, `real_test.exs`'s rounded initial values and
  subnormal literals, and the contract walk's arrays drawing a bit of an element read and
  written, a host's element key and an element of a global array at a far end, its reach
  grown by four. Cost against `e60cc0a`, 26 programs (`a10/cost_base.txt` and
  `a10/cost_now.txt`): every program scans in exactly what it did but one of arrays,
  whose call with its inputs costs 5 reductions more, a reduction a key and four for the
  look; every program of no real compiles in two reductions more, and one of reals in
  0.4% to 3.5% more, its declaration lines read for the warning; every source tokenizes
  in what it did. A bit of an element reads in what a tag's bit does, 27 reductions a
  rung, and is written in one more. README's `fan.exs` and `weigh.exs` re-run, the first
  showing a subnormal refused and a rounded declaration warned, the second an element set
  alone, two keys refused and a bit of an element. The mutation table, each mutant judged
  by the full suite's exit code (`a10/mut/run.log`), on `0a2d8f5`: B1 to B22
  (decision 221: an element's bit refused as before, lowered with no element container,
  read as 0, written over its word, its one-shot rule, use, name, write, warnings, edit
  operand and plan, and `lowered?/1`), H1 to H8 (decision 222: the key refused, its count,
  range and tag checks, the two clashes, a real element's rounding and the key filter),
  C1 to C14 (decision 223: the far end refused, its count, range and tag checks, the
  array's use, the two drivers, the writer warnings, the copy out and in, and an edit's
  held element), S1 and S2 (decision 226), I1 to I7 (decision 227: the warning dropped, a
  rung read as a declaration, `lowered?/1`'s, an array global's, the configuration's, and
  only the first literal of a list) and L1 and L2 (decision 228: a subnormal still a lex
  error, and `1.0e-400` read as 0.0), all red but six: B19 and B20 (a storage bit of an
  element never blocked, and not kept listed on a rung a jump skips), C13 (a far end's
  element held under its spelling), C14 (a host-built runtime's array unchecked where only
  an element of it is read) and I2 (any rung naming a real tag second read as a
  declaration) survived, and C10 (a real global array's element written an int from a
  var_output) survived as an equivalent mutant, its `+ 0 * as_real(to, 0)` making 7 the
  float 7.0; `072c914` pins each, tests only, after which B19, B20, C13, C14 and I2 are
  red on it, and C10b, the widening dropped outright, survives on `0a2d8f5` and is red on
  `072c914`.
  2047 tests (10 doctests), up from 2013.

  *Provisional readings* (the answers): (1) a whole key beside an element key in one call,
  and two keys naming one element, are refused; (2) a key naming a row of a
  multi-dimensional array, `"grid[1]"`, is refused, one subscript a dimension; (3) a real
  literal no double holds but 0.0, `1.0e-400`, stays a lex error; (4) an edit that leaves
  an element no connection drives any more reports it held by name and value, and one
  that replaces a whole-array driver by element drivers reports the array held whole;
  (5) a bit of an element's IR container is the element's own operand; (6) a printed
  configuration spells a rounded initial value as the value held, so it reads back
  unwarned.

  **Questions for the maintainer** (the answers' open readings), each taken
  provisionally as written, the closest reading to the record:

  1. *A whole array and one of its elements in one call.* The recipe panel sends the ten
     steps of `var_input steps int[10]` and, in the same message, `"steps[3]" => 5`. As
     built the call is refused, "inputs `steps` and `steps[3]` each set `steps` … a call
     sets an array whole or by its elements, not both", and so is `"steps[3]"` beside
     `"steps[03]"`; the operator sees the HMI's write rejected and the old recipe kept.
     The options: (a) as built; (b) the whole first and then the element, so step 3 is
     5; (c) the element ignored. A map has no order a host can see, which is why (a) was
     taken. Logix has no host contract of this kind (**unverified** for an HMI's writes).
  2. *A row of a grid from a host.* `var_input grid int[4,8]` holds four lines of eight
     settings, and an HMI sends one line, `"grid[1]" => [1, 2, 3, 4, 5, 6, 7, 8]`. As
     built it is refused, told an element takes one subscript a dimension. The options:
     (a) as built; (b) a row by its leading subscripts, a list of the remaining shape.
     Logix names a row of a multi-dimensional array in some instructions' operands, not
     as one tag (**unverified** here).
  3. *A literal no float holds.* `move 1.0e-400 big` into an `lreal` is refused as it
     lexes, "`1.0e-400` is no number logex holds", where `move 1.0e-310 big` is refused by
     its slot naming the instruction and the tag (decision 228). The options: (a) as
     built; (b) read as 0.0 with its spelling kept and refused by the slot in the same
     words, "it would be written as 0.0". The operator never sees either run; only the
     message differs. IEC and Logix say nothing found of such a literal.
  4. *A driver changed from the whole array to its elements by an edit.* `m1.o speeds`
     drives a global array whole, and an edit replaces it by `m2.s speeds[1]`. As built
     the edit reports `speeds` held whole, though one element is driven again; the
     operator sees every speed but the second keep its last value either way. The
     options: (a) as built; (b) each element no connection drives any more reported held
     by name. Logix reports no such hold (decisions 20 and 58 are logex's own).
  **The maintainer's answers**, 2026-10-24 (decisions 229 to 232). (1) *Confirmed*: a call
  that sets an array whole and one of its elements is refused (decision 229). (2)
  *Confirmed*: a host's key names one element or the array whole, no row (decision 230).
  (3) *Changed*: `1.0e-400` is refused by its slot, naming the instruction and the tag,
  "`move` writes `1.0e-400` into `big`, an lreal: it is too near 0.0 for an lreal, …: it
  would be written as 0.0", read by the lexer as the spelled leaf of 0.0, its spelling
  the flag (decision 231), superseding provisional reading 3. (4) *Changed*: an edit that
  replaces an array's whole driver by element drivers reports each element no longer
  driven held by name, `{:held, "speeds[3]", v}` (decision 232), superseding provisional
  reading 4's last clause. They landed with M5-12's four answers, below.
- **M5-12 · Tag subscripts and the index fault.** Decisions 152 and 153: a tag subscript
  of any integer width, the run-time check where the element is read or written, the
  major fault `:index_out_of_range` with the subscripts read, on M5-9's path; a write
  through a tag subscript a write of the whole array (§4.12's routine choice); a tag
  subscript refused on a one-shot's storage bit, a pulse coil's bits and whatever runs an
  instance. *Done when* the box counter's `weights[slot]` runs in §4.4's plant on the
  manual clock against an oracle that knows nothing of logex; a `slot` of 8 trips the
  runner with every output 0 once, the trip naming the instance, file, line and index; a
  false `otl weights_bits[slot]`, a skipped rung and a frozen block with `slot` at 8 raise
  nothing (decision 82); `ons edge[slot]` is a pinned refusal; `fault_test.exs` pins the
  kind; and the runner walk reaches it. *Size L.*

  **Status: DONE — landed 2026-10-24**, as three gated commits and one of documents. No syntax changed: M5-11's lexer
  already read `weights[slot]` and `grid[r,c]` as one name token, and `printer_test.exs`'s
  generator already gave a tag's name as a subscript (`:element_name`), so the golden
  record is unchanged. `cc6e9d8` lands the item; `866460b` and `ecb277b` pin, tests only, the mutants its table left alive. The compiler takes a subscript that is a
  tag of the routine of any integer width, beside literal ones, which are judged when the
  program compiles as before, in one pass over the subscripts that gathers the tags
  (`outside/4`, which also made a program of literal subscripts compile some 10% cheaper,
  239,749 reductions to 215,758 for the cost script's array program); a subscript tag that
  is no integer is refused at its line, a bit string told its conversion, `word_to_uint`,
  an array, an instance and a reserved word each in its words, a `cal` operand's too; the
  element lowers to `{:element_at, line, array, index, dims, name}`, each subscript a
  literal's value or the tag's `{:name, line, tag}`, and a bit of one, `faults[i].3` or
  `faults[i].[n]`, holds it as its container; `lowered?/1` holds a body's to the same
  shape. A one-shot's storage bit and a pulse coil's pulse bit refuse one (decision 154),
  "`ons` keeps its storage bit in `edge[slot]`, whose subscript `slot` holds: a one-shot's
  storage bit is a bool, a bit with a literal number or an element with literal
  subscripts, as in `edge[0]`". The runtime reads each subscript where the element is read
  or written, a one-dimensional element of one tag in a clause of its own, and one outside
  its dimension is the major fault `:index_out_of_range` on M5-9's path, thrown to the
  instruction's catch, `read` every subscript read (provisional reading 1): the
  instruction does nothing and passes no power, the rung and the scan run on, a `cal` whose
  operand meets it runs no body (decision 210's rule), a de-energised `otl` checks nothing
  and a de-energised `ote` checks as it writes its 0, a skipped rung and a frozen block
  check nothing (decision 82), and an element's subscripts are checked before a bit's
  number in it (provisional reading 2). `Logex.Runner` trips on it at the end of the step,
  as on a bit's, with no change. A write through a tag subscript is a write of the array
  whole (§4.12's routine choice): `Logex.Walk` names it by its array in `writes/1` and
  `element_writes/1`, and a subscript's tag is a use, read; a coil on `lamps[slot]` beside
  one on `lamps[sel]` or `lamps[2]`, or on a bit of one, in either order, is the
  second-`ote` warning, "`lamps[2]` is in `lamps`, which the `ote` on line 5 may write
  through a tag subscript" (provisional reading 3), and any write through one is warned
  as a write of each storage bit kept in the array; an edit's rung compares the subscript's
  tag by name, and blocks a one-shot on an element of an array the program writes through
  a tag subscript; and in a configuration an instance that so writes a global array
  through its `var_external` writes it whole, every other writer of the array then counted
  whole, and a connection driving any element of it told (provisional reading 4).

  *Done when*, each met: the box counter's `weights[slot]` runs in §4.4's plant from files
  on disk on the manual clock against an oracle of eight weights that knows nothing of
  logex, over 200 seeded boxes (`end_to_end_test.exs`, "a subscript held in a tag in the
  plant (M5-12)"); a `slot` of 8 trips the runner at the fast task's step as the slow task
  falls due, every output 0 once and nothing after, the trip naming the instance, the
  file, the line and the index, `{:fault, "fast", "scales", %Logex.Fault{kind:
  :index_out_of_range, file: ".../scales.ld", line: 12, read: [8]}}`, a tuple, `read:
  {8}`, since decision 233, the slow task's step never run; a false `otl weights_bits[slot]`, a skipped rung and a frozen block with
  `slot` at 8 raise nothing (`tag_subscript_test.exs`); `ons edge[slot]` is a pinned
  refusal; `fault_test.exs` pins the kind, alone and as a cycle's event; and the runner
  walk reaches `{:trip, :index_out_of_range}`, its program `index` adding to the panel's
  dint's element of a `dint[4]` while `pa` is pressed, and since the forces file can make
  a fresh start's first round fault, the walk's start now takes a first round that trips.
  A new walk in `api_contract_test.exs` runs tag subscripts of four widths beside literal
  ones at one, two and three dimensions, each drawn now and then out of range, alone,
  across restarts and in a resource, against an oracle restated from the text. README's
  "A subscript in a tag" is the real run of `scales.exs`, and "Arrays"'s run of
  `weigh.exs` again, its line 9 now a bool subscript's refusal.

  *Cost*, against `e00ae03` in a process the collector never visits: every program of the
  cost script scans in exactly the reductions it took, and so does each rung
  `tag_subscript_test.exs` pins, a `cal` too, 178.01 a rung; compiles within the run-to-run noise of ±4
  reductions, but the array program's 10% cheaper; a one-dimensional element of one tag
  subscript reads in 21 reductions a rung against a literal subscript's 16 and writes in 22
  against 17, two dimensions with one tag 35 against 18.

  *Mutation table*, each mutant judged by the full suite's exit code
  (`m5/a12/mut/run.log`): 50 mutants on `cc6e9d8`, C1 to C14 (the compiler: each refusal, a literal beside a
  tag, a `cal` operand's check, `lowered?/1`'s shape, a body's bit container and the
  message's wording), R1 to R16 (the runtime: each bound, each catch head, the fault's
  `read` and kind, a write's check and order, each type looked up for an element and a
  non-integer subscript), W1 to W3 (the walk's uses and writes), N1 to N10 (the warnings),
  P1 and P2 (an edit's rung), K1 to K4 (the configuration's writers) and G1 (the one rule
  of a destination), 36 red. Of the 14 that survived, `866460b` pins C13 (a body's bit of
  such an element), R10 (a bit's write checking its number before its element), R11 (the
  arithmetic's type asked of the rule), R13 (`not`'s source type), N7 (a real literal's
  warning) and N9 (a bit's write reaching storage bits), red there; `ecb277b` pins R12
  (a real element's rounding), R14 and R15 (a bitwise and a root destination's type asked
  of the rule, one reduction a rung, pinned exactly) and K4b, which replaced K4, whose
  key left every duplicate it was meant to keep identical, red there. Four are
  equivalent: C4 (the note for an undeclared subscript tag in a program that declares
  nothing, which no program reaches, its array reported first; `866460b` drops the
  clause), C11 and C12 (`lowered?/1`'s shape check of an element's subscripts and
  dimensions, whose forgeries its lowering again refuses all the same) and R16 (a
  subscript tag holding no integer, which no checked state holds).

  2092 tests (10 doctests), up from 2047.

  *Review of M5-12* (at `f5a3beb`), fixed in `80a47f1`, tests and code together, and recorded
  in the commit after it: (1) a pulse coil whose pulse bit is a bit of an element a tag subscripts, `osr
  q w[i].3`, raised `Protocol.UndefinedError` out of `Logex.compile/2`, since
  `Logex.Walk.bit_name/1` had no clause for such a bit and joined its tuple as a path; it
  names it as itself now, as it names `w[i]`, and the compiler's refusal is reached,
  "`osr` sets its pulse bit in `w[i].3`, whose subscript `i` holds: …", for `osr` and `osf`
  over three kinds of storage bit; (2) a write through a tag subscript beside a coil on a
  bit of an element, `move x w[i]` beside `ote w[2].1`, `move x w[2]` beside `ote w[i].1`
  and `move x w[i]` beside `ote w[i].1`, either first, was warned of nothing, against
  §4.12's routine choice with decisions 207 and 221, and is now the second-`ote` warning,
  a bool array's element beside a coil still warned of nothing (provisional reading 3);
  (3) a warning that involves a tag subscript now names the array, where "`e[j]` already
  has an `ote` on line 8" read as though `e[j]` were the element the first coil wrote:
  "`e[j]` is in `e`, which the `ote` on line 8 may write through a tag subscript", and
  after a literal one "`e[i]` is in `e`, as `e[0]` is, which already has an `ote` on line
  8"; a connection's far end `speeds[1].3` is told "`speeds[1]` is an element of the
  global `speeds` (line 2), not an instance", where it was told there is no instance
  `speeds[1]`; and a connection beside a var_external writer is told what it drives,
  "`c1.o` drives `speeds[2]`", where "drives it" read as the array; (4) a fault's `read`
  is a list, which plain `inspect` shows as a charlist, `[9]` as `~c"\t"`, now part of
  Question 1. Every program of the cost script compiles and scans in the reductions it
  took at `f5a3beb`, within ±4 of noise, and a program of coils on element bits beside
  whole writes compiles 1% dearer, the warnings now looking for them. *Mutation table*
  (`m5/rv12/mut/run.log`), each mutant a part of a fix reverted and judged by the full
  suite's exit code on `80a47f1`: 19 mutants, all red: F1 (`bit_name/1`'s clause for a bit of
  such an element), F2a to F2n (each clause of the whole write through a tag subscript, of
  an element's beside a coil through one, each bool exclusion, each new key and each
  check of an earlier write) and F3a to F3d (each wording: a coil after a literal or a
  tagged one in the array, the far end that drives an element and the element's member).
  2094 tests (10 doctests), up from 2092.

  *Provisional readings*: (1) a fault's `read` holds every subscript, literal ones too,
  one a dimension, `[8]` or `[1, 9]`, never the one alone that is out of range; (2) a bit
  of an element a tag subscripts has its element's subscripts checked before its bit's
  number, so `w[i].[n]` with both out of range is an index fault; (3) a coil on an element
  a tag subscripts, or on a bit of one, is a coil in its array whole for the second-`ote`
  warning, where a non-coil write through one beside a coil on a literal element,
  `move x lamps[slot]` beside `ote lamps[2]`, is warned of nothing, as `move x b` beside
  `ote b` is not, but since M5-12's review a write through one beside a coil on a bit of
  an element, `move x faults[i]` beside `ote faults[2].1`, is warned, as `move x w` beside
  `ote w.1` is (decision 207); (4) in a configuration an instance that writes a global array through a
  tag subscript makes every writer of the array a writer of it whole, the warnings naming
  the array; (5) a subscript's tag is a tag of the routine, never a member, `w[t.acc]`
  being no name the lexer reads, as M5-9's bit number is.

  **Questions for the maintainer**, each taken provisionally as written:

  1. *What a fault reports as read.* The box counter's `weights` is an `int[8]` and a grid
     of setpoints `grid` an `int[4,8]` read as `grid[1,c]`; `c` reaches 9. As built the
     trip reads `read: [1, 9]`, every subscript in order, the literal 1 among them, and
     `weights[slot]` with `slot` at 8 `read: [8]`; an engineer at the trip sees the whole
     element named. A list of small integers is, to Elixir, also a charlist, so a host
     that logs the fault with plain `inspect` sees `read: ~c"\b"` for `[8]` and
     `~c"\t"` for `[9]` (README's runs pass `charlists: :as_lists`). The options: (a) as
     built; (b) the subscripts a tag held alone, `[9]`; (c) the one out of range alone,
     `9`, as a bit's `read` is a number, which no `inspect` shows as a charlist; (d) a
     tuple, `{1, 9}`, every subscript, never a charlist. Logix's
     fault 4/20 names no subscript at all (1756-RM018A p.884; **unverified** what its
     fault log shows).
  2. *Two lamps, one through a subscript.* `ote lamps[slot]` and `ote lamps[2]` in one
     program: as built the second is warned "`lamps[2]` is in `lamps`, which the `ote` on
     line 5 may write through a tag subscript: the last one in the scan decides it", in
     either order, so the engineer is told before the plant runs that lamp 2 can be
     decided by either rung. The options: (a) as built; (b) no warning, as two coils on
     different elements are none. No such warning was found in IEC or in the Logix
     extracts read (**unverified**).
  3. *A move through a subscript beside a coil.* `move 0 lamps[slot]` and `ote lamps[2]`:
     as built nothing is warned, since `move x b` beside `ote b` is not; the operator may
     see lamp 2 flicker off when `slot` is 2. The options: (a) as built; (b) warned as two
     coils are, as decision 207 does for a bit beside its word's whole write. Since
     M5-12's review the bit case is warned: the fault lamps as bits of a word array,
     `ote faults[2].1` beside `move 0 faults[slot]`, either first, is told "`faults[slot]`
     is in `faults`, as `faults[2].1` is, which already has an `ote` on line 5", because a
     word's whole write beside a coil on its bit is warned by decision 207 and a write
     through a tag subscript writes the whole array (§4.12); so as built the lamp array of
     bools is warned of nothing and the same lamps as bits of words are warned. (a) keeps
     that difference; (b) warns both.
  4. *Two feeders writing one array.* `f1` writes `speeds[slot]` and `f2` writes
     `speeds[1]` through their `var_external`s: as built `f2` is told "`f2` writes `speeds`
     through its var_external, as `f1` does", the array named whole, since `f1` may write
     element 1. The options: (a) as built; (b) told by element, "`f2` writes `speeds[1]`
     ..., as `f1` may". Logix has no such configuration check (decision 48 is logex's own).
  **The maintainer's answers**, 2026-10-24 (decisions 233 to 236). (1) *Changed*: an
  index fault's `read` is a tuple of every subscript, `{8}` or `{1, 9}`, never a
  charlist; a bit fault's stays one integer (decision 233), superseding provisional
  reading 1's list. (2) *Confirmed*: `ote lamps[slot]` beside `ote lamps[2]` warns
  (decision 234). (3) *Changed*: a write through a tag subscript other than a coil's
  beside a coil on an element of a bool array, `move 0 lamps[slot]` beside `ote
  lamps[2]`, is the second-`ote` warning in either order, as for a word array, any
  instruction's write but a coil's counting (decision 235), superseding provisional
  reading 3. (4) *Changed*: the configuration's writer warning names the element, "`f2`
  writes `speeds[1]` through its var_external, as `f1` may", the other way round "`f2`
  may write `speeds[1]` …, as `f1` does", two writers through a tag subscript "`f2` may
  write `speeds` …, as `f1` may" (decision 236), superseding provisional reading 4.

  *The eight answers landed (2026-10-24)*, in two gated commits, one of code, tests and the
  record and one of tests, and one of documents. `466710f` records decisions 229 to 236 in §7 and lands the
  five changes. Decision 231 in the lexer, which reads a real literal no double holds
  but 0.0 as 0.0 with its spelling kept, the ordinary spelled leaf, so `well_formed!/1`
  and the printer need nothing new; `Logex.Parser.underflowed?/1`, the one rule, tells
  it from a zero by its spelling, and `is_zero_real/1`, its guard, gives each literal
  rule a clause of its own, the compiler's five and a declaration's initial value, which
  a literal of any other shape passes over in its head; the configuration file's reader
  and the forces reader refuse it as the lexer did (provisional); the golden record is
  regenerated on purpose, its diff read, the two such sources, `move 1.0e-400 aa` and
  `move 1_0.0e-4_00 aa`, now parsing and nothing else changed, and the printer's
  generator draws one, `:underflowed_real_lit`, with the lexer that reads it, since before
  it none parsed. Decision 232 in `Logex.Configuration.Edit`'s held globals, where it
  also found that an element of an array var_output at a connection's near end,
  `m2.o[1] speeds[2]`, never counted as a driver, its program's writes keyed by the
  array; it now drives where its program writes that element
  (`Logex.Walk.element_writes/1`). Decision 233 in the runtime's one throw of an index
  fault, the README's `scales.exs` now inspecting faults plainly. Decision 235 in
  `Logex.Warnings`: a literal element's coil marks its array for the look at writes
  through a tag subscript, and the bool exclusions are gone. Decision 236 in
  `Logex.Configuration`'s writer warnings, each thing two writers may share, a global,
  an element or an array written through a tag subscript, with its writers in line
  order, each with whether it may write it; M5-12's step that counted every writer of
  such an array whole is gone, so a connection to `speeds[2]` is told only to a writer
  that may write it. Tests: `fault_test.exs`'s tuple and its `inspect`, `real_test.exs`'s
  decision 231 in every slot, its leaf and the configuration's refusal,
  `tag_subscript_test.exs`'s bool array's warnings both ways round, every kind of write,
  the literal cases still none, and the warnings' growth, its configuration writers both
  ways round and with two and three writers, `array_configuration_test.exs`'s held
  elements by name and an element at a near end, and the runner walk's model restating
  an index fault's `read` as a tuple. README's `fan.exs` re-run with `move 1.0e-400 big`
  among its refusals, and `scales.exs` re-run, its faults reading `{8}` and `{1, 9}`
  with no `charlists:` option.

  *Cost*, against `1fe7a9b`, 29 programs (`m5/a13/cost_base.txt` and `cost_now.txt`):
  every program scans in exactly the reductions it took; every compile is within the
  run-to-run noise of ±10 reductions but a program of coils on bool elements beside
  writes of elements, 6.2% dearer (275,171 to 292,175), the warnings now looking for
  writes through a tag subscript; a program of spelled reals compiles 0.6% cheaper, and
  lexing zeros 6% cheaper, the lexer no longer reading a zero's digits again. *Restated
  after M5-13's review*, which measured smaller programs the 29 left out, each against
  `1fe7a9b` again (`m5/r13/cost2.exs`): eight coils on literal elements of a bool array
  beside eight literal moves into another array, with no tag subscript anywhere, compile
  7.0% dearer (15,336 to 16,402 reductions), and `ote lamps[slot]` beside eight literal
  moves 5.3% (9,047 to 9,522), each now looked at for writes through a tag subscript, as
  decision 235's *Cost* says; lexing a real zero is 406 to 388; the scans are the same.
  So "every compile within noise but one" understated it: a program of coils on a bool
  array's elements compiles some 5% to 7% dearer.

  *Mutation table*, each mutant judged by the full suite's exit code on `466710f`
  (`m5/a13/mut/run.log`): 35 mutants on `466710f`: T1 (decision 233: the tuple), U1 to U12 (decision 231: the rule, its zero spellings, each of the five compiler clauses, a declaration's, the configuration's reader, the forces reader, the lexer's −0.0 and the guard), H1 to H5 (decision 232: the held elements, their order, and the near end's element, by name, through a tag subscript and spelt), W1 to W8 (decision 235: the coil's mark, its own clause, the write before it, the coil before a write, the look at writes, the wording and the plain second `ote`) and C1 to C8 (decision 236: each verb, the array's own line, the element's writers, a plain global, the connection's element and the arrays); 32 red. H4 (an element at a near end whose program writes it through a tag subscript) and H5 (one spelt `o[00]`) survived and `697eb88` pins each, tests only, after which both are red; H2 (the held elements in reverse order) is equivalent, since a report is sorted, and the record now says so.

  2102 tests (11 doctests), up from 2094, and the commits `466710f` and `697eb88`.

  *Provisional readings* (the answers): (1) a configuration file's `1.0e-400` is refused
  as the lexer refused it, at its column, the only diagnostic, and a forces file's is no
  force; (2) a write of a literal element beside a coil through a tag subscript, `move 0
  lamps[2]` beside `ote lamps[slot]`, is warned too, the mirror of decision 235; (3) an
  instance that writes several elements beside a writer through a tag subscript is told
  at each, a line an element; (4) two literals compared, `eq 1.0e-400 0.0`, are 0.0 and
  0.0, true on every scan and warned only as two literals compared are.

  **Questions for the maintainer**, each taken provisionally as written:

  1. *`1.0e-400` in a configuration or a forces file.* A program refuses `move 1.0e-400
     big` naming the instruction and the tag (decision 231); a configuration file's
     `var_global big lreal 1.0e-400` is refused as the lexer refused it before, "`1.0e-400`
     is no number logex holds: an lreal's smallest above 0.0 is 2.2250738585072014e-308",
     at its column, and a forces file's `big 1.0e-400` stops the runner from starting, "no
     force". The options: (a) as built; (b) the configuration told in its global's words,
     "`big` is an lreal: `1.0e-400` is too near 0.0 for an lreal, …", as `1.0e-310` is,
     and the force held as 0.0, as `1.0e-310` is (decision 216's last bullet). The
     engineer sees only a different message for the configuration; for the forces file,
     (a) keeps the runner stopped until the line is fixed and (b) runs the fan forced to
     0.0. IEC and Logix say nothing found of either.
  2. *A move into one lamp beside a coil through a subscript.* `move 0 lamps[2]` beside
     `ote lamps[slot]`: as built it is warned, "`lamps[slot]` is in `lamps`, as `lamps[2]`
     is, which the `move` on line 4 writes", the mirror of decision 235, as `move x w[2]`
     beside `ote w[i].1` is warned for a word array; the operator may see lamp 2 flicker
     when `slot` is 2. The options: (a) as built; (b) none, since the `move` writes one
     lamp only, as `move x b` beside `ote b` is not warned. No such warning was found in
     IEC or the Logix extracts read (**unverified**).
  3. *A feeder of two speeds beside one through a subscript.* `t1` writes `speeds[1]` and
     `speeds[2]`, and `f1` writes `speeds[slot]`: as built `t1` is told twice, once for
     each element, "`t1` writes `speeds[1]` …, as `f1` may" and "… `speeds[2]` …". The
     options: (a) as built, a line an element; (b) one line naming them, "`t1` writes
     `speeds[1]` and `speeds[2]` …"; (c) one line naming the array. Logix has no such
     check (decision 48 is logex's own).
  4. *`1.0e-400` compared with 0.0.* `eq 1.0e-400 0.0` is two literals, 0.0 and 0.0 as
     the lexer reads them, so true on every scan and warned only as two literals compared
     are; `lt 0.0 1.0e-400`, which the text says is true, is false. The options: (a) as
     built; (b) refused as the slot refuses it beside a tag. IEC and Logix say nothing
     found.
  **The maintainer's answers**, 2026-10-24 (decisions 237 to 240). (1) *Changed*: a
  configuration line's `1.0e-400` is refused in its global's or member's words, "`big` is
  an lreal: `1.0e-400` is too near 0.0 for an lreal, …", as `1.0e-310` is, and a forces
  file's is held at 0.0 (decision 237). (2) *Confirmed*: `move 0 lamps[2]` beside `ote
  lamps[slot]` is warned (decision 238). (3) *Changed*: an instance writing several
  elements beside one other writer is told once, "`t1` writes `speeds[1]`, `speeds[2]` and
  `speeds[3]` through its var_external, as `f1` may", ten and then a count (decision 239).
  (4) *Changed*: `eq 1.0e-400 0.0` refuses the literal as every other slot does (decision
  240). They landed with M5-13's seven answers, below.
- **M5-13 · Located arrays.** Decision 156's follow-up: `var_global temps real[8] at
  card.i.0` occupying `card.i.0` to `card.i.7`, in the elements' order, each element a
  point named `temps[3]`, grouped by `Logex.IO.points/1`, read, written and forced as its
  own point, the forces file naming it so; a range that overlaps another point refused,
  both named; an online edit's located-I/O refusal covering the range. *Done when* §4.4's
  oven card gives its eight zone temperatures as one located array through the sim,
  `temps[3]` forced against its device and across a restart, a crash and a fresh start
  from its forces file; an overlap and a range past an adapter's points are pinned
  refusals; and the runner walk draws a located array. *Size M.*

  **Status: DONE — landed 2026-10-24**, as two gated commits, code and tests and then tests only, and one
  of documents. No syntax changed: the configuration reader already read `var_global
  temps real[8] at card.i.0`, which M5-11 refused, so the golden record and the printer's
  generator are unchanged; the configuration round trip's seeded draws now give located
  arrays too. `30d6a24` lands the item; `73d946c` pins, tests only, the mutants its table
  left alive. `Logex.Configuration.check/1` takes a located
  array, each element a point at the next address in the elements' order, its
  location's last field counting up (`Logex.Array.points/3`), named by its element,
  `temps[3]`: a range that overlaps another point is refused naming both, once a pair, at
  the first address they share, "`temps[3]` is at `card.i.3`, where `eye` already is (line
  3): a location holds one global, and `temps` is an array of input points, `card.i.0` to
  `card.i.7`"; a located array takes no initial list; one refused for its sizes takes no
  address; a location named in a connection names its element; an input array driven by
  a var_output or written through a var_external is refused naming its range; an array
  of output points nothing drives, or drives only by element, is warned of each element
  left at 0; and an event task's single is still a whole bool global, an element or an
  array told so. `Logex.IO.points/1` gives a point an element, and `bind!/2`'s message for
  an unbound device names an array's elements as their range. `Logex.Runtime` takes an
  element as an input key, `%{"temps[3]" => 37.5}`, stored as its type's nearest value and
  placed in its array, a few in place and more, up to every element a device reports,
  laid over the array in one pass (provisional, at 16; restated by M5-13's review: up to
  16 copies of the array's words in place, or one pass); gives each output element by its name; keeps a located
  input array across a restart, as an input point; and refuses, in pinned words, the
  array named whole, an output element, an element its array lacks, `temps[8]` or
  `temps[03]`, and an element of an unlocated array. `Logex.Runner` reads, writes and
  forces each element by its name through the device's per-point image, the forces
  file's line `temps[3] 150.0`, unforce and unforce_all putting back each element's last
  value, a restart's reread and decision 143's refusal of one element's value keeping
  the others', with no change to `Logex.Runner.Device`; a force, or a forces file's line,
  of the array whole, an output element or an element it lacks is refused, told the
  elements. `Logex.IO.Sim` takes `inputs:` and `outputs:`, how many points it has, its
  `check/3` and `init/3` refusing a point past them, so that a range past an adapter's
  points is a pinned refusal at bind. `Logex.Configuration.Edit`'s located-I/O refusal
  names a located array's range, so one grown, moved, unlocated, added or removed is told
  the points it took and would take; an element an edit stops driving is held by its
  name, decision 232's rule unchanged. Found on the way and fixed: an element of a global
  whose line was refused, `m1.l lamps[1]` under a broken `var_global lamps` line, was told
  "`lamps` is a global …, not a global"; it is now silent, as a use of the global's name
  is (decision 42).

  *Done when*, each met: §4.4's plant, from files on disk, reads its oven card's eight zone
  temperatures as one located array, `zone_t real[8] at card.i.0`, and lights a lamp a
  zone through `zone_hot bool[8] at card.q.0`, through `Logex.Runner` on the manual clock
  against an oracle of eight singles that knows nothing of logex, over 120 seeded
  readings, printed back exactly; `zone_t[3]` is forced against its device and across a
  restart, a crash and a fresh start from its forces file, `zone_t[3] 250.0`
  (`end_to_end_test.exs`, "a located array in the plant (M5-13)"); an overlap, of a point
  in a range, a range over a point and two ranges, and a range past an adapter's points,
  a sim of six inputs under eight, are pinned refusals (`located_array_test.exs`); and the
  runner walk draws a located array in and one out in every configuration, `pt int[3]` at
  `panel.i.3` and `qs bool[2]` at `drive.q.2`, each element pressed, forced, unforced and
  refused at its own address, its reach an element pressed, forced and misfit. The walk's
  check of its own late inputs now looks over 40 seeds, its catch moved to seed 30 by the
  draws' new stream, and names `pt[1]` among what it may catch.

  The cost, measured against `a8af419` with the item's cost script
  (`scratchpad/m5/a14/cost.exs`, configurations of 4 and 32 relays, each with a bool, a
  dint and a real input point, an output point and an unlocated array): a cycle, its
  outputs, `get/2` and a restart cost what they did, within the one to six reductions by
  which the base itself varies run to run, 27,170 for a cycle of 32 against 27,169 to
  27,171; a pinned test holds a cycle of no located array at 105.6 reductions a pair of
  points and its outputs at 4.5 a point, as measured at `a8af419`; `check/1`, `compile/3`
  and `points/1` are 12 to 96 reductions cheaper; `start/1` is 0.2% dearer and a
  configuration edit's accept 0.4%, deriving the located points once more. A located
  array's check, start, points and a cycle setting every element grow linearly, 8 times
  the elements costing at most 9 times (measured about 8).

  The mutation table, each mutant judged by the full suite's exit code on a copy of the
  commit (`scratchpad/m5/a14/mut/run.log`): 32 mutants on `30d6a24`, 29 red at once, an
  overlap taking its address (L1), an overlap told once for each element (L2), the
  elements' addresses off by one (L3), the initial list taken (L4, L5), the undriven
  warning's elements and its whole-array form (L6, L8), the refused line's element no
  longer silent (L9), an input array driven named as a point (D1), the element inputs
  not placed (R1), the overlay's values kept old (R2), the output elements dropped (R3),
  an input array reset by a restart (R4), the array named whole as an input, an output
  element, an element it lacks and the hint's ranges each in other words (R5 to R8), a
  real element's input not held at its nearest (R9), the points at the array's first
  address (I1), an unbound device's ranges (I2), the sim's bound, its init's check, an
  address of more fields and its count (S1 to S4), the runner's whole-array force,
  element it lacks and output array (N1 to N3), and the edit's range (E1, E2); three
  survived, a program's write through its var_external not counted as driving an output
  array (L7), an array refused for its sizes laid over other points (L10), and the fast
  clause of a restart with no located array dropped, costing 2 reductions a global with
  no other change (R10), each red after `73d946c`, the last by a restart's cost pinned
  in reductions beside the cycle's.

  Provisional readings, each a question for the maintainer:

  1. *The array named whole, at a point.* A located array's elements are its points;
     the oven's eight zones are `zone_t[0]` to `zone_t[7]`. As built, a host's input,
     a force and a forces file's line naming `zone_t` whole are refused, told the
     elements, so an operator forces one zone at a time and sees each forced zone listed
     by itself. The options: (a) as built; (b) a whole-array input or force taken as a
     list, `%{"zone_t" => [...]}`, as a host's array var_input is (decision 222), each
     element then forced; (c) a whole input taken, a whole force refused. Logix's module
     data is one tag, `Local:0:I.Data`, an array copied whole with `cps` (1756-PM004L
     p.20, cited as p.21 until M5-16 corrected it), and an alias names one point of it, `Local:2:I.Data.3` (p.46); and Logix
     forces within a tag, by element: "If the tag is an array or structure, such as an
     I/O tag, force a BOOL, SINT, INT, DINT, or REAL element or member" (p.53), forces
     enabled "for a specific module, tag collection, or tag element" (p.51), "expand the
     tag to show the value to force (that is, BOOL value of a DINT tag)" (p.54), which
     supports (a) (corrected by M5-13's review, which found these pages; it was
     **unverified** here). IEC's directly represented variables are single points (Ed 3
     Table 16).
  2. *A hierarchical address.* `rack.i.2.4` is slot 2, point 4. As built a located
     array's elements count up in the last field, `rack.i.2.4` to `rack.i.2.11`, so a
     range can run past what a slot holds and only the adapter's `check/3` can tell. The
     options: (a) as built; (b) refused for an address of more than one field; (c)
     counted up and carried into the field before at a size the adapter names. IEC
     leaves a hierarchical address's meaning to the manufacturer (Ed 2 §2.4.1.1, p.37);
     Logix names a module's data by its slot, `Location:Slot:Type.Member.SubMember.Bit`,
     a bit "depends on the size of the I/O module (0–31 for a 32-point module)"
     (1756-PM004L pp.18-19), so a module's points are within its own tag; no address
     that runs across slots was found in the extracts read (**unverified** that none
     exists).
  3. *An array of output points nothing drives.* The oven's eight lamps, of which a
     program drives zones 2 and 5 only. As built, the warning names every element left
     at 0, "nothing drives `lamps[0]`, `lamps[1]`, … or `lamps[7]`: they stay at 0", ten
     then a count, and one sentence for the array whole where none is driven. The
     options: (a) as built; (b) one warning naming the array only; (c) none where any
     element is driven. Logix has no such check; decision 48's warnings are logex's.
  4. *A located array grown by an edit.* The oven gains two zones, `zone_t real[10]`.
     As built the accept is refused twice, for the global's type (decision 157) and for
     the range its elements take, "… at `card.i.0` to `card.i.7` in the running
     configuration and at `card.i.0` to `card.i.9` in the candidate: located I/O changes
     only with a restart", both shown to the operator. The options: (a) as built; (b) the
     range's refusal alone; (c) the type's alone. Logix changes an array's size offline
     only (1756-RM094N p.85).

  *The review of M5-13 (2026-10-24)*, which found no wrong value at a point, answered in
  three gated commits, `aa2c5f2`, of code and tests, `bf23c7e`, of tests only, and one of
  documents. (1) No test read the
  outputs of an output array of more dimensions, so a mutant reading each element's
  subscripts reversed lived: `located_array_test.exs` now cycles `tq dint[2,3] at
  card.q.0` and runs it through the runner, each element by its name and at its address,
  the rightmost subscript fastest. (2) No test had exactly eleven undriven elements: the
  warning is pinned at ten named, eleven as ten and 1 more, and twelve. (3) The cost of
  placing elements was claimed as "some k + n, never k times n"; but a write in place
  copies the tuple of each dimension it passes through, so 16 elements of an
  `int[65536]` copy 16 times its words, which the BEAM counts as about one reduction
  each. Measured in a process that drops each cycle's runtime, as a runner does
  (`m5/rv13/wall.exs`, 200 cycles): one element 0.43 ms a cycle, two 0.76 ms, 16 in place
  4.1 ms and 17 in one pass 6.1 ms, in place the cheaper up to about 24; an
  `int[256,256]`, whose write copies 512 words, 16 in place 0.24 ms and 129 in one pass
  9 ms. The review's 4.5, 20.3 and 6.6 ms kept every cycle's runtime alive in a list, so
  its collector copied each array again and again; the switch at 16 is kept and the claim
  restated in words copied, here, in CLAUDE.md and in `placed/4` (provisional). (4) A
  program's write through its `var_external` into an array of output points drove the
  array whole, where a connection to one element drove only it: it now drives each
  element it writes, `ote lq[1]` that element alone, and the array whole only through a
  tag subscript, as decision 236 counts a writer (provisional, Question 5). (5) The very
  element through the very tag subscript, `ote l[slot]` beside `otl l[slot]` or `move 0
  l[slot]`, is warned since decision 235, where `ote l[2]` beside `otl l[2]` is not: it is
  kept, as `ote w.[n]` beside `otl w.[n]` has been warned since M5-9, pinned with a
  latch's and an `otu`'s, and recorded under decision 235 (provisional, Question 6). (6)
  The answers' cost was understated, restated above under them. (7) Question 1's Logix
  claim is now cited, 1756-PM004L pp.51, 53 and 54. (8) An input key that is an element
  was quoted with `inspect`, `"tb[9]"`, beside a misfit's `` `ti[1,1]` `` in one message:
  a key the lexer reads as one name is now quoted as a name, and anything else as the
  host gave it, `"temps[1, 2]"`; M5-12's Done-when notes the tuple; Question 2 cites
  PM004L pp.18-19; and the three older points: a scalar refused for its initial value,
  `var r int 40000`, made every use of `r` "not declared", and is now declared with none,
  its uses checked, as an array refused for its list is (provisional, Question 7);
  `Logex.IO.Sim.start_link(inputs: 3, inputs: 4)` was told `:inputs` is not an option,
  and it and the manual clock now refuse a key given twice in the runner's words, "takes
  each option once, got :inputs more than once"; and `Sim.set/2,3` refuses an address past
  `inputs:`, "the sim has 8 inputs, at the addresses [0] to [7], got: [8]", nothing set.
  Every program of the review's cost script compiles and scans in the reductions it took
  at `463b4ae`, and a configuration of no located array cycles as before, the pinned
  growth test unchanged. README's `oven.exs`, three times, and `scales.exs` re-run from
  its text: identical. *Mutation table* (`m5/rv13/mut/run.log`), each mutant judged by the
  full suite's exit code on `aa2c5f2`: 11 mutants, 10 red at once, the review's X16 (the
  cap at eleven) and X17 (an output element's subscripts reversed), V1 and V2 (a
  var_external's write counted as its array's, and the element filter dropped), Q1 (an
  element key quoted as given), S1 to S3 (a sim's set past its inputs taken, a key twice
  taken, a key twice told it is unknown), M1 (the manual clock's key twice taken) and D1
  (a scalar refused for its initial value declaring nothing); S4 (the addresses past the
  inputs unsorted, the first told in a map's own order) survived, since a map of 32 keys
  or fewer gives them sorted, and `bf23c7e` pins it with 40, after which it is red. The
  review's X5 (always one pass) moves only cost, and is left alive, as the review says.
  2133 tests (11 doctests), up from 2130.

  **Questions for the maintainer from the review**, each taken provisionally as written:

  5. *What a program's write drives.* The oven's eight zone lamps, `zone_hot bool[8] at
     card.q.0`, are written by one program through its `var_external`, `ote zone_hot[2]`
     only. As built that drives `zone_hot[2]` alone, so the configuration is warned that
     nothing drives `zone_hot[0]`, `zone_hot[1]` and the rest, which stay at 0, as when a
     connection drives one element; a write through a tag subscript, `ote zone_hot[z]`,
     drives every lamp. Until the review any write through a var_external drove the array
     whole and nothing was warned. The options: (a) as built, by element; (b) any write
     drives the array whole, so the engineer is warned only of an array no program
     writes. Logix has no such check; decision 48's warnings are logex's own.
  6. *A coil and a latch on one lamp through one subscript.* `ote lamps[slot]` and `otl
     lamps[slot]` in one program: as built warned, "`lamps[slot]` is in `lamps`, which the
     `ote` on line 5 may write through a tag subscript: the last one in the scan decides
     it", as `ote w.[n]` beside `otl w.[n]` is (M5-9), where `ote lamps[2]` beside `otl
     lamps[2]`, and `ote b` beside `otl b`, are not. The operator sees lamp `slot` set by
     whichever rung comes last, as with `lamps[2]`. The options: (a) as built, since a
     write through a tag subscript is a write of the array whole (§4.12); (b) none where
     both name the same element through the same tag, as for a literal element, and the
     same for `w.[n]`. No such warning was found in IEC or the Logix extracts read
     (**unverified**).
  7. *A tag refused for its initial value.* `var r int 40000`: an int cannot hold 40000.
     As built since the review the line is refused once and `r` is declared with no
     initial value, so a rung `xic r ote lamp` is told what is wrong with that rung, an
     int read as a bool, and not that `r` is undeclared; until then each use of `r` was
     told "`r` is not declared", one more message a use. The options: (a) as built, as an
     array refused for its initial list is (M5-11); (b) as before, the line declaring
     nothing. A line broken after its value, `var r int 5 7`, still declares nothing. IEC
     says nothing found; Logix's editor checks a value as it is typed (**unverified**).

  **The maintainer's answers**, 2026-10-24 (decisions 237 to 247, the eleven questions
  of M5-12's follow-ups, M5-13 and its review), **landed the same day** as one gated commit
  of code and tests, `cfc78c6`, one of tests, `31401c2`, and one of documents. Five confirm what was built:
  `move 0 lamps[2]` beside `ote lamps[slot]` warned (decision 238); a hierarchical
  address's last field counting up (242); the undriven warning naming each element, ten
  then a count (243); a program's write through its `var_external` driving each element
  it writes, a tag subscript the array whole (245); and a scalar refused for its initial
  value declared with none (247). Six change it:
  - *`1.0e-400` in a configuration and the forces file* (decision 237): refused in its
    global's or member's words, as `1.0e-310` is, through a subnormal stand-in no other
    literal of the text holds, `Logex.Configuration.Text.read_rounded/1`, quoted back as
    written in every message, a connection's constant and a task's interval among them;
    held at 0.0 in a forces file. Found on the way: `var_global g dint 1.5`, which a line
    can say since M5-10, raised from `compile/3` as the host's mistake; a float initial
    value is now judged by the literal rules, "`g` is a dint: `1.5` is a real, and a dint
    holds only integers", from Elixir too.
  - *The elements named together* (239): "`t1` writes `speeds[1]`, `speeds[2]` and
    `speeds[3]` through its var_external, as `f1` may (line 4): …", in the elements' order,
    ten and then a count.
  - *`eq 1.0e-400 0.0`* (240): "`eq` reads a number or a bit string, and compares two
    literals as lreals: `1.0e-400` is too near 0.0 for an lreal, …".
  - *A located array named whole* (241): a list of its shape in a cycle's inputs,
    `%{"zone_t" => [...]}`, in `Logex.Runner.force/3` and `unforce/2`, each element forced
    or unforced, and in a forces file's line, `zone_t 170.0 170.0 …`, its name and one
    value an element in the elements' order; the shape and every element checked, misfits
    ten then a count, a whole key beside an element key refused; the runner keeps each
    element's last device value for an unforce, as for each point; and the file is
    written element by element, one line an element, as the runner holds its forces, so
    that what it writes reads back to the very forces it holds. No element is a trigger
    (an event task's single is a whole bool global), so a whole force makes no round of
    its own.
  - *A located array grown by an edit* (244): refused once, for its range; one whose range
    is kept and whose elements' type changes is told its type; an unlocated array grown is
    still told its type (decision 157).
  - *The very element through the very tag* (246): `ote lamps[slot]` beside `otl
    lamps[slot]`, any write but a coil's, either first, and `ote w.[n]` beside `otl
    w.[n]`, superseding M5-9's reading, are warned of nothing; through other tags, `l[i]`
    beside `l[j]` or `w.[n]` beside `w.[m]`, still warned, and so is the very element's
    write beside a coil on another element or bit, whichever came first.

  The runner walk forces and unforces `pt` whole where it draws `pt[1]`, keeping its
  draws' stream, its reach the array forced and unforced whole. The cost, measured against
  `7deac11` (`scratchpad/m5/a15/cost_p.exs` and `cost_c.exs`): every program of the cost
  script compiles and scans in the reductions it took, but those with a coil on an
  element, 0.3% to 1.8% dearer to compile; a configuration's `compile/3` is cheaper, 1.1%
  at 4 relays and 32, its tokens looked at once for an underflowed literal where they were
  looked at through a call each; `check/1`, `start/1` and `points/1` five reductions dearer
  whatever the size, the writer warnings' empty case; and a cycle, its outputs, `get/2`
  and a restart cost what they did, a configuration of no located array looking for no
  whole key. *Mutation table* (`m5/a15/mut/run.log`), each mutant judged by the full
  suite's exit code on `cfc78c6`: 37 mutants, 35 red at once: C1 to C6 (decision 237: no stand-in, no respelling, the held literals not looked at, a float initial raised again, the initial rule's old guard, an array element's), F1 (the forces file refusing `1.0e-400` again), P1 (decision 240's refusal dropped), W1 to W5 (decision 239: each element its own line, the elements unsorted, the cap at a hundred, "or" for "and", every line of an instance merged), X1 to X9 (decision 246: the exception taken nowhere, at a tag-subscript write first, at a bit's write after its coil, at a coil after a bit's write, the first through other tags never kept, the subscripts or the bit's tag left out of the identity, the coil after an array coil, a tag subscript's name left out), E1 and E2 (decision 244's range alone dropped, the type of a kept range dropped), R1 to R4 (a whole input taken unchecked, not placed, the clash taken, a real element not held at its nearest) and N1, N2, N4 and N6 to N9 (a whole force's shape unchecked, an unforce of one element only, a whole line's elements not looked for twice, a whole force and a whole line not held at their nearest, the line's elements not kept for later lines, a line of several values naming no array taken as a point's); two survived, a whole line of more values than elements taken (N3) and a whole force's misfits uncapped (N5), and `31401c2` pins each, tests only, after which both are red.

  2138 tests (11 doctests), up from 2133.

  *Provisional readings* (the answers'), each a question for the maintainer:

  8. *The forces file's form for a whole array.* The oven's eight zones forced whole,
     `force(r, "zone_t", [170, …])`: as built the file holds eight lines, `zone_t[0]
     170.0` to `zone_t[7] 170.0`, as the runner holds the forces and `status/1` lists them,
     and a line `zone_t 170.0 …` written by hand is read as each element forced and written
     back by element at the next force; an operator unforcing zone 3 alone sees the other
     seven still listed. The options: (a) as built; (b) a whole line where every element is
     forced, `zone_t 170.0 170.0 …`, and element lines otherwise, so the file reads as the
     operator forced it. Logix forces within a tag, by element (1756-PM004L pp.51, 53, 54);
     no forces file of Logix's was found in the extracts read (**unverified**).
  9. *Two instances writing the same elements.* `t1` and `t2` both write `speeds[1]` and
     `speeds[3]`, neither through a tag subscript: as built `t2` is told once, "`t2` writes
     `speeds[1]` and `speeds[3]` through its var_external, as `t1` does", as decision 239
     tells an instance beside a writer through a tag subscript. The options: (a) as built;
     (b) a line an element, as before decision 239, which asked only of a tag subscript.
     Logix has no such check (decision 48 is logex's own).
  10. *A subnormal literal beside a literal.* `gt 1.0e-310 0.0`: as built it compiles and is
     true on every scan, the double it lexes as, warned only as two literals compared are,
     where decision 240 refuses `eq 1.0e-400 0.0`; beside a tag it is refused (decision
     228). The options: (a) as built, since its text and its value agree; (b) refused as
     beside a tag, "too near 0.0 for an lreal", as any literal a write would flush. IEC
     and Logix say nothing found.
- **M5-14 · Arrays of instances.** Decision 154: `var lane_t ton[4]`, `var lanes
  seal[4]`, a literal subscript on every instruction that runs one, a tag subscript on a
  member's read or write. *Done when* each refusal is pinned, the one-run rule holds per
  element (`ton lane_t[2] 500` twice refused), decision 85's two counter rungs hold per
  element, an edit of a lane's timer resumes it by its path `lane_t[2]`, a counter's edge
  memory on an element is on the block list by its path, an event task's timer, counter
  and one-shot warnings name each element, a `cal` of an element runs only its instance,
  and the contract walk draws arrays of instances. *Size L.*

  **Status: DONE — landed 2026-10-24**, as gated commits: `382777e` lands the item, code
  and tests; `9a84ed7` holds a configuration edit's accept for a program of no array of
  instances to its cost before the item and pins the mutants its table left alive; and a
  third holds the documents. The syntax was recorded first, in `3519c43`: a
  member after an element's subscripts, `lane_t[2].dn`, in the printer's generator and
  `@required_shapes` and 13 sources of the golden record, which the front end already read.
  The maintainer re-confirmed decision 154's literal rule on 2026-10-24. README's "Arrays of instances"
  is the run of `lanes.exs`, a sorter of four lanes, real output re-run on the item's code.

  An array of instances is the program's own: `var lane_t ton[4]`, `var lane_c
  ctu_int[4]` and `var gates gate[4]`. It is one to three dimensions of every timer, the
  long ones among them, every counter, the typed ones among them, or a user block, and its
  state is a tuple of instance maps in the elements' order (`Logex.FbType.started/2`).
  Each of the following is refused at its line, from Elixir too: an initial list; a
  var_input, var_output or var_external; an array of a block inside that block, at any
  depth; a configuration's global, `var_global w ton[2]`; and a connection. A host's input
  naming one is refused too.

  Each instruction that runs an instance takes an element by literal subscripts: a timer,
  a counter's side, a `cal`, and a one-shot's storage bit or a pulse coil's pulse bit (a
  bool element). The element is lowered with its name by value, so each rule holds per
  element:
  - M1-6's one-run rule, `ton lane_t[16#2] 30` beside `ton lane_t[2] 30` refused;
  - decision 85's preset agreement of a `ctud`'s two rungs;
  - each element's own preset;
  - nothing after an element's instruction on its path.

  An element a tag subscripts in such a slot is refused and told why: "`ton` runs
  `lane_t[i]`, whose subscript `i` holds: an instruction that runs an instance takes an
  element of an array of instances by literal subscripts, as in `ton lane_t[0]`, so that
  each element is one instance, run by one instruction whatever the program does". A
  `cal` of an array whole is told its element. A counter of one kind on the other's
  instruction is told its array's declaration, "declare its array `var lane_c ctud[4]`".

  A member of an element, `lane_t[slot].dn` or `lane_c[1].pv`, is read and written as an
  instance's member is, by literal or tag subscripts, and so are its bits. A subscript out
  of its dimension is M5-12's major fault, every subscript in `read`. A one-shot's storage
  bit in a member of an element is refused, as in a member of an instance. A `cal` of an
  element runs its body over that element's state alone. Its `:ran` record, its block
  list and a fault's `path` are by the element's name, `lanes[1]`.

  Every fact of an element is by its path: `lane_t[2]`, or `lanes[1].t` at depth. That
  holds in:
  - the walks;
  - the edit's plan, which resumes a timer and moves its preset, `{:preset, "lane_t[2]",
    {30, 50}}`, blocks a counter's edge memory, `lane_c[1].cu`, and a block's one-shot,
    `lanes[1].e`, and reports a member unwritten;
  - the event task's timer, counter and one-shot warnings;
  - `Logex.Runtime.get/2`, `m1.lane_t[2].acc`, which refuses an element or an array of
    instances named whole.

  An array of instances whose sizes or element type change is refused, as an array's is,
  and so is one whose user block's members change kind, by the first element's path. A
  state's array of instances is checked whole, a tuple of its sizes, each element its
  type's map, at depth in a block. The loader reads a block's name from a declaration with
  sizes, so `var gates gate[4]` loads `gate.ld`.

  *Done when*, each met:
  - Each refusal is pinned (`instance_array_test.exs`), `ton lane_t[i] 500` told why.
  - The one-run rule holds per element, however the subscript is spelled.
  - Decision 85's two counter rungs hold per element.
  - An edit resumes a lane's timer and moves its preset by its path `lane_t[2]`.
  - A counter's edge memory on an element is on the block list by its path until a scan
    runs it, and so is one on a rung a jump skips.
  - The event-task warnings name each element.
  - A `cal` of an element runs only its instance.
  - The contract walk draws arrays of instances:
    - a `ton` array of one or two dimensions, a `ctu` or `ctud` array and a gate block's;
    - members through a tag subscript, now and then out of range;
    - restarts, a misfit state refused, and edits that move a preset or block an edge;
    - a resource read through `get/2`;
    - against an oracle of each element as a scalar instance of its type, its reach every
      kind in `@ia_reach`.
  - `end_to_end_test.exs`, "arrays of instances in the plant (M5-14)", runs a sorter of four
    lanes from files on disk, `gates gate[4]` loaded from `gate.ld`, over 600 seeded cycles
    against an oracle that knows nothing of logex.

  The cost, measured in reductions against `aa41f4d`:
  - A program of no array of instances scans each rung in exactly what it did: a `ton` 112,
    a `ctud` 343 and a `cal` 288. A test pins each.
  - The compile scripts' programs compile within the one or two reductions the base varies
    by.
  - A configuration's check, start, cycle, outputs, restart and points cost what they did.
  - A configuration edit's accept costs what it did within the base's own spread, 325,088
    to 325,096 against 325,093 to 325,106 for 32 relays, after `9a84ed7` moved its new cases
    out of the comprehensions' inner generators, where `382777e` had it 120 to 230 dearer.
  - An element's rung scans in 9 to 14 reductions more than a scalar instance's (a `ton`
    121, a `cal` 302), and a member read through a tag subscript in 5 more than by a
    literal one. A test pins each.

  The mutation table, each mutant judged by the full suite's exit code on a copy of the
  commit (`scratchpad/m5/a16/mut/run.log`): 27 mutants on
  `382777e`. 21 were red at once:
  - the compiler's name by value, its one-run element clause, an element's preset, the
    tag-subscript refusal, the `cal` refusal, an element member's storage bit and a
    counter's array hint (K1 to K7);
  - the runtime's counter block by element, a long timer's unit by array, the member of
    an array of instances named whole and a `cal`'s write back (R1, R3, R5, R7);
  - the plan's element instances, edges and element writes (P1, P2, P4);
  - the walk's tag-subscripted member paths and element runs (WK1, WK2);
  - the warnings' unrun elements and their cap (W1, W2);
  - the section refusal (D2), the started presets (F1, once rewritten so that it
    compiles), the units by array (PR1) and the loader's sizes (L1).

  Five survived, and each is red after `9a84ed7`, which pins each in a test:
  - a skipped rung's mark for a counter element (R2), which only a ctud whose other side
    runs can see;
  - the multi-dimension member write through tag subscripts (R4);
  - a `tp` element's block by name (R6);
  - decision 26's fit for an array of instances (P3);
  - the declaration's refusal of an initial list holding a word (D1).

  `9a84ed7`'s changed lines were mutated again (P1b, P2b), red with all five.

  Provisional readings, each a question for the maintainer:

  1. *A member written through a tag subscript.* The sorter writes a lane's preset
     through the panel's lane, `xic set move 2 lane_c[k].pv`, and an edit drops that rung.
     As built, the edit's report names each element as no longer written, `{:unwritten,
     "lane_c[0].pv", 2}` and the rest, each keeping its value; the walks count the write as
     one to that member of every element. The options:
     - (a) as built;
     - (b) the elements the running program last wrote only, which no rule records today;
     - (c) none, as for a write no element is named by.
     Decision 96's report is logex's own; no such report of Logix's was found in the
     extracts read.
  2. *An array some of whose elements nothing runs.* Four lanes declared, three run. As
     built, one warning: "`lane_t` is an array of 4 tons, but no `ton` runs `lane_t[3]`: it
     never times", the elements listed ten and then counted, one sentence for the array
     whole where none is run. The options:
     - (a) as built;
     - (b) a warning an element, as four scalar timers would have;
     - (c) none where any element is run.
     IEC says nothing, and no such warning of Logix's was found in the extracts read
     (**unverified**).
  3. *Two coils on one member, one through a tag subscript.* `xic a ote lane_c[i].r` and
     `xio a ote lane_c[1].r`. As built, nothing is warned. Two coils through the very tag,
     `lane_c[i].r` twice, are the second-`ote` warning, and so are two literal elements by
     value, `lane_c[1].r` and `lane_c[01].r`. Decision 235 warns `ote lamps[2]` beside a
     write through `lamps[slot]` for a bool array. The options:
     - (a) as built;
     - (b) warned as decision 235 warns an element: "`lane_c[1].r` is in `lane_c`, which
       the `ote` on line 8 may write through a tag subscript".
     The warning is logex's own (decisions 207 and 235); IEC and the extracts of Logix
     read say nothing of it.
  4. *A block's member retyped in an array of its instances.* `var ws w[3]`, and an edit
     changes `w`'s `x` from a bool to a dint. As built, it is refused once, by the first
     element, "`ws[0].x` is a bool in the running program and a dint in the candidate: a
     member's type changes only with a restart". The options:
     - (a) as built;
     - (b) named for the array, "`x` of each element of `ws`";
     - (c) a refusal an element.
     Logix changes an existing array's size or data type offline only (1756-RM094N p.85),
     and says nothing found of how it names the change.
  *The review of M5-14 (2026-10-25)*, which found the code right against scalar twins
  over 400 seeded programs and 300 seeded edits, answered in four gated commits,
  `f218b2e`, of a test file only, `a9ae919`, of code and tests, `0b40fc0`, of tests only,
  and one of documents.
  (1) `382777e` had deleted the whole of M4-6's runner walk,
  `Logex.ApiContractTest.RunnerWalk`, with its two tests, and said nothing of it; its
  mutation table was judged by a suite without them. `f218b2e` puts the module back as it
  stood at `aa41f4d`, with decision 241's whole force of `pt` and M5-12's and M5-13's
  draws; M5-14's code passes it unchanged. (2) Four of the review's mutants lived, each
  changing what a program does; each now has a test red with it: a `tp` element pulsing
  on a first scan (X2); a one-shot an edit blocks in an element of user blocks firing at
  its next run (X3), or never leaving the block list (X4), now scanned against a scalar
  twin; and a member through a tag subscript as an instruction's third operand, `add x 1
  c[k].pv` with `k` out of range, throwing out of the public API (X7). (3) An edit moved
  each element of an array of instances by a put into the array's tuple, which copied the
  array once an element: linear in reductions, which count a tuple's copy as about one,
  but quadratic in wall time, an accept of `ton[65536]` 41 s and of `seal[65536]` 113 s.
  A switch and a prune now open each array of instances, keep its elements' changes in a
  map beside it and build it again once: `ton[65536]` accepts in 1.6 s, tests in 0.6 s
  and untests in 0.6 s, `seal[65536]` in 2.7, 1.8 and 2.1 s, a block holding `ton[65536]`
  in 3.3, 1.2 and 1.4 s (`m5/rv14/p/edit_time_big.exs`). A new growth test counts the
  words each step allocates, in a process the collector does not visit during it: from
  500 to 2,000 elements each step grows some 4.1 times, where the puts grew 10 to 12. (4)
  The seven `case` expressions are function clauses, and a test holds `lib/` to the four
  older ones, the parser's three and the runner's one. (5) README's "TIMER among them
  (1756-RM094N p.85)" went further than the page, which lists the exceptions, ALARM_xxx,
  AXIS_xxx, COORDINATE_SYSTEM, ENERGY_xxx, HMIBC, MESSAGE and MOTION_GROUP, and never
  names TIMER: README and decision 154's text now say the list does not include it. (6) A
  forces file's misfit quoted the value read, `1.0e-400` at an int point "got: 0.0": it
  now quotes the line as written, as decision 202 quotes a literal (provisional, Question
  5). (7) Two coils through the very tags on an element, `ote l[k]` twice, were told the
  array "may" be written, where `ote w.[n]` twice is told "`w.[n]` already has an `ote`":
  they are now told "`l[k]` already has an `ote` on line 6", as a member's `ote c[i].r`
  twice already was (provisional, Question 6).
  Cost, against `08cf605` (`m5/rv14/cost_base.txt`, `cost_now.txt`): the review's seven
  programs of no array of instances scan in exactly the reductions they took; they
  compile in 22 to 30 more of 7,000 to 10,600, the clauses' calls; an edit's accept takes
  35 to 210 more of 4,300 to 8,000, within the 700 by which one run of it varies, a test,
  untest and assemble 4 to 13 more. README's `lanes.exs` is unchanged by the review.
  *Mutation table* (`m5/rv14/mut/run.log`, `m5/rv14/mut2/run.log`), each mutant judged by
  the full suite's exit code on `a9ae919`: the review's four survivors, X2, X3, X4 and
  X7, each red with its new test; and 22 of the fixes' own, 18 red at once: each of the
  five places an array is opened dropped (Q1 to Q5), the rebuilt array ignoring its
  changes (Q6b; Q6 as first written did not compile) or left open (Q7), no array opened
  for a program that has any (Q8), the sizes read as one dimension (Q10), no element an
  instance (Q11), the timer facts of an element (Q12), an element's type taken as its
  array's (Q14), the compiler's and the type's held names of an array of blocks (C2, F1),
  the very-tags wording (W1), and a forces file's integer and whole-line misfits quoted as
  read (U1, U2). Three survived, and each is red after `0b40fc0`, which pins each: the
  edit's facts of an array of user blocks (Q13), now a block's new member started in each
  element and pruned by a cancel; the compiler's one-version check of such an array
  declared from Elixir (C1); and a real point's misfit quoted as read (U3), `temps[2]
  1.0E39`. Q9, an opened element read back from the array rather than from its changes,
  is left alive as equivalent: no rule reads an element after writing it in the same
  window. 2194 tests (11 doctests), up from 2185.

  **Questions for the maintainer from the review**, each taken provisionally as written:

  5. *How a forces file's bad value is quoted.* The forces file is the text file the
     runner reads at every start, one forced input a line, `name value`. An engineer
     writes the tank level's line in hex, `level 16#ffffffff`, which is 4294967295, too
     large for the `dint` point, and the runner refuses to start. As built since the
     review it says "`level` is a dint, forced to an integer from -2147483648 to
     2147483647, got: 16#ffffffff", the value as the line writes it, and `1.0e-400` at an
     int point "got: 1.0e-400"; until then it said "got: 4294967295" and "got: 0.0", the
     value read. A host's `force/3` gives a value, not text, and is quoted as the value.
     The options: (a) as built, the text as written; (b) the value read, as decision
     226's example was pinned; (c) both, "got: 16#ffffffff, which is 4294967295". Logix
     keeps forces in the project, not a file (1756-PM004L pp.52–53), so offers no
     precedent; IEC says nothing of forcing.
  6. *Two coils through one subscript tag.* A conveyor's lamps, `lamps bool[8]`, and two
     rungs `xic a ote lamps[slot]` and `xic b ote lamps[slot]`: whichever comes last
     sets lamp `slot`. As built since the review it is told "`lamps[slot]` already has an
     `ote` on line 6: the last one in the scan decides it", as `ote lamps[2]` twice and
     `ote w.[n]` twice are; until then "`lamps[slot]` is in `lamps`, which the `ote` on
     line 6 may write through a tag subscript". Through two tags, `lamps[i]` and
     `lamps[j]`, it is still told the array "may" be written, since they may name two
     lamps. The options: (a) as built; (b) the array's words, as before. Decision 246 says
     two coils through the very tag are two coils, warned, but not in which words; the
     warning is logex's own, and no such warning of IEC's or Logix's was found
     (**unverified**).
  **The maintainer's answers**, 2026-10-26 (decisions 248 to 256, M5-13's questions 8 to
  10 and M5-14's six), **landed the same day** as one gated commit of code, tests and the
  record, `f6b4c55`, and one of documents. Five confirm what was built: the forces file one line an
  element even where every element is forced (decision 248); two instances writing the
  same literal elements told once, the elements named together (249); an edit dropping
  `move 2 lane_c[k].pv` reporting every element's `pv` unwritten (251); one warning an
  array of instances some of whose elements run, ten then a count (252); and two coils
  through one subscript tag told "`lamps[slot]` already has an `ote` on line 6" (256).
  Four change it:
  - *A subnormal literal beside a literal* (250): `gt 1.0e-310 0.0` is refused, "`gt`
    reads a number or a bit string, and compares two literals as lreals: `1.0e-310` is
    too near 0.0 for an lreal, …", either side, as `eq 1.0e-400 0.0` is; the smallest
    normal double beside a literal is taken.
  - *A member through a tag subscript beside a literal element's* (253): `ote
    lane_c[i].r` beside `ote lane_c[1].r`, either first, is the second-`ote` warning in
    decision 235's words, "`lane_c[1].r` is in `lane_c`, which the `ote` on line 8 may
    write through a tag subscript", and so is any other write of the member through a
    tag subscript, `otl lane_c[i].r`, beside a coil on a literal element's, and a literal
    element's written beside a coil through one; the very member through the very tags
    is warned of nothing (decision 246), and through other tags, `lane_c[i].r` beside
    `lane_c[j].r`, it is warned (provisional, Question 8).
  - *A block's member retyped in an array of its instances* (254): refused once, "`x` of
    every element of `ws` is a bool in the running program and a dint in the candidate: a
    member's type changes only with a restart", in a block's instance by its path, `b.ws`,
    and in turn in an array of blocks that hold one (provisional, Question 9).
  - *A forces file's bad value* (255): quoted as written and as read, "got: 16#ffffffff,
    which is 4294967295", once where the two are one text, "got: 2147483648", a line that
    holds no number quoted as written, "is no force", as before.

  README's "Reals" gains `gt 1.0e-310 0.0` in `fan.exs`'s refused program, re-run on the
  commit; `lanes.exs` is unchanged by the answers. The cost, measured against `26d0955`
  (`scratchpad/m5/a17/cost.exs`, three runs each): every program of the cost script
  compiles and scans in the reductions it took, within the base's own spread of a few
  reductions, but two that hold what the answers look at, which scan as before and compile
  dearer: 200 comparisons of two literals, 2,298 reductions of 224,548 (1.0%), a real
  literal's flush checked; and 50 rungs that coil and latch a member of an element, 4,055
  of 170,250 (2.4%), the members compared. An edit's accept of 100 relays and of an array
  of 16 blocks costs what it did, and the lexer's five scripts what they did. *Mutation
  table* (`scratchpad/m5/a17/mut/run.log`), each mutant judged by the full suite's exit
  code on a copy of the commit: 27 mutants on `f6b4c55`, 26 red at once: A1 and A2 (decision 250: the flush never checked, checked in a `real`), W1 to W15 (decision 253: a literal element's coil not told a coil or a write through a tag subscript before it, its member not kept for later, a tag-subscripted coil not told a literal element's coil, the very tags' exemption and wording dropped at a coil and at a write, a literal element's write not told a coil before it or not kept, the member left out of the words a coil names, a literal element's write not looked for, told as a whole write, and the member left out of either key), P1 to P4 (decision 254: the first element's path again, a leading `.`, a tag's for a member's, an array inside an element not cited in turn) and R1 to R5 (decision 255: the one-text case dropped, the value read never shown, a whole line's, a real point's or an integer point's misfit as written alone). One survived, A3, the message's value 0.0 for the literal's, which is equivalent: `Logex.Declarations.literal_misfit/3` reads only whether a float is in its type's range, and both are, so it is left alive.

  2195 tests (11 doctests), up from 2194.

  *Provisional readings* (the answers'), each a question for the maintainer *(answered on
  2026-10-26: 7 changed, a bit of a member of an element compared, decision 257; 8
  confirmed, decision 258; 9 changed, one path with `[*]`, decision 259; below, after
  M5-16's review)*:

  7. *A bit of a member of an element, coiled twice.* A sorter's lane counter, `lane_c
     ctu[4]`, and two rungs `xic a ote lane_c[1].pv.3` and `xic b ote lane_c[1].pv.3`:
     whichever comes last sets bit 3 of lane 1's preset. Found on the way to decision
     253: as built nothing is warned, where two coils on a bit of a scalar instance's
     member, `ote c.pv.3` twice, are the second-`ote` warning (M5-8's review), and so is
     a coil on it beside `move x c.pv`. The options: (a) as built, a bit of a member of an
     element not compared; (b) compared as a member's bit is, by its path, `lane_c[1].pv.3`,
     two coils on it warned and a coil beside a write of the member whole warned, and one
     through a tag subscript, `lane_c[i].pv.3`, as decision 253 compares a member. The
     warning is logex's own (decision 207); IEC and the Logix extracts read say nothing
     of it.
  8. *Two lanes' members through two tags.* `xic a ote lane_c[i].r` and `xic b ote
     lane_c[j].r`: when `i` and `j` hold one lane, the last rung decides it, and
     otherwise each resets its own lane. As built since decision 253 it is told "`lane_c[j].r`
     is in `lane_c`, which the `ote` on line 8 may write through a tag subscript", as
     `ote lamps[i]` beside `ote lamps[j]` is for a bool array (decision 246); until then
     nothing. The options: (a) as built; (b) nothing, since the tags may name two lanes.
     The warning is logex's own; IEC and the Logix extracts read say nothing of it.
  9. *A member retyped in an array of blocks inside an array of blocks.* `var hs h[2]`,
     each `h` holding `var ws w[2]`, and an edit changes `w`'s `x` from a bool to a dint.
     As built since decision 254 it is told once, "`x` of every element of `ws` of every
     element of `hs` is a bool in the running program and a dint in the candidate: …".
     The options: (a) as built; (b) by the inner array's path below the outer's element,
     "`x` of every element of `hs[*].ws`"; (c) by the first elements, `hs[0].ws[0].x`,
     as before decision 254. Logix changes an existing array's size or data type offline
     only (1756-RM094N p.85), and says nothing found of how it names the change.
- **M5-15 · The contract walk's cross-type reach.** Each item above has extended the walks
  with its own rules; this one draws the types together: programs, configurations and
  runner walks that mix every type, `@junk` and `@edges` by type (`1.0` stops being junk
  for a real), mixed-type `cal`s and connections (decision 159), bits and arrays with
  literal and tag subscripts, and edits refused by type, against oracles that restate each
  rule. *Done when* the walks' reach covers every type, every refusal kind and every trip
  reason but `{:internal, message}`, repeating exactly from fresh processes. *Size L.*

  **Status: DONE — landed 2026-10-26**, as gated commits: `7c19e4b` lands the walks, the defect
  they found fixed with a focused test, and the record's note on it; and a second holds
  the documents. No syntax and no rule of the language changed but the one message.

  The walks' cross-type reach is `Logex.ApiContractTest.CrossTypeWalk`, a module of its
  own in `api_contract_test.exs`, so that it runs beside the other walks, and the runner
  walk's configurations mixed. Its oracles know nothing of logex: each type's range, Ed 3
  Figure 11 as its edges, the wrap, the binary transfer, IEEE 754's rounding, IEC's CTU,
  CTD and TON in nanoseconds, the index and bit faults, and the host's rule for each
  type's input, restated in the test.
  - *Every pair.* `move` over each ordered pair of the fifteen elementary types, accepted
    by Figure 11 or refused in its words, naming its conversion or saying there is none;
    each of the 182 conversions and truncations given a source of each type and a
    destination of each type, taking exactly the sources Figure 11 widens into its
    `from` type and its own destination, each refusal and its hint in its words; `add`
    and `and` over every pair, taking exactly their class; and a connection of each type
    into a var_input and out of a var_output of each other type, widening by Figure 11
    or refused naming the conversion a program would make (decision 159).
  - *Programs that mix the types,* 400 at its seed: two to four types drawn from the
    fifteen, each a var_input, a var_output and an array of one or two dimensions, with
    an initial value or list now and then, beside a var_input array of another type, a
    typed counter's array (`ctd_int`, `ctd_udint`, `ctu_int` or `ctu_udint`), a long
    timer's array (`ton_ltime[2]`) and a block whose var_input and var_output widen
    (decision 159). Their rungs move, convert, truncate, add and mask across the types,
    each operand a tag, an element by literal or tag subscripts, a member of an element of
    an instance array, a bit by a literal or a tag number, or a literal, now and then
    based (decision 149). Every scan's outputs, instances and faults are exact, over a
    host's mistakes and each input's edges by type, `1.0` a real's value and junk for
    every other type (the walks' `@junk` and `@edges` by type), restarts, and edits that
    keep every value, report a changed initial value as declared (decision 157), or
    change a scalar's type, an array's size or an instance array's kind, which accept
    refuses at each tag's line in its words; and in a resource whose located globals,
    a located array among them, are each of a type Figure 11 widens into the program's
    input, and whose globals its outputs and arrays widen into. Its reach is every type
    read, written, in an element, at a point, given at its edges and refused from a host;
    every family of conversion, integer to integer, to and from a bit string, to and from
    a real, between the reals, and the truncations; a wrap, a saturation, a tie; the
    index, bit, contact and de-energised `ote` faults; a counter at its type's limit and
    a long timer done; each edit and each host refusal; and the walk again from a fresh
    process, exactly.
  - *The runner walk,* whose configurations now mix the types: the drive's `dr real` and
    `dw word` points, pressed and forced, a `qu uint` output, and a program of a typed
    counter's array, a long timer's array and a real array the panel's dint subscripts;
    a float past a single's range at the real point a bad value, among its read faults.
    Every trip reason but `{:internal, message}` is reached as before, now in mixed
    configurations. The draws changed with the configuration, and the seed family
    `{2026, 10, n}` missed `:array_unforced`, so the walk draws `{2027, 10, n}`; of six
    families checked three reached every atom, each miss a reach and no check. Its input
    check compares a reading by value, a real point's 0 from its device and the 0.0 the
    resource holds being one reading.

  **The defect the walks found.** A truncation's misfit was told the conversion that
  rounds: `real_trunc_int` given an lreal source was told "use `lreal_to_int`", given a
  dint destination "use `real_to_dint`", and given a real destination "use `move`", none
  of which truncates, where decision 148 tells a conversion's slot the conversion that
  does the whole job. It is now told `lreal_trunc_int` and `real_trunc_dint`, and a real
  destination nothing (provisional, question 1); a source of an integer or a bit string
  is still told its conversion. `real_test.exs` pins each, failing with the fix reverted;
  decision 162 notes it.

  **Cost.** The compiler's one new clause is met only by a truncation's misfit: every
  program of `a18/cost.exs`'s 33, a truncation's among them, compiles and scans within
  its parent's own spread, every scan identical, over two runs each; an edit's accept and
  the lexer cost what they did. The suite's wall time, two runs each, interleaved on one
  machine: 80.4 and 82.4 s at `98cd152`, 87.1 and 87.9 s at `7c19e4b`, some 6 s more, the
  cross-type walk about 2 s of it and the runner walk's mixed program the rest, its walk
  now about 10 s; the suite passes 2198 tests (11 doctests, 2187 tests), 3 more.

  **Mutation table** (each judged by the full suite, `a18/mut/run.log`): fifteen mutants,
  every one red, the cross-type walk failing for each, and for X10 alone.

  | Mutant | Planted | Red in |
  |---|---|---|
  | X1 | a truncation's lreal source told `lreal_to_int` again | CrossTypeWalk, RealTest |
  | X2 | a truncation's integer destination told `real_to_dint` | CrossTypeWalk, RealTest |
  | X3 | a truncation's real destination told `move` | CrossTypeWalk, RealTest |
  | X4 | a `uint` no longer widening into a `real` | CrossTypeWalk, TypeTableTest |
  | X5 | a bit-string transfer not kept to its `from` width | CrossTypeWalk, BitStringTest |
  | X6 | a typed down counter going past its type's minimum | CrossTypeWalk, RunnerWalk, the counters' tests |
  | X7 | a block's real formal given an integer unconverted | CrossTypeWalk, RealTest |
  | X8 | a block's copy-out into a real left an integer | CrossTypeWalk, RealTest |
  | X9 | a connection's integer copy-out into a real global left an integer | CrossTypeWalk, RealTest, ArrayConfigurationTest |
  | X10 | an lreal input taking an integer past its range | CrossTypeWalk alone |
  | X11 | a long timer's millisecond adding 1,000 ns | CrossTypeWalk, LongTimerTest and others |
  | X12 | an array of instances' type named in the singular | CrossTypeWalk, InstanceArrayTest, ArrayTest |
  | X13 | a counter's load keeping its `un` | CrossTypeWalk, CounterTest and others |
  | X14 | a real input taking an integer past its range | CrossTypeWalk, RealTest, EndToEndTest |
  | X15 | a down counter's `q` at `cv < 0` | CrossTypeWalk, CounterTest and others |

  A first run on an earlier snapshot of the walk, whose draws differed, found X5 caught by
  `bit_string_test.exs` alone; the walk as landed meets a negative source widened into a
  wider bit string and catches it, which a run with X5 planted confirmed.

  **Questions for the maintainer** *(answered on 2026-10-26: 1 changed, a truncation into a
  real told it writes an integer, decision 260; 2 confirmed, as declared, decision 261;
  below, after M5-16's review)*.
  1. *A truncation into a real.* A programmer writes `real_trunc_int fan_hz shown`, the
     fan's 37.9 Hz to show as 37, but declared `shown` a `real`. The compiler refuses it;
     what does the message suggest? (a) Nothing, as built: "`real_trunc_int` writes an
     int, but `shown` is a real (declared on line 2)"; (b) "use `move`", as before, though
     a move would show 37.9; (c) say why, "no instruction truncates into a real: declare
     `shown` an integer type". IEC's TRUNC writes only an integer (Ed 3 Table 22 feature
     2b, decision 162); Logix's TRUNC writes a REAL or LREAL destination too
     (1756-RM018A-EN-P pp.828–829), so a Logix programmer may expect one.
  2. *An initial value reported as declared.* An edit gives `var_output speed real` an
     initial value, `1.0e-30`. The report reads `{:initial_changed, "speed", {0.0,
     1.0e-30}}`, the value as written, though a real holds it as 1.0000000031710769e-30,
     which a restart will start it at. (a) As declared, as built, decision 157's "compared
     exactly as declared", so `0` edited to `0.0` is reported though both start at 0.0;
     (b) the value it will start at, so the operator sees what a restart gives, and `0`
     to `0.0` reported no more; (c) both, `{0.0, 1.0e-30}` beside what it starts at. The
     walk found the two edits differ today: a configuration's `var_global speed real
     1.0e-30` is held at its nearest as the file is read, so a configuration edit reports
     `{0.0, 1.0000000031710769e-30}`, while `var_global x real 0` still reports `0`, as
     written; the walk restates each as built. Logix has no declared initial value but the
     value a download carries, unverified.

  **Review of M5-15, and its fixes** (2026-10-26, on `943c05f`). The review planted 22
  mutants: 17 were caught by the new walks, four survived the whole suite and one more was
  caught only by an older test; at 30 fresh seed families the runner walk failed real
  checks in two and reached every atom in only ten; a check had been loosened. Each
  finding became:
  - *Four survivors, each a misbehaviour the suite let through* (Y6, Y9, Y10, Y18): each
    is now a focused test that fails with its mutant planted. `array_configuration_test.exs`
    holds an int var_output element at a near end, `m1.o[0] rs[2]`, into a real global
    array as 1.0, never 1; `long_timer_test.exs` reads and writes bits 0, 31, 32, 40, 62 and
    63 of a `ton_ltime`'s `.pre`, a scalar's, a literal element's and a tag-subscripted
    one's, bit 63 its sign; `bit_string_test.exs` computes `not`, `shl` and `rol` of a
    `byte[2]` element, by literal and tag subscripts, in 8 bits, and `not` of an element's
    member in its member's type.
  - *The new walks' reach, which had met five rules only by chance* (Y5, Y9, Y10, Y13,
    Y20): the cross-type walk now draws `not`, `shl`, `shr`, `rol` and `ror` across the
    widths, decision 214 restated in the source's bits and decision 165's counts, a count
    a literal about the width or an integer tag, `s` among them, negative now and then; a
    long timer's preset with bits above 31, 2^32 and 2^40 ms and the largest whole number
    of milliseconds a lint holds, and a bit above 31 of its `.pre` read every rung; the
    block's own lword output `w`, a scalar instance's member, read by bit; integers a real
    rounds as a tie up to the even one, 2^24 + 3 and 2^53 + 3, among each wide integer
    type's inputs, an lreal input no single holds, 16777219.0 and 0.30000000000000004, and
    a conversion reading an input three times as often as another source; and a resource
    whose outputs go now and then into an element of a global array of two, `m1.y0 gv0[1]`,
    and whose output arrays go element by element into their globals', both widening.
    Each is a reach atom, `:rounded_into_real`, `:tie_rounded_up`, `:not_wider`,
    `:shift_wider`, `:rotated`, `:negative_count`, `:member_high_bit`, `:block_member_bit`,
    `:element_out_into_real` and `:elements_out`, so a walk that stops meeting one fails.
  - *A defect the extended walk found.* `not` and the shifts of a user block's member, or
    of a member of an element of an array of them, computed in the destination's type:
    `shr b.o 33 y`, `o` a dint at −2^31 and `y` a lint, wrote 2147483647, where decision
    214 computes in the source's dint and writes 0. `Logex.Program.destination/3` types a
    destination, and logic outside a block never writes a block's member, so it gave none;
    the scan now reads the member's type in its block, in the program's one table
    (decision 53). `bit_string_test.exs` pins it; decision 214 notes it.
  - *The runner walk's two failing families* (`{3113, 10, n}` and `{3111, 10, n}`): both
    were the walk's model, not the runner, each reproduced and traced. In 3113 the walk
    told the panel's next write to fail and advanced a poll period expecting that write
    to trip the runner, but a round tripped first on `b1`'s major fault, before its write;
    the failure then met the trip's 0, which the device passes over (decision 135, "where
    it still takes a write"), or, on another run, a poll's write again just before it, so
    the panel kept its last outputs or was written 0. The model now allows either for a
    device whose write's failure a different trip overtook. In 3111 the walk's poll period
    before a "stuck runner" injection let a round trip the runner already, and the model
    still expected the device's deadline to trip it; it now checks a runner tripped already
    and moves on. `trip_test.exs` pins the runner's side: a trip's 0 that fails is passed
    over, the first reason kept, nothing written, until a restart writes again (question
    3 asks whether it should try again). Over the 32 families checked after the fixes, no
    check failed, nor in the 32 run before the draws were raised.
  - *The runner walk's fragile reach, and its seed.* The walk is back at the record's seed
    family `{2026, 10, n}`, and its draws are raised rather than its seed moved: 45 walks
    where there were 30; a trigger forced half the time to the other value than it reads,
    so that the force makes its round; forced triggers and the triggers pressed more
    often, the panel's dint more often -4, an array forced whole drawn among the forces and
    unforced whole about as often as all its other forces together, and a continuous task's
    slow step twice among the injections. Every atom is reached at `{2026, 10, n}`; of the
    31 families `{2026, 10, n}` and `{3101..3130, 10, n}`, 28 reach every atom, where the
    review found 10 of 30 at fresh families, the three misses `:next_due_from_step` (an interval cut a while after
    the last round, rare by its nature, decision 139) and, once each, `:array_unforced`
    and `:forced_trigger`, each a reach and no check. The walk takes about 20 s alone,
    where it took 10, run beside the suite's other modules. Its self test of the input
    check, which seeks the first walk to give the core a late input, now meets it at the
    44th of its own seeds, so it searches to 80 where it searched to 40.
  - *The loosened check* is scoped back: a real point's reading is compared by value, 0
    from its device and 0.0 in the resource one reading, and every other point's exactly,
    so a float at an integer or a bool point is no reading of it.
  - *Minor.* The cross-type walk's oracle, the rules it restates and the model of a scan,
    holds no `if`, `cond` or `case` now, each a clause; its draws keep `case` over a random
    number, as every other walk's do, the rule's grep being `lib/`'s (question 5). Decision
    250's words for a comparison are the maintainer's to change (question 4).

  The cross-type walk passes at its seed and at each of the 30 families `{3000 + i, 10,
  100 + 7i}`, i from 1 to 30, where before the review's run one missed `:saturated`.
  **Cost.** The runtime's change is met only by a `not` or a shift whose source is a
  member: a program of 300 of them, of a built-in instance and of an element, scans in one
  reduction more each, 31111 where its parent took 30811; every other program of
  `rv15/cost.exs`'s 34 scans exactly as at `943c05f` and compiles within its own spread,
  over two runs each. The suite's wall time, two runs each, interleaved: 86.2 and 76.8 s
  at `943c05f`, 78.4 and 82.9 s at the fix, within the parent's own spread; it passes 2203
  tests (11 doctests, 2192 tests), 5 more.

  **Mutation table** (`rv15/mut/run.log`, `run4.log`): the review's seven mutants the
  suite or the new walks missed, and two of the fixes reverted, each red, in its focused
  test and in the cross-type walk but ZF, which the runner walk meets only where a write's
  failure is overtaken.

  | Mutant | Planted | Red in |
  |---|---|---|
  | Y5 | a scalar into a real global array's element left unrounded | CrossTypeWalk, ArrayConfigurationTest |
  | Y6 | an element of a var_output array into one, the same | CrossTypeWalk, ArrayConfigurationTest |
  | Y9 | a member of an element's bit read through a 32-bit mask | CrossTypeWalk, LongTimerTest |
  | Y10 | a scalar member's bit, the same | CrossTypeWalk, LongTimerTest |
  | Y13 | the real conversions computing in an lreal | CrossTypeWalk, ApiContractTest, RealTest |
  | Y18 | `not` and the shifts of an element in the destination's type | CrossTypeWalk, BitStringTest |
  | Y20 | an integer's tie into a real no longer to even | CrossTypeWalk, ApiContractTest, RealTest |
  | UB | the block member fix reverted | CrossTypeWalk (both tests), BitStringTest |
  | ZF | a trip's 0 that fails raising in the device | TripTest |

  **Questions for the maintainer** (M5-15's review) *(answered on 2026-10-26: 3 changed to
  (c), the 0 tried again at each poll and `status/1` naming each device not known to be 0,
  decision 262; 4 changed to (b), "it would be read as 0.0", decision 263; 5 changed to
  (b), every walk's and end-to-end test's oracle in clauses, decision 264; below, after
  M5-16's review)*.
  3. *A trip's 0 that a device does not take.* A conveyor's drive card is told to stop:
     the runner trips, on a bit number out of range say, and writes every output 0 once,
     but the card's write fails that moment (a cable glitch, `{:error, :eio}`). Today the
     runner passes the failure over, as decision 135's "where it still takes a write"
     has it: the card keeps showing its last outputs, the conveyor's run bit still 1, and
     nothing tries again until a restart. What should an operator see? (a) As built: one
     zero, and the card's own fault behaviour is relied on; (b) the zero tried again at
     each poll while the runner is tripped, until one is taken; (c) (b), and `status/1`
     names each device whose outputs are not known to be 0. IEC says nothing. In Logix the
     output module itself goes to its configured fault state when the controller faults
     or its connection is lost, "A major fault on the controller causes the outputs to go
     to their configured fault state" (1756-UM900B p.242) and "the output remains in the
     Fault mode state until a connection is re-established" (1756-UM058L p.83), so the
     module, not a write from the controller, holds the safe state.
  4. *Decision 250's words for a comparison.* `gt 1.0e-310 0.0` is refused "…: it would be
     written as 0.0", words decision 240 took from a write; a comparison writes nothing.
     (a) Keep them, one message for every slot; (b) "it would be read as 0.0" in a
     comparison's slots alone; (c) "the comparison would compare 0.0". IEC and Logix have
     no such message; unverified for Logix's handling of a denormal constant.
  5. *Clauses, not conditionals, in tests.* CLAUDE.md's rule is enforced on `lib/` by a
     grep; the test files hold some 300 `if`, `cond` and `case`, most in the walks' draws
     and harnesses. This review made the cross-type walk's oracle clauses. (a) `lib/` only,
     as now; (b) every walk's oracle too, the draws free; (c) all test code, with the grep
     extended. IEC and Logix have nothing to say here.
- **M5-16 · The documents' closing pass.** Each item has brought its README sections,
  instruction table rows and stanzas; this one checks "What logex is not" (which says
  "bool and dint only, no real, no bit access, no arrays") against the code,
  `docs/naming.md`'s `bool`, `dint` and `at` stanzas and its deferred and rounding rows,
  `docs/organisation.md` §4.1, §4.5, §4.7, §4.8, §4.12 and §5 annotated as landed,
  `PLAN.md` M1-3 and §5's structured-addressing entry, CLAUDE.md's Key Files, and
  Milestone 5's done sentence clause by clause against the tests. *Size S.*

  **Landed** (2026-10-26), as one commit of the documents, no code in `lib/` or `test/`
  changed. README: every example run again on the tip, each of the 30 `mix run` outputs
  the same as printed but the run on the real clock, whose keyword list is the same in
  three runs and whose figures are now that run's, 1,229 rounds in 1,230 ms; and the
  quoted messages beside them compiled again, of which one was stale, the unknown type's
  list for `var s3 sael`, which lacked `real` and `lreal` since M5-10, now as the compiler
  gives it. The intro says what the code has: forty instructions and the 182 typed
  conversions, in thirty-two modules, where it said thirty-one and twenty-nine, and
  Milestone 5's types landed whole; the instruction table's `neg` and `abs` write a real
  too, where it said an integer; the dialect's syntax list names the timer and counter
  type words, `status.[n]`, a tag subscript, a bit of an element and an array of
  instances; "Settled, not yet landed" says nothing decided waits to land, Milestone 5
  having landed whole; and "What logex is not" lists what Milestone 5 left deferred, the
  TIME and LTIME types, strings, structures, enumerations, typed literals, IEC's array
  bounds, a whole-array copy, partial access, `round`, `ceil` and `floor`, and the timers'
  millisecond resolution, each checked against the code. `docs/naming.md`, append-only,
  gains seven amendments: `bool`'s place in the type table and as a bitwise operand;
  `dint`'s M5-3 amendment past; `at`'s "logex has no BYTE or WORD" no longer true, and a
  located array; the Arithmetic, Bitwise and Data movement tables' deferred rows, which
  landed and which stay deferred, the rounding row's truncation landed and `round`,
  `ceil` and `floor` not; and `ton_ltime`'s conventional row's citation. 
  `docs/organisation.md`: §4.1, §4.5, §4.7, §4.8, §4.12's head, §5's two rows and the head
  of Milestone 5's decisions annotated as landed, decision 221's "until M5-12" annotated
  past, and two citations corrected where they stand. This plan: its status, §1's "What
  works", M1-3's types and signatures, and §5's structured addressing, whose bit IR has
  carried its name since M5-8's review and whose arrays and float-literal trap are now
  past.
  CLAUDE.md's Key Files: the facts that went stale with Milestone 5 put right, each
  still-true fact kept: a `var_external` of any elementary type, where it said a bool or
  a dint; a tag's type any row of the table or an array; an instruction slot's generic
  types; the runner that "will read" a watchdog and a clock, which it reads; README's
  sections of M5-9, M5-11 and M5-13; and `docs/organisation.md`'s status through M5-16.
  One code document is stale and left as it is, since no test can fail on it:
  `Logex.Tag`'s `@type t` gives `initial` as an integer or a map, where a real's is a
  float and an array's a list, and `type` without an array; a typespec has no reader in
  the suite but the compiler, which does not check it, so its fix waits for an item that
  changes `Logex.Tag`. *(Fixed by M5-16's review, which found more of it stale: below.)*

  **The record's Logix and IEC claims, checked** (2026-10-26), against the extracts of
  the manuals (1756-RM018A, Sept 2025; 1756-RM094N, Sept 2025; 1756-PM004L, Nov 2023;
  1756-PM014O, Sept 2024; 1756-PM015Q, Sept 2025; 1756-UM058L; 1756-UM900B) and of IEC
  61131-3 Ed 2:2003 and Ed 3:2013, each at its printed page: the 182 citations of a
  Logix publication in §4.12, decisions 144 to 256, this Milestone and `docs/naming.md`'s
  Milestone 5 stanzas, 58 distinct pages, each claim read beside its page, and the 51 IEC
  citations with a page, each quotation found on its page or the one beside it where a
  table runs across two. Found false and corrected: 1756-PM004L "p.21" for a module's data
  copied whole with CPS, which is p.20 (decision 241, M5-13's first question); 1756-RM094N
  "p.13" for LTIME on the 5x80 controllers, which is the 5590 chapter's, the 5x80's p.21
  (§4.12's table, decision 158, `docs/naming.md`'s `ton_ltime`); "Logix has no conversion
  instructions", where it has TRUNC, TO_BCD and BCD_TO, only no typed conversion between
  numeric types (M5-3's second question); and "Logix has one TIMER", "one unit, the
  millisecond", where the 5x80 and 5590 timers take a TIMER_T in microseconds too
  (1756-RM018A pp.110–111; M5-6's questions). Marked **unverified**, having no page: that
  Logix checks a program once, at download (decision 182, M5-4's and M5-5's questions).
  Imprecise but true, left as they stand: IEC's Table 22 footnotes b and c, cited at
  p.78 where the table starts, are on p.79; Table 31's "overloaded on all bit-string
  types", cited p.89, is on p.88; Table 11 feature 4, cited p.53, is on p.35, p.53 holding
  the examples with negative bounds *(each corrected by M5-16's review: decision 151's
  in place, `docs/naming.md`'s two by an amendment)*; and "Logix has no bit-string types" rests on p.873's
  list of types beside p.874's table. 1756-PM013H and 1756-PM020I, cited for STRING's 82
  characters and DWORD as a CIP type code, are not among the extracts and are unverified
  here, the first also given by 1756-RM094N p.90. The working table is the scratchpad's
  `m5/a19/cl/verdicts.md`.

  **Milestone 5's done sentence, checked** (2026-10-26, on M5-16's tip), clause by clause,
  with the test that shows each; a test named here is in `test/logex/`.

  | Clause | Shown by |
  |---|---|
  | a program and a configuration of §4.4's plant, loaded from files on disk, declare and run every type decisions 144 and 155 name | **piecewise, not as one plant.** From files on disk through `Logex.Runner` on the manual clock against an oracle that knows nothing of logex: `end_to_end_test.exs`, "M5-3's Done-when: the drive's speed read as a uint point and moved into a dint" (`uint`, `dint`), "M5-8's Done-when: the drive's status read as a word point, its bit 3 lighting the run lamp" (`word`) and "M5-10's Done-when: the fan's speed is a real read from the drive" (`real`, `lreal`, `int`). Every integer width and bit string reaches the runner on the manual clock only as a card of points, `integer_width_test.exs`, "each width's limits are read from the device, and one past them trips the runner", and `bit_string_test.exs`, "each one's values are read from the device, and one past them, -1 or a float trips the runner"; and every type runs in programs and resources in `api_contract_test.exs`, "programs that mix every type run as each type's rules restated: …", against oracles that restate each rule, through no file and no runner. **No plant declares `sint`, `lint`, `usint`, `udint`, `ulint`, `byte`, `dword` or `lword`** (question 1). *Since M5-16's review, whole:* `end_to_end_test.exs`, "Milestone 5's done sentence in one plant", §4.4's plant from files on disk whose bench program and configuration declare all fifteen, each a point of its own type read and written through `Logex.Runner` on the manual clock against an oracle that knows nothing of logex |
  | the fan's speed a `real` from the drive card | `end_to_end_test.exs`, "M5-10's Done-when: the fan's speed is a real read from the drive" |
  | and its eight zone temperatures a located `real[8]` | `end_to_end_test.exs`, "M5-13's Done-when: the oven card's eight zones are one located array" |
  | the box counter a typed counter | `end_to_end_test.exs`, "M5-5's Done-when: a ctud_int and a ctd_udint stop at their types' limits in a plant", from files on disk **through `cycle/3`, not the runner**; through the runner only in the runner walk's `mix` program, `ctd_udint[2]`, against a model that calls `cycle/3` (`api_contract_test.exs`, "the runner on the manual clock runs each round as cycle/3 runs it, …") (question 1). *Since M5-16's review:* the one plant's `ctud_int` box counter, loaded to 32767, stopping there with `ov`, and counted down, through the runner against IEC's CTUD restated |
  | and its weights an array indexed by a tag | `end_to_end_test.exs`, "M5-12's Done-when: the box counter's `weights[slot]` runs in the plant, and `slot` at 8 trips it", whose box counter counts by a one-shot, `ons edge`, not a typed counter; *since M5-16's review* the one plant's, whose box counter is the `ctud_int` |
  | an integer result past its width wraps with no power | `arithmetic_test.exs`, "`add`, `sub`, `mul`, `div` and `mod` at each width's limits, in its own type", and the dint's "a sum past the top wraps to the bottom and passes no power on that scan …" |
  | a real's saturates | `real_test.exs`, "a result past a real's range saturates with no power" |
  | and no infinity, NaN or −0.0 ever reaches a state | `real_test.exs`, "no float exception leaves a scan, and no state holds −0.0 or a subnormal", "−0.0 and a subnormal are written as 0.0" and "a state's real holds one of its type's values: a float, never −0.0, no subnormal" |
  | every mixed-type operand Figure 11 does not widen is refused naming its conversion | `integer_width_test.exs`, "move takes a source its destination's width holds, and names the conversion for every other pair"; `arithmetic_test.exs`, "a source no Figure 11 cell widens into the destination's type is refused, …"; `real_test.exs`, "a type Figure 11 does not widen is told its conversion"; and the cross-type walk's every pair through `move`, each conversion's two slots, `add`, `and` and a connection |
  | and every conversion rounds as IEC's examples say | `real_test.exs`, "a real into an integer rounds to the nearest, a tie to the even neighbour", IEC's `REAL_TO_INT(2.5)` and `(-2.5)` among its cases, and the 34 conversions and 16 truncations against IEC's examples |
  | an index or a bit number out of range trips the runner with every output 0 once | `end_to_end_test.exs`, "M5-9's Done-when: the run lamp follows `drive_faults.[sel]`, and `sel` at 16 trips the plant" and "M5-12's Done-when: …, and `slot` at 8 trips it", every output 0 once and nothing after; `trip_test.exs`, "a bit number out of range trips at the end of its step, before the round's …"; and *since M5-16's review* the one plant's `slot` at 8, every output of its four devices 0 once. Each through a device that takes the write: a zero whose write fails is passed over (decision 135), M5-15's review's question 3 |
  | and a negative square root is a minor fault, `:negative_sqrt` | `real_test.exs`, "a negative source writes 0.0 with no power and the minor fault `:negative_sqrt`", alone and as a cycle's event |
  | an online edit of a type or a size is refused | `edit_test.exs`, "refuses a type change, every one, at the candidate's line, in line order"; `integer_width_test.exs`, "a width changed is refused at its line, …"; `bit_string_test.exs`, "a bit string's type changed is refused at its line, …"; `real_test.exs`, "a type change between the reals is refused"; `array_test.exs`, "an array's type, its dimensions or its sizes change only with a restart"; `instance_array_test.exs`, "an array of instances changes its sizes or type only with a restart, …" |
  | and a changed initial value of every type is reported | `integer_width_test.exs`, "… and a changed initial value of each width reported"; `bit_string_test.exs`, "… and a changed initial value reported"; `real_test.exs`, "`var x real 0` edited to `var x real 0.0` is a changed initial value"; `array_test.exs`, "a changed initial list is reported element by element, the running values kept"; a bool's and a dint's since OE-1, `edit_test.exs`, "for a kept var or var_output, keeps the running value, is reported at each …" |
  | and the contract walks reach every type, refusal and trip reason, repeating exactly | `api_contract_test.exs`, "programs that mix every type run as each type's rules restated: …", its reach asserted whole and a fresh process's first walks the same; and "the runner on the manual clock runs each round as cycle/3 runs it, trips as the watchdogs and the faults say, and reaches every event kind and trip reason", every trip reason but `{:internal, message}`, which only the hidden seam reaches (`trip_test.exs`) |

  So every clause is shown by a test but the first and the typed counter's: the done
  sentence puts every type and a typed counter in one plant, from files on disk, through
  the runner against an oracle, and the suite shows the types each in its own plant, card
  or walk, eight of the fifteen never in a plant, and the typed counter through `cycle/3`
  in a plant and through the runner only in a walk against a model. Whether that reading
  stands, or a test closes it first, is the maintainer's (question 1). *(M5-16's review
  agreed with (b), and built it: every clause is now shown by a test, the first two whole
  in one plant; below.)*

  **Put to the maintainer** (M5-16) *(answered on 2026-10-26: accepted as is, the one plant
  M5-16's review built showing the first clause; Milestone 5 is closed, decision 265)*:
  1. *Milestone 5's first clause, shown piecewise.* The done sentence asks for one plant,
     §4.4's conveyor with its fan, oven card and box counter, loaded from files on disk,
     that declares and runs every type and a typed counter through the runner against an
     oracle that knows nothing of logex. The suite shows each type in the plant that
     needs it, the drive's speed a `uint`, its status a `word`, the fan's speed a `real`,
     and the eight integer widths and four bit strings as a card of points on the runner;
     `sint`, `lint`, `usint`, `udint`, `ulint`, `byte`, `dword` and `lword` are never in a
     plant, and the typed counter runs through the runner only in a seeded walk checked
     against `cycle/3`. An operator sees nothing either way: the question is whether the
     milestone is done. (a) Done as is, each clause met by the item that built it, as the
     maintainer accepted M4's timing clauses; (b) one more end-to-end test before it is
     called done: §4.4's plant from files on disk with a program declaring all fifteen
     elementary types, a `ctud_int` box counter, the fan's `real`, the oven's located
     `real[8]` and `weights[slot]`, through `Logex.Runner` on the manual clock against an
     oracle, its cost about one test of the size of M5-13's; (c) the sentence amended to
     what the suite shows. Recommended: (b), the reading closest to the sentence. IEC and
     Logix say nothing of how a milestone is shown.

  **Review of M5-16, and its fixes** (2026-10-26, on `b7a6109`). The review re-ran every
  README example (29 the same byte for byte, the real clock's figures that run's), compiled
  each quoted message again, checked the facts and citations the entry names against the
  code and the extracts, and found no defect in `lib/` or `test/`. Its six findings, and
  what each became:
  1. *The proposed done sentence overclaimed* "declared everywhere a dint is, from files on
     disk and through `Logex.Runner`": eight of the fifteen types reached the runner only as
     a card of points built from source text. Fixed by finding 2's test, and the sentence
     proposed below says what the tests show and no more.
  2. *Question 1's gap is real*; the review agreed with (b). Built: `end_to_end_test.exs`,
     "Milestone 5's done sentence in one plant", §4.4's plant from files on disk with four
     programs beside its own, `bench.ld`, which declares every elementary type, each a
     `var_input` from a point of its own type on a `bench` device and a `var_output` to one,
     an integer through `add i 1 o ote ok` wrapping with no power at its top, a bit string
     through `not`, a bool through `xio`, a `real` and an `lreal` through `mul … 2.0`
     saturating at their largest values; M5-10's fan, its speed a `real` from the drive;
     M5-13's oven, its zones the located `real[8]`; and `boxes.ld`, a `ctud_int` box counter
     on the photo-eye and the outfeed, loaded to 32767 and stopping there with `ov`, each
     box's weight kept in `weights[slot]`. Over 300 seeded rounds through `Logex.Runner` on
     the manual clock, against an oracle that knows nothing of logex: each width's wrap by
     its range, each bit string's `not` by its width, a single through the BEAM's 32-bit
     encoding, −0.0 and a subnormal 0.0, saturation by sign, IEC's CTUD restated over an
     int and eight weights in a list; its reach asserted, a wrap, a load and `ov`. Then
     `slot` at 8 trips the plant at the fast task's step, `{:fault, "fast", "boxes",
     %Logex.Fault{kind: :index_out_of_range, read: {8}, …}}` at `boxes.ld` line 21, every
     output of the four devices written 0 once, and nothing after. Four mutants of `lib/`,
     each judged by this test alone, all red (`scratchpad/m5/rv16b/mut`): an integer
     result wrapped to 0, a negative real saturating to the positive largest value, a
     −0.0 kept, and an integer result of 255 inside its type passing no power. It changes no code, so the
     cost of every program is as at `b7a6109`.
  3. *Eight questions are still open* and the record said "landed whole" and "none awaits
     code". Gathered below, each where it stands; `docs/organisation.md`'s head of the
     decisions, README's status and CLAUDE.md's now say that Milestone 5's items have
     landed with these readings provisional, each built as the record's closest reading,
     so that only an answer other than the one built awaits code. M5-15's review's
     question 3 is noted against the done sentence's "every output 0 once", above and in
     the sentence proposed.
  4. *More code documentation was stale.* `Logex.Tag`'s moduledoc and `@type t` now give
     every elementary type, the bit strings and reals among them, an array of instances
     and a real's zero, 0.0; `new!/4`'s doc a tag's start at its type's zero; and
     `Logex.Edit`'s moduledoc the initial values reported for every elementary type and an
     array element by element. Documentation and a typespec only: the compiled code is
     unchanged.
  5. *Three IEC pages.* Decision 151's Table 11 feature 4 corrected in place to p.35;
     `docs/naming.md`, append-only, amended at the real conversions' stanza (Table 22
     footnote b, p.79) and at `and` (Table 31's "overloaded on all bit-string types",
     p.88), each read again in the extract of Ed 3:2013.
  6. *Wording.* This plan's status says §4.12 and §5 annotated and the head of the
     decisions, not every decision; CLAUDE.md credits a `var_external` array's sizes to
     M5-11, beside decision 159's widths; and README says an array of instances has its
     members read and written through any subscript, `move 70 t[i].pre` writing
     `t[1].pre`.

  2204 tests (11 doctests), up from 2203.

  **The questions still open on Milestone 5**, gathered (M5-16's review) *(every one answered
  on 2026-10-26, decisions 257 to 265, below)*: every one asks
  of a reading built as provisional, so Milestone 5 runs as each says until answered.
  - M5-14's answers, provisional readings 7 to 9: a bit of a member of an element coiled
    twice, two lanes' members through two tags, and a member retyped in an array of blocks
    inside an array of blocks (§3, M5-14, "Provisional readings");
  - M5-15's questions 1 and 2: what a truncation into a real is told, and whether a
    changed initial value is reported as declared or as held (§3, M5-15);
  - M5-15's review's questions 3 to 5: a trip's 0 that a device does not take, which bears
    on the done sentence's "every output 0 once"; decision 250's words for a comparison;
    and whether CLAUDE.md's clauses-not-conditionals rule reaches test code (§3, M5-15's
    review);
  - M5-16's question 1, which the review answered for itself by building (b): whether the
    maintainer takes the one plant as the first clause shown.

  **The done sentence, as the tests show it** (proposed, after M5-16's review; *accepted as
  is by the maintainer on 2026-10-26, decision 265, its every output's 0 tried again at
  each poll since decision 262*): §4.4's
  plant, loaded from files on disk, declares in a program and its configuration every one
  of the fifteen elementary types, each read from a point of its own type and written to
  one, with the fan's speed a `real` from the drive card, its eight zone temperatures a
  located `real[8]`, a `ctud_int` box counter and its weights in `weights[slot]`, and runs
  them through `Logex.Runner` on the manual clock against an oracle that knows nothing of
  logex; an integer result past its width wraps with no power, a real's saturates, and no
  infinity, NaN or −0.0 reaches a state; every mixed-type operand Figure 11 does not widen
  is refused naming its conversion, and every conversion rounds as IEC's examples say; an
  index or a bit number out of range trips the runner with every output written 0 once,
  through each device that takes the write (M5-15's review's question 3), and a negative
  square root is the minor fault `:negative_sqrt`; an online edit of a type or a size is
  refused, and a changed initial value of every type is reported; and the contract walks
  reach every type, refusal and trip reason but `{:internal, message}`, which only the
  hidden seam reaches, repeating exactly.

  **The maintainer's answers to the questions still open** (2026-10-26, decisions 257 to
  265, `docs/organisation.md` §7), landed the same day as one gated commit of code, tests
  and the record and one of documents. **Milestone 5 is closed**: its done sentence is
  accepted as proposed after M5-16's review (decision 265). Three answers confirm what was
  built: two lanes' members through two tags warned (decision 258), and a changed real
  initial value reported as declared, `{0.0, 1.0e-30}` (decision 261), each now pinned by a
  test of its own where none was; and the done sentence. Six change it:
  - *A bit of a member of an element* (257): `ote lane_c[1].pv.3` twice, and a coil on it
    beside `move 5 lane_c[1].pv`, are the second-`ote` warning, as on `c.pv.3`; through a
    tag subscript, `lane_c[i].pv.3`, in decisions 253's and 256's words, "already has an
    `ote`" through the very tags and "may write" through others; and a bit a tag numbers of
    a literal element's member, `lane_c[1].pv.[i]`, keyed by the member as M5-9 keys
    `c.pv.[n]`. Not compared (provisional): a member's whole write beside a coil on its
    bit where a tag subscript stands on either side.
  - *A member retyped in nested arrays of blocks* (259): one path, `[*]` for each array,
    "`hs[*].ws[*].x` is a bool in the running program and a dint in the candidate, in every
    element: a member's type changes only with a restart", and so at one level, "`ws[*].x`
    …", superseding decision 254's "`x` of every element of `ws`", so that the messages
    keep one form.
  - *A truncation into a real* (260): "`real_trunc_int` writes an int, but `shown` is a
    real (declared on line 3): a truncation writes an integer, so declare `shown` an int, or
    use `move` to keep the real", the conversion that rounds, `lreal_to_real`, where the
    truncation's real does not widen into the destination's.
  - *A trip's 0 that a device does not take* (262): while tripped, a device whose adapter
    did not take its 0 is written its 0 again at each poll, and nothing else, until one is
    taken; `status/1`'s `unzeroed`, a list of device names in device-name order, names it
    until then, and a device down at the trip until a restart; the first reason kept, a
    restart releasing and writing as before, one refused naming again each device whose 0
    it did not take. The runner walk's model restates it, `status/1`'s `unzeroed` checked
    after every step, a refused restart now and then given a device whose 0 fails, its two
    reach atoms, `:unzeroed_named` and `:zero_retried`, among the walk's.
  - *Decision 250's words* (263): every comparison slot says "it would be read as 0.0",
    beside a literal and beside a tag; every other slot keeps "it would be written as 0.0".
  - *Clauses in tests* (264): every function and test of the walks and the end-to-end tests
    but the draws is clauses, 320 of their 443 conditionals rewritten as function clauses,
    the 123 left all in draws, each
    walk's module naming its draws in `@draws`, `end_to_end_test.exs` holding none, and
    `clauses_test.exs` reading both files' syntax trees to pin it (a conditional in a
    string or a comment is none, one inline is one). The walks run on their seeds as before:
    every walk green, its reach the same, and no assertion fewer (the count of `assert`,
    `refute` and `flunk` in each test file the same or more).

  *Mutation table* (`scratchpad/m5/close/mut/run.log`), each mutant judged by the full
  suite's exit code on a copy of the tip: 38 mutants, 37 red.
  W1–W7 (decision 257's compare of a member's bit, literal and through a tag subscript,
  in `Logex.Warnings`) each red on `instance_array_test.exs`'s table; P1–P3 (decision
  259's `[*]` path) red on the retyped refusals; C1–C3 (decision 260's truncation into a
  real) red on `real_test.exs` and the cross-type walk's Figure 11 oracle; D1–D4 (decision
  263's "read as") red on the real literal tests; R1–R8 (decision 262's retry and
  `unzeroed`, in `Logex.Runner` and its device) each red on `trip_test.exs` and the
  RunnerWalk's model; O1–O9, O11 and O12 (an oracle's clause changed, decision 264) each
  red on its walk or its end-to-end test, so each rewritten oracle still decides. O10,
  `or true` on an event task's runs, survived: a weakening of an oracle cannot fail against
  a correct logex, so it measures nothing, and O10b, the same clause told the opposite
  edge, is red on the configuration walk. P3's first run was also red on one trip test
  under the load of the run, which passed on its re-run alone

  *Cost*, against `453ef7b` (`scratchpad/m5/close/cost.exs`, three runs each): every program
  of the cost script compiles and scans in the reductions it took, within 2, but the one
  that holds what decision 257 compares, 50 rungs that coil and latch a bit of a member of
  an element, which compiles in 190,230 reductions where it took 169,649 (12.1%), its
  scans the same; a truncation's compile, an accept and the lexer's five scripts as before.

  2212 tests (11 doctests), up from 2204.

  *Provisional readings* (the answers'), each a question for the maintainer:
  1. *A stop while a device's 0 has not been taken.* The runner tripped, the drive card's 0
     failed, and the host stops the runner before the card's next poll. As built the close
     writes nothing more, as before decision 262, so the card keeps its last outputs. The
     options: (a) as built; (b) the close tries the 0 once more, as the poll would have.
     Logix leaves the safe state to the module's own fault behaviour (1756-UM900B p.242).
  2. *A device down at the trip.* A drive killed or gone down when the runner trips is named
     in `status/1`'s `unzeroed` until a restart, its outputs not known to be 0; one whose 0
     was taken and that goes down later is not named. The options: (a) as built; (b) a
     device that goes down while tripped named too, though its 0 was taken.
  3. *A member's whole write beside a bit of it through a tag subscript.* `move 5
     lane_c[1].pv` beside `ote lane_c[i].pv.3`, either first, is warned of nothing, where
     `move x c.pv` beside `ote c.pv.3` is the second-`ote` warning. The options: (a) as
     built; (b) warned, "`lane_c[i].pv.3` is in `lane_c`, as `lane_c[1].pv` is, which the
     `move` on line 12 writes whole".
  4. *A comparison beside a tag* (decision 263's reading). `eq l 1.0e-310`, `l` an lreal,
     is told "… which never holds it: … it would be read as 0.0", the comparison's own
     slot, where the question asked of two literals. The options: (a) as built; (b) "written
     as 0.0" beside a tag, the literal held in the tag's type.

  *Owed by the maintainer*, outside this session's reach: `nix flake update` and its commit,
  `flake.lock` being the 2024-01-19 lock (§4, the toolchain item); and the old backup
  branches, `backup/m2-2` to `backup/tidy`, 32 of them, `backup/m5` among them, to delete
  once Milestone 5's commits are on `main`.

**What stays deferred**, each a later item or milestone (§4.12): the TIME and LTIME types,
the dates and `T#` literals; strings and characters; enumerations, named values and
subranges; structures, UDTs and directly derived types; typed literals, `int#5`, and
octal; references; IEC's array bounds, `ARRAY[*]`, more than three dimensions and
whole-array `copy` and `fill`; IEC's byte and word partial access, `w.%B1`; online
widening; `round`, `ceil` and `floor`; the BOOL, BCD and real-to-bit-pattern conversions;
and nanoseconds in the core's clock. Not adopted: pointers, unions, target-width integers
and Logix's literal suffixes.

**Milestone 5 is done when** a program and a configuration of §4.4's plant, loaded from
files on disk, declare and run every type decision 144 and 155 name, the fan's speed a
`real` from the drive card and its eight zone temperatures a located `real[8]`, the box
counter a typed counter and its weights an array indexed by a tag, through `Logex.Runner`
on the manual clock against an oracle that knows nothing of logex; an integer result past
its width wraps with no power, a real's saturates, and no infinity, NaN or −0.0 ever
reaches a state; every mixed-type operand Figure 11 does not widen is refused naming its
conversion, and every conversion rounds as IEC's examples say; an index or a bit number
out of range trips the runner with every output 0 once, and a negative square root is a
minor fault, `:negative_sqrt`; an online edit of a type or a
size is refused, and a changed initial value of every type is reported; and the contract
walks reach every type, refusal and trip reason, repeating exactly.

---

## 4. Backlog

- **B1 · Punctuation branch delimiters. LANDED.** The three lexer rules are
  `BST = (\()`, `NXB = (\|)`, `BND = (\))`, the grammar is untouched, and the migration
  diagnostic shipped with them. What follows is the finding as written, in the past tense
  where it describes what was fixed.

  A missing space before `nxb` silently turned OR into
  AND. `bst`/`nxb`/`bnd` were bare alphanumeric words (`ladder_lexer.xrl:7-9`) drawn from
  the same character set as `NAME`, and leex's maximal munch swallows them into an
  adjacent identifier. `nxb` is the only structural token that does not affect
  `bst`/`bnd` balance, so removing it always leaves a *grammatically legal* rung:

  ```
  bst xic aa nxb xic bb   bnd ote dd   aa=0,bb=1  ->  dd=1      (correct: OR)
  bst xic aa     nxb→"aanxb"…          aa=0,bb=1  ->  dd=0      (silently: AND)

  bst mov src dst  nxb xic bb bnd ote ee  ->  %{"dst" => 9}
  bst mov src dstnxb   xic bb bnd ote ee  ->  %{"dstnxb" => 9, "dst" => 0}
  ```

  Not fixable in the lexer — `aanxb` is a legitimate identifier. Fix at the language
  surface. **§5 settled the characters as `(` `|` `)`, not `[` `,` `]`** — see there for
  why. The leex rules are, with every metacharacter escaped (verified: compiles clean, and
  `xic aa ( xic bb | xic cc ) ote dd` with `aa=1,cc=1` gives `dd=1`):

  ```
  BST = (\()
  NXB = (\|)
  BND = (\))
  ```

  Do not transcribe these unescaped — `BST = (()` is `bad regexp 'unterminated ('`, which
  at least fails loudly; a half-escaped variant is the dangerous one. Nothing in the grammar
  changes: the yecc terminals are already the atoms `bst nxb bnd`.
  Whichever characters are used, every deletion around a punctuation delimiter becomes a
  no-op or a loud error, which is the point. M0-4 was the prerequisite and has landed;
  before it, `a-zA-z` in `NAME` swallowed `]` into identifiers.

  **Settled by §5, and taken: `(` `|` `)` rather than `[` `,` `]`.** It was a
  source-language break, not a contained lexer tweak.
  `bst`/`nxb`/`bnd` stopped being keywords and became ordinary tag names, so every branching
  program was rewritten: `lex_and_parse_test.exs:6`, every branching source in
  `end_to_end_test.exs` (including the three unbalanced-token cases, which still stay parse
  errors), README's syntax list, instruction table and worked example, and the branching
  examples in this document. The migration is *silent*, not loud — an old `bst …` program is
  no longer a syntax error; it would reach `instructionize/1` and die as
  `MatchError: no match of right hand side value: nil` with no mnemonic and no line, the
  exact failure M1-2 exists to remove — so it shipped *with* that diagnostic, a guard clause
  on the name head saying "line N: `bst` is no longer a keyword — branches are written
  `( … | … )`". Only mnemonic position is claimed: `bst` is a perfectly good tag name now,
  which `printer_test.exs` pins.

  Two consequences recorded elsewhere in this document: M0-4's keyword-precedence check is
  moot (§2·M0-4), and §5's case-folding is unblocked (§5).

  **Why not `[ , ]`.** Borrowing neutral text's brackets without its parentheses forecloses
  array subscripts: with `[`/`]` freed from `NAME` by M0-4 they would belong to branch
  structure alone, making the `[3]` addressing wanted in §5 and §8·6 unlexable (verified
  with the bracket delimiters applied: `tokenize("xic aa[3]")` → `name, name, bst,
  int_lit, bnd`). Real neutral text avoids the clash only because operands are
  parenthesised — `XIC(aa[3])`. `( … | … )` leaves `[`, `]`, `,` and `.` unspent, and reads
  as "a AND (b OR c)" to anyone who has seen a regex. Note also that `BST`/`NXB`/`BND` are
  **not** neutral-text spellings — they occur zero times in the instruction-set reference or
  the import/export reference. They *are* vendor mnemonics, from the same vendor's **earlier**
  controller family, whose ASCII rung format spells a branch `SOR BST … NXB … BND … EOR`.
  The destination this bullet argued for was right; its stated origin was the wrong
  generation, not the wrong vendor.

- **B2 · Digit-led lexemes split instead of erroring. FIXED** in the hand-written lexer:
  `tokenize("mov 1bst aa")` is `{:error, {{1, 5}, Logex.Lexer, {:missing_separator,
  "1bst"}}, 1}`, naming the whole run; `mov 123 hh`, a bare `1`, tags ending in digits and
  `1(` still lex. The leex-rule prescription below is history — the fix is an explicit
  clause after the digits, so the longest-match subtlety it relied on no longer arises.
  Guarded in `frontend_test.exs`; the golden record's regenerated diff (on 1.20.4) was
  exactly the 139 inputs with a digit running into a letter or `_`. The finding as written: a digit-led
  lexeme splits silently
  rather than erroring, then dies much later with an unlocated `FunctionClauseError`:
  `tokenize("mov 1bst aa bnd")` is `int_lit(1)` + `name("bst")` + … , where the user
  plainly meant one tag. *B1 blunted the original framing without closing the finding:* the
  example used to read `int_lit(1)` + **a genuine `bst` token** — a branch-start
  materialising from the middle of a word — which is no longer possible, because the
  delimiters are punctuation. The nearest survivor is `tokenize("1(")` → `int_lit(1), bst`,
  which is a split but arguably the right reading. The finding stands on the silent split
  itself; the fix is unchanged. One leex rule fixes
  it; leex is longest-match, so a digit-led lexeme running on into letters beats the
  digit-only `{INT}` match wherever the rule sits in the file:

  `[0-9]+[a-zA-Z_][a-zA-Z0-9_]* : {error, "missing separator after integer: " ++ TokenChars}.`

  Note leex's `{error, _}` action takes a **string**, not a term: it is wrapped as
  `{user, S}` and the generated `format_error({user, S}) -> S` hands it back verbatim, so
  a tuple there makes `format_error/1` return non-iodata and blows up the very error path
  M1-5 commits to calling. The trailing `[a-zA-Z0-9_]*` matters too — without it only the
  first letter is consumed and the message names `1b` instead of `1bst`. `mov 123 hh`,
  bare `1`, and identifiers ending in digits (`bst1`, `tag1`) are unaffected.

- **B3 · CI. LANDED.** `.github/workflows/ci.yml` runs on every push and pull request,
  on `ubuntu-latest`, with `erlef/setup-beam@v1.24.1` giving Erlang/OTP 28 and Elixir
  1.20.4, the pair `mix.exs` and `shell.nix` pin, `deps` and `_build` cached on the
  versions it resolved and `mix.exs` (there is no `mix.lock`). Four steps, each judged by
  its exit code: `mix format --check-formatted`, `mix compile --force
  --warnings-as-errors`, `MIX_ENV=test mix compile --force --warnings-as-errors` and
  `mix test --warnings-as-errors`; CONTRIBUTING's "Before you commit" lists the same four.
  The red island in history below stays where it is: CI keeps a new one from landing
  unseen. What follows is the item as written.

  *Since the hand-written front end (§6), three lines:
  `mix compile --force --warnings-as-errors`, `mix format --check-formatted`,
  `mix test --warnings-as-errors` (the flag since M1-5's second review: `mix compile` never
  compiles the tests, so a warning in one passed the plain `mix test` for six commits),
  each judged by exit code. The grammar-conflict gate below went with yecc; there is no
  grammar left to check.* As first written, four lines: `mix compile --warnings-as-errors`,
  `mix format --check-formatted`, `mix test`, and a grammar-conflict gate:

  ```
  erl -noshell -eval 'case yecc:file("src/ladder_parser.yrl",
        [{parserfile,"/tmp/conflictcheck.erl"},{report,false},{return,true}]) of
      {ok,_,[]} -> halt(0); _ -> halt(1) end.'
  ```

  The fourth line is not redundant, and this is the one that matters: **`mix compile
  --warnings-as-errors` does not catch a shift/reduce conflict.** yecc emits a working,
  silently disambiguated parser and mix reports it as a warning that
  `--warnings-as-errors` does not upgrade. Verified by adding one ambiguous production
  (`elems -> elems elem` alongside `elems -> elem elems`): yecc reports 6 shift/reduce
  conflicts, and `mix compile --warnings-as-errors`, `mix format --check-formatted` and
  `mix test` **all exit 0**. Only reduce/reduce fails the build. `{parserfile, …}` keeps
  the check from dropping a stray `src/ladder_parser.erl` into the checkout. This gate is
  what makes §6's "keep yecc for its conflict-freedom alarm" argument actually true.

  *Before §6:* all four passed after M1-1 (`27 tests, 0 failures`, and zero conflicts
  against the post-M0-5 grammar), and with `src/` tracking only the `.xrl` and `.yrl`,
  leex/yecc were a hard prerequisite of all four — the image had to carry
  `erlang-parsetools`. *Since:* the three gates pass on 1.20.4, and no parsetools are
  needed (README, "Running it").

  On history: `mix test` fails at `ec0534a` and `35fe1b9` (`list_to_string(list)` was
  written with a lowercase Erlang *atom* instead of the variable `List`, silently repaired
  inside the unrelated `0f7d77f`). Those two are an interior island, not a prefix —
  `d47eb21` before them is green (`1 doctest, 1 test, 0 failures`), so `git bisect` does
  have a clean baseline. Only the two root commits (`b8e8f8a`, `d319fb3`) predate the mix
  project; every commit after them is bisectable.

- **B4 · nix dev shell has bit-rotted.** **Landed `9c1a7bd`**, with the lock refresh still
  owed. `shell.nix` now pins `beam.packages.erlang_28` with `elixir_1_20`, and `flake.nix`
  tracks `nixos-26.05` instead of `master`. The original diagnosis — `erlangR26` deleted
  from nixpkgs on 2024-05-24 — was overtaken before it was acted on: nixpkgs now `throw`s
  on `erlang_26`, `elixir_1_15` and `elixir_1_16` as EOL, so the rename to `erlang_26` this
  item proposed would also have failed. What decided the versions was the 2026-09-07 CVE
  check: OTP 26 left support on 2026-05-26 and every 2026 OTP advisory was fixed only on
  27/28/29; Elixir 1.15 left the last-five-minors window on 2026-06-03 and is
  affected-and-unpatched by CVE-2026-75758. Nothing in logex's own code paths is reachable
  by any of them (no deps; runtime is `kernel`/`stdlib` only), so this is toolchain
  hygiene, not a fix. Still open: `flake.lock` is the 2024-01-19 lock and does not match
  the new input — the first `nix develop` re-locks it; run `nix flake update` and commit.
  Not evaluated in the session that landed it (no `nix` on that machine).

- **B5 · Split `Logex.Compiler` along the pipeline** once M1-2 and M1-5 exist and the module
  is doing five jobs instead of four. The front end is already out, as `Logex.Lexer` and
  `Logex.Parser` (§6); what remains is `Ast`, `Instruction`, `Analyzer` and `Runtime`
  (`Logex.Diagnostic` exists since M1-2; `Logex.Program`, `Logex.Tag` and
  `Logex.Declarations` since M1-3). Note the recursion of `evaluate/2`
  is currently written as extra **public** clauses of the same function (M1-2 made
  `instructionize/1`'s private), so `Logex.Compiler.evaluate([{:xic, …}], {true, env})` on a
  half-formed IR is a supported entry point. Make every recursive clause a `defp` with a
  distinct name.
  *The narrow part landed with M1-5 (`d0870b3`): the evaluator is in `Logex.Runtime`,
  every clause private, the recursion split into `rung/2`, `series/2` and `element/2`, and
  `runtime_test.exs` pins the public surface of `Logex`, `Logex.Runtime` and
  `Logex.Compiler`; M1-5 also added `Logex.Warnings`, `Logex.Instance` and
  `Logex.Scan`. What remains is the lowering (`Ast`, `Instruction`, `Analyzer`), still in
  `Logex.Compiler`. M1-6 made them `rung/3`, `series/3`, `element/3` and `evaluate/3`, and
  added `Logex.FbType`, whose surface the same test pins.* *(Milestone 2's design,
  2026-10-02: the part Milestone 2 needs, one walk of a program's IR in place of the
  compiler's, `Logex.Warnings`' and `Logex.Edit`'s, answering which tags a program writes
  and which timers it runs, knowing `cal` and reaching block bodies, lands as M2-4's first
  commit. Until then M2-5 adds a `cal` clause to each walk; §3.)* *(M2-5 landed so: its
  second commit gave the two walks one lookup of an instruction's slots,
  `Logex.Compiler.signature/2`, and its third taught that lookup `cal`, whose slots are
  its block's.)* *(M2-4 landed the walk, `Logex.Walk`, its second commit, `2a03b52`: the
  compiler, `Logex.Warnings` and `Logex.Edit` read it, and `Logex.Configuration` reads
  which tags a program type writes there. The lowering, `Ast`, `Instruction` and
  `Analyzer`, is still in `Logex.Compiler`.)*

- **B6 · Project metadata. LANDED.** `mix.exs` has a `description`, a `package`
  (`licenses: ["Apache-2.0"]`, a link to the GitHub repository) and a `source_url`, which
  `mix hex.build` reads back with no warning; `extra_applications: [:logger]` is gone, as
  nothing in `lib/` or `test/` uses Logger; `Logex.Compiler` has a `@moduledoc` naming its
  stages and why each is public (no `@spec`s: the docs state each function's shapes). The
  Elixir requirement, `~> 1.20`, is unchanged. `mix test --cover` reports 99.24% on 1.20.4,
  `Logex.Compiler` 98.42%, every module 100% but `Logex.FbType` (97.30%), `Logex.Walk`
  (97.56%), `Logex.Compiler`, `Logex.Configuration` (99.09%), `Logex.Declarations`
  (99.13%), `Logex` (99.18%), `Logex.Runtime` (99.51%) and `Logex.Edit.Plan` (99.67%).
  The CI it once listed is B3's. What follows is the finding as written.

  No `@spec`/`@moduledoc` on `Logex.Compiler`; no
  `description`/`package`/`licenses` in `mix.exs` despite a full Apache-2.0 `LICENSE`;
  unused `extra_applications: [:logger]`. `mix test --cover` reported a meaningless ~54%
  while it counted the generated scanners (`Logex.Compiler` 90%, `:ladder_lexer` 30%).
  With the front end hand-written (§6, `65d9bc4`) it reported 97.92% on 1.20.4
  (`Logex.Compiler` 94.59%); after M1-5's first review (`b8a9bd8`) it reported 99.17%,
  every module 100% but `Logex.Diagnostic` (90.00%) and `Logex.Declarations` (97.69%).

- **B7 · Style.** Five `{false, env}` clauses with identical *bodies*
  (`xic`, `xio`, `otl`, `otu`, `move` — the heads differ) collapse to one guard clause
  `when op in [:xic, :xio, :otl, :otu, :move]`; `ote`'s own `{false, env}` clause
  writes 0, so it stays. The guard keeps it from shadowing `{:routine, …}`, `{:rung, …}`
  or `{:branches, …}`, so it is safe anywhere in the clause list. It does **not** remove
  the new-instruction trap, it *moves* it. M0-3 landed the mandatory-`{false, env}` warning
  in CLAUDE.md's "New instructions, step 2" bullet, which
  already closes it: an opcode added per the current recipe — both clauses — evaluates a
  de-energised rung fine, while one added with only the `{true, env}` clause still raises
  `FunctionClauseError`, because the new atom was never added to the whitelist. So if B7 is
  taken, the only doc change left is an addendum to that bullet: "or add the opcode to the
  `{false, env}` guard list instead, when de-energising does nothing". Do not widen the guard to a bare
  catch-all. Since M1-2 an instruction is `{op, line, operands}`, so `{_op, _, _}` can no
  longer swallow `{:branches, …}`, and validation rejects the truncated instructions it
  used to let through; but it would still turn a forgotten de-energised clause, loud
  today, into a silent do-nothing — wrong for any coil that must write on a false rung,
  as `ote` does.
  `Enum.any?(outputs, fn o -> o == true end)` →
  accumulate the boolean directly and drop the reversed intermediate list in the
  `{:branches, _}` reducer — but keep the fold
  non-short-circuiting: any form that puts `evaluate` on the right of `or`/`||`, or that
  bails once the accumulator is true, skips a later branch's OTE/MOV side effects and
  still passes every CI gate. §6 explains why that matters. The `{:rung, branch}`
  clause `{:rung, branch}` names the `{power_flow, env}` pair `env`.
  *B5 (`d0870b3`, 2026-09-29) took part of this with it: the `== true` is gone
  (`Enum.any?(powers)`), `Enum.map_reduce` keeps the legs in order with no reversed list,
  `rung/2` names the env map `env`, and `evaluate/2` has no routine, rung or branches clause
  left for a guard to shadow. The five identical `{false, env}` bodies stand, and so does
  the intermediate `powers` list in `element({:branches, _}, _)`. M1-6 made these
  `evaluate/3` and `element/3`, and the six comparisons share one guarded clause pair.*

- **B8 · A lone `\r` never delimits a rung, so a CR-only file is silently one rung.**
  **Status: DONE — landed 2026-09-30, as the fix below says.** A CRLF is still one
  newline located at its `\n`, a lone `\r` is a newline of its own, and `\r\r\n` is two
  newlines in one run. The golden record changed in exactly the 165 entries predicted,
  each an input with a lone CR; `frontend_test.exs` and `end_to_end_test.exs` now pin it
  too, so the golden test is no longer the only one to see it.
  *Written against leex; `Logex.Lexer` kept the behaviour on purpose (its whitespace
  clause takes `?\r`), so the finding stands and only the fix below changes form.*
  `WHITESPACE = [\s\t\r]` (`ladder_lexer.xrl:6`) claims `\r` before `RND = (\r?\n)`
  can, so a classic-Mac line ending is skipped as whitespace rather than ending the
  rung. The same text then means different things in CR and LF:

  ```
  tokenize("ote aa\rote bb")  -> [name, name, name, name]        # no :rnd at all
  tokenize("ote aa\note bb")  -> [name, name, rnd, name, name]

  "xic gg ote r1\rote r2"  gg=0  ->  r2=0     # one rung: flow is false throughout
  "xic gg ote r1\note r2"  gg=0  ->  r2=1     # two rungs: second is independent
  ```

  Silent and wrong, not loud — every other malformed file shape (BOM, `\f`, `\v`,
  U+2028) is an `{:illegal, …}` error. **Fix:** in `Logex.Lexer`, take `?\r` out of the
  whitespace clause and treat `\r\n` and a lone `\r` as a newline. The line counter is
  the lexer's own, so a CR-only file gets real line numbers — the caveat the leex fix
  carried (leex counted only `\n`) no longer applies. The golden record will change: on
  1.20.4, 165 of its 1,362 entries, every one an input with a lone CR (256 have one). Made
  as a mutation, with a CRLF newline still located at its `\n`, the change fails the
  golden test and nothing else; locating it at the `\r` also moves an error location
  `frontend_test.exs` pins. Predates M0; M0-5's `\r?` in `RND` makes it *look* handled,
  which is why it is worth recording.

- **B9 · An Elixir-embedded `defladder` DSL — proposed, not adopted.** `docs/defladder.md`
  is the study: what Nx's `defn` actually does (call-time tracing, which a static ladder
  routine has no use for), an executed spike (a 71-line macro producing this parser's AST,
  byte-identical scan output, located compile errors), a judged design panel and two
  adversarial refutations. Its recommendation: one macro that emits the parse-stage AST and
  owns no vocabulary — mnemonics from `instructions/0`, tags via `tokenize/1` — with a
  parallel group spelled `branch(leg, leg)` rather than an infix operator, because `|||`
  and `|` both bind looser than `|>` and an unparenthesised seal-in silently becomes
  OR-of-AND (B1's defect class on a surface no gate sees). Preconditions if adopted: M1-2
  (one validator) and M1-5 (a `%Program{}` and a runtime for `name/1` to sit on; both
  met, M1-5 on 2026-09-29), and a
  re-run of the whole study on Elixir 1.20, the floor in `mix.exs` — every receipt is from the 1.14
  sandbox. The report's §15 lists the decisions this item is waiting on, and they are still
  open. One seam came forward on its own: M1-3, decided 2026-09-28, provides the
  Elixir-side declarer (`instructionize(ast, declared)` and `Logex.Tag.new!/4`) that §11's
  M1-3 row asks for; §15's decision 3 (head declarations in the DSL's output) stays B9's.
  Nothing else in §3 or §5 changes until they are made. No codegen backend: the second backend the spike built
  disagreed with `evaluate/2` on 5,708 of 20,000 seeded envs and on 0 text-reachable ones.
  *(Re-scoped 2026-10-01, `docs/organisation.md` §4.9: a running controller is edited as
  data, so a DSL can only write a first version. Its output must be a whole program,
  name, declarations and rungs, as text that `Logex.compile/2` accepts or as data that
  the data API accepts (`docs/organisation.md` §4.9), which settles §15's decision 3; and nothing writes a later edit back into the `.ex` file.
  Spark was considered for the same role and is not adopted inside logex: as a separate
  authoring package it works (a probe produced a `%Logex.Program{}` equal to the text
  path's), but its rungs are wordy, its autocomplete is ElixirLS-only, and it is a
  dependency.)*

- **B10 · `Logex.Warnings.second_otes/3` orders by a map. LANDED.** It walks the `ote`
  uses in rung order, keeping each tag's first `ote` in a map that is only looked up, as
  M1-6's storage-bit pass walks its uses; "second ote warnings on one line come in rung
  order, however many there are" in `validation_test.exs` pins it with 40 tags given their
  second `ote` on one line in the reverse of their names' order, and fails with the
  grouping put back. What follows is the finding as written.

  It grouped the `ote` uses with
  `Enum.group_by/3` and walked the groups, so two second-`ote` warnings on one line came
  out in the map's order: the names' order for 32 names or fewer, no order past that
  (CONTRIBUTING's "32 keys or fewer"), and never rung order. The final sort by line keeps
  lines in order, not the warnings within one. M1-6's own passes walk the uses in rung
  order, and a test with 40 storage bits on one line pins that; do the same here, with a
  test past 32 names. Found by the M1-6 design panel; not M1-6's to change. *(M1-6 gave
  the function a third argument, the `ons` storage bits it leaves to their own warning.)*

---

## 5. Settled decisions

*Several decisions below are written as leex rules (`//` comments, `QUALIFIED` names,
negative literals, line continuations). The lexer is hand-written now (§6); each rule
becomes a clause in `Logex.Lexer`, and the behaviour it specifies still stands.*

**How does Elixir declare a controller, and how is a running one changed?**

**Decided 2026-10-01: as data, staged, and never through the Elixir compiler** (design,
measurements and sources in `docs/organisation.md` §4.9; its decisions 15–20, and 21–29
for OE-1's design; work items OE-1 and OE-2 in §3).
- One model, held as data: `%Logex.Program{}` and, from M2-1, `%Logex.Configuration{}`.
  Their saved form is `.ld` and `.logex` text, which printers write, and a data API refuses
  what the text cannot say.
- Nothing compiles a user's program to BEAM, and no front end puts the Elixir compiler on
  the path that changes a running program (§6).
- Spark is not adopted inside logex. An authoring package outside it may come later, as a
  one-way seed that emits the same data (B9).
- Online edit is staged from its first version, as the conventional family's is: accept,
  test, untest, assemble, cancel (landed for one program instance with OE-1, 2026-10-01). State moves by name: an added tag starts at its initial
  value, a removed one is pruned at assemble, a type change is refused while running, a
  timer's `.pre` follows its preset where logic left it alone, and an `ons` the edit adds,
  or whose rung it changes, does not fire on the first scan after the switch.
- While running, a task's interval and priority may change; moving an instance to another
  task, and adding or removing a task, are refused.
- An output an edit leaves undriven holds its last value, as the conventional family's
  do, and every step's report lists each one with the value it holds.

**Does logex aim to ingest a vendor export format, or to be its own dialect?**

**Decided: its own dialect.** logex does not aim to import neutral text and will not
become an importer. Its surface is lowercase, space-separated, unparenthesised and
newline-delimited, which real neutral text is not. The *vocabulary* is borrowed from the
a conventional ladder mnemonic set; the *syntax* is not.

Being a dialect is a licence to choose names, not to choose them carelessly. **Every new
instruction is surveyed before it is written** — against IEC 61131-3 and against the major
vendor toolchains — and named deliberately in that light. The survey lives
in `docs/naming.md`, one stanza per mnemonic, and `test/logex/naming_test.exs` fails if a
mnemonic reaches `@instructions` without one. The rule, in order: **(1)** if IEC names the
operation, take the IEC name lowercased; **(2)** if IEC supplies only a graphical element,
take the clearest vendor mnemonic and say which; **(3)** never invent a readable word for
a thing that already has a standard name.

Two survey findings are why the rule has two tiers, and both are load-bearing. IEC
61131-3 names ladder contacts and coils only as **graphical elements with English
phrases** ("Normally open contact", "SET (latch) coil"), so for `xic`/`ote` there is no
standard name to conform to. And **Edition 4.0 (2025) removed Instruction List from the
standard entirely** — there is no longer any IEC textual mnemonic vocabulary at all. A
mnemonic ladder language is *necessarily* a dialect.

### What the decision settles

Each of these was blocked on the dialect question. Full rationale and sources in
`docs/naming.md`.

- **§4·B1 branch delimiters — take B1, as `( … | … )`.** Unblocked: the objection was that
  punctuation was a half-step into a vendor export format foreclosing `[3]` addressing. The
  bracket form is unavailable to logex — it works only because there the operands are
  parenthesised, so a subscript `[` is always inside parens. `( | )` reads as
  "a AND (b OR c)" to anyone who has seen a regex, and leaves `[`, `]`, `,` and `.`
  unspent. Three lexer rules, **zero grammar edits** — the token atoms are still
  `bst nxb bnd`, now produced by `(`, `|` and `)`. **LANDED**, with the migration
  diagnostic, per §4·B1.
  *(Correction to B1's wording when it lands: `BST`/`NXB`/`BND` are **not** vendor
  neutral-text spellings — but they are vendor mnemonics, from the earlier controller
  family's ASCII rung format. The "no vendor reference surveyed" phrasing this note once
  carried was a negative scoped to one generation and worded as though it covered the vendor;
  see the survey-scope note in `docs/naming.md`. Landing B1 therefore trades a real vendor
  spelling for a coined one — still the right call on the fusion hazard, but say so in the
  migration hint rather than implying the words were logex's own.)*
- **M1-4 nonzero-is-true — keep as a totality guarantee, reject as a language rule.** Land
  `bit/2` so `xic`/`xio` are complementary by construction, then once M1-3's tag table
  exists make a non-BOOL operand a located diagnostic rather than a coercion (that half
  **landed with M1-3**; `bit/2` **landed with M1-4**). The survey
  is unanimous against nonzero-is-true, with no vendor precedent: even Mitsubishi's
  untyped devices require a *bit* (`D.b`), not a word. The escape hatch every vendor gives
  is bit addressing — `xic setpoint.3`.
- **Structured addressing — adopt `.`, resolved in the lexer.** One rule,
  `QUALIFIED = {NAME}(\.({NAME}|{INT}))*`, so `t1.dn` and `word.3` lex as one `name`
  token; **no grammar edit**. `env` holds a per-instance record, since `.acc` and `.dn`
  must update together in one scan. Array subscripts defer cleanly, because `[`/`]` stayed
  free. Two traps: the token no longer round-trips to a flat `env` key, and `.` in the
  lexer is safe only while there are no float literals. **The lexer rule landed
  2026-09-30**, as a `Logex.Lexer` clause: `a.1b` is B2's mistyped lexeme, named whole, and
  a `.` with no name or integer after it is illegal. Since a tag name is whatever lexes as
  one name, the same commit forbids a `.` in a declared tag's name. **Members landed with
  M1-6:** `t1.dn` is a member of the timer `t1`, resolved in the compiler and lowered to
  `{:member, line, path}`; a dotted name that is not a declared member is a diagnostic;
  `word.3`, bit access, is refused with its own message until it lands. **Bit access
  landed with M5-8** (2026-10-23): `status.3` is a bit of an integer or a bit string,
  lowered to `{:bit, line, path, n, mask}`; a bit of a `bool` is refused, and a bit
  number held in a tag waits for M5-9. **A bit number held in a tag landed with M5-9**
  (2026-10-23): `status.[n]`, one name token, lowered to `{:bit_at, line, path, tag,
  {width, top}, name}`. *(M5-16, 2026-10-26: the bit's IR has carried its name as written
  since M5-8's review, `{:bit, line, path, n, mask, name}` (decision 209).)* **Array
  subscripts landed with Milestone 5**: literal ones, `temps[3]` and `grid[1,7]`, with
  M5-11 on 2026-10-23, lowered to `{:element, line, array, index, name}`, one name token
  ending at its `]`, a `.` part allowed after it, so still no grammar edit; a subscript
  held in a tag, `weights[slot]`, with M5-12 on 2026-10-24, `{:element_at, ...}`; a bit of
  an element, `faults[2].3`, since decision 221; and a member of an element of instances,
  `lane_t[2].dn`, with M5-14, `{:member, line, element, members}`. And the second trap is
  closed: real literals landed with M5-10, digits, a `.` and digits, and a name never
  begins with a digit, so `t1.dn` and `1.5` never meet.
- **Comments — `//` to end of line.** `//[^\r\n]* : skip_token.` — it must **not**
  consume the newline, or `ote a // note\note b` silently becomes one rung. Test exactly
  that. Keep `;` a lex error: it is the rung *terminator* in neutral text and reusing it
  would mislead. Later, promote a comment above a rung into a structural
  `%Logex.Rung{comment:, elements:}` — a compiler that only skips comments can never print
  `rung 4 ("seal-in for main motor"): unknown instruction`. **Landed 2026-09-30** as a
  `Logex.Lexer` clause that stops before `\n` or `\r`; a comment may hold any character,
  but invalid UTF-8 in one is still a located error, and the printer drops comments (the
  structural form above is still later work).
- **Negative literals — one lexer rule**, `-[0-9]+`, sign glued to the digits, no leading
  `+`. Widen §4·B2's digit-led rule to `-?[0-9]+…` in the same change. logex has no infix
  operators, so `-` can only be a sign; record that this must move to the grammar when
  infix arithmetic arrives. *(OE-1: until this lands, `Logex.Parser.well_formed!/1`
  refuses a negative literal in a tree built as data, and `Logex.Declarations.check/1` a
  negative initial value from Elixir. Landing it widens both, in the same change.)*
  *(Landed with M3-3, 2026-10-14, `docs/organisation.md` decision 97: both widened, with
  `Logex.Configuration`'s checks, whose file can say a negative number now; and a sign
  begins a lexeme, so `a-5` and `5-3` are one mistyped lexeme each, named whole, as
  B2's `1bst` is.)*
- **Case — mnemonics case-insensitive, tags case-sensitive.** **Landed with M1-2.** One
  `String.downcase/1` at `instructionize/1`'s mnemonic lookup. IEC and every vendor are case-*insensitive*, so a user arriving from
  any of them has a correct prior. M1-3 added the rest (**landed**): two declared tags
  differing only in case are an error, and a tag used in the wrong case gets `did you mean
  `motor`? (tags are case-sensitive)`. **Unblocked — B1 has landed.** The blocker was that while `bst`/`nxb`/`bnd` were
  keywords, case-folding made `BST` a name and `bst` a keyword. The delimiters are
  punctuation now, so there is no keyword left to fold.
- **Mnemonics are reserved words, in any case.** Decided with M1-2 (September 2026): no
  tag may be spelled like a mnemonic, so `ote`, `OTE` and `Ote` are never tags. It is
  what closes `mov src ote`, where the operand list ran on into the next instruction and
  wrote a tag called `ote`; an operand-signature table alone cannot tell that tag from
  the instruction. The alternative, leaving every name legal until M1-3's declarations
  catch an undeclared `ote`, left the worst case open for a milestone. The cost, accepted:
  each new instruction reserves its name when it lands, and breaks any program with a
  tag of that name. IEC reserves its keywords case-insensitively too. M1-3 reserved five
  more words the same way, the section and type words `var var_input var_output bool
  dint`, and M1-6 eight, `ons eq ne lt gt le ge ton`, `ton` as a type word too.
- **Program organisation follows IEC's software model, in logex's dialect.** Decided
  2026-09-28: logex is heading for IEC's hierarchy (configuration, tasks, program
  instances, function-block instances, globals), its task-style execution (continuous,
  periodic, event) and I/O mapping in the configuration, not in program bodies.
  `docs/organisation.md` sets out the model, the conventional family's hierarchy mapped
  onto it, the logex form and Milestone 2. Its fourteen open decisions were taken as
  recommended on 2026-09-28, with its Milestone-1 changes (M1-3, M1-5 and M1-6 record
  them) and Milestone 2 (§3). In one line: a file is a POU type, state is an instance, a
  configuration instantiates, wires and schedules; no routines, no controller scope, no
  preemption. Milestone 2 was designed on 2026-10-02 (§3), adding the document's
  decisions 30–40, all taken as recommended but the configuration file's extension,
  `.logex`, the maintainer's own choice. **Routines are deferred by decision** —
  subroutines that share their
  program's scope, called with JSR, have no IEC counterpart, and a program's logic is
  factored with function blocks instead; revisit only if that proves too heavy.
- **`mov` → `move`.** **Landed with M1-2**, with no alias: `mov` is an unknown
  instruction whose diagnostic says *"did you mean `move`?"*. The one existing name the survey changed. The conventional
  toolchain renamed MOV→MOVE in its 2024 conformance sweep *"to conform to IEC
  61131-3 and PLCopen standards"*, and `MOVE` is a genuine IEC standard function; keeping
  `mov` pins logex to a spelling that convention has itself retired.
  A source-language break, so scheduled with M1-2, whose unknown-mnemonic diagnostic can
  carry *"did you mean `move`?"* — cheaper than an alias, and it exercises the validator.

The existing five bit instructions stay. That is the survey's most useful negative result:
there is no better vocabulary to migrate to, so `xic xio ote otl otu` are a closed,
grandfathered borrowing — **not** a precedent that the next instruction should also come
from that same source.

---

## 6. Deliberately not changing

**~~Keep leex/yecc.~~ Reversed, September 2026: the lexer and parser are hand-written**
(`lib/logex/lexer.ex`, `lib/logex/parser.ex`; `src/` is gone). The argument below rested on
yecc's conflict check being wired in as a gate, and two measured studies on the pinned
Elixir 1.20.4 / OTP 28 showed that gate could not be made to hold at a sensible price.
Five front ends were prototyped against the suite (leex+yecc as-is and fixed, hand lexer +
yecc, NimbleParsec, Pegasus, hand-written); then the best yecc option — hand lexer + yecc +
a Mix guard compiler — was hardened over three adversarial rounds. Holding "a conflicted
grammar never builds green" took a 221-line guard coupled to about eight Mix behaviours and
an 87-second test suite, and a final review still built a conflicted parser green: two
`mix compile` runs with different `TMPDIR`s share no build lock, because Mix 1.20.4 keys it
under `System.tmp_dir!()` (`mix/sync/lock.ex:132-134`). NimbleParsec and Pegasus were
6.9-8.3x slower, silent on grammar mistakes, and dependencies. What replaces the alarm:
`test/fixtures/frontend_golden.txt`, a record of what the yecc grammar accepted and produced
on ~1,400 sources, which the hand-written front end matched exactly when it landed (B2 has
since rewritten 139 entries, on purpose); the
printer's round-trip generator, which must reach every production; and the suite — every
meaning-changing overlap planted in the prototype parser failed it. The cost accepted: an
ambiguity no test exercises is now caught by nothing.

Keeping leex beside it as an alternative lexer was considered and declined (September 2026).
Once its lexemes stopped being grown a byte at a time (`2b00370`), the hand-written lexer
took 0.78-1.12x leex's time on the densest artificial inputs and was 2.5x or more faster on
real programs and the README example (on 1.20.4; leex's scanner alone, handed a ready
charlist, still wins on 200k lines of short names).
A second lexer would need every lexer change, which covers B8 and all of §5, made twice,
and a token adapter. It would also bring back parsetools, Mix's leex warning and generated
`src/*.erl`. What it would offer is already held elsewhere: the golden record is its
behaviour, and `bf59167` has its source for anyone benchmarking against it.

The original reasoning follows.

**Keep leex/yecc.** The `rnd = \n` terminal looks like the classic argument for a
hand-written or combinator parser, but the entire fix is one grammar production and one
lexer rule (M0-5), and the grammar's conflict-freedom is the one tool that will say when
the language becomes ambiguous — **provided that check is wired into CI as its own step
(§4·B3).** Nothing in the default `mix compile` pipeline fails on a shift/reduce conflict,
so the check M0-5 runs by hand has to become a gate, or this guarantee lapses the first
time a production is added for comments, negative literals or structured addressing (§5).

Keep every whitespace and newline subtlety inside the lexer (now `Logex.Lexer`) and keep
the grammar newline-naive — that part of the reasoning survives the reversal. Line
continuations, when wanted, are one `Logex.Lexer` clause that skips a `\` followed by
blanks and a newline, and zero grammar changes. *(OE-1: `Logex.Parser.well_formed!/1`
holds every rung of a tree built as data to one line, as the parser gives them today; the
clause widens it in the same change.)*

One known limit to accept alongside this: the grammar declares no `error` productions, so
`parse/1` aborts at the first syntax error — three independent errors yield one
diagnostic. That is *why* M1-5's front-end error is singular while M1-2's validation
returns a list.

**Nothing compiles a user's program to BEAM, and no front end puts the Elixir compiler on
the path that changes a running program** (decided 2026-10-01, `docs/organisation.md`
§4.9). Every front end ends in `%Logex.Program{}` (and from M2-1 `%Logex.Configuration{}`)
data that `Logex.Runtime` interprets. A generated-code backend was rejected once already:
the defladder spike's disagreed with the interpreter on 5,708 of 20,000 seeded envs (B9).
An edit through the Elixir compiler was measured on 2026-10-01 and fails every test that
matters for a running controller: a Spark-defined module recompiled with
`Code.compile_string/2` took 74–95 ms for 4 tags and 0.5–0.7 s for 200, against 22 µs and
1.7 ms for `Logex.compile/2` on the same two programs; it ran arbitrary code written in the edit; an edit that
failed validation unloaded the running module; and where names are atoms, as Spark
entities' usually are, every new name is an atom that is never collected.

**Keep mnemonics out of the grammar.** They arrive as ordinary `name` tokens and resolve
against the `@instructions` module attribute, so adding an instruction touches a map
plus two `evaluate/3` clauses and never the front end. That is the right dividing line.

**Keep the sequential `env` threading through parallel branches** (the
`element({:branches, legs}, _, _)` clause in `Logex.Runtime`, an `Enum.map_reduce` that
runs every leg from the power flowing into the group) and the non-short-circuiting fold
along a rung (`series/3`, an `Enum.reduce` over `element/3`). Both look like accidents of using
`Enum.reduce` and are in fact faithful controller behaviour. *(Until B5, 2026-09-29, these
were the `{:branches, _}` and `is_list(branch)` clauses of `Logex.Compiler.evaluate/2`.)*

---

## 7. Findings register

Every defect the review and the audit after Milestone 0 (`440bc83`) turned up, with the
milestone item or backlog bullet that closes it, and its status as of M1-5 and its two
reviews (2026-09-29). `B1`–`B10` are the §4 backlog bullets; B9 is proposed work, listed for
its status. Other items that are pure forward work rather than defects (M1-3, M1-6, B5)
have no row, and the later reviews of M1-3 and M1-5 are recorded in those items' Status
blocks instead. An ID of `—` means the finding has no plan item yet. Locations are current
as of `1b1b1df` unless a cell says otherwise.

| ID | Sev | Area | Finding | Location | Status |
|---|---|---|---|---|---|
| M0-1 | high | evaluate | `get_arg/2` matches `:lit_int`; every other stage emits `:int_lit` | `get_arg/2` | **closed** `690fc2d` |
| M0-3 | med | docs/build | `CLAUDE.md` promises regeneration that does not happen; a grammar edit is silently ignored on a fresh clone | `CLAUDE.md` compile + Key Files + step-2 bullets | **closed** `dde8c1d` — fresh-clone case; the generated front end's same-second trap went with it (§6), and CONTRIBUTING records the narrow residue left for `.ex` files |
| M0-2 | med | tests | No test crosses a stage seam; per-stage fixtures are hand-typed and contradict each other | `end_to_end_test.exs` | **closed** `03c10e0` |
| M0-5 | med | grammar | `rnd` is a strict infix separator, and a branch leg cannot be empty | `ladder_parser.yrl:8,12,16,21` | **closed** `b65e756` |
| B1 | med | lexer | Missing space before `nxb` fuses into an identifier — parallel silently becomes series | `ladder_lexer.xrl:8` | **closed** — delimiters are `(` `\|` `)`; guarded by "deleting a space around a delimiter is a no-op" in `end_to_end_test.exs` |
| M1-2 | med | lowering | No validation pass: unknown mnemonic → bare `MatchError`; short arity → truncated IR; and `mov src ote` silently eats the next mnemonic as a tag, no error, energised rung | `instructionize/1`, name clause | **closed** `e569113` — a located diagnostic for each case, every mistake in a routine reported (`validation_test.exs`) |
| M1-4 | med | semantics | `xic`/`xio` are independent positive tests — a non-bit or undefined tag reads false for both | the xic and xio clauses of `evaluate/3` (were `evaluate/2`'s) | closed: unreachable from source (`2b093de`, M1-3); complementary by construction (M1-4) |
| B8 | med | lexer | A lone `\r` never delimits a rung, so a CR-only file is silently one rung and disagrees with the same text in LF | `Logex.Lexer`, the whitespace clause (was `ladder_lexer.xrl:6,10`) | **closed** 2026-09-30 — a lone `\r` is a newline |
| M0-4 | low | lexer | `NAME` regex: `+` rejects single-char tags; `a-zA-z` typo admits ``[ \ ] ^ ` `` | `ladder_lexer.xrl:5` | **closed** `3f3b104` |
| — | low | tests | M0-4's fix was unguarded: no test used a single-character tag or a bracketed name, so reverting `ladder_lexer.xrl:5` left `mix test` fully green | `end_to_end_test.exs` | **closed** `b8fc743` |
| M1-5 | low | API | No public entry point and no `Logex` module; no scan loop | — | **closed** (M1-5) — `Logex.compile/2`, `compile_file/1` and `Logex.Runtime`; the host calls each scan, and a scheduler is Milestone 2's |
| M1-5 | low | errors | Three error conventions across four stages; `format_error/1` never called; empty program reports line `999999` | `tokenize/1`, `parse/1` | **closed** — `999999` by `b65e756`; for a host, M1-5: `Logex.compile*` return `%Logex.Diagnostic{}` only, the front end's through its `format_error/1`. The stage functions keep their own shapes on purpose, for the golden record |
| M0-3 | low | tooling | Generated `src/*.erl` tracked, embedding absolute `/nix/store` paths → ~700-line cross-OTP churn | `src/ladder_lexer.erl:1` (at `c9c7f51`; untracked since) | **closed** `dde8c1d` |
| B4 | low | tooling | nix dev shell bit-rotted: `erlangR26` alias removed from nixpkgs master 2024-05-24; flake tracked `master`; lock from 2024-01-19 | `shell.nix`, `flake.nix` | **landed** `9c1a7bd` — OTP 28 / Elixir 1.20 on `nixos-26.05`; lock refresh owed |
| B2 | low | lexer | Digit-led lexeme splits rather than erroring: `1bst` → `int_lit(1)` + `name("bst")` | `Logex.Lexer`, the integer clause (was `ladder_lexer.xrl:20`) | **closed** — a located `:missing_separator` lex error naming the whole run |
| B3 | low | history | 2 commits ship a red suite (`ec0534a`, `35fe1b9`) — an interior island; `d47eb21` is a clean bisect baseline | `.github/workflows/ci.yml` | **closed** — CI runs the four gates on every push and pull request; the island stays in history |
| B6 | low | project | No CI, no `@spec`/`@moduledoc`, no mix.exs metadata, unused `:logger` | `mix.exs` | **closed** — metadata, a `@moduledoc` on `Logex.Compiler`, no `:logger`; CI is B3's |
| B7 | nit | style | 5 `{false, env}` clauses with identical bodies; `Enum.any?(o, &(&1==true))`; intermediate list in branch reducer | `Logex.Runtime`, the evaluate clauses (was `Logex.Compiler.evaluate/2`) | open — B5's `Enum.map_reduce` took the `&(&1==true)` with it; the rest stands |
| M1-1 | nit | IR | AST nodes were keyword-list-shaped with duplicate keys where order is the meaning; `Keyword.get/2` would silently return only the first | the `elem ->` productions | **closed** `a22bf39` — elems are `{kind, line, value}` 3-tuples, not pairs |
| §5 | nit | domain | No comments, no negative literals, no structured addressing (`Timer.DN`, `Arr[3]`) | `Logex.Lexer` (was `ladder_lexer.xrl:3`) | **partly closed** — `//` comments and the `.` lexer rule landed 2026-09-30, members with M1-6, and negative literals with M3-3, and literal bit access with M5-8 and a bit number held in a tag, `status.[n]`, with M5-9 on 2026-10-23, and arrays by literal subscripts, `Arr[3]`, with M5-11 the same day, and a bit of an element, `Arr[3].2`, with decision 221, and a subscript held in a tag, `Arr[slot]`, with M5-12 on 2026-10-24 |
| B9 | low | surface | An Elixir-embedded `defladder` front end: studied, spiked, judged; recommendation and open decisions in `docs/defladder.md` | — | proposed; re-scoped 2026-10-01 as a one-way seed that emits a whole program as data |
| B10 | nit | warnings | Second-`ote` warnings on one line come in map order, not rung order | `Logex.Warnings.second_otes/3` | **closed** — the uses walked in rung order; guarded by a 40-tag test in `validation_test.exs` |

---

## 8. Domain gaps, in priority order

The execution model — rung-condition-in, series AND, parallel OR, non-retentive OTE vs
retentive OTL/OTU, top-to-bottom rungs with immediate data-table updates — is faithful.
The mnemonic set is authentic ladder vocabulary rather than invented. What is missing:

1. **Timers and counters (TON/TOF/RTO, CTU/CTD/RES)** — decisive. Essentially no real
   routine exists without them, and they are why the scan model matters. *`ton` landed with
   M1-6, as a declared instance on the injected clock; TOF, TP, RTO, RES and the counters
   are open, and reuse its `%Logex.FbType{}`.* *(Milestone 3, decided 2026-10-14: IEC's
   counters `ctu`, `ctd` and `ctud` in M3-1, reset and loaded through their `r` and `ld`
   inputs rather than a RES, landed 2026-10-14; `tof`, `tp` and `rto` in M3-2, landed
   2026-10-14, the `rto` cleared through its `r` input.)*
2. **A scan loop and I/O image.** The input image, the clock and the first-scan bit landed
   with M1-5 (`put_inputs/3`, `%Logex.Scan{}`). The scheduler landed with M2-1:
   `Logex.Runtime.cycle/3` steps a configuration's resource by the time the host says has
   passed, merging the input points that changed into a kept image, running the due
   tasks' instances by priority and returning every output point. A wall-clock runner,
   the only code that will read a clock, comes after Milestone 2 (`docs/organisation.md`
   §5). *(Milestone 4, designed and decided 2026-10-17, §3: decisions 108–121, and
   122–128 after M4-1's review, 2026-10-18.)* *(Landed with Milestone 4, M4-1 to M4-7, by
   2026-10-20: `Logex.Runner`, decisions 108–143.)*
3. **A tag table with types.** Landed with M1-3.
4. **Comparisons (`eq ne lt gt le ge` — IEC names, see `docs/naming.md`)** — high value,
   low cost. *Landed with M1-6, on dints.*
5. **Math (ADD/SUB/MUL/DIV), one-shots (ONS/OSR/OSF), then control flow (JMP/LBL/MCR).**
   ONS is the canonical instruction that cannot exist without cross-scan state. *`ons`
   landed with M1-6; OSR and OSF are open.* *(Milestone 3: arithmetic in M3-3, landed
   2026-10-14, `add sub mul div mod neg abs`; `osr` and `osf` in M3-4, landed 2026-10-14;
   forward `jmp`/`lbl` in M3-5, landed 2026-10-15, and no MCR, decision 83.)* JMP/LBL
   do *not* require abandoning the `Enum.reduce` over rungs — widening the accumulator
   from `env` to `{skip, env}` is enough for forward jumps; only backward jumps need an
   indexed loop. *(M3-5 replaced both reduces, a program's and a block body's, with one
   recursion over the rungs, which a jump turns into a skip, the jump's record riding in
   the env under an atom key; a scan with no jump costs fewer reductions than before.)*
6. **Surface syntax: comments, negative literals, structured addressing.** See §5.
   *(Negative literals landed with M3-3, 2026-10-14.)*
7. **Program organisation: configurations, tasks, program instances, I/O mapping.**
   Decided in §5; Milestone 2 (§3), designed 2026-10-02, its first item, M2-1, landed the
   same day, and M2-5, user function blocks, on 2026-10-04; the model in
   `docs/organisation.md`.
