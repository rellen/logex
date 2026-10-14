defmodule Logex.Runtime do
  @moduledoc """
  Runs a compiled program as instances, one scan at a time. Nothing here reads a clock:
  the host injects time.

  - `instance/1` makes an instance's state, every tag at its initial value.
  - `call/4` is one scan of one instance: copy the inputs in, run every rung, give the
    outputs back. It is what a configuration's scheduler calls for each instance it runs.
  - `put_inputs/3`, `scan/2` and `scan/3` are the task-less sugar: the implicit
    configuration of one instance, whose var_inputs are the host's input image.
  - `restart/3` starts an instance again, keeping its clock and the inputs that fit their
    types.
  - `start/1`, `cycle/3`, `next_due_in/1`, `overlaps/1`, `get/2`, `get!/2` and `restart/2` run a
    configuration (`Logex.Configuration`) as one resource, `%Logex.Runtime{}`, below.

  **A configuration** (M2-1, `docs/organisation.md` §4.6). `start/1` makes the resource at
  time 0: every global at its initial value, every program instance as `instance/1` makes
  it, every task with an interval due at once, and every trigger's last sample 0. A
  *cycle* is one step of the resource, `cycle/3`, and a *scan* one execution of one
  instance, `call/4`. Each cycle, in order:

  1. `now` advances by `elapsed_ms`.
  2. `inputs`, keyed by input-point name, merge into the input points, which keep their
     values between cycles: a host sends only what changed, and every scan of the cycle
     sees the one sample.
  3. Each task's `single`, its trigger, if it has one (M2-6), is sampled once, after the
     merge and before any scan, so a trigger logic writes takes effect in the next cycle
     and a 1, 0, 1 inside one host step is not seen. A periodic task is due when its next
     due time has come. Every task's phase is anchored at 0, `start/1`'s `now`, so a first
     cycle that advances the clock reports the periods it spans. An event task is due when
     its trigger samples 1 and sampled 0 last, a trigger already 1 in the first cycle
     counting (decision 11), its due time the cycle's `now`. A task with both runs at most
     once a cycle: on an edge, or while its trigger samples 0 and a due time has come; a
     due time that comes while it samples 1 is skipped, not counted, the next on the same
     phase, so an edge run does not move the phase (decision 39); a late cycle is read by
     its sample alone, an edge cycle skipping the due times since the last (decision 51),
     a cycle that samples 0 running one that came while the image held 1 (decision 52).
     Due tasks run by priority, 0 first, then the earlier due time, then the order the
     configuration declares them; each runs its instances in the configuration's order,
     and the task-less instances run last, once each, in every cycle.
  4. A scan copies each connected var_input in, from its global or constant, and each
     var_external's global into the instance's state (M2-4), runs the instance through
     `call/4`, splits each var_external off again into its global, and then copies each
     connected var_output out to its global, so a connection's copy-out lands after a write
     through a var_external to the same global (decision 47). An instance sees what an
     earlier one wrote in the same cycle and never what a later one writes, through a
     connection and through a var_external alike.
  5. A task that ran periodically moves its next due time on by whole intervals past
     `now`, so its phase never drifts. Each period it missed, because the cycle came late,
     is counted, not run again: `{:overlap, task, missed}`, and `overlaps/1` gives each
     task's count. A task with a single alone never overlaps, and is listed at 0.
  6. The outputs are every output point, after every scan of the cycle.

  The events, in the order they happened, are `{:ran, task, instance, now}`, `task` being
  `:none` for a task-less instance, and `{:overlap, task, missed}`, just before its task's
  scans. They are an open set: a host tolerates a kind it does not know; an event task's
  run is its `{:ran, ...}` events, with no kind of its own. `next_due_in/1` is when a
  periodic due time next comes, which a runner sleeps on: it counts periodic due times
  only, a task with a single and an interval's among them even while its trigger is held
  1, since task-less instances run in whatever cycle comes and an edge is seen only in a
  cycle the runner makes (decision 50), so a runner of only those paces its own cycles.
  `get/2` reads a global, any declared tag of a program instance, a `var` among them and a
  var_external, which it reads as its global, or a public member of a function block
  instance in one; never an internal member, an instance whole, a task or the
  configuration, and a path that names one of those is told which it names: `get/2` gives
  `{:ok, value}` or `{:error, reason}`, and `get!/2` the value, raising `ArgumentError`
  with that reason (decision 41). `restart/2` starts the resource again, as `start/1` left
  it but for its clock and its input image, which it keeps, as `restart/3` keeps an
  instance's var_inputs. A `%Logex.Runtime{}` is opaque, plain data: one built or edited
  by hand is outside this contract. A `%Logex.Configuration{}` is the data
  API, built by hand by design, so `start/1` checks it again.

  A cycle and `next_due_in/1` take time linear in the tasks declared, whatever is due, but
  for the sort of the tasks due, n log n in them, every trigger sampled once a cycle.
  A refusal lists the names a key could have been once, on the first line that needs
  them, so its message is linear in its problems; its time is not, since each unknown key
  is matched against every name for a did-you-mean, quadratic in the two, as the `.ld`
  compiler's refusals are. Only a host's own mistake pays it.

  **A host's loop.** Only the host reads a clock. A runner sleeps `next_due_in/1`
  milliseconds, or less when it paces task-less instances or watches for an input to
  change, then reads its devices into an input map, calls `cycle/3` with the time that
  really passed and that map, and writes the outputs it gets back to its devices:

      rt = Logex.Runtime.start(config)
      # loop: sleep, then
      {rt, outputs, events} = Logex.Runtime.cycle(rt, elapsed_ms, inputs)

  What it may rely on:

  1. The first cycle runs at once, after `start/1` and after `restart/2`, whatever
     `next_due_in/1` says (decision 50): it is 0 then only where a task has an interval,
     and an event task whose trigger is already 1 runs in that cycle. A first cycle a
     whole interval later reports the run it missed. A trigger that logic writes fires at
     the next cycle the runner makes, and one that nothing writes, an unlocated global,
     fires once a start if its initial value is 1 and never otherwise.
  2. Late is reported, never replayed: a task runs once however late, and keeps its phase.
  3. Inputs are a delta: only input points, each with a value that fits its type, merged
     into the image, every problem with one call in one raise, in key order. The image
     starts at 0, so a host's first cycle carries every input point it knows.
  4. Outputs are a snapshot: every output point, every cycle, whether or not anything ran.
  5. Events are a log and an open set.
  6. A cycle is a function of its arguments, so a host that records each cycle's
     `elapsed_ms` and inputs replays every output and event exactly.
  7. A mistake by the host raises `ArgumentError`, and nothing else escapes.

  **One rule for each piece of a resource's state** (`docs/organisation.md` §4.9), which
  `start/1` uses and `Logex.Configuration.Edit`, the edit of a running configuration
  (OE-2), uses for a piece it adds, with its exceptions:
  - the clock, `now`, is 0 at `start/1`, moves on by each cycle's `elapsed_ms`, and is
    kept by `restart/2` and by every step of an edit;
  - a global starts by `Logex.Configuration.initial/1`: at `start/1`, at `restart/2` but
    for an input point, whose value is the host's from its first cycle on and is kept, and
    at the switch that first finds one the configuration started declares missing. A kept
    one whose initial value an edit changes keeps its running value until `restart/2`
    (decision 44); one only the configuration stopped declares is kept unused until
    assemble or cancel prunes it, or the first test of an edit that supersedes this one
    drops it (decision 66); and an output point nothing drives any more holds its
    value (decision 20);
  - a program instance starts as `instance/1` makes it, every tag by
    `Logex.Program.initial_env/1`, whose doc lists the edit's exceptions, and `restart/2`
    restarts it through `restart/3`. An edit's switch moves a kept one by its program
    type's plan (`Logex.Edit`'s rules, by path), its `now` set to the resource's after fix
    F11's undo reads its own (decision 56); one only the configuration started runs starts
    as `start/1` starts one, or comes back from aside;
  - a var_external (M2-4) holds no state of its own in a resource: there is one copy of
    each global, the resource's. A cycle merges it into its instance's state for the one
    scan and splits it off after; `start/1` and `restart/2` drop the 0 that `instance/1`
    and `restart/3` give it, so between cycles no instance's state holds one. An edit's
    switch merges each by the var_externals of the program it stops before the instance's
    switch and splits each off by those of the program it starts after, with any of the
    first that the second does not declare (decision 45), so a tag both declare keeps its
    value whatever its section, a `var` made a var_external drops its own value for the
    global's (decision 55), and no switch writes a global;
  - a task is due at the clock, `now`, with no overlap counted: at 0 by `start/1`, at the
    kept clock by `restart/2`. No edit adds or removes a task while it runs (decision 19),
    so no edit starts one by this rule. A task an edit keeps keeps its overlap count and
    its due time, except that an interval the edit changes makes it next due at
    `min(next_due, now + new interval)`, at test and again at untest (decision 40);
  - a task's trigger (M2-6), the last sample of its `single`, is 0 at `start/1` and by
    `restart/2`, so a trigger already 1 fires in the next cycle, and a cycle samples it
    once, after the input merge and before any scan. An edit's switch keeps it, so a
    switch fires no event, and its accept refuses a changed `single`, or an `interval`
    added to or removed from a task with one, while the plant runs (§4.9);
  - the generation (OE-2), the count of the configuration edits' steps taken on the
    resource, is 0 at `start/1` and kept by a cycle and by `restart/2`, so that a restart
    during an edit keeps the edit's stage. Every step of an edit but accept moves it on by
    one, cancel from accept included (decisions 60 and 64), so an edit that has ended can
    never step again;
  - the instances set aside (OE-2), `aside`, the state of each instance an edit's switch
    stops, by name, are none at `start/1`, kept by a cycle and never scanned, and dropped
    by `restart/2`, so the next switch starts each again (decision 65). A switch sets
    aside each instance only the configuration it stops runs, and the old state of one it
    retypes, and brings one back where the configuration it starts runs it again, its
    `now` the resource's and each timer that was timing resumed from the switch (decision
    57); assemble, and cancel after an untest, prune them, and an edit's first test drops
    those an edit it superseded left (decision 66).

  A program instance inside a resource is edited only with its configuration, through
  `Logex.Configuration.Edit`, whose steps take and return the resource and write it
  through this module alone (`edited/2`, internal), as its opacity requires; `Logex.Edit`
  takes one lone instance, which `instance/1` made. `restart/2` restarts the whole
  resource, during an edit too, keeping its stage; there is no restart of one instance
  inside it.

  A program run alone, through `instance/1`, `call/4` and `scan/2,3`, keeps a
  var_external as a tag of its own, at 0, which its host cannot set, as no input is but a
  var_input, and `restart/3` puts back at 0 (M2-4): exactly a one-instance configuration
  with, for each var_external, an unlocated global of no initial value that no other
  instance uses. So `scan/2` and a one-instance configuration give identical outputs for
  such a program too, given those globals.

  A user function block's instance (M2-5) is a map in the env, under its name, of its
  members, an instance it holds a map in that; `cal` runs it, rung power its EN, its body
  over that map with the scan narrowed to it (`Logex.Scan`), and on a false EN nothing at
  all (decision 12).

  A lone running instance takes a changed program through `Logex.Edit` (OE-1,
  `docs/organisation.md` §4.9): accept, test, untest, assemble or cancel, each between two
  scans, its state moved by name. An instance carries two fields for it
  (`Logex.Instance`): `ons_blocked`, the storage bits whose `ons` its next scan blocks,
  and since M3-1 the counters' edge memories whose `ctu` or `ctd` it blocks,
  which an edit's switch sets and only the runtime fills into a scan (`Logex.Scan`), and a
  scan empties but for a bit inside an instance whose body it did not run (M2-5); and
  `switched`, which an edit's switch sets and a scan clears.

  **The host contract.** A mistake by the host raises `ArgumentError` (a host bug, not a
  PLC event, `docs/organisation.md` §4.6); a mistake in the source is a diagnostic from
  `Logex.compile/2`. Only a declared `var_input` may be set, by its name as a string, with
  a value that fits its type exactly: a bool is 0 or 1, a dint an integer of 32 bits. Every
  input problem in one call comes in one raise, a line each, in key order. Inputs merge
  into the instance, so a host sends only what changed. Outputs are every `var_output`.
  Time never goes backwards for an instance, and a `%Logex.Scan{}` must agree with it about
  `first`; its `ons_blocked` is the runtime's, which `call/4` fills in with a map of the
  bits the instance's list names, so a host leaves it out. A state is matched to its program
  by name, and its values are not checked each scan. Scanning a recompile of the same name
  over a kept instance, a *plain swap*, stays in this contract: the instance keeps its
  values until `restart/3`, so a tag the recompile adds reads 0, an added timer starting at
  a `.pre` of 0, a tag whose type it changes keeps its old value, a timer's map reaching the
  outputs and the contacts, and a timer whose `ton` it gives back catches up all the time it
  was not run.
  `Logex.Edit` moves a state to a new program by rule instead: it starts what is added,
  restarts a value that does not fit its type, refuses a type change, moves a timer's
  `.pre` to a changed preset where logic left it alone, resumes a timer it gives back
  its `ton` from the switch, and blocks each one-shot and counter it adds or changes until a scan runs
  it, the next scan at the top level, where a plain swap's first scan can fire one whose
  condition was already true; inside a function block's instance it does each of these by
  the member's path (M2-5).
  `restart/3` starts every tag again but the `var_input`s whose values fit their types,
  and empties `ons_blocked`. A `%Logex.Program{}`, `%Logex.Instance{}` or `%Logex.Edit{}` built or
  edited by hand is outside this contract, and so is one that holds a block type whose body
  was edited by hand, which may raise: a body whose rungs are no IR does. Only a `cal` of
  an instance its table lacks, or whose type it names and does not hold, is defined: it
  runs nothing. A type given to `Logex.compile/2` or `Logex.Tag.new!/4` cannot be one: it
  is the one its source text compiles to (`Logex.FbType.user?/1`, decision 54).

  **During an edit of a running configuration** the host's loop is unchanged: it takes
  each step between two cycles, keeps the runtime each step returns, which `cycle/3` then
  runs, and tolerates a report kind it does not know. The input image is the resource's,
  kept across every step; each var_input is copied in from its connection; and a held
  output point is among every cycle's outputs at the value it holds. A step on an edit
  that has ended or that another has stepped past is refused by the generation; two
  resources started from one configuration cannot be told apart, so stepping an edit on
  the other is outside this contract (decision 60).

  **During an edit of a lone instance** the host scans, sets inputs and restarts through
  `Logex.Edit.running/1`; scanning the other program is outside this contract. The edit
  adds two duties (OE-1, fix F10):
  - under test, send only the var_inputs of `Logex.Edit.running(edit)`: one the candidate
    removed is refused as undeclared, like any other;
  - resend every input a step reports as `{:input, name, value}` before the next scan,
    since across a switch "a host sends only what changed" is no longer enough, and stop
    sending each one it reports as `{:unread, name, value}`.
  """

  alias Logex.{Configuration, Declarations, Diagnostic, FbType, Instance, Program, Scan, Tag}
  alias Logex.FbType.Member

  @comparisons [:eq, :ne, :lt, :gt, :le, :ge]

  # The resource (M2-1): the configuration it runs; `now`, its clock; `globals`, one value
  # for each global, the input points' among them; `instances`, each program instance's
  # state by name; `tasks`, each task's next due time and overlap count by name; and
  # `wiring`, what `start/1` derives from the configuration once, never state of its own.
  # A task with a single holds its trigger's last sample there too (M2-6). OE-2:
  # `generation`, the count of the configuration edits' steps taken on it, and `aside`,
  # the state of each instance an edit's switch has set aside, by name, never scanned.
  @enforce_keys [:config, :now, :globals, :instances, :tasks, :wiring, :generation, :aside]
  defstruct [:config, :now, :globals, :instances, :tasks, :wiring, :generation, :aside]

  @opaque t :: %__MODULE__{}

  # M2-5: the key under which a scan records which instances' bodies ran.
  @ran :ran

  @doc "A new instance of `program`: every tag at its initial value, before its first scan."
  def instance(program) do
    program!(program)
    %Instance{type: program.name, env: Program.initial_env(program), now: 0, first: true}
  end

  @doc """
  One scan of one instance, at `scan.now`: `inputs` are copied in, every rung runs, and
  `{outputs, state}` comes back, the outputs being every `var_output`.
  """
  def call(program, state, inputs, scan) do
    program!(program)
    state = state!(state, program)
    scan = scan!(scan, state)
    state |> merge!(program, inputs) |> run(program, scan)
  end

  @doc """
  Sets inputs in an instance's input image, checked as `call/4` checks them, for the next
  `scan/2` or `scan/3`.
  """
  def put_inputs(program, state, inputs) do
    program!(program)
    state!(state, program) |> merge!(program, inputs)
  end

  @doc """
  One scan of the implicit configuration: `elapsed_ms` after the last one (none for
  `scan/2`), with the inputs `put_inputs/3` set.
  """
  def scan(program, state, elapsed_ms \\ 0) do
    program!(program)
    %Instance{now: now, first: first} = state = state!(state, program)
    call(program, state, %{}, %Scan{now: now + elapsed!(elapsed_ms), first: first})
  end

  @doc """
  Starts an instance again: every tag back at its initial value except the `var_input`s
  whose values fit their types, the next scan marked first, no one-shot blocked, and the
  clock kept, since time never goes backwards. `switched` is kept too: a restart is not a
  scan, so it shows the host nothing.

  The `var_input`s are the host's input image, not the program's state: IEC leaves inputs
  "initialized in an implementation-dependent manner" (Ed 2 §2.4.2 rule 4), and keeping
  them is what makes `scan/2` agree with a configuration, whose copy-in refreshes them
  every scan. `:warm` is `:cold` until `retain` exists: nothing is retained yet.
  """
  def restart(program, state, mode) do
    program!(program)
    %Instance{env: env} = state = state!(state, program)
    mode!(mode)

    %{
      state
      | env: Map.merge(Program.initial_env(program), inputs(program, env)),
        first: true,
        ons_blocked: []
    }
  end

  @doc """
  A resource running `config`, at time 0 before its first cycle: every global at its
  initial value, 0 where it has none; every program instance as `instance/1` makes it;
  every task with an interval due at once, every trigger's last sample 0, and no overlap
  counted. `config` is checked again
  (`Logex.Configuration.check/1`), and one with a problem raises `ArgumentError` listing
  every one.
  """
  def start(%Configuration{} = config) do
    configured!(Configuration.check(config))
    wiring = wiring(config)

    %__MODULE__{
      config: config,
      now: 0,
      globals: Map.new(config.globals, &{&1.name, Configuration.initial(&1)}),
      instances:
        Map.new(config.instances, fn %{name: name, type: type} ->
          {name, detached(instance(Map.fetch!(config.programs, type)), wiring, name)}
        end),
      tasks: Map.new(config.tasks, &{&1.name, task_state(&1, 0)}),
      wiring: wiring,
      generation: 0,
      aside: %{}
    }
  end

  def start(other),
    do:
      raise(
        ArgumentError,
        "expected a %Logex.Configuration{} from Logex.Configuration.new!/1, got: #{inspect(other)}"
      )

  @doc """
  One cycle of the resource, `elapsed_ms` after the last: `{runtime, outputs, events}`,
  the outputs being every output point. See the moduledoc for its order.
  """
  def cycle(runtime, elapsed_ms, inputs) do
    %__MODULE__{now: now} = runtime = runtime!(runtime)
    elapsed = elapsed!(elapsed_ms)
    runtime = %{runtime | now: now + elapsed, globals: image!(runtime, inputs)}
    {runtime, due} = due(runtime)
    {runtime, events} = Enum.reduce(due, {runtime, []}, &run_task/2)

    {runtime, events} =
      Enum.reduce(runtime.wiring.taskless, {runtime, events}, &scanned(&1, :none, &2))

    {runtime, Map.new(runtime.wiring.outputs, &{&1, Map.fetch!(runtime.globals, &1)}),
     Enum.reverse(events)}
  end

  @doc """
  The milliseconds until a periodic due time next comes, or `:infinity` when no task has
  an interval: an event task's edge is seen only in a cycle, so it counts none (decision
  50). It is 0 after `start/1` where a task has an interval, and more than 0 after every
  cycle, which moves each due time it runs or skips past `now`.
  """
  def next_due_in(runtime) do
    %__MODULE__{now: now, tasks: tasks} = runtime!(runtime)

    for(%{next_due: next} <- Map.values(tasks), next != nil, do: next)
    |> Enum.min(fn -> nil end)
    |> due_in(now)
  end

  defp due_in(nil, _now), do: :infinity
  defp due_in(next, now), do: next - now

  @doc """
  Starts the resource again (`:warm` is `:cold` until `retain` exists). It is then as
  `start/1` left it, but for its clock and its input image, which it keeps: every other
  global back at its initial value, each instance through `restart/3`, every task with an
  interval due at the next cycle, every trigger's last sample 0, so a trigger already 1
  fires in it, and every overlap count 0. An instance a configuration edit set aside is
  dropped, and the edit's generation kept (OE-2). Keeping the input image is what keeps
  `scan/2` with `restart/3` and a one-instance configuration in agreement across a
  restart, with nothing for the host to send again (decision 38). There is no restart of
  one instance inside a resource.
  """
  def restart(runtime, mode) do
    %__MODULE__{now: now, config: config} = runtime = runtime!(runtime)
    mode!(mode)

    %{
      runtime
      | globals: Map.new(config.globals, &{&1.name, restarted(&1, runtime)}),
        instances:
          Map.new(runtime.instances, fn {name, state} ->
            restarted = restart(Map.fetch!(config.programs, state.type), state, mode)
            {name, detached(restarted, runtime.wiring, name)}
          end),
        tasks: Map.new(config.tasks, &{&1.name, task_state(&1, now)}),
        aside: %{}
    }
  end

  defp restarted(%Configuration.Global{name: name} = global, %__MODULE__{} = runtime),
    do: input_kept(Map.has_key?(runtime.wiring.inputs, name), global, runtime)

  defp input_kept(true, global, runtime), do: Map.fetch!(runtime.globals, global.name)
  defp input_kept(false, global, _runtime), do: Configuration.initial(global)

  # A task's state: its next periodic due time, nil for a task with no interval; its
  # overlap count; and, for a task with a single (M2-6), its trigger's last sample, 0 at
  # start/1 and by restart/2, so a trigger already 1 fires in the next cycle.
  defp task_state(%Configuration.Task{single: nil}, due), do: %{next_due: due, overlaps: 0}

  defp task_state(%Configuration.Task{interval: nil}, _due),
    do: %{next_due: nil, overlaps: 0, last: 0}

  defp task_state(%Configuration.Task{}, due), do: %{next_due: due, overlaps: 0, last: 0}

  # M2-4: one copy of each global. Between scans an instance's state holds none of its
  # var_externals, which instance/1 and restart/3 start at 0 as any tag: the resource's
  # global is the only copy (decision 49).
  defp detached(%Instance{env: env} = state, wiring, name),
    do: %{state | env: Map.drop(env, Map.fetch!(wiring.externals, name))}

  @doc false
  # OE-2: the one writer of a configuration edit's step into the resource, so that its
  # fields are written in this module alone (Logex.Configuration.Edit computes them).
  # `changes` holds what the step gives, among `config`, `globals`, `instances`, `aside`
  # and `tasks`, each whole: a switch gives all five, a prune the instances, globals and
  # what is set aside, and cancel from accept none. The wiring is derived again from the
  # configuration, and every step moves the generation on by one (decisions 60 and 64).
  def edited(%__MODULE__{} = runtime, changes) do
    %__MODULE__{config: config, generation: generation} = runtime = struct!(runtime, changes)
    %{runtime | wiring: wiring(config), generation: generation + 1}
  end

  @doc "Each task's overlap count, by name: the periods it missed since `start/1` or `restart/2`."
  def overlaps(runtime) do
    %__MODULE__{tasks: tasks} = runtime!(runtime)
    Map.new(tasks, fn {name, %{overlaps: overlaps}} -> {name, overlaps} end)
  end

  @doc """
  The value at an access path, the resource omitted (`docs/organisation.md` §4.7), as
  `{:ok, value}`: a global, `"estop"`; a program instance's tag, `"m1.fault"`, a
  var_external read as its global, `"m1.estop"` the value of `"estop"` (M2-4); or a member
  of a function block instance in it, `"m1.t1.acc"`, as logic names one. A string that
  names no such value, an instance named whole, an internal member, a task, the
  configuration, a path that names nothing, or no path at all, gives `{:error, reason}`,
  `reason` the message `get!/2` raises (decision 41). Something other than a resource,
  or a path that is not a string, is the host's mistake and raises `ArgumentError`.
  """
  def get(runtime, path) do
    looked_up(runtime!(runtime), string!(path))
  end

  defp looked_up(runtime, path) do
    {:ok, value!(runtime, path)}
  rescue
    error in ArgumentError -> {:error, Exception.message(error)}
  end

  @doc """
  The value at an access path, as `get/2` finds it, or `ArgumentError` with the reason
  `get/2` gives.
  """
  def get!(runtime, path), do: value!(runtime!(runtime), string!(path))

  defp value!(runtime, path) do
    [head | rest] = String.split(path!(path), ".")

    at_path(
      Map.fetch(runtime.wiring.globals, head),
      Map.fetch(runtime.wiring.types, head),
      {head, rest, path},
      runtime
    )
  end

  # A var_input whose value does not fit its type, as after a recompile of the same name
  # that changed the type, starts again with the rest.
  defp inputs(%Program{tags: tags}, env),
    do:
      for(
        {name, %Tag{section: :var_input, type: type}} <- tags,
        {:ok, value} <- [Map.fetch(env, name)],
        Declarations.fits?(type, value),
        into: %{},
        do: {name, value}
      )

  defp mode!(mode) when mode in [:cold, :warm], do: :ok

  defp mode!(mode),
    do: raise(ArgumentError, "restart takes :cold or :warm, got: #{inspect(mode)}")

  # The evaluator's scan is the host's `now` and `first` with the instance's block list,
  # which holds for this one scan (OE-1), made a tree once here so that each `ons` looks its
  # bit up: a walk of the list made the scan after a switch quadratic in the one-shots it
  # blocks. A bit inside a function block instance is named by its path, `s1.edge`, and the
  # tree holds it under its instance, so a `cal` hands its body only that instance's own
  # (M2-5); and the program's tag table, where a `cal` finds its instance's type, named,
  # with the program's one table of block types, where it finds the type (decision 53). A scan is what clears `switched`: the state then holds what this
  # program gave the host.
  #
  # M2-5: a bit is blocked until its `ons` runs. A bit of the program's own rungs runs on
  # this scan; one inside an instance runs only where a `cal` runs the instance's body, so
  # the bits of an instance whose `cal` was false, or that no `cal` runs, stay in the list
  # for the next scan, or the block would be used up unseen and the `ons` compare a changed
  # rung against the bit the old one wrote: the false pulse decision 21 prevents.
  defp run(
         %Instance{env: env, ons_blocked: blocked} = state,
         %Program{rungs: rungs, tags: tags, blocks: blocks} = program,
         %Scan{now: now, first: first}
       ) do
    tree = tree(blocked)
    scan = %Scan{now: now, first: first, ons_blocked: tree, tags: tags, blocks: blocks}
    {unrun, env} = unrun(tree, Enum.reduce(rungs, env, &rung(&1, &2, scan)))

    {outputs(program, env),
     %{state | env: env, now: now, first: false, ons_blocked: unrun, switched: false}}
  end

  # The bits of the tree whose `ons` did not run, by their paths, sorted: those inside an
  # instance whose body did not run. Each `cal` that runs an instance's body records it in
  # the env of the routine that runs it, under `@ran`, an atom, so no tag or member name
  # can be it, and takes its body's record out of the instance's map (`called/5`); this
  # takes the program's out, so no state keeps one.
  defp unrun(tree, env) do
    {ran, env} = recorded(env)
    {Enum.sort(kept(tree, ran, "", [])), env}
  end

  # The record taken out of an env, a map whatever an env built by hand left under its key.
  defp recorded(env) do
    {ran, env} = Map.pop(env, @ran, %{})
    {as_map(ran), env}
  end

  defp kept(tree, ran, prefix, acc),
    do:
      Enum.reduce(tree, acc, fn
        {_bit, true}, acc -> acc
        {instance, inner}, acc -> within(Map.fetch(ran, instance), inner, prefix <> instance, acc)
      end)

  defp within({:ok, ran}, inner, path, acc), do: kept(inner, as_map(ran), path <> ".", acc)
  defp within(:error, inner, path, acc), do: paths(inner, path, acc)

  defp paths(true, path, acc), do: [path | acc]

  defp paths(inner, path, acc),
    do: Enum.reduce(inner, acc, fn {name, at}, acc -> paths(at, path <> "." <> name, acc) end)

  # A var_output a hand-built env leaves out reads 0, as a contact reads it (M1-4).
  defp outputs(%Program{tags: tags}, env),
    do:
      for(
        {name, %Tag{section: :var_output}} <- tags,
        into: %{},
        do: {name, Map.get(env, name, 0)}
      )

  # The block list as a tree, each name split at its `.`s once: linear in the list.
  defp tree(bits), do: Enum.reduce(bits, %{}, &plant(String.split(&1, "."), &2))

  defp plant([bit], tree), do: Map.put(tree, bit, true)

  defp plant([instance | path], tree),
    do: Map.put(tree, instance, plant(path, as_map(Map.get(tree, instance))))

  # The arguments, checked in order: program, state, the state's owner, scan, inputs.
  defp program!(%Program{tags: tags, rungs: rungs}) when is_map(tags) and is_list(rungs), do: :ok

  # M2-5: what Logex.compile/2 gives for a function block's file, which a program runs.
  defp program!(%FbType{name: name} = type) when is_binary(name),
    do: raise(ArgumentError, "`#{name}` is " <> Declarations.not_a_program(type))

  defp program!(other),
    do:
      raise(
        ArgumentError,
        "expected a %Logex.Program{} from Logex.compile/2, got: #{inspect(other)}"
      )

  defp state!(%Instance{type: type}, _program) when not is_binary(type) and type != nil,
    do: raise(ArgumentError, "state.type must be a program name, got: #{inspect(type)}")

  defp state!(%Instance{env: env}, _program) when not is_map(env) or is_struct(env),
    do:
      raise(ArgumentError, "state.env must be a map of tag names to values, got: #{inspect(env)}")

  defp state!(%Instance{now: now}, _program) when not is_integer(now) or now < 0,
    do: raise(ArgumentError, "state.now must be #{ms()}, got: #{inspect(now)}")

  defp state!(%Instance{first: first}, _program) when not is_boolean(first),
    do: raise(ArgumentError, "state.first must be true or false, got: #{inspect(first)}")

  defp state!(%Instance{switched: switched}, _program) when not is_boolean(switched),
    do: raise(ArgumentError, "state.switched must be true or false, got: #{inspect(switched)}")

  defp state!(%Instance{ons_blocked: blocked} = state, program),
    do: owner!(blocked!(bits?(blocked), state), program)

  defp state!(other, _program),
    do:
      raise(
        ArgumentError,
        "expected a %Logex.Instance{} from Logex.Runtime.instance/1, got: #{inspect(other)}"
      )

  # F8: a proper list of names, or `run/3`'s `Map.from_keys/2` raises an unpinned
  # ArgumentError for an improper one.
  defp bits?([]), do: true
  defp bits?([bit | bits]) when is_binary(bit), do: bits?(bits)
  defp bits?(_not_bits), do: false

  defp blocked!(true, state), do: state

  defp blocked!(false, %Instance{ons_blocked: blocked}),
    do:
      raise(
        ArgumentError,
        "state.ons_blocked must be a list of storage bit names, got: #{inspect(blocked)}"
      )

  defp owner!(%Instance{type: name} = state, %Program{name: name}), do: state

  defp owner!(%Instance{type: type}, %Program{name: name}),
    do: raise(ArgumentError, "this state is an instance of #{named(type)}, not of #{named(name)}")

  defp named(nil), do: "an unnamed program"
  defp named(name), do: "`#{name}`"

  defp scan!(%Scan{now: now}, _state) when not is_integer(now) or now < 0,
    do: raise(ArgumentError, "scan.now must be #{ms()}, got: #{inspect(now)}")

  defp scan!(%Scan{first: first}, _state) when not is_boolean(first),
    do: raise(ArgumentError, "scan.first must be true or false, got: #{inspect(first)}")

  defp scan!(%Scan{ons_blocked: blocked}, _state) when blocked != [],
    do:
      raise(
        ArgumentError,
        "scan.ons_blocked is the runtime's, taken from the instance: a host leaves it out, " <>
          "got: #{inspect(blocked)}"
      )

  defp scan!(%Scan{tags: tags}, _state) when tags != nil,
    do:
      raise(
        ArgumentError,
        "scan.tags is the runtime's, taken from the program: a host leaves it out, " <>
          "got: #{inspect(tags)}"
      )

  defp scan!(%Scan{blocks: blocks}, _state) when blocks != nil,
    do:
      raise(
        ArgumentError,
        "scan.blocks is the runtime's, taken from the program: a host leaves it out, " <>
          "got: #{inspect(blocks)}"
      )

  defp scan!(%Scan{now: now}, %Instance{now: last}) when now < last,
    do:
      raise(
        ArgumentError,
        "time went backwards: this scan is at #{now} ms, " <>
          "but the instance was last scanned at #{last} ms"
      )

  defp scan!(%Scan{first: first} = scan, %Instance{first: first}), do: scan

  defp scan!(%Scan{first: false}, _state),
    do:
      raise(
        ArgumentError,
        "scan.first is false, but this is the instance's first scan since it started or restarted"
      )

  defp scan!(%Scan{first: true}, _state),
    do:
      raise(
        ArgumentError,
        "scan.first is true, but the instance has been scanned since it started or restarted"
      )

  defp scan!(other, _state),
    do: raise(ArgumentError, "expected a %Logex.Scan{}, got: #{inspect(other)}")

  defp elapsed!(ms) when is_integer(ms) and ms >= 0, do: ms

  defp elapsed!(other),
    do: raise(ArgumentError, "elapsed_ms must be #{ms()}, got: #{inspect(other)}")

  defp ms, do: "a non-negative integer of milliseconds"

  # Every input problem, a line each in key order, or the inputs merged into the state.
  defp merge!(%Instance{env: env} = state, %Program{} = program, inputs)
       when is_map(inputs) and not is_struct(inputs) do
    problems =
      for {key, value} <- Enum.sort(inputs), problem = problem(key, value, program), do: problem

    merged(problems, state, env, inputs)
  end

  defp merge!(_state, _program, inputs),
    do:
      raise(
        ArgumentError,
        ~s|inputs must be a map of var_input names to values, as in %{"start" => 1}, | <>
          "got: #{inspect(inputs)}"
      )

  defp merged([], state, env, inputs), do: %{state | env: Map.merge(env, inputs)}

  defp merged(problems, _state, _env, _inputs),
    do: raise(ArgumentError, Enum.join(once(problems), "\n"))

  # A refusal lists the names a key could have been once, on the first line that needs
  # them: each line that does gives its key and a function that lists them, so that n
  # wrong keys against n names make a message of n lines, not n lines of n names each.
  defp once(problems), do: elem(Enum.map_reduce(problems, false, &listed_once/2), 0)

  defp listed_once({line, list}, false), do: {line <> list.(), true}
  defp listed_once({line, _list}, true), do: {line, true}
  defp listed_once(line, listed), do: {line, listed}

  defp problem(key, _value, _program) when not is_binary(key),
    do:
      "input #{inspect(key)} is not a tag name: inputs are keyed by tag name, as a string, " <>
        ~s|as in %{"start" => 1}|

  defp problem(key, value, %Program{tags: tags} = program),
    do: declared(Map.fetch(tags, key), key, value, program)

  # A key naming no tag is told what its first part is, an instance's type itself (tag_of/2).
  defp declared(:error, key, _value, %Program{tags: tags} = program) do
    [head | path] = String.split(key, ".")
    undeclared(tag_of(program, head), path, key, tags)
  end

  defp declared({:ok, %Tag{section: :var_input} = tag}, _key, value, _program),
    do: fit(tag, value)

  defp declared({:ok, %Tag{} = tag}, key, _value, _program),
    do:
      "input #{label(key)} is a #{tag.section}#{on_line(tag)}, not a var_input: " <>
        "only a var_input is set from outside"

  # M1-6: the host never sets anything inside an instance. A key naming a declared tag was
  # found before this, so here a key found by its first part has a `.`, and it is called a
  # member only when the compiler would take it for one: `t1.dn`, never `t1.last`,
  # `t1.zz` or `t1.dn.x`, which reach into `t1` all the same.
  defp undeclared({:ok, %Tag{type: %FbType{} = type} = tag}, path, key, _tags),
    do:
      "input #{label(key)} #{reaches(member(type, path))} `#{tag.name}`, " <>
        "#{Declarations.instance_of(type)}: " <>
        "only a var_input is set from outside"

  defp undeclared(_tag, _path, key, tags) do
    inputs = for {name, %Tag{section: :var_input}} <- tags, do: name

    hint("input #{label(key)} is not declared", Declarations.suggest(key, inputs), inputs)
  end

  defp member(type, [name]), do: FbType.member(type, name)
  defp member(_type, _deeper), do: :error

  defp reaches({:ok, _member}), do: "names a member of"
  defp reaches(:error), do: "reaches into"

  defp hint(line, "", []), do: line <> ": this program has no var_input"

  defp hint(line, "", inputs),
    do:
      {line,
       fn -> ": the var_inputs are " <> Enum.map_join(Enum.sort(inputs), ", ", &"`#{&1}`") end}

  defp hint(line, suggestion, _inputs), do: line <> suggestion

  defp fit(%Tag{type: :dint} = tag, value) when not is_integer(value),
    do: "input `#{tag.name}` is a dint: its value must be an integer, found #{inspect(value)}"

  defp fit(%Tag{type: type} = tag, value), do: fits(Declarations.fits?(type, value), tag, value)

  defp fits(true, _tag, _value), do: nil

  defp fits(false, %Tag{type: :bool} = tag, value),
    do: "input `#{tag.name}` is a bool: only 0 or 1 fit, found #{inspect(value)}"

  defp fits(false, %Tag{type: :dint} = tag, value),
    do: "input `#{tag.name}` is a dint: #{value} does not fit in 32 bits"

  # A key is quoted as a name when every `.` part of it is one, so `t1.dn` reads as written.
  defp label(key), do: labelled(Enum.all?(String.split(key, "."), &Declarations.name?/1), key)

  defp labelled(true, key), do: "`#{key}`"
  defp labelled(false, key), do: inspect(key)

  defp on_line(%Tag{line: nil}), do: ""
  defp on_line(%Tag{line: line}), do: " (declared on line #{line})"

  # The configuration, checked again: check/1 raises the host's mistakes itself, and a
  # diagnostic raises as `Logex.Configuration.new!/1`'s do, formatted, a line each.
  defp configured!([]), do: :ok

  defp configured!(diagnostics),
    do: raise(ArgumentError, Enum.map_join(diagnostics, "\n", &Diagnostic.format/1))

  # What a cycle reads of the configuration, derived once: the tasks in declaration order,
  # each with its instances in theirs; the task-less instances; each instance's type and
  # its connections in and out; the input points' types and the output points' names; the
  # globals by name; and each instance's var_externals, by name (M2-4).
  defp wiring(%Configuration{} = config) do
    by_task = Enum.group_by(config.instances, & &1.task, & &1.name)
    types = Map.new(config.instances, &{&1.name, &1.type})

    sections =
      Enum.group_by(
        config.connections,
        &section(config, types, &1),
        &{&1.instance, {&1.member, &1.to}}
      )

    points = Enum.map(config.globals, &{&1, Configuration.location(&1.at)})

    %{
      tasks:
        config.tasks
        |> Enum.with_index()
        |> Enum.map(fn {task, index} ->
          {task.name, {task.single, task.interval}, task.priority, index,
           Map.get(by_task, task.name, [])}
        end),
      taskless: Map.get(by_task, nil, []),
      types: types,
      copy_in: grouped(config.instances, Map.get(sections, :var_input, [])),
      copy_out: grouped(config.instances, Map.get(sections, :var_output, [])),
      inputs: Map.new(for {global, {:ok, {_, "i", _}}} <- points, do: {global.name, global.type}),
      outputs: for({global, {:ok, {_, "q", _}}} <- points, do: global.name),
      globals: Map.new(config.globals, &{&1.name, &1}),
      externals:
        Map.new(config.instances, &{&1.name, externals(Map.fetch!(config.programs, &1.type))})
    }
  end

  defp externals(%Program{tags: tags}),
    do: for({name, %Tag{section: :var_external}} <- tags, do: name)

  defp section(config, types, connection) do
    %Tag{section: section} =
      Map.fetch!(
        Map.fetch!(config.programs, Map.fetch!(types, connection.instance)).tags,
        connection.member
      )

    section
  end

  defp grouped(instances, connections) do
    by_instance = Enum.group_by(connections, &elem(&1, 0), &elem(&1, 1))
    Map.new(instances, &{&1.name, Map.get(by_instance, &1.name, [])})
  end

  defp runtime!(%__MODULE__{} = runtime), do: runtime

  defp runtime!(other),
    do:
      raise(
        ArgumentError,
        "expected a %Logex.Runtime{} from Logex.Runtime.start/1, got: #{inspect(other)}"
      )

  # The input image: every problem with the inputs, a line each in key order, or the
  # inputs merged into the input points.
  defp image!(%__MODULE__{globals: globals} = runtime, inputs)
       when is_map(inputs) and not is_struct(inputs) do
    problems =
      for {key, value} <- Enum.sort(inputs),
          problem = point_problem(key, value, runtime),
          do: problem

    imaged(problems, globals, inputs)
  end

  defp image!(_runtime, inputs),
    do:
      raise(
        ArgumentError,
        ~s|inputs must be a map of input-point names to values, as in %{"pb_start_1" => 1}, | <>
          "got: #{inspect(inputs)}"
      )

  defp imaged([], globals, inputs), do: Map.merge(globals, inputs)

  defp imaged(problems, _globals, _inputs),
    do: raise(ArgumentError, Enum.join(once(problems), "\n"))

  defp point_problem(key, _value, _runtime) when not is_binary(key),
    do:
      "input #{inspect(key)} is not a point name: inputs are keyed by input-point name, " <>
        ~s|as a string, as in %{"pb_start_1" => 1}|

  defp point_problem(key, value, %__MODULE__{wiring: wiring} = runtime),
    do: point(Map.fetch(wiring.inputs, key), Map.fetch(wiring.globals, key), key, value, runtime)

  # An input point's value fits its type as a var_input's does, with the same messages.
  defp point({:ok, type}, _global, key, value, _runtime),
    do: fit(%Tag{name: key, type: type, section: :var_input}, value)

  defp point(:error, {:ok, global}, key, _value, _runtime),
    do:
      "input #{label(key)} is #{not_input(Configuration.location(global.at), global)}: " <>
        "only an input point is set from outside"

  defp point(:error, :error, key, _value, runtime),
    do: unknown_point(String.split(key, "."), key, runtime)

  defp not_input({:ok, _output}, global),
    do: "an output point (at `#{global.at}`), not an input point"

  defp not_input(:error, _global), do: "a global with no location, not an input point"

  defp unknown_point([head, _member | _], key, %__MODULE__{wiring: wiring}),
    do: reaching(Map.has_key?(wiring.types, head), head, key, wiring)

  defp unknown_point([name], key, runtime), do: named_point(kind(runtime, name), key, runtime)

  # A key naming a program instance whole, a task, or the configuration is told what that
  # name is: none of them is set from outside.
  defp named_point({:instance, type}, key, _runtime),
    do:
      "input #{label(key)} is a program instance of `#{type}`, not an input point: " <>
        "only an input point is set from outside"

  defp named_point(:task, key, _runtime),
    do:
      "input #{label(key)} is a task, not an input point: only an input point is set from outside"

  defp named_point(:configuration, key, _runtime),
    do:
      "input #{label(key)} is the configuration's name, not an input point: " <>
        "only an input point is set from outside"

  defp named_point(:none, key, runtime), do: no_point(key, runtime.wiring)

  defp reaching(true, head, key, _wiring),
    do:
      "input #{label(key)} reaches into the program instance `#{head}`: " <>
        "only an input point is set from outside"

  defp reaching(false, _head, key, wiring), do: no_point(key, wiring)

  defp no_point(key, wiring) do
    points = Enum.sort(Map.keys(wiring.inputs))

    point_hint(
      "input #{label(key)} is not an input point",
      Declarations.suggest(key, points, & &1, "names"),
      points
    )
  end

  defp point_hint(line, "", []), do: line <> ": this configuration has no input point"

  defp point_hint(line, "", points),
    do: {line, fn -> ": the input points are " <> and_list(Enum.map(points, &"`#{&1}`")) end}

  defp point_hint(line, suggestion, _points), do: line <> suggestion

  # What a name that is no global is in the resource: a program instance or a task, which
  # share the globals' one namespace, else the configuration's own name, which a task's
  # may equal.
  defp kind(%__MODULE__{wiring: wiring, tasks: tasks, config: config}, name),
    do: kind_of(Map.fetch(wiring.types, name), Map.has_key?(tasks, name), config.name == name)

  defp kind_of({:ok, type}, _task, _configuration), do: {:instance, type}
  defp kind_of(:error, true, _configuration), do: :task
  defp kind_of(:error, false, true), do: :configuration
  defp kind_of(:error, false, false), do: :none

  # Step 3: each trigger sampled once, after the input image is merged and before any
  # scan, so a trigger logic writes takes effect in the next cycle (M2-6); and the due
  # tasks, in the order they run: priority, then the earlier due time, then the order the
  # configuration declares them. An event task's due time is the cycle's `now`, the edge
  # being seen in this cycle; a periodic run's is its due time. A task with both that
  # samples 1 skips the due times that have come, moving its next one past `now` on its
  # phase, and counts none of them (decisions 39 and 51).
  defp due(%__MODULE__{now: now, globals: globals, tasks: states, wiring: %{tasks: tasks}} = rt) do
    {due, states} =
      Enum.flat_map_reduce(tasks, states, fn {name, trigger, priority, index, _} = task, states ->
        {plan, state} = plan(trigger, sample(trigger, globals), Map.fetch!(states, name), now)
        {for(at <- plan, do: {{priority, at, index}, task}), Map.put(states, name, state)}
      end)

    {%{rt | tasks: states}, due |> Enum.sort_by(&elem(&1, 0)) |> Enum.map(&elem(&1, 1))}
  end

  defp sample({nil, _interval}, _globals), do: nil
  defp sample({single, _interval}, globals), do: Map.fetch!(globals, single)

  # What a task does in this cycle: `{[due time], state}` when it runs, `{[], state}`
  # when not, its trigger's last sample kept.
  defp plan({nil, _interval}, nil, %{next_due: next} = state, now) when next <= now,
    do: {[next], state}

  defp plan({nil, _interval}, nil, state, _now), do: {[], state}

  defp plan({_single, nil}, sample, %{last: last} = state, now),
    do: {edge(last, sample, now), %{state | last: sample}}

  defp plan({_single, interval}, sample, %{last: last, next_due: next} = state, now),
    do: both(edge(last, sample, now), sample, {next, interval}, %{state | last: sample}, now)

  defp edge(0, 1, now), do: [now]
  defp edge(_last, _sample, _now), do: []

  # Decision 39: at most one run a cycle; on an edge, or while the trigger samples 0 and a
  # periodic due time has come. A due time that comes while it samples 1, an edge cycle's
  # among them, is skipped and not counted, the next on the same phase, so an edge run
  # does not move the phase; and one that came while the image held 1 runs in the cycle
  # that samples 0 (decision 52), since only the sample is known.
  defp both([now], _sample, {next, interval}, state, now),
    do: {[now], %{state | next_due: skipped(next, interval, now)}}

  defp both([], 1, {next, interval}, state, now),
    do: {[], %{state | next_due: skipped(next, interval, now)}}

  defp both([], 0, {next, _interval}, state, now) when next <= now, do: {[next], state}
  defp both([], 0, _due, state, _now), do: {[], state}

  defp skipped(next, interval, now) when next <= now,
    do: next + (div(now - next, interval) + 1) * interval

  defp skipped(next, _interval, _now), do: next

  # A due task runs once, however many periods have passed: the ones it missed are counted
  # and reported, and its next due time moves past `now` by whole intervals. A task with no
  # interval has none to move and never overlaps, and an edge run's was moved already.
  defp run_task({name, {_single, interval}, _priority, _index, instances}, {runtime, events}) do
    {missed, state} = periods(interval, Map.fetch!(runtime.tasks, name), runtime.now)
    runtime = %{runtime | tasks: Map.put(runtime.tasks, name, state)}
    Enum.reduce(instances, {runtime, overlap(missed, name) ++ events}, &scanned(&1, name, &2))
  end

  defp periods(nil, state, _now), do: {0, state}

  defp periods(interval, %{next_due: next, overlaps: overlaps} = state, now) when next <= now do
    missed = div(now - next, interval)
    {missed, %{state | next_due: next + (missed + 1) * interval, overlaps: overlaps + missed}}
  end

  defp periods(_interval, state, _now), do: {0, state}

  defp overlap(0, _task), do: []
  defp overlap(missed, task), do: [{:overlap, task, missed}]

  # One scan of one instance: its var_inputs copied in, `call/4`, its var_outputs out. M2-4:
  # each var_external's global is merged into the state before `call/4` and split off
  # after, back into the global, before the copy-out: a write through a var_external is
  # made during the scan, and a connection's copy-out after it (decision 47).
  defp scanned(
         name,
         task,
         {%__MODULE__{now: now, globals: globals, wiring: wiring} = runtime, events}
       ) do
    program = Map.fetch!(runtime.config.programs, Map.fetch!(wiring.types, name))
    %Instance{first: first} = state = Map.fetch!(runtime.instances, name)

    inputs =
      Map.new(Map.fetch!(wiring.copy_in, name), fn {member, to} ->
        {member, value(to, globals)}
      end)

    externals = Map.fetch!(wiring.externals, name)
    state = %{state | env: Map.merge(state.env, Map.take(globals, externals))}
    {outputs, state} = call(program, state, inputs, %Scan{now: now, first: first})
    globals = Map.merge(globals, Map.take(state.env, externals))
    state = %{state | env: Map.drop(state.env, externals)}

    globals =
      Enum.reduce(Map.fetch!(wiring.copy_out, name), globals, fn {member, global}, globals ->
        Map.put(globals, global, Map.fetch!(outputs, member))
      end)

    {%{runtime | instances: Map.put(runtime.instances, name, state), globals: globals},
     [{:ran, task, name, now} | events]}
  end

  defp value(global, globals) when is_binary(global), do: Map.fetch!(globals, global)
  defp value(constant, _globals), do: constant

  # An access path: one name token to the lexer, as `m1.t1.acc` is.
  defp path!(path) when is_binary(path), do: path_lexed(Logex.Lexer.tokenize(path), path)
  defp path!(path), do: raise(ArgumentError, not_a_path(path))

  defp string!(path) when is_binary(path), do: path
  defp string!(path), do: raise(ArgumentError, not_a_path(path))

  defp path_lexed({:ok, [{:name, _, path}], _}, path), do: path
  defp path_lexed(_lexed, path), do: raise(ArgumentError, not_a_path(path))

  defp not_a_path(path),
    do:
      "#{inspect(path)} is not an access path: a global, or a program instance, its tag and " <>
        ~s|the members below it, joined by `.`, as in "m1.t1.acc"|

  defp at_path({:ok, _global}, _instance, {head, [], _path}, runtime),
    do: Map.fetch!(runtime.globals, head)

  defp at_path({:ok, global}, _instance, {head, _rest, path}, _runtime),
    do:
      raise(
        ArgumentError,
        "`#{path}` goes too deep: `#{head}` is a #{global.type} global, which has no members"
      )

  defp at_path(:error, {:ok, type}, {head, [], _path}, runtime),
    do:
      raise(
        ArgumentError,
        "`#{head}` is a program instance of `#{type}`: an access path names one of its tags" <>
          example_tag(Map.fetch!(runtime.config.programs, type), head)
      )

  defp at_path(:error, {:ok, type}, {head, [tag | members], path}, runtime) do
    program = Map.fetch!(runtime.config.programs, type)
    read_tag(tag_of(program, tag), {head, tag, members, path}, program, runtime)
  end

  defp at_path(:error, :error, {head, _rest, _path}, runtime),
    do: raise(ArgumentError, unknown_head(kind(runtime, head), head, runtime))

  defp unknown_head(:task, head, _runtime),
    do:
      "`#{head}` is a task, not a global or a program instance: an access path starts at " <>
        "one of those, and overlaps/1 reads a task's overlap count"

  defp unknown_head(:configuration, head, _runtime),
    do:
      "`#{head}` is the configuration's name, which an access path leaves out: it starts " <>
        "at a global or a program instance"

  defp unknown_head(:none, head, runtime) do
    names = Enum.sort(Map.keys(runtime.wiring.globals) ++ Map.keys(runtime.wiring.types))

    "`#{head}` is neither a global nor a program instance" <>
      Declarations.suggest(head, names, & &1, "names")
  end

  # The first of its tags by name, or none for a program that declares none.
  defp example_tag(%Program{tags: tags}, head), do: tag_example(Enum.sort(Map.keys(tags)), head)

  defp tag_example([first | _], head), do: ", as in `#{head}.#{first}`"
  defp tag_example([], _head), do: ", and it declares none"

  # A program's tag, with its instance's type itself: a program, and a block's compiled body,
  # which runs as a program too, name each type their `blocks` hold (decision 53).
  defp tag_of(%Program{tags: tags, blocks: blocks}, name),
    do: fetched(Map.fetch(tags, name), blocks)

  defp fetched({:ok, tag}, blocks), do: {:ok, typed(tag, blocks)}
  defp fetched(:error, _blocks), do: :error

  # M2-4: a var_external is read as its global, the one copy, directly; a path below one
  # goes too deep, as below any bool or dint.
  defp read_tag({:ok, %Tag{section: :var_external}}, {_head, tag, [], _path}, _program, runtime),
    do: Map.fetch!(runtime.globals, tag)

  defp read_tag(found, {head, _tag, _members, _path} = at, program, runtime),
    do: in_program(found, at, program, Map.fetch!(runtime.instances, head).env)

  defp in_program(:error, {head, tag, _members, _path}, program, _env),
    do:
      raise(
        ArgumentError,
        "`#{head}` is a program instance of `#{program.name}`, which declares no `#{tag}`" <>
          Declarations.suggest(tag, Enum.sort(Map.keys(program.tags)))
      )

  defp in_program({:ok, %Tag{type: %FbType{} = type}}, {head, tag, members, path}, _program, env),
    do: in_block(type, "#{head}.#{tag}", members, {[tag], path}, env)

  defp in_program({:ok, %Tag{}}, {_head, tag, [], _path}, _program, env), do: walk(env, [tag])

  defp in_program({:ok, %Tag{type: type}}, {head, tag, _members, path}, _program, _env),
    do:
      raise(
        ArgumentError,
        "`#{path}` goes too deep: `#{head}.#{tag}` is a #{type}, which has no members"
      )

  # A function block instance's public members, as logic names them: never an internal
  # one, and never the instance whole. The walk follows a member whose type is a block as
  # deep as the types go; which members are public, and so how deep a path reaches, is
  # FbType.public/1's.
  defp in_block(type, at, [], _walked, _env),
    do:
      raise(
        ArgumentError,
        "`#{at}` is #{Declarations.instance_of(type)}: an access path names one of its " <>
          "members" <> example(at, FbType.public(type))
      )

  defp in_block(type, at, [member | deeper], {walked, path}, env),
    do: member_at(FbType.member(type, member), type, at, {member, deeper}, {walked, path}, env)

  defp member_at(:error, type, at, {member, _deeper}, _walked, _env) do
    names = Enum.map(FbType.public(type), & &1.name)

    raise(
      ArgumentError,
      no_member(Enum.find(type.members, &(&1.name == member)), type, {at, member}, names)
    )
  end

  # The path walked so far is kept reversed, so a path of any depth is read in time linear
  # in its depth.
  defp member_at(
         {:ok, %FbType.Member{type: %FbType{} = nested}},
         _type,
         at,
         {member, deeper},
         {walked, path},
         env
       ),
       do: in_block(nested, "#{at}.#{member}", deeper, {[member | walked], path}, env)

  defp member_at({:ok, _member}, _type, _at, {member, []}, {walked, _path}, env),
    do: walk(env, Enum.reverse([member | walked]))

  defp member_at({:ok, found}, _type, at, {member, _deeper}, {_walked, path}, _env),
    do:
      raise(
        ArgumentError,
        "`#{path}` goes too deep: `#{at}.#{member}` is a #{found.type}, which has no members"
      )

  # A name the type gives a member but FbType.member/2 does not is a hidden one's, and the
  # path is told which: a built-in block's internal member, or a user block's own `var`,
  # hidden outside it (decision 33). Any other is no member at all.
  defp no_member(%FbType.Member{role: :internal}, _type, {at, member}, names),
    do: "`#{at}.#{member}` is internal to `#{at}`: " <> public_only(names)

  defp no_member(%FbType.Member{role: :local}, type, {at, member}, names),
    do:
      "`#{at}.#{member}` is a `var` of `#{type.name}`, hidden outside it: " <> public_only(names)

  defp no_member(nil, type, {at, member}, names),
    do:
      "`#{at}.#{member}` is not a member of `#{at}`, #{Declarations.instance_of(type)}" <>
        block_hint(Declarations.suggest(member, names, &"#{at}.#{&1}", "members"), names)

  defp public_only([]), do: "an access path reads only its public members, and it has none"

  defp public_only(names),
    do: "an access path reads only its public members, " <> and_list(Enum.map(names, &"`#{&1}`"))

  # The member a read of the instance would mean: the first value the block sets, else the
  # first it is given. A user block may have neither (M2-5).
  defp example(at, members), do: example_of(Enum.sort_by(members, &(&1.role != :output)), at)

  defp example_of([%FbType.Member{name: name} | _], at), do: ", as in `#{at}.#{name}`"
  defp example_of([], _at), do: ", and it has none an access path reads"

  defp block_hint("", []), do: ": it has none an access path reads"
  defp block_hint("", names), do: ": its members are " <> and_list(Enum.map(names, &"`#{&1}`"))
  defp block_hint(suggestion, _names), do: suggestion

  defp and_list([one]), do: one
  defp and_list(items), do: Enum.join(Enum.drop(items, -1), ", ") <> " and " <> List.last(items)

  # The evaluator (B5): private, so no logic runs past the checks above. Each rung starts
  # with power, and `{power_flow, env}` threads through its elements in order. The scan is
  # read-only and the same for every instruction of every rung of one call (M1-6).
  defp rung({:rung, elements}, env, scan) do
    {_power_flow, env} = series(elements, {true, env}, scan)
    env
  end

  defp series(elements, acc, scan), do: Enum.reduce(elements, acc, &element(&1, &2, scan))

  # Every leg runs, from the power flowing into the group, with the env threading through
  # the legs in order, so a leg sees what an earlier one wrote. The group passes power if
  # any leg does: branches do not short-circuit.
  defp element({:branches, legs}, {power, env}, scan) do
    {powers, env} =
      Enum.map_reduce(legs, env, fn leg, env -> series(leg, {power, env}, scan) end)

    {Enum.any?(powers), env}
  end

  defp element(instruction, acc, scan), do: evaluate(instruction, acc, scan)

  # One instruction: `(instruction, {power_flow, env}, %Scan{})` to `{power_flow, env}`, a
  # clause for an energised rung and one for a de-energised one (CLAUDE.md). An operand is
  # `{:name, _, tag}`, `{:int_lit, _, value}` or, since M1-6, `{:member, _, path}`; read/2
  # and write/3 take all three, so no instruction clause cares which it got.
  defp evaluate({:xic, _, [operand]}, {true, env}, _scan) do
    {closed?(read(env, operand)), env}
  end

  defp evaluate({:xic, _, _}, {false, env}, _scan) do
    {false, env}
  end

  defp evaluate({:xio, _, [operand]}, {true, env}, _scan) do
    {not closed?(read(env, operand)), env}
  end

  defp evaluate({:xio, _, _}, {false, env}, _scan) do
    {false, env}
  end

  defp evaluate({:ote, _, [operand]}, {true, env}, _scan) do
    {true, write(env, operand, 1)}
  end

  defp evaluate({:ote, _, [operand]}, {false, env}, _scan) do
    {false, write(env, operand, 0)}
  end

  defp evaluate({:otl, _, [operand]}, {true, env}, _scan) do
    {true, write(env, operand, 1)}
  end

  defp evaluate({:otl, _, _}, {false, env}, _scan) do
    {false, env}
  end

  defp evaluate({:otu, _, [operand]}, {true, env}, _scan) do
    {true, write(env, operand, 0)}
  end

  defp evaluate({:otu, _, _}, {false, env}, _scan) do
    {false, env}
  end

  defp evaluate({:move, _, [source, destination]}, {true, env}, _scan) do
    {true, write(env, destination, read(env, source))}
  end

  defp evaluate({:move, _, _}, {false, env}, _scan) do
    {false, env}
  end

  # The one-shot on the rung condition (docs/naming.md, `ons`): power for the one scan in
  # which the power reaching it rises. The storage bit holds the power it received last
  # scan, read as a contact reads a bit. On an instance's first scan it passes none,
  # whatever the storage bit holds: the conventional ONS's "set to true to prevent an
  # invalid trigger during the first scan", read from the scan rather than set by a
  # prescan (PLAN.md M1-6, decision 3). One whose bit is in `scan.ons_blocked` passes none
  # in the same way, on the scan after an online edit's switch that runs it (OE-1,
  # decision 32): it still writes its bit, which the edit never does, so no rung that
  # reads the bit sees a write that no logic made.
  defp evaluate({:ons, _, [storage]}, {true, env}, %Scan{first: first, ons_blocked: blocked}) do
    {not first and not blocked?(storage, blocked) and not closed?(read(env, storage)),
     write(env, storage, 1)}
  end

  defp evaluate({:ons, _, [storage]}, {false, env}, _scan) do
    {false, write(env, storage, 0)}
  end

  # The six comparisons (docs/naming.md, `eq` to `ge`) are input instructions, as a contact
  # is: energised, power is the comparison of the first operand with the second, `lt a b`
  # reading a < b; de-energised, no power. Neither writes anything.
  defp evaluate({op, _, [a, b]}, {true, env}, _scan) when op in @comparisons do
    {compare(op, read(env, a), read(env, b)), env}
  end

  defp evaluate({op, _, _}, {false, env}, _scan) when op in @comparisons do
    {false, env}
  end

  # The on-delay timer (docs/naming.md, `ton`; docs/organisation.md §4.6). Rung power is
  # its IN. `last` is the time this `ton` last ran, energised or not (decision 5), and
  # energised, `.acc` gains `now - last`, unless `.en` shows it was not already enabled:
  # timing starts at the scan that first sees the rung true, which adds nothing. `.acc`
  # stays in 0..max(.pre, 0), so it never leaves a dint however long the gap, and `.dn` is
  # set when it gets there. De-energised, `.acc .dn .tt .en` go to 0. `last` changes only
  # here, so a timer that does not run (a frozen function block, M2-5) catches up when it
  # next does. The preset operand is not read: it is the timer's starting `.pre`, and logic
  # may have written another. Nothing may follow a `ton` on its path (Logex.Compiler), so
  # the power each clause hands on is never read; which it should be is not settled.
  defp evaluate({:ton, _, [timer, _preset]}, {true, env}, %Scan{now: now}) do
    {true, write(env, timer, timing(as_map(read(env, timer)), now))}
  end

  defp evaluate({:ton, _, [timer, _preset]}, {false, env}, %Scan{now: now}) do
    {false, write(env, timer, reset(as_map(read(env, timer)), now))}
  end

  # M3-2: the off-delay timer (docs/naming.md, `tof`; IEC's TOF). Rung power is its IN.
  # Energised, `.dn` and `.en` are set and `.acc` and `.tt` go to 0. De-energised, the run
  # after an energised one (`.en` 1) starts the delay, adding nothing, and each run while it
  # runs (`.tt` 1) adds `now - last`, as a `ton`'s energised run does, `.acc` staying in
  # 0..max(.pre, 0); at the limit `.dn` and `.tt` go to 0, so with a preset of 0 `.dn` drops
  # on the falling edge's own scan. Otherwise it is at rest: `.dn` and `.tt` 0, and `.acc`
  # where the delay left it. `.en` is 0 on every de-energised run, and `last` is stamped on
  # every run, so a `tof` a frozen block holds catches up when it next runs (decision 8).
  # Its falling edge is read from `.en`, which every start and restart puts at 0, so no first
  # scan sees one (decision 69). Nothing may follow it on its path (decision 73).
  defp evaluate({:tof, _, [timer, _preset]}, {true, env}, %Scan{now: now}) do
    {true, write(env, timer, held_on(as_map(read(env, timer)), now))}
  end

  defp evaluate({:tof, _, [timer, _preset]}, {false, env}, %Scan{now: now}) do
    {false, write(env, timer, off_delay(as_map(read(env, timer)), now))}
  end

  # M3-2: the pulse timer (docs/naming.md, `tp`; IEC's TP; decisions 74, 75 and 94). Rung
  # power is its IN. A rising edge, `.en` 0 from its last run, never on the instance's first
  # scan nor where the edit's block list holds `.en`, starts the pulse: `.tt` set and `.acc`
  # at 0, adding nothing. While `.tt` is set each run adds `now - last`, its rung true or
  # false, `.acc` staying in 0..max(.pre, 0), and an edge starts nothing; at the limit `.tt`
  # drops, and `.dn` is set where the rung is true, or `.dn` and `.acc` go to 0 where it is
  # false. Otherwise, energised it keeps `.dn` and `.acc`, so `.dn` holds while the rung does
  # after a pulse, and de-energised both go to 0. `.en` takes the rung's power and `last` is
  # stamped on every run. The run is recorded as a counter's is, so that the scan keeps no
  # block of a memory whose instruction ran (decision 87). Nothing may follow it on its path
  # (decision 73).
  defp evaluate({:tp, _, [timer, _preset]}, {true, env}, scan) do
    {true, pulsed(env, timer, true, scan)}
  end

  defp evaluate({:tp, _, [timer, _preset]}, {false, env}, scan) do
    {false, pulsed(env, timer, false, scan)}
  end

  # M3-1: IEC's counters (docs/naming.md, `ctu`, `ctd` and `ctud`; decisions 67 to 71 and
  # 84 to 86). Rung power is the count input of the side the mnemonic names, `cu` for a
  # `ctu` and `cd` for a `ctd`, and each run is IEC's body for that side, over the
  # instance's type, which the routine's tag table names: on a `ctu` or a `ctud`, `r` puts
  # `cv` to 0; else on a `ctd` or a `ctud`, `ld` puts it to `pv`; either clears the flags;
  # otherwise a rising edge of the side's input, its edge memory 0 from its last run,
  # counts, never on the instance's first scan nor where the edit's block list holds the
  # memory (decision 87), stopping at the dint's limits with `ov` or `un` set, which stays
  # until a reset or load. The memory then takes the rung's power, a reset or load keeping
  # it as IEC's R_TRIG does (decision 70), and the outputs are set from `cv`. The preset
  # operand is not read: it is the instance's starting `pv`. Nothing may follow a counter on
  # its path (decision 73), so the power each clause hands on is never read.
  defp evaluate({:ctu, _, [counter, _preset]}, {true, env}, scan) do
    {true, counted(env, counter, {:up, true}, scan)}
  end

  defp evaluate({:ctu, _, [counter, _preset]}, {false, env}, scan) do
    {false, counted(env, counter, {:up, false}, scan)}
  end

  defp evaluate({:ctd, _, [counter, _preset]}, {true, env}, scan) do
    {true, counted(env, counter, {:down, true}, scan)}
  end

  defp evaluate({:ctd, _, [counter, _preset]}, {false, env}, scan) do
    {false, counted(env, counter, {:down, false}, scan)}
  end

  # M2-5: `cal` runs an instance of a user function block (docs/organisation.md §4.3).
  # Rung power is its EN, and its ENO is the power out. Energised, each var_input operand
  # is read into the instance, the block's body runs over the instance's own map, with the
  # scan narrowed to it (its type's tag table and its own tree of blocked one-shots, `now`,
  # `first` and the block types the program's), and each var_output is written to its
  # operand. An instance's tag names its type, `{:block, name}`, which the scan's `blocks`
  # holds: the program's one table, which holds every type at any depth (decision 53).
  # De-energised, nothing (decision 12): nothing is copied in, the body does not run and
  # nothing is written out, so the instance and every tag its outputs name keep their
  # values. A timer inside keeps its `.en` and `last` and catches up when the block next
  # runs (decision 8), and an `ons` inside keeps its storage bit, so a block that first runs
  # after the program's first scan can fire one on its first run.
  defp evaluate(
         {:cal, _, [{:name, _, instance} | operands]},
         {true, env},
         %Scan{tags: tags, blocks: blocks} = scan
       ),
       do: {true, called(typed(Map.get(tags, instance), blocks), instance, operands, env, scan)}

  defp evaluate({:cal, _, _}, {false, env}, _scan) do
    {false, env}
  end

  # The block list names storage bits, and a storage bit is a declared bool of the routine
  # running, always a `{:name, _, bit}`: the compiler refuses an `ons` on a member, a
  # counter's `r` or `ld`, the only bool members logic may write (M3-1). An `ons` on a
  # member, which only a program built by hand can hold, is never blocked. A counter's edge
  # memory is blocked by its own instruction (counted/4). A
  # bit inside an instance is in the tree under the instance's name, which a `cal` hands its
  # body (M2-5); a storage bit is never named as an instance of its routine is.
  defp blocked?({:name, _, bit}, blocked), do: is_map_key(blocked, bit)
  defp blocked?({:member, _, _path}, _blocked), do: false

  # The type of an instance a `cal` runs: the one its tag names, or a tag's own in a program
  # built by hand. A name the program's blocks lack, which only a program built by hand can
  # give, is no type, and nothing runs.
  defp typed(%Tag{type: {:block, name}} = tag, %{} = blocks),
    do: %{tag | type: Map.get(blocks, name)}

  defp typed(tag, _blocks), do: tag

  # A `cal` of an instance its routine's table holds as a user block's. A program built by
  # hand may name one its table lacks, or one of another type: nothing runs, as nothing runs
  # for a hand-built env a `ton` finds no timer in.
  defp called(
         %Tag{type: %FbType{body: %Program{rungs: rungs, tags: own}} = type},
         instance,
         operands,
         env,
         %Scan{ons_blocked: blocked} = scan
       ) do
    [_instance | formals] = FbType.signature(type)
    slots = Enum.zip(formals, operands)
    state = Enum.reduce(slots, as_map(Map.get(env, instance)), &copy_in(&1, &2, env))
    inner = as_map(Map.get(blocked, instance))
    body = %{scan | tags: own, ons_blocked: inner}
    {state, env} = ran(instance, Enum.reduce(rungs, state, &rung(&1, &2, body)), env)
    Enum.reduce(slots, Map.put(env, instance, state), &copy_out(&1, &2, state))
  end

  defp called(_not_a_block, _instance, _operands, env, _scan), do: env

  # M2-5: an instance records that its body ran, with what its own body's `cal`s recorded,
  # so that the scan keeps the blocked bits of those that did not.
  defp ran(instance, state, env) do
    {nested, state} = recorded(state)
    {state, Map.put(env, @ran, Map.put(as_map(Map.get(env, @ran)), instance, nested))}
  end

  # M2-5: a `cal`'s copy-in and copy-out, by the formal each operand fills.
  defp copy_in({{{:value, _}, %Member{name: name}}, operand}, state, env),
    do: Map.put(state, name, read(env, operand))

  defp copy_in(_output, state, _env), do: state

  defp copy_out({{{:write, _}, %Member{name: name}}, operand}, env, state),
    do: write(env, operand, Map.get(state, name, 0))

  defp copy_out(_input, env, _state), do: env

  # M3-1: one run of a counter's side. Its kind is its tag's type in the routine's table;
  # an instance a program built by hand holds no tag for counts as the mnemonic's own. The
  # compiler names a counter only whole, `{:name, _, counter}`. Its
  # edge memory is blocked where the edit's block list names it, `boxes.cu` under the
  # counter's name in the tree, and the run is recorded as a `cal`'s is, so that the scan
  # keeps no block of a memory whose instruction ran (decision 87).
  defp counted(env, {:name, _, name} = counter, {side, power}, %Scan{} = scan) do
    kind = counter_kind(Map.get(scan.tags, name), side)
    memory = memory(side)
    tree = as_map(Map.get(scan.ons_blocked, name))
    blocked = scan.first or Map.get(tree, memory) == true
    state = as_map(read(env, counter))
    edge = power and not blocked and not closed?(Map.get(state, memory))
    env = write(env, counter, count(kind, side, state, {power, edge}))
    unblocked(map_size(tree) > 0, env, name)
  end

  defp counter_kind(%Tag{type: %FbType{name: kind, body: nil}}, _side)
       when kind in ["ctu", "ctd", "ctud"],
       do: kind

  defp counter_kind(_no_tag, :up), do: "ctu"
  defp counter_kind(_no_tag, :down), do: "ctd"

  defp memory(:up), do: "cu"
  defp memory(:down), do: "cd"

  defp unblocked(true, env, name),
    do: Map.put(env, @ran, Map.put(as_map(Map.get(env, @ran)), name, %{}))

  defp unblocked(false, env, _name), do: env

  @dint_max 2_147_483_647
  @dint_min -2_147_483_648

  # Whatever a hand-built env left in a counter, a well-formed one comes back: a member that
  # is not an integer reads 0, and a bit is read as a contact.
  defp count(kind, side, state, {power, edge}) do
    pv = integer(Map.get(state, "pv"))
    flags = {closed?(Map.get(state, "ov")), closed?(Map.get(state, "un"))}
    {cv, {ov, un}} = step(kind, side, state, {integer(Map.get(state, "cv")), pv, flags, edge})
    members(kind, state, %{"pv" => pv, "cv" => cv, "ov" => ov, "un" => un}, {side, power})
  end

  # IEC's priority, R before LD before a count (Ed 3 Table 45): a ctu has no `ld` and a
  # ctd no `r`.
  defp step(kind, side, state, {cv, pv, flags, edge}),
    do: step(kind, reset?(kind, state), load?(kind, state), side, {cv, pv, flags, edge})

  defp step(_kind, true, _load, _side, {_cv, _pv, _flags, _edge}), do: {0, {false, false}}
  defp step(_kind, false, true, _side, {_cv, pv, _flags, _edge}), do: {pv, {false, false}}
  defp step(_kind, false, false, _side, {cv, _pv, flags, false}), do: {cv, flags}

  defp step(_kind, false, false, :up, {cv, _pv, {_ov, un}, true}) when cv >= @dint_max,
    do: {cv, {true, un}}

  defp step(_kind, false, false, :up, {cv, _pv, flags, true}), do: {cv + 1, flags}

  defp step(_kind, false, false, :down, {cv, _pv, {ov, _un}, true}) when cv <= @dint_min,
    do: {cv, {ov, true}}

  defp step(_kind, false, false, :down, {cv, _pv, flags, true}), do: {cv - 1, flags}

  defp reset?("ctd", _state), do: false
  defp reset?(_kind, state), do: closed?(Map.get(state, "r"))

  defp load?("ctu", _state), do: false
  defp load?(_kind, state), do: closed?(Map.get(state, "ld"))

  # Each kind's members, the side's memory taking the rung's power and the other side's
  # kept.
  defp members("ctu", state, %{"pv" => pv, "cv" => cv, "ov" => ov}, {:up, power}),
    do: %{
      "cu" => one(power),
      "r" => bit(Map.get(state, "r")),
      "pv" => pv,
      "q" => one(cv >= pv),
      "cv" => cv,
      "ov" => one(ov)
    }

  defp members("ctd", state, %{"pv" => pv, "cv" => cv, "un" => un}, {:down, power}),
    do: %{
      "cd" => one(power),
      "ld" => bit(Map.get(state, "ld")),
      "pv" => pv,
      "q" => one(cv <= 0),
      "cv" => cv,
      "un" => one(un)
    }

  defp members("ctud", state, %{"pv" => pv, "cv" => cv, "ov" => ov, "un" => un}, {side, power}),
    do:
      Map.merge(
        %{
          "cu" => bit(Map.get(state, "cu")),
          "cd" => bit(Map.get(state, "cd")),
          "r" => bit(Map.get(state, "r")),
          "ld" => bit(Map.get(state, "ld")),
          "pv" => pv,
          "qu" => one(cv >= pv),
          "qd" => one(cv <= 0),
          "cv" => cv,
          "ov" => one(ov),
          "un" => one(un)
        },
        %{memory(side) => one(power)}
      )

  defp bit(value), do: one(closed?(value))

  # `ne`, `ge` and `le` are the negations of `eq`, `lt` and `gt`, so each pair is
  # complementary by construction, as `xic` and `xio` are (M1-4). Erlang's term order is
  # total, so a comparison of whatever a hand-built env holds never raises.
  defp compare(:eq, a, b), do: a == b
  defp compare(:ne, a, b), do: not compare(:eq, a, b)
  defp compare(:lt, a, b), do: a < b
  defp compare(:ge, a, b), do: not compare(:lt, a, b)
  defp compare(:gt, a, b), do: a > b
  defp compare(:le, a, b), do: not compare(:gt, a, b)

  # Whatever a hand-built env left in a timer, a well-formed one comes back: a member that
  # is not an integer reads 0, `.en` is read as a contact, and a `last` that is not an
  # integer, or is later than now, adds nothing. A negative `.acc`, which logic may write,
  # counts from 0: it is floored before the time is added, not after.
  defp timing(timer, now) do
    pre = integer(Map.get(timer, "pre"))
    limit = max(pre, 0)
    elapsed = elapsed(closed?(Map.get(timer, "en")), Map.get(timer, "last"), now)
    acc = min(max(integer(Map.get(timer, "acc")), 0) + elapsed, limit)
    done = acc == limit

    %{
      "pre" => pre,
      "acc" => acc,
      "dn" => one(done),
      "tt" => one(not done),
      "en" => 1,
      "last" => now
    }
  end

  defp reset(timer, now),
    do: %{
      "pre" => integer(Map.get(timer, "pre")),
      "acc" => 0,
      "dn" => 0,
      "tt" => 0,
      "en" => 0,
      "last" => now
    }

  # M3-2: a `tof`'s runs, energised and not.
  defp held_on(timer, now),
    do: %{
      "pre" => integer(Map.get(timer, "pre")),
      "acc" => 0,
      "dn" => 1,
      "tt" => 0,
      "en" => 1,
      "last" => now
    }

  defp off_delay(timer, now),
    do: delayed(closed?(Map.get(timer, "en")) or closed?(Map.get(timer, "tt")), timer, now)

  defp delayed(true, timer, now) do
    pre = integer(Map.get(timer, "pre"))
    limit = max(pre, 0)
    elapsed = elapsed(closed?(Map.get(timer, "tt")), Map.get(timer, "last"), now)
    acc = min(max(integer(Map.get(timer, "acc")), 0) + elapsed, limit)
    running = acc != limit

    %{
      "pre" => pre,
      "acc" => acc,
      "dn" => one(running),
      "tt" => one(running),
      "en" => 0,
      "last" => now
    }
  end

  defp delayed(false, timer, now),
    do: %{
      "pre" => integer(Map.get(timer, "pre")),
      "acc" => integer(Map.get(timer, "acc")),
      "dn" => 0,
      "tt" => 0,
      "en" => 0,
      "last" => now
    }

  # M3-2: one run of a `tp`. The compiler names a timer only whole, `{:name, _, timer}`.
  defp pulsed(env, {:name, _, name} = timer, power, %Scan{now: now} = scan) do
    tree = as_map(Map.get(scan.ons_blocked, name))
    blocked = scan.first or Map.get(tree, "en") == true
    state = as_map(read(env, timer))
    edge = power and not blocked and not closed?(Map.get(state, "en"))
    env = write(env, timer, pulse(closed?(Map.get(state, "tt")), edge, state, {power, now}))
    unblocked(map_size(tree) > 0, env, name)
  end

  # Pulsing: the time since its last run, whatever the rung or an edge.
  defp pulse(true, _edge, timer, {power, now}) do
    acc = max(integer(Map.get(timer, "acc")), 0) + elapsed(true, Map.get(timer, "last"), now)
    pulsing(timer, acc, {power, now})
  end

  # A rising edge starts the pulse from 0.
  defp pulse(false, true, timer, at), do: pulsing(timer, 0, at)

  # Neither: held true, `.dn` and `.acc` as they were; false, both 0.
  defp pulse(false, false, timer, {true, now}),
    do: %{
      "pre" => integer(Map.get(timer, "pre")),
      "acc" => integer(Map.get(timer, "acc")),
      "dn" => bit(Map.get(timer, "dn")),
      "tt" => 0,
      "en" => 1,
      "last" => now
    }

  defp pulse(false, false, timer, {false, now}),
    do: %{
      "pre" => integer(Map.get(timer, "pre")),
      "acc" => 0,
      "dn" => 0,
      "tt" => 0,
      "en" => 0,
      "last" => now
    }

  defp pulsing(timer, acc, {power, now}) do
    pre = integer(Map.get(timer, "pre"))
    limit = max(pre, 0)
    acc = min(acc, limit)
    timer = %{"pre" => pre, "acc" => acc, "en" => one(power), "last" => now}
    ended(acc == limit, power, timer)
  end

  defp ended(false, _power, timer), do: Map.merge(timer, %{"dn" => 0, "tt" => 1})
  defp ended(true, true, timer), do: Map.merge(timer, %{"dn" => 1, "tt" => 0})
  defp ended(true, false, timer), do: Map.merge(timer, %{"acc" => 0, "dn" => 0, "tt" => 0})

  defp elapsed(true, last, now) when is_integer(last), do: max(now - last, 0)
  defp elapsed(_enabled, _last, _now), do: 0

  defp integer(value) when is_integer(value), do: value
  defp integer(_not_an_integer), do: 0

  defp one(true), do: 1
  defp one(false), do: 0

  # An operand's value: a literal's own, a tag's, or a member's, reached by its path. A tag
  # or member the env leaves out, or one whose instance a hand-built env left as anything
  # but a map, reads as 0, as a missing tag always has, so `move` copies a 0, not a nil.
  defp read(_env, {:int_lit, _, value}), do: value
  defp read(env, {:name, _, name}), do: Map.get(env, name, 0)
  defp read(env, {:member, _, path}), do: walk(env, path)

  defp walk(value, []), do: value
  defp walk(%{} = map, [key | path]), do: walk(Map.get(map, key, 0), path)
  defp walk(_not_a_map, _path), do: 0

  # A write to a member puts an instance back together where a hand-built env broke it:
  # what is not a map on the way becomes one.
  defp write(env, {:name, _, name}, value), do: Map.put(env, name, value)
  defp write(env, {:member, _, path}, value), do: put_path(env, path, value)

  defp put_path(map, [key], value), do: Map.put(map, key, value)

  defp put_path(map, [key | path], value),
    do: Map.put(map, key, put_path(as_map(Map.get(map, key)), path, value))

  defp as_map(%{} = map), do: map
  defp as_map(_not_a_map), do: %{}

  # M1-4: `xic` reads this and `xio` its negation, so the two are complementary by
  # construction, whatever the env holds. The compiler lets only a bool reach a contact,
  # but an env the host builds by hand can hold a 5, a 0.0, a `false`, a nil, or leave a
  # tag out. A number is read by value, nonzero closed (PLAN.md §5), and a boolean as
  # itself; nil and a missing tag are open; anything else is closed. A member is read
  # the same way (M1-6).
  defp closed?(value) when is_number(value), do: value != 0
  defp closed?(value) when value in [nil, false], do: false
  defp closed?(_value), do: true
end
