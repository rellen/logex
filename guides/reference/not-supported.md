# What logex does not have

This page is for a reader who looks up 1 feature and asks if logex has it. The reader can
be a controls engineer who ports a [program](glossary.md#program) from a controller. The
reader can also be an Elixir developer who wants to know if logex can do a job. For each
feature that logex does not have, the page gives what logex does when a program or a
[host](glossary.md#host) uses it. It also gives what to use in its place, and the page
with the rules.

> #### Warning {: .warning}
>
> Do not use logex for a [safety function](glossary.md#safety-function). logex is not a
> safety controller, and it has no certificate for any industrial use. The emergency
> stop that cuts the power of a machine must work with no part of logex. It must work
> after logex stops or crashes, and before logex starts.
> [Safety and limits](../explanation/safety-and-limits.md) gives each limit and its
> reason.

| To find | Go to |
|---|---|
| What logex is not: safety, time, outputs, I/O | [What logex is not](#what-logex-is-not) |
| Other languages, editors and imports | [Languages and tools](#languages-and-tools) |
| Types, sections and qualifiers | [Declarations](#declarations) |
| Forms of a number, a time or a text | [Literals](#literals) |
| Bounds, subscripts and copies of an array | [Arrays](#arrays) |
| A byte of a word, a bit of a real | [Bits](#bits) |
| Rounding, a conversion, NaN and infinity | [Arithmetic and conversions](#arithmetic-and-conversions) |
| `res`, a master control zone, a jump back, a preset in a tag | [Instructions](#instructions) |
| Resources, `program retain` and retained points | [Configurations](#configurations) |
| A change of type while the program runs | [Online edits](#online-edits) |
| A force of an output | [Forces](#forces) |
| Persistent values, a first-scan bit, a prescan, a hot restart, the store | [Restarts and retained values](#restarts-and-retained-values) |
| Each message in full, from a run | [Each message in full](#each-message-in-full) |

Each table after [What logex is not](#what-logex-is-not) has the same 3 columns:

- "logex does not have" gives the feature.
- "What logex does" gives the [diagnostic](glossary.md#diagnostic) or the result.
- "Use" gives the feature of logex that does the work. "No replacement" tells you that
  logex has none.

A wrong text is a line of source text that logex refuses. Each wrong text has a number,
and the tables give that number. [Each message in full](#each-message-in-full) gives
each wrong text with its full message.

## What logex is not

| logex is not | The rule |
|---|---|
| A safety controller | Do not use logex for a safety function. Examples are an emergency stop, a guard interlock, a light curtain and a 2-hand control. The protection of a burner and the protection against pressure are also safety functions. Put each safety function in hardwired circuits or in a safety-rated controller. logex makes no claim against any functional-safety standard. |
| Certified | logex has no certificate for any industrial use. |
| Hard real-time | logex gives no limit for how late a [round](glossary.md#round) is, or for how much the time between 2 rounds changes. A [watchdog](glossary.md#watchdog) [trips](glossary.md#trip) the [runner](glossary.md#runner) after a [task](glossary.md#task) runs too long. It does not stop a task from running too long. |
| A guarantee that each output point goes to 0 after a failure | After a trip, logex writes the value 0 to each output point 1 time, if it can still write the point. It does the same after the runner stops or crashes, after a kill of the runner, and after a failure of a [device](glossary.md#device). If a device gets no message from the runner before a deadline, logex writes 0 to its output points 1 time. logex kills a device that hangs. Its output points then do what its hardware does when it gets no message. If the Elixir virtual machine stops, no part of logex runs. |
| A guard against an output point that a warm start sets to 1 | Each output point is 0 until the first round after a start writes it. A rung that reads a value with the qualifier [`retain`](glossary.md#retain) can write 1 to an output point in that first round. Thus a warm start can set an output point to 1 in its first round. [Retained values](retained-values-and-store.md) gives the rules. |
| A rule for a computer that sleeps | logex has no rule for what a sleep of the computer does to the [clock](glossary.md#clock) of a runner. |
| A compiler to BEAM code | A program [compiles](glossary.md#compile) to data, a `%Logex.Program{}`, and `Logex.Runtime` interprets it. |
| A set of adapters for real I/O | The only [adapter](glossary.md#adapter) in logex is `Logex.IO.Sim`, for a [simulated device](glossary.md#simulated-device). The host writes the adapter of each real device, with the behaviour `Logex.IO`. |
| An editor or a compiler of [IEC 61131-3](glossary.md#iec-61131-3) text | logex reads only its own [dialect](glossary.md#dialect): ladder logic as text. [Languages and tools](#languages-and-tools) gives each part. |

A program can miss a short pulse on an input [point](glossary.md#point). The runner
keeps only the latest value of each input point. A pulse that rises and falls between 2
rounds does not get to the program, unless it is the [trigger](glossary.md#trigger) of an
[event task](glossary.md#event-task). The program also does not see a pulse that is
shorter than the time between 2 reads of its device, unless the device reports it.
[Safety and limits](../explanation/safety-and-limits.md) gives the reasons and the cases.

## Languages and tools

| logex does not have | What logex does | Use |
|---|---|---|
| Structured Text, Function Block Diagram, Sequential Function Chart, Instruction List | A diagnostic. Example: ``illegal character ":"`` for an assignment `:=` (wrong text 1), ``unknown instruction `LD` `` (wrong text 2). | [Rungs](glossary.md#rung) in the dialect of logex. [Source syntax](source-syntax.md) gives the syntax. |
| A graphical editor | logex has no editor. A program is a text file. | A text editor |
| The text of IEC 61131-3, or the export file of a vendor tool | logex reads neither. It has the [mnemonics](glossary.md#mnemonic) of the [conventional set](glossary.md#conventional-set), but not its [operands](glossary.md#operand), such as `T4:5/DN`. | Write each rung again. [Port a program](../howto/port-a-program.md) gives the steps. |
| A subroutine and `jsr` | ``unknown instruction `jsr` `` (wrong text 3) | A [function block](glossary.md#function-block), and `cal` to run it. [Function blocks](function-blocks.md) gives the rules. |
| A function, IEC `FUNCTION` | A `.ld` file holds a program or a function block. logex reads `function` as an instruction: ``unknown instruction `function` ``. | A function block |

[The dialect and IEC 61131-3](../explanation/the-dialect-and-iec.md) explains why logex
has its own dialect.

## Declarations

logex has 15 [elementary types](glossary.md#elementary-type): `bool`, 8 integer types,
the 4 [bit strings](glossary.md#bit-string) and the 2 real types. It also has
[arrays](glossary.md#array) of these types. The [timers](glossary.md#timer), the
[counters](glossary.md#counter) and the function blocks are
[function block types](glossary.md#function-block-type).
[Declarations and types](declarations-and-types.md) gives each rule.

A type word that logex does not have gives ``unknown type `<word>` ``, then the list of
the type words of logex, as wrong text 4 shows. The message can end with a type word of
logex that is near in spelling: ``did you mean `tp_ltime`?`` for `ltime`.

| logex does not have | What logex does | Use |
|---|---|---|
| A time type: `time`, `ltime` | ``unknown type `time` `` (wrong text 4) | An integer [preset](glossary.md#preset): ms for a timer, ns for a [long timer](glossary.md#long-timer) |
| A date type or a time of day: `date`, `tod`, `time_of_day`, `date_and_time` | ``unknown type `date` `` | No replacement. The host can give a date to the program as integers. |
| A string or a character: `string`, `wstring`, `char` | ``unknown type `string` `` (wrong text 5) | No replacement |
| A structure or a user-defined type | ``unknown type`` with its name | Separate [tags](glossary.md#tag), or a function block that holds its tags with its logic |
| An enumeration | ``illegal character ","`` (wrong text 6) | An integer tag, and 1 integer for each value of the enumeration |
| A subrange, `int(0..10)` | ``"0..10" is no number`` (wrong text 7) | The integer type, and a comparison of the value |
| A reference or a pointer, `ref_to` | `` `var` declares one tag: found `p` and `ref_to` before the type `` (wrong text 8) | An array, and a [subscript](glossary.md#subscript) in a tag |
| The qualifier `constant` | `` `var` declares one tag: found `constant` and `limit` before the type `` (wrong text 9) | A tag with an [initial value](glossary.md#initial-value) that no rung writes |
| The [sections](glossary.md#section) `var_in_out` and `var_temp` | ``unknown instruction `var_in_out` `` (wrong texts 10 and 11). logex reads the line as a rung. | For `var_in_out`: a `var_input` and a `var_output`. For `var_temp`: `var`. |
| A located tag in a program | ``illegal character "%"`` for the IEC address `at %IX0.0` (wrong text 12). ``unexpected `at` after the declaration of `gate` `` for the address `at panel.i.0` (wrong text 13). | A [located global](glossary.md#located-global) in a [configuration file](glossary.md#configuration-file): `var_global eye bool at panel.i.0`. [Configuration file](configuration-file.md) gives the rules. |

## Literals

[Literals](literals.md) gives each form of a [literal](glossary.md#literal) that logex
reads.

| logex does not have | What logex does | Use |
|---|---|---|
| A time literal, `T#5s` | ``illegal character "#"`` (wrong text 14) | An integer preset: `ton t1 5000` |
| A typed literal, `int#5` | ``illegal character "#"`` (wrong text 15) | The plain literal, `5`. The tag sets the type. |
| An octal literal, or a base that is not 2 or 16 | ``"8#17" is no number``, then the 2 bases (wrong text 16) | `16#0f` or `2#1111` |
| A character or a string literal | ``illegal character "'"`` (wrong text 17) | No replacement |
| `true` and `false` | `` `true` is not declared `` (wrong text 18). logex reads the word as the name of a tag. | `1` and `0` |

## Arrays

An array of logex has 1 to 3 dimensions. The subscripts of each dimension start at 0. A
subscript is a literal or the name of a tag. [Use arrays](../howto/use-arrays.md) gives
the steps, and [Declarations and types](declarations-and-types.md) gives the rules.

| logex does not have | What logex does | Use |
|---|---|---|
| More than 3 dimensions | `` `grid` is declared with 4 dimensions `` (wrong text 19) | 3 dimensions or fewer |
| IEC bounds, `array[1..8] of int` or `int[1..8]` | ``"array[1..8]" is no name`` (wrong texts 20 and 21) | `int[8]`, with the subscripts 0 to 7 |
| An expression as a subscript, `weights[slot+1]` | ``"weights[slot+1]" is no name`` (wrong text 22) | A tag that holds the subscript: `add slot 1 next`, then `weights[next]` |
| A copy or a fill of a full array | `` `move` reads one tag, but `weights` is an array of 8 ints `` (wrong texts 23 and 24) | 1 [instruction](glossary.md#instruction) for each [element](glossary.md#element) |
| A subscript in a tag for an array of timers, counters or function blocks | `` `ton` runs `lane_t[slot]`, whose subscript `slot` holds `` (wrong text 25) | A literal subscript: `ton lane_t[2] 1000`, 1 instruction for each element |
| A change of the size of an array while the program runs | See [Online edits](#online-edits) | A [restart](glossary.md#restart) |

## Bits

| logex does not have | What logex does | Use |
|---|---|---|
| Access to 1 byte or 1 word of a bit string, `status.%B1` | ``illegal character "."`` (wrong text 26) | A shift and a conversion: `shr status 8 tmp`, then `word_to_byte tmp high`. [Instructions: bitwise](instructions-bitwise.md) gives the rules. |
| A bit of a real, `speed.3` | `` `speed.3` names a bit of `speed`, a real, which has no bits `` (wrong text 27) | No replacement |

[Use bit strings](../howto/use-bit-strings.md) gives the steps for 1
[bit](glossary.md#bit), such as `status.3`.

## Arithmetic and conversions

A real tag never holds a NaN, an infinity or `-0.0`.

| logex does not have | What logex does | Use |
|---|---|---|
| `round`, `ceil` and `floor` | ``unknown instruction `round` `` (wrong texts 28 to 30) | A [conversion](glossary.md#conversion) such as `real_to_dint`. It writes the nearest integer. A value halfway between 2 integers goes to the even integer: 2.5 becomes 2. `real_trunc_dint` removes the fraction. |
| A conversion from a `bool` into an integer, or into a `bool` | ``unknown instruction `bool_to_int` `` (wrong texts 31 and 32). `move` writes a `bool` into a bit string, but not into an integer. | From a `bool`: `move eye b`, with `b` a `byte`, then `byte_to_dint b count`. Into a `bool`: a comparison and a [coil](glossary.md#coil), `ne slot 0 ote lamp`. |
| A conversion from BCD, or into BCD | ``unknown instruction `bcd_to_int` `` (wrong texts 33 and 34) | No replacement |
| A conversion of the bit pattern of a real | ``unknown instruction `real_to_dword` `` (wrong text 35) | No replacement |
| NaN or an infinity from a result out of range | No diagnostic. The instruction writes the largest value of the type, or the lowest value for a negative result. It passes no power. | A coil after the instruction: `mul a b r ote ok`. The coil is 0 when the result is out of range. |
| NaN or an infinity from a divisor of 0 | No diagnostic. The instruction writes `0.0` and passes no power. It gives the [minor fault](glossary.md#minor-fault) `:divide_by_zero`. | A coil after the instruction, as for a result out of range |

[Conversions](conversions.md) gives each conversion that logex has, and
[Instructions: arithmetic and comparison](instructions-arithmetic-and-comparison.md)
gives the rules of a result.

## Instructions

| logex does not have | What logex does | Use |
|---|---|---|
| `res` | ``unknown instruction `res` `` (wrong text 36) | A coil on the [member](glossary.md#member) `r` of a `ctu`, a `ctud` or an `rto`: `xic pb ote boxes.r`. A `ctd` has no `r`: its member `ld` sets the count to the preset. A `ton`, a `tof` and a `tp` have no `r`. A [false rung](glossary.md#false-rung) resets a `ton`. A [true rung](glossary.md#true-rung) resets a `tof`. A false rung resets a `tp` after its pulse. |
| A master control zone, `mcr` | ``unknown instruction `mcr` `` (wrong text 37) | A [contact](glossary.md#contact) at the start of each rung. On a false rung, each `ote` writes 0. A `cal` on a false rung does not do this: its function block does not run and keeps its outputs. |
| A [jump](glossary.md#jump) back | `` `jmp top` jumps back, to the rung on line 17 `` (wrong text 38) | A jump forward, to a [label](glossary.md#label) on a later rung |
| A preset in a tag: `ton t1 count` | `` `ton` takes its preset as a number of milliseconds, found `count` `` (wrong text 39) | 2 rungs: `xic start move count t1.pre`, then `xic start ton t1 1000`. The literal is the preset until the `move` writes `pre`. |
| A time of less than 1 ms | A [warning](glossary.md#warning) for a long timer (wrong text 44). Each timer counts full ms of the clock, a long timer also. A preset of 500 ns times as 1 ms. | A preset in full ms |

[Instructions: timers and counters](instructions-timers-and-counters.md) and
[Instructions: jump and call](instructions-jump-and-call.md) give the rules.

## Configurations

A [configuration](glossary.md#configuration) runs as 1
[resource](glossary.md#resource). [Configuration file](configuration-file.md) gives the
rules of the file.

| logex does not have | What logex does | Use |
|---|---|---|
| More than 1 resource in a configuration, and the lines `resource` and `configuration` | ``unknown configuration line `resource` `` (wrong texts 45 and 46) | 1 configuration for each resource, and 1 runner for each configuration |
| `retain` on a `program` line, IEC `PROGRAM RETAIN` | `` `retain` before an instance's name is IEC's `PROGRAM RETAIN`, which logex does not have `` (wrong text 47) | `retain` on each tag to keep, in the program: `var retain count dint` |
| A retained located global | `` `eye` is an input point, and a located global takes no `retain` `` (wrong text 48). The runner reads an input point again at each start. An output point is 0 at each start until a program writes it. | No replacement for the point. To keep a value that a rung takes from the point, use `retain` on a tag of the program: `var retain kept bool`. |
| `persistent` on a global | ``unknown type `level` `` (wrong text 49). logex reads `persistent` as the name. | `retain` on the [global](glossary.md#global), `var_global retain level dint`, and a warm restart |

## Online edits

An [online edit](glossary.md#online-edit) changes a program while it runs.
[Online edit](online-edit.md) gives each rule.

| logex does not have | What logex does | Use |
|---|---|---|
| A change of the [type](glossary.md#type) of a tag or of a member | `` `hours` is a dint in the running program and an int in the candidate: a tag's type changes only with a restart `` (wrong text 50). logex refuses the same change for a member of a function block, and for an instance whose function block has a new name. | A restart with the new program |
| A change of the size of an array | `` `temps` is an array of 4 ints in the running program and an array of 8 ints in the candidate `` (wrong text 51) | A restart with the new program |

## Forces

[Forcing](forcing.md) gives each rule of a [force](glossary.md#force).

| logex does not have | What logex does | Use |
|---|---|---|
| A force of an output point | The runner raises an `ArgumentError`: `` `fan_out` is an output point, at `panel.q.0`: only an input point is forced `` (the line `force fan_out` of [the plant](#wrong-texts-45-to-51-and-the-host-calls-a-plant)) | No replacement |
| A force in `Logex.Runtime` | `Logex.Runtime` has no function for a force. Only the runner forces. | `Logex.Runner.force/3`, on a runner started with the option `forces:` |
| A retained force | The [store](glossary.md#store) keeps no force. | The [forces file](glossary.md#forces-file) keeps the forces. |

## Restarts and retained values

A [warm restart](glossary.md#warm-restart) keeps each value with the [qualifier](glossary.md#qualifier)
`retain`. A [cold restart](glossary.md#cold-restart) discards each
retained value. [Retained values](retained-values-and-store.md) and
[The store](store.md) give the rules.

| logex does not have | What logex does | Use |
|---|---|---|
| `persistent` values, kept across a cold restart | `` `var` declares one tag: found `persistent` and `total` before the type `` (wrong texts 42 and 43). logex reads `persistent` as a name. | `retain` on the tag, and a warm restart |
| A first-scan bit, such as `S:FS` of the conventional set | ``illegal character ":"`` (wrong text 40). A tag `first_scan` is a tag like each other tag: `` `first_scan` is not declared `` (wrong text 41). | A tag of the program, `var first bool 1`, that the last rung [unlatches](glossary.md#latch). [Keep values across a restart](../howto/keep-values-across-a-restart.md) gives the steps. |
| A prescan, a pass that prepares each instruction before the first scan | logex runs no prescan before the [first scan](glossary.md#first-scan). | No replacement. [Execution model](execution-model.md) gives the rules of the first scan. |
| A hot restart, a restart that continues each value as at the stop | `Logex.Runtime.restart/3` raises an `ArgumentError`: ``restart takes :cold or :warm, got: :hot`` (the line `restart :hot` of [the plant](#wrong-texts-45-to-51-and-the-host-calls-a-plant)) | A warm restart |
| A warm restart that starts some tags cold | An `ArgumentError` of the same form (the next line of [the plant](#wrong-texts-45-to-51-and-the-host-calls-a-plant)) | `retain` only on the tags to keep |
| 1 element of an array retained alone | The qualifier is on the [declaration](glossary.md#declaration) of the array. logex retains the whole array. | A separate tag, or a separate array |
| A count of the time of a stop | A retained timer continues from its `acc`. In the first [scan](glossary.md#scan) after a restart, the timer adds only the time that the host gives to that scan. It does not add the time while logex did not run. | No replacement |
| A store for each [instance](glossary.md#instance) | `Logex.Runtime` reads and writes no file. A runner with the option `retain:` keeps 1 store for its resource. | A runner |
| An encryption of the store, or a protection of its values against a person | A start reads the end line of the store, and refuses a store that is cut short. It refuses a value line that a person changed and whose `digest` line the person did not mend. A person who mends the `digest` line can change each value. The 1 scheme of a digest is `md5`, which has no key. | No replacement |
| Battery-backed memory or safety memory | In `Logex.Runtime`, a retained value is in memory only. A runner started with the option `retain:` keeps it in its store, a file on the disk of the host. A runner without `retain:` keeps it in memory only, and a crash of the runner loses it. | No replacement |

> #### Warning {: .warning}
>
> Do not keep a value of a safety function in logex. Examples are the lockout of a
> burner, a latch that the opening of a guard sets and a count of trips. A person can edit
> the store. A cold restart discards the value. A crash can set the value back to the last
> write of the store.

## Each message in full

The 2 scripts of this part give each message of this page. Each script reads the file
[`instructions-contacts-and-coils/report.exs`](instructions-contacts-and-coils.md#the-tags-of-the-wrong-rungs),
which prints each text and each message in lines of 80 characters or fewer. The directory
`examples` of the repository is a Mix project, and logex is its dependency. To run a
script, give its command in that directory.

### Wrong texts 1 to 44: programs

Each wrong text from 1 to 43 comes after the 16 declarations of the tags, and thus it
starts on line 17. Wrong text 44 is a full program with a long timer.

```elixir
{report, _} = Code.eval_file("instructions-contacts-and-coils/report.exs")

# The tags of a conveyor with a box counter. Each wrong text comes after them.
tags = """
var_input  start    bool
var_input  stop     bool
var_input  eye      bool
var_output motor    bool
var_output lamp     bool
var        boxes    ctu
var        t1       ton
var        lane_t   ton[4]
var        slot     int
var        count    dint
var        speed    real
var        status   word
var        pattern  dword
var        low      byte
var        weights  int[8]
var        copy     int[8]
"""

texts = [
  # The language
  "IF start THEN motor := 1; END_IF;",
  "LD start",
  "xic start jsr belt",
  # The declarations
  "var delay time",
  "var label string",
  "var colour (red, green)",
  "var level int(0..10)",
  "var p ref_to int",
  "var constant limit int 5",
  "var_in_out belt bool",
  "var_temp scratch int",
  "var_input gate bool at %IX0.0",
  "var_input gate bool at panel.i.0",
  # The literals
  "xic start ton t1 T#5s",
  "xic start move int#5 slot",
  "xic start move 8#17 slot",
  "xic start move 'a' slot",
  "xic start move true motor",
  # The arrays
  "var grid int[2,2,2,2]",
  "var bins array[1..8] of int",
  "var bins int[1..8]",
  "xic start move 1 weights[slot+1]",
  "xic start move weights copy",
  "xic start move 0 weights",
  "xic start ton lane_t[slot] 1000",
  # Bits
  "xic start move status.%B1 low",
  "xic speed.3 ote lamp",
  # Arithmetic and conversions
  "xic start round speed count",
  "xic start ceil speed speed",
  "xic start floor speed speed",
  "xic start bool_to_int eye count",
  "xic start int_to_bool slot lamp",
  "xic start bcd_to_int status slot",
  "xic start int_to_bcd slot status",
  "xic start real_to_dword speed pattern",
  # Instructions
  "xic start res t1",
  "xic start mcr",
  "lbl top\nxic start ote motor\nxic stop jmp top",
  "xic start ton t1 count",
  # The first scan and retained values
  "xic s:fs ote lamp",
  "xic first_scan ote lamp",
  "var persistent total dint",
  "var retain persistent total dint"
]

report.(1, texts, &Logex.compile(tags <> &1, name: "wrong"))

# A lamp that a long timer switches on. The preset is in ns.
lamp =
  "var_input start bool\nvar_output lamp bool\nvar long_t ton_ltime\n" <>
    "xic start ton long_t 500\nxic long_t.dn ote lamp"

report.(44, [lamp], &Logex.compile(&1, name: "lamp"))
```

```console
$ mix run not-supported-program.exs
 1  IF start THEN motor := 1; END_IF;
      line 17, column 21: illegal character ":"
 2  LD start
      line 17: unknown instruction `LD`
 3  xic start jsr belt
      line 17: unknown instruction `jsr`
 4  var delay time
      line 17: unknown type `time`: logex has `bool`, `sint`, `int`, `dint`,
      `lint`, `usint`, `uint`, `udint`, `ulint`, `real`, `lreal`, `byte`,
      `word`, `dword`, `lword`, `ctd`, `ctd_dint`, `ctd_int`, `ctd_lint`,
      `ctd_udint`, `ctd_ulint`, `ctu`, `ctu_dint`, `ctu_int`, `ctu_lint`,
      `ctu_udint`, `ctu_ulint`, `ctud`, `ctud_dint`, `ctud_int`, `ctud_lint`,
      `ctud_udint`, `ctud_ulint`, `rto`, `rto_ltime`, `tof`, `tof_ltime`, `ton`,
      `ton_ltime`, `tp` and `tp_ltime`
 5  var label string
      line 17: unknown type `string`: logex has `bool`, `sint`, `int`, `dint`,
      `lint`, `usint`, `uint`, `udint`, `ulint`, `real`, `lreal`, `byte`,
      `word`, `dword`, `lword`, `ctd`, `ctd_dint`, `ctd_int`, `ctd_lint`,
      `ctd_udint`, `ctd_ulint`, `ctu`, `ctu_dint`, `ctu_int`, `ctu_lint`,
      `ctu_udint`, `ctu_ulint`, `ctud`, `ctud_dint`, `ctud_int`, `ctud_lint`,
      `ctud_udint`, `ctud_ulint`, `rto`, `rto_ltime`, `tof`, `tof_ltime`, `ton`,
      `ton_ltime`, `tp` and `tp_ltime`
 6  var colour (red, green)
      line 17, column 16: illegal character ","
 7  var level int(0..10)
      line 17, column 15: "0..10" is no number: a real has digits on both sides
      of its `.`, `1.0` or `0.5`
 8  var p ref_to int
      line 17: `var` declares one tag: found `p` and `ref_to` before the type
 9  var constant limit int 5
      line 17: `var` declares one tag: found `constant` and `limit` before the
      type
10  var_in_out belt bool
      line 17: unknown instruction `var_in_out`
11  var_temp scratch int
      line 17: unknown instruction `var_temp`
12  var_input gate bool at %IX0.0
      line 17, column 24: illegal character "%"
13  var_input gate bool at panel.i.0
      line 17: unexpected `at` after the declaration of `gate`
14  xic start ton t1 T#5s
      line 17, column 19: illegal character "#"
15  xic start move int#5 slot
      line 17, column 19: illegal character "#"
16  xic start move 8#17 slot
      line 17, column 16: "8#17" is no number: a based number is written in base
      16, `16#ff`, or base 2, `2#1010`, and logex reads no other base
17  xic start move 'a' slot
      line 17, column 16: illegal character "'"
18  xic start move true motor
      line 17: `true` is not declared
19  var grid int[2,2,2,2]
      line 17: `grid` is declared with 4 dimensions, `[2,2,2,2]`: an array has
      one to three, as in `int[8]`, `int[4,8]` or `int[2,3,4]`
20  var bins array[1..8] of int
      line 17, column 10: "array[1..8]" is no name: an element's subscripts are
      one pair of brackets straight after its array's name, each a number or a
      tag's name, split by `,` with no space, as in `grid[1,7]`
21  var bins int[1..8]
      line 17, column 10: "int[1..8]" is no name: an element's subscripts are
      one pair of brackets straight after its array's name, each a number or a
      tag's name, split by `,` with no space, as in `grid[1,7]`
22  xic start move 1 weights[slot+1]
      line 17, column 18: "weights[slot+1]" is no name: an element's subscripts
      are one pair of brackets straight after its array's name, each a number or
      a tag's name, split by `,` with no space, as in `grid[1,7]`
23  xic start move weights copy
      line 17: `move` reads one tag, but `weights` is an array of 8 ints
      (declared on line 15): an instruction takes one of its elements, as in
      `weights[0]`
      line 17: `move` writes one tag, but `copy` is an array of 8 ints (declared
      on line 16): an instruction takes one of its elements, as in `copy[0]`
24  xic start move 0 weights
      line 17: `move` writes one tag, but `weights` is an array of 8 ints
      (declared on line 15): an instruction takes one of its elements, as in
      `weights[0]`
25  xic start ton lane_t[slot] 1000
      line 17: `ton` runs `lane_t[slot]`, whose subscript `slot` holds: an
      instruction that runs an instance takes an element of an array of
      instances by literal subscripts, as in `ton lane_t[0]`, so that each
      element is one instance, run by one instruction whatever the program does
26  xic start move status.%B1 low
      line 17, column 22: illegal character "."
27  xic speed.3 ote lamp
      line 17: `speed.3` names a bit of `speed`, a real, which has no bits
28  xic start round speed count
      line 17: unknown instruction `round`
29  xic start ceil speed speed
      line 17: unknown instruction `ceil`
30  xic start floor speed speed
      line 17: unknown instruction `floor`
31  xic start bool_to_int eye count
      line 17: unknown instruction `bool_to_int`
32  xic start int_to_bool slot lamp
      line 17: unknown instruction `int_to_bool` — did you mean
      `int_to_lword`?
33  xic start bcd_to_int status slot
      line 17: unknown instruction `bcd_to_int`
34  xic start int_to_bcd slot status
      line 17: unknown instruction `int_to_bcd` — did you mean `int_to_byte`?
35  xic start real_to_dword speed pattern
      line 17: unknown instruction `real_to_dword` — did you mean
      `real_to_dint`?
36  xic start res t1
      line 17: unknown instruction `res`
37  xic start mcr
      line 17: unknown instruction `mcr`
38  lbl top
    xic start ote motor
    xic stop jmp top
      line 19: `jmp top` jumps back, to the rung on line 17: a jump goes forward
      only, to a label on a later rung, since one back could loop for ever
39  xic start ton t1 count
      line 17: `ton` takes its preset as a number of milliseconds, found
      `count`: to preset `t1` from a tag, `move count t1.pre` on a rung above
40  xic s:fs ote lamp
      line 17, column 6: illegal character ":"
41  xic first_scan ote lamp
      line 17: `first_scan` is not declared
42  var persistent total dint
      line 17: `var` declares one tag: found `persistent` and `total` before the
      type
43  var retain persistent total dint
      line 17: `var retain` declares one tag: found `persistent` and `total`
      before the type
44  var_input start bool
    var_output lamp bool
    var long_t ton_ltime
    xic start ton long_t 500
    xic long_t.dn ote lamp
      line 4: warning: `ton` gives `long_t` a preset of 500 ns, which is no
      whole number of milliseconds: a ton_ltime counts whole milliseconds, so it
      times as the next whole millisecond, 1 ms
```

### Wrong texts 45 to 51 and the host calls: a plant

The script compiles a fan program and a configuration that runs 1 instance of it. Each
wrong text from 45 to 49 comes after the 7 lines of the configuration, and thus it
starts on line 8. Wrong texts 50 and 51 are lines of a new version of the fan program,
for an online edit. Then the script calls `Logex.Runtime.restart/3` and
`Logex.Runner.force/3` with arguments that logex refuses.

```elixir
alias Logex.IO.Sim
alias Logex.Runner
alias Logex.Runner.Clock.Manual

{report, _} = Code.eval_file("instructions-contacts-and-coils/report.exs")

# A fan that runs while the motor is hot, and counts its hours.
fan_text = """
var_input  hot   bool
var_output fan   bool
var        hours dint
var        temps int[4]

xic hot ote fan
xic fan add hours 1 hours
xic hot move 40 temps[0]
"""

{:ok, fan} = Logex.compile(fan_text, name: "fan")

# The configuration: 1 task, 3 globals on a panel and 1 instance of the fan.
head = """
task fast interval 10 priority 1
var_global hot     bool at panel.i.0
var_global fan_out bool at panel.q.0
var_global lamp    bool at panel.q.1
program f1 fan with fast
f1.hot hot
f1.fan fan_out
"""

texts = [
  "resource r1 on cpu",
  "configuration line_1",
  "program retain f2 fan with fast\nf2.hot hot\nf2.fan lamp",
  "var_global retain eye bool at panel.i.1",
  "var_global persistent level dint"
]

report.(45, texts, &Logex.Configuration.compile("line_1", head <> &1, %{"fan" => fan}))

# An online edit keeps the type of each tag and the size of each array.
state = Logex.Runtime.instance(fan)
candidates = [{"var hours int", "hours dint"}, {"var temps int[8]", "temps int[4]"}]

accept = fn "var " <> to = text ->
  {_, from} = List.keyfind(candidates, text, 0)
  {:ok, candidate} = Logex.compile(String.replace(fan_text, from, to), name: "fan")
  Logex.Edit.accept(fan, candidate, state)
end

report.(50, Enum.map(candidates, &elem(&1, 0)), accept)

# A restart is cold or warm.
for mode <- [:hot, {:warm, cold: ["hours"]}] do
  try do
    Logex.Runtime.restart(fan, state, mode)
  rescue
    error in ArgumentError -> IO.puts("restart #{inspect(mode)}\n  #{error.message}")
  end
end

# The runner forces an input point only.
{:ok, plant} = Logex.Configuration.compile("line_1", head, %{"fan" => fan})
File.rm("not-supported.forces")
{:ok, clock} = Manual.start_link()
{:ok, panel} = Sim.start_link(clock: clock)

{:ok, runner} =
  Runner.start_link(
    configuration: plant,
    io: %{"panel" => {Sim, sim: panel}},
    clock: {Manual, clock},
    forces: "not-supported.forces"
  )

IO.puts("force hot\n  #{inspect(Runner.force(runner, "hot", 1))}")

try do
  Runner.force(runner, "fan_out", 1)
rescue
  error in ArgumentError -> IO.puts("force fan_out\n  #{error.message}")
end

# The script leaves no forces file behind.
:ok = Runner.stop(runner)
File.rm("not-supported.forces")
```

```console
$ mix run not-supported-plant.exs
45  resource r1 on cpu
      line 8, column 1: unknown configuration line `resource`: a line starts
      with `task`, `var_global` or `program`, or is a connection, as in
      `m1.start pb_start_1`
46  configuration line_1
      line 8, column 1: unknown configuration line `configuration`: a line
      starts with `task`, `var_global` or `program`, or is a connection, as in
      `m1.start pb_start_1`
47  program retain f2 fan with fast
    f2.hot hot
    f2.fan lamp
      line 8, column 9: `retain` before an instance's name is IEC's `PROGRAM
      RETAIN`, which logex does not have: mark in its program what it keeps, as
      in `var retain count dint`
48  var_global retain eye bool at panel.i.1
      line 8: `eye` is an input point, and a located global takes no `retain`:
      an input point is read again at every start, and an output point starts at
      0 until logic writes it
49  var_global persistent level dint
      line 8, column 23: unknown type `level`: a global's type is `bool`,
      `sint`, `int`, `dint`, `lint`, `usint`, `uint`, `udint`, `ulint`, `real`,
      `lreal`, `byte`, `word`, `dword` or `lword`
50  var hours int
      line 3: `hours` is a dint in the running program and an int in the
      candidate: a tag's type changes only with a restart
51  var temps int[8]
      line 4: `temps` is an array of 4 ints in the running program and an array
      of 8 ints in the candidate: a tag's type changes only with a restart
restart :hot
  restart takes :cold or :warm, got: :hot
restart {:warm, [cold: ["hours"]]}
  restart takes :cold or :warm, got: {:warm, [cold: ["hours"]]}
force hot
  :ok
force fan_out
  `fan_out` is an output point, at `panel.q.0`: only an input point is forced
```

## See also

- [Safety and limits](../explanation/safety-and-limits.md): what logex is not, and why.
- [Port a program](../howto/port-a-program.md): move a program from a controller to
  logex.
- [How logex differs from Logix](../explanation/differences-from-logix.md) and
  [How logex differs from IEC 61131-3](../explanation/differences-from-iec.md): what a
  ported program does differently, with the source of each claim.
- [Short pulses on input points](../explanation/short-pulses.md): why a short pulse can
  be missed, and how long a signal must hold.
- [The dialect and IEC 61131-3](../explanation/the-dialect-and-iec.md): how the dialect
  of logex differs from IEC 61131-3.
- [Declarations and types](declarations-and-types.md): the types and the sections that
  logex has.
- [Diagnostics](diagnostics.md): the form of each message.
- [Glossary](glossary.md): the technical words of logex.
