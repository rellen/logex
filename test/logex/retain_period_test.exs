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
      rig = rig(dir)
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
      :erlang.trace(writer, true, [:call])
      :erlang.trace(runner, true, [:call])
      stopping = Task.async(fn -> Runner.stop(runner) end)
      refute Task.yield(stopping, 100)
      assert Sim.closed?(rig.panel)
      assert total(rig.store) == "1"
      :sys.resume(writer)
      assert Task.await(stopping) == :ok
      :erlang.trace_pattern({Logex.Retain, :written, 2}, false, [:global])
      assert writes_by() == [writer, runner]
      assert total(rig.store) == "3"
      refute Process.alive?(writer)
    end

    # PLAN M6-6's Done-when: a stop whose final write fails still stops and says so, the
    # write in progress waited for first.
    test "a stop whose final write fails still stops and returns its reason", %{tmp_dir: dir} do
      rig = rig(dir)
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

    # A writer that does not answer by the idle watchdog and a poll period, in real time,
    # is killed, its write reported failed, `:timeout`, and the stop's write made all the
    # same (provisional).
    test "a hung writer is killed at its deadline and the stop writes", %{tmp_dir: dir} do
      rig = rig(dir, idle: 60)
      {:ok, runner} = Runner.start_link(rig.opts)
      :ok = Runner.subscribe(runner)
      eye(rig, 1, 100)
      synced(runner)
      writer = writer(runner)
      :sys.suspend(writer)
      eye(rig, 0, 100)
      began = System.monotonic_time(:millisecond)
      assert Runner.stop(runner) == :ok
      assert System.monotonic_time(:millisecond) - began >= 70
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
  end

  describe "a trip and a restart" do
    # A trip's write, like a stop's, waits for the period's write in progress and drops the
    # one pending, so that the trip's is the last on disk.
    test "a trip waits for the write in progress, drops the pending one and writes last",
         %{tmp_dir: dir} do
      rig = rig(dir)
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
      assert writes_by() == [writer, runner]
      assert total(rig.store) == "3"
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

  # The writes the trace saw, by the process that made each.
  defp writes_by(acc \\ []) do
    receive do
      {:trace, pid, :call, {Logex.Retain, :written, _args}} -> writes_by([pid | acc])
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
  defp per_round(config, extra, dir) do
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
    assert Runner.stop(runner) == :ok
    GenServer.stop(panel)
    GenServer.stop(clock)
    (b - a) / rounds
  end

  test "a round with a store and a long period costs within a few reductions of none",
       %{tmp_dir: dir} do
    config = counters(4)
    none = per_round(config, [], dir)
    long = per_round(config, [retain: Path.join(dir, "s"), retain_period: 3_600_000], dir)
    assert long - none >= 0 and long - none <= 10, inspect({none, long})
  end

  test "a period's take-out grows linearly in the retained values", %{tmp_dir: dir} do
    [small, large] =
      for n <- [16, 64] do
        config = counters(n)
        store = [retain: Path.join(dir, "s")]
        often = per_round(config, store ++ [retain_period: 100], dir)
        long = per_round(config, store ++ [retain_period: 3_600_000], dir)
        often - long
      end

    assert small > 0 and large < 5 * small, inspect({small, large})
  end
end
