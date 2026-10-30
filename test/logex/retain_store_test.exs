defmodule Logex.RetainStoreTest do
  # M6-5 (docs/organisation.md §4.13, decisions 271, 275, 276, 284, 285, 291 and 292): the
  # store, the file on the host's disk a runner given `retain:` writes its retained values
  # into, at a trip, a stop and a cold restart, and a fresh start reads, warm unless
  # `start: :cold`, all on the manual clock.
  use ExUnit.Case, async: true

  alias Logex.{Configuration, Retain, Runner, Runtime}
  alias Logex.IO.Sim
  alias Logex.Runner.Clock.Manual

  @moduletag :tmp_dir
  @moduletag capture_log: true

  # A box counter, a retained global it totals through its var_external, a lamp it latches
  # and keeps, and an unretained one-shot.
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

  @plant """
  task fast interval 10 priority 1
  var_global eye_1 bool at panel.i.0
  var_global clr bool at panel.i.1
  var_global lamp_q bool at panel.q.0
  var_global retain total_boxes dint 0
  var_global shown dint
  program t1 tally with fast
    t1.eye eye_1
    t1.clear clr
    t1.count shown
    t1.lamp lamp_q
  """

  # The simulated device, which tells the test the store's text as each read and each
  # write finds it, so that a test sees what the store held when a device was read or
  # written: the stop's zeros before its write, a cold restart's write before its reads.
  defmodule Watching do
    @behaviour Logex.IO

    @impl true
    def check(device, points, opts), do: Sim.check(device, points, Keyword.take(opts, [:sim]))

    @impl true
    def init(device, points, opts) do
      {:ok, state} = Sim.init(device, points, Keyword.take(opts, [:sim]))
      {:ok, {state, opts[:store], opts[:test]}}
    end

    @impl true
    def read({state, store, test}) do
      send(test, {:read, File.read(store)})
      wrapped(Sim.read(state), store, test)
    end

    @impl true
    def write(values, {state, store, test}) do
      send(test, {:written, values, File.read(store)})
      wrapped(Sim.write(values, state), store, test)
    end

    defp wrapped({:ok, values, state}, store, test), do: {:ok, values, {state, store, test}}
    defp wrapped({:ok, state}, store, test), do: {:ok, {state, store, test}}
    defp wrapped({:error, reason, state}, store, test), do: {:error, reason, {state, store, test}}

    @impl true
    def close({state, _store, _test}), do: Sim.close(state)
  end

  defp programs(text \\ @tally) do
    {:ok, tally} = Logex.compile(text, name: "tally")
    %{"tally" => tally}
  end

  defp configured(source \\ @plant, programs \\ programs()) do
    {:ok, config} = Configuration.compile("plant", source, programs)
    config
  end

  # A clock started at a time a store's header names to the second, 2026-10-30T14:00:00Z.
  @wall 1_793_368_800_000

  defp rig(dir, extra \\ []) do
    {:ok, clock} = Manual.start_link(now: @wall)
    {:ok, panel} = Sim.start_link(clock: clock)
    store = Path.join(dir, "plant.retain")

    opts =
      [
        configuration: configured(),
        io: %{"panel" => {Sim, sim: panel}},
        clock: {Manual, clock},
        poll: 10,
        retain: store
      ]
      |> Keyword.merge(extra)

    %{clock: clock, panel: panel, store: store, opts: opts}
  end

  defp pressed(%{panel: panel, clock: clock}, eyes) do
    for eye <- eyes do
      Sim.set(panel, [0], eye)
      Manual.advance(clock, 10)
    end
  end

  # The panel's read failed, and the runner seen to have taken the device's notice of it,
  # which comes as a message of its own.
  defp tripped(%{panel: panel, clock: clock}, runner) do
    Sim.fail(panel, :read, {:error, :eio})
    Manual.advance(clock, 10)
    assert %{status: :tripped} = Runner.status(runner)
  end

  defp killed(runner) do
    Process.unlink(runner)
    ref = Process.monitor(runner)
    Process.exit(runner, :kill)
    assert_receive {:DOWN, ^ref, :process, _, :killed}
  end

  # The sim's opener gone down, so that a runner started on it again can open it (commit
  # 2adf13a): its device process traps the runner's exit and closes as it goes.
  defp opener_down(panel) do
    holder = GenServer.call(panel, :holder)
    down(holder)
  end

  defp down(nil), do: :ok

  defp down({pid, _device}) do
    ref = Process.monitor(pid)
    assert_receive {:DOWN, ^ref, :process, _, _}, 5000
  end

  defp values(runner),
    do: for(path <- ~w(total_boxes t1.boxes.cv t1.lamp shown), do: Runner.get!(runner, path))

  defp raises(message, fun), do: assert_raise(ArgumentError, message, fun)

  describe "the store's text (decision 276)" do
    # Every part of a resource's image among its lines: a retained global, an array global,
    # a trigger's last sample (decision 313), an instance with a built-in, an array of a
    # user block's instances, a real array, a two-dimensional array and an lreal, each
    # value in decimal or in the shortest text that reads back to its real.
    test "a resource's image written as the record's lines and read back exactly" do
      {:ok, gate} =
        Logex.compile(
          "function_block gate\nvar_input go bool\nvar retain k dint\nxic go add k 1 k",
          name: "gate"
        )

      {:ok, motor} =
        Logex.compile(
          "var_input eye bool\nvar retain boxes ctu\nvar retain lube rto\n" <>
            "var retain w real[3] 0.1 -2.5 3.4e38\nvar retain g int[2,2] 1 2 3 4\n" <>
            "var retain z lreal 0.1\nvar retain gs gate[2]\nvar retain x bool 1\nvar e bool\n" <>
            "xic eye ctu boxes 1000\nxic eye rto lube 360000000\nxic eye cal gs[1] eye",
          name: "motor",
          types: [gate]
        )

      source = """
      task fast interval 10 priority 1
      task ev single arm priority 0
      var_global eye_1 bool at panel.i.0
      var_global retain total_boxes dint 41
      var_global retain limits int[3] 10 -20 30
      var_global retain arm bool
      var_global plain dint 7
      program m1 motor with fast
        m1.eye eye_1
      """

      config = configured(source, %{"motor" => motor})
      rt = Runtime.start(config)
      {rt, _, _} = Runtime.cycle(rt, 0, %{"eye_1" => 0})
      {rt, _, _} = Runtime.cycle(rt, 10, %{"eye_1" => 1})
      {rt, _, _} = Runtime.cycle(rt, 10, %{"eye_1" => 1})
      image = Runtime.retained(rt)
      text = Retain.encode(image, Retain.at(@wall + 999))

      assert text == """
             logex retain 1
             configuration plant written 2026-10-30T14:00:00Z
             global arm bool 0
             global limits int[3] 10 -20 30
             global total_boxes dint 41
             trigger arm 0
             instance m1 motor
             m1.boxes ctu
             m1.boxes.cu bool 1
             m1.boxes.cv dint 1
             m1.boxes.ov bool 0
             m1.boxes.pv dint 1000
             m1.boxes.q bool 0
             m1.boxes.r bool 0
             m1.g int[2,2] 1 2 3 4
             m1.gs gate[2]
             m1.gs[0].go bool 0
             m1.gs[0].k dint 0
             m1.gs[1].go bool 1
             m1.gs[1].k dint 2
             m1.lube rto
             m1.lube.acc dint 10
             m1.lube.dn bool 0
             m1.lube.en bool 1
             m1.lube.pre dint 360000000
             m1.lube.r bool 0
             m1.lube.tt bool 1
             m1.w real[3] 0.1 -2.5 3.4e38
             m1.x bool 1
             m1.z lreal 0.1
             """

      assert Retain.decode!(text, {"plant.retain", "plant"}) ==
               {image, ~U[2026-10-30 14:00:00Z]}

      # Read back, it starts the resource a warm restart does, dropping nothing.
      assert Runtime.start(config, image) |> elem(1) == []
    end

    # Path order is by the subscripts' values, `t[2]` before `t[10]`, as the drops are
    # (`Logex.Image.ordered/1`), where the text's order would put `t[10]` first.
    test "an instance's lines in path order, element by its subscripts' values" do
      {:ok, timers} =
        Logex.compile("var retain t ton[11]\nvar go bool\nxic go ton t[10] 50",
          name: "timers"
        )

      config = configured("program m1 timers\n", %{"timers" => timers})
      text = Retain.encode(Runtime.retained(Runtime.start(config)), ~U[2026-10-30 14:00:00Z])
      lines = String.split(text, "\n")
      at = &Enum.find_index(lines, fn line -> line == &1 end)
      assert at.("m1.t ton[11]") < at.("m1.t[2].acc dint 0")
      assert at.("m1.t[2].acc dint 0") < at.("m1.t[10].acc dint 0")
      assert at.("m1.t[9].tt bool 0") + 1 == at.("m1.t[10].acc dint 0")
    end

    # A person's hand edit (decision 284) reads any number the lexer reads, as a forces
    # file's line does (decisions 218 and 226), a real at its type's nearest value, and a
    # subscript with leading zeros, which the start matches by its value (decision 312).
    test "a hand edit's numbers read by their values" do
      text = """
      logex retain 1
      configuration plant written 2026-10-30T14:00:00+00:00
      global total_boxes dint 16#29
      instance t1 tally
      t1.boxes ctu
      t1.boxes.cv dint 1_000
      t1.w real[2] 0.1 7
      """

      assert {%{globals: %{"total_boxes" => {:dint, 41}}, instances: %{"t1" => t1}},
              ~U[2026-10-30 14:00:00Z]} = Retain.decode!(text, {"s", "plant"})

      assert t1 == %{
               program: "tally",
               kinds: %{"boxes" => "ctu"},
               values: %{
                 "boxes.cv" => {:dint, 1000},
                 "w" => {{:array, :real, [2]}, [0.10000000149011612, 7]}
               }
             }
    end

    # Every line a store cannot be read by, each a line of one ArgumentError, in line
    # order, the store's path and the line's number before each (decisions 276 and 285).
    test "a store that does not read is refused, a line each" do
      text = """
      logex retain 2
      configuration other written junk
      global x foo 1
      m1.a dint 1
      instance m1 motor
      m2.a dint 1
      m1.b dint x
      m1.c int[2] 1
      m1.d ton[0]
      global x dint 1
      global x dint 2
      m1.e dint 1 2
      global 1x dint 1
      instance m2 9p
      trigger arm on
      m2.f  dint 1

      """

      raises(
        Enum.join(
          [
            "s: line 1: the store is of version 2, which this logex does not read: it reads " <>
              "`logex retain 1`",
            "s: line 2: the store is of configuration `other`, and this configuration is " <>
              "`plant`: a store starts only the configuration it was written for, so a " <>
              "renamed configuration starts only cold: start it with start: :cold to start " <>
              "over it",
            "s: line 2: `junk` is no time a store is written at, in UTC, as 2026-10-27T14:00:00Z",
            "s: line 3: `foo` is no type of a retained value: an elementary type's word, or " <>
              "an array of one, as `int[8]`",
            "s: line 4: `m1.a dint 1` comes before any `instance` line: an instance's lines " <>
              "follow its own",
            "s: line 6: `m2.a dint 1` is not under the instance `m1` whose lines it follows",
            "s: line 7: `x` is no number",
            "s: line 8: `int[2]` holds 2 values, one an element, in the elements' order",
            "s: line 9: `ton[0]` is no kind of instance: a built-in's or a block's name, or " <>
              "an array of its instances, as `ton[4]`",
            "s: line 11: `global x dint 2` names what line 10 names already",
            "s: line 12: `dint` holds one value, and the line gives 2",
            "s: line 13: `1x` names no global",
            "s: line 14: `9p` names no program type",
            "s: line 15: `on` is no number",
            "s: line 16: `m2.f  dint 1` is no line of a store: a line is `global <name> " <>
              "<type> <value>`, `trigger <name> <sample>`, `instance <name> <program type>`, " <>
              "`<path> <kind>` or `<path> <type> <value>`",
            "s: line 17: `` is no line of a store: a line is `global <name> <type> <value>`, " <>
              "`trigger <name> <sample>`, `instance <name> <program type>`, `<path> <kind>` " <>
              "or `<path> <type> <value>`"
          ],
          "\n"
        ),
        fn -> Retain.decode!(text, {"s", "plant"}) end
      )

      raises("s: line 1: the store is empty: its first line is `logex retain 1`", fn ->
        Retain.decode!("", {"s", "plant"})
      end)

      raises(
        "s: line 1: `logex forces 1` is no store's header: a store's first line is " <>
          "`logex retain 1`\ns: line 2: the store names no configuration: its second line " <>
          "is `configuration <name> written <time>`",
        fn -> Retain.decode!("logex forces 1\n", {"s", "plant"}) end
      )

      raises(
        "s: line 2: `configuration plant` names no configuration: a store's second line is " <>
          "`configuration <name> written <time>`",
        fn -> Retain.decode!("logex retain 1\nconfiguration plant", {"s", "plant"}) end
      )

      # A last line with no newline is read.
      assert {%{configuration: "plant"}, ~U[2026-10-30 14:00:00Z]} =
               Retain.decode!(
                 "logex retain 1\nconfiguration plant written 2026-10-30T14:00:00Z",
                 {"s", "plant"}
               )
    end
  end

  describe "a hand edit's header and paths (decisions 276 and 284)" do
    # The header's time is UTC, as the runner writes it: a time at another offset names
    # another moment than it seems to, and is refused, `Z` and `+00:00` taken.
    test "a time at an offset other than UTC is refused" do
      at = fn time -> "logex retain 1\nconfiguration plant written #{time}\n" end

      for time <- ["2026-10-30T14:00:00+05:00", "2026-10-30T14:00:00-01:00"] do
        raises(
          "s: line 2: `#{time}` is no time a store is written at, in UTC, as " <>
            "2026-10-27T14:00:00Z",
          fn -> Retain.decode!(at.(time), {"s", "plant"}) end
        )
      end

      for time <- ["2026-10-30T14:00:00Z", "2026-10-30T14:00:00+00:00"] do
        assert {_image, ~U[2026-10-30 14:00:00Z]} = Retain.decode!(at.(time), {"s", "plant"})
      end
    end

    # A line's path is the instance's name, a `.` and a path inside it: the name and a `.`
    # alone name nothing inside it.
    test "a path that names nothing inside its instance is refused" do
      raises(
        "s: line 4: `m1. dint 1` is not under the instance `m1` whose lines it follows\n" <>
          "s: line 5: `m1. ton` is not under the instance `m1` whose lines it follows",
        fn ->
          Retain.decode!(
            "logex retain 1\nconfiguration plant written 2026-10-30T14:00:00Z\n" <>
              "instance m1 motor\nm1. dint 1\nm1. ton\n",
            {"s", "plant"}
          )
        end
      )
    end
  end

  describe "a hand edit's sizes (decisions 276 and 284)" do
    # A type word or a kind with sizes is read by the store's own rule, never handed to a
    # reader that takes the lexer's word for the text: brackets or sizes no array has are
    # refused as any word the store does not read, a line each, where `real[3a]`,
    # `int[2#]` and `real[]]` raised a FunctionClauseError and `int[-1]` and `int[0]` were
    # told how many values they hold.
    test "brackets or sizes no array has are refused, a line each" do
      words =
        ~w(real[3a] int[2#] real[]] int[-1] int[0] int[] int[2 int[2]x int[2,] int[1,1,1,1]
           int[65537] int[2.0] int[x] foo[2])

      bad_kinds = ~w(ton[3a ton[4[ ton[2,0] ton[] ton[-1] ton[4]] ton[1,1,1,1])

      # Each line its own path, so that none names what another names.
      lines =
        Enum.with_index(words, &"m1.v#{&2} #{&1} 1") ++
          Enum.with_index(bad_kinds, &"m1.k#{&2} #{&1}")

      text =
        Enum.join(
          [
            "logex retain 1",
            "configuration plant written 2026-10-30T14:00:00Z",
            "instance m1 motor"
          ] ++ lines,
          "\n"
        )

      types =
        for {word, n} <- Enum.with_index(words, 4),
            do:
              "s: line #{n}: `#{word}` is no type of a retained value: an elementary type's " <>
                "word, or an array of one, as `int[8]`"

      kinds =
        for {kind, n} <-
              Enum.with_index(
                bad_kinds,
                4 + length(words)
              ),
            do:
              "s: line #{n}: `#{kind}` is no kind of instance: a built-in's or a block's " <>
                "name, or an array of its instances, as `ton[4]`"

      raises(Enum.join(types ++ kinds, "\n"), fn -> Retain.decode!(text, {"s", "plant"}) end)

      # Each size any whole number the lexer reads, in either case of the type word, the
      # largest array there is among them.
      assert {%{instances: %{"m1" => m1}}, _at} =
               Retain.decode!(
                 Enum.join(
                   [
                     "logex retain 1",
                     "configuration plant written 2026-10-30T14:00:00Z",
                     "instance m1 motor",
                     "m1.a INT[16#2] 1 2",
                     "m1.b bool[1,1_0,1] " <> Enum.join(List.duplicate("0", 10), " "),
                     "m1.c ton[2,3]",
                     "m1.d sint[65536] " <> Enum.join(List.duplicate("0", 65_536), " ")
                   ],
                   "\n"
                 ),
                 {"s", "plant"}
               )

      assert m1.kinds == %{"c" => {:array, "ton", [2, 3]}}
      assert m1.values["a"] == {{:array, :int, [2]}, [1, 2]}
      assert {{:array, :bool, [1, 10, 1]}, _} = m1.values["b"]
      assert {{:array, :sint, [65_536]}, _} = m1.values["d"]
    end

    test "a store whose sizes no array has starts nothing", %{tmp_dir: dir} do
      rig = rig(dir)

      for word <- ~w(real[3a] int[2#] real[]]) do
        File.write!(
          rig.store,
          "logex retain 1\nconfiguration plant written 2026-10-30T14:00:00Z\n" <>
            "global total_boxes #{word} 1 2 3\n"
        )

        raises(
          "#{rig.store}: line 3: `#{word}` is no type of a retained value: an elementary " <>
            "type's word, or an array of one, as `int[8]`",
          fn -> Runner.start_link(rig.opts) end
        )
      end

      assert Sim.reads(rig.panel) == 0
    end
  end

  describe "the runner's retain: and start: (decisions 271, 275 and 285)" do
    test "each checked in the caller, a pinned message each", %{tmp_dir: dir} do
      rig = rig(dir)

      for bad <- ["", :x, 5] do
        raises(
          "the runner's retain: is the path of the file its retained values are kept in, a " <>
            "string, got: #{inspect(bad)}",
          fn -> Runner.start_link(Keyword.put(rig.opts, :retain, bad)) end
        )
      end

      raises(
        "the runner's retain: and forces: name one file, #{inspect(rig.store)}: the store and " <>
          "the forces file are two files",
        fn -> Runner.start_link(Keyword.put(rig.opts, :forces, rig.store)) end
      )

      # One file named two ways is one file, and neither may be the `.tmp` the other is
      # written through, which each write would replace with its own text.
      raises(
        "the runner's retain: #{inspect(rig.store)} and forces: " <>
          "#{inspect(Path.join([dir, ".", "plant.retain"]))} name one file, " <>
          "#{inspect(rig.store)}: the store and the forces file are two files",
        fn ->
          Runner.start_link(Keyword.put(rig.opts, :forces, Path.join([dir, ".", "plant.retain"])))
        end
      )

      raises(
        "the runner's retain: #{inspect(rig.store <> ".tmp")} is the file its forces: " <>
          "#{inspect(rig.store)} is written through, each written whole to the `.tmp` beside " <>
          "it and renamed over it: the store and the forces file are two files, neither the " <>
          "other's `.tmp`",
        fn ->
          Runner.start_link(
            rig.opts
            |> Keyword.put(:forces, rig.store)
            |> Keyword.put(:retain, rig.store <> ".tmp")
          )
        end
      )

      raises(
        "the runner's forces: #{inspect(rig.store <> ".tmp")} is the file its retain: " <>
          "#{inspect(rig.store)} is written through, each written whole to the `.tmp` beside " <>
          "it and renamed over it: the store and the forces file are two files, neither the " <>
          "other's `.tmp`",
        fn -> Runner.start_link(Keyword.put(rig.opts, :forces, rig.store <> ".tmp")) end
      )

      for bad <- [:hot, nil, "warm"] do
        raises(
          "the runner's start: is :warm, a fresh start from its store, or :cold, from the " <>
            "configuration's initial values, got: #{inspect(bad)}",
          fn -> Runner.start_link(rig.opts ++ [start: bad]) end
        )
      end

      for mode <- [:warm, :cold] do
        raises(
          "the runner keeps no store, so start: #{inspect(mode)} has none to start from: " <>
            "start it with retain: a path",
          fn -> Runner.start_link(Keyword.delete(rig.opts, :retain) ++ [start: mode]) end
        )
      end

      # A clock with no wall clock runs a runner given no store, and not one given one.
      raises(
        "the runner's clock `Logex.RetainStoreTest.NoWall` has no wall_ms/1, which a runner " <>
          "given retain: writes its store's time by",
        fn -> Runner.start_link(Keyword.put(rig.opts, :clock, {__MODULE__.NoWall, rig.clock})) end
      )

      # In order: the forces file's mistake before the store's, the store's before the
      # start's, and nothing written or opened by a refused start.
      raises(~r/forces: is the path/, fn ->
        Runner.start_link(rig.opts ++ [forces: 5, start: :hot])
      end)

      raises(~r/retain: is the path/, fn ->
        Runner.start_link(Keyword.put(rig.opts, :retain, 5) ++ [start: :hot])
      end)

      refute File.exists?(rig.store)
      assert Sim.reads(rig.panel) == 0

      # Two files beside each other are two files.
      {:ok, runner} =
        Runner.start_link(Keyword.put(rig.opts, :forces, Path.join(dir, "plant.forces")))

      assert Runner.stop(runner) == :ok
    end

    test "a runner given no retain: has no store and says so" do
      {:ok, clock} = Manual.start_link()
      {:ok, panel} = Sim.start_link(clock: clock)

      {:ok, runner} =
        Runner.start_link(
          configuration: configured(),
          io: %{"panel" => {Sim, sim: panel}},
          clock: {Manual, clock},
          poll: 10
        )

      assert Runner.status(runner).retain == nil
      assert Runner.stop(runner) == :ok
    end
  end

  defmodule Crashing do
    def cycle_steps(_runtime, _elapsed, %{"clr" => 1}), do: :garbage
    def cycle_steps(runtime, elapsed, inputs), do: Runtime.cycle_steps(runtime, elapsed, inputs)
    def cycle_step(runtime, step), do: Runtime.cycle_step(runtime, step)
    def cycle_outputs(runtime), do: Runtime.cycle_outputs(runtime)
  end

  # A manual clock whose `now_ms/1` exits from `at` on in the runner, a clock gone down,
  # while its devices still read it and its wall clock still answers, so that the runner
  # is stopped by its clock and not tripped by a device, and a write at its end would
  # name a time.
  defmodule GoneNow do
    @behaviour Logex.Runner.Clock

    @impl true
    def now_ms({clock, at}),
      do: gone(Manual.now_ms(clock), at, Process.get(:"$initial_call"))

    @impl true
    def wake_at({clock, _at}, pid, message, at), do: Manual.wake_at(clock, pid, message, at)

    @impl true
    def cancel({clock, _at}, timer), do: Manual.cancel(clock, timer)

    @impl true
    def wall_ms({clock, _at}), do: Manual.wall_ms(clock)

    defp gone(now, at, {Logex.Runner, :init, 1}) when now >= at, do: exit(:gone)
    defp gone(now, _at, _process), do: now
  end

  # The simulated device, which calls the function an agent holds before each read, so
  # that a test acts between a cold restart's own write and its write-back.
  defmodule Spoiling do
    @behaviour Logex.IO

    @impl true
    def check(device, points, opts), do: Sim.check(device, points, Keyword.take(opts, [:sim]))

    @impl true
    def init(device, points, opts) do
      {:ok, state} = Sim.init(device, points, Keyword.take(opts, [:sim]))
      {:ok, {state, opts[:before]}}
    end

    @impl true
    def read({state, before}) do
      Agent.get(before, & &1).()
      wrapped(Sim.read(state), before)
    end

    @impl true
    def write(values, {state, before}), do: wrapped(Sim.write(values, state), before)

    defp wrapped({:ok, values, state}, before), do: {:ok, values, {state, before}}
    defp wrapped({:ok, state}, before), do: {:ok, {state, before}}
    defp wrapped({:error, reason, state}, before), do: {:error, reason, {state, before}}

    @impl true
    def close({state, _before}), do: Sim.close(state)
  end

  defmodule NoWall do
    @behaviour Logex.Runner.Clock

    @impl true
    def now_ms(clock), do: Manual.now_ms(clock)

    @impl true
    def wake_at(clock, pid, message, at), do: Manual.wake_at(clock, pid, message, at)

    @impl true
    def cancel(clock, timer), do: Manual.cancel(clock, timer)
  end

  describe "a fresh start (decisions 271, 277 and 285)" do
    # With no store file the start writes one at once, before any device is opened, of the
    # configuration's initial values, at the clock's wall time.
    test "with no store file the store is written at once", %{tmp_dir: dir} do
      rig = rig(dir)
      {:ok, runner} = Runner.start_link(rig.opts)
      config = configured()

      assert File.read!(rig.store) ==
               Retain.encode(Runtime.retained(Runtime.start(config)), ~U[2026-10-30 14:00:00Z])

      assert Runner.status(runner).retain == %{
               path: rig.store,
               written_at: ~U[2026-10-30 14:00:00Z],
               failed: nil,
               dropped: []
             }

      assert Runner.stop(runner) == :ok
    end

    test "a runner stopped and started fresh restores what its stop wrote", %{tmp_dir: dir} do
      rig = rig(dir)
      {:ok, runner} = Runner.start_link(rig.opts)
      pressed(rig, [1, 0, 1, 0, 1])
      kept = values(runner)
      assert kept == [3, 3, 1, 3]
      Manual.advance(rig.clock, 2000)
      assert Runner.stop(runner) == :ok
      assert File.read!(rig.store) =~ "configuration plant written 2026-10-30T14:00:02Z\n"

      opener_down(rig.panel)
      {:ok, runner} = Runner.start_link(rig.opts)

      # Its first round has run, the eye at 1 from the last set and the one-shot marked
      # first (decision 274): the counter and the total kept, `shown` from the count.
      assert values(runner) == kept

      assert Runner.status(runner).retain == %{
               path: rig.store,
               written_at: ~U[2026-10-30 14:00:02Z],
               failed: nil,
               dropped: []
             }

      assert Runner.stop(runner) == :ok
    end

    # A changed program meets the store by decision 277's matching, what it drops in
    # status/1, the rest kept.
    test "a changed program's drops reported in status/1", %{tmp_dir: dir} do
      rig = rig(dir)
      {:ok, runner} = Runner.start_link(rig.opts)
      pressed(rig, [1, 0, 1])
      assert Runner.stop(runner) == :ok
      opener_down(rig.panel)

      changed =
        configured(
          @plant,
          programs(String.replace(@tally, "var retain boxes ctu", "var retain boxes ctu_int"))
        )

      {:ok, runner} = Runner.start_link(Keyword.put(rig.opts, :configuration, changed))

      assert %{dropped: [{"t1.boxes", {:retyped, "ctu", "ctu_int"}}]} =
               Runner.status(runner).retain

      assert Runner.get!(runner, "total_boxes") == 2
      assert Runner.get!(runner, "t1.boxes.cv") == 0
      assert Runner.stop(runner) == :ok
    end

    test "a store that does not read, or of another configuration, starts nothing",
         %{tmp_dir: dir} do
      rig = rig(dir)
      File.write!(rig.store, "logex retain 1\nconfiguration line2 written 2026-10-30T14:00:00Z\n")

      raises(
        "#{rig.store}: line 2: the store is of configuration `line2`, and this configuration " <>
          "is `plant`: a store starts only the configuration it was written for, so a " <>
          "renamed configuration starts only cold: start it with start: :cold to start over it",
        fn -> Runner.start_link(rig.opts) end
      )

      File.write!(
        rig.store,
        "logex retain 1\nconfiguration plant written 2026-10-30T14:00:00Z\nbad\n"
      )

      raises(~r/line 3: `bad` is no line of a store/, fn -> Runner.start_link(rig.opts) end)

      # What its image holds the start judges as any image, each line naming the store.
      File.write!(
        rig.store,
        "logex retain 1\nconfiguration plant written 2026-10-30T14:00:00Z\ntrigger arm 1\n"
      )

      raises(
        "#{rig.store}: `triggers` holds \"arm\", which `globals` does not hold: a trigger's " <>
          "last sample is kept only with its retained global",
        fn -> Runner.start_link(rig.opts) end
      )

      File.mkdir_p!(Path.join(dir, "adir"))

      raises(
        "#{Path.join(dir, "adir")}: the store cannot be read: illegal operation on a directory",
        fn -> Runner.start_link(Keyword.put(rig.opts, :retain, Path.join(dir, "adir"))) end
      )

      # No device was opened or read, and the store is as it was.
      assert Sim.reads(rig.panel) == 0
      assert File.read!(rig.store) =~ "trigger arm 1"
    end

    # `start: :cold` reads no store, a broken one or another configuration's among them,
    # and writes a new one at once (decision 285).
    test "start: :cold ignores the store and writes a new one at once", %{tmp_dir: dir} do
      rig = rig(dir, start: :cold)
      File.write!(rig.store, "logex retain 1\nconfiguration line2 written 2026-10-30T14:00:00Z\n")
      {:ok, runner} = Runner.start_link(rig.opts)
      assert values(runner) == [0, 0, 0, 0]

      assert File.read!(rig.store) ==
               Retain.encode(
                 Runtime.retained(Runtime.start(configured())),
                 ~U[2026-10-30 14:00:00Z]
               )

      assert Runner.stop(runner) == :ok
    end

    # Decision 291: a fresh start whose write fails is not started, the store as it was and
    # no device opened.
    test "a fresh start whose store write fails starts nothing", %{tmp_dir: dir} do
      for mode <- [:cold, :warm] do
        rig = rig(Path.join(dir, "#{mode}"), start: mode)
        File.mkdir_p!(rig.store <> ".tmp")

        assert Runner.start_link(rig.opts) == {:error, {:retain, :eisdir}}
        refute File.exists?(rig.store)
        assert Sim.reads(rig.panel) == 0
        assert Sim.writes(rig.panel) == []
      end

      rig = rig(dir, retain: Path.join([dir, "missing", "plant.retain"]))
      assert Runner.start_link(rig.opts) == {:error, {:retain, :enoent}}
    end
  end

  describe "the writes at events (decisions 275, 291 and 292)" do
    # A trip writes the resource as the trip left it; the runner killed, a fresh start
    # restores that write, never the older one a stop made.
    test "a trip's write is what a fresh start after a kill restores", %{tmp_dir: dir} do
      rig = rig(dir)
      {:ok, runner} = Runner.start_link(rig.opts)
      pressed(rig, [1, 0])
      assert Runner.stop(runner) == :ok
      opener_down(rig.panel)

      {:ok, runner} = Runner.start_link(rig.opts)
      pressed(rig, [1, 0, 1, 0])
      Manual.advance(rig.clock, 3000)
      tripped(rig, runner)
      assert %{status: :tripped} = Runner.status(runner)
      assert Runner.status(runner).retain.written_at == ~U[2026-10-30 14:00:03Z]
      at_trip = values(runner)
      assert at_trip == [3, 3, 1, 3]
      killed(runner)
      opener_down(rig.panel)

      {:ok, runner} = Runner.start_link(rig.opts)
      assert values(runner) == at_trip
      assert Runner.stop(runner) == :ok
    end

    # Never half (decision 275): a write cut short by a crash leaves its `.tmp` beside the
    # store, which a fresh start never reads and the next write replaces.
    test "a write cut short leaves the store whole", %{tmp_dir: dir} do
      rig = rig(dir)
      {:ok, runner} = Runner.start_link(rig.opts)
      pressed(rig, [1, 0, 1])
      assert Runner.stop(runner) == :ok
      written = File.read!(rig.store)
      File.write!(rig.store <> ".tmp", binary_part(written, 0, 40))
      opener_down(rig.panel)

      {:ok, runner} = Runner.start_link(rig.opts)
      assert values(runner) == [2, 2, 1, 2]
      assert Runner.stop(runner) == :ok
      refute File.exists?(rig.store <> ".tmp")
      assert File.read!(rig.store) == written
    end

    # Decision 292: a runner killed writes no store; its fresh start meets the last event's.
    test "a crash writes nothing", %{tmp_dir: dir} do
      rig = rig(dir)
      {:ok, runner} = Runner.start_link(rig.opts)
      written = File.read!(rig.store)
      pressed(rig, [1, 0, 1])
      killed(runner)
      assert File.read!(rig.store) == written
      opener_down(rig.panel)

      {:ok, runner} = Runner.start_link(rig.opts)
      assert values(runner) == [0, 0, 1, 0]
      assert Runner.stop(runner) == :ok
    end

    # Decision 292: a runner that crashes, its terminate/2 run, writes no store either:
    # only a stop/2 writes as it terminates. A stand-in for the core's steps gives what the
    # core never gives where `clr` is 1, so that the runner crashes outside any guard,
    # after it has counted a box.
    test "a crash inside the runner writes nothing", %{tmp_dir: dir} do
      rig = rig(dir, steps: __MODULE__.Crashing)
      {:ok, runner} = Runner.start_link(rig.opts)
      written = File.read!(rig.store)
      pressed(rig, [1, 0, 1])
      assert values(runner) == [2, 2, 1, 2]
      Process.unlink(runner)
      ref = Process.monitor(runner)
      Sim.set(rig.panel, [1], 1)
      Manual.advance(rig.clock, 10)
      assert_receive {:DOWN, ^ref, :process, ^runner, {:function_clause, _stack}}, 5000
      assert Sim.closed?(rig.panel)
      assert File.read!(rig.store) == written
    end

    # Decision 316 (the maintainer, 2026-10-30), changing M6-5's reading 4, which wrote
    # nothing here: a runner its parent shuts down, as a supervisor's orderly shutdown
    # does, writes the store as stop/2 does, every output 0 and every device closed first,
    # and the next fresh start brings back what the shutdown wrote.
    test "a parent's shutdown writes the store after every output 0 and every device closed",
         %{tmp_dir: dir} do
      rig = rig(dir)
      store = rig.store

      opts =
        Keyword.put(rig.opts, :io, %{
          "panel" => {Watching, sim: rig.panel, store: store, test: self()}
        })

      Process.flag(:trap_exit, true)
      {:ok, runner} = Runner.start_link(opts)
      started = File.read!(store)
      pressed(rig, [1, 0, 1])
      assert values(runner) == [2, 2, 1, 2]
      flush()
      ref = Process.monitor(runner)
      Process.exit(runner, :shutdown)
      assert_receive {:DOWN, ^ref, :process, ^runner, :shutdown}, 5000
      assert_received {:written, %{[0] => 0}, {:ok, ^started}}
      assert Sim.outputs(rig.panel) == %{[0] => 0}
      assert Sim.closed?(rig.panel)
      assert File.read!(store) =~ "global total_boxes dint 2\n"
      opener_down(rig.panel)

      {:ok, runner} = Runner.start_link(rig.opts)
      assert values(runner) == [2, 2, 1, 2]
      assert Runner.stop(runner) == :ok
    end

    # Decision 316: a `{:shutdown, term}` is a shutdown too, and so is a supervisor's, which
    # the runner, `restart: :temporary`, takes as its parent's.
    test "a supervisor's shutdown and a {:shutdown, term} write the store", %{tmp_dir: dir} do
      rig = rig(dir)
      Process.flag(:trap_exit, true)
      {:ok, runner} = Runner.start_link(rig.opts)
      pressed(rig, [1, 0])
      ref = Process.monitor(runner)
      Process.exit(runner, {:shutdown, :end_of_shift})
      assert_receive {:DOWN, ^ref, :process, ^runner, {:shutdown, :end_of_shift}}, 5000
      assert File.read!(rig.store) =~ "global total_boxes dint 1\n"
      opener_down(rig.panel)

      {:ok, supervisor} = Supervisor.start_link([{Runner, rig.opts}], strategy: :one_for_one)
      [{Runner, runner, :worker, _}] = Supervisor.which_children(supervisor)
      assert values(runner) == [1, 1, 1, 1]
      pressed(rig, [1, 0, 1])
      assert values(runner) == [3, 3, 1, 3]
      ref = Process.monitor(runner)
      :ok = Supervisor.stop(supervisor)
      assert_receive {:DOWN, ^ref, :process, ^runner, :shutdown}, 5000
      assert Sim.closed?(rig.panel)
      assert File.read!(rig.store) =~ "global total_boxes dint 3\n"
    end

    # Decision 316: a shutdown's write that fails is reported as any failed write, the
    # runner down all the same and the store as it was.
    test "a parent's shutdown whose write fails is reported", %{tmp_dir: dir} do
      rig = rig(dir)
      Process.flag(:trap_exit, true)
      {:ok, runner} = Runner.start_link(rig.opts)
      :ok = Runner.subscribe(runner)
      written = File.read!(rig.store)
      pressed(rig, [1, 0, 1])
      File.mkdir_p!(rig.store <> ".tmp")
      ref = Process.monitor(runner)
      Process.exit(runner, :shutdown)
      assert_receive {:DOWN, ^ref, :process, ^runner, :shutdown}, 5000
      assert_received {Runner, ^runner, {:retain, {:error, :eisdir}}}
      assert Sim.closed?(rig.panel)
      assert File.read!(rig.store) == written
    end

    # Decision 292, kept by decision 316: a clock that goes down stops the runner as a
    # shutdown of its own, `{:shutdown, {:clock, reason}}`, not its parent's, and writes no
    # store, even where the clock's wall clock still answers.
    test "a runner whose clock goes down writes nothing", %{tmp_dir: dir} do
      rig = rig(dir)
      opts = Keyword.put(rig.opts, :clock, {__MODULE__.GoneNow, {rig.clock, @wall + 35}})
      {:ok, runner} = Runner.start_link(opts)
      written = File.read!(rig.store)
      pressed(rig, [1, 0, 1])
      assert values(runner) == [2, 2, 1, 2]
      Process.unlink(runner)
      ref = Process.monitor(runner)
      Manual.advance(rig.clock, 10)
      assert_receive {:DOWN, ^ref, :process, ^runner, {:shutdown, {:clock, :gone}}}, 5000
      assert Sim.closed?(rig.panel)
      assert File.read!(rig.store) == written
    end

    # Decision 316 names `:shutdown` and `{:shutdown, term}`: a parent that ends
    # `:normal`, which a supervisor never gives, ends the runner `:normal` and writes none,
    # as before (provisional).
    test "a parent's :normal exit writes nothing (provisional)", %{tmp_dir: dir} do
      rig = rig(dir)
      test = self()

      parent =
        spawn(fn ->
          {:ok, runner} = Runner.start_link(rig.opts)
          send(test, {:runner, runner})
          receive do: (:end -> :ok)
        end)

      assert_receive {:runner, runner}
      written = File.read!(rig.store)
      pressed(rig, [1, 0, 1])
      assert values(runner) == [2, 2, 1, 2]
      ref = Process.monitor(runner)
      send(parent, :end)
      assert_receive {:DOWN, ^ref, :process, ^runner, :normal}, 5000
      assert Sim.closed?(rig.panel)
      assert File.read!(rig.store) == written
    end

    # Decision 275: the stop's zeros come before its write, which a device sees at its
    # last write, and its answer after both.
    test "stop/2 writes the store after every output 0 and every device closed",
         %{tmp_dir: dir} do
      rig = rig(dir)
      store = rig.store

      opts =
        Keyword.put(rig.opts, :io, %{
          "panel" => {Watching, sim: rig.panel, store: store, test: self()}
        })

      {:ok, runner} = Runner.start_link(opts)
      pressed(rig, [1, 0, 1])
      started = File.read!(store)
      flush()
      assert Runner.stop(runner) == :ok
      assert_received {:written, %{[0] => 0}, {:ok, ^started}}
      assert Sim.closed?(rig.panel)
      assert File.read!(store) =~ "global total_boxes dint 2\n"
    end

    # Decision 275 and §4.13: a trip writes the store after every output is 0, never
    # before, so that a long write holds no output on; the device's 0 meets the store as
    # the start wrote it, and the trip's write follows. The trip is the runner's, a major
    # fault, not the device's own, which latches and writes its 0 before the runner hears.
    test "a trip writes the store after every output 0", %{tmp_dir: dir} do
      rig = rig(dir)
      store = rig.store

      faulting =
        String.replace(@tally, "var e bool\n", "var e bool\nvar w word\nvar n dint 16\n") <>
          "xic clear otl w.[n]\n"

      opts =
        rig.opts
        |> Keyword.put(:configuration, configured(@plant, programs(faulting)))
        |> Keyword.put(:io, %{"panel" => {Watching, sim: rig.panel, store: store, test: self()}})

      {:ok, runner} = Runner.start_link(opts)
      pressed(rig, [1, 0, 1])
      started = File.read!(store)
      assert started =~ "global total_boxes dint 0\n"
      flush()
      Sim.set(rig.panel, [1], 1)
      Manual.advance(rig.clock, 10)
      assert %{status: :tripped, trip: {:fault, "fast", "t1", _fault}} = Runner.status(runner)
      assert_received {:written, %{[0] => 0}, {:ok, ^started}}
      assert File.read!(store) =~ "global total_boxes dint 2\n"
      assert Runner.stop(runner) == :ok
    end

    test "a stop whose write fails stops all the same and says so", %{tmp_dir: dir} do
      rig = rig(dir)
      {:ok, runner} = Runner.start_link(rig.opts)
      written = File.read!(rig.store)
      pressed(rig, [1, 0, 1])
      File.mkdir_p!(rig.store <> ".tmp")
      Process.flag(:trap_exit, true)

      assert Runner.stop(runner, :shutdown) == {:error, {:retain, :eisdir}}
      assert_receive {:EXIT, ^runner, :shutdown}
      assert Sim.outputs(rig.panel) == %{[0] => 0}
      assert Sim.closed?(rig.panel)
      assert File.read!(rig.store) == written
    end

    # The stop is a system message, served by a runner suspended too, as before M6-5, and
    # its answer comes all the same.
    test "a suspended runner's stop answers its write too", %{tmp_dir: dir} do
      rig = rig(dir)
      {:ok, runner} = Runner.start_link(rig.opts)
      pressed(rig, [1])
      File.mkdir_p!(rig.store <> ".tmp")
      :sys.suspend(runner)
      assert Runner.stop(runner) == {:error, {:retain, :eisdir}}
      refute Process.alive?(runner)
      assert Sim.closed?(rig.panel)
    end

    # Decision 291: a cold restart writes the store before it releases or reads any
    # device, so a crash right after it brings back none of what it discarded; a warm one
    # writes none.
    test "a cold restart's write precedes its reads, and a crash after it restores none",
         %{tmp_dir: dir} do
      rig = rig(dir)

      opts =
        Keyword.put(rig.opts, :io, %{
          "panel" => {Watching, sim: rig.panel, store: rig.store, test: self()}
        })

      {:ok, runner} = Runner.start_link(opts)
      pressed(rig, [1, 0, 1])
      tripped(rig, runner)
      at_trip = File.read!(rig.store)
      assert at_trip =~ "global total_boxes dint 2\n"

      # Two seconds on, a write would name a later time: a warm restart writes none.
      Manual.advance(rig.clock, 2000)
      assert Runner.restart(runner, :warm) == :ok
      assert File.read!(rig.store) == at_trip
      tripped(rig, runner)
      flush()

      assert Runner.restart(runner, :cold) == :ok
      assert_received {:read, {:ok, cold}}
      assert cold =~ "global total_boxes dint 0\n"
      killed(runner)
      opener_down(rig.panel)

      {:ok, runner} = Runner.start_link(rig.opts)
      assert [0, 0, _lamp, 0] = values(runner)
      assert Runner.stop(runner) == :ok
    end

    # Decision 291: a cold restart whose write fails leaves the runner tripped as it was,
    # the store as it was, every output still 0 and no device released or read.
    test "a cold restart whose write fails changes nothing", %{tmp_dir: dir} do
      rig = rig(dir)
      {:ok, runner} = Runner.start_link(rig.opts)
      :ok = Runner.subscribe(runner)
      pressed(rig, [1, 0, 1])
      tripped(rig, runner)
      %{trip: trip} = Runner.status(runner)
      written = File.read!(rig.store)
      reads = Sim.reads(rig.panel)
      writes = Sim.writes(rig.panel)
      File.mkdir_p!(rig.store <> ".tmp")

      assert Runner.restart(runner, :cold) == {:error, {:retain, :eisdir}}
      assert_receive {Runner, ^runner, {:retain, {:error, :eisdir}}}
      assert %{status: :tripped, trip: ^trip, retain: %{failed: :eisdir}} = Runner.status(runner)
      assert File.read!(rig.store) == written
      assert {Sim.reads(rig.panel), Sim.writes(rig.panel)} == {reads, writes}
      assert List.last(writes) == %{[0] => 0}
      assert values(runner) == [2, 2, 1, 2]

      # Put right, the next restart writes, runs, and clears the failure.
      File.rm_rf!(rig.store <> ".tmp")
      assert Runner.restart(runner, :cold) == :ok
      assert %{status: :running, retain: %{failed: nil}} = Runner.status(runner)
      assert Runner.stop(runner) == :ok
    end

    # Decision 317 (the maintainer, 2026-10-30), changing M6-5's reading 5: a cold restart
    # a device then refuses writes the store back, after its zeros, with the values the
    # runner still holds, so that the refusal changes nothing on disk or in memory, and a
    # crash after it brings back what the trip kept, not the initial values the cold
    # restart's own write held.
    test "a cold restart a device refuses writes the store back", %{tmp_dir: dir} do
      rig = rig(dir)

      opts =
        Keyword.put(rig.opts, :io, %{
          "panel" => {Watching, sim: rig.panel, store: rig.store, test: self()}
        })

      {:ok, runner} = Runner.start_link(opts)
      pressed(rig, [1, 0, 1])
      tripped(rig, runner)
      %{trip: trip} = Runner.status(runner)
      at_trip = File.read!(rig.store)
      assert at_trip =~ "global total_boxes dint 2\n"
      Manual.advance(rig.clock, 2000)
      flush()

      Sim.fail(rig.panel, :read, {:error, :eio})
      assert {:error, {:io_init, "panel", _cause}} = Runner.restart(runner, :cold)

      # The refusal's 0 meets the cold restart's own write; the write-back comes after it.
      assert_received {:written, %{[0] => 0}, {:ok, cold}}
      assert cold =~ "global total_boxes dint 0\n"
      assert %{status: :tripped, trip: ^trip, retain: retain} = Runner.status(runner)
      assert %{written_at: ~U[2026-10-30 14:00:02Z], failed: nil} = retain
      assert values(runner) == [2, 2, 1, 2]
      back = File.read!(rig.store)
      assert back =~ "configuration plant written 2026-10-30T14:00:02Z\n"
      assert String.replace(back, "14:00:02Z", "14:00:00Z") == at_trip
      assert List.last(Sim.writes(rig.panel)) == %{[0] => 0}
      killed(runner)
      opener_down(rig.panel)

      {:ok, runner} = Runner.start_link(rig.opts)
      assert values(runner) == [2, 2, 1, 2]
      assert Runner.stop(runner) == :ok
    end

    # Decision 317: a refused warm restart wrote nothing and writes nothing back.
    test "a warm restart a device refuses writes nothing", %{tmp_dir: dir} do
      rig = rig(dir)
      {:ok, runner} = Runner.start_link(rig.opts)
      pressed(rig, [1, 0, 1])
      tripped(rig, runner)
      at_trip = File.read!(rig.store)
      Manual.advance(rig.clock, 2000)
      Sim.fail(rig.panel, :read, {:error, :eio})
      assert {:error, {:io_init, "panel", _cause}} = Runner.restart(runner, :warm)
      assert File.read!(rig.store) == at_trip
      assert Runner.stop(runner) == :ok
    end

    # Decision 317: a write-back that fails is reported as any failed write, `failed` in
    # `status/1`'s `retain` and `{:retain, {:error, reason}}` to the subscribers, the
    # runner tripped all the same; the store then holds the cold restart's own write.
    test "a cold restart's write-back that fails is reported", %{tmp_dir: dir} do
      rig = rig(dir)
      {:ok, agent} = Agent.start_link(fn -> fn -> :ok end end)

      opts =
        Keyword.put(rig.opts, :io, %{"panel" => {Spoiling, sim: rig.panel, before: agent}})

      {:ok, runner} = Runner.start_link(opts)
      pressed(rig, [1, 0, 1])
      tripped(rig, runner)
      %{trip: trip} = Runner.status(runner)
      :ok = Runner.subscribe(runner)
      tmp = rig.store <> ".tmp"
      Agent.update(agent, fn _ -> fn -> File.mkdir_p!(tmp) end end)
      Sim.fail(rig.panel, :read, {:error, :eio})

      assert {:error, {:io_init, "panel", _cause}} = Runner.restart(runner, :cold)
      assert_receive {Runner, ^runner, {:retain, {:error, :eisdir}}}
      assert %{status: :tripped, trip: ^trip, retain: %{failed: :eisdir}} = Runner.status(runner)
      assert values(runner) == [2, 2, 1, 2]
      assert File.read!(rig.store) =~ "global total_boxes dint 0\n"
      assert List.last(Sim.writes(rig.panel)) == %{[0] => 0}
      File.rm_rf!(tmp)
      Agent.update(agent, fn _ -> fn -> :ok end end)
      assert Runner.stop(runner) == :ok
      assert File.read!(rig.store) =~ "global total_boxes dint 2\n"
    end

    # A trip's write that fails is reported and the store left as it was.
    test "a trip's write that fails is reported", %{tmp_dir: dir} do
      rig = rig(dir)
      {:ok, runner} = Runner.start_link(rig.opts)
      :ok = Runner.subscribe(runner)
      written = File.read!(rig.store)
      pressed(rig, [1, 0, 1])
      File.mkdir_p!(rig.store <> ".tmp")
      tripped(rig, runner)

      assert_receive {Runner, ^runner, {:trip, {:io, "panel", {:error, :eio}}}}
      assert_receive {Runner, ^runner, {:retain, {:error, :eisdir}}}
      assert %{status: :tripped, retain: %{failed: :eisdir}} = Runner.status(runner)
      assert File.read!(rig.store) == written
      File.rm_rf!(rig.store <> ".tmp")
      assert Runner.stop(runner) == :ok
    end
  end

  describe "a warm fresh start's first round (decisions 272 and 284)" do
    # The retained lamp comes back on only through the program's logic in the first round,
    # which writes it with the round's other outputs: nothing is written before it.
    test "a retained output-driving bit is written only by the first round", %{tmp_dir: dir} do
      rig = rig(dir)
      {:ok, runner} = Runner.start_link(rig.opts)
      pressed(rig, [1, 0])
      assert Sim.outputs(rig.panel) == %{[0] => 1}
      killed(runner)
      opener_down(rig.panel)
      assert Sim.outputs(rig.panel) == %{[0] => 0}
      before = Sim.writes(rig.panel)

      # The store is the start's, which held the lamp off: a fresh start's first round
      # writes it off.
      {:ok, runner} = Runner.start_link(rig.opts)
      assert Enum.drop(Sim.writes(rig.panel), length(before)) == [%{[0] => 0}]
      tripped(rig, runner)
      assert Runner.restart(runner, :warm) == :ok
      pressed(rig, [1])
      tripped(rig, runner)
      killed(runner)
      opener_down(rig.panel)
      Sim.set(rig.panel, [0], 0)
      before = Sim.writes(rig.panel)

      # The trip's store holds the lamp on: the first round's write is the one that lights it.
      {:ok, runner} = Runner.start_link(rig.opts)
      assert Enum.drop(Sim.writes(rig.panel), length(before)) == [%{[0] => 1}]
      assert Runner.stop(runner) == :ok
    end

    # Decision 284: nothing special, a retained subscript that tripped the plant trips it
    # again at a warm fresh start, and not at a cold one.
    test "a retained value that tripped the plant trips it again warm, not cold",
         %{tmp_dir: dir} do
      {:ok, scale} =
        Logex.compile(
          "var_input w int\nvar_input go bool\nvar retain slot dint\nvar weights int[8]\n" <>
            "xic go add slot 1 slot\nmove w weights[slot]",
          name: "scale"
        )

      source = """
      task fast interval 10 priority 1
      var_global w int at panel.i.0
      var_global go bool at panel.i.1
      program s1 scale with fast
        s1.w w
        s1.go go
      """

      config = configured(source, %{"scale" => scale})
      rig = rig(dir, configuration: config)
      {:ok, runner} = Runner.start_link(rig.opts)
      Sim.set(rig.panel, [1], 1)
      Manual.advance(rig.clock, 100)
      assert %{status: :tripped, trip: {:fault, "fast", "s1", fault}} = Runner.status(runner)
      assert %{kind: :index_out_of_range, read: {8}} = fault
      killed(runner)
      opener_down(rig.panel)
      Sim.set(rig.panel, [1], 0)

      {:ok, runner} = Runner.start_link(rig.opts)

      assert %{status: :tripped, trip: {:fault, "fast", "s1", %{read: {8}}}} =
               Runner.status(runner)

      assert Runner.stop(runner) == :ok
      opener_down(rig.panel)

      {:ok, runner} = Runner.start_link(Keyword.put(rig.opts, :start, :cold))
      assert %{status: :running} = Runner.status(runner)
      assert Runner.get!(runner, "s1.slot") == 0
      assert Runner.stop(runner) == :ok
    end
  end

  describe "a runner with no store costs as before" do
    # Traced: a runner given no `retain:` takes no image out at a trip, a cold restart or a
    # stop, and restarts its resource once a restart, as before M6-5; one given a store takes
    # one out at each write, a cold restart's of the resource as it restarts it.
    test "no image is taken out without a store", %{tmp_dir: dir} do
      Code.ensure_loaded!(Runtime)

      calls =
        for extra <- [[retain: nil], []] do
          File.mkdir_p!(Path.join(dir, "#{length(extra)}"))
          rig = rig(Path.join(dir, "#{length(extra)}"), extra)
          {:ok, runner} = Runner.start_link(rig.opts)
          assert :erlang.trace_pattern({Runtime, :retained, 1}, true, [:global]) == 1
          assert :erlang.trace_pattern({Runtime, :restart, 2}, true, [:global]) == 1
          :erlang.trace(runner, true, [:call])
          pressed(rig, [1, 0])
          tripped(rig, runner)
          assert Runner.restart(runner, :cold) == :ok
          :erlang.trace(runner, false, [:call])
          assert Runner.stop(runner) == :ok
          traced([])
        end

      :erlang.trace_pattern({Runtime, :_, :_}, false, [:global])
      assert calls == [[restart: 2], [retained: 1, restart: 2, retained: 1, restart: 2]]
    end
  end

  describe "the atomic write (decision 275)" do
    # Traced in the runner's process: the store is written to its `.tmp`, synced to the
    # disk and closed before it is renamed over the store, the forces file's rule.
    test "a write is synced before its rename", %{tmp_dir: dir} do
      rig = rig(dir)
      {:ok, runner} = Runner.start_link(rig.opts)
      assert :erlang.trace_pattern({:file, :_, :_}, true, [:global]) > 0
      :erlang.trace(runner, true, [:call])
      tripped(rig, runner)
      :erlang.trace(runner, false, [:call])
      :erlang.trace_pattern({:file, :_, :_}, false, [:global])
      assert files([]) == [:open, :write, :sync, :close, :rename]
      assert Runner.stop(runner) == :ok
    end
  end

  defp files(calls) do
    receive do
      {:trace, _pid, :call, {:file, function, _args}} -> files([function | calls])
    after
      100 -> Enum.reverse(calls)
    end
  end

  defp traced(calls) do
    receive do
      {:trace, _pid, :call, {Runtime, function, args}} ->
        traced([{function, length(args)} | calls])
    after
      100 -> Enum.reverse(calls)
    end
  end

  describe "the store's growth in reductions" do
    # The store's text written and read back in reductions linear in its lines: n retained
    # counters and 4n, each a kind's line and six values'.
    test "encode/2 and decode!/2 grow linearly in the store's lines" do
      [small, large] =
        for n <- [16, 64] do
          text =
            Enum.map_join(1..n, "\n", &"var retain c#{&1} ctu") <>
              "\n" <> Enum.map_join(1..n, "\n", &"ctu c#{&1} 5")

          {:ok, program} = Logex.compile(text, name: "many")

          config =
            configured("task fast interval 10 priority 1\nprogram m1 many with fast\n", %{
              "many" => program
            })

          image = Runtime.retained(Runtime.start(config))
          text = Retain.encode(image, ~U[2026-10-30 14:00:00Z])
          assert Retain.decode!(text, {"s", "plant"}) == {image, ~U[2026-10-30 14:00:00Z]}

          {reductions(fn -> Retain.encode(image, ~U[2026-10-30 14:00:00Z]) end),
           reductions(fn -> Retain.decode!(text, {"s", "plant"}) end)}
        end

      {encode_small, decode_small} = small
      {encode_large, decode_large} = large
      assert encode_large < 5 * encode_small, inspect({small, large})
      assert decode_large < 5 * decode_small, inspect({small, large})
    end
  end

  defp reductions(fun) do
    parent = self()

    {_pid, ref} =
      :erlang.spawn_opt(
        fn ->
          {:reductions, before} = Process.info(self(), :reductions)
          fun.()
          {:reductions, later} = Process.info(self(), :reductions)
          send(parent, {:reductions, later - before})
        end,
        [:monitor, min_heap_size: 8_000_000]
      )

    assert_receive {:reductions, r}, 10_000
    assert_receive {:DOWN, ^ref, :process, _, :normal}, 10_000
    r
  end

  defp flush do
    receive do
      _message -> flush()
    after
      0 -> :ok
    end
  end
end
