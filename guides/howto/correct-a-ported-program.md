# Correct the diagnostics of a ported program

This guide is for a controls engineer who writes a ladder
[program](../reference/glossary.md#program) of a [Logix](../reference/glossary.md#logix)
controller or of [IEC 61131-3](../reference/glossary.md#iec-61131-3) again in logex. It
gives a script that [compiles](../reference/glossary.md#compile) the new file and prints
each [diagnostic](../reference/glossary.md#diagnostic). It also gives the change for each
message that a port frequently gives.

## Before you start

You must have:

- a Mix project with logex
  ([Your first program](../tutorials/first-program.md) shows how)
- a `.ld` file from steps 1 to 8 of
  [Port a program from Logix or IEC 61131-3](port-a-program.md)

The example is the file [`port-a-program/packer.ld`](port-a-program.md), in the directory
`port-a-program` of the Mix project. Its first try keeps a habit of the old tool on 4
lines. The [declarations](../reference/glossary.md#declaration) are correct:

<!-- unchecked: a first try that does not compile; every .ld file under examples/ must compile, and the output of step 2 was copied from a run of this text -->
```text
var_input start_pb bool
var_input stop_pb bool
var_input eye bool
var_input reset_pb bool
var_output motor bool
var_output jam_lamp bool
var_output full_lamp bool
var need_reset bool 1
var jam_t ton
var retain boxes ctu

xic reset_pb otu need_reset
( xic start_pb | xic Motor ) xio stop_pb xio need_reset ote motor
xic motor xic eye ton jam_t 5000
XIC jam_t.DN OTE jam_lamp
xic eye ctu boxes 12
xic boxes.dn ote full_lamp
xic reset_pb res boxes
```

## Steps

1. **Make the script `correct-a-ported-program.exs` in the root of the project.** Write
   the path of your file after `file =`.

```elixir
report = fn
  file, {:ok, _program} -> "#{file} compiles"
  _file, {:error, diagnostics} -> Enum.map_join(diagnostics, "\n", &Logex.Diagnostic.format/1)
end

file = "port-a-program/packer.ld"
IO.puts(report.(file, Logex.compile_file(file)))
```

For a file with no diagnostic, the script prints 1 line. For the corrected file, it
prints:

```console
$ mix run correct-a-ported-program.exs
port-a-program/packer.ld compiles
```

2. **Run the script on your file.** For each diagnostic, it prints the file, the line
   and the message. For the first try, it prints:

<!-- unchecked: the output of the first try, which the page shows above and which does not compile -->
```text
port-a-program/packer.ld: line 13: `Motor` is not declared — did you mean `motor`? (tags are case-sensitive)
port-a-program/packer.ld: line 15: `jam_t.DN` is not a member of `jam_t`, a ton — did you mean `jam_t.dn`? (members are case-sensitive)
port-a-program/packer.ld: line 17: `boxes.dn` is not a member of `boxes`, a ctu: its members are `cu`, `r`, `pv`, `q`, `cv` and `ov`
port-a-program/packer.ld: line 18: unknown instruction `res`
```

3. **Find each message in [The messages](#the-messages), and correct its line.** Start
   with the first message.

   | Line | First try | Corrected |
   |---|---|---|
   | 13 | `xic Motor` | `xic motor` |
   | 15 | `jam_t.DN` | `jam_t.dn` |
   | 17 | `boxes.dn` | `boxes.q` |
   | 18 | `xic reset_pb res boxes`, the last rung | `xic reset_pb ote boxes.r`, before the counter |

   The `res` rung moves before the counter. Then a reset has its effect in the same
   [scan](../reference/glossary.md#scan).

4. **Run the script again.** Do steps 3 and 4 again until the script prints that the
   file compiles.

## The result

The file compiles, and the script prints the line of step 1. Next, do the checks of
[Check the behaviour of a ported program](check-a-ported-program.md).

## The messages

Each table gives the start of a message and the change to make. In the tables, Port is
the guide [Port a program from Logix or IEC 61131-3](port-a-program.md).

### The text of a rung

| Message | What to do |
|---|---|
| `illegal character ";"` | Remove the semicolons and the parentheses of the text form of the old tool |
| `illegal character ","` | Write the operands with spaces: `ton jam_t 5000` |
| `illegal character "["` | Write the [branch](../reference/glossary.md#branch) as `( xic a \| xic b )` |
| ``unknown instruction `a` ``, after ``expects 1 operand (a tag), found none before a branch group`` | Remove the parentheses around each [operand](../reference/glossary.md#operand) |
| `` `BST` is no longer a keyword `` | Write `(` for BST, `\|` for NXB and `)` for BND |
| `illegal character ":"` | For `S:FS`, do Port, step 7. For an I/O address, declare an [input](../reference/glossary.md#input) [tag](../reference/glossary.md#tag) or an [output](../reference/glossary.md#output) tag. For `a : BOOL`, write `var a bool` |
| `illegal character "#"` | For `T#5s`, write the time as a whole number of milliseconds. For `int#5`, write `5` |
| `this rung writes nothing and jumps nowhere` | Write the [rung](../reference/glossary.md#rung) on 1 line |

An illegal character stops the compile at its line. After you correct it, the script can
print more diagnostics.

### Names and declarations

| Message | What to do |
|---|---|
| ``unknown instruction `mov` — did you mean `move`?`` | Use the name of the [instruction](../reference/glossary.md#instruction) that the message gives |
| ``unknown instruction `res` `` | Write a [coil](../reference/glossary.md#coil) on `r`, before the counter: `xic reset_pb ote boxes.r`. Port, step 4 gives each case |
| ``unknown instruction `equ` `` | Write `eq`, `ne`, `lt`, `gt`, `le` or `ge` |
| ``unknown instruction `jsr` `` or `` `mcr` `` | Do the action of the table in Port, Before you start |
| ``unknown type `timer` `` | Declare a [timer](../reference/glossary.md#timer): `ton`, `tof` or `rto`. For a [counter](../reference/glossary.md#counter), declare `ctu`, `ctd` or `ctud` |
| `` `Start` is not declared — did you mean `start`? `` | Write the name with the letters of its declaration |
| `` `start_pb` and `Start_PB` (line 1) differ only in case `` | Give 1 of the 2 tags a different name |
| `` `t1` is a ton: its preset is the number on its `ton` instruction `` | Remove the number from the declaration |

### Timers and counters

| Message | What to do |
|---|---|
| `` `t1.DN` is not a member of `t1`, a ton — did you mean `t1.dn`? `` | Write the [member](../reference/glossary.md#member) in lowercase |
| `` `t1.q` is not a member of `t1`, a ton `` | Read `t1.dn` |
| `` `boxes.dn` is not a member of `boxes`, a ctu `` | Read `boxes.q` |
| `` `t1.r` is not a member of `t1`, a ton `` | Delete the rung. A `ton` resets when its rung is false |
| `` `d.r` is not a member of `d`, a ctd `` | Write a coil on `d.ld`. It loads `pv` into `cv` |
| `` `ote motor` follows `ton t1` on its path `` | Put the instruction on a later rung, after `xic t1.dn` |
| `` `ote lamp` follows `ctu boxes` on its path `` | Put the instruction on a later rung, after `xic boxes.q` |
| `` `ton` takes its preset as a number of milliseconds, found `sp` `` | Write `move sp t1.pre` on a rung before the timer |
| `` `ton` runs `ts[i]`, whose subscript `i` holds `` | Run each [element](../reference/glossary.md#element) with its own instruction: `ton ts[0] 100` |

### Values and jumps

| Message | What to do |
|---|---|
| `` `move` writes `d`, a dint, into `s`, an sint `` | Use the conversion that the message gives: `dint_to_sint d s` |
| `` `move` writes `16#ffff` into `y`, an int `` | Write `-1`, or declare `y` a `uint` or a `word` |
| `` `jmp top` jumps back `` | Write the logic again with a forward [jump](../reference/glossary.md#jump) |

## If it does not work

| What you see | Cause | What to do |
|---|---|---|
| `(MatchError) no match of right hand side value` | A script matches `{:ok, ...}` on a file with a diagnostic | Run this script on the file, and correct each diagnostic |
| `cannot be read: no such file or directory` | The file is not at the path of the list | Run the script from the root of the project, or correct the path |
| A message that no table gives | A different error in the file | [Read a diagnostic](read-diagnostics.md) |

## See also

- [Port a program from Logix or IEC 61131-3](port-a-program.md): the steps before this
  guide.
- [Check the behaviour of a ported program](check-a-ported-program.md): the steps after
  this guide.
- [Diagnostics](../reference/diagnostics.md): the form of each diagnostic.
- [Glossary](../reference/glossary.md): the technical words of logex.
