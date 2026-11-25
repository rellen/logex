# Runs and tables of the records: faults

This page is for a contributor who reads a decision record about the faults of a scan. It holds the
runs, the measurements and the long tables of record 0010, so that each record stays
short. Each section names its record, and each record links to its section.

The suite runs each example of this page, as it runs the examples of each other page.
Each script and its files are under `examples/`.

## 0010. A fault does not stop a scan

These answers and this run support
[0010. A fault does not stop a scan](../adr/0010-a-fault-does-not-stop-a-scan.md).

### The same work on the BEAM

On the BEAM, the Erlang function that does the work of an instruction raises for most bad
values, or gives a wrong value. This table gives the results of a run on Elixir 1.20.4 and
OTP 28:

| Case | An example in the plant | The same work on the BEAM |
|---|---|---|
| A divisor of 0 | The line computes the boxes in each minute. At the start, the minutes are 0 | `div(120, 0)` raises `ArithmeticError` |
| The square root of a negative value | A subtraction before `sqrt` gives -0.25 for 1 scan, because of a rounding | `:math.sqrt(-0.25)` raises `ArithmeticError` |
| A [subscript](../../guides/reference/glossary.md#subscript) out of range | The tag `slot` gets to 8. `weights` is an `int[8]`, with the subscripts 0 to 7 | `elem(tuple, 8)` on a tuple of 8 raises `ArgumentError` |
| A [bit](../../guides/reference/glossary.md#bit) number out of range | The lamp shows the bit `sel` of a `word`, and `sel` gets to 16 | A read of bit 16 gives 0, with no error. A write gives a value outside a `word` |
| A negative count of a shift | The count `n` of `shl` gets to -1 | `Bitwise.bsl(9, -1)` gives 4, a shift to the right |

### What IEC 61131-3 and the controllers do

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
    runs on (1756-RM018A, `DIV` pp.445 to 451 and `MOD` pp.451 to 458).
  - MatIEC: `DIV` gives 0 with ENO FALSE. `MOD` gives 0 with ENO TRUE.
  - The S7-1200 gives 0 with ENO 0. STEP 7 Safety V20: with ENO wired, `DIV` gives 0 and
    the F-CPU runs on. With ENO not wired, the F-CPU goes to STOP.
  - CODESYS: the result depends on the target system.
- **A subscript out of range.**
  - IEC: an error, found only at run time for a subscript that the program computes.
  - Logix: the major fault 4/20 when the instruction runs (1756-RM018A p.884). The logic
    stops, unless a handler of faults clears the fault. Then the faulted instruction does
    not run, and the next instruction runs (1756-PM014O p.9).
  - The S7-1500 stops. The S7-1200 runs on, with an entry in its diagnostic buffer.
    CODESYS checks only with `CheckBounds`. No vendor uses the nearest subscript or wraps
    the subscript.
- **A bit number out of range.**
  - IEC: a bit number is a literal only.
  - Logix: the manuals ask for a bit number in the range of the integer (1756-PM004L
    p.44). They do not give the fault.
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

## See also

- [Decision records](../adr/README.md): the list of the records.
- [The checks of a change](testing-checks.md): how the suite runs the examples of a page.
