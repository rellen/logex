defmodule Logex.ApiContractTest do
  @moduledoc """
  M1-5's contract, over seeded random programs and random host calls. A mistake in the
  source is a returned diagnostic; a mistake by the host is an `ArgumentError` whose
  message is one of the documented kinds; a call without one is accepted; and nothing else
  ever escapes. The seed is fixed, so a failure reproduces.

  A property pins only what its generator reaches, so each test asserts its reach: every
  stage's diagnostics, and every kind of refusal a host can cause.

  M1-6: the programs hold timers, one-shots, members and comparisons. Every accepted scan
  is checked against an oracle for `ton` and `ons`, and every accepted call is made twice
  and must give the same result, since the runtime is a pure function of its arguments.
  A timer's invariants hold right after its `ton` runs, and a member written below the
  `ton` takes effect at the next scan, so the generated `ton` comes last: at the end of the
  scan the oracle sees the timer as its `ton` left it. The reach assertions cover every
  M1-6 diagnostic and warning, and what a timer and a one-shot do.

  OE-1: a third walk takes online edits (`Logex.Edit`) between its scans, the candidates
  drawn from one vocabulary so that two programs share their names, and now and then
  swaps a program without an edit (a plain swap), so a state holds what does not fit.
  Every host mistake it makes is refused with a documented message, and every step it may
  take is accepted, made twice and gives the same result. The writes each report lists,
  applied to the state before the step, give the state after it, and each kind of entry is
  checked against the rule restated from the two programs' text. Each held output is
  checked independently of the edit too: one the program that runs next does not show
  against the host's own image of its outputs, the latest value each scan gave it, and
  one it still shows against what its next scan gives, unless a restart comes first. Its
  reach covers every report kind, every refusal and every oracle.

  Its timers (decision 23, fixes F1 and F6): each switch's `.pre`, `.dn` forecasts and
  resumes are checked against the rules restated from the text, with the walk's own
  record of what the edit's last switch left and found. Three oracles do not restate
  those rules: no scan but a plain swap's lets a timer gain more than the scan's own time,
  as one caught up after a switch would (§4.9's Resume rule); the scan right after a
  switch does to `.dn` what the switch forecast; and a test then an untest with no scan
  between leaves the original's tags as they were, a timer the test resumed included, but
  for what either switch started, found from the two programs' text and the state and
  never from the reports, and its next scan's outputs with them (fixes F1 and F11). Right
  after a switch that resumed a timer, the walk often switches back at once, and now and
  then restarts first, which starts the timer again, so that the switch back must give
  no resume back.

  Its one-shots (decision 21, fixes F2, F3 and F7): each switch's block list is checked
  against the rule restated from the text, with the walk's own record of which side of
  the edit last scanned and what an earlier edit left pending. Two oracles do not restate
  it (F11): a one-shot pulses only if the previous scan ran the same `ons` rung text with
  its condition 0, which the rung writes to a tag of its own, wherever the program scanned
  writes the bit through its `ons` alone; and the round trip leaves the block list as it
  found it too, but before a first scan, which blocks every `ons`. Now and then a host
  finalises an edit at one boundary and takes another before any scan, so a block is
  still pending.

  M2-1: a fourth walk runs configurations as resources, through `start/1`, `cycle/3`,
  `get/2`, `next_due_in/1`, `overlaps/1` and `restart/2`. Every accepted cycle is checked
  against a model that restates the scheduler's rules and scans each instance through
  `call/4` alone, and against an oracle that knows nothing of how due tasks are found:
  every period of a task up to now is either run or counted as missed. Every host mistake
  is refused with a documented message, a configuration started with one mistake is
  refused whether the mistake is the host's or one a text could make, and every accepted
  call is made twice and gives the same result. Its reach covers every refusal and what
  the scheduler must be seen to do.

  M2-6: the same walk draws event tasks, a task with a single alone or with an interval
  too, beside periodic ones, its trigger an input point, an output point read back or an
  unlocated global a connection drives. Its model restates decision 39 in phase points
  from each task's anchor, and its oracle counts the skipped ones: every period of a task
  with an interval up to now is run, counted as missed, or skipped under a high trigger.
  Oracles that know only each trigger's samples, read from outside before each cycle,
  check that a task with a single alone runs exactly on the rising edges of its trigger,
  one with an interval too on every edge, never while its trigger stays 1 and at most once
  a cycle, and that tasks run in priority order. A configuration started with a single
  that is no name, or that names no bool global, or with an event task's interval of 0, is
  refused, and the reach covers each kind of edge, skip and late cycle (decisions 50 to 52).

  M2-5: a fifth walk takes online edits of programs that hold user function blocks, a
  block inside a block among them, drawn from versions that change a block's body, add
  and drop its members and timers, and change a member's kind, which accept refuses. Its
  oracles: the writes each report lists, applied by path, rebuild the state; a switch
  leaves every member of the program it starts present at every depth, and a prune none
  but the kept program's; a test then an untest with no scan between gives back every
  value neither switch started, a timer's `last` included, found from the reports' starts
  alone; and on any scan that runs a one-shot one or two levels down, whose chain of rungs,
  from the program's `cal` to the body's `ons` rung, differs in its text from the one it
  last ran under, the one-shot passes no power: on the scan right after a switch, or on a
  later one, where its instance's `cal` was false until then (decision 32).

  OE-2: a sixth walk takes staged edits of a running configuration
  (`Logex.Configuration.Edit`) between its cycles, over configurations of periodic tasks,
  an event task with and without an interval, two program types that share a global
  through `var_external` and hold a block two deep, and up to six instances, some on a slow
  task that skips cycles. Each candidate is the running configuration's draws with one to
  three changes allowed while running (a type's version, its timer taken out or given
  back, the blocks, an instance added, removed or retyped, an interval, a priority, the
  order of instances or tasks, a global added, removed or given another initial value, the
  wiring) and, one time in three, one refused, read back through a configuration file's
  text so that each element has its line; now and then one is accepted while an edit is
  open, from the configuration the resource runs, and supersedes it. Accept refuses exactly the diagnostics restated
  from the two configurations, in order; every host mistake is refused with a documented
  message, a candidate `check/1` refuses with `start/1`'s; and every accepted call is made
  twice and gives the same result. Its properties: the forecast is the report a test taken
  at once gives; the writes each report lists, applied to the resource before the step,
  give it after, globals, states, the instances set aside and next due times, each kept
  instance's `switched`, block list and `now` as their rules say; no step moves the clock,
  an overlap count or a trigger's sample; no state holds a var_external (decision 49); a
  step on an edit that has ended, been stepped past or been superseded is refused by the
  generation; at an edit's first test what a superseded edit left is dropped and reported
  (decision 66), and each instance a switch starts, and at a first test each instance and
  global the original lacks, is as a fresh start of the configuration started gives it;
  and a
  test then an untest with no cycle between leaves the resource as the test found it,
  every state, each set aside, the globals and the tasks, but for what either switch
  started, a tag the test joined to its global (decision 55), a timer the untest resumed
  in an instance it brought back from aside (decision 57), or gave back a resume of an
  earlier switch's after the clock moved (decision 56's known limit), and what a switch's
  own rules set: each instance's `now` the resource's (decision 56), a kept one's
  `switched` (OE-1), one set aside that the test brought back as decision 57 left it, and
  a changed interval's next due time (decision 40). Its oracles know nothing of the edit: after every step, a model of the
  scheduler seeded from the resource, M2-1's with M2-4's var_externals, runs each instance
  through `call/4` alone and must give every cycle's outputs, events, globals and states;
  no scan lets a timer gain more than the time since its own state's last scan; and a
  one-shot passes power only where its state's last scan ran the same `ons` rung with its
  condition 0. Its reach covers every refusal, every report kind and each property.

  M3-1: a seventh walk runs IEC's counters, an up counter with its reset above or below
  its rung, a down counter with its load, an up-down counter run from two rungs with its
  preset now and then moved to the top, and an up counter inside a block a `cal` runs,
  in three versions of its body, over random inputs, scans, restarts and online edits that
  change a preset, a rung, a block's body or a counter's presence, and now and then a
  counter's kind, which accept refuses. Its oracle restates IEC's bodies from the
  programs' text, rung by rung over the input image, and knows nothing of the block list:
  every scan is exact for each counter side that has run under its own rung's text with no
  switch since, or since its instance started; a side a switch came before counts no edge
  unless it last ran under the same rung text, and then may or may not; a switch keeps
  every counter both programs declare as it was but for `pv`, which at a first test moves
  to the new preset where logic left the old (decisions 23 and 27); the writes each report
  lists rebuild the state; each forecast holds at the counter's next run; a test then an
  untest with no scan between gives every counter back; and a restart starts each at its
  preset. Every accepted call is made twice and gives the same result.

  M3-2: an eighth walk runs the other timers, an off-delay `tof`, a pulse `tp`, a retentive
  `rto` with its reset above or below its rung, and a pulse inside a block a `cal` runs,
  in three versions of its body, over random inputs and scan intervals, restarts and online
  edits that change a preset, a rung, a reset's place, a block's body or a timer's presence,
  and now and then the `tof`'s kind, which accept refuses. Since M5-6 each of the three
  is a long timer half the time, `tof_ltime`, `tp_ltime` or `rto_ltime`, its preset the
  same number of ms in ns and each millisecond adding 1,000,000 ns, restated, and an edit
  now and then changes the `tof`'s unit, which accept refuses too. Its oracle restates each rule
  from the programs' text, IEC's TOF and TP and the conventional RTO, rung by rung over the
  input image at the scan's time, and knows nothing of the block list: every scan is exact
  but where a pulse a switch came before last ran under the same rung text, which may or
  may not start; one whose text changed starts none; a switch keeps every timer both
  programs run as it was but for `.pre` and `last`, `.pre` moving at a first test to the
  new preset where logic left the old; the writes each report lists rebuild the state; each
  forecast holds at the run its type's rule decides it; a test then an untest with no scan
  between gives every timer back; and a restart starts each at its preset. Every accepted
  call is made twice and gives the same result.

  M3-4: a tenth walk runs the pulse coils, `osr` and `osf`, each on a chain of contacts,
  its storage bit declared 0 or 1, and one inside a block a `cal` runs, in three versions of
  its body, over random inputs, scans, restarts and online edits that change a coil's
  chain, its kind, its storage bit's initial value, what follows it, its presence, the
  order of its rung or the block's body. Its oracle restates IEC's transition-sensing
  coils from the programs' text, over the input image, and knows nothing of the block
  list: every scan is exact for each coil that has run under its own rung's text with no
  switch since, or since its instance started; a coil a switch came before pulses no edge
  unless it last ran under the same rung text, and then may or may not; every coil writes
  its storage bit with the power it receives and passes that power on; a coil a block's
  false `cal` freezes, or that the program no longer runs, leaves both its bits alone; a
  switch keeps every bit as it was; the writes each report lists rebuild the state; a test
  then an untest with no scan between gives every bit back; and a restart starts each at
  its declared value. Every accepted call is made twice and gives the same result.

  M3-5: the compile walk's words and mistakes gain `jmp` and `lbl`, and its reach every
  diagnostic and the warning they bring. An eleventh walk runs forward jumps over six
  rungs in a random order, an `ote`, a one-shot, an `ons`, an `osr` or an `osf`, the two
  sides of a ctud, a `ton` and a `cal` of a block whose body may jump over its own
  one-shot, with up to three jumps among them, each to the label of a later rung or of a
  last one, the one-shot, each side and the `cal` now and then on a leg of a group whose
  other leg passes no power, over random inputs, scan intervals, restarts and online edits
  that change a chain, add, remove or retarget a jump, swap two rungs, change the
  one-shot's kind, put a rung's memory in a group or take it out, or change the block's
  body. Its oracle restates the scan from the programs' text, rung by
  rung over the input image, and knows nothing of the block list: a skipped rung changes
  nothing it writes; a rung that runs does what its text says, the timer timing from the
  time the walk last saw it run, so no skipped scan stamps it; and a one-shot or counter a
  switch came before counts or pulses no edge unless it last ran under the same rung text,
  however many scans skipped it since (decision 106), and a restart with no scan since
  leaves every memory fresh, so an edge after it is real. A switch keeps every value, and
  a test then an untest with no scan between gives the state back. Every accepted call is
  made twice and gives the same result.

  M4-6: the runner walk, `Logex.Runner` on the manual clock over seeded configurations with
  and without untimed programs, devices that report and that do not, waits, presses,
  faults, edits, forces, restarts and a crash, against a model that calls `cycle/3` with
  what the runner gave the core and a model of the watchdogs and the trip, is
  `Logex.ApiContractTest.RunnerWalk`, below, a module of its own so that it runs beside
  this one.
  """
  use ExUnit.Case, async: true

  alias Logex.{Diagnostic, Edit, Instance, Program, Runtime, Scan, Tag}
  alias Logex.Configuration.Edit, as: ConfigEdit

  @words ~w(var var_input var_output var_external bool dint xic xio ote otl otu move a b c) ++
           ~w(start stop Motor) ++
           ~w(ton ons eq ne lt gt le ge t1 t1.dn t1.acc t1.pre t1.zz t1.et a.b s1 n d.3) ++
           ~w(jmp lbl jmp lbl done top) ++
           ["(", "|", ")", "0", "1", "7", "1200", "3000000000", "retain", "\n", "\n"]

  # Words that are lex errors: in a soup they end the compile at the lexer.
  @lex_errors ["@", "1bst"]

  # Declaration mistakes a soup of words almost never assembles.
  @declaration_mistakes [
    "var ( xic a ) bool",
    "var d ( xic a )",
    "var e bool ( xic a )",
    "var a bool",
    "var retain r bool",
    "var bool dint",
    "var f bool 7",
    "var g dint 3000000000",
    "var h bool 1 2",
    "var_input i bool 0",
    "var t2 ton 5",
    "var_output t3 ton",
    "var ton",
    "var t4.x bool"
  ]

  # Rung mistakes, one or more for each diagnostic in @m16_diagnostics, which a soup of
  # words rarely assembles: most need a declared timer, which a soup declares half the time.
  @rung_mistakes [
    "xic a ton t1 5 ton t1 6",
    "ote t1.dn",
    "xic t1.zz ote a",
    "xic a.b ote a",
    "xic d.3 ote a",
    "xic d.32 ote a",
    "move t1.acc.x n",
    "move t1 n",
    "xic a ton t1 n",
    "ton t1 3000000000",
    "ton a 5",
    "eq a n ote a",
    "gt n 18446744073709551616 ote a",
    "xic t9.dn ote a",
    "xic a ton t1 5 ote a",
    "xic a ons s1 ote b\nxio a ons s1",
    "xic panel.i.0 ote a",
    "xic a jmp nowhere",
    "lbl top xic a ote b\nxic b jmp top",
    "lbl here xic a jmp here",
    "xic a lbl inside",
    "xic a jmp done jmp done\nlbl done",
    "xic a jmp done\nlbl done\nlbl Done",
    "lbl done\nlbl done",
    "lbl bool"
  ]

  # M1-6's diagnostics, and since M2-2 a location in a rung, by a fragment of each, that
  # the compile test must reach.
  @m16_diagnostics [
    "is already run by the `ton`",
    "but logic may write only",
    "is not a member of",
    "only an instance of a function block has members",
    "which has bits 0 to",
    "goes too deep",
    "name one of its members",
    "takes its preset as a number",
    "takes a preset of 0 to",
    "`ton` runs a ton or ton_ltime, but",
    "`eq` reads a number or a bit string, but",
    "`gt` reads a number or a bit string: `18446744073709551616`",
    "`t9` is not declared",
    "follows `ton t1` on its path",
    "is already the storage bit of the `ons`",
    "not an initial value on its declaration",
    "an instance is the program's own",
    "needs a tag name before the type `ton`",
    "is a location, written only after `at`",
    "names no label",
    "jumps back, to the rung on line",
    "jumps to its own rung",
    "is not first on its rung",
    "already labels",
    "differ only in case: labels are",
    "is a second `jmp` in this rung",
    "takes a label"
  ]

  # And its warnings, which only a program that compiles gets.
  @m16_warnings [
    "compares two literals",
    "the storage bit of the `ons`",
    "no `ton` runs it",
    "but no `jmp` names it"
  ]

  @junk [
    0,
    1,
    2,
    -1,
    1.0,
    nil,
    true,
    :x,
    "s",
    [],
    %{},
    {1},
    <<255>>,
    2_147_483_648,
    %Scan{now: 0, first: true}
  ]

  # M5-3: IEC's eight integer widths, each its kind and N (Ed 3 Table 10), restated here
  # and never read from Logex.Declarations, with Figure 11's "i" cells among them.
  @widths %{
    sint: {:signed, 8},
    int: {:signed, 16},
    dint: {:signed, 32},
    lint: {:signed, 64},
    usint: {:unsigned, 8},
    uint: {:unsigned, 16},
    udint: {:unsigned, 32},
    ulint: {:unsigned, 64}
  }

  # The widths in the table's order, a list: a map's keys come in an order that may differ
  # from one run of the VM to the next, an atom key being ordered by its index in the atom
  # table, so a draw from `Map.keys(@widths)` repeats only where the atoms were made in one
  # order (M5-4).
  @width_types [:sint, :int, :dint, :lint, :usint, :uint, :udint, :ulint]

  @figure_11 %{
    sint: [:int, :dint, :lint],
    int: [:dint, :lint],
    dint: [:lint],
    lint: [],
    usint: [:uint, :udint, :ulint, :int, :dint, :lint],
    uint: [:udint, :ulint, :dint, :lint],
    udint: [:ulint, :lint],
    ulint: []
  }

  # M5-8: IEC's four bit strings, each its N (Ed 3 Table 10 features 18 to 21), in the
  # table's order, restated here: 0 to 2^N - 1, the unsigned integer IEC compares one as.
  @bit_types [:byte, :word, :dword, :lword]
  @bit_widths %{byte: 8, word: 16, dword: 32, lword: 64}

  # Each width's range from IEC's footnotes c and d.
  defp width_range(type), do: width_range_of(Map.fetch!(@widths, type))
  defp width_range_of({:signed, n}), do: -Integer.pow(2, n - 1)..(Integer.pow(2, n - 1) - 1)//1
  defp width_range_of({:unsigned, n}), do: 0..(Integer.pow(2, n) - 1)//1

  # A var_input's values either side of its type's edges: since M5-3 every width's limits
  # and one past each, its zero and a float.
  @edges Map.merge(
           %{bool: [0, 1, 0, 1, 2, 1.0, true]},
           Map.new(@widths, fn
             {type, {:signed, n}} ->
               {low, high} = {-Integer.pow(2, n - 1), Integer.pow(2, n - 1) - 1}
               {type, [0, low, high, low - 1, high + 1, 1.0, %{}]}

             {type, {:unsigned, n}} ->
               high = Integer.pow(2, n) - 1
               {type, [0, 1, high, -1, high + 1, 1.0, %{}]}
           end)
         )
         |> Map.merge(
           Map.new(@bit_widths, fn {type, n} ->
             high = Integer.pow(2, n) - 1
             {type, [0, 1, high, div(high, 3), -1, high + 1, 1.0, %{}]}
           end)
         )

  # The documented kinds of refusal, by their first words. A scan's block list, which only
  # the runtime fills in (OE-1), is a kind of its own, so the walk is seen to reach it.
  @refusals [
    "input ",
    "inputs must be",
    "scan.ons_blocked",
    "scan.",
    "state.",
    "time went backwards",
    "expected a %Logex.",
    "elapsed_ms must be",
    "restart takes",
    "this state is an instance"
  ]

  # What the M1-6 oracle must see a timer and a one-shot do, at least once each.
  @behaviours [:idle, :timing, :done, :clamped, :negative_preset, :fired, :held_first]

  setup do
    :rand.seed(:exsss, {2026, 9, 29})
    :ok
  end

  defp pick(list), do: Enum.at(list, :rand.uniform(length(list)) - 1)

  # A third of the time a well-formed program, so the success path and its warnings are
  # reached. Otherwise a soup of words after the declarations, one of them malformed: a soup
  # that lexes and parses reaches validation, and one with a lex-error word ends at the
  # lexer. The compile test asserts that every stage is reached.
  defp source, do: source(:rand.uniform(3))

  defp source(1) do
    inputs = Enum.filter(~w(start stop), fn _ -> :rand.uniform(2) == 1 end)
    bools = inputs ++ ~w(a b c)
    # Half the programs time and one-shot on `go`, a third of those also moving into the
    # timer's members; and a third carry one of the M1-6 warnings' cases. A timed program
    # has the dint input, which it moves into its timer's .pre.
    timed? = :rand.uniform(2) == 1
    dint_input = Enum.filter(["var_input sp dint"], fn _ -> timed? or :rand.uniform(2) == 1 end)
    members? = timed? and :rand.uniform(3) == 1
    warned = if :rand.uniform(3) == 1, do: [pick(warned())], else: []

    # M5-3: half the programs take an input of a random width, moved into a width Figure 11
    # widens it into and converted into another, wrapping where it does not fit.
    widths = Enum.take([width_draw()], min(:rand.uniform(3) - 1, 1))
    # M5-8: and a third take a value of a bit string or an integer type, its bits and a
    # bitwise instruction, a shift by an sint tag and one by a literal; since decision 206
    # of a bool too.
    bits = Enum.take([bits_draw()], min(:rand.uniform(3) - 1, 1) * (:rand.uniform(2) - 1))

    declarations =
      Enum.map(inputs, &"var_input #{&1} bool") ++
        Enum.flat_map(widths, &elem(&1, 0)) ++
        Enum.flat_map(bits, &elem(&1, 0)) ++
        dint_input ++
        Enum.map(~w(a b c), &"#{pick(~w(var var_output))} #{&1} bool") ++
        ["var_output n dint 7"] ++
        if(timed?,
          do: [
            "var_input go bool",
            "var t1 ton",
            "var s1 bool",
            "var_output p bool"
          ],
          else: []
        ) ++
        Enum.flat_map(warned, &elem(&1, 0))

    outputs =
      ["ote #{pick(~w(a b c))}", "otl #{pick(~w(a b c))}", "otu a", "move 5 n", "move 1 b"] ++
        ["( xic a | ) ote c", "eq n 7 ote b", "lt n #{pick([5, 7, 9])} ote c"] ++
        if(timed?, do: ["ge t1.acc #{pick([0, 5, 20])} ote c", "xic t1.dn ote b"], else: [])

    rungs =
      for _ <- 1..:rand.uniform(5) do
        contacts =
          Enum.map_join(1..:rand.uniform(3), " ", fn _ ->
            "#{pick(~w(xic xio))} #{pick(bools)}"
          end)

        "#{contacts} #{pick(outputs)}"
      end

    moves = Enum.map(dint_input, fn _ -> "xic a move sp n" end)

    # A dint input moved into .pre while `go` is off, so while the timer is reset, keeps the
    # exact oracle below true; it may be negative, which times as 0.
    member_moves =
      if(members?, do: ["xic a move #{pick([3, 50])} t1.pre", "xic b move 0 t1.acc"], else: []) ++
        if timed?, do: ["xio go move sp t1.pre"], else: []

    # The one-shot and the timer come last, so the oracle sees them as they left them: a
    # timer's invariants hold right after its `ton` runs. Nothing follows the `ton`.
    timing =
      if timed?,
        do: ["xic go ons s1 ote p", "xic go ton t1 #{pick([0, 10, 25, 5000])}"],
        else: []

    Enum.join(
      declarations ++
        rungs ++
        moves ++
        Enum.flat_map(widths, &elem(&1, 1)) ++
        Enum.flat_map(bits, &elem(&1, 1)) ++
        Enum.flat_map(warned, &elem(&1, 1)) ++ member_moves ++ timing,
      "\n"
    )
  end

  defp source(2), do: soup(@words)
  defp source(3), do: soup(@words ++ @lex_errors)

  defp width_draw, do: width_draw(pick(@width_types))

  defp width_draw(from) do
    wide = pick([from | Map.fetch!(@figure_11, from)])
    to = pick(@width_types -- [from])

    {[
       "var_input w #{from}",
       "var_output wide #{wide}",
       "var_output narrow #{to}",
       "var_output wok bool"
     ], ["move w wide", "#{from}_to_#{to} w narrow ote wok"]}
  end

  # M5-8: a value of a bit string or an integer type, its bits read by a contact and
  # cleared by a coil, a bitwise instruction with a literal mask, and a shift or rotate by
  # an sint tag and by a literal, each restated below in the oracle (bitwised/3). Since
  # decision 206 a bool's too, a one-bit pattern read and cleared whole, its literal shift
  # 0 or 1; and for a bool or a bit string the bit read inverted by `not` into the type, a
  # bool widening into a bit string.
  defp bits_draw,
    do: bits_draw(pick([:bool | @bit_types] ++ @width_types), pick(~w(shl shr rol ror)))

  defp bits_draw(type, shift) do
    n = bits_n(type)
    {low, high} = bits_range(type)
    {read, cleared} = bits_named(type, n)

    {[
       "var_input bw #{type}",
       "var_input bn sint",
       "var_output bm #{type}",
       "var_output bs #{type}",
       "var_output bl #{type}",
       "var_output bok bool",
       "var_output bb bool",
       "var_output bset #{type}"
     ] ++ inverted_declared(type),
     [
       "#{pick(~w(and or xor))} bw #{pick(Enum.uniq([0, 1, high, max(low, -1), div(high, 3)]))} bm",
       "#{shift} bw bn bs ote bok",
       "#{pick(~w(shl shr rol ror))} bw #{literal_count(n)} bl",
       "xic #{read} ote bb",
       "move bw bset",
       "xic bb otu #{cleared}"
     ] ++ inverted_rung(type)}
  end

  # A bool has no bits: it is read and cleared whole, its one bit bit 0.
  defp bits_named(:bool, _n), do: {"bw", "bset"}
  defp bits_named(_type, n), do: {"bw.#{:rand.uniform(n) - 1}", "bset.#{pick([0, n - 1])}"}

  defp literal_count(1), do: pick([0, 1])
  defp literal_count(n), do: :rand.uniform(n - 1)

  defp inverted_declared(type) when type in [:bool | @bit_types],
    do: ["var_output bv #{type}"]

  defp inverted_declared(_integer), do: []

  defp inverted_rung(type) when type in [:bool | @bit_types], do: ["not bb bv"]
  defp inverted_rung(_integer), do: []

  defp bits_n(:bool), do: 1
  defp bits_n(type) when is_map_key(@bit_widths, type), do: Map.fetch!(@bit_widths, type)
  defp bits_n(type), do: elem(Map.fetch!(@widths, type), 1)

  defp bits_kind(:bool), do: :unsigned
  defp bits_kind(type) when is_map_key(@bit_widths, type), do: :unsigned
  defp bits_kind(type), do: elem(Map.fetch!(@widths, type), 0)

  defp bits_range(type) do
    %{first: first, last: last} = width_range_of({bits_kind(type), bits_n(type)})
    {first, last}
  end

  # Programs that compile with an M1-6 warning: declarations, then rungs.
  defp warned,
    do: [
      {[], ["eq 1 #{pick([1, 2])} ote c"]},
      {["var s2 bool"], ["xic a ons s2 ote b", "xio a ote s2"]},
      {["var t2 ton"], ["xic t2.dn ote c"]},
      {[], ["lbl spare xic a ote c"]}
    ]

  defp soup(words) do
    lines =
      for _ <- 1..:rand.uniform(6) do
        Enum.map_join(1..:rand.uniform(7), " ", fn _ -> pick(words) end)
      end

    declarations =
      for name <- ~w(a b c start stop), :rand.uniform(3) > 1 do
        "#{pick(~w(var var_input var_output))} #{name} #{pick(~w(bool bool dint))}"
      end ++
        Enum.filter(["var t1 ton", "var s1 bool", "var n dint", "var d dint"], fn _ ->
          :rand.uniform(2) == 1
        end)

    mistakes = [pick(@declaration_mistakes)] ++ lines ++ [pick(@rung_mistakes)]
    Enum.join(declarations ++ mistakes, "\n")
  end

  # Its draws are sized from the rate of its rarest diagnostics, "goes too deep", "is
  # already run by the `ton`" and "is already the storage bit of the `ons`", each given for
  # about one source in 120 over the seeds {n, 77, 7}, n from 1 to 60. At 600 sources a
  # run, 4 of the 260 seeds {n, 77, 7}, n to 60, and {n, 1, 1} and {7, n, 2026}, n to 100,
  # missed one. At 2,000 each is expected more than 15 times a run, and the reach holds at
  # this seed and, in its place, at each of {n, 77, 7}, {n, 1, 1} and {7, n, 2026}, n from
  # 1 to 100, every fragment given for 7 sources a run or more.
  test "compile/2 never raises for any source, and its diagnostics are in line order" do
    results = for _ <- 1..2000, do: Logex.compile(source(), name: "p")

    reached =
      for result <- results, into: MapSet.new() do
        case result do
          {:ok, %Program{name: "p", warnings: warnings}} ->
            assert warnings == Enum.sort_by(warnings, & &1.line)
            :ok

          {:error, [%Diagnostic{stage: stage} | _] = diagnostics} ->
            assert Enum.all?(
                     diagnostics,
                     &match?(%Diagnostic{line: line} when is_integer(line) and line > 0, &1)
                   )

            assert diagnostics == Enum.sort_by(diagnostics, & &1.line)
            stage
        end
      end

    assert reached == MapSet.new([:ok, :lex, :parse, :validate])

    errors = for {:error, diagnostics} <- results, d <- diagnostics, do: d.message
    warnings = for {:ok, program} <- results, w <- program.warnings, do: w.message

    for {fragment, messages} <-
          Enum.map(@m16_diagnostics, &{&1, errors}) ++ Enum.map(@m16_warnings, &{&1, warnings}) do
      assert Enum.any?(messages, &String.contains?(&1, fragment)),
             "no source reached the message containing #{inspect(fragment)}"
    end
  end

  # Its draws are sized from the rate of its rarest behaviour, a clamped timer, seen in
  # about one program in nine over the seeds {n, 77, 7}, n from 1 to 60. At 40 programs a
  # run, 4 of the 260 seeds {n, 77, 7}, n to 60, and {n, 1, 1} and {7, n, 2026}, n to 100,
  # missed one atom: a clamped timer, a negative preset or the "scan.ons_blocked" refusal.
  # At 150 a clamped timer is expected more than 15 times a run, and the reach holds at
  # this seed and, in its place, at each of {n, 77, 7}, {n, 1, 1} and {7, n, 2026}, n from
  # 1 to 100, every atom reached by 5 programs a run or more.
  test "the runtime refuses every host mistake with a documented ArgumentError, accepts " <>
         "every call without one, and nothing else escapes" do
    programs =
      Stream.repeatedly(fn -> Logex.compile(source(), name: "p") end)
      |> Stream.flat_map(fn
        {:ok, program} -> [program]
        {:error, _} -> []
      end)
      |> Enum.take(150)

    assert length(programs) == 150
    assert Enum.any?(programs, &match?(%{tags: %{"sp" => %Tag{section: :var_input}}}, &1))
    assert Enum.any?(programs, &match?(%{tags: %{"t1" => %Tag{type: %Logex.FbType{}}}}, &1))
    assert Enum.any?(programs, &String.contains?(&1.source, "move 0 t1.acc"))

    for program <- programs do
      # Another program's instance, for the owner check.
      {:ok, other} = Logex.compile(program.source, name: "q")
      walk(program, Runtime.instance(other), Runtime.instance(program), steps(program))
    end

    # M5-3: and a program of each width, a call at each of its edges, so every width's two
    # limits are drawn whatever the seed, each judged by the contract's own words; since
    # M5-8 each bit string's and each width's bits and bitwise instructions so too.
    # Each of the twelve types a bits draw, the tagged shift's four kinds in turn.
    draws =
      Enum.map(@width_types, &width_draw/1) ++
        Enum.zip_with(
          [:bool | @bit_types] ++ @width_types,
          Stream.cycle(~w(shl shr rol ror)),
          &bits_draw/2
        )

    for {inputs, rungs} <- draws do
      from = draw_type(inputs)
      {:ok, program} = Logex.compile(Enum.join(inputs ++ rungs, "\n"), name: "p")
      state = Runtime.instance(program)

      for inputs <- edge_calls(inputs, from) do
        scan = %Scan{now: state.now, first: state.first}

        call = fn ->
          scanned(program, state, inputs, Runtime.call(program, state, inputs, scan))
        end

        assert attempt(call) == :refused == bad_inputs?(program, inputs)
      end

      {:ok, other} = Logex.compile(program.source, name: "q")
      walk(program, Runtime.instance(other), state, steps(program))
    end

    # "state." is left out: only an instance edited by hand, outside the contract, gets it.
    assert Process.get(:refused, MapSet.new()) == MapSet.new(@refusals -- ["state."])
    assert Process.get(:behaviours, MapSet.new()) == MapSet.new(@behaviours)

    # M5-3: every width's two limits accepted and scanned, and a conversion that wraps
    # and one that fits.
    limits = for type <- @width_types, limit <- [:low, :high, :inside], do: {type, limit}

    assert Process.get(:widths, MapSet.new()) ==
             MapSet.new(limits ++ [{:wrapped, true}, {:wrapped, false}])

    # M5-8: every bit string's two limits, each bitwise instruction, each shift or rotate
    # by a negative count, one past the width and one inside it, and a bit set and clear;
    # since decision 206 a bool's two values, and a bool's bit inverted into a bool and
    # into each bit string.
    bits =
      for(type <- @bit_types, limit <- [:low, :high, :inside], do: {type, limit}) ++
        [{:bool, :low}, {:bool, :high}] ++
        for(type <- [:bool | @bit_types], do: {:inverted, type}) ++
        for(op <- ~w(and or xor)a, do: {:bitwise, op}) ++
        for(op <- ~w(shl shr rol ror)a, count <- [:negative, :past, :inside], do: {op, count}) ++
        [{:bit, 0}, {:bit, 1}]

    assert Process.get(:bits, MapSet.new()) == MapSet.new(bits)
  end

  # A call at each of a draw's input's edges, and for a bits draw at each of its count's,
  # a negative one, one past every width and 0 among them.
  defp edge_calls(inputs, from) do
    own = for value <- @edges[from], do: %{draw_input(inputs) => value}
    own ++ count_calls(draw_input(inputs))
  end

  defp count_calls("bw"), do: for(value <- @edges[:sint], do: %{"bw" => 1, "bn" => value})
  defp count_calls(_w), do: []

  # The input and its type a draw's program reads: the width draw's `w` or the bits draw's
  # `bw`.
  defp draw_type(["var_input " <> declaration | _]),
    do: declaration |> String.split(" ") |> List.last() |> String.to_existing_atom()

  defp draw_input(["var_input " <> declaration | _]), do: hd(String.split(declaration, " "))

  # A timed program walks longer, so a timer is seen through its edges: a preset set while
  # it is reset and then timed, a gap long enough to clamp.
  defp steps(%Program{tags: %{"go" => _}}), do: 90
  defp steps(%Program{tags: %{"w" => _}}), do: 60
  defp steps(%Program{tags: %{"bw" => _}}), do: 60
  defp steps(_program), do: 30

  # Random operations on one instance. Each says whether it is a host mistake, and the
  # runtime must agree: refuse it if so, accept it if not.
  defp walk(_program, _other, _state, 0), do: :ok

  defp walk(program, other, state, n) do
    {mistake?, call} = operation(program, other, state)

    case attempt(call) do
      {:ok, %Instance{} = next} ->
        refute mistake?, "a host mistake was accepted"
        assert next.now >= state.now
        walk(program, other, next, n - 1)

      :refused ->
        assert mistake?, "a call without a host mistake was refused"
        walk(program, other, state, n - 1)
    end
  end

  defp operation(program, other, state), do: operation(:rand.uniform(7), program, other, state)

  defp operation(1, program, _other, state) do
    inputs = inputs(program)
    {bad_inputs?(program, inputs), fn -> Runtime.put_inputs(program, state, inputs) end}
  end

  defp operation(2, program, _other, state) do
    elapsed = pick([0, 0, 5, 10, 25, 5000, 10_000_000_000, -1, 1.5, nil])

    {not (is_integer(elapsed) and elapsed >= 0),
     fn -> scanned(program, state, %{}, Runtime.scan(program, state, elapsed)) end}
  end

  defp operation(3, program, _other, state) do
    inputs = inputs(program)

    scan = %Scan{
      now: state.now + pick([0, 3, 10, 4990, 10_000_000_000, -1]),
      first: pick([state.first, state.first, not state.first])
    }

    {bad_inputs?(program, inputs) or scan.now < state.now or scan.first != state.first,
     fn -> scanned(program, state, inputs, Runtime.call(program, state, inputs, scan)) end}
  end

  defp operation(4, program, _other, state) do
    mode = pick([:cold, :warm, :hot])
    {mode == :hot, fn -> Runtime.restart(program, state, mode) end}
  end

  defp operation(5, program, other, state) do
    args = [
      pick([program, :x, %{}]),
      pick([state, other, %{}, nil]),
      pick([%{}, [], nil]),
      pick([
        %Scan{now: state.now, first: state.first},
        %Scan{now: state.now, first: state.first, ons_blocked: ["s1"]},
        0,
        nil
      ])
    ]

    {args != [program, state, %{}, %Scan{now: state.now, first: state.first}],
     fn -> scanned(program, state, %{}, apply(Runtime, :call, args)) end}
  end

  # The other entry points, given a bad program, state or inputs map.
  defp operation(6, program, other, state) do
    p = pick([program, program, :x, nil])
    s = pick([state, state, other, nil, %{}])
    inputs = pick([%{}, %{}, [], nil])

    case :rand.uniform(4) do
      1 ->
        {p != program, fn -> kept(Runtime.instance(p), state) end}

      2 ->
        {[p, s, inputs] != [program, state, %{}], fn -> Runtime.put_inputs(p, s, inputs) end}

      3 ->
        {[p, s] != [program, state], fn -> scanned(program, state, %{}, Runtime.scan(p, s)) end}

      4 ->
        {[p, s] != [program, state], fn -> Runtime.restart(p, s, :cold) end}
    end
  end

  # M1-6: a timed program's `go` held or dropped, so its timer and one-shot run often.
  # Dropping `go` often sets a new preset for `xio go move sp t1.pre`, sometimes negative.
  defp operation(7, %Program{tags: %{"go" => _} = tags} = program, _other, state) do
    inputs = go(pick([1, 1, 0]), Map.has_key?(tags, "sp"))
    {false, fn -> Runtime.put_inputs(program, state, inputs) end}
  end

  defp operation(7, program, other, state), do: operation(1, program, other, state)

  defp go(0, true), do: %{"go" => 0, "sp" => pick([-5, -5, 40])}
  defp go(go, _sp?), do: %{"go" => go}

  # A new instance is checked and set aside: the walk goes on with its own.
  defp kept(%Instance{now: 0, first: true}, state), do: state

  # The contract's own words: only a declared var_input, a bool 0 or 1, a dint in 32 bits,
  # and since M5-3 each integer width in its own range.
  defp bad_inputs?(program, inputs), do: Enum.any?(inputs, &bad_input?(program.tags, &1))

  defp bad_input?(tags, {key, value}), do: not fits?(Map.get(tags, key), value)

  defp fits?(%Tag{section: :var_input, type: :bool}, value), do: value in [0, 1]

  defp fits?(%Tag{section: :var_input, type: type}, value) when is_map_key(@widths, type),
    do: is_integer(value) and value in width_range(type)

  defp fits?(%Tag{section: :var_input, type: type}, value) when is_map_key(@bit_widths, type),
    do: is_integer(value) and value in 0..(Integer.pow(2, @bit_widths[type]) - 1)

  defp fits?(_tag, _value), do: false

  defp scanned(program, {outputs, %Instance{} = state}) do
    var_outputs = for {name, %{section: :var_output}} <- program.tags, do: name
    assert Enum.sort(Map.keys(outputs)) == Enum.sort(var_outputs)
    assert Enum.all?(Map.values(outputs), &is_integer/1)
    state
  end

  # A scan whose state before it is known: the M1-6 oracle, M5-3's, then the checks above.
  defp scanned(program, before, inputs, {outputs, %Instance{} = later} = result) do
    timed(program, before, Map.merge(before.env, inputs), outputs, later)
    widened(program, Map.merge(before.env, inputs), outputs)
    bitwised(program, Map.merge(before.env, inputs), outputs)
    scanned(program, result)
  end

  # M5-3's oracle: `move w wide` writes the input as it is, every width it is moved into
  # holding it (Figure 11), and `<from>_to_<to> w narrow` its low N bits, two's complement
  # where signed, with power where it fits, restated as a remainder by 2^N taken back into
  # the range. Each width's two limits are seen accepted, and a conversion that wraps and
  # one that fits.
  defp widened(
         %Program{tags: %{"w" => %Tag{type: from}, "narrow" => %Tag{type: to}}},
         env,
         outputs
       ) do
    w = env["w"]
    assert outputs["wide"] == w
    assert outputs["narrow"] == wrapped_into(to, w)
    fits = w in width_range(to)
    assert outputs["wok"] == Map.fetch!(%{true => 1, false => 0}, fits)
    width_reached({:wrapped, not fits})
    first..last//1 = width_range(from)
    width_reached({from, limit_of(w, first, last)})
  end

  defp widened(_program, _env, _outputs), do: :ok

  # M5-8's oracle, restated with arithmetic and never Bitwise: a value's pattern in its
  # type's N bits, the bitwise function bit by bit, a shift or rotate by decision 165's
  # rules, and a bit read and cleared in two's complement where signed.
  defp bitwised(%Program{tags: %{"bw" => %Tag{type: type}}, source: source}, env, outputs) do
    w = env["bw"]
    n = bits_n(type)
    [_, op, mask] = Regex.run(~r/^(and|or|xor) bw (-?\d+) bm$/m, source)
    [_, tagged] = Regex.run(~r/^(shl|shr|rol|ror) bw bn bs ote bok$/m, source)
    [_, literal, count] = Regex.run(~r/^(shl|shr|rol|ror) bw (\d+) bl$/m, source)
    bit = bit_drawn(Regex.run(~r/^xic bw(?:\.(\d+))? ote bb$/m, source))
    cleared = bit_drawn(Regex.run(~r/^xic bb otu bset(?:\.(\d+))?$/m, source))

    assert outputs["bm"] == bitwise_of(op, type, w, String.to_integer(mask))
    {shifted, power} = shift_of(tagged, type, w, env["bn"])
    assert {outputs["bs"], outputs["bok"]} == {shifted, power}
    assert outputs["bl"] == elem(shift_of(literal, type, w, String.to_integer(count)), 0)
    b = bit_at(type, w, bit)
    assert outputs["bb"] == b
    assert outputs["bset"] == cleared_of(b, type, w, cleared)
    inverted_of(type, b, outputs)

    first..last//1 = width_range_of({bits_kind(type), n})
    bits_reached({:bitwise, String.to_atom(op)})
    bits_reached({String.to_atom(tagged), count_kind(env["bn"], n)})
    bits_reached({String.to_atom(literal), count_kind(String.to_integer(count), n)})
    bits_reached({:bit, b})
    bits_kind_reached(type, limit_of(w, first, last))
  end

  defp bitwised(_program, _env, _outputs), do: :ok

  defp bit_drawn([_, bit]), do: String.to_integer(bit)
  defp bit_drawn([_]), do: 0

  # `not bb bv`: the bool's pattern, bb widened into bv's type by Figure 11, every bit of
  # bv's width inverted, so 1 - bb in a bool and 2^N - 1 - bb in a bit string.
  defp inverted_of(type, b, %{"bv" => bv}) do
    assert bv == from_bits(Enum.map(bits_list(b, bits_n(type)), &(1 - &1)))
    bits_reached({:inverted, type})
  end

  defp inverted_of(_integer, _b, _outputs), do: :ok

  defp bits_kind_reached(type, limit) when is_map_key(@bit_widths, type) or type == :bool,
    do: bits_reached({type, limit})

  defp bits_kind_reached(_integer, _limit), do: :ok

  defp count_kind(count, _n) when count < 0, do: :negative
  defp count_kind(count, n) when count >= n, do: :past
  defp count_kind(_count, _n), do: :inside

  defp bits_reached(atom),
    do: Process.put(:bits, MapSet.put(Process.get(:bits, MapSet.new()), atom))

  defp pattern_of(type, value), do: Integer.mod(value, Integer.pow(2, bits_n(type)))

  defp valued_of(type, p) do
    half = Integer.pow(2, bits_n(type) - 1)
    signed_of(bits_kind(type), p, half)
  end

  defp signed_of(:signed, p, half) when p >= half, do: p - 2 * half
  defp signed_of(_kind, p, _half), do: p

  defp bits_list(p, n), do: for(i <- 0..(n - 1), do: rem(div(p, Integer.pow(2, i)), 2))

  defp from_bits(bits),
    do:
      bits |> Enum.with_index() |> Enum.map(fn {b, i} -> b * Integer.pow(2, i) end) |> Enum.sum()

  defp bitwise_of(op, type, a, b) do
    n = bits_n(type)
    pairs = Enum.zip(bits_list(pattern_of(type, a), n), bits_list(pattern_of(type, b), n))
    valued_of(type, from_bits(Enum.map(pairs, &one_bit(op, &1))))
  end

  defp one_bit("and", {a, b}), do: a * b
  defp one_bit("or", {a, b}), do: max(a, b)
  defp one_bit("xor", {a, b}), do: rem(a + b, 2)

  defp shift_of(_op, _type, a, count) when count < 0, do: {a, 0}

  defp shift_of(op, type, a, count) do
    n = bits_n(type)
    {valued_of(type, moved_of(op, pattern_of(type, a), count, n)), 1}
  end

  defp moved_of(op, _p, count, n) when op in ["shl", "shr"] and count >= n, do: 0
  defp moved_of("shl", p, count, n), do: Integer.mod(p * Integer.pow(2, count), Integer.pow(2, n))
  defp moved_of("shr", p, count, _n), do: div(p, Integer.pow(2, count))

  defp moved_of("rol", p, count, n) do
    r = Integer.mod(count, n)
    Integer.mod(p * Integer.pow(2, r) + div(p, Integer.pow(2, n - r)), Integer.pow(2, n))
  end

  defp moved_of("ror", p, count, n) do
    r = Integer.mod(count, n)
    div(p, Integer.pow(2, r)) + Integer.mod(p, Integer.pow(2, r)) * Integer.pow(2, n - r)
  end

  defp bit_at(type, value, i), do: rem(div(pattern_of(type, value), Integer.pow(2, i)), 2)

  # `bset` is the value with bit i cleared where `bb`, the drawn bit, is set.
  defp cleared_of(0, _type, value, _i), do: value

  defp cleared_of(1, type, value, i) do
    p = pattern_of(type, value)
    valued_of(type, p - bit_at(type, value, i) * Integer.pow(2, i))
  end

  defp limit_of(w, w, _last), do: :low
  defp limit_of(w, _first, w), do: :high
  defp limit_of(_w, _first, _last), do: :inside

  defp wrapped_into(type, value) do
    first..last//1 = width_range(type)
    span = last - first + 1
    first + Integer.mod(value - first, span)
  end

  defp width_reached(atom),
    do: Process.put(:widths, MapSet.put(Process.get(:widths, MapSet.new()), atom))

  defp timed(%Program{tags: %{"go" => _}} = program, before, env, outputs, later) do
    go = env["go"]

    # ons: power once a rise is seen, never on the first scan; the bit follows `go`.
    fires = go == 1 and before.env["s1"] == 0 and not before.first
    assert outputs["p"] == if(fires, do: 1, else: 0)
    assert later.env["s1"] == go
    behaviour(:fired, fires)
    behaviour(:held_first, before.first and go == 1)

    # ton, whose rung is last: the timer as its ton left it, `last` stamped on every run.
    t1 = later.env["t1"]
    assert Enum.sort(Map.keys(t1)) == ~w(acc dn en last pre tt)
    assert t1["en"] == go
    assert t1["last"] == later.now
    timer(go, program, before.env["t1"], t1)
  end

  defp timed(_program, _before, _env, _outputs, _later), do: :ok

  defp timer(1, program, was, t1) do
    limit = max(t1["pre"], 0)
    assert t1["acc"] in 0..limit//1
    assert t1["dn"] == if(t1["acc"] == limit, do: 1, else: 0)
    assert t1["tt"] == 1 - t1["dn"]
    behaviour(if(t1["dn"] == 1, do: :done, else: :timing), true)
    behaviour(:negative_preset, t1["pre"] < 0)
    exact(String.contains?(program.source, "move 0 t1.acc"), was, t1, limit)
  end

  defp timer(0, _program, _was, t1) do
    assert %{"acc" => 0, "dn" => 0, "tt" => 0} = t1
    behaviour(:idle, true)
  end

  # Where no rung writes a member, .acc is exactly the delta formula's: nothing on the scan
  # that first sees the rung true, then the time since the ton last ran, added to .acc
  # floored at 0, and capped.
  defp exact(true, _was, _t1, _limit), do: :ok

  defp exact(false, was, t1, limit) do
    delta = if was["en"] == 1, do: t1["last"] - was["last"], else: 0
    assert t1["acc"] == min(max(was["acc"], 0) + delta, limit)
    behaviour(:clamped, was["acc"] + delta > limit and delta > 1_000_000)
  end

  defp behaviour(_name, false), do: :ok

  defp behaviour(name, true),
    do: Process.put(:behaviours, MapSet.put(Process.get(:behaviours, MapSet.new()), name))

  defp inputs(program) do
    var_inputs = for {name, %Tag{section: :var_input}} <- program.tags, do: name
    names = Map.keys(program.tags) ++ ["zz", "Start", "t1.dn", <<255>>, :start, 7]
    Map.new(1..:rand.uniform(3), fn _ -> pair(:rand.uniform(2), var_inputs, names, program) end)
  end

  # Half the pairs set a var_input near its type's edges, so a good input map is common.
  defp pair(1, [_ | _] = var_inputs, _names, program) do
    name = pick(var_inputs)
    {name, pick(@edges[program.tags[name].type])}
  end

  defp pair(_, _var_inputs, names, _program),
    do: {pick(names), pick([0, 1, 1, 0, 2_147_483_647] ++ @junk)}

  # Records each documented kind of refusal it sees, for the reach assertion. An accepted
  # call is made twice and must give the same result: nothing in the runtime reads a clock
  # or any state but its arguments (docs/organisation.md §4.6).
  defp attempt(fun, refusals \\ @refusals, key \\ :refused) do
    result = fun.()
    assert fun.() == result, "the same call gave two results"
    {:ok, result}
  rescue
    error in ArgumentError ->
      kind = Enum.find(refusals, &String.starts_with?(error.message, &1))
      assert kind, "undocumented refusal: #{error.message}"
      reached(key, kind)
      :refused
  end

  defp reached(key, name),
    do: Process.put(key, MapSet.put(Process.get(key, MapSet.new()), name))

  # ---- OE-1: the walk with online edits -------------------------------------------------

  # The refusals an edit gives, and the runtime's that it passes on, by their first words.
  @edit_refusals [
    "expected a %Logex.",
    "the candidate is",
    "this state is an instance",
    "state.",
    "test takes",
    "untest takes",
    "assemble takes",
    "cancel takes"
  ]

  @report_kinds [
    :added,
    :dn_drops,
    :dn_rises,
    :held,
    :initial_changed,
    :input,
    :ons_blocked,
    :preset,
    :preset_kept,
    :pruned,
    :resume_undone,
    :resumed,
    :unread,
    # Decision 96: a member input no logic of the program started writes any more.
    :unwritten,
    # OE-2: a configuration's edit gives these too, and every kind above by path.
    :instance_added,
    :instance_back,
    :instance_pruned,
    :instance_stopped,
    :interval,
    :joined,
    :left,
    :next_due,
    :order,
    :priority,
    # Decision 129 (M4-2): a task's watchdog, which a switch writes nothing for.
    :watchdog
  ]

  # The kinds only a configuration's edit gives, which the walk of a lone instance's edit
  # cannot reach.
  @configuration_kinds [
    :instance_added,
    :instance_back,
    :instance_pruned,
    :instance_stopped,
    :interval,
    :joined,
    :left,
    :next_due,
    :order,
    :priority,
    :watchdog
  ]

  @timer_kinds [:dn_drops, :dn_rises, :preset, :preset_kept, :resume_undone, :resumed]

  # What the walk must see happen, and its oracles check, at least once each.
  @edit_reach [
    :diagnosed,
    :forecast,
    :plain_swap,
    :swap_outside,
    :misfit,
    :stale,
    :initial_started,
    :initial_input,
    :restart_in_edit,
    :second_test,
    :held_point,
    :held_shown,
    :held_shown_scan,
    :assembled,
    :cancelled_accepted,
    :cancelled_untested,
    :pre_followed,
    :pre_outright,
    :pre_frozen,
    :pre_restored,
    :undo_after_restart,
    :resumed_scan,
    :dn_scan,
    :round_trip,
    :round_trip_timer,
    :round_trip_resumed,
    :round_trip_started,
    :round_trip_ons,
    :ons_new,
    :ons_changed,
    :ons_written,
    :ons_untouched,
    :ons_same_side,
    :ons_pending,
    :ons_switch_edge,
    :ons_blocked_edge
  ]

  @allowed %{
    test: [:accepted, :untested],
    untest: [:testing],
    assemble: [:testing],
    cancel: [:accepted, :untested]
  }

  # One vocabulary, so two draws share their names: `start` and `stop` move between
  # var_input and var, `a`, `b` and `c` between var and var_output, `n`'s initial value
  # changes, and `r` and `t1` change type now and then, which a plain swap leaves in the
  # state and an edit refuses. Decision 29's exceptions are reached too: `n` is left out one
  # time in three, so a state can lack it where both programs declare it, and a switch
  # starts it at a changed initial value; and `sp` takes an initial value now and then, and
  # moves between var and var_input, so one whose initial value changes becomes an input.
  # `s1` is a var_output driven by a one-shot's storage bit, and `cn` the one-shot's
  # condition, which the rung writes just before it; `s1` is declared now and then with no
  # `ons` on it, and written now and then by another instruction after the `ons`, as only a
  # program with a warning can.
  defp edit_source do
    inputs = Enum.flat_map(~w(start stop), &declared(&1, pick(~w(var_input var_input var none))))
    sp = pick(["var_input sp dint", "var sp dint", "var sp dint 5", nil])
    bools = Enum.map(~w(a b c), &{&1, pick(~w(var var_output var_output))})
    r = pick([:bool, :dint, nil])
    t1 = pick([:ton, :ton, :bool, nil])
    ons = pick([nil, nil, :tags, :rung, :rung, :written])

    declarations =
      Enum.map(inputs, fn {name, section} -> "#{section} #{name} bool" end) ++
        Enum.reject([sp], &is_nil/1) ++
        Enum.map(bools, fn {name, section} -> "#{section} #{name} bool" end) ++
        Enum.take(["var_output n dint #{pick(["", "7", "9"])}"], pick([0, 1, 1])) ++
        typed("r", r) ++ typed("t1", t1) ++ timer_input(t1) ++ ons_tags(ons)

    writable =
      ~w(a b c) ++
        for({name, "var"} <- inputs, do: name) ++
        for({name, :bool} <- [{"r", r}, {"t1", t1}], do: name)

    readable = writable ++ for({name, "var_input"} <- inputs, do: name) ++ timer_bit(t1)

    rungs =
      for _ <- 1..:rand.uniform(4) do
        "#{pick(~w(xic xio))} #{pick(readable)} #{pick(~w(ote ote otl otu))} #{pick(writable)}"
      end ++
        Enum.filter(["xic #{pick(readable)} move #{pick(["5", "7"] ++ sp_word(sp))} n"], fn _ ->
          :rand.uniform(2) == 1
        end) ++
        moves_into("r", r) ++
        ons_rungs(ons, readable) ++ preset_rung(t1, readable, sp) ++ timer_rung(t1)

    Enum.join(declarations ++ rungs, "\n")
  end

  defp declared(_name, "none"), do: []
  defp declared(name, section), do: [{name, section}]

  defp typed(_name, nil), do: []
  defp typed(name, type), do: ["var #{name} #{type}"]

  defp timer_input(:ton), do: ["var_input go bool"]
  defp timer_input(_t1), do: []

  defp timer_bit(:ton), do: ["t1.dn"]
  defp timer_bit(_t1), do: []

  # A timer no `ton` runs keeps whatever a plain swap left under its name, as a misfit.
  defp timer_rung(:ton),
    do: Enum.take(["xic go ton t1 #{pick([30, 5000])}"], :rand.uniform(3) - 1)

  defp timer_rung(_t1), do: []

  # Logic that changes the timer's `.pre`, so a switch finds one that is not a preset.
  defp preset_rung(:ton, readable, sp),
    do:
      Enum.take(
        ["xic #{pick(readable)} move #{pick(["40", "7"] ++ sp_word(sp))} t1.pre"],
        :rand.uniform(2) - 1
      )

  defp preset_rung(_t1, _readable, _sp), do: []

  defp ons_tags(nil), do: []
  defp ons_tags(_ons), do: ["var_output s1 bool", "var_output p bool", "var cn bool"]

  defp ons_rungs(:rung, readable), do: ["xic #{pick(readable)} ote cn ons s1 ote p"]

  defp ons_rungs(:written, readable),
    do: ons_rungs(:rung, readable) ++ ["xic #{pick(readable)} #{pick(~w(otu otl ote))} s1"]

  defp ons_rungs(_ons, _readable), do: []

  defp sp_word(nil), do: []
  defp sp_word(_sp), do: ["sp"]

  defp moves_into(name, :dint), do: ["move 3 #{name}"]
  defp moves_into(_name, _type), do: []

  defp edit_program do
    case Logex.compile(edit_source(), name: "p") do
      {:ok, program} -> program
      {:error, _} -> edit_program()
    end
  end

  defp variant(%Program{source: source}) do
    {declarations, rungs} = Enum.split_with(String.split(source, "\n"), &(&1 =~ ~r/^var/))
    n = "var_output n dint #{pick(["", "7", "9"])}"
    declarations = Enum.map(declarations, &String.replace(&1, ~r/^var_output n dint.*/, n))
    ton = "ton t1 #{pick([0, 30, 5000])}"
    rungs = Enum.map(drop_one(rungs), &String.replace(&1, ~r/ton t1 \d+/, ton))

    case Logex.compile(Enum.join(declarations ++ rungs, "\n"), name: "p") do
      {:ok, program} -> program
      {:error, _} -> edit_program()
    end
  end

  defp without_ton(%Program{source: source}) do
    lines = Enum.reject(String.split(source, "\n"), &(&1 =~ ~r/ ton t1 /))
    {:ok, program} = Logex.compile(Enum.join(lines, "\n"), name: "p")
    program
  end

  # The running program with a `ton` on its timer, where it declares one and runs none.
  defp with_ton(%Program{source: source} = p),
    do: with_ton(source =~ ~r/^var t1 ton$/m and not (source =~ ~r/ ton t1 /), p)

  defp with_ton(true, %Program{source: source}) do
    {:ok, program} = Logex.compile(source <> "\nxic go ton t1 #{pick([30, 5000])}", name: "p")
    program
  end

  defp with_ton(false, p), do: variant(p)

  defp drop_one([]), do: []
  defp drop_one(rungs), do: List.delete_at(rungs, :rand.uniform(length(rungs)) - 1)

  defp edit_attempt(fun), do: attempt(fun, @edit_refusals, :edit_refused)

  test "an online edit refuses every host mistake with a documented ArgumentError, and " <>
         "each step gives the report its rules and its writes say" do
    :rand.seed(:exsss, {2026, 10, 1})

    # Its rarer cases, a resume undone after a restart or a round trip that resumed a timer,
    # come up a few times a run, so the reach is measured beyond the seeds the draw was
    # tuned on: 200 walks missed an atom at 4 of the seeds 1 to 60, and 400 at none.
    for _ <- 1..400 do
      program = edit_program()
      {:ok, other} = Logex.compile(program.source, name: "q")

      walk = %{
        p: program,
        s: Runtime.instance(program),
        e: nil,
        o: nil,
        c: nil,
        points: %{},
        shows: %{},
        pre: %{},
        timed: [],
        round: nil,
        scanned: nil,
        prev: nil
      }

      edit_walk(Map.put(walk, :other, Runtime.instance(other)), 60)
    end

    assert Process.get(:edit_refused, MapSet.new()) == MapSet.new(@edit_refusals)
    assert Process.get(:kinds, MapSet.new()) == MapSet.new(@report_kinds -- @configuration_kinds)
    assert Process.get(:edit_reach, MapSet.new()) == MapSet.new(@edit_reach)
  end

  defp edit_walk(w, 0), do: w
  defp edit_walk(w, n), do: edit_walk(edit_op(op(w, :rand.uniform(12)), w), n - 1)

  # The operation that follows, as the walk or a trial run draws it; but right after a
  # switch that resumed a timer, half the time a scan, which must not catch the timer up; a
  # quarter of the time the switch back with no scan between, which gives the resume back;
  # and a quarter a restart, which starts the timer again, and then the switch back, which
  # then gives nothing back (fix F11). Resumes are rare, and a resume this edit's last
  # switch made is what each of the three needs.
  defp op(%{e: nil}, otherwise), do: otherwise
  defp op(w, otherwise), do: op(Edit.stage(w.e), names(w.timed, :resumed), otherwise)

  defp op(stage, [_ | _], _otherwise) when stage in [:testing, :untested],
    do: pick([1, 1, :back, :restart_back])

  defp op(_stage, _resumed, otherwise), do: otherwise

  defp edit_op(:back, w), do: step(back(Edit.stage(w.e)), w)
  defp edit_op(:restart_back, w), do: edit_op(:back, edit_op(10, w))

  defp edit_op(op, w) when op <= 4, do: edit_scan(w, :running)

  # One candidate in seven is a new program; the rest are the running program changed: with
  # one rung dropped, and `n`'s initial value and the timer's preset redrawn, so the two
  # keep their types, a value a plain swap left is reached, and the timer's `ton` changes
  # its preset; three in seven with its `ton` dropped, so the `ton` goes and comes back
  # while the timer is timing, which its untest resumes; or two in seven with it given
  # back, so a test resumes the timer, where it declares one and runs none (and otherwise
  # as the first). Two times in three a test and an untest with no scan between follow at
  # once, so an untest gives a resume back (fix F11).
  defp edit_op(op, %{e: nil, p: p} = w) when op in [5, 6],
    do:
      pick([&Function.identity/1, &there_and_back/1, &there_and_back/1]).(
        accept(
          pick([
            edit_program(),
            variant(p),
            without_ton(p),
            without_ton(p),
            without_ton(p),
            with_ton(p),
            with_ton(p)
          ]),
          w
        )
      )

  defp edit_op(op, w) when op in 5..9, do: step(pick([:test, :untest, :assemble, :cancel]), w)

  defp edit_op(10, %{p: p, s: s} = w) do
    {:ok, s} = edit_attempt(fn -> Runtime.restart(p, s, :cold) end)
    edit_reach(:restart_in_edit, w.e != nil)
    %{w | s: s, timed: [], round: nil, shows: %{}}
  end

  # A plain swap, within the runtime's contract while no edit is open: a scan of another
  # program over the state. An edit often follows, and is accepted only against a program
  # that has run the state: a variant of it, which keeps its types, so a value the swap
  # left that does not fit is reached; or the program swapped out, whose tags the state
  # still holds.
  defp edit_op(11, %{e: nil} = w), do: swap(edit_program(), w)

  # With an edit open, a trial run: a test, a scan of the candidate, an untest and a scan
  # of the original, each step refused where the stage does not allow it; or a test and an
  # untest with no scan between. A timer whose `ton` the candidate drops is then given it
  # back while it was timing. Or the edit is finalised at one boundary, a test and an
  # assemble, and another taken before any scan, so a one-shot it blocked is still pending
  # (fix F2).
  defp edit_op(11, w), do: pick([&trial/1, &trial/1, &there_and_back/1, &again/1]).(w)

  # A host mistake: a renamed candidate, another program's state, a bad state, something
  # that is not a program or an edit, or an edit given another program's state.
  defp edit_op(12, %{p: p, s: s} = w) do
    {:ok, renamed} = Logex.compile(p.source, name: "q")
    {candidate, step} = {edit_program(), pick([:test, :untest, :assemble, :cancel])}

    {junk, bad} =
      {pick([nil, %{}, renamed.rungs]), pick([%{s | switched: nil}, %{s | now: -1}, nil])}

    not_edit = pick([junk, p])

    calls =
      [
        fn -> Edit.accept(p, renamed, s) end,
        fn -> Edit.accept(p, candidate, w.other) end,
        fn -> Edit.accept(junk, p, s) end,
        fn -> Edit.accept(p, junk, s) end,
        fn -> Edit.accept(p, p, bad) end,
        fn -> apply(Edit, step, [not_edit, s]) end,
        fn -> Edit.running(not_edit) end,
        fn -> Edit.stage(not_edit) end
      ] ++ open_mistakes(w, step, bad)

    assert :refused = edit_attempt(pick(calls))
    w
  end

  # Decision 171: a swap to a program under which a value the state holds is an integer
  # outside its tag's type, `r`'s 3 under a bool, is the host's mistake, refused by the
  # swap's first call, the state kept as it was; and since decision 173 so is a value that
  # is no integer under a bool or a dint, a timer's map under what is now a bool, and since
  # decision 184 an integer under what is now a timer; the rule restated, with no call into
  # Logex.Declarations.
  defp swap(new, w), do: swapped(Enum.any?(w.s.env, &outside_type?(new.tags, &1)), new, w)

  defp swapped(true, new, w) do
    edit_reach(:swap_outside, true)
    assert :refused = edit_attempt(fn -> Runtime.scan(new, w.s, 0) end)
    w
  end

  defp swapped(false, new, %{p: old} = w) do
    edit_reach(:plain_swap, true)
    swapped = edit_scan(%{w | p: new}, :plain_swap)
    candidate = pick([variant(swapped.p), old])
    pick([&edit_op(1, &1), &accept(candidate, &1), &step(:test, accept(candidate, &1))]).(swapped)
  end

  defp outside_type?(tags, {name, value}), do: outside_type?(Map.get(tags, name), value)

  defp outside_type?(%Tag{type: :bool}, value) when is_integer(value), do: value not in 0..1

  defp outside_type?(%Tag{type: :dint}, value) when is_integer(value),
    do: value not in -2_147_483_648..2_147_483_647

  defp outside_type?(%Tag{type: type}, _no_integer) when type in [:bool, :dint], do: true

  # Decision 184: an instance's tag holds a map of its members, so a swap that leaves a
  # bool's or a dint's value under what is now a timer is refused too.
  defp outside_type?(%Tag{type: %Logex.FbType{}}, value), do: not is_map(value)
  defp outside_type?(%Tag{type: {:block, _}}, value), do: not is_map(value)
  defp outside_type?(_tag, _value), do: false

  defp open_mistakes(%{e: nil}, _step, _bad), do: []

  defp open_mistakes(%{e: edit} = w, step, bad),
    do: [fn -> Edit.test(edit, w.other) end, fn -> apply(Edit, step, [edit, bad]) end]

  defp trial(w) do
    w = step(:untest, edit_op(1, step(:test, w)))
    edit_op(op(w, 1), w)
  end

  defp back(:testing), do: :untest
  defp back(:untested), do: :test

  defp there_and_back(w), do: step(:untest, step(:test, w))

  defp again(w) do
    w = step(:assemble, step(:test, w))
    step(:test, accept(variant(w.p), w))
  end

  # A scan of the program the host runs, with inputs that fit: the host's image of its
  # outputs takes what the scan gives. A plain swap's scan catches a frozen timer up, as
  # it always has, so only another is held to the bound on what a timer gains.
  defp edit_scan(%{p: p} = w, scan) do
    inputs =
      for {name, %Tag{section: :var_input, type: type}} <- p.tags,
          :rand.uniform(2) == 1,
          into: %{},
          do: {name, pick(@edges[type] |> Enum.take(2))}

    elapsed = pick([0, 10, 25, 5000])
    {:ok, s} = edit_attempt(fn -> Runtime.put_inputs(p, w.s, inputs) end)
    {:ok, {outputs, later}} = edit_attempt(fn -> Runtime.scan(p, s, elapsed) end)
    assert Enum.sort(Map.keys(outputs)) == outputs_of(p)
    assert later.switched == false
    timed!(scan, p, s, later, w.timed)
    pulsed!(scan, p, s, later, outputs, w.prev)
    shown_scan!(scan, outputs, w.shows)
    prev = %{rung: ons_line(p), cn: later.env["cn"]}

    %{
      w
      | s: later,
        points: Map.merge(w.points, outputs),
        timed: [],
        round: nil,
        prev: prev,
        shows: %{}
    }
  end

  defp accept(candidate, %{p: p, s: s} = w),
    do: edit_accepted(edit_attempt(fn -> Edit.accept(p, candidate, s) end), candidate, w)

  defp edit_accepted({:ok, {:ok, edit, forecast}}, candidate, %{p: p, s: s} = w) do
    report!(forecast)
    assert {_, _, ^forecast} = Edit.test(edit, s)
    assert Edit.stage(edit) == :accepted and Edit.running(edit) == p
    edit_reach(:forecast, true)
    %{w | e: edit, o: p, c: candidate, pre: %{}, scanned: nil}
  end

  defp edit_accepted({:ok, {:error, diagnostics}}, candidate, %{p: p} = w) do
    assert Enum.all?(diagnostics, &match?(%Diagnostic{stage: :edit, severity: :error}, &1))
    assert Enum.map(diagnostics, & &1.line) == Enum.sort(Enum.map(diagnostics, & &1.line))
    cited = for d <- diagnostics, do: d.message |> String.split("`") |> Enum.at(1)

    retyped =
      for {name, %Tag{type: type}} <- candidate.tags,
          match?(%Tag{}, p.tags[name]) and p.tags[name].type != type,
          do: name

    assert Enum.sort(cited) == Enum.sort(retyped) and retyped != []
    edit_reach(:diagnosed, true)
    w
  end

  defp step(name, %{e: nil, s: s} = w) do
    assert :refused = edit_attempt(fn -> apply(Edit, name, [nil, s]) end)
    w
  end

  defp step(name, %{e: edit, s: s} = w) do
    stage = Edit.stage(edit)
    result = edit_attempt(fn -> apply(Edit, name, [edit, s]) end)
    stepped(name, stage, stage in @allowed[name], result, w)
  end

  defp stepped(_name, _stage, false, result, w) do
    assert result == :refused, "a step at the wrong stage was accepted"
    w
  end

  defp stepped(name, stage, true, {:ok, {next, later, report}}, %{s: before} = w)
       when name in [:test, :untest] do
    report!(report)

    assert later == %{
             before
             | env: rebuilt(before.env, report),
               switched: true,
               ons_blocked: names(report, :ons_blocked)
           }

    to = Edit.running(next)
    switched!(w.p, to, before, later, report, {name, stage})
    held!(w.p, to, report, later, w.points)
    pre = timers!(w.p, to, before, later, report, w.pre)
    scanned = ons!(sides(name, w), before, later, report, w.scanned)
    edit_reach(:second_test, name == :test and stage == :untested)
    round = round_trip!(name, w.round, {w.p, to, stage}, before, later, report)

    timed =
      for {kind, _, _} = entry <- report, kind in [:dn_drops, :dn_rises, :resumed], do: entry

    %{
      w
      | e: next,
        s: later,
        p: to,
        pre: pre,
        timed: timed,
        round: round,
        scanned: scanned,
        shows: shown(report, to)
    }
  end

  defp stepped(:cancel, :accepted, true, {:ok, {program, later, report}}, %{s: before} = w) do
    assert {program, later, report} == {w.o, before, []}
    edit_reach(:cancelled_accepted, true)
    %{w | e: nil, p: program, round: nil}
  end

  defp stepped(name, _stage, true, {:ok, {kept, later, report}}, %{s: before} = w) do
    report!(report)
    dropped = dropped(name, w)
    assert kept == Edit.running(w.e)
    assert later == %{before | env: rebuilt(before.env, report)}
    assert Enum.sort(Map.keys(later.env)) == Enum.sort(Map.keys(kept.tags))

    assert for({:pruned, tag, value} <- report, do: {tag, value}) ==
             Enum.sort(
               for {tag, value} <- before.env, not Map.has_key?(kept.tags, tag), do: {tag, value}
             )

    held!(dropped, kept, report, before, w.points)
    edit_reach(pruned(name), true)
    %{w | e: nil, s: later, p: kept, round: nil, shows: shown(report, kept)}
  end

  defp dropped(:assemble, w), do: w.o
  defp dropped(:cancel, w), do: w.c

  defp pruned(:assemble), do: :assembled
  defp pruned(:cancel), do: :cancelled_untested

  defp report!(report) do
    assert report == Enum.sort(report)
    keys = for {kind, name, _detail} <- report, do: {kind, name}
    assert keys == Enum.uniq(keys)

    for {kind, name, _detail} <- report do
      assert kind in @report_kinds and is_binary(name)
      reached(:kinds, kind)
    end
  end

  # The writes a report lists, applied to a state's env.
  defp rebuilt(env, report), do: Enum.reduce(report, env, &write/2)

  defp write({kind, name, value}, env) when kind in [:added, :input],
    do: Map.put(env, name, value)

  defp write({:preset, name, {_from, to}}, env), do: put_in(env, [name, "pre"], to)
  defp write({:resumed, name, gap}, env), do: update_in(env, [name, "last"], &(&1 + gap))
  defp write({:resume_undone, name, gap}, env), do: update_in(env, [name, "last"], &(&1 - gap))
  defp write({:pruned, name, _value}, env), do: Map.delete(env, name)
  defp write(_fact, env), do: env

  # A switch's rules, restated from the two programs: which tags start, at what value,
  # which inputs go live or unread, and which initial values changed.
  defp switched!(from, to, before, later, report, {name, stage}) do
    first_test? = name == :test and stage == :accepted
    initial = Program.initial_env(to)

    started = starts(from, to, before.env, first_test?)
    inputs = var_inputs(to)
    assert names(report, :added) == Enum.sort(started -- inputs)

    assert names(report, :input) ==
             Enum.sort(
               Enum.uniq((inputs -- var_inputs(from)) ++ (started -- (started -- inputs)))
             )

    assert names(report, :unread) == Enum.sort(var_inputs(from) -- inputs)

    for {kind, tag, value} <- report, kind in [:added, :input, :unread] do
      assert value == Map.get(later.env, tag, 0)
      assert kind == :unread or value == entry_value(tag in started, initial, before.env, tag)
    end

    old = Program.initial_env(from)

    changed =
      for {tag, %Tag{type: type}} <- to.tags,
          type in [:bool, :dint],
          match?(%Tag{type: ^type}, from.tags[tag]),
          old[tag] != initial[tag],
          do: tag

    reported = for tag <- changed, tag not in started, tag not in inputs, do: tag

    assert for({:initial_changed, _, _} = entry <- report, do: entry) ==
             Enum.sort(for tag <- reported, do: {:initial_changed, tag, {old[tag], initial[tag]}})

    edit_reach(:initial_started, Enum.any?(changed, &(&1 in started)))
    edit_reach(:initial_input, Enum.any?(changed, &(&1 in inputs and &1 not in started)))

    edit_reach(
      :misfit,
      first_test? and
        Enum.any?(started, &(Map.has_key?(before.env, &1) and Map.has_key?(from.tags, &1)))
    )

    edit_reach(
      :stale,
      first_test? and
        Enum.any?(started, &(Map.has_key?(before.env, &1) and not Map.has_key?(from.tags, &1)))
    )

    # Decision 96: `t1.pre`, which the program stopped moves a value into and the program
    # started does not, where it declares `t1` a timer, keeps its value and is reported.
    assert for({:unwritten, _, _} = entry <- report, do: entry) ==
             unwritten(moves_pre?(from) and not moves_pre?(to) and ton?(to), later.env)
  end

  defp moves_pre?(%Program{source: source}), do: source =~ ~r/ move \S+ t1\.pre$/m
  defp ton?(%Program{tags: tags}), do: match?(%Tag{type: %Logex.FbType{name: "ton"}}, tags["t1"])

  defp unwritten(true, env), do: [{:unwritten, "t1.pre", member_at(env["t1"], "pre")}]
  defp unwritten(false, _env), do: []

  defp member_at(%{} = instance, member), do: Map.get(instance, member, 0)
  defp member_at(_not_an_instance, _member), do: 0

  # The tags a switch starts at their initial value, from the text and the state: one the
  # state lacks, and at the first test one the candidate adds or whose value does not fit.
  defp starts(from, to, env, first_test?),
    do:
      for(
        {tag, declared} <- to.tags,
        not Map.has_key?(env, tag) or
          (first_test? and
             (not Map.has_key?(from.tags, tag) or not typed_as?(declared, env[tag]))),
        do: tag
      )

  # A tag started holds its initial value; any other the value it held, a section change
  # included (decision 25).
  defp entry_value(true, initial, _env, tag), do: initial[tag]
  defp entry_value(false, _initial, env, tag), do: env[tag]

  defp typed_as?(%Tag{type: :bool}, value), do: value in [0, 1]

  defp typed_as?(%Tag{type: :dint}, value),
    do: is_integer(value) and value in -2_147_483_648..2_147_483_647//1

  defp typed_as?(%Tag{}, %{} = timer), do: Enum.sort(Map.keys(timer)) == ~w(acc dn en last pre tt)
  defp typed_as?(%Tag{}, _value), do: false

  # Decision 20 restated from the text, and F4 checked against the host's own image: a
  # held output is one of either program's outputs that the program stopped (or dropped)
  # wrote, and the program kept does not write as an output. One the program kept shows
  # holds the state's value, and every such one is reported; one it does not show holds
  # what the host last received for it, and is reported only when the edit knows it.
  defp held!(stopped, kept, report, state, points) do
    expected =
      for tag <- Enum.uniq(outputs_of(stopped) ++ outputs_of(kept)),
          writes?(stopped, tag),
          not (tag in outputs_of(kept) and writes?(kept, tag)),
          do: tag

    reported = names(report, :held)
    assert reported -- expected == []
    assert Enum.filter(expected, &(&1 in outputs_of(kept))) -- reported == []

    for {:held, tag, value} <- report do
      held_value(tag in outputs_of(kept), tag, value, state, points)
    end
  end

  defp held_value(true, tag, value, state, _points) do
    assert value == Map.get(state.env, tag, 0)
    edit_reach(:held_shown, true)
  end

  defp held_value(false, tag, value, _state, points) do
    assert Map.fetch(points, tag) == {:ok, value}
    edit_reach(:held_point, true)
  end

  # F4, independently of the edit: a held output the program that runs next still shows is
  # what that program's next scan gives the host, unless a restart comes first.
  defp shown(report, kept),
    do: for({:held, tag, value} <- report, tag in outputs_of(kept), into: %{}, do: {tag, value})

  defp shown_scan!(:running, outputs, shows) do
    assert Map.take(outputs, Map.keys(shows)) == shows
    edit_reach(:held_shown_scan, shows != %{})
  end

  defp shown_scan!(_plain_swap, _outputs, _shows), do: :ok

  defp writes?(program, tag),
    do:
      Regex.match?(
        ~r/(^|\s)((ote|otl|otu|ons) #{tag}|move \S+ #{tag})(\s|$)/m,
        program.source
      )

  # Decision 23 and fixes F1 and F6, restated from the two programs' text: each timer
  # either program declares, as the start rules left it, takes the `.pre` the walk's own
  # record of the edit's last switch, or the presets, say; is reported so; and resumes where it
  # was timing and not run since. Returns the record for the next switch: for each timer,
  # the `.pre` this switch left and the one it found.
  defp timers!(from, to, before, later, report, record) do
    started = rebuilt(before.env, for({k, _, _} = e <- report, k in [:added, :input], do: e))
    timers = Enum.uniq(timers_of(from) ++ timers_of(to))

    {expected, record} =
      Enum.reduce(timers, {[], %{}}, fn tag, {expected, next} ->
        timer!(
          started[tag],
          {tag, ton_of(from, tag), ton_of(to, tag)},
          {later, before.switched},
          record[tag],
          {expected, next}
        )
      end)

    assert for({kind, _, _} = entry <- report, kind in @timer_kinds, do: entry) ==
             Enum.sort(expected)

    record
  end

  # A timer's map may lack members: a plain swap that writes `t1.pre` where the program
  # swapped out held a bool leaves `%{"pre" => 40}`, which no `ton` has run since.
  defp timer!(%{"pre" => pre} = was, {tag, from, to}, {later, switched}, undo, {expected, next}) do
    {how, target} = pre_target(undo, pre, from, to)
    now = later.now
    edit_reach(:undo_after_restart, switched and found?(undo) and was["last"] != now)
    {was, undone} = resume_undone(was, undo, switched, now, tag)
    resumed? = to != nil and was["en"] == 1 and was["last"] < now
    moved = Map.put(was, "pre", target)
    assert later.env[tag] == if(resumed?, do: Map.put(moved, "last", now), else: moved)

    entries =
      preset_entries(tag, pre, target, to, was) ++
        undone ++ if(resumed?, do: [{:resumed, tag, now - was["last"]}], else: [])

    edit_reach(how, target != pre or how == :pre_frozen)
    {entries ++ expected, Map.put(next, tag, {target, pre, if(resumed?, do: was["last"])})}
  end

  defp timer!(_not_a_timer, _timer, _later, _undo, acc), do: acc

  # Where this edit's last switch resumed the timer and no scan has run since, its `last`,
  # still at `now`, goes back to the one that switch found; not after a restart, which
  # started the timer again.
  defp resume_undone(%{"last" => now} = was, {_, _, last}, true, now, tag) when last != nil,
    do: {Map.put(was, "last", last), [{:resume_undone, tag, now - last}]}

  defp resume_undone(was, _undo, _switched, _now, _tag), do: {was, []}

  defp found?({_, _, last}), do: last != nil
  defp found?(nil), do: false

  defp pre_target({pre, found, _last}, pre, _from, _to), do: {:pre_restored, found}
  defp pre_target(_undo, pre, from, nil) when from != nil and pre != 0, do: {:pre_frozen, pre}
  defp pre_target(_undo, pre, _from, nil), do: {:frozen_unseen, pre}
  defp pre_target(_undo, _pre, nil, to), do: {:pre_outright, to}
  defp pre_target(_undo, from, from, to), do: {:pre_followed, to}
  defp pre_target(_undo, pre, _from, _to), do: {:kept, pre}

  defp preset_entries(_tag, pre, pre, to, _was) when to in [nil, pre], do: []
  defp preset_entries(tag, pre, pre, to, _was), do: [{:preset_kept, tag, {pre, to}}]

  defp preset_entries(tag, pre, target, nil, _was), do: [{:preset, tag, {pre, target}}]

  defp preset_entries(tag, pre, target, _to, was),
    do: [{:preset, tag, {pre, target}} | dn_forecast(tag, was, target)]

  defp dn_forecast(tag, %{"dn" => 1, "acc" => acc}, pre) when max(acc, 0) < pre,
    do: [{:dn_drops, tag, {max(acc, 0), pre}}]

  defp dn_forecast(tag, %{"dn" => 0, "en" => 1, "acc" => acc}, pre) when max(acc, 0) >= pre,
    do: [{:dn_rises, tag, {max(acc, 0), pre}}]

  defp dn_forecast(_tag, _was, _pre), do: []

  # The timers a program declares, and the preset of the `ton` that runs one, from its text.
  defp timers_of(program),
    do: for([_, tag] <- Regex.scan(~r/^var (\S+) ton$/m, program.source), do: tag)

  defp ton_of(program, tag) do
    case Regex.run(~r/(^|\s)ton #{tag} (\d+)/, program.source) do
      [_, _, preset] -> String.to_integer(preset)
      nil -> nil
    end
  end

  # Independent of the rules, a scan's timers against `ton` itself. Resume: no scan lets
  # a timer its program runs gain more than the scan's own time, as one caught up after a
  # switch would; reached where the last switch resumed the timer, and catching up would
  # have broken the bound. F6: the scan right after a switch, with the timer's rung true and
  # its `.pre` as the switch left it, drops `.dn` where the switch said it would, unless
  # `.pre` - `.acc` ms passed, and raises it where the switch said it would (forecast!/5).
  defp timed!(:plain_swap, _program, _before, _later, _timed), do: :ok

  defp timed!(:running, program, before, later, timed) do
    dt = later.now - before.now

    for tag <- timers_of(program), ton_of(program, tag) != nil do
      was = acc_of(before.env[tag])
      timer = later.env[tag]
      assert timer["acc"] <= was + dt

      edit_reach(
        :resumed_scan,
        tag in names(timed, :resumed) and timer["en"] == 1 and was + dt < max(timer["pre"], 0)
      )

      for {kind, ^tag, {acc, pre}} <- timed, kind in [:dn_drops, :dn_rises] do
        forecast!(kind, {acc, pre}, before.env[tag], timer, dt)
      end
    end
  end

  # A forecast speaks of the timer as the switch left it, a drop of a `.dn` at 1 and a rise
  # of one at 0, and is borne out by the next scan wherever the rung is true and `.pre` as
  # it was.
  defp forecast!(kind, {acc, pre}, was, timer, dt) do
    assert {was["dn"], acc, pre} == {dn_before(kind), acc_of(was), was["pre"]}

    if timer["en"] == 1 and timer["pre"] == pre and (kind == :dn_rises or dt < pre - acc) do
      assert timer["dn"] == 1 - dn_before(kind)
      edit_reach(:dn_scan, true)
    end
  end

  defp dn_before(:dn_drops), do: 1
  defp dn_before(:dn_rises), do: 0

  defp acc_of(%{"acc" => acc}), do: max(acc, 0)
  defp acc_of(_not_a_timer), do: 0

  # F1 and F11, independent of the rules and of the reports: a test then an untest with no
  # scan between leaves the original's tags as they were, and so its next scan's outputs, a
  # timer the test resumed included, but for the writes no untest undoes, found from the
  # two programs' text and the state: a tag either switch started, which the state lacked
  # or (at a first test) held a value of the wrong type for, at its initial value. A test
  # starts the round; an untest that follows it at once ends it; a scan, a restart,
  # accept, assemble and cancel clear it, through the walk.
  defp round_trip!(:test, _round, {from, to, stage}, before, _later, report) do
    started = starts(from, to, before.env, stage == :accepted)
    {before, report, Map.merge(before.env, Map.take(Program.initial_env(to), started))}
  end

  defp round_trip!(:untest, nil, _programs, _before, _later, _report), do: nil

  defp round_trip!(:untest, {was, tested, kept}, {_from, original, _stage}, before, later, report) do
    lacked = for {tag, _} <- original.tags, not Map.has_key?(before.env, tag), do: tag
    initial = Program.initial_env(original)
    expected = %{was | env: Map.merge(kept, Map.take(initial, lacked))}
    tags = Map.keys(original.tags)
    assert Map.take(later.env, tags) == Map.take(expected.env, tags)
    # Before a first scan, which blocks every `ons`, the list makes no difference.
    assert later.ons_blocked == was.ons_blocked or was.first
    {outputs, _} = Runtime.scan(original, expected, 10)
    assert {^outputs, _} = Runtime.scan(original, later, 10)
    edit_reach(:round_trip, true)

    edit_reach(
      :round_trip_timer,
      Enum.any?(tested ++ report, &(elem(&1, 0) in [:preset, :preset_kept]))
    )

    edit_reach(:round_trip_resumed, names(tested, :resumed) != [])

    edit_reach(
      :round_trip_started,
      Enum.any?(original.tags, fn {tag, _} ->
        not Map.has_key?(was.env, tag) and Map.has_key?(kept, tag) and kept[tag] != initial[tag]
      end)
    )

    edit_reach(:round_trip_ons, names(tested, :ons_blocked) != [])
    nil
  end

  # Decision 21 and fixes F2, F3 and F7, restated from the two programs' text, with the
  # walk's own record of which side of the edit left the storage bits and what is pending
  # against it: `s1` is blocked where the program started has its `ons`, unless the side
  # that last scanned is the one started, or has that `ons` in the same rung text and
  # writes `s1` no other way; or where it is pending and the program started has its
  # `ons`. Returns the record for the next switch.
  defp ons!({stops, sides}, before, later, report, scanned) do
    {last, pending} = scanned = ons_basis(scanned, before, stops)
    to = sides[started(stops)]
    {own, how} = own_blocks(last == stops, sides[last], to, before)
    kept = for "s1" <- pending, ons_line(to) != nil, do: "s1"
    assert names(report, :ons_blocked) == Enum.sort(Enum.uniq(own ++ kept))

    for {:ons_blocked, bit, value} <- report, do: assert(value == later.env[bit])

    edit_reach(how, how != :none)
    edit_reach(:ons_pending, own == [] and kept != [])
    scanned
  end

  defp sides(:test, w), do: {:original, %{original: w.o, candidate: w.c}}
  defp sides(:untest, w), do: {:candidate, %{original: w.o, candidate: w.c}}

  defp started(:original), do: :candidate
  defp started(:candidate), do: :original

  defp ons_basis(_known, %Instance{switched: false}, stops), do: {stops, []}
  defp ons_basis(nil, %Instance{ons_blocked: pending}, stops), do: {stops, pending}
  defp ons_basis(known, _state, _stops), do: known

  defp own_blocks(false, _last, to, _before), do: {[], same_side(ons_line(to))}

  defp own_blocks(true, last, to, before),
    do: own_ons(ons_line(last), ons_line(to), elsewhere?(last), Map.has_key?(before.env, "s1"))

  defp same_side(nil), do: :none
  defp same_side(_rung), do: :ons_same_side

  defp own_ons(_rung, nil, _elsewhere?, _existing?), do: {[], :none}
  defp own_ons(nil, _rung, _elsewhere?, true), do: {["s1"], :ons_new}
  defp own_ons(nil, _rung, _elsewhere?, false), do: {["s1"], :none}
  defp own_ons(rung, rung, true, _existing?), do: {["s1"], :ons_written}
  defp own_ons(rung, rung, false, _existing?), do: {[], :ons_untouched}
  defp own_ons(_rung, _changed, _elsewhere?, _existing?), do: {["s1"], :ons_changed}

  # The rung of the program's `ons`, as its text, and whether anything else writes `s1`.
  defp ons_line(program),
    do: Enum.find(String.split(program.source, "\n"), &String.contains?(&1, " ons s1 "))

  defp elsewhere?(program),
    do: Regex.match?(~r/(^|\s)((ote|otl|otu) s1|move \S+ s1)(\s|$)/m, program.source)

  # F11, independent of the rules: a one-shot pulses only if the previous scan ran the same
  # `ons` rung text with its condition 0. Read where the program scanned writes `s1` through
  # its `ons` alone, as a one-shot's own scans then bear it out, and not at a plain swap's
  # scan, which nothing blocks. Reached by a real edge on the scan right after a switch,
  # and by a block that kept a would-be pulse off.
  defp pulsed!(:plain_swap, _program, _state, _later, _outputs, _prev), do: :ok

  defp pulsed!(:running, program, state, later, outputs, prev),
    do: pulse!(ons_line(program), elsewhere?(program), state, later, outputs, prev)

  defp pulse!(nil, _elsewhere?, _state, _later, _outputs, _prev), do: :ok
  defp pulse!(_rung, true, _state, _later, _outputs, _prev), do: :ok

  defp pulse!(rung, false, state, _later, %{"p" => 1}, prev) do
    assert %{rung: ^rung, cn: 0} = prev
    edit_reach(:ons_switch_edge, state.switched)
  end

  defp pulse!(_rung, false, state, later, %{"p" => 0}, _prev),
    do:
      edit_reach(
        :ons_blocked_edge,
        "s1" in state.ons_blocked and later.env["cn"] == 1 and state.env["s1"] == 0 and
          not state.first
      )

  defp names(report, kind), do: for({^kind, name, _} <- report, do: name)

  defp var_inputs(program),
    do: Enum.sort(for {name, %Tag{section: :var_input}} <- program.tags, do: name)

  defp outputs_of(program),
    do: Enum.sort(for {name, %Tag{section: :var_output}} <- program.tags, do: name)

  defp edit_reach(name, true), do: reached(:edit_reach, name)

  defp edit_reach(_name, false), do: :ok

  # ---- M2-1: the walk over a configuration -----------------------------------------------

  # The refusals of a resource's calls, by the words that tell their kinds apart. Each line
  # of a refusal is one problem, and each must be one of these: the first whose words it
  # holds, so an instance's unknown tag, "is a program instance of `motor`, which declares
  # no", is told from the instance named whole by coming first.
  @config_refusals [
    {:runtime, "expected a %Logex.Runtime{} from Logex.Runtime.start/1"},
    {:elapsed, "elapsed_ms must be"},
    {:inputs, "inputs must be a map of input-point names"},
    {:key, "is not a point name"},
    {:output_point, "is an output point"},
    {:unlocated, "is a global with no location"},
    {:reaches, "reaches into the program instance"},
    {:no_point, "is not an input point"},
    {:bool, "is a bool: only 0 or 1 fit"},
    {:dint, "is a dint: its value must be an integer"},
    {:dint_range, "is outside -2147483648 to 2147483647"},
    # M5-8: a word point's value, an integer from 0 to 65535 (decision 156).
    {:word_range, "is a word: "},
    {:path, "is not an access path"},
    {:neither, "is neither a global nor a program instance"},
    {:too_deep, "goes too deep"},
    {:instance_key, "`, not an input point"},
    {:task, "is a task, not"},
    {:configuration, "is the configuration's name"},
    {:no_tag, "which declares no"},
    {:whole_instance, "is a program instance of `"},
    {:whole_block, "an access path names one of its members"},
    {:internal_member, "an access path reads only its public members"},
    {:no_member, "is not a member of"},
    {:mode, "restart takes :cold or :warm"},
    # start/1 checks its configuration again: a host's mistake that check/1 raises, or a
    # diagnostic it gives, formatted.
    {:fractional, "a priority is 0, the highest, to 65535, found 1.5"},
    {:priority, "a priority is 0 to 65535, and 0 is the highest"},
    # M2-6: a task's single, a bool global's name, as a host gives one or a text could; an
    # event task's interval of 0 is told so before any other's, whose words its own share.
    {:single_interval, "a task that runs only on the rising edges of its single"},
    {:interval, "an interval is at least 1 ms"},
    {:single_host, "a single is a bool global's name, or nil for none"},
    {:single_dint, "is a dint: a single is a bool global"},
    {:single_unknown, "the single of `t9`: no global"},
    {:lines, "a configuration's lines are all nil"},
    {:line, "a line is a positive integer"}
  ]

  # What the walk must see the scheduler do, at least once each.
  @config_reach [
    :ran_task,
    :ran_taskless,
    :overlap,
    :overlap_many,
    :no_task_due,
    :elapsed_zero,
    :priority_order,
    :due_time_order,
    :read_back,
    :constant,
    :copy_out_seen,
    :first_scan_ons,
    :timer_done,
    :infinity,
    :restart,
    :image_kept,
    # M2-6: event tasks, alone and with an interval.
    :edge_event,
    :edge_both,
    :held_skip,
    :late_edge_skip,
    :falling_due,
    :first_cycle_edge,
    :restart_refire,
    :logic_trigger,
    :overlap_under_single,
    :tie_event_periodic,
    # M5-8: a word's bit read through a connection, at a point or not.
    :word_bit
  ]

  # The program types a configuration of the walk draws from: a contact, a latch, a timer
  # with a dint preset and output, and a one-shot.
  @types %{
    "relay" => "var_input in bool\nvar_output out bool\nxic in ote out",
    "latch" =>
      "var_input set bool\nvar_input reset bool\nvar_output q bool\nxic set otl q\nxic reset otu q",
    "timer" =>
      "var_input go bool\nvar_input sp dint\nvar_output done bool\nvar_output acc dint\n" <>
        "var t1 ton\nxio go move sp t1.pre\nxic t1.dn ote done\nmove t1.acc acc\nxic go ton t1 30",
    "pulse" => "var_input in bool\nvar_output out bool\nvar s bool\nxic in ons s ote out",
    # M5-8: a word's bit 3 read by a contact and its low byte masked into a word.
    "bits" =>
      "var_input w word\nvar_output out bool\nvar_output lo word\nxic w.3 ote out\n" <>
        "and w 16#00ff lo"
  }

  # The globals: input points, output points and unlocated globals, bool and dint, and
  # since M5-8 a word at each kind of point and one unlocated.
  @points [
    {"i0", :bool, "panel.i.0"},
    {"i1", :bool, "panel.i.1"},
    {"i2", :bool, "panel.i.2"},
    {"d0", :dint, "drive.i.0"},
    {"o0", :bool, "panel.q.0"},
    {"o1", :bool, "panel.q.1"},
    {"o2", :bool, "panel.q.2"},
    {"a0", :dint, "drive.q.0"},
    {"g0", :bool, nil},
    {"g1", :bool, nil},
    {"n0", :dint, nil},
    {"w0", :word, "drive.i.1"},
    {"w1", :word, "drive.q.1"},
    {"wn", :word, nil}
  ]

  # The one global with an initial value, which a restart puts back.
  @initials %{"n0" => 7}

  # The bool globals a task's single may name (M2-6).
  @triggers ~w(i0 i1 i2 i0 o0 g0 g1)

  # Its draws are sized from the rate of its rarest atom, `:due_time_order`, seen in about
  # one configuration in 26 over the seeds {n, 77, 7}, n from 1 to 60. At 150
  # configurations a run, 1 of the 260 seeds {n, 77, 7}, n to 60, and {n, 1, 1} and
  # {7, n, 2026}, n to 100, missed it. At 400 it was expected more than 15 times a run.
  # M2-6 draws a task with a single for 1 in 2 tasks, which makes two periodic runs of one
  # priority rarer, so the walk took 500 configurations, its reach held at this seed and,
  # in its place, at each of {n, 77, 7}, {n, 1, 1} and {7, n, 2026}, n from 1 to 100, its
  # rarest atoms reached by at least 2 configurations a run (`:due_time_order`), 3
  # (`:first_cycle_edge`) and 5 (`:tie_event_periodic`), and every other by 7 or more.
  # Since M2-6's review it takes 1000, the maintainer's choice, for margin: at those 300
  # seeds every refusal is reached a run and its rarest atoms by at least 11
  # configurations (`:due_time_order`), 15 (`:first_cycle_edge`), 16
  # (`:tie_event_periodic`) and 19 (`:logic_trigger`), and every other by 56 or more; at
  # this seed, by 15, 37, 20 and 48.
  test "a resource refuses every host mistake with a documented ArgumentError, accepts " <>
         "every call without one, and runs as its rules say" do
    programs =
      Map.new(@types, fn {name, source} ->
        {:ok, program} = Logex.compile(source, name: name)
        {name, program}
      end)

    :rand.seed(:exsss, {2026, 10, 2})

    for _ <- 1..1000 do
      config = configuration(programs)
      model = model(config)
      runtime = Runtime.start(config)
      Process.put(:config_samples, %{})
      Process.put(:config_fresh, :start)
      config_walk(config, runtime, model, 50)
    end

    expected = MapSet.new(Enum.map(@config_refusals, &elem(&1, 0)))
    assert Process.get(:config_refused, MapSet.new()) == expected
    assert Process.get(:config_reach, MapSet.new()) == MapSet.new(@config_reach)
  end

  defp configuration(programs) do
    tasks =
      for name <- Enum.take(Enum.shuffle(~w(fast mid slow)), :rand.uniform(4) - 1),
          do: task_of(pick([:periodic, :periodic, :periodic, :event, :both, :both]), name)

    # Names drawn in a random order, so that declaration order is not name order, and no
    # order a name gives can pass for the one the configuration declares.
    instances =
      for name <- Enum.take(Enum.shuffle(~w(m1 m2 m3 m4 m5)), :rand.uniform(4)),
          do: %Logex.Configuration.Instance{
            name: name,
            type: pick(Map.keys(programs)),
            task: pick([nil | Enum.map(tasks, & &1.name)])
          }

    globals =
      for {name, type, at} <- @points,
          do: %Logex.Configuration.Global{
            name: name,
            type: type,
            at: at,
            initial: @initials[name]
          }

    {connections, _driven} =
      Enum.flat_map_reduce(instances, MapSet.new(), fn instance, driven ->
        program = programs[instance.type]
        tags = program.tags |> Map.values() |> Enum.sort_by(& &1.name)

        ins =
          for %Tag{section: :var_input} = tag <- tags,
              do: %Logex.Configuration.Connection{
                instance: instance.name,
                member: tag.name,
                to: source_for(tag.type)
              }

        Enum.flat_map_reduce(
          for(%Tag{section: :var_output} = tag <- tags, do: tag),
          driven,
          fn tag, driven ->
            sinks =
              for {name, type, at} <- @points,
                  type == tag.type,
                  at == nil or String.contains?(at, ".q."),
                  name not in driven,
                  :rand.uniform(2) == 1,
                  do: name

            outs =
              for sink <- Enum.take(sinks, 2),
                  do: %Logex.Configuration.Connection{
                    instance: instance.name,
                    member: tag.name,
                    to: sink
                  }

            {outs, Enum.reduce(outs, driven, &MapSet.put(&2, &1.to))}
          end
        )
        |> then(fn {outs, driven} -> {ins ++ outs, driven} end)
      end)

    Logex.Configuration.new!(
      name: "plant",
      programs: Map.values(programs),
      tasks: tasks,
      globals: globals,
      instances: instances,
      connections: connections
    )
  end

  # M2-6: a task of a kind drawn, its trigger a bool global: an input point, an output point
  # read back, or an unlocated global a connection may drive.
  defp task_of(kind, name) do
    task = %Logex.Configuration.Task{name: name, priority: pick([0, 1, 2, 2, 65_535])}
    triggered(kind, task)
  end

  defp triggered(:periodic, task), do: %{task | interval: pick([5, 10, 15, 30])}
  defp triggered(:event, task), do: %{task | single: pick(@triggers)}

  defp triggered(:both, task),
    do: %{task | single: pick(@triggers), interval: pick([5, 10, 15, 30])}

  # A var_input's source: a global of its type, an output point read back among them, or a
  # constant.
  defp source_for(:bool), do: pick(~w(i0 i1 i2 i0 i1 o0 g0 g1) ++ [0, 1])
  defp source_for(:dint), do: pick(["d0", "d0", "n0", "a0", 0, 40, 25])
  defp source_for(:word), do: pick(["w0", "w0", "wn", "w1", 0, 8, 65_535])

  # The walk's own model of a resource, from the rules in Logex.Runtime's moduledoc and
  # docs/organisation.md §4.6, each instance scanned by Runtime.call/4 alone: the input
  # image and every global, each instance's state, and each task's next due time, which
  # is a multiple of its interval since every task is due at 0, nil for a task with no
  # interval. M2-6: each task with a single keeps its trigger's last sample, 0 at start,
  # and counts the due times it skipped, phase points passed while its trigger samples 1
  # (decisions 39 and 51), apart from its periodic runs.
  defp model(config),
    do: %{
      now: 0,
      globals: Map.new(config.globals, &{&1.name, Map.get(@initials, &1.name, 0)}),
      states: Map.new(config.instances, &{&1.name, Runtime.instance(config.programs[&1.type])}),
      anchor: Map.new(config.tasks, &{&1.name, 0}),
      next: Map.new(config.tasks, &{&1.name, &1.interval && 0}),
      last: Map.new(config.tasks, &{&1.name, 0}),
      overlaps: Map.new(config.tasks, &{&1.name, 0}),
      runs: Map.new(config.tasks, &{&1.name, 0}),
      skipped: Map.new(config.tasks, &{&1.name, 0}),
      cycles: 0
    }

  # A restart, from the rules alone: the clock and the input points kept, every other
  # global at its initial value, each instance through restart/3, and every task anchored
  # at the kept clock, with nothing run or missed since.
  defp model_restart(config, model, mode),
    do: %{
      model
      | globals:
          Map.new(model.globals, fn {name, value} ->
            {name, kept(name in input_points(), value, Map.get(@initials, name, 0))}
          end),
        states:
          Map.new(model.states, fn {name, state} ->
            {name, Runtime.restart(config.programs[state.type], state, mode)}
          end),
        anchor: Map.new(config.tasks, &{&1.name, model.now}),
        next: Map.new(config.tasks, &{&1.name, &1.interval && model.now}),
        last: Map.new(config.tasks, &{&1.name, 0}),
        overlaps: Map.new(config.tasks, &{&1.name, 0}),
        runs: Map.new(config.tasks, &{&1.name, 0}),
        skipped: Map.new(config.tasks, &{&1.name, 0})
    }

  defp kept(true, value, _initial), do: value
  defp kept(false, _value, initial), do: initial

  defp input_points, do: for({name, _, at} <- @points, at != nil, at =~ ".i.", do: name)

  defp model_cycle(config, model, elapsed, inputs) do
    now = model.now + elapsed
    globals = Map.merge(model.globals, inputs)
    model = %{model | now: now, globals: globals, cycles: model.cycles + 1}

    # Every trigger sampled before any scan, then what each task does: an edge runs at
    # now; a due time that has come runs at it while the trigger samples 0, or is skipped
    # with every phase point up to now while it samples 1, an edge cycle's among them.
    {plans, model} =
      config.tasks
      |> Enum.with_index()
      |> Enum.map_reduce(model, fn {task, index}, model ->
        sample = task.single && globals[task.single]
        edge? = task.single != nil and model.last[task.name] == 0 and sample == 1
        come? = task.interval != nil and model.next[task.name] <= now
        model = %{model | last: Map.put(model.last, task.name, sample || 0)}
        model_plan({edge?, come?, sample}, task, index, model)
      end)

    due =
      plans
      |> Enum.reject(&is_nil/1)
      |> Enum.sort_by(fn {task, index, at} -> {task.priority, at, index} end)

    {model, events} =
      Enum.reduce(due, {model, []}, fn {task, _index, at}, {model, events} ->
        {model, events} = model_run(task, at, model, events)

        Enum.reduce(
          for(i <- config.instances, i.task == task.name, do: i),
          {model, events},
          &model_scan(config, &1, task.name, &2)
        )
      end)

    {model, events} =
      Enum.reduce(
        for(i <- config.instances, i.task == nil, do: i),
        {model, events},
        &model_scan(config, &1, :none, &2)
      )

    outputs =
      for {name, _type, at} <- @points,
          at != nil and String.contains?(at, ".q."),
          into: %{},
          do: {name, model.globals[name]}

    {model, outputs, Enum.reverse(events)}
  end

  # The phase points of a task from its anchor: the first after now, and how many lie from
  # its next due time to now.
  defp phase_after(model, task),
    do:
      model.anchor[task.name] +
        (div(model.now - model.anchor[task.name], task.interval) + 1) * task.interval

  defp phase_points(model, task),
    do:
      div(model.now - model.anchor[task.name], task.interval) -
        div(model.next[task.name] - model.anchor[task.name], task.interval) + 1

  defp model_plan({true, come?, _sample}, task, index, model) do
    model = model_skip(come?, task, model)
    {{task, index, model.now}, model}
  end

  defp model_plan({false, true, 1}, task, _index, model), do: {nil, model_skip(true, task, model)}

  defp model_plan({false, true, _sample}, task, index, model),
    do: {{task, index, model.next[task.name]}, model}

  defp model_plan({false, false, _sample}, _task, _index, model), do: {nil, model}

  defp model_skip(false, _task, model), do: model

  defp model_skip(true, task, model),
    do: %{
      model
      | next: Map.put(model.next, task.name, phase_after(model, task)),
        skipped: Map.update!(model.skipped, task.name, &(&1 + phase_points(model, task)))
    }

  # A run at its due time is periodic: the phase points from it up to now are the one run
  # and the periods it missed. A run at now that is no due time is an edge's, which moves
  # nothing.
  defp model_run(task, at, model, events) do
    periodic? = task.interval != nil and at == model.next[task.name] and at <= model.now
    model_periodic(periodic?, task, model, events)
  end

  defp model_periodic(false, _task, model, events), do: {model, events}

  defp model_periodic(true, task, model, events) do
    missed = phase_points(model, task) - 1

    model = %{
      model
      | next: Map.put(model.next, task.name, phase_after(model, task)),
        overlaps: Map.update!(model.overlaps, task.name, &(&1 + missed)),
        runs: Map.update!(model.runs, task.name, &(&1 + 1))
    }

    events = if missed > 0, do: [{:overlap, task.name, missed} | events], else: events
    {model, events}
  end

  defp model_scan(config, instance, task, {model, events}) do
    program = config.programs[instance.type]
    mine = for c <- config.connections, c.instance == instance.name, do: c
    section = fn c -> program.tags[c.member].section end

    inputs =
      for c <- mine,
          section.(c) == :var_input,
          into: %{},
          do: {c.member, if(is_binary(c.to), do: model.globals[c.to], else: c.to)}

    state = model.states[instance.name]

    {outputs, state} =
      Runtime.call(program, state, inputs, %Scan{now: model.now, first: state.first})

    bits_scanned(instance.type, inputs, outputs)

    globals =
      for c <- mine, section.(c) == :var_output, reduce: model.globals do
        globals -> Map.put(globals, c.to, outputs[c.member])
      end

    {%{model | states: Map.put(model.states, instance.name, state), globals: globals},
     [{:ran, task, instance.name, model.now} | events]}
  end

  # M5-8: a `bits` instance's outputs against an oracle that knows nothing of logex, a
  # word's bit 3 and its low byte, by division.
  defp bits_scanned("bits", %{"w" => w}, outputs) do
    assert outputs["out"] == rem(div(w, 8), 2)
    assert outputs["lo"] == rem(w, 256)
    config_reach(:word_bit, outputs["out"] == 1)
  end

  defp bits_scanned(_type, _inputs, _outputs), do: :ok

  defp config_walk(_config, _runtime, _model, 0), do: :ok

  defp config_walk(config, runtime, model, n) do
    case config_operation(:rand.uniform(8), config, runtime) do
      {:cycle, mistake?, elapsed, inputs} ->
        case config_attempt(fn -> Runtime.cycle(runtime, elapsed, inputs) end) do
          {:ok, {next, outputs, events}} ->
            before = model
            refute mistake?, "a host mistake was accepted: #{inspect({elapsed, inputs})}"
            samples!(config, runtime, inputs, events)

            {model, expected_outputs, expected_events} =
              model_cycle(config, model, elapsed, inputs)

            assert events == expected_events
            assert outputs == expected_outputs
            assert Runtime.overlaps(next) == model.overlaps
            observe(config, {before, model}, events, elapsed)
            check_model(config, next, model)
            config_walk(config, next, model, n - 1)

          :refused ->
            assert mistake?,
                   "a call without a host mistake was refused: #{inspect({elapsed, inputs})}"

            config_walk(config, runtime, model, n - 1)
        end

      {:get, mistake?, path} ->
        case config_attempt(fn -> Runtime.get!(runtime, path) end) do
          {:ok, value} ->
            refute mistake?, "a bad path was read: #{inspect(path)}"
            assert value == model_get(config, model, path)
            assert Runtime.get(runtime, path) == {:ok, value}

          :refused ->
            assert mistake?, "a good path was refused: #{inspect(path)}"
            refused_get(runtime, path)
        end

        config_walk(config, runtime, model, n - 1)

      {:bad_runtime, call} ->
        assert config_attempt(call) == :refused
        config_walk(config, runtime, model, n - 1)

      {:start, spoiled} ->
        assert config_attempt(fn -> Runtime.start(spoiled) end) == :refused
        config_walk(config, runtime, model, n - 1)

      {:restart, mistake?, mode} ->
        case config_attempt(fn -> Runtime.restart(runtime, mode) end) do
          {:ok, next} ->
            refute mistake?, "a bad restart was accepted: #{inspect(mode)}"
            model = model_restart(config, model, mode)
            config_reach(:restart, true)

            config_reach(
              :image_kept,
              Enum.any?(input_points(), &(Runtime.get!(next, &1) != 0))
            )

            check_restarted(config, next, model)
            Process.put(:config_samples, %{})
            Process.put(:config_fresh, :restart)
            config_walk(config, next, model, n - 1)

          :refused ->
            assert mistake?, "a good restart was refused: #{inspect(mode)}"
            config_walk(config, runtime, model, n - 1)
        end
    end
  end

  # Right after a restart, every task with an interval is due at once, so next_due_in/1 is
  # 0 if there is one and :infinity if not, however many event tasks there are (decision
  # 50), and every value is the model's.
  defp check_restarted(config, runtime, model) do
    periodic? = Enum.any?(config.tasks, &(&1.interval != nil))
    assert Runtime.next_due_in(runtime) == if(periodic?, do: 0, else: :infinity)
    assert Runtime.overlaps(runtime) == model.overlaps
    for {name, value} <- model.globals, do: assert(Runtime.get!(runtime, name) == value)

    for instance <- config.instances,
        {tag, value} <- model.states[instance.name].env,
        is_integer(value),
        do: assert(Runtime.get!(runtime, "#{instance.name}.#{tag}") == value)
  end

  # Everything the scheduler's rules say a model must also show: the next due time, every
  # global, and every tag of every instance.
  defp check_model(config, runtime, model) do
    next = model.next |> Map.values() |> Enum.reject(&is_nil/1) |> Enum.min(fn -> nil end)
    expected = if next == nil, do: :infinity, else: next - model.now
    assert Runtime.next_due_in(runtime) == expected
    # After a cycle no task is overdue: each it ran moved past now.
    assert expected == :infinity or expected > 0
    config_reach(:infinity, expected == :infinity)

    for {name, value} <- model.globals, do: assert(Runtime.get!(runtime, name) == value)

    for instance <- config.instances,
        {tag, value} <- model.states[instance.name].env,
        is_integer(value),
        do: assert(Runtime.get!(runtime, "#{instance.name}.#{tag}") == value)

    # Every period of a task up to now is either run, counted as missed or, for a task
    # with a single, skipped under a high trigger (decision 39): an oracle that knows
    # nothing of how the scheduler finds them. A task with a single alone has no periods
    # and never overlaps.
    for task <- config.tasks, task.interval != nil do
      assert model.runs[task.name] + model.overlaps[task.name] + model.skipped[task.name] ==
               div(model.now - model.anchor[task.name], task.interval) + 1
    end

    for task <- config.tasks, task.interval == nil, do: assert(model.overlaps[task.name] == 0)
  end

  # M2-6: oracles that know only each trigger's samples, read from outside before the
  # cycle through get!/2 and the inputs it sends, the last sample 0 after a start or a
  # restart: a task with a single alone runs exactly on its trigger's rising edges, and one
  # with an interval too on every edge, never while its trigger stays 1, and at most once a
  # cycle; and the tasks run in priority order. Its reach is the walk's.
  defp samples!(config, runtime, inputs, events) do
    seen = Process.get(:config_samples, %{})
    fresh = Process.get(:config_fresh, :start)

    samples =
      for task <- config.tasks,
          task.single != nil,
          into: %{},
          do: {task.name, Map.get(inputs, task.single, Runtime.get!(runtime, task.single))}

    ran = Enum.dedup(for {:ran, task, _, _} <- events, task != :none, do: task)
    running = MapSet.new(for i <- config.instances, i.task != nil, do: i.task)

    for task <- config.tasks, task.single != nil, MapSet.member?(running, task.name) do
      edge? = Map.get(seen, task.name, 0) == 0 and samples[task.name] == 1
      held? = Map.get(seen, task.name, 0) == 1 and samples[task.name] == 1
      runs = Enum.count(ran, &(&1 == task.name))
      assert runs <= 1, "#{task.name} ran #{runs} times in one cycle"
      if edge?, do: assert(runs == 1, "#{task.name} missed an edge")
      if held?, do: assert(runs == 0, "#{task.name} ran under a held trigger")
      if task.interval == nil, do: assert(runs == if(edge?, do: 1, else: 0))
      config_reach(:edge_event, edge? and task.interval == nil)
      config_reach(:edge_both, edge? and task.interval != nil)
      config_reach(:first_cycle_edge, edge? and fresh == :start)
      config_reach(:restart_refire, edge? and fresh == :restart)
      config_reach(:logic_trigger, edge? and task.single in ~w(o0 g0 g1) and fresh == false)
    end

    by_name = Map.new(config.tasks, &{&1.name, &1})
    order = for name <- ran, do: by_name[name]

    for [a, b] <- Enum.chunk_every(order, 2, 1, :discard) do
      assert a.priority <= b.priority

      config_reach(
        :tie_event_periodic,
        a.priority == b.priority and a.single == nil != (b.single == nil)
      )
    end

    Process.put(:config_samples, Map.merge(seen, samples))
    Process.put(:config_fresh, false)
  end

  defp observe(config, {before, model}, events, elapsed) do
    ran = for {:ran, task, instance, _} <- events, do: {task, instance}

    # M2-6: a due time skipped under a held trigger, one cycle's skips at an edge after a
    # late host (decision 51), a periodic run in a cycle that samples 0 of a due time that
    # came while the trigger was last seen 1 (decision 52), and an overlap of a task with
    # a single and an interval.
    for task <- config.tasks, task.single != nil and task.interval != nil do
      skipped = model.skipped[task.name] - before.skipped[task.name]
      ran? = Enum.any?(ran, &(elem(&1, 0) == task.name))
      config_reach(:held_skip, skipped > 0 and not ran?)
      config_reach(:late_edge_skip, skipped > 1 and ran?)

      config_reach(
        :falling_due,
        before.last[task.name] == 1 and model.last[task.name] == 0 and
          model.runs[task.name] > before.runs[task.name]
      )

      config_reach(
        :overlap_under_single,
        Enum.any?(events, &match?({:overlap, name, _} when name == task.name, &1))
      )
    end

    config_reach(:ran_task, Enum.any?(ran, &(elem(&1, 0) != :none)))
    config_reach(:ran_taskless, Enum.any?(ran, &(elem(&1, 0) == :none)))
    config_reach(:overlap, Enum.any?(events, &match?({:overlap, _, _}, &1)))
    config_reach(:overlap_many, Enum.any?(events, &match?({:overlap, _, m} when m > 1, &1)))
    config_reach(:no_task_due, config.tasks != [] and Enum.all?(ran, &(elem(&1, 0) == :none)))
    config_reach(:elapsed_zero, elapsed == 0 and model.cycles > 1)

    # Priority put a task declared later first; or, at one priority, an earlier due time
    # did.
    declared = config.tasks |> Enum.with_index() |> Map.new(fn {t, i} -> {t.name, {t, i}} end)
    order = for {task, _} <- Enum.dedup_by(ran, &elem(&1, 0)), task != :none, do: declared[task]
    indexes = Enum.map(order, &elem(&1, 1))
    config_reach(:priority_order, indexes != Enum.sort(indexes))

    # Two periodic runs of one priority, the one due earlier first; a task with a single
    # among them where it ran periodically (M2-6).
    periodic? = &(model.runs[&1.name] > before.runs[&1.name])

    config_reach(
      :due_time_order,
      Enum.any?(Enum.chunk_every(order, 2, 1, :discard), fn [{a, _}, {b, _}] ->
        a.priority == b.priority and periodic?.(a) and periodic?.(b) and
          before.next[a.name] < before.next[b.name]
      end)
    )

    config_reach(:read_back, Enum.any?(config.connections, &(&1.to in ~w(o0 a0))) and ran != [])
    config_reach(:constant, Enum.any?(config.connections, &is_integer(&1.to)) and ran != [])

    config_reach(
      :copy_out_seen,
      Enum.any?(
        config.connections,
        &(&1.to in ~w(g0 g1 n0) and model.globals[&1.to] != Map.get(@initials, &1.to, 0))
      )
    )

    config_reach(
      :first_scan_ons,
      Enum.any?(config.instances, &(&1.type == "pulse")) and model.cycles == 1
    )

    config_reach(
      :timer_done,
      Enum.any?(model.states, fn {_, s} -> match?(%{"t1" => %{"dn" => 1}}, s.env) end)
    )
  end

  defp config_reach(name, true), do: reached(:config_reach, name)
  defp config_reach(_name, false), do: :ok

  defp model_get(config, model, path) do
    case String.split(path, ".") do
      [global] ->
        model.globals[global]

      [instance | members] ->
        get_in(model.states[instance].env, members)
        |> then(&if(&1 == nil, do: 0, else: &1))
        |> tap(fn _ -> assert Enum.any?(config.instances, &(&1.name == instance)) end)
    end
  end

  # get/2 gives the reason get!/2 raises for a path that is a string (decision 41), and
  # raises for one that is not, as get!/2 does.
  defp refused_get(runtime, path) when is_binary(path) do
    error = assert_raise ArgumentError, fn -> Runtime.get!(runtime, path) end
    assert Runtime.get(runtime, path) == {:error, error.message}
  end

  defp refused_get(runtime, path),
    do: assert_raise(ArgumentError, fn -> Runtime.get(runtime, path) end)

  # One operation: a cycle, good or bad; a read, good or bad; or a call on something that
  # is not a runtime.
  defp config_operation(kind, _config, _runtime) when kind in [1, 2, 3] do
    elapsed =
      pick([0, 0, 1, 5, 5, 10, 10, 13, 30, 47, 100] ++ if(kind == 3, do: [-1, 1.5], else: []))

    {inputs, bad?} = config_inputs(kind == 3)
    {:cycle, bad? or not (is_integer(elapsed) and elapsed >= 0), elapsed, inputs}
  end

  defp config_operation(4, config, _runtime) do
    good =
      Enum.map(@points, &elem(&1, 0)) ++
        for instance <- config.instances,
            tag <- Map.keys(config.programs[instance.type].tags),
            tag not in ["t1"],
            do: "#{instance.name}.#{tag}"

    timers =
      for i <- config.instances,
          i.type == "timer",
          m <- ~w(pre acc dn tt en),
          do: "#{i.name}.t1.#{m}"

    {:get, false, pick(good ++ timers)}
  end

  defp config_operation(5, config, _runtime) do
    instance = pick(config.instances).name

    bad =
      [5, "", "a..b", "a b", "zz", "i0.x", instance, "#{instance}.zz", "#{instance}.in.x"] ++
        ["plant" | Enum.map(config.tasks, & &1.name)] ++
        for i <- config.instances,
            i.type == "timer",
            p <- ["t1", "t1.last", "t1.Acc", "t1.acc.x"],
            do: "#{i.name}.#{p}"

    {:get, true, pick(bad)}
  end

  defp config_operation(6, config, _runtime) do
    junk = pick([5, nil, %{}, config])

    {:bad_runtime,
     pick([
       fn -> Runtime.cycle(junk, 0, %{}) end,
       fn -> Runtime.get!(junk, "i0") end,
       fn -> Runtime.get(junk, "i0") end,
       fn -> Runtime.next_due_in(junk) end,
       fn -> Runtime.overlaps(junk) end,
       fn -> Runtime.restart(junk, :cold) end
     ])}
  end

  defp config_operation(7, _config, _runtime) do
    mode = pick([:cold, :warm, :cold, :warm, :hot, nil])
    {:restart, mode not in [:cold, :warm], mode}
  end

  # The configuration started again with one mistake: a fractional priority, a line no
  # file gives or a single that is no name, which no configuration text can say, or a
  # priority past 65535, an interval of 0 or a single that names no bool global, which a
  # text can (decisions 36 and 37; M2-6). A negative priority was the first until a
  # negative literal lexed (M3-3, decision 97): a text can say one now.
  defp config_operation(8, config, _runtime) do
    task = fn single, interval, priority ->
      %{
        config
        | tasks:
            config.tasks ++
              [
                %Logex.Configuration.Task{
                  name: "t9",
                  single: single,
                  interval: interval,
                  priority: priority
                }
              ]
      }
    end

    [first | rest] = config.globals

    {:start,
     pick([
       task.(nil, 10, 1.5),
       task.(nil, 10, 65_536),
       task.(nil, 0, 0),
       task.("i0", 0, 0),
       task.("d0", nil, 0),
       task.("zz", nil, 1),
       task.(7, 10, 0),
       %{config | globals: [%{first | line: 3} | rest]},
       %{config | globals: [%{first | line: 0} | rest]}
     ])}
  end

  # Inputs: a few input points with values that fit, and, for a bad step, one mistake.
  defp input_value(:bool), do: pick([0, 1])
  defp input_value(:dint), do: pick([0, 20, 40, -5])
  defp input_value(:word), do: pick([0, 8, 9, 0x00F7, 0xFFFF, 0x1234])

  defp config_inputs(false) do
    inputs =
      for {name, type, at} <- @points,
          at != nil and String.contains?(at, ".i."),
          :rand.uniform(3) == 1,
          into: %{},
          do: {name, input_value(type)}

    {inputs, false}
  end

  defp config_inputs(true) do
    {good, false} = config_inputs(false)

    bad =
      pick([
        {7, 1},
        {"o0", 1},
        {"g0", 1},
        {"m1.in", 1},
        {"m1", 1},
        {"m2", 1},
        {"fast", 1},
        {"plant", 1},
        {"zz", 1},
        {"i0", 2},
        {"d0", 1.5},
        {"d0", 3_000_000_000},
        {"w0", 65_536},
        {"w0", -1}
      ])

    case pick([:pair, :pair, :pair, :list]) do
      :pair -> {Map.put(good, elem(bad, 0), elem(bad, 1)), true}
      :list -> {[{"i0", 1}], true}
    end
  end

  defp config_attempt(fun) do
    result = fun.()
    assert fun.() == result, "the same call gave two results"
    {:ok, result}
  rescue
    error in ArgumentError ->
      for line <- String.split(error.message, "\n") do
        kind = Enum.find(@config_refusals, fn {_, words} -> String.contains?(line, words) end)
        assert kind, "undocumented refusal: #{line}"
        reached(:config_refused, elem(kind, 0))
      end

      :refused
  end

  # ---- M2-5: the walk with online edits of programs that hold blocks --------------------

  # Versions of a block `blk`, of a block `wrap` that holds one, and programs that hold
  # either, drawn so that two programs share their names: a body changed in its `ons` rung,
  # a member added with an initial value that changes, a member whose kind changes, and a
  # timer added, dropped or given one of three presets, or whose `.pre` logic moves; `wrap`
  # runs its `blk` always, under
  # a condition, under a one-shot of its own, or not at all; a program runs `x` under a
  # condition or not, holds a `wrap`, or a second `blk` it runs or does not.
  @fb_blk [
    "var e bool\nxic go ons e ote p",
    "var e bool\nxio go ons e ote p",
    "var e bool\nvar n dint 2\nxic go ons e ote p\nxic go move 3 n",
    "var e dint\nxic go move 1 e\nxic go ote p",
    "var t1 ton\nxic go ton t1 50\nxic t1.dn ote p",
    "var t1 ton\nxic go ton t1 80\nxic t1.dn ote p",
    "var e bool\nvar t1 ton\nxic go ons e ote p\nxic go ton t1 50",
    "var e bool\nvar n dint 5\nxic go ons e ote p\nxic go move 3 n",
    "var e bool\nvar t1 ton\nxic go ons e ote p\nxic t1.dn ote p",
    "var t1 ton\nxic go ton t1 20\nxic t1.dn ote p",
    "var t1 ton\nxic go ton t1 50\nxic go move 7 t1.pre\nxic t1.dn ote p"
  ]

  @fb_wrap [
    "cal inner a q",
    "xic a cal inner a q",
    "var k bool\nxic a ons k cal inner a q",
    "xic a ote q"
  ]

  @fb_head "var_input g bool\nvar_input h bool\nvar_input en bool\nvar_output p bool\nvar_output q bool\n"

  @fb_programs [
    "var x blk\nxic en cal x g p",
    "var x blk\nvar w wrap\nxic en cal x g p\ncal w h q",
    "var x blk\nvar w wrap\ncal x g p\ncal w h q",
    "var x blk\nvar w wrap\nxic g ote p\ncal w h q",
    "var w wrap\nxic g ote p\nxic en cal w h q",
    "var x blk\nvar w wrap\nvar y blk\nxic en cal x g p\nxic en cal w h q\ncal y h q",
    "var x blk\nvar y blk\nvar w wrap\nxic en cal x g p\ncal w g q"
  ]

  # What the walk must see happen, and its oracles check, at least once each: every switch
  # and prune, a report kind by a path inside an instance, a refused member kind change, a
  # round trip, and a scan right after a switch where an `ons` whose chain of rungs changed
  # ran, one and two levels down.
  @fb_reach [
    :test,
    :untest,
    :assemble,
    :cancel,
    :refused,
    :round_trip,
    :round_trip_timer,
    :ons_x_changed_ran,
    :ons_inner_changed_ran,
    :ons_x_changed_late,
    :ons_inner_changed_late,
    {:nested, :added},
    {:nested, :dn_drops},
    {:nested, :dn_rises},
    {:nested, :initial_changed},
    {:nested, :ons_blocked},
    {:nested, :preset},
    {:nested, :preset_kept},
    {:nested, :pruned},
    {:nested, :resume_undone},
    {:nested, :resumed},
    # Decision 96: a block's `.pre` its body moves a value into, and the other version not.
    {:nested, :unwritten}
  ]

  # Under which chain of rungs each one-shot last ran, none known yet (below).
  @fb_unknown %{x: :any, inner: :any}

  defp fb_programs do
    for {b, bi} <- Enum.with_index(@fb_blk),
        {wr, wi} <- Enum.with_index(@fb_wrap),
        {pr, pi} <- Enum.with_index(@fb_programs),
        {:ok, blk} =
          Logex.compile("function_block blk\nvar_input go bool\nvar_output p bool\n" <> b,
            name: "blk"
          ),
        {:ok, wrap} =
          Logex.compile(
            "function_block wrap\nvar_input a bool\nvar_output q bool\nvar inner blk\n" <> wr,
            name: "wrap",
            types: [blk]
          ),
        {:ok, program} <- [Logex.compile(@fb_head <> pr, name: "m", types: [blk, wrap])],
        do: {{bi, wi, pi}, program}
  end

  # Its reach holds at this seed and at each of the seeds 1 to 30 in its place. Its rarest
  # atoms, a one-shot two levels down checked on a later scan, a nested `:dn_rises` and a
  # nested `:resume_undone`, came 7 to 18, 6 to 20 and 7 to 32 times a run over those 31,
  # and a nested `:preset_kept` 173 to 302.
  # Drawn as the design pass drew them, 800 walks, two presets, steps mostly past both,
  # and a candidate drawn mostly with the running block's version, a nested `:dn_rises`
  # came one to four times a run, and three seeds of the 30 missed it.
  test "an online edit of a program that holds blocks: each report's writes rebuild the " <>
         "state by path, a switch leaves every member present, a prune leaves no other, a " <>
         "round trip gives every value back, and no one-shot fires on a changed chain" do
    :rand.seed(:exsss, {2026, 10, 2})
    programs = fb_programs()

    for _ <- 1..1600 do
      {key, program} = pick(programs)
      w = %{p: program, s: Runtime.instance(program), e: nil, key: key, c: nil, last: key}
      fb_walk(Map.merge(w, %{round: nil, after: false, wrote: @fb_unknown}), programs, 100)
    end

    assert Process.get(:fb_reach, MapSet.new()) == MapSet.new(@fb_reach)
  end

  defp fb_walk(w, _programs, 0), do: w

  defp fb_walk(w, programs, n),
    do:
      fb_walk(
        fb_op(pick(~w(scan scan scan accept test untest assemble cancel restart)a), w, programs),
        programs,
        n - 1
      )

  defp fb_running(%{e: nil, p: p}), do: p
  defp fb_running(%{e: edit}), do: Edit.running(edit)

  defp fb_key(%{e: nil, key: key}), do: key
  defp fb_key(%{e: edit, key: key, c: c}), do: fb_key(Edit.stage(edit), key, c)
  defp fb_key(:testing, _key, c), do: c
  defp fb_key(_stage, key, _c), do: key

  defp fb_op(:scan, w, _programs) do
    program = fb_running(w)

    inputs =
      for {name, %Tag{section: :var_input}} <- program.tags,
          :rand.uniform(3) == 1,
          into: %{},
          do: {name, pick([0, 1])}

    # Inputs change one time in three and time moves in steps of up to 60 ms, often short,
    # so a timer inside a block is done, or timing between two presets, when an edit moves
    # its `.pre`.
    {_outputs, later} =
      Runtime.scan(
        program,
        Runtime.put_inputs(program, w.s, inputs),
        pick([0, 10, 10, 20, 30, 60])
      )

    wrote = fb_pulses!(w, fb_key(w), later)
    %{w | s: later, round: nil, after: false, last: fb_key(w), wrote: wrote}
  end

  defp fb_op(:restart, w, _programs) do
    s = Runtime.restart(fb_running(w), w.s, pick([:cold, :warm]))
    %{w | s: s, round: nil, wrote: @fb_unknown}
  end

  # A candidate is, a third of the time each, any program, one with the running block's
  # version, or the running one with only its block's version drawn again.
  defp fb_op(:accept, %{e: nil, key: {b, wr, pr}} = w, programs) do
    same_block = for {{^b, _, _}, _} = entry <- programs, do: entry
    same_rest = for {{_, ^wr, ^pr}, _} = entry <- programs, do: entry
    {key, candidate} = pick(pick([programs, same_block, same_rest]))
    fb_accepted(Edit.accept(w.p, candidate, w.s), key, w)
  end

  defp fb_op(:test, w, _programs) when w.e != nil do
    fb_switch(Edit.stage(w.e) in [:accepted, :untested], :test, w)
  end

  defp fb_op(:untest, w, _programs) when w.e != nil do
    fb_switch(Edit.stage(w.e) == :testing, :untest, w)
  end

  defp fb_op(:assemble, w, _programs) when w.e != nil,
    do: fb_prune(Edit.stage(w.e) == :testing, :assemble, w)

  defp fb_op(:cancel, w, _programs) when w.e != nil,
    do: fb_prune(Edit.stage(w.e) in [:accepted, :untested], :cancel, w)

  defp fb_op(_op, w, _programs), do: w

  defp fb_accepted({:ok, edit, _forecast}, key, w), do: %{w | e: edit, c: key, round: nil}

  defp fb_accepted({:error, diagnostics}, _key, w) do
    assert Enum.all?(diagnostics, &match?(%Diagnostic{stage: :edit}, &1))
    fb_reach(:refused)
    w
  end

  defp fb_switch(false, _step, w), do: w

  defp fb_switch(true, step, w) do
    stage = Edit.stage(w.e)
    {edit, later, report} = apply(Edit, step, [w.e, w.s])
    fb_rebuilt!(step, w.s, later, report)
    assert Enum.sort(names(report, :ons_blocked)) == Enum.sort(later.ons_blocked)
    started = Program.initial_env(Edit.running(edit))
    assert fb_missing(fb_leaves(started), later.env) == []
    fb_round!(step, stage, w.round, later, report)
    round = fb_round(step, w.s, report)
    %{w | e: edit, s: later, round: round, after: true}
  end

  defp fb_prune(false, _step, w), do: w

  defp fb_prune(true, step, w) do
    {kept, later, report} = apply(Edit, step, [w.e, w.s])
    fb_rebuilt!(step, w.s, later, report)
    assert fb_missing(fb_leaves(later.env), Program.initial_env(kept)) == []
    key = fb_kept(step, w)
    %{w | e: nil, p: kept, s: later, key: key, round: nil}
  end

  defp fb_kept(:assemble, w), do: w.c
  defp fb_kept(:cancel, w), do: w.key

  # The writes a report lists, applied by path to the state before its step.
  defp fb_rebuilt!(step, before, later, report) do
    fb_reach(step)
    for {kind, name, _} <- report, String.contains?(name, "."), do: fb_reach({:nested, kind})
    assert Enum.reduce(report, before.env, &fb_write/2) == later.env
  end

  defp fb_path(name), do: String.split(name, ".")

  defp fb_write({kind, name, value}, env) when kind in [:added, :input],
    do: put_in(env, Enum.map(fb_path(name), &Access.key(&1, %{})), value)

  defp fb_write({:preset, name, {_from, to}}, env), do: put_in(env, fb_path(name) ++ ["pre"], to)

  defp fb_write({:resumed, name, gap}, env),
    do: update_in(env, fb_path(name) ++ ["last"], &(&1 + gap))

  defp fb_write({:resume_undone, name, gap}, env),
    do: update_in(env, fb_path(name) ++ ["last"], &(&1 - gap))

  defp fb_write({:pruned, name, _value}, env) do
    {parent, [leaf]} = Enum.split(fb_path(name), -1)
    fb_drop(parent, leaf, env)
  end

  defp fb_write(_fact, env), do: env

  defp fb_drop([], leaf, env), do: Map.delete(env, leaf)
  defp fb_drop(parent, leaf, env), do: update_in(env, parent, &Map.delete(&1, leaf))

  defp fb_leaves(map, prefix \\ []),
    do:
      Enum.flat_map(map, fn
        {key, %{} = inner} -> fb_leaves(inner, prefix ++ [key])
        {key, value} -> [{prefix ++ [key], value}]
      end)

  defp fb_missing(leaves, env), do: for({path, _} <- leaves, get_in(env, path) == nil, do: path)

  # A test then an untest with no scan between leaves every value as it was, but for what
  # either switch started, found from the reports' starts alone: a timer included.
  defp fb_round(:test, before, report), do: {before, report}
  defp fb_round(:untest, _before, _report), do: nil

  defp fb_round!(:untest, :testing, {before, tested}, later, untested) do
    started =
      for {kind, name, _} <- tested ++ untested, kind in [:added, :input], do: fb_path(name)

    changed =
      for {path, value} <- fb_leaves(before.env),
          not Enum.any?(started, &List.starts_with?(path, &1)),
          get_in(later.env, path) != value,
          do: {path, value}

    assert changed == []
    fb_reach(:round_trip)

    timer? = Enum.any?(fb_leaves(before.env), fn {path, _} -> List.last(path) == "last" end)
    fb_reach(:round_trip_timer, timer?)
  end

  defp fb_round!(_step, _stage, _round, _later, _report), do: :ok

  # Decision 21's oracle, from the programs' text alone: a one-shot of `blk` that runs
  # under a chain of rungs, from the program's `cal` down to the body's `ons` rung, other
  # than the one it last ran under passes no power; and `blk`'s output, where only that
  # rung writes it, is then 0. The chain is each rung's text: the `ons` rung of each
  # version, or none. Under which chain each one-shot last ran is known from the walk
  # alone: none after a start or a restart, whose first run fires (PLAN M2-5, `first` is
  # the program's), and unknown where a `wrap` runs its `blk` under a one-shot of its own.
  # It fails where a block is used up by a scan whose `cal` was false (a pulse after it).
  @fb_ons_text %{
    0 => "xic go ons e ote p",
    1 => "xio go ons e ote p",
    2 => "xic go ons e ote p",
    6 => "xic go ons e ote p",
    7 => "xic go ons e ote p",
    8 => "xic go ons e ote p"
  }

  # The versions whose output only the `ons` rung writes.
  @fb_observable [0, 1, 2, 6, 7]

  defp fb_pulses!(%{s: %Instance{first: true}, wrote: wrote}, {_b, wr, pr} = key, later),
    do: %{
      x: fb_ran(fb_x_ran(pr, later.env), fb_x_chain(key), wrote.x),
      inner: fb_ran(fb_inner_ran(wr, pr, later.env), fb_inner_chain(key), wrote.inner)
    }

  defp fb_pulses!(%{wrote: wrote, after: switched}, {b, wr, pr} = key, later) do
    body = b in @fb_observable
    x_ran = fb_x_ran(pr, later.env)
    x_chain = fb_x_chain(key)
    late = fb_late(switched, :ons_x_changed_late)

    fb_pulse!(
      [:ons_x_changed_ran | late],
      body && x_ran == true,
      wrote.x not in [:any, x_chain],
      later.env["x"]
    )

    inner_ran = fb_inner_ran(wr, pr, later.env)
    inner_chain = fb_inner_chain(key)
    late = fb_late(switched, :ons_inner_changed_late)

    fb_pulse!(
      [:ons_inner_changed_ran | late],
      body && inner_ran == true,
      wrote.inner not in [:any, inner_chain],
      later.env["w"]["inner"]
    )

    %{x: fb_ran(x_ran, x_chain, wrote.x), inner: fb_ran(inner_ran, inner_chain, wrote.inner)}
  end

  # A pulse checked on a later scan than the one right after a switch, its `cal` false on
  # those between.
  defp fb_late(true, _atom), do: []
  defp fb_late(false, atom), do: [atom]

  # Whether each instance's body ran: true, false, or :unknown where it ran under a
  # one-shot of `wrap`'s own.
  defp fb_x_ran(pr, env), do: pr == 2 or (pr in [0, 1, 5, 6] and env["en"] == 1)

  defp fb_inner_ran(wr, pr, env) when wr in [0, 1],
    do: fb_wrap_ran(pr, env) and (wr == 0 or env["w"]["a"] == 1)

  defp fb_inner_ran(2, pr, env), do: fb_wrap_ran(pr, env) and :unknown
  defp fb_inner_ran(_wr, _pr, _env), do: false

  defp fb_ran(true, chain, _wrote), do: chain
  defp fb_ran(false, _chain, wrote), do: wrote
  defp fb_ran(:unknown, _chain, _wrote), do: :any

  defp fb_wrap_ran(pr, _env) when pr in [1, 2, 3, 6], do: true
  defp fb_wrap_ran(pr, env) when pr in [4, 5], do: env["en"] == 1
  defp fb_wrap_ran(_pr, _env), do: false

  defp fb_pulse!(atoms, ran, true, %{"p" => p}) when ran in [true] do
    assert p == 0
    Enum.each(atoms, &fb_reach/1)
  end

  defp fb_pulse!(_atom, _ran, _changed, _instance), do: :ok

  defp fb_x_chain({b, _wr, pr}),
    do: {Enum.at(~w(xen xen bare none xnone xen xen), pr), Map.get(@fb_ons_text, b)}

  defp fb_inner_chain({b, wr, pr}),
    do: {Enum.at(~w(none h h h en en g), pr), Enum.at(@fb_wrap, wr), Map.get(@fb_ons_text, b)}

  defp fb_reach(atom), do: reached(:fb_reach, atom)

  defp fb_reach(atom, true), do: fb_reach(atom)
  defp fb_reach(_atom, false), do: :ok

  # ---- M2-4: globals shared through var_external, against a model of one map ----------

  # Each program type, and what one scan of it does to the globals and its own state, as
  # Elixir: `{globals, own}` from `{globals, own, inputs, first}`, `inputs` its var_inputs
  # as copied in. A var_external is the global itself, read and written in place, the
  # pointer reading of IEC and MatIEC: the model knows nothing of a merge or a split.
  @ext_types %{
    "copy" => "var_external i0 bool\nvar_external g0 bool\nxic i0 ote g0",
    "chain" =>
      "var_external g0 bool\nvar_external g1 bool\nvar_external q0 bool\nxic g0 ote g1\n" <>
        "xic g1 ote q0",
    "latch" =>
      "var_external i1 bool\nvar_external g1 bool\nvar_external i0 bool\nxic i1 otl g1\n" <>
        "xic i0 otu g1",
    "pulse" => "var_external g0 bool\nvar_external q1 bool\nvar s bool\nxic g0 ons s ote q1",
    "mover" =>
      "var_external d0 dint\nvar_external n0 dint\nvar_external a0 dint\n" <>
        "gt d0 10 move d0 n0\nmove n0 a0",
    "mixed" =>
      "var_input in bool\nvar_output out bool\nvar_external g0 bool\nxic in ote g0\n" <>
        "xio g0 ote out"
  }

  defp ext_run("copy", {gl, own, _in, _first}), do: {Map.put(gl, "g0", gl["i0"]), own}

  defp ext_run("chain", {gl, own, _in, _first}) do
    gl = Map.put(gl, "g1", gl["g0"])
    {Map.put(gl, "q0", gl["g1"]), own}
  end

  defp ext_run("latch", {gl, own, _in, _first}) do
    gl = ext_when(gl["i1"] == 1, gl, "g1", 1)
    {ext_when(gl["i0"] == 1, gl, "g1", 0), own}
  end

  defp ext_run("pulse", {gl, own, _in, first}) do
    fired = gl["g0"] == 1 and own["s"] == 0 and not first
    {Map.put(gl, "q1", ext_bit(fired)), %{"s" => gl["g0"]}}
  end

  defp ext_run("mover", {gl, own, _in, _first}) do
    gl = ext_when(gl["d0"] > 10, gl, "n0", gl["d0"])
    {Map.put(gl, "a0", gl["n0"]), own}
  end

  defp ext_run("mixed", {gl, own, inputs, _first}) do
    gl = Map.put(gl, "g0", inputs["in"])
    {gl, Map.put(own, "out", ext_bit(gl["g0"] == 0))}
  end

  defp ext_when(true, gl, name, value), do: Map.put(gl, name, value)
  defp ext_when(false, gl, _name, _value), do: gl

  defp ext_bit(true), do: 1
  defp ext_bit(false), do: 0

  @ext_globals [
    {"i0", :bool, "panel.i.0", nil},
    {"i1", :bool, "panel.i.1", nil},
    {"d0", :dint, "drive.i.0", nil},
    {"g0", :bool, nil, nil},
    {"g1", :bool, nil, 1},
    {"n0", :dint, nil, 7},
    {"q0", :bool, "panel.q.0", nil},
    {"q1", :bool, "panel.q.1", nil},
    {"a0", :dint, "drive.q.0", nil}
  ]

  @ext_reach ~w(restart saw_earlier_write missed_later_write output_via_external
                copy_out_over_external pulse_fired dint_moved not_due)a

  # 120 configurations of up to six instances of the types above, 40 steps each: a cycle,
  # or now and then a restart. After each, every global, every var_external of every
  # instance read as its instance's path, every tag of its own, and no var_external held
  # in any instance's state, against the model; and the reach asserted whole: a global
  # another instance changed earlier in the cycle read through a var_external, a write a
  # reader earlier in the cycle missed, an output point written through one, a copy-out
  # over the same scan's write through one, a one-shot fired, a dint moved, a task not due.
  test "a resource whose programs share globals through var_external runs as a model of " <>
         "one map of globals says, with one copy of each" do
    programs =
      Map.new(@ext_types, fn {name, source} ->
        {:ok, program} = Logex.compile(source, name: name)
        {name, program}
      end)

    :rand.seed(:exsss, {2026, 10, 424})

    for _ <- 1..120 do
      config = ext_config(programs)
      ext_walk(config, Runtime.start(config), ext_model(config), 40)
    end

    assert Process.get(:ext_reach, MapSet.new()) == MapSet.new(@ext_reach)
  end

  defp ext_reach(name, true), do: reached(:ext_reach, name)
  defp ext_reach(_name, false), do: :ok

  defp ext_config(programs) do
    tasks =
      for name <- Enum.take(Enum.shuffle(~w(fast mid slow)), :rand.uniform(4) - 1),
          do: %Logex.Configuration.Task{
            name: name,
            interval: pick([5, 10, 15, 30]),
            priority: pick([0, 1, 1, 2])
          }

    instances =
      for name <- Enum.take(Enum.shuffle(~w(m1 m2 m3 m4 m5 m6)), :rand.uniform(6)),
          do: %Logex.Configuration.Instance{
            name: name,
            type: pick(Map.keys(@ext_types)),
            task: pick([nil | Enum.map(tasks, & &1.name)])
          }

    # A mixed instance copies `in` from a bool global or a constant, and drives `out` into
    # an unlocated global or an output point no other connection drives.
    {connections, _sinks} =
      Enum.flat_map_reduce(instances, ~w(g0 g1 q0 q1), &ext_wire/2)

    used = MapSet.new(instances, & &1.type)

    Logex.Configuration.new!(
      name: "plant",
      programs: for({name, p} <- programs, name in used, do: p),
      tasks: tasks,
      globals:
        for(
          {name, type, at, initial} <- @ext_globals,
          do: %Logex.Configuration.Global{name: name, type: type, at: at, initial: initial}
        ),
      instances: instances,
      connections: connections
    )
  end

  defp ext_wire(%Logex.Configuration.Instance{type: "mixed", name: name}, sinks) do
    source = %Logex.Configuration.Connection{
      instance: name,
      member: "in",
      to: pick(~w(i0 i1 g0 g1 q0) ++ [0, 1])
    }

    ext_sink(sinks, source, name)
  end

  defp ext_wire(_instance, sinks), do: {[], sinks}

  defp ext_sink([], source, _name), do: {[source], []}

  defp ext_sink(sinks, source, name) do
    sink = pick(sinks)

    {[source, %Logex.Configuration.Connection{instance: name, member: "out", to: sink}],
     sinks -- [sink]}
  end

  defp ext_initial(name),
    do: Enum.find_value(@ext_globals, fn {n, _, _, i} -> n == name and (i || 0) end)

  defp ext_input?(name),
    do: Enum.any?(@ext_globals, fn {n, _, at, _} -> n == name and at != nil and at =~ ".i." end)

  defp ext_model(config),
    do: %{
      now: 0,
      globals: Map.new(@ext_globals, fn {n, _, _, i} -> {n, i || 0} end),
      own: Map.new(config.instances, &{&1.name, ext_own(&1.type)}),
      first: Map.new(config.instances, &{&1.name, true}),
      next: Map.new(config.tasks, &{&1.name, 0}),
      writer: %{},
      read: %{}
    }

  defp ext_own("pulse"), do: %{"s" => 0}
  defp ext_own("mixed"), do: %{"out" => 0}
  defp ext_own(_type), do: %{}

  defp ext_walk(_config, _runtime, _model, 0), do: :ok

  defp ext_walk(config, runtime, model, n) do
    {runtime, model} = ext_step(:rand.uniform(12), config, runtime, model)
    ext_check(config, runtime, model)
    ext_walk(config, runtime, model, n - 1)
  end

  defp ext_step(1, config, runtime, model) do
    mode = pick([:cold, :warm])

    model = %{
      model
      | globals:
          Map.new(model.globals, fn {g, v} -> {g, ext_kept(ext_input?(g), v, ext_initial(g))} end),
        own: Map.new(config.instances, &{&1.name, ext_own(&1.type)}),
        first: Map.new(config.instances, &{&1.name, true}),
        next: Map.new(config.tasks, &{&1.name, model.now})
    }

    ext_reach(:restart, true)
    {Runtime.restart(runtime, mode), model}
  end

  defp ext_step(_cycle, config, runtime, model) do
    elapsed = pick([0, 1, 5, 5, 10, 10, 15, 30, 47])

    inputs =
      for {name, type, at, _} <- @ext_globals,
          at != nil and at =~ ".i.",
          :rand.uniform(2) == 1,
          into: %{},
          do: {name, ext_input(type)}

    {runtime, outputs, events} = Runtime.cycle(runtime, elapsed, inputs)
    {model, ran} = ext_cycle(config, model, elapsed, inputs)
    assert for({:ran, task, instance, _} <- events, do: {task, instance}) == ran

    assert outputs ==
             for(
               {name, _, at, _} <- @ext_globals,
               at != nil and at =~ ".q.",
               into: %{},
               do: {name, model.globals[name]}
             )

    {runtime, model}
  end

  defp ext_kept(true, value, _initial), do: value
  defp ext_kept(false, _value, initial), do: initial

  defp ext_input(:bool), do: pick([0, 1])
  defp ext_input(:dint), do: pick([0, 5, 11, 40])

  defp ext_cycle(config, model, elapsed, inputs) do
    now = model.now + elapsed
    model = %{model | now: now, globals: Map.merge(model.globals, inputs), writer: %{}, read: %{}}

    due =
      config.tasks
      |> Enum.with_index()
      |> Enum.filter(fn {task, _} -> model.next[task.name] <= now end)
      |> Enum.sort_by(fn {task, index} -> {task.priority, model.next[task.name], index} end)
      |> Enum.map(&elem(&1, 0))

    ext_reach(:not_due, length(due) < length(config.tasks) and due != [])

    {model, ran} =
      Enum.reduce(due, {model, []}, fn task, {model, ran} ->
        periods = div(now - model.next[task.name], task.interval)
        next = model.next[task.name] + (periods + 1) * task.interval
        model = %{model | next: Map.put(model.next, task.name, next)}

        Enum.reduce(
          for(i <- config.instances, i.task == task.name, do: i),
          {model, ran},
          &ext_scan(config, &1, task.name, &2)
        )
      end)

    {model, ran} =
      Enum.reduce(
        for(i <- config.instances, i.task == nil, do: i),
        {model, ran},
        &ext_scan(config, &1, :none, &2)
      )

    {model, Enum.reverse(ran)}
  end

  defp ext_scan(config, instance, task, {model, ran}) do
    mine = for c <- config.connections, c.instance == instance.name, do: c

    inputs =
      for c <- mine,
          c.member == "in",
          into: %{},
          do: {"in", ext_source(c.to, model.globals)}

    {written, own} =
      ext_run(
        instance.type,
        {model.globals, model.own[instance.name], inputs, model.first[instance.name]}
      )

    globals =
      for c <- mine, c.member == "out", reduce: written do
        globals -> Map.put(globals, c.to, own["out"])
      end

    externals =
      for {name, %Tag{section: :var_external}} <- config.programs[instance.type].tags,
          do: name

    changed = for {g, v} <- written, v != model.globals[g], do: g
    others = for {g, w} <- model.writer, w != instance.name, do: g
    ext_reach(:saw_earlier_write, Enum.any?(externals, &(&1 in others)))

    ext_reach(
      :missed_later_write,
      Enum.any?(changed, &(Map.get(model.read, &1, instance.name) != instance.name))
    )

    ext_reach(:output_via_external, Enum.any?(changed, &(&1 in ~w(q0 q1 a0))))

    ext_reach(
      :copy_out_over_external,
      Enum.any?(
        mine,
        &(&1.member == "out" and written[&1.to] != own["out"] and &1.to in externals)
      )
    )

    ext_reach(:pulse_fired, instance.type == "pulse" and written["q1"] == 1)
    ext_reach(:dint_moved, "n0" in changed)

    model = %{
      model
      | writer: Enum.reduce(changed, model.writer, &Map.put(&2, &1, instance.name)),
        read: Enum.reduce(externals, model.read, &Map.put(&2, &1, instance.name))
    }

    {%{
       model
       | globals: globals,
         own: Map.put(model.own, instance.name, own),
         first: Map.put(model.first, instance.name, false)
     }, [{task, instance.name} | ran]}
  end

  defp ext_source(to, globals) when is_binary(to), do: globals[to]
  defp ext_source(constant, _globals), do: constant

  # Every global; every var_external of every instance, read as its global; every own
  # tag; and no var_external in any instance's state, the opaque resource looked into on
  # purpose (decision 49), since no public call can see a stale copy.
  defp ext_check(config, runtime, model) do
    for {name, value} <- model.globals, do: assert(Runtime.get!(runtime, name) == value, name)

    for instance <- config.instances do
      program = config.programs[instance.type]
      %Runtime{instances: %{} = states} = runtime
      %Instance{env: env} = Map.fetch!(states, instance.name)

      for {name, %Tag{section: :var_external}} <- program.tags do
        assert Runtime.get!(runtime, "#{instance.name}.#{name}") == model.globals[name]
        refute Map.has_key?(env, name), "#{instance.name} holds #{name}"
      end

      for {name, value} <- model.own[instance.name],
          do: assert(Runtime.get!(runtime, "#{instance.name}.#{name}") == value)
    end
  end

  # ---- OE-2: the walk over a configuration's edit ----------------------------------------

  # The host's mistakes a configuration's edit refuses, and the runtime's and start/1's it
  # passes on, by their first words.
  @ce_refusals [
    {:runtime, "expected a %Logex.Runtime{} from Logex.Runtime.start/1"},
    {:not_a_configuration, "expected a %Logex.Configuration{} from"},
    {:not_an_edit, "expected a %Logex.Configuration.Edit{}"},
    {:name, "the candidate is `"},
    {:generation, "this edit expects the resource at generation"},
    {:configuration, "this edit is of another configuration"},
    {:untest_stage, "untest takes an edit"},
    {:test_stage, "test takes an edit"},
    {:assemble_stage, "assemble takes an edit"},
    {:cancel_stage, "cancel takes an edit"},
    {:invalid, "no task `"}
  ]

  # What accept refuses, by the words of each message, as the walk predicts it.
  @ce_diagnostics [
    :kind,
    :task_added,
    :task_removed,
    :single,
    :event_interval,
    :moved,
    :global_type,
    :located,
    :located_new,
    :located_removed,
    :tag_type
  ]

  @ce_reach [
    :forecast,
    :round_trip,
    :round_trip_back,
    :round_trip_started,
    :round_trip_joined,
    :unscanned_switch,
    :restart_in_edit,
    :stale,
    :assembled,
    :cancelled_accepted,
    :cancelled_untested,
    :model_after_switch,
    :model_after_prune,
    :pulse_after_switch,
    :retyped_elsewhere,
    :blocked_inside,
    :round_trip_aside,
    :round_trip_next_due,
    :resumed_by_tt,
    :superseded,
    :superseded_aside,
    :superseded_global,
    :superseded_named_again,
    :stale_superseded,
    :with_main
  ]

  # The longest walk of the suite, 16.8 s to 18.2 s over 32 runs of the suite on four
  # cores, 16 alone and 16 four at once, and past ExUnit's default of 60 s on a busier
  # machine: in M3-3's mutation runs, four suites at once, it timed out twice, failing two
  # rows by a timeout that said nothing of their mutants. Its 500 configurations are what
  # its reach needs, so its time is given room rather than its draws cut.
  @tag timeout: 300_000
  test "a configuration's edit refuses every host mistake with a documented ArgumentError, " <>
         "and each step's writes rebuild the resource, which then runs as its rules say" do
    # M4-2's draws, a watchdog, `with main` and a task's kind, moved the seeded stream, and
    # {2026, 10, 13} no longer reached a `tp`'s resume in 500 configurations; this seed
    # reaches every kind and every refusal.
    :rand.seed(:exsss, {2026, 10, 19})

    for _ <- 1..500 do
      spec = ce_spec()
      Process.put(:ce_timers, Map.new(spec.versions, fn {type, v} -> {type, v.timer} end))
      {:ok, config} = ce_config(spec)
      runtime = Runtime.start(config)

      w = %{
        rt: runtime,
        model: ce_seed(runtime),
        spec: spec,
        e: nil,
        c: nil,
        stale: [],
        passed: [],
        sup: [],
        round: nil,
        prev: %{},
        onsp: %{},
        resumed: false,
        o: nil
      }

      ce_walk(w, 50)
    end

    assert Process.get(:ce_refused, MapSet.new()) == MapSet.new(Keyword.keys(@ce_refusals))
    assert Process.get(:ce_diagnosed, MapSet.new()) == MapSet.new(@ce_diagnostics)
    assert Process.get(:ce_kinds, MapSet.new()) == MapSet.new(@report_kinds)
    assert Process.get(:ce_reach, MapSet.new()) == MapSet.new(@ce_reach)
  end

  # A value the type checker cannot see through, so that a host's mistake is passed as the
  # host would pass it.
  defp ce_opaque(value), do: Process.get(:__opaque_to_the_type_checker__, value)

  defp ce_reach(name), do: reached(:ce_reach, name)
  defp ce_reach(name, true), do: ce_reach(name)
  defp ce_reach(_name, false), do: :ok

  # ---- the draws ---------------------------------------------------------------------------

  # One version of a program type, from one vocabulary, so that two versions share their
  # names: `x` a var_input, a var or none, which a switch makes live or unread; the timer
  # `t1`, of one kind for every version of its type (M3-2: a `ton`, a `tof`, a `tp` or an
  # `rto`), run at one of two presets or none, its `.pre` written by logic now and
  # then, and its `.dn` copied out or not, which holds an output; a one-shot whose rung
  # changes; `n` with an initial value that changes, or none; `k`, whose type a refused
  # draw changes; `g0` a var_external, a var or none, read and now and then written; and a
  # `blk` instance, two deep, run or not.
  defp ce_version,
    do: %{
      x: pick([:input, :var, :none]),
      timer: pick(~w(ton ton tof tp rto)),
      ton: pick([nil, 15, 30, 30, 45]),
      pre: pick([true, false, false]),
      out: pick([true, true, false]),
      ons: pick([nil, :xic, :xic, :xio]),
      n: pick([nil, 1, 2]),
      k: :bool,
      g: pick([:ext, :ext, :var, :none]),
      gw: pick([true, false, false]),
      blk: pick([true, false])
    }

  defp ce_source(v) do
    decls =
      ["var_input in bool"] ++
        ce_x(v.x) ++
        ["var_output out bool", "var_output q bool", "var_output r bool"] ++
        ["var t1 #{v.timer}", "var sp dint 40", "var s bool", "var c bool", "var w bool"] ++
        ce_n(v.n) ++ ["var k #{v.k}"] ++ ce_g(v.g) ++ ce_blk(v.blk)

    rungs =
      ce_ton(v.timer, v.ton) ++
        if(v.pre, do: ["xio in move sp t1.pre"], else: []) ++
        if(v.out, do: ["xic t1.dn ote out"], else: []) ++
        ce_ons(v.ons) ++
        [if(v.k == :bool, do: "xic in ote k", else: "xic in move 1 k")] ++
        if(v.x == :none, do: [], else: ["xic x ote r"]) ++
        ce_g_rungs(v.g, v.gw) ++ if(v.blk, do: ["cal b1 in w"], else: [])

    Enum.join(decls, "\n") <> "\n\n" <> Enum.join(rungs, "\n") <> "\n"
  end

  defp ce_x(:input), do: ["var_input x bool"]
  defp ce_x(:var), do: ["var x bool"]
  defp ce_x(:none), do: []
  defp ce_n(nil), do: []
  defp ce_n(n), do: ["var n dint #{n}"]
  defp ce_g(:ext), do: ["var_external g0 bool"]
  defp ce_g(:var), do: ["var g0 bool"]
  defp ce_g(:none), do: []
  defp ce_blk(true), do: ["var b1 blk"]
  defp ce_blk(false), do: []
  defp ce_ton(_timer, nil), do: []
  defp ce_ton(timer, preset), do: ["xic in #{timer} t1 #{preset}"]
  defp ce_ons(nil), do: []
  defp ce_ons(:xic), do: ["xic in ote c ons s ote q"]
  defp ce_ons(:xio), do: ["xio in ote c ons s ote q"]
  defp ce_g_rungs(:none, _write?), do: []
  defp ce_g_rungs(_g, true), do: ["xic g0 ote w", "xic in ote g0"]
  defp ce_g_rungs(_g, false), do: ["xic g0 ote w"]

  # The two blocks, two deep: `leaf`'s timer at one of two presets, and `blk`'s member `m`
  # with an initial value that changes, or none.
  defp ce_blocks(%{leaf: preset, m: m, ons: ons}) do
    {:ok, leaf} =
      Logex.compile(
        "function_block leaf\nvar_input go bool\nvar_output done bool\nvar t ton\n\n" <>
          "xic go ton t #{preset}\n",
        name: "leaf"
      )

    member = if m, do: "var m dint #{m}\n", else: ""
    shot = %{nil => "", xic: "xic go ons e ote f\n", xio: "xio go ons e ote f\n"}[ons]

    {:ok, blk} =
      Logex.compile(
        "function_block blk\nvar_input go bool\nvar_output done bool\nvar i1 leaf\n" <>
          "var e bool\nvar f bool\n" <> member <> "\ncal i1 go done\n" <> shot,
        name: "blk",
        types: [leaf]
      )

    blk
  end

  @ce_points [
    {"i0", :bool, "panel.i.0"},
    {"i1", :bool, "panel.i.1"},
    {"o0", :bool, "panel.q.0"},
    {"o1", :bool, "panel.q.1"},
    {"o2", :bool, "panel.q.2"},
    {"o3", :bool, "panel.q.3"}
  ]

  defp ce_spec do
    # M4-2: each task with a watchdog or none, and half the time the continuous task,
    # `main`, which an instance with no task runs, and one `with main` too.
    main =
      if :rand.uniform(2) == 1,
        do: [%{name: "main", continuous: true, single: nil, interval: nil, priority: nil}],
        else: []

    tasks =
      for task <-
            [
              %{name: "fast", single: nil, interval: 10, priority: pick([1, 2])},
              %{name: "slow", single: nil, interval: pick([20, 30]), priority: pick([1, 2, 3])},
              %{name: "ev", single: "i0", interval: pick([nil, 20]), priority: pick([0, 2])}
            ] ++ main,
          do: Map.merge(%{continuous: false, watchdog: pick([nil, 50, 500])}, task)

    on = ["fast", "slow", "slow", "ev", nil] ++ Enum.map(main, & &1.name)

    instances =
      for name <- Enum.take(Enum.shuffle(~w(m1 m2 m3 m4)), 1 + :rand.uniform(3)),
          do: %{name: name, type: pick(~w(a b)), task: pick(on)}

    spec = %{
      tasks: tasks,
      globals:
        for({name, type, at} <- @ce_points, do: %{name: name, type: type, at: at, initial: nil}) ++
          [
            %{name: "g0", type: :bool, at: nil, initial: pick([nil, 1])},
            %{name: "g1", type: :bool, at: nil, initial: nil},
            %{name: "spare", type: :dint, at: nil, initial: nil}
          ],
      instances: instances,
      versions: %{"a" => ce_version(), "b" => ce_version()},
      blocks: %{leaf: pick([20, 25]), m: pick([nil, 1, 2]), ons: pick([nil, :xic, :xio])},
      wiring: %{}
    }

    ce_wire(spec, false)
  end

  # Every var_input of each instance connected, each var_output now and then to a point or
  # a global nothing else drives; with `keep?`, each instance keeps what it had where that
  # still holds.
  defp ce_wire(spec, keep?) do
    globals = Map.new(spec.globals, &{&1.name, &1})

    {wiring, _driven} =
      Enum.map_reduce(spec.instances, MapSet.new(), fn %{name: name, type: type}, driven ->
        v = spec.versions[type]
        had = if keep?, do: Map.get(spec.wiring, name, %{}), else: %{}

        ins =
          for member <- ["in"] ++ if(v.x == :input, do: ["x"], else: []),
              into: %{},
              do: {member, ce_source_of(Map.get(had, member), globals)}

        {outs, driven} =
          Enum.reduce(~w(out q r), {%{}, driven}, fn member, {outs, driven} ->
            ce_sink(Map.get(had, member), member, globals, {outs, driven})
          end)

        {{name, Map.merge(ins, outs)}, driven}
      end)

    %{spec | wiring: Map.new(wiring)}
  end

  defp ce_source_of(had, globals) when is_binary(had) do
    if Map.has_key?(globals, had), do: had, else: ce_source_of(nil, globals)
  end

  defp ce_source_of(had, _globals) when is_integer(had), do: had
  defp ce_source_of(nil, _globals), do: pick(["i0", "i1", "g1", 0, 1, 1])

  defp ce_sink(had, member, globals, {outs, driven}) when is_binary(had) do
    case Map.has_key?(globals, had) and not MapSet.member?(driven, had) do
      true -> {Map.put(outs, member, had), MapSet.put(driven, had)}
      false -> {outs, driven}
    end
  end

  defp ce_sink(nil, member, globals, {outs, driven}) do
    free =
      for name <- ~w(o0 o1 o2 o3 g1), Map.has_key?(globals, name), name not in driven, do: name

    case {free, :rand.uniform(2)} do
      {[_ | _], 1} ->
        sink = pick(free)
        {Map.put(outs, member, sink), MapSet.put(driven, sink)}

      _ ->
        {outs, driven}
    end
  end

  defp ce_text(spec) do
    tasks =
      for t <- spec.tasks,
          do:
            "task #{t.name}" <>
              if(t.continuous, do: " continuous", else: "") <>
              if(t.single, do: " single #{t.single}", else: "") <>
              if(t.interval, do: " interval #{t.interval}", else: "") <>
              if(t.priority, do: " priority #{t.priority}", else: "") <>
              if(t.watchdog, do: " watchdog #{t.watchdog}", else: "")

    globals =
      for g <- spec.globals,
          do:
            "var_global #{g.name} #{g.type}" <>
              if(g.at, do: " at #{g.at}", else: "") <>
              if(g.initial, do: " #{g.initial}", else: "")

    programs =
      for i <- spec.instances do
        Enum.join(
          ["program #{i.name} #{i.type}" <> if(i.task, do: " with #{i.task}", else: "")] ++
            for(
              {member, to} <- Enum.sort(Map.get(spec.wiring, i.name, %{})),
              do: "  #{i.name}.#{member} #{to}"
            ),
          "\n"
        )
      end

    Enum.join([Enum.join(tasks, "\n"), Enum.join(globals, "\n") | programs], "\n\n") <> "\n"
  end

  defp ce_programs(spec) do
    blk = ce_blocks(spec.blocks)

    Map.new(spec.versions, fn {type, v} ->
      {:ok, program} = Logex.compile(ce_source(v), name: type, types: [blk])
      {type, program}
    end)
  end

  defp ce_config(spec),
    do: Logex.Configuration.compile("plant", ce_text(spec), ce_programs(spec))

  # A candidate: the running configuration's draws with one to three changes, most of them
  # allowed while running and some refused, the wiring then mended, or drawn again.
  @ce_changes [
    :version,
    :version,
    :ton,
    :ton,
    :ton,
    :blocks,
    :add,
    :remove,
    :retype,
    :interval,
    :priority,
    :reorder,
    :reorder_tasks,
    :watchdog,
    :with_main,
    :global_add,
    :global_remove,
    :initial,
    :rewire
  ]

  @ce_refused [
    :kind,
    :task_add,
    :task_remove,
    :single,
    :event_interval,
    :move,
    :global_type,
    :located,
    :tag_type
  ]

  # One to three changes allowed while running, and one time in three one refused too.
  defp ce_candidate(spec) do
    changes =
      for(_ <- 1..:rand.uniform(3), do: pick(@ce_changes)) ++
        if(:rand.uniform(3) == 1, do: [pick(@ce_refused)], else: [])

    spec = Enum.reduce(changes, spec, &ce_change/2)
    ce_wire(spec, :rewire not in changes)
  end

  # A new version of a type, `k` and its timer's kind kept; or one that keeps all but its
  # timer's instruction, taken out, given back or moved to another preset, so that resumes
  # and their undoing come up.
  defp ce_change(:version, spec) do
    type = pick(~w(a b))
    was = spec.versions[type]
    %{spec | versions: Map.put(spec.versions, type, %{ce_version() | k: was.k, timer: was.timer})}
  end

  defp ce_change(:ton, spec) do
    type = pick(~w(a b))
    was = spec.versions[type]

    %{
      spec
      | versions: Map.put(spec.versions, type, %{was | ton: pick([nil, 15, 30, 45] -- [was.ton])})
    }
  end

  defp ce_change(:blocks, spec),
    do: %{
      spec
      | blocks: %{leaf: pick([20, 25]), m: pick([nil, 1, 2]), ons: pick([nil, :xic, :xio])}
    }

  defp ce_change(:add, spec) do
    case ~w(m1 m2 m3 m4 m5 m6) -- Enum.map(spec.instances, & &1.name) do
      [] ->
        spec

      free ->
        instance = %{
          name: pick(free),
          type: pick(~w(a b)),
          task: pick(["fast", "slow", "ev", nil])
        }

        %{spec | instances: spec.instances ++ [instance]}
    end
  end

  defp ce_change(:remove, %{instances: [_, _ | _] = instances} = spec),
    do: %{spec | instances: List.delete_at(instances, :rand.uniform(length(instances)) - 1)}

  defp ce_change(:remove, spec), do: spec

  # Decisions 43 and 61: a new instance under an old name, on any task.
  defp ce_change(:retype, spec) do
    i = :rand.uniform(length(spec.instances)) - 1

    instances =
      List.update_at(spec.instances, i, fn instance ->
        %{
          instance
          | type: if(instance.type == "a", do: "b", else: "a"),
            task: pick(["fast", "slow", "ev", nil])
        }
      end)

    %{spec | instances: instances}
  end

  defp ce_change(:interval, spec) do
    tasks =
      Enum.map(spec.tasks, fn
        %{interval: nil} = task ->
          task

        task ->
          if :rand.uniform(2) == 1, do: %{task | interval: pick([5, 10, 15, 20, 40])}, else: task
      end)

    %{spec | tasks: tasks}
  end

  # The continuous task takes no priority (decision 111), so its own is left out.
  defp ce_change(:priority, spec) do
    i = :rand.uniform(length(spec.tasks)) - 1

    tasks =
      List.update_at(spec.tasks, i, fn
        %{continuous: true} = task -> task
        task -> %{task | priority: pick([0, 1, 2, 3])}
      end)

    %{spec | tasks: tasks}
  end

  # Decision 129: a watchdog changes while running, and `with main` added or taken away
  # moves nothing.
  defp ce_change(:watchdog, spec) do
    i = :rand.uniform(length(spec.tasks)) - 1
    %{spec | tasks: List.update_at(spec.tasks, i, &%{&1 | watchdog: pick([nil, 30, 50, 500])})}
  end

  defp ce_change(:with_main, spec) do
    main? = Enum.any?(spec.tasks, & &1.continuous)

    instances =
      Enum.map(spec.instances, fn
        %{task: nil} = i when main? -> %{i | task: "main"}
        %{task: "main"} = i -> %{i | task: nil}
        i -> i
      end)

    %{spec | instances: instances}
  end

  defp ce_change(:reorder, spec), do: %{spec | instances: Enum.shuffle(spec.instances)}
  defp ce_change(:reorder_tasks, spec), do: %{spec | tasks: Enum.shuffle(spec.tasks)}

  defp ce_change(:global_add, spec) do
    case Enum.any?(spec.globals, &(&1.name == "g2")) do
      true ->
        spec

      false ->
        %{
          spec
          | globals:
              spec.globals ++ [%{name: "g2", type: :bool, at: nil, initial: pick([nil, 1])}]
        }
    end
  end

  defp ce_change(:global_remove, spec),
    do: %{
      spec
      | globals: Enum.reject(spec.globals, &(&1.name in ~w(spare g2) and :rand.uniform(2) == 1))
    }

  defp ce_change(:initial, spec),
    do: %{spec | globals: Enum.map(spec.globals, &ce_initial/1)}

  defp ce_change(:rewire, spec), do: spec

  # Refused at accept. Decision 129: a task made continuous or timed, its name kept: `main`
  # made periodic where it is declared, `slow` made continuous where it is not.
  defp ce_change(:kind, spec) do
    case Enum.any?(spec.tasks, & &1.continuous) do
      true ->
        %{
          spec
          | tasks:
              Enum.map(
                spec.tasks,
                &if(&1.continuous,
                  do: %{&1 | continuous: false, interval: 25, priority: 4},
                  else: &1
                )
              )
        }

      false ->
        %{
          spec
          | tasks:
              Enum.map(
                spec.tasks,
                &if(&1.name == "slow",
                  do: %{&1 | continuous: true, interval: nil, priority: nil},
                  else: &1
                )
              )
        }
    end
  end

  defp ce_change(:task_add, spec),
    do: %{
      spec
      | tasks:
          spec.tasks ++
            [
              %{
                name: "extra",
                single: nil,
                interval: 5,
                priority: 3,
                continuous: false,
                watchdog: nil
              }
            ]
    }

  defp ce_change(:task_remove, spec) do
    instances = Enum.map(spec.instances, &if(&1.task == "slow", do: %{&1 | task: nil}, else: &1))
    %{spec | tasks: Enum.reject(spec.tasks, &(&1.name == "slow")), instances: instances}
  end

  defp ce_change(:single, spec),
    do: %{
      spec
      | tasks: Enum.map(spec.tasks, &if(&1.single, do: %{&1 | single: pick(~w(i1 g1))}, else: &1))
    }

  defp ce_change(:event_interval, spec),
    do: %{
      spec
      | tasks:
          Enum.map(spec.tasks, fn
            %{single: nil} = task -> task
            %{interval: nil} = task -> %{task | interval: 20}
            task -> %{task | interval: nil}
          end)
    }

  defp ce_change(:move, spec) do
    i = :rand.uniform(length(spec.instances)) - 1
    tasks = ["fast", "slow", "ev", nil]

    %{
      spec
      | instances: List.update_at(spec.instances, i, &%{&1 | task: pick(tasks -- [&1.task])})
    }
  end

  defp ce_change(:global_type, spec),
    do: %{
      spec
      | globals:
          Enum.map(spec.globals, &if(&1.name == "spare", do: %{&1 | type: :bool}, else: &1))
    }

  defp ce_change(:located, spec) do
    case pick([:move, :new, :drop, :to_g1]) do
      :move ->
        ce_located(spec, "o3", &%{&1 | at: "panel.q.7"})

      :new ->
        %{
          spec
          | globals: spec.globals ++ [%{name: "o9", type: :bool, at: "panel.q.9", initial: nil}]
        }

      :drop ->
        %{spec | globals: Enum.reject(spec.globals, &(&1.name == "o3"))}

      :to_g1 ->
        ce_located(spec, "g1", &%{&1 | at: "panel.q.8"})
    end
  end

  defp ce_change(:tag_type, spec) do
    type = pick(~w(a b))
    v = spec.versions[type]

    %{
      spec
      | versions: Map.put(spec.versions, type, %{v | k: if(v.k == :bool, do: :dint, else: :bool)})
    }
  end

  defp ce_located(spec, name, fun),
    do: %{spec | globals: Enum.map(spec.globals, &if(&1.name == name, do: fun.(&1), else: &1))}

  defp ce_initial(%{name: "g0", initial: nil} = global), do: %{global | initial: 1}
  defp ce_initial(%{name: "g0"} = global), do: %{global | initial: nil}
  defp ce_initial(global), do: global

  # ---- what accept refuses, restated from the two configurations -------------------------

  defp ce_predicted(o, c) do
    tasks = Map.new(o.tasks, &{&1.name, &1})
    globals = Map.new(o.globals, &{&1.name, &1})
    instances = Map.new(o.instances, &{&1.name, &1})

    # Decision 129, restated: an instance runs untimed where it has no task or names the
    # continuous task, and one that names a task whose kind changed is told nothing more.
    untimed = fn config -> Enum.find_value(config.tasks, :none, &(&1.continuous && &1.name)) end

    rekinded =
      for t <- c.tasks, w = tasks[t.name], w != nil, w.continuous != t.continuous, do: t.name

    places = {untimed.(o), untimed.(c), rekinded}

    own =
      Enum.flat_map(c.tasks, &ce_task(Map.get(tasks, &1.name), &1)) ++
        Enum.flat_map(c.globals, &ce_global(Map.get(globals, &1.name), &1)) ++
        Enum.flat_map(c.instances, &ce_moved(Map.get(instances, &1.name), &1, places))

    kept_tasks = MapSet.new(c.tasks, & &1.name)
    kept_globals = MapSet.new(c.globals, & &1.name)

    gone =
      for(
        t <- o.tasks,
        t.name not in kept_tasks,
        do:
          {:task_removed, nil,
           "task `#{t.name}` (line #{t.line} of the running configuration) is removed: a task is removed only with a restart"}
      ) ++
        for g <- o.globals,
            g.at != nil,
            g.name not in kept_globals,
            do:
              {:located_removed, nil,
               "`#{g.name}` at `#{g.at}` (line #{g.line} of the running configuration) is removed: located I/O changes only with a restart"}

    types =
      Enum.uniq(
        for i <- c.instances, Map.get(instances, i.name, %{type: nil}).type == i.type, do: i.type
      )

    typed =
      for type <- types,
          was = o.programs[type].tags["k"].type,
          now = c.programs[type].tags["k"],
          was != now.type,
          do:
            {:tag_type, now.line,
             "`k` is a #{was} in the running program and a #{now.type} in the candidate: a tag's type changes only with a restart"}

    Enum.sort_by(own, &elem(&1, 1)) ++ gone ++ typed
  end

  defp ce_task(nil, t),
    do: [{:task_added, t.line, "task `#{t.name}` is added: a task is added only with a restart"}]

  defp ce_task(%{continuous: was} = w, %{continuous: now} = t) when was != now do
    kind = fn
      %{continuous: true} -> "continuous"
      %{single: nil} -> "periodic"
      _ -> "an event task"
    end

    [
      {:kind, t.line,
       "task `#{t.name}` is #{kind.(w)} in the running configuration and #{kind.(t)} in the candidate: a task's kind changes only with a restart"}
    ]
  end

  defp ce_task(was, t) do
    single =
      if was.single != t.single,
        do: [
          {:single, t.line,
           "task `#{t.name}`'s single changes from #{ce_named(was.single)} to #{ce_named(t.single)}: a task's single changes only with a restart"}
        ],
        else: []

    interval =
      if was.single != nil and was.single == t.single and
           was.interval == nil != (t.interval == nil),
         do: [
           {:event_interval, t.line,
            "task `#{t.name}` has a single, and its interval is #{if t.interval, do: "added", else: "removed"}: an event task's interval is added or removed only with a restart"}
         ],
         else: []

    single ++ interval
  end

  defp ce_named(nil), do: "none"
  defp ce_named(name), do: "`#{name}`"

  defp ce_global(nil, %{at: nil}), do: []

  defp ce_global(nil, g),
    do: [
      {:located_new, g.line,
       "`#{g.name}` at `#{g.at}` is added: located I/O changes only with a restart"}
    ]

  defp ce_global(was, g) do
    typed =
      if was.type != g.type,
        do: [
          {:global_type, g.line,
           "`#{g.name}` is a #{was.type} global in the running configuration and a #{g.type} in the candidate: a global's type changes only with a restart"}
        ],
        else: []

    located =
      case {was.at, g.at} do
        {same, same} ->
          []

        {nil, at} ->
          [
            {:located, g.line,
             "`#{g.name}` has no location in the running configuration and is at `#{at}` in the candidate: located I/O changes only with a restart"}
          ]

        {at, nil} ->
          [
            {:located, g.line,
             "`#{g.name}` is at `#{at}` in the running configuration and has no location in the candidate: located I/O changes only with a restart"}
          ]

        {a, b} ->
          [
            {:located, g.line,
             "`#{g.name}` is at `#{a}` in the running configuration and at `#{b}` in the candidate: located I/O changes only with a restart"}
          ]
      end

    typed ++ located
  end

  defp ce_moved(%{type: type, task: was}, %{type: type, task: task} = i, {o, c, rekinded}) do
    {from, to} = {ce_place(was, o), ce_place(task, c)}

    cond do
      was in rekinded or task in rekinded ->
        []

      match?({{:untimed, _}, {:untimed, _}}, {from, to}) ->
        []

      from == to ->
        []

      true ->
        [
          {:moved, i.line,
           "`#{i.name}` runs #{ce_with(from)} in the running configuration and #{ce_with(to)} in the candidate: an instance moves to another task only with a restart"}
        ]
    end
  end

  defp ce_moved(_was, _instance, _places), do: []

  defp ce_place(nil, untimed), do: {:untimed, untimed}
  defp ce_place(untimed, untimed), do: {:untimed, untimed}
  defp ce_place(task, _untimed), do: task

  defp ce_with({:untimed, :none}), do: "with no task"
  defp ce_with({:untimed, task}), do: "with `#{task}`"
  defp ce_with(task), do: "with `#{task}`"

  # ---- the walk ----------------------------------------------------------------------------

  defp ce_walk(w, 0), do: w

  # Right after a test, half the time its untest with no cycle between, the round trip.
  defp ce_walk(%{round: {_, _}} = w, n) when n > 0,
    do:
      ce_walk(
        if(:rand.uniform(3) > 1, do: ce_step(:untest, w), else: ce_op(:rand.uniform(12), w)),
        n - 1
      )

  # Right after a switch that resumed a timer, often the switch back, at once or after a
  # short cycle that its task may not scan, which gives the resume back (fix F11).
  defp ce_walk(%{resumed: true, e: edit} = w, n) when n > 0 and edit != nil do
    w = %{w | resumed: false}

    case :rand.uniform(4) do
      1 -> ce_walk(ce_step(:back, w), n - 1)
      2 -> ce_walk(w, n)
      _ -> ce_walk(ce_step(:back, ce_cycle(w, 5)), n - 1)
    end
  end

  defp ce_walk(w, n), do: ce_walk(ce_op(:rand.uniform(12), w), n - 1)

  defp ce_op(op, w) when op <= 5, do: ce_cycle(w)
  defp ce_op(op, %{e: nil} = w) when op in 6..8, do: ce_accept(w)

  # An edit open, now and then another accepted over it, which supersedes it (§4.9): the
  # running configuration's draws changed, the edit it supersedes never stepped again.
  defp ce_op(op, w) when op in 6..9 and w.e != nil do
    case :rand.uniform(6) do
      1 -> ce_accept(w)
      _ -> ce_step(pick([:test, :untest, :assemble, :cancel, :back, :back]), w)
    end
  end

  defp ce_op(9, w), do: ce_cycle(w)
  defp ce_op(10, w), do: ce_restart(w)
  defp ce_op(11, w), do: ce_stale(w)
  defp ce_op(12, w), do: ce_mistakes(w)

  defp ce_attempt(fun) do
    result = fun.()
    assert fun.() == result, "the same call gave two results"
    {:ok, result}
  rescue
    error in ArgumentError ->
      kind = Enum.find(@ce_refusals, fn {_, words} -> String.contains?(error.message, words) end)
      assert kind, "undocumented refusal: #{error.message}"
      reached(:ce_refused, elem(kind, 0))
      {:refused, elem(kind, 0), error.message}
  end

  # A cycle, against the model seeded from the resource after the last step, and the two
  # oracles that know nothing of an edit: no scan lets a timer gain more than the time
  # since its instance's last scan, and a one-shot passes power only where its instance's
  # last scan ran the same `ons` rung with its condition 0.
  defp ce_cycle(w), do: ce_cycle(w, pick([0, 5, 10, 10, 15, 30]))

  defp ce_cycle(w, elapsed) do
    # Inputs change now and then, so that a timer times for long enough to be done.
    inputs = for name <- ~w(i0 i1), :rand.uniform(4) == 1, into: %{}, do: {name, pick([0, 1])}
    {:ok, {rt, outputs, events}} = ce_attempt(fn -> Runtime.cycle(w.rt, elapsed, inputs) end)

    {model, expected_outputs, expected_events} =
      ce_model_cycle(w.rt.config, w.model, elapsed, inputs)

    assert events == expected_events
    assert outputs == expected_outputs
    assert rt.globals == model.globals
    assert rt.instances == model.states

    {prev, onsp} =
      Enum.reduce(events, {w.prev, w.onsp}, fn
        {:ran, _task, name, now}, {prev, onsp} ->
          before = w.rt.instances[name]
          later = rt.instances[name]
          # Each state's own history: a retyped instance's old state, set aside, and its
          # new one share a name.
          key = {name, later.type}
          gap = now - Map.get(prev, key, 0)

          for path <- [["t1"], ["b1", "i1", "t"]],
              %{"acc" => was} <- [get_in(before.env, path)],
              %{"acc" => acc} <- [get_in(later.env, path)],
              do:
                assert(
                  acc - was <= gap,
                  "#{name}.#{Enum.join(path, ".")} gained #{acc - was} in #{gap} ms"
                )

          rung = ce_ons_rung(rt.config.programs[later.type])

          if later.env["q"] == 1 and rung != nil do
            assert Map.get(onsp, key) == {rung, 0}, "#{name}'s one-shot pulsed"
            ce_reach(:pulse_after_switch, before.switched)
          end

          {Map.put(prev, key, now), Map.put(onsp, key, rung && {rung, later.env["c"]})}

        _event, acc ->
          acc
      end)

    ce_reach(
      :unscanned_switch,
      Enum.any?(rt.instances, fn {_n, s} -> s.switched end) and w.round != nil
    )

    %{w | rt: rt, model: model, prev: prev, onsp: onsp, round: nil}
  end

  defp ce_moves_pre?(%Program{source: source}), do: source =~ "move sp t1.pre"

  defp ce_ons_rung(%{source: source}),
    do: Enum.find(String.split(source, "\n"), &String.contains?(&1, " ons "))

  defp ce_accept(w) do
    w = %{w | spec: ce_running_spec(w)}
    spec = ce_candidate(w.spec)

    case ce_config(spec) do
      {:ok, candidate} -> ce_accepted(candidate, spec, w)
      {:error, _diagnostics} -> w
    end
  end

  # The draws of the configuration the resource runs: an open edit's candidate under test,
  # its original otherwise.
  defp ce_running_spec(%{e: nil, spec: spec}), do: spec

  defp ce_running_spec(%{e: edit, c: {_candidate, spec}} = w),
    do: if(ConfigEdit.stage(edit) == :testing, do: spec, else: w.spec)

  defp ce_accepted(candidate, spec, w) do
    predicted = ce_predicted(w.rt.config, candidate)

    case ce_attempt(fn -> ConfigEdit.accept(w.rt, candidate) end) do
      {:ok, {:error, diagnostics}} ->
        assert predicted != []

        assert Enum.map(diagnostics, &{&1.line, &1.message}) ==
                 Enum.map(predicted, &{elem(&1, 1), elem(&1, 2)})

        for {kind, _, _} <- predicted, do: reached(:ce_diagnosed, kind)
        w

      {:ok, {:ok, edit, forecast}} ->
        assert predicted == [], inspect(predicted)
        ce_report!(forecast)
        # The forecast is the report a test taken now gives.
        {_edit, _rt, report} = ConfigEdit.test(edit, w.rt)
        assert report == forecast
        ce_reach(:forecast)

        retyped =
          for i <- candidate.instances,
              o <- w.rt.config.instances,
              o.name == i.name,
              o.type != i.type,
              o.task != i.task,
              do: i

        ce_reach(:retyped_elsewhere, retyped != [])

        # Decision 129: `with main` added or taken away, an instance kept on its type.
        ce_reach(
          :with_main,
          Enum.any?(candidate.instances, fn i ->
            Enum.any?(
              w.rt.config.instances,
              &(&1.name == i.name and &1.type == i.type and &1.task != i.task and
                  Enum.sort([&1.task, i.task]) == Enum.sort([nil, "main"]))
            )
          end)
        )

        ce_reach(:superseded, w.e != nil)
        sup = if w.e, do: [w.e | w.sup], else: w.sup
        %{w | e: edit, c: {candidate, spec}, o: w.rt.config, round: nil, sup: sup}
    end
  end

  defp ce_report!(report) do
    assert report == Enum.sort(report)
    keys = for {kind, name, _detail} <- report, do: {kind, name}
    assert keys == Enum.uniq(keys)

    for {kind, _name, _detail} <- report do
      assert kind in @report_kinds
      reached(:ce_kinds, kind)
    end
  end

  @ce_allowed %{
    test: [:accepted, :untested],
    untest: [:testing],
    assemble: [:testing],
    cancel: [:accepted, :untested]
  }

  defp ce_step(:back, w),
    do: ce_step(if(ConfigEdit.stage(w.e) == :testing, do: :untest, else: :test), w)

  defp ce_step(step, w) do
    stage = ConfigEdit.stage(w.e)
    allowed? = stage in @ce_allowed[step]
    result = ce_attempt(fn -> apply(ConfigEdit, step, [w.e, w.rt]) end)
    ce_stepped(step, stage, allowed?, result, w)
  end

  defp ce_stepped(_step, _stage, false, result, w) do
    assert {:refused, _kind, _message} = result
    w
  end

  defp ce_stepped(step, stage, true, {:ok, {next, rt, report}}, w)
       when step in [:test, :untest] do
    ce_report!(report)
    assert ConfigEdit.stage(next) == if(step == :test, do: :testing, else: :untested)
    assert rt.config == ConfigEdit.running(next)
    ce_unmoved!(w.rt, rt, report)
    ce_rebuilt!(w.rt, rt, report, :switch)
    ce_restated!(w.rt, rt, report, {:switch, step == :test and stage == :accepted})
    ce_one_copy!(rt, if(step == :test, do: ConfigEdit.running(w.e), else: elem(w.c, 0)))
    ce_round!(step, w, rt, report)
    ce_reach(:model_after_switch)
    _ = stage

    %{
      w
      | e: next,
        rt: rt,
        model: ce_seed(rt),
        stale: [w.e | w.stale],
        passed: w.sup ++ w.passed,
        sup: [],
        round: if(step == :test, do: {w.rt, report}, else: nil),
        resumed: Enum.any?(report, &match?({:resumed, _, _}, &1))
    }
  end

  defp ce_stepped(step, stage, true, {:ok, {kept, rt, report}}, w) do
    ce_report!(report)
    ce_unmoved!(w.rt, rt, report)

    case {step, stage} do
      {:cancel, :accepted} ->
        assert report == []
        assert %{rt | generation: w.rt.generation} == w.rt
        ce_reach(:cancelled_accepted)

      _ ->
        ce_rebuilt!(w.rt, rt, report, :prune)

        ce_restated!(
          w.rt,
          rt,
          report,
          {:prune, if(step == :assemble, do: w.o, else: elem(w.c, 0))}
        )

        assert rt.aside == %{}
        ce_reach(if(step == :assemble, do: :assembled, else: :cancelled_untested))
        ce_reach(:model_after_prune)
    end

    # Cancel from accept leaves what a superseded edit set aside, which no configuration
    # here runs, for the next edit's first test to drop (decision 66).
    ce_one_copy!(rt, if(stage == :accepted, do: nil, else: rt.config))
    assert rt.config == kept
    {_, spec} = w.c
    spec = if step == :assemble, do: spec, else: w.spec

    %{
      w
      | e: nil,
        c: nil,
        rt: rt,
        model: ce_seed(rt),
        spec: spec,
        stale: [w.e | w.stale],
        passed: w.sup ++ w.passed,
        sup: [],
        round: nil
    }
  end

  # Each report kind of the configuration's, against its rule restated from the two
  # configurations' text and the resource before the step; and what a step leaves in every
  # running state, read from its program's text: a switch every tag its program declares
  # but a var_external, and a prune those alone.
  defp ce_restated!(before, later, report, {:switch, first?}) do
    {from, to} = {before.config, later.config}
    {before, dropped} = ce_left(before, from, first?)
    was = Map.new(from.tasks, &{&1.name, &1})

    tasks =
      for(
        t <- to.tasks,
        o = was[t.name],
        o.interval != t.interval,
        do: {:interval, t.name, {o.interval, t.interval}}
      ) ++
        for(
          t <- to.tasks,
          o = was[t.name],
          o.priority != t.priority,
          do: {:priority, t.name, {o.priority, t.priority}}
        ) ++
        for(
          t <- to.tasks,
          o = was[t.name],
          (o.watchdog || 500) != (t.watchdog || 500),
          do: {:watchdog, t.name, {o.watchdog || 500, t.watchdog || 500}}
        ) ++
        for t <- to.tasks,
            o = was[t.name],
            o.interval != t.interval,
            next = before.tasks[t.name].next_due,
            min(next, before.now + t.interval) != next,
            do: {:next_due, t.name, {next, min(next, before.now + t.interval)}}

    old = Map.new(from.globals, &{&1.name, &1})

    globals =
      for(
        g <- to.globals,
        not Map.has_key?(before.globals, g.name),
        do: {:added, g.name, g.initial || 0}
      ) ++
        for(
          g <- to.globals,
          Map.has_key?(before.globals, g.name),
          o = old[g.name],
          o != nil and (o.initial || 0) != (g.initial || 0),
          do: {:initial_changed, g.name, {o.initial || 0, g.initial || 0}}
        ) ++ ce_held(from, to, later)

    kept =
      for i <- to.instances,
          Enum.any?(from.instances, &(&1.name == i.name and &1.type == i.type)),
          do: i.name

    stopped = for i <- from.instances, i.name not in kept, do: {:instance_stopped, i.name, i.type}

    started =
      for i <- to.instances,
          i.name not in kept,
          do:
            {if(match?(%{type: t} when t == i.type, before.aside[i.name]),
               do: :instance_back,
               else: :instance_added
             ), i.name, i.type}

    shared =
      for name <- kept,
          type = Enum.find(to.instances, &(&1.name == name)).type,
          {f, t} = {ce_externals(from.programs[type]), ce_externals(to.programs[type])},
          entry <-
            for(
              e <- t,
              e not in f,
              do: {:joined, "#{name}.#{e}", {before.instances[name].env[e], later.globals[e]}}
            ) ++
              for(
                e <- f,
                e not in t,
                Map.has_key?(to.programs[type].tags, e),
                do: {:left, "#{name}.#{e}", later.globals[e]}
              ),
          do: entry

    # Decision 96: a kept instance's `t1.pre`, which its type's stopped version moves `sp`
    # into and the started one does not, keeps its value and is reported by its path.
    unwritten =
      for name <- kept,
          type = Enum.find(to.instances, &(&1.name == name)).type,
          ce_moves_pre?(from.programs[type]) and not ce_moves_pre?(to.programs[type]),
          do: {:unwritten, "#{name}.t1.pre", later.instances[name].env["t1"]["pre"]}

    restated =
      Enum.sort(
        dropped ++
          tasks ++ globals ++ stopped ++ started ++ shared ++ unwritten ++ ce_orders(from, to)
      )

    given =
      for {kind, name, _} = entry <- report,
          kind in [
            :interval,
            :priority,
            :watchdog,
            :next_due,
            :instance_stopped,
            :instance_added,
            :instance_back,
            :instance_pruned,
            :joined,
            :left,
            :order,
            :unwritten
          ] or
            (not String.contains?(to_string(name), ".") and
               kind in [:added, :initial_changed, :held, :pruned]),
          do: entry

    assert given == restated

    ce_reach(
      :superseded_named_again,
      Enum.any?(dropped, fn {_kind, name, _} ->
        Enum.any?(to.instances ++ to.globals, &(&1.name == name))
      end)
    )

    # A fresh start of the configuration started, which knows nothing of an edit, for what
    # only it runs or declares: each instance a switch starts is as start/1 starts it, and
    # at the first test so is each instance and each global the original lacks, whatever an
    # edit this one superseded left in the resource (decision 66); what is set aside is
    # then the original's alone.
    fresh = Runtime.start(to)

    for {:instance_added, name, _} <- report,
        do: assert(later.instances[name] == fresh.instances[name], name)

    if first? do
      for i <- to.instances,
          i.name not in kept,
          do: assert(later.instances[i.name] == fresh.instances[i.name], i.name)

      for g <- to.globals,
          not Map.has_key?(old, g.name),
          do: assert(later.globals[g.name] == fresh.globals[g.name], g.name)

      assert Enum.sort(Map.keys(later.aside)) ==
               Enum.sort(for i <- from.instances, i.name not in kept, do: i.name)
    end

    # Each resume from the resource's clock (decisions 56 and 57), of a timer that was
    # timing; and, but at the first test, no start over a value the state already holds.
    for {:resumed, path, gap} <- report do
      [name | rest] = String.split(path, ".")
      state = Map.merge(before.instances, before.aside)[name]
      times = ce_times(state.type, rest)
      %{^times => 1, "last" => last} = get_in(state.env, rest)
      assert last + gap == later.now
      ce_reach(:resumed_by_tt, times == "tt")
    end

    for {:added, path, _} <- report,
        not first?,
        [name, rest] <- [String.split(path, ".", parts: 2)],
        state = before.instances[name],
        state != nil,
        Enum.any?(from.instances, &(&1.name == name)),
        do:
          assert(
            get_in(state.env, String.split(rest, ".")) == nil,
            "#{path} started over a value"
          )

    # No start rule starts a var_external, whose value is its global's.
    for {:added, path, _} <- report,
        [name, tag] <- [String.split(path, ".", parts: 2)],
        state = later.instances[name],
        do: refute(tag in ce_externals(to.programs[state.type]), "#{path} started")

    ce_declared!(later, &MapSet.subset?/2)
  end

  defp ce_restated!(before, later, report, {:prune, from}) do
    to = later.config

    restated =
      Enum.sort(
        for(
          name <- Map.keys(before.globals),
          not Enum.any?(to.globals, &(&1.name == name)),
          do: {:pruned, name, before.globals[name]}
        ) ++
          for({name, state} <- before.aside, do: {:instance_pruned, name, state.type}) ++
          ce_held(from, to, later)
      )

    given = for {_kind, name, _} = entry <- report, not String.contains?(name, "."), do: entry
    assert given == restated
    ce_declared!(later, &MapSet.equal?/2)
  end

  # Decision 66: at an edit's first switch what the resource holds that the original does
  # not declare, which an edit this one superseded left, is dropped before the switch and
  # reported, `:pruned` and `:instance_pruned`; the switch is restated over the rest.
  defp ce_left(before, _from, false), do: {before, []}

  defp ce_left(before, from, true) do
    declared = MapSet.new(from.globals, & &1.name)
    {kept, gone} = Map.split_with(before.globals, fn {name, _} -> name in declared end)
    ce_reach(:superseded_aside, before.aside != %{})
    ce_reach(:superseded_global, gone != %{})

    {%{before | globals: kept, aside: %{}},
     for({name, value} <- gone, do: {:pruned, name, value}) ++
       for({name, state} <- before.aside, do: {:instance_pruned, name, state.type})}
  end

  defp ce_declared!(rt, relation) do
    for {_name, state} <- rt.instances do
      program = rt.config.programs[state.type]
      declared = MapSet.new(Map.keys(program.tags) -- ce_externals(program))
      assert relation.(declared, MapSet.new(Map.keys(state.env)))
    end
  end

  defp ce_externals(program),
    do: for({name, %Tag{section: :var_external}} <- program.tags, do: name)

  # Decision 20 for the plant, from the programs' text: a global a connection copies out a
  # var_output that some rung writes to, or that a rung writes through a var_external.
  defp ce_drives(config) do
    writes = fn program, name -> program.source =~ ~r/\b(ote|otl|otu) #{name}\b/ end
    types = Map.new(config.instances, &{&1.name, &1.type})

    MapSet.new(
      for(
        c <- config.connections,
        is_binary(c.to),
        writes.(config.programs[types[c.instance]], c.member),
        do: c.to
      ) ++
        for(
          i <- config.instances,
          program = config.programs[i.type],
          name <- ce_externals(program),
          writes.(program, name),
          do: name
        )
    )
  end

  defp ce_held(from, to, later) do
    declared = MapSet.new(to.globals, & &1.name)

    for g <- Enum.sort(MapSet.difference(ce_drives(from), ce_drives(to))),
        g in declared,
        do: {:held, g, later.globals[g]}
  end

  # Decision 62, restated: the names both have on a task, or of the tasks, in another order.
  defp ce_orders(from, to) do
    # Decision 129: the untimed instances, with no task or `with` the continuous task, are
    # one order, under its name or :none.
    by_task = fn config ->
      untimed = Enum.find_value(config.tasks, :none, &(&1.continuous && &1.name))

      Enum.group_by(
        config.instances,
        &if(&1.task in [nil, untimed], do: untimed, else: &1.task),
        & &1.name
      )
    end

    {was, now} = {by_task.(from), by_task.(to)}
    # Decision 129's note: the continuous task's place among the tasks is no order.
    timed = fn config -> for t <- config.tasks, !t.continuous, do: t.name end

    lists =
      [{:tasks, timed.(from), timed.(to)}] ++
        for {task, names} <- now, do: {task, Map.get(was, task, []), names}

    for {name, old, new} <- lists,
        old -- (old -- new) != new -- (new -- old),
        do: {:order, name, new}
  end

  # No step moves the clock, an overlap count or a trigger's last sample, and only
  # decision 40 moves a next due time.
  defp ce_unmoved!(before, later, report) do
    assert later.now == before.now
    moved = for {:next_due, task, {_from, to}} <- report, into: %{}, do: {task, to}

    for {name, state} <- before.tasks do
      assert later.tasks[name] == %{state | next_due: Map.get(moved, name, state.next_due)}
    end
  end

  # Decision 49: no state, running or set aside, holds a var_external of its own program,
  # the running configuration's or, set aside, the other's.
  defp ce_one_copy!(rt, other) do
    for {states, config} <- [{rt.instances, rt.config}, {rt.aside, other}],
        config != nil,
        {_name, state} <- states,
        {name, %Tag{section: :var_external}} <- config.programs[state.type].tags,
        do: refute(Map.has_key?(state.env, name))
  end

  # The writes a report lists, applied to the resource before its step, give it after: a
  # global's `:pruned` and an `:instance_pruned` first, which at a first test drop what a
  # superseded edit left before the switch writes over it (decision 66).
  defp ce_rebuilt!(before, later, report, kind) do
    {prunes, report} =
      Enum.split_with(report, fn {kind, name, _} ->
        kind in [:pruned, :instance_pruned] and not String.contains?(to_string(name), ".")
      end)

    gone = fn wanted -> for {^wanted, name, _} <- prunes, do: name end

    base =
      {Map.drop(before.globals, gone.(:pruned)), Map.drop(before.aside, gone.(:instance_pruned))}

    {base_globals, base_aside} = base
    names = fn wanted -> for {^wanted, name, _} <- report, do: name end
    stopped = names.(:instance_stopped)
    back = names.(:instance_back)
    added = names.(:instance_added)

    fresh =
      for name <- added, into: %{} do
        %{type: type} = Enum.find(later.config.instances, &(&1.name == name))
        program = later.config.programs[type]
        externals = for {n, %Tag{section: :var_external}} <- program.tags, do: n
        state = Runtime.instance(program)
        {name, %{state | env: Map.drop(state.env, externals)}}
      end

    instances =
      before.instances
      |> Map.drop(stopped)
      |> Map.merge(Map.take(base_aside, back))
      |> Map.merge(fresh)

    aside =
      base_aside
      |> Map.drop(back)
      |> Map.merge(Map.take(before.instances, stopped))

    {instances, globals} =
      Enum.reduce(report, {instances, base_globals}, fn {kind, name, value} = entry,
                                                        {instances, globals} ->
        case String.split(to_string(name), ".", parts: 2) do
          [instance, path] ->
            {Map.update!(
               instances,
               instance,
               &%{&1 | env: ce_write({kind, path, value}, &1.env)}
             ), globals}

          [_global] ->
            {instances, ce_global_write(entry, globals)}
        end
      end)

    assert later.globals == globals

    assert Map.new(later.instances, fn {n, s} -> {n, s.env} end) ==
             Map.new(instances, fn {n, s} -> {n, s.env} end)

    assert Map.new(later.aside, fn {n, s} -> {n, s.env} end) ==
             Map.new(aside, fn {n, s} -> {n, s.env} end)

    for {name, state} <- later.instances,
        name in back or (kind == :switch and name not in added) do
      assert state.now == later.now
    end

    if kind == :switch do
      kept = Map.keys(later.instances) -- (added ++ back)

      for name <- kept do
        state = later.instances[name]
        assert state.switched

        bits =
          for {:ons_blocked, path, _} <- report,
              [^name, bit] <- [String.split(path, ".", parts: 2)],
              do: bit

        assert state.ons_blocked == bits
        ce_reach(:blocked_inside, Enum.any?(bits, &String.contains?(&1, ".")))
      end
    end
  end

  defp ce_write({kind, path, value}, env) when kind in [:added, :input, :left],
    do: put_in(env, Enum.map(String.split(path, "."), &Access.key(&1, %{})), value)

  defp ce_write({:preset, path, {_from, to}}, env),
    do: put_in(env, String.split(path, ".") ++ ["pre"], to)

  defp ce_write({:resumed, path, gap}, env),
    do: update_in(env, String.split(path, ".") ++ ["last"], &(&1 + gap))

  defp ce_write({:resume_undone, path, gap}, env),
    do: update_in(env, String.split(path, ".") ++ ["last"], &(&1 - gap))

  defp ce_write({kind, path, _value}, env) when kind in [:pruned, :joined] do
    case Enum.split(String.split(path, "."), -1) do
      {[], [leaf]} -> Map.delete(env, leaf)
      {parent, [leaf]} -> update_in(env, parent, &Map.delete(&1, leaf))
    end
  end

  defp ce_write(_fact, env), do: env

  defp ce_global_write({:added, name, value}, globals), do: Map.put(globals, name, value)
  defp ce_global_write({:pruned, name, _value}, globals), do: Map.delete(globals, name)
  defp ce_global_write(_fact, globals), do: globals

  # A test then an untest with no cycle between leaves the resource as the test found it,
  # every state, each set aside, the globals and the tasks, but for what either switch
  # started, kept unused, a timer the untest resumed in an instance it brought back from
  # aside (decision 57), and what the switches' own rules set, each named below: found
  # from the states, never from the reports' writes.
  defp ce_round!(:untest, %{round: {before, test_report}, c: {candidate, _}}, later, report) do
    started = for {:instance_added, name, _} <- test_report, do: name
    # What a first test dropped of a superseded edit's (decision 66) is not the original's.
    dropped = for {kind, name, _} <- test_report, kind in [:pruned, :instance_pruned], do: name
    {aside, globals} = {Map.drop(before.aside, dropped), Map.drop(before.globals, dropped)}
    assert Map.keys(later.instances) |> Enum.sort() == Map.keys(before.instances) |> Enum.sort()
    assert Map.drop(later.aside, started) |> Map.keys() == Map.keys(aside)
    assert Map.take(later.globals, Map.keys(globals)) == globals
    back = for {:instance_back, name, _} <- report, do: name
    resumed = for {:resumed, path, _} <- report, do: path

    for {name, state} <- before.instances do
      after_env = later.instances[name].env

      # Decision 55: a tag the test joined to its global lost its own value, and the untest
      # leaves it at the global's.
      paths =
        for {kind, path, _} <- test_report ++ report,
            kind in [:added, :input, :joined],
            [^name, p] <- [String.split(path, ".", parts: 2)],
            do: p

      ce_reach(:round_trip_started, paths != [])
      ce_reach(:round_trip_joined, Enum.any?(test_report, &match?({:joined, _, _}, &1)))

      expected =
        Enum.reduce(paths, state.env, fn p, env ->
          ce_exempt(get_in(after_env, String.split(p, ".")), p, env)
        end)

      expected =
        Enum.reduce(resumed, expected, fn path, env ->
          undone? = Enum.any?(test_report, &match?({:resume_undone, ^path, _}, &1))

          ce_resumed_back(
            String.split(path, ".", parts: 2),
            name,
            {name in back, undone?},
            later.now,
            env
          )
        end)

      assert after_env == expected

      unless state.first,
        do: assert(later.instances[name].ons_blocked == state.ons_blocked or name in back)

      # The rest of the state: its type and `first` never touched; its `now` the
      # resource's, which a switch gives a kept instance and one back from aside (decisions
      # 56 and 57); and `switched` set by a switch of a kept one (OE-1), and as set aside
      # for one back.
      assert %{later.instances[name] | env: state.env, ons_blocked: state.ons_blocked} ==
               %{state | now: later.now, switched: state.switched or name not in back}
    end

    # Each instance set aside before the test and still aside after the untest: one the
    # candidate runs as its type came back at the test, its `now` the resource's and each
    # timer that was timing resumed from it (decision 57), and was set aside again as it
    # then was; any other is untouched. Found from the states alone.
    for {name, state} <- Map.drop(aside, started) do
      back? = Enum.any?(candidate.instances, &(&1.name == name and &1.type == state.type))
      ce_reach(:round_trip_aside, back?)
      assert later.aside[name] == ce_back_again(back?, state, later.now)
    end

    # Each task as the test found it but for decision 40: a changed interval's next due
    # time is min(next_due, now + new interval) at the test, and again with the old one at
    # the untest, which moves it no further back.
    intervals = Map.new(candidate.tasks, &{&1.name, &1.interval})

    for %{name: name, interval: old} <- before.config.tasks do
      task = before.tasks[name]
      due = ce_next_due(task.next_due, {old, intervals[name]}, later.now)
      ce_reach(:round_trip_next_due, due != task.next_due)
      assert later.tasks[name] == %{task | next_due: due}
    end

    ce_reach(:round_trip)
  end

  defp ce_round!(_step, _w, _later, _report), do: :ok

  defp ce_back_again(false, state, _now), do: state

  defp ce_back_again(true, state, now) do
    env =
      Enum.reduce([["t1"], ["b1", "i1", "t"]], state.env, fn path, env ->
        times = ce_times(state.type, path)

        case get_in(env, path) do
          %{^times => 1, "last" => last} when last < now -> put_in(env, path ++ ["last"], now)
          _ -> env
        end
      end)

    %{state | env: env, now: now}
  end

  # The member whose 1 says a timer is timing, by its kind (M3-2): a `tof` in its delay and
  # a `tp` in its pulse, `.tt`, whatever the rung; a `ton` and an `rto`, `.en`, the rung's.
  # `t1`'s kind is its program type's, one for the walk; the leaf block's timer is a `ton`.
  defp ce_times(type, ["t1"]), do: ce_times(Process.get(:ce_timers)[type])
  defp ce_times(_type, _path), do: "en"

  defp ce_times(kind) when kind in ["tof", "tp"], do: "tt"
  defp ce_times(_kind), do: "en"

  defp ce_next_due(next, {same, same}, _now), do: next
  defp ce_next_due(next, {old, new}, now), do: min(min(next, now + new), now + old)

  # A path a switch started, or a joined tag, is as the round trip left it: there, or not.
  defp ce_exempt(nil, path, env), do: ce_write({:pruned, path, nil}, env)
  defp ce_exempt(value, path, env), do: ce_write({:added, path, value}, env)

  # Decision 57: a timer of an instance back from aside resumes from the untest. Decision
  # 56: so does one of a kept instance that the test gave back a resume of an earlier
  # switch's, the clock having moved since with no scan of it: the known limit of §4.9's
  # spike, time since the instance's last scan not counted.
  defp ce_resumed_back([name, path], name, {back?, undone?}, now, env) when back? or undone? do
    ce_reach(:round_trip_back, back?)
    put_in(env, String.split(path, ".") ++ ["last"], now)
  end

  defp ce_resumed_back(_path, _name, _back?, _now, env), do: env

  defp ce_restart(w) do
    {:ok, rt} = ce_attempt(fn -> Runtime.restart(w.rt, :cold) end)
    assert rt.aside == %{} and rt.generation == w.rt.generation
    ce_reach(:restart_in_edit, w.e != nil)
    %{w | rt: rt, model: ce_seed(rt), round: nil}
  end

  # A step on an edit that has ended, or that another has stepped past.
  defp ce_stale(%{stale: [old | _]} = w) do
    assert {:refused, :generation, _} = ce_attempt(fn -> ConfigEdit.test(old, w.rt) end)
    ce_reach(:stale)

    for superseded <- Enum.take(w.passed, 1) do
      assert {:refused, :generation, _} = ce_attempt(fn -> ConfigEdit.test(superseded, w.rt) end)
      ce_reach(:stale_superseded)
    end

    w
  end

  defp ce_stale(w), do: w

  defp ce_mistakes(w) do
    assert {:refused, :runtime, _} =
             ce_attempt(fn -> ConfigEdit.accept(ce_opaque(:nope), w.rt.config) end)

    assert {:refused, :not_a_configuration, _} =
             ce_attempt(fn -> ConfigEdit.accept(w.rt, ce_opaque(:nope)) end)

    assert {:refused, :name, _} =
             ce_attempt(fn -> ConfigEdit.accept(w.rt, %{w.rt.config | name: "other"}) end)

    bad = %{w.rt.config | instances: Enum.map(w.rt.config.instances, &%{&1 | task: "nowhere"})}
    {:refused, :invalid, message} = ce_attempt(fn -> ConfigEdit.accept(w.rt, bad) end)
    assert message == ce_message(fn -> Runtime.start(bad) end)

    if w.e do
      assert {:refused, :not_an_edit, _} =
               ce_attempt(fn -> ConfigEdit.test(ce_opaque(:nope), w.rt) end)

      assert {:refused, :runtime, _} =
               ce_attempt(fn -> ConfigEdit.test(w.e, ce_opaque(:nope)) end)

      other =
        Runtime.start(%{
          w.rt.config
          | tasks:
              Enum.map(w.rt.config.tasks, &if(&1.continuous, do: &1, else: %{&1 | priority: 9}))
        })

      other = %{other | generation: w.rt.generation}
      assert {:refused, :configuration, _} = ce_attempt(fn -> ConfigEdit.test(w.e, other) end)
    end

    w
  end

  defp ce_message(fun) do
    fun.()
  rescue
    error in ArgumentError -> error.message
  end

  # ---- the model, M2-1's with M2-4's var_externals, seeded from a resource --------------

  defp ce_seed(rt),
    do: %{
      now: rt.now,
      globals: rt.globals,
      states: rt.instances,
      anchor: Map.new(rt.tasks, fn {name, s} -> {name, s.next_due || 0} end),
      next: Map.new(rt.tasks, fn {name, s} -> {name, s.next_due} end),
      last: Map.new(rt.tasks, fn {name, s} -> {name, Map.get(s, :last, 0)} end),
      overlaps: Map.new(rt.tasks, fn {name, s} -> {name, s.overlaps} end),
      runs: Map.new(rt.tasks, fn {name, _} -> {name, 0} end),
      skipped: Map.new(rt.tasks, fn {name, _} -> {name, 0} end),
      cycles: 0
    }

  defp ce_model_cycle(config, model, elapsed, inputs) do
    now = model.now + elapsed
    globals = Map.merge(model.globals, inputs)
    model = %{model | now: now, globals: globals, cycles: model.cycles + 1}

    {plans, model} =
      config.tasks
      |> Enum.with_index()
      |> Enum.map_reduce(model, fn {task, index}, model ->
        sample = task.single && globals[task.single]
        edge? = task.single != nil and model.last[task.name] == 0 and sample == 1
        come? = task.interval != nil and model.next[task.name] <= now
        model = %{model | last: Map.put(model.last, task.name, sample || 0)}
        ce_model_plan({edge?, come?, sample}, task, index, model)
      end)

    due =
      plans
      |> Enum.reject(&is_nil/1)
      |> Enum.sort_by(fn {task, index, at} -> {task.priority, at, index} end)

    {model, events} =
      Enum.reduce(due, {model, []}, fn {task, _index, at}, {model, events} ->
        {model, events} = ce_model_run(task, at, model, events)

        Enum.reduce(
          for(i <- config.instances, i.task == task.name, do: i),
          {model, events},
          &ce_model_scan(config, &1, task.name, &2)
        )
      end)

    # M4-2: the untimed instances, with no task or `with` the continuous task, last, under
    # its name, or :none where none is declared.
    untimed = Enum.find_value(config.tasks, :none, &(&1.continuous && &1.name))

    {model, events} =
      Enum.reduce(
        for(i <- config.instances, i.task in [nil, untimed], do: i),
        {model, events},
        &ce_model_scan(config, &1, untimed, &2)
      )

    outputs =
      for g <- config.globals,
          g.at != nil and String.contains?(g.at, ".q."),
          into: %{},
          do: {g.name, model.globals[g.name]}

    {model, outputs, Enum.reverse(events)}
  end

  defp ce_model_plan({true, _come?, _sample}, task, index, model) do
    model =
      if task.interval && model.next[task.name] <= model.now,
        do: ce_model_skip(task, model),
        else: model

    {{task, index, model.now}, model}
  end

  defp ce_model_plan({false, true, 1}, task, _index, model), do: {nil, ce_model_skip(task, model)}

  defp ce_model_plan({false, true, _sample}, task, index, model),
    do: {{task, index, model.next[task.name]}, model}

  defp ce_model_plan({false, false, _sample}, _task, _index, model), do: {nil, model}

  defp ce_phase_after(model, task),
    do:
      model.next[task.name] +
        (div(model.now - model.next[task.name], task.interval) + 1) * task.interval

  defp ce_model_skip(task, model),
    do: %{model | next: Map.put(model.next, task.name, ce_phase_after(model, task))}

  defp ce_model_run(task, at, model, events) do
    case task.interval != nil and at == model.next[task.name] and at <= model.now do
      false ->
        {model, events}

      true ->
        missed = div(model.now - at, task.interval)

        model = %{
          model
          | next: Map.put(model.next, task.name, ce_phase_after(model, task)),
            overlaps: Map.update!(model.overlaps, task.name, &(&1 + missed))
        }

        {model, if(missed > 0, do: [{:overlap, task.name, missed} | events], else: events)}
    end
  end

  defp ce_model_scan(config, instance, task, {model, events}) do
    program = config.programs[instance.type]
    mine = for c <- config.connections, c.instance == instance.name, do: c
    section = fn c -> program.tags[c.member].section end
    externals = for {name, %Tag{section: :var_external}} <- program.tags, do: name

    inputs =
      for c <- mine,
          section.(c) == :var_input,
          into: %{},
          do: {c.member, if(is_binary(c.to), do: model.globals[c.to], else: c.to)}

    state = model.states[instance.name]
    state = %{state | env: Map.merge(state.env, Map.take(model.globals, externals))}

    {outputs, state} =
      Runtime.call(program, state, inputs, %Scan{now: model.now, first: state.first})

    globals = Map.merge(model.globals, Map.take(state.env, externals))
    state = %{state | env: Map.drop(state.env, externals)}

    globals =
      for c <- mine, section.(c) == :var_output, reduce: globals do
        globals -> Map.put(globals, c.to, outputs[c.member])
      end

    {%{model | states: Map.put(model.states, instance.name, state), globals: globals},
     [{:ran, task, instance.name, model.now} | events]}
  end

  # ---- M3-1: counters, against IEC's rules restated from the programs' text -------------

  # What the counter walk must be seen to do, at least once each.
  @ct_reach [
    :negative_preset,
    :counted,
    :first_held,
    :reset_held,
    :loaded,
    :overflow,
    :both_edges,
    :frozen,
    :kept_across,
    :edge_blocked,
    :edge_kept,
    :blocked_counted_later,
    :preset_moved,
    :preset_kept,
    :forecast_drops,
    :forecast_rises,
    :round_trip,
    :retype_refused,
    :restarted,
    # M5-5: a count in each width, an alias's among them, an unsigned counter stopped at
    # 0, an edit of a counter's width refused and one of its alias accepted.
    :in_int,
    :in_dint,
    :in_lint,
    :in_udint,
    :in_ulint,
    :in_alias,
    :underflow,
    :width_refused,
    :alias_kept
  ]

  @ct_inputs ~w(e1 e2 e3 rs ld on)

  test "counters run as IEC's, restated from the programs' text: every scan exact where no " <>
         "switch came since a counter last ran, no count an edit made, and each switch's " <>
         "report rebuilding the state" do
    :rand.seed(:exsss, {2026, 10, 314})
    Process.put(:ct_programs, %{})

    for _ <- 1..300 do
      spec = ct_spec()
      program = ct_program(spec)
      w = %{spec: spec, p: program, s: Runtime.instance(program), e: nil, c: nil}
      # A new instance's memories are as its program leaves them: each side counts as last
      # run under its own rung, with no switch since.
      clean = Map.new(ct_texts(spec), fn {side, _text} -> {side, true} end)
      w = %{w | s: w.s} |> Map.merge(%{clean: clean, last: ct_texts(spec), forecast: []})
      ct_walk(Map.merge(w, %{round: nil, blocked: [], restarted: false}), 60)
    end

    assert Process.get(:ct_reach, MapSet.new()) == MapSet.new(@ct_reach)
  end

  defp ct_reached(name), do: reached(:ct_reach, name)

  # A program's counters, drawn: an up counter `u` with its reset above or below its rung, a
  # down counter `d` with its load, an up-down counter `b`, its two sides on two rungs and
  # now and then a preset moved near the top, and a block `s1` holding an up counter, in
  # one of three versions of its body, which a `cal` on `on` runs.
  defp ct_spec,
    do: %{
      u:
        ct_maybe(fn ->
          %{p: pick([1, 2, 3]), chain: ct_chain(), reset: pick([:above, :below])}
        end),
      kind_u: "ctu",
      # M5-5: each counter's width, a type word's suffix, `_dint` the alias of none
      # (decisions 158 and 163).
      wu: ct_width(),
      wd: ct_width(),
      wb: ct_width(),
      d: ct_maybe(fn -> %{p: pick([1, 2]), chain: ct_chain(), load: pick([:above, :below])} end),
      b:
        ct_maybe(fn ->
          %{p: pick([2, 3]), up: ct_chain(), down: ct_chain(), big: pick([true, false])}
        end),
      s: ct_maybe(fn -> pick([1, 2, 3]) end)
    }

  defp ct_width, do: pick(["", "_int", "_dint", "_lint", "_udint", "_ulint"])

  # A signed width's negative presets, drawn as often as two of the five others; none for
  # an unsigned width, where a negative preset is refused, so one taken to an unsigned width
  # is made positive.
  defp ct_negatives(width) when width in ["_udint", "_ulint"], do: []
  defp ct_negatives(_signed), do: [-1, -3]

  defp ct_unsigned([], preset), do: abs(preset)
  defp ct_unsigned(_signed, preset), do: preset

  # The other word of a dint counter, which names the same type, or any width for another.
  defp ct_alias(""), do: "_dint"
  defp ct_alias("_dint"), do: ""
  defp ct_alias(_width), do: ct_width()

  # The width a suffix names, the alias's the dint's.
  defp ct_plain(""), do: "dint"
  defp ct_plain("_" <> width), do: width

  # Each width's limits, restated: IEC's Table 10, not Logex.Declarations.
  defp ct_limits("int"), do: {-32_768, 32_767}
  defp ct_limits("dint"), do: {-2_147_483_648, 2_147_483_647}
  defp ct_limits("lint"), do: {-9_223_372_036_854_775_808, 9_223_372_036_854_775_807}
  defp ct_limits("udint"), do: {0, 4_294_967_295}
  defp ct_limits("ulint"), do: {0, 18_446_744_073_709_551_615}

  # The word an instance's type is named by in a message: its kind's, with its width's
  # suffix but for the dint's, whichever word declared it (decision 163).
  defp ct_named(kind, width) when width in ["", "_dint"], do: kind
  defp ct_named(kind, width), do: kind <> width

  defp ct_maybe(fun), do: if(:rand.uniform(4) == 1, do: nil, else: fun.())

  defp ct_chain,
    do: for(_ <- 1..:rand.uniform(2), do: {pick([:xic, :xic, :xio]), pick(~w(e1 e2 e3))})

  # The candidate: one to two of the changes an edit may make, or now and then a change of
  # `u`'s kind, which accept refuses.
  defp ct_candidate(spec),
    do:
      Enum.reduce(1..:rand.uniform(2), spec, fn _, spec -> ct_change(:rand.uniform(18), spec) end)

  # Decision 191: a signed counter's preset may be negative, as IEC's PV may.
  defp ct_change(1, %{u: %{} = u} = spec),
    do: %{spec | u: %{u | p: pick([0, 1, 2, 3, 4] ++ ct_negatives(spec.wu))}}

  defp ct_change(2, %{u: %{} = u} = spec), do: %{spec | u: %{u | chain: ct_chain()}}
  defp ct_change(3, %{u: %{} = u} = spec), do: %{spec | u: %{u | reset: pick([:above, :below])}}
  defp ct_change(4, spec), do: %{spec | u: pick([nil, %{p: 2, chain: ct_chain(), reset: :above}])}
  defp ct_change(5, %{d: %{} = d} = spec), do: %{spec | d: %{d | p: pick([1, 2, 3])}}

  defp ct_change(6, %{b: %{} = b} = spec),
    do: %{spec | b: %{b | p: pick([0, 1, 2, 3, 4] ++ ct_negatives(spec.wb))}}

  defp ct_change(7, %{b: %{} = b} = spec), do: %{spec | b: %{b | up: ct_chain()}}
  defp ct_change(8, %{b: %{} = b} = spec), do: %{spec | b: %{b | down: ct_chain()}}
  defp ct_change(9, %{b: %{} = b} = spec), do: %{spec | b: %{b | big: not b.big}}
  defp ct_change(10, spec), do: %{spec | s: pick([nil, 1, 2, 3])}
  defp ct_change(11, %{u: %{}} = spec), do: %{spec | kind_u: pick(["ctud", spec.kind_u])}
  # M5-5: `u`'s width, which accept refuses, or its alias, which changes no type.
  defp ct_change(12, %{u: %{} = u} = spec) do
    width = pick([ct_width(), ct_alias(spec.wu)])
    %{spec | wu: width, u: %{u | p: ct_unsigned(ct_negatives(width), u.p)}}
  end

  # A preset moved, the commonest change, to 0 now and then, so that forecasts come both
  # ways under any seed (M5-5's review: 4 seeds in 20 saw no forecast one way or the other;
  # since, none in 81). `u`'s width moves to its alias as often as to any width.
  defp ct_change(n, spec) when n in 13..17, do: ct_change(pick([1, 6]), spec)
  defp ct_change(18, %{s: version} = spec) when version in [1, 2], do: %{spec | s: 3 - version}
  defp ct_change(_n, spec), do: %{spec | d: pick([nil, %{p: 1, chain: ct_chain(), load: :below}])}

  @ct_bodies %{
    1 => "xic go ctu c 2",
    2 => "xic go ctu c 4",
    3 => "xic go xio clr ctu c 2"
  }

  defp ct_body(version) do
    {:ok, tally} =
      Logex.compile(
        "function_block tally\nvar_input go bool\nvar_input clr bool\nvar_output q bool\n" <>
          "var c ctu\nxic clr ote c.r\n#{@ct_bodies[version]}\nxic c.q ote q",
        name: "tally"
      )

    tally
  end

  # Each spec's program, compiled once a run.
  defp ct_program(spec) do
    known = Process.get(:ct_programs)

    case known do
      %{^spec => program} ->
        program

      _ ->
        {:ok, program} = Logex.compile(ct_source(spec), name: "ct", types: ct_types(spec))
        Process.put(:ct_programs, Map.put(known, spec, program))

        if Enum.any?(ct_rungs(spec), &match?({:count, _, _, _, p} when p < 0, &1)),
          do: ct_reached(:negative_preset)

        program
    end
  end

  defp ct_types(%{s: nil}), do: []
  defp ct_types(%{s: version}), do: [ct_body(version)]

  defp ct_source(spec) do
    declarations =
      Enum.map(@ct_inputs, &"var_input #{&1} bool") ++
        ["var_output y bool", "var_output n dint"] ++
        if(spec.u, do: ["var u #{spec.kind_u}#{spec.wu}"], else: []) ++
        if(spec.d, do: ["var d ctd#{spec.wd}"], else: []) ++
        if(spec.b, do: ["var b ctud#{spec.wb}"], else: []) ++
        if(spec.s, do: ["var s1 tally"], else: [])

    Enum.join(declarations ++ Enum.map(ct_rungs(spec), &ct_text/1) ++ ["xic e2 move 1 n"], "\n")
  end

  # The rungs, in order, as the model runs them: `{:set, counter, member, chain-or-input}`,
  # `{:count, counter, side, chain, preset}`, `{:move, counter, value}` and `{:cal, version}`.
  defp ct_rungs(spec),
    do: ct_u(spec.u) ++ ct_d(spec.d) ++ ct_b(spec.b, spec.wb) ++ ct_s(spec.s)

  defp ct_u(nil), do: []

  defp ct_u(%{reset: :above} = u),
    do: [{:set, "u", "r", "rs"}, {:count, "u", :up, u.chain, u.p}]

  defp ct_u(%{reset: :below} = u),
    do: [{:count, "u", :up, u.chain, u.p}, {:set, "u", "r", "rs"}]

  defp ct_d(nil), do: []

  defp ct_d(%{load: :above} = d),
    do: [{:set, "d", "ld", "ld"}, {:count, "d", :down, d.chain, d.p}]

  defp ct_d(%{load: :below} = d),
    do: [{:count, "d", :down, d.chain, d.p}, {:set, "d", "ld", "ld"}]

  defp ct_b(nil, _width), do: []

  # M5-5: the preset moved to the top of `b`'s own width.
  defp ct_b(b, width),
    do:
      if(b.big, do: [{:move, "b", elem(ct_limits(ct_plain(width)), 1)}], else: []) ++
        [
          {:set, "b", "r", "rs"},
          {:set, "b", "ld", "ld"},
          {:count, "b", :up, b.up, b.p},
          {:count, "b", :down, b.down, b.p}
        ]

  defp ct_s(nil), do: []
  defp ct_s(version), do: [{:cal, version}]

  defp ct_text({:set, counter, member, input}), do: "xic #{input} ote #{counter}.#{member}"
  defp ct_text({:move, counter, value}), do: "xic e3 move #{value} #{counter}.pv"
  defp ct_text({:cal, _version}), do: "xic on cal s1 e1 rs y"

  defp ct_text({:count, counter, side, chain, preset}),
    do: "#{ct_chain_text(chain)} #{ct_mnemonic(side)} #{counter} #{preset}"

  defp ct_chain_text(chain), do: Enum.map_join(chain, " ", fn {c, input} -> "#{c} #{input}" end)

  defp ct_mnemonic(:up), do: "ctu"
  defp ct_mnemonic(:down), do: "ctd"

  # Each counter's side, to the text of the rung it runs under, its preset left out: the
  # block's by the text of its body's rung.
  defp ct_texts(spec),
    do:
      Map.new(
        for(
          {:count, counter, side, chain, _p} <- ct_rungs(spec),
          do: {{counter, side}, {ct_chain_text(chain), ct_mnemonic(side)}}
        ) ++
          for(
            {:cal, version} <- ct_rungs(spec),
            do: {{"s1.c", :up}, String.replace(@ct_bodies[version], ~r/ \d+$/, "")}
          )
      )

  # Each counter's kind and preset, in this spec.
  defp ct_kinds(spec),
    do:
      Map.new(
        if(spec.u, do: [{"u", {spec.kind_u, spec.u.p}}], else: []) ++
          if(spec.d, do: [{"d", {"ctd", spec.d.p}}], else: []) ++
          if(spec.b, do: [{"b", {"ctud", spec.b.p}}], else: []) ++
          if(spec.s, do: [{"s1.c", {"ctu", ct_body_preset(spec.s)}}], else: [])
      )

  defp ct_body_preset(2), do: 4
  defp ct_body_preset(_version), do: 2

  defp ct_walk(w, 0), do: w

  defp ct_walk(w, n),
    do:
      ct_walk(
        ct_op(pick(~w(scan scan scan scan accept test untest assemble cancel restart)a), w),
        n - 1
      )

  defp ct_level(name) when name in ["rs", "ld"], do: pick([0, 0, 0, 0, 0, 1])
  defp ct_level(_name), do: pick([0, 1])

  defp ct_running(%{e: nil} = w), do: {w.p, w.spec}
  defp ct_running(%{e: edit} = w), do: ct_side_of(Edit.stage(edit), w)

  defp ct_side_of(:testing, w), do: {Edit.running(w.e), w.c}
  defp ct_side_of(_stage, w), do: {Edit.running(w.e), w.spec}

  defp ct_op(:scan, w) do
    {program, spec} = ct_running(w)
    # A reset or a load is rare, so counts build up, to a preset and past it.
    inputs = for name <- @ct_inputs, :rand.uniform(3) == 1, into: %{}, do: {name, ct_level(name)}
    before = Runtime.put_inputs(program, w.s, inputs)
    {:ok, {_outputs, later}} = attempt(fn -> Runtime.scan(program, before, 10) end)
    w = ct_check_scan(w, spec, before, later)
    %{w | s: later, round: nil, restarted: false}
  end

  defp ct_op(:restart, w) do
    {program, spec} = ct_running(w)
    s = Runtime.restart(program, w.s, pick([:cold, :warm]))

    for {name, {kind, preset}} <- ct_kinds(spec) do
      assert ct_at(s.env, name) == ct_initial(kind, preset)
    end

    ct_reached(:restarted)
    clean = Map.new(ct_texts(spec), fn {side, _text} -> {side, true} end)
    %{w | s: s, clean: clean, last: ct_texts(spec), forecast: [], round: nil, restarted: true}
  end

  defp ct_op(:accept, %{e: nil} = w) do
    candidate = ct_candidate(w.spec)

    case Edit.accept(w.p, ct_program(candidate), w.s) do
      {:ok, edit, _forecast} ->
        # M5-5: an edit of `u`'s word that changes no type, its alias, is accepted.
        if w.spec.u != nil and candidate.u != nil and candidate.wu != w.spec.wu,
          do: ct_reached(:alias_kept)

        %{w | e: edit, c: candidate}

      {:error, [%Diagnostic{stage: :edit, message: message}]} ->
        was = ct_named(w.spec.kind_u, w.spec.wu)
        now = ct_named(candidate.kind_u, candidate.wu)
        assert w.spec.u != nil and candidate.u != nil and was != now

        assert message ==
                 "`u` is a #{was} in the running program and a #{now} in the candidate: a " <>
                   "tag's type changes only with a restart"

        ct_reached(
          if candidate.kind_u != w.spec.kind_u, do: :retype_refused, else: :width_refused
        )

        w
    end
  end

  defp ct_op(:test, %{e: e} = w) when e != nil,
    do: ct_switch(Edit.stage(e) in [:accepted, :untested], :test, w)

  defp ct_op(:untest, %{e: e} = w) when e != nil,
    do: ct_switch(Edit.stage(e) == :testing, :untest, w)

  defp ct_op(:assemble, %{e: e} = w) when e != nil,
    do: ct_finish(Edit.stage(e) == :testing, :assemble, w)

  defp ct_op(:cancel, %{e: e} = w) when e != nil,
    do: ct_finish(Edit.stage(e) in [:accepted, :untested], :cancel, w)

  defp ct_op(_op, w), do: w

  defp ct_finish(false, _step, w), do: w

  defp ct_finish(true, step, w) do
    {:ok, {program, s, _report}} = attempt(fn -> apply(Edit, step, [w.e, w.s]) end)
    spec = if step == :assemble, do: w.c, else: w.spec
    %{w | p: program, s: s, e: nil, c: nil, spec: spec, round: nil}
  end

  defp ct_switch(false, _step, w), do: w

  defp ct_switch(true, step, w) do
    first? = Edit.stage(w.e) == :accepted
    {from, to} = if step == :test, do: {w.spec, w.c}, else: {w.c, w.spec}
    {:ok, {edit, s, report}} = attempt(fn -> apply(Edit, step, [w.e, w.s]) end)

    # The writes the report lists rebuild the state.
    assert s.env == ct_rebuilt(w.s.env, report)

    for {name, {kind, preset}} <- ct_kinds(to) do
      was = ct_kinds(from)[name]
      now = ct_at(s.env, name)
      old = ct_at(w.s.env, name)

      # A counter both programs declare, of one kind, keeps its count and its memories, and
      # at a first test its `pv` moves to the new preset where logic left the old, or is
      # kept (decisions 23 and 27).
      if match?({^kind, _}, was) and is_map(old) do
        assert Map.delete(now, "pv") == Map.delete(old, "pv")
        ct_reached(:kept_across)

        if first? do
          {_kind, from_p} = was
          assert now["pv"] == if(old["pv"] == from_p, do: preset, else: old["pv"])
          if old["pv"] != now["pv"], do: ct_reached(:preset_moved)
          if old["pv"] == now["pv"] and now["pv"] != preset, do: ct_reached(:preset_kept)
        end
      end
    end

    blocked = for {:ons_blocked, path, _value} <- report, do: path
    if blocked != [], do: ct_reached(:edge_blocked)

    # A test then an untest with no scan between gives the counters back.
    if step == :untest and w.round != nil do
      for {name, _} <- ct_kinds(to), is_map(ct_at(w.round, name)) do
        assert ct_at(s.env, name) == ct_at(w.round, name)
      end

      ct_reached(:round_trip)
    end

    forecast =
      for {kind, name, {cv, pv}} <- report,
          kind in [:dn_drops, :dn_rises],
          do: {kind, name, cv, pv}

    round = if step == :test, do: w.s.env, else: nil
    blocked = Enum.uniq(blocked ++ w.blocked)

    # A restart with no scan since leaves every memory as a fresh instance's, so an edge a
    # counter sees after it is a real one, whatever its rung's text was.
    last = if w.restarted, do: Map.merge(w.last, ct_texts(to)), else: w.last

    %{w | e: edit, s: s, clean: %{}, forecast: forecast, round: round, blocked: blocked}
    |> Map.put(:last, last)
  end

  defp ct_rebuilt(env, report),
    do:
      Enum.reduce(report, env, fn
        {:added, name, value}, env -> ct_put(env, name, value)
        {:preset, name, {_from, to}}, env -> ct_put(env, name <> ".pv", to)
        _fact, env -> env
      end)

  defp ct_at(env, name), do: get_in(env, String.split(name, "."))
  defp ct_put(env, name, value), do: put_in(env, String.split(name, "."), value)

  defp ct_initial("ctu", p), do: %{"cu" => 0, "r" => 0, "pv" => p, "q" => 0, "cv" => 0, "ov" => 0}

  defp ct_initial("ctd", p),
    do: %{"cd" => 0, "ld" => 0, "pv" => p, "q" => 0, "cv" => 0, "un" => 0}

  defp ct_initial("ctud", p),
    do: %{
      "cu" => 0,
      "cd" => 0,
      "r" => 0,
      "ld" => 0,
      "pv" => p,
      "qu" => 0,
      "qd" => 0,
      "cv" => 0,
      "ov" => 0,
      "un" => 0
    }

  # The scan, restated: every counter as IEC's body leaves it, run rung by rung over the
  # input image, from the state before the scan. A side runs exactly where it has run under
  # its rung's text with no switch since; one a switch came before counts no edge, unless
  # it last ran under the same text, in which case it may count it, the edit's block list
  # being the implementation's and no part of this oracle.
  defp ct_check_scan(w, spec, before, later) do
    image = Map.take(before.env, @ct_inputs)
    texts = ct_texts(spec)
    kinds = ct_kinds(spec)
    start = Map.new(kinds, fn {name, _kind} -> {name, ct_at(before.env, name)} end)

    ctx = %{
      image: image,
      w: w,
      texts: texts,
      kinds: kinds,
      widths: %{"u" => spec.wu, "d" => spec.wd, "b" => spec.wb, "s1.c" => ""},
      first: before.first
    }

    {possible, ran} =
      Enum.reduce(ct_rungs(spec), {[{start, []}], []}, fn rung, acc -> ct_run(rung, acc, ctx) end)

    got = Map.new(kinds, fn {name, _kind} -> {name, ct_at(later.env, name)} end)
    matching = for {counters, notes} <- possible, counters == got, do: notes
    assert matching != [], "no IEC reading gives #{inspect(got)} from #{inspect(start)}"
    notes = hd(matching)
    Enum.each(for(note when is_atom(note) <- notes, do: note), &ct_reached/1)
    if Enum.count(notes, &(&1 == {:side, "b"})) == 2, do: ct_reached(:both_edges)

    # Each forecast holds at the next run, where the count and the preset did not move.
    for {kind, name, cv, pv} <- w.forecast,
        {name, :up} in ran or {name, :down} in ran,
        got[name]["cv"] == cv and got[name]["pv"] == pv do
      done = Map.get(got[name], "qu", got[name]["q"])
      assert done == if(kind == :dn_drops, do: 0, else: 1)
      ct_reached(if kind == :dn_drops, do: :forecast_drops, else: :forecast_rises)
    end

    if before.first and Enum.any?(ran, &ct_cond(&1, spec, image)), do: ct_reached(:first_held)

    forecast =
      Enum.reject(w.forecast, fn {_k, name, _cv, _pv} ->
        {name, :up} in ran or {name, :down} in ran
      end)

    %{
      w
      | clean: Enum.reduce(ran, w.clean, &Map.put(&2, &1, true)),
        last: Enum.reduce(ran, w.last, &Map.put(&2, &1, texts[&1])),
        forecast: forecast
    }
  end

  defp ct_cond({"s1.c", :up}, _spec, image), do: image["on"] == 1 and image["e1"] == 1

  defp ct_cond({counter, side}, spec, image) do
    [chain] = for {:count, ^counter, ^side, chain, _} <- ct_rungs(spec), do: chain
    ct_eval(chain, image)
  end

  defp ct_eval(chain, image),
    do: Enum.all?(chain, fn {c, input} -> c == :xic == (image[input] == 1) end)

  defp ct_run({:set, counter, member, input}, {possible, ran}, ctx),
    do:
      {for({c, notes} <- possible, do: {put_in(c, [counter, member], ctx.image[input]), notes}),
       ran}

  defp ct_run({:move, counter, value}, {possible, ran}, ctx),
    do:
      {for(
         {c, notes} <- possible,
         do: {ct_if(ctx.image["e3"] == 1, c, [counter, "pv"], value), notes}
       ), ran}

  defp ct_run({:count, counter, side, chain, _preset}, {possible, ran}, ctx) do
    cond = ct_eval(chain, ctx.image)
    {kind, _} = ctx.kinds[counter]

    {Enum.flat_map(possible, &ct_side(&1, counter, {kind, side, cond}, ctx)),
     [{counter, side} | ran]}
  end

  defp ct_run({:cal, version}, {possible, ran}, %{image: %{"on" => 1} = image} = ctx) do
    cond = image["e1"] == 1 and (version != 3 or image["rs"] != 1)

    possible =
      possible
      |> Enum.map(fn {c, notes} -> {put_in(c, ["s1.c", "r"], image["rs"]), notes} end)
      |> Enum.flat_map(&ct_side(&1, "s1.c", {"ctu", :up, cond}, ctx))

    {possible, [{"s1.c", :up} | ran]}
  end

  defp ct_run({:cal, _version}, {possible, ran}, _ctx) do
    ct_reached(:frozen)
    {possible, ran}
  end

  defp ct_if(true, map, path, value), do: put_in(map, path, value)
  defp ct_if(false, map, _path, _value), do: map

  # One side, as IEC's body runs it: the edge counted where allowed, and, where only a
  # switch's block decides it, both readings.
  defp ct_side({counters, notes}, counter, {kind, side, cond}, ctx) do
    key = {counter, side}
    clean? = Map.get(ctx.w.clean, key, false)

    allowed =
      cond do
        ctx.first -> [false]
        clean? -> [true]
        Map.get(ctx.w.last, key) == ctx.texts[key] -> [false, true]
        true -> [false]
      end

    c = counters[counter]
    mem = if side == :up, do: "cu", else: "cd"
    edge? = cond and c[mem] == 0
    held = if edge? and c["r"] == 1 and kind != "ctd", do: [:reset_held], else: []

    for ok <- Enum.uniq(allowed) do
      {c, counted} = ct_iec({kind, Map.fetch!(ctx.widths, counter)}, side, c, edge? and ok, cond)
      sides = for :counted <- counted, do: {:side, counter}
      why = ct_why(counted, ok, clean?, key, ctx)
      {Map.put(counters, counter, c), notes ++ held ++ counted ++ sides ++ why}
    end
  end

  # A count after a switch: one kept, where only the block list decides it, or a counter
  # an edit blocked, counting at a later run.
  defp ct_why([:counted | _], true, false, _key, _ctx), do: [:edge_kept]

  defp ct_why([:counted | _], true, true, {counter, side}, ctx),
    do:
      if("#{counter}.#{ct_memory(side)}" in ctx.w.blocked, do: [:blocked_counted_later], else: [])

  defp ct_why(_counted, _ok, _clean?, _key, _ctx), do: []

  defp ct_memory(:up), do: "cu"
  defp ct_memory(:down), do: "cd"

  # M5-5: each counter stops at its width's limits, decision 71 by width.
  defp ct_iec({kind, width}, side, c, edge, cond) do
    {min, max} = ct_limits(ct_plain(width))
    mem = ct_memory(side)
    ov = Map.get(c, "ov", 0)
    un = Map.get(c, "un", 0)

    {cv, ov, un, notes} =
      cond do
        kind != "ctd" and c["r"] == 1 -> {0, 0, 0, []}
        kind != "ctu" and c["ld"] == 1 -> {c["pv"], 0, 0, [:loaded]}
        edge and side == :up and c["cv"] == max -> {c["cv"], 1, un, [:overflow]}
        edge and side == :up -> {c["cv"] + 1, ov, un, [:counted | ct_in(width)]}
        edge and side == :down and c["cv"] == min -> {c["cv"], ov, 1, ct_under(min)}
        edge and side == :down -> {c["cv"] - 1, ov, un, [:counted | ct_in(width)]}
        true -> {c["cv"], ov, un, []}
      end

    c = Map.merge(c, %{"cv" => cv, mem => if(cond, do: 1, else: 0)})
    c = if Map.has_key?(c, "ov"), do: Map.put(c, "ov", ov), else: c
    c = if Map.has_key?(c, "un"), do: Map.put(c, "un", un), else: c
    {ct_done(kind, c), notes}
  end

  defp ct_in("_dint"), do: [:in_dint, :in_alias]
  defp ct_in(width), do: [:"in_#{ct_plain(width)}"]

  defp ct_under(0), do: [:underflow]
  defp ct_under(_min), do: []

  defp ct_done("ctu", c), do: %{c | "q" => if(c["cv"] >= c["pv"], do: 1, else: 0)}
  defp ct_done("ctd", c), do: %{c | "q" => if(c["cv"] <= 0, do: 1, else: 0)}

  defp ct_done("ctud", c),
    do: %{
      c
      | "qu" => if(c["cv"] >= c["pv"], do: 1, else: 0),
        "qd" => if(c["cv"] <= 0, do: 1, else: 0)
    }

  # ---- M3-2: the other timers, against IEC's and the conventional rules restated --------

  # What the timer walk must be seen to do, at least once each.
  @tm_reach [
    :delay_ended,
    :delay_cut,
    :pulsed,
    :retrigger_ignored,
    :pulse_held,
    :first_held,
    :reset_held,
    :retained,
    :rto_done,
    :frozen,
    :kept_across,
    :edge_blocked,
    :edge_kept,
    :blocked_pulsed_later,
    :preset_moved,
    :forecast_drops,
    :forecast_rises,
    :forecast_waits,
    :round_trip,
    :retype_refused,
    :restarted,
    :long_timed,
    :unit_refused
  ]

  @tm_inputs ~w(e1 e2 e3 rs on)

  # M5-6 (decision 158): a long timer counts nanoseconds, IEC's LTIME's unit, on logex's
  # clock of milliseconds, restated here: each millisecond adds 1,000,000.
  @tm_ns 1_000_000

  test "the other timers run as IEC's and the conventional RTO, restated from the " <>
         "programs' text: every scan exact but where only an edit's block decides a pulse, " <>
         "and each switch's report rebuilding the state" do
    :rand.seed(:exsss, {2026, 10, 1414})
    Process.put(:tm_programs, %{})

    for _ <- 1..300 do
      spec = tm_spec()
      program = tm_program(spec)
      clean = Map.new(tm_texts(spec), fn {key, _text} -> {key, true} end)

      w = %{
        spec: spec,
        p: program,
        s: Runtime.instance(program),
        e: nil,
        c: nil,
        clean: clean,
        last: tm_texts(spec),
        forecast: [],
        round: nil,
        blocked: [],
        restarted: false
      }

      tm_walk(w, 60)
    end

    assert Process.get(:tm_reach, MapSet.new()) == MapSet.new(@tm_reach)
  end

  defp tm_reached(name), do: reached(:tm_reach, name)

  # A program's timers, drawn: an off-delay `f`, a pulse `h`, a retentive `l` with its reset
  # above or below its rung, and a block `s1` holding a pulse, in one of three versions of
  # its body, which a `cal` on `on` runs. Presets are a few scans long.
  # Since M5-6 each of `f`, `h` and `l` is drawn a long timer half the time, `ns`, its
  # preset the same number of ms in ns.
  defp tm_spec,
    do: %{
      f: tm_maybe(fn -> %{p: pick([0, 20, 40]), chain: tm_chain(), ns: tm_ns()} end),
      kind_f: "tof",
      h: tm_maybe(fn -> %{p: pick([0, 20, 40]), chain: tm_chain(), ns: tm_ns()} end),
      l:
        tm_maybe(fn ->
          %{p: pick([30, 60]), chain: tm_chain(), reset: pick([:above, :below]), ns: tm_ns()}
        end),
      s: tm_maybe(fn -> pick([1, 2, 3]) end)
    }

  defp tm_ns, do: pick([false, true])

  defp tm_maybe(fun), do: if(:rand.uniform(4) == 1, do: nil, else: fun.())

  defp tm_chain,
    do: for(_ <- 1..:rand.uniform(2), do: {pick([:xic, :xic, :xio]), pick(~w(e1 e2 e3))})

  # The candidate: one or two of the changes an edit may make, or now and then a change of
  # `f`'s kind, which accept refuses.
  defp tm_candidate(spec),
    do:
      Enum.reduce(1..:rand.uniform(2), spec, fn _, spec -> tm_change(:rand.uniform(12), spec) end)

  defp tm_change(1, %{f: %{} = f} = spec), do: %{spec | f: %{f | p: pick([0, 10, 20, 40])}}
  defp tm_change(2, %{f: %{} = f} = spec), do: %{spec | f: %{f | chain: tm_chain()}}
  defp tm_change(3, %{h: %{} = h} = spec), do: %{spec | h: %{h | p: pick([0, 10, 20, 40])}}
  defp tm_change(4, %{h: %{} = h} = spec), do: %{spec | h: %{h | chain: tm_chain()}}
  defp tm_change(5, %{l: %{} = l} = spec), do: %{spec | l: %{l | p: pick([10, 30, 60])}}
  defp tm_change(6, %{l: %{} = l} = spec), do: %{spec | l: %{l | reset: pick([:above, :below])}}

  defp tm_change(7, spec),
    do: %{spec | h: pick([nil, %{p: 20, chain: tm_chain(), ns: tm_kept_ns(spec.h)}])}

  defp tm_change(8, spec), do: %{spec | s: pick([nil, 1, 2, 3])}
  defp tm_change(9, %{f: %{}} = spec), do: %{spec | kind_f: pick(["ton", spec.kind_f])}
  defp tm_change(10, %{f: %{} = f} = spec), do: %{spec | f: %{f | ns: not f.ns}}
  defp tm_change(11, spec), do: tm_change(pick([1, 3, 5]), spec)

  defp tm_change(_n, spec),
    do: %{spec | f: pick([nil, %{p: 20, chain: tm_chain(), ns: tm_kept_ns(spec.f)}])}

  # A timer an edit adds keeps the unit of the one it replaces, or is drawn.
  defp tm_kept_ns(%{ns: ns}), do: ns
  defp tm_kept_ns(nil), do: tm_ns()

  @tm_bodies %{
    1 => "xic go tp t 20",
    2 => "xic go tp t 40",
    3 => "xic go xio clr tp t 20"
  }

  defp tm_body(version) do
    {:ok, pulse} =
      Logex.compile(
        "function_block pulse\nvar_input go bool\nvar_input clr bool\nvar_output q bool\n" <>
          "var t tp\n#{@tm_bodies[version]}\nxic t.tt ote q",
        name: "pulse"
      )

    pulse
  end

  defp tm_program(spec) do
    known = Process.get(:tm_programs)

    case known do
      %{^spec => program} ->
        program

      _ ->
        types = if spec.s, do: [tm_body(spec.s)], else: []
        {:ok, program} = Logex.compile(tm_source(spec), name: "tm", types: types)
        Process.put(:tm_programs, Map.put(known, spec, program))
        program
    end
  end

  defp tm_source(spec) do
    declarations =
      Enum.map(@tm_inputs, &"var_input #{&1} bool") ++
        ["var_output y bool"] ++
        for({name, word} <- Enum.sort(tm_words(spec)), name != "s1.t", do: "var #{name} #{word}") ++
        if(spec.s, do: ["var s1 pulse"], else: [])

    Enum.join(declarations ++ Enum.map(tm_rungs(spec), &tm_text/1), "\n")
  end

  # The rungs, in order, as the model runs them: `{:timer, name, kind, chain, preset}`,
  # `{:set, name, member, input}` and `{:cal, version}`.
  # A long timer's preset is in ns (M5-6).
  defp tm_rungs(spec),
    do:
      if(spec.f, do: [{:timer, "f", spec.kind_f, spec.f.chain, tm_p(spec.f)}], else: []) ++
        if(spec.h, do: [{:timer, "h", "tp", spec.h.chain, tm_p(spec.h)}], else: []) ++
        tm_l(spec.l) ++ if(spec.s, do: [{:cal, spec.s}], else: [])

  defp tm_p(%{p: p, ns: true}), do: p * @tm_ns
  defp tm_p(%{p: p}), do: p

  defp tm_l(nil), do: []

  defp tm_l(%{reset: :above} = l),
    do: [{:set, "l", "r", "rs"}, {:timer, "l", "rto", l.chain, tm_p(l)}]

  defp tm_l(%{reset: :below} = l),
    do: [{:timer, "l", "rto", l.chain, tm_p(l)}, {:set, "l", "r", "rs"}]

  # Each timer's type word, its kind's or since M5-6 its long timer's, and what a
  # millisecond adds to its `.acc`.
  defp tm_words(spec),
    do:
      Map.new(
        for(
          {name, kind, %{ns: ns}} <- [
            {"f", spec.kind_f, spec.f},
            {"h", "tp", spec.h},
            {"l", "rto", spec.l}
          ],
          do: {name, if(ns, do: "#{kind}_ltime", else: kind)}
        )
      )

  defp tm_scales(spec),
    do:
      Map.new(tm_words(spec), fn {name, word} ->
        {name, if(word =~ "_ltime", do: @tm_ns, else: 1)}
      end)

  defp tm_text({:timer, name, kind, chain, preset}),
    do: "#{tm_chain_text(chain)} #{kind} #{name} #{preset}"

  defp tm_text({:set, name, member, input}), do: "xic #{input} ote #{name}.#{member}"
  defp tm_text({:cal, _version}), do: "xic on cal s1 e1 rs y"

  defp tm_chain_text(chain), do: Enum.map_join(chain, " ", fn {c, input} -> "#{c} #{input}" end)

  # Each pulse's rung text, its preset left out, the block's by its body's rung: what decides
  # whether an edit blocks its edge.
  defp tm_texts(spec),
    do:
      Map.new(
        for({:timer, "h", _kind, chain, _p} <- tm_rungs(spec), do: {"h", tm_chain_text(chain)}) ++
          for(
            {:cal, version} <- tm_rungs(spec),
            do: {"s1.t", String.replace(@tm_bodies[version], ~r/ \d+$/, "")}
          )
      )

  # Each timer's kind and preset, in this spec.
  defp tm_kinds(spec),
    do:
      Map.new(
        for({:timer, name, kind, _chain, p} <- tm_rungs(spec), do: {name, {kind, p}}) ++
          for({:cal, version} <- tm_rungs(spec), do: {"s1.t", {"tp", tm_body_preset(version)}})
      )

  defp tm_body_preset(2), do: 40
  defp tm_body_preset(_version), do: 20

  defp tm_walk(w, 0), do: w

  defp tm_walk(w, n),
    do:
      tm_walk(
        tm_op(pick(~w(scan scan scan scan scan accept test untest assemble cancel restart)a), w),
        n - 1
      )

  defp tm_running(%{e: nil} = w), do: {w.p, w.spec}
  defp tm_running(%{e: edit} = w), do: tm_side_of(Edit.stage(edit), w)

  defp tm_side_of(:testing, w), do: {Edit.running(w.e), w.c}
  defp tm_side_of(_stage, w), do: {Edit.running(w.e), w.spec}

  defp tm_level("rs"), do: pick([0, 0, 0, 0, 0, 1])
  defp tm_level(_name), do: pick([0, 1])

  defp tm_op(:scan, w) do
    {program, spec} = tm_running(w)
    inputs = for name <- @tm_inputs, :rand.uniform(3) == 1, into: %{}, do: {name, tm_level(name)}
    before = Runtime.put_inputs(program, w.s, inputs)
    ms = pick([0, 5, 10, 10, 20, 45])
    {:ok, {_outputs, later}} = attempt(fn -> Runtime.scan(program, before, ms) end)
    w = tm_check_scan(w, spec, before, later)
    %{w | s: later, round: nil, restarted: false}
  end

  defp tm_op(:restart, w) do
    {program, spec} = tm_running(w)
    s = Runtime.restart(program, w.s, pick([:cold, :warm]))

    for {name, {kind, preset}} <- tm_kinds(spec),
        do: assert(tm_at(s.env, name) == tm_initial(kind, preset))

    tm_reached(:restarted)
    clean = Map.new(tm_texts(spec), fn {key, _text} -> {key, true} end)
    %{w | s: s, clean: clean, last: tm_texts(spec), forecast: [], round: nil, restarted: true}
  end

  defp tm_op(:accept, %{e: nil} = w) do
    candidate = tm_candidate(w.spec)

    case Edit.accept(w.p, tm_program(candidate), w.s) do
      {:ok, edit, _forecast} ->
        %{w | e: edit, c: candidate}

      # A timer of another type, a kind or since M5-6 a unit, changes only with a restart.
      {:error, [%Diagnostic{stage: :edit, message: message}]} ->
        {old, new} = {tm_words(w.spec), tm_words(candidate)}
        assert [name] = for({n, word} <- old, Map.get(new, n, word) != word, do: n)

        assert message =~
                 "`#{name}` is #{tm_a(old[name])} in the running program and #{tm_a(new[name])}"

        tm_reached(
          if old[name] =~ "_ltime" or new[name] =~ "_ltime",
            do: :unit_refused,
            else: :retype_refused
        )

        w
    end
  end

  defp tm_op(:test, %{e: e} = w) when e != nil,
    do: tm_switch(Edit.stage(e) in [:accepted, :untested], :test, w)

  defp tm_op(:untest, %{e: e} = w) when e != nil,
    do: tm_switch(Edit.stage(e) == :testing, :untest, w)

  defp tm_op(:assemble, %{e: e} = w) when e != nil,
    do: tm_finish(Edit.stage(e) == :testing, :assemble, w)

  defp tm_op(:cancel, %{e: e} = w) when e != nil,
    do: tm_finish(Edit.stage(e) in [:accepted, :untested], :cancel, w)

  defp tm_op(_op, w), do: w

  defp tm_finish(false, _step, w), do: w

  defp tm_finish(true, step, w) do
    {:ok, {program, s, _report}} = attempt(fn -> apply(Edit, step, [w.e, w.s]) end)
    spec = if step == :assemble, do: w.c, else: w.spec
    %{w | p: program, s: s, e: nil, c: nil, spec: spec, round: nil}
  end

  defp tm_switch(false, _step, w), do: w

  defp tm_switch(true, step, w) do
    first? = Edit.stage(w.e) == :accepted
    {from, to} = if step == :test, do: {w.spec, w.c}, else: {w.c, w.spec}
    {:ok, {edit, s, report}} = attempt(fn -> apply(Edit, step, [w.e, w.s]) end)

    # The writes the report lists rebuild the state.
    assert s.env == tm_rebuilt(w.s.env, report)

    # A timer both programs run, of one kind, keeps every member but `.pre` and `last`, and
    # at a first test its `.pre` moves to the new preset where logic left the old, which no
    # logic here moves (decisions 23 and 27).
    for {name, {kind, preset}} <- tm_kinds(to),
        {^kind, from_p} <- [tm_kinds(from)[name]],
        old = tm_at(w.s.env, name),
        is_map(old) do
      now = tm_at(s.env, name)
      assert Map.drop(now, ["pre", "last"]) == Map.drop(old, ["pre", "last"])
      tm_reached(:kept_across)

      if first? do
        assert now["pre"] == if(old["pre"] == from_p, do: preset, else: old["pre"])
        if old["pre"] != now["pre"], do: tm_reached(:preset_moved)
      end
    end

    blocked = for {:ons_blocked, path, _value} <- report, do: path
    if blocked != [], do: tm_reached(:edge_blocked)

    if step == :untest and w.round != nil do
      for {name, _} <- tm_kinds(to),
          is_map(tm_at(w.round, name)),
          do: assert(tm_at(s.env, name) == tm_at(w.round, name))

      tm_reached(:round_trip)
    end

    kinds = tm_kinds(to)

    forecast =
      for {kind, name, {_acc, _pre}} <- report,
          kind in [:dn_drops, :dn_rises],
          do: {kind, name, elem(kinds[name], 0)}

    # Exactly the forecasts each type's rule gives, from the state the switch leaves, for
    # each timer whose `.pre` it moved (decisions 93 to 95).
    expected =
      for {:preset, name, {_from, _to}} <- report,
          {type, _p} = kinds[name],
          kind <- tm_expected(type, tm_at(s.env, name)),
          do: {kind, name, type}

    assert Enum.sort(forecast) == Enum.sort(expected)

    round = if step == :test, do: w.s.env, else: nil
    last = if w.restarted, do: Map.merge(w.last, tm_texts(to)), else: w.last

    %{
      w
      | e: edit,
        s: s,
        clean: %{},
        forecast: forecast,
        round: round,
        blocked: Enum.uniq(blocked ++ w.blocked),
        last: last
    }
  end

  defp tm_rebuilt(env, report),
    do:
      Enum.reduce(report, env, fn
        {:added, name, value}, env -> tm_put(env, name, value)
        {:preset, name, {_from, to}}, env -> tm_put(env, name <> ".pre", to)
        {:resumed, name, gap}, env -> update_in(env, tm_path(name <> ".last"), &(&1 + gap))
        {:resume_undone, name, gap}, env -> update_in(env, tm_path(name <> ".last"), &(&1 - gap))
        _fact, env -> env
      end)

  defp tm_path(name), do: String.split(name, ".")
  defp tm_at(env, name), do: get_in(env, tm_path(name))
  defp tm_put(env, name, value), do: put_in(env, tm_path(name), value)

  defp tm_initial("rto", p), do: Map.put(tm_initial("ton", p), "r", 0)

  defp tm_initial(_kind, p),
    do: %{"pre" => p, "acc" => 0, "dn" => 0, "tt" => 0, "en" => 0, "last" => 0}

  # The scan, restated: every timer as its rule leaves it, run rung by rung over the input
  # image at the scan's `now`, from the state before the scan. A pulse a switch came before
  # starts on an edge only where it last ran under the same rung text, and then may or may
  # not, the edit's block list being the implementation's and no part of this oracle.
  defp tm_check_scan(w, spec, before, later) do
    image = Map.take(before.env, @tm_inputs)
    kinds = tm_kinds(spec)
    start = Map.new(kinds, fn {name, _} -> {name, tm_at(before.env, name)} end)

    ctx = %{
      image: image,
      w: w,
      texts: tm_texts(spec),
      first: before.first,
      now: later.now,
      scales: tm_scales(spec)
    }

    {possible, ran} =
      Enum.reduce(tm_rungs(spec), {[{start, []}], %{}}, fn rung, acc -> tm_run(rung, acc, ctx) end)

    got = Map.new(kinds, fn {name, _} -> {name, tm_at(later.env, name)} end)
    matching = for {timers, notes} <- possible, timers == got, do: notes
    assert matching != [], "no reading gives #{inspect(got)} from #{inspect(start)}"
    Enum.each(hd(matching), &tm_reached/1)

    # Each forecast holds at the timer's next run where its rule says it is decided.
    for {kind, name, type} <- w.forecast, Map.has_key?(ran, name) do
      tm_forecast(kind, type, got[name], ran[name])
    end

    forecast =
      Enum.reject(w.forecast, fn {kind, name, type} ->
        Map.has_key?(ran, name) and not tm_pending(kind, type, got[name], ran[name])
      end)

    %{
      w
      | clean: Enum.reduce(Map.keys(ran), w.clean, &Map.put(&2, &1, true)),
        last: Enum.reduce(Map.keys(ran), w.last, &tm_last(&2, &1, ctx.texts)),
        forecast: forecast
    }
  end

  defp tm_last(last, name, texts) when is_map_key(texts, name),
    do: Map.put(last, name, texts[name])

  defp tm_last(last, _name, _texts), do: last

  defp tm_expected("tof", %{"tt" => 1, "acc" => acc, "pre" => pre}) when acc >= pre,
    do: [:dn_drops]

  # A tof whose rung was true, its `.pre` moved to 0: its delay ends on the falling edge's
  # own scan (decision 93).
  defp tm_expected("tof", %{"en" => 1, "pre" => pre}) when pre <= 0, do: [:dn_drops]

  defp tm_expected("tp", %{"tt" => 1, "acc" => acc, "pre" => pre}) when acc >= pre,
    do: [:dn_rises]

  defp tm_expected("rto", %{"dn" => 1, "acc" => acc, "pre" => pre}) when acc < pre,
    do: [:dn_drops]

  defp tm_expected("rto", %{"dn" => 0, "acc" => acc, "pre" => pre}) when acc >= pre,
    do: [:dn_rises]

  defp tm_expected("ton", %{"dn" => 1, "acc" => acc, "pre" => pre}) when acc < pre,
    do: [:dn_drops]

  defp tm_expected("ton", %{"dn" => 0, "en" => 1, "acc" => acc, "pre" => pre})
       when acc >= pre,
       do: [:dn_rises]

  defp tm_expected(_type, _timer), do: []

  # A tof's drop holds where its next run finds its rung false; a pulse's end at its next run
  # whatever, `.dn` the rung's; an rto's at its next run with its rung true and `r` 0, a drop
  # where enough time has not passed.
  defp tm_forecast(:dn_drops, "tof", timer, {false, _r}) do
    assert timer["dn"] == 0
    tm_reached(:forecast_drops)
  end

  defp tm_forecast(:dn_rises, "tp", timer, {cond, _r}) do
    assert timer["tt"] == 0 and timer["dn"] == if(cond, do: 1, else: 0)
    tm_reached(:forecast_rises)
  end

  defp tm_forecast(:dn_drops, "rto", timer, {true, 0}) do
    assert timer["dn"] == 0 or timer["acc"] == timer["pre"]
    tm_reached(:forecast_drops)
  end

  defp tm_forecast(:dn_rises, "rto", timer, {true, 0}) do
    assert timer["dn"] == 1
    tm_reached(:forecast_rises)
  end

  defp tm_forecast(_kind, _type, _timer, _run), do: :ok

  # A tof's drop at a preset of 0 still holds after a run with its rung true, which keeps
  # `.dn` set: it waits for the next run with its rung false.
  defp tm_pending(:dn_drops, "tof", %{"pre" => pre}, {true, _r}) when pre <= 0 do
    tm_reached(:forecast_waits)
    true
  end

  defp tm_pending(_kind, _type, _timer, _run), do: false

  defp tm_eval(chain, image),
    do: Enum.all?(chain, fn {c, input} -> c == :xic == (image[input] == 1) end)

  defp tm_run({:set, name, member, input}, {possible, ran}, ctx),
    do:
      {for({t, notes} <- possible, do: {put_in(t, [name, member], ctx.image[input]), notes}), ran}

  defp tm_run({:timer, name, kind, chain, _p}, {possible, ran}, ctx) do
    cond = tm_eval(chain, ctx.image)

    {Enum.flat_map(possible, &tm_one(&1, name, {kind, cond}, ctx)),
     tm_ran(ran, name, cond, possible)}
  end

  defp tm_run({:cal, version}, {possible, ran}, %{image: %{"on" => 1} = image} = ctx) do
    cond = image["e1"] == 1 and (version != 3 or image["rs"] != 1)

    {Enum.flat_map(possible, &tm_one(&1, "s1.t", {"tp", cond}, ctx)),
     tm_ran(ran, "s1.t", cond, possible)}
  end

  defp tm_run({:cal, _version}, {possible, ran}, _ctx) do
    tm_reached(:frozen)
    {possible, ran}
  end

  # The timers that ran, each with its rung and, for an rto, the reset it saw.
  defp tm_ran(ran, name, cond, [{timers, _} | _]),
    do: Map.put(ran, name, {cond, Map.get(timers[name], "r", 0)})

  defp tm_one({timers, notes}, name, {kind, cond}, ctx) do
    t = timers[name]
    scale = Map.get(ctx.scales, name, 1)
    elapsed = if is_integer(t["last"]), do: max(ctx.now - t["last"], 0) * scale, else: 0
    long = if scale > 1 and elapsed > 0, do: [:long_timed], else: []

    edges = tm_edges(name, kind, ctx)
    first = if ctx.first and kind == "tp" and cond and t["en"] == 0, do: [:first_held], else: []

    for {t2, more} <- tm_rule(kind, t, cond, elapsed, edges) do
      {Map.put(timers, name, Map.put(t2, "last", ctx.now)),
       notes ++ more ++ first ++ long ++ tm_why(:pulsed in more, edges, name, ctx)}
    end
  end

  # A pulse after a switch: one only the block list decided, or one an edit blocked,
  # pulsing at a later run.
  defp tm_why(true, [false, true], _name, _ctx), do: [:edge_kept]

  defp tm_why(true, [true], name, ctx),
    do: if((name <> ".en") in ctx.w.blocked, do: [:blocked_pulsed_later], else: [])

  defp tm_why(_pulsed, _edges, _name, _ctx), do: []

  # Where a pulse may start on an edge: never on a first scan; always where it last ran
  # under its own text with no switch since; maybe where a switch came since and the text is
  # the same; never where the text changed.
  defp tm_edges(_name, kind, _ctx) when kind != "tp", do: [true]

  defp tm_edges(name, "tp", ctx) do
    cond do
      ctx.first -> [false]
      Map.get(ctx.w.clean, name, false) -> [true]
      Map.get(ctx.w.last, name) == ctx.texts[name] -> [false, true]
      true -> [false]
    end
  end

  # The off-delay timer: IEC's TOF, `.dn` its Q (decision 93).
  defp tm_rule("tof", t, true, _elapsed, _edges) do
    notes = if t["tt"] == 1, do: [:delay_cut], else: []
    [{%{t | "acc" => 0, "dn" => 1, "tt" => 0, "en" => 1}, notes}]
  end

  defp tm_rule("tof", t, false, elapsed, _edges) do
    lim = max(t["pre"], 0)

    cond do
      t["tt"] == 1 or t["en"] == 1 ->
        acc = min(max(t["acc"], 0) + if(t["tt"] == 1, do: elapsed, else: 0), lim)
        on = if acc < lim, do: 1, else: 0
        notes = if on == 0 and t["tt"] == 1, do: [:delay_ended], else: []
        [{%{t | "acc" => acc, "dn" => on, "tt" => on, "en" => 0}, notes}]

      true ->
        [{%{t | "dn" => 0, "tt" => 0, "en" => 0}, []}]
    end
  end

  # The on-delay timer, which `f` becomes where an edit that drops it changes its kind too
  # and a later one gives it back.
  defp tm_rule("ton", t, true, elapsed, _edges) do
    lim = max(t["pre"], 0)
    acc = min(max(t["acc"], 0) + if(t["en"] == 1, do: elapsed, else: 0), lim)
    done = if acc == lim, do: 1, else: 0
    [{%{t | "acc" => acc, "dn" => done, "tt" => 1 - done, "en" => 1}, []}]
  end

  defp tm_rule("ton", t, false, _elapsed, _edges),
    do: [{%{t | "acc" => 0, "dn" => 0, "tt" => 0, "en" => 0}, []}]

  # The pulse timer: IEC's TP, its pulse `.tt` (decisions 74, 75 and 94).
  defp tm_rule("tp", t, cond, elapsed, edges) do
    lim = max(t["pre"], 0)

    for edge_ok <- Enum.uniq(edges) do
      edge = cond and t["en"] == 0

      cond do
        t["tt"] == 1 ->
          acc = min(max(t["acc"], 0) + elapsed, lim)
          ignored = if edge, do: [:retrigger_ignored], else: []
          tm_pulse(t, acc, lim, cond, ignored)

        edge and edge_ok ->
          tm_pulse(t, 0, lim, cond, [:pulsed])

        cond ->
          held = if t["dn"] == 1, do: [:pulse_held], else: []
          {%{t | "tt" => 0, "en" => 1}, held}

        true ->
          {%{t | "acc" => 0, "dn" => 0, "tt" => 0, "en" => 0}, []}
      end
    end
  end

  # The retentive timer: the conventional RTO, cleared by `r` (decisions 76, 90 and 95).
  defp tm_rule("rto", t, cond, elapsed, _edges) do
    lim = max(t["pre"], 0)
    en = if cond, do: 1, else: 0

    cond do
      t["r"] == 1 ->
        held = if cond and t["acc"] > 0, do: [:reset_held], else: []
        [{%{t | "acc" => 0, "dn" => 0, "tt" => 0, "en" => en}, held}]

      cond ->
        kept = if t["en"] == 0 and t["acc"] > 0, do: [:retained], else: []
        acc = min(max(t["acc"], 0) + if(t["en"] == 1, do: elapsed, else: 0), lim)
        done = if acc == lim, do: 1, else: 0
        notes = if done == 1 and t["dn"] == 0, do: [:rto_done], else: []
        [{%{t | "acc" => acc, "dn" => done, "tt" => 1 - done, "en" => 1}, kept ++ notes}]

      true ->
        [{%{t | "tt" => 0, "en" => 0}, []}]
    end
  end

  defp tm_pulse(t, acc, lim, cond, notes) do
    cond do
      acc < lim -> {%{t | "acc" => acc, "dn" => 0, "tt" => 1, "en" => tm_bit(cond)}, notes}
      cond -> {%{t | "acc" => acc, "dn" => 1, "tt" => 0, "en" => 1}, notes}
      true -> {%{t | "acc" => 0, "dn" => 0, "tt" => 0, "en" => 0}, notes}
    end
  end

  defp tm_bit(true), do: 1
  defp tm_bit(false), do: 0

  defp tm_a("rto" <> _ = word), do: "an #{word}"
  defp tm_a(word), do: "a #{word}"

  # ---- M3-3: arithmetic, against IEC's rules restated as Elixir --------------------------

  # What the arithmetic walk must be seen to do, at least once each.
  @ar_reach [
              :above,
              :below,
              :far_past,
              :div_by_zero,
              :mod_by_zero,
              :min_by_minus_one,
              :neg_min,
              :abs_min,
              :mod_negative,
              :cut,
              :de_energised,
              :block_fault,
              :block_frozen,
              :event_fault,
              :edit_kept,
              :restarted,
              :negative_literal,
              :widened
            ] ++ for(type <- @width_types, do: {:wrapped, type})

  # Since M5-4 every tag of a program is of a width drawn from `@widths`, each width's
  # range from IEC's footnotes, restated above and never read from Logex.Declarations, and
  # an instruction's sources only of a width Figure 11 widens into its destination's, the
  # type it computes in (decision 147): the oracle wraps there (decision 146).

  # Values near a width's limits and near 0, which a source, a literal or an input takes:
  # the limits, one inside each, small values of each sign, and 2^(N/2), whose square passes
  # the top.
  defp ar_pool(type) do
    first..last//1 = width_range(type)
    {_kind, n} = Map.fetch!(@widths, type)
    root = Integer.pow(2, div(n, 2))

    Enum.filter(
      [0, 0, 1, -1, 2, -2, 3, -3, 7, -7, root, -root, last, first, last - 1, first + 1],
      &(&1 in first..last//1)
    )
  end

  @ar_ops [:add, :sub, :mul, :div, :mod, :neg, :abs]

  # Since M5-4 every tag is of a width drawn from the eight, and the reach adds a source
  # widened and a wrap in each width: at 150 specs it holds at this seed and, in its
  # place, at each of {n, 10, 333}, n from 1 to 30, the rarest atom a width's minimum
  # divided by -1, which a dividend and a divisor drawn for it make likely.
  test "arithmetic runs as IEC's rules restated at every width: every scan's results, " <>
         "power out and faults agree with an oracle that knows nothing of logex, alone, in a " <>
         "block, in a resource and across an edit" do
    :rand.seed(:exsss, {2026, 10, 333})

    for _ <- 1..150 do
      spec = ar_spec()
      program = ar_program(spec)
      ar_lone(spec, program, 24)
      ar_resource(spec, program, 8)
    end

    assert Process.get(:ar_reach, MapSet.new()) == MapSet.new(@ar_reach)
  end

  defp ar_reached(name), do: reached(:ar_reach, name)

  # The types a spec's tags take: the block's one width, if it has a block, and each
  # program tag's; `x0` and `x1`, which its `cal` gives the block's var_inputs, of a width
  # that widens into the block's (decision 159), and `yb`, which it fills, the block's.
  defp ar_types do
    block = pick(@width_types)
    into = Enum.filter(@width_types, &(&1 == block or block in Map.fetch!(@figure_11, &1)))

    Map.new(~w(x2 x3 v0 v1 v2 y0 y1), &{&1, pick(@width_types)})
    |> Map.merge(%{"x0" => pick(into), "x1" => pick(into), "yb" => block, "block" => block})
  end

  # A program's rungs over four inputs, three vars and two outputs, each rung an optional
  # contact on `g`, one to three arithmetic instructions and an optional coil, and now and
  # then a block `c1` of the same kind, run by a `cal` on `gb`. Each var starts at a value
  # drawn near a limit of its type.
  defp ar_spec(types \\ ar_types(), inits \\ nil, block \\ :draw) do
    inits = inits || for(i <- 0..2, do: pick(ar_pool(types["v#{i}"])))
    block_types = Map.new(~w(a b w r), &{&1, types["block"]})

    %{
      types: types,
      inits: inits,
      rungs:
        for(
          _ <- 1..Enum.random(2..6),
          do:
            ar_rung(
              types,
              ~w(x0 x1 x2 x3 v0 v1 v2 y0 y1),
              ~w(v0 v1 v2 y0 y1),
              ~w(ok0 ok1 ok2),
              "g"
            )
        ),
      block: ar_block(block, block_types)
    }
  end

  defp ar_block(:draw, types) do
    if(:rand.uniform(3) == 1,
      do: nil,
      else: %{
        init: pick(ar_pool(types["w"])),
        rungs:
          for(_ <- 1..Enum.random(1..3), do: ar_rung(types, ~w(a b w r), ~w(w r), ~w(ok), "go"))
      }
    )
  end

  defp ar_block(block, _types), do: block

  defp ar_rung(types, sources, destinations, coils, contact) do
    {pick([nil, nil, {:xic, contact}, {:xio, contact}]),
     for(
       _ <- 1..Enum.random(1..3),
       do: ar_instruction(pick(@ar_ops), types, sources, pick(destinations))
     ), pick([nil | coils])}
  end

  # The sources an instruction into `destination` may read: the tags of a width Figure 11
  # widens into its type, its own among them; and a `neg` into an unsigned destination,
  # which is refused (decision 145), is an `abs` instead.
  defp ar_instruction(op, types, sources, destination) do
    into = types[destination]
    widening = Enum.filter(sources, &(types[&1] == into or into in @figure_11[types[&1]]))
    ar_instruction_of(ar_op(op, Map.fetch!(@widths, into)), {into, widening}, destination)
  end

  defp ar_op(:neg, {:unsigned, _}), do: :abs
  defp ar_op(op, _width), do: op

  defp ar_instruction_of(op, sources, destination) when op in [:neg, :abs],
    do: {op, [ar_source(sources)], destination}

  defp ar_instruction_of(op, sources, destination) when op in [:div, :mod],
    do: {op, [ar_dividend(op, sources), ar_divisor(sources)], destination}

  defp ar_instruction_of(op, sources, destination),
    do: {op, [ar_source(sources), ar_source(sources)], destination}

  defp ar_source({into, tags}),
    do: if(:rand.uniform(3) == 1, do: {:lit, pick(ar_pool(into))}, else: {:tag, pick(tags)})

  # Since M5-4 one dividend of a `div` in four is its type's least value, and one divisor
  # in four into a signed type is -1, so that the minimum of each width is divided by -1
  # often enough for the reach, eight widths sharing what one dint had.
  defp ar_dividend(:div, {into, _tags} = sources),
    do: ar_dividend(pick([:drawn, :drawn, :drawn, :least]), width_range(into), sources)

  defp ar_dividend(_mod, sources), do: ar_source(sources)

  defp ar_dividend(:least, first.._last//1, _sources), do: {:lit, first}
  defp ar_dividend(_drawn, _range, sources), do: ar_source(sources)

  # A literal zero divisor is refused when the program compiles (decision 78): a divisor is
  # a tag, which may be 0, or a literal that is not.
  defp ar_divisor({into, _tags} = sources),
    do: ar_divisor(pick([:drawn, :drawn, :drawn, :minus_one]), Map.fetch!(@widths, into), sources)

  defp ar_divisor(:minus_one, {:signed, _n}, _sources), do: {:lit, -1}

  defp ar_divisor(_drawn, _width, {into, _tags} = sources) do
    case ar_source(sources) do
      {:lit, 0} -> {:lit, pick(Enum.reject(ar_pool(into), &(&1 == 0)))}
      source -> source
    end
  end

  defp ar_block_source(spec),
    do:
      Enum.join(
        [
          "function_block calc",
          "var_input a #{spec.types["block"]}",
          "var_input b #{spec.types["block"]}",
          "var_input go bool",
          "var_output r #{spec.types["block"]}",
          "var_output ok bool",
          "var w #{spec.types["block"]} #{spec.block.init}"
        ] ++ Enum.map(spec.block.rungs, &ar_text/1),
        "\n"
      )

  defp ar_declarations(spec),
    do:
      ["var_input g bool", "var_input gb bool"] ++
        for(x <- ~w(x0 x1 x2 x3), do: "var_input #{x} #{spec.types[x]}") ++
        for(
          {init, i} <- Enum.with_index(spec.inits),
          do: "var v#{i} #{spec.types["v#{i}"]} #{init}"
        ) ++
        for(y <- ~w(y0 y1 yb), do: "var_output #{y} #{spec.types[y]}") ++
        for(ok <- ~w(ok0 ok1 ok2 okb), do: "var_output #{ok} bool") ++
        if(spec.block, do: ["var c1 calc"], else: [])

  defp ar_source_text(spec),
    do:
      Enum.join(
        ar_declarations(spec) ++ Enum.map(spec.rungs, &ar_text/1) ++ ar_cal_text(spec.block),
        "\n"
      )

  defp ar_cal_text(nil), do: []
  defp ar_cal_text(_block), do: ["xic gb cal c1 x0 x1 g yb okb"]

  defp ar_text({contact, instructions, coil}) do
    Enum.join(
      ar_contact_text(contact) ++
        Enum.map(instructions, fn {op, sources, destination} ->
          Enum.join(["#{op}" | Enum.map(sources, &ar_operand_text/1)] ++ [destination], " ")
        end) ++ if(coil, do: ["ote #{coil}"], else: []),
      " "
    )
  end

  defp ar_contact_text(nil), do: []
  defp ar_contact_text({c, tag}), do: ["#{c} #{tag}"]

  defp ar_operand_text({:lit, n}), do: "#{n}"
  defp ar_operand_text({:tag, tag}), do: tag

  defp ar_program(spec) do
    types =
      case spec.block do
        nil ->
          []

        _block ->
          {:ok, calc} = Logex.compile(ar_block_source(spec), name: "calc")
          [calc]
      end

    {:ok, program} = Logex.compile(ar_source_text(spec), name: "ar", types: types)
    program
  end

  # ---- the oracle: IEC's rules, restated, over plain maps ------------------------------

  # The program's first rung's line, after its declarations, and the block's.
  defp ar_first_line(spec), do: length(ar_declarations(spec)) + 1
  defp ar_block_first_line, do: 8

  defp ar_initial(spec) do
    base =
      Map.new(~w(g gb x0 x1 x2 x3 y0 y1 yb ok0 ok1 ok2 okb), &{&1, 0})
      |> Map.merge(Map.new(Enum.with_index(spec.inits), fn {v, i} -> {"v#{i}", v} end))

    case spec.block do
      nil ->
        base

      block ->
        Map.put(base, "c1", %{
          "a" => 0,
          "b" => 0,
          "go" => 0,
          "r" => 0,
          "ok" => 0,
          "w" => block.init
        })
    end
  end

  # One scan: the program's rungs, then the `cal`, each fault `{op, line, path}`, in order.
  defp ar_scan(spec, env) do
    {env, faults} = ar_routine(spec, spec.rungs, env, {ar_first_line(spec), nil})
    {env, more} = ar_cal(spec, env)
    {env, faults ++ more}
  end

  # A routine's tags' types: the program's, or in the block, its one width for each of
  # `a b w r`.
  defp ar_types_in(spec, nil), do: spec.types
  defp ar_types_in(spec, "c1"), do: Map.new(~w(a b w r), &{&1, spec.types["block"]})

  defp ar_routine(spec, rungs, env, {first, path}) do
    types = ar_types_in(spec, path)

    {env, faults, _line} =
      Enum.reduce(rungs, {env, [], first}, fn rung, {env, faults, line} ->
        {env, more} = ar_rung_run(rung, env, {line, path, types})
        {env, faults ++ more, line + 1}
      end)

    {env, faults}
  end

  defp ar_rung_run({contact, instructions, coil}, env, at) do
    power = ar_contact(contact, env)
    if not power, do: ar_reached(:de_energised)

    {powered, env, faults} =
      Enum.reduce(instructions, {power, env, []}, fn instruction, {now, env, faults} ->
        # A rung's power that an earlier instruction on it took away.
        if power and not now, do: ar_reached(:cut)
        ar_instruction_run(instruction, now, env, at, faults)
      end)

    env = if coil, do: Map.put(env, coil, if(powered, do: 1, else: 0)), else: env
    {env, Enum.reverse(faults)}
  end

  defp ar_contact(nil, _env), do: true
  defp ar_contact({:xic, tag}, env), do: env[tag] == 1
  defp ar_contact({:xio, tag}, env), do: env[tag] != 1

  # De-energised, nothing; after an instruction that passed no power, so too.
  defp ar_instruction_run(_instruction, false, env, _at, faults) do
    {false, env, faults}
  end

  defp ar_instruction_run({op, sources, destination}, true, env, {line, path, types}, faults) do
    values = Enum.map(sources, &ar_value(&1, env))
    into = types[destination]
    first..last//1 = width_range(into)
    if Enum.any?(sources, &match?({:lit, n} when n < 0, &1)), do: ar_reached(:negative_literal)

    if Enum.any?(sources, &match?({:tag, tag} when :erlang.map_get(tag, types) != into, &1)),
      do: ar_reached(:widened)

    ar_notes(op, values, first)

    case ar_exact(op, values) do
      :zero_divisor ->
        ar_reached(if(op == :div, do: :div_by_zero, else: :mod_by_zero))
        if path, do: ar_reached(:block_fault)
        {false, Map.put(env, destination, 0), [{op, line, path} | faults]}

      {:ok, exact} when exact > last ->
        ar_reached(:above)
        ar_reached({:wrapped, into})
        {false, Map.put(env, destination, ar_wrapped(into, exact)), faults}

      {:ok, exact} when exact < first ->
        ar_reached(:below)
        ar_reached({:wrapped, into})
        {false, Map.put(env, destination, ar_wrapped(into, exact)), faults}

      {:ok, exact} ->
        {true, Map.put(env, destination, exact), faults}
    end
  end

  # Decision 146, restated: a result outside its destination's width keeps its remainder by
  # 2^N, taken back into the width's range, so that the stored value is the one of the
  # width's 2^N that the exact one is congruent to; one far past a limit, more than 2^N
  # out, is noted as well.
  defp ar_wrapped(type, exact) do
    {_kind, n} = Map.fetch!(@widths, type)
    span = Integer.pow(2, n)
    if abs(exact) >= span, do: ar_reached(:far_past)
    ar_into(rem(exact, span), width_range(type), span)
  end

  defp ar_into(r, _first..last//1, span) when r > last, do: r - span
  defp ar_into(r, first.._last//1, span) when r < first, do: r + span
  defp ar_into(r, _range, _span), do: r

  defp ar_value({:lit, n}, _env), do: n
  defp ar_value({:tag, tag}, env), do: Map.fetch!(env, tag)

  # The signed destination's minimum, divided by -1, negated or made absolute: the one
  # value of each that leaves its width.
  defp ar_notes(:div, [min, -1], min), do: ar_reached(:min_by_minus_one)
  defp ar_notes(:neg, [min], min) when min < 0, do: ar_reached(:neg_min)
  defp ar_notes(:abs, [min], min) when min < 0, do: ar_reached(:abs_min)

  defp ar_notes(:mod, [a, b], _first) when a < 0 and b != 0 and rem(a, b) != 0,
    do: ar_reached(:mod_negative)

  defp ar_notes(_op, _values, _first), do: :ok

  # The exact result, on Elixir's integers: IEC's DIV truncates toward zero, restated from
  # the magnitudes alone, and MOD is IN1 - (IN1/IN2)*IN2 from it (Ed 3 Table 29 notes d, e).
  defp ar_exact(:add, [a, b]), do: {:ok, a + b}
  defp ar_exact(:sub, [a, b]), do: {:ok, a - b}
  defp ar_exact(:mul, [a, b]), do: {:ok, a * b}
  defp ar_exact(op, [_a, 0]) when op in [:div, :mod], do: :zero_divisor
  defp ar_exact(:div, [a, b]), do: {:ok, ar_truncated(a, b)}
  defp ar_exact(:mod, [a, b]), do: {:ok, a - ar_truncated(a, b) * b}
  defp ar_exact(:neg, [a]), do: {:ok, 0 - a}
  defp ar_exact(:abs, [a]), do: {:ok, if(a < 0, do: 0 - a, else: a)}

  defp ar_truncated(a, b) do
    magnitude = Integer.floor_div(abs(a), abs(b))
    if a < 0 != b < 0, do: -magnitude, else: magnitude
  end

  # The `cal` on `gb`: the block's inputs copied in, its body over its own map, its outputs
  # copied out; on a false `gb`, nothing at all (decision 12).
  defp ar_cal(%{block: nil}, env), do: {env, []}

  defp ar_cal(spec, env) do
    if env["gb"] == 1 do
      c1 = Map.merge(env["c1"], %{"a" => env["x0"], "b" => env["x1"], "go" => env["g"]})
      {c1, faults} = ar_routine(spec, spec.block.rungs, c1, {ar_block_first_line(), "c1"})
      {Map.merge(env, %{"c1" => c1, "yb" => c1["r"], "okb" => c1["ok"]}), faults}
    else
      ar_reached(:block_frozen)
      {env, []}
    end
  end

  defp ar_inputs(spec) do
    Map.merge(
      %{"g" => pick([1, 1, 1, 0]), "gb" => pick([1, 1, 0])},
      Map.new(~w(x0 x1 x2 x3), &{&1, pick(ar_pool(spec.types[&1]))})
    )
  end

  defp ar_fault({op, line, path}, file),
    do: %Logex.Fault{
      severity: :minor,
      kind: :divide_by_zero,
      instruction: op,
      path: path,
      file: file,
      line: line
    }

  defp ar_outputs(env), do: Map.take(env, ~w(y0 y1 yb ok0 ok1 ok2 okb))

  # Every value a state holds is its tag's type's, or a bool's, at any depth.
  defp ar_fitting?(spec, env),
    do: Enum.all?(env, fn {k, v} -> ar_fits?(ar_types_in(spec, nil)[k], v, spec) end)

  defp ar_fits?(nil, %{} = c1, spec),
    do: Enum.all?(c1, fn {k, v} -> ar_fits?(ar_types_in(spec, "c1")[k], v, spec) end)

  defp ar_fits?(nil, v, _spec), do: v in [0, 1]
  defp ar_fits?(type, v, _spec), do: is_integer(v) and v in width_range(type)

  # ---- the walks ------------------------------------------------------------------------

  # A lone instance: every scan's outputs, state and faults the oracle's; halfway, an online
  # edit to another program of the same tags, whose every kept value stays as it was.
  defp ar_lone(spec, program, scans) do
    assert %Instance{faults: []} = Runtime.instance(program)

    {spec, program, state, model} =
      Enum.reduce(1..scans, {spec, program, Runtime.instance(program), ar_initial(spec)}, fn
        n, {spec, program, state, model} ->
          {state, model} = ar_maybe_restart(n == div(scans, 3), spec, program, state, model)

          {spec, program, state, model} =
            ar_maybe_edit(n == div(scans, 2), spec, program, state, model)

          inputs = ar_inputs(spec)
          {model, faults} = ar_scan(spec, Map.merge(model, inputs))

          {outputs, state} =
            Runtime.call(program, state, inputs, %Scan{now: state.now + 10, first: state.first})

          assert outputs == ar_outputs(model), ar_source_text(spec)
          assert state.env == model, ar_source_text(spec)
          assert state.faults == Enum.map(faults, &ar_fault(&1, nil)), ar_source_text(spec)
          assert ar_fitting?(spec, state.env)
          {spec, program, state, model}
      end)

    {spec, program, state, model}
  end

  # A restart, cold or warm, is no scan: it keeps the last scan's faults, and starts every
  # tag again but the var_inputs, which keep the host's values.
  defp ar_maybe_restart(false, _spec, _program, state, model), do: {state, model}

  defp ar_maybe_restart(true, spec, program, state, model) do
    restarted = Runtime.restart(program, state, pick([:cold, :warm]))
    model = Map.merge(ar_initial(spec), Map.take(model, ~w(g gb x0 x1 x2 x3)))
    assert restarted.faults == state.faults
    assert restarted.env == model
    ar_reached(:restarted)
    {restarted, model}
  end

  defp ar_maybe_edit(false, spec, program, state, model), do: {spec, program, state, model}

  defp ar_maybe_edit(true, spec, program, state, model) do
    candidate_spec = ar_spec(spec.types, spec.inits, spec.block)
    candidate = ar_program(candidate_spec)
    {:ok, edit, _forecast} = Edit.accept(program, candidate, state)
    {edit, switched, _report} = Edit.test(edit, state)
    {_program, switched, _report} = Edit.assemble(edit, switched)

    # Arithmetic keeps no state of its own: what it wrote is each tag's, kept by name, and
    # the last scan's faults stay until the next scan.
    assert switched.env == state.env
    assert switched.faults == state.faults
    ar_reached(:edit_kept)
    {candidate_spec, candidate, switched, model}
  end

  # A resource of two instances of the program, one on a task and one with none, their
  # inputs connected to input points: each cycle's events, `{:ran, ...}` and then each
  # fault's `{:fault, ...}`, the oracle's, and each instance's state too.
  defp ar_resource(spec, program, cycles) do
    inputs = ~w(g gb x0 x1 x2 x3)

    config =
      Logex.Configuration.new!(
        name: "plant",
        programs: [program],
        tasks: [%Logex.Configuration.Task{name: "fast", interval: 10, priority: 1}],
        globals:
          for(
            {name, i} <- Enum.with_index(inputs),
            do: %Logex.Configuration.Global{
              name: name,
              type: Map.get(spec.types, name, :bool),
              at: "panel.i.#{i}"
            }
          ),
        instances: [
          %Logex.Configuration.Instance{name: "m1", type: "ar", task: "fast"},
          %Logex.Configuration.Instance{name: "m2", type: "ar"}
        ],
        connections:
          for(
            instance <- ~w(m1 m2),
            input <- inputs,
            do: %Logex.Configuration.Connection{instance: instance, member: input, to: input}
          )
      )

    Enum.reduce(1..cycles, {Runtime.start(config), ar_initial(spec), ar_initial(spec), 0}, fn
      _, {rt, m1, m2, now} ->
        sample = ar_inputs(spec)
        {m1, f1} = ar_scan(spec, Map.merge(m1, sample))
        {m2, f2} = ar_scan(spec, Map.merge(m2, sample))
        {rt, _outputs, events} = Runtime.cycle(rt, if(now == 0, do: 0, else: 10), sample)
        now = if now == 0, do: 10, else: now + 10
        at = now - 10

        assert events ==
                 [{:ran, "fast", "m1", at}] ++
                   Enum.map(f1, &{:fault, "fast", "m1", ar_fault(&1, nil)}) ++
                   [{:ran, :none, "m2", at}] ++
                   Enum.map(f2, &{:fault, :none, "m2", ar_fault(&1, nil)})

        if f1 != [], do: ar_reached(:event_fault)
        %Runtime{instances: %{"m1" => s1, "m2" => s2}} = rt
        assert {s1.env, s1.faults, s2.env, s2.faults} == {m1, [], m2, []}
        assert ar_fitting?(spec, s1.env) and ar_fitting?(spec, s2.env)
        {rt, m1, m2, now}
    end)
  end

  # ---- M3-4: the pulse coils, against IEC's transition-sensing coils restated ----------

  # What the coil walk must be seen to do, at least once each.
  @pc_reach [
    :rose,
    :fell,
    :first_held,
    :passed_on,
    :frozen,
    :frozen_pulse_held,
    :removed_pulse_held,
    :kept_across,
    :edge_blocked,
    :edge_kept,
    :blocked_pulsed_later,
    :added,
    :pruned,
    :round_trip,
    :restarted
  ]

  @pc_inputs ~w(e1 e2 e3 on)

  test "pulse coils run as IEC's restated from the text: every scan exact where no switch " <>
         "came since a coil last ran, no pulse an edit made, and the power passed on" do
    :rand.seed(:exsss, {2026, 10, 444})
    Process.put(:pc_programs, %{})

    # Sized from its rarest atom, a removed coil's pulse bit held at 1, which needs the
    # coil to pulse on the scan before the switch that removes it: about 16 a run at 800
    # walks over the seeds {n, 77, 7}, {n, 1, 1} and {7, n, 2026}, n to 25, and the reach
    # holds at each of them and of {n, 3, 33} and {99, n, 5}, n to 35.
    for _ <- 1..800 do
      spec = pc_spec()
      program = pc_program(spec)

      w = %{
        spec: spec,
        p: program,
        s: Runtime.instance(program),
        e: nil,
        c: nil,
        clean: Map.new(pc_texts(spec), fn {bit, _text} -> {bit, true} end),
        last: pc_texts(spec),
        round: nil,
        blocked: [],
        restarted: false
      }

      pc_walk(w, 60)
    end

    assert Process.get(:pc_reach, MapSet.new()) == MapSet.new(@pc_reach)
  end

  defp pc_reached(name), do: reached(:pc_reach, name)

  # A program's coils, drawn: `r` and `f`, each an `osr` or an `osf` on a chain of
  # contacts, its storage bit declared 0 or 1 and its rung now and then ending in an `ote`
  # that shows the power the coil passes on; and a block `b`, in one of three versions of
  # its body, a coil inside it, which a `cal` on `on` runs. A coil's two bits are declared
  # only where the coil is, so an edit adds and drops them.
  defp pc_spec, do: %{r: pc_maybe(&pc_coil/0), f: pc_maybe(&pc_coil/0), b: pc_maybe(&pc_v/0)}

  defp pc_maybe(fun), do: if(:rand.uniform(4) == 1, do: nil, else: fun.())

  defp pc_coil,
    do: %{
      kind: pick([:osr, :osf]),
      chain: pc_chain(),
      init: pick([0, 1]),
      y: pick([true, false])
    }

  defp pc_v, do: pick([1, 2, 3])

  defp pc_chain,
    do: for(_ <- 1..:rand.uniform(2), do: {pick([:xic, :xic, :xio]), pick(~w(e1 e2 e3))})

  # The candidate: one or two of the changes an edit may make to a coil, none of which a
  # restart needs: its chain, its kind, its storage bit's initial value, whether an `ote`
  # follows it, its presence, the block's version, or the order of the two coils' rungs.
  defp pc_candidate(spec),
    do:
      Enum.reduce(1..:rand.uniform(2), spec, fn _, spec -> pc_change(:rand.uniform(9), spec) end)

  defp pc_change(1, spec), do: pc_coil_change(spec, :r)
  defp pc_change(2, spec), do: pc_coil_change(spec, :f)
  defp pc_change(3, spec), do: %{spec | r: pick([nil, pc_coil()])}
  defp pc_change(4, spec), do: %{spec | f: pick([nil, pc_coil()])}
  defp pc_change(5, spec), do: %{spec | b: pick([nil, 1, 2, 3])}
  defp pc_change(6, spec), do: Map.put(spec, :swapped, not Map.get(spec, :swapped, false))
  defp pc_change(_n, spec), do: pc_coil_change(spec, pick([:r, :f]))

  defp pc_coil_change(spec, coil) do
    case spec[coil] do
      nil ->
        spec

      c ->
        Map.put(
          spec,
          coil,
          case :rand.uniform(4) do
            1 -> %{c | chain: pc_chain()}
            2 -> %{c | kind: if(c.kind == :osr, do: :osf, else: :osr)}
            3 -> %{c | init: 1 - c.init}
            4 -> %{c | y: not c.y}
          end
        )
    end
  end

  @pc_bodies %{1 => "xic go osr s p", 2 => "xio go osr s p", 3 => "xic go osf s p"}

  defp pc_body(version) do
    {:ok, edge} =
      Logex.compile(
        "function_block edge\nvar_input go bool\nvar_output p bool\nvar s bool\n" <>
          @pc_bodies[version],
        name: "edge"
      )

    edge
  end

  defp pc_program(spec) do
    known = Process.get(:pc_programs)

    case known do
      %{^spec => program} ->
        program

      _ ->
        types = if spec.b, do: [pc_body(spec.b)], else: []
        {:ok, program} = Logex.compile(pc_source(spec), name: "pc", types: types)
        Process.put(:pc_programs, Map.put(known, spec, program))
        program
    end
  end

  defp pc_source(spec) do
    coils = for name <- [:r, :f], c = spec[name], do: {name, c}

    declarations =
      Enum.map(@pc_inputs, &"var_input #{&1} bool") ++
        Enum.flat_map(coils, fn {name, c} ->
          ["var s#{name} bool #{c.init}", "var_output p#{name} bool", "var_output y#{name} bool"]
        end) ++
        if(spec.b, do: ["var b edge", "var_output bu bool"], else: [])

    rungs = Enum.map(coils, &pc_text/1)
    rungs = if Map.get(spec, :swapped, false), do: Enum.reverse(rungs), else: rungs
    cal = if spec.b, do: ["xic on cal b e1 bu"], else: []
    Enum.join(declarations ++ rungs ++ cal, "\n")
  end

  defp pc_text({name, c}),
    do:
      "#{pc_chain_text(c.chain)} #{c.kind} s#{name} p#{name}" <>
        if(c.y, do: " ote y#{name}", else: "")

  defp pc_chain_text(chain), do: Enum.map_join(chain, " ", fn {c, input} -> "#{c} #{input}" end)

  # Each coil, by its storage bit's path, to the text of the rung it runs under: the
  # block's by its body's rung, under the `cal` rung, which no version changes.
  defp pc_texts(spec),
    do:
      Map.new(
        for(name <- [:r, :f], c = spec[name], do: {"s#{name}", pc_text({name, c})}) ++
          if(spec.b, do: [{"b.s", @pc_bodies[spec.b]}], else: [])
      )

  defp pc_walk(w, 0), do: w

  defp pc_walk(w, n),
    do:
      pc_walk(
        pc_op(pick(~w(scan scan scan scan accept test untest assemble cancel restart)a), w),
        n - 1
      )

  defp pc_running(%{e: nil} = w), do: {w.p, w.spec}
  defp pc_running(%{e: edit} = w), do: pc_side(Edit.stage(edit), w)

  defp pc_side(:testing, w), do: {Edit.running(w.e), w.c}
  defp pc_side(_stage, w), do: {Edit.running(w.e), w.spec}

  defp pc_op(:scan, w) do
    {program, spec} = pc_running(w)
    inputs = for name <- @pc_inputs, :rand.uniform(2) == 1, into: %{}, do: {name, pick([0, 1])}
    before = Runtime.put_inputs(program, w.s, inputs)
    {:ok, {_outputs, later}} = attempt(fn -> Runtime.scan(program, before, 10) end)
    w = pc_check_scan(w, spec, before, later)
    %{w | s: later, round: nil, restarted: false}
  end

  defp pc_op(:restart, w) do
    {program, spec} = pc_running(w)
    s = Runtime.restart(program, w.s, pick([:cold, :warm]))

    # Each bit starts again at its declared value.
    for {name, c} <- [r: spec.r, f: spec.f], c != nil do
      assert {s.env["s#{name}"], s.env["p#{name}"]} == {c.init, 0}
    end

    pc_reached(:restarted)
    clean = Map.new(pc_texts(spec), fn {bit, _text} -> {bit, true} end)
    %{w | s: s, clean: clean, last: pc_texts(spec), round: nil, restarted: true}
  end

  defp pc_op(:accept, %{e: nil} = w) do
    candidate = pc_candidate(w.spec)

    {:ok, {:ok, edit, _forecast}} =
      attempt(fn -> Edit.accept(w.p, pc_program(candidate), w.s) end)

    %{w | e: edit, c: candidate}
  end

  defp pc_op(:test, %{e: e} = w) when e != nil,
    do: pc_switch(Edit.stage(e) in [:accepted, :untested], :test, w)

  defp pc_op(:untest, %{e: e} = w) when e != nil,
    do: pc_switch(Edit.stage(e) == :testing, :untest, w)

  defp pc_op(:assemble, %{e: e} = w) when e != nil,
    do: pc_finish(Edit.stage(e) == :testing, :assemble, w)

  defp pc_op(:cancel, %{e: e} = w) when e != nil,
    do: pc_finish(Edit.stage(e) in [:accepted, :untested], :cancel, w)

  defp pc_op(_op, w), do: w

  defp pc_finish(false, _step, w), do: w

  defp pc_finish(true, step, w) do
    {:ok, {program, s, report}} = attempt(fn -> apply(Edit, step, [w.e, w.s]) end)
    assert s.env == pc_rebuilt(w.s.env, report)
    if Enum.any?(report, &match?({:pruned, _, _}, &1)), do: pc_reached(:pruned)
    spec = if step == :assemble, do: w.c, else: w.spec
    %{w | p: program, s: s, e: nil, c: nil, spec: spec, round: nil}
  end

  defp pc_switch(false, _step, w), do: w

  defp pc_switch(true, step, w) do
    to = if step == :test, do: w.c, else: w.spec
    {:ok, {edit, s, report}} = attempt(fn -> apply(Edit, step, [w.e, w.s]) end)

    # The writes the report lists rebuild the state: no switch writes a coil's bits, but
    # a tag it adds starts at its initial value.
    assert s.env == pc_rebuilt(w.s.env, report)
    if Enum.any?(report, &match?({:added, _, _}, &1)), do: pc_reached(:added)

    # Each coil's bits the program started declares are kept as the state held them, or
    # started at their initial values where the state lacked them.
    for bit <- Map.keys(pc_texts(to)), is_integer(pc_at(w.s.env, bit)) do
      assert pc_at(s.env, bit) == pc_at(w.s.env, bit)
      pc_reached(:kept_across)
    end

    blocked = for {:ons_blocked, path, _value} <- report, do: path
    if blocked != [], do: pc_reached(:edge_blocked)

    # A test then an untest with no scan between gives every bit back.
    if step == :untest and w.round != nil do
      assert Map.take(s.env, Map.keys(w.round)) == w.round
      pc_reached(:round_trip)
    end

    round = if step == :test, do: w.s.env, else: nil

    # A restart with no scan since leaves every bit as a fresh instance's, so an edge a coil
    # sees after it is a real one, whatever its rung's text was.
    last = if w.restarted, do: Map.merge(w.last, pc_texts(to)), else: w.last
    blocked = Enum.uniq(blocked ++ w.blocked)
    %{w | e: edit, s: s, clean: %{}, last: last, round: round, blocked: blocked}
  end

  defp pc_rebuilt(env, report),
    do:
      Enum.reduce(report, env, fn
        {:added, name, value}, env -> Map.put(env, name, value)
        {:pruned, name, _value}, env -> Map.delete(env, name)
        _fact, env -> env
      end)

  defp pc_at(env, path), do: get_in(env, String.split(path, "."))

  # The scan, restated: each coil IEC's transition-sensing coil, over the input image, from
  # the state before the scan. A coil whose storage bit says the power it last received
  # pulses where that power rose, for `osr`, or fell, for `osf`, never on a first scan,
  # exactly where it has run under its rung's text with no switch since; one a switch came
  # before pulses no edge unless it last ran under the same text, and then may or may not,
  # the edit's block list being the implementation's and no part of this oracle. Every
  # coil writes its storage bit with the power it receives, and passes that power on; a
  # coil the program does not run, removed or frozen in its block, leaves both bits alone.
  defp pc_check_scan(w, spec, before, later) do
    image = Map.take(before.env, @pc_inputs)
    texts = pc_texts(spec)

    ran =
      for {name, c} <- [r: spec.r, f: spec.f], c != nil do
        cond = pc_eval(c.chain, image)
        bit = "s#{name}"
        pulse = pc_coil!(c.kind, cond, bit, "p#{name}", {before, later, w, texts})

        if c.y do
          assert later.env["y#{name}"] == pc_one(cond)
          pc_reached(:passed_on)
        end

        if pulse == 1 and w.clean[bit] == true and bit in w.blocked,
          do: pc_reached(:blocked_pulsed_later)

        bit
      end

    ran = ran ++ pc_block(spec.b, image, {before, later, w, texts})

    # A removed coil's pulse bit holds what its last run gave it.
    for name <- ~w(r f), spec[String.to_atom(name)] == nil, is_integer(before.env["p#{name}"]) do
      assert later.env["p#{name}"] == before.env["p#{name}"]
      if later.env["p#{name}"] == 1, do: pc_reached(:removed_pulse_held)
    end

    %{
      w
      | clean: Enum.reduce(ran, w.clean, &Map.put(&2, &1, true)),
        last: Enum.reduce(ran, w.last, &Map.put(&2, &1, texts[&1]))
    }
  end

  defp pc_block(nil, _image, _ctx), do: []

  defp pc_block(version, %{"on" => 1} = image, {_before, later, _w, _texts} = ctx) do
    {kind, cond} = pc_body_coil(version, image["e1"] == 1)
    pulse = pc_coil!(kind, cond, "b.s", "b.p", ctx)
    assert later.env["bu"] == pulse
    ["b.s"]
  end

  defp pc_block(_version, _image, {before, later, _w, _texts}) do
    assert later.env["b"] == before.env["b"] and later.env["bu"] == before.env["bu"]
    pc_reached(:frozen)
    if later.env["b"]["p"] == 1, do: pc_reached(:frozen_pulse_held)
    []
  end

  defp pc_body_coil(1, e1), do: {:osr, e1}
  defp pc_body_coil(2, e1), do: {:osr, not e1}
  defp pc_body_coil(3, e1), do: {:osf, e1}

  # One coil's run: its storage bit takes the power, and its pulse bit the edge where the
  # oracle allows one, checked against the state; the pulse it gave.
  defp pc_coil!(kind, cond, bit, pulse, {before, later, w, texts}) do
    stored = pc_at(before.env, bit)
    edge? = pc_edge?(kind, cond, stored)

    allowed =
      cond do
        before.first -> [false]
        Map.get(w.clean, bit, false) -> [true]
        Map.get(w.last, bit) == texts[bit] -> [false, true]
        true -> [false]
      end

    if before.first and edge?, do: pc_reached(:first_held)
    got = pc_at(later.env, pulse)
    assert pc_at(later.env, bit) == pc_one(cond)
    assert got in Enum.map(allowed, &pc_one(edge? and &1)), "#{pulse}: #{got} from #{stored}"
    if got == 1, do: pc_reached(if kind == :osr, do: :rose, else: :fell)

    if got == 1 and not Map.get(w.clean, bit, false), do: pc_reached(:edge_kept)
    got
  end

  defp pc_edge?(:osr, cond, stored), do: cond and not pc_closed?(stored)
  defp pc_edge?(:osf, cond, stored), do: not cond and pc_closed?(stored)

  defp pc_closed?(1), do: true
  defp pc_closed?(_value), do: false

  defp pc_eval(chain, image),
    do: Enum.all?(chain, fn {c, input} -> c == :xic == (image[input] == 1) end)

  defp pc_one(true), do: 1
  defp pc_one(false), do: 0

  # ---- M3-5: the walk of forward jumps --------------------------------------------------

  @jp_reach [
    :jumpless,
    :jumped,
    :not_taken,
    :landed,
    :jump_skipped,
    :held_ote,
    :passed_on,
    :caught_up,
    :counted,
    :counted_down,
    :side_skipped,
    :coil_rose,
    :coil_fell,
    :late_edge,
    :blocked_through_skip,
    :leg_held,
    :edge_kept,
    :block_skipped,
    :block_frozen,
    :jump_added,
    :jump_removed,
    :label_moved,
    :round_trip,
    :restarted
  ]

  @jp_inputs ~w(e1 e2 e3 m1 m2 m3)

  # The block a `cal` runs, in three versions of its body: a jump on its `skip` over its
  # one-shot, the one-shot alone, and a jump over the one-shot on its inverted input.
  @jp_bodies %{
    1 => ["xic skip jmp done", "xic go ons e ote q", "lbl done"],
    2 => ["xic go ons e ote q"],
    3 => ["xic skip jmp done", "xio go ons e ote q", "lbl done"]
  }

  test "forward jumps skip exactly the rungs their text says, a skipped rung frozen, its " <>
         "timer catching up, and no edge an edit made, however many scans skip it" do
    :rand.seed(:exsss, {2026, 10, 555})
    Process.put(:jp_programs, %{})

    # Sized from its rarest atom, a one-shot or counter side on a group's leg whose rung an
    # edit changed meeting an edge at its first run after a skip: 8 at this seed, about 6 a
    # run at 400 walks and never under 2 over the seeds {n, 77, 7}, {n, 1, 1} and
    # {7, n, 2026}, n to 22, at each of which the reach holds; on a leg or not, 28 here,
    # about 20 a run and never under 10.
    for _ <- 1..400 do
      spec = jp_spec()
      if spec.jumps == [], do: jp_reached(:jumpless)
      program = jp_program(spec)

      w = %{
        spec: spec,
        p: program,
        s: Runtime.instance(program),
        e: nil,
        c: nil,
        clean: Map.new(jp_texts(spec), fn {mem, _text} -> {mem, true} end),
        last: jp_texts(spec),
        skips: %{},
        ran_at: %{},
        round: nil,
        restarted: false
      }

      jp_walk(w, 60)
    end

    assert Process.get(:jp_reach, MapSet.new()) == MapSet.new(@jp_reach)
  end

  defp jp_reached(name), do: reached(:jp_reach, name)

  # A program, drawn: six rungs in a random order, an `ote`, a one-shot, an `ons`, an
  # `osr` or an `osf`, the two sides of a ctud, each with a `move` of its count after it,
  # a `ton` and a `cal` of a block whose body may jump, each on a chain of contacts; and up
  # to three jumps among them, each on `m1`, `m2` or `m3`, put before one of the six and
  # going to the label of it or of a later one, or of a last rung of its own, now and then
  # with an `ote` after it on its rung. The one-shot, each side and the `cal`, with their
  # chains, stand now and then on a leg of a group, first or second, whose other leg,
  # `xic e3 xio e3`, passes no power, so the rung does what it would do without the group.
  @jp_rungs [:y, :s, :c, :d, :t, :b]
  @jp_grouped [:s, :c, :d, :b]

  defp jp_spec,
    do: %{
      order: Enum.shuffle(@jp_rungs),
      chains: Map.new(@jp_rungs, &{&1, pc_chain()}),
      jumps: for(_ <- 1..pick([0, 1, 2, 2, 3, 3])//1, do: jp_jump()),
      one_shot: pick([:ons, :osr, :osf]),
      b: pick([1, 2, 3]),
      legs: Map.new(@jp_grouped, &{&1, jp_leg()})
    }

  defp jp_leg, do: pick([nil, 1, 2])

  defp jp_jump do
    at = :rand.uniform(6) - 1

    %{
      at: at,
      to: at + :rand.uniform(7 - at) - 1,
      on: {pick([:xic, :xic, :xio]), pick(~w(m1 m2 m3))},
      q: pick([true, false])
    }
  end

  # The candidate: one or two changes an edit may make: a rung's chain, a jump added,
  # removed or sent to another label, two rungs swapped, the one-shot's kind, the block's
  # version, or a memory's rung put in a group, moved to its other leg or taken out.
  defp jp_candidate(spec),
    do:
      Enum.reduce(1..:rand.uniform(2), spec, fn _, spec -> jp_change(:rand.uniform(8), spec) end)

  # A chain changed, the one-shot's twice as often as another's.
  defp jp_change(1, spec), do: put_in(spec, [:chains, pick([:s | @jp_rungs])], pc_chain())

  defp jp_change(2, %{jumps: jumps} = spec) when length(jumps) < 3,
    do: %{spec | jumps: jumps ++ [jp_jump()]}

  defp jp_change(3, %{jumps: [_ | _] = jumps} = spec),
    do: %{spec | jumps: List.delete_at(jumps, :rand.uniform(length(jumps)) - 1)}

  defp jp_change(4, %{jumps: [_ | _] = jumps} = spec) do
    i = :rand.uniform(length(jumps)) - 1
    j = Enum.at(jumps, i)
    %{spec | jumps: List.replace_at(jumps, i, %{j | to: j.at + :rand.uniform(7 - j.at) - 1})}
  end

  defp jp_change(5, %{order: order} = spec) do
    i = :rand.uniform(5) - 1
    {a, b} = {Enum.at(order, i), Enum.at(order, i + 1)}
    %{spec | order: order |> List.replace_at(i, b) |> List.replace_at(i + 1, a)}
  end

  defp jp_change(6, spec), do: %{spec | b: pick([1, 2, 3])}
  defp jp_change(7, spec), do: %{spec | one_shot: pick([:ons, :osr, :osf])}
  defp jp_change(8, spec), do: put_in(spec, [:legs, pick(@jp_grouped)], jp_leg())
  defp jp_change(_n, spec), do: jp_change(1, spec)

  defp jp_body(version) do
    {:ok, hop} =
      Logex.compile(
        "function_block hop\nvar_input skip bool\nvar_input go bool\nvar_output q bool\n" <>
          "var e bool\n" <> Enum.join(@jp_bodies[version], "\n"),
        name: "hop"
      )

    hop
  end

  defp jp_program(spec) do
    known = Process.get(:jp_programs)

    case known do
      %{^spec => program} ->
        program

      _ ->
        {:ok, program} =
          Logex.compile(jp_source(spec), name: "jp", types: [jp_body(spec.b)])

        Process.put(:jp_programs, Map.put(known, spec, program))
        program
    end
  end

  defp jp_source(spec) do
    declarations =
      Enum.map(@jp_inputs, &"var_input #{&1} bool") ++
        Enum.map(~w(y p q1 q2 q3 bq), &"var_output #{&1} bool") ++
        ["var_output ku dint", "var_output kd dint"] ++
        ["var s bool", "var c ctud", "var t ton", "var b hop"]

    Enum.join(declarations ++ Enum.map(jp_items(spec), & &1.text), "\n")
  end

  # The program's rungs, in order, each with what the oracle needs: the jumps put before
  # each of the six, then that rung, labelled where a jump goes to it, and a last rung
  # where one goes past them all.
  defp jp_items(spec) do
    targets = MapSet.new(spec.jumps, & &1.to)
    numbered = Enum.with_index(spec.jumps, 1)

    rungs =
      for {which, pos} <- Enum.with_index(spec.order),
          item <- jp_jumps_at(numbered, pos) ++ [jp_rung(which, pos, targets, spec)],
          do: item

    rungs ++
      if(MapSet.member?(targets, 6), do: [%{kind: :end, label: "L6", text: "lbl L6"}], else: [])
  end

  defp jp_jumps_at(numbered, pos),
    do:
      for(
        {%{at: ^pos} = j, i} <- numbered,
        do: %{
          kind: :jmp,
          i: i,
          on: j.on,
          to: "L#{j.to}",
          q: j.q,
          label: nil,
          text:
            "#{elem(j.on, 0)} #{elem(j.on, 1)} jmp L#{j.to}" <>
              if(j.q, do: " ote q#{i}", else: "")
        }
      )

  defp jp_rung(which, pos, targets, spec) do
    label = if MapSet.member?(targets, pos), do: "L#{pos}", else: nil
    head = if label, do: "lbl #{label} ", else: ""

    rung = head <> jp_legs(spec.legs[which], pc_chain_text(spec.chains[which]), which, spec)

    %{
      kind: which,
      label: label,
      chain: spec.chains[which],
      one_shot: spec.one_shot,
      rung: rung,
      text: rung <> jp_after(which)
    }
  end

  # A memory and its chain, alone or on a leg of a group, its coil or `ote` after it.
  defp jp_legs(nil, chain, which, spec), do: chain <> jp_tail(which, spec)

  defp jp_legs(leg, chain, :s, %{one_shot: :ons}),
    do: jp_group(leg, chain <> " ons s") <> " ote p"

  defp jp_legs(leg, chain, which, spec), do: jp_group(leg, chain <> jp_tail(which, spec))

  defp jp_group(1, memory), do: "( #{memory} | xic e3 xio e3 )"
  defp jp_group(2, memory), do: "( xic e3 xio e3 | #{memory} )"

  defp jp_tail(:y, _spec), do: " ote y"
  defp jp_tail(:s, %{one_shot: :ons}), do: " ons s ote p"
  defp jp_tail(:s, %{one_shot: coil}), do: " #{coil} s p"
  defp jp_tail(:c, _spec), do: " ctu c 3"
  defp jp_tail(:d, _spec), do: " ctd c 3"
  defp jp_tail(:t, _spec), do: " ton t 200"
  defp jp_tail(:b, _spec), do: " cal b m3 e1 bq"

  # Each side of the counter is followed, on a rung of its own that no jump comes between,
  # by a `move` of the count, so the oracle sees what each side did.
  defp jp_after(:c), do: "\nmove c.cv ku"
  defp jp_after(:d), do: "\nmove c.cv kd"
  defp jp_after(_which), do: ""

  # Each edge memory, by its path, to the text it runs under, its rung's whole, its label
  # among it: the block's by its `cal` rung and its body's one-shot rung (decision 32).
  defp jp_texts(spec) do
    items =
      Map.new(
        for %{kind: kind, rung: rung} <- jp_items(spec),
            kind in [:s, :c, :d, :b],
            do: {kind, rung}
      )

    %{
      "s" => items.s,
      "c.cu" => items.c,
      "c.cd" => items.d,
      "b.e" => [items.b, Enum.find(@jp_bodies[spec.b], &(&1 =~ "ons"))]
    }
  end

  defp jp_walk(w, 0), do: w

  defp jp_walk(w, n),
    do:
      jp_walk(
        jp_op(pick(~w(scan scan scan scan scan accept test untest assemble cancel restart)a), w),
        n - 1
      )

  defp jp_running(%{e: nil} = w), do: {w.p, w.spec}
  defp jp_running(%{e: edit} = w), do: jp_side(Edit.stage(edit), w)

  defp jp_side(:testing, w), do: {Edit.running(w.e), w.c}
  defp jp_side(_stage, w), do: {Edit.running(w.e), w.spec}

  defp jp_op(:scan, w) do
    {program, spec} = jp_running(w)
    inputs = for name <- @jp_inputs, :rand.uniform(2) == 1, into: %{}, do: {name, pick([0, 1])}
    before = Runtime.put_inputs(program, w.s, inputs)
    dt = pick([10, 30, 100])
    {:ok, {_outputs, later}} = attempt(fn -> Runtime.scan(program, before, dt) end)
    w = jp_check_scan(w, spec, before, later)
    %{w | s: later, round: nil, restarted: false}
  end

  defp jp_op(:restart, w) do
    {program, spec} = jp_running(w)
    s = Runtime.restart(program, w.s, pick([:cold, :warm]))
    jp_reached(:restarted)
    clean = Map.new(jp_texts(spec), fn {mem, _text} -> {mem, true} end)

    %{
      w
      | s: s,
        clean: clean,
        last: jp_texts(spec),
        skips: %{},
        ran_at: %{},
        round: nil,
        restarted: true
    }
  end

  defp jp_op(:accept, %{e: nil} = w) do
    candidate = jp_candidate(w.spec)
    if length(candidate.jumps) > length(w.spec.jumps), do: jp_reached(:jump_added)
    if length(candidate.jumps) < length(w.spec.jumps), do: jp_reached(:jump_removed)

    if length(candidate.jumps) == length(w.spec.jumps) and candidate.jumps != w.spec.jumps,
      do: jp_reached(:label_moved)

    {:ok, {:ok, edit, _forecast}} =
      attempt(fn -> Edit.accept(w.p, jp_program(candidate), w.s) end)

    %{w | e: edit, c: candidate}
  end

  defp jp_op(:test, %{e: e} = w) when e != nil,
    do: jp_switch(Edit.stage(e) in [:accepted, :untested], :test, w)

  defp jp_op(:untest, %{e: e} = w) when e != nil,
    do: jp_switch(Edit.stage(e) == :testing, :untest, w)

  defp jp_op(:assemble, %{e: e} = w) when e != nil,
    do: jp_finish(Edit.stage(e) == :testing, :assemble, w)

  defp jp_op(:cancel, %{e: e} = w) when e != nil,
    do: jp_finish(Edit.stage(e) in [:accepted, :untested], :cancel, w)

  defp jp_op(_op, w), do: w

  defp jp_finish(false, _step, w), do: w

  defp jp_finish(true, step, w) do
    {:ok, {program, s, report}} = attempt(fn -> apply(Edit, step, [w.e, w.s]) end)
    assert s.env == pc_rebuilt(w.s.env, report)
    spec = if step == :assemble, do: w.c, else: w.spec
    %{w | p: program, s: s, e: nil, c: nil, spec: spec, round: nil}
  end

  defp jp_switch(false, _step, w), do: w

  defp jp_switch(true, step, w) do
    {:ok, {edit, s, report}} = attempt(fn -> apply(Edit, step, [w.e, w.s]) end)

    # Both programs declare every tag, so a switch writes nothing: every value is kept.
    assert s.env == pc_rebuilt(w.s.env, report) and s.env == w.s.env

    # A test then an untest with no scan between gives the state back.
    if step == :untest and w.round != nil do
      assert s.env == w.round
      jp_reached(:round_trip)
    end

    round = if step == :test, do: w.s.env, else: nil

    # A restart with no scan since leaves every memory as a fresh instance's, so an edge
    # one sees after it is a real one, whatever its rung's text was.
    to = if step == :test, do: w.c, else: w.spec
    last = if w.restarted, do: Map.merge(w.last, jp_texts(to)), else: w.last
    %{w | e: edit, s: s, clean: %{}, last: last, round: round}
  end

  # The scan, restated from the text over the input image and the state before it: the
  # rungs run top to bottom, and a `jmp` whose chain is true, once its rung is done, skips
  # every rung up to the one its label heads, which runs. A skipped rung changes nothing it
  # writes. A rung that runs does what its text says, a timer timing from the time this
  # walk last saw it run; a one-shot or counter a switch came before counts or pulses no
  # edge unless it last ran under the same text, and then may or may not, however many
  # scans skipped it since: the edit's block list is the implementation's and no part of
  # this oracle.
  defp jp_check_scan(w, spec, before, later) do
    image = Map.take(before.env, @jp_inputs)
    ctx = %{before: before, later: later, image: image, texts: jp_texts(spec), spec: spec}
    count = before.env["c"]["cv"]

    {w, skip} =
      Enum.reduce(jp_items(spec), {Map.merge(w, %{count: count, sides: %{}}), nil}, fn
        item, {w, skip} -> jp_item(item, skip, w, ctx)
      end)

    assert skip == nil
    jp_counter!(w.count, ctx)

    # One side of the counter blocked and skipped while the other ran (decision 106).
    for {mem, other} <- [{"c.cu", "c.cd"}, {"c.cd", "c.cu"}],
        w.sides[mem] == :skipped and w.sides[other] == :ran and mem in before.ons_blocked,
        do: jp_reached(:side_skipped)

    Map.drop(w, [:count, :sides])
  end

  # The counter after the scan: the count its sides left, and its outputs from it; a
  # counter neither side ran is as it was.
  defp jp_counter!(count, ctx) do
    now = ctx.later.env["c"]
    assert now["cv"] == count

    assert {now["qu"], now["qd"]} == {pc_one(count >= 3), pc_one(count <= 0)} or
             now == ctx.before.env["c"]
  end

  defp jp_item(%{label: label} = item, skip, w, ctx) when skip != nil and label != skip do
    jp_reached(:jump_skipped)
    {jp_frozen(item, w, ctx), skip}
  end

  defp jp_item(item, skip, w, ctx) do
    if skip != nil, do: jp_reached(:landed)
    jp_run(item, w, ctx)
  end

  defp jp_cond(chain, image), do: pc_eval(chain, image)

  defp jp_run(%{kind: :jmp} = j, w, ctx) do
    on = jp_cond([j.on], ctx.image)

    if j.q do
      assert ctx.later.env["q#{j.i}"] == pc_one(on)
      if on, do: jp_reached(:passed_on)
    end

    jp_reached(if on, do: :jumped, else: :not_taken)
    {w, if(on, do: j.to, else: nil)}
  end

  defp jp_run(%{kind: :end}, w, _ctx), do: {w, nil}

  defp jp_run(%{kind: :y, chain: chain}, w, ctx) do
    assert ctx.later.env["y"] == pc_one(jp_cond(chain, ctx.image))
    {w, nil}
  end

  # The one-shot: an `ons` and an `osr` see the power they receive rise, an `osf` see it
  # fall, its storage bit holding the power its last run received.
  defp jp_run(%{kind: :s, chain: chain, one_shot: kind}, w, ctx) do
    on = jp_cond(chain, ctx.image)
    stored = pc_closed?(ctx.before.env["s"])
    got = ctx.later.env["p"]
    edge? = if kind == :osf, do: not on and stored, else: on and not stored
    jp_edge!("s", edge?, got, w, ctx)

    if got == 1 and kind != :ons,
      do: jp_reached(if(kind == :osr, do: :coil_rose, else: :coil_fell))

    assert ctx.later.env["s"] == pc_one(on)
    {jp_ran(w, "s", ctx), nil}
  end

  # Each side of the counter, what it did read from the `move` after it, against the
  # count the scan had reached: a side counts by one on an edge where the oracle allows.
  defp jp_run(%{kind: :c, chain: chain}, w, ctx) do
    on = jp_cond(chain, ctx.image)
    after_up = ctx.later.env["ku"]
    counted = after_up - w.count
    assert counted in [0, 1]
    jp_edge!("c.cu", on and not pc_closed?(ctx.before.env["c"]["cu"]), counted, w, ctx)
    if counted == 1, do: jp_reached(:counted)
    assert ctx.later.env["c"]["cu"] == pc_one(on)
    {%{jp_ran(w, "c.cu", ctx) | count: after_up}, nil}
  end

  defp jp_run(%{kind: :d, chain: chain}, w, ctx) do
    on = jp_cond(chain, ctx.image)
    after_down = ctx.later.env["kd"]
    counted = w.count - after_down
    assert counted in [0, 1]
    jp_edge!("c.cd", on and not pc_closed?(ctx.before.env["c"]["cd"]), counted, w, ctx)
    if counted == 1, do: jp_reached(:counted_down)
    assert ctx.later.env["c"]["cd"] == pc_one(on)
    {%{jp_ran(w, "c.cd", ctx) | count: after_down}, nil}
  end

  defp jp_run(%{kind: :t, chain: chain}, w, ctx) do
    on = jp_cond(chain, ctx.image)
    was = ctx.before.env["t"]
    now = ctx.later.now
    ran_at = Map.get(w.ran_at, "t", was["last"])
    # No scan that skipped the timer stamped its `last`.
    assert was["last"] == ran_at

    acc =
      if on and was["en"] == 1,
        do: min(max(was["acc"], 0) + now - ran_at, 200),
        else: 0

    if on and was["en"] == 1 and now - ran_at > now - ctx.before.now, do: jp_reached(:caught_up)

    expected =
      if on,
        do: %{
          "pre" => 200,
          "acc" => acc,
          "dn" => pc_one(acc == 200),
          "tt" => pc_one(acc != 200),
          "en" => 1,
          "last" => now
        },
        else: %{"pre" => 200, "acc" => 0, "dn" => 0, "tt" => 0, "en" => 0, "last" => now}

    assert ctx.later.env["t"] == expected
    {%{w | ran_at: Map.put(w.ran_at, "t", now)}, nil}
  end

  defp jp_run(%{kind: :b, chain: chain}, w, ctx) do
    if jp_cond(chain, ctx.image) do
      jp_block(w, ctx)
    else
      {jp_frozen(%{kind: :b}, w, ctx), nil}
    end
  end

  # The block's body: its one-shot skipped where its version jumps on `skip`, `m3`.
  defp jp_block(w, ctx) do
    jumps? = ctx.spec.b in [1, 3]

    if jumps? and ctx.image["m3"] == 1 do
      assert Map.take(ctx.later.env["b"], ~w(e q)) == Map.take(ctx.before.env["b"], ~w(e q))
      assert ctx.later.env["bq"] == ctx.before.env["b"]["q"]
      jp_reached(:block_skipped)
      {jp_skipped(w, "b.e"), nil}
    else
      go = ctx.image["e1"] == 1
      on = if ctx.spec.b == 3, do: not go, else: go
      got = ctx.later.env["b"]["q"]
      jp_edge!("b.e", on and not pc_closed?(ctx.before.env["b"]["e"]), got, w, ctx)
      assert ctx.later.env["b"]["e"] == pc_one(on) and ctx.later.env["bq"] == got
      {jp_ran(w, "b.e", ctx), nil}
    end
  end

  # One run of an edge memory: what it gave, 1 or 0, where the oracle allows an edge.
  @jp_memories %{"s" => :s, "c.cu" => :c, "c.cd" => :d, "b.e" => :b}

  defp jp_edge!(mem, edge?, got, w, ctx) do
    same = Map.get(w.last, mem) == ctx.texts[mem]

    allowed =
      cond do
        ctx.before.first -> [false]
        Map.get(w.clean, mem, false) -> [true]
        same -> [false, true]
        true -> [false]
      end

    assert got in Enum.map(allowed, &pc_one(edge? and &1)), "#{mem}: #{got}"
    skipped = Map.get(w.skips, mem, 0) > 0

    if edge? and skipped and not same and not ctx.before.first and
         not Map.get(w.clean, mem, false) do
      jp_reached(:blocked_through_skip)
      if ctx.spec.legs[@jp_memories[mem]] != nil and mem != "b.e", do: jp_reached(:leg_held)
    end

    if got == 1 and skipped and Map.get(w.clean, mem, false), do: jp_reached(:late_edge)
    if got == 1 and not Map.get(w.clean, mem, false), do: jp_reached(:edge_kept)
  end

  defp jp_ran(w, mem, ctx),
    do: %{
      w
      | clean: Map.put(w.clean, mem, true),
        last: Map.put(w.last, mem, ctx.texts[mem]),
        skips: Map.put(w.skips, mem, 0),
        sides: Map.put(w.sides, mem, :ran)
    }

  defp jp_skipped(w, mem),
    do: %{
      w
      | skips: Map.update(w.skips, mem, 1, &(&1 + 1)),
        sides: Map.put(w.sides, mem, :skipped)
    }

  # A rung that does not run changes nothing it writes.
  defp jp_frozen(%{kind: :jmp, i: i}, w, ctx) do
    assert ctx.later.env["q#{i}"] == ctx.before.env["q#{i}"]
    w
  end

  defp jp_frozen(%{kind: :end}, w, _ctx), do: w

  defp jp_frozen(%{kind: :y, chain: chain}, w, ctx) do
    assert ctx.later.env["y"] == ctx.before.env["y"]
    if ctx.before.env["y"] != pc_one(jp_cond(chain, ctx.image)), do: jp_reached(:held_ote)
    w
  end

  defp jp_frozen(%{kind: :s}, w, ctx) do
    assert Map.take(ctx.later.env, ~w(s p)) == Map.take(ctx.before.env, ~w(s p))
    jp_skipped(w, "s")
  end

  # A skipped side leaves its memory and its `move` alone; the other side may run.
  defp jp_frozen(%{kind: :c}, w, ctx) do
    assert {ctx.later.env["c"]["cu"], ctx.later.env["ku"]} ==
             {ctx.before.env["c"]["cu"], ctx.before.env["ku"]}

    jp_skipped(w, "c.cu")
  end

  defp jp_frozen(%{kind: :d}, w, ctx) do
    assert {ctx.later.env["c"]["cd"], ctx.later.env["kd"]} ==
             {ctx.before.env["c"]["cd"], ctx.before.env["kd"]}

    jp_skipped(w, "c.cd")
  end

  defp jp_frozen(%{kind: :t}, w, ctx) do
    assert ctx.later.env["t"] == ctx.before.env["t"]
    w
  end

  defp jp_frozen(%{kind: :b}, w, ctx) do
    assert ctx.later.env["b"] == ctx.before.env["b"] and
             ctx.later.env["bq"] == ctx.before.env["bq"]

    jp_reached(:block_frozen)
    jp_skipped(w, "b.e")
  end
end

defmodule Logex.ApiContractTest.RunnerWalk do
  @moduledoc """
  M4-6: the runner walk (PLAN.md "M4-6 · The contract walk", `docs/organisation.md`
  §4.11), a module of its own beside `Logex.ApiContractTest`, so that it runs beside the
  other walks rather than after them. It runs `Logex.Runner` on the manual clock over 30
  seeded configurations, each a fast task, now and then a slow one, an event task on a
  panel's or a drive's input, an event task on a trigger logic writes and the continuous
  task, with an untimed counter under it or with no task, or none, so that about three in
  four have untimed programs, 22 of the 30 at this seed, and the rest do not; a divide by zero while the panel's dint reads 0; the
  panel and the drive each a simulated device that reports its changes or one that is only
  read; a forces file or none; a poll period, an idle watchdog and a share drawn. Each
  walk takes 70 steps: random waits and presses, forces and unforces, an online edit's
  steps (a candidate's interval, watchdog or untimed counter changed, or a task added,
  which accept refuses), host mistakes, a crash and a fresh start from the same forces
  file, restarts, cold and warm, each reading every device first (decision 142), one now
  and then refused by a device that cannot be opened, for a reason drawn, or by a device
  up whose read fails, in each way `Logex.IO.Sim` fails a read, which the restart gives
  back, and injected faults: a task's step slow by about its watchdog or the continuous
  task's, a host's request slower than the idle watchdog, the runner stuck for less than
  its idle watchdog or for longer than its devices' heartbeat, a device killed, or hung in
  a third of the walks, each hang costing a real-time wait,
  and a device's read, report or write failing in each way `Logex.IO.Sim` acts out, a
  value that does not fit and an address that is no input point's among them.

  It is checked against two models that know nothing of the runner's code.

  - The core's: the hidden seam, `steps:`, stands a module in for `Logex.Runtime`'s steps
    that runs each step as the core does and tells the walk what the runner gave it, each
    round's elapsed time and inputs with the clock's time as it began, and each step's
    task and time. The model calls `Logex.Runtime.cycle/3` with those, and every round's
    events, `{:round, now, outputs}` and resource are cycle/3's (a round that trips part
    way, those of the steps it ran); each edit's step is `Logex.Configuration.Edit`'s at
    the step's time on the clock, 0 while tripped (decision 139), its reply and event the
    same; each restart `Logex.Runtime.restart/2`'s; and after every step `status/1`, every
    `get/2` the walk reads, and each device's outputs (the last round's, 0 while tripped,
    or as they were for a device down) are the model's, a device written nothing while
    tripped after its 0. What the runner gave the core is checked too: each round's
    elapsed time is the clock's since the last round, 0 for the first after a start or a
    restart; a forced input reads its force, a reporting device's input its value now,
    every device's its value now in the first round after a start or a restart, which
    read it, and a read device's a value it held within two poll periods of the round,
    and the time passed inside steps while it was read, each pass that ended within that
    window widening it by its own time and no more, which a test of the check's own pins;
    a scheduled round comes exactly when decision 122's back to back rounds or the next periodic due time say, never before a step it waited
    behind, and none is left owed; and a force of a trigger makes its round at once, one
    that changes nothing none (decisions 120 and 138).
  - The watchdogs' and the trip's: a timed task's step longer than its watchdog trips
    `{:watchdog, {:task, ...}}` after it, the round longer than the continuous task's
    `{:watchdog, {:round, ...}}` with each step's time, a slow request `{:watchdog, {:idle,
    ms}}`, a runner stuck past its devices' deadlines `{:watchdog, {:device, "drive", idle
    + poll}}` (decision 137), each device fault `{:io, device, cause}` in its words, and
    since M5-9 a step whose run met a major fault, a bit whose number the panel's dint
    gives out of range, `{:fault, task, instance, fault}` at the step's end, no later step
    of its round run (decisions 153 and 160), as restated from the record; a fault that
    does not trip trips nothing; and a runner
    stopped or crashed writes every output 0 once where it ran, and nothing where it had
    tripped.

  The walk repeats exactly from fresh processes, and asserts its reach: every event kind,
  every trip reason but `{:internal, message}`, which the host contract makes unreachable
  from a walk and `trip_test.exs` reaches through the seam, and each kind of round, step,
  fault and mistake. No step reads the real clock, but the runner's waits for its devices
  are in real time (decision 125): an open or a close waits for the idle watchdog and a
  poll period, so the walk draws an idle watchdog of 400 or 500 ms, which a device's open
  made late by 100 ms, as on a loaded machine, now and then at a start, must not trip,
  and a hung device costs one such wait or less; and a round's write waits for what is left of
  its step's deadline on the manual clock, its task's watchdog and a poll period less the
  time a slow step passed, so a step slow by its watchdog exactly leaves its write a poll
  period, 3 to 8 ms, of real time.
  """
  use ExUnit.Case, async: true

  # A device or a runner the walk kills is reported by its process as it goes down.
  @moduletag :capture_log

  alias Logex.Configuration
  alias Logex.Configuration.Edit, as: ConfigEdit
  alias Logex.IO.Sim
  alias Logex.Runner
  alias Logex.Runner.Clock.Manual
  alias Logex.Runtime

  @table :logex_runner_walk

  # The hidden seam's stand-in for Logex.Runtime's steps (§4.11, `steps:`): each step is
  # the core's own, and the walk is told what the runner gave the core, the elapsed time
  # and the inputs of each round with the clock's time as it began, and each step's task
  # with the time it took. A step of a task the walk has made slow passes that time on the
  # manual clock after the core has run it, as a slow program would, once.
  defmodule Walked do
    @table :logex_runner_walk

    def cycle_steps(runtime, elapsed, inputs) do
      {test, clock} = walk()
      now = Manual.now_ms(clock)
      inputs = Logex.ApiContractTest.RunnerWalk.delayed(test, now, inputs)
      send(test, {:walked, self(), {:steps, elapsed, inputs, now}})
      Runtime.cycle_steps(runtime, elapsed, inputs)
    end

    def cycle_step(runtime, {_kind, task, _run} = step) do
      result = Runtime.cycle_step(runtime, step)
      {test, clock} = walk()
      ms = slow(:ets.take(@table, {test, :slow, task}))
      passed(clock, ms)
      send(test, {:walked, self(), {:step, task, ms}})
      result
    end

    def cycle_outputs(runtime), do: Runtime.cycle_outputs(runtime)

    defp walk do
      [test | _] = Process.get(:"$ancestors")
      {test, :ets.lookup_element(@table, {test, :clock}, 2)}
    end

    defp slow([{_key, ms}]), do: ms
    defp slow([]), do: 0

    defp passed(_clock, 0), do: :ok

    defp passed(clock, ms) do
      [test | _] = Process.get(:"$ancestors")
      Logex.ApiContractTest.RunnerWalk.passing(test, clock, ms)
    end
  end

  # The manual clock, every reading the runner makes passing `{test, :lag}` ms first where
  # the walk has set it: a host's request that takes that long, for the idle watchdog.
  # A device's readings, made in its own process, pass nothing; but where the walk has set
  # `{test, :late}`, the first a device makes, inside its open, sleeps that many ms in real
  # time first, once, as a loaded machine is late, which the runner's real-time wait for
  # an open, the idle watchdog and a poll period, must cover.
  defmodule Lagged do
    @behaviour Logex.Runner.Clock
    @table :logex_runner_walk

    @impl true
    def now_ms({clock, test}) do
      lag(Process.get(:"$initial_call"), clock, test)
      Manual.now_ms(clock)
    end

    @impl true
    def wake_at({clock, _test}, pid, message, at), do: Manual.wake_at(clock, pid, message, at)

    @impl true
    def cancel({clock, _test}, timer), do: Manual.cancel(clock, timer)

    defp lag({Logex.Runner, :init, 1}, clock, test),
      do: lagged(:ets.lookup(@table, {test, :lag}), clock)

    defp lag({Logex.Runner.Device, :init, 1}, _clock, test),
      do: late(:ets.take(@table, {test, :late}))

    defp lag(_other, _clock, _test), do: :ok

    defp late([{_key, ms}]), do: Process.sleep(ms)
    defp late([]), do: :ok

    defp lagged([{{test, :lag}, ms}], clock) when ms > 0,
      do: Logex.ApiContractTest.RunnerWalk.passing(test, clock, ms)

    defp lagged(_none, _clock), do: :ok
  end

  # Time passed inside a step on the manual clock, which delivers no device's poll on the
  # way, each pass recorded with the time it began, so that a read device's input is
  # allowed the time passed while it was read, and no more (`passes/2`).
  @doc false
  def passing(test, clock, ms) do
    :ets.insert(@table, {{test, :pass, :erlang.unique_integer()}, {Manual.now_ms(clock), ms}})
    delaying(:ets.lookup(@table, {test, :stale}), test, ms)
    Manual.pass(clock, ms)
  end

  # The check's own test (below): from the first time passed inside a step, a read
  # device's change, but a trigger's or a force's, given to the core late by that time
  # less 10 ms, as a runner that took it late would, so that it is never later than a
  # running maximum of the time passed would allow, but later than two poll periods.
  defp delaying([{_key, {names, poll}}], test, ms) when ms - 10 > 2 * poll + 1,
    do: :ets.insert_new(@table, {{test, :delay}, {ms - 10, names}})

  defp delaying(_stale, _test, _ms), do: true

  @doc false
  def delayed(test, now, inputs),
    do: delayed(:ets.lookup(@table, {test, :delay}), test, now, inputs)

  defp delayed([], _test, _now, inputs), do: inputs

  defp delayed([{_key, {delay, names}}], test, now, inputs) do
    {late, given} = Map.split(inputs, names)
    held = :ets.lookup_element(@table, {test, :held}, 2, %{})

    held =
      Enum.reduce(late, held, fn {name, value}, held ->
        Map.update(held, name, {value, now}, fn {_was, since} -> {value, since} end)
      end)

    {due, still} = Enum.split_with(held, fn {_name, {_value, since}} -> since + delay <= now end)
    :ets.insert(@table, {{test, :held}, Map.new(still)})
    Enum.into(for({name, {value, _since}} <- due, do: {name, value}), given)
  end

  # ---- the programs and the configurations -----------------------------------------------

  @programs %{
    "relay" => "var_input in bool\nvar_output out bool\nxic in ote out",
    "count" => "var_output n dint\nadd n 1 n",
    "ratio" => "var_input d dint\nvar_output q dint\ndiv 1000 d q",
    # M5-9: a bit whose number the panel's dint gives, read while the panel's `pb` is
    # pressed: its -4 is out of range, a major fault (decisions 153 and 160).
    "bit" =>
      "var_input n dint\nvar_input on bool\nvar w dint 5\nvar q bool\nxic on xic w.[n] ote q"
  }

  defp programs,
    do:
      Map.new(@programs, fn {name, text} ->
        {:ok, program} = Logex.compile(text, name: name)
        {name, program}
      end)

  # The plant's points: the panel's and the drive's, each with bools and a dint in and out.
  @points [
    {"pa", "bool", "panel.i.0"},
    {"pb", "bool", "panel.i.1"},
    {"pd", "dint", "panel.i.2"},
    {"qa", "bool", "panel.q.0"},
    {"qn", "dint", "panel.q.1"},
    {"da", "bool", "drive.i.0"},
    {"db", "bool", "drive.i.1"},
    {"qb", "bool", "drive.q.0"},
    {"qc", "dint", "drive.q.1"}
  ]

  @inputs %{
    "pa" => {"panel", [0], :bool},
    "pb" => {"panel", [1], :bool},
    "pd" => {"panel", [2], :dint},
    "da" => {"drive", [0], :bool},
    "db" => {"drive", [1], :bool}
  }

  @outputs %{"panel" => %{[0] => "qa", [1] => "qn"}, "drive" => %{[0] => "qb", [1] => "qc"}}

  # Everything the walk must be seen to reach: every event kind; every trip reason but
  # {:internal, message}; each kind of round (decisions 120, 122, 123 and 138); and each
  # step, refusal and fault.
  @runner_reach [
    :ran,
    :fault,
    :overlap,
    :round,
    :trip,
    :restart,
    :edit,
    {:trip, :task},
    {:trip, :round},
    {:trip, :idle},
    {:trip, :device},
    {:trip, :error},
    {:trip, :raised},
    {:trip, :thrown},
    {:trip, :exited},
    {:trip, :bad_value},
    {:trip, :unknown_address},
    {:trip, :timeout},
    {:trip, :down},
    {:trip, :bit_out_of_range},
    :round_first,
    :round_scheduled,
    :round_trigger,
    {:trigger_round, :report},
    {:trigger_round, :poll},
    {:trigger_round, :force},
    :logic_round,
    :untimed,
    :timed_only,
    :reporting,
    :read_only,
    :force,
    :forced_trigger,
    :forced_trigger_pressed,
    :unforce,
    :unforce_all,
    :no_forces_file,
    :misforced,
    :accept,
    :accept_refused,
    :test,
    :untest,
    :assemble,
    :cancel,
    :next_due_from_step,
    :test_refused,
    :untest_refused,
    :assemble_refused,
    :cancel_refused,
    :no_edit_held,
    :step_tripped,
    :untimed_added,
    :untimed_taken,
    :slow_injected,
    :stuck_small,
    :restart_cold,
    :restart_warm,
    :restart_init_refused,
    :restart_read_refused,
    :restart_running,
    :get_mistake,
    :crash,
    :late_open
  ]

  @paths ~w(pa pb pd da db qa qn qb qc cm cs g r1.out c1.n d1.q c2.n c3.n nothing)

  # A draw: the tasks' intervals and watchdogs, an event task on a panel's or a drive's
  # input, a trigger logic writes, the continuous task declared or not, and the untimed
  # counter, with no task or `with main`, or none.
  defp draw do
    %{
      fast: pick([2, 5, 10]),
      slow: pick([nil, 15, 25]),
      event: pick([nil, "pb", "db"]),
      logic: pick([false, true]),
      main: pick([false, true]),
      c2: pick([nil, :none, :main, :main]),
      wd: %{
        "fast" => pick([nil, 20, 30, 40]),
        "slow" => pick([20, 30, 40]),
        "e" => pick([20, 30]),
        "l" => pick([20, 40]),
        "main" => pick([20, 30, 40, nil])
      },
      extra: false
    }
  end

  defp text(d),
    do:
      Enum.join(
        tasks(d) ++
          Enum.map(@points, fn {name, type, at} -> "var_global #{name} #{type} at #{at}" end) ++
          ["var_global cm dint", "var_global cs dint", "var_global g bool"] ++ instances(d),
        "\n"
      ) <> "\n"

  defp tasks(d),
    do:
      ["task fast interval #{d.fast} priority 1#{watchdog(d.wd["fast"])}"] ++
        optional(d.slow, &"task slow interval #{&1} priority 2#{watchdog(d.wd["slow"])}") ++
        optional(d.event, &"task e single #{&1} priority 0#{watchdog(d.wd["e"])}") ++
        optional(d.logic, fn _ -> "task l single g priority 3#{watchdog(d.wd["l"])}" end) ++
        optional(d.main, fn _ -> "task main continuous#{watchdog(d.wd["main"])}" end) ++
        optional(d.extra, fn _ -> "task extra interval 7 priority 9" end)

  defp watchdog(nil), do: ""
  defp watchdog(ms), do: " watchdog #{ms}"

  defp optional(nil, _line), do: []
  defp optional(false, _line), do: []
  defp optional(value, line), do: [line.(value)]

  defp instances(d),
    do:
      [
        "program r1 relay with fast\n  r1.in pa\n  r1.out qa",
        "program c1 count with fast\n  c1.n qn",
        "program d1 ratio with #{ratio_task(d.slow)}\n  d1.d pd\n  d1.q qc",
        "program b1 bit with fast\n  b1.n pd\n  b1.on pb"
      ] ++
        optional(d.event, fn _ -> "program r2 relay with e\n  r2.in da\n  r2.out qb" end) ++
        optional(d.logic, fn _ -> "program rg relay with fast\n  rg.in pb\n  rg.out g" end) ++
        optional(d.logic, fn _ -> "program c3 count with l\n  c3.n cs" end) ++
        optional(d.c2, &untimed_counter(&1, d.main))

  defp ratio_task(nil), do: "fast"
  defp ratio_task(_slow), do: "slow"

  defp untimed_counter(:main, true), do: "program c2 count with main\n  c2.n cm"
  defp untimed_counter(_with, _main), do: "program c2 count\n  c2.n cm"

  defp configured(d, programs) do
    {:ok, config} = Configuration.compile("plant", text(d), programs)
    config
  end

  # A candidate: one or two changes a running plant takes, or a task added, which it
  # refuses.
  defp candidate(d) do
    changes = Enum.take_random([:fast, :fast, :slow, :wd, :c2, :c2, :refused], pick([1, 2]))
    Enum.reduce(changes, d, &changed/2)
  end

  # An interval cut more often than lengthened, so that decision 40 moves its next due
  # time from the step's time (decision 139).
  defp changed(:fast, d), do: %{d | fast: pick(shorter(d.fast, [2, 5, 10]))}
  defp changed(:slow, %{slow: nil} = d), do: d
  defp changed(:slow, d), do: %{d | slow: pick(shorter(d.slow, [15, 25, 40]))}

  defp changed(:wd, d),
    do: %{d | wd: Map.put(d.wd, pick(["fast", "slow", "main"]), pick([20, 30, 40]))}

  defp changed(:c2, %{c2: nil} = d), do: %{d | c2: pick([:none, :main])}
  defp changed(:c2, d), do: %{d | c2: nil}
  defp changed(:refused, d), do: %{d | extra: true}

  defp shorter(interval, intervals) do
    others = intervals -- [interval]
    (for(i <- others, i < interval, do: i) |> List.duplicate(2) |> List.flatten()) ++ others
  end

  defp pick(list), do: Enum.at(list, :rand.uniform(length(list)) - 1)

  # ---- the walk --------------------------------------------------------------------------

  setup_all do
    :ets.new(@table, [:named_table, :public, :set])
    :ok
  end

  # At 30 walks of 70 steps every atom is reached at this seed, in about 7 s alone, most of
  # it the hung devices' real-time waits. Over 30 other seed families every walk passed,
  # in 5 to 11 s, and 22 reached every atom, the rest missing one, an interval cut a while
  # after the last round (decision 139) or a step taken while tripped, each rare by its
  # nature.
  @tag :tmp_dir
  test "the runner on the manual clock runs each round as cycle/3 runs it, trips as the " <>
         "watchdogs and the faults say, and reaches every event kind and trip reason",
       %{tmp_dir: dir} do
    programs = programs()
    Process.put(:runner_reach, MapSet.new())

    logs =
      for seed <- 1..30 do
        :rand.seed(:exsss, {2026, 10, 19 + seed})
        walk(programs, dir, seed, 70)
      end

    # From fresh processes, the first walk again, exactly.
    :rand.seed(:exsss, {2026, 10, 20})
    assert walk(programs, dir, 1, 70) == hd(logs)

    assert Process.get(:runner_reach) == MapSet.new(@runner_reach)
  end

  # The walk's check of a read device's input allows the time passed inside a step while it
  # was read, and no more: a runner that gives the core such a change late, once time has
  # passed inside a step, by less than that time but by more than two poll periods, is
  # caught once the time passed is behind it. A check that kept the most time ever passed
  # would allow it for the rest of the walk.
  @tag :tmp_dir
  test "the walk's input check holds a read device's input to the time passed while it " <>
         "was read",
       %{tmp_dir: dir} do
    programs = programs()
    Process.put(:runner_reach, MapSet.new())
    Process.put(:stale_mode, true)

    caught =
      Enum.find_value(1..20, fn seed ->
        :rand.seed(:exsss, {2026, 11, seed})

        try do
          walk(programs, dir, seed, 70)
          nil
        rescue
          error in ExUnit.AssertionError -> error.message
        end
      end)

    assert is_binary(caught), "the walk's check caught no input given late"
    assert caught =~ ~r/^(pa|pd|da) read -?\d+ at \d+, held /
  end

  defp walk(programs, dir, seed, steps) do
    d = draw()
    config = configured(d, programs)
    {:ok, manual} = Manual.start_link()
    test = self()
    :ets.insert(@table, {{test, :clock}, manual})
    :ets.insert(@table, {{test, :lag}, 0})
    :ets.match_delete(@table, {{test, :pass, :_}, :_})
    for key <- [:delay, :held, :stale], do: :ets.delete(@table, {test, key})
    reports = %{"panel" => pick([true, false]), "drive" => pick([true, false])}
    sims = Map.new(reports, fn {name, r} -> {name, sim(r, manual)} end)
    file = pick([nil, Path.join(dir, "forces-#{seed}")])
    File.rm(file || Path.join(dir, "none"))

    w = %{
      programs: programs,
      draws: %{running: d, original: nil, candidate: nil},
      manual: manual,
      reports: reports,
      lossy: MapSet.new(),
      sims: sims,
      file: file,
      poll: pick([3, 5, 8]),
      idle: pick([400, 500]),
      overhead: pick([10, 20, 50, 90]),
      hangs: pick([true, false, false]),
      forces: %{},
      timeline: Map.new(@inputs, fn {name, _} -> {name, [{0, 0}]} end),
      log: [],
      fault: nil,
      down: MapSet.new(),
      unforcing: %{},
      hung: %{},
      begun: 0,
      doing: nil,
      crashed: false
    }

    reach(:untimed, untimed?(config))
    reach(:timed_only, not untimed?(config))
    reach(:reporting, reports["panel"] or reports["drive"])
    reach(:read_only, not (reports["panel"] and reports["drive"]))

    stale(Process.get(:stale_mode), test, reports, w.poll)
    w = started(w, config)
    w = Enum.reduce_while(1..steps, w, fn _, w -> stepped_on(step(w)) end)
    w = ended(w)
    for {_name, sim} <- sims, do: GenServer.stop(sim)
    GenServer.stop(manual)
    Enum.reverse(w.log)
  end

  # The check's own test reads only the read devices' inputs that are no trigger, and
  # ends its walk at a trip, after which a change held back would be held for as long.
  defp stale(nil, _test, _reports, _poll), do: :ok

  defp stale(true, test, reports, poll) do
    names =
      for {name, {device, _, _}} <- @inputs,
          name not in ["pb", "db"],
          not reports[device],
          do: name

    :ets.insert(@table, {{test, :stale}, {names, poll}})
  end

  defp stepped_on(%{status: :tripped} = w), do: on(Process.get(:stale_mode), w)
  defp stepped_on(w), do: {:cont, w}

  defp on(nil, w), do: {:cont, w}
  defp on(true, w), do: {:halt, w}

  defp sim(reports, manual) do
    {:ok, sim} = Sim.start_link(reports: reports, clock: manual)
    sim
  end

  # A runner started on the configuration, its first round run at once before it returns,
  # and the walk subscribed to every kind of event.
  defp started(w, config) do
    late = late_open()

    {:ok, runner} =
      Runner.start_link(
        configuration: config,
        io: Map.new(w.sims, fn {name, sim} -> {name, {Sim, sim: sim}} end),
        clock: {Lagged, {w.manual, self()}},
        poll: w.poll,
        idle: w.idle,
        overhead: w.overhead,
        forces: w.file,
        steps: Walked
      )

    assert :ets.lookup(@table, {self(), :late}) == []
    reach(:late_open, late)
    :ok = Runner.subscribe(runner, [:overlap, :fault, :trip, :restart, :edit, :ran, :round])
    rt = Runtime.start(config)

    w =
      Map.merge(w, %{
        runner: runner,
        config: config,
        rt: rt,
        edit: nil,
        expect: [],
        status: :running,
        trip: nil,
        rounds: 0,
        logical: 0,
        last: nil,
        first: true,
        floor: nil,
        round: nil,
        outputs: nil,
        written: %{},
        zeroed: %{},
        logic: logic_values(config, rt),
        longest: longest(%{}, config),
        subscribed: false,
        down: MapSet.new(),
        hung: %{}
      })

    # The first round's record came before the subscription: it ends with no event.
    w = consumed(w)
    w = round_ended(w, w.round.outputs)
    checked(%{w | subscribed: true})
  end

  # Now and then the first device opened is late, by more than an idle watchdog of 60 or
  # 80 ms and a poll period would cover and by less than the walk's 400 or 500: a loaded
  # machine, which must trip nothing, the runner waiting for an open in real time.
  defp late_open do
    late = :rand.uniform(6) == 1
    late && :ets.insert(@table, {{self(), :late}, 100})
    late
  end

  defp ended(w) do
    w = settled(w)
    before = writes(w)
    :ok = Runner.stop(w.runner)
    w = drained(w)
    stopped!(w, before)
    w
  end

  # Every output written 0 once by a runner stopped or gone while it ran, nothing by one
  # that had tripped, and every device that was up closed.
  defp stopped!(w, before) do
    for {name, sim} <- w.sims, not MapSet.member?(w.down, name) do
      assert Sim.closed?(sim)
      after_ = Sim.writes(sim)
      zeros = Map.new(Map.fetch!(@outputs, name), fn {address, _} -> {address, 0} end)
      zeroed!(w.status, before[name], after_, zeros)
    end
  end

  defp zeroed!(:running, before, after_, zeros),
    do: assert(Enum.drop(after_, length(before)) == [zeros])

  defp zeroed!(:tripped, before, after_, _zeros), do: assert(after_ == before)

  defp writes(w), do: Map.new(w.sims, fn {name, sim} -> {name, Sim.writes(sim)} end)

  # ---- the steps -------------------------------------------------------------------------

  # A step: a tripped runner restarted, more often than not soon; otherwise a wait, a
  # press, forcing, an edit's step, a fault, a host's mistake or a crash.
  defp step(w), do: stepped(%{w | doing: nil})

  defp stepped(%{status: :tripped} = w) do
    case :rand.uniform(10) do
      n when n <= 4 -> restart(w)
      n -> running_step(n, w)
    end
  end

  defp stepped(w), do: running_step(:rand.uniform(12), w)

  defp running_step(n, w) when n <= 3, do: wait(w, :rand.uniform(26) - 1)
  defp running_step(n, w) when n <= 5, do: press(w)
  defp running_step(6, w), do: forcing(Process.get(:stale_mode), w)
  defp running_step(n, w) when n in [7, 11], do: editing(w)
  defp running_step(8, %{status: :running} = w), do: inject(w)
  defp running_step(9, w), do: mistaken(w)
  defp running_step(10, %{file: file, crashed: false} = w) when file != nil, do: crashed(w)
  defp running_step(_n, w), do: wait(w, :rand.uniform(6))

  defp wait(w, ms) do
    target = now(w) + ms
    :ok = Manual.advance(w.manual, ms)
    checked(missed(consumed(w), target))
  end

  # A press, now and then of a trigger that is forced, whose device's change the runner
  # reads as the force and makes no round of (decision 117).
  defp press(w) do
    forced = for name <- triggers(w.config), Map.has_key?(w.forces, name), do: name
    name = pick(forced ++ forced ++ Enum.sort(Map.keys(@inputs)))
    {device, address, type} = @inputs[name]
    reach(:forced_trigger_pressed, name in forced)
    set(w, name, device, address, value(type))
  end

  defp set(w, name, device, address, value) do
    :ok = Sim.set(w.sims[device], address, value)
    checked(consumed(timed_value(%{w | doing: :report}, name, value)))
  end

  defp timed_value(w, name, value) do
    now = Manual.now_ms(w.manual)
    %{w | timeline: Map.update!(w.timeline, name, &[{now, value} | &1])}
  end

  defp value(:bool), do: pick([0, 1])
  defp value(:dint), do: pick([0, 0, 3, 7, -4])

  # ---- forcing ---------------------------------------------------------------------------

  # The check's own test forces nothing, a force being read exactly.
  defp forcing(nil, w), do: forcing(w)
  defp forcing(true, w), do: wait(w, 1)

  defp forcing(%{file: nil} = w) do
    {name, _} = pick(Enum.sort(@inputs))

    raises(
      "the runner keeps no forces file, so a force would not survive a crash: start it " <>
        "with forces: a path",
      fn -> Runner.force(w.runner, name, 1) end
    )

    reach(:no_forces_file, true)
    checked(w)
  end

  defp forcing(w) do
    w = %{settled(w) | doing: :force}

    case :rand.uniform(6) do
      n when n <= 3 ->
        name = pick(triggers(w.config) ++ Enum.sort(Map.keys(@inputs)))
        {_device, _address, type} = @inputs[name]
        value = value(type)
        kick = kicks?(w, name, value)
        began = w.begun
        assert Runner.force(w.runner, name, value) == :ok
        reach(:force, true)
        reach(:forced_trigger, kick == 1)

        # A force that changes what a trigger reads makes its round at once, before it
        # returns, and one that does not makes none (decisions 120 and 138).
        w = drained(%{w | forces: Map.put(w.forces, name, value)})
        assert w.begun - began == kick
        forced(w)

      n when n <= 5 ->
        name = pick(Enum.sort(Map.keys(w.forces)) ++ [pick(Enum.sort(Map.keys(@inputs)))])
        assert Runner.unforce(w.runner, name) == :ok
        reach(:unforce, Map.has_key?(w.forces, name))
        forced(%{w | forces: Map.delete(w.forces, name)})

      6 ->
        assert Runner.unforce_all(w.runner) == :ok
        reach(:unforce_all, map_size(w.forces) > 0)
        forced(%{w | forces: %{}, unforcing: w.forces})
    end
  end

  defp kicks?(%{status: :running} = w, name, value) do
    reads = Map.get_lazy(w.forces, name, fn -> Runtime.get!(w.rt, name) end)
    ((name in triggers(w.config) and value != reads) && 1) || 0
  end

  defp kicks?(_tripped, _name, _value), do: 0

  # The forces file holds every force, one a line, in name order (decision 140).
  defp forced(w) do
    text = for {name, value} <- Enum.sort(w.forces), into: "", do: "#{name} #{value}\n"
    assert File.read!(w.file) == text
    checked(%{consumed(w) | unforcing: %{}})
  end

  # ---- an online edit --------------------------------------------------------------------

  defp editing(%{edit: nil} = w) do
    case :rand.uniform(4) do
      1 -> held_none(w)
      _ -> accept(w)
    end
  end

  defp editing(w) do
    case :rand.uniform(5) do
      1 -> accept(w)
      n when n <= 3 -> edit_step(w, pick(refused(ConfigEdit.stage(w.edit))))
      _ -> edit_step(w, onward(ConfigEdit.stage(w.edit)))
    end
  end

  # The steps a stage refuses, each the host's mistake in Logex.Configuration.Edit's words.
  defp refused(:testing), do: [:test, :cancel]
  defp refused(_accepted_or_untested), do: [:untest, :assemble]

  defp onward(:accepted), do: pick([:test, :test, :cancel])
  defp onward(:testing), do: pick([:untest, :assemble])
  defp onward(:untested), do: pick([:test, :cancel])

  defp held_none(w) do
    step = pick([:test, :untest, :assemble, :cancel])

    raises(
      "the runner holds no edit: #{step}/1 is a step of the edit accept/2 accepts",
      fn -> apply(Runner, step, [w.runner]) end
    )

    reach(:no_edit_held, true)
    checked(w)
  end

  # The step's time on the runner's clock, the time since the last round began, 0 while
  # tripped (decision 139).
  defp step_time(%{status: :running} = w), do: Manual.now_ms(w.manual) - w.last.at
  defp step_time(_tripped), do: 0

  defp accept(w) do
    w = settled(w)
    draw = candidate(w.draws.running)
    candidate = configured(draw, w.programs)

    case ConfigEdit.accept(w.rt, candidate, step_time(w)) do
      {:ok, edit, forecast} ->
        assert Runner.accept(w.runner, candidate) == {:ok, forecast}
        reach(:accept, true)
        w = %{w | edit: edit, expect: [{:edit, :accept, forecast}]}
        w = put_in(w.draws.original, w.draws.running)
        checked(consumed(put_in(w.draws.candidate, draw)))

      {:error, diagnostics} ->
        assert Runner.accept(w.runner, candidate) == {:error, diagnostics}
        reach(:accept_refused, true)
        checked(consumed(w))
    end
  end

  defp edit_step(w, step) do
    w = settled(w)
    expected = model_step(w, step)
    reply = reply(fn -> apply(Runner, step, [w.runner]) end)
    edited(w, step, expected, reply)
  end

  defp model_step(w, step) when step in [:test, :untest] do
    apply(ConfigEdit, step, [w.edit, w.rt, step_time(w)])
  rescue
    error in ArgumentError -> {:raise, error.message}
  end

  defp model_step(w, step) do
    apply(ConfigEdit, step, [w.edit, w.rt])
  rescue
    error in ArgumentError -> {:raise, error.message}
  end

  defp reply(call) do
    call.()
  rescue
    error in ArgumentError -> {:raise, error.message}
  end

  defp edited(w, step, {:raise, message}, reply) do
    assert reply == {:raise, message}
    reach(:"#{step}_refused", true)
    checked(w)
  end

  defp edited(w, step, {edit, rt, report}, reply) when step in [:test, :untest] do
    assert reply == {:ok, report}
    reach(step, true)

    reach(
      :next_due_from_step,
      step_time(w) > 0 and Enum.any?(report, &match?({:next_due, _, _}, &1))
    )

    reach(:step_tripped, w.status == :tripped)
    config = ConfigEdit.running(edit)
    running = (step == :test && w.draws.candidate) || w.draws.original
    w = %{w | edit: edit, rt: rt, expect: [{:edit, step, report}]}
    checked(consumed(reconfigured(put_in(w.draws.running, running), config)))
  end

  defp edited(w, step, {config, rt, report}, reply) do
    assert reply == {:ok, report}
    reach(step, true)
    running = (step == :assemble && w.draws.candidate) || w.draws.original
    w = %{w | edit: nil, rt: rt, expect: [{:edit, step, report}]}
    checked(consumed(reconfigured(put_in(w.draws.running, running), config)))
  end

  # After a step the rounds read the configuration the resource runs, and the next is
  # planned again from the last, never before the step (decisions 129 and 139).
  defp reconfigured(%{status: :running} = w, config) do
    reach(:untimed_added, untimed?(config) and not untimed?(w.config))
    reach(:untimed_taken, untimed?(w.config) and not untimed?(config))
    %{w | config: config, longest: longest(w.longest, config), floor: now(w)}
  end

  defp reconfigured(w, config), do: %{w | config: config, longest: longest(w.longest, config)}

  defp now(w), do: Manual.now_ms(w.manual)

  # ---- a host's mistakes -----------------------------------------------------------------

  defp mistaken(w) do
    w = settled(w)

    case :rand.uniform(4) do
      1 ->
        restarted_running(w)

      2 ->
        {name, value, message} =
          pick([
            {"qa", 1, "`qa` is an output point, at `panel.q.0`: only an input point is forced"},
            {"pa", 2, "`pa` is a bool, forced to 0 or 1, got: 2"}
          ])

        raises(misforced(w.file, message), fn -> Runner.force(w.runner, name, value) end)
        reach(:misforced, w.file != nil)
        checked(w)

      3 ->
        path = pick(["nothing", "c1.nothing", "zz"])
        {:error, reason} = Runtime.get(w.rt, path)
        raises(reason, fn -> Runner.get!(w.runner, path) end)
        reach(:get_mistake, true)
        checked(w)

      4 ->
        restarted_running(w)
    end
  end

  # A runner with no forces file takes no force at all, which it says first.
  defp misforced(nil, _message),
    do:
      "the runner keeps no forces file, so a force would not survive a crash: start it " <>
        "with forces: a path"

  defp misforced(_file, message), do: message

  defp restarted_running(%{status: :running} = w) do
    raises("the runner is running: restart/2 starts a runner again once it has tripped", fn ->
      Runner.restart(w.runner, :cold)
    end)

    reach(:restart_running, true)
    checked(w)
  end

  defp restarted_running(w), do: restart(w)

  defp raises(message, fun), do: assert_raise(ArgumentError, message, fun)

  # ---- a restart -------------------------------------------------------------------------

  # A tripped runner restarted, :cold or :warm (decision 113): every device read once, in
  # device-name order, as a start reads them (decision 142), each that went down opened
  # again, one now and then refusing to open, or one up giving a read that fails, which
  # leaves the runner tripped with its first reason, every device that answers written 0
  # once more (decision 136). The device's own reason is the restart's, whatever it is.
  defp restart(w) do
    mode = pick([:cold, :warm])
    down = Enum.sort(MapSet.to_list(w.down))
    up = for name <- Enum.sort(Map.keys(w.sims)), Enum.all?(down, &(&1 > name)), do: name

    refusal =
      case {down != [] and :rand.uniform(3) == 1, up != [] and :rand.uniform(4) == 1} do
        {true, _} ->
          {:init, hd(down), pick([:refused, :unplugged, {:no_route, :rand.uniform(9)}])}

        {false, true} ->
          {:read, pick(up), pick(read_hows())}

        {false, false} ->
          nil
      end

    restart(refusal, mode, w)
  end

  defp restart(nil, mode, w) do
    assert Runner.restart(w.runner, mode) == :ok
    reach(:"restart_#{mode}", true)

    # Its first round ran before it returned.
    w = drained(w)
    assert w.round == nil and (w.first == false or w.status == :tripped)
    checked(consumed(w))
  end

  defp restart({callback, device, how}, mode, w) do
    before = writes(w)
    Sim.fail(w.sims[device], callback, refusal_how(callback, how))

    assert Runner.restart(w.runner, mode) ==
             {:error, {:io_init, device, refusal_cause(callback, device, how)}}

    reach(:"restart_#{callback}_refused", true)
    w = consumed(w)

    for {name, sim} <- w.sims, not MapSet.member?(w.down, name) do
      zeros = Map.new(Map.fetch!(@outputs, name), fn {address, _} -> {address, 0} end)
      assert Enum.drop(Sim.writes(sim), length(before[name])) == [zeros]
    end

    checked(%{w | zeroed: %{}})
  end

  defp refusal_how(:init, reason), do: {:error, reason}
  defp refusal_how(:read, how), do: how

  defp refusal_cause(:init, _device, reason), do: reason
  defp refusal_cause(:read, device, how), do: cause(device, :read, how)

  # ---- a crash and a fresh start ---------------------------------------------------------

  # The runner killed, as a machine that loses it: each device it had writes every output
  # 0 once, where it had not, and closes (decision 115); and a runner started again from
  # the same forces file comes back with every force (decision 127).
  defp crashed(w) do
    w = settled(w)
    devices = device_pids(w.runner)
    watched = Enum.map(devices, fn {_name, pid} -> Process.monitor(pid) end)
    before = writes(w)
    Process.unlink(w.runner)
    ref = Process.monitor(w.runner)
    Process.exit(w.runner, :kill)
    assert_receive {:DOWN, ^ref, :process, _, :killed}, 5000
    for ref <- watched, do: assert_receive({:DOWN, ^ref, :process, _, _}, 5000)
    w = drained(w)
    stopped!(w, before)
    reach(:crash, true)
    w = %{w | crashed: true, edit: nil}
    started(w, w.config)
  end

  defp device_pids(runner) do
    {:links, links} = Process.info(runner, :links)

    for pid <- links,
        {:dictionary, dictionary} <- [Process.info(pid, :dictionary)],
        dictionary[:"$initial_call"] == {Logex.Runner.Device, :init, 1},
        do: {:sys.get_state(pid).name, pid}
  end

  # ---- the faults ------------------------------------------------------------------------

  # A kind of fault, each kind as likely as another, and then one of its kind.
  defp inject(w) do
    w = settled(w)
    kinds = Enum.group_by(injections(w), &elem(&1, 0))
    injected(pick(kinds[pick([:slow | Enum.sort(Map.keys(kinds))])]), w)
  end

  # Each way `Logex.IO.Sim` fails a read, a report or a write.
  defp read_hows,
    do: [{:error, :eio}, :raise, :throw, :exit, {:value, [0], 2}, {:value, [7], 1}]

  defp injections(w) do
    devices = ["panel", "drive"]
    hows = read_hows()

    [{:slow, "fast"}, {:stuck, :small}, {:stuck, :big}] ++
      optional(w.config.tasks |> Enum.find(&(&1.name == "slow")), fn _ -> {:slow, "slow"} end) ++
      optional(continuous(w.config), &{:slow, &1}) ++
      optional(not untimed?(w.config), fn _ -> {:idle} end) ++
      for(device <- devices, do: {:kill, device}) ++
      for(device <- devices, w.hangs, do: {:hang, device}) ++
      for(device <- devices, how <- hows, do: {:read, device, how}) ++
      for(device <- devices, how <- Enum.take(hows, 4), do: {:write, device, how}) ++
      for(device <- devices, w.reports[device], how <- hows, do: {:report, device, how})
  end

  defp injected({:slow, task}, w) do
    ms = slow_ms(task, w)
    :ets.insert(@table, {{self(), :slow, task}, ms})
    w = wait_for_slow(w, task, 60)
    reach(:slow_injected, true)
    checked(w)
  end

  defp injected({:idle}, w) do
    lag = w.idle + pick([1, 1, 2, 5])
    :ets.insert(@table, {{self(), :lag}, lag})
    status = Runner.status(w.runner)
    :ets.insert(@table, {{self(), :lag}, 0})
    assert status.status == :running
    w = %{w | fault: {:watchdog, {:idle, lag}}}
    w = consumed(w)

    # The time the request took passed inside it, the devices' polls on the way waiting
    # for the clock's next advance, which delivers them.
    :ok = Manual.advance(w.manual, 0)
    tripped!(consumed(w))
  end

  defp injected({:stuck, size}, w) do
    :ok = Manual.advance(w.manual, w.poll)
    w = consumed(w)
    k = stuck(size, w)
    :sys.suspend(w.runner)
    :ok = Manual.advance(w.manual, k)
    :sys.resume(w.runner)
    w = %{w | floor: now(w)}

    case size do
      :small ->
        reach(:stuck_small, true)
        checked(consumed(w))

      :big ->
        w = %{w | fault: {:watchdog, {:device, "drive", w.idle + w.poll}}}
        tripped!(consumed(w))
    end
  end

  defp injected({:kill, device}, w) do
    [pid] = for {^device, pid} <- device_pids(w.runner), do: pid
    Process.exit(pid, :kill)
    w = %{w | fault: {:io, device, {:down, :killed}}, down: MapSet.put(w.down, device)}
    tripped!(until_tripped(w))
  end

  defp injected({:hang, device}, w) do
    [pid] = for {^device, pid} <- device_pids(w.runner), do: pid
    :sys.suspend(pid)

    w = %{
      w
      | fault: {:io, device, :timeout},
        down: MapSet.put(w.down, device),
        hung: Map.put(w.hung, device, now(w))
    }

    :ok = Manual.advance(w.manual, w.idle + 2 * w.poll + 2)
    tripped!(consumed(w))
  end

  defp injected({callback, device, how}, w) do
    Sim.fail(w.sims[device], callback, how)
    w = %{w | fault: {:io, device, cause(device, callback, how)}}
    fault_acted(callback, device, how, w)
  end

  defp fault_acted(:report, device, _how, w) do
    w = %{w | lossy: MapSet.put(w.lossy, device)}

    {name, {^device, address, _type}} =
      pick(for {_name, {^device, _, :bool}} = input <- Enum.sort(@inputs), do: input)

    {_at, was} = hd(w.timeline[name])
    value = 1 - was
    :ok = Sim.set(w.sims[device], address, value)
    tripped!(consumed(timed_value(w, name, value)))
  end

  defp fault_acted(_callback, _device, _how, w) do
    :ok = Manual.advance(w.manual, w.poll + 1)
    tripped!(consumed(w))
  end

  defp cause(_device, _callback, {:error, reason}), do: {:error, reason}

  defp cause(device, callback, :raise),
    do:
      {:raised,
       "the simulated device #{inspect(device)} raised in #{callback}, as fail/3 told it"}

  defp cause(_device, callback, :throw), do: {:thrown, {Sim, callback}}
  defp cause(_device, callback, :exit), do: {:exited, {Sim, callback}}
  defp cause(_device, _callback, {:value, [0], value}), do: {:bad_value, [0], value}
  defp cause(_device, _callback, {:value, address, _value}), do: {:unknown_address, address}

  # A step slow by about its task's watchdog, or the continuous task's over the round,
  # either side of it; one whose watchdog is far longer is slow by less than the idle
  # watchdog, so that its devices are heard throughout.
  defp slow_ms(task, w) do
    limits =
      for limit <- round_limit(continuous(w.config), w) ++ [watchdog(task, w.config)],
          limit <= 42,
          do: limit

    near(Enum.take(limits, pick([1, 1, 2])))
  end

  defp round_limit(nil, _w), do: []
  defp round_limit(task, w), do: [watchdog(task, w.config)]

  defp near([]), do: :rand.uniform(30)
  defp near(limits), do: max(1, pick(limits) + pick([-2, -1, 0, 1, 2, 3]))

  defp stuck(:small, w), do: :rand.uniform(w.idle - 1)
  defp stuck(:big, w), do: w.idle + w.poll + :rand.uniform(20)

  # A slow task's step is run within its interval, the walk moving the clock on until it is.
  defp wait_for_slow(_w, task, 0), do: flunk("the slow #{task} never ran")

  defp wait_for_slow(w, task, n) do
    case :ets.lookup(@table, {self(), :slow, task}) do
      [] ->
        w

      [_] when w.status == :tripped ->
        :ets.delete(@table, {self(), :slow, task})
        w

      [_] ->
        target = now(w) + 1
        :ok = Manual.advance(w.manual, 1)
        wait_for_slow(missed(consumed(w), target), task, n - 1)
    end
  end

  # The fault tripped the runner for the reason the watchdogs and the faults' rules give.
  defp tripped!(w) do
    assert w.status == :tripped, "#{inspect(w.fault)} did not trip the runner"
    assert w.fault == nil
    checked(w)
  end

  defp until_tripped(%{status: :tripped} = w), do: w

  defp until_tripped(w) do
    receive do
      {:walked, runner, record} when runner == w.runner -> until_tripped(record(w, record))
      {Runner, runner, event} when runner == w.runner -> until_tripped(event(w, event))
    after
      5000 -> flunk("no trip came")
    end
  end

  # ---- the model's stream ----------------------------------------------------------------

  # Every message the runner has sent: a :sys call answered after them marks the end.
  defp consumed(w) do
    :sys.get_state(w.runner)
    drained(w)
  end

  defp drained(w) do
    receive do
      {:walked, runner, record} when runner == w.runner -> drained(record(w, record))
      {Runner, runner, event} when runner == w.runner -> drained(event(w, event))
    after
      0 -> w
    end
  end

  defp logged(w, entry), do: %{w | log: [entry | w.log]}

  # A round begins: the runner gave the core its elapsed time and inputs.
  defp record(w, {:steps, elapsed, inputs, at} = record) do
    assert w.status == :running, "a round ran while tripped: #{inspect(record)}"
    assert w.round == nil
    w = logged(w, record)
    kind = round_kind(w, inputs)
    timed!(w, kind, elapsed, at)
    inputs!(w, inputs, at)
    {rt, steps} = Runtime.cycle_steps(w.rt, elapsed, inputs)
    {cycled, outputs, events} = Runtime.cycle(w.rt, elapsed, inputs)
    reach(:"round_#{kind}", true)
    reach({:trigger_round, w.doing || :poll}, kind == :trigger)

    %{
      w
      | logical: w.logical + elapsed,
        begun: w.begun + 1,
        round: %{
          at: at,
          rt: rt,
          steps: steps,
          ran: [],
          seen: [],
          took: 0,
          times: [],
          cycled: cycled,
          outputs: outputs,
          expected: events,
          trip: nil
        }
    }
  end

  defp record(w, {:step, task, ms} = record) do
    w = logged(w, record)
    %{steps: [{kind, ^task, _} = step | rest]} = round = w.round
    assert round.trip == nil, "a step ran after #{inspect(round.trip)}"
    {rt, events} = Runtime.cycle_step(round.rt, step)
    limit = watchdog(task, w.config)
    trip = major(events) || task_trip(kind == :timed and ms > limit, task, ms, limit)

    %{
      w
      | longest: Map.update(w.longest, task, ms, &max(&1, ms)),
        round: %{
          round
          | rt: rt,
            steps: rest,
            ran: round.ran ++ events,
            took: round.took + ms,
            times: round.times ++ [{task, ms}],
            trip: trip
        }
    }
  end

  # M5-9, restated (decisions 153 and 160): a step whose run met a major fault trips at its
  # end, for the first, before any later step of its round and before a watchdog.
  defp major(events) do
    Enum.find(events, fn
      {:fault, _task, _instance, %Logex.Fault{severity: :major}} -> true
      _event -> false
    end)
  end

  defp task_trip(true, task, ms, limit), do: {:watchdog, {:task, task, ms, limit}}
  defp task_trip(false, _task, _ms, _limit), do: nil

  # The round's events as the runner published them, the steps' and then its own; and
  # every other event, between rounds.
  defp event(%{round: round} = w, {:round, now, outputs} = event) when round != nil do
    w = logged(w, event)
    reach(:round, true)
    assert round.seen == round.expected
    assert now == w.logical
    assert outputs == round.outputs
    round_ended(w, outputs)
  end

  defp event(%{round: round} = w, {:trip, reason} = event) when round != nil do
    w = logged(w, event)
    assert round.seen == round.ran
    expected = round.trip || ended_trip(round.steps, w, round)
    assert reason == expected, "tripped #{inspect(reason)}, the rules give #{inspect(expected)}"
    reach(:trip, true)
    reach(trip_kind(reason), true)
    w = all_steps(round.steps, w, round.took)
    tripped(%{w | rt: round.rt, round: nil, fault: nil}, reason)
  end

  defp event(%{round: round} = w, event) when round != nil do
    w = logged(w, event)
    reach(elem(event, 0), true)
    %{w | round: %{round | seen: round.seen ++ [event]}}
  end

  defp event(w, {:trip, reason} = event) do
    w = logged(w, event)
    assert reason == w.fault, "tripped #{inspect(reason)}, the fault was #{inspect(w.fault)}"
    reach(:trip, true)
    reach(trip_kind(reason), true)
    tripped(%{w | fault: nil}, reason)
  end

  defp event(w, {:restart, mode} = event) do
    w = logged(w, event)
    reach(:restart, true)
    rt = Runtime.restart(w.rt, mode)

    %{
      w
      | rt: rt,
        status: :running,
        trip: nil,
        first: true,
        floor: nil,
        down: MapSet.new(),
        hung: %{},
        zeroed: %{},
        logic: logic_values(w.config, rt)
    }
  end

  defp event(w, {:edit, _step, _report} = event) do
    w = logged(w, event)
    reach(:edit, true)
    assert [^event | rest] = w.expect
    %{w | expect: rest}
  end

  defp event(_w, event), do: flunk("an event outside a round: #{inspect(event)}")

  # A trip after every step of a round ran: the continuous task's watchdog over the round,
  # or a device's fault as the round's outputs were written.
  defp ended_trip([], w, round), do: round_trip(w, round) || w.fault
  defp ended_trip(_steps, _w, _round), do: nil

  defp all_steps([], w, took), do: %{w | longest: continuous_ran(w, took)}
  defp all_steps(_steps, w, _took), do: w

  defp tripped(w, reason) do
    written =
      Map.new(w.sims, fn {name, _sim} ->
        {name, zeroed_unless_down(MapSet.member?(w.down, name), name, w)}
      end)

    %{w | status: :tripped, trip: reason, written: written}
  end

  defp zeroed_unless_down(true, name, w), do: Map.get(w.written, name)

  defp zeroed_unless_down(false, name, _w),
    do: Map.new(Map.fetch!(@outputs, name), fn {address, _} -> {address, 0} end)

  defp trip_kind({:fault, _task, _instance, %Logex.Fault{kind: kind}}), do: {:trip, kind}
  defp trip_kind({:watchdog, {kind, _, _, _, _}}), do: {:trip, kind}
  defp trip_kind({:watchdog, {kind, _, _, _}}), do: {:trip, kind}
  defp trip_kind({:watchdog, {kind, _, _}}), do: {:trip, kind}
  defp trip_kind({:watchdog, {kind, _}}), do: {:trip, kind}
  defp trip_kind({:io, _device, cause}) when is_atom(cause), do: {:trip, cause}
  defp trip_kind({:io, _device, cause}), do: {:trip, elem(cause, 0)}

  # A round that ran whole: the resource cycle/3 gives, its outputs written to every device
  # that is up, and the logic's triggers sampled for the next.
  defp round_ended(w, outputs) do
    round = w.round
    assert round.steps == [], "a round ended with steps left: #{inspect(round.steps)}"
    assert round.trip == nil, "no trip came where one was due: #{inspect(round.trip)}"
    assert round_trip(w, round) == nil, "no trip came where the round outlasted its watchdog"
    assert round.rt == round.cycled
    {logic, changed} = logic_changed(w, round.cycled)
    reach(:logic_round, changed)

    written =
      Map.new(@outputs, fn {device, points} ->
        {device, Map.new(points, fn {address, global} -> {address, outputs[global]} end)}
      end)

    %{
      w
      | rt: round.cycled,
        round: nil,
        rounds: w.rounds + 1,
        outputs: outputs,
        written: written,
        first: false,
        floor: nil,
        logic: logic,
        last: %{at: round.at, took: round.took, again: changed},
        longest: continuous_ran(w, round.took)
    }
  end

  defp round_trip(w, round), do: round_over(continuous(w.config), round, w)

  defp round_over(nil, _round, _w), do: nil

  defp round_over(task, round, w),
    do: over(round.took > watchdog(task, w.config), task, round, w)

  defp over(false, _task, _round, _w), do: nil

  defp over(true, task, round, w),
    do: {:watchdog, {:round, task, round.took, watchdog(task, w.config), round.times}}

  defp continuous_ran(w, took) do
    case continuous(w.config) do
      nil -> w.longest
      task -> Map.update(w.longest, task, took, &max(&1, took))
    end
  end

  # ---- the rules restated ----------------------------------------------------------------

  defp untimed?(%Configuration{tasks: tasks, instances: instances}) do
    timed = for %Configuration.Task{continuous: false, name: name} <- tasks, do: name
    Enum.any?(instances, &(&1.task not in timed))
  end

  defp continuous(config), do: continuous(untimed?(config), config)
  defp continuous(false, _config), do: nil

  defp continuous(true, config),
    do: Enum.find_value(config.tasks, :none, &(&1.continuous && &1.name))

  defp watchdog(:none, _config), do: 500

  defp watchdog(task, config),
    do: Configuration.watchdog(Enum.find(config.tasks, &(&1.name == task)))

  defp longest(longest, config),
    do:
      Map.merge(
        Map.new(Enum.map(config.tasks, & &1.name) ++ List.wrap(continuous(config)), &{&1, 0}),
        longest
      )

  defp triggers(config),
    do: for(%{single: single} <- config.tasks, Map.has_key?(@inputs, single || ""), do: single)

  defp logic_values(config, rt),
    do:
      Map.new(
        for(
          %{single: single} <- config.tasks,
          single != nil,
          not Map.has_key?(@inputs, single),
          do: {single, Runtime.get!(rt, single)}
        )
      )

  defp logic_changed(w, rt) do
    now = Map.new(w.logic, fn {name, _} -> {name, Runtime.get!(rt, name)} end)
    {now, now != w.logic}
  end

  # A round is the first after a start or a restart, a trigger's (a change of an event
  # task's trigger, from its device or a force, at once), or the schedule's.
  defp round_kind(%{first: true}, _inputs), do: :first

  defp round_kind(w, inputs) do
    changed =
      Enum.any?(triggers(w.config), fn name ->
        Map.has_key?(inputs, name) and inputs[name] != Runtime.get!(w.rt, name)
      end)

    (changed && :trigger) || :scheduled
  end

  defp timed!(_w, :first, elapsed, _at), do: assert(elapsed == 0)

  defp timed!(w, kind, elapsed, at) do
    assert elapsed == at - w.last.at, "a round's elapsed time is the time since the last"
    scheduled!(kind, w, at)
  end

  defp scheduled!(:trigger, _w, _at), do: :ok

  defp scheduled!(:scheduled, w, at),
    do: assert(at == next_at(w), "a round at #{at}, the schedule's at #{inspect(next_at(w))}")

  # When the next scheduled round comes: back to back while untimed programs exist or
  # logic changed a trigger (decisions 122 and 123), else the next periodic due time; never
  # before the last round ended, nor before a step it waited behind.
  defp next_at(%{last: last} = w) do
    again = untimed?(w.config) or last.again
    gap = earliest(back_to_back(again, last.took), due_in(Runtime.next_due_in(w.rt)))
    planned(gap, last, w.floor)
  end

  defp back_to_back(false, _took), do: nil
  defp back_to_back(true, took), do: max(took, 1)

  defp due_in(:infinity), do: nil
  defp due_in(ms), do: ms

  defp earliest(nil, other), do: other
  defp earliest(one, nil), do: one
  defp earliest(one, other), do: min(one, other)

  defp planned(nil, _last, _floor), do: nil
  defp planned(gap, last, floor), do: max(last.at + max(gap, last.took), floor || 0)

  # After the clock moved, no scheduled round is left owed up to the advance's target:
  # one due later, after time passed inside a step, waits for the next advance.
  defp missed(%{status: :running, last: last} = w, target) when last != nil do
    at = next_at(w)
    assert at == nil or at > target, "a round due at #{at} had not come by #{target}"
    w
  end

  defp missed(w, _target), do: w

  # Each input point as the round reads it: a force's value, exactly; a reporting
  # device's as it is now; and a read device's as it was within two poll periods, and the
  # time passed inside steps while it was read, of now.
  defp inputs!(w, inputs, at) do
    for {name, value} <- w.forces, do: assert(inputs[name] == value)

    passes = for {_key, pass} <- :ets.match_object(@table, {{self(), :pass, :_}, :_}), do: pass

    for {name, {device, _address, _type}} <- @inputs, not Map.has_key?(w.forces, name) do
      value = Map.get(inputs, name, Runtime.get!(w.rt, name))
      to = min(at, Map.get(w.hung, device, at))
      held = held(w.timeline[name], to - window(w, device, passes, to), to) ++ unforcing(w, name)
      assert value in held, "#{name} read #{value} at #{at}, held #{inspect(held)}"
    end
  end

  # Each trigger an unforce of all changes is its own round, reading those after it as
  # they were, forced (decision 138).
  defp unforcing(w, name), do: List.wrap(w.unforcing[name])

  # A start's and a restart's first round reads every device as it is then (decision 142).
  defp window(%{first: true}, _device, _passes, _to), do: 0

  defp window(w, device, passes, to),
    do: reported(w.reports[device] and not MapSet.member?(w.lossy, device), w, passes, to)

  # A read device's last read is within a poll period, or two where a read failed, of
  # now, and the time passed inside steps while it was read: each pass that ended within
  # that window held its polls back for as long as it passed, which widens the window in
  # turn.
  defp reported(true, _w, _passes, _to), do: 0
  defp reported(false, w, passes, to), do: allowed(2 * w.poll + 1, 2 * w.poll + 1, passes, to)

  defp allowed(window, read, passes, to) do
    passed = for {at, ms} <- passes, at + ms > to - window, reduce: 0, do: (sum -> sum + ms)
    widened(read + passed, window, read, passes, to)
  end

  defp widened(window, window, _read, _passes, _to), do: window
  defp widened(wider, _window, read, passes, to), do: allowed(wider, read, passes, to)

  defp held(timeline, from, to) do
    {within, before} = Enum.split_while(timeline, fn {at, _} -> at > from end)
    {_at, then} = List.first(before, {0, 0})
    [then | for({at, value} <- within, at <= to, do: value)]
  end

  # ---- the checks after every step -------------------------------------------------------

  # A round owed is run before a host's call, which would otherwise wait for the share's
  # slot (decision 131).
  defp settled(%{status: :running, last: last} = w) when last != nil do
    owed(untimed?(w.config) and next_at(w) <= now(w), w)
  end

  defp settled(w), do: w

  defp owed(false, w), do: w

  defp owed(true, w) do
    :ok = Manual.advance(w.manual, 0)
    settled(consumed(w))
  end

  defp checked(w) do
    w = settled(w)
    assert w.round == nil
    assert w.expect == []
    status = Runner.status(w.runner)

    assert Map.take(status, [:status, :trip, :rounds, :now, :overlaps, :forces, :edit]) == %{
             status: w.status,
             trip: w.trip,
             rounds: w.rounds,
             now: w.logical,
             overlaps: Runtime.overlaps(w.rt),
             forces: w.forces,
             edit: w.edit && ConfigEdit.stage(w.edit)
           }

    assert status.runs ==
             Map.new(w.longest, fn {task, ms} -> {task, {ms, watchdog(task, w.config)}} end)

    for path <- @paths, do: assert(Runner.get(w.runner, path) == Runtime.get(w.rt, path))

    for {name, sim} <- w.sims, Map.has_key?(w.written, name) do
      assert Sim.outputs(sim) == w.written[name], "#{name}'s outputs"
    end

    zeroed_once(w)
  end

  # Every output written 0 once at a trip, and nothing after it until a restart.
  defp zeroed_once(%{status: :tripped} = w) do
    counts = Map.new(w.sims, fn {name, sim} -> {name, length(Sim.writes(sim))} end)

    for {name, count} <- w.zeroed do
      assert counts[name] == count, "#{name} was written while tripped"
    end

    %{w | zeroed: Map.merge(counts, w.zeroed)}
  end

  defp zeroed_once(w), do: w

  defp reach(name, true),
    do: Process.put(:runner_reach, MapSet.put(Process.get(:runner_reach), name))

  defp reach(_name, _false), do: :ok
end
