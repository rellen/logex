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
