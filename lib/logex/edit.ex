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
    starts it.

  A timer is state like any other here: a kept timer keeps every member, `.pre` included.

  **Held outputs** (decision 20, fix F4). A var_output of either program that the program
  stopped drove, writing it through an instruction's write operand (an `ons` storage bit
  included), and that the program started does not drive as a var_output (it removes it,
  makes it another section, or writes it no more), holds its value, as the conventional
  family's outputs do, and the host holds its point. Every step reports it with the value
  the point holds:
  - for an output the program that runs next still shows, a var_output no logic of it
    writes, the state's value, which that program shows at every scan;
  - for one it does not show, the value the point last received. The edit learns it from
    the state at a step taken while the program it stops is the one that last scanned
    (`Logex.Instance`'s `switched` is false), with no restart since (`first` is false), and
    keeps it in its record of the instance, so it never re-reads a value that a restart
    cleared or that logic writing the tag as a var changed since. An output whose value
    it has not learnt is not reported.

  Test, its forecast and assemble report the outputs the original drove and the candidate
  does not; untest, and cancel after an untest, report the reverse.

  **Assemble** (from test) and **cancel** (after an untest) are not switches: each prunes
  the state to the tags of the program it keeps and reports its held outputs. Cancel from
  accept changes nothing and reports `[]`.

  **The report** is a list of `{kind, name, detail}`, sorted, with at most one entry per
  kind and name. The kinds are an open set, which a host must tolerate:

  | Kind | Detail | Given by |
  |---|---|---|
  | `:added` | the initial value it started at | a switch |
  | `:input` | the value it reads now: the host sends its real value before the next scan | a switch |
  | `:unread` | the value it holds, 0 if the state lacks it: the host stops sending it | a switch |
  | `:initial_changed` | `{old, new}`, the two initial values; the running value is kept | a switch |
  | `:held` | the value the output's point holds | every step |
  | `:pruned` | the value it had | assemble, cancel |

  The writes a report lists, `:added`, `:input` and `:pruned`, applied to the state before
  its step, give the state after it, but for `switched`, which a switch sets. The other
  kinds state facts.

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
  edit accepted against a program the state is not running (one that has not scanned,
  started or restarted it since another program last scanned it), and an edit built or
  changed by hand. A plain swap is a scan of the new program, so the program it swaps in
  is then the one the state is running.
  """

  alias Logex.{Compiler, Declarations, Diagnostic, FbType, Instance, Program, Runtime, Tag}

  @enforce_keys [:original, :candidate, :stage, :plans, :record]
  defstruct [:original, :candidate, :stage, :plans, :record]

  @opaque t :: %__MODULE__{}

  # The edit's record of one instance (F5): `shown`, the value each held output's point
  # holds, as the edit has learnt it (F4).
  @record %{shown: %{}}

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
    %{test: plan(o, c, forward, watched), untest: plan(c, o, back, watched)}
  end

  defp facts(%Program{tags: tags} = program),
    do: %{
      tags: tags,
      initial: Program.initial_env(program),
      inputs: section(tags, :var_input),
      outputs: section(tags, :var_output),
      writes: writes(program)
    }

  defp section(tags, wanted),
    do: for({name, %Tag{section: ^wanted}} <- tags, into: %{}, do: {name, true})

  # One direction, from the program a switch stops to the one it starts, or a prune keeps.
  # `left` is the watched outputs the program stopped shows: what a switch taken while it
  # is the program that last scanned learns from the state.
  defp plan(from, to, held, watched),
    do: %{
      initial: to.initial,
      keep: to.tags,
      starts: for({name, tag} <- to.tags, do: {name, not is_map_key(from.tags, name), fit(tag)}),
      inputs: to.inputs,
      live: for(name <- Map.keys(to.inputs), not is_map_key(from.inputs, name), do: name),
      unread: for(name <- Map.keys(from.inputs), not is_map_key(to.inputs, name), do: name),
      held: held,
      shows: to.outputs,
      left: for(name <- Map.keys(watched), is_map_key(from.outputs, name), do: name),
      changed: changed(from, to)
    }

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

  # Decision 29: a bool or a dint both declare, of one type, whose initial value differs.
  defp changed(from, to),
    do:
      for(
        {name, %Tag{type: type}} <- to.tags,
        type in [:bool, :dint],
        {:ok, %Tag{type: ^type}} <- [Map.fetch(from.tags, name)],
        Map.fetch!(from.initial, name) != Map.fetch!(to.initial, name),
        do: {name, Map.fetch!(from.initial, name), Map.fetch!(to.initial, name)}
      )

  defp fit(%Tag{type: %FbType{} = type}),
    do: {:members, Enum.sort(Map.keys(FbType.initial(type)))}

  defp fit(%Tag{type: type}), do: type

  # Every name a program writes through a write operand, an `ons` storage bit included:
  # one walk, into every group however deep, accumulating rather than copying.
  defp writes(%Program{rungs: rungs}) do
    signatures = Map.new(Compiler.instructions(), fn {_word, {symbol, sig}} -> {symbol, sig} end)
    Enum.reduce(rungs, %{}, fn {:rung, elements}, acc -> written(elements, acc, signatures) end)
  end

  defp written([], acc, _signatures), do: acc

  defp written([{:branches, legs} | rest], acc, signatures),
    do: written(rest, Enum.reduce(legs, acc, &written(&1, &2, signatures)), signatures)

  defp written([{symbol, _line, operands} | rest], acc, signatures),
    do: written(rest, wrote(Map.fetch!(signatures, symbol), operands, acc), signatures)

  defp wrote([{:write, _type} | signature], [{:name, _, name} | operands], acc),
    do: wrote(signature, operands, Map.put(acc, name, true))

  defp wrote([_slot | signature], [_operand | operands], acc), do: wrote(signature, operands, acc)
  defp wrote(_signature, _operands, acc), do: acc

  # ---- the per-instance half: a switch, between two scans, and a prune --------------------

  defp switch(plan, record, %Instance{env: env} = state, first_test?) do
    shown = learnt(record.shown, plan.left, state)

    started =
      for {name, added?, fit} <- plan.starts,
          starts?(Map.fetch(env, name), added?, fit, first_test?),
          do: name

    env = Map.merge(env, Map.take(plan.initial, started))
    {inputs, added} = Enum.split_with(started, &is_map_key(plan.inputs, &1))

    report =
      for(name <- added, do: {:added, name, Map.fetch!(env, name)}) ++
        for(name <- Enum.uniq(plan.live ++ inputs), do: {:input, name, Map.fetch!(env, name)}) ++
        for(name <- plan.unread, do: {:unread, name, Map.get(env, name, 0)}) ++
        for({name, old, new} <- plan.changed, do: {:initial_changed, name, {old, new}}) ++
        holding(plan, shown, env)

    {%{state | env: env, switched: true}, %{record | shown: shown}, Enum.sort(report)}
  end

  # Whether a switch starts a tag at its initial value: one the state lacks, always; and at
  # the first test, one the candidate adds, over what a plain swap left, or one whose value
  # does not fit its type (decision 26).
  defp starts?(:error, _added?, _fit, _first_test?), do: true
  defp starts?({:ok, _value}, _added?, _fit, false), do: false
  defp starts?({:ok, _value}, true, _fit, true), do: true
  defp starts?({:ok, value}, false, fit, true), do: not fits?(fit, value)

  # A timer fits by its member keys (decision 26). Within the contract the only map a
  # state can hold under a timer's name is a ton's, so until M2-5 adds a second function
  # block type, comparing the keys decides nothing that "is a map" would not.
  defp fits?({:members, keys}, %{} = timer), do: Enum.sort(Map.keys(timer)) == keys
  defp fits?({:members, _keys}, _not_a_timer), do: false
  defp fits?(type, value), do: Declarations.fits?(type, value)

  # What the points of `outputs`, the watched outputs of the program the step stops, hold,
  # learnt from the state while that program is the one that last scanned (F4). A restart
  # since that scan cleared what it showed, so it is forgotten; with no scan since the last
  # switch, no point has changed.
  defp learnt(shown, outputs, %Instance{switched: false, first: false, env: env}),
    do: Map.merge(shown, Map.new(outputs, &{&1, Map.get(env, &1, 0)}))

  defp learnt(shown, outputs, %Instance{switched: false, first: true}),
    do: Map.drop(shown, outputs)

  defp learnt(shown, _outputs, %Instance{switched: true}), do: shown

  # Each held output with the value its point holds: the state's, for one the program that
  # runs next still shows, since no logic of it writes the output; otherwise what the
  # point last received, if the edit has learnt it.
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
