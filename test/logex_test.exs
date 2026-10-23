defmodule LogexTest do
  @moduledoc """
  M1-5: `Logex.compile/2` and `Logex.compile_file/1`, the public way in. A program comes
  out named and stateless, or every mistake comes out as a located diagnostic. Milestone
  1's done sentence, Milestone 2's and Milestone 3's are each walked here, clause by clause,
  from files on disk.
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

  # Milestone 3's done sentence: a small bottling line in two `.ld` files under a `.logex`
  # configuration, every instruction Milestone 3 landed among them.
  @m3_conveyor """
  var_input run_pb bool
  var_input manual bool
  var_input jog_pb bool
  var_input bottle_eye bool
  var_input case_gone bool
  var_input infeed_eye bool
  var_input outfeed_eye bool
  var_input jam bool
  var_output motor bool
  var_output fan bool
  var_output horn bool
  var_output case_full bool
  var_output jog_lamp bool
  var_output cases dint
  var_output buffered dint
  var jog bool
  var s_case bool
  var step bool
  var bottles ctu
  var buffer ctud
  var run_on tof
  var horn_pulse tp

  // the manual section, skipped while the line is in auto
  xio manual jmp auto
  xic jog_pb ote jog
  xic jog ote jog_lamp
  lbl auto ( xic run_pb xio manual | xic manual xic jog ) ote motor
  // bottles into cases of 12, the count cleared as a full case leaves
  xic case_gone ote bottles.r
  xic bottle_eye ctu bottles 12
  xic bottles.q ote case_full
  xic bottles.q osr s_case step
  xic step add cases 1 cases
  // the buffer table, bottles in and out
  xic infeed_eye ctu buffer 50
  xic outfeed_eye ctd buffer 50
  move buffer.cv buffered
  // the fan runs on after the motor stops, and the horn sounds on a jam
  xic motor tof run_on 300
  xic run_on.dn ote fan
  xic jam tp horn_pulse 200
  xic horn_pulse.tt ote horn
  """

  @m3_filler """
  var_input fill bool
  var_input flow dint
  var_input minutes dint
  var_input reset_total bool
  var_input setpoint dint
  var_output valve bool
  var_output total dint
  var_output rate dint

  xic reset_total move 0 total
  xic fill xio reset_total add total flow total
  xic fill lt total setpoint ote valve
  div total minutes rate
  """

  @m3_plant """
  // a bottling line: the conveyor every 10 ms, the filler every 100 ms
  task fast interval 10 priority 1
  task slow interval 100 priority 2

  var_global run_pb      bool at panel.i.0
  var_global manual      bool at panel.i.1
  var_global jog_pb      bool at panel.i.2
  var_global bottle_eye  bool at panel.i.3
  var_global case_gone   bool at panel.i.4
  var_global infeed_eye  bool at panel.i.5
  var_global outfeed_eye bool at panel.i.6
  var_global jam         bool at panel.i.7
  var_global fill        bool at panel.i.8
  var_global reset_total bool at panel.i.9
  var_global flow        dint at meter.i.0
  var_global minutes     dint at meter.i.1
  var_global motor       bool at panel.q.0
  var_global fan         bool at panel.q.1
  var_global horn        bool at panel.q.2
  var_global case_full   bool at panel.q.3
  var_global jog_lamp    bool at panel.q.4
  var_global valve       bool at panel.q.5
  var_global cases       dint at hmi.q.0
  var_global buffered    dint at hmi.q.1
  var_global total       dint at hmi.q.2
  var_global rate        dint at hmi.q.3

  program line conveyor with fast
    line.run_pb      run_pb
    line.manual      manual
    line.jog_pb      jog_pb
    line.bottle_eye  bottle_eye
    line.case_gone   case_gone
    line.infeed_eye  infeed_eye
    line.outfeed_eye outfeed_eye
    line.jam         jam
    line.motor       motor
    line.fan         fan
    line.horn        horn
    line.case_full   case_full
    line.jog_lamp    jog_lamp
    line.cases       cases
    line.buffered    buffered

  program filler filler with slow
    filler.fill        fill
    filler.flow        flow
    filler.minutes     minutes
    filler.reset_total reset_total
    filler.setpoint    500
    filler.valve       valve
    filler.total       total
    filler.rate        rate
  """

  # The line's inputs, cycle by cycle, 10 ms apart after a first cycle at 0, seeded: run on,
  # bottles passing the eye, a case leaving now and then, the buffer's eyes, a jam now and
  # then, the filler filling with a flow, its minutes 0 for the first 3 s. A manual spell
  # from cycle 200 to 260 jogs the motor and leaves the jog held as the line returns to
  # auto; and before the edit at cycle 600 the motor stops at 585, until 650, and a bottle
  # sits on the eye from 597 to 605, so the switch comes with the fan in its run-on and a
  # bottle on the eye.
  defp m3_trace(n) do
    :rand.seed(:exsss, {2026, 10, 19})

    start = %{
      "run_pb" => 1,
      "manual" => 0,
      "jog_pb" => 0,
      "bottle_eye" => 0,
      "case_gone" => 0,
      "infeed_eye" => 0,
      "outfeed_eye" => 0,
      "jam" => 0,
      "fill" => 1,
      "reset_total" => 0,
      "flow" => 10,
      "minutes" => 0
    }

    {cycles, _} =
      Enum.map_reduce(0..(n - 1), start, fn i, image ->
        image = m3_forced(i, m3_drawn(i, image))
        {{if(i == 0, do: 0, else: 10), image}, image}
      end)

    cycles
  end

  defp m3_drawn(0, image), do: image

  defp m3_drawn(i, image) do
    flip = fn image, name, odds ->
      if :rand.uniform(odds) == 1, do: Map.update!(image, name, &(1 - &1)), else: image
    end

    image
    |> flip.("run_pb", 120)
    |> flip.("jog_pb", 8)
    |> flip.("bottle_eye", 3)
    |> Map.put("case_gone", if(:rand.uniform(70) == 1, do: 1, else: 0))
    |> flip.("infeed_eye", 4)
    |> flip.("outfeed_eye", 5)
    |> flip.("jam", 90)
    |> flip.("fill", 40)
    |> Map.put("reset_total", if(:rand.uniform(150) == 1, do: 1, else: 0))
    |> Map.update!("flow", &if(:rand.uniform(5) == 1, do: :rand.uniform(31) - 1, else: &1))
    |> Map.put("minutes", max(div(i, 100) - 2, 0))
  end

  defp m3_forced(i, image) when i in 200..254, do: %{image | "manual" => 1}
  defp m3_forced(i, image) when i in 255..259, do: %{image | "manual" => 1, "jog_pb" => 1}
  defp m3_forced(i, image) when i in 260..265, do: %{image | "manual" => 0, "jog_pb" => 1}

  defp m3_forced(i, image) when i in 597..605,
    do: %{image | "run_pb" => 0, "bottle_eye" => 1, "case_gone" => 0}

  defp m3_forced(i, image) when i in 585..649, do: %{image | "run_pb" => 0}
  defp m3_forced(650, image), do: %{image | "run_pb" => 1}
  defp m3_forced(_i, image), do: %{image | "manual" => 0}

  # The oracle, in plain Elixir from the line's description: it knows nothing of logex.
  # The conveyor's scan, every cycle: in manual the jog button jogs the motor and lights
  # the jog lamp, and in auto that section is left as it was; the motor runs on `run_pb`
  # in auto; a bottle is a rising edge of the eye, never at start-up, and the count clears
  # as a case leaves, the case full at the case size; each case filled steps the case
  # count once; the buffer counts its infeed's and outfeed's rising edges; the fan runs on
  # for the run-on time after the motor stops (IEC's TOF); the horn sounds for 200 ms from a
  # jam's rising edge, whatever the jam does meanwhile (IEC's TP).
  defp m3_model,
    do: %{
      first: true,
      filler_first: true,
      jog: 0,
      jog_lamp: 0,
      bottles: 0,
      eye: 0,
      case_size: 12,
      case_full: 0,
      was_full: 0,
      cases: 0,
      buffer: 0,
      infeed: 0,
      outfeed: 0,
      motor: 0,
      fan: %{was: 0, timing: false, et: 0, pt: 300},
      horn: %{was: 0, pulsing: false, et: 0, pt: 200},
      total: 0,
      valve: 0,
      rate: 0
    }

  defp m3_line(m, i) do
    edge = fn now, last -> not m.first and now == 1 and last == 0 end

    {jog, jog_lamp} =
      if i["manual"] == 1, do: {i["jog_pb"], i["jog_pb"]}, else: {m.jog, m.jog_lamp}

    motor =
      if (i["run_pb"] == 1 and i["manual"] == 0) or (i["manual"] == 1 and jog == 1),
        do: 1,
        else: 0

    bottles =
      cond do
        i["case_gone"] == 1 -> 0
        edge.(i["bottle_eye"], m.eye) -> m.bottles + 1
        true -> m.bottles
      end

    full = if bottles >= m.case_size, do: 1, else: 0
    stepped = if not m.first and full == 1 and m.was_full == 0, do: 1, else: 0

    buffer =
      m.buffer + if(edge.(i["infeed_eye"], m.infeed), do: 1, else: 0) -
        if(edge.(i["outfeed_eye"], m.outfeed), do: 1, else: 0)

    %{
      m
      | first: false,
        jog: jog,
        jog_lamp: jog_lamp,
        motor: motor,
        bottles: bottles,
        eye: i["bottle_eye"],
        case_full: full,
        was_full: full,
        cases: m.cases + stepped,
        buffer: buffer,
        infeed: i["infeed_eye"],
        outfeed: i["outfeed_eye"],
        fan: m3_run_on(m.fan, motor),
        horn: m3_pulse(m.horn, i["jam"], m.first)
    }
  end

  # IEC's TOF, scanned every 10 ms: on while the motor runs, timing from its stop, off once
  # the run-on time has passed.
  defp m3_run_on(fan, 1), do: %{fan | was: 1, timing: false, et: 0}
  defp m3_run_on(%{was: 1} = fan, 0), do: %{fan | was: 0, timing: fan.pt > 0, et: 0}
  defp m3_run_on(%{timing: true} = fan, 0), do: m3_timed(%{fan | et: min(fan.et + 10, fan.pt)})
  defp m3_run_on(fan, 0), do: fan

  defp m3_timed(%{et: et, pt: pt} = fan) when et >= pt, do: %{fan | timing: false}
  defp m3_timed(fan), do: fan

  defp m3_fan(%{was: 1}), do: 1
  defp m3_fan(%{timing: true}), do: 1
  defp m3_fan(_fan), do: 0

  # IEC's TP: a pulse from the jam's rising edge, never at start-up, for its preset.
  defp m3_pulse(%{pulsing: true} = horn, jam, _first) do
    et = horn.et + 10
    %{horn | was: jam, et: et, pulsing: et < horn.pt}
  end

  defp m3_pulse(%{was: 0} = horn, 1, false), do: %{horn | was: 1, et: 0, pulsing: horn.pt > 0}
  defp m3_pulse(horn, jam, _first), do: %{horn | was: jam}

  # The filler's scan, every 100 ms: the total adds the flow while filling, clears on a
  # reset, the valve open while filling below the setpoint of 500, and the rate the total
  # by the minutes, none while the minutes are 0, a minor fault the plant runs on through.
  defp m3_filler(m, i) do
    total =
      cond do
        i["reset_total"] == 1 -> 0
        i["fill"] == 1 -> m.total + i["flow"]
        true -> m.total
      end

    rate = if i["minutes"] == 0, do: 0, else: div(total, i["minutes"])
    valve = if i["fill"] == 1 and total < 500, do: 1, else: 0
    {%{m | filler_first: false, total: total, valve: valve, rate: rate}, i["minutes"] == 0}
  end

  defp m3_outputs(m),
    do: %{
      "motor" => m.motor,
      "fan" => m3_fan(m.fan),
      "horn" => if(m.horn.pulsing, do: 1, else: 0),
      "case_full" => m.case_full,
      "jog_lamp" => m.jog_lamp,
      "valve" => m.valve,
      "cases" => m.cases,
      "buffered" => m.buffer,
      "total" => m.total,
      "rate" => m.rate
    }

  # One cycle of the model at `now`: the conveyor, then the filler where it is due, and
  # the events the plant reports.
  defp m3_cycle(m, now, image, filler_file) do
    m = m3_line(m, image)
    ran = [{:ran, "fast", "line", now}]

    {m, events} =
      if rem(now, 100) == 0 do
        {m, fault?} = m3_filler(m, image)

        faults =
          if fault?,
            do: [
              {:fault, "slow", "filler",
               %Logex.Fault{
                 severity: :minor,
                 kind: :divide_by_zero,
                 instruction: :div,
                 path: nil,
                 file: filler_file,
                 line: 13
               }}
            ],
            else: []

        {m, ran ++ [{:ran, "slow", "filler", now} | faults]}
      else
        {m, ran}
      end

    {m, m3_outputs(m), events}
  end

  # Runs the trace through the resource, cycle by cycle, against the model, and takes the
  # edit after cycle `at`: what each cycle gave, with the model's state, for the checks.
  defp m3_run(config, candidate, trace, at, filler_file) do
    start = {Logex.Runtime.start(config), m3_model(), 0}

    {cycles, _} =
      trace
      |> Enum.with_index()
      |> Enum.map_reduce(start, fn {{elapsed, image}, i}, {runtime, model, now} ->
        now = now + elapsed
        {runtime, outputs, events} = Logex.Runtime.cycle(runtime, elapsed, image)
        {model, expected, expected_events} = m3_cycle(model, now, image, filler_file)
        assert outputs == expected, "cycle #{i}"
        assert events == expected_events, "cycle #{i}"
        assert Logex.Runtime.get!(runtime, "line.bottles.cv") == model.bottles, "cycle #{i}"
        {runtime, model} = m3_edit(i == at, runtime, model, candidate)
        {{image, outputs, events, model}, {runtime, model, now}}
      end)

    cycles
  end

  defp m3_edit(false, runtime, model, _candidate), do: {runtime, model}

  # The edit, between two cycles: the case size from 12 to 24 and the run-on from 300 ms to
  # 500 ms, through Logex.Configuration.Edit, tested and assembled. Each preset moves where
  # logic left it (decisions 23 and 27); the count, the bottle on the eye and the fan's
  # run-on are kept as they were: no count lost, no phantom count, no timer reset.
  defp m3_edit(true, runtime, model, candidate) do
    run_on = Logex.Runtime.get!(runtime, "line.run_on.acc")
    assert model.fan.timing and run_on > 0 and model.eye == 1

    {:ok, edit, forecast} = Logex.Configuration.Edit.accept(runtime, candidate)
    {edit, tested, report} = Logex.Configuration.Edit.test(edit, runtime)
    assert report == forecast

    full =
      if model.bottles in 12..23, do: [{:dn_drops, "line.bottles", {model.bottles, 24}}], else: []

    assert report ==
             Enum.sort(
               [{:preset, "line.bottles", {12, 24}}, {:preset, "line.run_on", {300, 500}}] ++ full
             )

    {_config, runtime, _report} = Logex.Configuration.Edit.assemble(edit, tested)

    assert Enum.map(
             ~w(line.bottles.cv line.bottles.pv line.run_on.acc line.run_on.pre),
             &Logex.Runtime.get!(runtime, &1)
           ) ==
             [model.bottles, 24, run_on, 500]

    {runtime, %{model | case_size: 24, fan: %{model.fan | pt: 500}}}
  end

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
    # four at once, so the bound is now a fifth above that, 5.40, up from 5.24.
    test "compiling stays linear in the program's size, in a heap no collection moves" do
      ratio = reductions_to_compile(2000, :large) / reductions_to_compile(500, :large)
      assert ratio < 5.40, "4x the tags took #{Float.round(ratio, 1)}x the reductions"
    end

    # The large heap hides what a compile copies. A Logex.Walk.instructions/1 that appends
    # each rung's instructions with `++`, quadratic in what it copies and 12x to 15x the
    # time at 4x the tags, grew 5.27x to 6.42x there, where `++` is charged few reductions
    # and no collection copies what it built, and passed the large heap's bound, then
    # 5.24, in three of five runs of the suite at M3-4's review; in the VM's own heap,
    # where each collection copies it again, it grows 12.4x to 12.9x. So each size
    # compiles again in a process of its own with the VM's heap (in_a_process/2,
    # `:default`): over 32 runs of the suite, 16 alone and 16 four at once, it grew
    # 4.40x to 4.67x alone and 4.87x to 6.19x four at once. The bound is a fifth above
    # that highest.
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
               "#{broken}: line 14: `m1` runs `motor`, which declares no `strat` — did you mean " <>
                 "`start`?",
               "#{broken}: line 15: program type `bad` does not compile: its mistakes follow, " <>
                 "cited in `bad.ld`",
               "#{bad}: line 3: unknown instruction `xyz`"
             ]
    end

    # PLAN.md's Milestone 3 done sentence, walked clause by clause, from files on disk
    # through Logex.Configuration.compile_file/1, as the tests above walk Milestones 1 and 2.
    test "Milestone 3's done sentence, as written in PLAN.md", %{tmp_dir: dir} do
      # A small bottling line written in `.ld` files ...
      write(dir, "conveyor.ld", @m3_conveyor)
      filler = write(dir, "filler.ld", @m3_filler)
      plant = write(dir, "plant.logex", @m3_plant)

      # ... runs under a `.logex` configuration ...
      assert {:ok, config} = Logex.Configuration.compile_file(plant)
      assert config.warnings == []
      assert Enum.all?(Map.values(config.programs), &(&1.warnings == []))

      # The line holds an instruction of each item of the milestone: counters, the other
      # timers, arithmetic, a pulse coil and a jump.
      held =
        for {_, program} <- config.programs,
            {symbol, _, _} <- Logex.Walk.instructions(program.rungs),
            into: MapSet.new(),
            do: symbol

      assert MapSet.subset?(MapSet.new(~w(ctu ctd tof tp add div osr jmp lbl)a), held)

      # The candidate it is edited to while it runs: the case size 24, the run-on 500 ms.
      File.mkdir_p!(Path.join(dir, "v2"))

      write(
        dir,
        "v2/conveyor.ld",
        @m3_conveyor
        |> String.replace("ctu bottles 12", "ctu bottles 24")
        |> String.replace("tof run_on 300", "tof run_on 500")
      )

      write(dir, "v2/filler.ld", @m3_filler)

      assert {:ok, candidate} =
               Logex.Configuration.compile_file(write(dir, "v2/plant.logex", @m3_plant))

      # ... through Logex.Runtime.cycle/3, against an oracle that knows nothing of logex,
      # every cycle's outputs, events and bottle count exact, the edit taken after cycle 600
      # (m3_run/5, m3_edit/4) ...
      cycles = m3_run(config, candidate, m3_trace(1200), 600, filler)
      models = for {_, _, _, model} <- cycles, do: model
      outputs = for {_, outputs, _, _} <- cycles, do: outputs

      # ... a conveyor whose `ctu` counts bottles into cases, reset through its `r` when a
      # case leaves ...
      resets =
        for {{image, _, _, _}, {_, _, _, was}} <- Enum.zip(tl(cycles), cycles),
            image["case_gone"] == 1 and was.bottles > 0,
            do: was

      assert length(resets) > 10 and List.last(models).cases >= 5
      assert Enum.any?(outputs, &(&1["case_full"] == 1))

      # ... a buffer whose `ctud` counts bottles in and out ...
      buffered = Enum.map(outputs, & &1["buffered"])
      assert Enum.max(buffered) > 3 and Enum.min(buffered) < -3

      # ... a fan run on by a `tof` after the motor stops ...
      run_ons = for o <- outputs, o["fan"] == 1 and o["motor"] == 0, do: o
      assert length(run_ons) > 60

      # ... a horn pulsed by a `tp` on a jam ...
      assert Enum.count(outputs, &(&1["horn"] == 1)) > 40

      # ... a fill valve whose `add`ed total closes it at a setpoint, a zero divisor in its
      # rate reported as a minor fault while the line runs on ...
      closed =
        for {image, out, _, _} <- cycles,
            image["fill"] == 1 and out["total"] >= 500,
            do: out["valve"]

      assert closed != [] and Enum.all?(closed, &(&1 == 0))

      faults = for {_, _, events, _} <- cycles, {:fault, _, _, _} = e <- events, do: e
      assert length(faults) == 30 and Enum.any?(outputs, &(&1["rate"] > 0))

      # ... an `osr` that steps a case counter: once a case, as the case fills ...
      steps = Enum.chunk_every(Enum.map(outputs, & &1["cases"]), 2, 1, :discard)
      assert Enum.all?(steps, fn [a, b] -> (b - a) in [0, 1] end)

      # ... and a manual-mode section skipped by `jmp`: the jog lamp left lit by the last
      # manual scan, though the jog button is released in auto.
      held_lamp =
        for {image, out, _, _} <- Enum.drop(cycles, 260),
            image["manual"] == 0 and image["jog_pb"] == 0,
            do: out["jog_lamp"]

      assert Enum.any?(Enum.slice(outputs, 200..254), &(&1["motor"] == 1))
      assert held_lamp != [] and Enum.all?(held_lamp, &(&1 == 1))

      # While it runs it is edited through Logex.Configuration.Edit to change the case size
      # and the run-on time, with no count lost, no phantom count and no timer reset
      # (m3_edit/4): the run-on in progress at the switch, from the motor's stop at cycle
      # 585, lasts 500 ms, not 300, and the bottle on the eye at the switch is counted once.
      fan = for i <- [584, 614, 615, 625, 634, 635], do: Enum.at(outputs, i)["fan"]
      assert fan == [1, 1, 1, 1, 1, 0]
      assert for(i <- 597..605, do: Enum.at(models, i).bottles) |> Enum.uniq() |> length() == 1

      # And a run again from the same files gives the same cycles.
      assert m3_run(config, candidate, m3_trace(1200), 600, filler) == cycles
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
