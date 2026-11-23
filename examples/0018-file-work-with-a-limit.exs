alias Logex.IO.Sim
alias Logex.Runner
alias Logex.Runner.Clock.Manual

Enum.each(Path.wildcard("tally.{retain,forces}*"), &File.rm!/1)
{:ok, plant} = Logex.Configuration.compile_file("tally.logex")
{:ok, clock} = Manual.start_link()
here = File.cwd!() <> "/"

# Each runner gets a new simulated panel. The paths are absolute, so that a start does
# not read the working directory through the file server. A limit of 300 ms keeps the
# run short.
opts = fn ->
  {:ok, panel} = Sim.start_link(clock: clock)

  {panel,
   [
     configuration: plant,
     io: %{"panel" => {Sim, sim: panel}},
     clock: {Manual, clock},
     retain: here <> "tally.retain",
     forces: here <> "tally.forces",
     write_limit: 300
   ]}
end

# A message without the directory of the run and without the numbers of the processes,
# in lines of 80 characters or fewer.
plain = fn message ->
  message |> String.replace(here, "") |> String.replace(~r/#PID<[0-9.]+>/, "#PID<...>")
end

wrap = fn text -> IO.write(Regex.replace(~r/(.{1,78})( |$)/, text, "  \\1\n")) end

refused = fn opts ->
  try do
    Runner.start_link(opts)
  rescue
    error in ArgumentError -> wrap.("refused: " <> plain.(error.message))
  end
end

eye = fn panel, values ->
  for value <- values do
    Sim.set(panel, "panel.i.0", value)
    Manual.advance(clock, 10)
  end
end

# The 3 keys of the forces, in a fixed sequence.
forcing = fn runner ->
  status = Runner.status(runner)
  [forces: status.forces, forcing: status.forcing, forces_unknown: status.forces_unknown]
end

# The disk stops: each call through the VM's file server waits. A real disk that stalls
# does the same to each file call.
server = Process.whereis(:file_server_2)
hold = fn -> :sys.suspend(server) end

let_go = fn ->
  :sys.resume(server)
  :sys.get_state(server)
end

{panel, first} = opts.()
{:ok, runner} = Runner.start_link(first)
:ok = Runner.subscribe(runner)
eye.(panel, [1, 0])

IO.puts("1. A second runner on the same files")
{_panel, second} = opts.()
refused.(second)

IO.puts("2. A force while the disk does not answer")
hold.()
force = Task.async(fn -> Runner.force(runner, "eye_1", 1) end)

wait = fn
  [forces: _, forcing: nil, forces_unknown: _], again -> again.(forcing.(runner), again)
  status, _again -> status
end

IO.puts("  while it is written: #{inspect(wait.(forcing.(runner), wait))}")
eye.(panel, [1, 0, 1, 0])
IO.puts("  total_boxes after 2 more boxes: #{Runner.get!(runner, "total_boxes")}")

try do
  Runner.force(runner, "nope", 1)
rescue
  error in ArgumentError -> wrap.("a wrong point, raised at once: " <> error.message)
end

IO.puts("  the answer at the limit: #{inspect(Task.await(force))}")
IO.puts("  then: #{inspect(forcing.(runner))}")

IO.puts("3. The disk answers again")
let_go.()
IO.puts("  tally.forces holds #{inspect(File.read!("tally.forces"))}")
IO.puts("  the runner: #{inspect(forcing.(runner))}")
IO.puts("  unforce: #{inspect(Runner.unforce(runner, "eye_1"))}")
IO.puts("  the runner: #{inspect(forcing.(runner))}")
IO.puts("  tally.forces holds #{inspect(File.read!("tally.forces"))}")

IO.puts("4. A trip while the disk does not answer")
hold.()
Sim.fail(panel, :read, {:error, :eio})
Manual.advance(clock, 10)
%{status: status, trip: trip, retain: retain} = Runner.status(runner)
IO.puts("  status: #{inspect(status)}, trip: #{inspect(trip)}")
IO.puts("  retain: unknown #{inspect(plain.(retain.unknown))}, failed #{inspect(retain.failed)}")

receive do
  {Runner, ^runner, {:retain, answer}} -> IO.puts("  event: #{inspect({:retain, answer})}")
end

IO.puts("5. A stop and a start while the disk does not answer")
IO.puts("  stop: #{inspect(Runner.stop(runner))}")
{_panel, third} = opts.()
refused.(third)

IO.puts("6. The disk answers again")
let_go.()
{_panel, fourth} = opts.()

attempt = fn ->
  try do
    Runner.start_link(fourth)
  rescue
    ArgumentError -> :held
  end
end

# The holder gives the files up when the cut write ends. Until then a start is refused.
free = fn
  {:ok, runner}, _again ->
    runner

  :held, again ->
    Process.sleep(10)
    again.(attempt.(), again)
end

runner = free.(attempt.(), free)
total = Runner.get!(runner, "total_boxes")
IO.puts("  started: total_boxes #{total}, forces #{inspect(Runner.status(runner).forces)}")
:ok = Runner.stop(runner)
