defmodule Logex.Configuration.Edit do
  @moduledoc """
  A staged edit of a running configuration (OE-2, `docs/organisation.md` §4.9, "OE-2's
  design"): a candidate configuration is accepted against the resource that runs the
  original, `%Logex.Runtime{}`, as `Logex.Edit` accepts a program against a lone
  instance (decision 59). Every step is taken between two cycles and returns a report.

      {:ok, edit, forecast} = Logex.Configuration.Edit.accept(runtime, candidate)
      {original, runtime, []} = Logex.Configuration.Edit.cancel(edit, runtime)

  **Accept** reads the running configuration from the resource, so it takes no program to
  run: `accept/2` checks the candidate against it and the resource, and changes nothing.
  Its forecast is the report a test taken now would give: the switch to the candidate,
  computed over the resource as it is and thrown away (decision 27).

  It refuses, as `{:error, diagnostics}` at stage `:edit`, what may change only with a
  restart: a task added or removed; a task's `single` added, removed or changed; an event
  task's interval added or removed; an instance both configurations run as one type moved
  to another task, or to or from none; a global's type; located I/O, a located global
  added, removed or moved, or a location added to or taken from a global, a device being
  only its points' prefix; and, in each program type an instance runs as that type in
  both, every type change `Logex.Edit` refuses, a member's by its path. The configuration's
  own refusals come first, each in the candidate's `file` at its element's line, in line
  order, an element only the running configuration has last, with no line, its line in the
  running configuration named in its text; then each program type's, in the order of its
  first such instance in the candidate, each in that type's own `file` (fix F15). A
  candidate's warnings stop nothing.

  **What may change while running**, which the forecast reports:
  - an instance both configurations run as one program type, a *kept* instance, moves
    through `Logex.Edit`'s per-instance switch, by one plan per program type and
    direction built at accept (fix F5), its reports named by its path, `m1.t1`. Each
    global is merged into its state by the var_externals of the program the switch stops
    (decision 45), and the plan knows the var_externals for globals, so no start rule
    starts one and none is reported as a changed initial value;
  - an instance only the configuration started runs, or one it runs as another program
    type (decision 43), which may run on another task (decision 61), is started as
    `Logex.Runtime.instance/1` starts it, `{:instance_added, name, type}`; one only the configuration stopped runs, or the
    old state of one retyped, is set aside, `{:instance_stopped, name, type}`;
  - a global only the configuration started declares starts at
    `Logex.Configuration.initial/1`, `{:added, name, value}`, at the switch that first
    finds it missing; one only the configuration stopped declares is kept unused; and a
    kept global whose initial value changed keeps its running value until
    `Logex.Runtime.restart/2`, `{:initial_changed, name, {old, new}}` (decision 44);
  - a task whose interval changed is next due at `min(next_due, now + new interval)`
    (decision 40), `{:interval, task, {old, new}}`, and `{:next_due, task, {from, to}}`
    where that moves it; its trigger's last sample is kept, so no switch fires an event.

  **Cancel** from accept ends the edit and changes nothing but the resource's generation,
  which it moves on by one (decision 64), and reports `[]`.

  **The report** is a list of `{kind, name, detail}`, sorted, at most one entry per kind
  and name, the kinds an open set a host must tolerate. A global, task or instance is
  named by its own name, since they share one namespace, and anything inside an instance
  by its path.

  **Host mistakes** raise `ArgumentError`, each with a message a test pins. Accept checks
  the runtime, with `Logex.Runtime`'s own message; then the candidate, as
  `Logex.Runtime.start/1` checks a configuration, with its messages, a candidate that
  `Logex.Configuration.check/1` refuses among them (decision 63); then that the candidate
  keeps the running configuration's name. A step checks the edit, then the runtime, then
  that the edit is current, its generation and then the configuration the resource runs,
  then the stage. The generation (decision 60) is moved on by every step but accept, so a
  step on an edit that has ended, or one another edit has stepped past, is refused. Two
  resources started from one configuration are equal, plain data, so an edit accepted on
  one may be stepped on the other while their generations agree: that is outside the
  contract, as is an edit built or changed by hand.
  """

  alias Logex.{Configuration, Diagnostic, Program, Runtime, Tag}
  alias Logex.Edit.Plan

  @enforce_keys [:original, :candidate, :stage, :plans, :records, :generation]
  defstruct [:original, :candidate, :stage, :plans, :records, :generation]

  @opaque t :: %__MODULE__{}

  @doc """
  Accepts `candidate` against `runtime`, the resource that runs the original:
  `{:ok, edit, forecast}`, the forecast being the report a test taken now would give, or
  `{:error, diagnostics}` when the candidate changes what may change only with a restart.
  Nothing is changed.
  """
  def accept(runtime, candidate) do
    %Runtime{config: original} = runtime = runtime!(runtime)
    candidate!(candidate)
    named!(original, candidate)
    accepted(refused(original, candidate) ++ retyped(original, candidate), runtime, candidate)
  end

  defp accepted([], %Runtime{config: original, generation: generation} = runtime, candidate) do
    edit = %__MODULE__{
      original: original,
      candidate: candidate,
      stage: :accepted,
      plans: plans(original, candidate),
      records: %{},
      generation: generation
    }

    {_changes, _records, forecast} = switch(edit, runtime, :test)
    {:ok, edit, forecast}
  end

  defp accepted(diagnostics, _runtime, _candidate), do: {:error, diagnostics}

  @doc """
  Keeps the original and ends the edit: from accept, the resource unchanged but for its
  generation, and the report `[]`. Returns the original.
  """
  def cancel(edit, runtime) do
    edit = edit!(edit)
    cancelled(edit, current!(edit, runtime!(runtime)))
  end

  defp cancelled(%__MODULE__{stage: :accepted} = edit, runtime),
    do: {edit.original, Runtime.edited(runtime, %{}), []}

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
  # each only the running configuration has, in its order there. A configuration's lines
  # are all numbers, from text, or all nil, from Elixir (Logex.Configuration.check/1), and
  # the sort is stable, so one from Elixir keeps the candidate's order. Each in the
  # candidate's file.
  defp refused(%Configuration{} = original, %Configuration{file: file} = candidate) do
    tasks = by_name(original.tasks)
    globals = by_name(original.globals)
    instances = by_name(original.instances)
    kept_tasks = by_name(candidate.tasks)
    kept_globals = by_name(candidate.globals)

    lined =
      for(t <- candidate.tasks, m <- task(Map.get(tasks, t.name), t), do: {t.line, m}) ++
        for(g <- candidate.globals, m <- global(Map.get(globals, g.name), g), do: {g.line, m}) ++
        for(i <- candidate.instances, m <- moved(Map.get(instances, i.name), i), do: {i.line, m})

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

  defp task(%Configuration.Task{} = was, %Configuration.Task{} = task),
    do: single(was.single, task.single, task.name) ++ interval(was, task)

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

  defp global(nil, %Configuration.Global{name: name, at: at}),
    do: ["`#{name}` at `#{at}` is added: #{located()}"]

  defp global(%Configuration.Global{} = was, %Configuration.Global{} = global),
    do: typed(was.type, global.type, global.name) ++ located(was.at, global.at, global.name)

  defp typed(same, same, _name), do: []

  defp typed(was, type, name),
    do: [
      "`#{name}` is a #{was} global in the running configuration and a #{type} in the " <>
        "candidate: a global's type changes only with a restart"
    ]

  defp located(same, same, _name), do: []

  defp located(was, at, name),
    do: [
      "`#{name}` #{where(was, at)} in the candidate: #{located()}"
    ]

  defp where(nil, at),
    do: "has no location in the running configuration and is at `#{at}`"

  defp where(was, nil),
    do: "is at `#{was}` in the running configuration and has no location"

  defp where(was, at), do: "is at `#{was}` in the running configuration and at `#{at}`"

  defp located, do: "located I/O changes only with a restart"

  defp removed_point(%Configuration.Global{name: name, at: at, line: line}),
    do: "`#{name}` at `#{at}`#{running_line(line)} is removed: #{located()}"

  # An instance both configurations run as one program type, on another task. One retyped
  # is a new instance, which may run on any task (decision 61).
  defp moved(%Configuration.Instance{type: type, task: task}, %Configuration.Instance{
         type: type,
         task: task
       }),
       do: []

  defp moved(
         %Configuration.Instance{type: type, task: was},
         %Configuration.Instance{type: type} = i
       ),
       do: [
         "`#{i.name}` runs #{with_task(was)} in the running configuration and " <>
           "#{with_task(i.task)} in the candidate: an instance moves to another task only " <>
           "with a restart"
       ]

  defp moved(_added_or_retyped, _instance), do: []

  defp with_task(nil), do: "with no task"
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

  # ---- a switch, between two cycles -------------------------------------------------------

  defp sides(edit, :test), do: {edit.original, edit.candidate}
  defp sides(edit, :untest), do: {edit.candidate, edit.original}

  # The switch from the configuration the direction stops, `from`, to the one it starts,
  # `to`, over the resource as it is: the pieces of the resource it gives, which
  # Logex.Runtime.edited/2 writes, each kept instance's record, and the report. Globals
  # first, so that a kept instance's merge sees every global the configuration started
  # declares.
  defp switch(edit, %Runtime{} = runtime, direction) do
    {from, to} = sides(edit, direction)
    {globals, reports} = globals(from, to, runtime.globals)

    context = %{
      first?: direction == :test and edit.stage == :accepted,
      direction: direction,
      edit: edit,
      runtime: runtime,
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

    {tasks, timed} = tasks(from, to, runtime)

    changes = %{
      config: to,
      globals: globals,
      instances: instances,
      aside: Map.merge(runtime.aside, Map.new(stopped)),
      tasks: tasks
    }

    report =
      reports ++
        started ++
        for({name, state} <- stopped, do: {:instance_stopped, name, state.type}) ++ timed

    {changes, records, Enum.sort(report)}
  end

  # A kept instance, of one program type in both: decision 45's merge by the var_externals
  # of the program stopped, then the type's plan.
  defp instance(
         {%{name: name, type: type}, type, from, _to},
         context,
         {instances, records, reports}
       ) do
    stops = Map.fetch!(from.programs, type)

    merged =
      merged(Map.fetch!(context.runtime.instances, name), externals(stops), context.globals)

    plan = Map.fetch!(Map.fetch!(context.edit.plans, type), context.direction)
    record = Map.get(records, name, Plan.record())

    {state, record, report} = Plan.switch(plan, record, merged, context.first?)

    {Map.put(instances, name, state), Map.put(records, name, record),
     for({kind, path, detail} <- report, do: {kind, name <> "." <> path, detail}) ++ reports}
  end

  # An instance the configuration started runs that the one stopped does not, as this
  # type: a new one, started as Logex.Runtime.instance/1 starts it, holding no var_external,
  # as start/1 starts one (decision 43).
  defp instance(
         {%{name: name, type: type}, _other, _from, to},
         _context,
         {instances, records, reports}
       ) do
    state = Runtime.instance(Map.fetch!(to.programs, type))
    {Map.put(instances, name, state), records, [{:instance_added, name, type} | reports]}
  end

  defp merged(%{env: env} = state, externals, globals),
    do: %{state | env: Map.merge(env, Map.take(globals, externals))}

  defp externals(%Program{tags: tags}),
    do: for({name, %Tag{section: :var_external}} <- tags, do: name)

  # Decision 44, and a global's one rule: one the configuration started declares that the
  # resource lacks starts at Logex.Configuration.initial/1, and a kept one whose initial
  # value changed keeps its running value. One only the configuration stopped declares is
  # kept, unused, so an instance set aside finds it if it comes back.
  defp globals(from, to, values) do
    was = by_name(from.globals)

    Enum.reduce(to.globals, {values, []}, fn global, {values, reports} ->
      global_moved(
        Map.fetch(values, global.name),
        Map.get(was, global.name),
        global,
        {values, reports}
      )
    end)
  end

  defp global_moved(:error, _was, global, {values, reports}) do
    value = Configuration.initial(global)
    {Map.put(values, global.name, value), [{:added, global.name, value} | reports]}
  end

  defp global_moved({:ok, _value}, %Configuration.Global{} = was, global, acc),
    do: initial_changed(Configuration.initial(was), Configuration.initial(global), global, acc)

  defp global_moved({:ok, _value}, nil, _global, acc), do: acc

  defp initial_changed(same, same, _global, acc), do: acc

  defp initial_changed(old, new, global, {values, reports}),
    do: {values, [{:initial_changed, global.name, {old, new}} | reports]}

  # Decision 40: a task whose interval changed is next due at min(next_due, now + new),
  # its trigger's last sample kept, so no switch fires an event. No task is added or
  # removed, and an event task keeps its interval or its lack of one, both refused at
  # accept, so each task is in both, and one with a changed interval has one in both.
  defp tasks(from, to, %Runtime{tasks: states, now: now}) do
    was = by_name(from.tasks)

    Enum.reduce(to.tasks, {states, []}, fn task, {states, reports} ->
      retimed(Map.fetch!(was, task.name), task, now, {states, reports})
    end)
  end

  defp retimed(%{interval: same}, %{interval: same}, _now, acc), do: acc

  defp retimed(%{interval: old}, %{name: name, interval: new}, now, {states, reports}) do
    %{next_due: next} = state = Map.fetch!(states, name)
    due = min(next, now + new)

    {Map.put(states, name, %{state | next_due: due}),
     [{:interval, name, {old, new}} | next_due(name, next, due)] ++ reports}
  end

  defp next_due(_name, same, same), do: []
  defp next_due(name, next, due), do: [{:next_due, name, {next, due}}]
end
