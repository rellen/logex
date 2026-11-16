# Inventory C: README.md lines 481-1245

Range: `## An example` and its first six subsections ("A timer and a one-shot", "A counter",
"Three more timers", "Long timers", "Arithmetic", "Integer widths"). The range ends on the
blank line before `### Bit strings` (line 1246). Every line was read.

Word counts are `wc -w` over the lines, code blocks included; the figure in brackets is the
prose alone (fenced blocks left out).

## How the suite reads these blocks (applies to every section below)

Read from `test/logex/readme_test.exs` (lines 1-43, 139-240), because it limits how the
examples can move:

- An example is an `elixir` block **followed at once** by a block that begins
  `$ mix run <script>`; the rest of that block is the expected output, compared exactly.
- A file block is marked by `<!-- file: path -->` on the line **straight above** its fence.
- Marked files **accumulate in README order**: "from there on it is that file of every later
  example, until a later block marked with the same path replaces it". So every example after
  line 495 is given `motor.ld`, every one after 641 `boxes.ld`, and so on.
- Each shown block is held to its file under `examples/` (decision 517 (b)); `scan.exs` is
  also run by `mix run` through `examples/mix.exs` in a test of its own.
- Later README sections read two files first shown in this range: `motor.ld` (lines 2233,
  2705-2821 `plant.logex`/`plant.exs`, 5237 `motor_v2.ld`, 5370 `v2/motor.ld`) and `boxes.ld`
  (lines 3916, 4343-4403 `warm/boxes.ld`, 5406-5487 `recount.exs`, and the test's derived
  files `faster/boxes.ld`, `warm/boxes.ld`, `boxes_v2.ld`). If the pages are split, the test's
  "files so far" rule must be replaced or those pages must show the file again.

---

## An example (lines 481-569, about 594 words [379 prose])

**Reader and purpose.** A newcomer who wants to see one whole program compiled and run from
Elixir: the source file, the host script, and what five scans print. It is also where the
reader first meets declarations, the compile error for a misspelt tag, and the host's
`ArgumentError`.

**Units.**

| # | lines | gist | type | destination |
|---|---|---|---|---|
| 1.1 | 483-489 | Where every example lives (`examples/`), how to run one (`mix run scan.exs` from that directory, `examples/mix.exs` with logex as its one dependency), `a_trip.exs` whole there, the suite holds each block to its file | H, C | howto/install-and-run (run an example); contributor/testing-strategy (blocks held to files, decision 517 (b)) |
| 1.2 | 491-493 | What `motor.ld` is; every tag declared before the first rung: its type and its section (`var_input`, `var_output`, `var`) | T, R | tutorials/first-program; reference/declarations-and-types |
| 1.3 | 495-511 | `motor.ld` source (8 declarations, 5 rungs) | T | tutorials/first-program |
| 1.4 | 513-515 | Reading of the rungs: rung 1 the seal-in (OR branch, AND series), `ote` non-retentive, rungs 3 and 4 latch and unlatch (`otl`/`otu`) | T, R, E | tutorials/first-program; reference/instructions; explanation/scan-cycle-and-time (power flow) |
| 1.5 | 515-518 | A misspelt tag is a compile error with a did-you-mean, not a silent rung; the exact message | T, H, R | tutorials/first-program (a "break it on purpose" step); howto/read-diagnostics; reference/diagnostics-and-warnings |
| 1.6 | 520-539 | `scan.exs`: compile once (named `motor` after its file), run as one instance; each step sets changed inputs then scans | T, R | tutorials/first-program; reference/host-contract |
| 1.7 | 541-543 | Instance starts with each tag at its initial value (0, `speed_sp` 1200); a scan returns the `var_output`s; an internal tag is read from the state; why five scans | T, R | tutorials/first-program; reference/execution-model |
| 1.8 | 545-555 | Output of `scan.exs` and the two-line reading of it (motor seals in, fault stays latched) | T | tutorials/first-program |
| 1.9 | 557-563 | A host mistake raises `ArgumentError`, every problem in one message; `put_inputs` with an output and a misspelt input, the two-line message | R, H | reference/host-contract; howto/read-diagnostics |
| 1.10 | 565-568 | `scan/3` (ms since last scan), `call/4` (one scan, time given explicitly, what the scheduler calls), `restart/3` (starts again, keeps inputs that fit their types) | R | reference/host-contract; reference/execution-model |

**Examples.**

| line | kind | path / script | unit |
|---|---|---|---|
| 495 (block 496-511) | `<!-- file: motor.ld -->` | `examples/motor.ld` | 1.3 |
| 523-539 | `elixir` script (followed by `$ mix run`) | `examples/scan.exs` | 1.6 |
| 545-552 (`$ mix run` on 546) | `$ mix run scan.exs` output | `scan.exs` | 1.8 |
| 560-563 | unmarked text block: the `ArgumentError` message of `put_inputs` | not run by the suite as an example (no mark, no `$ mix run`) | 1.9 |

No `elixir` block without a following `$ mix run` in this section. Two messages are quoted
inline, not in blocks, and no test in `readme_test.exs` runs them: the `run_lmap` diagnostic
(518) and the call `Logex.Runtime.put_inputs(motor, state, %{"motor" => 1, "strat" => 1})` (558).

**Rules stated.**

- 483-485: every example in the README is under `examples/`: each script a `$ mix run` block follows, every file one reads, and the files the prose describes rather than shows (`faster/packing.logex`).
- 486-487: from `examples/`, `mix run scan.exs` runs one as shown; `examples/mix.exs` names logex, the directory above, as its one dependency.
- 487-488: a script shown as the continuation of another (`a_trip.exs`) is whole under `examples/`.
- 488-489: the suite runs every example there and holds each shown block to its file.
- 491-493: every tag is declared before the first rung.
- 492: a declaration says what the tag holds (`bool`, `dint` or another type).
- 492-493: and its section: `var_input` supplied from outside, `var_output` produced for outside, `var` the program's own.
- 503 (shown): a declaration may end with an initial value (`var_output speed_sp dint 1200`).
- 506, 513 (shown): `( a | b )` is a branch, an OR; instructions in series are an AND; `xio` is "not".
- 513-514: `ote` is non-retentive: `motor` drops out the moment `stop` closes.
- 514-515: `otl` latches; only an `otu` clears it.
- 515-518: a misspelt tag is a compile error, not a rung that never fires; `Logex.compile_file/1` gives `` motor.ld: line 11: `run_lmap` is not declared — did you mean `run_lamp`? `` (format: file, line, message, did-you-mean).
- 520: `Logex.compile_file/1` names the program after its file (`motor` from `motor.ld`).
- 520-521: a program is compiled once and run as an instance.
- 521, 527: `Logex.Runtime.put_inputs(program, state, inputs)` sets the inputs that changed; inputs not named keep their value (shown by scans 2-5).
- 528: `Logex.Runtime.scan(program, state)` gives `{outputs, state}`.
- 533: `Logex.Runtime.instance(program)` makes the instance's first state.
- 541-542: an instance starts with every declared tag at its initial value: 0 unless declared otherwise.
- 542: a scan gives back the `var_output`s (a map of name to value; a bool is 1 or 0).
- 542-543: an internal tag is read from the instance's state, `state.env["fault"]`.
- 543: a seal-in and a latch only show across scans.
- 557: a mistake by the host raises `ArgumentError`, with every problem in one message.
- 561: `put_inputs` of a `var_output` is refused: "only a var_input is set from outside"; the message cites the declaring line.
- 562: `put_inputs` of an undeclared name is refused with a did-you-mean.
- 565: `scan/3` takes the milliseconds since the last scan, which a timer counts.
- 566-567: `Logex.Runtime.call/4` is one scan with the time given explicitly; the scheduler calls it for each instance it runs.
- 567-568: `restart/3` starts an instance again, keeping the inputs that fit their types.

**Citations.**

- 489: decision 517 (b).
- 567: cross-reference "A configuration", below (README line 2690).
- No plan items, no "provisional" marks, no links to other documents.

**Pictures.**

- A drawn ladder diagram of `motor.ld`'s five rungs, beside the text form. The seal-in branch (rung 1) is the one drawing that matters most: the text `( xic start | xic motor ) xio stop ote motor` is hard to see as a parallel path.
- A table or strip chart of the five scans: inputs set, then `motor`, `run_lamp`, `speed_sp`, `fault`, one column a scan. Shows the seal-in holding and the latch staying.
- A small sequence diagram: host script, `put_inputs`, `scan`, state handed back. Shows that the host owns the state and the runtime holds none.

**Glossary.**

- **tag**: a named value a program declares (491).
- **rung**: one line of logic, read left to right (513).
- **seal-in**: a rung whose output is also one of its own conditions, so it holds itself on (491, 513).
- **latch / unlatch** (`otl`/`otu`): an output set by one rung that stays set until another rung clears it (514-515).
- **non-retentive** (`ote`): the output follows its rung on every scan (513-514).
- **`var_input` / `var_output` / `var`**: supplied from outside / produced for outside / the program's own (492-493).
- **`bool`, `dint`**: the types a tag holds (492); not defined here.
- **scan**: one run of the program's rungs (521, 541-543).
- **instance**: one running copy of a compiled program, with its own state (520-521, 541).
- **initial value**: the value a tag has when an instance starts (541).
- **host**: the Elixir code that calls logex (557).
- **scheduler**: what runs each instance of a configuration (567); not defined here.

**Hard to read.**

1. 483-485: "Every example in this file is in the repository, under `examples/`: each script a `$ mix run` block follows, and every file one reads, `motor.ld` and `scan.exs` below among them, and the files the prose describes rather than shows, `faster/packing.logex` among them."
2. 486-488: "From that directory, `mix run scan.exs` runs one as it is run here, `examples/mix.exs` naming logex, the directory above, as its one dependency; a script shown here as the continuation of another, `a_trip.exs`, is there whole."
3. 565-568: "`scan/3` takes the milliseconds since the last scan, which a timer counts; `Logex.Runtime.call/4` is one scan with the time given explicitly, which is what the scheduler calls for each instance it runs ("A configuration", below); `restart/3` starts an instance again, keeping the inputs that fit their types."

---

## A timer and a one-shot (lines 570-635, about 406 words [186 prose])

**Reader and purpose.** A reader who has run the motor example and now needs a delay and a
single-scan pulse. It shows `ton` and `ons`, how time reaches a timer (`scan/3`), and the rule
that nothing follows a `ton` on its rung.

**Units.**

| # | lines | gist | type | destination |
|---|---|---|---|---|
| 2.1 | 572-588 | `delay.ld`: a lamp after `go` is held 3 s, a pulse on the scan `go` rises | T | tutorials/timers-and-counters |
| 2.2 | 590-619 | `delay.exs` stepping with `scan/3` and the elapsed ms; its six-line output | T | tutorials/timers-and-counters |
| 2.3 | 621-622 | `ton`: starts at the scan that first sees its rung true, counts time not scans, stops at its preset, a false rung resets it | R, H, E | reference/instructions; howto/use-timers; explanation/scan-cycle-and-time |
| 2.4 | 622-623 | `ons`: fires once per rise, never on an instance's first scan | R, H | reference/instructions; howto/use-one-shots-and-pulse-coils |
| 2.5 | 624-626 | The timer's members in `state.env["t1"]`: `pre`, `acc`, `dn`, `tt`, `en`, and `last`; `last` in a state a host hands in must not be later than the instance's `now` | R | reference/function-blocks (built-in timers); reference/host-contract (the `last` bound) |
| 2.6 | 628-634 | Nothing may follow a `ton` on its path, because the power after it is not settled; `xic go ton t1 3000 ote lamp` refused, with the message; read `.dn` on a rung below | R, H, E | reference/instructions; reference/diagnostics-and-warnings; howto/use-timers; explanation/the-dialect-and-iec (why it is unsettled) |

**Examples.**

| line | kind | path / script | unit |
|---|---|---|---|
| 575 (block 576-588) | `<!-- file: delay.ld -->` | `examples/delay.ld` | 2.1 |
| 592-609 | `elixir` script (followed by `$ mix run`) | `examples/delay.exs` | 2.2 |
| 611-619 (`$ mix run` on 612) | `$ mix run delay.exs` output | `delay.exs` | 2.2 |
| 632-634 | unmarked text block: the diagnostic for `ote lamp` after `ton t1` | not run by the suite as an example | 2.6 |

No `elixir` block without a following `$ mix run`.

**Rules stated.**

- 581 (shown): a timer is an instance declared by its type, `var t1 ton`.
- 584 (shown): `ton t1 3000` takes the instance and a preset in milliseconds.
- 585, 587 (shown): members are read with a dot, `t1.dn`, `t1.acc`; a rung may have no condition (`move t1.acc waited`).
- 586 (shown): `ons s1` takes a `bool` tag of its own.
- 590: `scan/3` is given the milliseconds since the last scan.
- 598 (shown): the instance's time is `state.now`.
- 621: the timer starts at the scan that first sees its rung true (it adds nothing on that scan: t=100 shows `waited` 0).
- 621-622: it counts the time that passed, not the number of scans.
- 622: it stops at its preset (`waited` stays 3000 at t=3600).
- 622: a false rung resets it (`waited` 0, `lamp` 0 at t=3610).
- 622-623: the one-shot fires once per rise.
- 623: the one-shot never fires on an instance's first scan, even with its input already held.
- 624-625: the timer's members are in the instance's state, `state.env["t1"]`, a map with `pre`, `acc`, `dn`, `tt` and `en`, and `last`.
- 625: `last` is the time its `ton` last ran.
- 625-626: a state a host hands in may hold `last` at any time up to the instance's own `now`, and no later.
- 628-629: whether the power after a `ton` is the rung's or the timer's `.dn` is not settled.
- 629: so nothing may follow a `ton` on its path (a `ton` ends its path).
- 630-633: `xic go ton t1 3000 ote lamp` is refused: `` delay.ld: line 8: `ote lamp` follows `ton t1` on its path: what passes on after a `ton` is not settled, so a `ton` ends its path; read the timer with `xic t1.dn` on a rung below ``.

**Citations.** None (no decision numbers, plan items, "provisional" marks or links). The
phrase "is not settled" (629, 633) is an open design point stated without a decision number;
the same rule is at README lines 305 and 309.

**Pictures.**

- A timing diagram, signal against time, 0 to 3610 ms: `go`, `t1.acc` (a ramp that starts one scan after `go` rises and flattens at 3000), `t1.dn`/`lamp`, `pulse` (one scan wide at t=100). Mark the scan instants, since the scans are unevenly spaced: that is the point of "counts time, not scans".
- A drawn pair of rungs: the refused `xic go ton t1 3000 ote lamp` beside the accepted two-rung form.
- A small table of a `ton`'s members and what each means.

**Glossary.**

- **timer instance** (`var t1 ton`): a tag whose type is a timer; it holds the timer's members (581, 624).
- **preset** (`pre`): the time a timer runs to (584, 622, 624).
- **`acc`**: the time a timer has counted (587, 624); the text does not gloss it.
- **`dn`**: the timer's "done" bit, on once the preset is reached (585, 628); not glossed.
- **`tt`, `en`**: members named but not explained here (625).
- **`last`**: the time the timer's instruction last ran (625).
- **`now`**: the instance's own clock, in ms (598, 626).
- **one-shot** (`ons`): passes power for one scan when its rung goes from false to true (572-573, 622-623).
- **rise**: a change from false to true (573, 623).
- **path**: one way through a rung, along which instructions follow one another (629).
- **first scan**: the first scan of a new instance, on which edge instructions do not fire (623).

**Hard to read.**

1. 624-626: "The timer's members are in the instance's state, `state.env["t1"]`, a map with `pre`, `acc`, `dn`, `tt` and `en`, and `last`, the time its `ton` last ran, which a state a host hands in may hold at any time up to the instance's own `now`, and no later."
2. 628-630: "Whether the power after a `ton` is the rung's or the timer's `.dn` is not settled, so nothing may follow a `ton` on its path, and `xic go ton t1 3000 ote lamp` is refused:"
3. 621-622: "The timer starts at the scan that first sees `go` (t=100), counts the time that passed, not the number of scans, and stops at its preset; a false rung resets it."

---

## A counter (lines 636-808, about 1180 words [617 prose])

**Reader and purpose.** A reader who needs to count events: boxes on a conveyor, a buffer's
stock. It covers the up counter in full, then the down and up-down counters, the typed
counters of other widths, and what happens at a width's limit.

**Units.**

| # | lines | gist | type | destination |
|---|---|---|---|---|
| 3.1 | 638-653 | `boxes.ld`: an eye counts boxes, a lamp at three, a button resets | T | tutorials/timers-and-counters |
| 3.2 | 655-696 | `boxes.exs`, twelve scans 10 ms apart, and its output | T | tutorials/timers-and-counters |
| 3.3 | 698-699 | A counter counts rising edges of its rung; not while the rung stays true; not on the first scan | R, E | reference/instructions (`ctu`); explanation/scan-cycle-and-time (start-up rule) |
| 3.4 | 699-703 | Reset is the `r` input, written by a rung like any bit ("IEC drives a counter by its pins"); a pin written before the counter's rung takes effect at its next run; a reset leaves the edge memory alone | R, H, E | reference/function-blocks; howto/use-counters; explanation/the-dialect-and-iec (pins, not a reset instruction) |
| 3.5 | 703-706 | A `ctu`'s members: `cu`, `r`, `pv` inputs; `q`, `cv` outputs; `ov` at 2147483647, where the count stops until a reset; logic writes only `r` and `pv` | R | reference/function-blocks |
| 3.6 | 708-710 | Down counter `ctd`: `ld` loads `cv` from the preset, each count takes one away, `q` on at 0; a new one starts with `cv` 0 and `q` on until its first load | R, H | reference/function-blocks; reference/instructions (`ctd`); howto/use-counters |
| 3.7 | 710-718 | Up-down counter `ctud`: a `ctu` on one rung and a `ctd` on another, `r` and `ld` both; three example rungs with `stock.qu` | H, R | howto/use-counters; reference/function-blocks |
| 3.8 | 720-724 | A `ctd` on an up counter is refused, with what to declare instead; the message | R, H | reference/diagnostics-and-warnings; howto/use-counters |
| 3.9 | 726-731 | A counter counts in a dint; typed counters `ctu_int`, `ctu_lint`, `ctu_udint`, `ctu_ulint` and the `ctd_`/`ctud_` forms; same instructions; preset judged in the instance's type; stops at the type's limits with `ov` or `un`, where the conventional CTUD rolls over | R, H, E | reference/function-blocks; reference/declarations-and-types; howto/use-counters; explanation/types-and-overflow |
| 3.10 | 731-735 | `ctu_dint`, `ctd_dint`, `ctud_dint` are IEC's names for `ctu`, `ctd`, `ctud`: one type, messages use the plain word, an edit between them changes nothing | R, E | reference/declarations-and-types; explanation/the-dialect-and-iec |
| 3.11 | 735-736 | An online edit that changes a counter's width is refused, as any type change is | R | reference/online-edit |
| 3.12 | 736-797 | `stock.ld`, `stock.exs` and output: a `ctud_int` at an int's top, a `ctu_dint`, a preset an int cannot hold | H | howto/use-counters |
| 3.13 | 799-803 | Reading of the run: stops at 32767 with `ov` until a reset or a load; counting down still works; `cases` holds the type `ctu` declares; preset past the top refused at its line; a signed counter's preset may be negative, `q` is `.cv >= .pv` | H, R | howto/use-counters; reference/function-blocks |
| 3.14 | 805-806 | A counter in a function block whose `cal` is false is frozen with the block | R | reference/function-blocks |
| 3.15 | 806-807 | A counter under an event task is a configuration warning | R, H | reference/diagnostics-and-warnings; howto/use-an-event-task |

**Examples.**

| line | kind | path / script | unit |
|---|---|---|---|
| 641 (block 642-653) | `<!-- file: boxes.ld -->` | `examples/boxes.ld` (also read by later examples: see the note at the top) | 3.1 |
| 657-680 | `elixir` script (followed by `$ mix run`) | `examples/boxes.exs` | 3.2 |
| 682-696 (`$ mix run` on 683) | `$ mix run boxes.exs` output | `boxes.exs` | 3.2 |
| 714-718 | unmarked text block: three `ctud` rungs (`stock`, `buffer_full`) | not a file, not run | 3.7 |
| 722-724 | unmarked text block: the diagnostic for `ctd` on a `ctu` | not run | 3.8 |
| 739 (block 740-753) | `<!-- file: stock.ld -->` | `examples/stock.ld` | 3.12 |
| 758-786 | `elixir` script (followed by `$ mix run`) | `examples/stock.exs` | 3.12 |
| 788-797 (`$ mix run` on 789) | `$ mix run stock.exs` output | `stock.exs` | 3.12 |

No `elixir` block without a following `$ mix run`.

**Rules stated.**

- 647, 650 (shown): a counter is an instance, `var boxes ctu`; `ctu boxes 3` takes the instance and a preset.
- 698: the counter counts rising edges of its rung.
- 698: never while its rung stays true.
- 698-699: never on the first scan, so a box already on the eye at start is not counted.
- 699-700: its reset is its `r` input, which a rung writes as any rung writes a bit (`xic reset_pb ote boxes.r`).
- 700-701: IEC drives a counter by its pins; a pin written before the counter's rung takes effect at the counter's next run.
- 701-703: a reset leaves the counter's memory of its rung alone, so a rung still true through the reset is not counted again.
- 703-705: the counter's members are IEC's, lowercased, in `state.env["boxes"]`: `cu`, `r`, `pv` inputs; `q`, `cv` outputs; and `ov`.
- 705-706: `ov` is set where a count would pass 2147483647; the count stops there until a reset.
- 706: logic writes only `r` and `pv`.
- 708: a down counter is `var hopper ctd`, IEC's CTD.
- 708: its load, `ld`, puts `cv` to its preset.
- 709: each count takes one away.
- 709: its `q` is on at 0.
- 709-710: a new `ctd` starts empty: `cv` 0, `q` already on, until its first load.
- 710-712: an up-down counter is `var stock ctud`, run by a `ctu` on one rung and a `ctd` on another; it has `r` and `ld` both.
- 717 (shown): a `ctud` has `qu` (its up output).
- 720-723: a `ctd` on an up counter is refused, with what to declare instead: `` line 8: `ctd` runs a ctd, ctud, ctd_int, ctud_int, ctd_lint, ctud_lint, ctd_udint, ctud_udint, ctd_ulint or ctud_ulint, but `boxes` is a ctu (declared on line 5): a ctu only counts up; declare it `var boxes ctud` to count both ways ``.
- 726: a counter counts in a dint, as IEC's CTU_DINT and the conventional set's COUNTER do.
- 727-728: the typed counters are `ctu_int`, `ctu_lint`, `ctu_udint`, `ctu_ulint`, and `ctd_` and `ctud_` the same.
- 728-729: each has its `pv` and `cv` of that type.
- 729: each is run by the same `ctu` and `ctd`: a rung never says a width.
- 729-730: a preset is judged in its instance's type.
- 730-731: the count stops at that type's limits with `ov` or `un` on (the conventional set's CTUD rolls over).
- 731-732: `ctu_dint`, `ctd_dint` and `ctud_dint` are IEC's names for `ctu`, `ctd` and `ctud`: a declaration with either word gives the one type.
- 733-734: every message and warning names the instance by the plain word, `a ctu`, whichever word declared it.
- 734-735: an online edit from one word to the other changes nothing.
- 735-736: an edit that changes a counter's width is refused, as any type change is.
- 771 (shown): a host may set a member in the state directly, `put_in(state.env["stock"]["cv"], 32_766)`.
- 780, 800 (shown): `stock.tags["cases"].type == Logex.FbType.ctu()` is true for a `ctu_dint`.
- 796: `` line 3: `ctu` takes a preset of -32768 to 32767 for a counter of ints, found `40000` ``.
- 799: a count stops at the type's top with `ov` on; `ov` stays until a reset or a load.
- 799-800: a count down from the top takes one away (`ov` stays on: output line 794).
- 800-801: a preset past the type's top is refused at its line, in the type it is judged in.
- 801-802: a signed counter's preset may be negative, as IEC's PV may: `ctu offset -10` on a `ctu_int` compiles.
- 802-803: `q` is `.cv >= .pv`, so with a negative preset it is on from the start.
- 805-806: a counter in a function block whose `cal` is false is frozen with the rest of the block; an edge that passes while it is frozen is not counted.
- 806-807: a counter under an event task is a configuration warning, since it sees its rung only when the task runs.

**Citations.**

- 727: decision 158 (typed counters).
- 732: decision 163 (`_dint` words name the plain types).
- 726, 731: "the conventional set" (a term of `docs/instruction-sets.md`; not linked here).
- No plan items, no "provisional" marks, no links.

**Pictures.**

- A timing diagram over the twelve scans of `boxes.exs`: `eye`, `reset_pb`, `boxes.cv`, `boxes.q`. It shows the three things prose struggles with: no count on the first scan, no count while the eye stays blocked, and no second count of the box that sat on the eye through the reset.
- A table of the counter types: rows `ctu`, `ctd`, `ctud`; columns the suffix (none/`_dint`, `_int`, `_lint`, `_udint`, `_ulint`), with the range of `cv` and `pv`. Fifteen types (eighteen words with the `_dint` aliases) in one view.
- A table of members for each kind: `cu`, `cd`, `r`, `ld`, `pv`, `q`/`qu`/`qd`, `cv`, `ov`, `un`, with "input or output" and "logic may write". The text names `qd`, `cd` and `un` nowhere or only in passing, so the writer must take them from the moduledoc.
- A drawn rung pair for the `ctud`: the infeed rung and the outfeed rung driving one instance.

**Glossary.**

- **photo-eye**: a sensor that is true while a box blocks it (638); plant jargon, not explained.
- **rising edge**: a rung going from false to true (698).
- **pin**: an input of a function block, which logic writes like a bit (700-701).
- **`cu`, `r`, `pv`, `q`, `cv`**: IEC's counter members, lowercased: count-up input, reset, preset value, output, current value (704-705; the text gives only "inputs" and "outputs").
- **`ov`**: set where a count would pass the type's top (705); **`un`**: its counterpart at the bottom (731; not explained).
- **load (`ld`)**: the down counter's input that puts `cv` to its preset (708).
- **`qu`**: the up-down counter's "up" output (717; not explained).
- **typed counter**: a counter that counts in an integer type other than dint (727).
- **width**: the size of an integer type (729, 735).
- **the conventional set**: the vendors' usual instruction set, as against IEC's (726, 731); defined elsewhere.
- **frozen**: a block whose `cal` is false does not run, and nothing in it sees its inputs (805-806).
- **event task**: a task that runs on an event, not on a period (806); defined elsewhere.

**Hard to read.**

1. 699-701: "Its reset is its `r` input, which the reset rung writes as any rung writes a bit: IEC drives a counter by its pins, a pin written before the counter's rung taking effect at its next run."
2. 727-731: "IEC's typed counters count in another integer type (decision 158): `ctu_int`, `ctu_lint`, `ctu_udint` and `ctu_ulint`, and `ctd_` and `ctud_` the same, each with its `pv` and `cv` of that type and run by the same `ctu` and `ctd`, so a rung never says a width: its preset is judged in its instance's type, and the count stops at that type's limits with `ov` or `un` on, where the conventional set's CTUD rolls over."
3. 731-735: "`ctu_dint`, `ctd_dint` and `ctud_dint` are IEC's names for `ctu`, `ctd` and `ctud` themselves (decision 163): a declaration with either word gives the one type, so every message and warning names the instance by the plain word, `a ctu`, whichever word declared it, and an edit from one to the other changes nothing."

---

## Three more timers (lines 809-911, about 857 words [452 prose])

**Reader and purpose.** A reader who knows `ton` and needs an off-delay, a fixed pulse or an
accumulating timer. It shows `tof`, `tp` and `rto` in one program and then lists how each
behaves across a restart, an online edit and an event task.

**Units.**

| # | lines | gist | type | destination |
|---|---|---|---|---|
| 4.1 | 811-836 | `line.ld`: a fan run-on (`tof`), a horn pulse (`tp`), a lubrication timer (`rto`), presets of a few scans | H | howto/use-timers |
| 4.2 | 838-883 | `line.exs`, fourteen scans 10 ms apart, and its output | H | howto/use-timers |
| 4.3 | 885-886 | `tof`: `.dn` stays on through the delay after the rung goes false and drops at the preset after the scan that saw it go false; `.dn` is IEC's Q | R, H | reference/instructions; reference/function-blocks; howto/use-timers |
| 4.4 | 886-890 | `tp`: no pulse for a rung true at start (the start-up rule of every edge-driven instruction); pulse exactly the preset, `.tt` the pulse; an edge during a pulse starts nothing; `.dn` on as the pulse ends while the rung holds | R, H | reference/instructions; reference/function-blocks; howto/use-timers |
| 4.5 | 890-895 | `rto`: keeps its time while the rung is false, adds from the scan after the rung is true again; `.dn` at the preset; reset input `r` clears it, time counting again from the last scan that saw the reset | R, H | reference/instructions; reference/function-blocks; howto/use-timers |
| 4.6 | 895-900 | The `rto` across a restart: 0 when nothing is marked; `var retain lube rto` keeps its time on a warm restart and resumes from the instance's `now`, cold starts at 0; in a resource a warm `restart/2` resumes from the resource's `now` | R, H, E | reference/retained-values-and-store; howto/keep-values-across-a-restart; explanation/warm-and-cold-restarts |
| 4.7 | 902-904 | Each is a timer by every rule a `ton` keeps: one instruction runs it, nothing may follow it on its path, logic may `move` into `.pre` and `.acc`, a change of timer type is refused by an online edit | R | reference/instructions; reference/online-edit |
| 4.8 | 904-908 | An edit that moves a preset forecasts each by its own rule (`tof`'s `.dn` dropping, `tp`'s pulse ending, `rto`'s `.dn`); a `tp` an edit adds while its rung is true gives no pulse at the switch | R, H | reference/online-edit; howto/edit-a-running-program |
| 4.9 | 908-910 | Under an event task each is a configuration warning in its own words: a `tof`'s delay and a `tp`'s pulse end only when the task next runs | R, H | reference/diagnostics-and-warnings; howto/use-an-event-task |

**Examples.**

| line | kind | path / script | unit |
|---|---|---|---|
| 815 (block 816-836) | `<!-- file: line.ld -->` | `examples/line.ld` | 4.1 |
| 840-865 | `elixir` script (followed by `$ mix run`) | `examples/line.exs` | 4.2 |
| 867-883 (`$ mix run` on 868) | `$ mix run line.exs` output | `line.exs` | 4.2 |

No `elixir` block without a following `$ mix run`. No unmarked blocks.

**Rules stated.**

- 824-826, 828, 830, 833 (shown): instances are `var run_on tof`, `var horn_pulse tp`, `var lube rto`; each instruction takes the instance and a preset in ms.
- 885: a `tof` holds its `.dn` on through its delay after its rung goes false.
- 885-886: it drops `.dn` at the preset (30 ms) after the scan that saw the rung go false.
- 886: a `tof`'s `.dn` is IEC's Q: on while the rung is true and through the delay.
- 886-888: a `tp` gives no pulse for a rung already true at start, by the start-up rule every edge-driven instruction keeps.
- 888-889: a `tp`'s pulse lasts exactly its preset; `.tt` is its pulse.
- 889-890: an edge during a pulse starts nothing (the rung may fall and rise meanwhile).
- 890: a `tp`'s `.dn` comes on as the pulse ends, while the rung holds.
- 890-891: an `rto` keeps its time while its rung is false and adds to it when the rung is true again.
- 891-893: it adds from the scan after the rung goes true again, as a `ton` adds nothing on the scan that first sees its rung true.
- 893: an `rto`'s `.dn` comes on at its preset.
- 893-894: an `rto`'s reset input `r`, written by a rung above it, clears it (`xic greased ote lube.r`).
- 894-895: after a reset the time counts again from the last scan that saw the reset.
- 895: a restart, warm or cold, starts an unmarked `rto` at 0.
- 896-897: declared `var retain lube rto`, a warm restart keeps its time, resuming from its instance's `now`, its last scan's.
- 897: a cold restart starts it at 0.
- 898-899: in a resource, a warm `restart/2` resumes it from the resource's `now`, the restart's, as a start from the store does.
- 899-900: so the time since the instance's task last ran is not counted either.
- 902: each of `tof`, `tp`, `rto` is a timer by every rule a `ton` keeps.
- 902: one instruction runs it.
- 902-903: nothing may follow it on its path.
- 903: logic may `move` into `.pre` and `.acc`.
- 903-904: a `ton` made a `tof` is a change of type, which an online edit refuses.
- 904-905: an edit that moves a preset forecasts each timer by its own rule.
- 905-906: for a `tof`: its `.dn` dropping during its delay, or at its rung's fall where its preset goes to 0 while the rung is true.
- 906-907: for a `tp`: its pulse ending.
- 907: for an `rto`: its `.dn` at its next run with its rung true.
- 907-908: a `tp` an edit adds while its rung is true gives no pulse at the switch.
- 908-909: under an event task each is a configuration warning in its own words.
- 909-910: a `tof`'s delay and a `tp`'s pulse end only when the task next runs.

**Citations.**

- 897: decisions 266 and 273 (retained `rto` across warm and cold restarts).
- 900: decision 382 (a resource's warm restart resumes from the resource's `now`).
- No plan items, no "provisional" marks, no links.

**Pictures.**

- Four timing diagrams on one time axis, one a timer kind: rung input, `.acc`, `.dn`, `.tt` for `ton`, `tof`, `tp`, `rto`. This is the standard IEC picture and replaces most of lines 885-895. For `tp` show a second edge inside the pulse being ignored; for `rto` show the flat stretch while the rung is false and the `r` reset.
- A strip chart of the fourteen scans of `line.exs` (inputs `motor`, `fault`, `greased`; outputs `fan`, `horn`, `grease_due`, `run_ms`), since the three timers overlap in the one run and the output table is hard to read by eye.
- A before/after pair for the `rto` across a warm restart: retained (`acc` kept, resumes from `now`) against unmarked (0).
- A comparison table of the four timers: what starts it, what `.dn` means, what `.tt` means, what a false rung does, how it is reset.

**Glossary.**

- **run-on** (off-delay, `tof`): an output held on for a time after its condition stops (811, 885).
- **pulse timer** (`tp`): gives a pulse of fixed length on a rising edge (811, 888).
- **retentive timer** (`rto`): adds up the time its rung is true and keeps the sum while it is false (812, 890-891).
- **`.tt`**: "timer timing", the bit that is on while the timer is counting; for a `tp`, the pulse (889).
- **IEC's Q**: the IEC name of a timer's output, which logex calls `.dn` (886).
- **start-up rule**: no edge-driven instruction fires on an instance's first scan (887-888).
- **edge-driven instruction**: one that acts on a change of its rung, not on its level (888).
- **warm restart / cold restart**: a restart that keeps retained values / one that starts every value again (895-897); defined elsewhere.
- **`retain`**: the qualifier that marks a tag to be kept across a warm restart (896).
- **resource**: a running configuration (898); defined elsewhere.
- **the store**: the retained values on disk (899); defined elsewhere.
- **the switch**: the moment an online edit takes effect (908); defined elsewhere.
- **forecast**: what an edit's report says a changed preset will do (905); defined elsewhere.

**Hard to read.**

1. 895-900: "A restart, warm or cold, starts it at 0 too, since this program marks nothing: declared `var retain lube rto`, a warm restart keeps its time, resuming from its instance's `now`, its last scan's, and a cold one starts it at 0 (decisions 266 and 273); in a resource, a warm `restart/2` resumes it from the resource's `now`, the restart's, as a start from the store does, so the time since the instance's task last ran is not counted either (decision 382)."
2. 890-895: "The `rto` keeps its 10 ms while the motor is stopped and adds to it when it runs again, from the scan after the motor starts again, as a `ton` adds nothing on the scan that first sees its rung true; `grease_due` lights at its 50 ms, and its reset input `r`, written by the `greased` rung above it, clears it, the time counting again from the last scan that saw the reset."
3. 904-907: "An edit that moves a preset forecasts each by its own rule: a `tof`'s `.dn` dropping during its delay, or at the motor's stop where its preset goes to 0 while the motor runs, a `tp`'s pulse ending, an `rto`'s `.dn` at its next run with its rung true."

---

## Long timers (lines 912-1005, about 699 words [385 prose])

**Reader and purpose.** A reader who needs a delay longer than 24.8 days, or who is porting a
program that uses IEC's LTIME. The section's real message is a hazard: a long timer's preset
is in nanoseconds, the rung does not say so, and the clock still ticks in milliseconds.

**Units.**

| # | lines | gist | type | destination |
|---|---|---|---|---|
| 5.1 | 914-919 | A `ton` counts a dint of ms, at most 24.8 days; `ton_ltime`, `tof_ltime`, `tp_ltime`, `rto_ltime` count a lint of nanoseconds, up to about 292 years; the instructions stay `ton`, `tof`, `tp`, `rto` | R, H, E | reference/function-blocks; reference/declarations-and-types; howto/use-timers; explanation/types-and-overflow |
| 5.2 | 921-938 | `cure.ld`: a 36-hour cure and a 90 s fan run-on, presets in ns | H | howto/use-timers (a "long timers" part) |
| 5.3 | 940-988 | `cure.exs`: seven scans, then a recompile with a 1,500,000 ns preset and a ported `ge cure.acc 3000`; output with two warnings | H | howto/use-timers; reference/diagnostics-and-warnings (the two warning texts) |
| 5.4 | 990-993 | "The unit is the instance's, not the rung's": `ton t 2000000` is 33 minutes on a `ton` and 2 ms on a `ton_ltime`; a changed declaration compiles with every preset a million times off | H, E | howto/use-timers (a warning box); explanation/the-dialect-and-iec; NEW howto/port-a-program (see the summary: porting hazards have no page) |
| 5.5 | 993-998 | "The resolution is a millisecond": each ms adds 1,000,000 ns; a preset that is no whole ms is reached at the next whole ms and warned of; so is such a literal beside `.pre` or `.acc` in `move`, a conversion, a comparison, `add` or `sub` | R, E | reference/function-blocks; reference/diagnostics-and-warnings; explanation/scan-cycle-and-time |
| 5.6 | 998-1000 | A long timer's `.pre` and `.acc` take a `move` of a `lint` or anything that widens into one, in ns | R | reference/function-blocks |
| 5.7 | 1000-1003 | An online edit `ton` to `ton_ltime` or back is a type change, refused; a preset edit is reported and forecast in ns, a resumed timer's gap in ms | R | reference/online-edit |
| 5.8 | 1003-1004 | Under an event task each is warned of in its own words, "a ton_ltime times across the task's runs" | R | reference/diagnostics-and-warnings; howto/use-an-event-task |

**Examples.**

| line | kind | path / script | unit |
|---|---|---|---|
| 924 (block 925-938) | `<!-- file: cure.ld -->` | `examples/cure.ld` | 5.2 |
| 945-975 | `elixir` script (followed by `$ mix run`) | `examples/cure.exs` | 5.3 |
| 977-988 (`$ mix run` on 978) | `$ mix run cure.exs` output | `cure.exs` | 5.3 |

No `elixir` block without a following `$ mix run`. No unmarked blocks.

**Rules stated.**

- 914: a `ton` counts a dint of milliseconds, so it reaches 24.8 days at most.
- 914-916: the long timers are `ton_ltime`, `tof_ltime`, `tp_ltime` and `rto_ltime` (IEC's suffix on the retentive timer).
- 916: they count a `lint` of nanoseconds in `.pre` and `.acc`, as IEC's LTIME does.
- 916-917: a preset may be up to 9223372036854775807 ns, about 292 years.
- 917-918: the instructions stay `ton`, `tof`, `tp` and `rto`: each runs both of its kind.
- 918-919: every rule of the plain timers is its kind's.
- 983 (shown): a false rung resets a `ton_ltime`'s `.acc` to 0.
- 986: warning text: `` line 9: warning: `ge` compares `cure.acc` with `3000`, where `cure.acc` is a ton_ltime's time in nanoseconds: 3000 ns is no whole number of milliseconds, and a ton_ltime counts whole milliseconds ``.
- 987: warning text: `` line 10: warning: `tof` gives `run_on` a preset of 1500000 ns, which is no whole number of milliseconds: a tof_ltime counts whole milliseconds, so it times as the next whole millisecond, 2 ms ``.
- 974 (shown): a compiled program's warnings are `program.warnings`, formatted by `Logex.Diagnostic.format/1`.
- 990: the unit is the instance's, not the rung's.
- 990-991: `ton t 2000000` is 2,000,000 ms (about 33 minutes) where `t` is a `ton`, and 2 ms where it is a `ton_ltime`.
- 991-993: a declaration changed from one to the other compiles with every preset a million times off; nothing on the rung says which.
- 993-994: the resolution is a millisecond: logex's clock and every elapsed time a host or the runner gives are whole milliseconds.
- 994-995: each millisecond adds 1,000,000 ns to `.acc`.
- 995-996: a preset that is no whole number of milliseconds is reached at the next whole millisecond, and warned of.
- 996-998: a literal that `move`, a conversion, a comparison, `add` or `sub` takes beside a long timer's `.pre` or `.acc`, and that is no whole number of ms, is warned of too.
- 998-1000: a long timer's `.pre` and `.acc` take a `move` of a `lint` or of anything that widens into one, in ns.
- 1000-1001: an online edit from a `ton` to a `ton_ltime`, or back, is a change of type and refused.
- 1001-1002: an edit of a long timer's preset is reported and forecast in ns.
- 1002-1003: a resumed timer's gap is reported in ms, the clock's unit.
- 1003-1004: under an event task each is warned of in its own words, "a ton_ltime times across the task's runs".

**Citations.**

- 917: decision 158, M5-6.
- 998: decision 196 (the whole-millisecond warnings).
- No "provisional" marks, no links.

**Pictures.**

- A two-row table: plain timer against long timer; unit of `.pre`/`.acc` (ms / ns), type (dint / lint), largest preset (24.8 days / about 292 years), type words, what one ms adds to `.acc` (1 / 1,000,000).
- A before/after pair of the same rung, `ton t 2000000`, under `var t ton` and under `var t ton_ltime`, with the time each gives. This is the hazard of lines 990-993 in one glance.
- A small number-line sketch of a 1,500,000 ns preset between the 1 ms and 2 ms ticks, reached at 2 ms.

**Glossary.**

- **long timer**: a timer whose `.pre` and `.acc` are a `lint` of nanoseconds (914-917).
- **LTIME**: IEC's 64-bit duration type, in nanoseconds (916).
- **`lint`**: a 64-bit signed integer (916; defined under "Integer widths").
- **`_ltime` suffix**: the type word's ending that makes a timer a long timer (915).
- **resolution**: the smallest step of time logex's clock takes, one millisecond (993).
- **the runner**: what runs a plant on the clock (994); defined elsewhere.
- **widens into**: every value of the source type is a value of the destination type (999; defined under "Integer widths").
- **resumed timer's gap**: the time a timer did not count across an edit or restart (1002); not explained here.
- **ported**: carried over from another program or controller (942, 998).

**Hard to read.**

1. 993-998: "**The resolution is a millisecond:** logex's clock and every elapsed time a host or the runner gives are whole milliseconds, so each millisecond adds 1,000,000 ns to `.acc`, and a preset that is no whole number of milliseconds, as the 1,500,000 ns above, is reached at the next whole millisecond, 2 ms, and warned of; so is a literal that `move`, a conversion, a comparison, `add` or `sub` takes beside a long timer's `.pre` or `.acc`, as the ported `ge cure.acc 3000` above, a time in ns too (decision 196)."
2. 940-943: "`cure.exs` scans it, each scan the given milliseconds after the last, and then compiles it again with the fan's run-on cut to 1,500,000 ns and the cured lamp lit by a comparison ported from a `ton`'s rung, `ge cure.acc 3000`, which meant 3 s and on a `ton_ltime` reads 3,000 ns:"
3. 914-917: "IEC's long timers, `ton_ltime`, `tof_ltime` and `tp_ltime`, and `rto_ltime`, IEC's suffix on the retentive timer, count a `lint` of **nanoseconds** in `.pre` and `.acc`, as IEC's LTIME does, so a preset may be up to 9223372036854775807 ns, about 292 years (decision 158, M5-6)."

---

## Arithmetic (lines 1006-1126, about 920 words [468 prose])

**Reader and purpose.** A reader who needs sums, a comparison and a division in a program, and
who must know what happens on overflow and on a zero divisor. It is also the first place the
reader meets faults, and a cycle's events.

**Units.**

| # | lines | gist | type | destination |
|---|---|---|---|---|
| 6.1 | 1008-1030 | `fill.ld`: a running total, a setpoint comparison, an overflow lamp for this scan and a latched one, a flow per minute | H | howto/do-arithmetic |
| 6.2 | 1032-1099 | `fill.exs`: six scans printing faults, then one cycle under a configuration built from Elixir with its events, then two refused sources; output | H, R | howto/do-arithmetic; reference/faults (the fault as printed); howto/build-a-configuration-from-elixir (the config is a small complete one) |
| 6.3 | 1101-1103 | `add` reads its sources before it writes; each arithmetic instruction's power out is IEC's ENO, true when the stored value is the exact result, so anything may follow it | R, E | reference/instructions; explanation/types-and-overflow |
| 6.4 | 1104-1110 | A result outside a dint wraps (low 32 bits, two's complement), with no power and no fault on that scan; how to latch an overflow; no value outside a dint reaches a state | R, H, E | reference/instructions; howto/do-arithmetic; explanation/types-and-overflow |
| 6.5 | 1110-1112 | History: until Milestone 5 a result stopped at the nearer limit; it now wraps as Logix and the S7-1200 do, with no power out as on the S7-1200, at every width | X, E, C | drop the history from user docs; explanation/types-and-overflow (the vendor comparison); adr/NNNN-integer-overflow-wraps (decision 146) |
| 6.6 | 1113-1118 | A zero divisor gives 0 and no power, and is a minor fault; `state.faults`; a cycle's `{:fault, ...}` event after its `{:ran, ...}`; what a fault names; the plant runs on | R, H | reference/faults; reference/execution-model (events); howto/do-arithmetic |
| 6.7 | 1119-1122 | `div` truncates toward zero; `mod`'s sign is the dividend's; `neg` and `abs` of the lowest dint, and `div -2147483648 -1`, overflow | R | reference/instructions |
| 6.8 | 1123-1125 | A literal zero divisor is refused at compile; a negative literal is its sign glued to its digits; `5-3` is an error; a difference is `sub` | R | reference/literals; reference/diagnostics-and-warnings; reference/source-syntax |

**Examples.**

| line | kind | path / script | unit |
|---|---|---|---|
| 1013 (block 1014-1030) | `<!-- file: fill.ld -->` | `examples/fill.ld` | 6.1 |
| 1035-1083 | `elixir` script (followed by `$ mix run`) | `examples/fill.exs` | 6.2 |
| 1085-1099 (`$ mix run` on 1086) | `$ mix run fill.exs` output | `fill.exs` | 6.2 |

No `elixir` block without a following `$ mix run`. No unmarked blocks. Note that `fill.exs`
does three jobs (scans, a configuration's cycle, two compile errors) and must move whole, so
the page that takes it shows a configuration before the reader has met one.

**Rules stated.**

- 1025, 1027, 1029 (shown): `add a b dest`, `div a b dest` take two sources and a destination; `ge a b` compares and passes power.
- 1101-1102: `add total flow total` reads its sources before it writes, so a destination may be a source and a total runs on from scan to scan.
- 1102-1103: each arithmetic instruction's power out is IEC's ENO: true when the value it stores is the exact result.
- 1103: so anything may follow an arithmetic instruction on its rung.
- 1104: a result outside a dint wraps: it keeps its low 32 bits, read in two's complement (2147483647 + 1 is −2147483648).
- 1105-1106: on the scan that wraps, the instruction passes no power and raises no fault.
- 1107-1108: the power is off for the one scan that wrapped and back on at the next.
- 1108-1109: a program that must remember an overflow latches it, on the rung after the `add` (`xio total_ok otl overflow`).
- 1109-1110: no value outside a dint ever reaches a state.
- 1110-1111: (history) until Milestone 5 a result stopped at the nearer limit.
- 1111-1112: the dint wraps as Logix and the S7-1200 do, with no power out as on the S7-1200; so does every integer width.
- 1113: a zero divisor gives 0 and no power on that scan.
- 1113-1114: it is a minor fault the scan reports, `severity: :minor`.
- 1114-1115: a lone instance's `state.faults` is every `%Logex.Fault{}` of the scan that returned it, `[]` for none.
- 1115-1116: a cycle gives each fault as an event just after its scan's `{:ran, ...}`, naming the task and the instance: `{:fault, task, instance, %Logex.Fault{}}` (1096).
- 1116-1118: the fault names the instruction, the file and the line, and `path`, the block instance it ran in for one inside a function block.
- 1088 (shown): a fault's fields are `severity`, `kind` (`:divide_by_zero`), `instruction`, `path`, `file`, `line`, `read`.
- 1095 (shown): `{:ran, task, instance, time}`.
- 1072 (shown): `Logex.Runtime.cycle(resource, now, inputs)` gives `{resource, outputs, events}`; `Logex.Runtime.start(config)` makes the resource; a cycle's outputs are the located globals (`%{"valve" => 1}`).
- 1118: after a minor fault the plant runs on.
- 1119: `div` truncates toward zero, as IEC's does: `div -7 2 q` is −3.
- 1119-1120: `mod` is the remainder IEC defines, its sign the dividend's: `mod -7 3 r` is −1.
- 1120-1121: `neg` and `abs` of −2147483648 overflow, giving −2147483648 itself and no power.
- 1121-1122: `div -2147483648 -1` does the same.
- 1123: a literal zero divisor is refused when the program compiles: `` line 3: `div` divides by the literal `0`: a zero divisor gives 0 and passes no power on every scan, so a literal one is refused `` (1097).
- 1123-1124: a negative literal is its sign glued to its digits, `-5`, wherever a literal goes.
- 1124-1125: a sign begins a number, so `5-3` is an error, not a number and then another: `` line 2, column 6: missing separator before `-`: "5-3" is neither a tag nor a number, and a sign begins a number `` (1098).
- 1125: a difference is `sub`.

**Citations.**

- 1110: Milestone 5, decision 146 (wrap replaces stopping at the limit).
- 1112: cross-reference "Integer widths", below (line 1127).
- 1111-1112: vendor behaviour cited without a source here: Logix, the S7-1200.
- No "provisional" marks, no links.

**Pictures.**

- A number circle (or a number line with an arrow that jumps from the top to the bottom) for a dint: 2147483647 + 1 lands on −2147483648. One picture explains "wraps" better than the sentence at 1104-1106.
- A strip chart of the six scans of `fill.exs`: `flow`, `total`, `total_ok`, `overflow`, `valve`. It shows `total_ok` dropping for exactly one scan while `overflow` stays latched, and the valve opening again after the wrap.
- A small table: for each of `add`, `sub`, `mul`, `div`, `mod`, `neg`, `abs`, what is stored and whether power passes in three cases (exact result, overflow, zero divisor).
- A drawn rung for `add total flow total ote total_ok`, to show that power out of an arithmetic box can drive a coil.

**Glossary.**

- **ENO**: IEC's "enable out": the power an instruction passes on, true when it did its work exactly (1102).
- **wraps**: a result too big for its type keeps only its low bits, so it jumps to the other end of the range (1104).
- **two's complement**: the usual way a signed integer is held in bits (1104); not explained.
- **dint**: a 32-bit signed integer, −2147483648 to 2147483647 (1104-1105).
- **minor fault**: a fault a scan reports and runs on through (1113-1114, 1118).
- **`%Logex.Fault{}`**: the record of one fault (1115).
- **cycle**: one step of a running configuration, which runs the tasks that are due (1115); defined elsewhere.
- **event**: an item in the list a cycle returns, such as `{:ran, ...}` or `{:fault, ...}` (1116).
- **`path`**: the block instance a fault happened in, for a fault inside a function block (1117).
- **lone instance**: an instance run directly by the host, not under a configuration (1114).
- **setpoint**: the value a process is meant to reach (1009); plant jargon.
- **literal**: a number written in the source (1123).

**Hard to read.**

1. 1113-1116: "A zero divisor, the minutes at start-up, gives 0 and no power on that scan, and is a minor fault the scan reports, `severity: :minor`: a lone instance's `state.faults` is every `%Logex.Fault{}` of the scan that returned it, `[]` for none, and a cycle gives each as an event just after its scan's `{:ran, ...}`, naming the task and the instance."
2. 1110-1112: "Until Milestone 5 (decision 146) a result stopped at the nearer limit instead; the dint now wraps, as Logix and the S7-1200 do, with no power out as on the S7-1200, and so does every integer width ("Integer widths", below)."
3. 1123-1125: "A negative literal is its sign glued to its digits, `-5`, wherever a literal goes, and a sign begins a number, so `5-3` is an error rather than a number and then another: a difference is `sub`."

---

## Integer widths (lines 1127-1245, about 1147 words [761 prose])

**Reader and purpose.** A reader who must match a device's 8-, 16- or 64-bit registers, or who
is porting a program with mixed integer types. It gives the eight integer types, when a value
moves between them without a conversion, the 56 conversions, and how arithmetic and
comparisons treat mixed widths.

**Units.**

| # | lines | gist | type | destination |
|---|---|---|---|---|
| 7.1 | 1129-1147 | `drive.ld`: a `uint` register moved into a `dint`, doubled in a `uint`, a `dint` level converted into an `sint`, two "it fitted" lamps | H | howto/choose-integer-widths-and-convert |
| 7.2 | 1149-1197 | `drive.exs`: three scans, an input too big for a `uint`, and six refused lines (three `move`s, an `add`, a `neg`, a comparison); output | H, R | howto/choose-integer-widths-and-convert; reference/diagnostics-and-warnings (six message texts); reference/host-contract (the input range message) |
| 7.3 | 1199-1205 | The types: `bool`, `sint int dint lint` signed, `usint uint udint ulint` unsigned, 8 to 64 bits; declared wherever a dint is; every value from a host, a device or a force is range-checked, with the range in the message | R | reference/declarations-and-types; reference/host-contract |
| 7.4 | 1206-1210 | `move` works in its destination's type; a source moves in where IEC's Figure 11 widens it; every other pair is refused, naming the conversion; a bool and an integer have none | R, E | reference/instructions (`move`); reference/declarations-and-types (the widening table); explanation/types-and-overflow |
| 7.5 | 1211-1219 | The 56 conversions `<from>_to_<to>`: power when the value fits, low bits kept and no power when it does not, no fault; the source may be any type that widens into the named one; the destination is exact; a literal source compiles with a warning | R, H | reference/conversions; howto/choose-integer-widths-and-convert |
| 7.6 | 1220-1223 | A `cal`'s operands and a configuration's connections widen as `move` does; a `var_external` binds only to a global of exactly its type; an edit that changes a tag's width is refused until a restart, one that changes its initial value is reported | R | reference/function-blocks; reference/configuration-file; reference/online-edit |
| 7.7 | 1224-1235 | Arithmetic works in its destination's type: wrap at that width, sources widen or are refused, two `int`s into a `dint` cannot overflow (unlike IEC's overloaded `INT + INT` and Siemens's), `neg` into unsigned refused, `div` and `mod` rules at every width | R, E, H | reference/instructions; explanation/types-and-overflow; NEW howto/port-a-program (the "behaves differently" warning) |
| 7.8 | 1236-1241 | A comparison reads two integers of any widths by value, exactly; a literal compared with a tag must be a value of the tag's type; two literals compile with a warning | R | reference/instructions; reference/literals |
| 7.9 | 1242-1244 | The seven type words are reserved in any case in every `.ld` and `.logex` file, and the 56 mnemonics in every `.ld` file | R, X | reference/source-syntax (reserved words); drop "new" (history) |

**Examples.**

| line | kind | path / script | unit |
|---|---|---|---|
| 1134 (block 1135-1147) | `<!-- file: drive.ld -->` | `examples/drive.ld` | 7.1 |
| 1152-1183 | `elixir` script (followed by `$ mix run`) | `examples/drive.exs` | 7.2 |
| 1185-1197 (`$ mix run` on 1186) | `$ mix run drive.exs` output | `drive.exs` | 7.2 |

No `elixir` block without a following `$ mix run`. No unmarked blocks.

**Rules stated.**

- 1136-1142 (shown): a declaration's words may be aligned with extra spaces.
- 1157 (shown): `scan/2` with no elapsed time.
- 1190: a host's input outside its type is refused: `` input `hz` is a uint: 65536 is outside 0 to 65535 ``.
- 1199-1200: `bool` and IEC's eight integer widths are logex's types: `sint int dint lint`, signed in two's complement, and `usint uint udint ulint`, unsigned, of 8, 16, 32 and 64 bits, IEC's words lowercased. (Stale as "logex's types": the README goes on to bit strings, reals and arrays.)
- 1201-1202: each is declared wherever a dint is: a tag of any section, a block's member, a global, located or not.
- 1202-1203: every value a host, a device or a force gives one is checked against its range.
- 1203-1205: a mistake is told the range of its width, signed or unsigned: "128 is outside -128 to 127", "-1 is outside 0 to 255".
- 1206: `move` works in its destination's type.
- 1206-1207: a source moves in where IEC's Figure 11 widens it: every value of it is a value of the destination.
- 1207-1208: so a `uint` moves into a `dint`, a `usint` into an `int`.
- 1208-1209: never signed into unsigned, nor unsigned into a signed type of its own width, nor anything into a narrower type.
- 1209-1210: every other pair is refused, naming the conversion that does it (`` so convert it with `dint_to_uint` ``, 1191).
- 1210: a bool and an integer have no conversion (message at 1193).
- 1192 (shown): a literal moved must be a value of the destination's type: `` `move` writes `70000` into `hz`, a uint: it is outside 0 to 65535 ``.
- 1211-1212: there are 56 conversions, `<from>_to_<to>` for every ordered pair of two widths; they are the one way a value narrows or changes sign.
- 1212-1213: where the value fits, it is written and the instruction passes power.
- 1213-1215: where it does not, its low bits are kept (129 becomes −127 in an `sint`, as Logix's truncation gives), no power passes, and there is no fault.
- 1215-1217: a conversion's source may be of any type that widens into the one its name reads (`dint_to_int` takes an `sint` or a `usint`).
- 1217-1218: its destination is exactly the type its name writes.
- 1218-1219: a conversion of a literal compiles with the warning an all-literal `add` draws: its result never changes.
- 1220-1221: a `cal`'s operands and a configuration's connections widen as `move` does, an output into a wider tag or global.
- 1221-1222: a `var_external` is its global, so it binds only to one of exactly its type.
- 1222-1223: an online edit that changes a tag's width is refused until a restart.
- 1223: an online edit that changes a tag's initial value is reported.
- 1224: the arithmetic works as `move` does, in its destination's type.
- 1224-1226: `add hz hz twice` adds two `uint`s in a `uint`; 65535 doubled wraps to 65534 with no power.
- 1227-1229: a source widens into the destination's type where Figure 11 lets it (`add hz level speed` computes a `uint` and a `dint` in the `dint`).
- 1229: any other source is refused naming its conversion (message at 1194).
- 1229-1230: since the computation is the destination's, two `int`s added into a `dint` cannot overflow.
- 1230-1232: IEC's overloaded `INT + INT` and Siemens's `INT#1 + 50000` compute in the narrower type, so a program ported from those that counted on the narrow overflow behaves differently.
- 1232-1233: `neg` into an unsigned type is refused.
- 1233-1234: the refusal names the narrowest signed type its source widens into, to declare instead (message at 1195).
- 1234-1235: `div` and `mod` keep their zero divisor and their sign rules at every width.
- 1236-1237: a comparison reads two integers of any widths by value, exactly.
- 1237-1238: so an `sint` −1 is less than a `udint` 0, and a `ulint`'s top is greater than a `lint`'s.
- 1238-1240: a literal compared with a tag must be a value of the tag's type; `lt hz 70000` with a `uint` `hz` is refused (message at 1196).
- 1241: a comparison of two literals compiles, with the warning that the result never changes.
- 1242-1243: the seven type words (`sint int lint usint uint udint ulint`) are reserved in any case in every `.ld` and `.logex` file, so a tag or a global named `int` stops compiling.
- 1243-1244: the 56 conversion mnemonics are reserved in every `.ld` file.
- 1191-1196: six diagnostic texts, each a rule's exact wording; copy them whole into reference/diagnostics-and-warnings.

**Citations.**

- 1200: decisions 144 and 145 (the eight widths).
- 1205: decision 177 (range messages).
- 1206: decision 147 (`move` in its destination's type).
- 1207, 1227: IEC's Figure 11 (the widening figure; no clause or edition given here).
- 1212: decision 148 (the 56 conversions).
- 1217: decision 176 (a conversion's source may widen).
- 1219: decision 178 (the literal-conversion warning).
- 1222: decision 159 (`cal`, connections, `var_external`).
- 1223: decision 157 (edits of width and of initial value).
- 1224: decision 147 again; 1226-1227: decision 146 (wrap).
- 1233: decision 145 (`neg` into unsigned refused); 1234: decision 181 (naming the signed type).
- 1236: decision 147; 1240: decision 183 (literal against a tag's type).
- 1214, 1231: vendor behaviour cited without a source here: Logix's truncation, Siemens's `INT#1 + 50000`.
- No plan items, no "provisional" marks, no links.

**Pictures.**

- The widening diagram (IEC's Figure 11 for the eight integers): the types as nodes, an arrow where `move` is allowed without a conversion (`usint` to `int`, `uint` to `dint`, and so on). This is the single most useful picture in the range: lines 1206-1210 and 1227-1229 describe a graph in words.
- A table of the eight types: word, bits, signed or not, lowest and highest value.
- A flowchart, "getting a value from type A into type B": does A widen into B? then `move`; else is there a `<a>_to_<b>`? then convert and check the power out; a bool has none.
- A before/after bit picture of `dint_to_sint` on 129: the low 8 bits kept, read as −127.
- A 8-by-8 grid of the conversions (from down the side, to across the top), the diagonal empty, to show where "56" comes from and to index the names.

**Glossary.**

- **width**: the number of bits of an integer type: 8, 16, 32 or 64 (1199-1200).
- **`sint`, `int`, `dint`, `lint`**: signed integers of 8, 16, 32 and 64 bits (1199).
- **`usint`, `uint`, `udint`, `ulint`**: unsigned integers of 8, 16, 32 and 64 bits (1200).
- **widen**: to move into a type that holds every value of the source type (1207).
- **Figure 11**: the figure of IEC 61131-3 that says which type widens into which (1207).
- **narrow**: to move into a type that does not hold every value of the source (1212).
- **conversion**: an instruction `<from>_to_<to>` that narrows or changes sign, and says by its power out whether the value fitted (1211-1215).
- **truncation**: keeping only the low bits of a value that does not fit (1214).
- **register**: a numbered word of a device (1129); plant jargon.
- **located** (global): a global bound to an I/O point (1202); defined elsewhere.
- **force**: a value an operator pins on an input (1203); defined elsewhere.
- **`var_external`**: a program's tag that is a configuration's global (1221); defined elsewhere.
- **connection**: a configuration's wire from an instance's member to a global or a value (1220); defined elsewhere.
- **overloaded** (`INT + INT`): IEC's one `ADD` that takes its type from its operands (1230).
- **mnemonic**: an instruction's short name (1243).

**Hard to read.**

1. 1199-1205: "`bool` and IEC's eight integer widths are logex's types: `sint int dint lint`, signed in two's complement, and `usint uint udint ulint`, unsigned, of 8, 16, 32 and 64 bits, IEC's words lowercased (decisions 144 and 145). Each is declared wherever a dint is, a tag of any section, a block's member, a global, located or not, and every value a host, a device or a force gives one is checked against its range, a mistake told the range of its width, signed or unsigned: "128 is outside -128 to 127", "-1 is outside 0 to 255" (decision 177)." (two sentences; the second is the hard one)
2. 1229-1235: "Since the computation is the destination's, two `int`s added into a `dint` cannot overflow, where IEC's overloaded `INT + INT` and Siemens's `INT#1 + 50000` compute in the narrower type, so a program ported from those that counted on the narrow overflow behaves differently. `neg` into an unsigned type is refused (decision 145), told the narrowest signed type its source widens into, to declare instead (decision 181), and `div` and `mod` keep their zero divisor and their sign at every width."
3. 1129-1132: "`drive.ld` — a drive card's 16-bit speed register, a `uint`, moved into the `dint` the rest of the program works in and doubled in a `uint`, with a lamp that is off when the double did not fit, and a level trimmed into an `sint`, with a lamp that is off when the level did not fit:"

---

## Notes across the range

**Totals.** 65 units. 24 suite-held example blocks: 8 file blocks (`motor.ld`, `delay.ld`,
`boxes.ld`, `stock.ld`, `line.ld`, `cure.ld`, `fill.ld`, `drive.ld`), 8 `elixir` scripts
(`scan.exs`, `delay.exs`, `boxes.exs`, `stock.exs`, `line.exs`, `cure.exs`, `fill.exs`,
`drive.exs`) and 8 `$ mix run` output blocks. 4 further unmarked text blocks (560-563,
632-634, 714-718, 722-724) that the suite does not run. No `elixir` block lacks a following
`$ mix run`, so the range holds no "fragment".

**Proposed new slug.**

- NEW `howto/port-a-program` (or a section "Differences a ported program meets" in
  explanation/the-dialect-and-iec). Why: the range holds four porting hazards that fit no
  listed page and are easy to lose: a long timer's preset unit (990-993), a `ge` ported from a
  `ton` rung (942-943, 998), counters that stop where the conventional CTUD rolls over
  (730-731), and arithmetic computed in the destination's type, not the narrower one
  (1229-1232), plus wrap against saturation (1110-1112).

**Repeated elsewhere in the README.**

- "A `ton` ends its path": lines 305 and 309 (the instruction table) as well as 629, 633, 902.
- Figure 11 widening: lines 296, 311, 314, 451, and again at 1338 and 1650.
- ENO and wrap: line 311-313 and 465 as well as 1102-1112, 1215, 1225.
- The first-scan (start-up) rule: lines 301-309 as well as 623, 699, 887; again at 1825, 2109.
- The typed counters and long timers: lines 463-464 ("What has landed") as well as 726-736, 914-919.
- The 56 conversions and the eight widths: lines 31-32, 231, 451.
- Event-task warnings (807, 908-910, 1003-1004): said again for coils at 2123, and shown in the "An event task" section (3774 on, line 3812).
- The did-you-mean message: also at 1973.

**Stale or history-flavoured wording.**

- 1199: "`bool` and IEC's eight integer widths are logex's types" was true when written; bit strings, reals and arrays follow in the same README.
- 1242: "The seven new type words" ("new" is history); 1110-1112: "Until Milestone 5 ... now wraps".
- 628-629: "is not settled" presents an open design point as a rule with no decision number.
- 917: "M5-6" is a plan item in user-facing text.

**Content that sits oddly in a tutorial flow.**

- Each example section ends with a paragraph of rules about online edits, restarts, resources and event tasks (735-736, 805-807, 895-910, 1000-1004, 1220-1223): the reader has met none of those yet at this point in the README. These go to the reference pages named in the tables and should leave only a "see also" behind.
- `fill.exs` (1054-1074) builds a full configuration and runs a cycle inside the arithmetic example, 1,600 lines before "A configuration" explains one.
