alias Logex.Runner
alias Logex.Runner.Clock.Manual
alias Logex.IO.Sim

{:ok, plant} = Logex.Configuration.compile_file("warm/packing.logex")
{:ok, clock} = Manual.start_link()
{:ok, panel} = Sim.start_link(reports: true, clock: clock)

{:ok, runner} =
  Runner.start_link(
    configuration: plant,
    io: %{"panel" => {Sim, sim: panel}},
    clock: {Manual, clock}
  )

show = fn label ->
  %{status: status, now: now} = Runner.status(runner)
  out = Sim.outputs(panel)
  IO.puts("t=#{String.pad_leading("#{now}", 2)}  #{label}  #{status}  k1=#{out["panel.q.0"]} case_full=#{out["panel.q.4"]}  boxes=#{Runner.get!(runner, "b1.boxes.cv")}")
end

Sim.set(panel, "panel.i.0", 1)              # start pressed
Manual.advance(clock, 10)
Sim.set(panel, "panel.i.0", 0)

for _box <- 1..3 do
  Sim.set(panel, "panel.i.8", 1)
  Manual.advance(clock, 2)
  Sim.set(panel, "panel.i.8", 0)
  Manual.advance(clock, 2)
end

show.("three boxes  ")
Sim.fail(panel, :read, {:error, :eio})      # the panel's next read fails
Manual.advance(clock, 10)
show.("tripped      ")
:ok = Runner.restart(runner, :warm)         # the count kept, the conveyor off
show.("warm restart ")

Sim.fail(panel, :read, {:error, :eio})
Manual.advance(clock, 10)
:ok = Runner.restart(runner, :cold)         # every value back to its initial one
show.("cold restart ")
:ok = Runner.stop(runner)
