alias Logex.Runner
alias Logex.Runner.Clock.Manual
alias Logex.IO.Sim

{:ok, plant} = Logex.Configuration.compile_file("short-pulses/lane.logex")
{:ok, clock} = Manual.start_link()
{:ok, panel} = Sim.start_link(reports: true, clock: clock)

{:ok, runner} =
  Runner.start_link(
    configuration: plant,
    io: %{"panel" => {Sim, sim: panel}},
    clock: {Manual, clock}
  )

box = fn ms ->
  from = Manual.now_ms(clock)
  # A box comes to the photo-eye.
  Sim.set(panel, "panel.i.8", 1)
  Manual.advance(clock, ms)
  # The box is past the photo-eye.
  Sim.set(panel, "panel.i.8", 0)
  Manual.advance(clock, 100 - ms)
  count = Runner.get!(runner, "b1.count")
  IO.puts("a box at the eye from #{from} ms to #{from + ms} ms  count=#{count}")
end

Manual.advance(clock, 10)
box.(60)
box.(20)
box.(60)
:ok = Runner.stop(runner)
