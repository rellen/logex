# The IR and the program type

This page is for a contributor. It gives the data that a
[compile](../../guides/reference/glossary.md#compile) makes: the IR of each
[rung](../../guides/reference/glossary.md#rung) and the fields of `%Logex.Program{}`.
Read it before you add a form of [operand](../../guides/reference/glossary.md#operand),
change a field of the [program type](../../guides/reference/glossary.md#program-type) or
write a walk of the IR. [The compile pipeline](compile-pipeline.md) gives the stages that
make this data.

> #### Caution {: .error}
>
> Do not read the operands of an instruction through a separate table. Use
> `Logex.Compiler.signature/2`. The operands of a `cal` are those of its block, and this
> function finds them through the tag table.

## What the IR holds

The IR, the intermediate representation, is each rung as a list of
[instructions](../../guides/reference/glossary.md#instruction). The compiler makes it
from the parse tree. Each [mnemonic](../../guides/reference/glossary.md#mnemonic) becomes
an atom, and the compiler checks each operand against the
[tags](../../guides/reference/glossary.md#tag). `Logex.Runtime`
[interprets](../../guides/reference/glossary.md#interpret) the IR, and `Logex.Walk` reads
it.

### An example: the IR of a fan

This program runs a fan. It reads a [member](../../guides/reference/glossary.md#member)
of a [timer](../../guides/reference/glossary.md#timer), a
[bit](../../guides/reference/glossary.md#bit) of a word, an
[element](../../guides/reference/glossary.md#element) by a tag
[subscript](../../guides/reference/glossary.md#subscript) and a
[literal](../../guides/reference/glossary.md#literal) written in base 16:

<!-- file: ir-and-program-type/fan.ld -->
```text
var_input run bool
var_input status word
var_input temps real[4]
var_input slot int
var_output fan bool
var_output alarm bool
var_output speed real
var t1 ton

xic run ton t1 3000
xic t1.dn ote fan
xic status.3 ote alarm
gt temps[slot] 40.0 move 75.5 speed
xic fan gt temps[2] 16#3c otl alarm
```

<!-- rung: ir-and-program-type/fan.ld -->
![The 5 rungs of fan.ld as a ladder drawing. Rung 1: run, then the timer t1 with the preset 3000. Rung 2: t1.dn, then the coil fan. Rung 3: status.3, then the coil alarm. Rung 4: the comparison gt of the element of temps at slot with 40.0, then a move of 75.5 into speed. Rung 5: fan and the comparison gt of element 2 of temps with 16#3c, then a latch of alarm.](../../guides/assets/ir-and-program-type-fan.svg)

The script [`examples/ir-and-program-type.exs`](../../examples/ir-and-program-type.exs)
prints each instruction of the IR, then 4 facts of the program type.
`Logex.Walk.instructions/1` gives the instructions of all rungs in sequence. Run the
script from `examples/`:

```elixir
{:ok, fan} = Logex.compile_file("ir-and-program-type/fan.ld")

# Each instruction of the IR: its symbol and line, then each operand.
for {symbol, line, operands} <- Logex.Walk.instructions(fan.rungs) do
  IO.puts("line #{line}: #{symbol}")
  Enum.each(operands, fn operand -> IO.puts("  " <> inspect(operand)) end)
end

# The facts that the compiler settles once for the scan.
IO.puts("t1 initial: " <> inspect(fan.tags["t1"].initial))
IO.puts("reals:      " <> inspect(fan.reals))
IO.puts("arrays:     " <> inspect(fan.arrays))
IO.puts("units:      " <> inspect(fan.units))
```

```console
$ mix run ir-and-program-type.exs
line 10: xic
  {:name, 10, "run"}
line 10: ton
  {:name, 10, "t1"}
  {:int_lit, 10, 3000}
line 11: xic
  {:member, 11, ["t1", "dn"]}
line 11: ote
  {:name, 11, "fan"}
line 12: xic
  {:bit, 12, ["status"], 3, 8, "status.3"}
line 12: ote
  {:name, 12, "alarm"}
line 13: gt
  {:element_at, 13, "temps", [{:name, 13, "slot"}], [4], "temps[slot]"}
  {:real_lit, 13, 40.0}
line 13: move
  {:real_lit, 13, 75.5}
  {:name, 13, "speed"}
line 14: xic
  {:name, 14, "fan"}
line 14: gt
  {:element, 14, "temps", [2], "temps[2]"}
  {:int_lit, 14, 60, "16#3c"}
line 14: otl
  {:name, 14, "alarm"}
t1 initial: %{"pre" => 3000}
reals:      %{"speed" => :real, "temps" => :real}
arrays:     %{"temps" => {:array, :real, [4]}}
units:      nil
```

In the parse tree, `t1.dn`, `status.3` and `temps[slot]` are each 1 name. The compiler
reads each name against the tags and gives it the form of its kind:

- `t1.dn` is a member: the path `["t1", "dn"]`.
- `status.3` is a bit: the path, the bit number 3 and its mask 8.
- `temps[slot]` is an element by a tag subscript: the
  [array](../../guides/reference/glossary.md#array), the tag `slot` and the size `[4]`.
  The [scan](../../guides/reference/glossary.md#scan) checks the value of `slot` against
  the size.
- `16#3c` keeps its spelling beside its value, 60.

The forms of a bit and an element keep the name of the source text last, for the
messages. The compiler also writes the
[preset](../../guides/reference/glossary.md#preset) of `ton t1 3000` into the tag `t1`.

## How it is built

### The forms of the IR

A rung is `{:rung, elements}`. An element is an instruction, `{symbol, line, operands}`,
or a group of branches, `{:branches, legs}`, with no line. Each leg is a list of
elements. An operand has 1 of these forms:

| Form | Example of the text |
|---|---|
| `{:name, line, tag}` | `fan` |
| `{:int_lit, line, value}` or `{:real_lit, line, value}`, with a spelling last where the text is not the plain value | `3000`, `16#3c`, `40.0` |
| `{:member, line, path}` | `t1.dn` |
| `{:bit, line, path, n, mask, name}` | `status.3` |
| `{:bit_at, line, path, {:name, line, tag}, {width, top}, name}` | `status.[n]` |
| `{:element, line, array, subscripts, name}` | `temps[2]` |
| `{:element_at, line, array, subscripts, dims, name}` | `temps[slot]` |
| `{:member, line, element, members}` | `gates[1].dn` |
| `{:label, line, name}` | `done` in `jmp done` |

`Logex.Parser` gives the guards and readers of a literal: `is_int_lit/1`, `is_literal/1`,
`value/1` and `spelling/1`. Read a literal through them, because a literal has 2 forms.

`Logex.Compiler.lowered?/1` defines a compiled body: the IR, the tags and the
[warnings](../../guides/reference/glossary.md#warning) that a compile gives. It is to the
IR what `Logex.Parser.well_formed!/1` is to the parse tree.

### The fields of the program type

| Field | Holds |
|---|---|
| `name`, `file`, `source` | The name, the path of the file and the text. Each is nil from `Logex.Compiler.instructionize/3` |
| `rungs` | The IR of each rung. The [declarations](../../guides/reference/glossary.md#declaration) are not rungs here |
| `tags` | The tag table, by name: each `%Logex.Tag{}` with its type, section, initial value, qualifier and line |
| `blocks` | Each user block type of the program, at each depth, 1 time, by name |
| `units` | For each timer that does not count in ms, what 1 ms adds to its `acc`: 1,000,000 for a long timer |
| `reals` | The type of each real tag and each array of reals |
| `arrays` | The type of each array: `{:array, type, sizes}` |
| `retained` | Each path that a [warm restart](../../guides/reference/glossary.md#warm-restart) keeps |
| `warnings` | Each warning in line order, then the warnings of each block that the loader read |

`units`, `reals`, `arrays` and `retained` are nil where the program has none.
`Logex.Program.initial_env/1` gives the first values of an
[instance](../../guides/reference/glossary.md#instance) from the tags. The tag of an
instance of a user block names its type as `{:block, name}`, and `blocks` holds the type.
`Logex.Program.typed_tags/1` gives the tags with each type in its place.

### The walk

`Logex.Walk` is the only walk of the IR. The compiler, `Logex.Warnings`, `Logex.Edit` and
`Logex.Configuration.check/1` read the IR through it. It gives the instructions, the uses
and the writes of a program, its
[one-shots](../../guides/reference/glossary.md#one-shot), its timers and its
[counters](../../guides/reference/glossary.md#counter). It goes into each block that a
`cal` runs, at each depth, and reads each block type 1 time.

## Why it is built this way

Each number is a decision of [`docs/organisation.md`](../organisation.md) §7, the full
log.

- **A program is data.** Decisions 15, 16 and 17: `Logex.Runtime` interprets the IR, and
  an [online edit](../../guides/reference/glossary.md#online-edit) compares 2 values.
  [0001. A program is data](../adr/0001-a-program-is-data.md).
- **Each instruction and operand keeps its line.** A
  [diagnostic](../../guides/reference/glossary.md#diagnostic), a warning, a
  [fault](../../guides/reference/glossary.md#fault) and an online edit cite it.
- **A literal keeps its spelling.** Decision 202: a message quotes `16#ffff` and not
  `65535`.
- **A block type 1 time.** Decision 53 keeps each block type 1 time, in `blocks`. A copy
  of the program then grows with the number of block types, and not with the paths to
  them through the nesting.
- **The compiler settles the facts.** Decision 197 puts the unit of each timer into
  `units`, so a scan does not look it up for each timer. A program with no long timer, no
  real, no array and no retained tag pays nothing. A new operand on a timer was the other
  choice, but it changes the shape that each walk reads.

## How to change it

To add a form of operand:

1. Write a test case in `test/logex/instructionize_test.exs` or
   `test/logex/validation_test.exs`. See it fail.
2. Lower the form in `Logex.Compiler`, and add it to `lowered?/1`.
3. Read the form in `Logex.Walk`, at each depth of `cal`.
4. Run it in `Logex.Runtime`. [The runtime and the evaluator](runtime-and-evaluator.md)
   gives the clauses.
5. Run `scripts/gate.sh`. It must print `GATE-OK`.

| Part | Its test files |
|---|---|
| The lowering to the IR | `test/logex/instructionize_test.exs`, `test/logex/validation_test.exs` |
| The run of the IR | `test/logex/evaluation_test.exs` |
| The walk | `test/logex/walk_test.exs` |
| A program from text to its run | `test/logex/end_to_end_test.exs` |

## See also

- [0001. A program is data](../adr/0001-a-program-is-data.md).
- [The compile pipeline](compile-pipeline.md): the stages that make the IR.
- [The runtime and the evaluator](runtime-and-evaluator.md): the scan of the IR.
- [The architecture of an online edit](online-edit.md): how an edit compares 2 program
  types, and [The online edit of a resource](online-edit-of-a-resource.md) the switch of
  a configuration.
- [Declarations and types](../../guides/reference/declarations-and-types.md): the rules
  of the tag table.
- [Glossary](../../guides/reference/glossary.md): the technical words of logex.
