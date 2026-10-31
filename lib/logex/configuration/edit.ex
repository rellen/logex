defmodule Logex.Configuration.Edit do
  @moduledoc """
  A staged edit of a running configuration (OE-2, `docs/organisation.md` §4.9, "OE-2's
  design"): a candidate configuration is accepted against the resource that runs the
  original, `%Logex.Runtime{}`, tested in it, untested, and assembled or cancelled, with
  `Logex.Edit`'s steps and report over a whole plant (decision 59). Every step is taken
  between two cycles and returns a report.

      {:ok, edit, forecast}     = Logex.Configuration.Edit.accept(runtime, candidate)
      {edit, runtime, report}   = Logex.Configuration.Edit.test(edit, runtime)   # the candidate runs
      {edit, runtime, report}   = Logex.Configuration.Edit.untest(edit, runtime) # the original again
      {edit, runtime, report}   = Logex.Configuration.Edit.test(edit, runtime)
      {config, runtime, report} = Logex.Configuration.Edit.assemble(edit, runtime)

  | Step | Taken from | `Logex.Runtime.cycle/3` then runs | The resource |
  |---|---|---|---|
  | `accept/2` | — | the original | read for the forecast, unchanged |
  | `test/2` | accepted, untested | the candidate | switched to the candidate |
  | `untest/2` | testing | the original | switched back |
  | `assemble/2` | testing | the candidate; the edit ends | pruned to the candidate |
  | `cancel/2` | accepted | the original; the edit ends | unchanged but for its generation; the report is `[]` |
  | `cancel/2` | untested | the original; the edit ends | pruned to the original |

  The resource carries the configuration it runs, so the host chooses nothing to scan:
  `running/1` says what a cycle runs, and the host keeps the runtime each step returns. A
  `Logex.Runtime.restart/2` during an edit keeps its stage (decision 65).

  **Accept** reads the running configuration from the resource: `accept/2` checks the
  candidate against it and the resource, and changes nothing. Its forecast is the report a
  test taken now would give, the switch computed over the resource as it is and thrown
  away (decision 27); a test taken later reads the resource as it is then.

  It refuses, as `{:error, diagnostics}` at stage `:edit`, what may change only with a
  restart: a task added or removed, the continuous task's line among them; a task made
  continuous, or a continuous one made timed, keeping its name, which is that task's one
  refusal, so no instance that names it is told it moved (decision 129); a task's `single`
  added, removed or changed; an event task's interval added or removed; an instance both
  configurations run as one type moved to another task, or to or from none, an instance
  with no task and one `with` the continuous task being in one place, so that `with main`
  added or taken away moves nothing, and the continuous task named where it is declared; a global's type; located I/O, a located global
  added, removed or moved, or a location added to or taken from a global, a device being
  only its points' prefix, since M5-13 a located array's by the range its elements occupy,
  `card.i.0` to `card.i.7`, so that one grown or shrunk is refused for its range, and since
  decision 244 for its range alone, an unlocated array grown for its type (decision 157);
  and, in each program type an instance runs as that type in
  both, every type change `Logex.Edit` refuses, a member's by its path. The configuration's
  own refusals come first, each in the candidate's `file` at its element's line, in line
  order, an element only the running configuration has last, with no line, its line in the
  running configuration named in its text, its removed tasks before its removed located
  globals, each in its order there; then each program type's, in the order of its first
  such instance in the candidate, each in that type's own `file` (fix F15). A candidate's
  warnings stop nothing.

  **A switch**, `test/2` or `untest/2`, moves the resource from the configuration it stops
  to the one it starts, writes it in the resource, which then runs the latter, and prunes
  nothing but, at the first test, what an edit this one superseded left (decision 66):
  - at an edit's first test, the resource runs the original and holds nothing of this
    edit's, so an instance set aside, or a global the original does not declare, was left
    by an earlier edit, accepted over the same resource and never ended, under another
    candidate. It is dropped before the switch, as a prune drops it, `{:instance_pruned,
    name, type}` and `{:pruned, name, value}`, so that no instance comes back, and no
    global keeps a value, that this edit's programs never ran: a candidate that runs or
    declares it again starts it as `Logex.Runtime.start/1` would;
  - an instance both configurations run as one program type, a *kept* instance, moves
    through `Logex.Edit`'s per-instance switch, by one plan per program type and
    direction built at accept (fix F5), its reports named by its path, `m1.t1`. Each
    global is merged into its state by the var_externals of the program the switch stops,
    and each var_external of the program started is split off again after, with any of
    the program stopped's that the one started does not declare, so no instance's state
    holds one (decisions 45 and 49), and the plan knows them, so no start rule starts one
    and none is reported as a changed initial value. No switch writes a global: a
    var_external of the program started that the program stopped declares as its own tag,
    or not at all, has that own value dropped, `{:joined, path, {own, global}}`, `own` nil
    where it had none, and reads the shared global from its next scan (decision 55); one of
    the program stopped that the one started declares as its own tag keeps the global's
    value as its own, `{:left, path, value}` (decision 25). A timer
    resumes from the resource's clock, and the switch gives the instance that clock as its
    `now`, fix F11's undo reading the instance's own `now` first, the time the last switch
    gave it (decision 56);
  - an instance only the configuration started runs, or one it runs as another program
    type (decision 43), which may run on another task (decision 61), comes back from
    aside where an earlier switch of this edit set it aside, as it was, its `now` the
    resource's and each timer that was timing resumed from the switch, `:resumed` by its
    path, since the edit stopped it, not its logic (decision 57),
    `{:instance_back, name, type}`; or is started as `Logex.Runtime.instance/1` starts it,
    its var_externals dropped as `start/1` drops them, `{:instance_added, name, type}`;
  - an instance only the configuration stopped runs, or the old state of one retyped, is
    set aside, kept unused and never scanned, `{:instance_stopped, name, type}`;
  - a global only the configuration started declares starts at
    `Logex.Configuration.initial/1`, `{:added, name, value}`, at the switch that first
    finds it missing; one only the configuration stopped declares is kept unused, so an
    instance set aside that reads it finds it if it comes back; and a kept global whose
    initial value changed keeps its running value until `Logex.Runtime.restart/2`,
    `{:initial_changed, name, {old, new}}` (decision 44); and since decision 302 a kept
    global whose `retain` the edit adds or takes away keeps its value, nothing written,
    `{:retain_added, name, value}` or `{:retain_removed, name, value}`, the value it holds,
    which the next warm restart keeps or puts back (decision 278), `non_retain` and no
    qualifier one;
  - a task whose interval changed is next due at `min(next_due, now + new interval)`
    (decision 40), `{:interval, task, {old, new}}`, and `{:next_due, task, {from, to}}`
    where that moves it, `now` the step's time: the resource's, plus the `elapsed_ms`
    since its last cycle that `test/3` and `untest/3` take, and `accept/3` for its
    forecast, 0 unless given, so that a host whose clock has moved on since the last
    cycle, as `Logex.Runner`'s has, counts the new interval from the edit (decision 139);
    the step moves no clock, the resource's `now` and a resumed timer's staying the
    resource's; its trigger's last sample is kept, so no switch fires an event;
  - a task whose priority changed is reported, `{:priority, task, {old, new}}`: the next
    cycle's sort reads it, so it needs no state;
  - a task whose watchdog changed is reported, `{:watchdog, task, {old, new}}`, in ms, 500
    for none, so `watchdog 500` written where a line had none reports nothing: the runner
    reads it at each step it times, and the resource holds no state for it (M4-2,
    decision 129);
  - the order of the instances on each task, and of the tasks, is configuration, not
    state, so a reorder is allowed (decision 62) and reported where the names both
    configurations have there change their order among themselves: `{:order, task,
    names}`, `task` `:none` for the task-less instances, or the continuous task's name,
    under which they and the instances `with` it are one order (decision 129), and `:tasks`
    for the timed tasks, the continuous task's place among them no order, since it is
    never due and takes part in no tie (decision 129), `names` every name there in its
    new order;
  - the wiring is derived again from the configuration started, so a var_input's new
    connection is read at its instance's next scan.

  **Held outputs** (decisions 20 and 58). A global the configuration a step stops drives,
  where a connection copies out a var_output its program writes (`Logex.Walk.writes/1`) or
  a program writes it through a var_external, and the configuration it starts declares
  and does not drive, holds its value, and every step of that direction reports it,
  `{:held, global, value}`, its value in the resource, which is what the next cycle's
  outputs give for an output point. A connection whose var_output the program no longer
  writes copies out a frozen value, so its point holds too. Each kept instance's own
  var_outputs come by path beside it, as `Logex.Edit` reports them, so a held point is
  named both as the point the operator sees and as the output the programmer changed.
  Test, its forecast and assemble report what the original drives and the candidate
  does not; untest, and cancel after an untest, the reverse. Both are read from the two
  configurations alone, once at accept.

  **Assemble** (from test) and **cancel** (after an untest) are not switches: each prunes
  the resource to the configuration it keeps, each kept instance by its type's plan, by
  path, as `Logex.Edit` prunes one; every instance set aside, `{:instance_pruned, name,
  type}`; and every global the kept configuration does not declare, `{:pruned, name,
  value}`. Since decision 315 each prune drops, besides, whatever a kept instance holds
  that its running program does not declare, at any depth, whatever left it there, a
  tag an edit this one superseded switched in among it, `{:pruned, "m1.spare", 4}`, by
  its path as `Logex.Edit`'s kind, where until then only the type's plan pruned it, so an
  instance the edit retyped kept such a tag until a restart. Cancel from accept changes
  nothing but the resource's generation, which it moves on by one (decision 64), and
  reports `[]`, so what a superseded edit left stays, unused, for the next edit's first
  test, its next prune, or a restart, to drop.

  **A restart during an edit** (decision 65) restarts the instances of the configuration
  the resource runs, drops those set aside and the globals only the other configuration
  declares, and keeps the generation and the edit's stage: the next switch starts again
  what it dropped, `:instance_added` and `:added`.

  **The report** is a list of `{kind, name, detail}`, sorted, at most one entry per kind
  and name, the kinds an open set a host must tolerate. A global, task or instance is
  named by its own name, since they share one namespace, and anything inside an instance
  by its path. Each kept instance's switch and prune give `Logex.Edit`'s kinds, by path,
  `{:preset, "m1.t1", {5000, 6000}}`, as its moduledoc's table says, among them a member
  input no logic of the instance's program writes any more, `{:unwritten, "m1.lube.r", 1}`
  (decision 96), and since M6-7 a path of the instance whose retention the edit changes,
  `{:retain_added, "t1.boxes", %{...}}`, beside a global's by its name (decision 302).
  The configuration's:

  | Kind | Name | Detail | Given by |
  |---|---|---|---|
  | `:instance_added` | instance | its program type: started as `Logex.Runtime.instance/1` starts it, holding no var_external | a switch |
  | `:instance_stopped` | instance | its program type: set aside, its state kept unused | a switch |
  | `:instance_back` | instance | its program type: back from aside as it was set aside, its timers resumed | a switch |
  | `:instance_pruned` | instance | its program type: its state dropped | assemble, cancel; a first test, what a superseded edit set aside |
  | `:added` | global | the initial value it starts at | a switch |
  | `:initial_changed` | global | `{old, new}`: the running value is kept until a restart | a switch |
  | `:retain_added` | global | the value it holds, which a warm restart now keeps; nothing is written (decision 302) | a switch |
  | `:retain_removed` | global | the value it holds, which a warm restart no longer keeps; nothing is written (decision 302) | a switch |
  | `:pruned` | global | the value it had | assemble, cancel; a first test, what a superseded edit kept unused |
  | `:held` | global | its value, which nothing drives any more | every step |
  | `:interval` | task | `{old, new}`, in ms | a switch |
  | `:next_due` | task | `{from, to}`, in ms: decision 40's move | a switch |
  | `:priority` | task | `{old, new}` | a switch |
  | `:watchdog` | task | `{old, new}`, in ms, 500 for none: the runner's to read (decision 129) | a switch |
  | `:joined` | `instance.tag` | `{own, global}`: the own value dropped, nil for none, and the global it reads | a switch |
  | `:left` | `instance.tag` | the global's value, now the instance's own | a switch |
  | `:order` | task, `:none` or `:tasks` | the names there in their new order | a switch |

  The writes a report lists, applied to the resource before its step, give the resource
  after it: OE-1's by path, as `Logex.Edit`'s moduledoc lists them, and `:instance_added`,
  `:instance_stopped`, `:instance_back`, `:instance_pruned`, `:added`, `:pruned`,
  `:next_due`, `:joined` and `:left`, with each kept instance's `switched` and block list
  as OE-1 states them, and the `now` of a kept instance and of one back from aside the
  resource's (decisions 56 and 57). A first test's `:instance_pruned` and `:pruned` are
  written before the rest, since what they drop is gone before the switch, which may start
  it again under the same name (decision 66). The other kinds state facts.

  **Host mistakes** raise `ArgumentError`, each with a message a test pins. Accept checks
  the runtime, with `Logex.Runtime`'s own message, and since decision 200 each program
  type it runs, as `Logex.Configuration.check/1` checks a program edited by hand after it
  compiled (`Logex.Program.edited_by_hand/1`), in name order; then its `elapsed_ms`, a non-negative
  integer, in `Logex.Runtime.cycle/3`'s words; then the candidate, as
  `Logex.Runtime.start/1` checks a configuration, with its messages, a candidate that
  `Logex.Configuration.check/1` refuses among them (decision 63); then that the candidate
  keeps the running configuration's name. A step checks the edit, then the runtime, then
  a switch's `elapsed_ms`, as accept does, then that the edit is current, its generation and then the configuration the resource runs,
  then the stage, in OE-1's words. The generation (decision 60) is moved on by every step
  but accept, so a step on an edit that has ended, or one another edit has stepped past,
  is refused. Two resources started from one configuration are equal, plain data, so an
  edit accepted on one may be stepped on the other while their generations agree: that is
  outside the contract, as is an edit built or changed by hand.
  """

  alias Logex.{Configuration, Declarations, Diagnostic, FbType, Instance, Program, Runtime, Tag}
  alias Logex.Walk
  alias Logex.Edit.Plan

  @enforce_keys [:original, :candidate, :stage, :plans, :held, :records, :generation]
  defstruct [:original, :candidate, :stage, :plans, :held, :records, :generation]

  @opaque t :: %__MODULE__{}

  @doc """
  Accepts `candidate` against `runtime`, the resource that runs the original:
  `{:ok, edit, forecast}`, the forecast being the report a test taken `elapsed_ms` after
  the resource's last cycle would give (decision 139), or
  `{:error, diagnostics}` when the candidate changes what may change only with a restart.
  Nothing is changed.
  """
  def accept(runtime, candidate, elapsed_ms \\ 0) do
    %Runtime{config: original} = runtime = runtime!(runtime)
    edited!(original)
    at = at!(runtime, elapsed_ms)
    candidate!(candidate)
    named!(original, candidate)

    accepted(
      refused(original, candidate) ++ retyped(original, candidate),
      {runtime, at},
      candidate
    )
  end

  defp accepted(
         [],
         {%Runtime{config: original, generation: generation} = runtime, at},
         candidate
       ) do
    edit = %__MODULE__{
      original: original,
      candidate: candidate,
      stage: :accepted,
      plans: plans(original, candidate),
      held: %{test: held(original, candidate), untest: held(candidate, original)},
      records: %{},
      generation: generation
    }

    {_changes, _records, forecast} = switch(edit, {runtime, at}, :test)
    {:ok, edit, forecast}
  end

  defp accepted(diagnostics, _runtime, _candidate), do: {:error, diagnostics}

  @doc """
  Runs the candidate in the resource, from accept or after an untest, `elapsed_ms` after
  the resource's last cycle, the step's time for decision 139.
  """
  def test(edit, runtime, elapsed_ms \\ 0) do
    edit = edit!(edit)
    runtime = runtime!(runtime)
    at = at!(runtime, elapsed_ms)
    tested(edit, {current!(edit, runtime), at})
  end

  defp tested(%__MODULE__{stage: stage} = edit, timed) when stage in [:accepted, :untested],
    do: stepped(edit, timed, :test, :testing)

  defp tested(edit, _timed), do: stage!(edit, "test", "accepted or untested")

  @doc """
  Runs the original in the resource again, from test, `elapsed_ms` after the resource's
  last cycle, as `test/3` takes it.
  """
  def untest(edit, runtime, elapsed_ms \\ 0) do
    edit = edit!(edit)
    runtime = runtime!(runtime)
    at = at!(runtime, elapsed_ms)
    untested(edit, {current!(edit, runtime), at})
  end

  defp untested(%__MODULE__{stage: :testing} = edit, timed),
    do: stepped(edit, timed, :untest, :untested)

  defp untested(edit, _timed), do: stage!(edit, "untest", "under test")

  # A switch, written into the resource by Logex.Runtime.edited/2, which moves its
  # generation on; the edit expects the new one.
  defp stepped(edit, {runtime, _at} = timed, direction, stage) do
    {changes, records, report} = switch(edit, timed, direction)
    %Runtime{generation: generation} = runtime = Runtime.edited(runtime, changes)
    {%{edit | stage: stage, records: records, generation: generation}, runtime, report}
  end

  @doc """
  Keeps the candidate, from test, and ends the edit: what only the original has is pruned.
  Returns the candidate, the configuration the resource runs from now on.
  """
  def assemble(edit, runtime) do
    edit = edit!(edit)
    assembled(edit, current!(edit, runtime!(runtime)))
  end

  defp assembled(%__MODULE__{stage: :testing} = edit, runtime) do
    {runtime, report} = prune(edit, runtime, :test)
    {edit.candidate, runtime, report}
  end

  defp assembled(edit, _runtime), do: stage!(edit, "assemble", "under test")

  @doc """
  Keeps the original and ends the edit: from accept, the resource unchanged but for its
  generation, and the report `[]`; after an untest, what only the candidate has pruned.
  Returns the original.
  """
  def cancel(edit, runtime) do
    edit = edit!(edit)
    cancelled(edit, current!(edit, runtime!(runtime)))
  end

  defp cancelled(%__MODULE__{stage: :accepted} = edit, runtime),
    do: {edit.original, Runtime.edited(runtime, %{}), []}

  defp cancelled(%__MODULE__{stage: :untested} = edit, runtime) do
    {runtime, report} = prune(edit, runtime, :untest)
    {edit.original, runtime, report}
  end

  defp cancelled(edit, _runtime), do: stage!(edit, "cancel", "accepted or untested")

  @doc "The configuration the resource runs now: the candidate under test, the original otherwise."
  def running(edit), do: run(edit!(edit))

  defp run(%__MODULE__{stage: :testing, candidate: candidate}), do: candidate
  defp run(%__MODULE__{original: original}), do: original

  @doc "Where the edit stands: `:accepted`, `:testing` or `:untested`."
  def stage(edit), do: edit!(edit).stage

  # ---- host mistakes ----------------------------------------------------------------------

  # The runtime's own checks, and so its messages: overlaps/1 checks the resource and
  # changes nothing.
  defp runtime!(runtime) do
    Runtime.overlaps(runtime)
    runtime
  end

  # Decision 200: the program types the resource runs, each checked once again as
  # `Logex.Configuration.check/1` checked them where the resource started
  # (`Logex.Program.edited_by_hand/1`, decisions 182 and 197), in name order, so that one a
  # host changed by hand in a resource after its start is refused before an edit plans
  # from it, a line each in one message, in the words every entry point gives.
  defp edited!(%Configuration{programs: programs}) do
    lines = programs |> Enum.sort() |> Enum.flat_map(fn {_, p} -> Program.edited_by_hand(p) end)
    unedited!(lines)
  end

  defp unedited!([]), do: :ok
  defp unedited!(lines), do: raise(ArgumentError, Enum.join(lines, "\n"))

  # Decision 139: the step's time, `elapsed_ms` after the resource's last cycle, counted as
  # Logex.Runtime.cycle/3 counts it, in its words; 0, the resource's own time, by default.
  defp at!(%Runtime{now: now}, elapsed_ms) when is_integer(elapsed_ms) and elapsed_ms >= 0,
    do: now + elapsed_ms

  defp at!(_runtime, other),
    do:
      raise(
        ArgumentError,
        "elapsed_ms must be a non-negative integer of milliseconds, got: #{inspect(other)}"
      )

  # Decision 63: one rule for handing a configuration to a running resource, start/1's, its
  # messages for something that is no configuration, for a host mistake check/1 raises, and
  # for every diagnostic check/1 gives.
  defp candidate!(candidate), do: Runtime.start(candidate)

  defp named!(%Configuration{name: name}, %Configuration{name: name}), do: :ok

  defp named!(%Configuration{name: running}, %Configuration{name: candidate}),
    do:
      raise(
        ArgumentError,
        "the candidate is `#{candidate}`, but the running configuration is `#{running}`: " <>
          "an edit keeps the configuration's name"
      )

  defp edit!(%__MODULE__{} = edit), do: edit

  defp edit!(other),
    do:
      raise(
        ArgumentError,
        "expected a %Logex.Configuration.Edit{} from Logex.Configuration.Edit.accept/2, " <>
          "got: #{inspect(other)}"
      )

  # Decision 60: the generation the edit expects, then the configuration the resource runs.
  defp current!(
         %__MODULE__{generation: generation} = edit,
         %Runtime{generation: generation} = runtime
       ),
       do: configured!(run(edit) == runtime.config, runtime)

  defp current!(%__MODULE__{generation: expected}, %Runtime{generation: generation}),
    do:
      raise(
        ArgumentError,
        "this edit expects the resource at generation #{expected}, but it is at generation " <>
          "#{generation}: the edit has ended, or another edit has stepped since"
      )

  defp configured!(true, runtime), do: runtime

  defp configured!(false, _runtime),
    do:
      raise(
        ArgumentError,
        "this edit is of another configuration than the one the resource runs: accept the " <>
          "candidate against this resource"
      )

  defp stage!(%__MODULE__{stage: stage}, step, wanted),
    do: raise(ArgumentError, "#{step} takes an edit #{wanted}, but this one is #{shown(stage)}")

  defp shown(:testing), do: "under test"
  defp shown(stage), do: Atom.to_string(stage)

  # ---- accept: what may change only with a restart (§4.9) ---------------------------------

  # The configuration's own refusals: each element of the candidate's in line order, then
  # each only the running configuration has, its tasks and then its located globals, each
  # in its order there, whatever their lines in its text. A configuration's lines
  # are all numbers, from text, or all nil, from Elixir (Logex.Configuration.check/1), and
  # the sort is stable, so one from Elixir keeps the candidate's order. Each in the
  # candidate's file.
  defp refused(%Configuration{} = original, %Configuration{file: file} = candidate) do
    tasks = by_name(original.tasks)
    globals = by_name(original.globals)
    instances = by_name(original.instances)
    kept_tasks = by_name(candidate.tasks)
    kept_globals = by_name(candidate.globals)
    untimed = {untimed(original), untimed(candidate), rekinded(tasks, candidate.tasks)}

    lined =
      for(t <- candidate.tasks, m <- task(Map.get(tasks, t.name), t), do: {t.line, m}) ++
        for(g <- candidate.globals, m <- global(Map.get(globals, g.name), g), do: {g.line, m}) ++
        for(
          i <- candidate.instances,
          m <- moved(Map.get(instances, i.name), i, untimed),
          do: {i.line, m}
        )

    gone =
      for(t <- original.tasks, not is_map_key(kept_tasks, t.name), do: removed_task(t)) ++
        for(
          g <- original.globals,
          g.at != nil,
          not is_map_key(kept_globals, g.name),
          do: removed_point(g)
        )

    for {line, message} <-
          Enum.sort_by(lined, &elem(&1, 0)) ++ for(m <- gone, do: {nil, m}),
        do: %Diagnostic{stage: :edit, file: file, line: line, message: message}
  end

  defp by_name(elements), do: Map.new(elements, &{&1.name, &1})

  defp task(nil, %Configuration.Task{name: name}),
    do: ["task `#{name}` is added: a task is added only with a restart"]

  # Decision 129: a task made continuous, or a continuous one made timed, is refused as one
  # change, its kind's, and its single and interval are then not compared.
  defp task(
         %Configuration.Task{continuous: same} = was,
         %Configuration.Task{continuous: same} = task
       ),
       do: single(was.single, task.single, task.name) ++ interval(was, task)

  defp task(was, task),
    do: [
      "task `#{task.name}` is #{kind(was)} in the running configuration and #{kind(task)} " <>
        "in the candidate: a task's kind changes only with a restart"
    ]

  defp kind(%Configuration.Task{continuous: true}), do: "continuous"
  defp kind(%Configuration.Task{single: nil}), do: "periodic"
  defp kind(%Configuration.Task{}), do: "an event task"

  defp single(same, same, _name), do: []

  defp single(was, single, name),
    do: [
      "task `#{name}`'s single changes from #{named(was)} to #{named(single)}: a task's " <>
        "single changes only with a restart"
    ]

  defp named(nil), do: "none"
  defp named(name), do: "`#{name}`"

  # An event task, with the same single in both, whose interval is added or removed. A
  # periodic task always has an interval, so its own changes, decision 40's.
  defp interval(%{single: single, interval: nil}, %{single: single, interval: interval} = task)
       when single != nil and interval != nil,
       do: [event_interval(task.name, "added")]

  defp interval(%{single: single, interval: interval}, %{single: single, interval: nil} = task)
       when single != nil and interval != nil,
       do: [event_interval(task.name, "removed")]

  defp interval(_was, _task), do: []

  defp event_interval(name, how),
    do:
      "task `#{name}` has a single, and its interval is #{how}: an event task's interval " <>
        "is added or removed only with a restart"

  defp removed_task(%Configuration.Task{name: name, line: line}),
    do: "task `#{name}`#{running_line(line)} is removed: a task is removed only with a restart"

  defp running_line(nil), do: ""
  defp running_line(line), do: " (line #{line} of the running configuration)"

  defp global(nil, %Configuration.Global{at: nil}), do: []

  defp global(nil, %Configuration.Global{name: name} = global),
    do: ["`#{name}` at #{span(global)} is added: #{located()}"]

  # Decision 244: a located array whose range changes, grown, shrunk, moved, made a scalar
  # or unlocated, `zone_t real[8]` to `real[10]` at `card.i.0`, is refused once, for the
  # range its elements take, where until then it was refused for its type too; the range's
  # refusal says it all, since a restart takes both. One whose range is kept is still told
  # its type, `real[8]` to `int[8]`, and an unlocated array grown is told its type alone
  # (decision 157).
  defp global(%Configuration.Global{} = was, %Configuration.Global{} = global),
    do: kept_global(span(was), span(global), {was, global})

  defp kept_global(same, same, {was, global}), do: typed(was.type, global.type, global.name)

  defp kept_global(was_at, at, {%{type: {:array, _, _}} = was, global}) when was.at != nil,
    do: located(was_at, at, global.name)

  defp kept_global(was_at, at, {_was, %{type: {:array, _, _}} = global})
       when global.at != nil,
       do: located(was_at, at, global.name)

  defp kept_global(was_at, at, {was, global}),
    do: typed(was.type, global.type, global.name) ++ located(was_at, at, global.name)

  defp typed(same, same, _name), do: []

  defp typed(was, type, name),
    do: [
      "`#{name}` is #{Declarations.a_global(was)} in the running configuration and " <>
        "#{Declarations.a_type(type)} in the " <>
        "candidate: a global's type changes only with a restart"
    ]

  defp located(same, same, _name), do: []

  defp located(was, at, name),
    do: [
      "`#{name}` #{where(was, at)} in the candidate: #{located()}"
    ]

  defp where(nil, at),
    do: "has no location in the running configuration and is at #{at}"

  defp where(was, nil),
    do: "is at #{was} in the running configuration and has no location"

  defp where(was, at), do: "is at #{was} in the running configuration and at #{at}"

  # Where a global is, as an edit's refusal names it: its location, or, for a located
  # array (M5-13, decision 156), the range its elements occupy, `card.i.0` to `card.i.7`,
  # so that an array grown or moved is told the points it would take; nil for none.
  defp span(%Configuration.Global{at: nil}), do: nil

  defp span(%Configuration.Global{at: at, type: {:array, _type, dims}}),
    do: ranged(Configuration.location(at), dims, at)

  defp span(%Configuration.Global{at: at}), do: "`#{at}`"

  defp ranged({:ok, {device, io, fields}}, dims, _at) do
    points = Logex.Array.points("", dims, fields)
    {_, _, from} = hd(points)
    {_, _, to} = List.last(points)
    "`#{Enum.join([device, io | from], ".")}` to `#{Enum.join([device, io | to], ".")}`"
  end

  defp ranged(:error, _dims, at), do: "`#{at}`"

  defp located, do: "located I/O changes only with a restart"

  defp removed_point(%Configuration.Global{name: name, line: line} = global),
    do: "`#{name}` at #{span(global)}#{running_line(line)} is removed: #{located()}"

  # An instance both configurations run as one program type, on another task. One retyped
  # is a new instance, which may run on any task (decision 61). Decision 129: an instance
  # with no task and one `with` the continuous task run in one place, so each is compared
  # as it runs, `with main` added or taken away no move, and one moved to or from the
  # continuous task is told it by the continuous task's name.
  defp moved(
         %Configuration.Instance{type: type, task: was},
         %Configuration.Instance{type: type} = i,
         {was_untimed, untimed, rekinded}
       ),
       do:
         runs_on(
           MapSet.member?(rekinded, was) or MapSet.member?(rekinded, i.task),
           {runs(was, was_untimed), runs(i.task, untimed)},
           i
         )

  defp moved(_added_or_retyped, _instance, _untimed), do: []

  # The tasks made continuous or timed, whose own refusal is the one mistake: an instance
  # that names one is not told it moved as well.
  defp rekinded(was, tasks),
    do:
      MapSet.new(
        for %{name: name, continuous: continuous} <- tasks,
            match?(%{continuous: other} when other != continuous, Map.get(was, name)),
            do: name
      )

  defp runs_on(true, _places, _instance), do: []
  defp runs_on(false, {was, task}, instance), do: placed(was, task, instance)

  defp placed(same, same, _instance), do: []

  # With the untimed instances in both, whatever the continuous task is called: a change of
  # the continuous task's line is the task's own refusal, one mistake one message.
  defp placed({:untimed, _was}, {:untimed, _now}, _instance), do: []

  defp placed(was, task, i),
    do: [
      "`#{i.name}` runs #{with_task(was)} in the running configuration and " <>
        "#{with_task(task)} in the candidate: an instance moves to another task only " <>
        "with a restart"
    ]

  # Where an instance runs: on its timed task, or with the untimed instances, under the
  # continuous task's name, or `:none` where none is declared.
  defp runs(nil, untimed), do: {:untimed, untimed}
  defp runs(untimed, untimed), do: {:untimed, untimed}
  defp runs(task, _untimed), do: task

  defp untimed(%Configuration{tasks: tasks}), do: Enum.find_value(tasks, :none, &continuous/1)

  defp continuous(%Configuration.Task{continuous: true, name: name}), do: name
  defp continuous(_timed), do: nil

  defp with_task({:untimed, :none}), do: "with no task"
  defp with_task({:untimed, task}), do: "with `#{task}`"
  defp with_task(task), do: "with `#{task}`"

  # Fix F5: each program type an instance runs as that type in both, once, in the order of
  # its first such instance in the candidate, refused by Logex.Edit's own rules in its own
  # file.
  defp retyped(original, candidate),
    do:
      Enum.flat_map(
        kept_types(original, candidate),
        &Plan.retyped(Map.fetch!(original.programs, &1), Map.fetch!(candidate.programs, &1))
      )

  defp kept_types(original, candidate) do
    types = Map.new(original.instances, &{&1.name, &1.type})

    Enum.uniq(for %{name: name, type: type} <- candidate.instances, types[name] == type, do: type)
  end

  # One plan per kept program type and direction, its var_externals the globals (fix F5).
  defp plans(original, candidate),
    do:
      Map.new(kept_types(original, candidate), fn type ->
        {type,
         Plan.plans(
           Map.fetch!(original.programs, type),
           Map.fetch!(candidate.programs, type),
           :globals
         )}
      end)

  # ---- held outputs (decision 20) ---------------------------------------------------------

  # The globals a configuration drives, which the configuration stopped drives and the one
  # started, which declares them, does not: each holds its value, and every step of that
  # direction reports it, beside each kept instance's own var_outputs by path (decision 58).
  # Read from the two configurations alone, once at accept, as a plan is.
  #
  # Since decision 232 an array the stopped configuration drives whole, where the started
  # one drives some of its elements, holds each element it no longer drives, each by its
  # name, `speeds[3]`, the report sorting them with its other rows; one it drives none of
  # holds whole, as before.
  defp held(from, to) do
    driven = drives(to)
    keep = by_name(to.globals)

    for name <- Enum.sort(Map.keys(drives(from))),
        [array | _] = :binary.split(name, "["),
        is_map_key(keep, array),
        not is_map_key(driven, name),
        not is_map_key(driven, array),
        held <- undriven(Map.fetch!(keep, array), name, driven),
        do: held
  end

  defp undriven(%Configuration.Global{name: name, type: {:array, _type, dims}}, name, driven) do
    elements = for index <- Logex.Array.indexes(dims), do: Logex.Array.name(name, index)
    some_driven(Enum.split_with(elements, &is_map_key(driven, &1)), name)
  end

  defp undriven(_global, name, _driven), do: [name]

  defp some_driven({[], _held}, name), do: [name]
  defp some_driven({_driven, held}, _name), do: held

  # A global is driven where a connection copies out a var_output its program writes
  # (Logex.Walk.writes/1), or a program writes it through a var_external. A connection whose
  # var_output the program no longer writes copies out a frozen value: the point holds. A
  # connection names a var_input or a var_output (Logex.Configuration.check/1), and no
  # logic writes a var_input (Logex.Compiler), so a member written is a var_output. Each
  # program type's writes are read once. Since decision 232 an element of an array
  # var_output at a connection's near end, `b.o[1]`, drives where its program writes that
  # element, or its array through a tag subscript (`Logex.Walk.element_writes/1`), where
  # until then no element member drove anything.
  defp drives(%Configuration{programs: programs, instances: instances, connections: connections}) do
    types = Map.new(instances, &{&1.name, &1.type})

    writes =
      Map.new(Enum.uniq(Map.values(types)), &{&1, type_writes(Map.fetch!(programs, &1))})

    copied =
      for %Configuration.Connection{instance: instance, member: member, to: global} <-
            connections,
          is_binary(global),
          member_written?(Map.fetch!(writes, Map.fetch!(types, instance)), member),
          do: driven_name(global)

    through =
      for {type, {written, _elements}} <- writes,
          {name, %Tag{section: :var_external}} <- Map.fetch!(programs, type).tags,
          is_map_key(written, name),
          do: name

    Map.new(copied ++ through, &{&1, true})
  end

  defp type_writes(program),
    do: {Map.new(Walk.writes(program)), Map.new(Walk.element_writes(program))}

  defp member_written?({writes, elements}, member),
    do: written_member(Logex.Array.split(member), member, {writes, elements})

  defp written_member(nil, member, {writes, _elements}), do: is_map_key(writes, member)

  defp written_member({array, _subscripts}, member, {_writes, elements}),
    do: is_map_key(elements, driven_name(member)) or is_map_key(elements, array)

  # Decision 223: a connection may drive an element of a global array, `speeds[1]`, named by
  # its subscripts' values, held and reported as that element.
  defp driven_name(global), do: element_name(Logex.Array.split(global), global)

  defp element_name(nil, global), do: global

  defp element_name({array, subscripts}, _global),
    do: Logex.Array.name(array, for(text <- subscripts, do: elem(Logex.Array.subscript(text), 1)))

  defp holding(names, globals),
    do: for(name <- names, do: {:held, name, held_value(Logex.Array.split(name), name, globals)})

  defp held_value(nil, name, globals), do: Map.fetch!(globals, name)

  defp held_value({array, subscripts}, _name, globals),
    do:
      Logex.Array.fetch(
        Map.fetch!(globals, array),
        for(text <- subscripts, do: elem(Logex.Array.subscript(text), 1))
      )

  # ---- a switch, between two cycles -------------------------------------------------------

  defp sides(edit, :test), do: {edit.original, edit.candidate}
  defp sides(edit, :untest), do: {edit.candidate, edit.original}

  # The switch from the configuration the direction stops, `from`, to the one it starts,
  # `to`, over the resource as it is: the pieces of the resource it gives, which
  # Logex.Runtime.edited/2 writes, each kept instance's record, and the report. Globals
  # first, so that a kept instance's merge sees every global the configuration started
  # declares.
  defp switch(edit, {%Runtime{} = runtime, at}, direction) do
    {from, to} = sides(edit, direction)
    first? = direction == :test and edit.stage == :accepted
    {left, aside, dropped} = superseded(first?, from, runtime)
    {globals, reports} = globals(from, to, left)

    context = %{
      first?: first?,
      direction: direction,
      edit: edit,
      runtime: runtime,
      aside: aside,
      globals: globals
    }

    froms = Map.new(from.instances, &{&1.name, &1.type})
    tos = Map.new(to.instances, &{&1.name, &1.type})

    stopped =
      for %{name: name, type: type} <- from.instances,
          Map.get(tos, name) != type,
          do: {name, Map.fetch!(runtime.instances, name)}

    {instances, records, started} =
      Enum.reduce(to.instances, {%{}, edit.records, []}, fn instance, acc ->
        instance({instance, Map.get(froms, instance.name), from, to}, context, acc)
      end)

    started_names = for %{name: name, type: type} <- to.instances, froms[name] != type, do: name

    {tasks, timed} = tasks(from, to, runtime, at)

    changes = %{
      config: to,
      globals: globals,
      instances: instances,
      aside: Map.merge(Map.drop(aside, started_names), Map.new(stopped)),
      tasks: tasks
    }

    report =
      dropped ++
        reports ++
        started ++
        for({name, state} <- stopped, do: {:instance_stopped, name, state.type}) ++
        timed ++ holding(Map.fetch!(edit.held, direction), globals)

    {changes, records, Enum.sort(report)}
  end

  # Decision 66: at an edit's first switch the resource runs the original and holds nothing
  # of this edit's, so what it holds that the original does not declare, an instance set
  # aside or a global kept unused, was left by an edit this one superseded, under another
  # candidate: it is dropped before the switch, as assemble prunes it, `:instance_pruned` and
  # `:pruned`, so that nothing comes back, or starts over a value, that this edit's
  # programs never ran.
  defp superseded(false, _from, %Runtime{globals: globals, aside: aside}),
    do: {globals, aside, []}

  defp superseded(true, %Configuration{globals: declared}, %Runtime{} = runtime) do
    keep = by_name(declared)

    {globals, gone} =
      Map.split_with(runtime.globals, fn {name, _value} -> is_map_key(keep, name) end)

    {globals, %{},
     for({name, value} <- gone, do: {:pruned, name, value}) ++
       for({name, state} <- runtime.aside, do: {:instance_pruned, name, state.type})}
  end

  # A kept instance, of one program type in both: decision 45's merge by the var_externals
  # of the program stopped, the type's plan, and the split by those of the program started,
  # with any of the program stopped's that the one started does not declare, so no copy of
  # a global stays in the state (decision 49). The switch resumes a timer from the
  # resource's clock, and gives the instance that clock (decision 56).
  defp instance(
         {%{name: name, type: type}, type, from, to},
         context,
         {instances, records, reports}
       ) do
    stops = Map.fetch!(from.programs, type)
    starts = Map.fetch!(to.programs, type)

    merged =
      merged(Map.fetch!(context.runtime.instances, name), externals(stops), context.globals)

    plan = Map.fetch!(Map.fetch!(context.edit.plans, type), context.direction)
    record = Map.get(records, name, Plan.record())

    {state, record, report} =
      Plan.switch(plan, record, merged, context.first?, context.runtime.now)

    state = split(state, externals(starts) ++ undeclared(externals(stops), starts))
    shared = sections(stops, starts, merged.env, context.globals)

    {Map.put(instances, name, state), Map.put(records, name, record),
     for({kind, path, detail} <- report ++ shared, do: {kind, name <> "." <> path, detail}) ++
       reports}
  end

  # An instance the configuration started runs that the one stopped does not, as this
  # type: back from aside, where an earlier switch of this edit set it aside, or a new one,
  # started as Logex.Runtime.instance/1 starts it, holding no var_external, as start/1
  # starts one (decision 43).
  defp instance({%{name: name, type: type}, _other, _from, to}, context, acc),
    do:
      back(
        Map.fetch(context.aside, name),
        {name, Map.fetch!(to.programs, type)},
        context,
        acc
      )

  # Decision 55, and decision 45 the other way: a var_external of the program started that
  # the program stopped declares otherwise, or not at all, has its own value dropped at the
  # split, nil where it had none, and reads its global from the next scan, `:joined`; one
  # of the program stopped that the one started declares as its own tag keeps the global's
  # value, merged in, as its own, `:left`. No global is written.
  defp sections(stops, starts, env, globals) do
    {was, now} = {Map.new(externals(stops), &{&1, true}), Map.new(externals(starts), &{&1, true})}

    for(
      name <- Map.keys(now),
      not is_map_key(was, name),
      do: {:joined, name, {Map.get(env, name), Map.fetch!(globals, name)}}
    ) ++
      for(
        name <- Map.keys(was),
        not is_map_key(now, name),
        is_map_key(starts.tags, name),
        do: {:left, name, Map.fetch!(globals, name)}
      )
  end

  # Decision 57: an instance set aside as one of this type comes back as it was set aside,
  # its `now` the resource's, as a switch gives a kept one (decision 56), and each timer
  # that was timing resumed from the switch, by its path: the edit stopped the instance, not
  # its logic, so the time set aside is not caught up.
  defp back(
         {:ok, %Instance{type: type} = state},
         {name, %Program{name: type} = program},
         context,
         {instances, records, reports}
       ) do
    %Runtime{now: now} = context.runtime
    {env, resumed} = resume(timers(program), state.env, {name, now})

    {Map.put(instances, name, %{state | env: env, now: now}), records,
     [{:instance_back, name, type} | resumed ++ reports]}
  end

  defp back(
         _none,
         {name, %Program{name: type} = program},
         _context,
         {instances, records, reports}
       ) do
    state = split(Runtime.fresh(program), externals(program))
    {Map.put(instances, name, state), records, [{:instance_added, name, type} | reports]}
  end

  # Every timer a program's state holds, at any depth, by its path: each of its tags whose
  # type is a built-in timer, and inside each instance of a user block, each member's in
  # turn, read inside the program's one table of types (decision 53), with the member whose
  # 1 says it is timing (M3-2).
  defp timers(%Program{} = program),
    do:
      for(
        {name, %Tag{type: type}} <- Program.typed_tags(program),
        timer <- timer_paths(type, [name]),
        do: timer
      )

  # M3-1: a built-in that keeps time (Logex.FbType.rules/1); one that keeps none, a
  # counter, has nothing to resume.
  defp timer_paths(%FbType{body: nil} = type, path), do: timing(FbType.rules(type), path)

  defp timer_paths(%FbType{members: members} = type, path),
    do:
      for(
        member <- members,
        inner <- timer_paths(FbType.type_of(type, member), [member.name | path]),
        do: inner
      )

  defp timer_paths(_leaf, _path), do: []

  defp timing(%{kind: :timer, times: times}, path), do: [{Enum.reverse(path), times}]
  defp timing(_keeps_no_time, _path), do: []

  defp resume(timers, env, at),
    do:
      Enum.reduce(timers, {env, []}, fn {path, times}, acc ->
        resumed(get_in(env, path), {path, times}, at, acc)
      end)

  defp resumed(%{"last" => last} = timer, {path, times}, {name, now}, {env, reports})
       when :erlang.map_get(times, timer) == 1 and last < now,
       do:
         {put_in(env, path, %{timer | "last" => now}),
          [{:resumed, Enum.join([name | path], "."), now - last} | reports]}

  defp resumed(_timer, _path, _at, acc), do: acc

  defp merged(%{env: env} = state, externals, globals),
    do: %{state | env: Map.merge(env, Map.take(globals, externals))}

  defp split(%{env: env} = state, externals), do: %{state | env: Map.drop(env, externals)}

  defp undeclared(names, %Program{tags: tags}), do: Enum.reject(names, &is_map_key(tags, &1))

  defp externals(%Program{tags: tags}),
    do: for({name, %Tag{section: :var_external}} <- tags, do: name)

  # Decision 44, and a global's one rule: one the configuration started declares that the
  # resource lacks starts at Logex.Configuration.initial/1, and a kept one whose initial
  # value changed keeps its running value. One only the configuration stopped declares is
  # kept, unused, so an instance set aside finds it if it comes back.
  defp globals(from, to, values) do
    was = by_name(from.globals)

    Enum.reduce(to.globals, {values, []}, fn global, {values, reports} ->
      was = Map.get(was, global.name)

      Map.fetch(values, global.name)
      |> global_moved(was, global, {values, reports})
      |> requalified(was, global)
    end)
  end

  # Decision 302 (the maintainer, 2026-10-29), decision 278's report for a global: a kept
  # global whose qualifier the edit changes from no `retain` to `retain`, or back, is
  # reported by its name with the value it holds, which the next warm restart keeps or no
  # longer keeps, and nothing is written. `non_retain` and none are one, neither retained,
  # so a change between them reports nothing (provisional).
  defp requalified(acc, nil, _global), do: acc

  defp requalified(acc, %Configuration.Global{retain: :retain}, %Configuration.Global{
         retain: :retain
       }),
       do: acc

  defp requalified({values, reports}, %Configuration.Global{retain: :retain}, global),
    do: {values, [{:retain_removed, global.name, requalified_value(values, global)} | reports]}

  defp requalified({values, reports}, _was, %Configuration.Global{retain: :retain} = global),
    do: {values, [{:retain_added, global.name, requalified_value(values, global)} | reports]}

  defp requalified(acc, _was, _global), do: acc

  defp requalified_value(values, global),
    do: reported(global.type, Map.fetch!(values, global.name))

  defp global_moved(:error, _was, global, {values, reports}) do
    value = Configuration.initial(global)

    {Map.put(values, global.name, value),
     [{:added, global.name, reported(global.type, value)} | reports]}
  end

  # Decision 157 (M5-10): the declared initial values are compared exactly, as decision 44
  # takes for a global what decision 29 does for a tag, so that a real's `0` and `0.0` are
  # two values, the running value kept either way.
  # M5-11 (decision 157): an array global's initial list is compared element by element,
  # each element whose declared value changed reported by its name, `limits[2]`, in the
  # elements' order; its type, so its sizes, is the same here, a change refused at accept.
  defp global_moved(
         {:ok, _value},
         %Configuration.Global{type: {:array, _, dims} = type} = was,
         global,
         acc
       ),
       do:
         [
           Logex.Array.indexes(dims),
           Logex.Array.declared(type, was.initial),
           Logex.Array.declared(type, global.initial)
         ]
         |> Enum.zip()
         |> Enum.reduce(acc, fn {index, old, new}, acc ->
           initial_changed(old, new, %{global | name: Logex.Array.name(global.name, index)}, acc)
         end)

  defp global_moved({:ok, _value}, %Configuration.Global{} = was, global, acc),
    do: initial_changed(declared(was), declared(global), global, acc)

  defp global_moved({:ok, _value}, nil, _global, acc), do: acc

  # M5-11: an array global's value is reported as a host is given one, a list, a list of
  # lists for more dimensions.
  defp reported({:array, _type, dims}, value), do: Logex.Array.to_list(value, dims)
  defp reported(_type, value), do: value

  defp declared(%Configuration.Global{initial: nil} = global), do: Configuration.initial(global)
  defp declared(%Configuration.Global{initial: initial}), do: initial

  defp initial_changed(same, same, _global, acc), do: acc

  defp initial_changed(old, new, global, {values, reports}),
    do: {values, [{:initial_changed, global.name, {old, new}} | reports]}

  # Decision 40: a task whose interval changed is next due at min(next_due, now + new),
  # its trigger's last sample kept, so no switch fires an event, `now` the step's time,
  # the resource's own and `elapsed_ms` since, the wall clock's through the runner
  # (decision 139). No task is added or removed, and an event task keeps its interval or
  # its lack of one, both refused at accept, so each task is in both, and one with a
  # changed interval has one in both.
  defp tasks(from, to, %Runtime{tasks: states}, now) do
    was = by_name(from.tasks)

    {states, reports} =
      Enum.reduce(to.tasks, {states, []}, fn task, {states, reports} ->
        old = Map.fetch!(was, task.name)
        retimed(old, task, now, {states, priority(old, task) ++ watchdog(old, task) ++ reports})
      end)

    {states, reports ++ orders(from, to)}
  end

  # A priority is read at each cycle's sort, so a changed one needs no state, and is
  # reported.
  defp priority(%{priority: same}, %{priority: same}), do: []

  defp priority(%{priority: old}, %{name: name, priority: new}),
    do: [{:priority, name, {old, new}}]

  # Decision 129: a watchdog is read by the runner at each step of a round, with no state
  # in the resource, so a changed one needs no state, and is reported, in ms, 500 for none.
  defp watchdog(old, task),
    do: watchdog_moved(Configuration.watchdog(old), Configuration.watchdog(task), task.name)

  defp watchdog_moved(same, same, _name), do: []
  defp watchdog_moved(old, new, name), do: [{:watchdog, name, {old, new}}]

  # Decision 62: the order of the instances on each task, `:none` for the task-less ones,
  # is their execution order, and the order of the tasks breaks ties of priority and due
  # time (decision 11). Neither is state, so a reorder is allowed; one is reported wherever
  # the names both configurations have there change their order among themselves, with
  # every name there in its new order.
  defp orders(from, to) do
    {untimed_was, untimed_now} = {untimed(from), untimed(to)}
    was = Enum.group_by(from.instances, &ordered_on(&1.task, untimed_was), & &1.name)
    now = Enum.group_by(to.instances, &ordered_on(&1.task, untimed_now), & &1.name)

    ordered(:tasks, timed(from.tasks), timed(to.tasks)) ++
      Enum.flat_map(now, fn {task, names} -> ordered(task, Map.get(was, task, []), names) end)
  end

  # Decision 129: the continuous task is never due and takes part in no tie, so its
  # place among the task lines is no order; the tasks' order is the timed tasks'.
  defp timed(tasks),
    do: for(%Configuration.Task{continuous: false, name: name} <- tasks, do: name)

  # Decision 129: the untimed instances, with no task or `with` the continuous task, are
  # one order, under its name, or `:none` where none is declared.
  defp ordered_on(task, untimed), do: untimed_key(runs(task, untimed))

  defp untimed_key({:untimed, untimed}), do: untimed
  defp untimed_key(task), do: task

  defp ordered(name, was, now) do
    both = Map.new(was, &{&1, true})
    kept = Map.new(now, &{&1, true})

    reorder(
      Enum.filter(was, &is_map_key(kept, &1)) == Enum.filter(now, &is_map_key(both, &1)),
      name,
      now
    )
  end

  defp reorder(true, _name, _names), do: []
  defp reorder(false, name, names), do: [{:order, name, names}]

  defp retimed(%{interval: same}, %{interval: same}, _now, acc), do: acc

  defp retimed(%{interval: old}, %{name: name, interval: new}, now, {states, reports}) do
    %{next_due: next} = state = Map.fetch!(states, name)
    due = min(next, now + new)

    {Map.put(states, name, %{state | next_due: due}),
     [{:interval, name, {old, new}} | next_due(name, next, due)] ++ reports}
  end

  defp next_due(_name, same, same), do: []
  defp next_due(name, next, due), do: [{:next_due, name, {next, due}}]

  # ---- assemble and cancel: the prune -----------------------------------------------------

  # Assemble keeps the candidate, from test, and cancel after an untest the original, which
  # runs: each instance kept in both pruned by its type's plan for the direction that last
  # switched to it, by path; every instance set aside pruned whole; and every global the
  # configuration kept does not declare pruned. Nothing is switched, so no one-shot is
  # blocked and no `.pre` moves.
  defp prune(edit, %Runtime{} = runtime, direction) do
    {from, to} = sides(edit, direction)
    froms = Map.new(from.instances, &{&1.name, &1.type})

    {instances, reports} =
      Enum.reduce(to.instances, {runtime.instances, []}, fn instance, acc ->
        pruned(instance, Map.get(froms, instance.name), {edit, direction}, acc)
      end)

    {instances, reports} =
      Enum.reduce(
        to.instances,
        {instances, reports},
        &undeclared(&1, Map.get(froms, &1.name), to.programs, &2)
      )

    keep = by_name(to.globals)

    {globals, gone} =
      Map.split_with(runtime.globals, fn {name, _value} -> is_map_key(keep, name) end)

    report =
      reports ++
        for({name, value} <- gone, do: {:pruned, name, value}) ++
        for({name, state} <- runtime.aside, do: {:instance_pruned, name, state.type}) ++
        holding(Map.fetch!(edit.held, direction), globals)

    {Runtime.edited(runtime, %{instances: instances, globals: globals, aside: %{}}),
     Enum.sort(report)}
  end

  defp pruned(%{name: name, type: type}, type, {edit, direction}, {instances, reports}) do
    plan = Map.fetch!(Map.fetch!(edit.plans, type), direction)
    record = Map.get(edit.records, name, Plan.record())
    {state, report} = Plan.prune(plan, record, Map.fetch!(instances, name))

    {Map.put(instances, name, state),
     for({kind, path, detail} <- report, do: {kind, name <> "." <> path, detail}) ++ reports}
  end

  defp pruned(_added, _other, _context, acc), do: acc

  # Decision 315 (the maintainer, 2026-10-30): every prune drops whatever a kept instance's
  # running program does not declare, at any depth, whatever left it there, an edit this
  # one superseded among them (decision 66), each reported `:pruned` by its path, as
  # Logex.Edit reports a tag a prune drops. An instance of one type in both configurations
  # the type's plan has pruned to exactly what its program declares, at any depth, so only
  # one the edit retyped or added is walked here, and a prune of an edit that retypes
  # nothing costs what it did.
  defp undeclared(%{type: type}, type, _programs, acc), do: acc

  defp undeclared(%{name: name, type: type}, _from, programs, {instances, reports}) do
    program = Map.fetch!(programs, type)
    %Instance{env: env} = state = Map.fetch!(instances, name)
    {env, gone} = declared_only(env, Program.typed_tags(program), name, reports)
    {Map.put(instances, name, %{state | env: env}), gone}
  end

  defp declared_only(env, tags, prefix, reports) do
    {kept, gone} = Map.split_with(env, fn {name, _value} -> is_map_key(tags, name) end)

    reports =
      Enum.reduce(gone, reports, fn {name, value}, acc ->
        [{:pruned, prefix <> "." <> name, value} | acc]
      end)

    Enum.reduce(tags, {kept, reports}, fn {name, %Tag{type: type}}, acc ->
      inside(type, name, prefix, acc)
    end)
  end

  # Inside a user block's instance, or each element of an array of them, the members its
  # type declares; a built-in's members are fixed, and any other value holds none.
  defp inside(type, name, prefix, {env, reports}),
    do: inside_of(type, Map.get(env, name), {name, prefix}, {env, reports})

  defp inside_of(%FbType{body: %Program{}} = type, %{} = map, {name, prefix}, {env, reports}) do
    {map, reports} = members_only(map, type, prefix <> "." <> name, reports)
    {Map.put(env, name, map), reports}
  end

  defp inside_of(
         {:array, %FbType{body: %Program{}} = type, dims},
         values,
         {name, prefix},
         {env, reports}
       )
       when is_tuple(values) do
    {values, reports} = elements(values, dims, {type, prefix <> "." <> name, []}, reports)
    {Map.put(env, name, values), reports}
  end

  defp inside_of(_type, _value, _at, acc), do: acc

  defp members_only(map, %FbType{members: members} = type, path, reports) do
    names = Map.new(members, &{&1.name, FbType.type_of(type, &1)})
    {kept, gone} = Map.split_with(map, fn {name, _value} -> is_map_key(names, name) end)

    reports =
      Enum.reduce(gone, reports, fn {name, value}, acc ->
        [{:pruned, path <> "." <> name, value} | acc]
      end)

    Enum.reduce(names, {kept, reports}, fn {name, type}, {map, reports} ->
      {map, reports} = inside(type, name, path, {map, reports})
      {map, reports}
    end)
  end

  defp elements(values, [count], {type, path, above}, reports) do
    {kept, reports} =
      Enum.map_reduce(0..(count - 1), reports, fn i, reports ->
        members_only(elem(values, i), type, Logex.Array.name(path, above ++ [i]), reports)
      end)

    {List.to_tuple(kept), reports}
  end

  defp elements(values, [count | dims], {type, path, above}, reports) do
    {kept, reports} =
      Enum.map_reduce(0..(count - 1), reports, fn i, reports ->
        elements(elem(values, i), dims, {type, path, above ++ [i]}, reports)
      end)

    {List.to_tuple(kept), reports}
  end
end
