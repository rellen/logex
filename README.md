# logex

A Ladder Logic compiler and interpreter in Elixir. It compiles a ladder program written as
text into a named, stateless value, and runs it as instances, one scan at a time, with the
time the host injects. No dependencies and no generated code: the lexer and parser are
written by hand, and the whole thing is twenty-one small modules.

**Stage: early, and honest about it.** Fourteen instructions, among them an on-delay
timer, a one-shot and six comparisons, parallel branches to arbitrary nesting depth,
latch/unlatch that holds across scans, power flow that resets per rung, a typed tag table
that every tag is declared in, a public API (`Logex.compile/2`,
`Logex.compile_file/1` and `Logex.Runtime`), an online edit that changes a running
instance's program without a restart (`Logex.Edit`), a scheduler that runs instances of
several programs as one configuration on periodic tasks, wired to input and output points
(`Logex.Configuration`), and a printer that turns an AST back into source so a routine
round-trips — all of that works and is tested end to end, and a program with mistakes in
it gets every one reported with its line rather than an exception, a misspelt tag
included. What does not exist yet: counters, the other timers, math, the configuration
file, which will hold a configuration as text (a configuration is built from Elixir data
for now), shared globals, event tasks and function blocks of your own. `PLAN.md` is a
full review of the codebase and says precisely what is missing, in what order it gets
fixed, and why.

## The dialect

**logex is its own dialect. It does not aim to import vendor neutral text, and will not
become an importer.**

Source syntax today:

- declaration lines before the first rung, one tag each: `<section> <name> <type>
  [<initial>]`, the section `var`, `var_input` or `var_output`, the type `bool`, `dint`
  or `ton`, as in `var_output speed_sp dint 1200`. Every tag a rung uses must be
  declared. A `var_input` is supplied from outside and no instruction may write it; a tag
  with no initial value starts at 0. A timer, `var t1 ton`, is declared only with `var`
  and with no initial value: its preset is the number on the `ton` that runs it
- mnemonics, sections and types in any case (`xic`, `XIC`, `VAR_INPUT`), and reserved: no
  tag may be named after one, in any case, so `ote`, `Ote` and `bool` are never tags; tags
  are case-sensitive (`aa` and `AA` are two tags)
- operands separated by spaces — and a number must be followed by one: `move 1bst aa` is an
  error naming `1bst`, not the number `1` and a tag `bst`
- no operand parentheses, no terminator
- `//` starts a comment, which runs to the end of its line
- a name may have `.` parts: `t1.dn` is the member `dn` of the timer `t1`. A timer's
  members are `.pre` and `.acc` (dint, which logic may write) and `.dn`, `.tt` and `.en`
  (bool, which only its `ton` sets), read anywhere; members are case-sensitive, and a
  dotted name that is not a declared member is an error. `word.3`, bit access, is
  refused for now. No tag is declared with a `.`
- a newline ends a rung: LF, CRLF or a lone CR
- `(` … `|` … `)` open, separate and close a parallel branch group

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
The survey lives in [`docs/naming.md`](docs/naming.md), one stanza per mnemonic or
declaration word, and `test/logex/naming_test.exs` fails if an instruction or a
declaration word reaches the compiler without one. The rule it applies, in order: if IEC names the operation, take the IEC
name; if IEC supplies only a graphical element, take the clearest vendor mnemonic and say
which; never invent a readable word for a thing that already has a standard name.

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
| `eq a b` `ne a b` `lt a b` `gt a b` `le a b` `ge a b` | two dints, each a tag, a member or a literal | compare — pass power when `a = b`, `a ≠ b`, `a < b`, `a > b`, `a ≤ b`, `a ≥ b`; none on a false rung. Two literals are a warning |
| `ton t1 5000` | a timer, then a preset of 0 to 2147483647 ms | on-delay timer — rung power is its IN. True: `.acc` counts the milliseconds since the scan that first saw the rung true, up to `.pre`, where `.dn` is set. False: the timer resets. The preset is where `.pre` starts, when the instance starts or restarts; a `move` into `.pre` holds until then. An online edit that changes the preset moves `.pre` to it where `.pre` still holds the old one, and keeps a `.pre` that logic changed. One `ton` runs a timer, and nothing may follow it on its path: read it with `xic t1.dn` on a rung below |
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

These are decided (see [`docs/naming.md`](docs/naming.md), and `PLAN.md` §5 and §3's
Milestone 2) and will change the source language:
- **Program organisation** ([`docs/organisation.md`](docs/organisation.md)): a
  configuration file (`.logex`) that instantiates `.ld` programs, wires them to I/O points
  and globals, and schedules them on tasks, in text (the configuration it reads, and its
  scheduler, landed with M2-1, built from Elixir data); `var_external` for shared globals;
  event tasks; function blocks called with `cal`. Each new word still gets its
  `docs/naming.md` stanza, which may change a spelling.

- **Bit access** with `.` (`word.3`), and negative integer literals, which lex.
- **The other timers, counters and math** arrive as `tof tp rto res`, `ctu ctd`, `add sub
  mul div mod abs sqrt neg` — IEC names wherever IEC names the operation. `rto`, `res` and
  `neg` are the exceptions: the standard has no retentive timer, no standalone counter
  reset and no negate function, so those follow rule 2 and come from a vendor.
  `docs/naming.md` says which, per mnemonic.

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

## A configuration

A configuration runs instances of one or more programs as one resource: each instance on a
periodic task or on none, its `var_input`s and `var_output`s connected to globals, and the
globals located at the host's input and output points or not
([`docs/organisation.md`](docs/organisation.md) §4.4 to §4.6). Until the configuration
file lands, one is built from Elixir data with `Logex.Configuration.new!/1`, which checks
it and raises every problem at once. `Logex.Runtime.start/1` makes the resource, and
`cycle/3` steps it by the milliseconds the host says have passed, with the input points
that changed, returning every output point and what ran.

`plant.exs` — two instances of `motor.ld`, `m1` on a 10 ms task and `m2` on a 50 ms one,
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
      %Configuration.Task{name: "fast", interval: 10, priority: -1},
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
task `fast`: a priority is 0, the highest, to 65535, found -1
program instance `m2`: there is no task `slwo` — did you mean `slow`?
`pb_stop_1` is an input point: `m2.motor` cannot drive it
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
- A priority of -1 is a mistake no configuration file could hold, since a negative number
  does not lex, so `Logex.Configuration.check/1` raises it as the host's; the other two a
  file could hold, and `check/1` returns them as diagnostics, each cited at its line when
  a file gives one. `new!/1` raises them all, the host's first.

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

The diagnostic names no file, because a `%Logex.Program{}` keeps none, a gap Milestone 2
must close. A section change and a changed initial value are not type changes: the value
is kept, and the report says what changed.

During an edit the host scans, sets inputs and restarts through `Logex.Edit.running/1`,
and sends only that program's var_inputs. It resends each input a step reports as
`{:input, name, value}`, stops sending each one reported as `{:unread, name, value}`,
holds each point reported as `{:held, name, value}`, and ignores a report kind it does
not know.

A program built as data rather than text, through `Logex.Compiler.instructionize/2` and
`Logex.Tag.new!/4`, is refused with an `ArgumentError` where no text could say it, as a
negative literal or a timer's preset given from Elixir. So every program an edit takes
could be written as a `.ld` file.

An edit takes one lone instance. An instance a configuration runs is not edited until
OE-2, which edits a running configuration: a `%Logex.Runtime{}` is opaque, and changes
only through its API.

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

## Documents

- `PLAN.md` — the codebase review and the ordered plan of work
- [`docs/naming.md`](docs/naming.md) — the IEC and vendor naming survey, one stanza per mnemonic or declaration word
- [`docs/instruction-sets.md`](docs/instruction-sets.md) — what IEC 61131-3 specifies for ladder, clause by clause, and what free software (MatIEC/Beremiz, OpenPLC, LDmicro, ClassicLadder, rusty, IronPLC) actually implements
- `CONTRIBUTING.md` — how to work on it: when the test output misleads, what a fix owes, what not to "fix"
- `CLAUDE.md` — commands and conventions for anyone (or anything) editing the code
- [`docs/organisation.md`](docs/organisation.md) — program organisation: IEC's configurations, tasks, program instances and I/O mapping, the conventional family's hierarchy mapped onto them, and the logex form for them, and how a running controller is changed (decided; program instances landed with M1-5, the online edit of one with OE-1, and configurations with periodic tasks, from Elixir data, with M2-1; the rest of Milestone 2 is designed)
- [`docs/defladder.md`](docs/defladder.md) — a study of an Elixir-embedded `defladder` DSL: what Nx's `defn` does, an executed spike, and a recommendation (proposed, not adopted)

## License

Apache-2.0. See `LICENSE`.
