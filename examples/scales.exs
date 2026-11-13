{:ok, scales} = Logex.compile_file("scales.ld")

scan = fn state, label, inputs ->
  state = Logex.Runtime.put_inputs(scales, state, inputs)
  {outputs, state} = Logex.Runtime.scan(scales, state)
  IO.puts("#{label}  #{inspect(outputs)}  weights #{inspect(state.env["weights"])}")
  for fault <- state.faults, do: IO.puts("    #{inspect(fault)}")
  state
end

Logex.Runtime.instance(scales)
|> scan.("slot 2          ", %{"eye" => 0, "weight" => 0, "slot" => 2})
|> scan.("box 620, slot 2 ", %{"eye" => 1, "weight" => 620})
|> scan.("gone            ", %{"eye" => 0})
|> scan.("box 410, slot 5 ", %{"eye" => 1, "weight" => 410, "slot" => 5})
|> scan.("gone, slot 2    ", %{"eye" => 0, "slot" => 2})
|> scan.("slot 8          ", %{"slot" => 8})

{:ok, plant} =
  Logex.Configuration.compile(
    "plant",
    """
    task fast interval 10 priority 1
    var_global box_eye    bool at panel.i.0
    var_global box_slot   int  at panel.i.1
    var_global box_weight int  at drive.i.0
    var_global box_heavy  bool at panel.q.0
    program scales scales with fast
      scales.eye    box_eye
      scales.weight box_weight
      scales.slot   box_slot
      scales.heavy  box_heavy
    """,
    %{"scales" => scales}
  )

{:ok, clock} = Logex.Runner.Clock.Manual.start_link()
{:ok, panel} = Logex.IO.Sim.start_link(reports: true, clock: clock)
{:ok, drive} = Logex.IO.Sim.start_link(clock: clock)

{:ok, runner} =
  Logex.Runner.start_link(
    configuration: plant,
    io: %{"panel" => {Logex.IO.Sim, sim: panel}, "drive" => {Logex.IO.Sim, sim: drive}},
    clock: {Logex.Runner.Clock.Manual, clock}
  )

Logex.IO.Sim.set(drive, "drive.i.0", 730)
Logex.IO.Sim.set(panel, %{"panel.i.0" => 1, "panel.i.1" => 4})
Logex.Runner.Clock.Manual.advance(clock, 10)
IO.puts("box 730 in slot 4: the lamp #{inspect(Logex.IO.Sim.outputs(panel))}")
Logex.IO.Sim.set(panel, "panel.i.1", 8)
Logex.Runner.Clock.Manual.advance(clock, 10)
IO.puts("slot 8: the lamp #{inspect(Logex.IO.Sim.outputs(panel))}, #{inspect(Logex.Runner.status(runner).status)}")
IO.puts("    #{inspect(Logex.Runner.status(runner).trip)}")
Logex.Runner.stop(runner)

{:ok, grid} =
  Logex.compile("var_input c int\nvar grid int[4,8]\nvar_output x int\nmove grid[1,c] x", name: "grid")

{_outputs, state} =
  Logex.Runtime.scan(grid, Logex.Runtime.put_inputs(grid, Logex.Runtime.instance(grid), %{"c" => 9}))

IO.puts("grid[1,c] at c 9: #{inspect(state.faults)}")

{:error, diagnostics} =
  Logex.compile(
    "var weights int[8]\nvar grid int[4,8]\nvar edge bool[8]\nvar slot int\nvar code word\n" <>
      "var x int\nvar on bool\n" <>
      "move weights[code] x\nmove grid[slot,8] x\nxic on ons edge[slot] ote on\n" <>
      "move weights[sloot] x",
    name: "wrong"
  )

for diagnostic <- diagnostics, do: IO.puts(Logex.Diagnostic.format(diagnostic))
