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
  `:edit`: every one, at the candidate's declaration line, in line order, several members
  of one instance on its one line by path, and a tag declared from Elixir, which has no
  line, after them. A changed section or initial value is not a type change, and a
  warning in the candidate does not stop it. Its forecast is the report a test taken now
  would give; a test taken later reads the state as it is then. An `:edit` diagnostic
  cites the candidate's file, its `file`, which `Logex.compile_file/1` sets, and none for
  a candidate compiled from text (fix F15). A user function block's type, for the edit,
  is its name and its members' kinds (below).

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
  - *resume:* a timer the program started runs and the program stopped does not, timing
    when it last ran (`.en` 1, its `last` before `now`), resumes from the switch, where the
    program stopped is the one that last scanned (as for one-shots, below): its `last`
    becomes `now`, so the time no `ton` ran it is not caught up. Where the program started
    last scanned, a test and an untest with no scan between, it left the timer as it is.

  Each move of `.pre` is reported as `:preset`. A `.pre` that stays, on a timer the
  program started runs, is reported as `:preset_kept` where it is not that program's
  preset. After a move of the `.pre` of a timer the program started runs, `:dn_drops` says
  that its `.dn`, now 1 with `.acc` below the new `.pre`, drops at the next scan with its
  rung true, unless at least `.pre` − `.acc` ms have passed by then; `:dn_rises` that its
  `.dn`, now 0 while timing with `.acc` at or past the new `.pre`, rises at that scan. No
  latch is added: `.dn` is `.acc` against `.pre`, as `ton` counts them.

  **One-shots** (decision 21, fixes F2, F3 and F7). No switch writes a storage bit: a bit
  armed by writing 1 would echo into any rung that reads it. A switch lists bits in the
  instance's `ons_blocked` instead, and the next scan that runs each one's `ons` blocks it,
  as a first scan blocks every `ons` (`Logex.Instance`): it passes no power, and still
  writes its bit. At the top level that is the next scan; inside a function block's
  instance, the next whose `cal` runs its body (decision 32). Against the program that last
  scanned, a switch lists each `ons` of the program it starts that is not in an identical
  rung there, line numbers ignored, or whose bit that program also writes through another
  instruction: an `ons` the edit adds, one whose rung it changes, and one whose bit may not
  hold the power the `ons` last received. An untouched `ons` is not listed, and keeps a real
  edge on the switch scan.
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
  no one-shot, so one the last switch blocked stays blocked until a scan runs it. Cancel
  from accept changes nothing and reports `[]`.

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
  | `:ons_blocked` | the storage bit's value, unchanged: its `ons` passes no power at the next scan that runs it | a switch |
  | `:held` | for an output the next program shows, the state's value, what its next scan gives, which can differ from what the point holds until then; otherwise the value the point last received | every step |
  | `:pruned` | the value it had | assemble, cancel |

  The writes a report lists, `:added`, `:input`, `:preset`, `:resume_undone`, `:resumed`
  and `:pruned`, applied to the state before its step, give the state after it, with the
  bits of its `:ons_blocked` entries, in order, as the block list a switch leaves, and
  `switched`, which a switch sets. The other kinds state facts and forecasts.

  **Function blocks** (M2-5, decisions 31 and 32). An instance of a user function block
  keeps its type while the block keeps its name and every member both versions declare
  keeps its kind, at any depth: an edit may change the block's body, its members' order and
  roles, and add or drop members. A member whose kind changes is refused, cited by its path
  at the line of the instance that holds it: ``line 4: `p.edge` is a bool in the running
  program and a dint in the candidate: a member's type changes only with a restart``; a
  block renamed is a type change of the instance, ``… is an instance of `pulse` in the
  running program and an instance of `latch` in the candidate …``. Inside an instance both
  programs declare, a switch moves each member as it moves a tag, by its path, `p.count`:
  one the state lacks starts at its initial value; at the first test, one the candidate's
  version adds, or whose value does not fit, starts so too; a kept bool or dint whose
  initial value changed keeps its value and is reported; a timer meets the timer rules;
  and an instance it holds is moved in turn. A member only the stopped program's version
  declares is kept until assemble or cancel prunes it, by its path. This is the nested
  migration `docs/organisation.md` §4.9 gives M2-5.
  - An `ons` inside an instance a `cal` runs is a one-shot of the program, its bit named by
    its path, `p.edge`, its rung the chain of rungs from the program's rung that runs the
    outermost instance down to the body's rung that holds it; a change to any of them, a
    `cal`'s operands included, or the formals they fill, as when the block's inputs are
    reordered, blocks it. It stays blocked until a scan runs it (decision 32): a scan whose
    `cal` of its instance is false keeps it listed (`Logex.Instance`), and a switch taken
    after such a scan lists it again where the program it starts has that `ons`, as it
    does a block an earlier edit left pending (F2).
  - A timer inside an instance is resumed only where the program started runs it and the
    one stopped does not, read from the stopped program's text: a `cal` of the instance,
    on a rung of each program down to it, and a `ton` in the body; and only where the
    program stopped is the one that last scanned. A timer frozen by a false `cal` both
    programs run is not, and catches up when its block next runs (decision 8). A timer, or
    an instance, only the program stopped declares is kept, and a `.pre` or a resume the
    edit's last switch moved is given back by its path (fixes F1 and F11).
  - An output a `cal` writes is driven by the program, as one any instruction writes is.
  - Cost (decision 32): a bit inside an instance is named by its path, so a switch, and the
    scan right after it, are linear in the block list's bytes, not in its one-shots: with a
    one-shot at every level of a chain of blocks, quadratic in the depth. At the top level,
    where a bit's name is one name, nothing changes.

  **One edit per instance** (fix F5). At accept the edit builds two plans, original to
  candidate and back, from the two programs alone, so a plan cannot go stale; a switch and
  a prune are each a function of one plan, the edit's record of one instance, and its
  state. OE-2's configuration edit builds the plans once per program type and calls those
  once per instance; here each instance takes its own edit. A report names a tag, or a
  member inside an instance by its path.

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
  alias Logex.FbType.Member

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

  # The runtime's own messages for a non-program, a function block type among them (M2-5).
  defp program!(%Program{tags: tags, rungs: rungs}) when is_map(tags) and is_list(rungs), do: :ok

  defp program!(%FbType{name: name} = type) when is_binary(name),
    do: raise(ArgumentError, "`#{name}` is " <> Declarations.not_a_program(type))

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
  # In line order, a tag declared from Elixir (line nil, after every number) last, by name,
  # and several members of one instance, on its one line, by path.
  # M2-5: an instance of a user block keeps its type while the block keeps its name and
  # every member both versions declare keeps its kind, at any depth: the block's body, and a
  # member it adds or drops, change with an edit, the state moving by member name (the
  # nested migration, §4.9; decision 31). A member whose kind changes is cited by its path,
  # at the line of the instance that holds it. Each is cited in the candidate's file, where
  # it has one (fix F15). Each program's tags are read with each instance's type itself, as
  # a block's compiled body, which runs as a program too, names the types it holds.
  defp retyped(%Program{} = original, %Program{file: file} = edited) do
    running = Program.typed_tags(original)
    candidate = Program.typed_tags(edited)

    retyped =
      for {name, %Tag{type: type, line: line}} <- candidate,
          {:ok, %Tag{type: was}} <- [Map.fetch(running, name)],
          {path, from, to} <- changes(was, type, name),
          do: {{line, name, path}, retyped(path, {file, line}, from, to)}

    for {_at, diagnostic} <- Enum.sort_by(retyped, &elem(&1, 0)), do: diagnostic
  end

  defp changes(same, same, _path), do: []

  defp changes(
         %FbType{name: name, body: %Program{}} = was,
         %FbType{name: name, body: %Program{}} = type,
         path
       ) do
    before = by_name(was)

    for %Member{name: member} = to <- type.members,
        {:ok, from} <- [Map.fetch(before, member)],
        change <-
          changes(FbType.type_of(was, from), FbType.type_of(type, to), path <> "." <> member),
        do: change
  end

  defp changes(was, type, path), do: [{path, was, type}]

  # A version's members by name, built once per type compared, so that matching the
  # members of two versions is linear in them, not quadratic.
  defp by_name(nil), do: %{}
  defp by_name(%FbType{members: members}), do: Map.new(members, &{&1.name, &1})

  defp retyped(path, {file, line}, was, type),
    do: %Diagnostic{
      stage: :edit,
      file: file,
      line: line,
      message:
        "`#{path}` is #{word(was)} in the running program and #{word(type)} in the " <>
          "candidate: #{whose(String.contains?(path, "."))} type changes only with a restart"
    }

  defp whose(false), do: "a tag's"
  defp whose(true), do: "a member's"

  # A user block's name is any name, so it takes no article of its own (M2-5).
  defp word(%FbType{} = type), do: Declarations.instance_of(type)
  defp word(type), do: "a #{type}"

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

  # A program's tags with each instance's type itself (Logex.Program.typed_tags/1), as
  # every walk below reads them: a block's compiled body, which runs as a program too,
  # names each type it holds.
  defp facts(%Program{rungs: rungs} = program) do
    tags = Program.typed_tags(program)
    {writes, ons, called, bodies} = rungs(rungs, tags)

    %{
      tags: tags,
      initial: Program.initial_env(program),
      inputs: section(tags, :var_input),
      outputs: section(tags, :var_output),
      writes: writes,
      ons: ons,
      ons_rungs: Map.new(ons, fn {key, _bits} -> {key, true} end),
      ons_bits: for({_key, bits} <- ons, bit <- bits, into: %{}, do: {bit, true}),
      timers:
        for(
          {name, %Tag{type: %FbType{body: nil}} = tag} <- tags,
          into: %{},
          do: {name, preset(tag)}
        ),
      # M2-5: each instance of a user block, with its type and whether a `cal` runs it; and
      # what each block type's body writes and runs, by the type's name.
      blocks:
        for(
          {name, %Tag{type: %FbType{body: %Program{}} = type}} <- tags,
          into: %{},
          do: {name, {type, is_map_key(called, name)}}
        ),
      bodies: bodies
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
      timers: timers(from, to),
      nested: nested(from, to)
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

  # M2-5: an instance of a user block fits by being a map: which members it holds is the
  # nested migration's to settle, member by member (below).
  defp fit(%Tag{type: %FbType{body: %Program{}}}), do: :block

  defp fit(%Tag{type: %FbType{} = type}),
    do: {:members, Enum.sort(Map.keys(FbType.initial(type)))}

  defp fit(%Tag{type: type}), do: type

  # What a program's rungs write and where its one-shots are, in one walk, into every group
  # however deep, accumulating rather than copying: how many times each name is written
  # through a write operand, an `ons` storage bit and a `cal`'s output included; and, for
  # each rung that holds an `ons`, the rung with its line numbers taken out, beside the
  # storage bits of its `ons`. A rung is stripped once and compared once, however many
  # `ons` it holds. Each instruction's slots are its own, from Logex.Compiler.signature/2
  # given the tag table of the routine that holds it, each instance's type itself, the one
  # lookup (M2-5).
  #
  # M2-5: an `ons` inside an instance a `cal` runs is a one-shot of the program's too, its
  # bit named by its path, `s1.edge`, and its rung the chain of rungs down to it, each with
  # its line numbers taken out: the body's rung that holds it, the rung of the body above
  # that `cal`s its instance, and so on up to the program's rung that `cal`s the outermost,
  # so a change to any of them, a `cal`'s operands included, makes it a changed one-shot
  # (decision 21, by path). Its bit is written as many times as its block's body writes
  # it. Each block type's body is read once, however many instances run it, and the walk
  # down is linear in the instances.
  defp rungs(rungs, tags) do
    bodies = bodies(for({_, %Tag{type: %FbType{body: %Program{}} = type}} <- tags, do: type), %{})

    Enum.reduce(rungs, {%{}, [], %{}, bodies}, fn {:rung, elements}, {writes, ons, called, _} ->
      {writes, bits, cals} = written(elements, {writes, [], []}, tags)
      chain = chain(bits, cals, {elements, tags})

      {writes, ons} =
        Enum.reduce(cals, {writes, oned(bits, chain, ons)}, &inside(&1, chain, &2, bodies))

      {writes, ons, runs(cals, called), bodies}
    end)
  end

  defp chain([], [], _elements), do: nil
  defp chain(_bits, _cals, {elements, tags}), do: [stripped(elements, tags)]

  defp oned([], _key, ons), do: ons
  defp oned(bits, key, ons), do: [{key, bits} | ons]

  defp runs(cals, called),
    do: Enum.reduce(cals, called, fn {name, _type}, set -> Map.put(set, name, true) end)

  # Every user block type a program holds, at any depth, by name: the rungs of its body
  # that hold an `ons` or a `cal`, each stripped, with the bits and the instances, what the
  # body writes, and the instances it runs. A body holds each type its instances are of
  # once, and its walk reads its tags with each instance's type itself.
  defp bodies(types, bodies),
    do:
      Enum.reduce(types, bodies, fn
        %FbType{name: name, body: %Program{} = body}, bodies when not is_map_key(bodies, name) ->
          bodies = bodies(Map.values(body.blocks), Map.put(bodies, name, nil))
          Map.put(bodies, name, body(body))

        _known, bodies ->
          bodies
      end)

  defp body(%Program{rungs: rungs} = body) do
    tags = Program.typed_tags(body)

    {writes, held, called} =
      Enum.reduce(rungs, {%{}, [], %{}}, fn {:rung, elements}, {writes, held, called} ->
        {writes, bits, cals} = written(elements, {writes, [], []}, tags)
        {writes, held(bits, cals, {elements, tags}, held), runs(cals, called)}
      end)

    %{rungs: Enum.reverse(held), writes: writes, called: called}
  end

  defp held([], [], _elements, held), do: held

  defp held(bits, cals, {elements, tags}, held),
    do: [{stripped(elements, tags), bits, cals} | held]

  # One instance a `cal` runs, `prefix` its path, under the chain of rungs that runs it.
  defp inside({instance, %FbType{name: type}}, chain, acc, bodies),
    do: inside(Map.fetch!(bodies, type), instance, chain, acc, bodies)

  defp inside(%{rungs: rungs, writes: counts}, prefix, chain, acc, bodies),
    do:
      Enum.reduce(rungs, acc, fn {stripped, bits, cals}, {writes, ons} ->
        chain = [stripped | chain]
        paths = Enum.map(bits, &(prefix <> "." <> &1))
        writes = Enum.reduce(bits, writes, &Map.put(&2, prefix <> "." <> &1, Map.get(counts, &1)))
        ons = oned(paths, {prefix, chain}, ons)

        Enum.reduce(cals, {writes, ons}, fn {name, type}, acc ->
          inside({prefix <> "." <> name, type}, chain, acc, bodies)
        end)
      end)

  defp written([], acc, _tags), do: acc

  defp written([{:branches, legs} | rest], acc, tags),
    do: written(rest, Enum.reduce(legs, acc, &written(&1, &2, tags)), tags)

  defp written([{:ons, _line, [{:name, _, bit}]} | rest], {writes, bits, cals}, tags),
    do: written(rest, {count(writes, bit), [bit | bits], cals}, tags)

  defp written([{_symbol, _line, operands} = instruction | rest], {writes, bits, cals}, tags),
    do:
      written(
        rest,
        {wrote(Compiler.signature(instruction, tags), operands, writes), bits,
         calling(instruction, tags, cals)},
        tags
      )

  # M2-5: the instances a rung's `cal`s run, each with its type. A `cal` of an instance its
  # table does not hold as a user block's, which only a body built by hand can have, runs
  # nothing (Logex.Runtime), and so runs nothing here either; its signature/2 slots are none,
  # so it writes nothing.
  defp calling({:cal, _line, [{:name, _, instance} | _]}, tags, cals),
    do: block_call(Map.get(tags, instance), instance, cals)

  defp calling(_instruction, _tags, cals), do: cals

  defp block_call(%Tag{type: %FbType{body: %Program{}} = type}, instance, cals),
    do: [{instance, type} | cals]

  defp block_call(_not_a_block, _instance, cals), do: cals

  defp wrote([{:write, _type} | signature], [{:name, _, name} | operands], acc),
    do: wrote(signature, operands, count(acc, name))

  defp wrote([_slot | signature], [_operand | operands], acc), do: wrote(signature, operands, acc)
  defp wrote(_signature, _operands, acc), do: acc

  defp count(writes, name), do: Map.update(writes, name, 1, &(&1 + 1))

  # A rung as the text says it, line numbers taken out: a rung moved or renumbered is the
  # same rung (decision 21).
  #
  # M2-5: a `cal` is stripped with the formals its operands fill, its block's members in
  # `cal`'s order, so an edit that reorders a block's inputs, which the text of the rung
  # does not show, changes the rung as an edit of its operands would (decision 21).
  defp stripped(elements, tags), do: Enum.map(elements, &bare(&1, tags))

  defp bare({:branches, legs}, tags), do: {:branches, Enum.map(legs, &stripped(&1, tags))}

  defp bare({:cal, _line, [{:name, _, instance} | _] = operands}, tags),
    do: {:cal, Enum.map(operands, &operand/1), formals(Map.get(tags, instance))}

  defp bare({symbol, _line, operands}, _tags), do: {symbol, Enum.map(operands, &operand/1)}

  defp formals(%Tag{type: %FbType{body: %Program{}} = type}),
    do: for({_slot, %Member{name: name}} <- tl(FbType.signature(type)), do: name)

  defp formals(_not_a_block), do: nil

  defp operand({kind, _line, value}), do: {kind, value}

  # ---- M2-5: the state inside a user block's instances, across a switch -----------------

  # For each instance of a user block the program started declares, a plan of its members,
  # from the two versions of its type: the nested migration of §4.9, copying the members
  # both declare and starting the rest. Built per type, not per instance: an instance's plan
  # depends on its type, the other program's version of it, and whether each program runs
  # it, so a program of many instances of one block plans that block once, and the plan is
  # linear in the types and their members.
  #
  # An instance only the program stopped declares is kept, unused, until a prune, and its
  # plan holds only the timers inside it, whose `.pre` and `last` the edit's last switch
  # may have moved, to give back (fixes F1 and F11), as `timers/2` holds a timer only one
  # program declares.
  defp nested(from, to) do
    {plans, memo} =
      Enum.map_reduce(to.blocks, %{}, fn {name, {type, run}}, memo ->
        {was, ran} = before(Map.get(from.blocks, name), type)
        {plan, memo} = member_plan(was, type, {ran, run}, {from.bodies, to.bodies}, memo)
        {{name, plan}, memo}
      end)

    {gone, _memo} =
      Enum.flat_map_reduce(from.blocks, memo, fn
        {name, _block}, memo when is_map_key(to.blocks, name) ->
          {[], memo}

        {name, {type, _ran}}, memo ->
          {plan, memo} = gone_plan(Map.fetch(memo, {:gone, type.name}), type, memo)
          {[{name, plan}], memo}
      end)

    plans ++ gone
  end

  # The other program's version of an instance's type, where it holds one of that name.
  defp before({%FbType{name: name} = was, ran}, %FbType{name: name}), do: {was, ran}
  defp before(_none, _type), do: {nil, false}

  defp member_plan(was, type, runs, bodies, memo) do
    key = {type.name, was != nil, runs}
    planned(Map.fetch(memo, key), key, {was, type, runs, bodies}, memo)
  end

  defp planned({:ok, plan}, _key, _types, memo), do: {plan, memo}

  defp planned(:error, key, {was, type, runs, bodies}, memo) do
    before = {was, by_name(was)}

    {members, memo} =
      Enum.map_reduce(
        type.members,
        memo,
        &member(%{&1 | type: FbType.type_of(type, &1)}, before, {type, runs, bodies}, &2)
      )

    names = Map.new(type.members, &{&1.name, true})
    {gone, memo} = gone(was, names, memo)
    plan = %{members: members ++ gone, names: names}
    {plan, Map.put(memo, key, plan)}
  end

  # The timers only the stopped program's version of a block declares, at any depth, which
  # the program started does not run: their `.pre` and `last` are still this edit's to give
  # back (fix F1, F11), as `timers/2` covers a timer only one program declares at the top
  # level. Planned once per type.
  defp gone(nil, _names, memo), do: {[], memo}

  defp gone(%FbType{members: members} = type, names, memo),
    do:
      members
      |> Enum.reject(&is_map_key(names, &1.name))
      |> Enum.flat_map_reduce(memo, &gone_member(&1, FbType.type_of(type, &1), &2))

  defp gone_member(%Member{name: name}, %FbType{body: nil}, memo),
    do: {[{:timer_gone, name}], memo}

  defp gone_member(%Member{name: name}, %FbType{} = type, memo) do
    {plan, memo} = gone_plan(Map.fetch(memo, {:gone, type.name}), type, memo)
    {[{:block_gone, name, plan}], memo}
  end

  defp gone_member(_leaf, _type, memo), do: {[], memo}

  defp gone_plan({:ok, plan}, _type, memo), do: {plan, memo}

  defp gone_plan(:error, type, memo) do
    {members, memo} = gone(type, %{}, memo)
    plan = %{members: members}
    {plan, Map.put(memo, {:gone, type.name}, plan)}
  end

  defp member(%Member{name: name} = member, {was, before}, context, memo),
    do: member(member, resolved(was, Map.get(before, name)), context, memo, name)

  # A member with its type itself, a user block's taken from the body (Logex.FbType).
  defp resolved(_type, nil), do: nil
  defp resolved(type, member), do: %{member | type: FbType.type_of(type, member)}

  defp member(%Member{type: type, initial: initial}, old, _context, memo, name)
       when type in [:bool, :dint],
       do: {{:leaf, name, type, initial, old_initial(old), old != nil}, memo}

  defp member(
         %Member{type: %FbType{body: nil} = type, initial: initial},
         old,
         context,
         memo,
         name
       ) do
    {_type, {ran, run}, _bodies} = context
    start = FbType.initial(type, initial)
    keys = Enum.sort(Map.keys(start))
    {{:timer, name, keys, start, runs_ton(ran, old), runs_ton(run, initial), old != nil}, memo}
  end

  defp member(%Member{type: %FbType{} = type, initial: initial}, old, context, memo, name) do
    {owner, {ran, run}, {before_bodies, bodies}} = context
    was = old_type(old)
    ran = ran and called?(before_bodies, owner.name, name)
    run = run and called?(bodies, owner.name, name)
    {plan, memo} = member_plan(was, type, {ran, run}, {before_bodies, bodies}, memo)
    {{:block, name, {type, initial}, old != nil, plan}, memo}
  end

  defp old_initial(nil), do: nil
  defp old_initial(%Member{initial: initial}), do: initial

  defp old_type(nil), do: nil
  defp old_type(%Member{type: type}), do: type

  # The preset of the `ton` that runs a timer inside a block, as the compiler gives its
  # member (Logex.Compiler), where the program runs the block; nil where it does not, or no
  # `ton` of the body runs the timer.
  defp runs_ton(false, _member_or_initial), do: nil
  defp runs_ton(true, nil), do: nil
  defp runs_ton(true, %Member{initial: initial}), do: runs_ton(true, initial)
  defp runs_ton(true, %{} = initial), do: Map.get(initial, "pre")

  # Whether a block's body, in one program's version of it, has a `cal` of an instance it
  # holds. It is asked only of a version the program holds: of the program started's own,
  # and of the stopped program's where it runs the instance, and so holds a version of that
  # name, since accept refuses an instance or member whose block is renamed.
  defp called?(bodies, type, name), do: is_map_key(Map.fetch!(bodies, type).called, name)

  # Decision 21 and fix F7: the storage bits of the `ons` of `to` that a switch from `from`,
  # the program that last scanned, blocks until a scan runs each. Each is blocked unless
  # `from` has that `ons` in an identical rung, line numbers ignored, and writes its bit
  # through nothing else: an `ons` that `to` adds, one whose rung it changes, and one whose
  # bit `from` also writes through another instruction, which may leave the bit at a value
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
    scanned = scanned(record.scanned, state, plan)
    clock = {now, state.switched, elem(scanned, 0) == plan.stops}

    {env, inside, pre} =
      Enum.reduce(
        plan.nested,
        {env, [], %{}},
        &migrate(&1, fresh, {first_test?, record.pre, clock}, &2)
      )

    {inputs, added} = Enum.split_with(started, &is_map_key(plan.inputs, &1))
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
        for(bit <- blocked, do: {:ons_blocked, bit, bit_at(env, bit)}) ++
        holding(plan, shown, env)

    {env, timed, pre} =
      Enum.reduce(plan.timers, {env, [], pre}, fn {name, from, to}, acc ->
        timed({name, name, from, to}, record.pre, clock, acc)
      end)

    {%{state | env: env, switched: true, ons_blocked: blocked},
     %{record | shown: shown, pre: pre, scanned: scanned}, Enum.sort(timed ++ inside ++ report)}
  end

  # A storage bit's value, a bit inside an instance found by its path (M2-5).
  defp bit_at(env, bit), do: path_at(env, String.split(bit, "."))

  defp path_at(value, []), do: value
  defp path_at(%{} = map, [key | path]), do: path_at(Map.get(map, key, 0), path)
  defp path_at(_not_a_map, _path), do: 0

  # M2-5, the nested migration (§4.9): inside each instance of a user block both programs
  # declare, kept as a map and not started whole above, each member the program started
  # declares moves by the rules a tag does: one the state lacks starts at its initial value;
  # at the first test, one the candidate's version of the block adds, or whose value does
  # not fit its type, starts so too; a kept bool or dint whose initial value changed keeps
  # its value and is reported; a timer meets the timer rules; and an instance it holds is
  # migrated in turn. A member only the stopped program's version declares is kept, unused,
  # until assemble or cancel prunes it. Each is reported by its path, `s1.count`.
  defp migrate({name, plan}, fresh, rules, {env, reports, pre}) do
    migrate_in(
      Map.get(env, name),
      is_map_key(fresh, name),
      {name, plan},
      rules,
      {env, reports, pre}
    )
  end

  defp migrate_in(%{} = map, false, {name, plan}, rules, {env, reports, pre}) do
    {map, reports, pre} = members(plan, map, name, rules, {reports, pre})
    {Map.put(env, name, map), reports, pre}
  end

  defp migrate_in(_started_or_not_a_map, _fresh?, _plan, _rules, acc), do: acc

  defp members(plan, map, prefix, rules, {reports, pre}),
    do: Enum.reduce(plan.members, {map, reports, pre}, &moved_member(&1, prefix, rules, &2))

  defp moved_member({:leaf, name, type, initial, old, kept?}, prefix, {first?, _, _}, acc) do
    path = prefix <> "." <> name

    starts?(Map.fetch(elem(acc, 0), name), not kept?, type, first?)
    |> started(name, path, initial, acc)
    |> initial_changed({kept?, old, initial}, path)
  end

  defp moved_member({:timer, name, keys, initial, from, to, kept?}, prefix, rules, acc) do
    {first?, undo, clock} = rules
    {map, reports, pre} = acc
    path = prefix <> "." <> name

    timer_moved(
      starts?(Map.fetch(map, name), not kept?, {:members, keys}, first?),
      {name, path, initial, from, to},
      {undo, clock},
      {map, reports, pre}
    )
  end

  defp moved_member({:block, name, initial, kept?, plan}, prefix, rules, {map, reports, pre}) do
    {first?, _undo, _clock} = rules
    path = prefix <> "." <> name

    block_moved(
      starts?(Map.fetch(map, name), not kept?, :block, first?),
      {name, path, initial, plan},
      rules,
      {map, reports, pre}
    )
  end

  # A timer only the stopped program's version declares: kept, unused, and its `.pre` and
  # `last` given back where this edit's last switch moved them.
  defp moved_member({:timer_gone, name}, prefix, {_first?, undo, clock}, acc),
    do: timed({name, prefix <> "." <> name, nil, nil}, undo, clock, acc)

  defp moved_member({:block_gone, name, plan}, prefix, rules, {map, reports, pre}),
    do:
      block_kept(
        Map.get(map, name),
        {name, prefix <> "." <> name, plan},
        rules,
        {map, reports, pre}
      )

  defp started(true, name, path, initial, {map, reports, pre}),
    do: {:started, {Map.put(map, name, initial), [{:added, path, initial} | reports], pre}}

  defp started(false, _name, _path, _initial, acc), do: {:kept, acc}

  defp initial_changed({:started, acc}, _initials, _path), do: acc

  defp initial_changed({:kept, {map, reports, pre}}, {true, old, new}, path) when old != new,
    do: {map, [{:initial_changed, path, {old, new}} | reports], pre}

  defp initial_changed({:kept, acc}, _initials, _path), do: acc

  defp timer_moved(true, {name, path, initial, _from, _to}, _clocks, {map, reports, pre}),
    do: {Map.put(map, name, initial), [{:added, path, initial} | reports], pre}

  defp timer_moved(false, {name, path, _initial, from, to}, {undo, clock}, acc),
    do: timed({name, path, from, to}, undo, clock, acc)

  # A block's initial state is built only where one starts: built for every member it would
  # make the plan quadratic in the depth of nesting.
  defp block_moved(true, {name, path, {type, overrides}, _plan}, _rules, {map, reports, pre}) do
    initial = FbType.initial(type, overrides)
    {Map.put(map, name, initial), [{:added, path, initial} | reports], pre}
  end

  defp block_moved(false, {name, path, _initial, plan}, rules, {map, reports, pre}),
    do: block_kept(Map.get(map, name), {name, path, plan}, rules, {map, reports, pre})

  defp block_kept(%{} = inner, {name, path, plan}, rules, {map, reports, pre}) do
    {inner, reports, pre} = members(plan, inner, path, rules, {reports, pre})
    {Map.put(map, name, inner), reports, pre}
  end

  defp block_kept(_not_a_map, _plan, _rules, acc), do: acc

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
  # program stopped, with what the scan left pending, which is nothing at the top level,
  # since every rung runs, but a bit inside an instance whose body no scan has run since it
  # was listed (M2-5): its bit is still the one an older rung wrote. No scan since, and
  # that switch this edit's: what it recorded, so a test and an untest with no scan
  # between lose no real edge (F3). No scan since an earlier edit's switch, whose program
  # this edit cannot know: the program stopped is taken for it, with the earlier edit's
  # blocks still pending (F2).
  defp scanned(_known, %Instance{switched: false, ons_blocked: pending}, plan),
    do: {plan.stops, pending}

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
  defp fits?(:block, value), do: is_map(value)
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
  # `key` is the timer's name in the map it lives in, and `name` how the record and the
  # report name it: a top-level timer's name, or its path inside an instance (M2-5).
  defp timed({key, name, _from, _to} = timer, undo, clock, {env, _report, _left} = acc),
    do: timer(Map.get(env, key), timer, Map.get(undo, name), clock, acc)

  defp timer(
         %{"pre" => pre} = value,
         {key, name, from, to},
         undo,
         {now, switched, stopped_last?},
         {env, report, left}
       ) do
    {value, undone} = undone(value, undo, switched, now, name)
    target = target(undo, pre, from, to)

    {value, resumed, found} =
      resumed({from, to, stopped_last?}, %{value | "pre" => target}, name, now)

    {Map.put(env, key, value), moved(name, pre, target, to, value) ++ undone ++ resumed ++ report,
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

  # A timer the program started runs and the program stopped does not, timing when it last
  # ran (`.en` 1, its `last` before `now`), resumes from the switch: its `last` becomes
  # `now`, so the time no `ton` ran it is not caught up (§4.9's Resume rule, decision 23).
  # The `last` it found is returned too, for the next switch to give back (F11). M2-5: a
  # timer both programs run is never resumed. At the top level its `last` is `now` anyway,
  # since a `ton` stamps it at every scan; inside a block whose `cal` was false it is
  # earlier, and the timer catches up when the block next runs, as decision 8 wants. And
  # "the program stopped did not run it" is asked of the program that last scanned, as
  # the one-shots' rule asks it (F3): where that is the program started, a test and an
  # untest with no scan between, the program started left the timer as it is, frozen or
  # not, and no resume is due.
  defp resumed({nil, to, true}, %{"en" => 1, "last" => last} = timer, name, now)
       when to != nil and last < now,
       do: {%{timer | "last" => now}, [{:resumed, name, now - last}], last}

  defp resumed(_presets, timer, _name, _now), do: {timer, [], nil}

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
    {kept, inside} = Enum.reduce(plan.nested, {kept, []}, &prune_in/2)
    {%{state | env: kept}, Enum.sort(holding(plan, record.shown, env) ++ pruned ++ inside)}
  end

  # M2-5: inside each instance of a user block the program kept declares, the members its
  # version of the block does not declare, at any depth, each reported by its path.
  defp prune_in({name, plan}, {env, reports}),
    do: pruned_in(Map.get(env, name), {name, plan}, {env, reports})

  defp pruned_in(%{} = map, {name, plan}, {env, reports}) do
    {map, reports} = prune_members(plan, map, name, reports)
    {Map.put(env, name, map), reports}
  end

  defp pruned_in(_not_a_map, _plan, acc), do: acc

  defp prune_members(plan, map, prefix, reports) do
    {kept, gone} = Map.split_with(map, fn {name, _value} -> is_map_key(plan.names, name) end)

    reports =
      Enum.reduce(gone, reports, fn {name, v}, acc ->
        [{:pruned, prefix <> "." <> name, v} | acc]
      end)

    Enum.reduce(plan.members, {kept, reports}, fn
      {:block, name, _initial, _kept?, inner}, {kept, reports} ->
        nested_prune(Map.get(kept, name), {name, prefix <> "." <> name, inner}, {kept, reports})

      _member, acc ->
        acc
    end)
  end

  defp nested_prune(%{} = inner, {name, path, plan}, {map, reports}) do
    {inner, reports} = prune_members(plan, inner, path, reports)
    {Map.put(map, name, inner), reports}
  end

  defp nested_prune(_not_a_map, _plan, acc), do: acc
end
