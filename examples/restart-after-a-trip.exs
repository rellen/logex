alias Logex.IO.Sim
alias Logex.Runner
alias Logex.Runner.Clock.Manual

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
  %{"panel.q.0" => k1, "panel.q.4" => case_full} = Sim.outputs(panel)
  boxes = Runner.get!(runner, "b1.boxes.cv")
  IO.puts("t=#{now}  #{label}  #{status}  k1=#{k1} case_full=#{case_full}  boxes=#{boxes}")
end

# The plant runs: start pressed, then 3 boxes.
Sim.set(panel, "panel.i.0", 1)
Manual.advance(clock, 10)
Sim.set(panel, "panel.i.0", 0)

for _box <- 1..3 do
  Sim.set(panel, "panel.i.8", 1)
  Manual.advance(clock, 2)
  Sim.set(panel, "panel.i.8", 0)
  Manual.advance(clock, 2)
end

show.("3 boxes      ")

# The next read of the panel fails, and the write of the trip's 0 fails too.
Sim.fail(panel, :read, {:error, :eio})
Sim.fail(panel, :write, {:error, :eio})
Manual.advance(clock, 10)

# The reason of the trip.
IO.inspect(Runner.status(runner).trip, label: "trip")

# The devices whose outputs can still be on.
IO.inspect(Runner.status(runner).unzeroed, label: "unzeroed")
show.("tripped      ")
Manual.advance(clock, 10)
IO.inspect(Runner.status(runner).unzeroed, label: "unzeroed")
show.("1 poll later ")

# A value of the resource.
IO.inspect(Runner.get!(runner, "k1"), label: "k1 in the resource")

# A restart before the cause is removed, then a warm restart.
Sim.fail(panel, :read, {:error, :eio})
IO.inspect(Runner.restart(runner, :warm), label: "restart")
show.("no restart   ")
:ok = Runner.restart(runner, :warm)
show.("warm restart ")

# A second trip, and a cold restart.
Sim.fail(panel, :read, {:error, :eio})
Manual.advance(clock, 10)
:ok = Runner.restart(runner, :cold)
show.("cold restart ")
:ok = Runner.stop(runner)
