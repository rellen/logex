# rf-T-correct · refutation of the T-synth configuration-text spike, correctness lens

Label rf-T-correct. Written 2026-10-02. Target: `scratchpad/m2/T-synth-work` (T1's patch on
`47319f7`, plus T-synth's fixes), read against `T-synth.md` §1-§3 and `docs/organisation.md`
§4.4-§4.8 at `47319f7`. `/home/user/logex` was not modified (`git status --short` is empty,
HEAD `47319f7`). Work was done in a `cp -a` of `T-synth-work`
(`scratchpad/m2/rf-T-correct-work`), now deleted. The probe scripts are kept in
`scratchpad/m2/rf-T-correct-probe/` (`helpers.exs`, `p1.exs` to `p10.exs`). Each was run
from the copy as `source scratchpad/toolchain/env.sh && mix run probe/pN.exs`, on Elixir
1.20.4 / OTP 28, and each exited 0.

`P.c(label, source)` in `helpers.exs` runs `Logex.Configuration.compile("plant", source,
programs)` against three types compiled from source. `motor` has var_inputs `start`, `stop`
and `sp` (a dint), var_outputs `motor` and `speed_sp`, and `var fault`. `ext` has
`var_input start`, `var_external estop bool` and `var_external count dint`, and writes both.
`timed` has `var_input start`, `var_output done` and runs `ton t1 100`. Each diagnostic is
printed with `Logex.Diagnostic.format/1`.

## What holds

These were probed and agree with T-synth §3 word for word:

- Every reader message T1-T34, each at its column (`p8.exs`, 51 lines).
- Check messages C1-C20, C25-C48, W1-W6a and W6b (`p1`, `p2`, `p3`, `p8`, `p9`).
- CRLF, a lone CR, comments and blank lines read the same as LF, with the same line
  numbers (`p1`, `p9`). With `"\r\n\r"` each line end counts twice, as the lexer's B8
  rule gives.
- Keywords match in any case, and names are case-sensitive.
- A location takes one spelling (`panel.I.0`, `panel.i.00`), and a located input or output
  refuses an initial value.
- Out-of-range values are refused at max+1 and at a bignum: an interval of 0, an interval
  or a priority of 2147483648, and a dint constant or initial value of 2147483648.
- A negative number is a `:lex` error.
- var_external is refused when it is missing, of the wrong type, a task, an instance, an
  input point it writes, or connected as a member. Two writers (W4) and a writer plus a
  driver (W5) are warnings.
- The loader gives F1-F5b and F6-F9 as listed. A type file's own diagnostics come last,
  each with its file.
- The valid path is linear. 4x the instances cost **3.87x** the reductions (`p6.exs`: n=250
  gives 559,553 reductions, n=1000 gives 2,166,019).

## Findings

### rf-T-correct-1 (medium) An improper list escapes as `FunctionClauseError` from four public calls

R60 and CLAUDE.md ("Nothing else may escape the public API") both require a pinned
`ArgumentError`. `entries!/1` only guards `is_list/1`, and `Enum.each/2` then fails on the
tail.

```
g = {:global, nil, %{name: "a", type: :bool, initial: nil, at: nil}}
Text.print([g | :x])            => FunctionClauseError
Configuration.new!("plant", [g | :x], %{})  => FunctionClauseError
Text.entries!([g | :x])         => FunctionClauseError
Configuration.check("plant", [g | :x], %{}) => FunctionClauseError
```

The seeded totality test misses this because `junk/1`
(`configuration_test.exs:1743-1781`) builds only proper lists.

**Fix:** in `entries!/1`, check the list is proper (for example `length/1` inside a `try`,
or a recursive `proper?/1`) and raise H8. Add an improper list to `junk(0)`.

### rf-T-correct-2 (medium) A line holding `(`, `|` or `)` declares nothing, so one stray character cascades

R13 says "A broken line still declares its name, and a broken connection still connects
its var_input". T-synth §1.1 says the same: "For a broken line whose name it could read, it
gives a placeholder". But `grouped/2` returns `[]` declared for any line with a delimiter,
before the line is read.

```
task fast interval 10 priority 1
var_global g bool
program m1 motor ( with fast
m1.start g / m1.stop 0 / m1.sp 0
  line 3, column 18: a configuration line cannot hold `(`
  line 4: no instance `m1`: declare it, as in `program m1 motor`
  line 5: no instance `m1`: declare it, as in `program m1 motor`
  line 6: no instance `m1`: declare it, as in `program m1 motor`
  this configuration declares no `program`: it would run nothing
```

The other line kinds behave the same way:

- `task fast interval 10 | priority 1` gives `| ` and then `line 3: no task `fast``.
- `var_global g bool )` gives `)` and then `line 4: no global `g``.
- `m1.start ( g` gives `(` and then `line 3: `m1` leaves its var_input `start` unconnected`.

**Fix:** read the line's leading words before refusing the delimiter, so the line yields
the same `{:declared, …}` placeholder as any other broken line. Test it with one delimiter
per line kind, asserting the whole list.

### rf-T-correct-3 (medium) `entries!/1` and `print/1` accept entries the reader refuses, so `print/1` emits text that does not read back

`entries!/1` is documented as "the text's own definition of its data, as
`Logex.Parser.well_formed!/1` is a program's". R48 says "An entry no line could say raises
`ArgumentError` from … `print/1` and `entries!/1` alike". `name!/2` checks only that a value
lexes as one name token. It does not check the reader's position rules: a type word or `at`
cannot name a global (T18), an input word cannot name a task (T9), `with` cannot be a
program type (T30), and an input word cannot be a `single` (T13).

```
Text.entries!([{:global, nil, %{name: "at", ...}}])  => :ok
Text.print(…"at"…)  => "var_global at bool\n"
Text.read(Text.print([global "AT"]))   => {:error, ["`var_global` needs a name before `AT`…"]}
Text.read(Text.print([task "single"])) => {:error, ["`task` needs a name before `single`…"]}
Text.read(Text.print([program type "with"])) => {:error, ["`program m1` needs a program type before `with`…"]}
Text.read(Text.print([task single: "interval"])) => {:error, ["`single` needs a bool global…, found `interval`"]}
Text.read(Text.print([global "bool"])) => {:error, [...needs a name before `bool`...]}
```

`check/3` still reports these as `:configure` diagnostics (C1, C18, C43), so the
constructor's round trip (R49) holds. The definition function and `print/1` do not.

**Fix:** in `entries!/1`, refuse a keyword (in any case) in each name position the reader
refuses: a global's name if it is `at`, `bool` or `dint`; a task's name or `single` if it
is an input word; a program type of `with`. Alternatively, refuse every keyword in every
name position, and make C1 and C18 text-only. Add a property that `read(print(e))` is
`{:ok, e}` for every `e` that `entries!/1` accepts.

### rf-T-correct-4 (low) A dotted name after `with` gets a global's or a member's message

`undeclared(true, …)` ignores the wanted kind. R57 is scoped to "a location where a global
is wanted (a connection's source or sink, a `single`)", and R58 to connections. But `with`
wants a task:

```
program m1 motor with panel.i.0
  line 3: `panel.i.0` is a location, written only after `at` on a `var_global` line: declare a global at it, as in `var_global point bool at panel.i.0`, and name that
program m1 motor with m1.start
  line 3: `m1.start` is an instance's member: instances share a value only through a global, which one drives and the other reads
program m1 motor with x.y
  line 3: `x.y` names a member of an instance, and there is no instance `x`
```

In the first case the message tells the user to put a global after `with`, which is wrong
advice. org §4.7 asks that "each wrong reading gets a diagnostic that names it", and none
of these is the reading of a task position.

**Fix:** branch on the wanted kind. For `:task`, say a task's name has no `.` (as C2
does), or say `no task` with a did-you-mean.

### rf-T-correct-5 (low) The file-kind messages contradict themselves for a dotfile name or a trailing `/`

`Path.extname/1` gives `""` for `.lxcf`, `x.lxcf/` and `motor.ld/`. Both loaders then
print a message that refutes itself:

```
Configuration.compile_file(".lxcf")   => "`.lxcf` is not a configuration file: a configuration's file ends in `.lxcf`, as in `plant.lxcf`"
Configuration.compile_file("x.lxcf/") => "`x.lxcf` is not a configuration file: a configuration's file ends in `.lxcf`…"
Configuration.compile_file("")        => "`` is not a configuration file…"
Logex.compile_file("motor.ld/")       => "`motor.ld` has no extension: a program's file ends in `.ld`, as in `motor.ld.ld`"
Logex.compile_file(".lxcf")           => "`.lxcf` has no extension: … as in `.lxcf.ld`"
Logex.compile_file("")                => "`` has no extension: … as in `.ld`"
```

T-synth fixed exactly this shape for `.ld` (F9, JT1 D9). The configuration loader has no
counterpart, and F7 has no guard for a trailing separator or an empty basename.

**Fix:** give a bare `.lxcf` an F9-like message. Let a path ending in `/`, or with an empty
basename, fall through to `cannot be read`, or give it its own message.

### rf-T-correct-6 (low) An `interval 0` on a `single` task is advised to drop `with`

C6 is the same for every task:

```
task fast single g interval 0 priority 1
  line 1: the interval of `fast` is 0: an interval is at least 1 ms, and an instance that runs every cycle is declared without `with`
```

Under IEC rule 2 (org §4.4, Tasks), `single g interval 0` means event-only. The intended
fix is to drop `interval`. Dropping `with`, as advised, turns an event instance into a
cyclic one.

**Fix:** for a task with `single`, give a second C6 text, for example "… is 0: leave
`interval` out for a task that runs only on its events".

### rf-T-correct-7 (low) C45's example writes a location in the spelling C16 refuses

```
m1.start panel.I.0      (no global there)
  line 3: `panel.I.0` is a location, …: declare a global at it, as in `var_global point bool at panel.I.0`, and name that
```

Following that advice gets C16 next. `where_located(nil, name)` prints the location as
written. It should print `canonical_text(key)`, which the `{:respell, key}` branch
already has.

**Fix:** pass the parsed key into `where_located/2` and print its one spelling.

### rf-T-correct-8 (low) A refused declaration is not a placeholder, so references to it are reported again, sometimes misread

R52 and R56 cover broken lines and locations only. When a whole line is refused for its
name (declared twice, a keyword, a `.`, or a case twin), nothing enters it into the
namespace:

```
task program interval 10 priority 1 / program m1 motor with program
  line 1: `program` is a keyword and cannot name a task
  line 3: no task `program`: `program` is a keyword …
task a.b interval 10 priority 1 / program m1 motor with a.b
  line 1: `a.b` cannot name a task: …
  line 3: `a.b` names a member of an instance, and there is no instance `a`
program m1 motor … / program m1 timed with fast / m1.done d
  line 8: `m1` is declared twice: first on line 4, as an instance
  line 9: `m1` is a `motor`, which declares no `done`
```

The `.ld` side does not recover a bad name either
(`lib/logex/declarations.ex:190-194`, "A bad name is not recovered"). So this is house
practice, not a regression. The second and third cases still give a wrong reading, or
blame the wrong instance.

**Fix:** decide in §13 whether a refused declaration is a placeholder. At least add the
name to `broken`, so later references are skipped.

### rf-T-correct-9 (low) The error path is quadratic: 15.8x for 4x

R50 claims linearity for the valid path only. The valid path holds at 3.87x. But each
undeclared reference runs `names_of/2` and `Declarations.suggest/4` over every declared
name (`p6.exs`):

```
bad global: n=250 7,303,941 red 45ms;  n=1000 115,556,679 red 830ms; ratio 15.82
bad task:   n=250 7,335,253 red 48ms;  n=1000 115,292,470 red 725ms; ratio 15.72
```

The `.ld` compiler does the same for undeclared tags (`p7.exs`: ratio **16.03**). This is
inherited house practice, not new to the spike. A 10,000-line file with a wrong name on
each line would take roughly 80 s.

**Fix:** none needed for M2. Note it in §12 (risks), or compute the per-kind candidate list
once.

### rf-T-correct-10 (low) A location's device part is unchecked: case twins and instance clashes

- `var_global g bool at panel.i.0` and `var_global h bool at Panel.i.0` compile with no
  diagnostic, as two points.
- With `var_global g bool at m1.i.0` and `program m1 motor`, the line `m1.start m1.i.0`
  gives "`m1.i.0` is an instance's member: …" (C26). It is the location of a declared
  global, and C44 would be the right message.

R15 refuses names that differ only in case because "these would be two". The device names
`panel` and `Panel` are the same hazard, and the host binds devices by name
(org §4.5, `io: %{"panel" => …}`).

**Fix:** a §13 question: is a device name case-folded and kept apart from instance names?
At least, in `dotted/5`, prefer a declared location's reading over a member of an instance
that has no such member.

### rf-T-correct-11 (low) `print/1` allocates one newline per line number

```
Text.print([{:task, 50_000_000, %{name: "a", single: nil, interval: 1, priority: 1}}]) |> byte_size()  => 50000028
```

`entries!/1` puts no bound on a line, so a host mistake costs memory in proportion to the
line number.

**Fix:** none needed for a spike. If `print/1` lands, either note this in its doc or cap a
line from Elixir.
