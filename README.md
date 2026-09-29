# logex

A Ladder Logic compiler and interpreter in Elixir. It compiles a ladder program written as
text into a named, stateless value, and runs it as instances, one scan at a time, with the
time the host injects. No dependencies and no generated code: the lexer and parser are
written by hand, and the whole thing is thirteen small modules.

**Stage: early, and honest about it.** Six instructions, parallel branches to arbitrary
nesting depth, latch/unlatch that holds across scans, power flow that resets per rung, a
typed tag table that every tag is declared in, a public API (`Logex.compile/2`,
`Logex.compile_file/1` and `Logex.Runtime`), and a printer that turns an AST back into
source so a routine round-trips — all of that works and is tested end to end, and a
program with mistakes in it gets every one reported with its line rather than an
exception, a misspelt tag included. What does not exist yet: timers and counters, and a
scheduler — the host calls one scan at a time. `PLAN.md` is a full review of the codebase and says precisely what is missing, in
what order it gets fixed, and why.

## The dialect

**logex is its own dialect. It does not aim to import vendor neutral text, and will not
become an importer.**

Source syntax today:

- declaration lines before the first rung, one tag each: `<section> <name> <type>
  [<initial>]`, the section `var`, `var_input` or `var_output`, the type `bool` or `dint`,
  as in `var_output speed_sp dint 1200`. Every tag a rung uses must be declared. A
  `var_input` is supplied from outside and no instruction may write it; a tag with no
  initial value starts at 0
- mnemonics, sections and types in any case (`xic`, `XIC`, `VAR_INPUT`), and reserved: no
  tag may be named after one, in any case, so `ote`, `Ote` and `bool` are never tags; tags
  are case-sensitive (`aa` and `AA` are two tags)
- operands separated by spaces — and a number must be followed by one: `move 1bst aa` is an
  error naming `1bst`, not the number `1` and a tag `bst`
- no operand parentheses, no terminator
- a newline ends a rung
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
  configuration file that instantiates `.ld` programs, wires them to I/O points and
  globals, and schedules them on tasks; `var_external` for shared globals; function blocks
  called with `cal`. Each new word still gets its `docs/naming.md` stanza, which may change
  a spelling.

- **`//` starts a comment**; `.` gives member access (`t1.dn`, `word.3`); negative integer
  literals lex.
- **Timers, counters, comparisons and math** arrive as `ton tof tp rto res`, `ctu ctd`,
  `eq ne lt gt le ge`, `add sub mul div mod abs sqrt neg` — IEC names wherever IEC names
  the operation. `rto`, `res` and `neg` are the exceptions: the standard has no retentive
  timer, no standalone counter reset and no negate function, so those follow rule 2 and
  come from a vendor. `docs/naming.md` says which, per mnemonic.

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

`scan/3` takes the milliseconds since the last scan, for the timers to come;
`Logex.Runtime.call/4` is one scan with the time given explicitly, which is what a
scheduler will call; `restart/3` starts an instance again, keeping its inputs.

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
- [`docs/organisation.md`](docs/organisation.md) — program organisation: IEC's configurations, tasks, program instances and I/O mapping, the conventional family's hierarchy mapped onto them, and the logex form for them (decided; program instances landed with M1-5, configurations and tasks are Milestone 2)
- [`docs/defladder.md`](docs/defladder.md) — a study of an Elixir-embedded `defladder` DSL: what Nx's `defn` does, an executed spike, and a recommendation (proposed, not adopted)

## License

Apache-2.0. See `LICENSE`.
