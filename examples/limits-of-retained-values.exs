alias Logex.Runner
alias Logex.Runner.Clock.Manual
alias Logex.IO.Sim

Logger.configure(level: :none)              # show no crash report of the kill
{:ok, plant} = Logex.Configuration.compile_file("limits-of-retained-values/lane.logex")
{:ok, clock} = Manual.start_link()
File.rm("lane.retain")

start = fn options ->
  {:ok, panel} = Sim.start_link(reports: true, clock: clock)
  io = %{"panel" => {Sim, sim: panel}}
  fixed = [configuration: plant, io: io, clock: {Manual, clock}, retain: "lane.retain"]
  {:ok, runner} = Runner.start_link(fixed ++ options)
  {runner, panel}
end

box = fn panel ->
  Sim.set(panel, "panel.i.8", 1)              # a box at the eye for 60 ms
  Manual.advance(clock, 60)
  Sim.set(panel, "panel.i.8", 0)
  Manual.advance(clock, 40)
end

show = fn label, {runner, panel} ->
  lamp = Sim.outputs(panel)["panel.q.4"]
  IO.puts("#{label}  count=#{Runner.get!(runner, "b1.count")}  lamp=#{lamp}")
end

{runner, panel} = start.([])
for _box <- 1..3, do: box.(panel)
show.("3 boxes, then a stop   ", {runner, panel})
:ok = Runner.stop(runner)                   # the stop writes the store

{runner, panel} = start.([])
show.("a start                ", {runner, panel})
box.(panel)
show.("1 more box, then a kill", {runner, panel})
Process.unlink(runner)
down = Process.monitor(runner)
Process.exit(runner, :kill)                 # a kill writes no store

receive do
  {:DOWN, ^down, :process, _runner, :killed} -> :ok
end

{runner, panel} = start.([])
show.("a start                ", {runner, panel})
:ok = Runner.stop(runner)

{runner, panel} = start.(start: :cold)
show.("a start with :cold     ", {runner, panel})
:ok = Runner.stop(runner)
