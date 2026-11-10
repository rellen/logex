defmodule Logex.RetainPeriodTest do
  # M6-6 (docs/organisation.md §4.13, decision 275): the periodic writer, a runner given
  # `retain:` writing its store every `retain_period:` ms from the resource between rounds,
  # through a writer process of its own, latest wins, all on the manual clock. Not async:
  # its tests trace the writer's calls, and a trace pattern is global.
  use ExUnit.Case, async: false

  alias Logex.{Configuration, Runner, Runtime}
  alias Logex.IO.Sim
  alias Logex.Runner.Clock.Manual

  @moduletag :tmp_dir
  @moduletag capture_log: true

  # retain_store_test.exs's box counter: a retained count, a retained total it adds to
  # through its var_external, and a retained lamp it latches.
  @tally """
  var_input eye bool
  var_input clear bool
  var_external total_boxes dint
  var_output retain lamp bool
  var_output count dint
  var retain boxes ctu
  var e bool

  xic eye ctu boxes 1000
  xic eye ons e add total_boxes 1 total_boxes
  move boxes.cv count
  xic eye otl lamp
  xic clear otu lamp
  """

  @globals """
  var_global eye_1 bool at panel.i.0
  var_global clr bool at panel.i.1
  var_global lamp_q bool at panel.q.0
  var_global retain total_boxes dint 0
  var_global shown dint
  """

  @wired """
    t1.eye eye_1
    t1.clear clr
    t1.count shown
    t1.lamp lamp_q
  """

  # Timed only: the fast task every 10 ms.
  @plant "task fast interval 10 priority 1\n" <>
           @globals <> "program t1 tally with fast\n" <> @wired

  # Untimed: the box counter in the continuous task, its rounds back to back.
  @untimed "task main continuous\n" <> @globals <> "program t1 tally\n" <> @wired

  # The hidden seam's steps, each round's start and each period's take-out told to the
  # test with the clock's time from the start, and a step made slow once where the test
  # asks, the clock passing inside it.
  defmodule Watched do
    alias Logex.Runtime
    alias Logex.Runner.Clock.Manual

    def cycle_steps(runtime, elapsed, inputs) do
      send(test(), {:round, at()})
      Runtime.cycle_steps(runtime, elapsed, inputs)
    end

    def cycle_step(runtime, step) do
      slow(:persistent_term.get({__MODULE__, :slow, test()}, nil))
      Runtime.cycle_step(runtime, step)
    end

    def cycle_outputs(runtime), do: Runtime.cycle_outputs(runtime)

    def retained(runtime) do
      send(test(), {:taken, at()})
      Runtime.retained(runtime)
    end

    defp slow(nil), do: :ok

    defp slow(ms) do
      :persistent_term.erase({__MODULE__, :slow, test()})
      Manual.pass(clock(), ms)
    end

    defp test, do: hd(Process.get(:"$ancestors"))
    defp clock, do: :persistent_term.get({__MODULE__, test()})
    defp at, do: Manual.now_ms(clock()) - Logex.RetainPeriodTest.wall()
  end

  # A clock started at a time a store's header names to the second, 2026-10-30T14:00:00Z.
  @wall 1_793_368_800_000
  def wall, do: @wall

  defp programs do
    {:ok, tally} = Logex.compile(@tally, name: "tally")
    %{"tally" => tally}
  end

  defp configured(source \\ @plant) do
    {:ok, config} = Configuration.compile("plant", source, programs())
    config
  end

  defp rig(dir, extra \\ []) do
    {:ok, clock} = Manual.start_link(now: @wall)
    {:ok, panel} = Sim.start_link(clock: clock)
    store = Path.join(dir, "plant.retain")
    :persistent_term.put({Watched, self()}, clock)
    on_exit(fn -> :persistent_term.erase({Watched, self()}) end)

    opts =
      Keyword.merge(
        [
          configuration: configured(),
          io: %{"panel" => {Sim, sim: panel}},
          clock: {Manual, clock},
          poll: 10,
          retain: store,
          retain_period: 100
        ],
        extra
      )

    %{clock: clock, panel: panel, store: store, opts: opts}
  end

  defp eye(%{panel: panel, clock: clock}, eye, ms) do
    Sim.set(panel, [0], eye)
    Manual.advance(clock, ms)
  end

  defp total(store),
    do:
      hd(
        Regex.run(~r/global total_boxes dint (\d+)\n/, File.read!(store), capture: :all_but_first)
      )

  defp values(runner),
    do: for(path <- ~w(total_boxes t1.boxes.cv t1.lamp shown), do: Runner.get!(runner, path))

  defp killed(runner) do
    Process.unlink(runner)
    ref = Process.monitor(runner)
    Process.exit(runner, :kill)
    assert_receive {:DOWN, ^ref, :process, _, :killed}
  end

  # The sim's opener gone down, so that a runner started on it again can open it (commit
  # 2adf13a).
  defp opener_down(panel), do: down(GenServer.call(panel, :holder))

  defp down(nil), do: :ok

  defp down({pid, _device}) do
    ref = Process.monitor(pid)
    assert_receive {:DOWN, ^ref, :process, _, _}, 5000
  end

  # The runner's writer, among its links, nil before the first period's write.
  defp writer(runner) do
    {:links, links} = Process.info(runner, :links)

    Enum.find(
      links,
      &(initial_call(Process.info(&1, :dictionary)) == {Logex.Runner.Writer, :init, 1})
    )
  end

  defp initial_call({:dictionary, dictionary}), do: dictionary[:"$initial_call"]
  defp initial_call(nil), do: nil

  # The writer's write handed on and answered, and the runner past its answer, twice, so
  # that an image that waited behind it is written too.
  defp synced(runner) do
    for _ <- 1..2 do
      _ = :sys.get_state(writer(runner))
      _ = :sys.get_state(runner)
    end
  end

  defp raises(message, fun), do: assert_raise(ArgumentError, message, fun)

  # What stands at the store's `.tmp` before the period's write: a leftover, so that the
  # write's first call through the file server is its delete of it, or nothing, so that
  # it is the rename.
  defp leftover(:delete, beside), do: File.write!(beside, "left over\n")
  defp leftover(:rename, _beside), do: :ok

  # The store after a write killed in its delete, the old whole, or in its rename, the
  # new whole.
  defp stored(:delete, text, before), do: text == before
  defp stored(:rename, text, before), do: text != before and total_in(text) == "2"

  defp total_in(text),
    do: hd(Regex.run(~r/global total_boxes dint (\d+)\n/, text, capture: :all_but_first))

  # The process whose call of `kind` waits in the held file server's mailbox, once one does.
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

  # Every message the seam sent, in order, from the mailbox.
  defp seen(acc \\ []) do
    receive do
      {:round, at} -> seen([{:round, at} | acc])
      {:taken, at} -> seen([{:taken, at} | acc])
    after
      0 -> Enum.reverse(acc)
    end
  end

  defp flush do
    receive do
      _message -> flush()
    after
      0 -> :ok
    end
  end

  describe "retain_period: (decision 275)" do
    test "checked in the caller, a pinned message each", %{tmp_dir: dir} do
      rig = rig(dir)

      for bad <- [99, 3_600_001, 0, -5, 150.0, :x, "100"] do
        raises(
          "the runner's retain_period: is how often it writes its store, a whole number of " <>
            "ms from 100 to 3600000, got: #{inspect(bad)}",
          fn -> Runner.start_link(Keyword.put(rig.opts, :retain_period, bad)) end
        )
      end

      raises(
        "the runner keeps no store, so retain_period: 500 has none to write: start it with " <>
          "retain: a path",
        fn ->
          Runner.start_link(Keyword.delete(rig.opts, :retain) |> Keyword.put(:retain_period, 500))
        end
      )

      raises("Logex.Runner takes each option once, got :retain_period more than once", fn ->
        Runner.start_link(rig.opts ++ [retain_period: 200])
      end)

      # In order: the start's mistake before the period's, and nothing written or opened.
      raises(~r/start: is :warm/, fn ->
        Runner.start_link(Keyword.put(rig.opts, :retain_period, 5) ++ [start: :hot])
      end)

      refute File.exists?(rig.store)
      assert Sim.reads(rig.panel) == 0

      for ms <- [100, 3_600_000] do
        {:ok, runner} = Runner.start_link(Keyword.put(rig.opts, :retain_period, ms))
        assert Runner.stop(runner) == :ok
        opener_down(rig.panel)
      end
    end

    # 1000 ms unless set: the store's age moves on each second, `status/1`'s `written_at`
    # the header's time of the write on disk.
    test "every 1000 ms unless set, status/1 showing the last write's age", %{tmp_dir: dir} do
      rig = rig(dir)
      {:ok, runner} = Runner.start_link(Keyword.delete(rig.opts, :retain_period))
      assert Runner.status(runner).retain.written_at == ~U[2026-10-30 14:00:00Z]
      eye(rig, 1, 990)
      assert Runner.status(runner).retain.written_at == ~U[2026-10-30 14:00:00Z]
      assert total(rig.store) == "0"
      eye(rig, 1, 10)
      synced(runner)
      assert Runner.status(runner).retain.written_at == ~U[2026-10-30 14:00:01Z]
      assert total(rig.store) == "1"
      Manual.advance(rig.clock, 2000)
      synced(runner)
      assert Runner.status(runner).retain.written_at == ~U[2026-10-30 14:00:03Z]
      assert File.read!(rig.store) =~ "configuration plant written 2026-10-30T14:00:03Z\n"
      assert Runner.stop(runner) == :ok
    end
  end

  describe "the period's write and a crash (decision 292)" do
    # PLAN M6-6's Done-when: a runner killed between two periods restores the earlier
    # period's write, never what came since.
    test "a runner killed between two periods restores the earlier period's write",
         %{tmp_dir: dir} do
      rig = rig(dir)
      {:ok, runner} = Runner.start_link(rig.opts)
      eye(rig, 1, 30)
      eye(rig, 0, 30)
      eye(rig, 1, 40)
      synced(runner)
      assert values(runner) == [2, 2, 1, 2]
      eye(rig, 0, 30)
      eye(rig, 1, 30)
      assert values(runner) == [3, 3, 1, 3]
      killed(runner)
      opener_down(rig.panel)

      {:ok, runner} = Runner.start_link(rig.opts)
      assert values(runner) == [2, 2, 1, 2]
      assert Runner.status(runner).retain.written_at == ~U[2026-10-30 14:00:00Z]
      assert Runner.stop(runner) == :ok
    end

    # M6-6's review: a runner killed in the middle of a period's write, its writer held
    # inside its write; the writer goes down with its runner, the store is the last whole
    # write, and a fresh start restores that. The writer was held by a pipe at the store's
    # `.tmp`, which since M10 (RV-4) its write deletes first, each write's `.tmp` its own;
    # since RV-4's review it is held inside Logex.Retain.written/2 by the VM's file server
    # held, `:sys.suspend/1`, which its write's delete of what stands at the `.tmp` and its
    # rename go through, its other calls raw. Killed in the delete, before its file is
    # made, the store is the write before it; killed in the rename, its file whole and
    # synced, the rename the server holds lands once the server answers and the store is
    # that write: the old or the new, whole, never a mix.
    test "a runner killed in the middle of a period's write restores the write before it",
         %{tmp_dir: dir} do
      text = String.replace(@tally, "var e bool\n", "var e bool\nvar retain big dint[20000]\n")
      {:ok, tally} = Logex.compile(text, name: "tally")
      {:ok, config} = Configuration.compile("plant", @plant, %{"tally" => tally})

      for {held_in, restored} <- [delete: [1, 1, 1, 1], rename: [2, 2, 1, 2]] do
        rig = rig(Path.join(dir, "#{held_in}"), configuration: config)
        File.mkdir_p!(Path.dirname(rig.store))
        {:ok, runner} = Runner.start_link(rig.opts)
        eye(rig, 1, 100)
        synced(runner)
        before = File.read!(rig.store)
        assert total(rig.store) == "1"
        writer = writer(runner)
        ref = Process.monitor(writer)
        leftover(held_in, rig.store <> ".tmp")
        server = Process.whereis(:file_server_2)
        :sys.suspend(server)
        on_exit(fn -> :sys.resume(server) end)
        eye(rig, 0, 50)
        eye(rig, 1, 50)
        assert values(runner) == [2, 2, 1, 2]
        assert waiting_call(server, held_in) == writer
        killed(runner)
        assert_receive {:DOWN, ^ref, :process, ^writer, :killed}, 5000
        :sys.resume(server)
        assert stored(held_in, File.read!(rig.store), before)
        refute File.exists?(rig.store <> ".tmp")
        opener_down(rig.panel)

        {:ok, runner} = Runner.start_link(rig.opts)
        assert values(runner) == restored
        assert Runner.stop(runner) == :ok
      end
    end

    # Decision 316's shutdown and decision 292's crash measured against the period's: a
    # parent's shutdown writes the resource as it was, and a crash after a period brings
    # back that period's write.
    test "a shutdown writes the resource as it was, a later period's write and all",
         %{tmp_dir: dir} do
      rig = rig(dir)
      Process.flag(:trap_exit, true)
      {:ok, runner} = Runner.start_link(rig.opts)
      eye(rig, 1, 100)
      synced(runner)
      assert total(rig.store) == "1"
      eye(rig, 0, 30)
      eye(rig, 1, 30)
      ref = Process.monitor(runner)
      Process.exit(runner, :shutdown)
      assert_receive {:DOWN, ^ref, :process, ^runner, :shutdown}, 5000
      assert total(rig.store) == "2"
    end
  end

  describe "the period's place among the rounds (decisions 108 and 122, restated)" do
    # With no untimed program the period has a wake of its own, between two rounds, which
    # holds every round up to it; one due with a round comes after that round. No round
    # moves: the rounds' times are those of a runner with no store.
    test "timed only: at its own wake, or just after the round due with it", %{tmp_dir: dir} do
      runs =
        for {period, n} <- [{105, 1}, {100, 2}, {nil, 3}] do
          File.mkdir_p!(Path.join(dir, "#{n}"))
          rig = rig(Path.join(dir, "#{n}"), steps: Watched)
          opts = period_opts(rig.opts, period)
          {:ok, runner} = Runner.start_link(opts)
          eye(rig, 1, 95)
          flush_rounds_before(95)
          Manual.advance(rig.clock, 20)
          seen = seen()
          assert Runner.stop(runner) == :ok
          opener_down(rig.panel)
          seen
        end

      assert runs == [
               [round: 100, taken: 105, round: 110],
               [round: 100, taken: 100, round: 110],
               [round: 100, round: 110]
             ]
    end

    # With untimed programs the rounds run back to back, a millisecond each on the manual
    # clock, and the period's take-out is the runner's own work in the share's slot: at
    # 20%, C = 4 and S = 1, slots after the rounds at 3, 7, ..., 99 and 103, so the period
    # due at 100 comes in the slot at 103, after its round and before the next; at 50%, C = 1,
    # a slot after every round, at 100. Every round is at its millisecond either way.
    test "untimed: first in the share's slot at or after its due time", %{tmp_dir: dir} do
      runs =
        for {overhead, period, n} <- [{20, 100, 1}, {50, 100, 2}, {20, nil, 3}] do
          File.mkdir_p!(Path.join(dir, "#{n}"))

          rig =
            rig(Path.join(dir, "#{n}"),
              steps: Watched,
              configuration: configured(@untimed),
              overhead: overhead
            )

          {:ok, runner} = Runner.start_link(period_opts(rig.opts, period))
          Manual.advance(rig.clock, 98)
          flush_rounds_before(98)
          Manual.advance(rig.clock, 7)
          seen = seen()
          assert Runner.stop(runner) == :ok
          opener_down(rig.panel)
          seen
        end

      rounds = for at <- 98..105, do: {:round, at}
      assert Enum.at(runs, 2) == rounds
      assert Enum.at(runs, 0) == List.insert_at(rounds, 6, {:taken, 103})
      assert Enum.at(runs, 1) == List.insert_at(rounds, 3, {:taken, 100})
    end

    # The due times are a grid from the start: one passed inside a slow step is taken once,
    # just after it, and the next is the grid's next, none made up.
    test "a due time passed while the runner was busy is skipped, never made up",
         %{tmp_dir: dir} do
      rig = rig(dir, steps: Watched)
      {:ok, runner} = Runner.start_link(rig.opts)
      Manual.advance(rig.clock, 90)
      flush_rounds_before(91)
      :persistent_term.put({Watched, :slow, self()}, 250)
      Manual.advance(rig.clock, 10)
      assert [{:round, 100}, {:taken, 350} | _rounds] = seen()
      Manual.advance(rig.clock, 100)
      assert [{:taken, 400}] = for({:taken, _} = t <- seen(), do: t)
      assert Runner.stop(runner) == :ok
    end
  end

  defp period_opts(opts, nil), do: Keyword.delete(opts, :retain_period) |> Keyword.delete(:retain)
  defp period_opts(opts, ms), do: Keyword.put(opts, :retain_period, ms)

  defp flush_rounds_before(at) do
    receive do
      {:round, before} when before < at -> flush_rounds_before(at)
      {:taken, before} when before < at -> flush_rounds_before(at)
    after
      0 -> :ok
    end
  end

  describe "the writer (decision 275)" do
    # PLAN M6-6's Done-when: a slow write delays no round. The writer suspended, the
    # rounds run on and the periods' take-outs wait, the newest replacing the one before;
    # resumed, it ends its write and writes the newest, the one between dropped.
    test "a slow write delays no round, and the newest image waiting wins", %{tmp_dir: dir} do
      rig = rig(dir)
      {:ok, runner} = Runner.start_link(rig.opts)
      eye(rig, 1, 100)
      synced(runner)
      writer = writer(runner)
      :sys.suspend(writer)
      before = Runner.status(runner).rounds
      eye(rig, 0, 50)
      eye(rig, 1, 50)
      assert values(runner) == [2, 2, 1, 2]
      eye(rig, 0, 50)
      eye(rig, 1, 50)
      assert values(runner) == [3, 3, 1, 3]
      eye(rig, 0, 50)
      eye(rig, 1, 50)
      assert values(runner) == [4, 4, 1, 4]
      assert Runner.status(runner).rounds == before + 30
      assert total(rig.store) == "1"
      assert Runner.status(runner).retain.written_at == ~U[2026-10-30 14:00:00Z]
      # The write at 200 in progress, the one at 300 waiting and replaced by the one at 400.
      assert traced_writes(writer, runner) == 2
      assert total(rig.store) == "4"
      assert Runner.stop(runner) == :ok
    end

    # A write that fails leaves the old store, is reported as every failed write is, and
    # the plant runs on; the next period's that is taken clears `failed`.
    test "a write that fails leaves the old store, is reported, and the plant runs on",
         %{tmp_dir: dir} do
      rig = rig(dir)
      {:ok, runner} = Runner.start_link(rig.opts)
      :ok = Runner.subscribe(runner)
      eye(rig, 1, 100)
      synced(runner)
      written = File.read!(rig.store)
      File.mkdir_p!(rig.store <> ".tmp")
      eye(rig, 0, 50)
      eye(rig, 1, 50)
      synced(runner)
      assert_receive {Runner, ^runner, {:retain, {:error, :eisdir}}}
      assert %{status: :running, retain: %{failed: :eisdir}} = Runner.status(runner)
      assert File.read!(rig.store) == written
      assert values(runner) == [2, 2, 1, 2]
      File.rmdir!(rig.store <> ".tmp")
      Manual.advance(rig.clock, 100)
      synced(runner)
      assert %{failed: nil, written_at: ~U[2026-10-30 14:00:00Z]} = Runner.status(runner).retain
      assert total(rig.store) == "2"
      refute_received {Runner, ^runner, {:retain, _}}
      assert Runner.stop(runner) == :ok
    end

    # PLAN M6-6's Done-when: a stop while a period's write is in progress waits for it,
    # drops the one pending and writes last, after its zeros and closes.
    test "a stop waits for the write in progress, drops the pending one and writes last",
         %{tmp_dir: dir} do
      # A write limit of 5000: the test holds the writer in real time while the stop waits
      # on it, the write limit before the writer is killed (M6-6's review), and since
      # decision 353 the stop's own write has that time too; at the runner's 510 ms, the
      # idle watchdog and a poll period before decision 400 (RV-11) gave the limit an option
      # of its own, which an idle watchdog of 5000 stood for here, a loaded machine's syncs
      # outran the hold now and then (scripts/load.sh, RV-4: the writer killed, as at the
      # parent, or the stop's write `:timeout`). The test reads no limit.
      rig = rig(dir, write_limit: 5000)
      {:ok, runner} = Runner.start_link(rig.opts)
      eye(rig, 1, 100)
      synced(runner)
      writer = writer(runner)
      :sys.suspend(writer)
      eye(rig, 0, 50)
      eye(rig, 1, 50)
      eye(rig, 0, 50)
      eye(rig, 1, 50)
      assert values(runner) == [3, 3, 1, 3]
      Code.ensure_loaded!(Logex.Retain)
      assert :erlang.trace_pattern({Logex.Retain, :written, 2}, true, [:global]) == 1
      # Decision 353: the runner's own write is Writer.written/3's, in a process of its own.
      assert :erlang.trace_pattern({Logex.Runner.Writer, :written, 3}, true, [:global]) == 1
      :erlang.trace(writer, true, [:call])
      :erlang.trace(runner, true, [:call])
      stopping = Task.async(fn -> Runner.stop(runner) end)
      refute Task.yield(stopping, 100)
      assert Sim.closed?(rig.panel)
      assert total(rig.store) == "1"
      :sys.resume(writer)
      assert Task.await(stopping) == :ok
      :erlang.trace_pattern({Logex.Retain, :written, 2}, false, [:global])
      :erlang.trace_pattern({Logex.Runner.Writer, :written, 3}, false, [:global])
      assert writes_by() == [writer, runner]
      assert total(rig.store) == "3"
      refute Process.alive?(writer)
    end

    # PLAN M6-6's Done-when: a stop whose final write fails still stops and says so, the
    # write in progress waited for first.
    test "a stop whose final write fails still stops and returns its reason", %{tmp_dir: dir} do
      # A write limit of 5000: the test holds the writer in real time while the stop waits
      # on it, the write limit before the writer is killed (M6-6's review), and since
      # decision 353 the stop's own write has that time too; at the runner's 510 ms, the
      # idle watchdog and a poll period before decision 400 (RV-11) gave the limit an option
      # of its own, which an idle watchdog of 5000 stood for here, a loaded machine's syncs
      # outran the hold now and then (scripts/load.sh, RV-4: the writer killed, as at the
      # parent, or the stop's write `:timeout`). The test reads no limit.
      rig = rig(dir, write_limit: 5000)
      {:ok, runner} = Runner.start_link(rig.opts)
      eye(rig, 1, 100)
      synced(runner)
      writer = writer(runner)
      :sys.suspend(writer)
      eye(rig, 0, 100)
      File.mkdir_p!(rig.store <> ".tmp")
      stopping = Task.async(fn -> Runner.stop(runner) end)
      refute Task.yield(stopping, 50)
      :sys.resume(writer)
      assert Task.await(stopping) == {:error, {:retain, :eisdir}}
      refute Process.alive?(runner)
      assert Sim.closed?(rig.panel)
      assert total(rig.store) == "1"
    end

    # A writer that does not answer by the write limit, in real time, is killed, its write
    # reported failed, `:timeout`, and the stop's write made all the same (provisional).
    # Since decision 353 the stop's own write has that time too, so the limit is 410 here,
    # where at 70 a loaded machine's sync missed it; the idle watchdog of 400 and a poll
    # period stood for it before decision 400 (RV-11) gave it `write_limit:`.
    test "a hung writer is killed at its deadline and the stop writes", %{tmp_dir: dir} do
      rig = rig(dir, write_limit: 410)
      {:ok, runner} = Runner.start_link(rig.opts)
      :ok = Runner.subscribe(runner)
      eye(rig, 1, 100)
      synced(runner)
      writer = writer(runner)
      :sys.suspend(writer)
      eye(rig, 0, 100)
      began = System.monotonic_time(:millisecond)
      assert Runner.stop(runner) == :ok
      assert System.monotonic_time(:millisecond) - began >= 410
      refute Process.alive?(writer)
      assert_received {Runner, ^runner, {:retain, {:error, :timeout}}}
      assert File.read!(rig.store) =~ "global total_boxes dint 1\n"
    end

    # A writer gone down is reported, `{:down, reason}`, where it held a write, and the
    # next period's write is made by a new one (provisional).
    test "a writer gone down is reported and a new one writes the next period",
         %{tmp_dir: dir} do
      rig = rig(dir)
      {:ok, runner} = Runner.start_link(rig.opts)
      :ok = Runner.subscribe(runner)
      eye(rig, 1, 100)
      synced(runner)
      writer = writer(runner)
      :sys.suspend(writer)
      eye(rig, 0, 100)
      Process.exit(writer, :kill)
      _ = :sys.get_state(runner)
      assert_receive {Runner, ^runner, {:retain, {:error, {:down, :killed}}}}
      assert Runner.status(runner).retain.failed == {:down, :killed}
      eye(rig, 1, 100)
      _ = :sys.get_state(runner)
      assert writer(runner) not in [nil, writer]
      synced(runner)
      assert total(rig.store) == "2"
      assert Runner.status(runner).retain.failed == nil
      assert Runner.stop(runner) == :ok
    end

    # M6-6's review: a writer that goes down while it holds a write, before the runner has
    # handled its exit, is taken as gone by the event's wait at once, its write reported
    # `{:down, reason}`, never waited on to the deadline and reported `:timeout`. The
    # runner suspended keeps the exit in its mailbox; the stop, a system message, still
    # reaches it. A write limit of 5000, the wait's deadline, so that a wait to it is told
    # from none: since decision 400 (RV-11) `write_limit:`, where an idle watchdog of 5000
    # stood for it.
    test "a writer gone down before an event's write is not waited on", %{tmp_dir: dir} do
      rig = rig(dir, write_limit: 5000)
      {:ok, runner} = Runner.start_link(rig.opts)
      :ok = Runner.subscribe(runner)
      eye(rig, 1, 100)
      synced(runner)
      writer = writer(runner)
      :sys.suspend(writer)
      eye(rig, 0, 100)
      :sys.suspend(runner)
      ref = Process.monitor(writer)
      Process.exit(writer, :kill)
      assert_receive {:DOWN, ^ref, :process, ^writer, :killed}
      began = System.monotonic_time(:millisecond)
      assert Runner.stop(runner) == :ok
      assert System.monotonic_time(:millisecond) - began < 2500
      assert_received {Runner, ^runner, {:retain, {:error, {:down, :killed}}}}
      refute_received {Runner, ^runner, {:retain, {:error, :timeout}}}
      assert File.read!(rig.store) =~ "global total_boxes dint 1\n"
    end

    # M6-6's review: a writer gone down while it holds no write is forgotten, and the next
    # period's write is made by a new one, not handed to the one gone.
    test "a writer gone down while idle is replaced at the next period", %{tmp_dir: dir} do
      rig = rig(dir)
      {:ok, runner} = Runner.start_link(rig.opts)
      :ok = Runner.subscribe(runner)
      eye(rig, 1, 100)
      synced(runner)
      writer = writer(runner)
      ref = Process.monitor(writer)
      Process.exit(writer, :kill)
      assert_receive {:DOWN, ^ref, :process, ^writer, :killed}
      _ = :sys.get_state(runner)
      assert writer(runner) == nil
      refute_received {Runner, ^runner, {:retain, _}}
      eye(rig, 0, 50)
      eye(rig, 1, 50)
      assert writer(runner) not in [nil, writer]
      synced(runner)
      assert total(rig.store) == "2"
      assert Runner.stop(runner) == :ok
    end
  end

  describe "the period's hand-off (decision 488)" do
    # The runner hands its writer the retained values it picks out of the resource, and
    # the writer makes the image of them, where the runner sent it the whole resource, every
    # program's code and every instance's state: so what it sends is the same for the box
    # counter beside 100 rungs that retain nothing as beside 3,000, and the store the
    # writer writes holds the resource's retained values.
    test "sends the retained values alone, whatever else the program holds", %{tmp_dir: dir} do
      sent =
        for rungs <- [100, 3000] do
          tally =
            String.replace(@tally, "var e bool\n", "var e bool\nvar spare dint\n") <>
              String.duplicate("xic eye add spare 1 spare\n", rungs)

          {:ok, program} = Logex.compile(tally, name: "tally")
          {:ok, config} = Configuration.compile("plant", @plant, %{"tally" => program})
          rig = rig(Path.join(dir, "r#{rungs}"), configuration: config)
          File.mkdir_p!(Path.dirname(rig.store))
          {:ok, runner} = Runner.start_link(rig.opts)
          :erlang.trace(runner, true, [:send])
          eye(rig, 1, 100)
          synced(runner)
          :erlang.trace(runner, false, [:send])
          trace = :erlang.trace_delivered(runner)
          assert_receive {:trace_delivered, ^runner, ^trace}
          assert total(rig.store) == "1"
          assert Runner.stop(runner) == :ok
          handed_off(runner)
        end

      assert [[small], [large]] = sent
      assert :erts_debug.flat_size(small) == :erts_debug.flat_size(large)
    end

    # RV-18's review, finding 2 (its mutant r20): what the instance holds beside its
    # retained values, an array of 100 dints or of 3,000 that no path retains, is no more
    # of the hand-off, where the test above, its code alone grown, let the runner send each
    # retaining instance's whole state.
    test "sends the retained values alone, whatever else the instance holds",
         %{tmp_dir: dir} do
      sent =
        for size <- [100, 3000] do
          tally =
            String.replace(@tally, "var e bool\n", "var e bool\nvar spare dint[#{size}]\n") <>
              "xic eye add spare[0] 1 spare[#{size - 1}]\n"

          {:ok, program} = Logex.compile(tally, name: "tally")
          {:ok, config} = Configuration.compile("plant", @plant, %{"tally" => program})
          rig = rig(Path.join(dir, "s#{size}"), configuration: config)
          File.mkdir_p!(Path.dirname(rig.store))
          {:ok, runner} = Runner.start_link(rig.opts)
          :erlang.trace(runner, true, [:send])
          eye(rig, 1, 100)
          synced(runner)
          :erlang.trace(runner, false, [:send])
          trace = :erlang.trace_delivered(runner)
          assert_receive {:trace_delivered, ^runner, ^trace}
          assert total(rig.store) == "1"
          assert Runner.get!(runner, "t1.spare[#{size - 1}]") == 1
          assert Runner.stop(runner) == :ok
          handed_off(runner)
        end

      assert [[small], [large]] = sent
      assert :erts_debug.flat_size(small) == :erts_debug.flat_size(large)
    end
  end

  # What the runner handed its writer, each period's, from the trace of its sends.
  defp handed_off(runner, acc \\ []) do
    receive do
      {:trace, ^runner, :send, {:"$gen_cast", {:write, _at, taken, _owed}}, _writer} ->
        handed_off(runner, [taken | acc])

      {:trace, ^runner, :send, _message, _to} ->
        handed_off(runner, acc)
    after
      0 -> Enum.reverse(acc)
    end
  end

  describe "a trip and a restart" do
    # A trip's write, like a stop's, waits for the period's write in progress and drops the
    # one pending, so that the trip's is the last on disk.
    test "a trip waits for the write in progress, drops the pending one and writes last",
         %{tmp_dir: dir} do
      # A write limit of 5000: the test holds the writer in real time while the trip waits
      # on it, the write limit before the writer is killed (M6-6's review), and since
      # decision 353 the trip's own write has that time too; at the runner's 510 ms, the
      # idle watchdog and a poll period before decision 400 (RV-11) gave the limit an option
      # of its own, which an idle watchdog of 5000 stood for here, a loaded machine's syncs
      # outran the hold now and then (scripts/load.sh, RV-4: the writer killed, as at the
      # parent, or the trip's write `:timeout`). The test reads no limit.
      rig = rig(dir, write_limit: 5000)
      {:ok, runner} = Runner.start_link(rig.opts)
      eye(rig, 1, 100)
      synced(runner)
      writer = writer(runner)
      :sys.suspend(writer)
      eye(rig, 0, 50)
      eye(rig, 1, 50)
      eye(rig, 0, 50)
      eye(rig, 1, 50)
      assert values(runner) == [3, 3, 1, 3]
      Code.ensure_loaded!(Logex.Retain)
      assert :erlang.trace_pattern({Logex.Retain, :written, 2}, true, [:global]) == 1
      # Decision 353: the runner's own write is Writer.written/3's, in a process of its own.
      assert :erlang.trace_pattern({Logex.Runner.Writer, :written, 3}, true, [:global]) == 1
      :erlang.trace(writer, true, [:call])
      :erlang.trace(runner, true, [:call])

      spawn(fn ->
        Process.sleep(50)
        :sys.resume(writer)
      end)

      Sim.fail(rig.panel, :read, {:error, :eio})
      Manual.advance(rig.clock, 10)
      assert %{status: :tripped} = Runner.status(runner)
      _ = :sys.get_state(writer)
      _ = :sys.get_state(runner)
      :erlang.trace_pattern({Logex.Retain, :written, 2}, false, [:global])
      :erlang.trace_pattern({Logex.Runner.Writer, :written, 3}, false, [:global])
      assert writes_by() == [writer, runner]
      assert total(rig.store) == "3"
      assert Runner.stop(runner) == :ok
    end

    # M6-6's review: the period's write a trip waits for is reported as every write is, so
    # that one that fails is said, the trip's own after it.
    test "a trip reports the failure of the period's write it waited for", %{tmp_dir: dir} do
      # A write limit of 5000: the test holds the writer in real time while the trip waits
      # on it, the write limit before the writer is killed (M6-6's review), and since
      # decision 353 the trip's own write has that time too; at the runner's 510 ms, the
      # idle watchdog and a poll period before decision 400 (RV-11) gave the limit an option
      # of its own, which an idle watchdog of 5000 stood for here, a loaded machine's syncs
      # outran the hold now and then (scripts/load.sh, RV-4: the writer killed, as at the
      # parent, or the trip's write `:timeout`). The test reads no limit.
      rig = rig(dir, write_limit: 5000)
      {:ok, runner} = Runner.start_link(rig.opts)
      :ok = Runner.subscribe(runner)
      eye(rig, 1, 100)
      synced(runner)
      writer = writer(runner)
      :sys.suspend(writer)
      eye(rig, 0, 100)
      File.mkdir_p!(rig.store <> ".tmp")

      spawn(fn ->
        Process.sleep(50)
        :sys.resume(writer)
      end)

      Sim.fail(rig.panel, :read, {:error, :eio})
      Manual.advance(rig.clock, 10)
      assert %{status: :tripped, retain: %{failed: :eisdir}} = Runner.status(runner)
      assert_received {Runner, ^runner, {:retain, {:error, :eisdir}}}
      assert_received {Runner, ^runner, {:retain, {:error, :eisdir}}}
      assert total(rig.store) == "1"
      assert Runner.stop(runner) == {:error, {:retain, :eisdir}}
    end

    # M6-6's review: a writer that does not answer a trip's wait by its deadline is killed,
    # so that it cannot wake later and write an older image over the trip's. Since
    # decision 353 the trip's own write has the write limit too, so the limit is 410 here,
    # where at 70 a loaded machine's sync missed it; the idle watchdog of 400 and a poll
    # period stood for it before decision 400 (RV-11) gave it `write_limit:`.
    test "a hung writer is killed at a trip's deadline and never writes after it",
         %{tmp_dir: dir} do
      rig = rig(dir, write_limit: 410)
      {:ok, runner} = Runner.start_link(rig.opts)
      :ok = Runner.subscribe(runner)
      eye(rig, 1, 100)
      synced(runner)
      writer = writer(runner)
      :sys.suspend(writer)
      # The write held is the image at 200, of 2 boxes; the trip at 300, of 3.
      eye(rig, 0, 50)
      eye(rig, 1, 50)
      eye(rig, 0, 50)
      eye(rig, 1, 40)
      Sim.fail(rig.panel, :read, {:error, :eio})
      Manual.advance(rig.clock, 10)
      assert %{status: :tripped} = Runner.status(runner)
      assert_received {Runner, ^runner, {:retain, {:error, :timeout}}}
      tripped = File.read!(rig.store)
      assert tripped =~ "global total_boxes dint 3\n"
      refute Process.alive?(writer)
      catch_exit(:sys.resume(writer))
      Process.sleep(50)
      assert File.read!(rig.store) == tripped
      assert Runner.stop(runner) == :ok
    end

    # No period while tripped: the trip's write is the store until a restart, and a warm
    # restart takes up the grid at its next due time, writing nothing at once.
    test "nothing written while tripped but the trip's own write", %{tmp_dir: dir} do
      rig = rig(dir, steps: Watched)
      {:ok, runner} = Runner.start_link(rig.opts)
      eye(rig, 1, 130)
      Sim.fail(rig.panel, :read, {:error, :eio})
      Manual.advance(rig.clock, 10)
      assert %{status: :tripped} = Runner.status(runner)
      tripped = File.read!(rig.store)
      flush()
      Manual.advance(rig.clock, 520)
      assert File.read!(rig.store) == tripped
      assert seen() == []
      assert Runner.restart(runner, :warm) == :ok
      assert [{:round, 660}] = seen()
      Manual.advance(rig.clock, 39)
      assert for({:taken, _} = t <- seen(), do: t) == []
      Manual.advance(rig.clock, 1)
      assert for({:taken, _} = t <- seen(), do: t) == [taken: 700]
      assert Runner.stop(runner) == :ok
    end
  end

  # The writes the trace saw, by the process that made each: the writer's through
  # Logex.Retain.written/2, and since decision 353 the runner's own through
  # Logex.Runner.Writer.written/3, which makes it in a process of its own.
  defp writes_by(acc \\ []) do
    receive do
      {:trace, pid, :call, {Logex.Retain, :written, _args}} -> writes_by([pid | acc])
      {:trace, pid, :call, {Logex.Runner.Writer, :written, _args}} -> writes_by([pid | acc])
    after
      100 -> Enum.reverse(acc)
    end
  end

  defp traced_writes(writer, runner) do
    Code.ensure_loaded!(Logex.Retain)
    assert :erlang.trace_pattern({Logex.Retain, :written, 2}, true, [:global]) == 1
    :erlang.trace(writer, true, [:call])
    :sys.resume(writer)
    synced(runner)
    synced(runner)
    :erlang.trace_pattern({Logex.Retain, :written, 2}, false, [:global])
    length(writes_by())
  end
end

defmodule Logex.RetainPeriodCostTest do
  # M6-6's cost: a round of a runner with a store and a long period costs within a few
  # reductions of one with no store, and a period's take-out grows linearly in the
  # retained values alone. The collector kept out of the counts by a large heap, set for
  # the processes these tests start; not async, so that no other test starts one meanwhile.
  use ExUnit.Case, async: false

  alias Logex.{Configuration, Runner}
  alias Logex.IO.Sim
  alias Logex.Runner.Clock.Manual

  @moduletag :tmp_dir
  @moduletag capture_log: true

  setup do
    before = :erlang.system_flag(:min_heap_size, 2_000_000)
    on_exit(fn -> :erlang.system_flag(:min_heap_size, before) end)
  end

  defp counters(n) do
    text =
      "var_input eye bool\n" <>
        Enum.map_join(1..n, "\n", &"var retain c#{&1} ctu") <>
        "\n\n" <> Enum.map_join(1..n, "\n", &"xic eye ctu c#{&1} 5")

    {:ok, program} = Logex.compile(text, name: "many")

    {:ok, config} =
      Configuration.compile(
        "plant",
        "task fast interval 10 priority 1\nvar_global eye_1 bool at panel.i.0\n" <>
          "program m1 many with fast\n  m1.eye eye_1\n",
        %{"many" => program}
      )

    config
  end

  # The runner's reductions a round over 200 rounds of the fast task, the eye toggled.
  defp per_round(config, extra, dir), do: elem(costs(config, extra, dir), 0)

  # The same less what the manual clock's synchronisation costs the runner a round (RV-7).
  # `Manual.advance/2` follows each timer it delivers with `:sys.get_state/2`, one a wake
  # and so one a round here, whose answer copies the runner's whole state, at about a
  # reduction a 100 words and not evenly: a store's 200 words more made it 48.0 a reply
  # with none and 50.1 to 50.5 with one in one CI run, two of the 8 the bound's test read
  # apart, the rest the round's own. That copy is the test's, never a round's, and is
  # measured on the same runner just after, the mean of 200 replies, and taken off.
  defp own_round(config, extra, dir) do
    {per_round, synced} = costs(config, extra, dir)
    per_round - synced
  end

  defp costs(config, extra, dir) do
    {:ok, clock} = Manual.start_link()
    {:ok, panel} = Sim.start_link(clock: clock)
    File.rm(Path.join(dir, "s"))

    {:ok, runner} =
      Runner.start_link(
        [configuration: config, io: %{"panel" => {Sim, sim: panel}}, clock: {Manual, clock}] ++
          extra
      )

    Manual.advance(clock, 100)
    {:reductions, a} = Process.info(runner, :reductions)
    rounds = Runner.status(runner).rounds

    for i <- 1..20 do
      Sim.set(panel, [0], rem(i, 2))
      Manual.advance(clock, 100)
    end

    {:reductions, b} = Process.info(runner, :reductions)
    rounds = Runner.status(runner).rounds - rounds
    {:reductions, c} = Process.info(runner, :reductions)
    for _ <- 1..200, do: :sys.get_state(runner)
    {:reductions, d} = Process.info(runner, :reductions)
    assert Runner.stop(runner) == :ok
    GenServer.stop(panel)
    GenServer.stop(clock)
    {(b - a) / rounds, (d - c) / 200}
  end

  # One scheduler online until the test ends, the VM's flag put back as it was then.
  defp one_scheduler do
    online = :erlang.system_flag(:schedulers_online, 1)
    on_exit(fn -> :erlang.system_flag(:schedulers_online, online) end)
  end

  # The least of several runs' costs a round. The devices' messages a round depend on how
  # the scheduler interleaves them, which only ever adds reductions: one run in CI read
  # 15.6 more a round where five here read 3.5 to 7.6 (ci on 8f92723), and since RV-3's
  # review the bound's test reads the least of nine, where it read five, after CI read
  # 10.3 on cb18575 where four runs here read 6.6 to 7.8.
  defp least(config, extra, dir, runs),
    do: Enum.min(for _ <- 1..runs, do: per_round(config, extra, dir))

  # Since RV-7 the bound's test reads each round's own cost, the clock's synchronisation
  # taken off, the two measured in turn, nine of each, the least of each: CI read 10.3,
  # 10.4 and 10.1 apart on `cb18575`, `57260e1` and `6e3b6a6` and 8.1 on RV-7's probe,
  # where runs here read 8.0 to 9.0, the copy 2.0 to 2.5 of it and the rest 5.8 to 6.1.
  #
  # Since RV-19 it counts with one scheduler online, the VM's own flag set for the test
  # and put back after it, so that the runner, its clock and its device run one at a time:
  # a runner's reductions a round move with whether the processes it calls and that send
  # to it run at the same time on other schedulers, which only ever adds to them, and the
  # least of nine read a round's own cost only where the VM had settled its processes onto
  # one scheduler by itself. CI read 10.02 on `e6d81df`, `{1677.17, 1687.19}`, where a
  # quiet VM of CI's read 1678.565 and 1684.605 at every count but its first, 6.04 apart
  # (RV-19's probe on `6913767`): neither least was a settled count. Here a fresh VM read
  # 1679.4 to 1681.2 and 1685.5 to 1686.6 for eighteen counts and more, until it settled,
  # and then 1678.555 and 1684.6 at every count; with one scheduler online, 1678.555 and
  # 1684.6 at every count from the first, alone and under the busy loops.
  test "a round with a store and a long period costs within a few reductions of none",
       %{tmp_dir: dir} do
    one_scheduler()
    config = counters(4)
    store = [retain: Path.join(dir, "s"), retain_period: 3_600_000]

    {none, long} =
      Enum.unzip(for _ <- 1..9, do: {own_round(config, [], dir), own_round(config, store, dir)})

    {none, long} = {Enum.min(none), Enum.min(long)}
    assert long - none >= 0 and long - none <= 10, inspect({none, long})
  end

  test "a period's take-out grows linearly in the retained values", %{tmp_dir: dir} do
    [small, large] =
      for n <- [16, 64] do
        config = counters(n)
        store = [retain: Path.join(dir, "s")]
        # The least of three runs each, as the test above reads five (RV-3's review met
        # one run under load past the bound).
        often = least(config, store ++ [retain_period: 100], dir, 3)
        long = least(config, store ++ [retain_period: 3_600_000], dir, 3)
        often - long
      end

    assert small > 0 and large < 5 * small, inspect({small, large})
  end
end
