defmodule Logex.Edit do
  @moduledoc """
  A staged edit of one program instance (OE-1, `docs/organisation.md` §4.9): a candidate
  program is accepted beside the running one, tested over the instance's state, untested,
  and assembled or cancelled, as the conventional family's online edit is. Every step is
  taken between two scans and returns a report.

      {:ok, edit, forecast}    = Logex.Edit.accept(motor, candidate, state)
      {edit, state, report}    = Logex.Edit.test(edit, state)      # the candidate runs
      {edit, state, report}    = Logex.Edit.untest(edit, state)    # the original again
      {edit, state, report}    = Logex.Edit.test(edit, state)
      {program, state, report} = Logex.Edit.assemble(edit, state)  # the candidate stays

  | Step | Taken from | The host then scans | The state |
  |---|---|---|---|
  | `accept/3` | — | the original | read for the forecast, unchanged |
  | `test/2` | accepted, untested | the candidate | switched to the candidate |
  | `untest/2` | testing | the original | switched back |
  | `assemble/2` | testing | the candidate; the edit ends | pruned to the candidate's tags |
  | `cancel/2` | accepted | the original; the edit ends | unchanged; the report is `[]` |
  | `cancel/2` | untested | the original; the edit ends | pruned to the original's tags |

  **Which program the host scans.** `running/1`, the candidate under test and the original
  otherwise, goes to `Logex.Runtime.call/4`, `scan/2,3`, `put_inputs/3` and `restart/3`
  until the edit ends, and after it the program `assemble/2` or `cancel/2` returned. A
  restart during an edit keeps its stage: the next switch starts again what the restart
  dropped. `Logex.Runtime`'s moduledoc gives the host's duties during an edit.

  **Accept** checks the two programs and the state, and changes nothing. It refuses a
  candidate that changes the type of a tag both programs declare, any `Logex.Tag` type
  inequality (a bool and a dint, a tag and a timer), as `{:error, diagnostics}` at stage
  `:edit`: every one, at the candidate's declaration line, in line order, and a tag
  declared from Elixir, which has no line, after them. A changed section or initial value
  is not a type change, and a warning in the candidate does not stop it. Its forecast is
  the report a test taken now would give; a test taken later reads the state as it is
  then. An `:edit` diagnostic has no file, since a `%Logex.Program{}` keeps none (fix F15).

  **A switch**, `test/2` or `untest/2`, moves the state from the program it stops to the
  one it starts. It prunes nothing, and never touches `now` or `first`, so no switch makes
  a scan first. Its rules:
  - *start what is missing:* a tag the program started declares and the state lacks
    starts at its initial value (`Logex.Program.initial_env/1`): one the candidate adds,
    or one that a restart during the edit dropped;
  - *start what the candidate adds:* at the first test only, every tag the candidate adds
    starts so too, over whatever a plain swap left under its name;
  - *restart what does not fit* (decision 26): at the first test only, so does every tag
    of the candidate whose value does not fit its declared type, by
    `Logex.Declarations.fits?/2`, or for a timer, by its member keys;
  - *inputs* (decision 22): a var_input of the program started that was not one of the
    program stopped (added, back at untest, or given the section) is reported as
    `:input`, and so is a var_input a rule above starts, since its value is the host's;
    a var_input of the program stopped that is not one of the program started (removed,
    or given another section) is reported as `:unread`. A section change keeps the value
    (decision 25);
  - *held outputs* (decision 20): below;
  - *initial values* (decision 29): a bool or dint both programs declare whose initial
    value differs keeps its running value, and the new one applies when a restart next
    starts it. It is not reported where a rule above started it, which `:added` reports,
    or `:input` for a var_input, nor where it is a var_input of the program started,
    whose value a restart keeps;
  - *one-shots* (decision 21): below;
  - *timers:* below.

  **Timers** (decision 23, fixes F1 and F6). A timer a rule above starts is at its initial
  value; one kept keeps every member but `.pre` and `last`, which move by these rules, in
  order:
  - *`.pre`, undone first:* each switch records in the edit, for each timer either program
    declares, the `.pre` it left and the one it found. The edit's next switch first gives
    back the one found wherever `.pre` still equals the one left, so an untest gives back
    exactly the `.pre` its test found. Where logic has changed it since, the two rules
    below apply instead. A new edit's record starts empty, so it gives back no `.pre` an
    earlier edit's switch moved;
  - *`.pre`, a `ton` in both:* where both programs run a `ton` on the timer, a `.pre`
    still at the preset of the program stopped moves to that of the program started, and
    one that logic changed is kept;
  - *`.pre`, a `ton` stopped or restored:* a timer the program started runs no `ton` on
    keeps its `.pre` frozen, and one it runs that the program stopped did not takes its
    preset outright, so a `ton` removed and restored at a new preset gives the `.pre` a
    restart would;
  - *a resume undone* (fix F11): where this edit's last switch resumed a timer and no
    scan has run since (`switched`), a `last` still at `now` goes back to the one that
    switch found, so a test and an untest with no scan between leave the original's
    timers as they were. A resume an earlier edit's last switch made is not given back;
  - *resume:* a timer the program started runs, timing when it last ran (`.en` 1) and not
    run since (its `last` before `now`, which within the contract means the program
    stopped did not run it), resumes from the switch: its `last` becomes `now`, so the
    time no `ton` ran it is not caught up.

  Each move of `.pre` is reported as `:preset`. A `.pre` that stays, on a timer the
  program started runs, is reported as `:preset_kept` where it is not that program's
  preset. After a move of the `.pre` of a timer the program started runs, `:dn_drops` says
  that its `.dn`, now 1 with `.acc` below the new `.pre`, drops at the next scan with its
  rung true, unless at least `.pre` − `.acc` ms have passed by then; `:dn_rises` that its
  `.dn`, now 0 while timing with `.acc` at or past the new `.pre`, rises at that scan. No
  latch is added: `.dn` is `.acc` against `.pre`, as `ton` counts them.

  **One-shots** (decision 21, fixes F2, F3 and F7). No switch writes a storage bit: a bit
  armed by writing 1 would echo into any rung that reads it. A switch lists bits in the
  instance's `ons_blocked` instead, and the next scan blocks each one's `ons`, as a first
  scan blocks every `ons` (`Logex.Instance`): it passes no power, and still writes its
  bit. Against the program that last scanned, a switch lists each `ons` of the program it
  starts that is not in an identical rung there, line numbers ignored, or whose bit that
  program also writes through another instruction: an `ons` the edit adds, one whose rung
  it changes, and one whose bit may not hold the power the `ons` last received. An
  untouched `ons` is not listed, and keeps a real edge on the switch scan.
  - The program that last scanned is the one the switch stops where a scan has run since
    the last switch (`Logex.Instance`'s `switched` is false), and otherwise the one this
    edit recorded at that switch.
  - Where it is the program the switch starts, whose bits are as it left them, the switch
    lists none of that program's own, so a test and an untest with no scan between lose no
    real edge (F3).
  - Where the last switch was an earlier edit's, whose programs this edit does not know,
    the program the switch stops is taken for it, and every bit still listed that the
    program started has an `ons` on stays listed, so a second edit taken before any scan
    cannot make a one-shot fire (F2). At worst a real edge is lost.

  Each listed bit is reported as `:ons_blocked`, with its value, which the switch leaves
  alone.

  **Held outputs** (decision 20, fix F4). A var_output of either program that the program
  stopped drove, writing it through an instruction's write operand (an `ons` storage bit
  included), and that the program started does not drive as a var_output (it removes it,
  makes it another section, or writes it no more), holds its value, as the conventional
  family's outputs do, and the host holds its point. Every step reports it with a value:
  - for an output the program that runs next still shows, a var_output no logic of it
    writes, the state's value, which that program's next scan gives the host, and which
    can differ from what the point holds until that scan: after a restart, or where the
    program stopped wrote the tag as a var;
  - for one it does not show, the value the point last received. The edit learns it from
    the state at a step taken while the program it stops is the one that last scanned
    (`Logex.Instance`'s `switched` is false), with no restart since (`first` is false), and
    keeps it in its record of the instance, so it never re-reads a value that a restart
    cleared or that logic writing the tag as a var changed since. An output whose value
    it has not learnt is not reported.

  Test, its forecast and assemble report the outputs the original drove and the candidate
  does not; untest, and cancel after an untest, report the reverse.

  **Assemble** (from test) and **cancel** (after an untest) are not switches: each prunes
  the state to the tags of the program it keeps and reports its held outputs, and blocks
  no one-shot, so one the last switch blocked stays blocked for the next scan. Cancel from
  accept changes nothing and reports `[]`.

  **The report** is a list of `{kind, name, detail}`, sorted, with at most one entry per
  kind and name. The kinds are an open set, which a host must tolerate:

  | Kind | Detail | Given by |
  |---|---|---|
  | `:added` | the initial value it started at | a switch |
  | `:input` | the value it reads now: the host sends its real value before the next scan | a switch |
  | `:unread` | the value it holds, 0 if the state lacks it: the host stops sending it | a switch |
  | `:initial_changed` | `{old, new}`, the two initial values; the running value is kept | a switch |
  | `:preset` | `{from, to}`, the move of the timer's `.pre` | a switch |
  | `:preset_kept` | `{pre, preset}`: `.pre` kept, not the preset of the `ton` that runs it | a switch |
  | `:dn_drops`, `:dn_rises` | `{acc, pre}`, as `ton` counts them, a negative `.acc` as 0 | a switch |
  | `:resumed` | the milliseconds not caught up: `last` moves on by that many, to `now` | a switch |
  | `:resume_undone` | the milliseconds of the resume this edit's last switch made: `last` moves back by that many | a switch |
  | `:ons_blocked` | the storage bit's value, unchanged: its `ons` passes no power at the next scan | a switch |
  | `:held` | for an output the next program shows, the state's value, what its next scan gives, which can differ from what the point holds until then; otherwise the value the point last received | every step |
  | `:pruned` | the value it had | assemble, cancel |

  The writes a report lists, `:added`, `:input`, `:preset`, `:resume_undone`, `:resumed`
  and `:pruned`, applied to the state before its step, give the state after it, with the
  bits of its `:ons_blocked` entries, in order, as the block list a switch leaves, and
  `switched`, which a switch sets. The other kinds state facts and forecasts.

  **One edit per instance** (fix F5). At accept the edit builds two plans, original to
  candidate and back, from the two programs alone, so a plan cannot go stale; a switch and
  a prune are each a function of one plan, the edit's record of one instance, and its
  state. OE-2's configuration edit builds the plans once per program type and calls those
  once per instance; here each instance takes its own edit. A report names a tag.

  **Host mistakes** raise `ArgumentError`, each with a message a test pins: something
  other than a program at accept, with the runtime's own message; a candidate with
  another name than the running program's (two unnamed programs count as one name);
  something other than an edit; a state that is not the running program's, with the
  runtime's own messages; and a step taken at the wrong stage. A step checks the edit,
  then the state, then the stage. Outside the contract, and not detected until OE-2's
  configuration carries a generation: scanning the program the edit is not running, two
  edits of one instance at once, a step on an edit that has ended or been superseded, an
  edit accepted against a program the state is not running, and an edit built or changed
  by hand. The program the state is running is the one the last of these left it with:
  `Logex.Runtime.instance/1`, `Logex.Runtime.restart/3`, a scan, or this module's
  `assemble/2` or `cancel/2`. A plain swap is a scan of the new program, so the program
  it swaps in is then the one the state is running; a test and an assemble at one
  boundary leave it running the candidate, so another edit may be accepted against the
  candidate before any scan (F2), and none against the original.
  """

  alias Logex.{Compiler, Declarations, Diagnostic, FbType, Instance, Program, Runtime, Tag}

  @enforce_keys [:original, :candidate, :stage, :plans, :record]
  defstruct [:original, :candidate, :stage, :plans, :record]

  @opaque t :: %__MODULE__{}

  # The edit's record of one instance (F5): `shown`, the value each held output's point
  # holds, as the edit has learnt it (F4); `pre`, for each timer, the `.pre` the last
  # switch left and the one it found (F1), and the `last` it found where it resumed the
  # timer, nil otherwise (F11), `{left, found, last}`; and `scanned`, nil until the edit's
  # first switch, then `{side, pending}`: which of its two programs, `:original` or
  # `:candidate`, left the storage bits, and the bits still blocked against it from an
  # earlier edit (F2, F3).
  @record %{shown: %{}, pre: %{}, scanned: nil}

  @doc """
  Accepts `candidate` beside `running`, the program `state` is an instance of:
  `{:ok, edit, forecast}`, the forecast being the report a test taken now would give, or
  `{:error, diagnostics}` when the candidate changes a tag's type. Nothing is changed.
  """
  def accept(running, candidate, state) do
    program!(running)
    program!(candidate)
    named!(running, candidate)
    accepted(retyped(running, candidate), running, candidate, checked(running, state))
  end

  defp accepted([], running, candidate, state) do
    plans = plans(running, candidate)

    edit = %__MODULE__{
      original: running,
      candidate: candidate,
      stage: :accepted,
      plans: plans,
      record: @record
    }

    {_state, _record, forecast} = switch(plans.test, @record, state, true)
    {:ok, edit, forecast}
  end

  defp accepted(diagnostics, _running, _candidate, _state), do: {:error, diagnostics}

  @doc "Runs the candidate over the state, from accept or after an untest."
  def test(edit, state) do
    edit = edit!(edit)
    tested(edit, state!(edit, state))
  end

  defp tested(%__MODULE__{stage: stage} = edit, state) when stage in [:accepted, :untested] do
    {state, record, report} = switch(edit.plans.test, edit.record, state, first_test?(stage))
    {%{edit | stage: :testing, record: record}, state, report}
  end

  defp tested(edit, _state), do: stage!(edit, "test", "accepted or untested")

  defp first_test?(:accepted), do: true
  defp first_test?(:untested), do: false

  @doc "Runs the original again over the same state, from test."
  def untest(edit, state) do
    edit = edit!(edit)
    untested(edit, state!(edit, state))
  end

  defp untested(%__MODULE__{stage: :testing} = edit, state) do
    {state, record, report} = switch(edit.plans.untest, edit.record, state, false)
    {%{edit | stage: :untested, record: record}, state, report}
  end

  defp untested(edit, _state), do: stage!(edit, "untest", "under test")

  @doc """
  Keeps the candidate, from test, and ends the edit: what only the original declares is
  pruned. Returns the candidate, the program the host scans from now on.
  """
  def assemble(edit, state) do
    edit = edit!(edit)
    assembled(edit, state!(edit, state))
  end

  defp assembled(%__MODULE__{stage: :testing} = edit, state) do
    {state, report} = prune(edit.plans.test, edit.record, state)
    {edit.candidate, state, report}
  end

  defp assembled(edit, _state), do: stage!(edit, "assemble", "under test")

  @doc """
  Keeps the original and ends the edit: from accept, with nothing changed, or after an
  untest, when what only the candidate declares is pruned. Returns the original.
  """
  def cancel(edit, state) do
    edit = edit!(edit)
    cancelled(edit, state!(edit, state))
  end

  defp cancelled(%__MODULE__{stage: :accepted} = edit, state), do: {edit.original, state, []}

  defp cancelled(%__MODULE__{stage: :untested} = edit, state) do
    {state, report} = prune(edit.plans.untest, edit.record, state)
    {edit.original, state, report}
  end

  defp cancelled(edit, _state), do: stage!(edit, "cancel", "accepted or untested")

  @doc "The program the host scans now: the candidate under test, the original otherwise."
  def running(edit), do: run(edit!(edit))

  defp run(%__MODULE__{stage: :testing, candidate: candidate}), do: candidate
  defp run(%__MODULE__{original: original}), do: original

  @doc "Where the edit stands: `:accepted`, `:testing` or `:untested`."
  def stage(edit), do: edit!(edit).stage

  # ---- host mistakes ----------------------------------------------------------------------

  # The runtime's own message for a non-program.
  defp program!(%Program{tags: tags, rungs: rungs}) when is_map(tags) and is_list(rungs), do: :ok

  defp program!(other),
    do:
      raise(
        ArgumentError,
        "expected a %Logex.Program{} from Logex.compile/2, got: #{inspect(other)}"
      )

  defp named!(%Program{name: name}, %Program{name: name}), do: :ok

  defp named!(%Program{name: running}, %Program{name: candidate}),
    do:
      raise(
        ArgumentError,
        "the candidate is #{named(candidate)}, but the running program is #{named(running)}: " <>
          "an edit keeps the program's name"
      )

  defp named(nil), do: "an unnamed program"
  defp named(name), do: "`#{name}`"

  defp edit!(%__MODULE__{} = edit), do: edit

  defp edit!(other),
    do:
      raise(
        ArgumentError,
        "expected a %Logex.Edit{} from Logex.Edit.accept/3, got: #{inspect(other)}"
      )

  # The runtime's checks, and so its messages: put_inputs/3 with no inputs checks the
  # program and the state, and changes nothing.
  defp checked(program, state), do: Runtime.put_inputs(program, state, %{})

  defp state!(edit, state), do: checked(run(edit), state)

  defp stage!(%__MODULE__{stage: stage}, step, wanted),
    do: raise(ArgumentError, "#{step} takes an edit #{wanted}, but this one is #{shown(stage)}")

  defp shown(:testing), do: "under test"
  defp shown(stage), do: Atom.to_string(stage)

  # ---- accept: the two programs alone -----------------------------------------------------

  # §4.9: a tag's type, a function block's members included, changes only with a restart.
  # In line order, a tag declared from Elixir (line nil, after every number) last, by name.
  defp retyped(%Program{tags: running}, %Program{tags: candidate}) do
    retyped =
      for {name, %Tag{type: type, line: line}} <- candidate,
          {:ok, %Tag{type: was}} <- [Map.fetch(running, name)],
          was != type,
          do: {{line, name}, retyped(name, line, was, type)}

    for {_at, diagnostic} <- Enum.sort_by(retyped, &elem(&1, 0)), do: diagnostic
  end

  defp retyped(name, line, was, type),
    do: %Diagnostic{
      stage: :edit,
      line: line,
      message:
        "`#{name}` is a #{word(was)} in the running program and a #{word(type)} in the " <>
          "candidate: a tag's type changes only with a restart"
    }

  defp word(%FbType{name: name}), do: name
  defp word(type), do: Atom.to_string(type)

  # The per-program half (F5): what each program declares and drives, read once, and a
  # plan for each direction. A switch then reads and writes only the state and the record,
  # so nothing a plan holds can go stale. Sets are maps to `true`, for `is_map_key/2`.
  defp plans(original, candidate) do
    o = facts(original)
    c = facts(candidate)
    forward = held(o, c)
    back = held(c, o)
    watched = Map.new(forward ++ back, &{&1, true})

    %{
      test: plan({:original, o}, c, forward, watched),
      untest: plan({:candidate, c}, o, back, watched)
    }
  end

  defp facts(%Program{tags: tags} = program) do
    {writes, ons} = rungs(program)

    %{
      tags: tags,
      initial: Program.initial_env(program),
      inputs: section(tags, :var_input),
      outputs: section(tags, :var_output),
      writes: writes,
      ons: ons,
      ons_rungs: Map.new(ons, fn {rung, _bits} -> {rung, true} end),
      ons_bits: for({_rung, bits} <- ons, bit <- bits, into: %{}, do: {bit, true}),
      timers: for({name, %Tag{type: %FbType{}} = tag} <- tags, into: %{}, do: {name, preset(tag)})
    }
  end

  defp section(tags, wanted),
    do: for({name, %Tag{section: ^wanted}} <- tags, into: %{}, do: {name, true})

  # The preset of the `ton` that runs a timer, which the compiler gives the timer as the
  # `pre` of its initial value (Logex.Compiler), or nil where no `ton` of the program runs
  # it, and its initial value is none.
  defp preset(%Tag{initial: %{"pre" => preset}}), do: preset
  defp preset(%Tag{initial: nil}), do: nil

  # One direction, from the program a switch stops to the one it starts, or a prune keeps.
  # `left` is the watched outputs the program stopped shows: what a switch taken while it
  # is the program that last scanned learns from the state. `stops` names the program
  # stopped, `:original` or `:candidate`, and `blocks` is the one-shots of the program
  # started to block where the program stopped is the one that last scanned.
  defp plan({stops, from}, to, held, watched),
    do: %{
      stops: stops,
      blocks: blocks(from, to),
      ons: to.ons_bits,
      initial: to.initial,
      keep: to.tags,
      starts: for({name, tag} <- to.tags, do: {name, not is_map_key(from.tags, name), fit(tag)}),
      inputs: to.inputs,
      live: for(name <- Map.keys(to.inputs), not is_map_key(from.inputs, name), do: name),
      unread: for(name <- Map.keys(from.inputs), not is_map_key(to.inputs, name), do: name),
      held: held,
      shows: to.outputs,
      left: for(name <- Map.keys(watched), is_map_key(from.outputs, name), do: name),
      changed: changed(from, to),
      timers: timers(from, to)
    }

  # Each timer either program declares, with the preset of the `ton` that runs it in the
  # program stopped and in the one started, nil for none: the `.pre` rules read no more.
  defp timers(from, to),
    do:
      for(
        name <- Map.keys(Map.merge(from.timers, to.timers)),
        do: {name, Map.get(from.timers, name), Map.get(to.timers, name)}
      )

  # Decision 20: a var_output of either program that `from` drove and `to` does not drive
  # as a var_output.
  defp held(from, to),
    do:
      Enum.sort(
        for name <- Map.keys(Map.merge(from.outputs, to.outputs)),
            is_map_key(from.writes, name),
            not drives?(to, name),
            do: name
      )

  defp drives?(facts, name),
    do: is_map_key(facts.outputs, name) and is_map_key(facts.writes, name)

  # Decision 29: a bool or a dint both declare, of one type, whose initial value differs,
  # and that is no var_input of `to`, since a restart keeps a var_input's value.
  defp changed(from, to),
    do:
      for(
        {name, %Tag{type: type}} <- to.tags,
        type in [:bool, :dint],
        not is_map_key(to.inputs, name),
        {:ok, %Tag{type: ^type}} <- [Map.fetch(from.tags, name)],
        Map.fetch!(from.initial, name) != Map.fetch!(to.initial, name),
        do: {name, Map.fetch!(from.initial, name), Map.fetch!(to.initial, name)}
      )

  defp fit(%Tag{type: %FbType{} = type}),
    do: {:members, Enum.sort(Map.keys(FbType.initial(type)))}

  defp fit(%Tag{type: type}), do: type

  # What a program's rungs write and where its one-shots are, in one walk, into every group
  # however deep, accumulating rather than copying: how many times each name is written
  # through a write operand, an `ons` storage bit included; and, for each rung that holds
  # an `ons`, the rung with its line numbers taken out, beside the storage bits of its
  # `ons`. A rung is stripped once and compared once, however many `ons` it holds.
  defp rungs(%Program{rungs: rungs}) do
    signatures = Map.new(Compiler.instructions(), fn {_word, {symbol, sig}} -> {symbol, sig} end)

    Enum.reduce(rungs, {%{}, []}, fn {:rung, elements}, {writes, ons} ->
      {writes, bits} = written(elements, {writes, []}, signatures)
      {writes, oned(bits, elements, ons)}
    end)
  end

  defp oned([], _elements, ons), do: ons
  defp oned(bits, elements, ons), do: [{stripped(elements), bits} | ons]

  defp written([], acc, _signatures), do: acc

  defp written([{:branches, legs} | rest], acc, signatures),
    do: written(rest, Enum.reduce(legs, acc, &written(&1, &2, signatures)), signatures)

  defp written([{:ons, _line, [{:name, _, bit}]} | rest], {writes, bits}, signatures),
    do: written(rest, {count(writes, bit), [bit | bits]}, signatures)

  defp written([{symbol, _line, operands} | rest], {writes, bits}, signatures),
    do: written(rest, {wrote(Map.fetch!(signatures, symbol), operands, writes), bits}, signatures)

  defp wrote([{:write, _type} | signature], [{:name, _, name} | operands], acc),
    do: wrote(signature, operands, count(acc, name))

  defp wrote([_slot | signature], [_operand | operands], acc), do: wrote(signature, operands, acc)
  defp wrote(_signature, _operands, acc), do: acc

  defp count(writes, name), do: Map.update(writes, name, 1, &(&1 + 1))

  # A rung as the text says it, line numbers taken out: a rung moved or renumbered is the
  # same rung (decision 21).
  defp stripped(elements), do: Enum.map(elements, &bare/1)

  defp bare({:branches, legs}), do: {:branches, Enum.map(legs, &stripped/1)}
  defp bare({symbol, _line, operands}), do: {symbol, Enum.map(operands, &operand/1)}

  defp operand({kind, _line, value}), do: {kind, value}

  # Decision 21 and fix F7: the storage bits of the `ons` of `to` that a switch from `from`,
  # the program that last scanned, blocks for one scan. Each is blocked unless `from` has
  # that `ons` in an identical rung, line numbers ignored, and writes its bit through
  # nothing else: an `ons` that `to` adds, one whose rung it changes, and one whose bit
  # `from` also writes through another instruction, which may leave the bit at a value
  # that is not the power the `ons` last received.
  defp blocks(from, to),
    do:
      for(
        {rung, bits} <- to.ons,
        same <- [is_map_key(from.ons_rungs, rung)],
        bit <- bits,
        not (same and Map.get(from.writes, bit) == 1),
        do: bit
      )

  # ---- the per-instance half: a switch, between two scans, and a prune --------------------

  defp switch(plan, record, %Instance{env: env, now: now} = state, first_test?) do
    shown = learnt(record.shown, plan.left, state)

    started =
      for {name, added?, fit} <- plan.starts,
          starts?(Map.fetch(env, name), added?, fit, first_test?),
          do: name

    fresh = Map.take(plan.initial, started)
    env = Map.merge(env, fresh)
    {inputs, added} = Enum.split_with(started, &is_map_key(plan.inputs, &1))
    scanned = scanned(record.scanned, state, plan)
    blocked = blocked(scanned, plan)

    report =
      for(name <- added, do: {:added, name, Map.fetch!(env, name)}) ++
        for(name <- Enum.uniq(plan.live ++ inputs), do: {:input, name, Map.fetch!(env, name)}) ++
        for(name <- plan.unread, do: {:unread, name, Map.get(env, name, 0)}) ++
        for(
          {name, old, new} <- plan.changed,
          not is_map_key(fresh, name),
          do: {:initial_changed, name, {old, new}}
        ) ++
        for(bit <- blocked, do: {:ons_blocked, bit, Map.fetch!(env, bit)}) ++
        holding(plan, shown, env)

    {env, timed, pre} =
      Enum.reduce(plan.timers, {env, [], %{}}, &timed(&1, record.pre, {now, state.switched}, &2))

    {%{state | env: env, switched: true, ons_blocked: blocked},
     %{record | shown: shown, pre: pre, scanned: scanned}, Enum.sort(timed ++ report)}
  end

  # Whether a switch starts a tag at its initial value: one the state lacks, always; and at
  # the first test, one the candidate adds, over what a plain swap left, or one whose value
  # does not fit its type (decision 26).
  defp starts?(:error, _added?, _fit, _first_test?), do: true
  defp starts?({:ok, _value}, _added?, _fit, false), do: false
  defp starts?({:ok, _value}, true, _fit, true), do: true
  defp starts?({:ok, value}, false, fit, true), do: not fits?(fit, value)

  # ---- one-shots across a switch (decision 21; fixes F2, F3 and F7) ----------------------

  # Which program left the storage bits, the one each `ons` would read them from, and the
  # bits still blocked against it. A scan since the last switch (`switched` false): the
  # program stopped, with nothing pending, since a scan empties the list. No scan since,
  # and that switch this edit's: what it recorded, so a test and an untest with no scan
  # between lose no real edge (F3). No scan since an earlier edit's switch, whose program
  # this edit cannot know: the program stopped is taken for it, with the earlier edit's
  # blocks still pending (F2).
  defp scanned(_known, %Instance{switched: false}, plan), do: {plan.stops, []}
  defp scanned(nil, %Instance{ons_blocked: pending}, plan), do: {plan.stops, pending}
  defp scanned(known, _state, _plan), do: known

  # The block list a switch leaves: its plan's blocks where the program stopped left the
  # bits, none where the program started did, since its bits are then as it left them; and
  # every pending bit the program started still has an `ons` on. Sorted, each bit once.
  defp blocked({last, pending}, plan),
    do:
      Enum.sort(
        Enum.uniq(own(last, plan) ++ for(bit <- pending, is_map_key(plan.ons, bit), do: bit))
      )

  defp own(stops, %{stops: stops, blocks: blocks}), do: blocks
  defp own(_started, _plan), do: []

  # A timer fits by its member keys (decision 26): a map with none missing. A plain swap can
  # leave one that lacks some: where the program swapped out held a bool under the name,
  # a program that writes `t1.pre` and runs no `ton` on it leaves `%{"pre" => 40}`, which
  # the timer rules, reading `.acc`, `.dn` and `.en`, could not take.
  defp fits?({:members, keys}, %{} = timer), do: Enum.sort(Map.keys(timer)) == keys
  defp fits?({:members, _keys}, _not_a_timer), do: false
  defp fits?(type, value), do: Declarations.fits?(type, value)

  # ---- a timer across a switch (decision 23; fixes F1 and F6) -----------------------------

  # One timer either program declares, `from` and `to` the presets of the `ton`s that run
  # it in the program stopped and the one started, nil for none, taken after the start
  # rules, so one they started is at its initial value, where these rules move nothing.
  # A resume this edit's last switch made may be undone, its `.pre` moves, it may resume,
  # and the record keeps the `.pre` left, the one found, and the `last` a resume found.
  # A map a plain swap left with `.pre` but not every member is one no `ton` of either
  # program runs (below), so the rules that read the others never reach it.
  defp timed({name, _from, _to} = timer, undo, clock, {env, _report, _left} = acc),
    do: timer(Map.get(env, name), timer, Map.get(undo, name), clock, acc)

  defp timer(
         %{"pre" => pre} = value,
         {name, from, to},
         undo,
         {now, switched},
         {env, report, left}
       ) do
    {value, undone} = undone(value, undo, switched, now, name)
    target = target(undo, pre, from, to)
    {value, resumed, found} = resumed(to, %{value | "pre" => target}, name, now)

    {Map.put(env, name, value),
     moved(name, pre, target, to, value) ++ undone ++ resumed ++ report,
     Map.put(left, name, {target, pre, found})}
  end

  # No `.pre`: what a plain swap left under the name of a timer the candidate does not
  # declare, since the first test starts again every one of its own that does not fit: a
  # value of another type, or a map of only the members logic wrote. No `ton` of either
  # program runs it, or that program's scan would have made it a timer's whole map, and no
  # rule reads it.
  defp timer(_not_a_timer, _timer, _undo, _now, acc), do: acc

  # Where `.pre` goes. F1 first: still what this edit's last switch left, it goes back to
  # what that switch found. Otherwise, decision 23: a timer the program started runs no
  # `ton` on keeps its `.pre` frozen, and one it runs that the program stopped did not
  # takes its preset outright. And where both run one: a `.pre` still at the old preset
  # takes the new one, and one logic changed is kept, read when the switch is taken, not
  # at accept (decision 27).
  defp target({pre, found, _last}, pre, _from, _to), do: found
  defp target(_undo, pre, _from, nil), do: pre
  defp target(_undo, _pre, nil, to), do: to
  defp target(_undo, from, from, to), do: to
  defp target(_undo, pre, _from, _to), do: pre

  # What a switch reports of `.pre`: a move, with what it does to `.dn` where the program
  # started runs the timer; or, where `.pre` stays on a timer that program runs, a `.pre`
  # that is not its preset.
  defp moved(_name, pre, pre, nil, _timer), do: []
  defp moved(_name, pre, pre, pre, _timer), do: []
  defp moved(name, pre, pre, to, _timer), do: [{:preset_kept, name, {pre, to}}]

  defp moved(name, pre, target, to, timer),
    do: [{:preset, name, {pre, target}} | done(to, timer, name)]

  # F6: `.dn` is `.acc` against `.pre`, with no latch (docs/naming.md, `ton`), so after a
  # move it drops at the next scan with its rung true, unless `.pre` - `.acc` ms pass by
  # then, or rises at that scan, where it is timing. Each counted as `ton` counts it, a
  # negative `.acc` as 0. A moved `.pre` is never negative where the program started runs
  # the timer: a switch moves it to a preset, or back from one.
  defp done(nil, _timer, _name), do: []

  defp done(_to, %{"pre" => pre, "acc" => acc, "dn" => dn, "en" => en}, name),
    do: done(dn, en, max(acc, 0), pre, name)

  defp done(1, _en, acc, pre, name) when acc < pre, do: [{:dn_drops, name, {acc, pre}}]
  defp done(0, 1, acc, pre, name) when acc >= pre, do: [{:dn_rises, name, {acc, pre}}]
  defp done(_dn, _en, _acc, _pre, _name), do: []

  # A timer the program started runs, timing when it last ran and not run since: its `last`
  # is before `now`, which within the contract means the program stopped did not run it,
  # since every `ton` stamps `last` at every scan. It resumes from the switch, so the time
  # no `ton` ran it is not caught up (§4.9's Resume rule). The `last` it found where it
  # resumes is returned too, for the next switch to give back (F11).
  defp resumed(nil, timer, _name, _now), do: {timer, [], nil}

  defp resumed(_to, %{"en" => 1, "last" => last} = timer, name, now) when last < now,
    do: {%{timer | "last" => now}, [{:resumed, name, now - last}], last}

  defp resumed(_to, timer, _name, _now), do: {timer, [], nil}

  # A resume undone: where this edit's last switch resumed the timer and no scan has run
  # since (`switched`), its `last`, still that switch's `now`, goes back to the one it
  # found, so a test and an untest with no scan between leave the original's timers as
  # they were. The `last` found is in the edit's record, so an earlier edit's is unknown.
  defp undone(%{"last" => now} = timer, {_pre, _found, last}, true, now, name)
       when is_integer(last),
       do: {%{timer | "last" => last}, [{:resume_undone, name, now - last}]}

  defp undone(timer, _undo, _switched, _now, _name), do: {timer, []}

  # What the points of `outputs`, the watched outputs of the program the step stops, hold,
  # learnt from the state while that program is the one that last scanned (F4). A restart
  # since that scan cleared what it showed, so it is forgotten; with no scan since the last
  # switch, no point has changed.
  defp learnt(shown, outputs, %Instance{switched: false, first: false, env: env}),
    do: Map.merge(shown, Map.new(outputs, &{&1, Map.get(env, &1, 0)}))

  defp learnt(shown, outputs, %Instance{switched: false, first: true}),
    do: Map.drop(shown, outputs)

  defp learnt(shown, _outputs, %Instance{switched: true}), do: shown

  # Each held output with its value: for one the program that runs next still shows, the
  # state's, which that program's next scan gives the host, since no logic of it writes
  # the output, and which can differ from what the point holds until that scan; otherwise
  # what the point last received, if the edit has learnt it.
  defp holding(plan, shown, env),
    do:
      for(
        name <- plan.held,
        {:ok, value} <- [holds(name, plan.shows, shown, env)],
        do: {:held, name, value}
      )

  defp holds(name, shows, _shown, env) when is_map_key(shows, name),
    do: {:ok, Map.get(env, name, 0)}

  defp holds(name, _shows, shown, _env), do: Map.fetch(shown, name)

  # Assemble and cancel: the state pruned to the tags of the program kept, `to`, which ran
  # last, and its direction's held outputs. Nothing is learnt here: a held output the kept
  # program does not show is none of its outputs, so no scan since the switch changed its
  # point, and the record has the value.
  defp prune(plan, record, %Instance{env: env} = state) do
    {kept, gone} = Map.split_with(env, fn {name, _value} -> is_map_key(plan.keep, name) end)
    pruned = for {name, value} <- gone, do: {:pruned, name, value}
    {%{state | env: kept}, Enum.sort(holding(plan, record.shown, env) ++ pruned)}
  end
end
