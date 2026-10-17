# Throwaway runner spike (never landed): §4.4's plant driven through Spike.Runner on a fake
# clock with in-memory devices, every scenario printed, the deterministic one run twice and
# compared; then a short run on the real clock.
#
#   mix run spike-runner/scenarios.exs
Code.require_file("plant.exs", __DIR__)
Code.require_file("runner.exs", __DIR__)

defmodule Spike.Scenarios do
  alias Spike.{Runner, Plant}
  alias Spike.Clock.Fake
  alias Spike.IO.Sim

  # panel.i.<n>: pb_start_1 0, pb_stop_1 1, tt_1 2, pb_start_2 3, pb_stop_2 4, tt_2 5,
  # pb_reset 6, estop 7; panel.q.<n>: k1 0, k2 1, lamp_1 2, lamp_2 3; drive.q.<n>: sp_1 0, sp_2 1.
  def plant(opts \\ []) do
    {:ok, clock} = Fake.start_link()
    panel = Sim.new()
    drive = Sim.new()
    for a <- 0..7, do: Sim.set(panel, [a], 0)

    {:ok, r} =
      Keyword.get(opts, :start, &Runner.start_link/1).(
        configuration: Keyword.get(opts, :config, Plant.config()),
        io: %{"panel" => {Sim, sim: panel, clock: clock}, "drive" => {Sim, sim: drive, clock: clock}},
        clock: {Fake, clock},
        period: 10,
        watchdog: 100
      )

    Runner.subscribe(r, [:overlap, :fault, :trip, :restart, :edit])
    %{r: r, clock: clock, panel: panel, drive: drive, log: []}
  end

  def line(p, label) do
    st = Runner.status(p.r)
    q = Sim.outputs(p.panel)
    d = Sim.outputs(p.drive)
    events = drain()

    text =
      "t=#{pad(st.now)} #{String.pad_trailing(label, 30)} #{st.status} " <>
        "k1=#{q[[0]]} k2=#{q[[1]]} lamp_1=#{q[[2]]} lamp_2=#{q[[3]]} sp_1=#{d[[0]]} sp_2=#{d[[1]]}" <>
        if(events == [], do: "", else: "  " <> inspect(events, limit: :infinity))

    IO.puts(text)
    %{p | log: [text | p.log]}
  end

  defp pad(n), do: String.pad_leading("#{n}", 4)

  defp drain do
    receive do
      {Runner, _pid, event} -> [event | drain()]
    after
      0 -> []
    end
  end

  def step(p, ms, label, inputs \\ %{}) do
    Enum.each(inputs, fn {a, v} -> Sim.set(p.panel, [a], v) end)
    Fake.advance(p.clock, ms)
    line(p, label)
  end

  # A: the plant run, deterministic on the fake clock.
  def run_a do
    p = plant() |> line("started, first cycle at once")
    p = step(p, 10, "both starts pressed", %{0 => 1, 3 => 1})
    p = step(p, 40, "held to 50 ms")
    p = step(p, 10, "released", %{0 => 0, 3 => 0})
    p = step(p, 10, "estop pressed (event task)", %{7 => 1})
    p = step(p, 30, "m2 sees estop at its scan")
    {:ok, v} = Runner.get(p.r, "k1_at_trip")
    {:ok, w} = Runner.get(p.r, "k2_at_trip")
    p = %{p | log: ["snapshot k1_at_trip=#{v} k2_at_trip=#{w}" | p.log]}
    IO.puts(hd(p.log))
    p = step(p, 10, "estop released, reset pressed", %{7 => 0, 6 => 1})
    p = step(p, 10, "reset released", %{6 => 0})
    p = step(p, 10, "start 1 pressed", %{0 => 1})
    p = step(p, 10, "start 1 released", %{0 => 0})
    stop(p)
    Enum.reverse(p.log)
  end

  # B: an online edit stepped through the runner between cycles: the slow task to 20 ms and
  # m2's reset wired to the reset button.
  def run_b do
    p = plant() |> line("started")
    p = step(p, 10, "both starts pressed", %{0 => 1, 3 => 1})
    p = step(p, 40, "held to 50 ms")
    p = step(p, 10, "released", %{0 => 0, 3 => 0})

    text =
      Plant.plant_text()
      |> String.replace("task slow interval 50 priority 2", "task slow interval 20 priority 2")
      |> String.replace("  m2.reset    0", "  m2.reset    pb_reset")

    candidate = Plant.config(text)
    {:ok, forecast} = Runner.accept(p.r, candidate)
    IO.puts("accept forecast: #{inspect(forecast)}")
    {:ok, report} = Runner.test(p.r)
    IO.puts("test report: #{inspect(report)}")
    p = step(p, 10, "testing")
    p = step(p, 20, "testing, slow now every 20 ms")
    {:ok, report} = Runner.assemble(p.r)
    IO.puts("assemble report: #{inspect(report)}")
    p = step(p, 20, "assembled")
    IO.puts("status: #{inspect(Runner.status(p.r))}")
    stop(p)
  end

  # C: the watchdog on a slow cycle: a read that takes 150 ms of the fake clock.
  def run_c do
    p = plant() |> line("started")
    p = step(p, 10, "starts pressed", %{0 => 1, 3 => 1})
    p = step(p, 40, "both running")
    writes_before = length(Sim.writes(p.panel))
    Sim.fail(p.panel, {:delay, 150})
    p = step(p, 10, "panel read takes 150 ms")
    writes = Sim.writes(p.panel)
    IO.puts("panel writes after the trip: #{inspect(Enum.drop(writes, writes_before))}")
    IO.puts("m1.fault, k1 as the resource last held them: #{inspect({Runner.get(p.r, "m1.fault"), Runner.get(p.r, "k1")})}")
    p = step(p, 200, "200 ms later, still tripped")
    IO.puts("panel writes while tripped: #{length(Sim.writes(p.panel)) - length(writes)}")
    :ok = Runner.restart(p.r, :cold)
    p = line(p, "restarted cold")
    p = step(p, 10, "starts still held", %{})
    p = step(p, 10, "starts released, pressed again", %{0 => 0, 3 => 0})
    p = step(p, 10, "start 1", %{0 => 1})
    stop(p)
  end

  # D: device failures: an error, a raise, a bad value, each tripping and restarted.
  def run_d do
    p = plant() |> line("started")
    p = step(p, 10, "start 1 pressed", %{0 => 1})
    Sim.fail(p.drive, {:error, :econnreset})
    p = step(p, 10, "drive read fails")
    :ok = Runner.restart(p.r, :cold)
    p = step(p, 10, "restarted")
    Sim.fail(p.panel, :raise)
    p = step(p, 10, "panel adapter raises")
    :ok = Runner.restart(p.r, :warm)
    p = step(p, 10, "restarted warm")
    Sim.fail(p.panel, {:bad, [0], 7})
    p = step(p, 10, "panel gives 7 for a bool")
    Sim.fail(p.panel, nil)
    stop(p)
  end

  # E: the runner wedged (suspended): each output device's own heartbeat zeroes it.
  def run_e do
    p = plant() |> line("started")
    p = step(p, 10, "start 1 pressed", %{0 => 1, 3 => 1})
    p = step(p, 40, "running")
    :sys.suspend(p.r)
    Fake.advance(p.clock, 150)
    IO.puts("runner suspended 150 ms: panel #{inspect(Sim.outputs(p.panel))} drive #{inspect(Sim.outputs(p.drive))}")
    :sys.resume(p.r)
    p = line(p, "runner resumed")
    stop(p)
  end

  # F: the runner killed: each device zeroes its outputs and closes.
  def run_f do
    Process.flag(:trap_exit, true)
    # A device whose parent is killed terminates through terminate/2, which zeroes it; OTP
    # logs that as an error report, which this run leaves out.
    :logger.set_primary_config(:level, :none)
    p = plant(start: &Runner.start/1)
    p = step(p, 10, "start 1 pressed", %{0 => 1, 3 => 1})
    p = step(p, 40, "running")
    devices = :sys.get_state(p.r).devices |> Map.values()
    Process.exit(p.r, :kill)
    Enum.each(devices, fn pid -> ref = Process.monitor(pid); receive do {:DOWN, ^ref, _, _, _} -> :ok after 1000 -> :timeout end end)
    IO.puts("runner killed: panel #{inspect(Sim.outputs(p.panel))} closed=#{Sim.closed?(p.panel)}; drive #{inspect(Sim.outputs(p.drive))} closed=#{Sim.closed?(p.drive)}")
  end

  # G: a hung device: the runner's call times out in real time, the device is killed, the
  # other zeroed, and a restart opens it again.
  def run_g do
    p = plant() |> line("started")
    p = step(p, 10, "start 1 pressed", %{0 => 1})
    Sim.fail(p.panel, :hang)
    t0 = System.monotonic_time(:millisecond)
    p = step(p, 10, "panel read hangs")
    IO.puts("tripped after #{System.monotonic_time(:millisecond) - t0} ms of real time")
    :ok = Runner.restart(p.r, :cold)
    p = step(p, 10, "restarted, panel opened again")
    stop(p)
  end

  # H: host mistakes raise in the caller, and the runner runs on.
  def run_h do
    p = plant()
    for {label, fun} <- [
          {"get! of no path", fn -> Runner.get!(p.r, "m1.nope") end},
          {"force an output", fn -> Runner.force(p.r, "k1", 1) end},
          {"force a bool to 2", fn -> Runner.force(p.r, "pb_start_1", 2) end},
          {"test with no edit", fn -> Runner.test(p.r) end},
          {"restart :hot", fn -> Runner.restart(p.r, :hot) end}
        ] do
      try do
        fun.()
        IO.puts("#{label}: no raise")
      rescue
        e in ArgumentError -> IO.puts("#{label}: ArgumentError: #{Exception.message(e)}")
      end
    end

    :ok = Runner.force(p.r, "pb_start_1", 1)
    p = step(p, 10, "pb_start_1 forced to 1")
    IO.puts("alive after the mistakes: #{Process.alive?(p.r)}, status #{inspect(Runner.status(p.r).forces)}")
    stop(p)
  end

  defp stop(p) do
    Runner.stop(p.r)
    IO.puts("stopped: panel #{inspect(Sim.outputs(p.panel))} closed=#{Sim.closed?(p.panel)}")
  end

  # R: the real clock, briefly: 2 s of §4.4's plant at 10 ms.
  def run_r do
    panel = Sim.new()
    drive = Sim.new()
    for a <- 0..7, do: Sim.set(panel, [a], 0)

    {:ok, r} =
      Runner.start_link(
        configuration: Plant.config(),
        io: %{"panel" => {Sim, sim: panel}, "drive" => {Sim, sim: drive}},
        period: 10,
        watchdog: 100
      )

    Runner.subscribe(r, [:ran, :overlap, :trip])
    Process.sleep(100)
    Sim.set(panel, [0], 1)
    Process.sleep(60)
    Sim.set(panel, [0], 0)
    Process.sleep(1840)
    st = Runner.status(r)
    ran = drain()
    counts = ran |> Enum.filter(&(elem(&1, 0) == :ran)) |> Enum.frequencies_by(&elem(&1, 2))
    IO.puts("real clock, 2 s: #{inspect(Map.take(st, [:status, :now, :cycles, :max_late_ms, :max_cycle_ms, :overlaps]))}")
    IO.puts("  runs by instance: #{inspect(counts)}; overlaps/trips: #{inspect(Enum.reject(ran, &(elem(&1, 0) == :ran)))}")
    IO.puts("  k1=#{Sim.outputs(panel)[[0]]} after a 60 ms press")
    Runner.stop(r)
    IO.puts("  stopped: panel #{inspect(Sim.outputs(panel))} closed=#{Sim.closed?(panel)}")
  end
end

which = System.argv()
run = fn name, fun -> if which == [] or name in which, do: (IO.puts("\n### #{name}"); fun.()) end

run.("A", fn ->
  first = Spike.Scenarios.run_a()
  IO.puts("\n### A again, compared")
  second = Spike.Scenarios.run_a()
  IO.puts("A twice identical: #{first == second}")
end)

run.("B", &Spike.Scenarios.run_b/0)
run.("C", &Spike.Scenarios.run_c/0)
run.("D", &Spike.Scenarios.run_d/0)
run.("E", &Spike.Scenarios.run_e/0)
run.("F", &Spike.Scenarios.run_f/0)
run.("G", &Spike.Scenarios.run_g/0)
run.("H", &Spike.Scenarios.run_h/0)
run.("R", &Spike.Scenarios.run_r/0)
