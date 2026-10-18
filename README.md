# logex

A Ladder Logic compiler and interpreter in Elixir. It compiles a ladder program written as
text into a named, stateless value, and runs it as instances, one scan at a time, with the
time the host injects. No dependencies and no generated code: the lexer and parser are
written by hand, and the whole thing is twenty-five small modules.

**Stage: early, and honest about it.** Thirty-one instructions, among them four timers,
two that run IEC's three counters, seven of integer arithmetic, a one-shot and two pulse
coils, six comparisons and a forward jump to a label, parallel branches to arbitrary
nesting depth,
latch/unlatch that holds across scans, power flow that resets per rung, a typed tag table
that every tag is declared in, function blocks of your own, each written once in a file of
its own, instantiated as often as needed and run with `cal`, a public API
(`Logex.compile/2`, `Logex.compile_file/1`, `Logex.compile_files/1` and `Logex.Runtime`),
an online edit that changes a running instance's program, its function blocks included,
without a restart (`Logex.Edit`), and one that changes a running configuration as a whole
(`Logex.Configuration.Edit`), a scheduler that runs instances of several programs as
one configuration on periodic tasks and on event tasks, which the rising edge of a bool
global makes due, wired to input and output points, its programs
sharing globals by name, such as an e-stop, through `var_external`
(`Logex.Configuration`), written as a configuration file (`.logex`) that names its `.ld`
program types or built from Elixir data, and a printer that turns an AST back into source
so a routine round-trips, as a configuration file does too — all of that works and is
tested end to end, and a program or a configuration with mistakes in it gets every one
reported with its file and line rather than an exception, a misspelt tag included. What
does not exist yet: bit access, and a real type, which `sqrt` waits for.
`PLAN.md` is a full review of the codebase and says precisely what is missing, in what
order it gets fixed, and why.

## The dialect

**logex is its own dialect. It does not aim to import vendor neutral text, and will not
become an importer.**

Source syntax today:

- declaration lines before the first rung, one tag each: `<section> <name> <type>
  [<initial>]`, the section `var`, `var_input`, `var_output` or `var_external`, the type
  `bool`, `dint`, `ton` or a function block's name, as in `var_output speed_sp dint 1200`
  or `var tare dint -120`.
  Every tag a rung uses must be declared. A `var_input` is supplied from outside and no
  instruction may write it; a tag with no initial value starts at 0. A timer, `var t1
  ton`, is declared only with `var` and with no initial value: its preset is the number on
  the `ton` that runs it. So is an instance of a function block, `var s1 seal`
- `var_external estop bool` names a configuration's global, its `var_global estop bool`
  ("A global shared by name", below): logic reads and writes the global itself, one copy
  for every instance that declares it. It is a bool or a dint, with no initial value, and
  no configuration file's keyword names one. A function block's file refuses it: a block
  takes a global through a var_input its `cal` fills. A program run alone keeps it as a
  tag of its own, at 0, which its host cannot set
- mnemonics, sections and types in any case (`xic`, `XIC`, `VAR_INPUT`), and reserved: no
  tag may be named after one, in any case, so `ote`, `Ote`, `cal` and `bool` are never
  tags; tags are case-sensitive (`aa` and `AA` are two tags). A function block's name is
  matched exactly, as a tag's is, and is not reserved
- operands separated by spaces — and a number must be followed by one: `move 1bst aa` is an
  error naming `1bst`, not the number `1` and a tag `bst`
- an integer, `5`, or a negative one, its sign glued to its digits, `-5`, with no `+`. A
  sign begins a number, so it needs a space before it too: `move 5-3 aa` is an error naming
  `5-3`, and `ote a-5` one naming `a-5`; a difference is `sub`. A literal goes in 32 bits,
  −2147483648 to 2147483647, a preset being 0 or more
- no operand parentheses, no terminator
- `//` starts a comment, which runs to the end of its line
- a name may have `.` parts: `t1.dn` is the member `dn` of the timer `t1`. A timer's
  members are `.pre` and `.acc` (dint, which logic may write) and `.dn`, `.tt` and `.en`
  (bool, which only its `ton` sets), read anywhere. A function block instance's inputs
  and outputs, `s1.run`, are read anywhere too; its own `var`s are named only inside it,
  and nothing outside it writes any of its members. Members are case-sensitive, and a
  dotted name that is not a declared member is an error. `word.3`, bit access, is
  refused for now. No tag is declared with a `.`
- a newline ends a rung: LF, CRLF or a lone CR
- `(` … `|` … `)` open, separate and close a parallel branch group
- a label, what `jmp auto` and `lbl auto` name, is a name with no `.` parts and no
  reserved word, `function_block` among them in a function block's file, and never a tag:
  it is not declared, labels are their routine's own namespace, so `lbl auto` may stand
  beside a tag `auto`, and they are case-sensitive, two that differ only in case refused
  ("A forward jump", below)
- a file whose first rung is `function_block seal`, comments and blank lines allowed
  before it, is a function block type, `seal`, named as its file is: its declarations
  are its members and its rungs its body. `Logex.compile/2` returns it as a
  `%Logex.FbType{}`. A program given it in `types:`, or compiled by
  `Logex.compile_file/1` with `seal.ld` beside it, declares instances of it and runs each
  with `cal`. In a block's file `function_block` is reserved, in any case. A block holds
  no instance of itself, at any depth
- `Logex.compile_file/1` takes a `.ld` file only, exactly: any other name is a `:file`
  diagnostic. `Logex.compile_files/1` compiles several, each as `compile_file/1` does,
  through one memo, so a block several of them hold is compiled once

A configuration file (`.logex`, "A configuration", below) has lines of its own, one
element each, its keywords in any case, `//` comments, and a line ending as a `.ld`
file's does:

- `task <name> interval <ms> priority <p>`: a periodic task, every 1 to 2147483647 ms,
  at a priority of 0, the highest, to 65535, its inputs in that order. A number out of
  range, a negative one among them, is a diagnostic at its line
- `task <name> single <global> [interval <ms>] priority <p>`: an event task, due in the
  cycle its trigger, a bool global, rises from 0 to 1, and in the first if it is already
  1; with `interval` too, also due periodically while the trigger is 0, at most once a
  cycle. `single` comes first of the three inputs, as IEC orders them
- `var_global <name> <type> [<initial>]`, a `bool` or a `dint`, and `var_global <name>
  <type> at <device>.i.<n>` or `… at <device>.q.<n>`, an input or an output point, which
  takes no initial value: the `var_global … at` lines are the plant's I/O list
- `program <instance> <type> [with <task>]`: an instance of the program type in
  `<type>.ld` beside the file, on a task or, without `with`, run in every cycle after the
  tasks
- `<instance>.<member> <global or constant>`: a connection, with no arrow, since the
  member's section fixes its direction. Every `var_input` is connected once, to a global
  of its type or a constant; a `var_output` drives a global of its type, never an input
  point, and one connection at most drives a global. Names resolve over the whole file
- `task single interval priority with program var_global at bool dint` are reserved in
  a configuration file, in any case, and nowhere else: a `.ld` program may still have a
  tag called `task` or `single`, though no `var_external`, whose name is a global's too
- a program type's `var_external` binds to the global of its name and type, checked once
  a type at its first instance's `program` line; nothing writes an input point through
  one, and no connection names one. Two instances that write one global through one, and
  an instance that writes through one a global a connection drives, are warnings

The *vocabulary* is a conventional ladder mnemonic set. The *branch delimiters used to be
too*, and are no longer — which is worth stating plainly, because the survey that found the
precedent is the same one that records giving it up.

That vendor's **current** controller family exports uppercase, parenthesised,
semicolon-terminated text and spells a branch with brackets and commas. An **earlier**
family's ASCII rung format is uppercase, space-separated and unparenthesised, and spells a
branch `BST … NXB … BND` — which, until §4·B1 landed, was logex's own line with the case
flipped and the rung delimiters dropped. Those three are that vendor's own mnemonics,
glossed in the earlier family's programming-software guide as branch start, next branch and
branch end; its controller reference bills the same three, under those spelled-out names, as
instructions with an execution time and a word of memory each. They are not a museum piece
either: the current family's software has the same per-rung text area, and these are still
what you type into it.

logex took `(` `|` `)` instead, and the reason is lexical rather than aesthetic: the three
words are drawn from the same character set as tag names, so one missing space fused `nxb`
into a neighbouring identifier and turned a parallel group into a series one with no error
anywhere. Punctuation cannot fuse. That is a deliberate divergence from a real precedent
rather than a coinage filling a gap, which is the more expensive kind — `PLAN.md` §4·B1 has
the measurements and `docs/naming.md` the survey.

Borrowing a vocabulary is still not the same as accepting a format, and logex remains a
dialect by choice: it will not grow an importer, and it takes none of that family's operand
syntax (`I:003/4`, `T4:5/DN`).

Being a dialect is a licence to choose names, not a licence to choose them carelessly. So
every new instruction is surveyed before it is written: what does IEC 61131-3 call this,
what do the major vendor toolchains call it, and what should logex call it in that light?
The survey lives in [`docs/naming.md`](docs/naming.md), one stanza per mnemonic,
declaration word, word that heads a file, `function_block`, or configuration file's word,
and
`test/logex/naming_test.exs` fails if any of them reaches the compiler without one. The
rule it applies, in order: if IEC names the operation, take the IEC name; if IEC supplies
only a graphical element, take the clearest vendor mnemonic and say which; never invent a
readable word for a thing that already has a standard name.

Two findings from that survey are worth stating up front, because they explain why the
rule has two tiers. IEC 61131-3 defines ladder contacts and coils as *graphical symbols*
with English names, not mnemonics — so for `xic` or `ote` there is no standard name to
conform to. And Edition 4.0 (2025) removed Instruction List from the standard entirely:
its Scope now reads *"This suite consists of the textual language structured text (ST),
and the graphical languages, ladder diagram (LD) and function block diagram (FBD)"*. There
is no longer any IEC textual mnemonic vocabulary at all. A mnemonic ladder language is
necessarily a dialect; the point of surveying is to know what you are diverging from.

## Instructions

| Written as | Operands | Does |
|---|---|---|
| `xic aa` | bool tag | examine if closed — passes power when `aa` is 1 |
| `xio aa` | bool tag | examine if open — passes power when `aa` is 0 |
| `ote xx` | bool tag, not a `var_input` | output energize — writes 1 on a true rung and **0 on a false rung** |
| `otl xx` | bool tag, not a `var_input` | output latch — writes 1 on a true rung, leaves the tag alone otherwise |
| `otu xx` | bool tag, not a `var_input` | output unlatch — writes 0 on a true rung, leaves the tag alone otherwise |
| `move 123 hh` | source, then a destination of the same type, not a `var_input` | copies a literal or a tag into a tag; a literal must fit the destination (`mov` until M1-2; it now gets a diagnostic pointing here) |
| `ons s1` | bool tag, the storage bit, not a `var_input` | one-shot — passes power for the one scan in which the power reaching it rises, never on an instance's first scan, nor on the first scan after an online edit that adds it or changes its rung; `s1` holds the power it saw last scan. A second `ons` on `s1` is an error, and any other write to `s1` a warning |
| `osr s1 pulse` | two bool tags it writes, each not a `var_input`: the storage bit, then the pulse bit, which may be a member logic may write | one-shot rising, IEC's positive transition-sensing coil in the conventional set's form — sets `pulse` for the one scan in which the power reaching it rises, and clears it on every other run, never on an instance's first scan, nor on the first scan after an online edit that adds it or changes its rung; `s1` holds the power it saw last run. It passes that power on, so anything may follow it on its rung. A second `ons`, `osr` or `osf` on `s1` is an error, as is `s1` for its pulse bit too, and any other write to `s1` a warning; a second coil on `pulse`, an `ote` among them, is the second-`ote` warning |
| `osf s1 pulse` | as `osr` | one-shot falling, IEC's negative transition-sensing coil — sets `pulse` for the one scan in which the power reaching it falls, which its run on the false rung sees, and is `osr` in every other rule |
| `eq a b` `ne a b` `lt a b` `gt a b` `le a b` `ge a b` | two dints, each a tag, a member or a literal | compare — pass power when `a = b`, `a ≠ b`, `a < b`, `a > b`, `a ≤ b`, `a ≥ b`; none on a false rung. Two literals are a warning |
| `ton t1 5000` | a timer, then a preset of 0 to 2147483647 ms | on-delay timer — rung power is its IN. True: `.acc` counts the milliseconds since the scan that first saw the rung true, up to `.pre`, where `.dn` is set. False: the timer resets. The preset is where `.pre` starts, when the instance starts or restarts; a `move` into `.pre` holds until then. An online edit that changes the preset moves `.pre` to it where `.pre` still holds the old one, and keeps a `.pre` that logic changed. One `ton` runs a timer, and nothing may follow it on its path: read it with `xic t1.dn` on a rung below |
| `tof run_on 30000` | an off-delay timer (`var run_on tof`), then a preset in ms | off-delay timer, IEC's TOF — rung power is its IN. True: `.dn` set, `.acc` 0. The first false scan starts the delay, and `.dn` stays set until `.acc` reaches `.pre`, then drops; a true rung during the delay ends it with `.dn` still set. A new or restarted one is at rest, `.dn` 0. Read it with `xic run_on.dn` on a rung below |
| `tp horn_pulse 3000` | a pulse timer (`var horn_pulse tp`), then a preset in ms | pulse timer, IEC's TP — a rising edge of its rung, never on an instance's first scan, starts a pulse on `.tt` exactly `.pre` long, whatever the rung does meanwhile, an edge during it ignored; `.dn` is set as the pulse ends and holds while the rung does. Read the pulse with `xic horn_pulse.tt` on a rung below |
| `rto lube 360000000` | a retentive timer (`var lube rto`), then a preset in ms | retentive on-delay timer, the conventional RTO — true, it times as `ton`; false, it keeps `.acc` and `.dn`, so its time adds up across the rung's drops. Its reset `.r`, an input a rung writes, `xic greased ote lube.r`, puts `.acc`, `.dn` and `.tt` to 0 at its next run; every restart, warm or cold, starts it at 0. Logic writes `.pre`, `.acc` and `.r` |
| `ctu boxes 12` | an up counter (`var boxes ctu`) or an up-down one (`ctud`), then a preset of 0 to 2147483647 | count up — rung power is the counter's count input `cu`. Each rising edge adds one to `.cv`, never on an instance's first scan, and `.q` is `.cv >= .pv`. Its reset `.r`, an input a rung writes, as `xic reset_pb ote boxes.r`, puts `.cv` to 0 at the counter's next run, and keeps its memory of `cu`, so a box on the eye at a reset is not counted again. At 2147483647 the count stops and `.ov` stays on until a reset. The preset is where `.pv` starts; logic writes only `.r` and `.pv`, and a `ctud`'s `.ld`. One `ctu` runs a counter, and nothing may follow it on its path: read it with `xic boxes.q` on a rung below |
| `ctd hopper 40` | a down counter (`var hopper ctd`) or an up-down one, then a preset | count down — rung power is `cd`. Its load `.ld` puts `.cv` to `.pv`; each rising edge takes one away, stopping at −2147483648 with `.un` on until a load; `.q` is `.cv <= 0`. A `ctud`, `var stock ctud`, is run by one `ctu` and one `ctd` on two rungs, with one preset, and has `.r` and `.ld`, `.qu` at `.cv >= .pv` and `.qd` at `.cv <= 0` |
| `add a b dst` `sub a b dst` `mul a b dst` | two dints, each a tag, a member or a literal, then a dint tag or member it writes, not a `var_input` | add, subtract (`a − b`), multiply — true: writes the result and passes power; a result outside a dint stops at the nearer limit, −2147483648 or 2147483647, and passes no power on that scan. False: writes nothing, passes no power. The sources are read first, so `add total flow total` runs a total on. Anything may follow on the rung: its power out is IEC's ENO |
| `div a b dst` `mod a b dst` | as `add` | divide, truncated toward zero (`div -7 2 q` is −3), and IEC's remainder, its sign the dividend's (`mod -7 3 r` is −1). A zero divisor writes 0, passes no power and is a minor fault the scan reports, `state.faults` or a cycle's `{:fault, task, instance, fault}` event; a literal 0 divisor is refused. `div -2147483648 -1` stops at the top, with no power |
| `neg a dst` `abs a dst` | a dint, a tag, a member or a literal, then a dint it writes | negate, absolute value — as `add`, one source: −2147483648 has no positive twin, so each gives 2147483647 for it, with no power |
| `cal s1 a b q` | an instance of a function block, then a value for each of its var_inputs (a tag, a member or a literal of its type) and a tag for each of its var_outputs, which it writes, so not a `var_input`, in the block's declaration order | runs the instance: rung power is its EN, and passes on. True: copies `a` and `b` in, runs the block's rungs over the instance's state and copies its outputs out to `q`. False: copies nothing in or out and runs nothing, so the instance and `q` are frozen; a timer inside catches up when the block next runs. One `cal` runs an instance, and a `ton` is run by its `ton`, never by `cal` |
| `jmp auto` | a label, a name declared nowhere | jump — true: once the rest of its rung has run, skips the rungs after its own up to the one `lbl auto` heads, which runs, and passes on the power it receives, so anything may follow it. False: skips nothing and passes no power. The label is on a later rung of the same routine: a jump back or to its own rung is refused, and a rung holds one `jmp`. A skipped rung runs nothing, so its coils hold and its counters, one-shots and timers are frozen, as in a block whose `cal` is false, a timer catching up when it next runs |
| `lbl auto` | a label | label — first on its rung, which it names as a jump's target, and passes on the power it receives. A label names one rung of its routine, a block's body its own, and a label no `jmp` names is a warning |
| `( … \| … )` | — | parallel branch group: the legs OR together, and every leg runs |

Each instruction's operands are checked against this table and against their tags'
declarations, and every mistake in a routine's declarations and instructions is reported
with its line, in line order. A lex or parse error
still stops at the first, before any instruction is checked. With `src` declared, `move
src ote` gives two, because `move` runs out of operands at an instruction and `ote` then
has none of its own:

```
line 2: `move` expects 2 operands (a value, then a tag), found 1 before the instruction `ote`
line 2: `ote` expects 1 operand (a tag), found none
```

A tag an instruction writes may be a `var_external`: the write is to its global, which a
configuration refuses where that global is an input point.

Two behaviours that are deliberate rather than accidental: branches do **not**
short-circuit, so a later leg's `ote` and `move` still take effect after an earlier leg is
already true; and the environment threads through the legs in order, so a leg can see what
an earlier leg wrote. Both match how a real controller scans a rung.

`xic` and `xio` are complementary by construction: whatever a tag holds, exactly one of
them passes power. The compiler lets only a `bool` reach either, but an env built by hand
rather than by `Logex.Program.initial_env/1` can still hold a 5, a `false` or leave a tag
out, so evaluation settles it: a number reads by value, nonzero closed (so `0.0` is open);
a boolean reads as itself; `nil` and a missing tag are open; anything else is closed. That
totality is a guarantee, not a feature to write programs against (`PLAN.md` §5).

### Settled, not yet landed

These are decided (see [`docs/naming.md`](docs/naming.md), and `PLAN.md` §5) and will
change the source language. Program organisation, `PLAN.md`'s Milestone 2, has landed
whole ("A function block" and "A configuration", below):
- **Bit access** with `.` (`word.3`).
- **`sqrt`**, waiting for a real type. Milestone 3 (`PLAN.md` §3, decisions 67–107 in
  [`docs/organisation.md`](docs/organisation.md) §7) has otherwise landed whole: the
  counters, the other timers, integer arithmetic, the pulse coils and the forward jump
  ("A counter", "Three more timers", "Arithmetic", "Two pulse coils" and "A forward
  jump", below). IEC names wherever IEC names the operation; `neg`, `osr`, `osf`, `jmp`
  and `lbl` are rule 2's, from a vendor, `docs/naming.md` saying which. There is no
  `res`: a counter resets through its own `r` input, as IEC's does, and so does a
  retentive timer, `xic greased ote lube.r` (decision 90). Nor is there a master control
  zone, for good (decision 83).
- **The wall-clock runner**, `PLAN.md`'s Milestone 4 (decisions 108–128 in
  [`docs/organisation.md`](docs/organisation.md) §7, designed in its §4.11): a
  configuration file's task line will take `watchdog <ms>`, 500 ms where it has none, and
  one line may declare the continuous task, `task main continuous`, in which a program
  with no `with` runs; and `Logex.Runner` will run a configuration on the real clock
  through device adapters (`Logex.IO`), its untimed programs back to back, one round a
  clock millisecond at most, an input forced from the host staying forced across a
  restart and, kept in a file the host names, across a crash.

## An example

Neither file below is in the repository — create them to follow along.

`motor.ld` — a seal-in motor starter with a latched fault. Every tag is declared before the
first rung: what it holds (`bool` or `dint`), and whether it is supplied from outside
(`var_input`), produced for outside (`var_output`) or the program's own (`var`):

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

Rung 1 is the seal-in: `start` OR `motor` itself, AND not `stop`. Because `ote` is
non-retentive, `motor` drops out the moment `stop` closes. Rung 3 latches `fault`, which
only rung 4 can clear — that is what makes `otl`/`otu` different from `ote`. A misspelt
tag is a compile error, not a rung that silently never fires: with `xic motor ote
run_lmap`, `Logex.compile_file/1` gives
`` motor.ld: line 11: `run_lmap` is not declared — did you mean `run_lamp`? ``.

`scan.exs` — the program is compiled once, named `motor` after its file, and run as one
instance. Each step sets the inputs that changed, then scans:

```elixir
{:ok, motor} = Logex.compile_file("motor.ld")

scan = fn state, label, inputs ->
  state = Logex.Runtime.put_inputs(motor, state, inputs)
  {outputs, state} = Logex.Runtime.scan(motor, state)
  IO.puts("#{label}  #{inspect(outputs)}  fault=#{state.env["fault"]}")
  state
end

Logex.Runtime.instance(motor)
|> scan.("start pressed ", %{"start" => 1})
|> scan.("start released", %{"start" => 0})
|> scan.("overtemp      ", %{"overtemp" => 1})
|> scan.("stop pressed  ", %{"stop" => 1})
|> scan.("cooled, idle  ", %{"stop" => 0, "overtemp" => 0})
```

An instance starts with every declared tag at its initial value: 0, except `speed_sp` at
1200. A scan gives back the `var_output`s; `fault` is internal, read from the instance's
state. Five scans, because a seal-in and a latch only show across scans:

```
$ mix run scan.exs
start pressed   %{"motor" => 1, "run_lamp" => 1, "speed_sp" => 1200}  fault=0
start released  %{"motor" => 1, "run_lamp" => 1, "speed_sp" => 1200}  fault=0
overtemp        %{"motor" => 1, "run_lamp" => 1, "speed_sp" => 0}  fault=1
stop pressed    %{"motor" => 0, "run_lamp" => 0, "speed_sp" => 0}  fault=1
cooled, idle    %{"motor" => 0, "run_lamp" => 0, "speed_sp" => 0}  fault=1
```

The motor holds itself in after the start button is released, and the fault stays latched
after the overtemperature input clears.

A mistake by the host raises `ArgumentError`, with every problem in one message.
`Logex.Runtime.put_inputs(motor, state, %{"motor" => 1, "strat" => 1})` gives:

```
input `motor` is a var_output (declared on line 5), not a var_input: only a var_input is set from outside
input `strat` is not declared — did you mean `start`?
```

`scan/3` takes the milliseconds since the last scan, which a timer counts;
`Logex.Runtime.call/4` is one scan with the time given explicitly, which is what the
scheduler calls for each instance it runs ("A configuration", below); `restart/3` starts an
instance again, keeping the inputs that fit their types.

### A timer and a one-shot

`delay.ld` — a lamp that lights once `go` has been held for three seconds, and a pulse on
the scan `go` rises:

```
var_input go bool
var_output lamp bool
var_output pulse bool
var_output waited dint
var t1 ton
var s1 bool

xic go ton t1 3000
xic t1.dn ote lamp
xic go ons s1 ote pulse
move t1.acc waited
```

`delay.exs` steps it with `scan/3`, giving the milliseconds since the last scan:

```elixir
{:ok, delay} = Logex.compile_file("delay.ld")

scan = fn state, elapsed, label, inputs ->
  state = Logex.Runtime.put_inputs(delay, state, inputs)
  {outputs, state} = Logex.Runtime.scan(delay, state, elapsed)
  IO.puts("t=#{String.pad_leading("#{state.now}", 4)}  #{label}  #{inspect(outputs)}")
  state
end

Logex.Runtime.instance(delay)
|> scan.(0, "idle      ", %{})
|> scan.(100, "go on     ", %{"go" => 1})
|> scan.(1000, "held      ", %{})
|> scan.(2000, "held      ", %{})
|> scan.(500, "held      ", %{})
|> scan.(10, "go off    ", %{"go" => 0})
```

```
$ mix run delay.exs
t=   0  idle        %{"lamp" => 0, "pulse" => 0, "waited" => 0}
t= 100  go on       %{"lamp" => 0, "pulse" => 1, "waited" => 0}
t=1100  held        %{"lamp" => 0, "pulse" => 0, "waited" => 1000}
t=3100  held        %{"lamp" => 1, "pulse" => 0, "waited" => 3000}
t=3600  held        %{"lamp" => 1, "pulse" => 0, "waited" => 3000}
t=3610  go off      %{"lamp" => 0, "pulse" => 0, "waited" => 0}
```

The timer starts at the scan that first sees `go` (t=100), counts the time that passed,
not the number of scans, and stops at its preset; a false rung resets it. The one-shot
fires once per rise, and never on an instance's first scan, even with `go` already held.
The timer's members are in the instance's state, `state.env["t1"]`, a map with `pre`,
`acc`, `dn`, `tt` and `en`, and `last`, the time its `ton` last ran.

The lamp is read from `t1.dn` on a rung of its own. Whether the power after a `ton` is
the rung's or the timer's `.dn` is not settled, so nothing may follow a `ton` on its path,
and `xic go ton t1 3000 ote lamp` is refused:

```
delay.ld: line 8: `ote lamp` follows `ton t1` on its path: what passes on after a `ton` is not settled, so a `ton` ends its path; read the timer with `xic t1.dn` on a rung below
```

### A counter

`boxes.ld` — a box counter on a conveyor: a photo-eye adds one for each box, the
case-full lamp lights at three, and a button resets the count for the next case:

```
var_input eye bool
var_input reset_pb bool
var_output full_lamp bool
var_output count dint
var boxes ctu

xic reset_pb ote boxes.r
xic eye ctu boxes 3
xic boxes.q ote full_lamp
move boxes.cv count
```

`boxes.exs` scans it once per line, 10 ms apart:

```elixir
{:ok, boxes} = Logex.compile_file("boxes.ld")

scan = fn state, label, inputs ->
  state = Logex.Runtime.put_inputs(boxes, state, inputs)
  {outputs, state} = Logex.Runtime.scan(boxes, state, 10)
  IO.puts("#{label}  #{inspect(outputs)}")
  state
end

Logex.Runtime.instance(boxes)
|> scan.("box on the eye at start", %{"eye" => 1})
|> scan.("eye clear              ", %{"eye" => 0})
|> scan.("box 1                  ", %{"eye" => 1})
|> scan.("still box 1            ", %{})
|> scan.("eye clear              ", %{"eye" => 0})
|> scan.("box 2                  ", %{"eye" => 1})
|> scan.("eye clear              ", %{"eye" => 0})
|> scan.("box 3                  ", %{"eye" => 1})
|> scan.("reset, box on the eye  ", %{"reset_pb" => 1})
|> scan.("reset let go           ", %{"reset_pb" => 0})
|> scan.("eye clear              ", %{"eye" => 0})
|> scan.("box 1 of the next case ", %{"eye" => 1})
```

```
$ mix run boxes.exs
box on the eye at start  %{"count" => 0, "full_lamp" => 0}
eye clear                %{"count" => 0, "full_lamp" => 0}
box 1                    %{"count" => 1, "full_lamp" => 0}
still box 1              %{"count" => 1, "full_lamp" => 0}
eye clear                %{"count" => 1, "full_lamp" => 0}
box 2                    %{"count" => 2, "full_lamp" => 0}
eye clear                %{"count" => 2, "full_lamp" => 0}
box 3                    %{"count" => 3, "full_lamp" => 1}
reset, box on the eye    %{"count" => 0, "full_lamp" => 0}
reset let go             %{"count" => 0, "full_lamp" => 0}
eye clear                %{"count" => 0, "full_lamp" => 0}
box 1 of the next case   %{"count" => 1, "full_lamp" => 0}
```

The counter counts rising edges of its rung, never while the eye stays blocked and never
on the first scan, so the box already on the eye at start is not counted. Its reset is its
`r` input, which the reset rung writes as any rung writes a bit: IEC drives a counter by
its pins, a pin written before the counter's rung taking effect at its next run. A reset
leaves the counter's memory of its eye alone, so the box still on the eye when the button
was pressed is not counted again in the next case: the next box is box 1. The counter's
members are IEC's, lowercased, in `state.env["boxes"]`: `cu`, `r` and `pv` its inputs, `q`
and `cv` its outputs, and `ov`, set where a count would pass 2147483647, which then stops
there until a reset. Logic writes only `r` and `pv`.

A down counter, `var hopper ctd`, is IEC's CTD: its load, `ld`, puts `cv` to its preset,
each portion takes one away, and its `q` is on at 0. A new one starts empty, as IEC's
does: its `cv` is 0, and its `q` already on, until its first load. An up-down counter, `var stock ctud`,
is run by a `ctu` on one rung and a `ctd` on another, as a buffer table's infeed and
outfeed eyes, with `r` and `ld` both:

```
xic infeed ctu stock 50
xic outfeed ctd stock 50
xic stock.qu ote buffer_full
```

A `ctd` on an up counter is refused, with what to declare instead:

```
line 8: `ctd` runs a ctd or a ctud, but `boxes` is a ctu (declared on line 5): a ctu only counts up; declare it `var boxes ctud` to count both ways
```

A counter in a function block whose `cal` is false is frozen with the rest of the block:
a box that passes the eye while it is frozen is not counted. A counter under an event
task is a configuration warning, since it sees its rung only when the task runs.

### Three more timers

`line.ld` — a fan that runs on after the motor stops, a horn pulsed on a fault, and a
lubrication timer that adds up the motor's running time, each with a preset of a few
scans so the run is short:

```
var_input motor bool
var_input fault bool
var_input greased bool
var_output fan bool
var_output horn bool
var_output grease_due bool
var_output run_ms dint
var run_on tof
var horn_pulse tp
var lube rto

xic motor tof run_on 30
xic run_on.dn ote fan
xic fault tp horn_pulse 30
xic horn_pulse.tt ote horn
xic greased ote lube.r
xic motor rto lube 50
xic lube.dn ote grease_due
move lube.acc run_ms
```

`line.exs` scans it once per line, 10 ms apart:

```elixir
{:ok, line} = Logex.compile_file("line.ld")

scan = fn state, label, inputs ->
  state = Logex.Runtime.put_inputs(line, state, inputs)
  {outputs, state} = Logex.Runtime.scan(line, state, 10)
  IO.puts("#{label}  #{inspect(outputs)}")
  state
end

Logex.Runtime.instance(line)
|> scan.("fault at start, motor on", %{"fault" => 1, "motor" => 1})
|> scan.("motor runs              ", %{})
|> scan.("motor stops, fault clear", %{"motor" => 0, "fault" => 0})
|> scan.("run-on                  ", %{})
|> scan.("fault                   ", %{"fault" => 1})
|> scan.("run-on over, fault clear", %{"fault" => 0})
|> scan.("fault again, ignored    ", %{"fault" => 1})
|> scan.("pulse over, motor on    ", %{"motor" => 1})
|> scan.("motor runs              ", %{})
|> scan.("motor runs              ", %{})
|> scan.("motor runs              ", %{})
|> scan.("motor runs: greasing due", %{})
|> scan.("greased                 ", %{"greased" => 1})
|> scan.("greased let go          ", %{"greased" => 0})
```

```
$ mix run line.exs
fault at start, motor on  %{"fan" => 1, "grease_due" => 0, "horn" => 0, "run_ms" => 0}
motor runs                %{"fan" => 1, "grease_due" => 0, "horn" => 0, "run_ms" => 10}
motor stops, fault clear  %{"fan" => 1, "grease_due" => 0, "horn" => 0, "run_ms" => 10}
run-on                    %{"fan" => 1, "grease_due" => 0, "horn" => 0, "run_ms" => 10}
fault                     %{"fan" => 1, "grease_due" => 0, "horn" => 1, "run_ms" => 10}
run-on over, fault clear  %{"fan" => 0, "grease_due" => 0, "horn" => 1, "run_ms" => 10}
fault again, ignored      %{"fan" => 0, "grease_due" => 0, "horn" => 1, "run_ms" => 10}
pulse over, motor on      %{"fan" => 1, "grease_due" => 0, "horn" => 0, "run_ms" => 10}
motor runs                %{"fan" => 1, "grease_due" => 0, "horn" => 0, "run_ms" => 20}
motor runs                %{"fan" => 1, "grease_due" => 0, "horn" => 0, "run_ms" => 30}
motor runs                %{"fan" => 1, "grease_due" => 0, "horn" => 0, "run_ms" => 40}
motor runs: greasing due  %{"fan" => 1, "grease_due" => 1, "horn" => 0, "run_ms" => 50}
greased                   %{"fan" => 1, "grease_due" => 0, "horn" => 0, "run_ms" => 0}
greased let go            %{"fan" => 1, "grease_due" => 0, "horn" => 0, "run_ms" => 10}
```

The `tof` holds `fan` on through its 30 ms run-on after the motor stops, and drops it at
30 ms after the scan that saw the motor stop; `.dn` is IEC's Q, on while the rung is true and through the delay. The
`tp` gives no pulse for the fault present at start, by the start-up rule every
edge-driven instruction keeps, and the fault at 50 ms sounds the horn for exactly 30 ms,
`.tt` its pulse, though the fault clears and comes back meanwhile: an edge during a pulse
starts nothing. Its `.dn` comes on as the pulse ends, while the rung holds. The `rto`
keeps its 10 ms while the motor is stopped and adds to it when it runs again, from the
scan after the motor starts again, as a `ton` adds nothing on the scan that first sees its rung
true; `grease_due` lights at its 50 ms, and its reset input `r`, written by the
`greased` rung above it, clears it, the time counting again from the last scan that saw
the reset. A restart, warm or cold, starts it at 0 too, until `retain` lands.

Each is a timer by every rule a `ton` keeps: one instruction runs it, nothing may follow
it on its path, logic may move into `.pre` and `.acc`, and a `ton` made a `tof` is a
change of type, which an online edit refuses. An edit that moves a preset
forecasts each by its own rule: a `tof`'s `.dn` dropping during its delay, or at the
motor's stop where its preset goes to 0 while the motor runs, a `tp`'s pulse
ending, an `rto`'s `.dn` at its next run with its rung true. A `tp` an edit adds while its
fault is present sounds no horn at the switch. Under an event task each is a
configuration warning in its own words: a `tof`'s delay and a `tp`'s pulse end only when
the task next runs.

### Arithmetic

`fill.ld` — a fill valve: each scan adds the meter's flow to a running total, `ge` closes
the valve once the total reaches the setpoint, a lamp shows the total is still real, and
the flow per minute is worked out from the minutes run:

```
var_input flow dint
var_input setpoint dint
var_input minutes dint
var_output valve bool
var_output total dint
var_output total_ok bool
var_output per_minute dint
var full bool

add total flow total ote total_ok
ge total setpoint ote full
xio full ote valve
div total minutes per_minute
```

`fill.exs` scans it once per line, 100 ms apart, printing each scan's faults under it,
then runs it under a configuration for one cycle and prints the events:

```elixir
{:ok, fill} = Logex.compile_file("fill.ld")

scan = fn state, label, inputs ->
  state = Logex.Runtime.put_inputs(fill, state, inputs)
  {outputs, state} = Logex.Runtime.scan(fill, state, 100)
  IO.puts("#{label}  #{inspect(outputs)}")
  for fault <- state.faults, do: IO.puts("    #{inspect(fault)}")
  state
end

Logex.Runtime.instance(fill)
|> scan.("400 in, no minutes yet", %{"flow" => 400, "setpoint" => 1000})
|> scan.("a minute in           ", %{"minutes" => 1})
|> scan.("past the setpoint     ", %{"minutes" => 2})
|> scan.("a meter gone wild     ", %{"flow" => 2_147_483_000})
|> scan.("still wild            ", %{})
|> scan.("a backflow of 5       ", %{"flow" => -5})

config =
  Logex.Configuration.new!(
    name: "plant",
    programs: [fill],
    tasks: [%Logex.Configuration.Task{name: "fill", interval: 100, priority: 1}],
    globals: [
      %Logex.Configuration.Global{name: "flow", type: :dint, at: "meter.i.0"},
      %Logex.Configuration.Global{name: "valve", type: :bool, at: "panel.q.0"}
    ],
    instances: [%Logex.Configuration.Instance{name: "f1", type: "fill", task: "fill"}],
    connections: [
      %Logex.Configuration.Connection{instance: "f1", member: "flow", to: "flow"},
      %Logex.Configuration.Connection{instance: "f1", member: "setpoint", to: 1000},
      %Logex.Configuration.Connection{instance: "f1", member: "minutes", to: 0},
      %Logex.Configuration.Connection{instance: "f1", member: "valve", to: "valve"}
    ]
  )

{_rt, outputs, events} = Logex.Runtime.cycle(Logex.Runtime.start(config), 0, %{"flow" => 400})
IO.puts("a cycle: #{inspect(outputs)}")
for event <- events, do: IO.puts("    #{inspect(event)}")

{:error, [diagnostic]} =
  Logex.compile("var_input total dint\nvar_output rate dint\ndiv total 0 rate", name: "rate")

IO.puts(Logex.Diagnostic.format(diagnostic))

{:error, [diagnostic]} = Logex.compile("var_output x dint\nmove 5-3 x", name: "minus")
IO.puts(Logex.Diagnostic.format(diagnostic))
```

```
$ mix run fill.exs
400 in, no minutes yet  %{"per_minute" => 0, "total" => 400, "total_ok" => 1, "valve" => 1}
    %Logex.Fault{kind: :divide_by_zero, instruction: :div, path: nil, file: "fill.ld", line: 13}
a minute in             %{"per_minute" => 800, "total" => 800, "total_ok" => 1, "valve" => 1}
past the setpoint       %{"per_minute" => 600, "total" => 1200, "total_ok" => 1, "valve" => 0}
a meter gone wild       %{"per_minute" => 1073741823, "total" => 2147483647, "total_ok" => 0, "valve" => 0}
still wild              %{"per_minute" => 1073741823, "total" => 2147483647, "total_ok" => 0, "valve" => 0}
a backflow of 5         %{"per_minute" => 1073741821, "total" => 2147483642, "total_ok" => 1, "valve" => 0}
a cycle: %{"valve" => 1}
    {:ran, "fill", "f1", 0}
    {:fault, "fill", "f1", %Logex.Fault{kind: :divide_by_zero, instruction: :div, path: nil, file: "fill.ld", line: 13}}
line 3: `div` divides by the literal `0`: a zero divisor gives 0 and passes no power on every scan, so a literal one is refused
line 2, column 6: missing separator before `-`: "5-3" is neither a tag nor a number, and a sign begins a number
```

- `add total flow total` reads its sources before it writes, so the total runs on from
  scan to scan. Each arithmetic instruction's power out is IEC's ENO: true when its
  result is a dint's, so anything may follow it on its rung, here the `ote total_ok`.
- A result outside a dint stops at the nearer limit, −2147483648 or 2147483647, and on
  that scan the instruction passes no power: the wild meter's total stops at the top and
  `total_ok` goes off, so no total ever jumps to a huge negative number, and none outside
  a dint reaches a state. It comes back in with the next flow that brings it in.
- A zero divisor, the minutes at start-up, gives 0 and no power on that scan, and is a
  minor fault the scan reports: a lone instance's `state.faults` is every
  `%Logex.Fault{}` of the scan that returned it, `[]` for none, and a cycle gives each as
  an event just after its scan's `{:ran, ...}`, naming the task and the instance. The
  fault names the instruction, the file and the line, and `path`, the block instance it
  ran in for one inside a function block. The plant runs on.
- `div` truncates toward zero, as IEC's does, so `div -7 2 q` is −3, and `mod` is the
  remainder IEC defines, its sign the dividend's: `mod -7 3 r` is −1. `neg` and `abs` of
  −2147483648 overflow, giving 2147483647 and no power, as `div -2147483648 -1` does.
- A literal zero divisor is refused when the program compiles. A negative literal is its
  sign glued to its digits, `-5`, wherever a literal goes, and a sign begins a number, so
  `5-3` is an error rather than a number and then another: a difference is `sub`.

### Two pulse coils

`step.ld` — a start button that steps a sequence once a press, while a lamp on the same
rung shows the button held, and a pulse when a box leaves a photo-eye:

```
var_input start_pb bool
var_input eye bool
var_output step bool
var_output held_lamp bool
var_output box_left bool
var_output step_no dint
var s1 bool
var s2 bool

xic start_pb osr s1 step ote held_lamp
xic step add step_no 1 step_no
xic eye osf s2 box_left
```

`step.exs` scans it once per line, 10 ms apart:

```elixir
{:ok, step} = Logex.compile_file("step.ld")

scan = fn state, label, inputs ->
  state = Logex.Runtime.put_inputs(step, state, inputs)
  {outputs, state} = Logex.Runtime.scan(step, state, 10)
  IO.puts("#{label}  #{inspect(outputs)}")
  state
end

Logex.Runtime.instance(step)
|> scan.("start held at start", %{"start_pb" => 1})
|> scan.("start released     ", %{"start_pb" => 0})
|> scan.("start pressed      ", %{"start_pb" => 1})
|> scan.("still held         ", %{})
|> scan.("box on the eye     ", %{"eye" => 1})
|> scan.("start released     ", %{"start_pb" => 0})
|> scan.("box left the eye   ", %{"eye" => 0})
|> scan.("start pressed      ", %{"start_pb" => 1})
|> scan.("nothing new        ", %{})

{:error, [diagnostic]} =
  Logex.compile("var_input start_pb bool\nvar s1 bool\nxic start_pb osr s1 s1", name: "same")

IO.puts(Logex.Diagnostic.format(diagnostic))
```

```
$ mix run step.exs
start held at start  %{"box_left" => 0, "held_lamp" => 1, "step" => 0, "step_no" => 0}
start released       %{"box_left" => 0, "held_lamp" => 0, "step" => 0, "step_no" => 0}
start pressed        %{"box_left" => 0, "held_lamp" => 1, "step" => 1, "step_no" => 1}
still held           %{"box_left" => 0, "held_lamp" => 1, "step" => 0, "step_no" => 1}
box on the eye       %{"box_left" => 0, "held_lamp" => 1, "step" => 0, "step_no" => 1}
start released       %{"box_left" => 0, "held_lamp" => 0, "step" => 0, "step_no" => 1}
box left the eye     %{"box_left" => 1, "held_lamp" => 0, "step" => 0, "step_no" => 1}
start pressed        %{"box_left" => 0, "held_lamp" => 1, "step" => 1, "step_no" => 2}
nothing new          %{"box_left" => 0, "held_lamp" => 1, "step" => 0, "step_no" => 2}
line 3: `s1` is both the storage bit and the pulse bit of this `osr`: its pulse bit is another tag, which it sets for one scan on an edge
```

- `osr` is IEC's positive transition-sensing coil, in the form the conventional set
  writes it: `s1`, its storage bit, holds the power the coil received when it last ran,
  and `step`, its pulse bit, is set for the one scan in which that power rises, and
  cleared at every other. The sequence steps once a press, however long the button is
  held. `osf` is the negative one: `box_left` is set for the scan in which the eye
  clears, which its run on the false rung sees.
- Each passes on the power it receives, as a coil does in IEC and in the conventional set,
  so anything may follow it on its rung: `held_lamp` follows the button, not the pulse.
  That is what parts them from `ons`, which passes the pulse itself, so that the rest of
  its rung sees one scan only.
- Neither pulses on an instance's first scan, whatever its storage bit holds, so a button
  already held at start steps nothing, as an `ons` fires nothing then. That scan is the
  instance's: a coil in a function block whose `cal` is first true later reads its storage
  bit as declared at the block's first run, so a button held since start steps once
  there, as an `ons` fires, and an `osf` whose storage bit is declared 1 pulses on a false
  rung, a fall that never happened.
- A storage bit is under every rule an `ons`'s is: a second `ons`, `osr` or `osf` on it is
  an error, any other write to it a warning, and an online edit that adds a coil or
  changes its rung blocks its next pulse until a scan runs it, so an edit never makes a
  pulse no edge made ("Changing a running program", below). Its storage bit is never its
  pulse bit, which may be any bool logic writes, a counter's reset `boxes.r` among them,
  and a second coil on one pulse bit, an `ote` among them, is the second-`ote` warning.
- A coil in a function block whose `cal` is false is frozen with the rest of the block,
  both its bits held, so a pulse it gave on the block's last run stays on until it next
  runs. A coil under an event task is a configuration warning in its own words, as an
  `ons` is ("An event task", below): it sees its rung only when the task runs, and the
  pulse it sets stays on until the task next runs.

### A forward jump

`jog.ld` — a conveyor that runs on `run_pb` in auto and is jogged on a button in manual,
with a lamp that shows the button held and another once it has been held for three
seconds. While the line is in auto, a `jmp` skips the manual section:

```
var_input manual bool
var_input jog_pb bool
var_input run_pb bool
var_output auto_lamp bool
var_output jog_lamp bool
var_output jog_long bool
var_output motor bool
var jog_t ton

// in auto, jump over the manual section
xio manual jmp auto ote auto_lamp
xic jog_pb ote jog_lamp
xic jog_pb ton jog_t 3000
xic jog_t.dn ote jog_long
lbl auto ( xic run_pb xio manual | xic manual xic jog_pb ) ote motor
```

`jog.exs` steps it as `delay.exs` does, printing the timer's `.acc` too, and then compiles
a jump back:

```elixir
{:ok, jog} = Logex.compile_file("jog.ld")

scan = fn state, elapsed, label, inputs ->
  state = Logex.Runtime.put_inputs(jog, state, inputs)
  {outputs, state} = Logex.Runtime.scan(jog, state, elapsed)
  acc = state.env["jog_t"]["acc"]
  IO.puts("t=#{String.pad_leading("#{state.now}", 4)}  #{label}  #{inspect(outputs)}  acc=#{acc}")
  state
end

Logex.Runtime.instance(jog)
|> scan.(0, "auto, run on       ", %{"run_pb" => 1})
|> scan.(100, "manual             ", %{"manual" => 1})
|> scan.(100, "jog pressed        ", %{"jog_pb" => 1})
|> scan.(1000, "jog held           ", %{})
|> scan.(100, "auto, jog held     ", %{"manual" => 0})
|> scan.(100, "jog let go in auto ", %{"jog_pb" => 0})
|> scan.(2000, "auto               ", %{})
|> scan.(100, "manual, jog pressed", %{"manual" => 1, "jog_pb" => 1})
|> scan.(100, "jog let go         ", %{"jog_pb" => 0})

{:error, [diagnostic]} =
  Logex.compile("var_input a bool\nvar_output b bool\nlbl top xic a ote b\nxic a jmp top",
    name: "loop"
  )

IO.puts(Logex.Diagnostic.format(diagnostic))
```

```
$ mix run jog.exs
t=   0  auto, run on         %{"auto_lamp" => 1, "jog_lamp" => 0, "jog_long" => 0, "motor" => 1}  acc=0
t= 100  manual               %{"auto_lamp" => 0, "jog_lamp" => 0, "jog_long" => 0, "motor" => 0}  acc=0
t= 200  jog pressed          %{"auto_lamp" => 0, "jog_lamp" => 1, "jog_long" => 0, "motor" => 1}  acc=0
t=1200  jog held             %{"auto_lamp" => 0, "jog_lamp" => 1, "jog_long" => 0, "motor" => 1}  acc=1000
t=1300  auto, jog held       %{"auto_lamp" => 1, "jog_lamp" => 1, "jog_long" => 0, "motor" => 1}  acc=1000
t=1400  jog let go in auto   %{"auto_lamp" => 1, "jog_lamp" => 1, "jog_long" => 0, "motor" => 1}  acc=1000
t=3400  auto                 %{"auto_lamp" => 1, "jog_lamp" => 1, "jog_long" => 0, "motor" => 1}  acc=1000
t=3500  manual, jog pressed  %{"auto_lamp" => 0, "jog_lamp" => 1, "jog_long" => 1, "motor" => 1}  acc=3000
t=3600  jog let go           %{"auto_lamp" => 0, "jog_lamp" => 0, "jog_long" => 0, "motor" => 0}  acc=0
line 4: `jmp top` jumps back, to the rung on line 3: a jump goes forward only, to a label on a later rung, since one back could loop for ever
```

- `jmp auto` is IEC's jump to a network label, in the conventional set's words. On a true
  rung it skips the rungs after its own up to the one `lbl auto` heads, which runs; on a
  false rung it does nothing. The jump is taken once its own rung is done, and `jmp`
  passes on the power it receives, so the `ote auto_lamp` after it lights while the line
  is in auto (decision 104). `lbl` stands first on its rung and passes on the power it
  receives.
- A skipped rung runs nothing, so the section is frozen as a block whose `cal` is false
  is (decision 82). The `ote` of `jog_lamp` writes neither 1 nor 0 while the line is in
  auto, so the lamp stays lit though the button was let go at t=1400. The timer keeps its
  `.acc` while it is skipped, and catches up when it next runs, as a frozen block's does:
  `jog_t` never saw the button let go, and its first run back in manual, at t=3500, counts
  the 2.3 s since it last ran, so `jog_long` lights at once. A counter or a one-shot on a
  skipped rung keeps its memory of its rung, so an edge that comes and goes while it is
  skipped is never counted, and a zero divisor there is no fault, since its `div` never
  runs.
- A jump goes forward only, so a scan stays one pass over the rungs: a jump back, or to
  its own rung, is refused, since either could loop for ever (decision 81). So is a `jmp`
  to a label its routine does not have, the nearest on a later rung suggested, a `lbl`
  not first on its rung, a label on two rungs, two labels that differ only in case, and a
  second `jmp` on one rung. A label no `jmp` names is a warning.
- A label is a name of its own, not a tag, and its routine's (decision 105): a function
  block's body jumps within itself, and no `jmp` reaches into a block or out of one.
- The warnings read a rung a jump may skip as any rung, so an `ote motor` in each of two
  sections a jump makes exclusive is still the second-`ote` warning (decision 107, which
  the maintainer confirmed after M3-5's review: the checks read the program's text, not
  which rungs run): give the motor one rung that reads each mode, as `jog.ld`'s last rung
  does.
- `jmp` and `lbl` are mnemonics, reserved in any case, so a tag named `jmp` or `lbl`,
  `Jmp` or `LBL` among them, no longer compiles.

### A function block

`seal.ld` — the seal-in of `motor.ld`'s first rung, written once as a function block. Its
first rung, `function_block seal`, says what kind of file it is and names the block, as
the file is named; its declarations are the block's members, and its rungs its body:

```
// A seal-in: `run` holds itself in from `start` until `stop`.
function_block seal
var_input start bool
var_input stop bool
var_output run bool

( xic start | xic run ) xio stop ote run
```

`belts.ld` — three conveyors, each sealed in by an instance of its own, `s1` to `s3`, with
one stop button. The third runs only while `auto` is on:

```
var_input start_1 bool
var_input start_2 bool
var_input start_3 bool
var_input stop bool
var_input auto bool
var_output belt_1 bool
var_output belt_2 bool
var_output belt_3 bool
var_output all_run bool
var s1 seal
var s2 seal
var s3 seal

cal s1 start_1 stop belt_1
cal s2 start_2 stop belt_2
xic auto cal s3 start_3 stop belt_3
xic s1.run xic s2.run xic s3.run ote all_run
```

`cal s1 start_1 stop belt_1` runs `s1`: its operands fill the block's var_inputs, then its
var_outputs, in the order the block declares them, and rung power is the instance's EN.
`s1.run` reads an output from outside the block.

`belts.exs` — `Logex.compile_file/1` finds `seal.ld` beside `belts.ld`, since `seal` is no
type logex has, and compiles it first. Each scan prints the outputs and `s3`'s state:

```elixir
{:ok, belts} = Logex.compile_file("belts.ld")

scan = fn state, label, inputs ->
  state = Logex.Runtime.put_inputs(belts, state, inputs)
  {outputs, state} = Logex.Runtime.scan(belts, state, 10)
  IO.puts("#{label}  #{inspect(outputs)}  s3=#{inspect(state.env["s3"])}")
  state
end

Logex.Runtime.instance(belts)
|> scan.("start 1, auto  ", %{"start_1" => 1, "auto" => 1})
|> scan.("start 2 and 3  ", %{"start_1" => 0, "start_2" => 1, "start_3" => 1})
|> scan.("released       ", %{"start_2" => 0, "start_3" => 0})
|> scan.("auto off, stop ", %{"auto" => 0, "stop" => 1})
|> scan.("auto on        ", %{"auto" => 1})
```

```
$ mix run belts.exs
start 1, auto    %{"all_run" => 0, "belt_1" => 1, "belt_2" => 0, "belt_3" => 0}  s3=%{"run" => 0, "start" => 0, "stop" => 0}
start 2 and 3    %{"all_run" => 1, "belt_1" => 1, "belt_2" => 1, "belt_3" => 1}  s3=%{"run" => 1, "start" => 1, "stop" => 0}
released         %{"all_run" => 1, "belt_1" => 1, "belt_2" => 1, "belt_3" => 1}  s3=%{"run" => 1, "start" => 0, "stop" => 0}
auto off, stop   %{"all_run" => 0, "belt_1" => 0, "belt_2" => 0, "belt_3" => 1}  s3=%{"run" => 1, "start" => 0, "stop" => 0}
auto on          %{"all_run" => 0, "belt_1" => 0, "belt_2" => 0, "belt_3" => 0}  s3=%{"run" => 0, "start" => 0, "stop" => 1}
```

- Each instance is a seal-in of its own. Its state is a map of the block's members,
  nested in the program instance's under the instance's name, `state.env["s3"]`.
- When `auto` falls, `cal s3` has a false EN: the block's rungs do not run, and nothing is
  copied in or out, so `s3` and `belt_3` are frozen. Belt 3 runs on through the stop that
  drops the other two, and `s3` never reads `stop`. Once `auto` is back, `s3` runs, reads
  `stop` and drops out. That is IEC's rule for a false EN
  ([`docs/organisation.md`](docs/organisation.md) §4.3), and why a stop that must always
  work goes into the block, not in front of its `cal`.
- From Elixir, `Logex.compile/2` takes the block as a type:
  `Logex.compile(File.read!("seal.ld"), name: "seal")` gives `{:ok, %Logex.FbType{}}`,
  and `Logex.compile(File.read!("belts.ld"), name: "belts", types: [seal])` the program.
- In a configuration, `Logex.Runtime.get(rt, "m1.s2.run")` reads `s2`'s output in the
  instance `m1`, as `{:ok, 1}` while belt 2 runs. A block's own `var`s are hidden from
  outside it, and nothing outside it writes any of its members.

`compile_file/1` hands back the warnings of the blocks it loads after the program's own,
each with its block's file as the loader found it beside the program. Had `seal.ld`
declared a `var spare bool` on its line 6 that no rung uses,
`Enum.map(belts.warnings, &Logex.Diagnostic.format/1)` would be
``["./seal.ld: line 6: warning: `spare` is declared but no rung uses it"]``. `compile/2`,
whose caller compiled the block, gives only the program's own.

Each mistake is located in the file that holds it. A misspelt type, `var s3 sael`, is one
message: the uses of a declaration whose type is unknown are not reported again. A write
to a block's member from outside it, a rung `xic auto ote s1.run` on line 18, is refused.
And a block that holds an instance of itself, `var inner seal` on line 6 of `seal.ld`, is
refused in its own file, and the program that names it is compiled no further:

```
belts.ld: line 12: unknown type `sael`: logex has `bool`, `dint`, `ctd`, `ctu`, `ctud`, `rto`, `tof`, `ton` and `tp`, and the function block `seal` — did you mean `seal`?
belts.ld: line 18: `ote` writes `s1.run`, but `s1` is an instance of `seal`, whose members only its body writes
./seal.ld: line 6: `seal` cannot hold an instance of `seal`: a function block never holds an instance of itself
```

## A configuration

A configuration runs instances of one or more programs as one resource: each instance on a
periodic task, on an event task or on none, its `var_input`s and `var_output`s connected to globals, and the
globals located at the host's input and output points or not
([`docs/organisation.md`](docs/organisation.md) §4.4 to §4.6). It is written as a
configuration file (`.logex`), which `Logex.Configuration.compile_file/1` reads, loading
each program type from the `.ld` file beside it, or built from Elixir data with
`Logex.Configuration.new!/1`. Either way one validator checks it, in the configuration
file's words. `Logex.Runtime.start/1` makes the resource, and `cycle/3` steps it by the
milliseconds the host says have passed, with the input points that changed, returning
every output point and what ran.

### A configuration file

`plant.logex` — two instances of `motor.ld`, above, `m1` on a 10 ms task and `m2` on a
50 ms one, each wired to its own buttons, contactor and speed setpoint; `m2`'s `overtemp`
and `reset` are tied to 0. Every global located `at` a point is the plant's I/O list:

```
// plant.logex -- two conveyors, one program type (motor.ld)
task fast interval 10 priority 1
task slow interval 50 priority 2

var_global pb_start_1 bool at panel.i.0
var_global pb_stop_1  bool at panel.i.1
var_global tt_1       bool at panel.i.2
var_global pb_start_2 bool at panel.i.3
var_global pb_stop_2  bool at panel.i.4
var_global pb_reset   bool at panel.i.5
var_global k1         bool at panel.q.0
var_global k2         bool at panel.q.1
var_global sp_1       dint at drive.q.0
var_global sp_2       dint at drive.q.1

program m1 motor with fast
  m1.start    pb_start_1
  m1.stop     pb_stop_1
  m1.overtemp tt_1
  m1.reset    pb_reset
  m1.motor    k1
  m1.speed_sp sp_1

program m2 motor with slow
  m2.start    pb_start_2
  m2.stop     pb_stop_2
  m2.overtemp 0
  m2.reset    0
  m2.motor    k2
  m2.speed_sp sp_2
```

`broken.logex`, beside it, has a mistake on four of its lines:

```
task fast interval 10 priority 1
var_global pb_start_1 bool at panel.i.0
var_global pb_stop_1  bool at panel.i.1
var_global k1         bool at panel.q.0
var_global sp_1       dint at drive.q.0
program m1 motor with fsat
  m1.start    pb_start_1
  m1.stop     pb_stop_1
  m1.motor    pb_stop_1
  m1.speed_sp k1
program m2 pump
```

`load.exs` loads the plant, cycles it and loads the broken file:

```elixir
{:ok, plant} = Logex.Configuration.compile_file("plant.logex")

print = fn
  nil, _now, _outputs, _events -> :ok
  label, now, out, events -> IO.puts("t=#{String.pad_leading("#{now}", 2)}  #{label}  k1=#{out["k1"]} k2=#{out["k2"]}  #{inspect(events)}")
end

cycle = fn {rt, now}, elapsed, inputs, label ->
  {rt, outputs, events} = Logex.Runtime.cycle(rt, elapsed, inputs)
  print.(label, now + elapsed, outputs, events)
  {rt, now + elapsed}
end

{Logex.Runtime.start(plant), 0}
|> cycle.(0, %{}, "idle         ")
|> cycle.(10, %{"pb_start_1" => 1, "pb_start_2" => 1}, "both started ")
|> cycle.(10, %{}, nil)
|> cycle.(10, %{}, nil)
|> cycle.(10, %{}, nil)
|> cycle.(10, %{}, "held to 50 ms")
|> cycle.(10, %{"pb_start_1" => 0, "pb_start_2" => 0}, "released     ")

{:error, diagnostics} = Logex.Configuration.compile_file("broken.logex")
Enum.each(diagnostics, &IO.puts(Logex.Diagnostic.format(&1)))
```

```
$ mix run load.exs
t= 0  idle           k1=0 k2=0  [{:ran, "fast", "m1", 0}, {:ran, "slow", "m2", 0}]
t=10  both started   k1=1 k2=0  [{:ran, "fast", "m1", 10}]
t=50  held to 50 ms  k1=1 k2=1  [{:ran, "fast", "m1", 50}, {:ran, "slow", "m2", 50}]
t=60  released       k1=1 k2=1  [{:ran, "fast", "m1", 60}]
broken.logex: line 6: no task `fsat` — did you mean `fast`?
broken.logex: line 6: `m1` leaves its var_inputs `overtemp` and `reset` unconnected: connect each to a global, a point or a constant, as in `m1.overtemp 0`
broken.logex: line 9: `pb_stop_1` is an input point (line 3): `m1.motor`, a var_output, cannot drive it
broken.logex: line 10: `m1.speed_sp` is a dint, but `k1` is a bool (line 4)
broken.logex: line 11: unknown program type `pump`: there is no `pump.ld` beside `broken.logex`
```

- The plant is named after its file, and `motor` is compiled from `motor.ld` once, however
  many instances it has. The program types are compiled through `Logex.compile_files/1`,
  one memo for the configuration, so a function block that several program types hold is
  compiled once too, and its warnings are handed back once, by the first program type
  that holds it. A `.ld` file a `program` line names that is a function block's, or that
  does not compile, is cited at the line of its first instance, the latter with the files
  its mistakes are cited in, a block's among them; those mistakes follow the
  configuration's, each once, with its own file and line.
- Every task is due in the first cycle. `m2` sees its start button only when it next runs,
  at 50 ms, so it starts then, and holds itself in after the button is released.
- Every mistake is a diagnostic at its line, naming the file, in line order, and the
  configuration file's words are the same from Elixir data: an instance's unconnected
  `var_input`s are one diagnostic, at its `program` line.
- `Logex.Configuration.compile/3` is the same compile from text, with the program types
  given as data and no file read. `Logex.Configuration.Text.print/1` prints a
  configuration back to its text, which compiles back to the very configuration.

### From Elixir data

`plant.exs` — the same plant built as Elixir data, two instances of `motor.ld`, `m1` on a 10 ms task and `m2` on a 50 ms one,
each wired to its own buttons, contactor and speed setpoint; `m2`'s `overtemp` and `reset`
are tied to 0. It then builds the same plant with three mistakes in it:

```elixir
{:ok, motor} = Logex.compile_file("motor.ld")

alias Logex.Configuration
alias Logex.Configuration.{Connection, Global, Instance}

point = fn name, type, at -> %Global{name: name, type: type, at: at} end

wire = fn instance, pairs ->
  for {member, to} <- pairs, do: %Connection{instance: instance, member: member, to: to}
end

fields = [
  name: "plant",
  programs: [motor],
  tasks: [
    %Configuration.Task{name: "fast", interval: 10, priority: 1},
    %Configuration.Task{name: "slow", interval: 50, priority: 2}
  ],
  globals: [
    point.("pb_start_1", :bool, "panel.i.0"),
    point.("pb_stop_1", :bool, "panel.i.1"),
    point.("tt_1", :bool, "panel.i.2"),
    point.("pb_start_2", :bool, "panel.i.3"),
    point.("pb_stop_2", :bool, "panel.i.4"),
    point.("pb_reset", :bool, "panel.i.5"),
    point.("k1", :bool, "panel.q.0"),
    point.("k2", :bool, "panel.q.1"),
    point.("sp_1", :dint, "drive.q.0"),
    point.("sp_2", :dint, "drive.q.1")
  ],
  instances: [
    %Instance{name: "m1", type: "motor", task: "fast"},
    %Instance{name: "m2", type: "motor", task: "slow"}
  ],
  connections:
    wire.("m1", [{"start", "pb_start_1"}, {"stop", "pb_stop_1"}, {"overtemp", "tt_1"}]) ++
      wire.("m1", [{"reset", "pb_reset"}, {"motor", "k1"}, {"speed_sp", "sp_1"}]) ++
      wire.("m2", [{"start", "pb_start_2"}, {"stop", "pb_stop_2"}, {"overtemp", 0}]) ++
      wire.("m2", [{"reset", 0}, {"motor", "k2"}, {"speed_sp", "sp_2"}])
]

print = fn
  nil, _now, _outputs, _events -> :ok
  label, now, out, events ->
    points = "k1=#{out["k1"]} k2=#{out["k2"]} sp_1=#{out["sp_1"]} sp_2=#{out["sp_2"]}"
    IO.puts("t=#{String.pad_leading("#{now}", 3)}  #{label}  #{points}  #{inspect(events)}")
end

cycle = fn {rt, now}, elapsed, inputs, label ->
  {rt, outputs, events} = Logex.Runtime.cycle(rt, elapsed, inputs)
  print.(label, now + elapsed, outputs, events)
  {rt, now + elapsed}
end

{rt, _now} =
  {Logex.Runtime.start(Configuration.new!(fields)), 0}
  |> cycle.(0, %{}, "idle         ")
  |> cycle.(10, %{"pb_start_1" => 1, "pb_start_2" => 1}, "both started ")
  |> cycle.(10, %{}, nil)
  |> cycle.(10, %{}, nil)
  |> cycle.(10, %{}, nil)
  |> cycle.(10, %{}, "held to 50 ms")
  |> cycle.(10, %{"pb_start_1" => 0, "pb_start_2" => 0}, "released     ")
  |> cycle.(10, %{"tt_1" => 1}, "tt_1 trips   ")
  |> cycle.(35, %{}, "35 ms late   ")

IO.inspect(Logex.Runtime.overlaps(rt), label: "overlaps")
IO.inspect(Logex.Runtime.next_due_in(rt), label: "next due in")
IO.inspect(Logex.Runtime.get!(rt, "m1.fault"), label: "m1.fault")

bad =
  Keyword.merge(fields,
    tasks: [
      %Configuration.Task{name: "fast", interval: 10, priority: 1.5},
      %Configuration.Task{name: "slow", interval: 50, priority: 2}
    ],
    instances: [
      %Instance{name: "m1", type: "motor", task: "fast"},
      %Instance{name: "m2", type: "motor", task: "slwo"}
    ],
    connections: fields[:connections] ++ wire.("m2", [{"motor", "pb_stop_1"}])
  )

try do
  Configuration.new!(bad)
rescue
  error in ArgumentError -> IO.puts(error.message)
end
```

```
$ mix run plant.exs
t=  0  idle           k1=0 k2=0 sp_1=1200 sp_2=1200  [{:ran, "fast", "m1", 0}, {:ran, "slow", "m2", 0}]
t= 10  both started   k1=1 k2=0 sp_1=1200 sp_2=1200  [{:ran, "fast", "m1", 10}]
t= 50  held to 50 ms  k1=1 k2=1 sp_1=1200 sp_2=1200  [{:ran, "fast", "m1", 50}, {:ran, "slow", "m2", 50}]
t= 60  released       k1=1 k2=1 sp_1=1200 sp_2=1200  [{:ran, "fast", "m1", 60}]
t= 70  tt_1 trips     k1=1 k2=1 sp_1=0 sp_2=1200  [{:ran, "fast", "m1", 70}]
t=105  35 ms late     k1=1 k2=1 sp_1=0 sp_2=1200  [{:overlap, "fast", 2}, {:ran, "fast", "m1", 105}, {:ran, "slow", "m2", 105}]
overlaps: %{"fast" => 2, "slow" => 0}
next due in: 5
m1.fault: 1
task `fast`: a priority is 0, the highest, to 65535, found 1.5
no task `slwo` — did you mean `slow`?
`pb_stop_1` is an input point: `m2.motor`, a var_output, cannot drive it
```

- Every task is due in the first cycle, and after it `m1` runs every 10 ms and `m2` every
  50 ms; the cycles at 20, 30 and 40 ms ran `m1` alone and are not printed. Due tasks run
  by priority, 0 the highest, then the earlier due time, then the order declared. `m2`
  sees its start button only when it next runs, at 50 ms, so it starts then.
- `tt_1` latches `m1`'s fault, which drops `sp_1` and leaves `m2` alone.
- The last cycle came 35 ms after the one before. The 10 ms task, due at 80 ms, runs once
  rather than three times, and reports the two periods it missed, at 80 and 90 ms, just
  before its scan; its phase is kept, so it is next due at 110 ms. `overlaps/1` counts
  the missed periods, and `get!/2` reads any global or any instance's tag by its path;
  `get/2` gives it as `{:ok, value}`, or `{:error, reason}` for a path that names nothing.
- A priority of 1.5 is a mistake no configuration file could hold, since a number in one
  is whole, so `Logex.Configuration.check/1` raises it as the host's; the other two a
  file could hold, as it could a priority of -1, a negative number lexing since M3-3, and `check/1` returns them as diagnostics, each cited at its line when
  a file gives one. `new!/1` raises them all, the host's first.

### A global shared by name

`conveyor.ld` reads an e-stop that every conveyor shares, through `var_external`, and
latches its `fault` on it until `reset`:

```
var_input start bool
var_input stop bool
var_input reset bool
var_output motor bool
var_external estop bool
var fault bool

xic estop otl fault
xic reset otu fault
( xic start | xic motor ) xio stop xio fault ote motor
```

`line.logex` declares the e-stop once, as an input point, and runs two conveyors, `c1`
on a 10 ms task and `c2` on a 50 ms one. Neither connects `estop`: each reads the global
by name.

```
// line.logex -- two conveyors, one e-stop
task fast interval 10 priority 1
task slow interval 50 priority 2

var_global estop      bool at panel.i.7
var_global pb_start_1 bool at panel.i.0
var_global pb_start_2 bool at panel.i.1
var_global pb_reset   bool at panel.i.2
var_global k1         bool at panel.q.0
var_global k2         bool at panel.q.1

program c1 conveyor with fast
  c1.start pb_start_1
  c1.stop  0
  c1.reset pb_reset
  c1.motor k1

program c2 conveyor with slow
  c2.start pb_start_2
  c2.stop  0
  c2.reset pb_reset
  c2.motor k2
```

`shared.exs` runs the line twice, once with the e-stop held from 50 ms and once with a
10 ms press at 20 ms, then loads `wrong.logex`, which misspells the global and connects
the var_external besides:

```
var_global estp       bool at panel.i.7
var_global pb_start_1 bool at panel.i.0
var_global k1         bool at panel.q.0
program c1 conveyor
  c1.start pb_start_1
  c1.stop  0
  c1.reset 0
  c1.motor k1
  c1.estop estp
```

```elixir
{:ok, line} = Logex.Configuration.compile_file("line.logex")

run = fn label, steps ->
  IO.puts(label)

  Enum.reduce(steps, Logex.Runtime.start(line), fn {now, inputs}, rt ->
    {rt, out, events} = Logex.Runtime.cycle(rt, min(now, 10), inputs)
    ran = for {:ran, _task, instance, _now} <- events, do: instance
    IO.puts("  t=#{String.pad_leading("#{now}", 2)}  k1=#{out["k1"]} k2=#{out["k2"]}  ran #{Enum.join(ran, ", ")}")
    rt
  end)
end

start = %{"pb_start_1" => 1, "pb_start_2" => 1}
release = %{"pb_start_1" => 0, "pb_start_2" => 0}

rt =
  run.("e-stop held from 50 ms:", [
    {0, start}, {10, release}, {20, %{}}, {30, %{}}, {40, %{}}, {50, %{"estop" => 1}}, {60, %{}}
  ])

IO.inspect(for(path <- ~w(estop c1.estop c2.estop c2.fault), do: Logex.Runtime.get!(rt, path)),
  label: "estop c1.estop c2.estop c2.fault"
)

run.("e-stop pressed for 10 ms at 20 ms:", [
  {0, start}, {10, release}, {20, %{"estop" => 1}}, {30, %{"estop" => 0}}, {40, %{}}, {50, %{}}
])

{:error, diagnostics} = Logex.Configuration.compile_file("wrong.logex")
Enum.each(diagnostics, &IO.puts(Logex.Diagnostic.format(&1)))
```

```
$ mix run shared.exs
e-stop held from 50 ms:
  t= 0  k1=1 k2=1  ran c1, c2
  t=10  k1=1 k2=1  ran c1
  t=20  k1=1 k2=1  ran c1
  t=30  k1=1 k2=1  ran c1
  t=40  k1=1 k2=1  ran c1
  t=50  k1=0 k2=0  ran c1, c2
  t=60  k1=0 k2=0  ran c1
estop c1.estop c2.estop c2.fault: [1, 1, 1, 1]
e-stop pressed for 10 ms at 20 ms:
  t= 0  k1=1 k2=1  ran c1, c2
  t=10  k1=1 k2=1  ran c1
  t=20  k1=0 k2=1  ran c1
  t=30  k1=0 k2=1  ran c1
  t=40  k1=0 k2=1  ran c1
  t=50  k1=0 k2=1  ran c1, c2
wrong.logex: line 4: `conveyor` declares `var_external estop bool` on line 5 of `conveyor.ld`, but there is no global `estop` — did you mean `estp`?
wrong.logex: line 9: `c1.estop` is a var_external of `conveyor`, which reaches the global `estop` itself: only a var_input or var_output connects
```

- During a scan an instance reads and writes the global itself: the scheduler merges
  each `var_external`'s global into the instance's state before the scan and splits it
  off after, so the resource holds one copy of each global, and `get!/2` reads `c2.estop`
  as `estop`. An instance sees what an earlier one wrote in the same cycle, as with a
  connection; a connection's copy-out comes after a write through a `var_external` to the
  same global, so the copy-out stands.
- The e-stop held from 50 ms, a cycle both tasks run, stops both conveyors in that cycle.
  An instance sees a global when it runs, so `c2`, on the 50 ms task, never sees the 10 ms
  press: an e-stop must be held at least as long as the slowest interval that reads it,
  as a maintained e-stop contact is.
- A `var_external` with no global of its name, or of another type, is a diagnostic at
  the line of the first instance of its type, naming the type's own file and line, once
  a type; so is a write through one to an input point. A connection never names one.
- Two instances that write one global through `var_external`, and an instance that writes
  through one a global a connection drives, are warnings on the configuration's
  `warnings`, in the words true of each: each scan reads what the other last wrote, and
  the later write in a cycle stands, or an instance's own copy-out, after the scan,
  stands, or, for a global that is the storage bit of an `ons`, an `osr` or an `osf`,
  the one-shot fires on the wrong scans.

### An event task

`trip.logex` runs a conveyor of `conveyor.ld`, above, on a 10 ms task, and `snapshot.ld`
on an event task, `trip`, which the e-stop's rising edge makes due:

```
var_input a bool
var_output a_was bool

xic a ote a_was
```

```
// trip.logex -- a conveyor, and a snapshot of its contactor when the e-stop rises
task fast interval 10 priority 1
task trip single estop priority 0

var_global estop      bool at panel.i.7
var_global pb_start_1 bool at panel.i.0
var_global pb_reset   bool at panel.i.2
var_global k1         bool at panel.q.0
var_global k1_at_trip bool

program c1 conveyor with fast
  c1.start pb_start_1
  c1.stop  0
  c1.reset pb_reset
  c1.motor k1

program snap snapshot with trip
  snap.a     k1
  snap.a_was k1_at_trip
```

`trip.exs` presses the start button, raises the e-stop, holds it, releases and resets it,
restarts the conveyor and raises the e-stop again; then it loads `timed.logex`, which runs
a program with a timer under an event task, and `wrong_trip.logex`, which has a mistake on
each of its task lines. `debounce.ld` and the two files:

```
var_input in bool
var_output out bool
var t1 ton

xic in ton t1 20
xic t1.dn ote out
```

```
task trip single pb priority 0
var_global pb bool at panel.i.0
program d debounce with trip
  d.in pb
```

```
task trip single sp priority 0
task tick priority 1
task late single pb interval 0 priority 2
var_global sp dint
var_global pb bool at panel.i.0
program d debounce with late
  d.in pb
```

```elixir
{:ok, line} = Logex.Configuration.compile_file("trip.logex")

steps = [
  {"started             ", 0, %{"pb_start_1" => 1}},
  {"released            ", 10, %{"pb_start_1" => 0}},
  {"e-stop rises        ", 10, %{"estop" => 1}},
  {"held                ", 10, %{}},
  {"released, reset     ", 10, %{"estop" => 0, "pb_reset" => 1}},
  {"restarted           ", 10, %{"pb_reset" => 0, "pb_start_1" => 1}},
  {"e-stop rises again  ", 10, %{"estop" => 1, "pb_start_1" => 0}}
]

Enum.reduce(steps, {Logex.Runtime.start(line), 0}, fn {label, elapsed, inputs}, {rt, now} ->
  {rt, out, events} = Logex.Runtime.cycle(rt, elapsed, inputs)
  ran = for {:ran, task, instance, _now} <- events, do: "#{task}:#{instance}"
  at_trip = Logex.Runtime.get!(rt, "k1_at_trip")
  IO.puts("t=#{String.pad_leading("#{now + elapsed}", 2)}  #{label}k1=#{out["k1"]} k1_at_trip=#{at_trip}  ran #{Enum.join(ran, ", ")}")
  {rt, now + elapsed}
end)

{:ok, timed} = Logex.Configuration.compile_file("timed.logex")
Enum.each(timed.warnings, &IO.puts(Logex.Diagnostic.format(&1)))

{:error, diagnostics} = Logex.Configuration.compile_file("wrong_trip.logex")
Enum.each(diagnostics, &IO.puts(Logex.Diagnostic.format(&1)))
```

```
$ mix run trip.exs
t= 0  started             k1=1 k1_at_trip=0  ran fast:c1
t=10  released            k1=1 k1_at_trip=0  ran fast:c1
t=20  e-stop rises        k1=0 k1_at_trip=1  ran trip:snap, fast:c1
t=30  held                k1=0 k1_at_trip=1  ran fast:c1
t=40  released, reset     k1=0 k1_at_trip=1  ran fast:c1
t=50  restarted           k1=1 k1_at_trip=1  ran fast:c1
t=60  e-stop rises again  k1=0 k1_at_trip=1  ran trip:snap, fast:c1
timed.logex: line 3: warning: `d` runs under the event task `trip`, and `debounce` runs the timer `t1` on line 5 of `debounce.ld`: a ton times across the task's runs, and one whose rung is true on two runs in a row counts the whole time between them
wrong_trip.logex: line 1: the single of `trip`, `sp`, is a dint (line 4): a single is a bool global
wrong_trip.logex: line 2: task `tick` needs an interval or a single, as in `task tick interval 10 priority 1` or `task tick single estop priority 0`
wrong_trip.logex: line 3: the interval of `late` is 0: an interval is at least 1 ms, and a task that runs only on the rising edges of its single is declared without one
```

- A task's `single` is sampled once a cycle, after the inputs are merged and before any
  scan, and a sample of 1 after one of 0 makes the task due. `trip` runs at 20 ms and at
  60 ms, not while the e-stop is held, and at priority 0 it runs before `c1` in each, so
  the snapshot records the contactor as the cycle before left it. The last sample starts
  at 0, so a trigger already 1 in the first cycle fires, and `restart/2` sets it to 0
  again; a pulse inside one host step is never seen, and a trigger that logic writes fires
  in the next cycle.
- An event task's due time is the cycle's `now`, so a late periodic task of the same
  priority runs before it. With `interval` too, a task runs at most once a cycle: on an
  edge, or at its due time while the trigger is 0; a due time that comes while it is 1 is
  skipped and not counted, and the phase never moves. `next_due_in/1` counts periodic due
  times only, so a host cycles at once after `start/1` and `restart/2`, whatever it says.
- A ton in a program an event task runs times across the task's runs, which only the
  configuration knows, so the configuration warns of each, a block's timer by its path.
  So it does of every other timer, of each counter after them, and of each one-shot after
  those, an `ons`, an `osr` or an `osf`, each in its own words and a block's by its
  storage bit's path: a counter or a one-shot sees its rung only when the task runs, so an
  edge between two runs is never seen, and a rung that is the task's trigger is true at
  every run, so that `xic estop osr s1 pressed` under the e-stop's own event task never
  pulses; and the pulse a coil does set stays on until the task next runs.
- A single names a bool global; a dint, another kind of name and no global are each a
  diagnostic at the task's line, a dotted one told the reading it has.

## Changing a running program

A running instance takes a changed program without a restart, the way the conventional
family's controllers are edited online. `Logex.Edit` *accepts* a candidate beside the
running program, *tests* it over the instance's state, *untests* back to the original as
often as needed, and then *assembles*, keeping the candidate, or *cancels*. Every step is
taken between two scans and returns a report of what it did to the state, and nothing
goes through the Elixir compiler. [`docs/organisation.md`](docs/organisation.md) §4.9 has
the design and every rule, and `Logex.Edit`'s moduledoc the rules as built.

`motor_v2.ld` — the motor of `motor.ld`, with `run_lamp` replaced by `at_speed`, lit once
the motor has run for two seconds, and a pulse, `started`, on the scan the motor starts:

```
var_input start bool
var_input stop bool
var_input overtemp bool
var_input reset bool
var_output motor bool
var_output at_speed bool
var_output started bool
var_output speed_sp dint 1200
var fault bool
var t1 ton
var s1 bool

( xic start | xic motor ) xio stop ote motor
xic motor ton t1 2000
xic t1.dn ote at_speed
xic motor ons s1 ote started
xic overtemp otl fault
xic reset otu fault
xic fault move 0 speed_sp
```

`edit.exs` starts the motor, then edits its program while it runs. During the edit it
scans whichever program `Logex.Edit.running/1` names, and after it the one `assemble/2`
returns:

```elixir
{:ok, motor} = Logex.compile_file("motor.ld")
# An edit keeps the program's name, and compile_file/1 would name this one `motor_v2`.
{:ok, v2} = Logex.compile(File.read!("motor_v2.ld"), name: "motor")

scan = fn state, program, elapsed, label, inputs ->
  state = Logex.Runtime.put_inputs(program, state, inputs)
  {outputs, state} = Logex.Runtime.scan(program, state, elapsed)
  IO.puts("t=#{String.pad_leading("#{state.now}", 4)}  #{label}  #{inspect(outputs)}")
  state
end

step = fn {edit, state, report}, label ->
  IO.puts(label)
  Enum.each(report, &IO.puts("        #{inspect(&1)}"))
  {edit, state}
end

state =
  Logex.Runtime.instance(motor)
  |> scan.(motor, 10, "start pressed ", %{"start" => 1})
  |> scan.(motor, 10, "start released", %{"start" => 0})

{:ok, edit, _forecast} = Logex.Edit.accept(motor, v2, state)
{edit, state} = step.(Logex.Edit.test(edit, state), "test")

state =
  state
  |> scan.(Logex.Edit.running(edit), 10, "under test    ", %{})
  |> scan.(Logex.Edit.running(edit), 2000, "under test    ", %{})

{edit, state} = step.(Logex.Edit.untest(edit, state), "untest")
state = scan.(state, Logex.Edit.running(edit), 10, "untested      ", %{})
{edit, state} = step.(Logex.Edit.test(edit, state), "test")
{motor, state} = step.(Logex.Edit.assemble(edit, state), "assemble")

state
|> scan.(motor, 10, "stop pressed  ", %{"stop" => 1})
|> scan.(motor, 10, "start pressed ", %{"stop" => 0, "start" => 1})
```

```
$ mix run edit.exs
t=  10  start pressed   %{"motor" => 1, "run_lamp" => 1, "speed_sp" => 1200}
t=  20  start released  %{"motor" => 1, "run_lamp" => 1, "speed_sp" => 1200}
test
        {:added, "at_speed", 0}
        {:added, "s1", 0}
        {:added, "started", 0}
        {:added, "t1", %{"acc" => 0, "dn" => 0, "en" => 0, "last" => 0, "pre" => 2000, "tt" => 0}}
        {:held, "run_lamp", 1}
        {:ons_blocked, "s1", 0}
t=  30  under test      %{"at_speed" => 0, "motor" => 1, "speed_sp" => 1200, "started" => 0}
t=2030  under test      %{"at_speed" => 1, "motor" => 1, "speed_sp" => 1200, "started" => 0}
untest
        {:held, "at_speed", 1}
        {:held, "started", 0}
t=2040  untested        %{"motor" => 1, "run_lamp" => 1, "speed_sp" => 1200}
test
        {:held, "run_lamp", 1}
        {:ons_blocked, "s1", 1}
        {:resumed, "t1", 10}
assemble
        {:held, "run_lamp", 1}
        {:pruned, "run_lamp", 1}
t=2050  stop pressed    %{"at_speed" => 0, "motor" => 0, "speed_sp" => 1200, "started" => 0}
t=2060  start pressed   %{"at_speed" => 0, "motor" => 1, "speed_sp" => 1200, "started" => 1}
```

- **Accept** changed nothing. It checked the candidate against the running program and
  returned a forecast, the report a test taken at once would give: here, the first test's
  report exactly.
- **Test** moved the state to the candidate by name, and the motor stayed sealed in. What
  the candidate adds starts at its declared initial value, so `t1` starts at its preset
  of 2000 and times from the switch. `run_lamp` is no longer among the outputs, so it is
  *held*: the host keeps that point at 1, as the conventional family's outputs keep their
  last state. And the new one-shot is blocked for the scan after the switch. `motor` was
  already 1 and nothing rose, so `started` does not pulse.
- **Untest** ran the original again over the same state. Now the outputs only the
  candidate drove are held.
- **Test**, again: `t1`, which no `ton` ran while the original ran, resumes from the
  switch rather than catching up the 10 ms it missed, and the one-shot is blocked again,
  because the original scanned last.
- **Assemble** kept the candidate and pruned what only the original declares. The edit is
  over, and the one-shot fires on the motor's next real start.

The edit is what keeps that run right. Scanning `motor_v2` over the same state with no
edit, a *plain swap*, is still allowed, but its first scan gives
`%{"at_speed" => 1, "motor" => 1, "speed_sp" => 1200, "started" => 1}`: a pulse, though
the motor was already running, and `at_speed` at once, because a timer the state lacks
starts at a `.pre` of 0 until a restart.

A candidate that changes a tag's type is refused at accept, since only a restart can
change one. Had `motor_v2.ld` kept `run_lamp` as `var_output run_lamp dint`, on its line
7, `accept/3` would have returned `{:error, [diagnostic]}`:

```
line 7: `run_lamp` is a bool in the running program and a dint in the candidate: a tag's type changes only with a restart
```

The diagnostic names no file because `v2` came from `Logex.compile/2`, which reads none.
A candidate from `Logex.compile_file/1` keeps its path as its `file`, and the diagnostic
names it: compiled from `v2/motor.ld`, the same candidate gives
`` v2/motor.ld: line 7: `run_lamp` is a bool in the running program … ``. A section
change and a changed initial value are not type changes: the value is kept, and the
report says what changed.

A program that holds function blocks is edited the same way, its blocks with it
(decisions 31 and 32 in [`docs/organisation.md`](docs/organisation.md) §7). A block's
body may change, and members may be added or dropped: each instance's state moves member
by member, by its path, and a member whose type changes is refused at accept, by its
path, as a tag's is. Had `seal.ld` been edited to start a belt only on the press of
`start`, not while it is held, with a `var edge bool` and the rung
`( xic start ons edge | xic run ) xio stop ote run`, a test of `belts` compiled again
with it, taken while `auto` is off, would report `{:added, "s1.edge", 0}` and `{:ons_blocked, "s1.edge", 0}`,
and the same for `s2` and `s3`. The one-shot in `s3`, whose `cal` is frozen, stays
blocked until a scan runs the block's body, once `auto` is back: a `start_3` held through
the edit does not start belt 3 then, and its next press does.

During an edit the host scans, sets inputs and restarts through `Logex.Edit.running/1`,
and sends only that program's var_inputs. It resends each input a step reports as
`{:input, name, value}`, stops sending each one reported as `{:unread, name, value}`,
holds each point reported as `{:held, name, value}`, and ignores a report kind it does
not know.

A program built as data rather than text, through `Logex.Compiler.instructionize/2` and
`Logex.Tag.new!/4`, is refused with an `ArgumentError` where no text could say it, as a
literal that is no integer, a timer's preset given from Elixir, or a function block type edited by
hand and given in `types:`. So every program an edit takes could be written as a `.ld`
file, and every block it holds as a block's file. A block type given where a program goes,
to the runtime, to `accept/3` or in a configuration's `programs`, raises one message:

```
`seal` is a function block type, which runs inside a program through `cal`: an instance is of a %Logex.Program{}
```

A counter is edited as a timer is: its count is kept, its `.pv` moves to a changed
preset where logic left it alone, and its edge memory is blocked as an `ons` bit is, by
its path, where the edit adds the counter or changes its rung, so the switch counts no box
that was not a real edge. `recount.exs` raises `boxes.ld`'s case from three to five while
the third box is still on the eye:

```elixir
{:ok, boxes} = Logex.compile_file("boxes.ld")
# A case of five, not three: boxes_v2.ld is boxes.ld with `ctu boxes 5`.
{:ok, v2} = Logex.compile(File.read!("boxes_v2.ld"), name: "boxes")

scan = fn state, program, label, inputs ->
  state = Logex.Runtime.put_inputs(program, state, inputs)
  {outputs, state} = Logex.Runtime.scan(program, state, 10)
  IO.puts("#{label}  #{inspect(outputs)}")
  state
end

state =
  Logex.Runtime.instance(boxes)
  |> scan.(boxes, "start      ", %{})
  |> scan.(boxes, "box 1      ", %{"eye" => 1})
  |> scan.(boxes, "eye clear  ", %{"eye" => 0})
  |> scan.(boxes, "box 2      ", %{"eye" => 1})
  |> scan.(boxes, "eye clear  ", %{"eye" => 0})
  |> scan.(boxes, "box 3      ", %{"eye" => 1})

{:ok, edit, _forecast} = Logex.Edit.accept(boxes, v2, state)
{edit, state, report} = Logex.Edit.test(edit, state)
IO.puts("test, with box 3 still on the eye")
Enum.each(report, &IO.puts("        #{inspect(&1)}"))
{boxes, state, _report} = Logex.Edit.assemble(edit, state)

state
|> scan.(boxes, "still box 3", %{})
|> scan.(boxes, "eye clear  ", %{"eye" => 0})
|> scan.(boxes, "box 4      ", %{"eye" => 1})
|> scan.(boxes, "eye clear  ", %{"eye" => 0})
|> scan.(boxes, "box 5      ", %{"eye" => 1})
```

```
$ mix run recount.exs
start        %{"count" => 0, "full_lamp" => 0}
box 1        %{"count" => 1, "full_lamp" => 0}
eye clear    %{"count" => 1, "full_lamp" => 0}
box 2        %{"count" => 2, "full_lamp" => 0}
eye clear    %{"count" => 2, "full_lamp" => 0}
box 3        %{"count" => 3, "full_lamp" => 1}
test, with box 3 still on the eye
        {:dn_drops, "boxes", {3, 5}}
        {:preset, "boxes", {3, 5}}
still box 3  %{"count" => 3, "full_lamp" => 0}
eye clear    %{"count" => 3, "full_lamp" => 0}
box 4        %{"count" => 4, "full_lamp" => 0}
eye clear    %{"count" => 4, "full_lamp" => 0}
box 5        %{"count" => 5, "full_lamp" => 1}
```

The count stays at 3, `pv` moves to 5, and the report forecasts that `q`, done at 3 of 3,
drops at the counter's next run, which it does: the lamp goes out, and the box still on
the eye is not counted again. A counter the edit adds while its rung is true is reported
`{:ons_blocked, "rejects.cu", 0}` and counts nothing at the switch; a preset changed alone
blocks nothing, since no power on the rung reads it. A pulse coil is blocked as an `ons`
is, by its storage bit: one the edit adds, or whose rung it changes, its kind or its pulse
bit among the rung, is reported `{:ons_blocked, "s1", 0}` and sets no pulse at the switch,
so an edit of its pulse bit alone loses a press that rises on that scan, as an edit of what
an `ons` drives does; and its pulse bit is an ordinary bool, which an edit that removes the
coil leaves as it was.

A jump changes what an edit does in one place, where a block holds: a one-shot, a
counter's side or a pulse timer that a switch blocks on a rung a jump skips stays blocked
through every skipped scan until a scan runs it, as one in a frozen block does (decision
106), so a jog section edited while the line is in auto pulses or counts nothing at its
first run back in manual that no real edge made. A rung is compared whole, its `lbl` and
`jmp` among it, so an edit that labels a one-shot's or a pulse coil's rung, or adds a
`jmp` to it, blocks it once too, at the cost of one press that rises on the first scan
after the switch, as the maintainer confirmed after M3-5's review: one rule with a coil's
rung compared whole (decision 101). Labels are names, so an edit that moves rungs leaves
every jump as it was; a `jmp` an edit adds freezes its section from the switch, and one it
removes frees it, a timer there catching up.

An edit that leaves no rung writing a counter's `r`, `ld` or `pv`, an `rto`'s `r` or a
timer's `.pre` leaves it as it was, as an output the edit stops driving holds. Tested while
`reset_pb` is held, a `boxes_v3.ld` that is `boxes.ld` with no reset rung reports
`{:unwritten, "boxes.r", 1}`, and the counter counts no box while `r` stays on, until a
restart puts it to 0.

An edit of a lone instance gives the host the duties above; one of a running plant, below,
takes them over.

### A running plant

A configuration that runs is edited as a whole, `Logex.Configuration.Edit`, with the same
steps and the same report over the resource: `accept/2` takes the `%Logex.Runtime{}` that
runs the original and the candidate configuration; each step takes the runtime and
returns it, switched between two cycles, so `Logex.Runtime.cycle/3` runs whatever the
edit has installed, and the host chooses nothing. It never writes a global: decisions
55–66 in [`docs/organisation.md`](docs/organisation.md) §7, and its "OE-2's design" in
§4.9, give every rule.

`v2/conveyor.ld` sounds a horn, a new unlocated global it writes through a
`var_external`, while the conveyor is faulted; `v2/trip.logex` checks it every 5 ms and
drops the snapshot:

```
var_input start bool
var_input stop bool
var_input reset bool
var_output motor bool
var_external estop bool
var_external horn bool
var fault bool

xic estop otl fault
xic reset otu fault
( xic start | xic motor ) xio stop xio fault ote motor
xic fault ote horn
```

```
// trip.logex -- the conveyor sounds a horn while it is faulted, checked every 5 ms
task fast interval 5 priority 1
task trip single estop priority 0

var_global estop      bool at panel.i.7
var_global pb_start_1 bool at panel.i.0
var_global pb_reset   bool at panel.i.2
var_global k1         bool at panel.q.0
var_global k1_at_trip bool
var_global horn       bool

program c1 conveyor with fast
  c1.start pb_start_1
  c1.stop  0
  c1.reset pb_reset
  c1.motor k1
```

`edit_plant.exs` runs `trip.logex`, above, edits it while it runs, untests, tests again and
assembles; then tries a step on the edit that has ended, and a candidate,
`moved/trip.logex`, that is `v2/trip.logex` with `c1` moved to `trip`:

```elixir
{:ok, line} = Logex.Configuration.compile_file("trip.logex")
{:ok, v2} = Logex.Configuration.compile_file("v2/trip.logex")

cycle = fn rt, elapsed, label, inputs ->
  {rt, out, events} = Logex.Runtime.cycle(rt, elapsed, inputs)
  ran = for {:ran, task, instance, _now} <- events, do: "#{task}:#{instance}"
  # `horn` is a global of the candidate's alone.
  horn =
    case Logex.Runtime.get(rt, "horn") do
      {:ok, value} -> " horn=#{value}"
      {:error, _reason} -> ""
    end

  IO.puts("#{label}k1=#{out["k1"]} k1_at_trip=#{Logex.Runtime.get!(rt, "k1_at_trip")}#{horn}  ran #{Enum.join(ran, ", ")}")
  rt
end

step = fn {edit, rt, report}, label ->
  IO.puts(label)
  Enum.each(report, &IO.puts("        #{inspect(&1)}"))
  {edit, rt}
end

rt =
  Logex.Runtime.start(line)
  |> cycle.(0, "t=  0  started           ", %{"pb_start_1" => 1})
  |> cycle.(10, "t= 10  released          ", %{"pb_start_1" => 0})

{:ok, edit, _forecast} = Logex.Configuration.Edit.accept(rt, v2)
{edit, rt} = step.(Logex.Configuration.Edit.test(edit, rt), "test")

rt =
  rt
  |> cycle.(5, "t= 15  under test        ", %{})
  |> cycle.(5, "t= 20  e-stop rises      ", %{"estop" => 1})

{edit, rt} = step.(Logex.Configuration.Edit.untest(edit, rt), "untest")

rt =
  rt
  |> cycle.(10, "t= 30  released, reset   ", %{"estop" => 0, "pb_reset" => 1})
  |> cycle.(10, "t= 40  e-stop rises      ", %{"estop" => 1, "pb_reset" => 0})

{edit, rt} = step.(Logex.Configuration.Edit.test(edit, rt), "test")
{_line, rt} = step.(Logex.Configuration.Edit.assemble(edit, rt), "assemble")
_rt = cycle.(rt, 5, "t= 45  assembled         ", %{"estop" => 0})

try do
  Logex.Configuration.Edit.untest(edit, rt)
rescue
  error in ArgumentError -> IO.puts(error.message)
end

{:ok, moved} = Logex.Configuration.compile_file("moved/trip.logex")
{:error, diagnostics} = Logex.Configuration.Edit.accept(Logex.Runtime.start(line), moved)
Enum.each(diagnostics, &IO.puts(Logex.Diagnostic.format(&1)))
```

```
$ mix run edit_plant.exs
t=  0  started           k1=1 k1_at_trip=0  ran fast:c1
t= 10  released          k1=1 k1_at_trip=0  ran fast:c1
test
        {:added, "horn", 0}
        {:held, "k1_at_trip", 0}
        {:instance_stopped, "snap", "snapshot"}
        {:interval, "fast", {10, 5}}
        {:joined, "c1.horn", {nil, 0}}
        {:next_due, "fast", {20, 15}}
t= 15  under test        k1=1 k1_at_trip=0 horn=0  ran fast:c1
t= 20  e-stop rises      k1=0 k1_at_trip=0 horn=1  ran fast:c1
untest
        {:instance_back, "snap", "snapshot"}
        {:interval, "fast", {5, 10}}
t= 30  released, reset   k1=0 k1_at_trip=0  ran fast:c1
t= 40  e-stop rises      k1=0 k1_at_trip=0  ran trip:snap, fast:c1
test
        {:held, "k1_at_trip", 0}
        {:instance_stopped, "snap", "snapshot"}
        {:interval, "fast", {10, 5}}
        {:joined, "c1.horn", {nil, 1}}
assemble
        {:held, "k1_at_trip", 0}
        {:instance_pruned, "snap", "snapshot"}
t= 45  assembled         k1=0 k1_at_trip=0 horn=1  ran fast:c1
this edit expects the resource at generation 3, but it is at generation 4: the edit has ended, or another edit has stepped since
moved/trip.logex: line 12: `c1` runs with `fast` in the running configuration and with `trip` in the candidate: an instance moves to another task only with a restart
```

- **Test** switched the plant between two cycles, with no instance restarted: `c1` kept
  its state and stayed sealed in. The new global `horn` started at its initial value, and
  `c1` reads and writes it from its next scan, `:joined` with no value of its own. `fast`
  is next due within its new interval of the switch, at 15 ms, not 20. `snap` is set
  aside, its state kept, and `k1_at_trip`, which nothing drives any more, holds its
  value. The e-stop's edge at 20 ms runs no snapshot: the candidate's `trip` runs no
  instance.
- **Untest** brought `snap` back as it was set aside. No switch fires an event: the
  trigger's last sample was kept, so `trip` runs at the next real edge, at 40 ms.
- **Test**, again: `horn` was kept unused while the original ran, so it is not started
  again, and `c1` joins it at its last value.
- **Assemble** kept the candidate and pruned `snap`. The edit is over, and the resource's
  generation, which every step moved on, refuses a step on it.
- **Accept refuses** what changes only with a restart, each at its line in the
  candidate's files: a task added or removed, a task's `single`, an event task's interval
  added or removed, an instance moved to another task, a global's type, located I/O, and
  a tag's type in a program type an instance keeps.

A program type changed for the whole plant moves each instance of it through the
per-instance switch above, by one plan for the type, its reports named by path,
`c1.t1`. An instance added starts as `start/1` starts one; one removed is set aside and
pruned at assemble, and comes back at untest with its timers carrying on from where they
stopped; one given another program type is a remove and an add, and may run on another
task. A var_external made a program's own `var` keeps the global's value, `:left`; a
`var` made a var_external drops its own value for the global's, `:joined`, and the global
is left alone. A changed priority, and a reorder of tasks or instances, is allowed and
reported. A restart during an edit keeps its stage. An edit accepted while another is
open supersedes it: at its first test, whatever the earlier edit left set aside or kept
unused is dropped, `:instance_pruned` and `:pruned`, so an instance or global the new
candidate names again starts afresh (decision 66).

The host's duties shrink to the loop's: take each step between two cycles, keep the
runtime it returns, and tolerate a report kind it does not know. The input image is the
resource's and kept, each var_input is copied in from its connection, and a held point is
in every cycle's outputs at the value it holds.

## Running it

The toolchain this repository documents and pins is **Elixir 1.20 on Erlang/OTP 28**
(`mix.exs`, `.tool-versions`, `shell.nix`, `flake.nix`) — one version to think about, and it
is inside both projects' security windows. `.tool-versions` pins the exact patch releases
(`28.5.0.6`, `1.20.4-otp-28`) and is read by both mise and asdf; `nix develop` uses
`shell.nix`; `mix.exs` is the bound the compiler itself enforces. The floor was `~> 1.15` until September 2026; Elixir 1.15 and OTP 26
left their windows in June and May 2026, and the oldest pair still receiving security fixes
is Elixir 1.16 on OTP 27. There are no dependencies to fetch and nothing is generated at
build time, so a bare Erlang/OTP plus Elixir is enough — no `erlang-parsetools`.

On an older toolchain `mix compile` aborts with *"you're trying to run :logex on Elixir
v1.14.0 but it has declared in its mix.exs file it supports only Elixir ~> 1.20"*.
**Install a newer Elixir rather than relaxing `mix.exs`** — the requirement is deliberate, and a loosened version constraint is the kind
of edit that gets committed by accident. `nix develop` gives you the pinned toolchain; the
committed `flake.lock` predates the current pin, so the first run re-locks it — commit the
result. If you cannot install one, run the suite in the throwaway sandbox in
`CONTRIBUTING.md`, which relaxes the bound in a *copy*.

```
mix compile
mix test
mix format
```

CI runs the gates `CONTRIBUTING.md` asks of every commit — `mix format
--check-formatted`, `mix compile --force --warnings-as-errors`, the same under
`MIX_ENV=test`, and `mix test --warnings-as-errors` — on every push and pull request, on
Erlang/OTP 28 and Elixir 1.20.4 (`.github/workflows/ci.yml`).

## Documents

- `PLAN.md` — the codebase review and the ordered plan of work
- [`docs/naming.md`](docs/naming.md) — the IEC and vendor naming survey, one stanza per mnemonic, declaration word, word that heads a file or configuration file's word
- [`docs/instruction-sets.md`](docs/instruction-sets.md) — what IEC 61131-3 specifies for ladder, clause by clause, and what free software (MatIEC/Beremiz, OpenPLC, LDmicro, ClassicLadder, rusty, IronPLC) actually implements
- `CONTRIBUTING.md` — how to work on it: when the test output misleads, what a fix owes, what not to "fix"
- `CLAUDE.md` — commands and conventions for anyone (or anything) editing the code
- [`docs/organisation.md`](docs/organisation.md) — program organisation: IEC's configurations, tasks, program instances and I/O mapping, the conventional family's hierarchy mapped onto them, and the logex form for them, and how a running controller is changed (decided; program instances landed with M1-5, the online edit of one with OE-1, configurations with periodic tasks, from Elixir data, with M2-1, function blocks, their online edit included, with M2-5, the configuration file with its periodic tasks with M2-2 and M2-3, globals shared through `var_external` with M2-4, and event tasks with M2-6, which completes Milestone 2, and a configured plant's online edit with OE-2)
- [`docs/defladder.md`](docs/defladder.md) — a study of an Elixir-embedded `defladder` DSL: what Nx's `defn` does, an executed spike, and a recommendation (proposed, not adopted)

## License

Apache-2.0. See `LICENSE`.
