{:ok, selected} = Logex.compile_file("selected.ld")

scan = fn state, label, inputs ->
  state = Logex.Runtime.put_inputs(selected, state, inputs)
  {outputs, state} = Logex.Runtime.scan(selected, state)
  IO.puts("#{label}  #{inspect(outputs)}")
  for fault <- state.faults, do: IO.puts("    #{inspect(fault)}")
  state
end

Logex.Runtime.instance(selected)
|> scan.("16#0010, bit 4 ", %{"faults" => 0x0010, "sel" => 4})
|> scan.("16#0010, bit 15", %{"sel" => 15})
|> scan.("16#0010, bit 16", %{"sel" => 16})

{:ok, plant} =
  Logex.Configuration.compile(
    "plant",
    """
    task fast interval 10 priority 1
    var_global drive_faults word at drive.i.0
    var_global sel          int  at panel.i.0
    var_global fault_lamp   bool at panel.q.0
    program lamp1 selected with fast
      lamp1.faults drive_faults
      lamp1.sel    sel
      lamp1.lamp   fault_lamp
    """,
    %{"selected" => selected}
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

Logex.IO.Sim.set(drive, "drive.i.0", 0x0010)
Logex.IO.Sim.set(panel, "panel.i.0", 4)
Logex.Runner.Clock.Manual.advance(clock, 10)
IO.puts("bit 4:  the lamp #{inspect(Logex.IO.Sim.outputs(panel))}")
Logex.IO.Sim.set(panel, "panel.i.0", 16)
Logex.Runner.Clock.Manual.advance(clock, 10)
IO.puts("bit 16: the lamp #{inspect(Logex.IO.Sim.outputs(panel))}, #{inspect(Logex.Runner.status(runner).status)}")
IO.puts("    #{inspect(Logex.Runner.status(runner).trip)}")
Logex.Runner.stop(runner)

{:error, diagnostics} =
  Logex.compile(
    "var status word\nvar code word\nvar on bool\nvar n int\n" <>
      "xic status.[code] ote on\nxic on.[n] ote on\nxic on ons status.[n]\nxic status.[16] ote on",
    name: "wrong"
  )

for diagnostic <- diagnostics, do: IO.puts(Logex.Diagnostic.format(diagnostic))

{:ok, literal} =
  Logex.compile("var_input status word\nvar_output on bool\nxic status.[16#4] ote on", name: "literal")

state = Logex.Runtime.put_inputs(literal, Logex.Runtime.instance(literal), %{"status" => 0x0010})
IO.puts("status.[16#4] of 16#0010: #{inspect(elem(Logex.Runtime.scan(literal, state), 0))}")
