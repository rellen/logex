defmodule Logex.StalledDiskTest do
  @moduledoc """
  Decision 353 (RV-4): every file write the runner makes, a force's of the forces file and
  the store's at a trip, a stop, a cold restart and a fresh start, is limited to the
  runner's write limit of real time, as the period's write is where the runner waits on it
  (decision 275), and so is the forces file's read at a restart, the limit since decision
  400 (RV-11) its `write_limit:`, where it was the idle watchdog and a poll period: one
  past it fails, a
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
  alias Logex.Runner.Paths

  # The manual clock, whose every reading takes the milliseconds an agent holds, none
  # until the test sets some: so that a request's own work takes time once it does.
  defmodule Ticking do
    @behaviour Logex.Runner.Clock

    @impl true
    def now_ms({clock, ticks}) do
      Manual.pass(clock, Agent.get(ticks, & &1))
      Manual.now_ms(clock)
    end

    @impl true
    def wake_at({clock, _ticks}, pid, message, at), do: Manual.wake_at(clock, pid, message, at)

    @impl true
    def cancel({clock, _ticks}, timer), do: Manual.cancel(clock, timer)
  end

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

  # Every write's limit, the runner's `write_limit:`: 1010 ms of real time, the idle
  # watchdog and a poll period this file gave every runner for it before decision 400
  # (RV-11) gave the limit an option of its own, which these runners are given now. At 110
  # ms a write the disk was free for, a fresh start's or a stop's, missed its limit on a
  # loaded machine beside another suite's syncs in four runs of six, and at 510 ms a
  # force's once in fifty (scripts/load.sh); a stalled write fails at any limit, which only
  # the time the test takes reads.
  @limit 1010
  @poll 10

  # The plant with an event task on the panel's `e`, a trigger, its tally's lamp at no
  # device.
  @kicked """
  task fast interval 10 priority 1
  task kick single e priority 0
  var_global eye_1 bool at panel.i.0
  var_global level dint at panel.i.1
  var_global e bool at panel.i.2
  var_global lamp_q bool at panel.q.0
  var_global seen bool
  var_global retain total dint 0

  program t1 tally with fast
    t1.eye eye_1
    t1.lamp lamp_q

  program k tally with kick
    k.eye e
    k.lamp seen
  """

  defp configured(plant \\ @plant) do
    {:ok, tally} = Logex.compile(@tally, name: "tally")
    {:ok, config} = Configuration.compile("plant", plant, %{"tally" => tally})
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
          write_limit: @limit,
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

  # The runner's own force's write once its rename waits in the held file server, its
  # process read from the runner, so that a rename an earlier test's killed write left in
  # the server's mailbox, which a resume had not yet served when this test held it again,
  # is never taken for it (the review of RV-16: the first mutation table met one).
  defp renaming(server, runner), do: renaming_of(:sys.get_state(runner).writing, server, runner)

  defp renaming_of(%{write: {writer, _ref}}, server, runner),
    do:
      renamed_by(
        writer in callers(Process.info(server, :messages), :rename),
        writer,
        server,
        runner
      )

  defp renaming_of(nil, server, runner), do: renamed_by(false, nil, server, runner)

  defp renamed_by(true, writer, _server, _runner), do: writer

  defp renamed_by(false, _writer, server, runner) do
    Process.sleep(1)
    renaming(server, runner)
  end

  # A call of `kind` waiting in the held file server, `{:called, pid}`, or `:answered`
  # where the task it was awaited from ended first, its write killed at its limit before
  # it made the call.
  defp called_or_answered(server, kind, task),
    do: called_or_ended(callers(Process.info(server, :messages), kind), server, kind, task)

  defp callers({:messages, messages}, kind),
    do: for({:"$gen_call", {pid, _}, request} <- messages, elem(request, 0) == kind, do: pid)

  defp called_or_ended([pid | _], _server, _kind, _task), do: {:called, pid}

  defp called_or_ended([], server, kind, task),
    do: ended_or_waiting(Process.alive?(task.pid), server, kind, task)

  defp ended_or_waiting(false, _server, _kind, _task), do: :answered
  defp ended_or_waiting(true, server, kind, task), do: called_or_answered(server, kind, task)

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

  # Decision 391 (RV-11), the leave for a timed-out write reported failed: the write past
  # its limit is unknown until its answer is taken, where it was `failed: :timeout`; and
  # decision 440 (RV-16), the leave for the key absent: `unknown` always there, nil once
  # the answer is taken.
  defp written_status(%{retain: %{unknown: nil}} = status, _runner), do: status
  defp written_status(_unknown, runner), do: written(runner)

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
  defp reading_raw, do: reading_raw(System.monotonic_time(:millisecond) + @limit)

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
  @answers 4 * @limit

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
      assert took >= @limit and took < @answers

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
      # Decision 391 (RV-11), the leave for a timed-out write reported failed: unknown, the
      # store as the host spelled it, `failed` nil, where it was `failed: :timeout`.
      assert %{status: :tripped, retain: %{failed: nil, unknown: store}} = Runner.status(runner)
      assert store == rig.store
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

    # Decision 390 (RV-11), the leave for a restart answered `{:error, {:forces,
    # :timeout}}`: the read past its limit keeps the forces the runner holds and the
    # restart goes on, the line back, the file it could not read named in status/1, where
    # the restart answered `{:error, {:forces, :timeout}}` and left the runner tripped.
    test "a restart whose forces file's read does not end within its limit keeps the " <>
           "forces it holds and goes on, naming the file (decision 390)",
         %{tmp_dir: dir} do
      rig = rig(dir)
      {:ok, runner} = Runner.start_link(rig.opts)
      assert Runner.force(runner, "level", 7) == :ok
      Sim.fail(rig.panel, :read, {:error, :eio})
      Manual.advance(rig.clock, 10)
      assert %{status: :tripped} = Runner.status(runner)

      # The forces file a FIFO, whose read waits for a writer that never comes.
      File.rm!(rig.forces)
      {_, 0} = System.cmd("mkfifo", [rig.forces])
      {took, answer} = timed(fn -> Runner.restart(runner, :warm) end)
      assert answer == :ok
      assert took >= @limit and took < @answers

      assert %{
               status: :running,
               trip: nil,
               forces: %{"level" => 7},
               forces_unread: {forces, :timeout}
             } = Runner.status(runner)

      assert forces == rig.forces
      assert Runner.get!(runner, "level") == 7

      # The killed read's call let go, and the file back, the next force's write lands and
      # the file is named no more.
      {:ok, pipe} = :file.open(rig.forces, [:write, :raw])
      :ok = :file.close(pipe)
      File.rm!(rig.forces)
      assert Runner.force(runner, "eye_1", 1) == :ok
      assert File.read!(rig.forces) == "eye_1 1\nlevel 7\n"
      # Decision 440 (RV-16), the leave for the key absent: always there, nil.
      assert Runner.status(runner).forces_unread == nil
      assert Runner.stop(runner) == :ok
    end

    # Decision 390 (RV-11), the leave for a fresh start refused when the forces file cannot
    # be read: the read past its limit starts the runner with no force, the file named in
    # status/1, where the start was refused, an ArgumentError naming the file. The runner
    # keeps no store (RV-7's review): the test's write limit, short so that the FIFO's read
    # ends soon, held the start's write of a store to it too, which on the loaded machine
    # of that review's ten suites took past it once, `{:error, {:retain, :timeout}}` at
    # 2037 ms, the forces read's 1010 and the write's own, where the test is of the forces
    # file alone. So the first file the start reads raw is the FIFO, which the call waits
    # for: up to the test's own wait, `@answers`, since a loaded machine took the start past
    # a limit's time before it, twice in 30 runs under the busy loops, where the store's
    # read, raw too, came first and was taken for the FIFO's.
    test "a start whose forces file's read does not end within its limit starts with no " <>
           "force, naming the file, and every other file call answers meanwhile (decision 390)",
         %{tmp_dir: dir} do
      rig = rig(dir, retain: nil, retain_period: nil)
      {_, 0} = System.cmd("mkfifo", [rig.forces])
      on_exit(fn -> let_go(rig.forces) end)

      # The read raw, off the VM's file server, so that another process's file call, made
      # while the start waits on the FIFO, answers, where a read through the server held
      # it and every other file call of the VM's for as long as the FIFO had no writer. The
      # start is the test's own, so that the runner it starts is its child.
      other = Path.join(dir, "other")

      call =
        Task.async(fn ->
          reading_raw(System.monotonic_time(:millisecond) + @answers)
          File.write!(other, "answered\n")
          {File.read!(other), System.monotonic_time(:millisecond)}
        end)

      {took, {:ok, runner}} = timed(fn -> Runner.start_link(rig.opts) end)
      started = System.monotonic_time(:millisecond)
      assert {"answered\n", answered} = Task.await(call, @answers)
      assert answered < started
      assert took >= @limit and took < @answers

      assert %{status: :running, forces: forces, forces_unread: {file, :timeout}} =
               Runner.status(runner)

      assert forces == %{} and file == rig.forces
      assert Runner.stop(runner) == :ok

      # The killed read's call let go, and the file gone, the start starts with none and
      # names no file.
      let_go(rig.forces)
      File.rm!(rig.forces)
      {:ok, runner} = Runner.start_link(rig.opts)
      # Decision 440 (RV-16), the leave for the key absent: always there, nil.
      assert Runner.status(runner).forces_unread == nil
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
      # Decision 391 (RV-11): unknown, where it was `failed: :timeout`.
      assert %{status: :tripped, trip: ^trip, retain: %{failed: nil, unknown: store}} =
               Runner.status(runner)

      assert store == rig.store
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

      assert took >= @limit
      # Decision 391 (RV-11): unknown, where it was `failed: :timeout`.
      assert %{status: :running, retain: %{failed: nil, unknown: store}} = Runner.status(runner)
      assert store == rig.store
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
      assert took >= 2 * @limit and took < 2 * @answers
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

  # RV-5: the store's read at a fresh start raw and limited as the forces file's is
  # (decision 415), and decision 360's copy of a store the start dropped from a write as
  # every other, limited the same, its failure reported and the start going on.
  describe "a fresh start's store on a stalled disk (RV-5, decision 360)" do
    test "a start whose store's read does not end within its limit is refused, naming the " <>
           "file, and every other file call answers meanwhile",
         %{tmp_dir: dir} do
      rig = rig(dir, forces: nil)
      {_, 0} = System.cmd("mkfifo", [rig.store])
      on_exit(fn -> let_go(rig.store) end)

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
               "#{rig.store}: the store cannot be read: the disk did not answer within the " <>
                 "write limit, 1010 ms (write_limit:)"

      assert took >= @limit and took < @answers
      assert Sim.reads(rig.panel) == 0

      let_go(rig.store)
      File.rm!(rig.store)
      {:ok, runner} = Runner.start_link(rig.opts)
      assert Runner.stop(runner) == :ok
    end

    test "a start's copy of a store it dropped from that does not end within its limit is " <>
           "reported :timeout, and the start goes on",
         %{tmp_dir: dir} do
      rig = rig(dir, forces: nil)
      {:ok, runner} = Runner.start_link(rig.opts)
      eye(rig, 1)
      assert Runner.stop(runner) == :ok
      read = File.read!(rig.store)

      {:ok, retyped} =
        Logex.compile(String.replace(@tally, "boxes ctu", "boxes ctu_int"), name: "tally")

      {:ok, config} = Configuration.compile("plant", @plant, %{"tally" => retyped})
      next = rig(dir, forces: nil, configuration: config)

      # The store read raw, off the held server; the copy's rename through it held.
      server = held()
      {took, {:ok, runner}} = timed(fn -> Runner.start_link(next.opts) end)
      assert took >= @limit and took < @answers

      # Decision 391 (RV-11): the copy unknown, its path, where it was `failed: :timeout`.
      assert %{
               status: :running,
               retain: %{failed: nil, unknown: copy, copy: nil, dropped: [_drop]}
             } =
               Runner.status(runner)

      # Decision 418 (RV-13), the leave for the one `.dropped`: the copy's own number,
      # `.dropped.1`, the first.
      assert copy == rig.store <> ".dropped.1"

      # The killed copy's rename may land once the disk answers, the copy whole; the store
      # is as the start read it until its first write, which since RV-5's review makes the
      # copy owed first, the stop's here, since decision 418 under the next number past
      # the killed copy where that landed, none replaced, and since decision 456 (RV-6)
      # none where it landed, the same bytes: the copy that landed is the one made.
      :sys.resume(server)
      assert File.read!(rig.store) == read
      landed = File.read(copy)
      assert landed in [{:ok, read}, {:error, :enoent}]
      assert Runner.stop(runner) == :ok
      owed = owed_copy(landed, rig.store)
      assert File.read!(owed) == read
      assert File.read(copy) == {:ok, read}
      refute File.exists?(rig.store <> ".dropped.2")
      refute File.read!(rig.store) == read
    end

    # RV-5's review: the look at each file for a symbolic link, made raw in the start's
    # caller with no limit, held the caller as long as a stalled disk held it, the store's
    # and the forces file's reads limited after it. Every call a fresh start makes on its
    # files is now made in a process of its own, limited, none in the caller: a raw call
    # goes past the file server, so the caller's own calls are traced, every function of
    # `:file`, through a start that reads a forces file and a store and copies it, each
    # named by an absolute path, which `Path.expand/1` resolves without the directory the
    # start is made in.
    test "no file call of a fresh start is made in its caller", %{tmp_dir: dir} do
      # A write limit of 5,000 ms, which covers a loaded machine's disk: the test reads no
      # limit (decision 400, where an idle watchdog of 5,000 stood for it, RV-4's question
      # 12).
      rig = rig(dir, write_limit: 5000)
      {:ok, runner} = Runner.start_link(rig.opts)
      eye(rig, 1)
      assert Runner.force(runner, "level", 7) == :ok
      assert Runner.stop(runner) == :ok

      {:ok, retyped} =
        Logex.compile(String.replace(@tally, "boxes ctu", "boxes ctu_int"), name: "tally")

      {:ok, config} = Configuration.compile("plant", @plant, %{"tally" => retyped})
      next = rig(dir, configuration: config, write_limit: 5000)
      assert :erlang.trace_pattern({:file, :_, :_}, true, [:local]) > 0
      {caller, started} = traced_start(next.opts)
      :erlang.trace_pattern({:file, :_, :_}, false, [:local])
      assert {:ok, runner} = started

      assert %{forces: %{"level" => 7}, retain: %{copy: copy, dropped: [_drop]}} =
               Runner.status(runner)

      assert File.exists?(copy)
      assert traced_calls(caller) == []
      assert Runner.stop(runner) == :ok
      send(caller, :done)
    end
  end

  # Decision 418: the copy a stop made of a copy owed, past one that landed late; since
  # decision 456 (RV-6), the leave for the next number past it, the one that landed, the
  # same bytes as the store the start read, so that no copy the same as the last is made.
  defp owed_copy({:ok, _read}, store), do: store <> ".dropped.1"
  defp owed_copy({:error, :enoent}, store), do: store <> ".dropped.1"

  # Decision 456 (RV-6): an owed copy over a killed one that landed, the same bytes, makes
  # no write of its own, so the first rename the held server takes is the store's; over
  # one that did not land it is written, its rename let through first.
  defp copy_let_through({:ok, _read}, _server, _restart), do: :ok

  defp copy_let_through({:error, :enoent}, server, restart) do
    assert {:called, _copying} = called_or_answered(server, :rename, restart)
    :sys.resume(server)
    :sys.suspend(server)
  end

  # The VM's file server held for `ms` of real time and then let go, as a disk slow over a
  # write, healthy, is.
  defp held_for(ms) do
    server = held()

    spawn(fn ->
      Process.sleep(ms)
      :sys.resume(server)
    end)

    server
  end

  # Decision 391 (RV-11): a write past its limit may still land once the disk answers, the
  # file the old or the new, so status/1 names it unknown, neither failed nor written,
  # until a later write lands or fails: the store's and its copy's under `retain`, a
  # force's as the set it held.
  describe "a write past its limit is unknown until a later one lands (decision 391)" do
    test "the store's: unknown until a later write lands, or fails", %{tmp_dir: dir} do
      rig = rig(dir, forces: nil)
      {:ok, runner} = Runner.start_link(rig.opts)
      eye(rig, 1)
      %{retain: %{written_at: started}} = Runner.status(runner)
      server = held()

      # A trip's write past its limit: unknown, the last write known made its age.
      Sim.fail(rig.panel, :read, {:error, :eio})
      Manual.advance(rig.clock, 10)

      assert %{status: :tripped, retain: %{unknown: store, failed: nil, written_at: ^started}} =
               written_or_unknown(runner)

      assert store == rig.store

      # The disk back, a cold restart's write lands: unknown no more.
      :sys.resume(server)
      assert Runner.restart(runner, :cold) == :ok
      retain = Runner.status(runner).retain
      # Decision 440 (RV-16), the leave for the key absent: always there, nil.
      assert retain.unknown == nil
      assert retain.failed == nil

      # Past its limit again, a trip's; then a write that fails, the store's `.tmp` a
      # directory, a stop's: failed, known, unknown no more.
      eye(rig, 1)
      server = held()
      Sim.fail(rig.panel, :read, {:error, :eio})
      Manual.advance(rig.clock, 10)
      # Decision 440 (RV-16): the key always there, so its file named.
      assert %{retain: %{unknown: unknown}} = written_or_unknown(runner)
      assert unknown == rig.store
      :sys.resume(server)
      wait_for_tmp_gone(rig.store <> ".tmp")
      File.mkdir!(rig.store <> ".tmp")
      assert {:ok, %{retain: retain}} = {:ok, Runner.status(runner)}
      # Decision 440 (RV-16): the key always there, so its file named.
      assert retain.unknown == rig.store
      assert Runner.restart(runner, :cold) == {:error, {:retain, :eisdir}}
      retain = Runner.status(runner).retain
      assert retain.failed == :eisdir
      # Decision 440 (RV-16), the leave for the key absent: always there, nil.
      assert retain.unknown == nil
      File.rmdir!(rig.store <> ".tmp")
      assert Runner.stop(runner) == :ok
    end

    # Decision 502 (RV-19): a restart's read no longer makes the set known, the cut write
    # that held it able to land after the read; the name was "... lands, fails or a
    # restart reads it", and the restart's last assertion read it nil.
    test "a force's: the set it held unknown until a later write of the file lands or " <>
           "fails, a restart's read leaving it so",
         %{tmp_dir: dir} do
      rig = rig(dir, retain: nil, retain_period: nil)
      {:ok, runner} = Runner.start_link(rig.opts)
      assert Runner.force(runner, "level", 7) == :ok
      # Decision 440 (RV-16), the leave for the key absent: always there, nil.
      assert Runner.status(runner).forces_unknown == nil
      server = held()

      assert Runner.force(runner, "eye_1", 1) == {:error, {:forces, :timeout}}

      assert %{forces: %{"level" => 7}, forces_unknown: %{"eye_1" => 1, "level" => 7}} =
               Runner.status(runner)

      # The disk back, the killed write may land: the file the old set or the new.
      :sys.resume(server)
      wait_for_tmp_gone(rig.forces <> ".tmp")
      assert File.read!(rig.forces) in ["level 7\n", "eye_1 1\nlevel 7\n"]

      # A later write that lands: known, the runner's set.
      assert Runner.unforce(runner, "eye_1") == :ok
      assert File.read!(rig.forces) == "level 7\n"
      # Decision 440 (RV-16), the leave for the key absent: always there, nil.
      assert Runner.status(runner).forces_unknown == nil

      # Past its limit again; then one that fails, a directory at the `.tmp`: known.
      server = held()
      assert Runner.force(runner, "eye_1", 1) == {:error, {:forces, :timeout}}
      assert %{forces_unknown: %{"eye_1" => 1}} = Runner.status(runner)
      :sys.resume(server)
      wait_for_tmp_gone(rig.forces <> ".tmp")
      File.mkdir!(rig.forces <> ".tmp")
      assert Runner.force(runner, "eye_1", 1) == {:error, {:forces, :eisdir}}
      # Decision 440 (RV-16), the leave for the key absent: always there, nil.
      assert Runner.status(runner).forces_unknown == nil
      File.rmdir!(rig.forces <> ".tmp")

      # Past its limit once more; then a restart reads the file as it stands, and names the
      # set unknown still, the cut write able to land after its read (decision 502); a
      # later write that lands knows it.
      server = held()
      assert Runner.force(runner, "eye_1", 1) == {:error, {:forces, :timeout}}
      :sys.resume(server)
      wait_for_tmp_gone(rig.forces <> ".tmp")
      Sim.fail(rig.panel, :read, {:error, :eio})
      Manual.advance(rig.clock, 10)
      # Decision 440 (RV-16): the key always there, so the set it holds named.
      assert %{status: :tripped, forces_unknown: set} = Runner.status(runner)
      assert set == %{"eye_1" => 1, "level" => 7}
      assert Runner.restart(runner, :warm) == :ok
      status = Runner.status(runner)
      assert status.forces_unknown == %{"eye_1" => 1, "level" => 7}
      assert status.forces in [%{"level" => 7}, %{"eye_1" => 1, "level" => 7}]
      assert Runner.force(runner, "eye_1", 1) == :ok
      assert %{forces_unknown: nil, forces: %{"eye_1" => 1, "level" => 7}} = Runner.status(runner)
      assert Runner.stop(runner) == :ok
    end

    # RV-11's review: a restart whose read of the file fails knows no more of what it holds
    # than before (decision 390), so the set a write past its limit held stays unknown,
    # named beside the file the restart could not read, until a force's write lands.
    test "a force's set unknown is kept by a restart that cannot read the file, both named",
         %{tmp_dir: dir} do
      rig = rig(dir, retain: nil, retain_period: nil)
      forces = rig.forces
      {:ok, runner} = Runner.start_link(rig.opts)
      assert Runner.force(runner, "level", 7) == :ok
      server = held()
      assert Runner.force(runner, "eye_1", 1) == {:error, {:forces, :timeout}}
      :sys.resume(server)
      wait_for_tmp_gone(forces <> ".tmp")

      File.rm!(forces)
      File.mkdir!(forces)
      Sim.fail(rig.panel, :read, {:error, :eio})
      Manual.advance(rig.clock, 10)
      assert %{status: :tripped} = Runner.status(runner)
      assert Runner.restart(runner, :warm) == :ok

      assert %{
               status: :running,
               forces: %{"level" => 7},
               forces_unread: {^forces, :eisdir},
               forces_unknown: %{"eye_1" => 1, "level" => 7}
             } = Runner.status(runner)

      # A write that lands: both known.
      File.rmdir!(forces)
      assert Runner.unforce(runner, "eye_1") == :ok
      status = Runner.status(runner)
      # Decision 440 (RV-16), the leave for the key absent: always there, nil.
      assert status.forces_unread == nil
      # Decision 440 (RV-16), the leave for the key absent: always there, nil.
      assert status.forces_unknown == nil
      assert File.read!(forces) == "level 7\n"
      assert Runner.stop(runner) == :ok
    end

    # RV-11's review: a write over the store that owes the copy first (decision 360),
    # killed at its limit, names the file it was in as the limit passed: the copy, where
    # the copy's write was cut, the store as it was and the copy still owed, where it named
    # the store, which it never reached; and the store, where it was the store's, the copy
    # made (decision 447). Each is stalled at its rename, the one call of a write the held
    # file server takes: the copy's, and then, the copy's let through, the store's.
    test "an owed copy's: a write killed in the copy names the copy, and one killed in " <>
           "the store's write names the store, the copy made",
         %{tmp_dir: dir} do
      rig = rig(dir, forces: nil)
      {:ok, runner} = Runner.start_link(rig.opts)
      eye(rig, 1)
      assert Runner.stop(runner) == :ok
      read = File.read!(rig.store)
      # Decision 418 (RV-13), the leave for the one `.dropped`: the copy's own number, the
      # first, `.dropped.1`, written through the copies' one `.tmp`.
      copy = rig.store <> ".dropped.1"
      tmp = rig.store <> ".dropped.tmp"

      {:ok, retyped} =
        Logex.compile(String.replace(@tally, "boxes ctu", "boxes ctu_int"), name: "tally")

      {:ok, config} = Configuration.compile("plant", @plant, %{"tally" => retyped})
      next = rig(dir, forces: nil, configuration: config)
      File.mkdir!(tmp)
      {:ok, runner} = Runner.start_link(next.opts)
      assert %{retain: %{copy: nil, failed: :eisdir, written_at: started}} = Runner.status(runner)
      File.rmdir!(tmp)

      # A trip's write, killed in the copy's rename: the copy unknown, the store as the
      # start read it, its age the start's.
      server = held()
      Sim.fail(next.panel, :read, {:error, :eio})
      Manual.advance(next.clock, 10)

      assert %{
               status: :tripped,
               retain: %{unknown: ^copy, copy: nil, failed: nil, written_at: ^started}
             } = written_or_unknown(runner)

      :sys.resume(server)
      wait_for_tmp_gone(tmp)
      assert File.read!(rig.store) == read

      # A cold restart's, the copy still owed: the copy's rename let through and the
      # store's held, killed at the limit: the copy made, the store unknown. Since
      # decision 418 the copy is numbered past the killed one where that landed, none
      # replaced, and since decision 456 (RV-6) it is the killed one where that landed,
      # the same bytes, with no write of its own.
      landed = File.read(copy)
      made = owed_copy(landed, rig.store)
      server = held()
      restart = Task.async(fn -> Runner.restart(runner, :cold) end)
      copy_let_through(landed, server, restart)
      # The store's write killed at its limit in its rename, or, on a machine loaded past
      # the limit's 1,010 ms, in its raw calls before it, which tells the same: the store
      # unknown, the copy made. The wait ends either way, where it waited for a rename that
      # never came, once in fifty runs under load (the review of RV-13).
      _storing = called_or_answered(server, :rename, restart)
      assert Task.await(restart, @answers) == {:error, {:retain, :timeout}}

      assert %{status: :tripped, retain: %{unknown: store, copy: ^made, failed: nil}} =
               Runner.status(runner)

      assert store == rig.store
      assert :file.read_file(made, [:raw]) == {:ok, read}
      :sys.resume(server)
      wait_for_tmp_gone(rig.store <> ".tmp")
      assert Runner.stop(runner) == :ok
    end
  end

  # Decision 418 (RV-13): each copy a name of its own, numbered one past the highest that
  # stands as it begins, and not renamed over a file that stands at its number as it
  # looks, raw, just before its rename: one a host makes there while it is written, here
  # while the copy's write waits on the held file server in its delete of a leftover at
  # the copies' `.tmp`, after it read the directory and before that look, is left as it
  # is, the copy failing `:eexist` and owed, as decision 416 has a copy that cannot be
  # made, the start going on; the next write over the store makes it under the next number
  # past the host's file (decision 448: failed and owed, where it could take the next free
  # number at once). The test's name said "while it is written", which the review of
  # RV-13 found true only before the look (below).
  describe "a copy's number (decision 418)" do
    test "a file a host makes at the copy's number while it is written, before the copy " <>
           "looks at its name, is never replaced",
         %{tmp_dir: dir} do
      rig = rig(dir, forces: nil)
      {:ok, runner} = Runner.start_link(rig.opts)
      eye(rig, 1)
      assert Runner.stop(runner) == :ok
      read = File.read!(rig.store)

      {:ok, retyped} =
        Logex.compile(String.replace(@tally, "boxes ctu", "boxes ctu_int"), name: "tally")

      {:ok, config} = Configuration.compile("plant", @plant, %{"tally" => retyped})
      next = rig(dir, forces: nil, configuration: config)
      File.write!(rig.store <> ".dropped.tmp", "a leftover")
      server = held()

      start =
        Task.async(fn ->
          {:ok, runner} = Runner.start_link(next.opts)
          Process.unlink(runner)
          runner
        end)

      _copying = waiting_call(server, :delete)
      host = rig.store <> ".dropped.1"
      :ok = :file.write_file(host, "a host's file", [:raw])
      :sys.resume(server)
      runner = Task.await(start, @answers)

      assert %{status: :running, retain: %{copy: nil, failed: :eexist, dropped: [_drop]}} =
               Runner.status(runner)

      assert File.read!(host) == "a host's file"
      assert File.read!(rig.store) == read
      refute File.exists?(rig.store <> ".dropped.tmp")

      # The stop's write makes the owed copy first, under the next number, and then the
      # store.
      assert Runner.stop(runner) == :ok
      assert File.read!(rig.store <> ".dropped.2") == read
      assert File.read!(host) == "a host's file"
      refute File.read!(rig.store) == read
    end

    # The review of RV-13: the look and the rename are two calls, the rename through the
    # VM's file server, so that a file a host makes at the copy's number between them, as
    # the rename waits in the held server's queue, is replaced by the copy, the copy made
    # and named (decision 449, as built: decision 418 has none replaced, and the rename
    # that refuses a name that stands, a hard link, is not on every card's file system).
    test "a file a host makes at the copy's number after the copy looked, as its rename " <>
           "waits, is replaced (decision 449)",
         %{tmp_dir: dir} do
      rig = rig(dir, forces: nil)
      {:ok, runner} = Runner.start_link(rig.opts)
      eye(rig, 1)
      assert Runner.stop(runner) == :ok
      read = File.read!(rig.store)

      {:ok, retyped} =
        Logex.compile(String.replace(@tally, "boxes ctu", "boxes ctu_int"), name: "tally")

      {:ok, config} = Configuration.compile("plant", @plant, %{"tally" => retyped})
      next = rig(dir, forces: nil, configuration: config)
      server = held()

      start =
        Task.async(fn ->
          {:ok, runner} = Runner.start_link(next.opts)
          Process.unlink(runner)
          runner
        end)

      assert {:called, _renaming} = called_or_answered(server, :rename, start)
      host = rig.store <> ".dropped.1"
      assert :file.read_link_info(host, [:raw]) == {:error, :enoent}
      :ok = :file.write_file(host, "a host's file", [:raw])
      :sys.resume(server)
      runner = Task.await(start, @answers)

      assert %{status: :running, retain: %{copy: ^host, failed: nil, dropped: [_drop]}} =
               Runner.status(runner)

      assert File.read!(host) == read
      refute File.exists?(rig.store <> ".dropped.tmp")
      assert Runner.stop(runner) == :ok
      refute File.exists?(rig.store <> ".dropped.2")
    end
  end

  # Decision 417 (RV-13): a cold start over a store a fresh start would refuse copies it
  # first and writes the store only once the copy is made, so a copy the disk does not
  # finish within the write limit is judged as decision 291 judges a cold start whose
  # first write fails: the start refused, `{:error, {:retain, :timeout}}`, no device read
  # and the store as it was, the copy's rename alone left to land once the disk answers;
  # and a store that stands but whose read does not end within its limit, a FIFO in its
  # place, can be copied by no start, the same (decision 453).
  describe "a cold start's copy (decision 417)" do
    test "a cold start whose copy does not end within its limit starts nothing, the store " <>
           "as it was",
         %{tmp_dir: dir} do
      rig = rig(dir, forces: nil, start: :cold)
      cut = "logex retain 2\nconfiguration plant written 2026-10-30T14:00:00Z\nglobal tot"
      File.write!(rig.store, cut)
      server = held()
      {took, answer} = timed(fn -> Runner.start_link(rig.opts) end)
      assert answer == {:error, {:retain, :timeout}}
      assert took >= @limit and took < @answers
      assert Sim.reads(rig.panel) == 0
      assert :file.read_file(rig.store, [:raw]) == {:ok, cut}
      :sys.resume(server)
      wait_for_tmp_gone(rig.store <> ".dropped.tmp")
      assert File.read!(rig.store) == cut
      assert File.read(rig.store <> ".dropped.1") in [{:ok, cut}, {:error, :enoent}]
      refute File.exists?(rig.store <> ".tmp")
    end

    test "a cold start over a store whose read does not end within its limit starts nothing",
         %{tmp_dir: dir} do
      rig = rig(dir, forces: nil, start: :cold)
      {_, 0} = System.cmd("mkfifo", [rig.store])
      on_exit(fn -> let_go(rig.store) end)
      {took, answer} = timed(fn -> Runner.start_link(rig.opts) end)
      assert answer == {:error, {:retain, :timeout}}
      assert took >= @limit and took < @answers
      assert Sim.reads(rig.panel) == 0
      assert {:ok, %File.Stat{type: :other}} = File.lstat(rig.store)
      let_go(rig.store)
    end
  end

  # Decision 414 (RV-13): the end's write, a stop's or a shutdown's, takes the retained
  # image out and makes the store's text in the write's own process, within the write
  # limit, which the child spec's shutdown deadline counts, where the runner made them in
  # its own process with no limit (b3-store-image-4), so that a store too big to make and
  # write within the limit is cut off at it and told, `{:retain, {:error, :timeout}}`,
  # never killed by its supervisor in the making. Traced: the runner itself calls neither
  # `Logex.Runtime.retained/1` nor `Logex.Retain.encode/2` as it ends, and a process it
  # starts, the write's, calls both, the store then written. A trace pattern moves every
  # process's reductions, and this module is not async (CONTRIBUTING.md).
  describe "the end's write within its limit (decision 414)" do
    test "the end's write makes the store's text in the write's own process",
         %{tmp_dir: dir} do
      for ending <- [:stop, :shutdown] do
        rig = rig(Path.join(dir, "#{ending}"), forces: nil, write_limit: 5000)
        File.mkdir_p!(Path.join(dir, "#{ending}"))
        {:ok, runner} = Runner.start_link(rig.opts)
        Process.unlink(runner)
        eye(rig, 1)
        ref = Process.monitor(runner)
        assert :erlang.trace_pattern({Logex.Retain, :encode, 2}, true, [:local]) == 1
        assert :erlang.trace_pattern({Logex.Runtime, :retained, 1}, true, [:local]) == 1
        :erlang.trace(runner, true, [:call, :set_on_spawn])
        ended_by(ending, runner)
        assert_receive {:DOWN, ^ref, :process, ^runner, _reason}, @answers
        :erlang.trace_pattern({Logex.Retain, :encode, 2}, false, [:local])
        :erlang.trace_pattern({Logex.Runtime, :retained, 1}, false, [:local])
        calls = traced_all()
        refute Enum.any?(calls, &match?({^runner, _mfa}, &1)), inspect(calls)

        assert [{write, {Logex.Runtime, :retained, [_runtime]}}] =
                 for({_pid, {Logex.Runtime, :retained, _}} = call <- calls, do: call)

        assert [{^write, {Logex.Retain, :encode, [_image, _at]}}] =
                 for({_pid, {Logex.Retain, :encode, _}} = call <- calls, do: call)

        assert File.read!(rig.store) =~ "t1.boxes.cv dint 1\n"
      end
    end
  end

  # Decision 455 (RV-6): every write of the store makes its text so, the end's since
  # decision 414 and since RV-6 a trip's, a cold restart's, `start: :cold`'s, a fresh
  # start's with no store file and the period's, where each but the period's made it in the
  # runner, with no limit, and the period's took the image out there: so that a store too
  # big to make and write within the limit is cut off at it and reported, the runner
  # answering on, where a trip of 131,072 retained timers kept it some 11 s making the text
  # (RV-13's question 7). Traced, each process the test and the runner start traced too:
  # the runner calls neither `Logex.Runtime.retained_image/1` nor `Logex.Retain.encode/2`,
  # and one process calls both, each write's own, the period's the writer's. Since
  # decision 488 (RV-18) the image is made by `retained_image/1`, `retained/1` through it,
  # and the period's writer makes it of the retained values the runner sends, where the
  # trace named `retained/1`, which the writer called on the whole resource.
  describe "every write of the store makes its text in the write's own process (decision 455)" do
    # The work traced in `traced`, the runner or the test that starts one, and every process
    # either starts.
    defp texts_made(traced, work) do
      assert :erlang.trace_pattern({Logex.Retain, :encode, 2}, true, [:local]) == 1
      assert :erlang.trace_pattern({Logex.Runtime, :retained_image, 1}, true, [:local]) == 1
      :erlang.trace(traced, true, [:call, :set_on_spawn])
      runner = work.()
      :erlang.trace(traced, false, [:call, :set_on_spawn])
      :erlang.trace_pattern({Logex.Retain, :encode, 2}, false, [:local])
      :erlang.trace_pattern({Logex.Runtime, :retained_image, 1}, false, [:local])
      ref = :erlang.trace_delivered(:all)
      assert_receive {:trace_delivered, :all, ^ref}, @answers
      calls = traced_all()
      refute Enum.any?(calls, &match?({^runner, _mfa}, &1)), inspect(calls)
      takers = for {pid, {Logex.Runtime, :retained_image, _}} <- calls, do: pid
      makers = for {pid, {Logex.Retain, :encode, _}} <- calls, do: pid
      assert [_ | _] = takers
      assert takers == makers and self() not in takers
      runner
    end

    test "a trip's, a cold restart's, a cold start's, a fresh start's and the period's",
         %{tmp_dir: dir} do
      rig = rig(Path.join(dir, "trip"), forces: nil, write_limit: 5000)
      File.mkdir_p!(Path.join(dir, "trip"))
      {:ok, runner} = Runner.start_link(rig.opts)
      eye(rig, 1)

      texts_made(runner, fn ->
        Sim.fail(rig.panel, :read, {:error, :eio})
        Manual.advance(rig.clock, 10)
        assert %{status: :tripped} = Runner.status(runner)
        runner
      end)

      assert File.read!(rig.store) =~ "t1.boxes.cv dint 1\n"
      texts_made(runner, fn -> assert Runner.restart(runner, :cold) == :ok and runner end)
      assert File.read!(rig.store) =~ "t1.boxes.cv dint 0\n"
      assert Runner.stop(runner) == :ok

      for {start, at} <- [{:cold, "cold"}, {:warm, "fresh"}] do
        rig = rig(Path.join(dir, at), forces: nil, write_limit: 5000, start: start)
        File.mkdir_p!(Path.join(dir, at))
        runner = texts_made(self(), fn -> elem(Runner.start_link(rig.opts), 1) end)
        assert File.read!(rig.store) =~ "t1.boxes.cv dint 0\n"
        assert Runner.stop(runner) == :ok
      end

      rig = rig(Path.join(dir, "period"), forces: nil, write_limit: 5000, retain_period: 100)
      File.mkdir_p!(Path.join(dir, "period"))
      {:ok, runner} = Runner.start_link(rig.opts)
      eye(rig, 1)

      texts_made(runner, fn ->
        Manual.advance(rig.clock, 100)
        holding(rig.store, "t1.boxes.cv dint 1\n")
        runner
      end)

      assert Runner.stop(runner) == :ok
    end
  end

  # Decision 455 (RV-6): a store too big to make and write within the limit, its text's
  # making counted, is cut off at it and reported as any write past its limit (decision
  # 391), and the runner answers on: 10,000 retained timers, whose take-out and text take
  # some 300 ms here, against a write limit of 50 ms. Where the runner made the text first,
  # with no limit, the trip's write and `start: :cold`'s landed after it.
  describe "a store too big for its write limit (decision 455)" do
    @timers """
    var_input eye bool
    var_output lamp bool
    var retain boxes ctu
    var retain tl ton[10000]

    xic eye ctu boxes 1000
    xic eye ton tl[0] 100
    xic eye ote lamp
    """

    defp timers(dir, extra) do
      {:ok, tally} = Logex.compile(@timers, name: "tally")
      {:ok, config} = Configuration.compile("plant", @plant, %{"tally" => tally})
      rig(dir, [configuration: config, forces: nil] ++ extra)
    end

    test "a trip's write is cut off at the limit and reported, the runner answering",
         %{tmp_dir: dir} do
      made = timers(dir, write_limit: 5000)
      {:ok, runner} = Runner.start_link(made.opts)
      assert Runner.stop(runner) == :ok
      stored = File.read!(made.store)

      rig = timers(dir, write_limit: 50)
      {:ok, runner} = Runner.start_link(rig.opts)
      :ok = Runner.subscribe(runner, [:trip, :retain])
      Sim.fail(rig.panel, :read, {:error, :eio})
      Manual.advance(rig.clock, 10)

      assert_receive {Runner, ^runner, {:trip, {:io, "panel", {:error, :eio}}}}, @answers
      assert_receive {Runner, ^runner, {:retain, {:error, :timeout}}}, @answers
      assert %{status: :tripped, retain: %{unknown: unknown, failed: nil}} = Runner.status(runner)
      assert unknown == rig.store
      assert File.read!(rig.store) == stored
      assert Runner.stop(runner) == {:error, {:retain, :timeout}}
    end

    test "start: :cold's first write is cut off at the limit, and the start refused",
         %{tmp_dir: dir} do
      rig = timers(dir, write_limit: 50, start: :cold)
      assert Runner.start_link(rig.opts) == {:error, {:retain, :timeout}}
      assert Sim.reads(rig.panel) == 0
    end
  end

  # Once the store holds `line`, the period's writer having written it.
  defp holding(store, line), do: held_line(File.read!(store) =~ line, store, line)

  defp held_line(true, _store, _line), do: :ok

  defp held_line(false, store, line) do
    Process.sleep(1)
    holding(store, line)
  end

  # Decision 414: the limit counted from before the write's process is made, so that the
  # copy into it of what its call holds, a large resource among it, is within the limit
  # and the shutdown's deadline counts it (`Logex.Runner.Writer.within/2`). Traced: the
  # caller reads the clock, makes the write's process and reads the clock again, the wait
  # its limit less the time between, where a limit counted from after the process was
  # made read the clock once, before, or not at all. A trace pattern moves every
  # process's reductions, and this module is not async (CONTRIBUTING.md).
  describe "a write's limit counted from before its process is made (decision 414)" do
    test "the caller reads the clock before it makes the write's process and after" do
      test = self()

      caller =
        spawn(fn ->
          Process.flag(:trap_exit, true)

          receive do
            :go -> send(test, {:within, Logex.Runner.Writer.within(fn -> :written end, 5000)})
          end

          receive do
            :done -> :ok
          end
        end)

      assert :erlang.trace_pattern({System, :monotonic_time, 1}, true, [:global]) == 1
      :erlang.trace(caller, true, [:call, :procs])
      send(caller, :go)
      assert_receive {:within, :written}, 5000
      :erlang.trace(caller, false, [:call, :procs])
      :erlang.trace_pattern({System, :monotonic_time, 1}, false, [:global])
      ref = :erlang.trace_delivered(caller)
      assert_receive {:trace_delivered, ^caller, ^ref}, 5000
      send(caller, :done)

      assert [
               {:clock, :millisecond},
               {:spawned, write},
               {:clock, :millisecond}
             ] = clock_and_spawns(caller)

      assert {:module, Logex.Runner.Writer} == :erlang.fun_info(write, :module)
    end
  end

  # The caller's clock reads and the processes it made, in the order it made them, each a
  # process's function where it made one.
  defp clock_and_spawns(caller) do
    receive do
      {:trace, ^caller, :call, {System, :monotonic_time, [unit]}} ->
        [{:clock, unit} | clock_and_spawns(caller)]

      {:trace, ^caller, :spawn, _pid, {:erlang, :apply, [fun, []]}} ->
        [{:spawned, fun} | clock_and_spawns(caller)]

      {:trace, ^caller, _other, _pid} ->
        clock_and_spawns(caller)

      {:trace, ^caller, _other, _pid, _info} ->
        clock_and_spawns(caller)
    after
      0 -> []
    end
  end

  defp ended_by(:stop, runner), do: assert(Runner.stop(runner) == :ok)

  defp ended_by(:shutdown, runner),
    do: assert(Task.await(Task.async(fn -> GenServer.stop(runner, :shutdown) end)) == :ok)

  defp traced_all do
    receive do
      {:trace, pid, :call, mfa} -> [{pid, mfa} | traced_all()]
    after
      0 -> []
    end
  end

  # The runner's status once a trip's write has been made or found past its limit.
  defp written_or_unknown(runner), do: tripped_status(Runner.status(runner), runner)

  defp tripped_status(%{status: :running}, runner), do: written_or_unknown(runner)
  defp tripped_status(status, _runner), do: status

  # Waits until a killed write's late calls are done with its `.tmp`, the disk back: its
  # rename lands or its delete does, a leftover of its own left to the next write.
  defp wait_for_tmp_gone(tmp), do: tmp_waited(File.exists?(tmp), tmp, 500)

  defp tmp_waited(false, _tmp, _left), do: :ok
  defp tmp_waited(true, _tmp, 0), do: :ok

  defp tmp_waited(true, tmp, left) do
    Process.sleep(10)
    tmp_waited(File.exists?(tmp), tmp, left - 1)
  end

  # Decision 400 (RV-11): every file write and read decision 353 limits is limited by the
  # runner's `write_limit:`, apart from the heartbeat: a write the disk is slow over past
  # the idle watchdog and a poll period, within the write limit, lands, where it was
  # killed at the idle watchdog and a poll period before, `:timeout`.
  describe "the write limit, apart from the heartbeat (decision 400)" do
    test "a write the disk finishes past the idle watchdog and a poll period, within the " <>
           "write limit, lands",
         %{tmp_dir: dir} do
      # The heartbeat 110 ms, the write limit 1010 and the disk slow for 400 ms of each
      # write: a write past the heartbeat, within the limit.
      rig = rig(dir, idle: 100, retain_period: 100)
      {:ok, runner} = Runner.start_link(rig.opts)
      :ok = Runner.subscribe(runner, [:retain, :trip])
      eye(rig, 1)

      # A force.
      held_for(400)
      {took, answer} = timed(fn -> Runner.force(runner, "level", 7) end)
      assert answer == :ok and took >= 400
      assert File.read!(rig.forces) == "level 7\n"
      assert %{status: :running, trip: nil, forces: %{"level" => 7}} = Runner.status(runner)

      # The period's write at 100, by the writer: not reported past the heartbeat, and
      # made once the disk answers.
      held_for(400)
      eye(rig, 0)
      Manual.advance(rig.clock, 80)
      Process.sleep(600)
      period_settled(runner)
      refute_received {Runner, ^runner, {:retain, {:error, :timeout}}}
      assert %{status: :running, retain: %{failed: nil}} = Runner.status(runner)
      assert File.read!(rig.store) =~ "t1.boxes.cv dint 1\n"

      # A trip's write, the next box counted first: the panel's notice trips the runner as
      # it next runs, and status/1 is answered once the trip, its write among it, is done.
      eye(rig, 1)
      held_for(400)
      Sim.fail(rig.panel, :read, {:error, :eio})
      Manual.advance(rig.clock, 10)
      assert_receive {Runner, ^runner, {:trip, {:io, "panel", {:error, :eio}}}}, @answers
      assert %{status: :tripped, retain: %{failed: nil}} = Runner.status(runner)
      refute_received {Runner, ^runner, {:retain, {:error, _}}}
      assert File.read!(rig.store) =~ "t1.boxes.cv dint 2\n"

      # A cold restart's write, and a stop's.
      held_for(400)
      {took, answer} = timed(fn -> Runner.restart(runner, :cold) end)
      assert answer == :ok and took >= 400
      assert File.read!(rig.store) =~ "t1.boxes.cv dint 0\n"
      held_for(400)
      {took, answer} = timed(fn -> Runner.stop(runner) end)
      assert answer == :ok and took >= 400

      # A fresh start's, `start: :cold`.
      held_for(400)
      {took, {:ok, again}} = timed(fn -> Runner.start_link(rig.opts ++ [start: :cold]) end)
      assert took >= 400
      assert %{status: :running, retain: %{failed: nil}} = Runner.status(again)
      assert Runner.stop(again) == :ok
    end

    # Unless set, the write limit is 5000 ms, whatever the idle watchdog: a force the disk
    # is slow over for 400 ms beside an idle watchdog of 100 lands, and one it does not
    # finish is cut at 5000.
    test "the write limit is 5000 ms unless set", %{tmp_dir: dir} do
      rig = rig(dir, idle: 100)
      {:ok, runner} = Runner.start_link(Keyword.delete(rig.opts, :write_limit))
      held_for(400)
      assert Runner.force(runner, "level", 7) == :ok
      server = held()
      {took, answer} = timed(fn -> Runner.force(runner, "level", 8) end)
      assert answer == {:error, {:forces, :timeout}}
      assert took >= 5000
      :sys.resume(server)
      assert %{status: :running, forces: %{"level" => 7}} = Runner.status(runner)
      assert Runner.stop(runner) == :ok
    end

    test "each write past its limit is killed at the write limit, not at the idle watchdog " <>
           "and a poll period",
         %{tmp_dir: dir} do
      # The heartbeat 60 ms and the write limit 1010: each write the disk does not finish
      # is cut at the limit, never sooner.
      rig = rig(dir, idle: 50, forces: nil)
      {:ok, runner} = Runner.start_link(rig.opts)
      :ok = Runner.subscribe(runner, [:retain])
      eye(rig, 1)
      server = held()

      Sim.fail(rig.panel, :read, {:error, :eio})

      {took, _} =
        timed(fn ->
          Manual.advance(rig.clock, 10)
          assert_receive {Runner, ^runner, {:retain, {:error, :timeout}}}, @answers
        end)

      assert took >= @limit and took < @answers

      {took, answer} = timed(fn -> Runner.restart(runner, :cold) end)
      assert answer == {:error, {:retain, :timeout}}
      assert took >= @limit and took < @answers

      {took, answer} = timed(fn -> Runner.stop(runner) end)
      assert answer == {:error, {:retain, :timeout}}
      assert took >= @limit and took < @answers

      # Decision 475 (RV-18): the stop's write cut at its limit, its rename in the held
      # server's queue, the store stays held for the runner until that write has ended, a
      # start on it refused naming it, where the start went on to a write of its own; the
      # server let go, the holder ends, and the start's own write is cut at its limit.
      [{_store, holder, :retain}] = :ets.lookup(Logex.Runner.Paths, rig.store)

      assert_raise ArgumentError,
                   "the runner's retain: #{inspect(rig.store)} names the store of a runner " <>
                     "of this VM that has stopped, #{inspect(runner)}, held by " <>
                     "#{inspect(holder)} until a write of it that runner cut at its write " <>
                     "limit has ended, which may yet land: two runners on one file write " <>
                     "each over the other's",
                   fn -> Runner.start_link(rig.opts ++ [start: :cold]) end

      ref = Process.monitor(holder)
      :sys.resume(server)
      assert_receive {:DOWN, ^ref, :process, ^holder, :normal}, @answers
      server = held()
      {took, answer} = timed(fn -> Runner.start_link(rig.opts ++ [start: :cold]) end)
      assert answer == {:error, {:retain, :timeout}}
      assert took >= @limit and took < @answers
      :sys.resume(server)
    end

    # RV-5's review left a relative path's expansion in the start's caller, where it reads
    # the working directory through the VM's file server, so that a held server held the
    # start: it is made in a process of its own within the write limit now, as every file
    # call of the start is, a working directory the disk does not answer for in time
    # refusing the start, the file named. Since RV-11's review the refusal says the file
    # cannot be located, where it said it cannot be read, which decision 390 carries a
    # forces file's start on past (decision 446): with no path the start holds no file as
    # its own and tells neither from the other; and the store's, a second start named by a
    # relative store alone, the same. This file is not async, so the working directory
    # moved here is no other test's.
    test "a relative path's expansion is made within the write limit, never in the caller",
         %{tmp_dir: dir} do
      cwd = File.cwd!()
      File.cd!(dir)
      on_exit(fn -> File.cd!(cwd) end)
      rig = rig(dir, forces: "plant.forces", retain: "plant.retain", write_limit: 5000)

      assert :erlang.trace_pattern({:file, :_, :_}, true, [:local]) > 0
      {caller, started} = traced_start(rig.opts)
      :erlang.trace_pattern({:file, :_, :_}, false, [:local])
      assert {:ok, runner} = started
      assert traced_calls(caller) == []
      assert Runner.force(runner, "level", 7) == :ok
      assert Runner.stop(runner) == :ok
      send(caller, :done)
      assert File.read!(Path.join(dir, "plant.forces")) == "level 7\n"

      server = held()
      opts = Keyword.put(rig.opts, :write_limit, @limit)
      start = Task.async(fn -> timed(fn -> start_refused(opts) end) end)
      assert {:ok, {took, refused}} = Task.yield(start, 2 * @answers)

      assert refused ==
               "plant.forces: the forces file cannot be located: the working directory a " <>
                 "relative path is read against did not answer within the write limit, " <>
                 "1010 ms (write_limit:)"

      assert took >= @limit and took < @answers

      opts = Keyword.put(opts, :forces, nil)
      start = Task.async(fn -> timed(fn -> start_refused(opts) end) end)
      assert {:ok, {took, refused}} = Task.yield(start, 2 * @answers)

      assert refused ==
               "plant.retain: the store cannot be located: the working directory a relative " <>
                 "path is read against did not answer within the write limit, 1010 ms " <>
                 "(write_limit:)"

      assert took >= @limit and took < @answers
      :sys.resume(server)
    end

    # On the real clock a force's write the disk is slow over past the heartbeat, within
    # the write limit, latches no device and trips nothing: since decision 437 the write is
    # made off the runner's path and the runner goes on refreshing its devices at its
    # waits and rounds as ever, where decision 400 had it renew them each poll period while
    # it waited on its disk and leave the wait out of the request's time; the refresh's
    # wake that comes during the write, here the first, the plant's task due only every
    # 2 s, finds every device heard. The heartbeat 1010 ms and the disk slow for 2500, so
    # that a loaded machine's late wakes, 668 ms at most seen (RV-4's review), stay inside
    # the margin of each refresh.
    test "on the real clock a force's write slow past the heartbeat latches no device and " <>
           "trips nothing",
         %{tmp_dir: dir} do
      rig =
        rig(dir,
          configuration: configured(String.replace(@plant, "interval 10", "interval 2000")),
          clock: {Logex.Runner.Clock.Monotonic, nil},
          idle: 1000,
          write_limit: 5000,
          retain: nil,
          retain_period: nil
        )

      {:ok, runner} = Runner.start_link(rig.opts)
      :ok = Runner.subscribe(runner, [:trip])

      # A device that latched, or was taken as hung, tells the runner, which trips as it
      # takes the notice: status/1, answered after it, would say so.
      held_for(2500)
      {took, answer} = timed(fn -> Runner.force(runner, "level", 7) end)
      assert answer == :ok and took >= 2500
      Process.sleep(100)

      assert %{status: :running, trip: nil, forces: %{"level" => 7}, unzeroed: []} =
               Runner.status(runner)

      refute_received {Runner, ^runner, {:trip, _reason}}
      assert File.read!(rig.forces) == "level 7\n"
      assert Runner.stop(runner) == :ok
    end

    # RV-11's review: the time a force's write waited on the disk is left out of that
    # request's time alone, 0 again once it is answered, so that a later request whose own
    # work takes longer than the idle watchdog trips it as ever. Here the clock passes 1000
    # ms while the force's write waits on the held disk, the idle watchdog 2 ms, and every
    # reading of the clock then takes 3: the force trips nothing, and a get after it trips
    # the runner, as any slow request does (decision 128). The plant's task is due only
    # every 100 s, so that no round is due as either comes (decision 396).
    test "the time a force's write waited is its own request's alone: a slow request " <>
           "after it trips the idle watchdog",
         %{tmp_dir: dir} do
      {:ok, ticks} = Agent.start_link(fn -> 0 end)

      rig =
        rig(dir,
          configuration: configured(String.replace(@plant, "interval 10", "interval 100000")),
          idle: 2,
          retain: nil,
          retain_period: nil
        )

      opts = Keyword.put(rig.opts, :clock, {Ticking, {rig.clock, ticks}})
      {:ok, runner} = Runner.start_link(opts)
      :ok = Runner.subscribe(runner, [:trip])

      server = held()
      force = Task.async(fn -> Runner.force(runner, "level", 7) end)
      _writing = waiting_call(server, :rename)
      Manual.pass(rig.clock, 1000)
      :sys.resume(server)
      assert Task.await(force, @answers) == :ok
      assert %{status: :running, trip: nil, forces: %{"level" => 7}} = Runner.status(runner)
      refute_received {Runner, ^runner, {:trip, _reason}}

      Agent.update(ticks, fn _ -> 3 end)
      assert Runner.get(runner, "total") == {:ok, 0}
      # Decision 352 (RV-6): named by the work it was met in, the get.
      assert_receive {Runner, ^runner, {:trip, {:watchdog, {:idle, 3, :get}}}}, @answers
      assert Runner.stop(runner) == :ok
    end
  end

  # Decision 437 (RV-16): the rounds run on while a force's or an unforce's write of the
  # forces file is out, and the force takes effect at the first round after the write
  # lands, so that the logic keeps the plant under control on a slow disk and no force is
  # in effect before the file holds it (decision 117); the caller waits for the write as
  # it did. Each write is stalled at its rename, the held file server's one call of it.
  # The limit is no part of what these read but where a test says so: each runner is
  # given @out, so that a write a loaded machine's disk is slow over before it comes to
  # its rename, or one held while the test steps the runner, is never cut at the limit,
  # where at 1010 ms one in ten runs under scripts/load.sh beside another suite's syncs
  # was cut before its rename, and the test waited for a rename that never came.
  @out 20_000

  describe "the rounds run on while a force's write is out (decision 437)" do
    test "rounds run, status/1 answers and the force is in effect from the first round " <>
           "after the write lands, none before",
         %{tmp_dir: dir} do
      rig = rig(dir, retain: nil, retain_period: nil, write_limit: @out)
      {:ok, runner} = Runner.start_link(rig.opts)
      eye(rig, 0)
      %{rounds: before} = Runner.status(runner)
      server = held()
      force = Task.async(fn -> Runner.force(runner, "eye_1", 1) end)
      _writing = waiting_call(server, :rename)

      # Five rounds while the write waits on the disk, the eye read as its device gives it,
      # and status/1 answered, the force listed nowhere yet.
      for _ <- 1..5, do: Manual.advance(rig.clock, 10)

      assert %{status: :running, rounds: rounds, forces: forces, trip: nil} =
               Runner.status(runner)

      assert rounds == before + 5 and forces == %{}
      assert Sim.outputs(rig.panel) == %{[0] => 0}
      assert Task.yield(force, 0) == nil

      # The disk back, the force answered once its write has landed, the file holding it,
      # and read from the next round on.
      :sys.resume(server)
      assert Task.await(force, @answers) == :ok
      assert File.read!(rig.forces) == "eye_1 1\n"
      assert %{forces: %{"eye_1" => 1}, rounds: ^rounds} = Runner.status(runner)
      assert Sim.outputs(rig.panel) == %{[0] => 0}
      Manual.advance(rig.clock, 10)
      assert Sim.outputs(rig.panel) == %{[0] => 1}
      assert Runner.stop(runner) == :ok
    end

    # A second force while one's write is out waits behind it, in order, its write built
    # on the set the first left (decision 465).
    test "a force asked while another's write is out waits behind it, its write built on " <>
           "the set the first left",
         %{tmp_dir: dir} do
      rig = rig(dir, retain: nil, retain_period: nil, write_limit: @out)
      {:ok, runner} = Runner.start_link(rig.opts)
      server = held()
      first = Task.async(fn -> Runner.force(runner, "level", 7) end)
      _writing = waiting_call(server, :rename)
      second = calling(Task.async(fn -> Runner.force(runner, "eye_1", 1) end))
      unforced = calling(Task.async(fn -> Runner.unforce(runner, "level") end))
      assert %{forces: %{}} = Runner.status(runner)

      # One write out at a time: the second's has not begun, the first's alone waits.
      assert {:messages, messages} = Process.info(server, :messages)

      assert length(
               for({:"$gen_call", _, request} <- messages, elem(request, 0) == :rename, do: 1)
             ) == 1

      :sys.resume(server)
      assert Task.await(first, @answers) == :ok
      assert Task.await(second, @answers) == :ok
      assert Task.await(unforced, @answers) == :ok
      assert File.read!(rig.forces) == "eye_1 1\n"
      assert %{forces: %{"eye_1" => 1}} = Runner.status(runner)
      assert Runner.stop(runner) == :ok
    end

    # RV-16's review: the forces that wait their turn are written in the order asked, the
    # last asked the last written, though a forced trigger's round, run as its write
    # lands and before the next behind it is served, serves a force that waited for the
    # share: that force goes behind the ones that came before it, where it was served
    # ahead of them, and the older force, written last, won. The trigger `e` forced, its
    # write held; `level` forced to 3 behind it; the round due at 20 owed, so that `level`
    # forced to 5 waits for the share.
    test "the forces behind a write are written in the order asked, a forced trigger's " <>
           "round between them",
         %{tmp_dir: dir} do
      rig =
        rig(dir,
          configuration: configured(@kicked),
          retain: nil,
          retain_period: nil,
          write_limit: @out
        )

      {:ok, runner} = Runner.start_link(rig.opts)
      eye(rig, 0)
      server = held()
      trigger = Task.async(fn -> Runner.force(runner, "e", 1) end)
      _writing = waiting_call(server, :rename)
      older = calling(Task.async(fn -> Runner.force(runner, "level", 3) end))
      Manual.pass(rig.clock, 10)
      newer = calling(Task.async(fn -> Runner.force(runner, "level", 5) end))
      assert %{rounds: rounds, queue: queue, forces: %{}} = :sys.get_state(runner)
      assert :queue.len(queue) == 1

      :sys.resume(server)
      assert Task.await(trigger, @answers) == :ok
      assert Task.await(older, @answers) == :ok
      assert Task.await(newer, @answers) == :ok
      assert File.read!(rig.forces) == "e 1\nlevel 5\n"
      assert %{forces: %{"e" => 1, "level" => 5}, rounds: after_} = Runner.status(runner)
      assert after_ == rounds + 1
      Manual.advance(rig.clock, 10)
      assert Runner.get!(runner, "level") == 5
      assert Runner.stop(runner) == :ok
    end

    # RV-16's review: an unforce_all writes the file as a force does, so it waits its turn
    # behind a write that is out. Decision 473 (RV-18): a host's mistake among the requests
    # is raised in its caller as it is asked, while the write ahead of it is still out,
    # where it waited its turn and was raised only once that write had ended; the force
    # asked after it is then written with the unforce_all, in the order asked.
    test "an unforce_all waits behind a write, and a force behind a host's mistake is " <>
           "served after it",
         %{tmp_dir: dir} do
      rig = rig(dir, retain: nil, retain_period: nil, write_limit: @out)
      {:ok, runner} = Runner.start_link(rig.opts)
      server = held()
      first = Task.async(fn -> Runner.force(runner, "level", 7) end)
      _writing = waiting_call(server, :rename)
      cleared = calling(Task.async(fn -> Runner.unforce_all(runner) end))

      assert stop_answer_of(fn -> Runner.force(runner, "drum", 1) end) ==
               {:raised, "`drum` is no input point of `plant`"}

      last = calling(Task.async(fn -> Runner.force(runner, "eye_1", 1) end))
      assert %{forces: %{}} = Runner.status(runner)
      assert Task.yield(first, 0) == nil

      :sys.resume(server)
      assert Task.await(first, @answers) == :ok
      assert Task.await(cleared, @answers) == :ok
      assert Task.await(last, @answers) == :ok
      assert File.read!(rig.forces) == "eye_1 1\n"
      assert %{forces: %{"eye_1" => 1}} = Runner.status(runner)
      assert Runner.stop(runner) == :ok
    end

    # Decision 437 (RV-16): the write keeps its link to the runner through its call of the
    # file system, so that a runner killed while a force's write is out takes the write
    # down with it, its caller told the runner is gone (RV-16's review); the call it was
    # in, already with the file server, lands as the disk comes back, as any killed
    # write's does, and nothing after it.
    test "a runner killed while a force's write is out takes the write down with it",
         %{tmp_dir: dir} do
      rig = rig(dir, retain: nil, retain_period: nil, write_limit: @out)
      {:ok, runner} = Runner.start_link(rig.opts)
      Process.unlink(runner)
      server = held()
      force = Task.async(fn -> stop_answer_of(fn -> Runner.force(runner, "level", 7) end) end)
      writer = renaming(server, runner)
      ref = Process.monitor(writer)
      Process.exit(runner, :kill)
      assert_receive {:DOWN, ^ref, :process, ^writer, :killed}, @answers
      assert Task.await(force, @answers) == gone_told(runner)
      :sys.resume(server)
    end

    # A trip and an edit's step made while a force's write is out leave it as it was: it
    # is taken onto the set the runner then holds once it lands, and read from the first
    # round after it, a restart's first round, which reads the file as every start does.
    # Decision 468 (RV-18): a restart made while it is out waits for it before it reads
    # the file, so that it reads what the write leaves, where it read the file as it stood,
    # the old set, showed the force the write was taking away, and the write then landed.
    test "a trip, a restart and an edit's step made while it is out leave it as it was",
         %{tmp_dir: dir} do
      rig = rig(dir, retain: nil, retain_period: nil, write_limit: @out)
      {:ok, runner} = Runner.start_link(rig.opts)
      eye(rig, 0)

      # A trip while it is out: the force taken once it lands, the runner still tripped,
      # and read by the restart's first round.
      server = held()
      force = Task.async(fn -> Runner.force(runner, "eye_1", 1) end)
      _writing = waiting_call(server, :rename)
      Sim.fail(rig.panel, :read, {:error, :eio})
      Manual.advance(rig.clock, 10)
      assert %{status: :tripped, forces: %{}} = Runner.status(runner)
      :sys.resume(server)
      assert Task.await(force, @answers) == :ok
      assert %{status: :tripped, forces: %{"eye_1" => 1}} = Runner.status(runner)
      assert Runner.restart(runner, :warm) == :ok
      assert Sim.outputs(rig.panel) == %{[0] => 1}

      # A restart while it is out waits for it (decision 468), then reads the file it left,
      # raw, the new set, its first round reading the eye as the device gives it.
      Sim.fail(rig.panel, :read, {:error, :eio})
      Manual.advance(rig.clock, 10)
      server = held()
      unforce = Task.async(fn -> Runner.unforce(runner, "eye_1") end)
      _writing = waiting_call(server, :rename)
      restart = Task.async(fn -> Runner.restart(runner, :warm) end)
      assert Task.yield(restart, 200) == nil
      assert Task.yield(unforce, 0) == nil
      :sys.resume(server)
      assert Task.await(restart, @answers) == :ok
      assert Task.await(unforce, @answers) == :ok
      assert File.read!(rig.forces) == ""
      assert %{status: :running, forces: %{}, forcing: nil} = Runner.status(runner)
      assert Sim.outputs(rig.panel) == %{[0] => 0}

      # An edit's steps while it is out, each answered: the force taken once it lands onto
      # the configuration the edit switched to.
      faster = configured(String.replace(@plant, "interval 10", "interval 5"))
      server = held()
      force = Task.async(fn -> Runner.force(runner, "level", 3) end)
      _writing = waiting_call(server, :rename)
      assert {:ok, _forecast} = Runner.accept(runner, faster)
      assert {:ok, _report} = Runner.test(runner)
      assert {:ok, _report} = Runner.assemble(runner)
      assert %{edit: nil, forces: %{}} = Runner.status(runner)
      :sys.resume(server)
      assert Task.await(force, @answers) == :ok
      Manual.advance(rig.clock, 5)
      assert Runner.get!(runner, "level") == 3
      assert Runner.stop(runner) == :ok
    end

    # A stop made while a force's write is out waits for it, to its own limit, and answers
    # its caller as it ends, the files given up only after it (decision 356); a force that
    # waited behind it is answered as to a runner that is not running (decision 467).
    test "a stop made while it is out waits for it and answers its caller, every output 0",
         %{tmp_dir: dir} do
      rig = rig(dir, retain: nil, retain_period: nil, write_limit: @out)
      {:ok, runner} = Runner.start_link(rig.opts)
      eye(rig, 1)
      server = held()
      force = Task.async(fn -> Runner.force(runner, "level", 7) end)
      _writing = waiting_call(server, :rename)

      behind =
        calling(Task.async(fn -> stop_answer_of(fn -> Runner.force(runner, "eye_1", 0) end) end))

      assert %{forces: %{}} = Runner.status(runner)
      stop = Task.async(fn -> Runner.stop(runner) end)
      assert Task.yield(stop, 200) == nil
      assert Sim.closed?(rig.panel)
      assert List.last(Sim.writes(rig.panel)) == %{[0] => 0}
      :sys.resume(server)
      assert Task.await(force, @answers) == :ok
      assert Task.await(stop, @answers) == :ok
      assert Task.await(behind, @answers) == gone_told(runner)
      assert File.read!(rig.forces) == "level 7\n"

      # Past its limit, @limit here, the stop answers the force's caller at that limit;
      # a write a loaded disk cuts at it before its rename is answered so too.
      rig = rig(Path.join(dir, "late"), retain: nil, retain_period: nil)
      File.mkdir_p!(Path.dirname(rig.forces))
      {:ok, runner} = Runner.start_link(rig.opts)
      server = held()
      force = Task.async(fn -> timed(fn -> Runner.force(runner, "level", 7) end) end)
      _writing = called_or_answered(server, :rename, force)
      assert Runner.stop(runner) == :ok
      assert {took, {:error, {:forces, :timeout}}} = Task.await(force, @answers)
      assert took >= @limit and took < @answers
      :sys.resume(server)
    end

    # Decision 437 (RV-16's review): a stop that finds a force's write already past its
    # limit, the cut's timer waiting unread behind the stop, cuts it at once and answers
    # its caller so, as one cut at its limit is, the stop answered `:ok`. The runner held
    # past the limit, so that the stop comes ahead of the timer.
    test "a stop that finds a force's write past its limit cuts it at once and answers " <>
           "its caller so",
         %{tmp_dir: dir} do
      rig = rig(dir, retain: nil, retain_period: nil, write_limit: 300)
      {:ok, runner} = Runner.start_link(rig.opts)
      server = held()
      force = Task.async(fn -> stop_answer_of(fn -> Runner.force(runner, "level", 7) end) end)
      _writing = called_or_answered(server, :rename, force)
      :sys.suspend(runner)
      past(:sys.get_state(runner).writing)
      stop = Task.async(fn -> Runner.stop(runner) end)
      assert Task.await(force, @answers) == {:error, {:forces, :timeout}}
      assert Task.await(stop, @answers) == :ok
      :sys.resume(server)
    end

    # On the real clock: the runner's rounds go on, and status/1 is answered, while the
    # write waits on the held disk, the force's call still out, however loaded the machine;
    # the force read once it lands. The task's watchdog and the idle watchdog are 5 s, the
    # heartbeat a loaded machine's to miss, which this test does not read.
    test "on the real clock the rounds run on while a force's write is out", %{tmp_dir: dir} do
      rig =
        rig(dir,
          configuration:
            configured(String.replace(@plant, "priority 1", "priority 1 watchdog 5000")),
          clock: {Logex.Runner.Clock.Monotonic, nil},
          idle: 5000,
          write_limit: 20_000,
          retain: nil,
          retain_period: nil
        )

      {:ok, runner} = Runner.start_link(rig.opts)
      server = held()
      force = Task.async(fn -> Runner.force(runner, "eye_1", 1) end)
      _writing = waiting_call(server, :rename)
      %{rounds: before} = Runner.status(runner)
      deadline = System.monotonic_time(:millisecond) + 10_000
      assert %{forces: %{}, trip: nil} = rounds_past(runner, before, deadline)
      assert Task.yield(force, 0) == nil
      assert Sim.outputs(rig.panel) == %{[0] => 0}
      :sys.resume(server)
      assert Task.await(force, @answers) == :ok
      assert lamp_on(rig.panel, System.monotonic_time(:millisecond) + 10_000) == 1

      assert %{status: :running, trip: nil, forces: %{"eye_1" => 1}, unzeroed: []} =
               Runner.status(runner)

      assert Runner.stop(runner) == :ok
    end
  end

  # Decision 465 (RV-18): the forcing requests asked while a write of the forces file is
  # out wait behind it and are joined into the next write, applied in the order asked,
  # each caller answered when that write lands, or as it fails or is cut, each the same
  # answer: ten such take two writes, where each was written in a write of its own and ten
  # took ten. Decision 466: `status/1`'s `forcing` the set the write that is out holds,
  # nil where none is out. Decision 473: a host's mistake among them raised in its caller
  # as it is asked, whatever write is out. Each write is counted as the runner begins it
  # (`Logex.Runner.Writer.begun/2`, traced in the runner).
  describe "the forcing requests behind a write joined into the next (decisions 465, 466, 473)" do
    defp begun_traced(runner) do
      assert :erlang.trace_pattern({Logex.Runner.Writer, :begun, 2}, true, [:local]) == 1
      on_exit(fn -> :erlang.trace_pattern({Logex.Runner.Writer, :begun, 2}, false, [:local]) end)
      :erlang.trace(runner, true, [:call])
      runner
    end

    defp begun_texts(runner) do
      receive do
        {:trace, ^runner, :call, {Logex.Runner.Writer, :begun, [_path, text]}} ->
          [text | begun_texts(runner)]
      after
        0 -> []
      end
    end

    test "ten asked while one write is out take two writes, each caller answered when " <>
           "the joined write lands, the changes applied in the order asked",
         %{tmp_dir: dir} do
      rig = rig(dir, retain: nil, retain_period: nil, write_limit: @out)
      {:ok, runner} = Runner.start_link(rig.opts)
      begun_traced(runner)
      assert %{forcing: nil} = Runner.status(runner)
      server = held()
      first = Task.async(fn -> Runner.force(runner, "level", 7) end)
      _writing = waiting_call(server, :rename)
      assert %{forces: %{}, forcing: %{"level" => 7}} = Runner.status(runner)

      calls = [
        fn -> Runner.force(runner, "eye_1", 1) end,
        fn -> Runner.force(runner, "level", 3) end,
        fn -> Runner.unforce(runner, "eye_1") end,
        fn -> Runner.force(runner, "level", 4) end,
        fn -> Runner.unforce_all(runner) end,
        fn -> Runner.force(runner, "level", 5) end,
        fn -> Runner.force(runner, "eye_1", 0) end,
        fn -> Runner.unforce(runner, "level") end,
        fn -> Runner.force(runner, "level", 9) end
      ]

      behind = for call <- calls, do: calling(Task.async(call))

      # The nine wait behind the first's write, none begun and none answered; status/1
      # shows the set the write that is out holds.
      assert %{forces: %{}, forcing: %{"level" => 7}} = Runner.status(runner)
      assert for(task <- behind, do: Task.yield(task, 0)) == List.duplicate(nil, 9)
      assert begun_texts(runner) == ["level 7\n"]

      :sys.resume(server)
      assert Task.await(first, @answers) == :ok
      assert for(task <- behind, do: Task.await(task, @answers)) == List.duplicate(:ok, 9)

      # One write more, the nine joined: each change on the set the one before it left,
      # the unforce_all clearing what came before it and the last force of `level` last.
      assert begun_texts(runner) == ["eye_1 0\nlevel 9\n"]
      assert File.read!(rig.forces) == "eye_1 0\nlevel 9\n"
      assert %{forces: %{"eye_1" => 0, "level" => 9}, forcing: nil} = Runner.status(runner)
      Manual.advance(rig.clock, 10)
      assert Runner.get!(runner, "level") == 9
      assert Runner.stop(runner) == :ok
    end

    test "the joined write cut at its limit answers each of its callers so, the set it " <>
           "held unknown",
         %{tmp_dir: dir} do
      rig = rig(dir, retain: nil, retain_period: nil, write_limit: 3000)
      {:ok, runner} = Runner.start_link(rig.opts)
      begun_traced(runner)
      server = held()
      first = Task.async(fn -> Runner.force(runner, "level", 7) end)
      _writing = called_or_answered(server, :rename, first)
      second = calling(Task.async(fn -> Runner.force(runner, "eye_1", 1) end))
      third = calling(Task.async(fn -> Runner.unforce(runner, "level") end))

      # The first cut at its limit, its set unknown; the two behind it joined into one
      # write on the set the runner holds, cut so too, each told the same.
      assert Task.await(first, 3 * @answers) == {:error, {:forces, :timeout}}
      assert Task.await(second, 3 * @answers) == {:error, {:forces, :timeout}}
      assert Task.await(third, 3 * @answers) == {:error, {:forces, :timeout}}
      assert begun_texts(runner) == ["level 7\n", "eye_1 1\n"]

      assert %{forces: %{}, forcing: nil, forces_unknown: %{"eye_1" => 1}} =
               Runner.status(runner)

      :sys.resume(server)
      assert Runner.stop(runner) == :ok
    end

    # RV-18's review, finding 8: the changes behind a write are joined at a cost in
    # proportion to their number, where each change's points were appended to every point
    # before them, a cost in their number squared: 16,000 behind one write took half a
    # second of one handler's work, which no watchdog times. The runner's reductions from
    # the disk's answer to every caller answered, at 500 and at 2,000 behind the write.
    test "joining the requests behind a write grows with their number, not its square",
         %{tmp_dir: dir} do
      [small, large] =
        for n <- [500, 2000] do
          sub = Path.join(dir, "n#{n}")
          File.mkdir_p!(sub)
          rig = rig(sub, retain: nil, retain_period: nil, write_limit: @out)
          {:ok, runner} = Runner.start_link(rig.opts)
          server = held()
          first = Task.async(fn -> Runner.force(runner, "level", 7) end)
          _writing = renaming(server, runner)
          behind = for i <- 1..n, do: Task.async(fn -> Runner.force(runner, "level", i) end)
          all_behind(runner, n)
          {:reductions, before} = Process.info(runner, :reductions)
          :sys.resume(server)
          assert Task.await(first, @answers) == :ok
          assert Enum.uniq(for(task <- behind, do: Task.await(task, @answers))) == [:ok]
          {:reductions, done} = Process.info(runner, :reductions)
          assert %{forces: %{"level" => level}, forcing: nil} = Runner.status(runner)
          assert level in 1..n
          assert Runner.stop(runner) == :ok
          done - before
        end

      assert large < 6 * small, "#{small} reductions at 500, #{large} at 2,000"
    end

    # RV-18's review, finding 2 (its mutant r03): every point a joined change unforces
    # reads its device again once the joined write lands, the last change's or not, where
    # only the last change's points were read again and an earlier one's kept its forced
    # value in the logic, the lamp on, while status/1 showed it unforced.
    test "a point unforced by a joined change that is not the last reads its device again",
         %{tmp_dir: dir} do
      rig = rig(dir, retain: nil, retain_period: nil, write_limit: @out)
      {:ok, runner} = Runner.start_link(rig.opts)
      eye(rig, 0)
      assert Runner.force(runner, "eye_1", 1) == :ok
      Manual.advance(rig.clock, 10)
      assert Sim.outputs(rig.panel) == %{[0] => 1}
      server = held()
      first = Task.async(fn -> Runner.force(runner, "level", 7) end)
      _writing = waiting_call(server, :rename)
      unforce = calling(Task.async(fn -> Runner.unforce(runner, "eye_1") end))
      last = calling(Task.async(fn -> Runner.force(runner, "level", 3) end))
      :sys.resume(server)
      assert Task.await(first, @answers) == :ok
      assert Task.await(unforce, @answers) == :ok
      assert Task.await(last, @answers) == :ok
      assert %{forces: %{"level" => 3}, forcing: nil} = Runner.status(runner)
      Manual.advance(rig.clock, 10)
      assert Runner.get!(runner, "eye_1") == 0
      assert Sim.outputs(rig.panel) == %{[0] => 0}
      assert Runner.stop(runner) == :ok
    end

    # Decision 473 (RV-18): every host's mistake in a forcing request raised at once while
    # a write is out, each message pinned whole, nothing put behind the write for it, and
    # the write's own caller answered as ever once it lands.
    test "a host's mistake in a forcing request is raised at once while a write is out",
         %{tmp_dir: dir} do
      rig = rig(dir, retain: nil, retain_period: nil, write_limit: @out)
      {:ok, runner} = Runner.start_link(rig.opts)
      begun_traced(runner)
      server = held()
      first = Task.async(fn -> Runner.force(runner, "level", 7) end)
      _writing = waiting_call(server, :rename)

      assert_raise ArgumentError, "`drum` is no input point of `plant`", fn ->
        Runner.force(runner, "drum", 1)
      end

      assert_raise ArgumentError,
                   "`lamp_q` is an output point, at `panel.q.0`: only an input point is forced",
                   fn -> Runner.force(runner, "lamp_q", 1) end

      assert_raise ArgumentError, "`eye_1` is a bool, forced to 0 or 1, got: 2", fn ->
        Runner.force(runner, "eye_1", 2)
      end

      assert_raise ArgumentError, "`drum` is no input point of `plant`", fn ->
        Runner.unforce(runner, "drum")
      end

      assert %{queue: queue, behind: behind} = :sys.get_state(runner)
      assert :queue.is_empty(queue) and :queue.is_empty(behind)
      assert Task.yield(first, 0) == nil
      :sys.resume(server)
      assert Task.await(first, @answers) == :ok
      assert begun_texts(runner) == ["level 7\n"]
      assert %{forces: %{"level" => 7}, forcing: nil} = Runner.status(runner)
      assert Runner.stop(runner) == :ok
    end
  end

  # Decision 468 (RV-18): a restart asked while a write of the forces file is out waits
  # for that write, to its limit, before it reads the file, so that the HMI never shows a
  # force that then vanishes; the requests that waited behind the write are joined into
  # the next once the restart has read the file; a write cut at its limit leaves what
  # decision 391 says, the restart reading the file as it then stands.
  describe "a restart waits for a write of the forces file that is out (decision 468)" do
    test "the restart reads the file the write left, and the requests behind it are " <>
           "written after",
         %{tmp_dir: dir} do
      rig = rig(dir, retain: nil, retain_period: nil, write_limit: @out)
      {:ok, runner} = Runner.start_link(rig.opts)
      eye(rig, 0)
      server = held()
      first = Task.async(fn -> Runner.force(runner, "level", 7) end)
      _writing = waiting_call(server, :rename)
      behind = calling(Task.async(fn -> Runner.force(runner, "eye_1", 1) end))
      Sim.fail(rig.panel, :read, {:error, :eio})
      Manual.advance(rig.clock, 10)
      assert %{status: :tripped, forces: %{}, forcing: %{"level" => 7}} = Runner.status(runner)

      # The restart waits on the write, and since decision 500 (RV-19) off the runner's
      # path, the runner answering meanwhile, where it answered nothing (decision 468 as
      # RV-18 built it).
      restart = calling(Task.async(fn -> Runner.restart(runner, :warm) end))
      assert Task.yield(restart, 200) == nil
      assert Task.yield(first, 0) == nil
      assert %{status: :tripped, forcing: %{"level" => 7}} = Runner.status(runner)

      :sys.resume(server)
      assert Task.await(first, @answers) == :ok
      assert Task.await(restart, @answers) == :ok
      assert Task.await(behind, @answers) == :ok
      assert Runner.get!(runner, "level") == 7
      assert File.read!(rig.forces) == "eye_1 1\nlevel 7\n"

      assert %{status: :running, forces: %{"eye_1" => 1, "level" => 7}, forcing: nil} =
               Runner.status(runner)

      Manual.advance(rig.clock, 10)
      assert Sim.outputs(rig.panel) == %{[0] => 1}
      assert Runner.stop(runner) == :ok
    end

    # Decision 502 (RV-19): the set the cut write held stays unknown after the restart's
    # read, the write able to land after it; the name ended "the set unknown no more", and
    # the status read `forces_unknown: nil`.
    test "a write cut at its limit: the restart answers once it is cut and reads the file " <>
           "as it stands, the set still unknown",
         %{tmp_dir: dir} do
      rig = rig(dir, retain: nil, retain_period: nil, write_limit: 300)
      {:ok, runner} = Runner.start_link(rig.opts)
      server = held()
      force = Task.async(fn -> timed(fn -> Runner.force(runner, "level", 7) end) end)
      _writing = called_or_answered(server, :rename, force)
      Sim.fail(rig.panel, :read, {:error, :eio})
      Manual.advance(rig.clock, 10)
      assert %{status: :tripped} = Runner.status(runner)
      assert {took, :ok} = timed(fn -> Runner.restart(runner, :warm) end)
      assert {forced, {:error, {:forces, :timeout}}} = Task.await(force, @answers)
      assert forced >= 300 and took < @answers

      assert %{status: :running, forces: %{}, forces_unknown: %{"level" => 7}, forcing: nil} =
               Runner.status(runner)

      :sys.resume(server)
      assert Runner.stop(runner) == :ok
    end

    # Decision 500 (RV-19): the wait off the runner's path. RV-18's review's probe 468W, a
    # lamp test's force out on a disk that takes its time, the line tripped and restarted:
    # status/1 blocked 1,503 ms while the restart waited; now every request is answered at
    # once meanwhile, the line shown tripped and the force on its way in `forcing`, and
    # the restart is made, and answered, once the write has ended.
    test "while a restart waits for the write every request is answered at once, the line " <>
           "tripped and the force in forcing",
         %{tmp_dir: dir} do
      rig = rig(dir, retain: nil, retain_period: nil, write_limit: @out)
      {:ok, runner} = Runner.start_link(rig.opts)
      server = held()
      force = Task.async(fn -> Runner.force(runner, "level", 7) end)
      _writing = waiting_call(server, :rename)
      Sim.fail(rig.panel, :read, {:error, :eio})
      Manual.advance(rig.clock, 10)
      restart = calling(Task.async(fn -> Runner.restart(runner, :cold) end))

      {took, status} = timed(fn -> Runner.status(runner) end)
      assert %{status: :tripped, trip: {:io, "panel", _}, forcing: %{"level" => 7}} = status
      assert took < 200
      assert {:ok, _value} = Runner.get(runner, "level")
      assert :ok = Runner.subscribe(runner, [:restart])
      assert Task.yield(restart, 100) == nil

      :sys.resume(server)
      assert Task.await(force, @answers) == :ok
      assert Task.await(restart, @answers) == :ok
      assert_receive {Runner, ^runner, {:restart, :cold}}
      assert %{status: :running, forces: %{"level" => 7}, forcing: nil} = Runner.status(runner)
      assert Runner.get!(runner, "level") == 7
      assert Runner.stop(runner) == :ok
    end

    # Decision 500 (RV-19), the readings decisions 509 and 508 take as built: a force
    # asked during the wait joins the next write, as decision 465 has every request behind
    # a write, and the restart reads the file the write it waited for left, the force
    # written after it; and a second restart asked meanwhile is taken once the first is
    # made, as it was when the wait was the runner's own, and finds the runner running,
    # refused as decision 133 refuses any.
    test "a force asked during the wait is written after the restart, and a second restart " <>
           "finds the line running",
         %{tmp_dir: dir} do
      rig = rig(dir, retain: nil, retain_period: nil, write_limit: @out)
      {:ok, runner} = Runner.start_link(rig.opts)
      server = held()
      first = Task.async(fn -> Runner.force(runner, "level", 7) end)
      _writing = waiting_call(server, :rename)
      Sim.fail(rig.panel, :read, {:error, :eio})
      Manual.advance(rig.clock, 10)
      restart = calling(Task.async(fn -> Runner.restart(runner, :warm) end))
      behind = calling(Task.async(fn -> Runner.force(runner, "eye_1", 1) end))

      again =
        calling(
          Task.async(fn ->
            assert_raise ArgumentError,
                         "the runner is running: restart/2 starts a runner again once it " <>
                           "has tripped",
                         fn -> Runner.restart(runner, :warm) end
          end)
        )

      assert %{status: :tripped, forces: %{}, forcing: %{"level" => 7}} = Runner.status(runner)
      :sys.resume(server)
      assert Task.await(first, @answers) == :ok
      assert Task.await(restart, @answers) == :ok
      assert %ArgumentError{} = Task.await(again, @answers)
      assert Task.await(behind, @answers) == :ok
      assert File.read!(rig.forces) == "eye_1 1\nlevel 7\n"
      assert %{status: :running, forces: %{"eye_1" => 1, "level" => 7}} = Runner.status(runner)
      assert Runner.stop(runner) == :ok
    end

    # RV-19's review, finding 1 (its probe P500a): decision 354 has a trip stand until a
    # restart asked after it. Two restarts wait for the write; the first is made, and its
    # own first round's write fails, tripping the line again: the second, asked before that
    # trip, is refused by it, in decision 133's words, the line left tripped, where taken
    # after the trip it found the runner tripped and was made, the trip cleared by a
    # restart asked before it. Where the first is refused, the line still tripped, the
    # second is made in turn, as when the wait was the runner's own.
    test "a second restart waiting is refused by a trip the first's own round meets, and " <>
           "made where the first is refused",
         %{tmp_dir: dir} do
      rig = rig(dir, retain: nil, retain_period: nil, write_limit: @out)
      {:ok, runner} = Runner.start_link(rig.opts)
      server = held()
      force = Task.async(fn -> Runner.force(runner, "level", 7) end)
      _writing = waiting_call(server, :rename)
      Sim.fail(rig.panel, :read, {:error, :eio})
      Manual.advance(rig.clock, 10)
      assert %{status: :tripped, trip: {:io, "panel", {:error, :eio}}} = Runner.status(runner)
      Sim.fail(rig.panel, :write, {:error, :eio})
      :ok = Runner.subscribe(runner, [:trip, :restart])
      first = calling(Task.async(fn -> Runner.restart(runner, :warm) end))

      second =
        calling(
          Task.async(fn ->
            assert_raise ArgumentError,
                         "the runner is running: restart/2 starts a runner again once it " <>
                           "has tripped",
                         fn -> Runner.restart(runner, :warm) end
          end)
        )

      :sys.resume(server)
      assert Task.await(force, @answers) == :ok
      assert Task.await(first, @answers) == :ok
      assert %ArgumentError{} = Task.await(second, @answers)
      assert_receive {Runner, ^runner, {:restart, :warm}}
      assert_receive {Runner, ^runner, {:trip, {:io, "panel", {:error, :eio}}}}
      refute_receive {Runner, ^runner, {:restart, _mode}}, 100
      assert %{status: :tripped, trip: {:io, "panel", {:error, :eio}}} = Runner.status(runner)

      server = held()
      again = Task.async(fn -> Runner.force(runner, "level", 3) end)
      _writing = waiting_call(server, :rename)
      Sim.fail(rig.panel, :read, {:error, :eio})
      refused = calling(Task.async(fn -> Runner.restart(runner, :warm) end))
      made = calling(Task.async(fn -> Runner.restart(runner, :warm) end))
      :sys.resume(server)
      assert Task.await(again, @answers) == :ok
      assert {:error, {:io_init, "panel", _cause}} = Task.await(refused, @answers)
      assert Task.await(made, @answers) == :ok
      assert %{status: :running, trip: nil, forces: %{"level" => 3}} = Runner.status(runner)
      assert Runner.stop(runner) == :ok
    end

    # Decision 500 (RV-19): an edit's step asked during the wait is served at once, the
    # restart made on the resource it leaves (provisional); and a stop meanwhile answers
    # the restart as one to a runner that is not running, a request behind the write as
    # decision 467 has it, the stop waiting for the write to its limit and answering its
    # callers as it ends.
    test "an edit's step during the wait is served at once, and a stop answers the waiting " <>
           "restart as not running",
         %{tmp_dir: dir} do
      rig = rig(dir, retain: nil, retain_period: nil, write_limit: @out)
      {:ok, runner} = Runner.start_link(rig.opts)
      server = held()
      force = Task.async(fn -> Runner.force(runner, "level", 7) end)
      _writing = waiting_call(server, :rename)
      Sim.fail(rig.panel, :read, {:error, :eio})
      Manual.advance(rig.clock, 10)

      restart =
        calling(
          Task.async(fn ->
            assert_raise ArgumentError,
                         "the runner #{inspect(runner)} is not running",
                         fn -> Runner.restart(runner, :warm) end
          end)
        )

      assert {:ok, _forecast} = Runner.accept(runner, configured())
      assert %{status: :tripped, edit: :accepted} = Runner.status(runner)
      assert {:ok, _report} = Runner.cancel(runner)
      assert %{status: :tripped, edit: nil} = Runner.status(runner)
      assert Task.yield(restart, 0) == nil

      stop = Task.async(fn -> Runner.stop(runner) end)
      assert %ArgumentError{} = Task.await(restart, @answers)
      assert Task.yield(stop, 0) == nil
      :sys.resume(server)
      assert Task.await(stop, @answers) == :ok
      assert Task.await(force, @answers) == :ok
    end

    # RV-18's review, finding 2 (its mutant r06): only a tripped runner's restart waits;
    # one asked while the runner runs is the host's mistake, raised at once whatever write
    # is out, as decision 473 has a forcing request's, the write and the request behind it
    # left as they were and written in turn.
    test "a restart asked while the runner runs is raised at once, the write out and the " <>
           "requests behind it written in turn",
         %{tmp_dir: dir} do
      rig = rig(dir, retain: nil, retain_period: nil, write_limit: @out)
      {:ok, runner} = Runner.start_link(rig.opts)
      server = held()
      first = Task.async(fn -> Runner.force(runner, "level", 7) end)
      _writing = waiting_call(server, :rename)
      behind = calling(Task.async(fn -> Runner.force(runner, "eye_1", 1) end))

      restart =
        Task.async(fn ->
          assert_raise ArgumentError,
                       "the runner is running: restart/2 starts a runner again once it has " <>
                         "tripped",
                       fn -> Runner.restart(runner, :warm) end
        end)

      assert {:ok, %ArgumentError{}} = Task.yield(restart, @answers)
      assert Task.yield(first, 0) == nil
      assert %{forcing: %{"level" => 7}} = Runner.status(runner)
      :sys.resume(server)
      assert Task.await(first, @answers) == :ok
      assert Task.await(behind, @answers) == :ok
      assert File.read!(rig.forces) == "eye_1 1\nlevel 7\n"
      assert %{forces: %{"eye_1" => 1, "level" => 7}, forcing: nil} = Runner.status(runner)
      assert Runner.stop(runner) == :ok
    end
  end

  # Decision 445 (RV-16): while `forces_unread` stands a restart keeps the forces the
  # runner holds and takes none from the file, and the next write of the file, a force's
  # or an unforce's, writes the runner's set over it, so that no force comes back that the
  # HMI was not showing, where a restart that read the file took what it held.
  describe "a restart while the forces file is named unread (decision 445)" do
    test "the level forced to 7, a crash, a start on a stalled disk, the disk back, a trip " <>
           "and a restart: level reads its input, not 7",
         %{tmp_dir: dir} do
      rig = rig(dir, retain: nil, retain_period: nil)
      {:ok, runner} = Runner.start_link(rig.opts)
      Process.unlink(runner)
      assert Runner.force(runner, "level", 7) == :ok
      assert File.read!(rig.forces) == "level 7\n"
      ref = Process.monitor(runner)
      Process.exit(runner, :kill)
      assert_receive {:DOWN, ^ref, :process, ^runner, :killed}, @answers

      # The next start finds the disk stalled at the forces file, its raw read waiting on a
      # FIFO in its place past its limit, and starts with no force, the file named.
      File.rm!(rig.forces)
      {_, 0} = System.cmd("mkfifo", [rig.forces])
      on_exit(fn -> let_go(rig.forces) end)
      next = rig(dir, retain: nil, retain_period: nil)
      {:ok, runner} = Runner.start_link(next.opts)
      forces = next.forces
      assert %{forces: %{}, forces_unread: {^forces, :timeout}} = Runner.status(runner)

      # The disk back, the file as the crash left it, `level 7`; the level reads its input.
      let_go(forces)
      File.rm!(forces)
      File.write!(forces, "level 7\n")
      Sim.set(next.panel, [1], 3)
      Manual.advance(next.clock, 10)
      assert Runner.get!(runner, "level") == 3

      # A trip and a restart: the file named still, the restart takes none of it, and the
      # level reads its input, 3, never the 7 no one has forced since the start.
      Sim.fail(next.panel, :read, {:error, :eio})
      Manual.advance(next.clock, 10)
      assert %{status: :tripped} = Runner.status(runner)
      assert Runner.restart(runner, :warm) == :ok

      assert %{status: :running, forces: %{}, forces_unread: {^forces, :timeout}} =
               Runner.status(runner)

      assert Runner.get!(runner, "level") == 3
      Manual.advance(next.clock, 10)
      assert Runner.get!(runner, "level") == 3

      # The next force's write writes the runner's set over the file, `level 7` gone with
      # it, and the file is named no more.
      assert Runner.force(runner, "eye_1", 1) == :ok
      assert File.read!(forces) == "eye_1 1\n"
      assert %{forces: %{"eye_1" => 1}, forces_unread: nil} = Runner.status(runner)
      assert Runner.stop(runner) == :ok
    end
  end

  # Decision 472 (RV-18): an orderly stop, `stop/2` or a supervisor's shutdown, while
  # `forces_unread` stands writes the runner's own set to the forces file before it ends,
  # within the write limit, so that the next start brings back nothing the HMI was not
  # showing, as decision 445 has a restart; a stop whose write fails says so; a crash
  # writes nothing. Each begins as decision 445's test does: `level` forced to 7, a
  # crash, a fresh start that cannot read the file, the disk back with the file as the
  # crash left it.
  describe "a stop while the forces file is named unread (decision 472)" do
    defp unread_start(dir, extra \\ []) do
      rig = rig(dir, retain: nil, retain_period: nil)
      {:ok, runner} = Runner.start_link(rig.opts)
      Process.unlink(runner)
      assert Runner.force(runner, "level", 7) == :ok
      ref = Process.monitor(runner)
      Process.exit(runner, :kill)
      assert_receive {:DOWN, ^ref, :process, ^runner, :killed}, @answers
      File.rm!(rig.forces)
      {_, 0} = System.cmd("mkfifo", [rig.forces])
      next = rig(dir, Keyword.merge([retain: nil, retain_period: nil], extra))
      {:ok, runner} = Runner.start_link(next.opts)
      Process.unlink(runner)
      forces = next.forces
      assert %{forces: %{}, forces_unread: {^forces, :timeout}} = Runner.status(runner)
      let_go(forces)
      File.rm!(forces)
      File.write!(forces, "level 7\n")
      {runner, next}
    end

    test "stop/2 writes the runner's set, and the next start brings back no force",
         %{tmp_dir: dir} do
      {runner, rig} = unread_start(dir)
      assert Runner.stop(runner) == :ok
      assert File.read!(rig.forces) == ""

      {:ok, runner} = Runner.start_link(rig(dir, retain: nil, retain_period: nil).opts)
      assert %{forces: %{}, forces_unread: nil} = Runner.status(runner)
      assert Runner.stop(runner) == :ok
    end

    test "a supervisor's shutdown writes the runner's set too", %{tmp_dir: dir} do
      {runner, rig} = unread_start(dir)
      Process.flag(:trap_exit, true)
      Process.link(runner)
      Process.exit(runner, :shutdown)
      assert_receive {:EXIT, ^runner, :shutdown}, @answers
      assert File.read!(rig.forces) == ""
    end

    test "a crash writes nothing, the file as it stood", %{tmp_dir: dir} do
      {runner, rig} = unread_start(dir)
      ref = Process.monitor(runner)
      Process.exit(runner, :kill)
      assert_receive {:DOWN, ^ref, :process, ^runner, :killed}, @answers
      assert File.read!(rig.forces) == "level 7\n"
    end

    # RV-18's review, finding 2 (its mutant r08): a crash whose terminate/2 runs, a stop
    # for a reason no orderly end gives, writes nothing either, where the test above, a
    # kill, never reaches terminate/2.
    test "a crash that runs terminate/2 writes nothing too", %{tmp_dir: dir} do
      {runner, rig} = unread_start(dir)
      ref = Process.monitor(runner)
      assert GenServer.stop(runner, :boom) == :ok
      assert_receive {:DOWN, ^ref, :process, ^runner, :boom}, @answers
      assert File.read!(rig.forces) == "level 7\n"
    end

    test "the runner's set as it stands at the stop, a force since among it", %{tmp_dir: dir} do
      {runner, rig} = unread_start(dir)

      # A force's write lands, the runner's set over the file, and the file named no
      # more: the stop then writes nothing of its own.
      assert Runner.force(runner, "eye_1", 1) == :ok
      assert %{forces_unread: nil} = Runner.status(runner)
      File.write!(rig.forces, "eye_1 1\nlevel 7\n")
      assert Runner.stop(runner) == :ok
      assert File.read!(rig.forces) == "eye_1 1\nlevel 7\n"
    end

    test "a stop whose write fails answers so, and one cut at its limit too",
         %{tmp_dir: dir} do
      {runner, rig} = unread_start(dir)
      File.mkdir!(rig.forces <> ".tmp")
      assert Runner.stop(runner) == {:error, {:forces, :eisdir}}
      assert File.read!(rig.forces) == "level 7\n"
      File.rmdir!(rig.forces <> ".tmp")

      File.mkdir!(Path.join(dir, "cut"))
      {runner, _rig} = unread_start(Path.join(dir, "cut"))
      server = held()
      assert {took, {:error, {:forces, :timeout}}} = timed(fn -> Runner.stop(runner) end)
      assert took >= @limit and took < @answers
      :sys.resume(server)
    end

    # RV-18's review, finding 2 (its mutant r09). Decision 493 (RV-19): where both the
    # forces file's write and the store's fail, stop/2 answers both in one error, in the
    # order they were written, where it answered the store's failure alone and the forces
    # file's went untold.
    test "a stop whose two writes both fail answers both", %{tmp_dir: dir} do
      store = Path.join(dir, "both.retain")
      {runner, rig} = unread_start(dir, retain: store, retain_period: 3_600_000)
      File.mkdir!(rig.forces <> ".tmp")
      File.mkdir!(store <> ".tmp")
      assert Runner.stop(runner) == {:error, [forces: :eisdir, retain: :eisdir]}
      assert File.read!(rig.forces) == "level 7\n"
    end

    # Decision 493 (RV-19): where only one fails it is answered as it stands, the store's
    # alone `{:error, {:retain, reason}}`; and writes cut at their limit on a stalled disk
    # are answered so, both in the list, `:timeout` each.
    test "a stop whose store's write alone fails answers it alone, and two writes cut are " <>
           "both answered",
         %{tmp_dir: dir} do
      store = Path.join(dir, "store.retain")
      {runner, _rig} = unread_start(dir, retain: store, retain_period: 3_600_000)
      File.mkdir!(store <> ".tmp")
      assert Runner.stop(runner) == {:error, {:retain, :eisdir}}
      File.rmdir!(store <> ".tmp")

      File.mkdir!(Path.join(dir, "cut"))
      cut = Path.join([dir, "cut", "store.retain"])
      {runner, _rig} = unread_start(Path.join(dir, "cut"), retain: cut, retain_period: 3_600_000)
      server = held()

      assert {took, {:error, [forces: :timeout, retain: :timeout]}} =
               timed(fn -> Runner.stop(runner) end)

      assert took >= 2 * @limit and took < @answers
      :sys.resume(server)
    end

    # Decision 493 (RV-19): a shutdown, which no caller waits on, publishes the forces
    # file's failure to the subscribers, `{:forces, {:error, reason}}`, a default kind, as
    # it publishes the store's, so that an HMI or a log can warn that the next start may
    # bring back an old force, where it told it to no one; and a stop/2 publishes it too,
    # besides its answer, the store's after it.
    test "a shutdown publishes the forces file's failure, and a stop too", %{tmp_dir: dir} do
      store = Path.join(dir, "end.retain")
      {runner, rig} = unread_start(dir, retain: store, retain_period: 3_600_000)
      :ok = Runner.subscribe(runner)
      File.mkdir!(rig.forces <> ".tmp")
      File.mkdir!(store <> ".tmp")
      Process.flag(:trap_exit, true)
      Process.link(runner)
      Process.exit(runner, :shutdown)
      assert_receive {:EXIT, ^runner, :shutdown}, @answers
      assert_received {Runner, ^runner, {:forces, {:error, :eisdir}}}
      assert_received {Runner, ^runner, {:retain, {:error, :eisdir}}}
      assert File.read!(rig.forces) == "level 7\n"

      File.mkdir!(Path.join(dir, "stop"))
      {runner, rig} = unread_start(Path.join(dir, "stop"))
      :ok = Runner.subscribe(runner, [:forces])
      File.mkdir!(rig.forces <> ".tmp")
      assert Runner.stop(runner) == {:error, {:forces, :eisdir}}
      assert_received {Runner, ^runner, {:forces, {:error, :eisdir}}}
      refute_received {Runner, ^runner, _other}
    end
  end

  # Decision 475 (RV-18): a runner's claim on its forces file, and on its store, is held
  # until every write of it the runner began has ended, so that no runner of the VM starts
  # on the file meanwhile, a start then refused naming the file held: a write cut at its
  # limit, its process killed, may still have its rename in the VM's file server's queue,
  # which lands once the disk answers, and a runner started on the file before then read
  # the old set, the operator told the force had failed, and the next restart took it
  # (RV-16's review, its probe T4). A holder of logex's own holds the file for the runner
  # that ended until the server has answered a call made after the cut.
  describe "a runner's files held until its writes have ended (decision 475)" do
    defp forces_held_told(rig, runner, holder),
      do:
        "the runner's forces: #{inspect(rig.forces)} names the forces file of a runner " <>
          "of this VM that has stopped, #{inspect(runner)}, held by #{inspect(holder)} " <>
          "until a write of it that runner cut at its write limit has ended, which may " <>
          "yet land: two runners on one file write each over the other's"

    defp holder_of(path) do
      [{^path, holder, _role}] = :ets.lookup(Logex.Runner.Paths, path)
      holder
    end

    # A force whose write the test needs landed, asked again where the write was cut at
    # the rig's short limit, a loaded machine slow over it, the file server not held: a
    # later write that lands has had every call of the cut one answered before its own
    # (decision 475), so that the file holds the runner's set, and nothing of the cut one
    # is left in the server's mailbox for a held server's wait to take for the test's.
    # The short limit is the test's to cut the write it holds; one landing was met past
    # it at a load average of 30 (RV-18's load runs).
    defp landed(runner, name, value),
      do: landed(Runner.force(runner, name, value), runner, name, value, 10)

    defp landed(:ok, _runner, _name, _value, _tries), do: :ok

    defp landed({:error, {:forces, :timeout}}, runner, name, value, tries) when tries > 1,
      do: landed(Runner.force(runner, name, value), runner, name, value, tries - 1)

    test "a stop that cuts a force's write holds the file until it lands, and the next " <>
           "start then reads what it left",
         %{tmp_dir: dir} do
      rig = rig(dir, retain: nil, retain_period: nil, write_limit: 300)
      {:ok, runner} = Runner.start_link(rig.opts)
      assert landed(runner, "level", 7) == :ok
      server = held()
      force = Task.async(fn -> stop_answer_of(fn -> Runner.force(runner, "eye_1", 1) end) end)
      _writing = waiting_call(server, :rename)
      assert Runner.stop(runner) == :ok
      assert Task.await(force, @answers) == {:error, {:forces, :timeout}}

      # The file held for the stopped runner: a start on it refused, naming it.
      holder = holder_of(rig.forces)
      assert Paths.ended_runner(holder) == runner
      next = rig(dir, retain: nil, retain_period: nil, write_limit: @out)

      assert_raise ArgumentError, forces_held_told(next, runner, holder), fn ->
        Runner.start_link(next.opts)
      end

      # The disk back: the cut write's rename lands, the holder ends, and the next start
      # reads the file as the write left it, the force its operator was told had failed
      # in effect and listed, where it came back unseen at a later restart.
      ref = Process.monitor(holder)
      :sys.resume(server)
      assert_receive {:DOWN, ^ref, :process, ^holder, :normal}, @answers
      assert File.read!(rig.forces) == "eye_1 1\nlevel 7\n"
      {:ok, runner} = Runner.start_link(next.opts)
      assert %{forces: %{"eye_1" => 1, "level" => 7}} = Runner.status(runner)
      assert Runner.stop(runner) == :ok
    end

    test "a force's write cut while the runner ran holds the file at its stop; a write " <>
           "that lands after it frees it at once",
         %{tmp_dir: dir} do
      rig = rig(dir, retain: nil, retain_period: nil, write_limit: 300)
      {:ok, runner} = Runner.start_link(rig.opts)
      server = held()
      assert Runner.force(runner, "level", 7) == {:error, {:forces, :timeout}}
      assert Runner.stop(runner) == :ok
      holder = holder_of(rig.forces)
      assert Paths.ended_runner(holder) == runner
      ref = Process.monitor(holder)
      :sys.resume(server)
      assert_receive {:DOWN, ^ref, :process, ^holder, :normal}, @answers

      # A later write of the file that lands, every call before its own answered, frees
      # the file as the runner stops.
      {:ok, runner} = Runner.start_link(rig.opts)
      server = held()
      assert Runner.force(runner, "level", 7) == {:error, {:forces, :timeout}}
      :sys.resume(server)
      assert landed(runner, "level", 3) == :ok
      assert Runner.stop(runner) == :ok
      assert Paths.held([{rig.forces, :forces}]) == :ok
      {:ok, runner} = Runner.start_link(rig.opts)
      assert Runner.stop(runner) == :ok
    end

    # RV-18's review, finding 2 (its mutant r15): a later write that fails by itself has
    # had every call before its own answered too, the cut one's among them, so it frees
    # the file as one that lands does: the runner's stop, the file server held again,
    # hands nothing to a holder.
    test "a write that fails after a cut one frees the file at the stop as one that lands",
         %{tmp_dir: dir} do
      rig = rig(dir, retain: nil, retain_period: nil, write_limit: 300)
      {:ok, runner} = Runner.start_link(rig.opts)
      server = held()
      assert Runner.force(runner, "level", 7) == {:error, {:forces, :timeout}}
      :sys.resume(server)
      _ = :sys.get_state(server)
      File.rm(rig.forces <> ".tmp")
      File.mkdir!(rig.forces <> ".tmp")
      assert Runner.force(runner, "level", 3) == {:error, {:forces, :eisdir}}
      File.rmdir!(rig.forces <> ".tmp")
      server = held()
      assert Runner.stop(runner) == :ok
      assert Paths.held([{rig.forces, :forces}]) == :ok
      :sys.resume(server)
    end

    test "a stop whose store's write is cut holds the store, and a start whose first " <>
           "write is cut holds it too",
         %{tmp_dir: dir} do
      rig = rig(dir, forces: nil)
      {:ok, runner} = Runner.start_link(rig.opts)
      server = held()
      assert Runner.stop(runner) == {:error, {:retain, :timeout}}
      holder = holder_of(rig.store)
      assert Paths.ended_runner(holder) == runner
      assert {:held, _path, ^holder, _role} = Paths.held([{rig.store <> ".tmp", {:tmp, :retain}}])
      ref = Process.monitor(holder)
      :sys.resume(server)
      assert_receive {:DOWN, ^ref, :process, ^holder, :normal}, @answers

      server = held()
      parent = self()

      start =
        spawn(fn -> send(parent, {:started, Runner.start_link(rig.opts ++ [start: :cold])}) end)

      assert_receive {:started, {:error, {:retain, :timeout}}}, @answers
      holder = holder_of(rig.store)
      assert Paths.ended_runner(holder) not in [nil, start]
      ref = Process.monitor(holder)
      :sys.resume(server)
      assert_receive {:DOWN, ^ref, :process, ^holder, :normal}, @answers
      assert Paths.held([{rig.store, :retain}]) == :ok
    end

    # RV-18's review, finding 1, the leave of decision 475 (a runner's claim given up at
    # its end with a write still out): this test was "a crash holds nothing, as before",
    # which asserted the killed runner's file free, `Paths.held/1` `:ok`, while the
    # force's write it cut could still land. A killed runner runs no terminate/2 and hands
    # nothing on, so its claim stands under its dead pid, told to a start as left, and the
    # start takes the file only once the file server has answered a look behind every
    # call the killed writes left in its queue (RV-16's probe T5, the review's 475K).
    test "a runner killed with a write out leaves the file to a start's look at the file " <>
           "server: refused past its limit, the next reading what the write left",
         %{tmp_dir: dir} do
      rig = rig(dir, retain: nil, retain_period: nil, write_limit: 300)
      {:ok, runner} = Runner.start_link(rig.opts)
      Process.unlink(runner)
      assert landed(runner, "level", 7) == :ok
      server = held()
      unforce = Task.async(fn -> stop_answer_of(fn -> Runner.unforce(runner, "level") end) end)
      _writing = renaming(server, runner)
      ref = Process.monitor(runner)
      Process.exit(runner, :kill)
      assert_receive {:DOWN, ^ref, :process, ^runner, :killed}, @answers
      assert Task.await(unforce, @answers) == gone_told(runner)
      forces = rig.forces
      assert Paths.held([{forces, :forces}]) == {:left, forces, runner, :forces}
      assert :file.read_file(forces, [:raw]) == {:ok, "level 7\n"}

      # A start meanwhile: its look waits behind the unforce's rename past its limit, and
      # it is refused, the file named left, nothing read.
      next = rig(dir, retain: nil, retain_period: nil, write_limit: 300)
      assert {took, message} = timed(fn -> start_refused(next.opts) end)
      assert message == forces_left_told(next, runner, 300)
      assert took >= 300 and took < @answers

      # One whose look the disk answers: the unforce's rename lands first, and the start
      # reads the file as it left it, `level` forced no more, where it read `level 7`
      # and showed a force the file no longer held.
      later = rig(dir, retain: nil, retain_period: nil, write_limit: @out)
      parent = self()

      spawn(fn ->
        {:ok, started} = Runner.start_link(later.opts)
        Process.unlink(started)
        send(parent, {:started, started})
      end)

      looking(server, forces)
      :sys.resume(server)
      assert_receive {:started, runner}, @answers
      assert File.read!(forces) == ""
      assert %{forces: %{}, forces_unknown: nil, forces_unread: nil} = Runner.status(runner)
      assert Runner.stop(runner) == :ok
      assert Paths.held([{forces, :forces}]) == :ok
    end

    test "a runner killed with nothing out leaves the file to a start at once, and a holder " <>
           "killed leaves its file to the same look",
         %{tmp_dir: dir} do
      rig = rig(dir, retain: nil, retain_period: nil, write_limit: 300)
      {:ok, runner} = Runner.start_link(rig.opts)
      Process.unlink(runner)
      assert landed(runner, "level", 7) == :ok
      ref = Process.monitor(runner)
      Process.exit(runner, :kill)
      assert_receive {:DOWN, ^ref, :process, ^runner, :killed}, @answers
      forces = rig.forces
      assert Paths.held([{forces, :forces}]) == {:left, forces, runner, :forces}
      {:ok, runner} = Runner.start_link(rig(dir, retain: nil, retain_period: nil).opts)
      assert %{forces: %{"level" => 7}} = Runner.status(runner)

      # A stop that cuts a force's write hands the file to a holder; the holder killed by
      # the host, the cut write still out, leaves the file to a start's look as a killed
      # runner does, where the file was free at once.
      server = held()
      assert Runner.force(runner, "eye_1", 1) == {:error, {:forces, :timeout}}
      assert Runner.stop(runner) == :ok
      holder = holder_of(forces)
      ref = Process.monitor(holder)
      Process.exit(holder, :kill)
      assert_receive {:DOWN, ^ref, :process, ^holder, :killed}, @answers
      assert Paths.held([{forces, :forces}]) == {:left, forces, holder, :forces}
      next = rig(dir, retain: nil, retain_period: nil, write_limit: 300)
      assert forces_left_told(next, holder, 300) == start_refused(next.opts)
      :sys.resume(server)
      {:ok, runner} = Runner.start_link(next.opts)
      assert %{forces: %{"eye_1" => 1, "level" => 7}} = Runner.status(runner)
      assert Runner.stop(runner) == :ok
    end
  end

  defp forces_left_told(rig, gone, ms),
    do:
      "the runner's forces: #{inspect(rig.forces)} names the forces file of " <>
        "#{inspect(gone)}, a process of this VM that ended without giving it up: a write of " <>
        "it may still wait in the VM's file server, which has not answered a look behind it " <>
        "within the write limit, #{ms} ms (write_limit:), and may yet land"

  # Every one of `n` forcing requests waiting behind the write that is out.
  defp all_behind(runner, n),
    do: behind_counted(:queue.len(:sys.get_state(runner).behind), runner, n)

  defp behind_counted(n, _runner, n), do: :ok

  defp behind_counted(_fewer, runner, n) do
    Process.sleep(1)
    all_behind(runner, n)
  end

  # A start's look at `path` through the held file server, once one from a live process
  # waits there: a refused start's look, killed at its limit, left behind it, is passed by.
  defp looking(server, path), do: looked_for(Process.info(server, :messages), server, path)

  defp looked_for({:messages, messages}, server, path),
    do: looker(Enum.any?(messages, &live_look?(&1, path)), server, path)

  defp live_look?({:"$gen_call", {pid, _tag}, {:read_link_info, at}}, path),
    do: IO.chardata_to_string(at) == path and Process.alive?(pid)

  defp live_look?(_message, _path), do: false

  defp looker(true, _server, _path), do: :ok

  defp looker(false, server, path) do
    Process.sleep(1)
    looking(server, path)
  end

  # Real time slept past a write's limit, where one is out.
  defp past(nil), do: :ok

  defp past(%{until: until}),
    do: Process.sleep(max(until - System.monotonic_time(:millisecond), 0) + 20)

  # The status once a round has run past `before`, polled until `deadline`.
  defp rounds_past(runner, before, deadline),
    do: past(Runner.status(runner), runner, before, deadline)

  defp past(%{rounds: rounds} = status, _runner, before, _deadline) when rounds > before,
    do: status

  defp past(_status, runner, before, deadline) do
    assert System.monotonic_time(:millisecond) < deadline, "no round ran while the write was out"
    Process.sleep(10)
    rounds_past(runner, before, deadline)
  end

  # The panel's lamp once a round has written it on, polled until `deadline`.
  defp lamp_on(panel, deadline), do: lamp(Sim.outputs(panel), panel, deadline)

  defp lamp(%{[0] => 1}, _panel, _deadline), do: 1

  defp lamp(_outputs, panel, deadline) do
    assert System.monotonic_time(:millisecond) < deadline, "the force was never read"
    Process.sleep(10)
    lamp_on(panel, deadline)
  end

  # A task once its call has been sent, waiting for the answer, so that a request the test
  # makes after it comes behind it in the runner's mailbox.
  defp calling(task), do: in_call(Process.info(task.pid, :current_function), task)

  defp in_call({:current_function, {:gen, :do_call, 4}}, task), do: task

  defp in_call(_elsewhere, task) do
    Process.sleep(1)
    calling(task)
  end

  defp stop_answer_of(call) do
    call.()
  rescue
    error in ArgumentError -> {:raised, error.message}
  end

  # A start made in a process of its own that this one traces, a process cannot trace its
  # own calls, kept alive, the runner's parent, until the test is done with it.
  defp traced_start(opts) do
    parent = self()
    ref = make_ref()

    caller =
      spawn(fn ->
        receive do
          :go -> send(parent, {ref, Runner.start_link(opts)})
        end

        receive do
          :done -> :ok
        end
      end)

    :erlang.trace(caller, true, [:call])
    send(caller, :go)
    assert_receive {^ref, started}, 5000
    :erlang.trace(caller, false, [:call])
    {caller, started}
  end

  defp traced_calls(caller) do
    receive do
      {:trace, ^caller, :call, mfa} -> [mfa | traced_calls(caller)]
    after
      0 -> []
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
          rig(Path.join(dir, "#{System.unique_integer([:positive])}"),
            forces: nil,
            write_limit: 5000
          )

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
        assert text =~ ~r/\Alogex retain 2\nconfiguration plant written /
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
