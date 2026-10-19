defmodule Logex.ForceTest do
  @moduledoc """
  M4-5: forcing through the runner (decisions 117 and 127, `docs/organisation.md` §4.11,
  "Forcing"), every rule on the manual clock with simulated devices: a forced input held
  against its device and across a restart, a forced trigger's round, `unforce/2` putting
  back the device's last value, `unforce_all/1`, the status's list, the forces file
  written whole before each call returns, a write that fails changing nothing, and every
  host mistake raised in the caller with the runner still alive.
  """
  use ExUnit.Case, async: true

  @moduletag :tmp_dir

  alias Logex.Configuration
  alias Logex.IO.Sim
  alias Logex.Runner
  alias Logex.Runner.Clock.Manual

  # A stand-in for Logex.Runtime's steps whose step of the task `trip` takes 505 ms of the
  # runner's manual clock, which the test put in this module's table under the runner.
  defmodule SlowTrip do
    alias Logex.Runtime

    def cycle_steps(runtime, elapsed, inputs), do: Runtime.cycle_steps(runtime, elapsed, inputs)
    def cycle_outputs(runtime), do: Runtime.cycle_outputs(runtime)

    def cycle_step(runtime, {_kind, "trip", _run} = step) do
      [{_runner, clock}] = :ets.lookup(Logex.ForceTest, self())
      Manual.pass(clock, 505)
      Runtime.cycle_step(runtime, step)
    end

    def cycle_step(runtime, step), do: Runtime.cycle_step(runtime, step)
  end

  # A panel whose reads give nothing: no input point has a value from its device.
  defmodule QuietIO do
    @behaviour Logex.IO

    @impl true
    def init(_device, _points, _opts), do: {:ok, nil}

    @impl true
    def read(state), do: {:ok, %{}, state}

    @impl true
    def write(_values, state), do: {:ok, state}
  end

  setup_all do
    :ets.new(__MODULE__, [:named_table, :public])
    :ok
  end

  defp program(source, name) do
    {:ok, program} = Logex.compile(source, name: name)
    program
  end

  # The relay on a 10 ms task, from the panel's `x` to its `y`; an event task on the
  # panel's `e` counting its rises into `hits`, the drive's one output; a dint input, a
  # global at no device, and an output point.
  @plant """
  task fast interval 10 priority 1
  task trip single e priority 0

  var_global x     bool at panel.i.0
  var_global e     bool at panel.i.1
  var_global level dint at panel.i.2
  var_global y     bool at panel.q.0
  var_global hits  dint at drive.q.0
  var_global seen  dint

  program r relay with fast
    r.in  x
    r.out y

  program c count with trip
    c.n hits

  program m copy with fast
    m.in  level
    m.out seen
  """

  defp plant do
    {:ok, config} = Configuration.compile("plant", @plant, programs())
    config
  end

  defp programs do
    %{
      "relay" => program("var_input in bool\nvar_output out bool\nxic in ote out", "relay"),
      "count" => program("var_output n dint\nadd n 1 n", "count"),
      "copy" => program("var_input in dint\nvar_output out dint\nmove in out", "copy")
    }
  end

  # The plant on a manual clock, the panel reporting and the drive only read, its forces
  # kept in `forces` under the test's directory unless `extra` says otherwise.
  defp started(dir, extra \\ []) do
    {:ok, clock} = Manual.start_link()
    {:ok, panel} = Sim.start_link(reports: true, clock: clock)
    {:ok, drive} = Sim.start_link(clock: clock)
    file = Path.join(dir, "forces")

    {:ok, runner} =
      Runner.start_link(
        [
          configuration: plant(),
          io: %{"panel" => {Sim, sim: panel}, "drive" => {Sim, sim: drive}},
          clock: {Manual, clock},
          forces: file
        ]
        |> Keyword.merge(extra)
      )

    %{runner: runner, clock: clock, panel: panel, drive: drive, file: file}
  end

  defp raises(message, fun), do: assert_raise(ArgumentError, message, fun)

  describe "a force (decision 117)" do
    test "holds an input point against its device, from the next round, until unforced",
         %{tmp_dir: dir} do
      %{runner: runner, clock: clock, panel: panel, file: file} = started(dir)
      assert Runner.force(runner, "x", 1) == :ok
      assert Runner.status(runner).forces == %{"x" => 1}

      # Its device says 0 and then 1 and 0 again; the controller reads 1 throughout.
      Manual.advance(clock, 10)
      assert Sim.outputs(panel) == %{[0] => 1}
      Sim.set(panel, [0], 1)
      Sim.set(panel, [0], 0)
      Manual.advance(clock, 10)
      assert Runner.get!(runner, "x") == 1
      assert Sim.outputs(panel) == %{[0] => 1}
      assert File.read!(file) == "x 1\n"

      # Forced to 0 against a device that says 1, and then unforced: the next round reads
      # the device's last value, 1, which no report brought again.
      Sim.set(panel, [0], 1)
      assert Runner.force(runner, "x", 0) == :ok
      Manual.advance(clock, 10)
      assert Sim.outputs(panel) == %{[0] => 0}
      assert File.read!(file) == "x 0\n"
      assert Runner.unforce(runner, "x") == :ok
      assert Runner.status(runner).forces == %{}
      assert File.read!(file) == ""
      Manual.advance(clock, 10)
      assert Runner.get!(runner, "x") == 1
      assert Sim.outputs(panel) == %{[0] => 1}
    end

    test "a device's change while forced is kept, and an unforce puts back the last one",
         %{tmp_dir: dir} do
      %{runner: runner, clock: clock, panel: panel} = started(dir)
      Runner.force(runner, "level", 7)
      Manual.advance(clock, 10)
      assert Runner.get!(runner, "seen") == 7

      for value <- [3, 9, -4], do: Sim.set(panel, [2], value)
      Manual.advance(clock, 10)
      assert Runner.get!(runner, "seen") == 7

      Runner.unforce(runner, "level")
      Manual.advance(clock, 10)
      assert Runner.get!(runner, "seen") == -4
    end

    test "an unforce of a point no device has given a value puts back the input image's",
         %{tmp_dir: dir} do
      %{runner: runner, clock: clock} =
        started(dir, io: %{"panel" => QuietIO, "drive" => QuietIO})

      Runner.force(runner, "level", 7)
      Manual.advance(clock, 10)
      Runner.unforce(runner, "level")
      Manual.advance(clock, 10)
      assert Runner.get!(runner, "seen") == 0
    end

    test "the file holds every force, one a line, in name order, and unforce_all/1 " <>
           "writes it empty",
         %{tmp_dir: dir} do
      %{runner: runner, clock: clock, panel: panel, file: file} = started(dir)
      Sim.set(panel, %{[0] => 1, [2] => 5})
      Runner.force(runner, "x", 0)
      Runner.force(runner, "level", -12)
      Runner.force(runner, "x", 0)
      assert File.read!(file) == "level -12\nx 0\n"
      assert Runner.status(runner).forces == %{"x" => 0, "level" => -12}
      Manual.advance(clock, 10)
      assert {Runner.get!(runner, "y"), Runner.get!(runner, "seen")} == {0, -12}

      # Every force off, each point back to its device's last value.
      assert Runner.unforce_all(runner) == :ok
      assert File.read!(file) == ""
      assert Runner.status(runner).forces == %{}
      Manual.advance(clock, 10)
      assert {Runner.get!(runner, "y"), Runner.get!(runner, "seen")} == {1, 5}

      # Nothing is left beside it.
      assert File.ls!(dir) == ["forces"]
    end

    test "an unforce of a point not forced changes nothing, and writes the set again",
         %{tmp_dir: dir} do
      %{runner: runner, file: file} = started(dir)
      Runner.force(runner, "level", 1)
      File.write!(file, "stale")
      assert Runner.unforce(runner, "x") == :ok
      assert Runner.status(runner).forces == %{"level" => 1}
      assert File.read!(file) == "level 1\n"
    end

    test "holds across a restart", %{tmp_dir: dir} do
      %{runner: runner, clock: clock, panel: panel} = started(dir)
      Runner.force(runner, "x", 1)
      Manual.advance(clock, 10)

      # A value that does not fit trips it; put right, it restarts with the force on.
      Sim.set(panel, [1], 5)
      assert %{status: :tripped, forces: %{"x" => 1}} = Runner.status(runner)
      Sim.set(panel, [1], 0)
      assert Runner.restart(runner, :cold) == :ok
      assert %{status: :running, forces: %{"x" => 1}} = Runner.status(runner)
      assert Runner.get!(runner, "y") == 1
      assert List.last(Sim.writes(panel)) == %{[0] => 1}
    end

    test "is taken while tripped, and the restart's first round reads it", %{tmp_dir: dir} do
      %{runner: runner, clock: clock, panel: panel} = started(dir)
      Manual.advance(clock, 10)
      Sim.set(panel, [1], 5)
      assert Runner.status(runner).status == :tripped
      assert Runner.force(runner, "x", 1) == :ok
      Sim.set(panel, [1], 0)
      Runner.restart(runner, :cold)
      assert Runner.get!(runner, "y") == 1
    end
  end

  describe "a forced trigger (decisions 117 and 120)" do
    test "a force that changes a trigger makes its round at once, before it returns",
         %{tmp_dir: dir} do
      %{runner: runner, panel: panel, drive: drive} = started(dir)
      rounds = Runner.status(runner).rounds

      assert Runner.force(runner, "e", 1) == :ok
      assert Sim.outputs(drive) == %{[0] => 1}
      assert Runner.status(runner).rounds == rounds + 1

      # Forced again to what it reads: no change, no round.
      Runner.force(runner, "e", 1)
      assert Runner.status(runner).rounds == rounds + 1

      # Its device's changes change nothing the controller reads, and make no round.
      Sim.set(panel, [1], 1)
      Sim.set(panel, [1], 0)
      assert Runner.status(runner).rounds == rounds + 1
      assert Runner.get!(runner, "hits") == 1

      # Unforced, it reads its device's 0: a change, a round, and no rise.
      Runner.unforce(runner, "e")
      assert Runner.status(runner).rounds == rounds + 2
      assert Runner.get!(runner, "e") == 0

      # Forced to 1 again, a rise: counted, at once.
      Runner.force(runner, "e", 1)
      assert Sim.outputs(drive) == %{[0] => 2}
      assert Runner.status(runner).rounds == rounds + 3

      # unforce_all/1's change of it makes one round too.
      Runner.unforce_all(runner)
      assert Runner.status(runner).rounds == rounds + 4
    end

    test "while tripped a forced trigger makes no round", %{tmp_dir: dir} do
      %{runner: runner, panel: panel} = started(dir)
      Sim.set(panel, [1], 5)
      %{rounds: rounds, status: :tripped} = Runner.status(runner)
      Runner.force(runner, "e", 1)
      assert Runner.status(runner).rounds == rounds
    end

    test "a force of a point that is no trigger makes no round", %{tmp_dir: dir} do
      %{runner: runner} = started(dir)
      rounds = Runner.status(runner).rounds
      Runner.force(runner, "x", 1)
      Runner.unforce(runner, "x")
      assert Runner.status(runner).rounds == rounds
    end
  end

  describe "the forces file (decision 127)" do
    test "holds every force in name order, however many", %{tmp_dir: dir} do
      names = for n <- 0..39, do: "p" <> String.pad_leading(Integer.to_string(n), 2, "0")

      text =
        "task fast interval 10 priority 1\n" <>
          Enum.map_join(Enum.with_index(names), fn {name, n} ->
            "var_global #{name} bool at panel.i.#{n}\n"
          end) <>
          "var_global y bool at panel.q.0\nvar_global z bool at drive.q.0\n" <>
          "program r relay with fast\n  r.in p00\n  r.out y\n"

      relay = program("var_input in bool\nvar_output out bool\nxic in ote out", "relay")
      {:ok, config} = Configuration.compile("many", text, %{"relay" => relay})
      %{runner: runner, file: file} = started(dir, configuration: config)
      for name <- Enum.shuffle(names), do: :ok = Runner.force(runner, name, 1)
      assert File.read!(file) == Enum.map_join(names, &"#{&1} 1\n")
    end

    test "each write is a new file beside it, renamed over it, never the old one written " <>
           "in place, so that a crash leaves the old set or the new",
         %{tmp_dir: dir} do
      %{runner: runner, file: file} = started(dir)
      Runner.force(runner, "x", 1)
      %File.Stat{inode: first} = File.stat!(file)
      Runner.force(runner, "level", 2)
      %File.Stat{inode: second} = File.stat!(file)
      assert first != second
      assert File.read!(file) == "level 2\nx 1\n"
    end

    test "a write that fails changes nothing and gives {:error, {:forces, reason}}",
         %{tmp_dir: dir} do
      %{runner: runner, clock: clock, panel: panel} =
        started(dir, forces: Path.join([dir, "gone", "forces"]))

      assert Runner.force(runner, "x", 1) == {:error, {:forces, :enoent}}
      assert Runner.status(runner).forces == %{}
      Manual.advance(clock, 10)
      assert Sim.outputs(panel) == %{[0] => 0}
      assert File.ls!(dir) == []
    end

    test "a rename that fails leaves the file and the forces as they were, nothing beside it",
         %{tmp_dir: dir} do
      %{runner: runner, clock: clock, panel: panel, file: file} = started(dir)
      Runner.force(runner, "x", 1)

      # The path is taken by a directory: the new set cannot be renamed over it.
      File.rm!(file)
      File.mkdir!(file)
      assert Runner.unforce(runner, "x") == {:error, {:forces, :eisdir}}
      assert Runner.unforce_all(runner) == {:error, {:forces, :eisdir}}
      assert Runner.force(runner, "level", 3) == {:error, {:forces, :eisdir}}
      assert Runner.status(runner).forces == %{"x" => 1}
      assert File.ls!(dir) == ["forces"]
      Manual.advance(clock, 10)
      assert Sim.outputs(panel) == %{[0] => 1}
    end
  end

  describe "a forced trigger's round, timed by its steps" do
    test "is not the request's: a force is timed against the idle watchdog without it",
         %{tmp_dir: dir} do
      config =
        Configuration.compile(
          "plant",
          String.replace(@plant, "single e priority 0", "single e priority 0 watchdog 2000"),
          programs()
        )
        |> elem(1)

      %{runner: runner, clock: clock} = started(dir, configuration: config, steps: SlowTrip)
      :ets.insert(__MODULE__, {runner, clock})
      Runner.subscribe(runner)

      # Its round takes 505 ms, longer than the idle watchdog, within its own watchdog.
      assert Runner.force(runner, "e", 1) == :ok

      assert %{status: :running, rounds: 2, runs: %{"trip" => {505, 2000}}} =
               Runner.status(runner)

      refute_received {Runner, ^runner, {:trip, _reason}}
      assert Runner.get!(runner, "hits") == 1
    end
  end

  describe "the host's mistakes, raised in the caller with the runner still alive" do
    test "a runner started without forces: takes no force", %{tmp_dir: dir} do
      %{runner: runner} = started(dir, forces: nil)

      message =
        "the runner keeps no forces file, so a force would not survive a crash: start it " <>
          "with forces: a path"

      raises(message, fn -> Runner.force(runner, "x", 1) end)
      raises(message, fn -> Runner.unforce(runner, "x") end)
      raises(message, fn -> Runner.unforce_all(runner) end)
      assert Runner.status(runner).forces == %{}
    end

    test "forces: that is no path" do
      for bad <- [:forces, "", ~c"forces", 1] do
        raises(
          "the runner's forces: is the path of the file its forces are kept in, a string, " <>
            "got: #{inspect(bad)}",
          fn -> started(System.tmp_dir!(), forces: bad) end
        )
      end
    end

    test "a point that is no input point's, by what it is", %{tmp_dir: dir} do
      %{runner: runner} = started(dir)

      raises("`y` is an output point, at `panel.q.0`: only an input point is forced", fn ->
        Runner.force(runner, "y", 1)
      end)

      raises("`hits` is an output point, at `drive.q.0`: only an input point is forced", fn ->
        Runner.unforce(runner, "hits")
      end)

      raises("`seen` is no input point of `plant`", fn -> Runner.force(runner, "seen", 1) end)

      raises("`levl` is no input point of `plant` — did you mean `level`?", fn ->
        Runner.force(runner, "levl", 1)
      end)

      raises(
        "`X` is no input point of `plant` — did you mean `x`? (names are case-sensitive)",
        fn ->
          Runner.unforce(runner, "X")
        end
      )

      raises(
        ~s|a force names an input point by its name, a string, as in "eye_1", got: :x|,
        fn -> Runner.force(runner, :x, 1) end
      )

      assert Runner.status(runner).forces == %{}
    end

    test "a configuration with no input point says so", %{tmp_dir: dir} do
      {:ok, config} =
        Configuration.compile(
          "plain",
          "task fast interval 10 priority 1\nvar_global y dint at panel.q.0\n" <>
            "program c count with fast\n  c.n y\n",
          %{"count" => program("var_output n dint\nadd n 1 n", "count")}
        )

      {:ok, clock} = Manual.start_link()
      {:ok, panel} = Sim.start_link(clock: clock)

      {:ok, runner} =
        Runner.start_link(
          configuration: config,
          io: %{"panel" => {Sim, sim: panel}},
          clock: {Manual, clock},
          forces: Path.join(dir, "forces")
        )

      raises(
        "`x` is no input point of `plain`, which has none: only an input point is forced",
        fn ->
          Runner.force(runner, "x", 1)
        end
      )
    end

    test "a value that does not fit its point", %{tmp_dir: dir} do
      %{runner: runner, file: file} = started(dir)

      for value <- [2, -1, 1.0, true, "1"] do
        raises("`x` is a bool, forced to 0 or 1, got: #{inspect(value)}", fn ->
          Runner.force(runner, "x", value)
        end)
      end

      for value <- [2_147_483_648, -2_147_483_649, 1.5] do
        raises(
          "`level` is a dint, forced to an integer from -2147483648 to 2147483647, got: " <>
            inspect(value),
          fn -> Runner.force(runner, "level", value) end
        )
      end

      assert Runner.force(runner, "level", -2_147_483_648) == :ok
      assert Runner.force(runner, "level", 2_147_483_647) == :ok
      assert File.read!(file) == "level 2147483647\n"
    end
  end
end
