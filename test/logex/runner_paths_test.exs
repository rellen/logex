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

  # The claims the VM's table holds for a store and its `.tmp`: a runner that stops, or
  # whose start is refused after it claimed them, gives them up as it ends, not merely by
  # being gone.
  defp claims(store),
    do: :ets.lookup(Logex.Runner.Paths, store) ++ :ets.lookup(Logex.Runner.Paths, store <> ".tmp")

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
