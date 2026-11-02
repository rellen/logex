defmodule Logex.StalledDiskTest do
  @moduledoc """
  Decision 353 (RV-4): every file write the runner makes, a force's of the forces file and
  the store's at a trip, a stop, a cold restart and a fresh start, is limited to the idle
  watchdog and a poll period of real time, as the period's write is where the runner waits
  on it (decision 275), and so is the forces file's read at a restart: one past it fails, a
  force `{:error, {:forces, :timeout}}`, a store write reported as any failed write, and the
  runner answers on. A stalled disk is acted out by the VM's file server held
  (`:sys.suspend/1`), which every write's rename goes through, and a delete of what stands
  at its `.tmp`, its other calls raw, so that stop/2, restart/2, status/1 and force/3 are
  seen answering, the plant's outputs 0 through the trip as ever, and the forces file's read
  at a restart, raw, by a FIFO in its place, whose read waits for a writer. And M10: each
  write's `.tmp` is its own, made new and exclusively, whatever stands at it deleted, so
  that a write killed inside a call of the file system, which runs on in the kernel after
  the kill, never writes into the next write's file. Not async: the file server is the
  VM's, and a test holds it.
  """
  use ExUnit.Case, async: false

  @moduletag :tmp_dir
  @moduletag capture_log: true

  alias Logex.{Configuration, Runner}
  alias Logex.IO.Sim
  alias Logex.Runner.Clock.Manual

  # A box counter: a retained count of the eye's rises, and its lamp at the panel.
  @tally """
  var_input eye bool
  var_output lamp bool
  var retain boxes ctu

  xic eye ctu boxes 1000
  xic eye ote lamp
  """

  @plant """
  task fast interval 10 priority 1
  var_global eye_1 bool at panel.i.0
  var_global level dint at panel.i.1
  var_global lamp_q bool at panel.q.0
  var_global retain total dint 0

  program t1 tally with fast
    t1.eye eye_1
    t1.lamp lamp_q
  """

  # Every write's limit, the idle watchdog and a poll period: 1010 ms of real time. At 110
  # ms a write the disk was free for, a fresh start's or a stop's, missed its limit on a
  # loaded machine beside another suite's syncs in four runs of six, and at 510 ms a
  # force's once in fifty (scripts/load.sh); a stalled write fails at any limit, which only
  # the time the test takes reads.
  @idle 1000
  @poll 10

  defp configured do
    {:ok, tally} = Logex.compile(@tally, name: "tally")
    {:ok, config} = Configuration.compile("plant", @plant, %{"tally" => tally})
    config
  end

  defp rig(dir, extra \\ []) do
    {:ok, clock} = Manual.start_link()
    {:ok, panel} = Sim.start_link(clock: clock)
    store = Path.join(dir, "plant.retain")
    forces = Path.join(dir, "plant.forces")

    opts =
      Keyword.merge(
        [
          configuration: configured(),
          io: %{"panel" => {Sim, sim: panel}},
          clock: {Manual, clock},
          idle: @idle,
          poll: @poll,
          retain: store,
          forces: forces,
          retain_period: 3_600_000
        ],
        extra
      )

    %{opts: opts, clock: clock, panel: panel, store: store, forces: forces}
  end

  defp eye(%{panel: panel, clock: clock}, eye) do
    Sim.set(panel, [0], eye)
    Manual.advance(clock, 10)
  end

  # The VM's file server held, as a stalled disk holds every call of the file system made
  # through it; let go when the test ends whatever comes, since every file call waits on
  # it meanwhile.
  defp held do
    server = Process.whereis(:file_server_2)
    :sys.suspend(server)
    on_exit(fn -> :sys.resume(server) end)
    server
  end

  defp caller_alive?({:"$gen_call", {pid, _tag}, _request}) when is_pid(pid),
    do: Process.alive?(pid)

  defp caller_alive?(_message), do: false

  # The process whose call of `kind`, a delete or a rename, waits in the held file
  # server's mailbox, once one does.
  defp waiting_call(server, kind), do: caller(Process.info(server, :messages), server, kind)

  defp caller({:messages, messages}, server, kind),
    do:
      caller_found(
        for({:"$gen_call", {pid, _}, request} <- messages, elem(request, 0) == kind, do: pid),
        server,
        kind
      )

  defp caller_found([pid | _], _server, _kind), do: pid
  defp caller_found([], server, kind), do: waiting_call(server, kind)

  # Waits until a stop's request to terminate waits in the runner's mailbox.
  defp terminate_waiting(runner),
    do: terminate_found(Process.info(runner, :messages), runner)

  defp terminate_found({:messages, messages}, runner),
    do:
      terminate_seen(
        Enum.any?(messages, &match?({:system, _, {:terminate, _}}, &1)),
        runner
      )

  defp terminate_seen(true, _runner), do: :ok
  defp terminate_seen(false, runner), do: terminate_waiting(runner)

  # The first stop's reason, and its end: its write let through, or its runner killed as
  # it writes, which ends both stops.
  defp reason_of(:killed), do: :normal
  defp reason_of(reason), do: reason

  defp ended(:killed, runner), do: Process.exit(runner, :kill)
  defp ended(_reason, _runner), do: :ok

  defp answers(:killed, runner),
    do: {gone_told(runner), gone_told(runner)}

  defp answers(_reason, _runner), do: {:ok, :ok}

  defp gone_told(runner), do: {:raised, "the runner #{inspect(runner)} is not running"}

  defp stop_answer(runner, reason) do
    Runner.stop(runner, reason)
  rescue
    error in ArgumentError -> {:raised, error.message}
  end

  # The period's writer and the runner each through their mailboxes twice, so that a
  # write handed has been made and its answer taken.
  defp period_settled(runner) do
    {:links, links} = Process.info(runner, :links)

    writers =
      for pid <- links,
          {:dictionary, dictionary} <- [Process.info(pid, :dictionary)],
          dictionary[:"$initial_call"] == {Logex.Runner.Writer, :init, 1},
          do: pid

    for writer <- writers, _ <- 1..2 do
      _ = :sys.get_state(writer)
      _ = :sys.get_state(runner)
    end
  end

  # The runner's status once a period's write has answered and been taken.
  defp written(runner), do: written_status(Runner.status(runner), runner)

  defp written_status(%{retain: %{failed: :timeout}}, runner), do: written(runner)
  defp written_status(status, _runner), do: status

  # A FIFO's reader let go: the FIFO opened for reading and writing, which never waits,
  # by a shell spawned straight, its path an argument, since a file call through the VM's
  # file server may be the one held.
  defp let_go(fifo) do
    port =
      Port.open({:spawn_executable, "/bin/sh"}, [
        :exit_status,
        args: ["-c", "exec 3<>\"$0\"", fifo]
      ])

    receive do
      {^port, {:exit_status, status}} -> status
    end
  end

  # Waits until a process of the runner's reads a file raw, inside the start's limit, a
  # limit's time at most.
  defp reading_raw, do: reading_raw(System.monotonic_time(:millisecond) + @idle + @poll)

  defp reading_raw(until),
    do: raw_found(Enum.any?(Process.list(), &raw_reader?/1), until)

  defp raw_found(true, _until), do: :ok

  defp raw_found(false, until),
    do: raw_waited(System.monotonic_time(:millisecond) < until, until)

  defp raw_waited(true, until), do: reading_raw(until)
  defp raw_waited(false, _until), do: flunk("no process of the runner's read the file raw")

  defp raw_reader?(pid), do: frames_read(Process.info(pid, :current_stacktrace))

  defp frames_read({:current_stacktrace, frames}),
    do: Enum.any?(frames, &match?({Logex.Runner.Writer, _, _, _}, &1))

  defp frames_read(nil), do: false

  defp start_refused(opts) do
    Runner.start_link(opts)
  rescue
    error in ArgumentError -> error.message
  end

  defp timed(fun) do
    {us, result} = :timer.tc(fun)
    {div(us, 1000), result}
  end

  # A call that does not hang answers within a few of its limits; one that hangs, as every
  # call did on a stalled disk before decision 353, never does.
  @answers 4 * (@idle + @poll)

  describe "a stalled disk (decision 353)" do
    test "a force whose write does not end within its limit is {:error, {:forces, :timeout}}, " <>
           "nothing forced, and the runner answers on",
         %{tmp_dir: dir} do
      rig = rig(dir)
      {:ok, runner} = Runner.start_link(rig.opts)
      assert Runner.force(runner, "level", 7) == :ok
      server = held()

      {took, answer} = timed(fn -> Runner.force(runner, "eye_1", 1) end)
      assert answer == {:error, {:forces, :timeout}}
      assert took >= @idle + @poll and took < @answers

      # The write past its limit was killed, its call of the file system left to the disk:
      # nothing that waits on the file server is alive to write on once the disk is back.
      assert {:messages, [_ | _] = waiting} = Process.info(server, :messages)
      refute Enum.any?(waiting, &caller_alive?/1)

      assert %{status: :running, forces: %{"level" => 7}} = Runner.status(runner)
      eye(rig, 0)
      assert Sim.outputs(rig.panel) == %{[0] => 0}

      # The disk back, the next force writes the whole set.
      :sys.resume(server)
      assert Runner.force(runner, "eye_1", 1) == :ok
      assert File.read!(rig.forces) == "eye_1 1\nlevel 7\n"
      assert Runner.stop(runner) == :ok
    end

    test "a trip's write is reported :timeout, and status/1, restart/2 and stop/2 answer",
         %{tmp_dir: dir} do
      rig = rig(dir)
      {:ok, runner} = Runner.start_link(rig.opts)
      :ok = Runner.subscribe(runner)
      eye(rig, 1)
      eye(rig, 0)
      written = File.read!(rig.store)
      server = held()

      # The panel's notice trips the runner as it next runs; the trip's write, after the
      # zeros, waits its limit on the disk and is reported.
      Sim.fail(rig.panel, :read, {:error, :eio})
      Manual.advance(rig.clock, 10)
      assert_receive {Runner, ^runner, {:trip, {:io, "panel", {:error, :eio}}}}, @answers
      assert_receive {Runner, ^runner, {:retain, {:error, :timeout}}}, @answers
      assert %{status: :tripped, retain: %{failed: :timeout}} = Runner.status(runner)
      assert Sim.outputs(rig.panel) == %{[0] => 0}

      # A cold restart writes the store first, and its write times out as the trip's did.
      {took, answer} = timed(fn -> Runner.restart(runner, :cold) end)
      assert answer == {:error, {:retain, :timeout}}
      assert took < @answers
      assert %{status: :tripped} = Runner.status(runner)

      # The stop's write times out too, and the stop says so, the runner gone.
      {took, answer} = timed(fn -> Runner.stop(runner) end)
      assert answer == {:error, {:retain, :timeout}}
      assert took < @answers
      refute Process.alive?(runner)

      # The disk back, the trip's write, killed in its rename, whole and synced by then,
      # lands, the store the new write, never a mix; the cold restart's and the stop's
      # found it at the `.tmp` and waited behind it in their deletes, writing nothing.
      :sys.resume(server)
      text = File.read!(rig.store)
      assert text != written
      assert text =~ "t1.boxes.cv dint 1\n"
      refute File.exists?(rig.store <> ".tmp")
    end

    test "a runner killed while its own write waits on the disk takes the write down with " <>
           "it, which does nothing after the call it was in, and the next runner's write stands",
         %{tmp_dir: dir} do
      rig = rig(dir, forces: nil)
      {:ok, runner} = Runner.start_link(rig.opts)
      Process.unlink(runner)
      eye(rig, 1)
      eye(rig, 0)
      written = File.read!(rig.store)

      # A leftover at the store's `.tmp`, so that the trip's write, past its raw open,
      # waits on the held disk in its delete of it; the runner is killed meanwhile, its
      # files free for the next runner at once (decision 356). The write, linked to it,
      # goes down with it, while the disk still holds its delete.
      File.write!(rig.store <> ".tmp", "leftover\n")
      server = held()
      Sim.fail(rig.panel, :read, {:error, :eio})
      Manual.advance(rig.clock, 10)
      writer = waiting_call(server, :delete)
      ref = Process.monitor(writer)
      Process.exit(runner, :kill)
      assert_receive {:DOWN, ^ref, :process, ^writer, _reason}, @answers

      # The disk back, the killed write's delete lands and nothing after it: the store is
      # as it was, where a write left alive would go on to make its file and rename it,
      # into the next runner's write. The next runner's cold start writes its own.
      :sys.resume(server)
      assert File.read!(rig.store) == written
      refute File.exists?(rig.store <> ".tmp")
      next = rig(dir, forces: nil, start: :cold)
      {:ok, again} = Runner.start_link(next.opts)
      assert %{status: :running, retain: %{failed: nil}} = Runner.status(again)
      assert File.read!(rig.store) =~ "t1.boxes.cv dint 0\n"
      refute File.exists?(rig.store <> ".tmp")
      assert Runner.stop(again) == :ok
    end

    test "a write's exit, its process linked to the runner, is taken with its answer, and " <>
           "never reaches the runner as a message of its own",
         %{tmp_dir: dir} do
      rig = rig(dir)
      {:ok, runner} = Runner.start_link(rig.opts)
      :erlang.trace_pattern({Runner, :handle_info, 2}, true, [:local])
      on_exit(fn -> :erlang.trace_pattern({Runner, :handle_info, 2}, false, [:local]) end)
      :erlang.trace(runner, true, [:call])
      assert Runner.force(runner, "level", 7) == :ok
      assert Runner.unforce(runner, "level") == :ok
      assert %{status: :running} = Runner.status(runner)
      :erlang.trace(runner, false, [:call])
      refute_received {:trace, ^runner, :call, {Runner, :handle_info, [{:EXIT, _, _}, _]}}
      assert Runner.stop(runner) == :ok
    end

    test "a restart whose forces file's read does not end within its limit is " <>
           "{:error, {:forces, :timeout}}, the runner tripped as it was",
         %{tmp_dir: dir} do
      rig = rig(dir)
      {:ok, runner} = Runner.start_link(rig.opts)
      assert Runner.force(runner, "level", 7) == :ok
      Sim.fail(rig.panel, :read, {:error, :eio})
      Manual.advance(rig.clock, 10)
      assert %{status: :tripped, trip: trip} = Runner.status(runner)

      # The forces file a FIFO, whose read waits for a writer that never comes.
      File.rm!(rig.forces)
      {_, 0} = System.cmd("mkfifo", [rig.forces])
      {took, answer} = timed(fn -> Runner.restart(runner, :warm) end)
      assert answer == {:error, {:forces, :timeout}}
      assert took >= @idle + @poll and took < @answers
      assert %{status: :tripped, trip: ^trip, forces: %{"level" => 7}} = Runner.status(runner)

      # The killed read's call let go, and the file back, the restart restarts.
      {:ok, pipe} = :file.open(rig.forces, [:write, :raw])
      :ok = :file.close(pipe)
      File.rm!(rig.forces)
      File.write!(rig.forces, "level 7\n")
      assert Runner.restart(runner, :warm) == :ok
      assert Runner.stop(runner) == :ok
    end

    test "a start whose forces file's read does not end within its limit is refused, " <>
           "naming the file, and every other file call answers meanwhile",
         %{tmp_dir: dir} do
      rig = rig(dir)
      {_, 0} = System.cmd("mkfifo", [rig.forces])
      on_exit(fn -> let_go(rig.forces) end)

      # The read raw, off the VM's file server, so that another process's file call, made
      # while the start waits on the FIFO, answers, where a read through the server held
      # it and every other file call of the VM's for as long as the FIFO had no writer.
      start = Task.async(fn -> timed(fn -> start_refused(rig.opts) end) end)
      reading_raw()
      other = Path.join(dir, "other")

      call =
        Task.async(fn ->
          File.write!(other, "answered\n")
          File.read!(other)
        end)

      assert Task.yield(call, @answers) == {:ok, "answered\n"}
      assert Task.yield(start, 0) == nil
      {took, refused} = Task.await(start, 2 * @answers)

      assert refused ==
               "#{rig.forces}: the forces file cannot be read: the disk did not answer within " <>
                 "the idle watchdog and a poll period"

      assert took >= @idle + @poll and took < @answers

      # The killed read's call let go, and the file gone, the start starts.
      let_go(rig.forces)
      File.rm!(rig.forces)
      {:ok, runner} = Runner.start_link(rig.opts)
      assert Runner.stop(runner) == :ok
    end

    test "a cold restart's write is {:error, {:retain, :timeout}}, the runner tripped as it " <>
           "was, and a warm one, which writes nothing, restarts",
         %{tmp_dir: dir} do
      rig = rig(dir, forces: nil)
      {:ok, runner} = Runner.start_link(rig.opts)
      :ok = Runner.subscribe(runner)
      eye(rig, 1)
      Sim.fail(rig.panel, :read, {:error, :eio})
      Manual.advance(rig.clock, 10)
      assert %{status: :tripped, trip: trip} = Runner.status(runner)
      server = held()

      {took, answer} = timed(fn -> Runner.restart(runner, :cold) end)
      assert answer == {:error, {:retain, :timeout}}
      assert took < @answers
      assert %{status: :tripped, trip: ^trip, retain: %{failed: :timeout}} = Runner.status(runner)
      assert Sim.outputs(rig.panel) == %{[0] => 0}

      assert Runner.restart(runner, :warm) == :ok
      assert %{status: :running} = Runner.status(runner)
      assert Runner.get!(runner, "t1.boxes.cv") == 1

      :sys.resume(server)
      assert Runner.stop(runner) == :ok
    end

    test "a period's write that does not end within its limit is reported :timeout, and " <>
           "its answer, the disk back, taken",
         %{tmp_dir: dir} do
      rig = rig(dir, retain_period: 100)
      {:ok, runner} = Runner.start_link(rig.opts)
      :ok = Runner.subscribe(runner, [:retain])
      eye(rig, 1)
      server = held()

      # The period's write at 100 waits on the disk past its limit: reported, the plant
      # running on, where nothing told it while the writer waited for ever.
      {took, _} =
        timed(fn ->
          Manual.advance(rig.clock, 100)
          assert_receive {Runner, ^runner, {:retain, {:error, :timeout}}}, @answers
        end)

      assert took >= @idle + @poll
      assert %{status: :running, retain: %{failed: :timeout}} = Runner.status(runner)
      eye(rig, 0)
      eye(rig, 1)
      assert Runner.get!(runner, "t1.boxes.cv") == 2

      # The disk back, the late write lands and its answer is taken, the failure cleared;
      # the next period's write then writes the newest.
      :sys.resume(server)
      assert %{retain: %{failed: nil}} = written(runner)
      Manual.advance(rig.clock, 100)
      period_settled(runner)
      assert File.read!(rig.store) =~ "t1.boxes.cv dint 2\n"
      refute_received {Runner, ^runner, {:retain, {:error, _}}}
      assert Runner.stop(runner) == :ok
    end

    test "a stop waits on a period's write in progress and on its own each within its limit",
         %{tmp_dir: dir} do
      rig = rig(dir, retain_period: 100)
      {:ok, runner} = Runner.start_link(rig.opts)
      eye(rig, 1)
      server = held()

      # The period's write at 100 waits on the disk; the plant runs on meanwhile.
      Manual.advance(rig.clock, 100)
      eye(rig, 0)
      eye(rig, 1)
      assert Runner.get!(runner, "t1.boxes.cv") == 2

      {took, answer} = timed(fn -> Runner.stop(runner) end)
      assert answer == {:error, {:retain, :timeout}}
      assert took >= 2 * (@idle + @poll) and took < 2 * @answers
      assert Sim.closed?(rig.panel)
      :sys.resume(server)
    end

    test "a fresh start's write, start: :cold, is {:error, {:retain, :timeout}}, nothing " <>
           "started",
         %{tmp_dir: dir} do
      rig = rig(dir, forces: nil, start: :cold)
      server = held()
      {took, answer} = timed(fn -> Runner.start_link(rig.opts) end)
      assert answer == {:error, {:retain, :timeout}}
      assert took < @answers
      assert Sim.reads(rig.panel) == 0
      :sys.resume(server)
    end
  end

  describe "each write's `.tmp` its own (M10)" do
    # A write killed inside a call of the file system runs that call on after the kill;
    # here the test's own open of a file at the store's `.tmp` stands in for such a
    # write's, its descriptor still open on it. The runner's next write deletes it first
    # and writes a file of its own, so the late write lands in a file no name reaches,
    # never in the store; with one `.tmp` written through again it was the store's own.
    # c1-runner-rounds-10: a stop that names itself to the runner once its stoppers are
    # taken, while another stop's write waits on the disk, is ended by that stop's
    # `{:shutdown, term}`, an orderly end, which answers it `:ok`.
    test "a stop made while another's write waits on the disk, ended by that stop's " <>
           "orderly reason, answers :ok, and one ended by a kill raises",
         %{tmp_dir: dir} do
      for ending <- [:normal, :shutdown, {:shutdown, :end_of_shift}, :killed] do
        rig =
          rig(Path.join(dir, "#{System.unique_integer([:positive])}"), forces: nil, idle: 5000)

        File.mkdir_p!(Path.dirname(rig.store))
        {:ok, runner} = Runner.start_link(rig.opts)
        Process.unlink(runner)
        eye(rig, 1)
        server = held()
        stop = Task.async(fn -> stop_answer(runner, reason_of(ending)) end)
        waiting_call(server, :rename)
        second = Task.async(fn -> stop_answer(runner, :normal) end)
        terminate_waiting(runner)
        ended(ending, runner)
        :sys.resume(server)

        assert {Task.await(stop, 2 * @answers), Task.await(second, 2 * @answers)} ==
                 answers(ending, runner)

        refute Process.alive?(runner)
      end
    end

    test "a write's late call into an earlier `.tmp` never reaches the store",
         %{tmp_dir: dir} do
      for write <- [:stop, :trip] do
        rig = rig(Path.join(dir, "#{write}"), forces: nil)
        File.mkdir_p!(Path.dirname(rig.store))
        {:ok, runner} = Runner.start_link(rig.opts)
        eye(rig, 1)
        File.write!(rig.store <> ".tmp", "logex retain 1\n")
        {:ok, late} = :file.open(rig.store <> ".tmp", [:read, :write, :raw, :binary])
        eye(rig, 0)
        eye(rig, 1)
        written(write, rig, runner)
        :ok = :file.pwrite(late, 0, "junk junk junk junk junk junk junk junk\n")
        :ok = :file.close(late)

        text = File.read!(rig.store)
        assert text =~ ~r/\Alogex retain 1\nconfiguration plant written /
        assert text =~ "t1.boxes.cv dint 2\n"
        refute text =~ "junk"
        refute File.exists?(rig.store <> ".tmp")
        stopped(write, runner)
      end
    end

    # Whatever stands at the `.tmp` is deleted, never written through: a link there no
    # longer carries the store's text to the file it names.
    test "a link at the store's `.tmp` is removed, the file it names untouched",
         %{tmp_dir: dir} do
      rig = rig(dir, forces: nil)
      {:ok, runner} = Runner.start_link(rig.opts)
      victim = Path.join(dir, "victim")
      File.write!(victim, "kept\n")
      File.ln_s!(victim, rig.store <> ".tmp")
      eye(rig, 1)
      assert Runner.stop(runner) == :ok
      assert File.read!(victim) == "kept\n"
      assert File.read!(rig.store) =~ "t1.boxes.cv dint 1\n"
      refute File.exists?(rig.store <> ".tmp")
    end
  end

  # The write the test's late call races: a stop's, or a trip's, the runner then stopped
  # once the store has been read.
  defp written(:stop, _rig, runner), do: assert(Runner.stop(runner) == :ok)

  defp written(:trip, rig, runner) do
    Sim.fail(rig.panel, :read, {:error, :eio})
    Manual.advance(rig.clock, 10)
    assert %{status: :tripped, retain: %{failed: nil}} = Runner.status(runner)
  end

  defp stopped(:stop, _runner), do: :ok
  defp stopped(:trip, runner), do: assert(Runner.stop(runner) == :ok)
end
