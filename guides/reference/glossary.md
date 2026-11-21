# Glossary

This page is for each reader of the logex documentation. It gives 1 definition for each
technical word that a page of the documentation can use.

For some words, the page also gives the word that IEC 61131-3 uses and the word of the
[conventional set](#conventional-set). The sources of these words are
[`docs/naming.md`](../../docs/naming.md) and
[`docs/organisation.md`](../../docs/organisation.md). If an entry gives no IEC word or
no conventional word, these 2 documents have none.

## Programs and rungs

### dialect

The text form that logex reads for a ladder program. It is the syntax of logex. It is not
the export format of a vendor.

### program

A file of declarations and rungs. logex compiles a program into data.

IEC 61131-3: a program type. Conventional set: a program.

### program type

A compiled program. A program type holds no values. You make 1 or more instances from it.

### compile

To make a program type from the text of a program. If the text has an error, logex
returns diagnostics and no program type.

### instance

One copy of a program type or of a function block type that has a state. Each instance
has a separate value for each tag.

IEC 61131-3: an instance.

### routine

The rungs of 1 program, or the rungs of 1 function block. A label belongs to 1 routine.

### rung

One line of a program. A rung has 1 or more instructions in series, from left to right.

IEC 61131-3: a network. Conventional set: a rung.

### instruction

One operation on a rung. An instruction has a mnemonic and its operands.

### mnemonic

The short name of an instruction, for example `xic`. A mnemonic is a reserved word.

### operand

A tag, a member, a bit, an element, a label or a literal that comes after a mnemonic.

### literal

A number in the source text, for example `3000`, `16#ff` or `37.5`.

### power flow

The state, true or false, that each instruction gives to the next instruction on a rung.
The left end of each rung is true.

IEC 61131-3: power flow. Conventional set: the rung condition.

### rail

One of the 2 vertical lines of a ladder drawing. Power flows from the left rail through
each rung to the right rail. The text of a program does not show the rails.

### true rung

The condition of a rung at an instruction when the power flow to that instruction is
true.

### false rung

The condition of a rung at an instruction when the power flow to that instruction is
false.

### enable

To give power to an instruction. A true rung enables the instruction. The member `en` of
a timer is 1 while the rung enables the timer.

Conventional set: the enable bit, `.EN`.

### contact

An instruction that reads 1 bool and passes power or stops it: `xic` and `xio`.

IEC 61131-3: a contact.

### coil

An instruction that writes 1 bool from the power flow: `ote`, `otl`, `otu`, `osr` and
`osf`.

IEC 61131-3: a coil.

### latch

To write 1 to a bool with the coil `otl`. On a false rung, `otl` does not change the
bool. Thus the bool stays 1 until a different instruction writes 0 to it.

IEC 61131-3: a SET coil. Conventional set: OTL, Output Latch.

### unlatch

To write 0 to a bool with the coil `otu`. On a false rung, `otu` does not change the
bool.

IEC 61131-3: a RESET coil. Conventional set: OTU, Output Unlatch.

### branch

A group of parallel legs on a rung, written `( a | b )`. Power flows out of the branch if
1 leg or more is true.

### leg

One of the parallel paths of a branch.

### label

A name that the `lbl` instruction gives to a rung. The `jmp` instruction jumps to a
label.

IEC 61131-3: a network label. Conventional set: a label.

### jump

A move of the scan from a `jmp` instruction to a later rung that has the label. The scan
does not run the rungs between them.

### seal-in

A rung that keeps its output on with a contact of the same output.

### one-shot

An instruction that is true for 1 scan when its input changes: `ons`, `osr` and `osf`.

### storage bit

The bool tag in which a one-shot keeps the power flow of its last run.

### pulse bit

The bool tag that an `osr` or an `osf` sets to 1 for 1 scan.

## Tags and types

### tag

A named value of a program, with a type. Each tag has a declaration.

IEC 61131-3: a variable. Conventional set: a tag.

### declaration

A line that gives the section, the name and the type of 1 tag. All declarations come
before the first rung.

### section

The first word of a declaration. It tells where the value of the tag comes from: `var`,
`var_input`, `var_output` or `var_external`.

### type

The set of values that a tag can hold. A type is an elementary type, an array of an
elementary type, or a function block type.

### elementary type

A type with 1 value: `bool`, an integer type, a bit string type or a real type. The table
"Type words" on this page lists each of them.

### bit string

A value of 8, 16, 32 or 64 bits that is not a number: `byte`, `word`, `dword` or `lword`.

IEC 61131-3: a bit string.

### array

A tag that holds a fixed number of values of 1 type, in 1, 2 or 3 dimensions.

### element

One value of an array. A subscript in brackets selects it, for example `weights[3]`.

### subscript

The number of an element of an array. The first element has the subscript 0.

### member

A named part of an instance of a function block type. You write it after a dot, for
example `t1.dn`.

### bit

One binary digit of an integer tag or of a bit string tag, read as a bool. You write its
number after a dot, for example `status.3`.

### initial value

The value that a tag has when its instance starts. It is 0 if the declaration gives no
value.

### qualifier

The word `retain` or `non_retain` after the section word of a declaration.

### conversion

An instruction that puts a value of 1 type into a tag of a different type. Its mnemonic
names the 2 types, for example `dint_to_sint` or `real_trunc_int`. If the value does not
fit an integer type, the conversion keeps the low bits and passes no power. If the value
is past the limit of a real type, the conversion writes the largest value of that sign. It
passes no power. A conversion to or from a bit string keeps the low bits and passes power.

IEC 61131-3: a type conversion function, for example `DINT_TO_SINT`.

### widen

To put a value of 1 type into a tag of a wider type with no conversion. logex widens a
type only into a type that holds each value of the first type.

IEC 61131-3: an implicit type conversion.

### wrap

To keep the low bits of an integer result that its type cannot hold, in 2's complement
for a signed type. A result 1 past the limit goes to the other end of the range. Example:
in an `sint`, 127 + 1 wraps to -128. An arithmetic instruction, or a conversion between 2
number types, that wraps a result passes no power. A conversion to or from a bit string
keeps the low bits and passes power.

### reserved word

A word that a kind of file keeps for its own lines, so it cannot be a name in that kind
of file. For example, a mnemonic or a type word cannot be the name of a tag. A message
calls a reserved word a keyword.

## Function blocks

### function block

A routine with a state, written in a separate file. A program declares instances of it
and runs each instance with `cal`.

IEC 61131-3: a function block. Conventional set: a user-defined instruction.

### function block type

The compiled form of a function block. The built-in function block types are the timers
and the counters.

### timer

An instance of a built-in function block type that measures time: `ton`, `tof`, `tp` or
`rto`.

IEC 61131-3: a timer function block. Conventional set: a TIMER tag.

### counter

An instance of a built-in function block type that counts rising edges: `ctu`, `ctd` or
`ctud`.

IEC 61131-3: a counter function block. Conventional set: a COUNTER tag.

### preset

The limit of a timer or of a counter: the time to measure or the number to count to. The
instruction on the rung gives it.

### rising edge

A change of a bool from 0 to 1 between 2 runs of an instruction.

## Runs

### host

The Elixir application that calls logex. The host gives the inputs and the time to a
program.

### scan

One run of the rungs of 1 instance, from the first rung to the last rung.

IEC 61131-3: an evaluation of the networks. Conventional set: a scan.

### first scan

The first scan of an instance after it starts or restarts. A one-shot gives no pulse on
the first scan.

### state

The values of 1 instance between 2 scans. The host keeps the state and gives it to the
next scan.

### input

A tag of the section `var_input`. The host or a configuration gives its value. An
instruction cannot write to it.

### output

A tag of the section `var_output`. A scan returns its value to the host or to a
configuration.

### restart

A new start of an instance or of a resource.

### cold restart

A restart that sets each tag to its initial value.

### warm restart

A restart that keeps the value of each tag that has the qualifier `retain`. Each other
tag starts at its initial value.

### retain

To keep a value across a warm restart. The qualifier `retain` on a declaration selects
the tags that logex retains.

IEC 61131-3: RETAIN.

### fault

An error that a scan finds while it runs, for example a division by 0. The scan
continues. A fault is data that the scan reports.

### minor fault

A fault that the scan reports and that does not stop a plant.

### major fault

A fault that causes a trip when a runner runs the plant.

### diagnostic

A report of 1 error in a source text, with the file and the line. The compiler returns
diagnostics. It does not raise them.

### warning

A report of a possible error in a source text. A program with warnings compiles.

### host contract

The modules that a host calls. Each of these modules refuses a wrong argument with an
`ArgumentError`.

## Configurations

### configuration

A set of program instances, tasks, globals and connections that run together as 1 plant.

IEC 61131-3: a configuration. Conventional set: a controller.

### configuration file

A `.logex` file that describes a configuration. It names the `.ld` files of the program
types.

### resource

A configuration while it runs: the instances, the values of the globals and the time.

IEC 61131-3: a resource.

### plant

The machine or the process that 1 configuration controls. The documentation also uses
this word for the configuration and its programs together.

### task

A schedule for program instances in a configuration.

IEC 61131-3: a task. Conventional set: a task.

### periodic task

A task that is due at a fixed interval.

IEC 61131-3: a task with INTERVAL. Conventional set: a periodic task.

### event task

A task that is due when its trigger rises.

IEC 61131-3: a task with SINGLE. Conventional set: an event task.

### continuous task

The task that runs each program instance that has no timed task.

IEC 61131-3: a program with no task. Conventional set: the continuous task.

### trigger

The bool global that makes an event task due on its rising edge.

### priority

The rank of a task. The priority 0 is the highest.

### cycle

One pass of a resource: it runs each task that is due at the time that the host gives.

### global

A value of a configuration that programs share by name. A program reads or writes it
through a `var_external` declaration.

IEC 61131-3: a global variable. Conventional set: a controller-scope tag.

### connection

A line of a configuration that joins an input or an output of an instance to a global or
to a constant.

### point

One input or one output of a device, at an address. A located global is at a point.

### located global

A global with the word `at` and the address of a point.

IEC 61131-3: a located variable. Conventional set: an alias tag on an I/O member.

### location

The text that names a point in a configuration, for example `panel.i.0`. It has 3
parts: the name of a device, the letter `i` or `q`, and an address. The letter `i` is
for an input point, and the letter `q` is for an output point.

IEC 61131-3: a direct representation, such as `%IX1.1`.

### device

The hardware, or a simulated device, that holds the points of a configuration.

### adapter

A module that reads and writes 1 kind of device for the runner.

### simulated device

A device with no hardware: `Logex.IO.Sim`. A test sets its inputs and reads its outputs.

## The runner

### runner

The process that runs a resource on a clock and through devices: `Logex.Runner`.

### round

One step of the runner: it takes the inputs from the devices, runs a cycle and writes
the outputs to the devices.

### poll period

The time between 2 reads of a device by the runner: the option `poll:` of
`Logex.Runner`, 10 ms by default.

### clock

The source of the time for the runner. The manual clock moves only when a test moves it.

### watchdog

A limit of time for a task or for the runner. The runner trips if the work takes longer
than the limit.

Conventional set: a watchdog.

### trip

A stop of the plant by the runner, for example after a watchdog or a major fault. The
runner writes 0 to each output 1 time. It runs no round until a restart.

### force

To hold an input at a value that an operator gives, in place of the value from the
device. The noun is "a force".

### forces file

The file in which a runner keeps its forces, so that they stay after the runner stops.

### store

The file in which a runner keeps the retained values on the disk of the host.

### retained image

The retained values of an instance or of a resource as plain data. The host can take the
image out and put it into a new instance or resource.

## Online edits

### online edit

A change to the program of an instance, or to a configuration, while it runs and with no
restart.

### accept

The first step of an online edit: logex checks the new program and keeps it beside the
old program.

### test

The step of an online edit that runs the new program in place of the old program. The
verb is "do a test".

### untest

The step of an online edit that puts the old program back in place of the new program.

### assemble

The step of an online edit that makes the new program the only program.

### cancel

The step of an online edit that removes the new program and keeps the old program.

## Standards and vendors

### IEC 61131-3

The international standard for the programming languages of programmable controllers.
Ladder diagram is 1 of its languages.

### conventional set

The ladder vocabulary that most controls engineers know, with mnemonics such as `XIC` and
`OTE`. logex takes its mnemonics from it. The documentation does not name the vendor of
this vocabulary, as [`docs/naming.md`](../../docs/naming.md) does not.

### Logix

A family of industrial controllers. A page can compare the behaviour of logex with the
behaviour of a Logix controller.

## Instruction mnemonics

logex has 40 instructions and 182 typed conversions. For the rules of each instruction,
read the reference pages of the instructions.

| logex | What it is | IEC 61131-3 | Conventional set |
|---|---|---|---|
| `xic` | A contact that is true when its tag is 1 | Normally open contact | XIC, Examine If Closed |
| `xio` | A contact that is true when its tag is 0 | Normally closed contact | XIO, Examine If Open |
| `ote` | A coil that writes the power flow to its tag | Coil | OTE, Output Energize |
| `otl` | A coil that sets its tag to 1 on a true rung | SET (latch) coil | OTL, Output Latch |
| `otu` | A coil that sets its tag to 0 on a true rung | RESET (unlatch) coil | OTU, Output Unlatch |
| `ons` | A one-shot in the rung | None | ONS, One Shot |
| `osr` | A one-shot coil for a rising edge | Positive transition-sensing coil | OSR, One Shot Rising |
| `osf` | A one-shot coil for a falling edge | Negative transition-sensing coil | OSF, One Shot Falling |
| `ton` | An on-delay timer | TON | TON |
| `tof` | An off-delay timer | TOF | TOF, Timer Off Delay |
| `tp` | A pulse timer | TP | None |
| `rto` | A retentive on-delay timer | None | RTO, Retentive Timer On |
| `ctu` | An up counter | CTU | CTU, Count Up |
| `ctd` | A down counter | CTD | CTD, Count Down |
| `eq` | Equal | EQ | EQ (before: EQU) |
| `ne` | Not equal | NE | NE (before: NEQ) |
| `lt` | Less than | LT | LT (before: LES) |
| `gt` | Greater than | GT | GT (before: GRT) |
| `le` | Less than or equal | LE | LE (before: LEQ) |
| `ge` | Greater than or equal | GE | GE (before: GEQ) |
| `add` | Add | ADD | ADD |
| `sub` | Subtract | SUB | SUB |
| `mul` | Multiply | MUL | MUL |
| `div` | Divide | DIV | DIV |
| `mod` | Remainder | MOD | MOD |
| `neg` | Negate | None | NEG |
| `abs` | Absolute value | ABS | ABS |
| `sqrt` | Square root | SQRT | SQRT (before: SQR) |
| `move` | Copy a value into a tag | MOVE | MOVE (before: MOV) |
| `and` | Bitwise AND | AND | AND |
| `or` | Bitwise OR | OR | OR |
| `xor` | Bitwise exclusive OR | XOR | XOR |
| `not` | Bitwise complement | NOT | NOT |
| `shl` | Shift left | SHL | None |
| `shr` | Shift right | SHR | None |
| `rol` | Rotate left | ROL | None |
| `ror` | Rotate right | ROR | None |
| `jmp` | Jump to a label | The jump element | JMP, Jump to Label |
| `lbl` | Give a label to a rung | The network label | LBL, Label |
| `cal` | Run an instance of a function block | CAL, in Instruction List | A user-defined instruction, by its name on the rung |

The typed conversions have names of 2 forms:

| logex | What it is | IEC 61131-3 | Conventional set |
|---|---|---|---|
| `int_to_dint`, `word_to_int`, `real_to_int` and 163 more | Convert a value of 1 type into a tag of a different type | `<FROM>_TO_<TO>` | None: MOV converts to the type of its destination |
| `real_trunc_int` and 15 more | Convert a real to an integer and remove the fraction | `REAL_TRUNC_INT` and the others | TRUNC (before: TRN) |

## Type words

| logex | What it is | IEC 61131-3 | Conventional set |
|---|---|---|---|
| `bool` | 0 or 1 | BOOL | BOOL |
| `sint` | A signed integer of 8 bits | SINT | SINT |
| `int` | A signed integer of 16 bits | INT | INT |
| `dint` | A signed integer of 32 bits | DINT | DINT |
| `lint` | A signed integer of 64 bits | LINT | LINT |
| `usint` | An unsigned integer of 8 bits | USINT | USINT |
| `uint` | An unsigned integer of 16 bits | UINT | UINT |
| `udint` | An unsigned integer of 32 bits | UDINT | UDINT |
| `ulint` | An unsigned integer of 64 bits | ULINT | ULINT |
| `byte` | A bit string of 8 bits | BYTE | None |
| `word` | A bit string of 16 bits | WORD | None |
| `dword` | A bit string of 32 bits | DWORD | None for programs |
| `lword` | A bit string of 64 bits | LWORD | None |
| `real` | A floating-point number of 32 bits | REAL | REAL |
| `lreal` | A floating-point number of 64 bits | LREAL | LREAL |

The type word of a timer or of a counter is the name of its function block type, for
example `ton`, `ctu` or `ctud`. A typed counter has a word such as `ctu_int`. A long
timer has a word such as `ton_ltime` and counts in nanoseconds.

## Declaration words

| logex | What it is | IEC 61131-3 | Conventional set |
|---|---|---|---|
| `var` | A tag that only the program uses | VAR | A local tag |
| `var_input` | A tag with a value from outside the program | VAR_INPUT | An Input parameter |
| `var_output` | A tag with a value for outside the program | VAR_OUTPUT | An Output parameter |
| `var_external` | A global of the configuration, used in a program | VAR_EXTERNAL | None: a controller-scope tag needs no declaration |
| `retain` | The qualifier that keeps a value across a warm restart | RETAIN | None |
| `non_retain` | The qualifier that does not keep a value | NON_RETAIN | None |
| `function_block` | The first word of the file of a function block | FUNCTION_BLOCK | A user-defined instruction definition |

## Configuration words

| logex | What it is | IEC 61131-3 | Conventional set |
|---|---|---|---|
| `program` | Make an instance of a program type | PROGRAM, WITH | A program |
| `with` | Put an instance under a task | WITH | None: the task lists its programs |
| `task` | Declare a task | TASK | TASK |
| `interval` | The period of a periodic task | INTERVAL | The period of a periodic task |
| `single` | The trigger of an event task | SINGLE | An Event task |
| `priority` | The priority of a task | PRIORITY | The priority of a task |
| `continuous` | Declare the continuous task | None: a program with no task | A Continuous task |
| `watchdog` | The limit of time of a task | None | The watchdog of a task |
| `var_global` | Declare a global | VAR_GLOBAL | A controller-scope tag |
| `at` | Give a global the address of a point | AT | An alias tag on an I/O member |

## See also

- [Your first program](../tutorials/first-program.md): a tutorial that uses the first
  words of this page.
- [The style guide](../../docs/style-guide.md): the writing rules for these pages.
