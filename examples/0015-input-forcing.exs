# The rules of record 0015 in a run: what a runner forces, where it keeps the forces, and
# what a start and a restart read. The runner runs on a manual clock, with a simulated
# panel, so the output is the same at each run.
alias Logex.Runner
alias Logex.Runner.Clock.Manual
alias Logex.IO.Sim

Logger.configure(level: :none)
{:ok, packing} = Logex.Configuration.compile_file("packing.logex")
{:ok, trip} = Logex.Configuration.compile_file("trip.logex")
forces = "packing.forces"
File.rm_rf!(forces)

# Starts a runner of `plant` with the options, and gives the runner, its clock and its panel.
start = fn plant, options ->
  {:ok, clock} = Manual.start_link()
  {:ok, panel} = Sim.start_link(reports: true, clock: clock)
  io = %{"panel" => {Sim, sim: panel}}
  options = [configuration: plant, io: io, clock: {Manual, clock}] ++ options
  {:ok, runner} = Runner.start_link(options)
  {runner, clock, panel}
end

# Prints the answer of `fun`, or the message of the ArgumentError that it raises.
attempt = fn fun ->
  try do
    IO.puts("  " <> inspect(fun.()))
  rescue
    error in ArgumentError -> IO.puts("  " <> error.message)
  end
end

# Prints the time, the value of eye that the program reads, the count and the forces.
show = fn runner ->
  %{now: now, forces: in_effect} = Runner.status(runner)
  eye = Runner.get!(runner, "eye")
  boxes = Runner.get!(runner, "b1.count")
  IO.puts("  t=#{now} eye=#{eye} boxes=#{boxes} forces=#{inspect(in_effect)}")
end

# Moves the real photo-eye on and off. Each change gets a round of 1 ms.
box = fn panel, clock ->
  Sim.set(panel, "panel.i.8", 1)
  Manual.advance(clock, 1)
  Sim.set(panel, "panel.i.8", 0)
  Manual.advance(clock, 1)
end

file = fn -> IO.puts("  packing.forces: " <> inspect(File.read!(forces))) end

IO.puts("1. A runner with no forces file")
{runner, _clock, _panel} = start.(packing, [])
attempt.(fn -> Runner.force(runner, "eye", 1) end)
:ok = Runner.stop(runner)

IO.puts("2. An output point, a tag of an instance, and the core")
{runner, clock, panel} = start.(packing, forces: forces)
attempt.(fn -> Runner.force(runner, "k1", 1) end)
attempt.(fn -> Runner.force(runner, "b1.eye", 1) end)
{:module, Logex.Runtime} = Code.ensure_loaded(Logex.Runtime)
names = for {name, arity} <- Logex.Runtime.__info__(:functions), do: "#{name}/#{arity}"
forcing = Enum.filter(names, &String.contains?(&1, "forc"))
IO.puts("  functions of Logex.Runtime with forc in the name: #{inspect(forcing)}")

IO.puts("3. The real eye counts, then the force holds eye at 1")
box.(panel, clock)
show.(runner)
:ok = Runner.force(runner, "eye", 1)
Manual.advance(clock, 1)
show.(runner)
box.(panel, clock)
box.(panel, clock)
show.(runner)
file.()

IO.puts("4. A write of the file that fails")
File.mkdir!(forces <> ".tmp")
attempt.(fn -> Runner.force(runner, "pb_reset", 1) end)
show.(runner)
file.()
File.rmdir!(forces <> ".tmp")

IO.puts("5. A crash, and a fresh start that reads the file")
Process.flag(:trap_exit, true)
Process.exit(runner, :kill)
receive do: ({:EXIT, ^runner, :killed} -> :ok)
{runner, clock, panel} = start.(packing, forces: forces)
show.(runner)

IO.puts("6. The real eye is on, and then eye is unforced")
Sim.set(panel, "panel.i.8", 1)
Manual.advance(clock, 1)
show.(runner)
:ok = Runner.unforce(runner, "eye")
Manual.advance(clock, 1)
show.(runner)
file.()
:ok = Runner.stop(runner)

IO.puts("7. A forced trigger")
{runner, _clock, panel} = start.(trip, forces: forces)
:ok = Runner.subscribe(runner, [:ran])

# Prints the tasks that ran since the last look, from the :ran events.
ran = fn label ->
  _ = :sys.get_state(runner)
  {:messages, messages} = Process.info(self(), :messages)
  tasks = for {Runner, ^runner, {:ran, task, _, _}} <- messages, do: task
  for {Runner, ^runner, _} <- messages, do: receive(do: ({Runner, ^runner, _} -> :ok))
  IO.puts("  #{label}: ran #{inspect(tasks)}")
end

press = fn ->
  Sim.set(panel, "panel.i.7", 1)
  Sim.set(panel, "panel.i.7", 0)
end

:ok = Runner.force(runner, "estop", 1)
ran.("force estop 1")
press.()
ran.("the real e-stop pressed and let go")
:ok = Runner.force(runner, "estop", 1)
ran.("force estop 1 again")
:ok = Runner.unforce(runner, "estop")
ran.("unforce estop")
press.()
ran.("the real e-stop pressed and let go")
:ok = Runner.stop(runner)

IO.puts("8. A forces file that a person writes")
File.write!(forces, "// the eye, blocked for a test\neye 1\n")
attempt.(fn -> start.(packing, forces: forces) end)
File.write!(forces, "pb_reset 1_0\n")
attempt.(fn -> start.(packing, forces: forces) end)
File.write!(forces, "eye 01\r\n")
{runner, _clock, _panel} = start.(packing, forces: forces)
show.(runner)
:ok = Runner.force(runner, "pb_reset", 1)
file.()
:ok = Runner.stop(runner)

IO.puts("9. A forces file that the start cannot read")
File.rm!(forces)
File.mkdir!(forces)
{runner, clock, panel} = start.(packing, forces: forces)
%{forces_unread: {_path, reason}} = Runner.status(runner)
IO.puts("  forces_unread: the file, #{inspect(reason)}")
File.rmdir!(forces)
File.write!(forces, "eye 1\n")
# A failed read of the panel trips the runner. The script can then ask for a restart.
Sim.fail(panel, :read, {:error, :eio})
Manual.advance(clock, 10)
IO.puts("  #{Runner.status(runner).status}, restart: #{inspect(Runner.restart(runner, :cold))}")
show.(runner)
IO.puts("  stop: #{inspect(Runner.stop(runner))}")
file.()
File.rm!(forces)
