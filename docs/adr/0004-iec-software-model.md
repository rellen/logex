# 0004. The software model of IEC 61131-3

This record is for a contributor who wants to know how logex organises a
[plant](../../guides/reference/glossary.md#plant), and why. A file is a type, and an
instance holds the values. A configuration file makes the instances, connects them to
globals and puts them on tasks.

Read this record before you add one of these:

- a subroutine, or a tag that each program reads with no declaration
- a link from 1 program to another
- a write to a [member](../../guides/reference/glossary.md#member)
- a new line of a
  [configuration file](../../guides/reference/glossary.md#configuration-file)

## Status

Accepted. No later record replaces this record.

## Date

2026-09-28, for the direction and decisions 1 to 14. The other decisions apply it:
2026-10-02 (30 to 35), 2026-10-04 (46 to 49), 2026-10-05 (53) and 2026-10-14 (84 to 92).

## Context

Until 2026-09-28, a `.ld` file was a list of rungs with no program name. `evaluate/2` ran
it 1 time against a flat map of values, with no instance, no mark on the physical inputs
and no loop. The maintainer asked for 3 things of
[IEC 61131-3](../../guides/reference/glossary.md#iec-61131-3): its hierarchy, its tasks
and its mapping of I/O.

Edition 2 §1.4.1 of IEC 61131-3 gives the hierarchy. A configuration contains resources. A
resource contains programs, and tasks control them. A program contains
[function blocks](../../guides/reference/glossary.md#function-block). A program reaches a
global only through a VAR_EXTERNAL.

A connection joins a global to an input of a program, or an output to a global. Table 49
has no connection between 2 programs. A located variable is a global at a physical
address, with `AT`.

IEC 61131-3 has no subroutine. Edition 3 §6.6.1.4.1 gives what a call runs: "a function, a
function block instance, or a method of a function block or class". Edition 3 also
deprecates an address in the body of a program or a block. Such an address "limits the
reusability of these program organization unit types" (§6.5.5.1).
[`docs/organisation.md` §2](../organisation.md#2-the-iec-model-top-down) gives the
sources.

The [conventional set](../../guides/reference/glossary.md#conventional-set) has a
different hierarchy. Its program is a type and a schedule together, and JSR calls its
subroutines. Each program reads each controller-scope tag with no declaration. A parameter
connection joins 2 programs with no global. The source is the import/export reference of
the conventional family, Sept 2025, ch.8 (programs) and ch.15 (parameter connections), as
[`docs/organisation.md` §8](../organisation.md#8-sources-and-what-is-unverified) lists it.

## Decision

logex follows the software model of IEC 61131-3, in its
[dialect](../../guides/reference/glossary.md#dialect).

| IEC 61131-3 | logex | Where logex keeps the values |
|---|---|---|
| Program type | 1 `.ld` file: `conveyor.ld` is the type `conveyor` | A type holds no values. It is data, `%Logex.Program{}` |
| Function block type | 1 `.ld` file that starts with `function_block seal` | A type holds no values. It is data, `%Logex.FbType{}` |
| Function block instance | `var s1 seal`, run by `cal s1 …` | In the instance that declares it: `c1.s1` |
| Timer or counter instance | `var t1 ton`, `var boxes ctu` | In the instance that declares it: `p1.boxes` |
| Configuration with 1 resource | 1 `.logex` file | The [resource](../../guides/reference/glossary.md#resource) |
| [Task](../../guides/reference/glossary.md#task) | `task fast interval 10 …` | The resource |
| Program instance | `program c1 conveyor with fast` | The resource |
| Global, located or not | `var_global k1 bool at …` | The resource, 1 copy of each global |
| VAR_EXTERNAL | `var_external estop bool` | It is its global, and holds no copy |
| Connection | `c1.motor k1`, with no arrow | It copies a value in before each scan, and out after it |
| Access path | `c1.s1.run`, for `Logex.Runtime.get/2` | It names a value, and holds none |

The rules:

1. **A file is a type.** It is a
   [program type](../../guides/reference/glossary.md#program-type) or a
   [function block type](../../guides/reference/glossary.md#function-block-type). A block
   file starts with `function_block <name>` after comments. `<name>` is the name of its
   file. A block never holds itself, at any depth.
2. **An [instance](../../guides/reference/glossary.md#instance) holds all the values.**
   Its [state](../../guides/reference/glossary.md#state) maps each
   [tag](../../guides/reference/glossary.md#tag) name to its value. Each
   [timer](../../guides/reference/glossary.md#timer),
   [counter](../../guides/reference/glossary.md#counter) and block instance in it is a
   nested map. The field `blocks` of a program holds 1 copy of each block type, at any
   depth.
3. **A [rung](../../guides/reference/glossary.md#rung) writes only some members of a timer
   or a counter.** It writes `pre` and `acc` of a timer, `r` of an `rto`, and `r`, `ld`
   and `pv` of a counter. It writes no member of a user block. A rung reads each member,
   but not a `var` of a user block.
4. **The [power flow](../../guides/reference/glossary.md#power-flow) into an instance is 1
   of its inputs.** It is IN of a timer, or CU or CD of a counter. For a block, it is EN,
   the [enable](../../guides/reference/glossary.md#enable) input of `cal`. A
   [false rung](../../guides/reference/glossary.md#false-rung) resets a `ton`.
5. **A false rung freezes a block.** `cal` then copies nothing in and writes nothing out.
   The operands of `cal` are positional: the `var_input` tags, then the `var_output` tags.
6. **A counter reads `r`, `ld` and `pv` when its instruction runs.** Thus a reset on an
   earlier rung acts in the same [scan](../../guides/reference/glossary.md#scan). A reset
   on a later rung acts in the next scan. While the counter reads `r` as 1, it
   counts no edge. logex has no `res` instruction.
7. **1 `ctud` counts up and down.** Put `ctu stock 50` on 1 rung and `ctd stock 50` on
   another. Each rung gives 1 count input of the same instance.
8. **A [configuration](../../guides/reference/glossary.md#configuration) is a separate
   `.logex` file.**
9. **A [connection](../../guides/reference/glossary.md#connection) has no arrow, and each
   `var_input` has one.** The [section](../../guides/reference/glossary.md#section) of the
   member gives the direction. A `var_input` connects to a
   [global](../../guides/reference/glossary.md#global),
   [located](../../guides/reference/glossary.md#located-global) or not, or to a constant.
10. **Programs share a value only through a global.**
11. **A `var_external` is its global.** A write to it is a write to the global. If 1
    instance writes a global in both ways, the copy-out writes last, with a warning. Only
    a program type declares a `var_external`. A block takes a value through a
    `var_input`.
12. **A program has 1 [routine](../../guides/reference/glossary.md#routine).** It has no
    subroutine and no `jsr`. A function block divides a large program.

A `.ld` file alone runs as 1 instance with no task, which the
[host](../../guides/reference/glossary.md#host) scans with `Logex.Runtime.scan/3`.
`Logex.compile_file/1` loads each block from `<word>.ld` beside the file, and gives the
warnings of each block after the warnings of the program. `Logex.compile/2` takes the
blocks in `types:`.

[Runs and tables of the records: the core](../implementation/record-runs-core.md#0004-the-software-model-of-iec-61131-3)
gives a plant in this model: 2 conveyors of 1 program type and a packer. It runs the plant
2 times, and shows a refusal for each of rules 3, 9, 10, 11 and 12.

## Consequences

The good results:

- 1 program type runs as many instances. Each instance has its own values and its own
  task.
- The state is a map by tag name. Thus an
  [online edit](../../guides/reference/glossary.md#online-edit) moves each value to the
  tag of the same name.
- The `var_global ... at` lines are the list of the I/O of the plant. A program type holds
  no address.
- No `var_input` reads 0 forever because its connection is missing.
- The flags `ov` and `un` of a counter agree with its count. Apart from the count inputs,
  only `r` and `ld` change the count, and both clear the flags.
- The size of a program grows with its block types, not with the paths to them. The page
  of the runs gives the measurement.

The costs:

- A reader from the conventional set finds no subroutine, no tag that each program reads
  with no declaration, no parameter connection and no `res`.
- An instance reads a global only when its task runs it. In the run, `k2` on the slow task
  goes to 0 10 ms after `k1`. An `estop` of 10 ms leaves `k2` at 1.
- A counter in a frozen block does not count, and the block keeps its outputs. A box still
  at the eye when the block runs again counts then, if the counter last saw the eye at 0.
- The operands of `cal` are positional, so the compiler cannot find 2 bool operands in the
  wrong sequence: `cal s1 halt start motor` compiles with no message.
- No public function shows that a resource keeps 1 copy of each global. ExUnit tests in
  `test/logex/scheduler_test.exs` and `test/logex/api_contract_test.exs` look inside the
  opaque `%Logex.Runtime{}`.

> #### Warning {: .warning}
>
> Hold the e-stop signal for at least the slowest interval of the tasks that read it. An
> instance on a slower task can miss a shorter pulse. It then reads the e-stop as 0, and
> its outputs do not change. See
> [the configuration file](../../guides/reference/configuration-file.md).

> #### Warning {: .warning}
>
> Do not put the e-stop in front of `cal`. A false rung freezes the block: with
> `xio estop cal s1 start stop motor`, `motor` stays 1 when `estop` is 1. Write the
> e-stop into an input of the block, as the conveyor of the run writes it into `halt`. See
> [function blocks](../../guides/reference/function-blocks.md).

## Alternatives considered

| Alternative | Why logex does not do it |
|---|---|
| Subroutines with JSR, SBR and RET | IEC 61131-3 has none, and `cal` divides a program. logex can add them if a block cannot do the job |
| A tag that each program reads with no declaration, or a connection between 2 programs | IEC 61131-3 reaches a global only through VAR_EXTERNAL, and its Table 49 has no connection between programs |
| `var_external` in a block, as IEC 61131-3 lets | A block then reaches past its caller. The refusal can relax later and break no program |
| An address such as `%qx0.0` in a declaration, or `AT %I*` in a program type | The plant then has no list of its I/O, and Edition 3 deprecates an address in a type. The lexer refuses `%` |
| `cal` on a false rung writes its outputs again | IEC 61131-3 says that the outputs "keep their states" |
| A rung writes `cv` | A write can leave the overflow flag `ov` at 1 at a count of 3 |
| Each block type held in each holder | The size grows as 2 to the power of the levels |
| A `var_input` with no connection reads 0 | To relax the rule later breaks no plant. To make it stricter later breaks plants |

Section 7 gives the other options of each decision. Examples are `.lcf` as the extension,
the arrows `:=` and `=>`, a `res` instruction and more than 1 resource.

## The decisions that this record sums up

This record sums up these decisions of
[`docs/organisation.md`](../organisation.md#7-decisions). Its §4.1 to §4.5 give the
design, and its §5 the parts that logex does not have.

- The model, its files and its loader: 1, 2, 3, 4, 30, 34 and 35.
- Connections and globals: 5, 6, 7, 46, 47, 48 and 49.
- The state of an instance and its block types: 9 and 53.
- A false `cal`: 12 and 89.
- A user block shows only its inputs and outputs: 33.
- The members of a counter that a rung writes, and when a reset acts: 84, 85, 86, 90, 91
  and 92.

Related pages:

- [0002. A dialect for logex, and a survey for each word](0002-own-dialect-and-names.md):
  the words of the dialect.
- [0011. Tasks and rounds](0011-tasks-and-rounds.md): the schedule of the tasks.
- [0012. The staged online edit](0012-staged-online-edit.md): the edit that moves the
  state by tag name.
- [The configuration file](../../guides/reference/configuration-file.md) and
  [function blocks](../../guides/reference/function-blocks.md): the rules for a user.
