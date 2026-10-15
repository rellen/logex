defmodule LogexTest do
  @moduledoc """
  M1-5: `Logex.compile/2` and `Logex.compile_file/1`, the public way in. A program comes
  out named and stateless, or every mistake comes out as a located diagnostic. Milestone
  1's done sentence and Milestone 2's are each walked here, clause by clause, from files on
  disk.
  """
  use ExUnit.Case, async: true

  doctest Logex

  alias Logex.Diagnostic

  @seal "var_input start bool\nvar_input stop bool\nvar_output motor bool\n" <>
          "( xic start | xic motor ) xio stop ote motor\n"

  defp formatted({:error, diagnostics}), do: Enum.map(diagnostics, &Diagnostic.format/1)

  # Milestone 2's done sentence: §4.3's seal-in block and motor, §4.4's snapshot, and a
  # plant of §4.4's shape with a periodic task, an event task and a task-less instance.
  @m2_seal """
  function_block seal
  var_input start bool
  var_input stop bool
  var_output run bool

  ( xic start | xic run ) xio stop ote run
  """

  @m2_motor """
  var_input start bool
  var_input stop bool
  var_input overtemp bool
  var_input reset bool
  var_output motor bool
  var_output run_lamp bool
  var_output speed_sp dint 1200
  var_output running_ms dint
  var_external estop bool
  var fault bool
  var halt bool
  var s1 seal
  var t1 ton

  xic estop otl fault
  xic overtemp otl fault
  xic reset otu fault
  ( xic stop | xic fault ) ote halt
  cal s1 start halt motor
  xic motor ote run_lamp
  xic fault move 0 speed_sp
  xic motor ton t1 5000
  xic motor move t1.acc running_ms
  """

  @m2_snapshot """
  var_input a bool
  var_input b bool
  var_output a_was bool
  var_output b_was bool

  xic a ote a_was
  xic b ote b_was
  """

  @m2_plant """
  // two conveyors of one motor type, and a snapshot the e-stop's edge runs
  task fast interval 10 priority 1
  task trip single estop priority 0

  var_global estop      bool at panel.i.7
  var_global pb_start_1 bool at panel.i.0
  var_global pb_stop_1  bool at panel.i.1
  var_global tt_1       bool at panel.i.2
  var_global pb_start_2 bool at panel.i.3
  var_global pb_stop_2  bool at panel.i.4
  var_global tt_2       bool at panel.i.5
  var_global pb_reset   bool at panel.i.6
  var_global k1         bool at panel.q.0
  var_global k2         bool at panel.q.1
  var_global lamp_1     bool at panel.q.2
  var_global lamp_2     bool at panel.q.3
  var_global sp_1       dint at drive.q.0
  var_global sp_2       dint at drive.q.1
  var_global k1_at_trip bool
  var_global k2_at_trip bool

  program m1 motor with fast
    m1.start    pb_start_1
    m1.stop     pb_stop_1
    m1.overtemp tt_1
    m1.reset    pb_reset
    m1.motor    k1
    m1.run_lamp lamp_1
    m1.speed_sp sp_1

  program m2 motor
    m2.start    pb_start_2
    m2.stop     pb_stop_2
    m2.overtemp tt_2
    m2.reset    pb_reset
    m2.motor    k2
    m2.run_lamp lamp_2
    m2.speed_sp sp_2

  program snap snapshot with trip
    snap.a     k1
    snap.b     k2
    snap.a_was k1_at_trip
    snap.b_was k2_at_trip
  """

  # One mistake of each kind on each line that has one: scheduling (an interval of 0, a
  # trigger that is no global, an unknown task), wiring (an input point driven, a member
  # the type does not declare) and typing (a dint to a bool, a dint trigger), and a program
  # type whose own file does not compile.
  @m2_broken """
  task fast interval 0 priority 1
  task trip single estp priority 0
  task pulse single sp priority 2
  var_global estop bool at panel.i.7
  var_global k1    bool at panel.q.0
  var_global sp    dint
  program m1 motor with fsat
    m1.start    estop
    m1.stop     0
    m1.overtemp 0
    m1.reset    0
    m1.motor    estop
    m1.speed_sp k1
    m1.strat    0
  program b bad with trip
    b.a 0
  """

  # A seeded trace of N cycles: the elapsed time of each and the inputs it brings, the
  # start buttons pressed in the first cycle, then the e-stop, the stops and the resets
  # set at random, so its edges come where they will.
  defp m2_trace(n) do
    :rand.seed(:exsss, {2026, 10, 12})

    first = {0, %{"pb_start_1" => 1, "pb_start_2" => 1}}

    rest =
      for _ <- 2..n do
        inputs =
          for point <- ~w(estop pb_start_1 pb_start_2 pb_stop_1 pb_reset),
              :rand.uniform(4) == 1,
              into: %{},
              do: {point, :rand.uniform(2) - 1}

        {Enum.random([0, 5, 10, 10, 25]), inputs}
      end

    [first | rest]
  end

  # Each cycle's outputs, its events and the snapshot's two globals, from a fresh start.
  defp m2_run(config, trace) do
    {cycles, _runtime} =
      Enum.map_reduce(trace, Logex.Runtime.start(config), fn {elapsed, inputs}, runtime ->
        {runtime, outputs, events} = Logex.Runtime.cycle(runtime, elapsed, inputs)

        snapshot =
          {Logex.Runtime.get!(runtime, "k1_at_trip"), Logex.Runtime.get!(runtime, "k2_at_trip")}

        {{outputs, events, snapshot}, runtime}
      end)

    cycles
  end

  # The cycles in which the e-stop's input point rises, from the trace alone.
  defp m2_rises(trace) do
    trace
    |> Enum.map_reduce(0, fn {_elapsed, inputs}, last ->
      now = Map.get(inputs, "estop", last)
      {last == 0 and now == 1, now}
    end)
    |> elem(0)
    |> Enum.with_index()
    |> for_each_true()
  end

  defp for_each_true(flags), do: for({true, i} <- flags, do: i)

  # Each tag has a rung of its own, with a one-shot whose storage bit a second rung also
  # writes, a comparison of two literals, and a timer run by a `ton` whose members are read
  # and written, so every pass over the program, the M1-6 warnings among them, has work to
  # do. A second copy runs each timer with a second `ton`, followed on its path by a
  # contact, two errors, so the one-ton rule's and the path rule's reports are timed too,
  # and runs a timer no line declares, with a tag preset and a contact after it, so the
  # hints that look for a declared twin of it are.
  defp reductions_to_compile(tags, heap) do
    names = for i <- 1..tags, do: "t#{i}"
    declarations = Enum.map(names, &"var #{&1} bool\nvar #{&1}_s bool\nvar #{&1}_t ton")

    rungs =
      Enum.map(
        names,
        &("xic #{&1} ons #{&1}_s eq 1 1 ote #{&1}\nxio #{&1} ote #{&1}_s\n" <>
            "xic #{&1}_t.dn move #{&1}_t.acc #{&1}_t.pre\nxic #{&1} ton #{&1}_t 50")
      )

    source = Enum.join(declarations ++ rungs, "\n")
    tons = Enum.map(names, &"ton #{&1}_t 60 xic #{&1}\nton zz #{&1} xic #{&1}")
    twice = Enum.join(declarations ++ rungs ++ tons, "\n")

    in_a_process(heap, fn ->
      {:reductions, before} = Process.info(self(), :reductions)
      {:ok, _program} = Logex.compile(source, name: "big")
      {:error, _two_tons} = Logex.compile(twice, name: "big")
      {:reductions, later} = Process.info(self(), :reductions)
      later - before
    end)
  end

  # A process of its own, with a heap of the size given: `:large`, whose heap starts large
  # enough that the compile at 2,000 tags runs one major collection, not 61, each copying
  # a heap that holds the program built so far and charged in reductions, more of them on
  # a busy machine, 4M words, 32 MB; or `:default`, the VM's, where those collections run.
  defp in_a_process(heap, measure) do
    Task.await(
      Task.async(fn ->
        heap_of(heap)
        measure.()
      end),
      :infinity
    )
  end

  defp heap_of(:large) do
    Process.flag(:min_heap_size, 4_000_000)
    :erlang.garbage_collect()
  end

  defp heap_of(:default), do: :ok

  # One rung nested `depth` groups deep, each with a second leg and a contact after it, and
  # a timer's contact, a comparison of two literals and a one-shot innermost, so every walk
  # of a rung has work at every depth. A second copy has a `ton` innermost, which the
  # contact after every group follows on its path, an error at every depth, and as many
  # declarations after the rung, each told the rung's line, found at its innermost. The
  # least of three counts, since a busy VM can raise one by a few percent.
  defp reductions_to_nest(depth) do
    nest = fn innermost ->
      Enum.reduce(1..depth, innermost, fn _, inner -> "( #{inner} | xic b ) xic a" end)
    end

    declarations = "var a bool\nvar b bool\nvar s bool\nvar t1 ton\n"
    source = declarations <> "xic a ton t1 5\n" <> nest.("xic t1.dn eq 1 1 ons s") <> " ote b"
    late = Enum.map_join(1..depth, &"\nvar z#{&1} bool")
    timed = declarations <> nest.("xic a ton t1 5") <> late

    Enum.min(
      for _ <- 1..3 do
        {:reductions, before} = Process.info(self(), :reductions)
        {:ok, _program} = Logex.compile(source, name: "deep")
        {:error, _after_a_ton} = Logex.compile(timed, name: "deep")
        {:reductions, later} = Process.info(self(), :reductions)
        later - before
      end
    )
  end

  describe "compile/2" do
    test "names the program, keeps its source, and lowers it as instructionize/2 does" do
      {:ok, tokens, _} = Logex.Compiler.tokenize(@seal)
      {:ok, ast} = Logex.Compiler.parse(tokens)
      {:ok, lowered} = Logex.Compiler.instructionize(ast)

      assert {:ok, program} = Logex.compile(@seal, name: "seal")
      assert %Logex.Program{name: "seal", source: @seal, warnings: []} = program
      assert program.rungs == lowered.rungs
      assert program.tags == lowered.tags
    end

    test "a lex error is the one diagnostic, with its column" do
      result = Logex.compile("var a bool\nxic @a ote a", name: "p")
      assert {:error, [%Diagnostic{stage: :lex, line: 2, column: 5}]} = result
      assert formatted(result) == [~s(line 2, column 5: illegal character "@")]
    end

    test "a parse error is the one diagnostic, with its column" do
      result = Logex.compile("var a bool\nxic a ) ote a", name: "p")
      assert {:error, [%Diagnostic{stage: :parse, line: 2, column: 7}]} = result

      assert formatted(result) == [
               "line 2, column 7: expected a newline or end of input, found `)`"
             ]

      assert formatted(Logex.compile("var a bool\n( xic a ote a", name: "p")) == [
               "line 2, column 1: this `(` is never closed: the input ends before its `)`"
             ]
    end

    test "after the front end, every mistake is reported, stamped :validate" do
      result = Logex.compile("var a bool\nzzz\nxic b ote a", name: "p")

      assert formatted(result) == [
               "line 2: unknown instruction `zzz`",
               "line 3: `b` is not declared"
             ]

      {:error, diagnostics} = result
      assert Enum.all?(diagnostics, &(&1.stage == :validate))
    end

    test "raises ArgumentError when the call breaks its contract, never for the source" do
      for {call, message} <- [
            {fn -> Logex.compile(~c"xic a", name: "p") end,
             ~s(Logex.compile/2 takes source text as a binary, got: ~c"xic a")},
            {fn -> Logex.compile(@seal, name: :seal) end,
             "a program's name is a string, got: :seal"},
            {fn -> Logex.compile(@seal, name: nil) end, "a program's name is a string, got: nil"},
            {fn -> Logex.compile(@seal, name: "my seal") end,
             ~s("my seal" cannot name a program: a name is a letter or `_`, ) <>
               "then letters, digits or `_`"},
            # The rule is anchored at the very end: `$` would let a final newline through.
            {fn -> Logex.compile(@seal, name: "seal\n") end,
             ~s("seal\\n" cannot name a program: a name is a letter or `_`, ) <>
               "then letters, digits or `_`"},
            {fn -> Logex.compile(@seal, name: "") end,
             ~s("" cannot name a program: a name is a letter or `_`, ) <>
               "then letters, digits or `_`"},
            {fn -> Logex.compile(@seal, []) end,
             "Logex.compile/2 takes a name and, where the source uses function blocks, their " <>
               ~s|types, as in Logex.compile(source, name: "motor", types: [seal]), got: []|},
            {fn -> Logex.compile(@seal, name: "p", file: "x") end,
             "Logex.compile/2 takes a name and, where the source uses function blocks, their " <>
               ~s|types, as in Logex.compile(source, name: "motor", types: [seal]), | <>
               ~s|got: [name: "p", file: "x"]|}
          ] do
        assert_raise ArgumentError, message, call
      end
    end

    # Counted in reductions rather than time, so the bound holds on any machine. At 500
    # and 2,000 tags a linear compile grows about 4x; a pass that walks every use for
    # every tag, as the warnings first did, grows about 14x, 13.5x to 13.7x at M3-3's
    # review. What takes the figure above 4x is garbage collection, and a busy machine
    # takes it further: each major collection copies a heap that holds the program built
    # so far, 65 of them at 2,000 tags to 13 at 500, and a busy VM charges the same
    # collections more reductions, so that in the test's own process the figure reached
    # 7.29x with four suites at once, and its bound was 8.75. So each size compiles in a
    # process of its own whose heap starts at 4M words (in_a_process/2, `:large`), where
    # 2,000 tags take one major collection and 11 minor ones, not 61 and 168, and 500 tags
    # two minor ones: over 32 runs of the suite, 16 alone and 16 four at once, it grew
    # 4.07x to 4.12x alone and 4.09x to 4.36x four at once, the collections left charged a
    # little more on a busy machine. The bound is a fifth above that highest. Over 32 more
    # at M3-4's review, as many each way, it grew 4.05x to 4.12x alone and 4.07x to 4.50x
    # four at once, 16% under the bound.
    test "compiling stays linear in the program's size, in a heap no collection moves" do
      ratio = reductions_to_compile(2000, :large) / reductions_to_compile(500, :large)
      assert ratio < 5.24, "4x the tags took #{Float.round(ratio, 1)}x the reductions"
    end

    # The large heap hides what a compile copies. A Logex.Walk.instructions/1 that appends
    # each rung's instructions with `++`, quadratic in what it copies and 12x to 15x the
    # time at 4x the tags, grew 5.27x to 6.42x there, where `++` is charged few reductions
    # and no collection copies what it built, and passed 5.24 in three of five runs of the
    # suite at M3-4's review; in the VM's own heap, where each collection copies it again,
    # it grows 12.4x to 12.9x. So each size compiles again in a process of its own with the
    # VM's heap (in_a_process/2, `:default`): over 32 runs of the suite, 16 alone and 16
    # four at once, it grew 4.40x to 4.67x alone and 4.87x to 6.19x four at once. The bound
    # is a fifth above that highest.
    test "compiling stays linear in the program's size, in the VM's own heap" do
      ratio = reductions_to_compile(2000, :default) / reductions_to_compile(500, :default)
      assert ratio < 7.43, "4x the tags took #{Float.round(ratio, 1)}x the reductions"
    end

    # And in its depth. At 500 and 8,000 levels a linear compile grows about 16x. A walk
    # that copies what it found in a group at every level, as the instruction and warning
    # walks first did, grows 20x or more, since `++` is charged few reductions for what it
    # copies; the path pass, which copied its diagnostics so, grew about 140x, and finding
    # the first rung's line again for each declaration after it about 180x. Over the same
    # 96 runs it grew 15.72x to 16.38x; the bound is a fifth above the highest, and the
    # copying walks give 50x to 61x in this test (CONTRIBUTING.md).
    test "compiling stays linear in the depth of nesting" do
      ratio = reductions_to_nest(8000) / reductions_to_nest(500)
      assert ratio < 19.7, "16x the depth took #{Float.round(ratio, 1)}x the reductions"
    end

    test "a name is checked for shape only: a word reserved in .ld files is a good name" do
      assert {:ok, %Logex.Program{name: "move"}} = Logex.compile(@seal, name: "move")
      assert {:ok, %Logex.Program{name: "_Seal2"}} = Logex.compile(@seal, name: "_Seal2")
      assert {:ok, %Logex.Program{name: "motor_v2"}} = Logex.compile(@seal, name: "motor_v2")
    end
  end

  describe "compile_file/1" do
    @describetag :tmp_dir

    defp write(dir, file, source) do
      path = Path.join(dir, file)
      File.write!(path, source)
      path
    end

    test "names the program after the file and keeps its source", %{tmp_dir: dir} do
      path = write(dir, "seal.ld", @seal)
      assert {:ok, %Logex.Program{name: "seal", source: @seal}} = Logex.compile_file(path)
    end

    test "gives the done sentence's diagnostic, with the file on every one", %{tmp_dir: dir} do
      path = write(dir, "seal.ld", "var_input a bool\nvar b bool\nxyz a\nxic c ote b")

      assert formatted(Logex.compile_file(path)) == [
               "#{path}: line 3: unknown instruction `xyz`",
               "#{path}: line 4: `c` is not declared"
             ]
    end

    test "a file that cannot be read is a :file diagnostic, not an exception", %{tmp_dir: dir} do
      missing = Path.join(dir, "missing.ld")
      assert {:error, [%Diagnostic{stage: :file, line: nil}]} = Logex.compile_file(missing)

      assert formatted(Logex.compile_file(missing)) == [
               "#{missing}: cannot be read: no such file or directory"
             ]

      # A directory named as a `.ld` file passes the gate, and cannot be read.
      folder = Path.join(dir, "folder.ld")
      File.mkdir!(folder)

      assert formatted(Logex.compile_file(folder)) == [
               "#{folder}: cannot be read: illegal operation on a directory"
             ]
    end

    test "a file whose name cannot name a program is a :file diagnostic, and the source is " <>
           "still compiled",
         %{tmp_dir: dir} do
      clean = write(dir, "motor-v2.ld", @seal)

      assert {:error, [%Diagnostic{stage: :file, line: nil, file: ^clean}]} =
               Logex.compile_file(clean)

      assert formatted(Logex.compile_file(clean)) == [
               ~s(#{clean}: "motor-v2" cannot name a program: a name is a letter or `_`, ) <>
                 "then letters, digits or `_` (rename the file)"
             ]

      broken = write(dir, "2motor.ld", "var a bool\nxyz a")

      assert {:error,
              [%Diagnostic{stage: :file, line: nil}, %Diagnostic{stage: :validate, line: 2}]} =
               Logex.compile_file(broken)

      assert formatted(Logex.compile_file(broken)) == [
               ~s(#{broken}: "2motor" cannot name a program: a name is a letter or `_`, ) <>
                 "then letters, digits or `_` (rename the file)",
               "#{broken}: line 2: unknown instruction `xyz`"
             ]
    end

    test "a refused name gives no warnings: an :error result carries none", %{tmp_dir: dir} do
      path = write(dir, "motor-v2.ld", "var spare bool\nvar a bool\nxic a ote a")

      assert formatted(Logex.compile_file(path)) == [
               ~s(#{path}: "motor-v2" cannot name a program: a name is a letter or `_`, ) <>
                 "then letters, digits or `_` (rename the file)"
             ]
    end

    test "stamps the file on every warning too", %{tmp_dir: dir} do
      path = write(dir, "w.ld", "var spare bool\nvar a bool\nxic a ote a")
      assert {:ok, %Logex.Program{warnings: [warning]}} = Logex.compile_file(path)

      assert Diagnostic.format(warning) ==
               "#{path}: line 1: warning: `spare` is declared but no rung uses it"
    end

    test "Milestone 1's done sentence, as written in PLAN.md", %{tmp_dir: dir} do
      # A seal-in circuit written in a .ld file on disk ...
      path = write(dir, "seal.ld", @seal)
      # ... compiled once into a named, stateless value you can hold ...
      assert {:ok, %Logex.Program{name: "seal"} = seal} = Logex.compile_file(path)
      # ... run for N scans as an instance against a typed tag table ...
      steps = [{%{"start" => 1}, 1}, {%{"start" => 0}, 1}, {%{}, 1}, {%{"stop" => 1}, 0}]

      Enum.reduce(steps, Logex.Runtime.instance(seal), fn {inputs, motor}, state ->
        state = Logex.Runtime.put_inputs(seal, state, inputs)
        assert {%{"motor" => ^motor}, state} = Logex.Runtime.scan(seal, state, 10)
        state
      end)

      # ... and report a located diagnostic instead of raising.
      broken = write(dir, "broken.ld", "var_input a bool\nvar b bool\nxyz a\nxic a ote b")

      assert formatted(Logex.compile_file(broken)) == [
               "#{broken}: line 3: unknown instruction `xyz`"
             ]
    end

    # PLAN.md's Milestone 2 done sentence, walked clause by clause, from files on disk
    # through Logex.Configuration.compile_file/1, as the test above walks Milestone 1's. Its
    # plant is §4.4's, with §4.3's motor and seal-in block, but for `m2`, which runs under no
    # task, so that one configuration has a periodic task, an event task and no task.
    test "Milestone 2's done sentence, as written in PLAN.md", %{tmp_dir: dir} do
      # A configuration file on disk instantiates one `.ld` program type twice, with a
      # function block inside it ...
      write(dir, "seal.ld", @m2_seal)
      write(dir, "motor.ld", @m2_motor)
      write(dir, "snapshot.ld", @m2_snapshot)
      plant = write(dir, "plant.logex", @m2_plant)
      assert {:ok, config} = Logex.Configuration.compile_file(plant)
      assert config.warnings == []
      assert for(i <- config.instances, i.type == "motor", do: i.name) == ["m1", "m2"]
      assert %Logex.Program{blocks: %{"seal" => %Logex.FbType{}}} = config.programs["motor"]

      # ... wires the instances to declared I/O points and to a shared global ...
      located = for g <- config.globals, g.at != nil, into: MapSet.new(), do: g.name

      for c <- config.connections,
          c.instance in ~w(m1 m2),
          is_binary(c.to),
          do: assert(c.to in located)

      assert %Logex.Configuration.Global{at: "panel.i.7"} =
               Enum.find(config.globals, &(&1.name == "estop"))

      assert config.programs["motor"].tags["estop"].section == :var_external

      # ... schedules them under a periodic task, an event task and no task ...
      assert Enum.map(config.tasks, &{&1.name, &1.single, &1.interval}) ==
               [{"fast", nil, 10}, {"trip", "estop", nil}]

      assert Enum.map(config.instances, &{&1.name, &1.task}) ==
               [{"m1", "fast"}, {"m2", nil}, {"snap", "trip"}]

      # ... runs deterministically for N cycles from an injected clock and input image,
      # with the same outputs on every run ...
      trace = m2_trace(60)
      first = m2_run(config, trace)
      assert {:ok, again} = Logex.Configuration.compile_file(plant)
      assert m2_run(again, trace) == first
      assert m2_run(config, trace) == first

      # The run does what the plant says: the start buttons close both contactors, and the
      # event task runs the snapshot first in each cycle the e-stop rises, and only then,
      # which records the contactors as the cycle before left them.
      outputs = for {outputs, _events, _snapshot} <- first, do: outputs
      events = for {_outputs, events, _snapshot} <- first, do: events
      assert Map.take(hd(outputs), ~w(k1 k2)) == %{"k1" => 1, "k2" => 1}
      trips = for {cycle, i} <- Enum.with_index(events), {:ran, "trip", "snap", _} <- cycle, do: i
      assert [_ | _] = trips
      assert trips == m2_rises(trace)
      for i <- trips, do: assert([{:ran, "trip", "snap", _} | _] = Enum.at(events, i))

      for i <- trips do
        {_outputs, _events, snapshot} = Enum.at(first, i)
        before = Enum.at([%{"k1" => 0, "k2" => 0} | outputs], i)
        assert snapshot == {before["k1"], before["k2"]}
      end

      # ... and reports every wiring, typing or scheduling mistake as a located diagnostic
      # naming its file and line.
      bad = write(dir, "bad.ld", "var_input a bool\nvar_output b bool\nxyz a\nxic a ote b")
      broken = write(dir, "broken.logex", @m2_broken)
      assert {:error, diagnostics} = Logex.Configuration.compile_file(broken)

      for d <- diagnostics,
          do: assert(is_binary(d.file) and is_integer(d.line), Diagnostic.format(d))

      assert formatted({:error, diagnostics}) == [
               "#{broken}: line 1: the interval of `fast` is 0: an interval is at least 1 ms, " <>
                 "and an instance that runs every cycle is declared without `with`",
               "#{broken}: line 2: the single of `trip`: no global `estp` — did you mean `estop`?",
               "#{broken}: line 3: the single of `pulse`, `sp`, is a dint (line 6): a single is " <>
                 "a bool global",
               "#{broken}: line 7: no task `fsat` — did you mean `fast`?",
               "#{broken}: line 12: `estop` is an input point (line 4): `m1.motor`, a " <>
                 "var_output, cannot drive it",
               "#{broken}: line 13: `m1.speed_sp` is a dint, but `k1` is a bool (line 5)",
               "#{broken}: line 14: `m1` is a `motor`, which declares no `strat` — did you mean " <>
                 "`start`?",
               "#{broken}: line 15: program type `bad` does not compile: its mistakes follow, " <>
                 "cited in `bad.ld`",
               "#{bad}: line 3: unknown instruction `xyz`"
             ]
    end

    # The name is the basename less its `.ld`. PLAN M2-2 (decided 2026-09-30): the
    # extension says what kind of file it is, so compile_file/1 takes only `.ld`, exactly,
    # where it once named a program after its basename less any last extension. This test
    # held `seal.txt` to that rule, and flips with the item.
    test "the name is the basename less its `.ld`", %{tmp_dir: dir} do
      assert {:ok, %Logex.Program{name: "seal"}} =
               Logex.compile_file(write(dir, "seal.ld", @seal))

      assert {:error, [%Diagnostic{stage: :file, message: ~s("seal.v2" cannot name) <> _}]} =
               Logex.compile_file(write(dir, "seal.v2.ld", @seal))
    end

    test "takes only a `.ld` file, exactly: any other is a :file diagnostic, and nothing is " <>
           "read",
         %{tmp_dir: dir} do
      for file <- ["seal.txt", "seal", "seal.LD", "seal.Ld", "seal.ld.bak", "seal.ldx"] do
        path = write(dir, file, @seal)

        assert {:error, [%Diagnostic{stage: :file, line: nil, file: ^path}]} =
                 Logex.compile_file(path)

        assert formatted(Logex.compile_file(path)) == [
                 "#{path}: `#{file}` is not a `.ld` file: Logex.compile_file/1 compiles a " <>
                   "program or a function block from its `.ld` file"
               ]
      end

      # Nothing is read: a file that is not there is told its kind, not that it is missing.
      missing = Path.join(dir, "missing.txt")

      assert formatted(Logex.compile_file(missing)) == [
               "#{missing}: `missing.txt` is not a `.ld` file: Logex.compile_file/1 " <>
                 "compiles a program or a function block from its `.ld` file"
             ]

      # A configuration file is not compile_file/1's, and is told whose it is.
      plant = write(dir, "plant.logex", "program m seal\n")

      assert formatted(Logex.compile_file(plant)) == [
               "#{plant}: `plant.logex` is a configuration file (`.logex`), which " <>
                 "Logex.Configuration.compile_file/1 loads"
             ]

      # A file named only `.ld` is a `.ld` file whose name names no program.
      bare = write(dir, ".ld", @seal)

      assert formatted(Logex.compile_file(bare)) == [
               ~s(#{bare}: "" cannot name a program: a name is a letter or `_`, then ) <>
                 "letters, digits or `_` (rename the file)"
             ]
    end

    test "a file named after a word reserved in .ld files compiles", %{tmp_dir: dir} do
      path = write(dir, "move.ld", @seal)
      assert {:ok, %Logex.Program{name: "move"}} = Logex.compile_file(path)
    end

    test "raises ArgumentError for a path that is not a binary" do
      assert_raise ArgumentError,
                   ~s(Logex.compile_file/1 takes a path as a binary, got: ~c"m.ld"),
                   fn -> Logex.compile_file(~c"m.ld") end
    end
  end

  describe "compile_files/1 (M2-2): several files, one memo" do
    @describetag :tmp_dir

    # A block with a warning, held by two programs.
    @block """
    function_block latch
    var_input set bool
    var_output q bool
    var spare bool
    xic set ote q
    """

    defp program_holding(dir, name) do
      path = Path.join(dir, name <> ".ld")
      File.write!(path, "var_input a bool\nvar_output b bool\nvar l1 latch\ncal l1 a b\n")
      path
    end

    test "compiles each as compile_file/1 does, a block they share once, its warnings " <>
           "handed back once",
         %{tmp_dir: dir} do
      latch = Path.join(dir, "latch.ld")
      File.write!(latch, @block)
      one = program_holding(dir, "one")
      two = program_holding(dir, "two")
      warning = "#{latch}: line 4: warning: `spare` is declared but no rung uses it"

      assert [{:ok, first}, {:ok, second}] = Logex.compile_files([one, two])
      assert {:ok, first} == Logex.compile_file(one)
      assert Enum.map(first.warnings, &Diagnostic.format/1) == [warning]
      assert {:ok, %{second | warnings: [hd(first.warnings)]}} == Logex.compile_file(two)
      assert second.warnings == []

      # In the other order, the other program hands the warning back.
      assert [{:ok, %{warnings: [_]}}, {:ok, %{warnings: []}}] = Logex.compile_files([two, one])

      # A path given twice gives its one result twice; each path passes the gate.
      assert [{:ok, ^first}, {:ok, ^first}] = Logex.compile_files([one, one])
      text = Path.join(dir, "one.txt")

      assert [{:ok, ^first}, {:error, [%Diagnostic{stage: :file, file: ^text}]}] =
               Logex.compile_files([one, text])

      assert Logex.compile_files([]) == []
    end

    # A block's own file hands nothing back, so it counts no block as handed back: a
    # program after it hands back the warnings of the block and of the block it holds.
    test "a block's file before a program that holds it hands back nothing for it",
         %{tmp_dir: dir} do
      File.write!(
        Path.join(dir, "inner.ld"),
        "function_block inner\nvar_input i bool\nvar_output o bool\nvar spare_inner bool\n" <>
          "xic i ote o\n"
      )

      seal = Path.join(dir, "seal.ld")

      File.write!(
        seal,
        "function_block seal\nvar_input i bool\nvar_output o bool\nvar spare_seal bool\n" <>
          "var n inner\ncal n i o\n"
      )

      belt = Path.join(dir, "belt.ld")
      File.write!(belt, "var_input i bool\nvar_output o bool\nvar s seal\ncal s i o\n")
      unused = &"`#{&1}` is declared but no rung uses it"

      assert [{:ok, %Logex.FbType{} = block}, {:ok, program}] =
               Logex.compile_files([seal, belt])

      assert Enum.map(block.body.warnings, & &1.message) == [unused.("spare_seal")]
      assert {:ok, program} == Logex.compile_file(belt)

      assert Enum.map(program.warnings, & &1.message) == [
               unused.("spare_inner"),
               unused.("spare_seal")
             ]
    end

    # What a cycle cites depends on the file it was reached from, so each path's result is
    # its own compile_file/1's, in either order.
    test "a chain of blocks that holds itself is cited from each path as compile_file/1 " <>
           "cites it",
         %{tmp_dir: dir} do
      for {name, holds} <- [{"fa", "fb"}, {"fb", "fa"}] do
        File.write!(
          Path.join(dir, name <> ".ld"),
          "function_block #{name}\nvar_input i bool\nvar x #{holds}\ncal x i\n"
        )
      end

      [pa, pb] =
        for {name, holds} <- [{"pa", "fa"}, {"pb", "fb"}] do
          path = Path.join(dir, name <> ".ld")
          File.write!(path, "var_input i bool\nvar x #{holds}\ncal x i\n")
          path
        end

      cycle = fn file, chain ->
        [own, held | _] = chain

        "#{Path.join(dir, file)}: line 3: `#{own}` cannot hold an instance of `#{held}` " <>
          "(#{Enum.join(chain, " → ")}): a function block never holds an instance of " <>
          "itself, at any depth"
      end

      assert formatted(Logex.compile_file(pa)) == [cycle.("fb.ld", ["fb", "fa", "fb"])]
      assert formatted(Logex.compile_file(pb)) == [cycle.("fa.ld", ["fa", "fb", "fa"])]
      alone = [Logex.compile_file(pa), Logex.compile_file(pb)]
      assert Logex.compile_files([pa, pb]) == alone
      assert Logex.compile_files([pb, pa]) == Enum.reverse(alone)
    end

    test "raises ArgumentError for what is not a proper list of binaries" do
      for paths <- ["one.ld", [~c"one.ld"], ["one.ld" | "two.ld"], [:one]] do
        assert_raise ArgumentError,
                     "Logex.compile_files/1 takes a list of paths as binaries, got: " <>
                       inspect(paths),
                     fn -> Logex.compile_files(Process.get(:opaque, paths)) end
      end
    end
  end
end
