# Check the behaviour of a ported program

This guide is for a controls engineer with a [program](../reference/glossary.md#program)
that [compiles](../reference/glossary.md#compile) in logex after a port from a [Logix](../reference/glossary.md#logix) controller or from
[IEC 61131-3](../reference/glossary.md#iec-61131-3). It gives each behaviour of logex
that can be different from the old controller, and the change to make for each.

> #### Warning {: .warning}
>
> Do not connect a ported program to a machine before you do these checks. A program
> that compiles can still give a different output from the old program. A wrong output
> can cause damage to a machine.

## Before you start

You must have:

- a ported program that compiles with no
  [diagnostic](../reference/glossary.md#diagnostic)
  ([Correct the diagnostics of a ported program](correct-a-ported-program.md) shows how)
- a list of cases from the old program: the [inputs](../reference/glossary.md#input), and the [outputs](../reference/glossary.md#output) that you expect

## Steps

1. **Read each [warning](../reference/glossary.md#warning) of the compile.** A program
   with warnings compiles. Each warning is a possible error. This script prints each
   warning of the file `cure.ld`:

<!-- fragment: the reader puts the name of the ported file in place of cure.ld -->
```elixir
{:ok, program} = Logex.compile_file("cure.ld")
Enum.each(program.warnings, &IO.puts(Logex.Diagnostic.format(&1)))
```

In `cure.ld`, `cure` is a `ton_ltime`, and line 7 is `ge cure.acc 3000`. The script
prints:

<!-- unchecked: a warning of a file that the page does not show, copied from a run -->
```text
cure.ld: line 7: warning: `ge` compares `cure.acc` with `3000`, where `cure.acc` is a ton_ltime's time in nanoseconds: 3000 ns is no whole number of milliseconds, and a ton_ltime counts whole milliseconds
```

2. **Check the arithmetic.** logex computes an
   [instruction](../reference/glossary.md#instruction) in the
   [type](../reference/glossary.md#type) of its destination.

   | What the old program does | What logex does | What to do |
   |---|---|---|
   | A program of IEC 61131-3 adds 2 INT [tags](../reference/glossary.md#tag) into a DINT tag | IEC 61131-3 computes `INT + INT` in INT. logex computes in the `dint`: 30000 + 30000 is 60000 | If the old program depends on the overflow of the INT, write the result into an `int` |
   | It gets a result that is too large for its type | The value wraps. The instruction passes no power and gives no [fault](../reference/glossary.md#fault). A Logix instruction passes power | Put a [coil](../reference/glossary.md#coil) after the instruction: `xic run add a b total ote total_ok`. To keep a record, repeat the conditions of the rung: `xic run xio total_ok otl overflow` |
   | It moves a DINT into a SINT | logex refuses the `move`. `dint_to_sint` keeps the low bits, and passes no power: 129 gives `-127` | Use the conversion and read its power |
   | It moves `16#ffff` into an INT | A Logix controller writes `-1`. logex refuses the [literal](../reference/glossary.md#literal): `16#ffff` is 65535 | Write `-1`, or declare the tag `uint` or `word` |
   | It divides by 0 | The result is 0, and the instruction passes no power. The scan reports the [minor fault](../reference/glossary.md#minor-fault) `divide_by_zero`. logex refuses a literal 0 divisor | Read the power of the instruction |
   | It takes the square root of a negative value | A Logix controller gives the root of the absolute value. logex writes 0.0, passes no power and reports the minor fault `negative_sqrt` | Put `abs` before `sqrt` if the program must have the root of the absolute value |

> #### Caution {: .error}
>
> Put a range check on each subscript that a tag holds. On a
> [runner](../reference/glossary.md#runner), a major fault
> [trips](../reference/glossary.md#trip) the [plant](../reference/glossary.md#plant).

3. **Check the [subscripts](../reference/glossary.md#subscript) and the bit numbers that
   a tag holds.**

   | What the old program does | What logex does | What to do |
   |---|---|---|
   | It reads an [element](../reference/glossary.md#element) with a subscript out of range | A Logix controller has a major fault of type 4, code 20, and stops the logic. In logex the instruction does nothing and passes no power. The scan reports the [major fault](../reference/glossary.md#major-fault) `index_out_of_range`. A runner trips the plant | Put a range check on the [rung](../reference/glossary.md#rung): `ge slot 0 lt slot 8 move weights[slot] checked` |
   | It reads a [bit](../reference/glossary.md#bit) with a number out of range | The same rules. The major fault is `bit_out_of_range` | Put a range check on the rung |
   | It uses an [array](../reference/glossary.md#array) of IEC 61131-3 from 1 | The first subscript is 0 | Subtract 1 from each subscript |

   An instruction on a [false rung](../reference/glossary.md#false-rung) reads no
   element. Thus the range check stops the fault.

4. **Check the [counters](../reference/glossary.md#counter).**

   | What the old program does | What logex does | What to do |
   |---|---|---|
   | It counts past the limit of the type | The count stops at the limit. The [member](../reference/glossary.md#member) `ov` or `un` is 1 until a reset or a load | If the old program depends on a count that rolls over, write that logic again |
   | It uses CTU of IEC 61131-3, which counts in an INT | A `ctu` counts in a `dint` | Declare `ctu_int` |
   | It resets the counter on a rung after the counter | The counter reads `r` when its instruction runs. The reset has its effect in the next [scan](../reference/glossary.md#scan) | Put the rung of `r` before the rung of the counter |

5. **Check the [first scan](../reference/glossary.md#first-scan).** On the first scan of
   an [instance](../reference/glossary.md#instance), these instructions give no pulse and
   no count. The condition of the rung has no effect. logex has no prescan.

   | Instruction | On the first scan |
   |---|---|
   | `ons`, `osr`, `osf` | No pulse |
   | `ctu`, `ctd` | No count. The counter keeps the input of the first scan. Thus a box that is on the eye at the start does not get a count on the next scan |
   | `tp` | No pulse of its [timer](../reference/glossary.md#timer) |

   The R_TRIG of IEC 61131-3 gives a pulse on its first call if its input is 1. A
   [one-shot](../reference/glossary.md#one-shot) in a [function block](../reference/glossary.md#function-block) can give a
   pulse on the first run of the block, if that run comes after the first scan.

   If a rung must act on an input that is on at the start, add a rung for the first
   scan: `xic first xic eye ote box_at_start`.
   [Port a program from Logix or IEC 61131-3](port-a-program.md), step 7, gives the tag
   `first`.

6. **Check the values across a [restart](../reference/glossary.md#restart).** At a
   [warm restart](../reference/glossary.md#warm-restart), logex keeps only the tags with
   the [qualifier](../reference/glossary.md#qualifier) `retain`. At a
   [cold restart](../reference/glossary.md#cold-restart), it keeps none of them. Each
   other tag gets its [initial value](../reference/glossary.md#initial-value), but a
   `var_input` keeps its value.

   A Logix controller keeps the value of each tag through a loss of power. logex keeps a
   retained value through a stop of the computer only if a runner keeps a
   [store](../reference/glossary.md#store). The option `retain:` of the runner gives the
   store. The runner writes the store each second, unless `retain_period:` gives a
   different period. After a crash, the store holds the values of its last write.

   > #### Warning {: .warning}
   >
   > Find each rung that reads a retained value before you mark a tag `retain`. A warm
   > restart can switch on an output in the first scan, with no action of an operator. A
   > rung that reads a retained value writes its output from that value.

7. **Check the time.**

   | What the old program does | What logex does | What to do |
   |---|---|---|
   | It has a [preset](../reference/glossary.md#preset) of LTIME | A `ton` counts milliseconds. A `ton_ltime` counts nanoseconds | Declare `ton_ltime`. Write the preset in ns, as a multiple of 1000000 |
   | It compares `.ACC` with a time in ms, and the new timer is a `ton_ltime` | `acc` is in ns. `ge cure.acc 3000` is 3000 ns | Multiply the number by 1000000 |

   Each timer counts whole milliseconds of the [clock](../reference/glossary.md#clock).
   A `ton_ltime` with a preset of 1500000 sets `dn` at 2 ms.

   > #### Caution {: .error}
   >
   > Make each input pulse longer than the time between 2
   > [rounds](../reference/glossary.md#round) of the runner. A runner keeps only the last
   > value of each input. Thus it can miss a short pulse. A pulse shorter than the time
   > between 2 reads of its [device](../reference/glossary.md#device) gets to the logic
   > only if the device reports it. Then make the input the
   > [trigger](../reference/glossary.md#trigger) of an
   > [event task](../reference/glossary.md#event-task).

8. **Run each case as scans.** Give the inputs of each case with
   `Logex.Runtime.put_inputs/3`. Compare the outputs of `Logex.Runtime.scan/3` with the
   outputs that you expect. Read `state.faults` after each scan.

## The result

The program behaves as the old program, or you know each difference. In this example,
`check-a-ported-program/belts.ld` adds the box counts of 2 belts. Each count is an `int`.
The program also reads the weight of the box in a slot.

<!-- file: check-a-ported-program/belts.ld -->
```text
var_input belt_1 int
var_input belt_2 int
var_input slot int
var_output total dint
var_output total_ok bool
var_output total_int int
var_output total_int_ok bool
var_output weight int
var_output checked int
var weights int[8] 410 380 520 0 0 0 0 0

add belt_1 belt_2 total ote total_ok
add belt_1 belt_2 total_int ote total_int_ok
move weights[slot] weight
ge slot 0 lt slot 8 move weights[slot] checked
```

<!-- rung: check-a-ported-program/belts.ld -->
![The 4 rungs of belts.ld as a ladder drawing. Rung 1: add belt_1 and belt_2 into total, then the coil total_ok. Rung 2: add belt_1 and belt_2 into total_int, then the coil total_int_ok. Rung 3: move the element of weights that slot selects into weight. Rung 4: if slot is 0 or more and less than 8, move that element into checked.](../assets/check-a-ported-program-belts.svg)

The script `check-a-ported-program.exs` runs 3 scans and prints each fault.

```elixir
{:ok, belts} = Logex.compile_file("check-a-ported-program/belts.ld")

scan = fn state, label, inputs ->
  state = Logex.Runtime.put_inputs(belts, state, inputs)
  {outputs, state} = Logex.Runtime.scan(belts, state)
  IO.puts(label)
  IO.puts("    #{inspect(outputs)}")

  for fault <- state.faults do
    IO.puts("    #{fault.severity} fault #{fault.kind}: line #{fault.line}, #{fault.instruction}")
  end

  state
end

Logex.Runtime.instance(belts)
|> scan.("1000 + 2000 boxes, slot 2", %{"belt_1" => 1000, "belt_2" => 2000, "slot" => 2})
|> scan.("30000 + 30000 boxes, slot 2", %{"belt_1" => 30000, "belt_2" => 30000})
|> scan.("slot 8", %{"slot" => 8})
```

```console
$ mix run check-a-ported-program.exs
1000 + 2000 boxes, slot 2
    %{"checked" => 520, "total" => 3000, "total_int" => 3000, "total_int_ok" => 1, "total_ok" => 1, "weight" => 520}
30000 + 30000 boxes, slot 2
    %{"checked" => 520, "total" => 60000, "total_int" => -5536, "total_int_ok" => 0, "total_ok" => 1, "weight" => 520}
slot 8
    %{"checked" => 520, "total" => 60000, "total_int" => -5536, "total_int_ok" => 0, "total_ok" => 1, "weight" => 520}
    major fault index_out_of_range: line 14, move
```

| Scan | What the output shows |
|---|---|
| 2 | The `dint` holds 60000. The `int` wraps to `-5536`, and `total_int_ok` is 0 |
| 3 | The `move` of rung 3, on line 14, has a major fault and does nothing. `weight` keeps 520. The range check of rung 4 stops its `move`, and that `move` has no fault |

## If it does not work

| What you see | Cause | What to do |
|---|---|---|
| An output that is 0 in 1 scan after an `add` | The result wraps and the instruction passes no power | Do the action of step 2 |
| `major fault index_out_of_range` in `state.faults` | A subscript out of range | Put a range check on the rung |
| A plant that trips with `{:fault, ...}` | A major fault, on a runner | [Find why a plant tripped](find-why-a-plant-tripped.md) |
| A count that does not change at the start | The first scan does not count | Do the action of step 5 |
| An output that is on after a warm restart | A rung reads a retained value | Do the action of step 6 |
| ``warning: `ge` compares `cure.acc` with `3000`, where `cure.acc` is a ton_ltime's time in nanoseconds`` | A time in ms on a timer in ns | Multiply the number by 1000000 |

## See also

- [Port a program from Logix or IEC 61131-3](port-a-program.md): the steps of a port.
- [Types and overflow](../explanation/types-and-overflow.md): why a value wraps and why
  the instruction passes no power.
- [Faults](../reference/faults.md): each fault, and what a scan and a runner do.
- [Use counters](use-counters.md): the limits of a counter and its reset.
- [Keep values across a restart](keep-values-across-a-restart.md): the qualifier
  `retain` and its rules.
- [Glossary](../reference/glossary.md): the technical words of logex.
