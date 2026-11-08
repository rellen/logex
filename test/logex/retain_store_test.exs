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

  # A task once its call has been sent and waits for its answer.
  defp waiting(task), do: in_call(Process.info(task.pid, :current_function), task)

  defp in_call({:current_function, {:gen, :do_call, 4}}, task), do: task

  defp in_call(_elsewhere, task) do
    Process.sleep(1)
    waiting(task)
  end

  # The time of every round the runner has published since the test subscribed, in order.
  defp rounds_published(runner, times) do
    receive do
      {Runner, ^runner, {:round, at, _outputs}} -> rounds_published(runner, [at | times])
    after
      0 -> Enum.reverse(times)
    end
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
    # Within 5 s, as every other wait here, where the default 100 ms met a loaded machine
    # (RV-3's review, which gave the runner's own reports below the same 5 s).
    assert_receive {:DOWN, ^ref, :process, _, :killed}, 5000
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
             logex retain 2
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
             end 31 lines
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
      logex retain 3
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
            "s: line 1: the store is of version 3, which this logex does not read: it reads " <>
              "`logex retain 2` and `logex retain 1`",
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

      raises("s: line 1: the store is empty: its first line is `logex retain 2`", fn ->
        Retain.decode!("", {"s", "plant"})
      end)

      raises(
        "s: line 1: `logex forces 1` is no store's header: a store's first line is " <>
          "`logex retain 2`\ns: line 2: the store names no configuration: its second line " <>
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

  # Decision 355 (the review after Milestone 6, b3-store-image-6 and c7-premortem-plant-7):
  # a store's first line is `logex retain 2` and its last its count of lines, `end <count>
  # lines`, so that a store cut short, at a line's end or inside a number, is refused at a
  # fresh start, naming the file and the line, where it was read short, its lost values
  # started at their initial values unreported and a number cut in its digits read as a
  # smaller one. A store of `logex retain 1` is read as before.
  describe "a store cut short (decision 355)" do
    # A counter and a total that a cut inside their digits would read smaller, a real
    # array, a latched lamp at the end, and no device, so that a start costs no open.
    @counting """
    var_external total dint
    var retain n dint
    var retain w real[3] 0.25 -2.5 3.4e38
    var retain lamp bool
    var go bool 1
    xic go add n 1 n
    xic go add total 1 total
    xic go otl lamp
    """

    @counted """
    task fast interval 10 priority 1
    var_global retain total dint 123456
    program t1 counting with fast
    """

    defp counted_rig(dir) do
      {:ok, counting} = Logex.compile(@counting, name: "counting")
      {:ok, config} = Configuration.compile("plant", @counted, %{"counting" => counting})
      {:ok, clock} = Manual.start_link(now: @wall)
      store = Path.join(dir, "plant.retain")

      # A write limit that covers a loaded machine's disk, each start and stop writing the
      # store (RV-4's question 12), none of these tests reading the write's limit: since
      # decision 400 (RV-11) the limit's own option, where an idle watchdog of 5000 stood
      # for it.
      opts = [
        configuration: config,
        io: %{},
        clock: {Manual, clock},
        poll: 10,
        write_limit: 5000,
        retain: store
      ]

      %{clock: clock, store: store, opts: opts}
    end

    # Every store the runner writes is of version 2, its last line counting its lines as
    # `wc -l` does, the header and the end line among them.
    test "a store's last line counts its lines", %{tmp_dir: dir} do
      rig = counted_rig(dir)
      {:ok, runner} = Runner.start_link(rig.opts)
      Manual.advance(rig.clock, 1000)
      assert Runner.stop(runner) == :ok
      text = File.read!(rig.store)

      assert text == """
             logex retain 2
             configuration plant written 2026-10-30T14:00:01Z
             global total dint 123557
             instance t1 counting
             t1.lamp bool 1
             t1.n dint 101
             t1.w real[3] 0.25 -2.5 3.4e38
             end 8 lines
             """

      lines = String.split(text, "\n", trim: true)
      assert List.last(lines) == "end #{length(lines)} lines"
    end

    # The fuzz: the store a runner wrote cut at every byte offset and a fresh start made on
    # each, every one refused, naming the file, but the cut of the last newline alone,
    # which keeps every line whole and starts with every value the stop wrote.
    test "a store cut at any byte is refused, or read whole", %{tmp_dir: dir} do
      rig = counted_rig(dir)
      {:ok, runner} = Runner.start_link(rig.opts)
      Manual.advance(rig.clock, 1000)
      assert Runner.stop(runner) == :ok
      text = File.read!(rig.store)

      # The values a fresh start from the whole store gives after its first round.
      whole = cut_start(rig)
      assert {:read, [123_558, 102, _w, 1]} = whole
      File.write!(rig.store, text)

      results =
        for at <- 0..(byte_size(text) - 1) do
          File.write!(rig.store, binary_part(text, 0, at))
          cut_start(rig)
        end

      {read, refused} = Enum.split_with(results, &match?({:read, _}, &1))
      assert read == [whole]
      assert List.last(results) == whole
      assert length(refused) == byte_size(text) - 1

      for {:refused, message} <- refused,
          do: assert(message =~ ~r/\A#{Regex.escape(rig.store)}: line \d+: /, message)
    end

    defp cut_start(rig) do
      {:ok, runner} = Runner.start_link(rig.opts)
      values = for path <- ~w(total t1.n t1.w t1.lamp), do: Runner.get!(runner, path)
      assert Runner.stop(runner) == :ok
      {:read, values}
    rescue
      error in ArgumentError -> {:refused, error.message}
    end

    # The same cuts read by the store's reader alone: every one refused but the last
    # newline's, a cut at a line's end and one inside a number among them, each told at
    # the line the cut left last; where version 1, which has no end line, read both short.
    test "a cut at a line's end and one inside a number, each told" do
      text = """
      logex retain 2
      configuration plant written 2026-10-30T14:00:00Z
      global total dint 1234567
      instance l1 line
      l1.boxes ctu
      l1.boxes.cv dint 1234567
      l1.lamp bool 1
      l1.t ton
      l1.t.acc dint 5
      l1.t.dn bool 0
      l1.t.pre dint 100
      end 12 lines
      """

      assert {%{globals: %{"total" => {:dint, 1_234_567}}}, ~U[2026-10-30 14:00:00Z]} =
               Retain.decode!(text, {"s", "plant"})

      # The text up to and with `tail`, the last of what a cut keeps.
      cut = fn tail ->
        [kept, _lost] = :binary.split(text, tail)
        kept <> tail
      end

      # Decision 417 (RV-13), the leave for the refusal's warning to copy the store aside:
      # its remedy now says that a cold start copies it first.
      told = fn n, last ->
        "s: line #{n}: `#{last}` is the store's last line, and no end line: a store of " <>
          "`logex retain 2` ends with `end <count> lines`, its count of lines, so this one " <>
          "was cut short, and a store cut short is not read: start it with start: :cold to " <>
          "start over it, which copies it first to the next `.dropped.<n>` beside it and " <>
          "then writes a new store over it"
      end

      # At a line's end, the lines after it lost.
      raises(told.(6, "l1.boxes.cv dint 1234567"), fn ->
        Retain.decode!(cut.("l1.boxes.cv dint 1234567\n"), {"s", "plant"})
      end)

      raises(told.(11, "l1.t.pre dint 100"), fn ->
        Retain.decode!(cut.("l1.t.pre dint 100\n"), {"s", "plant"})
      end)

      # Inside a number, which version 1 read as a smaller one.
      raises(told.(3, "global total dint 12"), fn ->
        Retain.decode!(cut.("global total dint 12"), {"s", "plant"})
      end)

      # A line the cut left half is told once, as the store's last, never as a line of no
      # store's shape too.
      raises(told.(5, "l1.box"), fn -> Retain.decode!(cut.("l1.box"), {"s", "plant"}) end)

      # Inside the end line: its count cut in its digits, and the word after it cut.
      for last <- ["end 1", "end 12", "end 12 li"] do
        raises(told.(12, last), fn -> Retain.decode!(cut.(last), {"s", "plant"}) end)
      end

      # Version 1, as before: the same lines cut at a line's end, or in a number, read
      # short.
      v1 = fn kept -> String.replace(kept, "logex retain 2", "logex retain 1") end

      assert {%{instances: %{"l1" => %{values: values}}}, _at} =
               Retain.decode!(v1.(cut.("l1.boxes.cv dint 1234567\n")), {"s", "plant"})

      refute Map.has_key?(values, "lamp")

      assert {%{globals: %{"total" => {:dint, 12}}}, _at} =
               Retain.decode!(v1.(cut.("global total dint 12")), {"s", "plant"})
    end

    # A hand edit's end line (decision 284): one line changed in place keeps the count; a
    # line added or taken away without it, a count no whole number, and an end line that is
    # not last are each refused at their lines.
    test "a hand edit's end line, its count and its place" do
      head = "logex retain 2\nconfiguration plant written 2026-10-30T14:00:00Z\n"

      assert {%{globals: %{"total" => {:dint, 0}}}, _at} =
               Retain.decode!(head <> "global total dint 0\nend 4 lines\n", {"s", "plant"})

      # Any whole number the lexer reads, as every number of a store is, and no newline
      # after the end line.
      assert {%{globals: %{"total" => {:dint, 0}}}, _at} =
               Retain.decode!(head <> "global total dint 0\nend 16#4 lines", {"s", "plant"})

      raises(
        "s: line 5: the store's end line counts 4 lines, and the store has 5: a line was " <>
          "lost or doubled, or a hand edit added or removed one without changing the count, " <>
          "which counts every line, the end line among them, and the store is not read",
        fn ->
          Retain.decode!(
            head <> "global total dint 0\nglobal x dint 1\nend 4 lines\n",
            {"s", "plant"}
          )
        end
      )

      raises(
        "s: line 3: the store's end line counts 4 lines, and the store has 3: a line was " <>
          "lost or doubled, or a hand edit added or removed one without changing the count, " <>
          "which counts every line, the end line among them, and the store is not read",
        fn -> Retain.decode!(head <> "end 4 lines\n", {"s", "plant"}) end
      )

      for count <- ["four", "-4", "4.0"] do
        raises(
          "s: line 4: `end #{count} lines` counts no lines: a store's end line is `end " <>
            "<count> lines`, its count of lines a whole number",
          fn ->
            Retain.decode!(head <> "global total dint 0\nend #{count} lines\n", {"s", "plant"})
          end
        )
      end

      raises(
        "s: line 3: `end 5 lines` comes before the store's last line: a store's end line is " <>
          "its last line",
        fn ->
          Retain.decode!(
            head <> "end 5 lines\nglobal total dint 0\nend 5 lines\n",
            {"s", "plant"}
          )
        end
      )

      # A store of version 1 has no end line: one a hand edit gave it is a line of no
      # store's shape there, told since RV-5's review as an end line its header does not
      # take, where it was told, though last, as one before the store's last.
      raises(
        "s: line 3: `end 3 lines` is an end line, which a store whose first line is " <>
          "`logex retain 2` ends with, and this store's first line is not",
        fn ->
          Retain.decode!(
            "logex retain 1\nconfiguration plant written 2026-10-30T14:00:00Z\nend 3 lines\n",
            {"s", "plant"}
          )
        end
      )
    end

    # RV-5's review: a store whose first line is not exactly `logex retain 2`, a version
    # past it, a word's case, a space after it or a byte-order mark before it, is told so
    # at its first line, and its end line, its last, never told as one before the store's
    # last; a byte-order mark is told in plain words and the rest read as if it were not
    # there, the end line judged as version 2's.
    test "a header that is not `logex retain 2` never tells its end line false" do
      body = "configuration plant written 2026-10-30T14:00:00Z\nglobal total dint 0\n"
      end_told = "`end 4 lines` is an end line, which a store whose first line is"

      for {header, first} <- [
            {"logex retain 3",
             "the store is of version 3, which this logex does not read: it reads `logex " <>
               "retain 2` and `logex retain 1`"},
            {"Logex retain 2",
             "`Logex retain 2` is no store's header: a store's first line is `logex retain 2`"},
            {"logex retain 2 ",
             "`logex retain 2 ` is no store's header: a store's first line is `logex retain 2`"}
          ] do
        raises(
          "s: line 1: #{first}\ns: line 4: #{end_told} `logex retain 2` ends with, and this " <>
            "store's first line is not",
          fn -> Retain.decode!(header <> "\n" <> body <> "end 4 lines\n", {"s", "plant"}) end
        )
      end

      bom =
        "the store begins with a byte-order mark, `\\xEF\\xBB\\xBF`, as an editor that " <>
          "saves UTF-8 with one writes it: a store is ASCII and begins `logex retain 2`, so " <>
          "save it without one"

      raises("s: line 1: #{bom}", fn ->
        Retain.decode!("\xEF\xBB\xBFlogex retain 2\n" <> body <> "end 4 lines\n", {"s", "plant"})
      end)

      # Beside it the rest judged as it is: a count that is not its lines', told.
      raises(
        "s: line 1: #{bom}\ns: line 4: the store's end line counts 5 lines, and the store " <>
          "has 4: a line was lost or doubled, or a hand edit added or removed one without " <>
          "changing the count, which counts every line, the end line among them, and the " <>
          "store is not read",
        fn ->
          Retain.decode!(
            "\xEF\xBB\xBFlogex retain 2\n" <> body <> "end 5 lines\n",
            {"s", "plant"}
          )
        end
      )
    end

    # RV-5's review: a store cut after its header, at its end or inside the line naming its
    # configuration, is told once at the line the cut left last, as the store's last line,
    # where a cut inside the second line told it twice and a cut after the first told the
    # second, which the cut took, before the first. (A cut inside the header leaves no
    # header, and is told so.)
    test "a store cut inside its first two lines is told once, at its last line" do
      head = "logex retain 2\nconfiguration plant written 2026-10-30T14:00:00Z\n"
      text = head <> "global total dint 0\nend 4 lines\n"

      # Decision 417 (RV-13), the leave for the refusal's warning to copy the store aside:
      # its remedy now says that a cold start copies it first.
      told = fn n, last ->
        "s: line #{n}: `#{last}` is the store's last line, and no end line: a store of " <>
          "`logex retain 2` ends with `end <count> lines`, its count of lines, so this one " <>
          "was cut short, and a store cut short is not read: start it with start: :cold to " <>
          "start over it, which copies it first to the next `.dropped.<n>` beside it and " <>
          "then writes a new store over it"
      end

      for at <- byte_size("logex retain 2")..(byte_size(head) - 1) do
        kept = binary_part(text, 0, at)
        {last, n} = kept |> String.split("\n") |> Enum.with_index(1) |> last_line()
        raises(told.(n, last), fn -> Retain.decode!(kept, {"s", "plant"}) end)
      end
    end

    defp last_line(lines), do: last_kept(Enum.reverse(lines))
    defp last_kept([{"", _n} | rest]), do: hd(rest)
    defp last_kept([last | _rest]), do: last
  end

  # RV-5, the review's store and file lows: a hand edit's line ends read as LF (a7-docs-1,
  # c2-runner-persist-10); a comment, a tab and a byte no store holds told as what they are
  # (b3-store-image-10); every refusal of a store bounded, its lines and each text it
  # quotes (b3-store-image-11); a store that is a symbolic link refused (b3-store-image-5);
  # and decision 284's hand edit made with the runner stopped (a7-docs-2).
  # The tests below that start and stop a runner, each of whose writes is limited to the
  # write limit, give it a write limit of 5,000 ms that covers a loaded machine's disk,
  # none reading the limit (RV-4's question 12; since decision 400, RV-11, `write_limit:`,
  # where an idle watchdog of 5,000 stood for it).
  describe "a hand edit's store (RV-5)" do
    @head "logex retain 2\nconfiguration plant written 2026-10-30T14:00:00Z\n"

    # The lines given, ended by their count, as a hand edit that keeps its count leaves
    # them.
    defp counted_store(lines),
      do: @head <> Enum.map_join(lines, &(&1 <> "\n")) <> "end #{length(lines) + 3} lines\n"

    # a7-docs-1, c2-runner-persist-10: a store a hand edit saved with CRLF line ends, or
    # a lone CR's, where each line was told as the line it seemed and was not, "the store
    # is of version 1\r". RV-5 refused it in plain words at its first line holding a
    # carriage return; decision 410 (RV-13), the leave for that reading: it is read as the
    # store it is, a line ended by LF, CRLF or a lone CR alike, as B8 has the source's and
    # a configuration file's readers read them, its lines counted however they end, and the
    # next write is LF's.
    test "a store saved with CRLF or a lone CR is read as the runner wrote it",
         %{tmp_dir: dir} do
      rig = rig(dir, write_limit: 5000)
      {:ok, runner} = Runner.start_link(rig.opts)
      pressed(rig, [1, 0, 1])
      assert values(runner) == [2, 2, 1, 2]
      assert Runner.stop(runner) == :ok
      text = File.read!(rig.store)
      refute text =~ "\r"

      # Each line ended so, and one line alone ended by CRLF, and every kind of end in one
      # store: each starts with every value the stop wrote, and its next write is LF's.
      mixed =
        text
        |> String.split("\n", trim: true)
        |> Enum.zip(Stream.cycle(["\r\n", "\r", "\n"]))
        |> Enum.map_join(fn {line, ending} -> line <> ending end)

      for saved <- [
            String.replace(text, "\n", "\r\n"),
            String.replace(text, "\n", "\r"),
            String.replace(text, "\nt1.boxes ctu\n", "\nt1.boxes ctu\r\n"),
            mixed
          ] do
        File.write!(rig.store, saved)
        opener_down(rig.panel)
        {:ok, runner} = Runner.start_link(rig.opts)
        assert values(runner) == [2, 2, 1, 2], inspect(saved)
        assert Runner.status(runner).retain.dropped == []
        assert Runner.stop(runner) == :ok
        assert File.read!(rig.store) == text
      end
    end

    # Decision 410: a store saved with CRLF, or a lone CR's, cut at any byte is refused, or
    # read whole, as one saved with LF is (decision 355): its end line is last however its
    # lines end, so only a cut of its last line end, or of the CR or the LF of a last CRLF,
    # keeps every line whole; every other cut leaves a last line that is no end line, or
    # cuts the end line's count or its word.
    test "a store saved with CRLF or a lone CR and cut short is refused, as one of LF is" do
      text = """
      logex retain 2
      configuration plant written 2026-10-30T14:00:00Z
      global total dint 1234567
      instance l1 line
      l1.n dint 76543
      end 6 lines
      """

      whole = Retain.decode!(text, {"s", "plant"})

      for ending <- ["\r\n", "\r"] do
        saved = String.replace(text, "\n", ending)
        assert Retain.decode!(saved, {"s", "plant"}) == whole

        results =
          for at <- 0..(byte_size(saved) - 1) do
            try do
              {:read, Retain.decode!(binary_part(saved, 0, at), {"s", "plant"})}
            rescue
              error in ArgumentError -> {:refused, error.message}
            end
          end

        {read, refused} = Enum.split_with(results, &match?({:read, _}, &1))
        kept = byte_size(ending)
        assert read == List.duplicate({:read, whole}, kept), ending
        assert Enum.take(results, -kept) == read
        assert length(refused) == byte_size(saved) - kept

        for {:refused, message} <- refused,
            do: assert(message =~ ~r/\As: line \d+: /, message)
      end

      # A cut inside a number of a CRLF store, and at a line's end, each told at the line
      # the cut left last, as the store saved with LF is.
      saved = String.replace(text, "\n", "\r\n")
      [{at, 3}] = :binary.matches(saved, "123")
      [{line_5, 4}] = :binary.matches(saved, "l1.n")

      raises(
        "s: line 3: `global total dint 12` is the store's last line, and no end line: a " <>
          "store of `logex retain 2` ends with `end <count> lines`, its count of lines, so " <>
          "this one was cut short, and a store cut short is not read: start it with " <>
          "start: :cold to start over it, which copies it first to the next " <>
          "`.dropped.<n>` beside it and then writes a new store over it",
        fn -> Retain.decode!(binary_part(saved, 0, at + 2), {"s", "plant"}) end
      )

      raises(
        "s: line 4: `instance l1 line` is the store's last line, and no end line: a " <>
          "store of `logex retain 2` ends with `end <count> lines`, its count of lines, so " <>
          "this one was cut short, and a store cut short is not read: start it with " <>
          "start: :cold to start over it, which copies it first to the next " <>
          "`.dropped.<n>` beside it and then writes a new store over it",
        fn -> Retain.decode!(binary_part(saved, 0, line_5), {"s", "plant"}) end
      )
    end

    test "a comment, a tab and a byte no store holds are told as what they are" do
      text =
        counted_store([
          "// edited by hand",
          "# edited by bob",
          "global total_boxes dint\t3",
          "global total_boxes dint 3\xFF",
          "instance t1 tally",
          "t1.boxes.cv dint 4\x01"
        ])

      raises(
        Enum.join(
          [
            "s: line 3: `// edited by hand` is a comment, and a store holds none: the runner " <>
              "writes the store whole at every write, so no comment outlives the next",
            "s: line 4: `# edited by bob` is a comment, and a store holds none: the runner " <>
              "writes the store whole at every write, so no comment outlives the next",
            "s: line 5: `global total_boxes dint\t3` holds a tab, and a store's words are " <>
              "each one space apart",
            "s: line 6: `global total_boxes dint 3\\xFF` holds the byte \\xFF, which no " <>
              "store holds: a store's text is printable ASCII, its words each one space apart",
            "s: line 8: `t1.boxes.cv dint 4\\x01` holds the byte \\x01, which no store " <>
              "holds: a store's text is printable ASCII, its words each one space apart"
          ],
          "\n"
        ),
        fn -> Retain.decode!(text, {"s", "plant"}) end
      )

      # The refusal printable, a byte the file holds shown, never written raw.
      message =
        try do
          Retain.decode!(text, {"s", "plant"})
        rescue
          error in ArgumentError -> error.message
        end

      assert String.printable?(message)
      refute message =~ <<0xFF>>
    end

    # RV-5's review: DEL is a control byte, told as one; and every text of the header a
    # problem quotes, its version and its time among them, shown printable, never raw.
    test "DEL, and the header's version and time, shown as their escapes" do
      raises(
        "s: line 3: `global total_boxes dint 3\\x7F` holds the byte \\x7F, which no store " <>
          "holds: a store's text is printable ASCII, its words each one space apart",
        fn -> Retain.decode!(counted_store(["global total_boxes dint 3\x7F"]), {"s", "plant"}) end
      )

      raises(
        "s: line 1: the store is of version \\xFF\\x01, which this logex does not read: it " <>
          "reads `logex retain 2` and `logex retain 1`",
        fn ->
          Retain.decode!(
            "logex retain \xFF\x01\nconfiguration plant written 2026-10-30T14:00:00Z\n",
            {"s", "plant"}
          )
        end
      )

      raises(
        "s: line 2: `2026\\xFF\\x01` is no time a store is written at, in UTC, as " <>
          "2026-10-27T14:00:00Z",
        fn ->
          Retain.decode!(
            "logex retain 1\nconfiguration plant written 2026\xFF\x01\n",
            {"s", "plant"}
          )
        end
      )
    end

    # RV-5's review: the store's path, the host's, as each line of a refusal names it,
    # printable whatever bytes it holds, a control byte, DEL and a byte of no UTF-8
    # character shown as its escape and a character past ASCII as it is; and a line's
    # 1,000 bytes counted after it, so that every line names the line and the problem
    # whatever its length, where a 1,115-byte path filled the line; one past 4,096 bytes,
    # the most a path Linux opens holds, shown as `…` and its last 4,096, the file's name
    # among them, cut at a character's boundary.
    test "the store's path in a refusal printable, and every line naming its line" do
      cut = @head <> "global total_boxes dint 3\n"

      # Decision 417 (RV-13), the leave for the refusal's warning to copy the store aside.
      told =
        "line 3: `global total_boxes dint 3` is the store's last line, and no end line: a " <>
          "store of `logex retain 2` ends with `end <count> lines`, its count of lines, so " <>
          "this one was cut short, and a store cut short is not read: start it with start: " <>
          ":cold to start over it, which copies it first to the next `.dropped.<n>` beside " <>
          "it and then writes a new store over it"

      deep = "/" <> Enum.map_join(1..20, "/", fn _ -> String.duplicate("d", 60) end)
      wide = "/" <> String.duplicate("é", 3000)
      kept = String.duplicate("é", div(4096 - byte_size("/plant.retain"), 2))

      for {path, shown} <- [
            {"/x/pl\xFFa\x01n\x7Ft\x00.retain", "/x/pl\\xFFa\\x01n\\x7Ft\\x00.retain"},
            {"/données/plant.retain", "/données/plant.retain"},
            {deep <> "/plant.retain", deep <> "/plant.retain"},
            {wide <> "/plant.retain", "…" <> kept <> "/plant.retain"}
          ] do
        message = refused(fn -> Retain.decode!(cut, {path, "plant"}) end)
        assert message == "#{shown}: #{told}"
        assert String.printable?(message)
      end
    end

    # RV-5's review: one problem past the 50 told, counted as one.
    test "a refusal of 51 problems counts the last as one" do
      text = counted_store(List.duplicate("global x dint 1", 52))
      lines = String.split(refused(fn -> Retain.decode!(text, {"s", "plant"}) end), "\n")
      assert length(lines) == 51
      assert List.last(lines) == "s: and 1 more problem, not listed"
    end

    # A line cut at its 1,000 bytes after its path ends at a character's boundary, a
    # character the cut would split dropped whole, whatever a line holds; `Logex.Refusal`
    # alone, the store's and the forces file's lines being printable ASCII but for its `…`.
    test "a line cut at a character's boundary" do
      line = String.duplicate("a", 999) <> "é" <> "tail"
      assert Logex.Refusal.told([line], "s") == "s: " <> String.duplicate("a", 999) <> "…"
    end

    # An empty line after the end line, which an editor may leave, told as what it is, the
    # line before it judged as the end line, where it was told as a store cut short.
    test "an empty line after the end line is told as one" do
      text = counted_store(["global total_boxes dint 3"])

      assert {%{globals: %{"total_boxes" => {:dint, 3}}}, _at} =
               Retain.decode!(text, {"s", "plant"})

      raises(
        "s: line 5: an empty line, which a store never holds: its end line is last\n" <>
          "s: line 6: an empty line, which a store never holds: its end line is last",
        fn -> Retain.decode!(text <> "\n\n", {"s", "plant"}) end
      )

      # One after a store cut short is told after the cut (the cut's remedy decision
      # 417's, the leave for its warning to copy the store aside).
      raises(
        "s: line 3: `global total_boxes dint 3` is the store's last line, and no end line: a " <>
          "store of `logex retain 2` ends with `end <count> lines`, its count of lines, so " <>
          "this one was cut short, and a store cut short is not read: start it with start: " <>
          ":cold to start over it, which copies it first to the next `.dropped.<n>` beside " <>
          "it and then writes a new store over it\ns: line 4: an empty line, which a store " <>
          "never holds: its end line is last",
        fn -> Retain.decode!(@head <> "global total_boxes dint 3\n\n", {"s", "plant"}) end
      )
    end

    # A store of a hundred thousand lines each naming what the first named, and one of a
    # line a megabyte long, each refused in a message of a few kilobytes: its first 50
    # problems, a line counting the rest, each text it quotes at most 60 bytes.
    test "a refusal names its first 50 problems and counts the rest, each text cut",
         %{tmp_dir: dir} do
      text = counted_store(List.duplicate("global x dint 1", 100_000))
      message = refused(fn -> Retain.decode!(text, {"s", "plant"}) end)
      lines = String.split(message, "\n")
      assert length(lines) == 51
      assert hd(lines) == "s: line 4: `global x dint 1` names what line 3 names already"
      assert List.last(lines) == "s: and 99949 more problems, not listed"
      assert byte_size(message) < 4_000

      word = String.duplicate("q", 1_000_000)

      raises(
        "s: line 3: `#{String.duplicate("q", 60)}…` is no type of a retained value: an " <>
          "elementary type's word, or an array of one, as `int[8]`",
        fn -> Retain.decode!(counted_store(["global x #{word} 1"]), {"s", "plant"}) end
      )

      # Through a fresh start, and with what the image refuses, `Logex.Runtime.start/2`'s
      # lines, bounded the same, each naming the store.
      rig = rig(dir)
      File.write!(rig.store, text)
      message = refused(fn -> Runner.start_link(rig.opts) end)
      assert length(String.split(message, "\n")) == 51
      assert String.ends_with?(message, "\n#{rig.store}: and 99949 more problems, not listed")

      paths = for i <- 1..120, do: "t1.boxes[x#{i}].cv dint 0"
      File.write!(rig.store, counted_store(["instance t1 tally" | paths]))
      message = refused(fn -> Runner.start_link(rig.opts) end)
      lines = String.split(message, "\n")
      assert length(lines) == 51
      assert hd(lines) =~ ~r/\A#{Regex.escape(rig.store)}: instance "t1": /
      assert List.last(lines) == "#{rig.store}: and 70 more problems, not listed"
      assert Sim.reads(rig.panel) == 0
    end

    defp refused(fun) do
      fun.()
      flunk("not refused")
    rescue
      error in ArgumentError -> error.message
    end

    # b3-store-image-5: every write is a new file renamed over the store, which would put a
    # file in a link's place and leave the file it names as it was, so a store or forces
    # file that is a link is refused at start, before either is read, a link to nothing
    # among them; a link at the store's `.tmp` or its copy is logex's own name, replaced.
    test "a store or forces file that is a symbolic link is refused at start",
         %{tmp_dir: dir} do
      rig = rig(dir)
      kept = Path.join(dir, "kept.retain")
      File.write!(kept, "old\n")
      File.ln_s!(kept, rig.store)

      for start <- [:warm, :cold] do
        raises(
          "the runner's retain: #{inspect(rig.store)} is a symbolic link: the store is " <>
            "written whole beside it and renamed over it, which would put a file in the " <>
            "link's place and leave the file it names as it was: name that file itself",
          fn -> Runner.start_link(rig.opts ++ [start: start]) end
        )
      end

      # A link to nothing too.
      File.rm!(kept)

      raises(~r/retain: .* is a symbolic link/, fn -> Runner.start_link(rig.opts) end)
      assert {:ok, %File.Stat{type: :symlink}} = File.lstat(rig.store)
      File.rm!(rig.store)

      forces = Path.join(dir, "plant.forces")
      File.ln_s!(Path.join(dir, "elsewhere.forces"), forces)

      raises(
        "the runner's forces: #{inspect(forces)} is a symbolic link: the forces file is " <>
          "written whole beside it and renamed over it, which would put a file in the " <>
          "link's place and leave the file it names as it was: name that file itself",
        fn -> Runner.start_link(rig.opts ++ [forces: forces]) end
      )

      assert Sim.reads(rig.panel) == 0
      refute File.exists?(rig.store)
    end
  end

  # Decision 284's remedy for a retained value that tripped the plant, a hand edit of the
  # store's line, made with the runner stopped (a7-docs-2): an edit made while it runs is
  # lost, a warm restart starting from what the runner holds and tripping again, its trip
  # writing the value back, and a stop writing it over the edit as it stops.
  describe "a hand edit, with the runner stopped (decision 284)" do
    defp slotted(dir) do
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

      rig(dir, configuration: configured(source, %{"scale" => scale}), write_limit: 5000)
    end

    defp edited(store),
      do:
        File.write!(
          store,
          String.replace(File.read!(store), "\ns1.slot dint 8\n", "\ns1.slot dint 0\n")
        )

    test "an edit while the runner runs is lost; one made with it stopped is read",
         %{tmp_dir: dir} do
      rig = slotted(dir)
      {:ok, runner} = Runner.start_link(rig.opts)
      Sim.set(rig.panel, [1], 1)
      Manual.advance(rig.clock, 100)

      assert %{status: :tripped, trip: {:fault, "fast", "s1", %{read: {8}}}} =
               Runner.status(runner)

      Sim.set(rig.panel, [1], 0)
      assert File.read!(rig.store) =~ "\ns1.slot dint 8\n"

      # Edited while tripped: a warm restart keeps what the runner holds, 8, and trips
      # again, the trip's write putting it back in the store.
      edited(rig.store)
      assert Runner.restart(runner, :warm) == :ok

      assert %{status: :tripped, trip: {:fault, "fast", "s1", %{read: {8}}}} =
               Runner.status(runner)

      assert File.read!(rig.store) =~ "\ns1.slot dint 8\n"

      # Edited again: the stop writes the 8 it holds over the edit.
      edited(rig.store)
      assert Runner.stop(runner) == :ok
      assert File.read!(rig.store) =~ "\ns1.slot dint 8\n"
      opener_down(rig.panel)

      # Edited with the runner stopped, the count kept: the fresh start reads 0 and runs.
      edited(rig.store)
      {:ok, runner} = Runner.start_link(rig.opts)
      assert %{status: :running} = Runner.status(runner)
      assert Runner.get!(runner, "s1.slot") == 0
      assert Runner.stop(runner) == :ok
    end
  end

  # Decision 360 (the review after Milestone 6, c6-pmi-2): a fresh start that drops
  # anything from its store copies the store, as it read it, before its first write over
  # it, so that a mistaken deploy's drops can be taken back after the next write has made
  # the store the new configuration's; the copy a time-limited write (decision 353), its
  # failure reported as a failed write's, the start going on; and `status/1` names it.
  # Decision 418 (RV-13), the leave for the one `<store>.dropped` and its replacement:
  # each copy a name of its own, `<store>.dropped.<n>`, n one past the highest that
  # stands, none replaced, where one `<store>.dropped` was replaced at each start that
  # dropped; each test's copy below is `.dropped.1`, its first, where it was `.dropped`.
  # Each runner here is given a write limit of 5,000 ms, which covers a loaded machine's
  # disk, none reading the limit: since decision 400 (RV-11) `write_limit:`, where an idle
  # watchdog of 5,000 stood for it (RV-4's question 12).
  describe "a store a fresh start drops from (decision 360)" do
    defp retyped,
      do:
        configured(
          @plant,
          programs(String.replace(@tally, "var retain boxes ctu", "var retain boxes ctu_int"))
        )

    # The period's writer, among the runner's links, through its mailbox and the runner
    # through its own, twice, so that the period's write handed it is made and taken.
    defp period_written(runner) do
      {:links, links} = Process.info(runner, :links)

      for pid <- links,
          {:dictionary, dictionary} <- [Process.info(pid, :dictionary)],
          dictionary[:"$initial_call"] == {Logex.Runner.Writer, :init, 1},
          _ <- 1..2 do
        _ = :sys.get_state(pid)
        _ = :sys.get_state(runner)
      end
    end

    # The panel a Watching device, which tells the test the copy's text at each read, so
    # that its first read, the start's own, sees whether the copy was made before it.
    defp watched(rig, config),
      do:
        rig.opts
        |> Keyword.put(:configuration, config)
        |> Keyword.put(:io, %{
          "panel" => {Watching, sim: rig.panel, store: rig.store <> ".dropped.1", test: self()}
        })

    test "a start that drops copies the store before any device is read, and names the copy",
         %{tmp_dir: dir} do
      rig = rig(dir, write_limit: 5000)
      {:ok, runner} = Runner.start_link(rig.opts)
      pressed(rig, [1, 0, 1])
      assert Runner.stop(runner) == :ok
      opener_down(rig.panel)
      read = File.read!(rig.store)

      {:ok, runner} = Runner.start_link(watched(rig, retyped()))
      assert_receive {:read, {:ok, ^read}}, 5000
      copy = rig.store <> ".dropped.1"

      # Decision 440 (RV-16), the leave for `unknown` absent: always there, nil where no
      # write is unknown.
      assert Runner.status(runner).retain == %{
               path: rig.store,
               written_at: ~U[2026-10-30 14:00:00Z],
               failed: nil,
               dropped: [{"t1.boxes", {:retyped, "ctu", "ctu_int"}}],
               copy: copy,
               unknown: nil
             }

      # The store itself as it was until the first write over it, the period's, which
      # writes the new configuration's; the copy as the start read it, the drop's value
      # in it.
      assert File.read!(rig.store) == read
      Manual.advance(rig.clock, 1000)
      period_written(runner)
      refute File.read!(rig.store) == read
      assert File.read!(rig.store) =~ "\nt1.boxes ctu_int\n"
      assert File.read!(copy) == read
      assert read =~ "\nt1.boxes ctu\nt1.boxes.cu bool 1\nt1.boxes.cv dint 2\n"
      refute File.exists?(rig.store <> ".dropped.tmp")
      assert Runner.stop(runner) == :ok
    end

    # Kept: a start that drops nothing, warm, cold or with no store, makes none and leaves
    # the copy where it is, and status/1 names none, its `copy` nil since decision 412
    # (RV-13), the leave for `copy` absent, where it had no `copy`; and since decision 418
    # the next that drops makes a copy of its own, the next number, `.dropped.2`, the
    # first kept, where it replaced the one copy with the store it read.
    test "every copy kept, the next that drops numbered past it", %{tmp_dir: dir} do
      rig = rig(dir, write_limit: 5000)
      {:ok, runner} = Runner.start_link(rig.opts)
      pressed(rig, [1, 0, 1])
      assert Runner.stop(runner) == :ok
      opener_down(rig.panel)
      first = File.read!(rig.store)
      copy = rig.store <> ".dropped.1"

      {:ok, runner} = Runner.start_link(Keyword.put(rig.opts, :configuration, retyped()))
      pressed(rig, [0, 1])
      assert Runner.stop(runner) == :ok
      opener_down(rig.panel)
      assert File.read!(copy) == first
      second = File.read!(rig.store)

      for extra <- [[], [start: :cold]] do
        {:ok, runner} =
          Runner.start_link(Keyword.merge(rig.opts, [configuration: retyped()] ++ extra))

        assert %{dropped: [], copy: nil} = Runner.status(runner).retain
        assert File.read!(copy) == first
        assert Runner.stop(runner) == :ok
        opener_down(rig.panel)
      end

      File.rm!(rig.store)
      {:ok, runner} = Runner.start_link(rig.opts)
      assert %{dropped: [], copy: nil} = Runner.status(runner).retain
      assert File.read!(copy) == first
      assert Runner.stop(runner) == :ok
      opener_down(rig.panel)

      # The store the retyped plant wrote, met by the original: dropped, and copied, to a
      # name of its own, the first copy as it was.
      File.write!(rig.store, second)
      {:ok, runner} = Runner.start_link(rig.opts)
      next = rig.store <> ".dropped.2"

      assert %{dropped: [{"t1.boxes", {:retyped, "ctu_int", "ctu"}}], copy: ^next} =
               Runner.status(runner).retain

      assert File.read!(next) == second
      assert File.read!(copy) == first
      assert Runner.stop(runner) == :ok
    end

    # Decision 418 (RV-13): a copy's number is one past the highest that stands beside the
    # store, every entry named the store's name, `.dropped.` and a whole number counting
    # by its number's value, whatever it is, a file or a directory a host made among them,
    # so that the copy's name is free; none is replaced; and an unnumbered `.dropped` an
    # earlier logex left counts for nothing and is kept as it stands (decision 450).
    test "a copy numbered one past the highest that stands, none replaced", %{tmp_dir: dir} do
      rig = rig(dir, write_limit: 5000)
      {:ok, runner} = Runner.start_link(rig.opts)
      pressed(rig, [1, 0])
      assert Runner.stop(runner) == :ok
      opener_down(rig.panel)
      read = File.read!(rig.store)
      at = &(rig.store <> &1)

      File.write!(at.(".dropped"), "an earlier logex's copy")
      File.write!(at.(".dropped.3"), "a host's file")
      File.write!(at.(".dropped.07"), "a host's seventh")
      File.mkdir!(at.(".dropped.9"))
      File.write!(at.(".dropped.011"), "a host's eleventh")
      File.write!(at.(".dropped.12.tmp"), "no copy's name")
      File.write!(at.(".dropped.x"), "nor this")
      before = for name <- File.ls!(dir), into: %{}, do: {name, File.read(Path.join(dir, name))}

      {:ok, runner} = Runner.start_link(Keyword.put(rig.opts, :configuration, retyped()))
      assert %{dropped: [_drop], copy: copy} = Runner.status(runner).retain
      assert copy == at.(".dropped.12")
      assert File.read!(copy) == read
      assert Runner.stop(runner) == :ok
      opener_down(rig.panel)

      for {name, was} <- before,
          name != "plant.retain",
          do: assert(File.read(Path.join(dir, name)) == was, name)

      # The next start that drops the same store makes no copy: since decision 456 (RV-6),
      # the leave for the next number past it, `.dropped.13`, the highest that stands,
      # `.dropped.12`, holds its bytes, and `status/1` names that one, the copy before it
      # kept.
      File.write!(rig.store, read)
      {:ok, runner} = Runner.start_link(Keyword.put(rig.opts, :configuration, retyped()))
      assert %{copy: next, failed: nil} = Runner.status(runner).retain
      assert next == copy
      refute File.exists?(at.(".dropped.13"))
      assert File.read!(copy) == read
      assert File.read!(at.(".dropped")) == "an earlier logex's copy"
      refute File.exists?(at.(".dropped.tmp"))
      assert Runner.stop(runner) == :ok
      opener_down(rig.panel)

      # A directory a host made past the highest copy counts as standing too, the highest
      # then (the review of RV-13): the next copy is numbered past it, where a count of
      # files alone would take its number and fail, `:eexist`; and the directory, which no
      # comparison reads, is no match for the store (decision 456).
      File.mkdir!(at.(".dropped.20"))
      File.write!(rig.store, read)
      {:ok, runner} = Runner.start_link(Keyword.put(rig.opts, :configuration, retyped()))
      assert %{copy: past, failed: nil} = Runner.status(runner).retain
      assert past == at.(".dropped.21")
      assert File.read!(past) == read
      assert File.dir?(at.(".dropped.20"))
      assert Runner.stop(runner) == :ok
    end

    # The review of RV-13: a store's copies are told by its name read whole, never by a
    # search for `.dropped.` in an entry's name, so that a store whose own name ends in
    # `.dropped` counts its copies, `plant.dropped.dropped.<n>`, and numbers the next past
    # them, each write after the start then made; where the search's matches, which never
    # overlap, read none of them, every copy was numbered 1, each after the first failed,
    # `:eexist`, and owed, and every write over the store failed behind it for the run.
    test "a store whose name ends in `.dropped` numbers its copies past its own",
         %{tmp_dir: dir} do
      store = Path.join(dir, "plant.dropped")
      rig = rig(dir, write_limit: 5000, retain: store)
      {:ok, runner} = Runner.start_link(rig.opts)
      pressed(rig, [1, 0])
      assert Runner.stop(runner) == :ok
      opener_down(rig.panel)
      read = File.read!(store)

      # Each start's store its own bytes, a total of its own, so that each makes a copy:
      # since decision 456 (RV-6) a start whose store holds the bytes of the highest copy
      # makes none.
      read =
        &String.replace(read, ~r/global total_boxes dint \d+/, "global total_boxes dint 10#{&1}")

      for n <- 1..3 do
        File.write!(store, read.(n))
        {:ok, runner} = Runner.start_link(Keyword.put(rig.opts, :configuration, retyped()))
        copy = store <> ".dropped.#{n}"
        assert %{copy: ^copy, failed: nil, dropped: [_drop]} = Runner.status(runner).retain
        assert File.read!(copy) == read.(n)
        refute read.(n) == read.(n + 1)
        Manual.advance(rig.clock, 1000)
        period_written(runner)
        assert File.read!(store) =~ "\nt1.boxes ctu_int\n"
        assert %{failed: nil, copy: ^copy} = Runner.status(runner).retain
        assert Runner.stop(runner) == :ok
        opener_down(rig.panel)
      end

      for n <- 1..3, do: assert(File.read!(store <> ".dropped.#{n}") == read.(n))
      refute File.exists?(store <> ".dropped.4")
    end

    # Decision 456 (RV-6), RV-13's question 8: a deploy that drops from the store copies
    # it, and then its device cannot be opened, and a supervisor starts it again while the
    # device boots, five times. Before it copies, each start compares the store with the
    # highest-numbered copy that stands, and where they hold the same bytes makes no new
    # copy, so that the five leave one copy, `.dropped.1`, where each made one of its own,
    # `.dropped.1` to `.dropped.5`, a card filled a store's size a restart; and the start
    # that opens its device names that one in `status/1`'s `copy`.
    test "five starts that fail after their copy leave one copy", %{tmp_dir: dir} do
      rig = rig(dir, write_limit: 5000)
      {:ok, runner} = Runner.start_link(rig.opts)
      pressed(rig, [1, 0, 1])
      assert Runner.stop(runner) == :ok
      opener_down(rig.panel)
      read = File.read!(rig.store)
      copy = rig.store <> ".dropped.1"
      opts = Keyword.put(rig.opts, :configuration, retyped())

      for _start <- 1..5 do
        Sim.fail(rig.panel, :init, {:error, :unplugged})
        assert Runner.start_link(opts) == {:error, {:io_init, "panel", :unplugged}}
        assert File.read!(rig.store) == read
        assert File.read!(copy) == read
        assert Enum.sort(File.ls!(dir)) == ["plant.retain", "plant.retain.dropped.1"]
      end

      {:ok, runner} = Runner.start_link(opts)

      assert %{copy: ^copy, failed: nil, dropped: [{"t1.boxes", _retyped}]} =
               Runner.status(runner).retain

      assert Enum.sort(File.ls!(dir)) == ["plant.retain", "plant.retain.dropped.1"]
      assert Runner.stop(runner) == :ok
    end

    # Decision 456 (RV-6): the comparison reads the highest copy only where it is a regular
    # file of the store's size, so that a FIFO a host put at the highest number, which a
    # read would wait on until the write limit cut the copy, is never read: it is no
    # match, and the copy is made past it at once.
    test "a FIFO at the highest copy's number is never read, the copy made past it",
         %{tmp_dir: dir} do
      rig = rig(dir, write_limit: 5000)
      {:ok, runner} = Runner.start_link(rig.opts)
      pressed(rig, [1, 0, 1])
      assert Runner.stop(runner) == :ok
      opener_down(rig.panel)
      read = File.read!(rig.store)
      {_out, 0} = System.cmd("mkfifo", [rig.store <> ".dropped.1"])
      opts = Keyword.put(rig.opts, :configuration, retyped())
      {took, {:ok, runner}} = :timer.tc(fn -> Runner.start_link(opts) end, :millisecond)
      copy = rig.store <> ".dropped.2"
      assert %{copy: ^copy, failed: nil, unknown: nil} = Runner.status(runner).retain
      assert File.read!(copy) == read
      assert took < 5000
      assert Runner.stop(runner) == :ok
    end

    # RV-6's review: the comparison reads the highest number's copy by the name logex
    # gives it, `<store>.dropped.<n>`. An entry spelled otherwise, `.dropped.007`, counts
    # for the number, so that the copy's name is free (decision 418), and is never
    # compared, the same bytes or not: `status/1` names a copy that stands under its own
    # name. A host's own regular file at that name holding the same bytes is the copy, as
    # decision 456 reads.
    test "a copy spelled otherwise at the highest number is never compared, the copy made " <>
           "past it; one at logex's own name with the same bytes is the copy",
         %{tmp_dir: dir} do
      rig = rig(dir, write_limit: 5000)
      {:ok, runner} = Runner.start_link(rig.opts)
      pressed(rig, [1, 0, 1])
      assert Runner.stop(runner) == :ok
      opener_down(rig.panel)
      read = File.read!(rig.store)
      opts = Keyword.put(rig.opts, :configuration, retyped())

      File.write!(rig.store <> ".dropped.007", read)
      {:ok, runner} = Runner.start_link(opts)
      copy = rig.store <> ".dropped.8"
      assert %{copy: ^copy, failed: nil, unknown: nil} = Runner.status(runner).retain
      assert File.read!(copy) == read
      assert Runner.stop(runner) == :ok
      opener_down(rig.panel)

      File.write!(rig.store, read)
      File.write!(rig.store <> ".dropped.9", read)
      {:ok, runner} = Runner.start_link(opts)
      copy = rig.store <> ".dropped.9"
      assert %{copy: ^copy, failed: nil, unknown: nil} = Runner.status(runner).retain
      refute File.exists?(rig.store <> ".dropped.10")
      assert Runner.stop(runner) == :ok
    end

    # A drop of any kind is copied for, the report itself the trigger: an instance the
    # configuration no longer has, and a global it no longer retains, beside the retyped
    # counter above.
    test "every kind of drop copies the store", %{tmp_dir: dir} do
      rig = rig(dir, write_limit: 5000)
      {:ok, runner} = Runner.start_link(rig.opts)
      pressed(rig, [1, 0])
      assert Runner.stop(runner) == :ok
      opener_down(rig.panel)
      read = File.read!(rig.store)
      copy = rig.store <> ".dropped.1"

      for {source, dropped} <- [
            {String.replace(@plant, "t1", "t2"), [{"t1", :undeclared}]},
            {String.replace(@plant, "var_global retain total_boxes", "var_global total_boxes"),
             [{"total_boxes", :unretained}]}
          ] do
        File.rm(copy)
        File.write!(rig.store, read)
        changed = configured(source, programs())

        {:ok, runner} = Runner.start_link(Keyword.put(rig.opts, :configuration, changed))
        assert %{dropped: ^dropped, copy: ^copy} = Runner.status(runner).retain
        assert File.read!(copy) == read
        assert Runner.stop(runner) == :ok
        opener_down(rig.panel)
      end
    end

    # The copy a write as every other (decision 353): one that fails is reported as a
    # failed write is, `failed` in status/1, and names no copy, the start going on. Since
    # RV-5's review the copy is then owed: no write replaces the store before it is made,
    # as decision 360 has it, where the period's write replaced the store and the drops
    # were lost for good. Each period's write makes the copy first and, while it fails,
    # writes no store, reported as a failed write; once the copy can be made the period's
    # makes it, of the store as the start read it, and then writes the store, the failure
    # cleared and the copy named.
    test "a copy that fails is owed, and no write replaces the store until it is made",
         %{tmp_dir: dir} do
      rig = rig(dir, write_limit: 5000)
      {:ok, runner} = Runner.start_link(rig.opts)
      pressed(rig, [1, 0])
      assert Runner.stop(runner) == :ok
      opener_down(rig.panel)
      read = File.read!(rig.store)
      copy = rig.store <> ".dropped.1"
      File.mkdir!(rig.store <> ".dropped.tmp")

      {:ok, runner} = Runner.start_link(Keyword.put(rig.opts, :configuration, retyped()))
      :ok = Runner.subscribe(runner)

      assert %{status: :running, retain: %{failed: :eisdir, copy: nil, dropped: [_drop]}} =
               Runner.status(runner)

      refute File.exists?(copy)

      for _period <- 1..2 do
        Manual.advance(rig.clock, 1000)
        period_written(runner)
        assert_receive {Runner, ^runner, {:retain, {:error, :eisdir}}}, 5000
        assert %{retain: %{failed: :eisdir, copy: nil}} = Runner.status(runner)
        assert File.read!(rig.store) == read
        refute File.exists?(copy)
      end

      File.rmdir!(rig.store <> ".dropped.tmp")
      Manual.advance(rig.clock, 1000)
      period_written(runner)
      assert %{retain: %{failed: nil, copy: ^copy}} = Runner.status(runner)
      assert File.read!(copy) == read
      assert File.read!(rig.store) =~ "\nt1.boxes ctu_int\n"
      refute_received {Runner, ^runner, {:retain, _}}

      # Made, the copy is owed no more: the next write leaves it as it is.
      File.write!(copy, "kept")
      Manual.advance(rig.clock, 1000)
      period_written(runner)
      assert Runner.stop(runner) == :ok
      assert File.read!(copy) == "kept"
    end

    # RV-5's review: the copy written at the store's path as the start resolved it, once,
    # as every read and write of it is (c2-runner-persist-9), and named in status/1 as the
    # host spelled the store: here through a link and `..`, which the kernel resolves past
    # the link, to another directory, and `Path.expand/1` by the words alone.
    test "the copy written where the store is read, and named as the host spelled it",
         %{tmp_dir: dir} do
      rig = rig(dir, write_limit: 5000)
      {:ok, runner} = Runner.start_link(rig.opts)
      pressed(rig, [1, 0])
      assert Runner.stop(runner) == :ok
      opener_down(rig.panel)
      read = File.read!(rig.store)
      File.mkdir_p!(Path.join([dir, "a", "b"]))
      File.ln_s!(Path.join([dir, "a", "b"]), Path.join(dir, "hop"))
      spelled = Path.join([dir, "hop", "..", "plant.retain"])
      opts = Keyword.merge(rig.opts, configuration: retyped(), retain: spelled)

      {:ok, runner} = Runner.start_link(opts)
      assert %{path: ^spelled, copy: copy, dropped: [_drop]} = Runner.status(runner).retain
      assert copy == spelled <> ".dropped.1"
      assert File.read!(rig.store <> ".dropped.1") == read
      refute File.exists?(Path.join([dir, "a", "plant.retain.dropped.1"]))
      assert Runner.stop(runner) == :ok
    end

    # RV-5's review: the copy is the store's bytes as the start read them, whatever their
    # spelling, never the store written again from what it holds: a hand edit's spelling
    # of a number, and a store of version 1, which the runner never writes now.
    test "the copy is the bytes the start read", %{tmp_dir: dir} do
      rig = rig(dir, write_limit: 5000)
      {:ok, runner} = Runner.start_link(rig.opts)
      pressed(rig, [1, 0])
      assert Runner.stop(runner) == :ok
      opener_down(rig.panel)
      written = File.read!(rig.store)
      assert written =~ "\nt1.boxes.cv dint 1\n"
      spelled = String.replace(written, "\nt1.boxes.cv dint 1\n", "\nt1.boxes.cv dint 16#01\n")

      v1 =
        written
        |> String.replace("logex retain 2", "logex retain 1")
        |> String.replace(~r/end \d+ lines\n\z/, "")

      for text <- [spelled, v1] do
        File.write!(rig.store, text)
        {:ok, runner} = Runner.start_link(Keyword.put(rig.opts, :configuration, retyped()))
        assert %{copy: copy, dropped: [_drop]} = Runner.status(runner).retain
        assert File.read!(copy) == text
        assert Runner.stop(runner) == :ok
        opener_down(rig.panel)
      end
    end

    # Decision 389 (RV-10), met in RV-5's merge of it: a stored trigger sample the
    # configuration has no task for, dropped by decision 277's matching and reported, is
    # copied for as every drop is, the drop report itself the copy's trigger, with no
    # change to the copy.
    test "a dropped trigger sample copies the store", %{tmp_dir: dir} do
      rig = rig(dir, write_limit: 5000)
      {:ok, runner} = Runner.start_link(rig.opts)
      pressed(rig, [1, 0])
      assert Runner.stop(runner) == :ok
      opener_down(rig.panel)
      [header, named | rest] = String.split(File.read!(rig.store), "\n", trim: true)
      lines = [header, named, "trigger gone 1" | Enum.drop(rest, -1)]
      text = Enum.join(lines, "\n") <> "\nend #{length(lines) + 1} lines\n"
      File.write!(rig.store, text)

      {:ok, runner} = Runner.start_link(rig.opts)
      assert %{dropped: [{"gone", :undeclared}], copy: copy} = Runner.status(runner).retain
      assert File.read!(copy) == text
      assert Runner.stop(runner) == :ok
    end

    # RV-5's review: what only the start reads leaves the runner's state once its devices
    # are open, the copy's text among it, which a copy made is owed no more; a round of a
    # runner with a store paid a reduction more for the host's spellings of its files
    # kept, which only a cost bound saw.
    test "what only the start reads is not kept", %{tmp_dir: dir} do
      rig = rig(dir, write_limit: 5000)
      {:ok, runner} = Runner.start_link(rig.opts)
      pressed(rig, [1, 0])
      assert Runner.stop(runner) == :ok
      opener_down(rig.panel)
      read = File.read!(rig.store)
      File.mkdir!(rig.store <> ".dropped.tmp")

      {:ok, runner} = Runner.start_link(Keyword.put(rig.opts, :configuration, retyped()))
      state = :sys.get_state(runner)
      assert Enum.filter([:copy, :named, :retain_period, :taker], &Map.has_key?(state, &1)) == []
      assert state.retain.owed == read
      File.rmdir!(rig.store <> ".dropped.tmp")
      Manual.advance(rig.clock, 1000)
      period_written(runner)
      assert %{retain: %{copy: _copy}} = Runner.status(runner)
      assert :sys.get_state(runner).retain.owed == nil
      assert Runner.stop(runner) == :ok
    end

    # The same at every event's write: a trip's, a cold restart's and a stop's, each
    # making the owed copy first and writing no store while it fails, the trip standing,
    # the cold restart leaving the runner tripped as it was (decision 291) and the stop
    # told the failure; the copy made by the first that can make it, the store then
    # written. A stop that could not make it left the store as the start read it, so the
    # next start drops from it again and copies it.
    test "every event's write makes the owed copy first", %{tmp_dir: dir} do
      rig = rig(dir, write_limit: 5000)
      {:ok, runner} = Runner.start_link(rig.opts)
      pressed(rig, [1, 0])
      assert Runner.stop(runner) == :ok
      opener_down(rig.panel)
      read = File.read!(rig.store)
      copy = rig.store <> ".dropped.1"
      tmp = rig.store <> ".dropped.tmp"
      File.mkdir!(tmp)
      opts = Keyword.put(rig.opts, :configuration, retyped())

      {:ok, runner} = Runner.start_link(opts)
      assert %{retain: %{failed: :eisdir, copy: nil}} = Runner.status(runner)
      tripped(rig, runner)
      assert %{status: :tripped, retain: %{failed: :eisdir, copy: nil}} = Runner.status(runner)
      assert File.read!(rig.store) == read
      assert Runner.restart(runner, :cold) == {:error, {:retain, :eisdir}}
      assert %{status: :tripped, retain: %{failed: :eisdir, copy: nil}} = Runner.status(runner)
      assert File.read!(rig.store) == read
      assert Runner.stop(runner) == {:error, {:retain, :eisdir}}
      assert File.read!(rig.store) == read
      refute File.exists?(copy)
      opener_down(rig.panel)

      {:ok, runner} = Runner.start_link(opts)
      assert %{retain: %{failed: :eisdir, copy: nil, dropped: [_drop]}} = Runner.status(runner)
      File.rmdir!(tmp)
      tripped(rig, runner)
      assert %{status: :tripped, retain: %{failed: nil, copy: ^copy}} = Runner.status(runner)
      assert File.read!(copy) == read
      assert File.read!(rig.store) =~ "\nt1.boxes ctu_int\n"
      assert Runner.stop(runner) == :ok
      opener_down(rig.panel)

      # A cold restart's write, and a stop's, make it in their turn, the cold restart's
      # after a trip that could not.
      for ended <- [:cold, :stop] do
        File.write!(rig.store, read)
        File.rm!(copy)
        File.mkdir!(tmp)
        {:ok, runner} = Runner.start_link(opts)
        assert %{retain: %{failed: :eisdir, copy: nil}} = Runner.status(runner)
        made_copy(ended, rig, runner, read)
        assert File.read!(copy) == read
        refute File.read!(rig.store) == read
        opener_down(rig.panel)
      end
    end

    defp made_copy(:cold, rig, runner, read) do
      tripped(rig, runner)
      assert File.read!(rig.store) == read
      File.rmdir!(rig.store <> ".dropped.tmp")
      assert Runner.restart(runner, :cold) == :ok
      assert %{status: :running, retain: %{failed: nil, copy: _copy}} = Runner.status(runner)
      assert File.read!(rig.store) =~ "\nt1.boxes.cv int 0\n"
      assert Runner.stop(runner) == :ok
    end

    defp made_copy(:stop, rig, runner, _read) do
      File.rmdir!(rig.store <> ".dropped.tmp")
      assert Runner.stop(runner) == :ok
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

      # Decision 360 (RV-5): nor the store's copy, which a start that drops writes over;
      # since decision 418 (RV-13), the leave for the one `.dropped`, any of its numbered
      # copies, `.dropped.<n>`, whatever the number's digits, or the copies' one `.tmp`,
      # and `.dropped`, which is written through that `.tmp`; and since decision 417 a cold
      # start over a store a fresh start would refuse copies it too, which the message
      # says (the review of RV-13). A store whose own name ends in `.dropped` has its
      # copies refused as any store's, its name read whole: `plant.dropped`'s first is
      # `plant.dropped.dropped.1`.
      dropped = Path.join(dir, "plant.dropped")

      for {store, copy} <-
            [{rig.store, ".dropped.1"}, {rig.store, ".dropped.12"}] ++
              [{rig.store, ".dropped.007"}, {rig.store, ".dropped.tmp"}] ++
              [{dropped, ".dropped.1"}, {dropped, ".dropped.30"}] do
        raises(
          "the runner's forces: #{inspect(store <> copy)} is a copy its retain: " <>
            "#{inspect(store)} is copied to, `.dropped.<n>`, by a start that drops from " <>
            "it or a cold start over it where a fresh start would refuse it, or the `.tmp` " <>
            "the copies are written through: the store's copies and the forces file are " <>
            "apart",
          fn ->
            Runner.start_link(Keyword.merge(rig.opts, retain: store, forces: store <> copy))
          end
        )
      end

      raises(
        "the runner's forces: #{inspect(rig.store <> ".dropped")} is written through " <>
          "#{inspect(rig.store <> ".dropped.tmp")}, the `.tmp` its retain: " <>
          "#{inspect(rig.store)} is copied through by a start that drops from it or a cold " <>
          "start over it where a fresh start would refuse it: the store's copies and the " <>
          "forces file are apart",
        fn -> Runner.start_link(Keyword.put(rig.opts, :forces, rig.store <> ".dropped")) end
      )

      # A forces file whose name only looks like a copy's is no copy: started, in a
      # directory of its own, so that the store its start writes is no file this test
      # reads.
      apart = rig(Path.join(dir, "apart"))
      File.mkdir_p!(Path.join(dir, "apart"))

      for name <- ~w(.dropped.1.tmp .dropped.x .dropped. .dropped.-1) do
        {:ok, runner} = Runner.start_link(Keyword.put(apart.opts, :forces, apart.store <> name))
        assert Runner.stop(runner) == :ok
        opener_down(apart.panel)
      end

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

  # The manual clock, its wall clock gone once the agent it holds says so, so that a
  # shutdown's write meets a clock that no longer names a time.
  defmodule WallGone do
    @behaviour Logex.Runner.Clock

    @impl true
    def now_ms({clock, _agent}), do: Manual.now_ms(clock)

    @impl true
    def wake_at({clock, _agent}, pid, message, at), do: Manual.wake_at(clock, pid, message, at)

    @impl true
    def cancel({clock, _agent}, timer), do: Manual.cancel(clock, timer)

    @impl true
    def wall_ms({clock, agent}), do: walled(Agent.get(agent, & &1), clock)

    defp walled(true, _clock), do: exit(:gone)
    defp walled(false, clock), do: Manual.wall_ms(clock)
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

  # The manual clock, its wall_ms/1 giving what the test put under its clock, once put.
  defmodule OddWall do
    @behaviour Logex.Runner.Clock

    @impl true
    def now_ms(clock), do: Manual.now_ms(clock)

    @impl true
    def wall_ms(clock), do: :persistent_term.get({__MODULE__, clock}, Manual.wall_ms(clock))

    @impl true
    def wake_at(clock, pid, message, at), do: Manual.wake_at(clock, pid, message, at)

    @impl true
    def cancel(clock, timer), do: Manual.cancel(clock, timer)
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

      # Decision 412 (RV-13), the leave for `copy` absent: `copy` always there, nil where
      # the start made no copy; and decision 440 (RV-16) `unknown` so, nil where no write
      # is unknown.
      assert Runner.status(runner).retain == %{
               path: rig.store,
               written_at: ~U[2026-10-30 14:00:00Z],
               failed: nil,
               dropped: [],
               copy: nil,
               unknown: nil
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

      # Decision 440 (RV-16), the leave for `unknown` absent: nil where no write is unknown.
      assert Runner.status(runner).retain == %{
               path: rig.store,
               written_at: ~U[2026-10-30 14:00:02Z],
               failed: nil,
               dropped: [],
               copy: nil,
               unknown: nil
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

      # What its image holds the start judges as any image, each line naming the store: a
      # sample that is no bool's value. (Until RV-10 this was `trigger arm 1`, of no global
      # of the configuration, which decision 389 makes a task's sample the start drops,
      # below, and until the review of RV-10 `trigger shown 1`, of a global the store does
      # not hold, which the review makes one too, "`triggers` holds \"shown\", which
      # `globals` does not hold".)
      File.write!(
        rig.store,
        "logex retain 1\nconfiguration plant written 2026-10-30T14:00:00Z\ntrigger arm 2\n"
      )

      raises(
        "#{rig.store}: `triggers` holds \"arm\" at 2, which is no last sample of a trigger, " <>
          "a bool's value",
        fn -> Runner.start_link(rig.opts) end
      )

      File.mkdir_p!(Path.join(dir, "adir"))

      raises(
        "#{Path.join(dir, "adir")}: the store cannot be read: illegal operation on a directory",
        fn -> Runner.start_link(Keyword.put(rig.opts, :retain, Path.join(dir, "adir"))) end
      )

      # No device was opened or read, and the store is as it was.
      assert Sim.reads(rig.panel) == 0
      assert File.read!(rig.store) =~ "trigger arm 2"
    end

    # `start: :cold` starts from no store, a broken one or another configuration's among
    # them, and writes a new one at once (decision 285). Decision 417 (RV-13), the leave
    # for a cold start that writes over a store a fresh start refused: it copies that store
    # first, as its bytes stand, under the next of its numbered copies (decision 418), and
    # writes the new store only once the copy is made, `status/1` naming the copy.
    test "start: :cold copies a store a fresh start would refuse, then writes a new one",
         %{tmp_dir: dir} do
      rig = rig(dir, start: :cold)
      old = "logex retain 1\nconfiguration line2 written 2026-10-30T14:00:00Z\n"
      File.write!(rig.store, old)
      {:ok, runner} = Runner.start_link(rig.opts)
      assert values(runner) == [0, 0, 0, 0]

      assert File.read!(rig.store) ==
               Retain.encode(
                 Runtime.retained(Runtime.start(configured())),
                 ~U[2026-10-30 14:00:00Z]
               )

      copy = rig.store <> ".dropped.1"
      assert %{copy: ^copy, dropped: [], failed: nil} = Runner.status(runner).retain
      assert File.read!(copy) == old
      assert Runner.stop(runner) == :ok
    end

    # Decision 456 (RV-6): a cold start compares the store it would copy with the highest
    # copy that stands, as a start that drops does, before it copies: one whose first write
    # fails after its copy is refused, the store as it was (decision 291), and each cold
    # start made again over it, its bytes the highest copy's, makes no new copy, where each
    # made one of its own; the one that writes names that copy.
    test "a cold start refused after its copy, started again, makes no second copy",
         %{tmp_dir: dir} do
      rig = rig(dir, start: :cold, write_limit: 5000)
      old = "logex retain 1\nconfiguration line2 written 2026-10-30T14:00:00Z\n"
      File.write!(rig.store, old)
      File.mkdir!(rig.store <> ".tmp")
      copy = rig.store <> ".dropped.1"

      for _start <- 1..3 do
        assert Runner.start_link(rig.opts) == {:error, {:retain, :eisdir}}
        assert File.read!(rig.store) == old
        assert File.read!(copy) == old

        assert Enum.sort(File.ls!(dir)) ==
                 ["plant.retain", "plant.retain.dropped.1", "plant.retain.tmp"]
      end

      File.rmdir!(rig.store <> ".tmp")
      {:ok, runner} = Runner.start_link(rig.opts)
      assert %{copy: ^copy, dropped: [], failed: nil} = Runner.status(runner).retain
      assert Enum.sort(File.ls!(dir)) == ["plant.retain", "plant.retain.dropped.1"]
      assert Runner.stop(runner) == :ok
    end

    # Decision 417 (RV-13): every store a warm fresh start would refuse is copied first by
    # a cold start, a cut one (decision 355), one of a line of no store's shape and one of
    # another configuration among them, each under the next number, none replaced; one
    # that reads whole, warm's to start from, needs no copy and gets none, as decision 360
    # copies only what a start drops; nor does a start that finds no store.
    test "a cold start copies what a fresh start would refuse, and nothing else",
         %{tmp_dir: dir} do
      rig = rig(dir, write_limit: 5000)
      {:ok, runner} = Runner.start_link(rig.opts)
      pressed(rig, [1, 0, 1])
      assert Runner.stop(runner) == :ok
      opener_down(rig.panel)
      whole = File.read!(rig.store)
      cold = Keyword.put(rig.opts, :start, :cold)

      refused = [
        binary_part(whole, 0, byte_size(whole) - 5),
        String.replace(whole, "\nt1.boxes ctu\n", "\n// a note\nt1.boxes ctu\n"),
        String.replace(whole, "configuration plant", "configuration line_2")
      ]

      for {text, n} <- Enum.with_index(refused, 1) do
        # A fresh start, warm, refuses it; a cold one copies it and starts.
        File.write!(rig.store, text)
        assert_raise ArgumentError, fn -> Runner.start_link(rig.opts) end
        {:ok, runner} = Runner.start_link(cold)
        copy = rig.store <> ".dropped.#{n}"
        assert %{copy: ^copy, dropped: [], failed: nil} = Runner.status(runner).retain
        assert File.read!(copy) == text
        # Started cold: the count and the total at their initial values, the eye still on.
        assert values(runner) == [0, 0, 1, 0]
        assert Runner.stop(runner) == :ok
        opener_down(rig.panel)
      end

      for {text, n} <- Enum.with_index(refused, 1),
          do: assert(File.read!(rig.store <> ".dropped.#{n}") == text)

      # A whole store, which a warm start would start from, and no store: no copy.
      for before <- [:whole, :none] do
        stand(before, rig.store, whole)
        {:ok, runner} = Runner.start_link(cold)
        assert %{copy: nil, dropped: []} = Runner.status(runner).retain
        assert Runner.stop(runner) == :ok
        opener_down(rig.panel)
        refute File.exists?(rig.store <> ".dropped.4")
      end
    end

    # Decision 417: a store is judged as a warm fresh start judges it, by its text's read,
    # `Logex.Retain.decode!/2`, and by the image's check, `Logex.Runtime.start/2`, so that
    # one whose text reads whole but whose image the start refuses, an element line for an
    # instance that holds no array, or a trigger's sample no bool holds, is copied first by
    # a cold start too, where a judge of the text alone wrote over it with no copy (the
    # review of RV-13).
    test "a cold start copies a store whose text reads but whose image a start refuses",
         %{tmp_dir: dir} do
      rig = rig(dir, write_limit: 5000)
      {:ok, runner} = Runner.start_link(rig.opts)
      pressed(rig, [1, 0, 1])
      assert Runner.stop(runner) == :ok
      opener_down(rig.panel)
      whole = File.read!(rig.store)
      cold = Keyword.put(rig.opts, :start, :cold)

      added = [
        {"t1.lamp bool 1\n", "t1.lamp bool 1\nt1.w[1] bool 1\n"},
        {"global total_boxes dint 2\n", "global total_boxes dint 2\ntrigger clr 2\n"}
      ]

      for {{from, to}, n} <- Enum.with_index(added, 1) do
        text = counted(String.replace(whole, from, to))
        refute text == whole
        assert {%{instances: %{"t1" => _}}, _at} = Retain.decode!(text, {rig.store, "plant"})
        File.write!(rig.store, text)
        assert_raise ArgumentError, fn -> Runner.start_link(rig.opts) end
        {:ok, runner} = Runner.start_link(cold)
        copy = rig.store <> ".dropped.#{n}"
        assert %{copy: ^copy, dropped: [], failed: nil} = Runner.status(runner).retain
        assert File.read!(copy) == text
        assert values(runner) == [0, 0, 1, 0]
        assert Runner.stop(runner) == :ok
        opener_down(rig.panel)
      end
    end

    # A store's text with its end line's count made the count of its lines again.
    defp counted(text) do
      lines = length(String.split(text, "\n", trim: true))
      String.replace(text, ~r/end \d+ lines\n\z/, "end #{lines} lines\n")
    end

    defp stand(:whole, store, whole), do: File.write!(store, whole)
    defp stand(:none, store, _whole), do: File.rm!(store)

    # Decision 417: the store written only once the copy is made, so a copy that cannot be
    # made is judged as decision 291 judges a cold start whose first write fails: the start
    # refused, `{:error, {:retain, reason}}`, the store as it was and no device opened, a
    # directory at the copies' `.tmp` here; and a store that stands but cannot be read, a
    # directory in its place, of which no copy can be made (decision 453), the same.
    test "a cold start whose copy cannot be made starts nothing, the store as it was",
         %{tmp_dir: dir} do
      rig = rig(dir, write_limit: 5000, start: :cold)
      cut = "logex retain 2\nconfiguration plant written 2026-10-30T14:00:00Z\nglobal tot"
      File.write!(rig.store, cut)
      File.mkdir!(rig.store <> ".dropped.tmp")

      assert Runner.start_link(rig.opts) == {:error, {:retain, :eisdir}}
      assert File.read!(rig.store) == cut
      refute File.exists?(rig.store <> ".dropped.1")
      assert Sim.reads(rig.panel) == 0
      assert Sim.writes(rig.panel) == []

      # Once the copy can be made, the start is made, the copy first.
      File.rmdir!(rig.store <> ".dropped.tmp")
      {:ok, runner} = Runner.start_link(rig.opts)
      assert File.read!(rig.store <> ".dropped.1") == cut
      refute File.read!(rig.store) == cut
      assert Runner.stop(runner) == :ok
      opener_down(rig.panel)

      store = Path.join(dir, "adir")
      File.mkdir!(store)
      reads = Sim.reads(rig.panel)

      assert Runner.start_link(Keyword.put(rig.opts, :retain, store)) ==
               {:error, {:retain, :eisdir}}

      assert File.dir?(store)
      assert Sim.reads(rig.panel) == reads
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

    # M6-6's review: a supervisor kills a child that has not ended by its spec's
    # `shutdown:`, which a GenServer's is 5000 ms; a runner's shutdown waits up to the idle
    # watchdog and a poll period on each device's close, and on its writer before it
    # writes, so its spec gives it `(devices + 2) * (idle + poll)`, never less than 5000
    # (decision 326, confirmed), and since decision 400 (RV-11) the writer's write and its
    # own each the write limit, `devices * (idle + poll) + 2 * write_limit`. Here a close
    # that hangs with `idle: 5000` holds the shutdown 5010 ms, past 5000, and the store is
    # written all the same.
    @tag timeout: 60_000
    test "a supervisor waits for a shutdown whose close hangs to write the store",
         %{tmp_dir: dir} do
      rig = rig(dir, idle: 5000)
      {:ok, supervisor} = Supervisor.start_link([{Runner, rig.opts}], strategy: :one_for_one)
      [{Runner, runner, :worker, _}] = Supervisor.which_children(supervisor)
      pressed(rig, [1, 0, 1])
      assert values(runner) == [2, 2, 1, 2]
      Sim.fail(rig.panel, :close, :hang)
      ref = Process.monitor(runner)
      begun = System.monotonic_time(:millisecond)
      :ok = Supervisor.stop(supervisor)
      assert_receive {:DOWN, ^ref, :process, ^runner, :shutdown}, 30_000
      assert System.monotonic_time(:millisecond) - begun >= 5010
      assert File.read!(rig.store) =~ "global total_boxes dint 2\n"
    end

    test "a runner's child spec gives its shutdown the time its devices and store take" do
      {:ok, clock} = Manual.start_link(now: @wall)
      io = fn n -> Map.new(1..n, &{"d#{&1}", Sim}) end
      base = [configuration: configured(), clock: {Manual, clock}, retain: "x.retain"]
      spec = &Runner.child_spec(Keyword.merge(base, &1))

      # Decision 400 (RV-11), the leave for a write limited to idle + poll: the writer's
      # write and the store's own each the write limit, 5000 ms unless set, where each was
      # the idle watchdog and a poll period, so that each figure below, but the floor's and
      # a host's own, counts two write limits where it counted two idle watchdogs and poll
      # periods (5000, 5100, 5610, 15_060, 8040, 5610 and 6020 before).
      assert %{id: Runner, restart: :temporary, shutdown: 10_510} = spec.(io: io.(1))
      assert spec.(io: io.(1)).start == {Runner, :start_link, [Keyword.merge(base, io: io.(1))]}
      assert spec.(io: io.(8)).shutdown == 14_080
      assert spec.(io: io.(9)).shutdown == 14_590
      assert spec.(io: io.(1), idle: 5000, poll: 20).shutdown == 15_020
      assert spec.(io: io.(2), idle: 2000).shutdown == 14_020
      assert spec.(io: io.(2), write_limit: 400).shutdown == 5000
      assert spec.(io: io.(8), write_limit: 400).shutdown == 5000
      assert spec.(io: io.(9), write_limit: 400).shutdown == 5390
      # An option start_link/1 refuses counts as its default; opts that are no keyword
      # list give a GenServer's 5000.
      assert spec.(io: io.(9), idle: 0, poll: :fast).shutdown == 14_590
      assert spec.(io: io.(9), write_limit: 0).shutdown == 14_590
      assert spec.(io: :none, idle: 3000).shutdown == 10_000
      # Decision 472 (RV-18): a forces file gives two write limits more, the force's write
      # that may be out and the write of the runner's set an orderly end makes.
      assert spec.(io: io.(1), forces: "x.forces").shutdown == 20_510
      assert spec.(io: io.(2), forces: "x.forces", write_limit: 400).shutdown == 5000
      assert spec.(io: io.(9), forces: "x.forces", write_limit: 400).shutdown == 6190
      assert Runner.child_spec(:nonsense).shutdown == 5000
      assert Runner.child_spec([{"io", 1}]).shutdown == 5000
      assert Supervisor.child_spec({Runner, base}, shutdown: 900).shutdown == 900

      # c1-runner-rounds-6 (RV-4): never past the longest a supervisor waits, 2^32 - 1 ms,
      # which a supervisor refuses at its shutdown.
      longest = [io: io.(1), idle: 2_147_483_647, poll: 2_147_483_647]
      assert spec.(longest).shutdown == 4_294_967_295
      assert spec.(io: io.(4), idle: 1_073_741_823, poll: 1).shutdown == 4_294_967_295
      assert spec.(io: io.(1), write_limit: 2_147_483_647).shutdown == 4_294_967_295
    end

    # c1-runner-rounds-5, c2-runner-persist-2 (RV-4): a stop whose clock went down before
    # its store's write, which names the time, answers that the write failed, the runner
    # stopped by the stop's reason, where the clock's exit escaped to the caller and ended
    # the runner abnormally.
    test "a stop whose clock is gone answers that its write failed", %{tmp_dir: dir} do
      rig = rig(dir)
      {:ok, runner} = Runner.start_link(rig.opts)
      Process.unlink(runner)
      pressed(rig, [1])
      written = File.read!(rig.store)
      ref = Process.monitor(runner)
      Process.unlink(rig.clock)
      Process.exit(rig.clock, :kill)

      assert {:error, {:retain, {:clock, gone}}} = Runner.stop(runner)
      assert gone == "the manual clock #{inspect(rig.clock)} is not running"
      assert_receive {:DOWN, ^ref, :process, ^runner, :normal}
      assert Sim.closed?(rig.panel)
      assert File.read!(rig.store) == written
    end

    # c5-tests-4 (RV-4): a map past 32 keys is in no order of its names, so the store's
    # global lines are sorted by name, as its instances' are: forty of them, in name order.
    test "a store's global lines are in name order past 32 of them", %{tmp_dir: dir} do
      names = for i <- 1..40, do: "g#{String.pad_leading("#{i}", 2, "0")}"

      text =
        "task fast interval 10 priority 1\nvar_global eye_1 bool at panel.i.0\n" <>
          Enum.map_join(Enum.shuffle(names), "", &"var_global retain #{&1} dint 7\n") <>
          "program c count with fast\n  c.eye eye_1\n"

      {:ok, count} =
        Logex.compile("var_input eye bool\nvar n dint\nxic eye add n 1 n", name: "count")

      {:ok, config} = Configuration.compile("plant", text, %{"count" => count})
      {:ok, clock} = Manual.start_link(now: @wall)
      {:ok, panel} = Sim.start_link(clock: clock)
      store = Path.join(dir, "plant.retain")

      {:ok, runner} =
        Runner.start_link(
          configuration: config,
          io: %{"panel" => {Sim, sim: panel}},
          clock: {Manual, clock},
          retain: store
        )

      lines = for "global " <> rest <- String.split(File.read!(store), "\n"), do: rest
      assert lines == Enum.map(names, &"#{&1} dint 7")
      assert Runner.stop(runner) == :ok
    end

    # c2-runner-persist-6 (RV-4): a wall clock that gives no time a header holds makes the
    # trip's write fail, reported as any failed write, the trip standing, where it crashed
    # the runner in the trip.
    test "a wall clock that gives no time later fails the write it was asked for",
         %{tmp_dir: dir} do
      rig = rig(dir)
      {:ok, runner} = Runner.start_link(Keyword.put(rig.opts, :clock, {OddWall, rig.clock}))
      :ok = Runner.subscribe(runner)
      written = File.read!(rig.store)
      :persistent_term.put({OddWall, rig.clock}, 1.5)
      on_exit(fn -> :persistent_term.erase({OddWall, rig.clock}) end)
      tripped(rig, runner)

      assert_receive {Runner, ^runner, {:retain, {:error, {:clock, {:wall_ms, 1.5}}}}}

      assert %{status: :tripped, retain: %{failed: {:clock, {:wall_ms, 1.5}}}} =
               Runner.status(runner)

      assert File.read!(rig.store) == written
      :persistent_term.erase({OddWall, rig.clock})
      assert Runner.stop(runner) == :ok
    end

    # Decision 394 (RV-11): a period's write whose wall clock gives no time a header holds
    # fails, reported as any failed write, and trips the runner naming the clock, every
    # output 0, where the plant ran on with every period's write failing; a restart while
    # the wall clock answers so is refused, and taken once it is mended.
    test "a period's write whose wall clock gives no time trips the runner, naming the " <>
           "clock (decision 394)",
         %{tmp_dir: dir} do
      rig = rig(dir)
      {:ok, runner} = Runner.start_link(Keyword.put(rig.opts, :clock, {OddWall, rig.clock}))
      :ok = Runner.subscribe(runner)
      pressed(rig, [1])
      :persistent_term.put({OddWall, rig.clock}, 1.5)
      on_exit(fn -> :persistent_term.erase({OddWall, rig.clock}) end)

      Manual.advance(rig.clock, 1000)
      assert_receive {Runner, ^runner, {:retain, {:error, {:clock, {:wall_ms, 1.5}}}}}
      assert_receive {Runner, ^runner, {:trip, {:clock, {:wall_ms, 1.5}}}}, 5000
      assert %{status: :tripped, trip: {:clock, {:wall_ms, 1.5}}} = Runner.status(runner)
      assert Sim.outputs(rig.panel) |> Map.values() |> Enum.all?(&(&1 == 0))
      assert Runner.restart(runner, :warm) == {:error, {:clock, {:wall_ms, 1.5}}}
      assert %{status: :tripped} = Runner.status(runner)

      :persistent_term.erase({OddWall, rig.clock})
      assert Runner.restart(runner, :warm) == :ok
      assert %{status: :running, trip: nil} = Runner.status(runner)
      assert Runner.stop(runner) == :ok
    end

    # Decision 441 (RV-16): with no untimed program the period's write comes at the end of
    # the round due with it, which reads its wall clock: one gone wrong stops that round
    # there and trips at once, so that a request that waited for the round is answered by
    # the trip, where the round went on to serve it running and the trip came after. Since
    # RV-16's review: the period's write is reported failed as before, and then the trip's
    # own, which reads the same wall clock; and the round, published as it ended, is
    # published once, its events none of the trip's.
    test "a period's write whose wall clock gives no time trips the round due with it at " <>
           "once (decision 441)",
         %{tmp_dir: dir} do
      rig = rig(dir)
      {:ok, runner} = Runner.start_link(Keyword.put(rig.opts, :clock, {OddWall, rig.clock}))
      :ok = Runner.subscribe(runner, [:overlap, :fault, :trip, :restart, :edit, :retain, :round])
      pressed(rig, [1])
      :persistent_term.put({OddWall, rig.clock}, 1.5)
      on_exit(fn -> :persistent_term.erase({OddWall, rig.clock}) end)

      # The period due at 1000 with the round there, a status/1 waiting for that round.
      Manual.pass(rig.clock, 990)
      status = Task.async(fn -> Runner.status(runner) end)
      waiting(status)
      _ = :sys.get_state(runner)
      Manual.advance(rig.clock, 0)

      assert %{status: :tripped, trip: {:clock, {:wall_ms, 1.5}}} = Task.await(status)
      assert_receive {Runner, ^runner, {:retain, {:error, {:clock, {:wall_ms, 1.5}}}}}
      assert_receive {Runner, ^runner, {:retain, {:error, {:clock, {:wall_ms, 1.5}}}}}
      assert_receive {Runner, ^runner, {:trip, {:clock, {:wall_ms, 1.5}}}}
      rounds = rounds_published(runner, [])
      assert List.last(rounds) == 1000
      assert rounds == Enum.uniq(rounds)
      :persistent_term.erase({OddWall, rig.clock})
      assert Runner.restart(runner, :warm) == :ok
      assert Runner.stop(runner) == :ok
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

    # Decision 316: a clock that goes down while the shutdown's write asks it the time
    # names no time, so that write is none, and the runner ends as its parent shut it
    # down, `:shutdown`, its devices zeroed and closed first, not as its clock's own exit.
    test "a shutdown whose clock goes down as it writes writes nothing", %{tmp_dir: dir} do
      rig = rig(dir)
      {:ok, agent} = Agent.start_link(fn -> false end)
      opts = Keyword.put(rig.opts, :clock, {__MODULE__.WallGone, {rig.clock, agent}})
      Process.flag(:trap_exit, true)
      {:ok, runner} = Runner.start_link(opts)
      written = File.read!(rig.store)
      pressed(rig, [1, 0, 1])
      assert values(runner) == [2, 2, 1, 2]
      Agent.update(agent, fn _ -> true end)
      ref = Process.monitor(runner)
      Process.exit(runner, :shutdown)
      assert_receive {:DOWN, ^ref, :process, ^runner, :shutdown}, 5000
      assert Sim.closed?(rig.panel)
      assert File.read!(rig.store) == written
    end

    # Decision 328 (the maintainer, 2026-10-30), changing M6-5's provisional reading,
    # which pinned this exit writing nothing: a parent that ends `:normal` is an orderly
    # exit, and the runner, which traps exits, writes the store as stop/2 does, every
    # output 0 and every device closed first, and the next fresh start brings it back.
    test "a parent's :normal exit writes the store after every output 0 and every device " <>
           "closed",
         %{tmp_dir: dir} do
      rig = rig(dir)
      store = rig.store
      test = self()

      opts =
        Keyword.put(rig.opts, :io, %{
          "panel" => {Watching, sim: rig.panel, store: store, test: test}
        })

      parent =
        spawn(fn ->
          {:ok, runner} = Runner.start_link(opts)
          send(test, {:runner, runner})
          receive do: (:end -> :ok)
        end)

      # The runner's start, in its parent, may take more than a moment under load.
      assert_receive {:runner, runner}, 5000
      started = File.read!(store)
      pressed(rig, [1, 0, 1])
      assert values(runner) == [2, 2, 1, 2]
      flush()
      ref = Process.monitor(runner)
      send(parent, :end)
      assert_receive {:DOWN, ^ref, :process, ^runner, :normal}, 5000
      assert_received {:written, %{[0] => 0}, {:ok, ^started}}
      assert Sim.closed?(rig.panel)
      assert File.read!(store) =~ "global total_boxes dint 2\n"
      opener_down(rig.panel)

      {:ok, runner} = Runner.start_link(rig.opts)
      assert values(runner) == [2, 2, 1, 2]
      assert Runner.stop(runner) == :ok
    end

    # Decision 328 for a tripped runner (M6-7's review): the trip wrote the store, and a
    # parent's `:normal` exit while tripped writes it again, the resource the trip kept,
    # as stop/2 of a tripped runner does. The store taken away after the trip shows the
    # second write.
    test "a parent's :normal exit while tripped writes the trip's resource", %{tmp_dir: dir} do
      rig = rig(dir)
      test = self()

      parent =
        spawn(fn ->
          {:ok, runner} = Runner.start_link(rig.opts)
          send(test, {:runner, runner})
          receive do: (:end -> :ok)
        end)

      assert_receive {:runner, runner}, 5000
      pressed(rig, [1, 0, 1])
      tripped(rig, runner)
      assert File.read!(rig.store) =~ "global total_boxes dint 2\n"
      File.rm!(rig.store)
      ref = Process.monitor(runner)
      send(parent, :end)
      assert_receive {:DOWN, ^ref, :process, ^runner, :normal}, 5000
      assert Sim.closed?(rig.panel)
      assert File.read!(rig.store) =~ "global total_boxes dint 2\n"
    end

    # Decisions 327 and 328: the runner tells an orderly exit by its reason alone, so a
    # `GenServer.stop/3` from a process that is not its parent, `:normal` or `:shutdown`,
    # writes the store too, and its caller is answered `:ok`.
    test "a GenServer.stop from any process, :normal or :shutdown, writes the store",
         %{tmp_dir: dir} do
      rig = rig(dir)
      {:ok, runner} = Runner.start_link(rig.opts)
      Process.unlink(runner)
      pressed(rig, [1, 0])
      stopper = Task.async(fn -> GenServer.stop(runner) end)
      assert Task.await(stopper, 10_000) == :ok
      assert Sim.closed?(rig.panel)
      assert File.read!(rig.store) =~ "global total_boxes dint 1\n"
      opener_down(rig.panel)

      {:ok, runner} = Runner.start_link(rig.opts)
      Process.unlink(runner)
      assert values(runner) == [1, 1, 1, 1]
      pressed(rig, [1, 0, 1])
      stopper = Task.async(fn -> GenServer.stop(runner, :shutdown) end)
      assert Task.await(stopper, 10_000) == :ok
      assert File.read!(rig.store) =~ "global total_boxes dint 3\n"
    end

    # Decision 327 (the maintainer, 2026-10-30): such a stop's caller is told `:ok` even
    # where the write fails, the failure told to the subscribers, as any failed write is;
    # stop/2 is the call that answers it. The runner is gone, so no status/1 reads it.
    test "a GenServer.stop whose write fails answers :ok and tells the subscribers",
         %{tmp_dir: dir} do
      rig = rig(dir)

      for reason <- [:normal, {:shutdown, :end_of_shift}] do
        {:ok, runner} = Runner.start_link(rig.opts)
        Process.unlink(runner)
        :ok = Runner.subscribe(runner)
        written = File.read!(rig.store)
        pressed(rig, [1, 0, 1])
        File.mkdir_p!(rig.store <> ".tmp")
        stopper = Task.async(fn -> GenServer.stop(runner, reason) end)
        assert Task.await(stopper, 10_000) == :ok
        assert_received {Runner, ^runner, {:retain, {:error, :eisdir}}}
        assert Sim.closed?(rig.panel)
        assert File.read!(rig.store) == written
        File.rm_rf!(rig.store <> ".tmp")
        opener_down(rig.panel)
      end
    end

    # Decision 328: a runner whose devices cannot be opened ends `:normal` too, but from
    # init/1, which gives `{:error, {:io_init, device, reason}}`, and a GenServer calls no
    # terminate/2 there: no resource has run, and the store is left exactly as it was.
    test "a runner whose device cannot be opened writes nothing", %{tmp_dir: dir} do
      rig = rig(dir)
      {:ok, runner} = Runner.start_link(rig.opts)
      pressed(rig, [1, 0, 1])
      assert Runner.stop(runner) == :ok
      written = File.read!(rig.store)
      opener_down(rig.panel)
      Manual.advance(rig.clock, 1000)

      Sim.fail(rig.panel, :init, {:error, :unplugged})
      assert Runner.start_link(rig.opts) == {:error, {:io_init, "panel", :unplugged}}
      assert File.read!(rig.store) == written
      assert File.ls!(dir) == ["plant.retain"]
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
      assert_receive {:EXIT, ^runner, :shutdown}, 5000
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
      assert_receive {Runner, ^runner, {:retain, {:error, :eisdir}}}, 5000
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
      # The restart's read of the panel makes the store's `.tmp` a directory in the
      # device's own process, through the VM's file server, within its real-time limit,
      # the idle watchdog and a poll period; beside a full suite and a mutation run's
      # (RV-4) that took over 510 ms in four runs of ten, the device killed before its
      # directory was made and the write-back did not fail, so the limit is 5000 ms here,
      # which nothing else in the test reads.
      rig = rig(dir, idle: 5_000)
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
      assert_receive {Runner, ^runner, {:retain, {:error, :eisdir}}}, 5000
      assert %{status: :tripped, trip: ^trip, retain: %{failed: :eisdir}} = Runner.status(runner)
      assert values(runner) == [2, 2, 1, 2]
      assert File.read!(rig.store) =~ "global total_boxes dint 0\n"
      assert List.last(Sim.writes(rig.panel)) == %{[0] => 0}
      File.rm_rf!(tmp)
      Agent.update(agent, fn _ -> fn -> :ok end end)
      assert Runner.stop(runner) == :ok
      assert File.read!(rig.store) =~ "global total_boxes dint 2\n"
    end

    # A trip's write that fails is reported and the store left as it was. A write limit
    # of 5000: since decision 353 the fresh start's, the trip's and the stop's writes each
    # have the write limit of real time, and at the runner's 510 ms, the idle watchdog and
    # a poll period before decision 400 (RV-11) gave the limit an option of its own, which
    # an idle watchdog of 5000 stood for here, a loaded machine's sync outran the stop's
    # now and then (scripts/load.sh, RV-4). The test reads no limit.
    test "a trip's write that fails is reported", %{tmp_dir: dir} do
      rig = rig(dir, write_limit: 5000)
      {:ok, runner} = Runner.start_link(rig.opts)
      :ok = Runner.subscribe(runner)
      written = File.read!(rig.store)
      pressed(rig, [1, 0, 1])
      File.mkdir_p!(rig.store <> ".tmp")
      tripped(rig, runner)

      assert_receive {Runner, ^runner, {:trip, {:io, "panel", {:error, :eio}}}}, 5000
      assert_receive {Runner, ^runner, {:retain, {:error, :eisdir}}}, 5000
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

  # Decision 350 (the maintainer, 2026-11-01): a trigger's rise stands as its last sample
  # only once the step that runs its task has run, so a round a major fault in an earlier
  # step trips leaves it as it was, in the resource and in the store, and the event task
  # runs on the next cycle that samples the rise: a warm restart's first, and a fresh
  # start's from the store, where until the review after Milestone 6 (b2-resource-1) the
  # rise was taken and the handler never ran. A box is counted where the task runs, and it
  # clears the latch.
  describe "a trigger's rise a trip cut off (decision 350)" do
    @arming "var_input eye bool\nvar_external arm bool\nxic eye otl arm"
    @counting "var_external hits dint\nvar_external arm bool\nadd hits 1 hits\notu arm"
    @faulting "var_external arm bool\nvar w int[2]\nvar i dint\nvar s bool\n" <>
                "xic arm ons s move 5 i\nxic arm move 1 w[i]"

    @tallying "var_external early_hits dint\nadd early_hits 1 early_hits"

    defp armed(dir, early \\ nil) do
      programs =
        for {name, text} <- [
              arming: @arming,
              counting: @counting,
              faulting: @faulting,
              tallying: @tallying
            ],
            into: %{} do
          {:ok, program} = Logex.compile(text, name: Atom.to_string(name))
          {Atom.to_string(name), program}
        end

      source = """
      task fast interval 1 priority 1
      task ev single arm priority 5
      var_global eye_1 bool at panel.i.0
      var_global retain arm bool
      var_global retain hits dint
      var_global retain early_hits dint
      program f1 faulting with fast
      program a1 arming with fast
        a1.eye eye_1
      program c1 counting with ev
      """

      rig(dir, configuration: configured(early_task(early, source), programs), poll: 10)
    end

    # A second event task on `arm`, `early`, before `fast` in the round, so the trip cuts
    # the round between the two tasks' steps; declared before `ev` or after it.
    defp early_task(nil, source), do: source

    defp early_task(:first, source),
      do: "task early single arm priority 0\n" <> source <> "program t1 tallying with early\n"

    defp early_task(:last, source),
      do:
        String.replace(
          source,
          "var_global eye_1",
          "task early single arm priority 0\nvar_global eye_1"
        ) <>
          "program t1 tallying with early\n"

    # The eye latches `arm` in one round; the next samples its rise, and `f1`, on `fast`,
    # before `ev`, faults on it: the round trips before `ev`'s step.
    defp cut_off(rig) do
      {:ok, runner} = Runner.start_link(rig.opts)
      Manual.advance(rig.clock, 30)
      Sim.set(rig.panel, [0], 1)
      Manual.advance(rig.clock, 30)
      assert %{status: :tripped, trip: {:fault, "fast", "f1", _}} = Runner.status(runner)
      assert {Runner.get!(runner, "arm"), Runner.get!(runner, "hits")} == {1, 0}
      Sim.set(rig.panel, [0], 0)
      Manual.advance(rig.clock, 10)
      runner
    end

    test "the event task runs after a warm restart, and the store kept the old sample",
         %{tmp_dir: dir} do
      rig = armed(dir)
      runner = cut_off(rig)
      {image, _at} = Retain.decode!(File.read!(rig.store), {rig.store, "plant"})
      assert image.triggers == %{"arm" => 0}
      assert Runner.restart(runner, :warm) == :ok
      Manual.advance(rig.clock, 20)
      assert {Runner.get!(runner, "arm"), Runner.get!(runner, "hits")} == {0, 1}
      assert Runner.stop(runner) == :ok
    end

    test "the event task runs after a crash and a fresh start from the store",
         %{tmp_dir: dir} do
      rig = armed(dir)
      runner = cut_off(rig)
      killed(runner)
      opener_down(rig.panel)
      {:ok, runner} = Runner.start_link(rig.opts)
      Manual.advance(rig.clock, 20)
      assert {Runner.get!(runner, "arm"), Runner.get!(runner, "hits")} == {0, 1}
      assert Runner.stop(runner) == :ok
    end
  end

  # RV-3's review: two event tasks on one trigger, the round cut between their steps, hold
  # two last samples, and the store keeps the one a task's step left as it was by the
  # task's name, so a fresh start from it runs the task the trip cut off, once, and not
  # the one that ran, whichever is declared first, as a warm restart does; until the review
  # the store kept the first task's sample for both, and the fresh start lost the cut
  # task's rise for good, or ran the other twice.
  describe "two event tasks on one trigger, a trip between their steps (decision 350)" do
    test "a warm restart and a fresh start from the store each run the cut task alone",
         %{tmp_dir: dir} do
      for {early, line} <- [first: "trigger ev 0", last: "trigger early 1"] do
        at = Path.join(dir, Atom.to_string(early))
        File.mkdir_p!(at)
        rig = armed(at, early)
        runner = cut_off(rig)
        assert Runner.get!(runner, "early_hits") == 1
        text = File.read!(rig.store)
        assert text =~ "\n" <> line <> "\n", text
        killed(runner)
        opener_down(rig.panel)
        {:ok, runner} = Runner.start_link(rig.opts)
        Manual.advance(rig.clock, 20)

        assert {Runner.get!(runner, "arm"), Runner.get!(runner, "hits"),
                Runner.get!(runner, "early_hits")} == {0, 1, 1},
               inspect(early)

        assert Runner.stop(runner) == :ok

        warm = Path.join(at, "warm")
        File.mkdir_p!(warm)
        rig = armed(warm, early)
        runner = cut_off(rig)
        assert Runner.restart(runner, :warm) == :ok
        Manual.advance(rig.clock, 20)

        assert {Runner.get!(runner, "arm"), Runner.get!(runner, "hits"),
                Runner.get!(runner, "early_hits")} == {0, 1, 1},
               inspect(early)

        assert Runner.stop(runner) == :ok
      end
    end

    # Since decision 389 a sample of a name the configuration declares with no single, a
    # task made periodic or taken out, is dropped and reported, and the resource starts,
    # where until RV-10 it was refused, "`triggers` holds \"fast\", which `globals` does not
    # hold".
    test "an image's sample of a task is a task's of the configuration, or dropped " <>
           "(decision 389)" do
      programs =
        for {name, text} <- [counting: @counting, tallying: @tallying], into: %{} do
          {:ok, program} = Logex.compile(text, name: Atom.to_string(name))
          {Atom.to_string(name), program}
        end

      config =
        configured(
          "task ev single arm priority 5\ntask early single arm priority 0\n" <>
            "task fast interval 1 priority 1\nvar_global retain arm bool\n" <>
            "var_global retain hits dint\nvar_global retain early_hits dint\n" <>
            "program c1 counting with ev\nprogram t1 tallying with early\n",
          programs
        )

      image = Runtime.retained(Runtime.start(config))
      assert image.triggers == %{"arm" => 0}
      {started, []} = Runtime.start(config, %{image | triggers: %{"arm" => 1, "early" => 0}})
      assert {started.tasks["ev"].last, started.tasks["early"].last} == {1, 0}

      assert {started, [{"fast", :undeclared}]} =
               Runtime.start(config, %{image | triggers: %{"arm" => 1, "fast" => 0}})

      assert {started.tasks["ev"].last, started.tasks["early"].last} == {1, 1}
    end
  end

  # Decision 389 (the maintainer, 2026-11-01), RV-3's question 16: a store written at a
  # round cut between two tasks on one trigger holds the cut task's own sample (decision
  # 350); a fresh start of a configuration that no longer declares that task drops the
  # sample, reports it in `status/1` as any dropped value, and starts, where until RV-10 it
  # started nothing. RV-5's copy of a store a fresh start drops from, decision 360, follows
  # the same `dropped`.
  describe "a stored sample of a task the configuration drops (decision 389)" do
    test "a fresh start drops it, reports it and starts", %{tmp_dir: dir} do
      rig = armed(dir, :last)
      runner = cut_off(rig)
      assert File.read!(rig.store) =~ "\ntrigger early 1\n"
      killed(runner)
      opener_down(rig.panel)

      programs =
        for {name, text} <- [arming: @arming, counting: @counting, faulting: @faulting],
            into: %{} do
          {:ok, program} = Logex.compile(text, name: Atom.to_string(name))
          {Atom.to_string(name), program}
        end

      config =
        configured(
          "task fast interval 1 priority 1\ntask ev single arm priority 5\n" <>
            "var_global eye_1 bool at panel.i.0\nvar_global retain arm bool\n" <>
            "var_global retain hits dint\nvar_global retain early_hits dint\n" <>
            "program f1 faulting with fast\nprogram a1 arming with fast\n  a1.eye eye_1\n" <>
            "program c1 counting with ev\n",
          programs
        )

      {:ok, runner} = Runner.start_link(Keyword.put(rig.opts, :configuration, config))
      assert %{dropped: [{"early", :undeclared}]} = Runner.status(runner).retain
      Manual.advance(rig.clock, 20)

      # The cut task gone, `ev` runs on the sample its trigger's entry held, as before.
      assert {Runner.get!(runner, "arm"), Runner.get!(runner, "hits")} == {0, 1}
      assert Runner.get!(runner, "early_hits") == 1
      assert Runner.stop(runner) == :ok
    end
  end

  # Decision 385 (the maintainer, 2026-11-01): a fresh start from the store puts each
  # retained `tof` held on at the outage at rest itself, through `Logex.Runtime.start/2`, a
  # member of a block whose `cal` is false at the first round among them, so that no fan
  # starts its run-on with nobody pressing anything.
  describe "a retained tof held on at the outage (decision 385)" do
    test "a fresh start from the store puts it at rest, in a block whose cal is false too",
         %{tmp_dir: dir} do
      {:ok, runon} =
        Logex.compile(
          "function_block runon\nvar_input go bool\nvar_output q bool\nvar t tof\n" <>
            "xic go tof t 50\nxic t.dn ote q",
          name: "runon"
        )

      {:ok, fans} =
        Logex.compile(
          "var_input motor bool\nvar_input go bool\nvar_output k bool\nvar_output l bool\n" <>
            "var retain fan tof\nvar retain r runon\nxic motor tof fan 50\n" <>
            "xic go cal r motor k\nxic fan.dn ote l",
          name: "fans",
          types: [runon]
        )

      config =
        configured(
          "task fast interval 10 priority 1\nvar_global m bool at panel.i.0\n" <>
            "var_global g bool at panel.i.1\nvar_global k bool at panel.q.0\n" <>
            "var_global l bool at panel.q.1\nprogram f1 fans with fast\nf1.motor m\n" <>
            "f1.go g\nf1.k k\nf1.l l\n",
          %{"fans" => fans}
        )

      rig = rig(dir, configuration: config)
      {:ok, runner} = Runner.start_link(rig.opts)
      Sim.set(rig.panel, [0], 1)
      Sim.set(rig.panel, [1], 1)
      Manual.advance(rig.clock, 20)
      Sim.set(rig.panel, [1], 0)
      Manual.advance(rig.clock, 20)
      assert {Runner.get!(runner, "k"), Runner.get!(runner, "l")} == {1, 1}
      killed(runner)
      Sim.set(rig.panel, [0], 0)
      opener_down(rig.panel)

      {:ok, runner} = Runner.start_link(rig.opts)
      assert Runner.get!(runner, "f1.fan.dn") == 0

      seen =
        for g <- [0, 1, 1] do
          Sim.set(rig.panel, [1], g)
          Manual.advance(rig.clock, 10)
          {Runner.get!(runner, "k"), Runner.get!(runner, "l")}
        end

      assert seen == [{0, 0}, {0, 0}, {0, 0}]
      assert Runner.stop(runner) == :ok
    end
  end

  describe "a runner with no store costs as before" do
    # Traced: a runner given no `retain:` takes no image out at a trip, a cold restart or a
    # stop, and restarts its resource once a restart, as before M6-5; one given a store takes
    # one out at each write, a cold restart's of the resource as it restarts it. Since
    # decision 455 (RV-6) each write takes its image out in the write's own process, which
    # the trace follows (`:set_on_spawn`), where the runner took it out itself.
    test "no image is taken out without a store", %{tmp_dir: dir} do
      Code.ensure_loaded!(Runtime)

      calls =
        for extra <- [[retain: nil], []] do
          File.mkdir_p!(Path.join(dir, "#{length(extra)}"))
          rig = rig(Path.join(dir, "#{length(extra)}"), extra)
          {:ok, runner} = Runner.start_link(rig.opts)
          assert :erlang.trace_pattern({Runtime, :retained, 1}, true, [:global]) == 1
          assert :erlang.trace_pattern({Runtime, :restart, 2}, true, [:global]) == 1
          :erlang.trace(runner, true, [:call, :set_on_spawn])
          pressed(rig, [1, 0])
          tripped(rig, runner)
          assert Runner.restart(runner, :cold) == :ok
          :erlang.trace(runner, false, [:call, :set_on_spawn])
          assert Runner.stop(runner) == :ok
          traced([])
        end

      :erlang.trace_pattern({Runtime, :_, :_}, false, [:global])
      assert calls == [[restart: 2], [retained: 1, restart: 2, retained: 1, restart: 2]]
    end
  end

  describe "the atomic write (decision 275)" do
    # Traced from the runner's process: the store is written to its `.tmp`, synced to the
    # disk and closed before it is renamed over the store, the forces file's rule.
    test "a write is synced before its rename", %{tmp_dir: dir} do
      rig = rig(dir)
      {:ok, runner} = Runner.start_link(rig.opts)
      assert :erlang.trace_pattern({:file, :_, :_}, true, [:global]) > 0
      # Since decision 353 the write is made in a process the runner starts for it, which
      # the trace follows.
      :erlang.trace(runner, true, [:call, :set_on_spawn])
      tripped(rig, runner)
      :erlang.trace(runner, false, [:call, :set_on_spawn])
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
