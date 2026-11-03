defmodule Logex.RunnerPathsTest do
  @moduledoc """
  The files a runner holds (RV-4): decision 356, a runner refuses at its start a store or
  forces path another runner of the same VM holds, naming it, the path free again once
  its holder stops, crashes or is killed; c2-runner-persist-9, a relative `retain:` or
  `forces:` resolved once, at the start, so that a `File.cd` moves neither file and two
  spellings of one path are one file; and M11, a fresh start's write made only once the
  runner's name is registered and its files claimed, so that a start refused writes
  nothing. Not async: a test moves the VM's working directory.
  """
  use ExUnit.Case, async: false

  @moduletag :tmp_dir
  @moduletag capture_log: true

  alias Logex.{Configuration, Runner}
  alias Logex.IO.Sim
  alias Logex.Runner.Clock.Manual

  @count """
  var_input eye bool
  var retain boxes ctu

  xic eye ctu boxes 1000
  """

  @plant """
  task fast interval 10 priority 1
  var_global eye_1 bool at panel.i.0

  program t1 count with fast
    t1.eye eye_1
  """

  defp configured do
    {:ok, count} = Logex.compile(@count, name: "count")
    {:ok, config} = Configuration.compile("plant", @plant, %{"count" => count})
    config
  end

  # A runner's options on a sim of its own and a manual clock, its files as `files` says.
  defp opts(files) do
    {:ok, clock} = Manual.start_link()
    {:ok, panel} = Sim.start_link(clock: clock)

    [configuration: configured(), io: %{"panel" => {Sim, sim: panel}}, clock: {Manual, clock}] ++
      files
  end

  defp panel(opts),
    do: opts |> Keyword.fetch!(:io) |> Map.fetch!("panel") |> elem(1) |> Keyword.fetch!(:sim)

  defp raises(message, fun), do: assert_raise(ArgumentError, message, fun)

  # The VM's table of claims gone, its keeper killed, so that the next claim makes it anew.
  defp table_gone(:undefined), do: :ok

  defp table_gone(keeper) do
    ref = Process.monitor(keeper)
    Process.exit(keeper, :kill)
    assert_receive {:DOWN, ^ref, :process, ^keeper, :killed}, 5000
    table_gone(:ets.info(Logex.Runner.Paths, :owner))
  end

  # The claims the VM's table holds for a store and its `.tmp`, and since decision 360 its
  # copy and the copy's `.tmp`: a runner that stops, or whose start is refused after it
  # claimed them, gives them up as it ends, not merely by being gone.
  defp claims(store),
    do:
      Enum.flat_map(
        [store, store <> ".tmp", store <> ".dropped", store <> ".dropped.tmp"],
        &:ets.lookup(Logex.Runner.Paths, &1)
      )

  # A start from a task, the runner unlinked so that the task's end leaves it running, or
  # refused for a file another runner holds.
  defp started_or_refused(opts) do
    {:ok, pid} = Runner.start_link(opts)
    Process.unlink(pid)
    {:ok, pid}
  rescue
    error in ArgumentError -> {:refused, held_message?(error.message)}
  end

  defp held_message?(message), do: true = message =~ "of another runner of this VM"

  defp held(option, given, what, holder),
    do:
      "the runner's #{option}: #{inspect(given)} #{what}" <>
        String.replace(
          " of another runner of this VM, HOLDER, which holds it until it stops: two " <>
            "runners on one file write each over the other's",
          "HOLDER",
          inspect(holder)
        )

  describe "two runners on one file (decision 356)" do
    test "a second runner on a store another holds is refused at start, naming it and its " <>
           "holder, nothing written and no device opened",
         %{tmp_dir: dir} do
      store = Path.join(dir, "plant.retain")
      {:ok, first} = Runner.start_link(opts(retain: store))
      written = File.read!(store)

      for start <- [:warm, :cold] do
        second = opts(retain: store, start: start)

        raises(held(:retain, store, "names the store", first), fn ->
          Runner.start_link(second)
        end)

        assert Sim.reads(panel(second)) == 0
        assert File.read!(store) == written
      end

      # One file however it is spelled, decision 325's rule across two runners.
      for spelled <- [
            Path.join([dir, ".", "plant.retain"]),
            Path.join([dir, "sub", "..", "plant.retain"])
          ] do
        raises(held(:retain, spelled, "names the store", first), fn ->
          Runner.start_link(opts(retain: spelled))
        end)
      end

      assert Runner.stop(first) == :ok
    end

    test "a store another runner keeps its forces in, a forces file another keeps its store " <>
           "in, and the `.tmp` either is written through are refused",
         %{tmp_dir: dir} do
      store = Path.join(dir, "plant.retain")
      forces = Path.join(dir, "plant.forces")
      {:ok, first} = Runner.start_link(opts(retain: store, forces: forces))

      raises(held(:retain, forces, "names the forces file", first), fn ->
        Runner.start_link(opts(retain: forces))
      end)

      raises(held(:forces, store, "names the store", first), fn ->
        Runner.start_link(opts(forces: store))
      end)

      raises(
        "the runner's forces: #{inspect(store <> ".tmp")} names the `.tmp` another runner " <>
          "of this VM, #{inspect(first)}, writes its store through, which it holds until it " <>
          "stops: two runners on one file write each over the other's",
        fn -> Runner.start_link(opts(forces: store <> ".tmp")) end
      )

      # A store whose `.tmp` is another's store.
      {:ok, other} = Runner.start_link(opts(retain: Path.join(dir, "x.tmp")))

      raises(
        "the runner's retain: #{inspect(Path.join(dir, "x"))} is written through " <>
          "#{inspect(Path.join(dir, "x.tmp"))}, the store of another runner of this VM, " <>
          "#{inspect(other)}, which holds it until it stops: two runners on one file write " <>
          "each over the other's",
        fn -> Runner.start_link(opts(retain: Path.join(dir, "x"))) end
      )

      assert Runner.stop(other) == :ok
      assert Runner.stop(first) == :ok
    end

    # Decision 360 (RV-5): the copy a fresh start keeps of a store it dropped from,
    # `<store>.dropped`, and the `.tmp` it is written through, are the runner's too.
    test "a store another runner copies its store to, and the copy's `.tmp`, are refused",
         %{tmp_dir: dir} do
      store = Path.join(dir, "plant.retain")
      # A write limit of 5,000 ms, which covers a loaded machine's disk: since decision 400
      # (RV-11) `write_limit:`, where an idle watchdog of 5,000 stood for it.
      {:ok, first} = Runner.start_link(opts(retain: store, write_limit: 5000))
      copy = store <> ".dropped"

      raises(held(:retain, copy, "names the store's copy, `.dropped`,", first), fn ->
        Runner.start_link(opts(retain: copy))
      end)

      raises(
        "the runner's retain: #{inspect(copy <> ".tmp")} names the `.tmp` another runner of " <>
          "this VM, #{inspect(first)}, writes its store's copy, `.dropped`, through, which it " <>
          "holds until it stops: two runners on one file write each over the other's",
        fn -> Runner.start_link(opts(retain: copy <> ".tmp")) end
      )

      # A store whose copy is another's store.
      {:ok, other} =
        Runner.start_link(opts(retain: Path.join(dir, "x.dropped"), write_limit: 5000))

      raises(
        "the runner's retain: #{inspect(Path.join(dir, "x"))} is copied to " <>
          "#{inspect(Path.join(dir, "x.dropped"))}, the store of another runner of this VM, " <>
          "#{inspect(other)}, which holds it until it stops: two runners on one file write " <>
          "each over the other's",
        fn -> Runner.start_link(opts(retain: Path.join(dir, "x"))) end
      )

      assert Runner.stop(other) == :ok
      assert Runner.stop(first) == :ok
      assert claims(store) == []
    end

    # The caller's check sees no holder for either of two starts made at once; the claim in
    # each runner's own process, once its name is registered, decides: one starts.
    test "of two starts at once on one store, one starts and the other is refused",
         %{tmp_dir: dir} do
      for n <- 1..20 do
        store = Path.join(dir, "#{n}.retain")
        both = for _ <- 1..2, do: opts(retain: store)
        go = self()

        tasks =
          for opts <- both do
            Task.async(fn ->
              receive do
                ^go -> :ok
              end

              started_or_refused(opts)
            end)
          end

        for task <- tasks, do: send(task.pid, go)
        answers = Enum.map(tasks, &Task.await/1)
        assert Enum.sort(Enum.map(answers, &elem(&1, 0))) == [:ok, :refused]
        for {:ok, pid} <- answers, do: assert(Runner.stop(pid) == :ok)
      end
    end

    # A file whose holder is down is taken over by one replace of exactly the dead holder's
    # claim: of several claims at once that each found it down, the one whose replace comes
    # second finds the claim changed and tries again, meeting the winner. Made on the VM's
    # table itself, four at once four thousand times, since the window between a claim's
    # look-up and its replace is a few instructions wide.
    test "of several claims at once on a file whose holder is down, one takes it over" do
      dead = spawn(fn -> :ok end)
      ref = Process.monitor(dead)
      assert_receive {:DOWN, ^ref, :process, ^dead, _reason}, 5000

      winners =
        for n <- 1..4000 do
          file = {"/logex-runner-paths-test/#{n}", :retain}
          :ok = Logex.Runner.Paths.claim([file], dead)
          test = self()

          claimers =
            for _ <- 1..4 do
              spawn(fn ->
                receive do
                  :go -> send(test, {:claimed, self(), Logex.Runner.Paths.claim([file], self())})
                end

                receive do
                  :done -> Logex.Runner.Paths.release([file], self())
                end
              end)
            end

          for claimer <- claimers, do: send(claimer, :go)

          answers =
            for claimer <- claimers do
              assert_receive {:claimed, ^claimer, answer}, 5000
              answer
            end

          for claimer <- claimers, do: send(claimer, :done)
          Enum.count(answers, &(&1 == :ok))
        end

      assert Enum.frequencies(winners) == %{1 => 4000}
    end

    # The take-over's race made in one process, through the claim's one seam, the holder's
    # liveness: the claimer's look at the dead holder, between its look-up of the holder's
    # claim and its replace of it, is where another claimer takes the file over, so that
    # its replace finds the claim changed and it tries again, meeting the winner, alive,
    # and is refused, where a replace that took nothing taken as a claim let both hold it.
    test "a claim whose take-over of a dead holder's file another made first is refused" do
      dead = spawn(fn -> :ok end)
      ref = Process.monitor(dead)
      assert_receive {:DOWN, ^ref, :process, ^dead, _reason}, 5000

      winner =
        spawn(fn ->
          receive do
            :done -> :ok
          end
        end)

      file = {"/logex-runner-paths-test/taken-over", :retain}
      :ok = Logex.Runner.Paths.claim([file], dead)

      meanwhile = fn
        ^dead ->
          :ok = Logex.Runner.Paths.claim([file], winner)
          false

        holder ->
          Process.alive?(holder)
      end

      assert Logex.Runner.Paths.claim([file], self(), meanwhile) ==
               {:held, "/logex-runner-paths-test/taken-over", winner, :retain}

      assert :ets.lookup(Logex.Runner.Paths, "/logex-runner-paths-test/taken-over") ==
               [{"/logex-runner-paths-test/taken-over", winner, :retain}]

      Logex.Runner.Paths.release([file], winner)
      send(winner, :done)
    end

    test "a path is free again once its holder stops, crashes or is killed", %{tmp_dir: dir} do
      store = Path.join(dir, "plant.retain")
      {:ok, first} = Runner.start_link(opts(retain: store))
      assert Runner.stop(first) == :ok
      assert claims(store) == []
      {:ok, second} = Runner.start_link(opts(retain: store))

      Process.unlink(second)
      ref = Process.monitor(second)
      Process.exit(second, :kill)
      assert_receive {:DOWN, ^ref, :process, ^second, :killed}
      {:ok, third} = Runner.start_link(opts(retain: store))

      # A start refused once its files are claimed, a device that cannot be opened, gives
      # them up at once, so that a start made right after finds them free.
      refused = opts(retain: Path.join(dir, "other.retain"))
      Sim.fail(panel(refused), :init, {:error, :no_card})
      assert Runner.start_link(refused) == {:error, {:io_init, "panel", :no_card}}
      assert claims(Path.join(dir, "other.retain")) == []
      {:ok, fourth} = Runner.start_link(opts(retain: Path.join(dir, "other.retain")))

      assert Runner.stop(third) == :ok
      assert Runner.stop(fourth) == :ok
    end
  end

  # An application of the test's own whose one child is a runner on the options its start
  # is given, standing for a host's application that starts the VM's first runner.
  defmodule Plant do
    use Application

    @impl true
    def start(_type, opts),
      do:
        Supervisor.start_link(
          [%{id: :runner, start: {Runner, :start_link, [opts]}, restart: :temporary}],
          strategy: :one_for_one
        )
  end

  describe "the VM's table of claims" do
    test "outlives an application's stop: one whose runner made the table, stopped, leaves " <>
           "every other runner's claims standing",
         %{tmp_dir: dir} do
      # The table made afresh, by the application's runner: its keeper gone first, the
      # claims of runners other tests left running with it, which no later test reads.
      table_gone(:ets.info(Logex.Runner.Paths, :owner))
      store = Path.join(dir, "plant.retain")
      app = :logex_paths_test_plant

      spec = [
        description: ~c"a host's plant",
        vsn: ~c"1",
        modules: [Plant],
        registered: [],
        applications: [:kernel, :stdlib],
        mod: {Plant, opts(retain: Path.join(dir, "app.retain"))}
      ]

      :ok = :application.load({:application, app, spec})
      on_exit(fn -> :application.unload(app) end)
      {:ok, _started} = Application.ensure_all_started(app)
      keeper = :ets.info(Logex.Runner.Paths, :owner)
      assert is_pid(keeper)

      # A runner of the test's own holds the store; the application's stop, which kills
      # every process whose group leader is the application's, leaves the keeper and the
      # claim, and a second runner on the store is still refused.
      {:ok, held} = Runner.start_link(opts(retain: store))
      :ok = Application.stop(app)
      assert Process.alive?(keeper)

      raises(held(:retain, store, "names the store", held), fn ->
        Runner.start_link(opts(retain: store))
      end)

      assert Runner.stop(held) == :ok
    end
  end

  describe "a fresh start's write (M11)" do
    test "a start refused {:already_started, pid} writes nothing", %{tmp_dir: dir} do
      store = Path.join(dir, "plant.retain")
      {:ok, first} = Runner.start_link([name: :rv4_paths_plant] ++ opts(retain: store))
      written = File.read!(store)
      other = Path.join(dir, "other.retain")

      for files <- [[retain: store, start: :cold], [retain: other, start: :cold], [retain: other]] do
        second = [name: :rv4_paths_plant] ++ opts(files)
        assert Runner.start_link(second) == {:error, {:already_started, first}}
        assert Sim.reads(panel(second)) == 0
      end

      assert File.read!(store) == written
      refute File.exists?(other)
      assert Runner.stop(first) == :ok
    end
  end

  describe "a relative path resolved once (c2-runner-persist-9)" do
    setup do
      cwd = File.cwd!()
      on_exit(fn -> File.cd!(cwd) end)
    end

    test "a File.cd after the start moves neither the store nor the forces file, and the " <>
           "absolute spelling of a relative path is the same file",
         %{tmp_dir: dir} do
      elsewhere = Path.join(dir, "elsewhere")
      File.mkdir_p!(elsewhere)
      File.cd!(dir)
      runner_opts = opts(retain: "plant.retain", forces: "plant.forces")
      {:ok, runner} = Runner.start_link(runner_opts)
      File.cd!(elsewhere)

      raises(held(:retain, Path.join(dir, "plant.retain"), "names the store", runner), fn ->
        Runner.start_link(opts(retain: Path.join(dir, "plant.retain")))
      end)

      assert Runner.force(runner, "eye_1", 1) == :ok
      assert Runner.status(runner).retain.path == "plant.retain"
      assert Runner.stop(runner) == :ok
      assert File.ls!(elsewhere) == []
      assert File.read!(Path.join(dir, "plant.forces")) == "eye_1 1\n"
      assert File.read!(Path.join(dir, "plant.retain")) =~ "t1.boxes.cv dint 0\n"
    end
  end
end
