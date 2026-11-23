alias Logex.Runtime
alias Logex.Runner
alias Logex.Runner.Clock.Manual
alias Logex.IO.Sim

programs =
  Map.new(~w(conveyor fan snapshot boxes), fn name ->
    {:ok, program} = Logex.compile_file(name <> ".ld")
    {name, program}
  end)

text = File.read!("0011-tasks-and-rounds/plant.logex")
{:ok, plant} = Logex.Configuration.compile("plant", text, programs)

# Give each cycle its milliseconds and the inputs that change. Print the events.
cycles = fn runtime, changes ->
  Enum.reduce(changes, runtime, fn {ms, inputs}, runtime ->
    {runtime, _outputs, events} = Runtime.cycle(runtime, ms, inputs)
    IO.puts("  +#{ms} ms #{inspect(inputs)}: #{inspect(events)}")
    runtime
  end)
end

IO.puts("1. The core: the due tasks by priority, then the continuous task")
runtime = cycles.(Runtime.start(plant), [{0, %{"estop" => 1}}, {10, %{}}])

IO.puts("2. A late cycle: 1 run, the missed periods counted")
runtime = cycles.(runtime, [{10, %{"estop" => 0}}, {35, %{"estop" => 1}}])
IO.puts("  overlaps: #{inspect(Runtime.overlaps(runtime))}")
IO.puts("  next_due_in: #{Runtime.next_due_in(runtime)} ms")

IO.puts("3. next_due_in/1 counts the periodic tasks only")

{:ok, alone} =
  Logex.Configuration.compile(
    "alone",
    """
    task trip single estop priority 0
    var_global estop      bool at panel.i.7
    var_global k1_at_trip bool
    program snap snapshot with trip
      snap.a     estop
      snap.a_was k1_at_trip
    """,
    Map.take(programs, ["snapshot"])
  )

IO.puts("  an event task alone: #{inspect(Runtime.next_due_in(Runtime.start(alone)))}")

# Each of the first 100 writes to the device passes ms on the manual clock.
slow_writes = fn {:ok, sim}, ms ->
  Enum.each(1..100, fn _write -> Sim.fail(sim, :write, {:delay, ms}) end)
  {:ok, sim}
end

# A device that reports its changes, a device that does not, or a slow device.
device = fn
  clock, :reports -> Sim.start_link(clock: clock, reports: true)
  clock, :reads -> Sim.start_link(clock: clock)
  clock, ms -> slow_writes.(Sim.start_link(clock: clock), ms)
end

# Start a runner on a manual clock, with a simulated device for each name.
on_the_clock = fn configuration, devices, options ->
  {:ok, clock} = Manual.start_link()

  io =
    Map.new(devices, fn {name, kind} ->
      {:ok, sim} = device.(clock, kind)
      {name, {Sim, sim: sim}}
    end)

  options = [configuration: configuration, io: io, clock: {Manual, clock}] ++ options
  {:ok, runner} = Runner.start_link(options)
  {runner, clock, Map.new(io, fn {name, {Sim, sim: sim}} -> {name, sim} end)}
end

rounds = fn runner, label ->
  %{now: now, rounds: rounds} = Runner.status(runner)
  IO.puts("  #{label}: now #{now} ms, #{rounds} rounds")
end

# Print each event that the runner sent since the last look.
events = fn events, runner ->
  receive do
    {Runner, ^runner, event} ->
      IO.puts("    #{inspect(event)}")
      events.(events, runner)
  after
    0 -> :ok
  end
end

IO.puts("4. The runner: rounds back to back while the continuous task runs a program")

{runner, clock, %{"panel" => panel}} =
  on_the_clock.(plant, %{"panel" => :reports, "drive" => :reads}, [])

rounds.(runner, "start")
Manual.advance(clock, 10)
rounds.(runner, "10 ms later")
Sim.set(panel, "panel.i.7", 1)
rounds.(runner, "the e-stop rises")
Sim.set(panel, "panel.i.8", 1)
rounds.(runner, "the eye sees a box")
Manual.advance(clock, 1)
rounds.(runner, "1 ms later")
IO.puts("  b1.count: #{Runner.get!(runner, "b1.count")}")
:ok = Runner.stop(runner)

IO.puts("5. No untimed instance: a round only when a task is due")

{:ok, timed} =
  Logex.Configuration.compile(
    "timed",
    """
    task fast interval 10 priority 1
    task started single k1 priority 3
    var_global pb_start_1 bool at panel.i.0
    var_global estop      bool at panel.i.7
    var_global k1         bool at panel.q.0
    var_global k1_seen    bool
    program c1 conveyor with fast
      c1.start pb_start_1
      c1.stop  0
      c1.reset 0
      c1.motor k1
    program snap snapshot with started
      snap.a     k1
      snap.a_was k1_seen
    """,
    Map.take(programs, ["conveyor", "snapshot"])
  )

{runner, clock, %{"panel" => panel}} = on_the_clock.(timed, %{"panel" => :reports}, [])
:ok = Runner.subscribe(runner, [:ran])
Manual.advance(clock, 35)
rounds.(runner, "35 ms later")
events.(events, runner)
Sim.set(panel, "panel.i.0", 1)
rounds.(runner, "start pressed")
Manual.advance(clock, 5)
rounds.(runner, "5 ms later")
events.(events, runner)
Manual.advance(clock, 1)
rounds.(runner, "1 ms later")
events.(events, runner)
:ok = Runner.stop(runner)

# A program that changes the lamp in each scan, and counts its scans.
{:ok, flash} =
  Logex.compile(
    """
    var_output lamp bool
    var_output n dint

    xio lamp ote lamp
    add n 1 n
    """,
    name: "flash"
  )

IO.puts("6. A round of 25 ms: the fast task waits for the next round")

{:ok, delays} =
  Logex.Configuration.compile(
    "delays",
    """
    task fast interval 10 priority 1
    task main continuous
    var_global lamp       bool at lamps.q.0
    var_global k1_at_trip bool
    program l1 flash
      l1.lamp lamp
    program snap snapshot with fast
      snap.a     0
      snap.a_was k1_at_trip
    """,
    Map.put(Map.take(programs, ["snapshot"]), "flash", flash)
  )

{runner, clock, _sims} = on_the_clock.(delays, %{"lamps" => 25}, poll: 1000)
:ok = Runner.subscribe(runner, [:ran, :overlap])
Enum.each(1..3, fn _advance -> Manual.advance(clock, 0) end)
IO.puts("  each round takes 25 ms: the clock at #{Manual.now_ms(clock)} ms")
events.(events, runner)
:ok = Runner.stop(runner)

IO.puts("7. The share: a call waits for its slot")

# Make the call from a separate process. Advance the clock 0 ms until it answers.
answered = fn
  _answered, {:ok, n}, _task, _clock ->
    n

  answered, nil, task, clock ->
    Manual.advance(clock, 0)
    answered.(answered, Task.yield(task, 10), task, clock)
end

slots = fn configuration, overhead, idle ->
  {runner, clock, _sims} =
    on_the_clock.(configuration, %{"lamps" => 1}, overhead: overhead, poll: 1000)

  Enum.each(1..idle//1, fn _advance -> Manual.advance(clock, 0) end)

  answers =
    Enum.map(1..3, fn _call ->
      task = Task.async(fn -> Runner.get!(runner, "l1.n") end)
      answered.(answered, Task.yield(task, 10), task, clock)
    end)

  :ok = Runner.stop(runner)
  Enum.join(answers, ", ")
end

flashing = fn tasks ->
  {:ok, configuration} =
    Logex.Configuration.compile(
      "lamp",
      tasks <>
        "var_global lamp bool at lamps.q.0\nprogram l1 flash with lamp_task\n  l1.lamp lamp\n",
      %{"flash" => flash}
    )

  configuration
end

continuous = flashing.("task lamp_task continuous\n")
periodic = flashing.("task lamp_task interval 1 priority 1\n")

for {label, configuration, overhead, idle} <- [
      {"continuous task, overhead 20", continuous, 20, 0},
      {"continuous task, overhead 50", continuous, 50, 0},
      {"continuous task, overhead 10", continuous, 10, 0},
      {"continuous task, overhead 20, a call after round 7", continuous, 20, 6},
      {"periodic task of 1 ms, overhead 20", periodic, 20, 0}
    ] do
  IO.puts("  #{label}: answers after rounds #{slots.(configuration, overhead, idle)}")
end
