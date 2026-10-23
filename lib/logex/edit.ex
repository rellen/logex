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
  - *initial values* (decision 29): a bool or an integer of any width both programs declare whose initial
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
    when it last ran (its `last` before `now`, and `.en` 1 for a `ton` or an `rto`, `.tt` 1
    for a `tof` in its delay or a `tp` in its pulse, M3-2), resumes from the switch, where the
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

  The other timers (M3-2, decisions 93 on) are timers by every rule above, each by its own
  type: a change of a timer's type, a `ton` made a `tof`, needs a restart. A `tof`'s `.dn`
  changes with its `.pre` during its delay, `.tt` 1: where `.acc` is at or past the new
  `.pre` there, `:dn_drops` says `.dn` drops at its next run, unless that run finds its
  rung true, which ends the delay with `.dn` set. It changes too where its rung was true at
  its last run, `.en` 1, and `.pre` moves to 0: the delay then ends on the falling edge's
  own scan, so `:dn_drops`, `{0, 0}`, says `.dn` drops at its next run with its rung false,
  however many runs with its rung true come first. A `tof` blocks nothing: an edit that turns
  its rung false starts its delay, `.dn` held through it, as the rung falling would. A `tp`'s
  pulse changes with its `.pre` only while it runs, `.tt` 1: where `.acc` is at or past
  the new `.pre` there, `:dn_rises` says the pulse ends at its next run, `.tt` dropping and
  `.dn` rising, unless that run finds its rung false, when `.dn` stays 0. A `tp`'s edge
  memory, `.en`, is blocked as a counter's is (below), by its path, `horn_pulse.en`, so a
  `tp` the edit adds while its rung is true, or whose rung it changes, starts no pulse at
  the switch (decision 94). An `rto` keeps `.dn` across a false rung, so its `.dn` changes
  with its `.pre` at its next run with its rung true: `:dn_drops` where `.dn` is 1 and `.acc`
  below the new `.pre`, unless at least `.pre` − `.acc` ms of true rung pass by then, and
  `:dn_rises` where `.dn` is 0 and `.acc` at or past it, its rung true at the switch or not,
  unless that run finds its reset `r` set. Its `r` is a member as a counter's is, kept by a
  switch and 0 in a new instance (decision 95).

  **Counters** (M3-1, decisions 87 and 88). A counter's `.pv` moves by the timers' rules
  for `.pre`, above, each move reported as `:preset` or `:preset_kept`, and it keeps its
  count, `cv`, and its flags. After a move of the `.pv` of a counter the program started
  runs, `:dn_drops` and `:dn_rises` say what its done member, `q` (a ctud's `qu`), now `cv
  >= pv` against the old `.pv`, becomes at the counter's next run, whatever its rung, since
  every run sets it, unless that run counts, resets or loads, which moves `cv` first. A
  ctd's `q` is `cv <= 0`, which no `.pv` moves, so it has none.
  No counter is resumed: it keeps no time. A counter's edge memory, `cu` or `cd`, is
  blocked as a one-shot's storage bit is (below), by its path, `boxes.cu`: its `ctu` or
  `ctd` counts no edge at the next scan that runs it, so a counter the edit adds while its
  rung is true counts nothing at the switch. Each instruction's memory is listed alone, a
  ctud's two sides each by its own rung, and the rungs are compared with the preset of
  every counter and timer on them left out, which no power on a rung reads, so a preset
  changed alone loses no real edge. No logic writes an edge memory, so it is listed only
  where its rung is not in the program that last scanned. A counter inside an instance a
  `cal` runs is blocked by its path, `s1.c.cu`, until a scan runs it (decision 32).

  **One-shots** (decision 21, fixes F2, F3 and F7). No switch writes a storage bit: a bit
  armed by writing 1 would echo into any rung that reads it. A switch lists bits in the
  instance's `ons_blocked` instead, and the next scan that runs each one's `ons` blocks it,
  as a first scan blocks every `ons` (`Logex.Instance`): it passes no power, and still
  writes its bit. At the top level that is the next scan, or since M3-5 the next that does
  not skip its rung (decision 106); inside a function block's instance, the next whose
  `cal` runs its body and does not skip its rung (decision 32). Against the program that last
  scanned, a switch lists each `ons` of the program it starts that is not in an identical
  rung there, line numbers, the preset of every timer and counter on it, and since decision
  202 a literal's spelling ignored, a literal compared by its value, so that `16#ff`
  respelling `255` changes no rung, or
  whose bit that program also writes through another instruction: an `ons` the edit adds,
  one whose rung it changes, and one whose bit may not hold the power the `ons` last
  received. An untouched `ons` is not listed, and keeps a real edge on the switch scan; so
  does one whose rung changes only in a `ton`'s preset, which no power on the rung reads,
  and which blocked it before M3-1 (decision 87). A rung's `lbl` and `jmp` are part of it
  (M3-5, decision 106): an edit that labels a one-shot's rung, a pulse coil's among them,
  or adds a `jmp` to it, blocks the one-shot once, at the cost of a press that rises on
  the first scan after the switch, as the maintainer confirmed after M3-5's review: one
  rule with a coil's rung compared whole (decision 101). Labels are names, so a rung that
  moves leaves every jump as it was, and a `jmp` an edit adds or removes freezes or frees
  its section from the switch, which blocks nothing whose rung it leaves alone (decision
  82).
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

  A pulse coil's storage bit (M3-4, decision 80) is a one-shot's by every rule above, its
  `osr` or `osf` setting no pulse at the next scan that runs it, and still writing both its
  bits: a coil the edit adds, one whose rung it changes, its kind, its pulse bit and its
  condition among the rung, and one whose storage bit the program that last scanned also
  writes another way. Its pulse bit is an ordinary bool, an output an edit stops driving
  held as any is (below), so a coil removed on the scan of its pulse leaves its pulse bit
  on.

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

  **A member input no longer written** (decision 96). A member input logic writes, a
  counter's `r`, `ld` or `pv`, an `rto`'s `r` or a timer's `.pre`, of a built-in instance
  the program started declares, at any depth, that the program stopped writes through an
  instruction (`Logex.Walk.member_writes/1`) and the program started writes through none,
  keeps its value, as a held output does, and each switch reports it by its path with the
  value it keeps, whatever it is: `{:unwritten, "lube.r", 1}`, a reset held when the edit
  removed its rung, which holds the timer at 0 until a restart. It asks nothing of the
  host. A timer's `.acc`, its own output, is not reported.

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
  | `:preset` | `{from, to}`, the move of the timer's `.pre`, a counter's `.pv` | a switch |
  | `:preset_kept` | `{pre, preset}`: `.pre` (`.pv`) kept, not the preset of the instruction that runs it | a switch |
  | `:dn_drops`, `:dn_rises` | `{acc, pre}`, as `ton` counts them, a negative `.acc` as 0; for a counter, `{cv, pv}` | a switch |
  | `:resumed` | the milliseconds not caught up: `last` moves on by that many, to `now` | a switch |
  | `:resume_undone` | the milliseconds of the resume this edit's last switch made: `last` moves back by that many | a switch |
  | `:ons_blocked` | the storage bit's value, unchanged: its `ons` passes no power at the next scan that runs it, its `osr` or `osf` sets no pulse; for a counter's edge memory, its value: its `ctu` or `ctd` counts no edge then | a switch |
  | `:held` | for an output the next program shows, the state's value, what its next scan gives, which can differ from what the point holds until then; otherwise the value the point last received | every step |
  | `:unwritten` | the value it keeps: a member input logic writes that the program stopped writes and the program started does not (decision 96) | a switch |
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
  version adds, or whose value does not fit, starts so too; a kept bool or integer whose
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
  state. They are an internal module's, `Logex.Edit.Plan`, so that
  `Logex.Configuration.Edit`, the edit of a running configuration (OE-2), builds the plans
  once per program type and calls those once per instance; here each instance takes its
  own edit. A report names a tag, or a member inside an instance
  by its path.

  **Host mistakes** raise `ArgumentError`, each with a message a test pins: something
  other than a program at accept, with the runtime's own message; a program edited by
  hand after it compiled (`Logex.Program.edited_by_hand/1`, decisions 182 and 197), the
  program running first and then the candidate (decision 200), in the runtime's words; a
  candidate with
  another name than the running program's (two unnamed programs count as one name);
  something other than an edit; a state that is not the running program's, or that holds
  an integer outside its tag's type in the program it runs (decision 171), with the
  runtime's own messages; and a step taken at the wrong stage. A step checks the edit,
  then the state, then the stage. Outside the contract, and not detected, since only a
  configuration's edit carries a generation (decision 60): scanning the program the edit
  is not running, two
  edits of one instance at once, a step on an edit that has ended or been superseded, an
  edit accepted against a program the state is not running, and an edit built or changed
  by hand. The program the state is running is the one the last of these left it with:
  `Logex.Runtime.instance/1`, `Logex.Runtime.restart/3`, a scan, or this module's
  `assemble/2` or `cancel/2`. A plain swap is a scan of the new program, so the program
  it swaps in is then the one the state is running; a test and an assemble at one
  boundary leave it running the candidate, so another edit may be accepted against the
  candidate before any scan (F2), and none against the original.
  """

  alias Logex.{Declarations, FbType, Program, Runtime}
  alias Logex.Edit.Plan

  @enforce_keys [:original, :candidate, :stage, :plans, :record]
  defstruct [:original, :candidate, :stage, :plans, :record]

  @opaque t :: %__MODULE__{}

  @doc """
  Accepts `candidate` beside `running`, the program `state` is an instance of:
  `{:ok, edit, forecast}`, the forecast being the report a test taken now would give, or
  `{:error, diagnostics}` when the candidate changes a tag's type. Nothing is changed.
  """
  def accept(running, candidate, state) do
    checked!(running)
    checked!(candidate)
    named!(running, candidate)
    accepted(Plan.retyped(running, candidate), running, candidate, checked(running, state))
  end

  defp accepted([], running, candidate, state) do
    plans = Plan.plans(running, candidate)

    edit = %__MODULE__{
      original: running,
      candidate: candidate,
      stage: :accepted,
      plans: plans,
      record: Plan.record()
    }

    {_state, _record, forecast} = Plan.switch(plans.test, Plan.record(), state, true)
    {:ok, edit, forecast}
  end

  defp accepted(diagnostics, _running, _candidate, _state), do: {:error, diagnostics}

  @doc "Runs the candidate over the state, from accept or after an untest."
  def test(edit, state) do
    edit = edit!(edit)
    tested(edit, state!(edit, state))
  end

  defp tested(%__MODULE__{stage: stage} = edit, state) when stage in [:accepted, :untested] do
    {state, record, report} =
      Plan.switch(edit.plans.test, edit.record, state, first_test?(stage))

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
    {state, record, report} = Plan.switch(edit.plans.untest, edit.record, state, false)
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
    {state, report} = Plan.prune(edit.plans.test, edit.record, state)
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
    {state, report} = Plan.prune(edit.plans.untest, edit.record, state)
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

  # The runtime's own messages for a non-program, a function block type among them (M2-5),
  # and since decision 182 for one edited by hand whose arithmetic computes in a
  # destination with no integer type, and since decision 197 whose units its tags do not
  # give (`Logex.Program.edited_by_hand/1`), since decision 190 checked once, where a
  # program is first handed in: here, since decision 200, the program running as well as
  # the candidate, the program running first, so that one swapped into the instance by
  # hand after its check is refused before an edit plans from it.
  defp checked!(program) do
    program!(program)
    computable!(Program.edited_by_hand(program))
  end

  defp program!(%Program{tags: tags, rungs: rungs}) when is_map(tags) and is_list(rungs),
    do: :ok

  defp program!(%FbType{name: name} = type) when is_binary(name),
    do: raise(ArgumentError, "`#{name}` is " <> Declarations.not_a_program(type))

  defp program!(other),
    do:
      raise(
        ArgumentError,
        "expected a %Logex.Program{} from Logex.compile/2, got: #{inspect(other)}"
      )

  defp computable!([]), do: :ok
  defp computable!(lines), do: raise(ArgumentError, Enum.join(lines, "\n"))

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
end
