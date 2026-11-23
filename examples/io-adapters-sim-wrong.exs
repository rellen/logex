# The script makes wrong calls to the simulated device and prints each message. A pid is
# different at each run, so the script prints each pid as #PID<...>.
alias Logex.IO.Sim
alias Logex.Runner
alias Logex.Runner.Clock.Manual

refused = fn call ->
  try do
    call.()
  rescue
    error in ArgumentError ->
      IO.puts(Regex.replace(~r/#PID<[0-9.]+>/, error.message, "#PID<...>"))
  end
end

IO.puts("Options of start_link/1:")
refused.(fn -> Sim.start_link(speed: 1) end)
refused.(fn -> Sim.start_link(reports: true, reports: false) end)
refused.(fn -> Sim.start_link(reports: 1) end)
refused.(fn -> Sim.start_link(wait: 0) end)
refused.(fn -> Sim.start_link(inputs: 0) end)
refused.(fn -> Sim.start_link(writes: 0) end)

IO.puts("\nBefore a runner opens the sim:")
{:ok, panel} = Sim.start_link(inputs: 9)
refused.(fn -> Sim.set(panel, "panel.i.0", 1) end)
refused.(fn -> Sim.set(panel, [9], 1) end)
refused.(fn -> Sim.set(panel, [-1], 1) end)
refused.(fn -> Sim.set(panel, [0], :on) end)

IO.puts("\nAfter a runner opens the sim:")
{:ok, plant} = Logex.Configuration.compile_file("packing.logex")
{:ok, clock} = Manual.start_link()
io = %{"panel" => {Sim, sim: panel}}
{:ok, runner} = Runner.start_link(configuration: plant, io: io, clock: {Manual, clock})
refused.(fn -> Sim.set(panel, [0], 1) end)
refused.(fn -> Sim.set(panel, "panel.i.9", 1) end)
refused.(fn -> Sim.set(panel, "panel.q.0", 1) end)
refused.(fn -> Sim.set(panel, "drive.i.0", 1) end)
refused.(fn -> Sim.set(panel, "panel.i.07", 1) end)

IO.puts("\nfail/3, hold/1 and let_go/1:")
refused.(fn -> Sim.fail(panel, :open, :raise) end)
refused.(fn -> Sim.fail(panel, :read, :boom) end)
refused.(fn -> Sim.fail(panel, :close, {:error, :closed}) end)
refused.(fn -> Sim.fail(panel, :write, {:value, [0], 1}) end)
refused.(fn -> Sim.let_go(panel) end)
:ok = Sim.hold(panel)
refused.(fn -> Sim.hold(panel) end)
refused.(fn -> Sim.let_go(panel) end)

IO.puts("\nA second runner on the same sim:")
refused.(fn -> Runner.start_link(configuration: plant, io: io, clock: {Manual, clock}) end)
:ok = Runner.stop(runner)
