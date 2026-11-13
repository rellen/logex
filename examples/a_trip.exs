alias Logex.Runner
alias Logex.Runner.Clock.Manual
alias Logex.IO.Sim

{:ok, plant} = Logex.Configuration.compile_file("packing.logex")
{:ok, clock} = Manual.start_link()
{:ok, panel} = Sim.start_link(reports: true, clock: clock)

{:ok, runner} =
  Runner.start_link(
    configuration: plant,
    io: %{"panel" => {Sim, sim: panel}},
    clock: {Manual, clock}
  )

:ok = Runner.subscribe(runner)

status = fn keys ->                         # the fields named, in the order named
  IO.inspect(for(key <- keys, do: {key, Map.fetch!(Runner.status(runner), key)}))
end

Sim.set(panel, "panel.i.0", 1)              # start pressed
Manual.advance(clock, 10)
Sim.set(panel, "panel.i.0", 0)

Sim.fail(panel, :read, {:error, :eio})      # the panel's next read, at its poll at 20, fails
Manual.advance(clock, 15)
status.([:status, :trip, :now, :rounds])    # a call, answered once the runner has tripped
IO.inspect(for({Runner, ^runner, event} <- Process.info(self(), :messages) |> elem(1), do: event), label: "events")
IO.inspect(Runner.get!(runner, "k1"), label: "k1 in the resource")
IO.inspect(Enum.take(Sim.writes(panel), -2), label: "the panel's last two writes")

Manual.advance(clock, 1000)                 # tripped: nothing runs, nothing is written
status.([:status, :now, :rounds])

:ok = Runner.restart(runner, :cold)         # the latch released, the first round at once
status.([:status, :trip, :now, :rounds])
IO.inspect(Sim.outputs(panel), label: "the panel's outputs")
