# 0010. A fault does not stop a scan

This record is for a contributor who adds an
[instruction](../../guides/reference/glossary.md#instruction) that can read a bad value
while a [program](../../guides/reference/glossary.md#program) runs. It is also for a
contributor who changes how `Logex.Runtime` reports a
[fault](../../guides/reference/glossary.md#fault), or how `Logex.Runner` trips on one. It
says why a divisor of 0 or a subscript out of range does not stop the
[scan](../../guides/reference/glossary.md#scan). It says why a fault is data, and why
only a [major fault](../../guides/reference/glossary.md#major-fault) trips the
[runner](../../guides/reference/glossary.md#runner). If you add an instruction, read
[What a new instruction must do](#what-a-new-instruction-must-do) first.
[Faults](../../guides/reference/faults.md) gives each rule for a user.

## Status

Accepted. No later record replaces this record. Decisions 153 and 160 amend decision 99,
in which only a divisor of 0 was a fault. They add a reason to the
[trip](../../guides/reference/glossary.md#trip) of decision 113. Decision 233 changes
the form of the field `read` of an index fault, from a list to a tuple.

## Date

2026-10-14, the date of decisions 78 and 99. Each part of the record has its date:

- 2026-10-14: decisions 78 and 99. `div`, `mod` and the fault `:divide_by_zero` are
  available on this date (`PLAN.md` M3-3).
- 2026-10-21: decisions 153, 160, 164, 165 and 167. The maintainer answered the questions
  of the design of the data types.
- 2026-10-23: the bit fault, the field `severity`, `sqrt` and the shift count are
  available (M5-8, M5-9 and M5-10). Decisions 210 and 211 confirm 2 rules of M5-9.
- 2026-10-24: the index fault is available (M5-12). Decision 233 makes `read` a tuple.

## Context

A program reads values from the [plant](../../guides/reference/glossary.md#plant) while it
runs. Some values are outside what an instruction can use. The compiler cannot find them,
because they come from a [tag](../../guides/reference/glossary.md#tag) at run time. On
the BEAM, the Erlang function that does the same work raises for most of them, or gives
a wrong value. This table gives the results of a run on Elixir 1.20.4 and OTP 28:

| Case | An example in the plant | The same work on the BEAM |
|---|---|---|
| A divisor of 0 | The line computes the boxes in each minute. At the start, the minutes are 0 | `div(120, 0)` raises `ArithmeticError` |
| The square root of a negative value | A subtraction before `sqrt` gives -0.25 for 1 scan, because of a rounding | `:math.sqrt(-0.25)` raises `ArithmeticError` |
| A [subscript](../../guides/reference/glossary.md#subscript) out of range | The tag `slot` gets to 8. `weights` is an `int[8]`, with the subscripts 0 to 7 | `elem(tuple, 8)` on a tuple of 8 raises `ArgumentError` |
| A [bit](../../guides/reference/glossary.md#bit) number out of range | The lamp shows the bit `sel` of a `word`, and `sel` gets to 16 | A read of bit 16 gives 0, with no error. A write gives a value outside a `word` |
| A negative count of a shift | The count `n` of `shl` gets to -1 | `Bitwise.bsl(9, -1)` gives 4, a shift to the right |

An exception from a scan is neither of the 2 errors of the
[host contract](../../guides/reference/glossary.md#host-contract).
[0008. Errors in the source and errors of the host](0008-source-mistakes-and-host-mistakes.md)
gives the 2 errors: a [diagnostic](../../guides/reference/glossary.md#diagnostic) for the
source text and an `ArgumentError` for the [host](../../guides/reference/glossary.md#host).
The program and the host are both correct here. The value comes from the plant.

[IEC 61131-3](../../guides/reference/glossary.md#iec-61131-3) and the controllers do
different things. The sources of [§4.12](../organisation.md#412-data-types-milestone-5)
and of decisions 150 and 153 give these answers. So do the stanzas of `div`, `mod`, `sqrt`
and `shl` in [the names](../naming.md):

- **A divisor of 0.**
  - IEC: a division by 0 is an error, so ENO is reset to FALSE (Ed 3 §6.6.2.5.8 and
    §6.6.1.5). Ed 2 Annex E lets an implementation find the error when it prepares the
    program, or while the program runs. For `MOD`, Table 29 note e gives OUT := 0.
  - [Logix](../../guides/reference/glossary.md#logix): `DIV` gives Source A for an
    integer divide, and `MOD` gives 0. Both raise the minor fault 4/4, and the controller
    runs on.
  - MatIEC: `DIV` gives 0 with ENO FALSE. `MOD` gives 0 with ENO TRUE.
  - The S7-1200 gives 0 with ENO 0. STEP 7 Safety V20: with ENO wired, `DIV` gives 0 and
    the F-CPU runs on. With ENO not wired, the F-CPU goes to STOP.
  - CODESYS: the result depends on the target system.
- **A subscript out of range.**
  - IEC: an error, found only at run time for a subscript that the program computes.
  - Logix: the major fault 4/20 when the instruction runs. The logic stops, unless a
    handler of faults clears the fault. Then the faulted instruction does not run, and
    the next instruction runs.
  - The S7-1500 stops. The S7-1200 runs on, with an entry in its diagnostic buffer.
    CODESYS checks only with `CheckBounds`. No vendor uses the nearest subscript or wraps
    the subscript.
- **A bit number out of range.**
  - IEC: a bit number is a literal only.
  - Logix: the manuals ask for a bit number in the range of the integer. They do not give
    the fault.
- **A negative square root.**
  - IEC: `SQRT` takes a real. The sources found no clause for a negative value. IEC 60559
    gives NaN.
  - Logix: `SQRT` takes the absolute value of the source before it calculates the root,
    with no fault (1756-RM018A p.474).
- **A negative count of a shift.**
  - IEC: "an error" (Ed 3 Table 30, footnote a).
  - Logix has no instruction that shifts an integer by a count. `BSL` and `BSR` shift a
    bit [array](../../guides/reference/glossary.md#array) by 1 place.

The sources give nothing more for these cases.

## Decision

### An instruction does a defined thing, and the scan runs on

For each case of the Context, logex gives 1 defined result. The instruction sets its
[power](../../guides/reference/glossary.md#power-flow) out, as the table gives. The rest
of the [rung](../../guides/reference/glossary.md#rung) runs on that power, and the next
rungs run. The scan always gets to its last rung (result 1).

| Case | The instruction writes | Power out | Fault |
|---|---|---|---|
| `div` or `mod` with a divisor of 0 or 0.0 | 0, or 0.0 to a real | No | `:divide_by_zero`, minor |
| `sqrt` of a value less than 0 | 0.0 | No | `:negative_sqrt`, minor |
| A subscript in a tag, outside its dimension | Nothing | No | `:index_out_of_range`, major |
| A bit number in a tag, outside the bits of its [type](../../guides/reference/glossary.md#type) | Nothing | No | `:bit_out_of_range`, major |
| A shift or a rotate with a count less than 0 | The source, with no shift | No | None |
| `shl` or `shr` with a count of the width or more | 0 | The power in | None |
| `rol` or `ror` with a count of the width or more | The rotate by the count modulo the width | The power in | None |
| An integer result outside its type | The low bits, a [wrap](../../guides/reference/glossary.md#wrap) | No | None |

The rows come from these decisions:

- 78 and 99 for a divisor of 0
- 164 for a negative root
- 153 for a subscript, and 160 for a bit number
- 165 for the count of a shift

The last row is decision 146, the rule of
[0006. The types of IEC 61131-3 and overflow](0006-iec-types-and-overflow.md). It is here
because it is not a fault.

logex checks the value before it calls the BEAM. `sqrt` checks its source before
`:math.sqrt/1`, so no `ArithmeticError` leaves a scan (decision 164).

### What a new instruction must do

If you add an instruction that can read a bad value at run time, do these 4 things:

1. Give the instruction 1 defined result for each bad value, and no power out. Write in
   its decision if the bad value is a minor fault, a major fault or no fault.
2. Check the value before you call the BEAM. Never let the BEAM raise.
3. Refuse in the compiler a literal that gives a fault or a bad value on each scan. The
   private functions `zero_divisor/4`, `negative_root/4` and `negative_count/4` of the
   compiler do this for `div`, `mod`, `sqrt` and the shifts.
4. For a new kind of fault, add the value of `kind` to the type and the moduledoc of
   `Logex.Fault`. Add a test to `test/logex/fault_test.exs`. Add the kind to the walks of
   `test/logex/api_contract_test.exs`. Add the rule to
   [Faults](../../guides/reference/faults.md).

[Add an instruction](../implementation/adding-an-instruction.md) gives all the steps.
[The runtime and the evaluator](../architecture/runtime-and-evaluator.md) shows where the
fault goes in the code.

### A literal that gives a bad value on each scan does not compile

A [literal](../../guides/reference/glossary.md#literal) does not change. Thus a literal
divisor of 0 gives 0 and no power on each scan. The compiler refuses these literals, with
a diagnostic at the line of each:

- a divisor 0, 0.0 or -0.0 of `div` or `mod` (decision 78)
- a source of `sqrt` less than 0, such as `-4.0` (decision 167). `-0.0` is not less than
  0, and compiles.
- a literal subscript outside its dimension, and a literal bit number outside the bits of
  its type
- a count of a shift or a rotate less than 0

[Faults](../../guides/reference/faults.md) shows each message in a run.

### A fault is data

A fault is a `%Logex.Fault{}`, plain data. logex reports it. It never raises it
(decision 99). A struct names each of its fields:

- `severity` is `:minor` or `:major` (decisions 153 and 160).
- `kind` is `:divide_by_zero`, `:negative_sqrt`, `:index_out_of_range` or
  `:bit_out_of_range`. The set is open, so a host must not fail on a kind that it does
  not know.
- `instruction` is the [mnemonic](../../guides/reference/glossary.md#mnemonic) as an atom.
- `path` is `nil` for a rung of the program. For a rung in a
  [function block](../../guides/reference/glossary.md#function-block), it names the block
  instance, such as `"f1"`, `"s1.inner"` or `"g[1]"`.
- `file` and `line` give the [routine](../../guides/reference/glossary.md#routine) that
  holds the instruction. `file` is `nil` for a program
  [compiled](../../guides/reference/glossary.md#compile) from a string.
- `read` is the value out of range: the bit number, each subscript in a tuple such as
  `{1, 9}`, or the source of a negative root. It is `nil` for a divisor of 0.

`read` is a tuple and not a list, because `inspect/1` shows the list `[8]` as `~c"\b"`
(decision 233).

The host finds the faults in 2 places (decision 99):

| The host runs | Where the faults are |
|---|---|
| `Logex.Runtime.scan/2`, `scan/3` or `call/4` on 1 [instance](../../guides/reference/glossary.md#instance) | `state.faults`: each fault of the last scan, in the sequence of the scan. It is `[]` for a scan with no fault |
| `Logex.Runtime.cycle/3` on a [resource](../../guides/reference/glossary.md#resource) | The event `{:fault, task, instance, fault}`, directly after the event `{:ran, task, instance, now}` of its scan. `task` is `:none` for the programs with no task |

An event is 1 item of the list that `cycle/3` gives. A runner sends a subscriber the
events of the kinds that the subscriber names in `Logex.Runner.subscribe/2`. The runner
sends the kind `:fault` by default.

The field `faults` of an instance has its own rule:

- `Logex.Runtime.instance/1` gives `[]`.
- Each scan replaces the list.
- `put_inputs/3`, `restart/3` and the switch of an
  [online edit](../../guides/reference/glossary.md#online-edit) keep it. None of them is a
  scan.
- A resource keeps no fault. A [cycle](../../guides/reference/glossary.md#cycle) gives its
  faults as events, and then removes them from the
  [state](../../guides/reference/glossary.md#state) of each instance.
- The runtime refuses a state whose `faults` is not a list of `%Logex.Fault{}`, with this
  `ArgumentError`:

<!-- unchecked: the message of a run, from a state with faults: :bad -->
```text
state.faults must be a list of %Logex.Fault{}, got: :bad
```

### A minor fault reports, and a major fault trips the runner

After a [minor fault](../../guides/reference/glossary.md#minor-fault), the plant runs on.
The runner sends the event and writes the outputs of the
[round](../../guides/reference/glossary.md#round), as after a round with no fault.

A step of a round is the run of 1 [task](../../guides/reference/glossary.md#task), or the
run of the programs with no task. After a major fault, the runner does these actions, in
sequence (decisions 153 and 160):

1. The step that found the first major fault of the round runs to its end. It also scans
   each instance after the one with the fault.
2. No later step of the round runs. For a tag of a later task, `Logex.Runner.get/2`
   gives the value of the round before.
3. The runner does not write the outputs of the round.
4. The trip writes 0 to each [output](../../guides/reference/glossary.md#output), through
   each [device](../../guides/reference/glossary.md#device) that answers. The
   [adapter](../../guides/reference/glossary.md#adapter) of a device can refuse the 0.
   Then the runner writes the 0 again at each poll, until the adapter takes it
   (decision 262).
5. The reason of the trip is `{:fault, task, instance, fault}`. It names the first major
   fault of the round.

If the step also runs longer than the
[watchdog](../../guides/reference/glossary.md#watchdog) of its task, the reason still
names the fault. The engineer must correct the fault, not the time (decision 211). The
test "a fault and a watchdog on one step trip for the fault" of
[trip_test.exs](../../test/logex/trip_test.exs) checks this rule.

`cycle/3` does not trip. It runs each task that is due, and gives the events. The host
decides what to do (result 3).

> #### Warning {: .warning}
>
> Do not use a major fault or a trip as a safety function. The trip writes 0 only through
> a device that answers, and only while the Elixir VM runs.
> [Safety and limits](../../guides/explanation/safety-and-limits.md) gives the limits.

### logex checks only an operand that the instruction uses

logex reads a tag that holds a subscript or a bit number only when the instruction reads
or writes the element or the bit. Thus these instructions check nothing and find no
fault:

- a [contact](../../guides/reference/glossary.md#contact), a comparison, `move`, `otl`
  or `otu` on a [false rung](../../guides/reference/glossary.md#false-rung)
- `div`, `mod` or `sqrt` on a false rung
- an instruction in a rung that a [jump](../../guides/reference/glossary.md#jump) skips
- the body of a function block whose `cal` is on a false rung

`ote` on a false rung writes 0, and thus checks its
[operand](../../guides/reference/glossary.md#operand).

In an [element](../../guides/reference/glossary.md#element) with a bit number in a tag,
such as `words[zone].[sel]`, logex checks the subscripts first.

A `cal` whose operand is out of range does nothing (decision 210):

- The body does not run. Its [timers](../../guides/reference/glossary.md#timer) do not
  run in that scan. When the body runs again, each timer adds all the time since it last
  ran.
- Each output keeps its value.
- The rule is the same if the copy in or the copy out reads the operand out of range.
- If the copy out reads it, the body has already run. logex discards that run: the block
  keeps the values from before it, and logex reports none of its minor faults
  (result 2).
- The power out of `cal` is false.

A major fault in the body of a block does not stop the body. The instruction does
nothing, and the body runs on, as the rungs of a program do. The `cal` passes its power
on, as with no fault. Only a fault in its own operands makes its power out false. Logix
stops the rest of an Add-On Instruction.

### How the code does it

A tag can give the subscript of an element or the number of a bit. If its value is out of
range, the read or the write throws the fault. A `catch` writes the fault under the atom
key `:faults` of the env, and gives no power. A `catch` costs 1 reduction. Thus only `cal`
and an instruction with such a tag among its first 3 operands have one.

`div`, `mod` and `sqrt` throw nothing: their clauses write the minor fault. After each
step, the runner looks for the first major fault among the events of the step.
[The runtime and the evaluator](../architecture/runtime-and-evaluator.md) gives the
functions.

```mermaid
flowchart TB
  op["An instruction uses its operand"]
  range(["Subscript and bit in range?"])
  value(["Divisor 0, or negative root?"])
  major["Major fault: it writes nothing"]
  minor["Minor fault: it writes 0 or 0.0"]
  work["It does its work"]
  on["No power out. The scan runs on"]
  where(["On a runner?"])
  host["The host reads the fault and decides"]
  runner(["A major fault in the step?"])
  write["The runner writes the outputs"]
  trip["At the end of the step, the runner trips"]
  op --> range
  range -- No --> major
  range -- Yes --> value
  value -- Yes --> minor
  value -- No --> work
  major --> on
  minor --> on
  on --> where
  where -- No --> host
  where -- Yes --> runner
  runner -- No --> write
  runner -- Yes --> trip
```

Figure: the path of a fault. The runtime checks the range before the value. With a lone
instance or `cycle/3`, the host decides. Only a runner trips, and only on a major fault.

### The rules in a run

The script `examples/0010-a-fault-does-not-stop-a-scan.exs` shows the rules of this
record as numbered results. It reads `scales.ld` and `fan.ld`. Run it from `examples/`.

`scales.ld` puts the weight of each box that the photo-eye sees into `weights[slot]`. The
panel gives `slot`. The program shows the weight in that slot, and a lamp while the weight
is more than 500.

<!-- file: scales.ld -->
```text
var_input  eye    bool
var_input  weight int
var_input  slot   int
var_output last   int
var_output heavy  bool
var weights int[8]
var edge    bool
var p       bool

xic eye ons edge ote p
xic p move weight weights[slot]
move weights[slot] last
gt weights[slot] 500 ote heavy
```

`fan.ld` computes the speed of the fan from its frequency, and the square root of the
frequency.

<!-- file: fan.ld -->
```text
var_input  hz      real
var_output speed   real
var_output precise lreal
var_output rpm     int
var_output whole   int
var_output root    real
var_output root_ok bool

// the fan's speed in revolutions a minute, in a real and in an lreal
mul hz 60.0 speed
mul hz 60.0 precise
real_to_int speed rpm
real_trunc_int speed whole
sqrt hz root ote root_ok
```

```elixir
alias Logex.Runtime
alias Logex.Runner
alias Logex.Runner.Clock.Manual
alias Logex.IO.Sim

{:ok, scales} = Logex.compile_file("scales.ld")
{:ok, fan} = Logex.compile_file("fan.ld")

# Gives 1 short line for a fault: its kind, severity, instruction, line and read.
short = fn %Logex.Fault{} = fault ->
  "#{fault.kind} #{fault.severity} #{fault.instruction} line #{fault.line} read #{inspect(fault.read)}"
end

# Runs 1 scan, then prints the outputs and each fault of the scan.
scan = fn state, program, label, inputs ->
  state = Runtime.put_inputs(program, state, inputs)
  {outputs, state} = Runtime.scan(program, state)
  IO.puts("  #{label}  #{inspect(outputs)}")
  for fault <- state.faults, do: IO.puts("    #{short.(fault)}")
  state
end

IO.puts("1. scales.ld: a subscript out of range")

state =
  Runtime.instance(scales)
  |> scan.(scales, "slot 2         ", %{"eye" => 0, "weight" => 0, "slot" => 2})
  |> scan.(scales, "box 620, slot 2", %{"eye" => 1, "weight" => 620})
  |> scan.(scales, "slot 8         ", %{"eye" => 0, "slot" => 8})

IO.puts("  weights #{inspect(state.env["weights"])}")
kept = Runtime.put_inputs(scales, state, %{"slot" => 2}).faults
IO.puts("  after put_inputs/3: #{length(kept)} faults")
scan.(state, scales, "slot 2 again   ", %{"slot" => 2})

IO.puts("2. A cal with an operand out of range")

{:ok, fan_speed} =
  Logex.compile(
    """
    function_block fan_speed
    var_input  pressure real
    var_output speed    real
    var_output ok       bool
    var        runs     dint

    sqrt pressure speed ote ok
    add runs 1 runs
    """,
    name: "fan_speed"
  )

{:ok, fans} =
  Logex.compile(
    """
    var_input  p      real
    var_input  fan    int
    var_output speeds real[2]
    var_output ok     bool
    var_output done   bool
    var        f1     fan_speed

    cal f1 p speeds[fan] ok ote done
    """,
    name: "fans",
    types: [fan_speed]
  )

state =
  Runtime.instance(fans)
  |> scan.(fans, "fan 1, p 4.0 ", %{"fan" => 1, "p" => 4.0})
  |> scan.(fans, "fan 2, p -1.0", %{"fan" => 2, "p" => -1.0})

IO.puts("  f1.runs #{state.env["f1"]["runs"]}")
scan.(state, fans, "fan 0, p -1.0", %{"fan" => 0})

IO.puts("3. cycle/3: the host gets the events")

{:ok, plant} =
  Logex.Configuration.compile(
    "plant",
    """
    task fast interval 10 priority 1
    task slow interval 10 priority 2
    var_global box_eye    bool at panel.i.0
    var_global box_slot   int  at panel.i.1
    var_global box_weight int  at panel.i.2
    var_global fan_hz     real at panel.i.3
    var_global box_heavy  bool at panel.q.0
    var_global fan_speed  real at panel.q.1
    program scales scales with fast
      scales.eye    box_eye
      scales.weight box_weight
      scales.slot   box_slot
      scales.heavy  box_heavy
    program f1 fan with fast
      f1.hz    fan_hz
      f1.speed fan_speed
    program f2 fan with slow
      f2.hz    fan_hz
    """,
    %{"scales" => scales, "fan" => fan}
  )

# Gives 1 line for an event. For a fault event, the line gives `fault` in place of the
# %Logex.Fault{}, and then the short form of the fault.
event = fn
  {:fault, task, instance, fault} ->
    "{:fault, #{inspect(task)}, #{inspect(instance)}, fault}  #{short.(fault)}"

  other ->
    inspect(other)
end

# Runs 1 cycle, then prints the outputs and each event.
cycle = fn runtime, label, elapsed, inputs ->
  {runtime, outputs, events} = Runtime.cycle(runtime, elapsed, inputs)
  IO.puts("  #{label}  #{inspect(outputs)}")
  for each <- events, do: IO.puts("    " <> event.(each))
  runtime
end

Runtime.start(plant)
|> cycle.("slot 2, 1.0 Hz", 0, %{"box_slot" => 2, "fan_hz" => 1.0})
|> cycle.("slot 8, 2.0 Hz", 10, %{"box_slot" => 8, "fan_hz" => 2.0})

IO.puts("4. The runner: a minor fault, then a major fault")
{:ok, clock} = Manual.start_link()
{:ok, panel} = Sim.start_link(reports: true, clock: clock)

{:ok, runner} =
  Runner.start_link(
    configuration: plant,
    io: %{"panel" => {Sim, sim: panel}},
    clock: {Manual, clock}
  )

# Prints the status, the outputs at the panel, and f1.speed and f2.speed in the resource.
show = fn label ->
  status = Runner.status(runner).status

  speeds =
    "f1.speed #{Runner.get!(runner, "f1.speed")}, f2.speed #{Runner.get!(runner, "f2.speed")}"

  IO.puts(
    "  #{String.pad_trailing(label <> ":", 17)} #{status}, panel #{inspect(Sim.outputs(panel))}"
  )

  IO.puts("    #{speeds}")
end

Sim.set(panel, %{"panel.i.1" => 2, "panel.i.3" => 1.0})
Manual.advance(clock, 10)
show.("slot 2, 1.0 Hz")
Sim.set(panel, "panel.i.3", -0.25)
Manual.advance(clock, 10)
show.("slot 2, -0.25 Hz")
Sim.set(panel, %{"panel.i.1" => 8, "panel.i.3" => 2.0})
Manual.advance(clock, 10)
show.("slot 8, 2.0 Hz")

IO.puts(
  "  writes of 120.0 to the panel: #{Enum.count(Sim.writes(panel), &(&1["panel.q.1"] == 120.0))}"
)

IO.puts("  the last write: #{inspect(List.last(Sim.writes(panel)))}")
{:fault, task, instance, fault} = Runner.status(runner).trip
IO.puts("  trip: #{task} #{instance} #{short.(fault)}")
:ok = Runner.stop(runner)
```

```console
$ mix run 0010-a-fault-does-not-stop-a-scan.exs
1. scales.ld: a subscript out of range
  slot 2           %{"heavy" => 0, "last" => 0}
  box 620, slot 2  %{"heavy" => 1, "last" => 620}
  slot 8           %{"heavy" => 0, "last" => 620}
    index_out_of_range major move line 12 read {8}
    index_out_of_range major gt line 13 read {8}
  weights {0, 0, 620, 0, 0, 0, 0, 0}
  after put_inputs/3: 2 faults
  slot 2 again     %{"heavy" => 1, "last" => 620}
2. A cal with an operand out of range
  fan 1, p 4.0   %{"done" => 1, "ok" => 1, "speeds" => [0.0, 2.0]}
  fan 2, p -1.0  %{"done" => 0, "ok" => 1, "speeds" => [0.0, 2.0]}
    index_out_of_range major cal line 8 read {2}
  f1.runs 1
  fan 0, p -1.0  %{"done" => 1, "ok" => 0, "speeds" => [0.0, 2.0]}
    negative_sqrt minor sqrt line 7 read -1.0
3. cycle/3: the host gets the events
  slot 2, 1.0 Hz  %{"box_heavy" => 0, "fan_speed" => 60.0}
    {:ran, "fast", "scales", 0}
    {:ran, "fast", "f1", 0}
    {:ran, "slow", "f2", 0}
  slot 8, 2.0 Hz  %{"box_heavy" => 0, "fan_speed" => 120.0}
    {:ran, "fast", "scales", 10}
    {:fault, "fast", "scales", fault}  index_out_of_range major move line 12 read {8}
    {:fault, "fast", "scales", fault}  index_out_of_range major gt line 13 read {8}
    {:ran, "fast", "f1", 10}
    {:ran, "slow", "f2", 10}
4. The runner: a minor fault, then a major fault
  slot 2, 1.0 Hz:   running, panel %{"panel.q.0" => 0, "panel.q.1" => 60.0}
    f1.speed 60.0, f2.speed 60.0
  slot 2, -0.25 Hz: running, panel %{"panel.q.0" => 0, "panel.q.1" => -15.0}
    f1.speed -15.0, f2.speed -15.0
  slot 8, 2.0 Hz:   tripped, panel %{"panel.q.0" => 0, "panel.q.1" => 0}
    f1.speed 120.0, f2.speed -15.0
  writes of 120.0 to the panel: 0
  the last write: %{"panel.q.0" => 0, "panel.q.1" => 0}
  trip: fast scales index_out_of_range major move line 12 read {8}
```

| Result | Rule | The output to read |
|---|---|---|
| 1 | A major fault does nothing, and the scan runs on | At slot 8, `move` and `gt` each give a fault and no power. `last` keeps 620, and `heavy` is 0. `put_inputs/3` keeps the 2 faults, and the next scan gives none |
| 2 | A `cal` with an operand out of range runs no body | At `fan` 2, the copy out reads `speeds[2]`. `f1.runs` stays 1, `ok` keeps 1, and the root of -1.0 gives no minor fault. At `fan` 0, the body runs and gives its minor fault, and `done` is 1 |
| 3 | `cycle/3` does not trip | Each fault comes directly after the `{:ran, ...}` of `scales`. `f1` and the task `slow` run, and the cycle gives `fan_speed` 120.0 |
| 4 | The runner runs on after a minor fault, and trips on a major fault | At -0.25 Hz, the runner writes -15.0. At slot 8, `f1` scans after the fault, in the same step: `f1.speed` is 120.0. The panel never gets 120.0, and its last write is 0 for each output. `f2.speed` stays -15.0, because the task `slow` did not run. The trip names the first fault, at line 12 |

## Consequences

The good results:

- A scan always gets to its last rung. No value from the plant makes the core raise. The
  host contract holds: a diagnostic or an `ArgumentError`, and no other error.
- Each instruction has 1 defined result for each bad value. A controls engineer can know
  the result before the program runs.
- A fault names the instance, the file, the line, the instruction and the value. The
  engineer finds the rung from the fault alone.
- The power out lets the program act on a fault. `div boxes minutes per_minute ote
  rate_ok` shows the fault on a lamp.
- The host decides for a lone instance and for `cycle/3`. Only the runner trips, and it
  never writes the outputs of a round with a major fault.

The costs:

- A host that reads no `state.faults` and no event does not see a minor fault. The
  value 0 looks like a correct value.
- `state.faults` holds only the faults of the last scan. A host that scans 2 times and
  reads after the second loses the faults of the first.
- A major fault stops the whole plant, also a fan that must run on. The trip writes 0 to
  each output (decision 113).
- A retained subscript that tripped the plant trips it again after a
  [warm restart](../../guides/reference/glossary.md#warm-restart).
  [0016. Retained values and starts](0016-retained-values-and-starts.md) gives the 3
  remedies (decision 284).
- logex runs the faulting step to its end, where Logix stops the logic. Thus the state
  that `get/2` reads after a trip is not the state that a Logix controller keeps after
  the fault. Neither writes the outputs of the round.
- Inside the body of a block, a major fault does not stop the body. Logix stops the rest
  of an Add-On Instruction.
- Each `cal` costs 1 reduction more for its `catch`. So does each instruction with a
  subscript or a bit number in a tag among its first 3 operands.

## Alternatives considered

| Alternative | Why logex does not do it |
|---|---|
| A division by 0 keeps its last result and gives no power | The maintainer chose 0 and no power, as recommended. Decision 78 gives no other reason |
| A division by 0 gives Source A, as Logix does | Source A looks like a correct answer. IEC's ENO, MatIEC and STEP 7 Safety give 0 (decision 78, the stanza of `div`) |
| A division by 0 gives 0 and no report | The maintainer took the recommendation, 0 and no power, and added a report: the host must know of each division by 0 (decision 78) |
| A fault as a tuple, `{:divide_by_zero, :div, path, file, line}` | A tuple names none of its fields. A struct names each field (decision 99) |
| `call/4` and `scan/2,3` give the events as a third element | Each host and each test of a lone instance then changes (decision 99) |
| An index out of range is a minor fault: a read gives 0, a write does nothing, and the plant runs on | Logix raises a major fault, and the S7-1500 stops. The maintainer chose the major fault, as recommended (decision 153) |
| The nearest subscript, `weights[7]`, with no message | `weights[7]` gets the weight of a different box, and nothing tells the host. No vendor does it (decision 153) |
| The subscript wraps, `weights[0]` | `weights[0]` gets the weight. No vendor does it (decision 153) |
| A bit number only as a literal, never in a tag | Logix lets a tag hold the number. The maintainer chose the tag with the major fault, as recommended (decision 160) |
| The bit number modulo the width | The maintainer chose the major fault, as for a subscript. Decision 160 gives no other reason |
| A negative root gives the root of its absolute value, as Logix does | A root of -0.25 that reads as 0.5 hides the rounding before it (decision 164) |
| A negative root gives NaN, as IEC 60559 does | logex keeps NaN out of each state (decision 150, kept by decision 164) |
| A negative root gives 0.0 and no power, with no fault, as a wrap does | The maintainer chose the minor fault, so that the host knows of the bad value. Decision 164 gives no other reason |
| A negative root is a major fault, which trips the plant | The maintainer chose the minor fault. Decision 164 gives no other reason |
| A negative count of a shift is a minor or a major fault | The maintainer chose no fault and no power. Decision 165 gives no reason |
| A literal negative root compiles | A literal never changes, so the program can never run without the fault. The compiler refuses a literal divisor of 0 for the same reason (decisions 78 and 167) |
| The trip names the watchdog when a step faults and is late | The engineer corrects the fault, not the time (decision 211) |
| `read` of an index fault is a list, `[8]` | `inspect/1` shows `[8]` as `~c"\b"` (decision 233) |

## Decisions in section 7

This record sums up 10 decisions of
[`docs/organisation.md`](../organisation.md#7-decisions):

- a fault as data, and the minor faults: 78, 99, 164 and 167
- the major faults: 153, 160, 210, 211 and 233
- the negative count of a shift, which is not a fault: 165

[§4.12](../organisation.md#412-data-types-milestone-5) of the same document gives the
design of the major fault, with its sources. `PLAN.md` keeps the history in M3-3, M5-8,
M5-9, M5-10 and M5-12.

It also uses decisions that other records sum up:

- Decision 113, the trip, and decision 262, the 0 written again at each poll:
  [0013. Watchdogs and the trip](0013-watchdogs-and-the-trip.md).
- Decision 146, the wrap, and decision 150, no NaN:
  [0006. The types of IEC 61131-3 and overflow](0006-iec-types-and-overflow.md).
- Decision 284, a retained value that trips again:
  [0016. Retained values and starts](0016-retained-values-and-starts.md).

[Faults](../../guides/reference/faults.md) gives the rules for a user.
[Trips and watchdogs](../../guides/explanation/trips-and-watchdogs.md) gives the model.
[Find why a plant tripped](../../guides/howto/find-why-a-plant-tripped.md) and
[Restart after a trip](../../guides/howto/restart-after-a-trip.md) give the steps.
