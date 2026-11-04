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
    # status/1, where the start was refused, an ArgumentError naming the file.
    test "a start whose forces file's read does not end within its limit starts with no " <>
           "force, naming the file, and every other file call answers meanwhile (decision 390)",
         %{tmp_dir: dir} do
      rig = rig(dir)
      {_, 0} = System.cmd("mkfifo", [rig.forces])
      on_exit(fn -> let_go(rig.forces) end)

      # The read raw, off the VM's file server, so that another process's file call, made
      # while the start waits on the FIFO, answers, where a read through the server held
      # it and every other file call of the VM's for as long as the FIFO had no writer. The
      # start is the test's own, so that the runner it starts is its child.
      other = Path.join(dir, "other")

      call =
        Task.async(fn ->
          reading_raw()
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
      # the killed copy where that landed, none replaced.
      :sys.resume(server)
      assert File.read!(rig.store) == read
      landed = File.read(copy)
      assert landed in [{:ok, read}, {:error, :enoent}]
      assert Runner.stop(runner) == :ok
      owed = owed_copy(landed, rig.store)
      assert File.read!(owed) == read
      assert File.read(copy) == {:ok, read}
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

  # Decision 418: the copy a stop made of a copy owed, past one that landed late.
  defp owed_copy({:ok, _read}, store), do: store <> ".dropped.2"
  defp owed_copy({:error, :enoent}, store), do: store <> ".dropped.1"

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

    test "a force's: the set it held unknown until a later write of the file lands, " <>
           "fails or a restart reads it",
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

      # Past its limit once more; then a restart reads the file, and knows what it holds.
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
      # Decision 440 (RV-16), the leave for the key absent: always there, nil.
      assert status.forces_unknown == nil
      assert status.forces in [%{"level" => 7}, %{"eye_1" => 1, "level" => 7}]
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
      # replaced.
      made = owed_copy(File.read(copy), rig.store)
      server = held()
      restart = Task.async(fn -> Runner.restart(runner, :cold) end)
      assert {:called, _copying} = called_or_answered(server, :rename, restart)
      :sys.resume(server)
      :sys.suspend(server)
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
  # past the host's file (provisional: failed and owed, where it could take the next free
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
    # and named (provisional, a question to the maintainer: decision 418 has none
    # replaced, and the rename that refuses a name that stands, a hard link, is not on
    # every card's file system).
    test "a file a host makes at the copy's number after the copy looked, as its rename " <>
           "waits, is replaced (provisional)",
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
  # place, can be copied by no start, the same (provisional).
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
      assert_receive {Runner, ^runner, {:trip, {:watchdog, {:idle, 3}}}}, @answers
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

    # The record is silent on a second force while one's write is out: it waits behind it,
    # in order, its write built on the set the first left (provisional).
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

    # A trip, a restart and an edit's step made while a force's write is out leave it as
    # it was: it is taken onto the set the runner then holds once it lands, and read from
    # the first round after it, a restart's first round, which reads the file as every
    # start does, among them where it came first.
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

      # A restart while it is out: the restart reads the file as it stands, raw, the old
      # set, and the force is taken once it lands, read from the next round on.
      Sim.fail(rig.panel, :read, {:error, :eio})
      Manual.advance(rig.clock, 10)
      server = held()
      unforce = Task.async(fn -> Runner.unforce(runner, "eye_1") end)
      _writing = waiting_call(server, :rename)
      assert Runner.restart(runner, :warm) == :ok
      assert %{status: :running, forces: %{"eye_1" => 1}} = Runner.status(runner)
      assert Sim.outputs(rig.panel) == %{[0] => 1}
      :sys.resume(server)
      assert Task.await(unforce, @answers) == :ok
      assert File.read!(rig.forces) == ""
      assert %{forces: %{}} = Runner.status(runner)
      Manual.advance(rig.clock, 10)
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
    # waited behind it is answered as to a runner that is not running (provisional).
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
