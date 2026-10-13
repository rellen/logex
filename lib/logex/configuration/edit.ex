defmodule Logex.Configuration.Edit do
  @moduledoc false
  # SPIKE (OE-2 design pass, throwaway): a staged edit of a running configuration, built
  # from Logex.Edit's per-program plans and per-instance switch and prune, decision 45's
  # merge and split around each kept instance, decision 43's remove plus add, decision
  # 44's report, decision 40's next due time, and a generation counter on the resource.
  # Not the design's final shape: no forecast check of the state, few host checks.

  alias Logex.{Configuration, Diagnostic, Edit, Instance, Program, Runtime, Tag, Walk}

  defstruct [:original, :candidate, :stage, :plans, :records, :generation]

  # ---- accept -------------------------------------------------------------------------

  def accept(%Runtime{config: original, generation: generation} = rt, %Configuration{} = c) do
    named!(original, c)

    case Configuration.check(c) ++ refused(original, c) ++ retyped(original, c) do
      [] ->
        edit = %__MODULE__{
          original: original,
          candidate: c,
          stage: :accepted,
          plans: plans(original, c),
          records: %{},
          generation: generation
        }

        {_rt, _records, forecast} = switch(edit, rt, :test)
        {:ok, edit, forecast}

      diagnostics ->
        {:error, diagnostics}
    end
  end

  def test(edit, rt) do
    rt = current!(edit, rt)
    stage!(edit, [:accepted, :untested], "test", "accepted or untested")
    {rt, records, report} = switch(edit, rt, :test)
    {%{edit | stage: :testing, records: records, generation: rt.generation}, rt, report}
  end

  def untest(edit, rt) do
    rt = current!(edit, rt)
    stage!(edit, [:testing], "untest", "under test")
    {rt, records, report} = switch(edit, rt, :untest)
    {%{edit | stage: :untested, records: records, generation: rt.generation}, rt, report}
  end

  def assemble(edit, rt) do
    rt = current!(edit, rt)
    stage!(edit, [:testing], "assemble", "under test")
    {rt, report} = prune(edit, rt, :test)
    {edit.candidate, rt, report}
  end

  def cancel(%__MODULE__{stage: :accepted} = edit, rt) do
    rt = current!(edit, rt)
    {edit.original, %{rt | generation: rt.generation + 1}, []}
  end

  def cancel(edit, rt) do
    rt = current!(edit, rt)
    stage!(edit, [:untested], "cancel", "accepted or untested")
    {rt, report} = prune(edit, rt, :untest)
    {edit.original, rt, report}
  end

  def stage(%__MODULE__{stage: stage}), do: stage

  # ---- host mistakes ----------------------------------------------------------------------

  defp named!(%Configuration{name: name}, %Configuration{name: name}), do: :ok

  defp named!(%Configuration{name: running}, %Configuration{name: candidate}),
    do:
      raise(
        ArgumentError,
        "the candidate is `#{candidate}`, but the running configuration is `#{running}`: " <>
          "an edit keeps the configuration's name"
      )

  # The generation counter: every step but accept moves the resource's generation on by
  # one, and an edit records the generation it last saw. A step on an edit that has ended,
  # been superseded, or was accepted beside another that has stepped since, finds the
  # resource at another generation.
  defp current!(%__MODULE__{generation: g}, %Runtime{generation: g} = rt), do: rt

  defp current!(%__MODULE__{generation: e}, %Runtime{generation: g}),
    do:
      raise(
        ArgumentError,
        "this edit last saw the resource at generation #{e}, but it is at generation #{g}: " <>
          "the edit has ended, or another edit has changed the resource since"
      )

  defp stage!(%__MODULE__{stage: stage}, wanted, step, words) do
    if stage in wanted,
      do: :ok,
      else: raise(ArgumentError, "#{step} takes an edit #{words}, but this one is #{stage}")
  end

  # ---- accept: the refusals ----------------------------------------------------------------

  defp refused(o, c) do
    o_tasks = Map.new(o.tasks, &{&1.name, &1})
    c_tasks = Map.new(c.tasks, &{&1.name, &1})
    o_globals = Map.new(o.globals, &{&1.name, &1})
    o_instances = Map.new(o.instances, &{&1.name, &1})

    tasks =
      for t <- c.tasks,
          problem = task_problem(Map.get(o_tasks, t.name), t),
          do: at(c, t.line, problem)

    gone =
      for t <- o.tasks,
          not is_map_key(c_tasks, t.name),
          do: at(c, nil, "task `#{t.name}` is removed: a task is removed only with a restart")

    globals =
      for g <- c.globals,
          problem = global_problem(Map.get(o_globals, g.name), g),
          do: at(c, g.line, problem)

    c_globals = Map.new(c.globals, &{&1.name, &1})

    lost =
      for g <- o.globals,
          g.at != nil,
          not is_map_key(c_globals, g.name),
          do:
            at(
              c,
              nil,
              "`#{g.name}` at `#{g.at}` is removed: located I/O changes only with a restart"
            )

    moved =
      for i <- c.instances,
          {:ok, %{type: type, task: task}} <- [Map.fetch(o_instances, i.name)],
          type == i.type,
          task != i.task,
          do:
            at(
              c,
              i.line,
              "`#{i.name}` runs #{with_task(task)} in the running configuration and " <>
                "#{with_task(i.task)} in the candidate: an instance moves to another task " <>
                "only with a restart"
            )

    tasks ++ gone ++ globals ++ lost ++ moved
  end

  defp with_task(nil), do: "with no task"
  defp with_task(task), do: "with `#{task}`"

  defp task_problem(nil, t), do: "task `#{t.name}` is added: a task is added only with a restart"

  defp task_problem(%{single: s}, %{single: s2} = t) when s != s2,
    do:
      "task `#{t.name}`'s single changes from #{inspect(s)} to #{inspect(s2)}: " <>
        "a task's single changes only with a restart"

  defp task_problem(%{single: s, interval: i}, %{interval: i2} = t)
       when s != nil and i == nil != (i2 == nil),
       do:
         "task `#{t.name}` is an event task whose interval is added or removed: " <>
           "that changes only with a restart"

  defp task_problem(_o, _t), do: nil

  defp global_problem(nil, %{at: nil}), do: nil

  defp global_problem(nil, g),
    do: "`#{g.name}` at `#{g.at}` is added: located I/O changes only with a restart"

  defp global_problem(%{type: t}, %{type: t2} = g) when t != t2,
    do:
      "`#{g.name}` is a #{t} global in the running configuration and a #{t2} in the " <>
        "candidate: a global's type changes only with a restart"

  defp global_problem(%{at: a}, %{at: a2} = g) when a != a2,
    do:
      "`#{g.name}` is at #{inspect(a)} in the running configuration and at #{inspect(a2)} " <>
        "in the candidate: located I/O changes only with a restart"

  defp global_problem(_o, _g), do: nil

  defp at(c, line, message),
    do: %Diagnostic{stage: :edit, file: c.file, line: line, message: message}

  # Each program type a kept instance runs under both: OE-1's type-change refusals, once a
  # type (fix F5).
  defp retyped(o, c),
    do: Enum.flat_map(kept_types(o, c), &Edit.__retyped__(o.programs[&1], c.programs[&1]))

  defp kept_types(o, c) do
    o_types = Map.new(o.instances, &{&1.name, &1.type})

    c.instances
    |> Enum.filter(&(Map.get(o_types, &1.name) == &1.type))
    |> Enum.map(& &1.type)
    |> Enum.uniq()
  end

  # One plan per program type and direction (fix F5).
  defp plans(o, c) do
    for type <- kept_types(o, c), reduce: %{test: %{}, untest: %{}} do
      acc ->
        %{test: test, untest: untest} = Edit.__plans__(o.programs[type], c.programs[type])
        %{test: Map.put(acc.test, type, test), untest: Map.put(acc.untest, type, untest)}
    end
  end

  # ---- a switch ----------------------------------------------------------------------------

  defp sides(edit, :test), do: {edit.original, edit.candidate}
  defp sides(edit, :untest), do: {edit.candidate, edit.original}

  defp switch(edit, %Runtime{} = rt, dir) do
    {from, to} = sides(edit, dir)
    first? = dir == :test and edit.stage == :accepted
    from_types = Map.new(from.instances, &{&1.name, &1.type})
    to_types = Map.new(to.instances, &{&1.name, &1.type})

    # Globals first, so that an instance's merge sees every global the candidate adds.
    {globals, global_reports} = globals(from, to, rt.globals)

    stopping = for {n, type} <- from_types, Map.get(to_types, n) != type, do: {n, type}

    idle =
      Enum.reduce(stopping, rt.idle, fn {n, _}, idle -> Map.put(idle, n, rt.instances[n]) end)

    instances = Map.drop(rt.instances, Enum.map(stopping, &elem(&1, 0)))
    stopped = for {n, type} <- stopping, do: {:instance_stopped, n, type}

    {instances, idle, records, inst_reports} =
      Enum.reduce(to.instances, {instances, idle, edit.records, []}, fn i, acc ->
        instance(i, Map.get(from_types, i.name), {from, to, dir, first?, edit, rt, globals}, acc)
      end)

    {tasks, task_reports} = tasks(from, to, rt.tasks, rt.now)

    rt = %{
      rt
      | config: to,
        wiring: Runtime.__wiring__(to),
        globals: globals,
        instances: instances,
        idle: idle,
        tasks: tasks,
        generation: rt.generation + 1
    }

    held = held(from, to, globals)
    {rt, records, Enum.sort(global_reports ++ stopped ++ inst_reports ++ task_reports ++ held)}
  end

  # A kept instance: decision 45's merge by the stopped program's var_externals, OE-1's
  # switch, the split by the started program's.
  defp instance(%{name: n, type: type}, type, ctx, {instances, idle, records, reports}) do
    {from, to, dir, first?, edit, rt, globals} = ctx
    p_from = from.programs[type]
    p_to = to.programs[type]
    ext_from = externals(p_from)
    ext_to = externals(p_to)
    state = Map.fetch!(instances, n)
    joined = Map.take(state.env, ext_to -- ext_from)
    # The resource's clock, so that a timer resumed starts timing at the switch, not at
    # the instance's last scan (open question in the design).
    merged = %{state | env: Map.merge(state.env, Map.take(globals, ext_from)), now: rt.now}
    record = Map.get(records, n, Edit.__record__())
    {state, record, report} = Edit.__switch__(edit.plans[dir][type], record, merged, first?)
    left = Map.take(state.env, ext_from -- ext_to)
    state = %{state | env: Map.drop(state.env, ext_to)}

    report =
      for(
        {kind, name, detail} <- report,
        not (kind == :added and name in ext_to),
        do: {kind, n <> "." <> name, detail}
      ) ++
        for(
          e <- ext_to -- ext_from,
          do: {:joined, n <> "." <> e, {Map.get(joined, e), Map.fetch!(globals, e)}}
        ) ++
        for {e, v} <- left, do: {:left, n <> "." <> e, v}

    {Map.put(instances, n, state), idle, Map.put(records, n, record), report ++ reports}
  end

  # An instance the started configuration runs that the stopped one does not run as this
  # type: back from idle, where an earlier switch of this edit set it aside, else started.
  defp instance(%{name: n, type: type}, _other, ctx, {instances, idle, records, reports}) do
    {_from, to, _dir, _first?, _edit, rt, _globals} = ctx

    case Map.fetch(idle, n) do
      {:ok, %Instance{type: ^type} = state} ->
        {Map.put(instances, n, state), Map.delete(idle, n), records, reports}

      _ ->
        program = to.programs[type]
        state = Runtime.instance(program)
        state = %{state | env: Map.drop(state.env, externals(program)), now: rt.now}

        {Map.put(instances, n, state), idle, Map.delete(records, n),
         [{:instance_added, n, type} | reports]}
    end
  end

  defp externals(%Program{tags: tags}),
    do: for({name, %Tag{section: :var_external}} <- tags, do: name)

  # Decision 44: a kept global's changed initial value is reported; an added one starts by
  # Configuration.initial/1; a removed one is kept, unused, until assemble or cancel.
  defp globals(from, to, values) do
    was = Map.new(from.globals, &{&1.name, &1})

    Enum.reduce(to.globals, {values, []}, fn g, {values, reports} ->
      case {Map.fetch(values, g.name), Map.fetch(was, g.name)} do
        {:error, _} ->
          v = Configuration.initial(g)
          {Map.put(values, g.name, v), [{:added, g.name, v} | reports]}

        {{:ok, _}, {:ok, old}} ->
          {a, b} = {Configuration.initial(old), Configuration.initial(g)}
          {values, if(a != b, do: [{:initial_changed, g.name, {a, b}} | reports], else: reports)}

        {{:ok, _}, :error} ->
          {values, reports}
      end
    end)
  end

  # Decision 40: a changed interval makes the task next due at min(next_due, now + new).
  defp tasks(from, to, states, now) do
    was = Map.new(from.tasks, &{&1.name, &1})

    Enum.reduce(to.tasks, {states, []}, fn t, {states, reports} ->
      old = Map.fetch!(was, t.name)
      state = Map.fetch!(states, t.name)

      p =
        if old.priority != t.priority,
          do: [{:priority, t.name, {old.priority, t.priority}}],
          else: []

      case {old.interval, t.interval} do
        {i, i} ->
          {states, p ++ reports}

        {_old, new} ->
          due = min(state.next_due, now + new)

          moved =
            if due != state.next_due, do: [{:next_due, t.name, {state.next_due, due}}], else: []

          {Map.put(states, t.name, %{state | next_due: due}),
           [{:interval, t.name, {old.interval, new}}] ++ moved ++ p ++ reports}
      end
    end)
  end

  # Decision 20, for globals: each global the stopped configuration drives, by a
  # connection's copy-out or a write through a var_external, that the started one does
  # not, holds its value.
  defp held(from, to, globals) do
    for g <- MapSet.difference(drives(from), drives(to)) |> Enum.sort(),
        do: {:held, g, Map.fetch!(globals, g)}
  end

  defp drives(config) do
    types = Map.new(config.instances, &{&1.name, &1.type})

    outs =
      for c <- config.connections,
          is_binary(c.to),
          %Tag{section: :var_output} <- [config.programs[types[c.instance]].tags[c.member]],
          do: c.to

    ext =
      for i <- config.instances,
          program = config.programs[i.type],
          {name, _lines} <- Walk.writes(program),
          match?(%Tag{section: :var_external}, program.tags[name]),
          do: name

    MapSet.new(outs ++ ext)
  end

  # ---- assemble and cancel --------------------------------------------------------------

  defp prune(edit, rt, dir) do
    {from, to} = sides(edit, dir)
    from_types = Map.new(from.instances, &{&1.name, &1.type})

    {instances, inst_reports} =
      Enum.reduce(to.instances, {rt.instances, []}, fn i, {instances, reports} ->
        case Map.get(from_types, i.name) do
          type when type == i.type ->
            record = Map.get(edit.records, i.name, Edit.__record__())
            {state, report} = Edit.__prune__(edit.plans[dir][type], record, instances[i.name])

            {Map.put(instances, i.name, state),
             for({k, n, d} <- report, do: {k, i.name <> "." <> n, d}) ++ reports}

          _ ->
            {instances, reports}
        end
      end)

    idle = for {n, %Instance{type: type}} <- rt.idle, do: {:instance_pruned, n, type}
    keep = MapSet.new(to.globals, & &1.name)
    {globals, gone} = Map.split_with(rt.globals, fn {n, _} -> MapSet.member?(keep, n) end)
    pruned = for {n, v} <- gone, do: {:pruned, n, v}

    rt = %{rt | instances: instances, idle: %{}, globals: globals, generation: rt.generation + 1}
    {rt, Enum.sort(inst_reports ++ idle ++ pruned ++ held(from, to, globals))}
  end
end
