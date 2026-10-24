defmodule Logex.Runtime do
  @moduledoc """
  Runs a compiled program as instances, one scan at a time. Nothing here reads a clock:
  the host injects time.

  - `instance/1` makes an instance's state, every tag at its initial value.
  - `call/4` is one scan of one instance: copy the inputs in, run the rungs in order, give
    the outputs back. It is what a configuration's scheduler calls for each instance it runs.
    Since M3-5 a `jmp` whose rung is true skips the rungs after it up to the one its label
    heads, `lbl`, once its own rung is done: a skipped rung runs nothing, so all it holds is
    frozen, as in a function block whose `cal` is false, and a timer in it catches up when
    it next runs (decisions 81, 82 and 104).
  - `put_inputs/3`, `scan/2` and `scan/3` are the task-less sugar: the implicit
    configuration of one instance, whose var_inputs are the host's input image.
  - `restart/3` starts an instance again, keeping its clock and the inputs that fit their
    types.
  - `start/1`, `cycle/3`, `next_due_in/1`, `overlaps/1`, `get/2`, `get!/2` and `restart/2` run a
    configuration (`Logex.Configuration`) as one resource, `%Logex.Runtime{}`, below.
    Since M4-3 `cycle/3` is the composition of three internal steps, hidden as `edited/2`
    is, which `Logex.Runner` calls so that it can read its clock between a cycle's task
    runs (decision 118): the host contract does not change.

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
     and the untimed instances run last, once each, in every cycle, in that order too:
     those with no task and, since M4-2, those of the configuration's continuous task,
     with `with` naming it or none, which means the same (decision 111). The continuous
     task is never due and never overlaps, and is listed at 0.
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
  the continuous task's name for an untimed instance where the configuration declares one
  (M4-2, decision 111), and `:none` where it declares none, `{:overlap, task, missed}`, just before its task's
  scans, and since M3-3 `{:fault, task, instance, fault}`, a `%Logex.Fault{}`, each
  fault the scan met, just after its scan's `{:ran, ...}`, in the order they happened
  (decision 99): a minor one, a zero divisor, which the plant runs on through, and since
  M5-9 a major one, a bit whose number a tag holds out of its word's bits (decisions 153
  and 160), and since M5-12 an element whose subscript a tag holds outside its dimension
  (decision 153), whose instruction did nothing, the scan and the cycle running on: a cycle runs
  every due step whatever its events, so a host driving the resource itself sees the
  event and decides, where `Logex.Runner` trips at the end of the step that met the
  round's first. They are an open set: a host tolerates a
  kind it does not know; an event task's run is its `{:ran, ...}` events, with no kind of
  its own. `next_due_in/1` is when a
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
    restarts it through `restart/3`. A cycle reports the faults of its scan as events and
    keeps none (M3-3, decision 99), so its `faults` is `[]` between cycles, and a restart
    and an edit's switch find it so. An edit's switch moves a kept one by its program
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
    the continuous task (M4-2) is never due and keeps an overlap count of 0, and no edit
    adds or removes it, or makes a task continuous or timed (decision 129);
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
  and since M3-1 the counters' edge memories whose `ctu` or `ctd` it blocks, and since M3-4
  the storage bits whose `osr` or `osf` it blocks,
  which an edit's switch sets and only the runtime fills into a scan (`Logex.Scan`), and a
  scan empties but for a bit inside an instance whose body it did not run (M2-5), and since
  M3-5 one on a rung a jump skipped (decision 106); and
  `switched`, which an edit's switch sets and a scan clears. Since M3-3 a third,
  `faults`, the faults of its last scan (decision 99), which each scan replaces and
  nothing else writes, is how a lone instance's host sees a zero divisor, and since M5-9 a
  bit number out of range, a major fault, and since M5-12 a subscript out of range, the
  scan run on: after `call/4`,
  `scan/2` or `scan/3`, `state.faults` is every `%Logex.Fault{}` that scan met, in order,
  `[]` for none.

  **The host contract.** A mistake by the host raises `ArgumentError` (a host bug, not a
  PLC event, `docs/organisation.md` §4.6); a mistake in the source is a diagnostic from
  `Logex.compile/2`. Only a declared `var_input` may be set, by its name as a string, with
  a value that fits its type exactly, by `Logex.Declarations.fits?/2`: a bool is 0 or 1, a
  dint an integer from -2147483648 to 2147483647, and since M5-3 each integer width an
  integer in its own range, a uint 0 to 65535, and since M5-10 a real any number within its
  range, stored as its nearest value, 16777217 in a `real` as 16777216.0, 2^128 refused
  (decision 166). Since M5-11 (decision 151) an array var_input is set whole, as a list of
  its first dimension's size, a list of lists for more dimensions, each element fitting its
  type, a misfit a line by the element's name, `w[1,2]`, and since decision 222 one element
  alone may be set by its name, `%{"steps[3]" => 5}`, every other kept, one subscript a
  dimension, each a number within it, and one call setting an array whole or by its
  elements, each once; and an array var_output is given as such a list. Every input problem in one call
  comes in one raise, a line each, in key order. Inputs merge into the instance, so a host
  sends only what changed. Outputs are every `var_output`.
  Time never goes backwards for an instance, and a `%Logex.Scan{}` must agree with it about
  `first`; its `ons_blocked` is the runtime's, which `call/4` fills in with a map of the
  bits the instance's list names, so a host leaves it out. A state is matched to its program
  by name, and since decision 171 its values are checked wherever it is handed in, after
  its owner: an integer outside its tag's or member's type, 5000000000 in a dint or 5 in a
  bool, at any depth, is refused, every such value a line of one message, so that nothing
  outside its type ever reaches a scan; and since decision 173 a value that is no integer
  in a bool or an integer tag or member, 37.5, `nil` or `"x"`, is outside its type too,
  "it is a dint, and its value must be an integer, found 37.5", retiring M1-4's reading
  of one for a state handed in; so since decision 184 is an instance's tag that holds no
  map, "it is a ton, and its value must be a map of its members, found 5", and since
  decision 186 a timer's `last` that is no integer, and since decision 188 one later than the instance's `now`,
  and since M5-10 a real's value that is no value of its type, an integer, −0.0, a
  subnormal or, in a `real`, a float no single is, "it is a real, and 0.1 is no value of
  a real, whose nearest is 0.10000000149011612" (decision 150), and since M5-11 an array
  whose value is no tuple of its sizes, "its value must be a tuple of 2 tuples of 3
  elements", an element outside its type by the element's name, `w[0,2]`, and a state
  that lacks an array, which a state holds whole, so that a write of an element always
  finds its array. A resource's instance is checked as each scan takes it, and before it
  each global a connection copies into it against the global's own type, which may be
  narrower than the var_input it fills (decision 159): "runtime.globals holds `a`
  outside its type: it is a uint, and 70000 is outside 0 to 65535", and since M5-11 a
  global array a connection copies whole whose value is no tuple of its sizes of its
  elements' values. A resource's instance is restarted with its var_externals' globals in
  its state, as a scan takes it. The check is linear in the state, a guard a value. Its env's keys are tag names: a scan
  keeps its own records in a routine's env under atoms no tag can be, `:faults`, `:jump` and
  `:ran`, and takes each out before it ends, so an env holding one is refused, since it
  would change the run; a block instance's map holding one has it dropped before its body
  runs.
  Scanning a recompile of
  the same name over a kept instance, a *plain swap*, stays in this contract: the instance
  keeps its values until `restart/3`, so a tag the recompile adds reads 0, an added timer
  starting at a `.pre` of 0, a tag whose type it changes keeps its old value, refused at
  the next call where it is an integer outside its new type (decision 171), or a value
  that is no map under what is now an instance (decision 184), a timer's map
  reaching the outputs and the contacts, and a timer whose `ton` it gives back catches up
  all the time it was not run.
  `Logex.Edit` moves a state to a new program by rule instead: it starts what is added,
  restarts a value that does not fit its type, refuses a type change, moves a timer's
  `.pre` to a changed preset where logic left it alone, resumes a timer it gives back
  its `ton` from the switch, and blocks each one-shot and counter it adds or changes until a scan runs
  it, the next scan at the top level, or the next that does not skip its rung (decision
  106), where a plain swap's first scan can fire one whose condition was already true;
  inside a function block's instance it does each of these by the member's path (M2-5).
  `restart/3` starts every tag again but the `var_input`s whose values fit their types,
  and empties `ons_blocked`. A program whose arithmetic computes in a destination that
  has no integer type, its tag retyped or taken out of the table, which only a program
  edited by hand after it compiled holds, is refused a line each
  (`Logex.Program.edited_by_hand/1`, decision 182) where it is first handed in, since
  decision 190 once: `instance/1`, `start/1` through `Logex.Configuration.check/1`, and
  an edit's accept, since decision 200 for the program running as well as its candidate;
  and since decision 197 so is one whose `units`, each timer's unit, are not the ones its
  tags give (`Logex.Program.units/1`). Every other entry point checks only a program's
  shape, so a program swapped in by hand after that check is trusted, and a scan that
  reaches such a destination raises there. Otherwise a `%Logex.Program{}`,
  `%Logex.Instance{}` or `%Logex.Edit{}` built or edited by hand is outside this contract, and so is one that holds a block type whose body
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

  alias Logex.{
    Configuration,
    Declarations,
    Diagnostic,
    Fault,
    FbType,
    Instance,
    Program,
    Scan,
    Tag,
    Walk
  }

  alias Logex.FbType.Member
  import Logex.Declarations, only: [is_elementary: 1, is_fitting: 2]

  @comparisons [:eq, :ne, :lt, :gt, :le, :ge]

  # M3-3: the arithmetic of two sources whose result is wrapped into its destination's type
  # (decision 146; a dint until M5-4), the two that divide, whose divisor may be 0
  # (decision 78), and the two of one source.
  @sums [:add, :sub, :mul]
  @divisions [:div, :mod]
  @signs [:neg, :abs]

  # M5-8: the bitwise instructions of two sources (decision 155), and the shifts and
  # rotates, whose second operand is a count (decision 165).
  @bitwise [:and, :or, :xor]
  @shifts [:shl, :shr, :rol, :ror]

  # The dint's limits, from the one table of types (M5-1): a counter of no tag's.
  @dint Declarations.range(:dint)

  # M5-3 (decision 148): each integer conversion's symbol, `:dint_to_int`, to the type it
  # writes, every ordered pair of two integer types of the one table.
  @integers Declarations.integers()

  @conversions for from <- Declarations.integers(),
                   to <- Declarations.integers(),
                   word = Declarations.conversion(from, to),
                   into: %{},
                   do: {String.to_atom(word), to}

  # M5-8 (decisions 148 and 155): each conversion with a bit string at either end, to its
  # `from` type's width and its `to` type, a binary transfer (Ed 3 Tables 24 and 25).
  @bit_strings Declarations.bit_strings()
  # Decision 214: the types a bitwise instruction's source computes in, its own.
  @bitwise_types [:bool | @integers ++ @bit_strings]

  @transfers for from <- Declarations.convertible(),
                 to <- Declarations.convertible(),
                 from in @bit_strings or to in @bit_strings,
                 word = Declarations.conversion(from, to),
                 into: %{},
                 do: {String.to_atom(word), {Declarations.width(from), to}}

  # M5-10 (decisions 148, 150, 161 and 162): the reals, the 34 real conversions, each
  # symbol to the type it writes, and the 16 truncations, each to its integer type.
  @reals Declarations.reals()

  @real_conversions for from <- @integers ++ @reals,
                        to <- @integers ++ @reals,
                        from in @reals or to in @reals,
                        word = Declarations.conversion(from, to),
                        into: %{},
                        do: {String.to_atom(word), to}

  @truncations for from <- @reals,
                   to <- @integers,
                   into: %{},
                   do: {String.to_atom("#{from}_trunc_#{to}"), to}

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

  # M3-3: the key under which a routine records the minor faults its scan met (decision
  # 99), an atom too, so no tag or member name can be it.
  @faults :faults
  # M5-9: what a read or write of a bit whose number is out of range throws, to its
  # instruction's element (element/3), never past it, with the fault's kind and what it
  # read; since M5-12 so does an element whose subscript is (decision 153).
  @out_of_range {__MODULE__, :out_of_range}

  # M3-5: the key under which an energised `jmp` records its label until its rung is done
  # (decision 104), an atom too; and the mark a skipped rung's edge memory gets in the record
  # under `@ran`, which keeps it on the block list (decision 106).
  @jump :jump
  @skipped :skipped

  # The keys a routine's env holds its records under while it runs, which the routine that
  # ran it takes out when it is done, so that no state holds one between scans: an env a
  # host hands in holding one is refused (state!/2), and a block instance's map holding one
  # has it dropped before its body runs (members_of/1). A key the runtime adds joins them,
  # and the guard of state!/2's refusal, which names each, since a guard reads no list.
  @own_keys [@faults, @jump, @ran]

  # M3-5: the instructions whose edge memory a skipped rung must mark to keep it blocked:
  # the one-shots, whose storage bits are leaves of the routine's own tree (Logex.Walk.
  # one_shots/0), and a counter's two sides, a `ctu`'s `cu` and a `ctd`'s `cd` (counted/4),
  # since a ctud's other side may run. A `tp`'s `en` needs no mark: one `tp` runs its
  # instance, so a skipped one leaves its instance out of the record, and kept/4 keeps all
  # its instance holds.
  @one_shots Walk.one_shots()
  @memories %{ctu: "cu", ctd: "cd"}

  @doc "A new instance of `program`: every tag at its initial value, before its first scan."
  def instance(program) do
    checked!(program)
    fresh(program)
  end

  # Decision 190: a new instance of a program already checked where it was handed in, a
  # configuration's by `Logex.Configuration.check/1`, so that `start/1` and a
  # configuration edit's switch check each program once, not once an instance. Internal.
  @doc false
  def fresh(program),
    do: %Instance{type: program.name, env: Program.initial_env(program), now: 0, first: true}

  @doc """
  One scan of one instance, at `scan.now`: `inputs` are copied in, the rungs run in order,
  a `jmp` whose rung is true skipping those after it up to the one its label heads (M3-5),
  and `{outputs, state}` comes back, the outputs being every `var_output`.
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
          {name, detached(fresh(Map.fetch!(config.programs, type)), wiring, name)}
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
    {runtime, steps} = cycle_steps(runtime, elapsed_ms, inputs)

    {runtime, events} =
      Enum.reduce(steps, {runtime, []}, fn step, {runtime, events} ->
        {runtime, ran} = cycle_step(runtime, step)
        {runtime, Enum.reverse(ran, events)}
      end)

    {runtime, cycle_outputs(runtime), Enum.reverse(events)}
  end

  @doc false
  # M4-3, decision 118: the cycle in steps, internal as edited/2 is, so that the wall-clock
  # runner can read its clock between them and time each task's run; cycle/3 is exactly
  # their composition. cycle_steps/3 is a cycle's first three steps, the clock moved on, the
  # input image merged and every trigger sampled, and gives each run the cycle makes, in
  # the order it makes them: each due timed task, `{:timed, task, run}`, and then, where
  # any exists, the untimed instances, `{:untimed, task, run}`, under the continuous task's
  # name or `:none` (decision 111). Each step is a pure function of the resource, read by
  # no clock: cycle_step/2 runs one, giving its events in order, and cycle_outputs/1 is the
  # output points after the last.
  def cycle_steps(runtime, elapsed_ms, inputs) do
    %__MODULE__{now: now} = runtime = runtime!(runtime)
    elapsed = elapsed!(elapsed_ms)
    runtime = %{runtime | now: now + elapsed, globals: image!(runtime, inputs)}
    {runtime, due} = due(runtime)

    {runtime,
     Enum.map(due, fn {name, _trigger, _priority, _index, _instances} = task ->
       {:timed, name, task}
     end) ++ untimed_step(runtime.wiring.untimed)}
  end

  defp untimed_step({_task, []}), do: []
  defp untimed_step({task, instances}), do: [{:untimed, task, instances}]

  @doc false
  # One step cycle_steps/3 gave, run: `{runtime, events}`, its events in the order they
  # happened.
  def cycle_step(%__MODULE__{} = runtime, {:timed, _name, task}) do
    {runtime, events} = run_task(task, {runtime, []})
    {runtime, Enum.reverse(events)}
  end

  def cycle_step(%__MODULE__{} = runtime, {:untimed, task, instances}) do
    {runtime, events} = Enum.reduce(instances, {runtime, []}, &scanned(&1, task, &2))
    {runtime, Enum.reverse(events)}
  end

  @doc false
  # The output points, every one, after a cycle's last step.
  def cycle_outputs(%__MODULE__{wiring: wiring, globals: globals}),
    do: Map.new(wiring.outputs, &{&1, Map.fetch!(globals, &1)})

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
            restarted =
              restart(
                Map.fetch!(config.programs, state.type),
                attached(state, runtime, name),
                mode
              )

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
  # start/1 and by restart/2, so a trigger already 1 fires in the next cycle. The
  # continuous task (M4-2) has no due time and never overlaps: overlaps/1 lists it at 0,
  # and next_due_in/1 counts it not.
  defp task_state(%Configuration.Task{continuous: true}, _due),
    do: %{next_due: nil, overlaps: 0}

  defp task_state(%Configuration.Task{single: nil}, due), do: %{next_due: due, overlaps: 0}

  defp task_state(%Configuration.Task{interval: nil}, _due),
    do: %{next_due: nil, overlaps: 0, last: 0}

  defp task_state(%Configuration.Task{}, due), do: %{next_due: due, overlaps: 0, last: 0}

  # M5-11: a state is restarted, and checked, with its var_externals' globals in it, as a
  # scan takes it, so that an array var_external, which a state holds whole, is there.
  defp attached(%Instance{env: env} = state, runtime, name),
    do: %{
      state
      | env: Map.merge(env, Map.take(runtime.globals, Map.fetch!(runtime.wiring.externals, name)))
    }

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
  of a function block instance in it, `"m1.t1.acc"`, as logic names one; and since M5-11
  an array whole, global or tag, given as a host is given one, a list, a list of lists for
  more dimensions, or an element of one by literal subscripts, `"temps[3]"` or
  `"m1.grid[1,7]"`, a var_external's read in its global. A string that
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
    at_head(Logex.Array.split(head), {head, rest, path}, runtime)
  end

  defp at_head(nil, {head, _rest, _path} = at, runtime),
    do:
      at_path(
        Map.fetch(runtime.wiring.globals, head),
        Map.fetch(runtime.wiring.types, head),
        at,
        runtime
      )

  # M5-11 (§4.12): an element of a global array, `temps[3]`, by literal subscripts.
  defp at_head({array, subscripts}, at, runtime),
    do: global_element(Map.fetch(runtime.wiring.globals, array), {array, subscripts}, at, runtime)

  defp global_element({:ok, global}, {array, subscripts}, {head, [], _path}, runtime),
    do:
      element_at(
        global.type,
        subscripts,
        {head, array, Declarations.a_global(global.type)},
        Map.fetch!(runtime.globals, array)
      )

  defp global_element({:ok, _global}, _array, {head, _rest, path}, _runtime),
    do:
      raise(
        ArgumentError,
        "`#{path}` goes too deep: `#{head}` is an element, which has no members"
      )

  defp global_element(:error, {array, _subscripts}, {head, _rest, _path}, runtime),
    do:
      raise(
        ArgumentError,
        unknown_element_head(Map.fetch(runtime.wiring.types, array), array, head, runtime)
      )

  defp unknown_element_head({:ok, _type}, array, head, _runtime),
    do:
      "`#{head}` names an element of `#{array}`, a program instance: an access path names " <>
        "an element of one of its tags, as in `#{array}.temps[3]`"

  defp unknown_element_head(:error, array, _head, runtime),
    do: unknown_head(kind(runtime, array), array, runtime)

  # An element of an array, by its subscripts as written, each a literal number in its
  # dimension, of a tag or a global `what` names.
  defp element_at({:array, _type, dims}, subscripts, {head, array, what}, value),
    do:
      Logex.Array.fetch(
        value,
        path_index(Enum.map(subscripts, &Logex.Array.subscript/1), dims, {head, array, what})
      )

  defp element_at(_type, _subscripts, {head, array, what}, _value),
    do:
      raise(
        ArgumentError,
        "`#{head}` names an element of `#{array}`, but `#{array}` is #{what}, no array"
      )

  defp path_index(subscripts, dims, {head, array, what}) do
    tags = for {:tag, name} <- subscripts, do: name
    index = for {:literal, n} <- subscripts, do: n
    indexed(tags, index, dims, {head, array, what})
  end

  defp indexed([name | _], _index, _dims, {head, array, _what}),
    do:
      raise(
        ArgumentError,
        "`#{head}`'s subscript `#{name}` is a tag's name: an access path names an element by " <>
          "literal subscripts, as in `#{array}[0]`"
      )

  defp indexed([], index, dims, {head, array, what}) when length(index) != length(dims),
    do:
      raise(
        ArgumentError,
        "`#{head}` names an element of `#{array}`, #{what}, by #{length(index)} " <>
          "subscript#{plural(length(index))}, where it takes #{length(dims)}, one a dimension"
      )

  defp indexed([], index, dims, {head, array, what}),
    do:
      index_in(
        Enum.find(Enum.zip(index, dims), fn {i, n} -> i < 0 or i >= n end),
        index,
        {head, array, what}
      )

  defp index_in(nil, index, _at), do: index

  defp index_in({i, n}, _index, {head, array, what}),
    do:
      raise(
        ArgumentError,
        "`#{head}`'s subscript `#{i}` is outside 0 to #{n - 1}: `#{array}` is #{what}"
      )

  defp plural(1), do: ""
  defp plural(_n), do: "s"

  # A var_input whose value does not fit its type, as after a recompile of the same name
  # that changed the type, starts again with the rest.
  defp inputs(%Program{tags: tags}, env),
    do:
      for(
        {name, %Tag{section: :var_input, type: type}} <- tags,
        {:ok, value} <- [Map.fetch(env, name)],
        kept_input?(type, value),
        into: %{},
        do: {name, value}
      )

  # M5-11: an array var_input is kept whole where its value is one, as a state holds it.
  defp kept_input?({:array, type, dims}, value),
    do: Logex.Array.held?(value, dims, &element_fits?(type, &1))

  defp kept_input?(type, value), do: Declarations.fits?(type, value)

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
  # rung against the bit the old one wrote: the false pulse decision 21 prevents. M3-5
  # (decision 106): so too for a rung a jump skipped, in the program or in a body that ran,
  # whose one-shots, counters and pulse timers did not run either.
  defp run(
         %Instance{env: env, ons_blocked: blocked} = state,
         %Program{rungs: rungs, tags: tags, blocks: blocks, units: units, reals: reals} =
           program,
         %Scan{now: now, first: first}
       ) do
    tree = tree(blocked)

    scan = %Scan{
      now: now,
      first: first,
      ons_blocked: tree,
      tags: tags,
      blocks: blocks,
      units: units,
      reals: reals
    }

    {unrun, env} = unrun(tree, rungs(rungs, env, scan))
    {faults, env} = faulted(env, program)

    {outputs(program, env),
     %{
       state
       | env: env,
         now: now,
         first: false,
         ons_blocked: unrun,
         switched: false,
         faults: faults
     }}
  end

  # M3-3 (decision 99): the program's record of the faults its scan met, taken out of the
  # env, so no state keeps one, oldest first: each on its own rungs stamped with its file
  # and no path, each from a block already placed (`raised/4`).
  defp faulted(env, %Program{file: file}) do
    {faults, env} = Map.pop(env, @faults, [])
    {faults |> as_list() |> Enum.reverse() |> Enum.flat_map(&placed(&1, nil, file)), env}
  end

  # A fault met on a routine's own rungs, `{symbol, line}`, is placed in the routine: at
  # `path`, nil for the program's, in its file. One placed already, a block's, is kept by the
  # program, and is a level further down from any other routine that ran that block: its
  # path gains the instance's name.
  # What a program built by hand left under the key, writing a tag it names by the atom, is
  # no fault: no env a host hands in holds the key (state!/2), and no body runs over a map
  # that does (members_of/1).
  defp placed({symbol, line}, path, file) when is_atom(symbol) and is_integer(line),
    do: [
      %Fault{
        severity: :minor,
        kind: :divide_by_zero,
        instruction: symbol,
        path: path,
        file: file,
        line: line
      }
    ]

  # M5-9 (decisions 153 and 160): a bit whose number a tag holds, read out of its word's
  # bits, a major fault, with the number read; and since M5-12 an element a tag subscript
  # names outside its array, with the subscripts read, one a dimension (decision 153).
  defp placed({kind, symbol, line, read}, path, file)
       when kind in [:bit_out_of_range, :index_out_of_range] and is_atom(symbol) and
              is_integer(line),
       do: [
         %Fault{
           severity: :major,
           kind: kind,
           instruction: symbol,
           path: path,
           file: file,
           line: line,
           read: read
         }
       ]

  # M5-10 (decision 164): a negative source of `sqrt`, a minor fault, with the value read.
  defp placed({:negative_sqrt, {symbol, line}, read}, path, file)
       when is_atom(symbol) and is_integer(line),
       do: [
         %Fault{
           severity: :minor,
           kind: :negative_sqrt,
           instruction: symbol,
           path: path,
           file: file,
           line: line,
           read: read
         }
       ]

  defp placed(%Fault{} = fault, nil, _file), do: [fault]

  defp placed(%Fault{path: path} = fault, instance, _file),
    do: [%{fault | path: instance <> "." <> path}]

  defp placed(_junk, _path, _file), do: []

  defp as_list(list) when is_list(list), do: list
  defp as_list(_not_a_list), do: []

  # The bits of the tree whose `ons` did not run, by their paths, sorted: those inside an
  # instance whose body did not run, and since M3-5 those on a rung a jump skipped. Each
  # `cal` that runs an instance's body records it in the env of the routine that runs it,
  # under `@ran`, an atom, so no tag or member name can be it, and takes its body's record
  # out of the instance's map (`called/5`); a skipped rung marks each edge memory it holds
  # there too (held/3); this takes the program's out, so no state keeps one.
  defp unrun(tree, env) do
    {ran, env} = recorded(env)
    {Enum.sort(kept(tree, ran, "", [])), env}
  end

  # The record taken out of an env, a map whatever a program built by hand left under its
  # key: no env a host hands in holds it, and no body runs over a map that does.
  defp recorded(env) do
    {ran, env} = Map.pop(env, @ran, %{})
    {as_map(ran), env}
  end

  defp kept(tree, ran, prefix, acc),
    do:
      Enum.reduce(tree, acc, fn
        {bit, true}, acc -> leaf(Map.get(ran, bit), prefix <> bit, acc)
        {instance, inner}, acc -> within(Map.fetch(ran, instance), inner, prefix <> instance, acc)
      end)

  # A bit of a routine that ran, or an edge memory of a counter or pulse timer in one, is used
  # up, unless a jump skipped its rung (M3-5, decision 106).
  defp leaf(@skipped, path, acc), do: [path | acc]
  defp leaf(_ran, _path, acc), do: acc

  defp within({:ok, ran}, inner, path, acc), do: kept(inner, as_map(ran), path <> ".", acc)
  defp within(:error, inner, path, acc), do: paths(inner, path, acc)

  defp paths(true, path, acc), do: [path | acc]

  defp paths(inner, path, acc),
    do: Enum.reduce(inner, acc, fn {name, at}, acc -> paths(at, path <> "." <> name, acc) end)

  # A var_output a hand-built env leaves out reads 0, as a contact reads it (M1-4). Since
  # M5-11 an array var_output is given as a host is given an array, a list, a list of lists
  # for more dimensions, where the program holds one (`arrays`), and every output as it
  # was before arrays where it holds none.
  defp outputs(%Program{tags: tags, arrays: nil}, env),
    do:
      for(
        {name, %Tag{section: :var_output}} <- tags,
        into: %{},
        do: {name, Map.get(env, name, 0)}
      )

  defp outputs(%Program{tags: tags, arrays: arrays}, env),
    do:
      for(
        {name, %Tag{section: :var_output}} <- tags,
        into: %{},
        do: {name, given(Map.get(arrays, name), Map.get(env, name, 0))}
      )

  defp given({:array, _type, dims}, value), do: Logex.Array.to_list(value, dims)
  defp given(nil, value), do: value

  # The block list as a tree, each name split at its `.`s once: linear in the list. Since
  # M5-8 a bit of a tag, `status.3`, is one leaf, its last two parts, as the block list and
  # the scan name it (decision 155).
  defp tree(bits), do: Enum.reduce(bits, %{}, &plant(leafed(String.split(&1, ".")), &2))

  defp leafed(parts), do: leaf_of(Enum.reverse(parts))

  defp leaf_of([last, word | rest] = reversed),
    do: numbered(Integer.parse(last), {last, word, rest}, reversed)

  defp leaf_of(reversed), do: Enum.reverse(reversed)

  defp numbered({_n, ""}, {last, word, rest}, _reversed),
    do: Enum.reverse([word <> "." <> last | rest])

  defp numbered(_no_bit, _parts, reversed), do: Enum.reverse(reversed)

  defp plant([bit], tree), do: Map.put(tree, bit, true)

  defp plant([instance | path], tree),
    do: Map.put(tree, instance, plant(path, as_map(Map.get(tree, instance))))

  # The arguments, checked in order: program, state, the state's owner, scan, inputs.
  # Decision 182: a program whose arithmetic computes in a destination that has no integer
  # type, which only one edited by hand after it compiled holds, is refused a line each,
  # and since decision 197 one whose units its tags do not give
  # (`Logex.Program.edited_by_hand/1`), since decision 190 once, where the program is first
  # handed in, `instance/1` here: the other entry points take the program's shape alone,
  # so that a scan costs what it did before decision 182.
  defp checked!(program) do
    program!(program)
    computable!(Program.edited_by_hand(program))
  end

  defp program!(%Program{tags: tags, rungs: rungs}) when is_map(tags) and is_list(rungs),
    do: :ok

  # M2-5: what Logex.compile/2 gives for a function block's file, which a program runs.
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

  defp state!(%Instance{type: type}, _program) when not is_binary(type) and type != nil,
    do: raise(ArgumentError, "state.type must be a program name, got: #{inspect(type)}")

  defp state!(%Instance{env: env}, _program) when not is_map(env) or is_struct(env),
    do:
      raise(ArgumentError, "state.env must be a map of tag names to values, got: #{inspect(env)}")

  # M3-5's review: a record of a scan's own, under a key no tag can be, would change the
  # run: a `:jump` skips rungs, a `:faults` entry is a fault no divisor met, and a `:ran`
  # mark keeps a memory blocked. No scan leaves one, so a host's env holding one is a
  # mistake, checked with the env's shape, before the clock and the owner.
  defp state!(%Instance{env: env}, _program)
       when is_map_key(env, @faults) or is_map_key(env, @jump) or is_map_key(env, @ran),
       do: raise(ArgumentError, own_keys(for key <- @own_keys, is_map_key(env, key), do: key))

  defp state!(%Instance{now: now}, _program) when not is_integer(now) or now < 0,
    do: raise(ArgumentError, "state.now must be #{ms()}, got: #{inspect(now)}")

  defp state!(%Instance{first: first}, _program) when not is_boolean(first),
    do: raise(ArgumentError, "state.first must be true or false, got: #{inspect(first)}")

  defp state!(%Instance{switched: switched}, _program) when not is_boolean(switched),
    do: raise(ArgumentError, "state.switched must be true or false, got: #{inspect(switched)}")

  defp state!(%Instance{ons_blocked: blocked, faults: faults} = state, program),
    do:
      values!(owner!(faults!(faults?(faults), blocked!(bits?(blocked), state)), program), program)

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

  # M3-3 (decision 99): the faults of the last scan, a proper list of them, as a scan gives
  # it; a scan replaces it, so its values are not looked into.
  defp faults?([]), do: true
  defp faults?([%Fault{} | faults]), do: faults?(faults)
  defp faults?(_not_faults), do: false

  defp faults!(true, state), do: state

  defp faults!(false, %Instance{faults: faults}),
    do:
      raise(
        ArgumentError,
        "state.faults must be a list of %Logex.Fault{}, got: #{inspect(faults)}"
      )

  defp own_keys([key]),
    do:
      "state.env holds #{inspect(key)}, the runtime's own key for a record a scan keeps " <>
        "and takes out before it ends: an env is keyed by tag names"

  defp own_keys(keys),
    do:
      "state.env holds #{and_list(Enum.map(keys, &inspect/1))}, the runtime's own keys for " <>
        "records a scan keeps and takes out before it ends: an env is keyed by tag names"

  defp owner!(%Instance{type: name} = state, %Program{name: name}), do: state

  defp owner!(%Instance{type: type}, %Program{name: name}),
    do: raise(ArgumentError, "this state is an instance of #{named(type)}, not of #{named(name)}")

  defp named(nil), do: "an unnamed program"
  defp named(name), do: "`#{name}`"

  # Decision 171: no value outside its tag's type reaches a scan. An integer a state holds
  # for a tag, or for a member of an instance it holds, at any depth, must fit the tag's or
  # the member's type, as an input must (Logex.Declarations.fits?/2): 5000000000 in a dint
  # is the host's mistake, refused where the state is handed in, after its owner, every
  # value outside a line of one message in path order. Walked once, each tag of the
  # program's table looked up in the state, a member of an instance by its type's members,
  # a user block's type found in the program's one table of block types (decision 53), so
  # the check is linear in the state, a guard a value that fits; the lines are sorted only
  # when there are any. A value that is no integer, 37.5, nil or "x", is outside its type
  # too, since decision 173 retired M1-4's reading of one for a state handed in; so is
  # an instance's tag that holds no map, 5 or nil (decision 184), and a timer's `last` that
  # is no integer (decision 186), or later than the instance's `now` (decision 188).
  defp values!(%Instance{env: env, now: now} = state, %Program{tags: tags, blocks: blocks}),
    do: fitted(misfits(env, tags, {as_map(blocks), now}, [], []), state)

  defp fitted([], state), do: state
  defp fitted(lines, _state), do: raise(ArgumentError, Enum.join(Enum.sort(lines), "\n"))

  defp misfits(env, tags, blocks, path, acc),
    do: misfits(Map.to_list(tags), env, {path, blocks}, acc)

  # A tag whose value fits its type is passed by one guard, the common case; one the env
  # leaves out, or holds as anything else, is looked at.
  defp misfits([{name, %Tag{type: type}} | rest], env, at, acc)
       when is_fitting(type, :erlang.map_get(name, env)),
       do: misfits(rest, env, at, acc)

  # M5-11 (decision 151): an array is held whole, a tuple of its dimensions' sizes, so a
  # state that lacks one is refused too: a write of an element writes into its array.
  defp misfits([{name, %Tag{type: {:array, _, _} = type}} | rest], env, {path, blocks} = at, acc),
    do: misfits(rest, env, at, held(Map.fetch(env, name), type, [name | path], blocks, acc))

  defp misfits([{name, %Tag{type: type}} | rest], env, {path, blocks} = at, acc),
    do: misfits(rest, env, at, present(Map.fetch(env, name), type, [name | path], blocks, acc))

  defp misfits([_not_a_tag | rest], env, at, acc), do: misfits(rest, env, at, acc)
  defp misfits([], _env, _at, acc), do: acc

  defp present({:ok, value}, type, path, blocks, acc), do: of_type(type, value, path, blocks, acc)
  defp present(:error, _type, _path, _blocks, acc), do: acc

  defp held({:ok, value}, type, path, blocks, acc), do: of_type(type, value, path, blocks, acc)

  defp held(:error, type, path, _blocks, acc),
    do: [
      "state.env lacks `#{Enum.join(Enum.reverse(path), ".")}`: it is " <>
        "#{Declarations.a_type(type)}, which a state holds whole, as " <>
        "`Logex.Runtime.instance/1` makes it"
      | acc
    ]

  defp of_type(type, value, _path, _blocks, acc) when is_fitting(type, value), do: acc

  # M5-10 (decision 150): a real holds a float that is one of its values, a single's for a
  # `real`, never −0.0 and no subnormal, and never an integer: a real's zero is 0.0.
  defp of_type(type, value, path, _blocks, acc) when type in @reals,
    do: real_held(Logex.Real.value?(type, value), type, value, path, acc)

  defp of_type(type, value, path, _blocks, acc) when is_elementary(type),
    do: [outside(type, value, path) | acc]

  # M5-11: an array's value is a tuple of its first dimension's size, of tuples of the next
  # for more dimensions, each element of its elements' type, told by the element's name,
  # `temps[3]`; a guard an element where every one fits.
  defp of_type({:array, type, dims} = array, value, path, blocks, acc),
    do:
      fitted_array(
        all_fit?(value, dims, type),
        array,
        value,
        {path, blocks},
        acc
      )

  defp of_type(%FbType{body: nil, members: members}, %{} = map, path, blocks, acc),
    do:
      Enum.reduce(members, acc, fn %Member{name: name, type: type}, acc ->
        present(Map.fetch(map, name), type, [name | path], blocks, acc)
      end)

  defp of_type(%FbType{body: %Program{tags: tags}}, %{} = map, path, blocks, acc),
    do: misfits(map, tags, blocks, path, acc)

  defp of_type({:block, name}, %{} = map, path, {blocks, _now} = known, acc),
    do: held_block(Map.fetch(blocks, name), map, path, known, acc)

  # Decision 184: an instance's tag holds a map of its members, so one that holds anything
  # else, 5 or nil, is outside its type, told the instance's type in a message's words.
  defp of_type(%FbType{} = type, value, path, _blocks, acc),
    do: [outside_instance(type, value, path) | acc]

  defp of_type({:block, name}, value, path, {blocks, _now}, acc),
    do: not_a_map(Map.fetch(blocks, name), value, path, acc)

  # Decision 186: a built-in timer's `last`, a time on the scan's clock, unbounded below, is
  # an integer, as every other member's value is; and since decision 188 none later than
  # the instance's `now`, a time the timer cannot have run at yet.
  defp of_type(:clock, value, _path, {_blocks, now}, acc)
       when is_integer(value) and value <= now,
       do: acc

  defp of_type(:clock, value, path, {_blocks, now}, acc) when is_integer(value),
    do: [described(Declarations.a_type(:clock), later(value, now), path) | acc]

  defp of_type(:clock, value, path, _blocks, acc),
    do: [described(Declarations.a_type(:clock), unfitting(:clock, :clock, value), path) | acc]

  defp later(value, now), do: "#{value} is later than the instance's now, #{now}"

  # Its shape is looked at only where an element does not fit, so a state whose every
  # element fits is walked once (M5-11's review).
  defp fitted_array(true, _array, _value, _at, acc), do: acc

  defp fitted_array(false, {:array, _, dims} = array, value, {path, blocks}, acc),
    do:
      shaped(
        false,
        Logex.Array.held?(value, dims, fn _element -> true end),
        {array, value, path, blocks},
        acc
      )

  # Every element of an integer, bit-string or bool array is judged by one guard, with no
  # function called, and a real's by its rule (M5-11's review): a state's array is walked
  # once each time it is handed in, so this is the cost of holding one.
  defp all_fit?(value, [count], type)
       when type not in @reals and is_tuple(value) and tuple_size(value) == count,
       do: guarded(value, count, type)

  defp all_fit?(value, [count | [_ | _] = dims], type)
       when is_tuple(value) and tuple_size(value) == count,
       do: rows_fit?(value, count, {dims, type})

  defp all_fit?(value, dims, type), do: Logex.Array.held?(value, dims, &element_fits?(type, &1))

  defp guarded(_value, 0, _type), do: true

  defp guarded(value, i, type) when is_fitting(type, :erlang.element(i, value)),
    do: guarded(value, i - 1, type)

  defp guarded(_value, _i, _type), do: false

  defp rows_fit?(_value, 0, _row), do: true

  defp rows_fit?(value, i, {dims, type} = row),
    do: all_fit?(:erlang.element(i, value), dims, type) and rows_fit?(value, i - 1, row)

  defp element_fits?(type, value) when is_fitting(type, value), do: true
  defp element_fits?(type, value) when type in @reals, do: Logex.Real.value?(type, value)
  defp element_fits?(_type, _value), do: false

  defp shaped(false, true, {{:array, type, dims} = array, value, [name | path], blocks}, acc) do
    Enum.zip(Logex.Array.indexes(dims), Logex.Array.to_flat(value, dims))
    |> Enum.reduce([], fn {index, element}, lines ->
      of_type(type, element, [Logex.Array.name(name, index) | path], blocks, lines)
    end)
    |> Enum.reverse()
    |> Logex.Array.capped(&more_outside(array, [name | path], &1))
    |> Enum.reverse(acc)
  end

  defp shaped(false, false, {{:array, _, dims} = array, value, path, _blocks}, acc),
    do: [
      described(
        Declarations.a_type(array),
        "its value must be #{tuple_shape(dims)}, found #{shown_value(value)}",
        path
      )
      | acc
    ]

  defp more_outside(array, path, count),
    do:
      "state.env holds `#{Enum.join(Enum.reverse(path), ".")}`, #{Declarations.a_type(array)}, " <>
        "with #{count} more #{elements(count)} outside its type, not listed"

  # A host's value as a message shows it, a list of integers as a list, never as the
  # charlist it may also be read as, `[72, 105]` and not `~c"Hi"`.
  defp shown_value(value), do: inspect(value, charlists: :as_lists)

  defp tuple_shape(dims), do: "a tuple of " <> shape_of(dims, "tuple")

  defp shape_of([count], _kind), do: "#{count} #{elements(count)}"
  defp shape_of([count | dims], kind), do: "#{count} #{kind}s of " <> shape_of(dims, kind)

  defp elements(1), do: "element"
  defp elements(_count), do: "elements"

  defp real_held(true, _type, _value, _path, acc), do: acc
  defp real_held(false, type, value, path, acc), do: [outside(type, value, path) | acc]

  defp held_block({:ok, %FbType{} = type}, map, path, blocks, acc),
    do: of_type(type, map, path, blocks, acc)

  defp held_block(_not_held, _map, _path, _blocks, acc), do: acc

  # A name the program's one table lacks, or holds as no type, which only a program built
  # by hand gives, is no type the check can read, and nothing runs for it (`called/5`).
  defp not_a_map({:ok, %FbType{} = type}, value, path, acc),
    do: [outside_instance(type, value, path) | acc]

  defp not_a_map(_not_held, _value, _path, acc), do: acc

  defp outside(type, value, path),
    do:
      described(
        Declarations.a_type(type),
        unfitting(Declarations.kind(type), type, value),
        path
      )

  defp outside_instance(type, value, path),
    do:
      described(
        Declarations.instance_of(type),
        "its value must be a map of its members, found #{shown_value(value)}",
        path
      )

  defp described(a_type, told, path),
    do:
      "state.env holds `#{Enum.join(Enum.reverse(path), ".")}` outside its type: it is " <>
        "#{a_type}, and " <> told

  # What a held value outside its type is told (decisions 171 and 173): an integer its
  # type's misfit, a bool's 2 among them; a value that is no integer, 37.5, nil or "x", in
  # a bool the same words, shown as the host gave it, and in an integer type the words an
  # input that is no integer is told.
  # M5-10: a real's value is a float, and one of its own: a float past a `real`'s range is
  # told its range, and any other float that is no value of the type the nearest that is.
  defp unfitting(:real, type, value) when is_float(value),
    do: unreal(Logex.Real.in_range?(type, value), type, value)

  defp unfitting(:real, _type, value),
    do: "its value must be a float, found #{shown_value(value)}"

  defp unfitting(_kind, type, value) when is_integer(value),
    do: Declarations.misfit(type, "#{value}")

  defp unfitting(:boolean, type, value), do: Declarations.misfit(type, inspect(value))

  defp unfitting(_integer, _type, value),
    do: "its value must be an integer, found #{shown_value(value)}"

  defp unreal(true, type, value),
    do:
      "#{inspect(value)} is no value of #{Declarations.a_type(type)}, whose nearest is " <>
        inspect(Logex.Real.nearest(type, value))

  defp unreal(false, type, value), do: Declarations.misfit(type, inspect(value))

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

  defp scan!(%Scan{units: units}, _state) when units != nil,
    do:
      raise(
        ArgumentError,
        "scan.units is the runtime's, taken from the program: a host leaves it out, " <>
          "got: #{inspect(units)}"
      )

  defp scan!(%Scan{reals: reals}, _state) when reals != nil,
    do:
      raise(
        ArgumentError,
        "scan.reals is the runtime's, taken from the program: a host leaves it out, " <>
          "got: #{inspect(reals)}"
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

    merged(problems, state, {env, program}, inputs)
  end

  defp merge!(_state, _program, inputs),
    do:
      raise(
        ArgumentError,
        ~s|inputs must be a map of var_input names to values, as in %{"start" => 1}, | <>
          "got: #{inspect(inputs)}"
      )

  # Decision 222 (provisional): one call sets an array whole or by its elements, never both,
  # and each element once, `"steps[3]"` and `"steps[03]"` naming one; a line an array, in
  # name order. A program of no array has none.
  defp clashes(%Program{tags: tags} = program, inputs) do
    inputs
    |> Map.keys()
    |> Enum.flat_map(&element_index(&1, program))
    |> Enum.group_by(&elem(&1, 0), &Tuple.delete_at(&1, 0))
    |> Enum.sort()
    |> Enum.flat_map(&clash(&1, Map.get(tags, elem(&1, 0)), inputs))
  end

  defp clash({array, keyed}, tag, inputs),
    do: clash(is_map_key(inputs, array), {array, keyed}, tag)

  defp clash(true, {array, keyed}, tag),
    do: [
      "inputs #{keyed_list([array | Enum.sort(for {_index, key} <- keyed, do: key)])} each set " <>
        "`#{array}`, #{Declarations.a_type(tag.type)}#{on_line(tag)}: a call sets an array " <>
        "whole or by its elements, not both"
    ]

  defp clash(false, {array, keyed}, tag),
    do:
      for(
        {index, [_, _ | _] = keys} <- Enum.sort(Enum.group_by(keyed, &elem(&1, 0), &elem(&1, 1))),
        do:
          "inputs #{keyed_list(Enum.sort(keys))} each set `#{Logex.Array.name(array, index)}`, " <>
            "an element of `#{array}`, #{Declarations.a_type(tag.type)}#{on_line(tag)}: a call " <>
            "sets each element once"
      )

  defp keyed_list(keys), do: Enum.map_join(keys, " and ", &"`#{&1}`")

  # An element key's array and index, its subscripts' values, where it names an element of
  # an array var_input within its dimensions, and nothing for any other key.
  defp element_index(key, %Program{tags: tags})
       when is_binary(key) and not is_map_key(tags, key) and byte_size(key) > 0 and
              binary_part(key, byte_size(key) - 1, 1) == "]",
       do: indexed(Logex.Array.split(key), key, tags)

  defp element_index(_key, _program), do: []

  defp indexed({array, subscripts}, key, tags),
    do: of_input(Map.fetch(tags, array), Logex.Lexer.tokenize(key), {array, subscripts, key})

  defp indexed(nil, _key, _tags), do: []

  defp of_input(
         {:ok, %Tag{section: :var_input, type: {:array, _, dims}}},
         {:ok, [{:name, _, key}], _line},
         {array, subscripts, key}
       ),
       do: in_dims(Enum.map(subscripts, &Logex.Array.subscript/1), dims, {array, key})

  defp of_input(_not_an_input, _tokens, _key), do: []

  defp in_dims(subscripts, dims, {array, key}) when length(subscripts) == length(dims),
    do: indexed_within(Enum.zip(subscripts, dims), [], {array, key})

  defp in_dims(_subscripts, _dims, _key), do: []

  defp indexed_within([], index, {array, key}), do: [{array, Enum.reverse(index), key}]

  defp indexed_within([{{:literal, n}, dim} | rest], index, key) when n >= 0 and n < dim,
    do: indexed_within(rest, [n | index], key)

  defp indexed_within(_outside, _index, _key), do: []

  defp merged([], state, {env, %Program{reals: nil, arrays: nil}}, inputs),
    do: %{state | env: Map.merge(env, inputs)}

  # M5-11 (decision 151): an array var_input's value is a host's list, held as the tuple a
  # state holds, each element of a real its nearest value; and since decision 222 an
  # element's key sets that element in its array, the rest kept, once the keys are seen to
  # set no array twice (clashes/2).
  defp merged([], state, {env, %Program{arrays: arrays, tags: tags} = program}, inputs)
       when arrays != nil,
       do:
         by_element(
           untagged(:maps.keys(inputs), tags),
           state,
           {env, program},
           inputs
         )

  # M5-10 (decision 166): an input into a real is the real's nearest value, an integer's
  # precision lost silently, 16,777,217 into a `real` stored as 16777216.0.
  defp merged([], state, {env, %Program{reals: reals}}, inputs),
    do: %{state | env: Map.merge(env, Map.new(inputs, &as_input(&1, reals)))}

  defp merged(problems, _state, _env, _inputs),
    do: raise(ArgumentError, Enum.join(once(problems), "\n"))

  # The keys that name no tag, an element's among them, in one recursion, a reduction a key.
  defp untagged([], _tags), do: []
  defp untagged([key | keys], tags) when is_map_key(tags, key), do: untagged(keys, tags)
  defp untagged([key | keys], tags), do: [key | untagged(keys, tags)]

  # No key names an element: the inputs are merged as M5-11 merged them.
  defp by_element([], state, {env, %Program{reals: reals, arrays: arrays}}, inputs),
    do: %{state | env: Map.merge(env, Map.new(inputs, &as_array_input(&1, reals, arrays)))}

  defp by_element(elements, state, {env, program}, inputs),
    do: elements_merged(clashes(program, inputs), {state, elements}, {env, program}, inputs)

  defp elements_merged([], {state, elements}, {env, %Program{} = program}, inputs) do
    wholes = Map.drop(inputs, elements)
    env = Map.merge(env, Map.new(wholes, &as_array_input(&1, program.reals, program.arrays)))

    %{
      state
      | env: Enum.reduce(Map.take(inputs, elements), env, &as_element_input(&1, &2, program))
    }
  end

  defp elements_merged(clashes, _state, _env, _inputs),
    do: raise(ArgumentError, Enum.join(clashes, "\n"))

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

  # Decision 222: a key naming an element of an array var_input, `"steps[3]"`, sets that
  # element, its value fitting the elements' type, the rest of the array kept.
  defp declared(:error, key, value, %Program{tags: tags} = program)
       when binary_part(key, byte_size(key) - 1, 1) == "]",
       do: element_key(Logex.Array.split(key), {key, value}, tags, program)

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

  defp element_key({array, subscripts}, {key, value}, tags, program),
    do: element_input(Map.fetch(tags, array), {key, subscripts, value}, tags, program)

  defp element_key(nil, {key, value}, tags, program),
    do: element_input(:error, {key, [], value}, tags, program)

  # A key is an element's name only where the lexer reads it as one name, its subscripts
  # numbers a literal may spell, `"steps[16#3]"` the element `steps[3]` (provisional), one a
  # dimension and each within it, as a rung's element is judged when the program compiles.
  defp element_input(
         {:ok, %Tag{section: :var_input, type: {:array, _, _}} = tag},
         {key, subscripts, value},
         tags,
         program
       ),
       do: one_name(Logex.Lexer.tokenize(key), {tag, key, subscripts, value}, {tags, program})

  defp element_input({:ok, %Tag{type: {:array, _, _}} = tag}, {key, _, _}, _tags, _program),
    do:
      "input #{inspect(key)} names an element of `#{tag.name}`, a #{tag.section}#{on_line(tag)}, " <>
        "not a var_input: only a var_input is set from outside"

  defp element_input(_not_an_array, {key, _, _}, tags, _program) do
    inputs = for {name, %Tag{section: :var_input}} <- tags, do: name
    hint("input #{inspect(key)} is not declared", "", inputs)
  end

  defp one_name({:ok, [{:name, _, key}], _line}, {tag, key, subscripts, value}, _world),
    do: subscripted_input(Enum.map(subscripts, &Logex.Array.subscript/1), {tag, key, value})

  defp one_name(_not_one_name, {_tag, key, _subscripts, _value}, {tags, program}),
    do: element_input(:error, {key, [], nil}, tags, program)

  defp subscripted_input(subscripts, {%Tag{type: {:array, type, dims}} = tag, key, value}) do
    count = length(subscripts)

    counted_input(
      Enum.find(subscripts, &match?({:tag, _}, &1)),
      count == length(dims),
      {tag, key, value},
      {subscripts, type, dims}
    )
  end

  defp counted_input({:tag, name}, _counted, {tag, key, _value}, {_subscripts, _type, dims}),
    do:
      "input `#{key}`'s subscript `#{name}` is a tag's name: a host names an element by " <>
        "numbers, as in `#{tag.name}[#{zeros(dims)}]`"

  defp counted_input(nil, false, {tag, key, _value}, {subscripts, _type, dims}),
    do:
      "input `#{key}` names an element of `#{tag.name}`, " <>
        "#{Declarations.a_type(tag.type)}#{on_line(tag)}, by #{length(subscripts)} " <>
        "#{subscripts_word(length(subscripts))}, where it takes #{length(dims)}, one a " <>
        "dimension, as in `#{tag.name}[#{zeros(dims)}]`"

  defp counted_input(nil, true, {tag, key, value}, {subscripts, type, dims}) do
    outside =
      subscripts
      |> Enum.zip(dims)
      |> Enum.with_index(1)
      |> Enum.find(fn {{{:literal, n}, dim}, _at} -> n < 0 or n >= dim end)

    within(outside, {tag, key, value}, {type, dims})
  end

  defp within(nil, {tag, key, value}, {type, _dims}),
    do: fit(%{tag | name: key, type: type}, value)

  defp within({{{:literal, n}, dim}, at}, {tag, key, _value}, {_type, dims}),
    do:
      "input `#{key}`'s subscript #{n} is outside #{dimension_word(length(dims), at)} " <>
        "of `#{tag.name}`, 0 to #{dim - 1}: `#{tag.name}` is " <>
        "#{Declarations.a_type(tag.type)}#{on_line(tag)}"

  defp zeros(dims), do: Enum.map_join(dims, ",", fn _ -> 0 end)

  defp subscripts_word(1), do: "subscript"
  defp subscripts_word(_count), do: "subscripts"

  defp dimension_word(1, _at), do: "the elements"
  defp dimension_word(_dims, 1), do: "the first dimension"
  defp dimension_word(_dims, 2), do: "the second dimension"
  defp dimension_word(_dims, 3), do: "the third dimension"

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

  # M5-11 (decision 151): an array var_input's value is a list of its first dimension's
  # size, of lists of the next for more dimensions, its every element fitting the elements'
  # type, each misfit a line by the element's name, `w[3]`.
  defp fit(%Tag{type: {:array, type, dims} = array} = tag, value) do
    listed(
      Logex.Array.listed?(value, dims, fn _element -> true end),
      {tag, array},
      {value, dims, type}
    )
  end

  # An integer type's value must be an integer, which a bool's is told by its range (M5-1:
  # the kind, from the one table of types).
  defp fit(%Tag{type: type} = tag, value), do: fit(Declarations.kind(type), tag, value)

  defp fit(kind, tag, value)
       when kind in [:signed, :unsigned, :bit_string] and not is_integer(value),
       do:
         "input `#{tag.name}` is #{Declarations.a_type(tag.type)}: its value must be an integer, " <>
           "found #{shown_value(value)}"

  # M5-10 (decision 166): a real's input is a number, an integer or a float, stored as the
  # real's nearest value, only one past its range refused.
  defp fit(:real, tag, value) when not is_number(value),
    do:
      "input `#{tag.name}` is #{Declarations.a_type(tag.type)}: its value must be a number, " <>
        "found #{shown_value(value)}"

  defp fit(_kind, %Tag{type: type} = tag, value),
    do: fits(Declarations.fits?(type, value), tag, value)

  defp listed(true, {tag, array}, {value, dims, type}) do
    lines =
      for {index, element} <- Enum.zip(Logex.Array.indexes(dims), listed_flat(value, dims)),
          line = fit(%{tag | name: Logex.Array.name(tag.name, index), type: type}, element),
          do: line

    joined(Logex.Array.capped(lines, &more_unfit(tag, array, &1)))
  end

  defp listed(false, {tag, array}, {value, dims, _type}),
    do:
      "input `#{tag.name}` is #{Declarations.a_type(array)}: its value must be " <>
        "#{list_shape(dims)}, found #{shown_value(value)}"

  defp more_unfit(tag, array, count),
    do:
      "input `#{tag.name}` is #{Declarations.a_type(array)}, with #{count} more " <>
        "#{elements(count)} outside its type, not listed"

  defp listed_flat(value, [_count]), do: value
  defp listed_flat(value, [_count | dims]), do: Enum.flat_map(value, &listed_flat(&1, dims))

  defp joined([]), do: nil
  defp joined(lines), do: Enum.join(lines, "\n")

  defp list_shape(dims), do: "a list of " <> shape_of(dims, "list")

  defp fits(true, _tag, _value), do: nil

  defp fits(false, %Tag{type: type} = tag, value),
    do:
      "input `#{tag.name}` is #{Declarations.a_type(type)}: " <>
        Declarations.misfit(type, shown(Declarations.kind(type), value))

  # A bool's misfit is shown as the host gave it, an integer's as a number.
  defp shown(:boolean, value), do: inspect(value)
  defp shown(_kind, value), do: "#{value}"

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

  # What a cycle reads of the configuration, derived once: the timed tasks in declaration
  # order, each with its instances in theirs; the untimed instances, those with no task and,
  # since M4-2, those of the continuous task, in theirs, under the continuous task's name,
  # or `:none` where the configuration declares none (decision 111); each instance's type and
  # its connections in and out; the input points' types and the output points' names; the
  # globals by name; and each instance's var_externals, by name (M2-4).
  defp wiring(%Configuration{} = config) do
    {continuous, timed} = Enum.split_with(config.tasks, & &1.continuous)
    untimed = untimed(continuous)
    by_task = Enum.group_by(config.instances, &timed_task(&1.task, untimed), & &1.name)
    types = Map.new(config.instances, &{&1.name, &1.type})

    sections =
      Enum.group_by(
        config.connections,
        &section(config, types, &1),
        &{&1.instance, {&1.member, far_end(&1.to)}}
      )

    points = Enum.map(config.globals, &{&1, Configuration.location(&1.at)})
    by_name = Map.new(config.globals, &{&1.name, &1})

    %{
      tasks:
        timed
        |> Enum.with_index()
        |> Enum.map(fn {task, index} ->
          {task.name, {task.single, task.interval}, task.priority, index,
           Map.get(by_task, task.name, [])}
        end),
      untimed: {untimed, Map.get(by_task, nil, [])},
      types: types,
      copy_in:
        grouped(
          config.instances,
          arrays_in(Map.get(sections, :var_input, []), config, types)
        ),
      copy_out:
        grouped(
          config.instances,
          Enum.map(Map.get(sections, :var_output, []), &widened_out(&1, config, {types, by_name}))
        ),
      inputs: Map.new(for {global, {:ok, {_, "i", _}}} <- points, do: {global.name, global.type}),
      reals:
        some(
          for {global, {:ok, {_, "i", _}}} <- points,
              global.type in @reals,
              do: {global.name, global.type}
        ),
      outputs: for({global, {:ok, {_, "q", _}}} <- points, do: global.name),
      globals: by_name,
      externals:
        Map.new(config.instances, &{&1.name, externals(Map.fetch!(config.programs, &1.type))})
    }
  end

  # Decision 223: a connection's far end that is an element of a global array, `speeds[1]`,
  # is `{:at, array, index}`, its subscripts' values, which check/1 took; any other is kept.
  defp far_end(to) when is_binary(to) and binary_part(to, byte_size(to) - 1, 1) == "]" do
    {array, subscripts} = Logex.Array.split(to)
    {:at, array, Enum.map(subscripts, &literal_subscript/1)}
  end

  defp far_end(to), do: to

  defp some([]), do: nil
  defp some(pairs), do: Map.new(pairs)

  # M5-10: a connection's copy-out of an integer into a real global, decision 159's widening,
  # which writes the real's nearest value, marked with the real's type; every other kept as
  # it was. M5-11: an array's whole, `{:array, member, to, dims, global}`, and an element's,
  # `{:element, array, index, to, global}`, `to` the real type it widens into or `:none`,
  # each read from the instance's state after its scan.
  defp widened_out({instance, {member, global}} = connection, config, {types, globals}) do
    program = Map.fetch!(config.programs, Map.fetch!(types, instance))
    out_of(connected_tag(program, member), connection, global_type(global, globals))
  end

  defp global_type({:at, array, _index}, globals) do
    %Configuration.Global{type: {:array, type, _dims}} = Map.fetch!(globals, array)
    type
  end

  defp global_type(global, globals), do: Map.fetch!(globals, global).type

  defp out_of(
         {:whole, %Tag{type: {:array, from, dims}}},
         {instance, {member, global}},
         {:array, to, _}
       ),
       do: {instance, {:array, member, real_widened(from, to), dims, global}}

  defp out_of({:element, array, index, from}, {instance, {_member, global}}, to),
    do: {instance, {:element, array, index, real_widened(from, to), global}}

  defp out_of({:whole, %Tag{type: from}}, connection, to),
    do: out_as(from in @integers and to in @reals, connection, to)

  defp real_widened(from, to) when from in @integers and to in @reals, do: to
  defp real_widened(_from, _to), do: :none

  # A connection's member: a tag whole, or an element of an array by its subscripts' values,
  # with the element's type.
  defp connected_tag(%Program{tags: tags}, member)
       when binary_part(member, byte_size(member) - 1, 1) == "]" do
    {array, subscripts} = Logex.Array.split(member)
    %Tag{type: {:array, type, _dims}} = Map.fetch!(tags, array)
    {:element, array, Enum.map(subscripts, &literal_subscript/1), type}
  end

  defp connected_tag(%Program{tags: tags}, member), do: {:whole, Map.fetch!(tags, member)}

  defp literal_subscript(text) do
    {:literal, n} = Logex.Array.subscript(text)
    n
  end

  # M5-11: the copy-in of an array var_input whole, from a global array, given as a host
  # gives one, `{member, {:array, dims, global}}`, and of one connected element by element,
  # every element connected, one entry for the array, `{array, {:elements, dims, ends}}`,
  # `ends` each element's global or constant in the elements' order; every other kept.
  defp arrays_in(connections, config, types) do
    {elements, plain} =
      Enum.reduce(connections, {%{}, []}, fn {instance, {member, _to}} = connection,
                                             {elements, plain} ->
        program = Map.fetch!(config.programs, Map.fetch!(types, instance))
        in_of(connected_tag(program, member), connection, {elements, plain}, program)
      end)

    Enum.reverse(plain) ++
      for {{instance, array}, ends} <- Enum.sort(elements) do
        %Tag{type: {:array, _type, dims}} =
          Map.fetch!(Map.fetch!(config.programs, Map.fetch!(types, instance)).tags, array)

        {instance,
         {array, {:elements, dims, Enum.map(Logex.Array.indexes(dims), &Map.fetch!(ends, &1))}}}
      end
  end

  defp in_of(
         {:whole, %Tag{type: {:array, _type, dims}}},
         {instance, {member, global}},
         {elements, plain},
         _program
       ),
       do: {elements, [{instance, {member, {:array, dims, global}}} | plain]}

  defp in_of(
         {:element, array, index, _type},
         {instance, {_member, to}},
         {elements, plain},
         _program
       ),
       do:
         {Map.update(elements, {instance, array}, %{index => to}, &Map.put(&1, index, to)), plain}

  defp in_of({:whole, _tag}, connection, {elements, plain}, _program),
    do: {elements, [connection | plain]}

  defp out_as(true, {instance, {member, global}}, to), do: {instance, {member, {to, global}}}
  defp out_as(false, connection, _to), do: connection

  defp externals(%Program{tags: tags}),
    do: for({name, %Tag{section: :var_external}} <- tags, do: name)

  # M4-2: the name the untimed instances run under, and an instance's timed task, nil for
  # one that runs with them: with no task, or `with` the continuous task, which means the
  # same (decision 111). The configuration declares one continuous task at most.
  defp untimed([]), do: :none
  defp untimed([%Configuration.Task{name: name}]), do: name

  defp timed_task(task, task), do: nil
  defp timed_task(task, _untimed), do: task

  defp section(config, types, connection) do
    program = Map.fetch!(config.programs, Map.fetch!(types, connection.instance))
    section_of(connected_tag(program, connection.member), program)
  end

  defp section_of({:whole, %Tag{section: section}}, _program), do: section

  defp section_of({:element, array, _index, _type}, %Program{tags: tags}),
    do: Map.fetch!(tags, array).section

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

    imaged(problems, {globals, runtime.wiring}, inputs)
  end

  defp image!(_runtime, inputs),
    do:
      raise(
        ArgumentError,
        ~s|inputs must be a map of input-point names to values, as in %{"pb_start_1" => 1}, | <>
          "got: #{inspect(inputs)}"
      )

  defp imaged([], {globals, %{reals: nil}}, inputs), do: Map.merge(globals, inputs)

  # M5-10 (decision 166): a real input point's value is the real's nearest value.
  defp imaged([], {globals, %{reals: reals}}, inputs),
    do: Map.merge(globals, Map.new(inputs, &as_input(&1, reals)))

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

    copy_in = Map.fetch!(wiring.copy_in, name)
    read!(copy_in, globals, wiring.globals)
    inputs = Map.new(copy_in, fn {member, to} -> {member, value(to, globals)} end)

    externals = Map.fetch!(wiring.externals, name)
    state = %{state | env: Map.merge(state.env, Map.take(globals, externals))}

    {outputs, %Instance{faults: faults} = state} =
      call(program, state, inputs, %Scan{now: now, first: first})

    globals = Map.merge(globals, Map.take(state.env, externals))
    state = %{state | env: Map.drop(state.env, externals), faults: []}

    env = state.env

    globals =
      Enum.reduce(Map.fetch!(wiring.copy_out, name), globals, fn
        # Decision 223: into an element of a global array, the rest of it kept.
        {member, {:at, array, index}}, globals ->
          at_element(globals, {array, index}, Map.fetch!(outputs, member))

        {member, {to, {:at, array, index}}}, globals ->
          at_element(globals, {array, index}, as_real(to, Map.fetch!(outputs, member)))

        {:element, from, i, to, {:at, array, index}}, globals ->
          value = as_real(to, Logex.Array.fetch(Map.fetch!(env, from), i))
          at_element(globals, {array, index}, value)

        {member, {to, global}}, globals ->
          Map.put(globals, global, as_real(to, Map.fetch!(outputs, member)))

        {member, global}, globals when is_binary(member) ->
          Map.put(globals, global, Map.fetch!(outputs, member))

        {:array, member, to, dims, global}, globals ->
          Map.put(globals, global, array_out(to, Map.fetch!(env, member), dims))

        {:element, array, index, to, global}, globals ->
          Map.put(globals, global, as_real(to, Logex.Array.fetch(Map.fetch!(env, array), index)))
      end)

    {%{runtime | instances: Map.put(runtime.instances, name, state), globals: globals},
     Enum.reduce(faults, [{:ran, task, name, now} | events], &[{:fault, task, name, &1} | &2])}
  end

  defp at_element(globals, {array, index}, value),
    do: %{globals | array => Logex.Array.put(Map.fetch!(globals, array), index, value)}

  # The globals an instance's connections copy in, each checked against its own type
  # before the copy-in, whose var_input it may widen into (decision 159), so that a value a
  # host left in a runtime it built is refused where its global is narrower than the
  # var_input it fills, as it is where the two are one type (decision 171, M5-3's review):
  # a line each, in name order, a global read twice told once.
  defp read!(copy_in, globals, declared),
    do: read_fitted(Enum.reduce(copy_in, [], &misread(&1, globals, declared, &2)))

  defp misread({_member, global}, globals, declared, acc) when is_binary(global),
    do: global_fit(Map.fetch!(declared, global), Map.fetch!(globals, global), acc)

  # Decision 223: an element of a global array is checked as its array.
  defp misread({_member, {:at, array, _index}}, globals, declared, acc),
    do: global_fit(Map.fetch!(declared, array), Map.fetch!(globals, array), acc)

  defp misread({_member, {:array, _dims, global}}, globals, declared, acc),
    do: global_fit(Map.fetch!(declared, global), Map.fetch!(globals, global), acc)

  defp misread({_array, {:elements, _dims, ends}}, globals, declared, acc),
    do: Enum.reduce(ends, acc, &misread({nil, &1}, globals, declared, &2))

  defp misread(_constant, _globals, _declared, acc), do: acc

  defp global_fit(%Configuration.Global{type: type}, value, acc) when is_fitting(type, value),
    do: acc

  # M5-11: an array global holds a tuple of its sizes, a tuple of tuples for more
  # dimensions, its every element one of its elements' type's values.
  defp global_fit(%Configuration.Global{type: {:array, type, dims}} = global, value, acc),
    do: array_global(Logex.Array.held?(value, dims, &element_fits?(type, &1)), global, value, acc)

  defp global_fit(%Configuration.Global{type: type} = global, value, acc) when type in @reals,
    do: real_global(Logex.Real.value?(type, value), global, value, acc)

  defp global_fit(%Configuration.Global{name: name, type: type}, value, acc),
    do: [
      "runtime.globals holds `#{name}` outside its type: it is " <>
        "#{Declarations.a_type(type)}, and " <> unfitting(Declarations.kind(type), type, value)
      | acc
    ]

  defp array_global(true, _global, _value, acc), do: acc

  defp array_global(false, %Configuration.Global{name: name, type: type}, value, acc),
    do: [
      "runtime.globals holds `#{name}` outside its type: it is #{Declarations.a_type(type)}, " <>
        "and its value must be #{tuple_shape(elem(type, 2))} of #{Declarations.word(elem(type, 1))}s, " <>
        "found #{shown_value(value)}"
      | acc
    ]

  defp real_global(true, _global, _value, acc), do: acc

  defp real_global(false, %Configuration.Global{name: name, type: type}, value, acc),
    do: [
      "runtime.globals holds `#{name}` outside its type: it is " <>
        "#{Declarations.a_type(type)}, and " <> unfitting(:real, type, value)
      | acc
    ]

  defp read_fitted([]), do: :ok

  defp read_fitted(lines),
    do: raise(ArgumentError, lines |> Enum.sort() |> Enum.dedup() |> Enum.join("\n"))

  defp value(global, globals) when is_binary(global), do: Map.fetch!(globals, global)

  defp value({:at, array, index}, globals),
    do: Logex.Array.fetch(Map.fetch!(globals, array), index)

  defp value({:array, dims, global}, globals),
    do: Logex.Array.to_list(Map.fetch!(globals, global), dims)

  defp value({:elements, dims, ends}, globals),
    do:
      Logex.Array.to_list(Logex.Array.from_flat(Enum.map(ends, &value(&1, globals)), dims), dims)

  defp value(constant, _globals), do: constant

  # M5-11: an array var_output's copy-out into a global array, each element widened into
  # the global's real where it is one.
  defp array_out(:none, value, _dims), do: value

  defp array_out(to, value, dims),
    do: Logex.Array.from_flat(Enum.map(Logex.Array.to_flat(value, dims), &as_real(to, &1)), dims)

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

  defp at_path({:ok, global}, _instance, {head, [], _path}, runtime),
    do: given(array_of(global.type), Map.fetch!(runtime.globals, head))

  defp at_path({:ok, global}, _instance, {head, _rest, path}, _runtime),
    do:
      raise(
        ArgumentError,
        "`#{path}` goes too deep: `#{head}` is #{Declarations.a_global(global.type)}, which " <>
          "has no members"
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
    tag_at(Logex.Array.split(tag), program, {head, tag, members, path}, runtime)
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

  defp tag_at(nil, program, {_head, tag, _members, _path} = at, runtime),
    do: read_tag(tag_of(program, tag), at, program, runtime)

  # M5-11 (§4.12): an element of an instance's array, `m1.temps[3]`, a var_external's read
  # in its global, and nothing below it.
  defp tag_at({array, subscripts}, program, {head, tag, [], _path}, runtime),
    do: element_tag(tag_of(program, array), {array, subscripts}, {head, tag}, {program, runtime})

  defp tag_at(_split, _program, {head, tag, _members, path}, _runtime),
    do:
      raise(
        ArgumentError,
        "`#{path}` goes too deep: `#{head}.#{tag}` is an element, which has no members"
      )

  defp element_tag(:error, {array, _subscripts}, {head, _tag}, {program, _runtime}),
    do: in_program(:error, {head, array, [], nil}, program, %{})

  defp element_tag({:ok, %Tag{} = found}, {array, subscripts}, {head, tag}, {_program, runtime}),
    do:
      element_at(
        found.type,
        subscripts,
        {"#{head}.#{tag}", "#{head}.#{array}", shown_type(found.type)},
        element_source(found, head, runtime)
      )

  defp element_source(%Tag{section: :var_external, name: name}, _head, runtime),
    do: Map.fetch!(runtime.globals, name)

  defp element_source(%Tag{name: name}, head, runtime),
    do: Map.fetch!(Map.fetch!(runtime.instances, head).env, name)

  defp shown_type(%FbType{} = type), do: Declarations.instance_of(type)
  defp shown_type(type), do: Declarations.a_type(type)

  defp array_of({:array, _type, _dims} = array), do: array
  defp array_of(_type), do: nil

  # M2-4: a var_external is read as its global, the one copy, directly; a path below one
  # goes too deep, as below any bool or integer.
  defp read_tag(
         {:ok, %Tag{section: :var_external, type: type}},
         {_head, tag, [], _path},
         _program,
         runtime
       ),
       do: given(array_of(type), Map.fetch!(runtime.globals, tag))

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

  defp in_program({:ok, %Tag{type: type}}, {_head, tag, [], _path}, _program, env),
    do: given(array_of(type), walk(env, [tag]))

  defp in_program({:ok, %Tag{type: type}}, {head, tag, _members, path}, _program, _env),
    do:
      raise(
        ArgumentError,
        "`#{path}` goes too deep: `#{head}.#{tag}` is #{Declarations.a_type(type)}, which has no members"
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
        "`#{path}` goes too deep: `#{at}.#{member}` is #{Declarations.a_type(found.type)}, which has no members"
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

  # The evaluator (B5): private, so no logic runs past the checks above. A routine's rungs,
  # a program's or one run of a block's body, run in order, each over the env the one before
  # it left: the one rung loop (M3-5). Each rung starts with power, and `{power_flow, env}`
  # threads through its elements in order. The scan is read-only and the same for every
  # instruction of every rung of one call (M1-6).
  defp rungs([], env, _scan), do: env

  defp rungs([{:rung, elements} | rest], env, scan) do
    {_power_flow, env} = series(elements, {true, env}, scan)
    jumped(env, rest, scan)
  end

  # M3-5 (decisions 81, 82 and 104): a rung whose `jmp` was energised has recorded its label,
  # and once the whole rung has run, as IEC's rule 3 has it, the rungs after it are skipped up
  # to the one its label heads, which runs. The compiler gives every `jmp` a label on a later
  # rung of its routine, so a skip always ends at one. A skipped rung runs nothing, so all it
  # holds is frozen, as in a block whose `cal` is false: its outputs, its counters and
  # one-shots, and its timers, which catch up when next run, since `last` is stamped only
  # where a timer runs. The record is taken out of the env at once, so no state keeps one.
  defp jumped(%{@jump => label} = env, rest, scan),
    do: skipped(rest, label, Map.delete(env, @jump), scan)

  defp jumped(env, rest, scan), do: rungs(rest, env, scan)

  defp skipped([{:rung, [{:lbl, _, [{:label, _, label}]} | _]} | _] = rest, label, env, scan),
    do: rungs(rest, env, scan)

  # Decision 106: where the block list holds a memory of this routine, a skipped rung marks
  # each it keeps, so that the scan keeps it listed until its instruction runs.
  defp skipped([rung | rest], label, env, %Scan{ons_blocked: blocked} = scan)
       when map_size(blocked) > 0,
       do: skipped(rest, label, held(rung, env), scan)

  defp skipped([_rung | rest], label, env, scan), do: skipped(rest, label, env, scan)

  # A label no rung after the jump heads, which only a program built by hand can hold: the
  # rest of the routine is skipped.
  defp skipped([], _label, env, _scan), do: env

  # M3-5 (decision 106): each edge memory a skipped rung's instructions keep, marked
  # `@skipped` in the routine's record under `@ran`, where the tree would hold it: a
  # one-shot's storage bit by its name, a counter side's memory under its instance's name.
  # A mark the tree holds no memory for is never read (kept/4). A `cal` or a `tp` on the
  # rung records no run, so all its instance holds is kept.
  defp held(rung, env), do: Enum.reduce(Walk.instructions([rung]), env, &hold/2)

  defp hold({symbol, _, [{:name, _, bit} | _]}, env) when symbol in @one_shots,
    do: mark(env, [bit])

  defp hold({symbol, _, [{:bit, _, [_], _, _, _} = bit | _]}, env) when symbol in @one_shots,
    do: mark(env, [Walk.bit_name(bit)])

  defp hold({symbol, _, [{:bit, _, {:element, _, _, _, _}, _, _, _} = bit | _]}, env)
       when symbol in @one_shots,
       do: mark(env, [Walk.bit_name(bit)])

  defp hold({symbol, _, [{:element, _, _, _, _} = bit | _]}, env) when symbol in @one_shots,
    do: mark(env, [Walk.bit_name(bit)])

  defp hold({symbol, _, [{:name, _, name} | _]}, env) when is_map_key(@memories, symbol),
    do: mark(env, [name, Map.fetch!(@memories, symbol)])

  defp hold(_instruction, env), do: env

  defp mark(env, path),
    do: Map.put(env, @ran, put_path(as_map(Map.get(env, @ran)), path, @skipped))

  defp series(elements, acc, scan), do: Enum.reduce(elements, acc, &element(&1, &2, scan))

  # Every leg runs, from the power flowing into the group, with the env threading through
  # the legs in order, so a leg sees what an earlier one wrote. The group passes power if
  # any leg does: branches do not short-circuit.
  defp element({:branches, legs}, {power, env}, scan) do
    {powers, env} =
      Enum.map_reduce(legs, env, fn leg, env -> series(leg, {power, env}, scan) end)

    {Enum.any?(powers), env}
  end

  # M5-9 (decisions 153 and 160): an instruction whose bit's number, held in a tag, is
  # outside its word's bits when it reads or writes the bit does nothing: it writes nothing
  # and passes no power, the rest of the rung running on that power, and the scan finishes.
  # The read or write that meets the number throws it (bit_mask/3), an instruction's clause
  # never seeing it, and the fault is recorded in the routine's env under `@faults`, as a
  # zero divisor is, major, and placed when the routine is done (faulted/2, raised/4). The
  # catch is the instruction's own, so a body's instruction is caught in the body, and a
  # `cal` whose operand is out of range does nothing, its body's run dropped, as Logix's
  # JSR whose parameter is out of bounds aborts (1756-PM014O p.9).
  #
  # A catch costs a reduction, so only an instruction that may throw has one: one with such
  # a bit among its first three operands, all any instruction but `cal` has, told from the
  # rest by its clause's head, and every `cal`, whose formals are any number. Any other
  # instruction runs as it did before M5-9.
  #
  # M5-12 (decision 153): so for an element a tag subscripts, `weights[slot]`, whose
  # subscript is outside its dimension where it is read or written, and a bit of one, its
  # element's subscripts checked first, an instruction with one among its first three
  # operands told by its clause's head too, so that a program with none runs as before.
  defp element({_, _, [{:bit_at, _, _, _, _, _} | _]} = instruction, acc, scan) do
    evaluate(instruction, acc, scan)
  catch
    :throw, {@out_of_range, kind, read} -> out_of_range(instruction, acc, {kind, read})
  end

  defp element({_, _, [_, {:bit_at, _, _, _, _, _} | _]} = instruction, acc, scan) do
    evaluate(instruction, acc, scan)
  catch
    :throw, {@out_of_range, kind, read} -> out_of_range(instruction, acc, {kind, read})
  end

  defp element({_, _, [_, _, {:bit_at, _, _, _, _, _} | _]} = instruction, acc, scan) do
    evaluate(instruction, acc, scan)
  catch
    :throw, {@out_of_range, kind, read} -> out_of_range(instruction, acc, {kind, read})
  end

  defp element({_, _, [{:element_at, _, _, _, _, _} | _]} = instruction, acc, scan) do
    evaluate(instruction, acc, scan)
  catch
    :throw, {@out_of_range, kind, read} -> out_of_range(instruction, acc, {kind, read})
  end

  defp element({_, _, [_, {:element_at, _, _, _, _, _} | _]} = instruction, acc, scan) do
    evaluate(instruction, acc, scan)
  catch
    :throw, {@out_of_range, kind, read} -> out_of_range(instruction, acc, {kind, read})
  end

  defp element({_, _, [_, _, {:element_at, _, _, _, _, _} | _]} = instruction, acc, scan) do
    evaluate(instruction, acc, scan)
  catch
    :throw, {@out_of_range, kind, read} -> out_of_range(instruction, acc, {kind, read})
  end

  defp element(
         {_, _, [{:bit, _, {:element_at, _, _, _, _, _}, _, _, _} | _]} = instruction,
         acc,
         scan
       ) do
    evaluate(instruction, acc, scan)
  catch
    :throw, {@out_of_range, kind, read} -> out_of_range(instruction, acc, {kind, read})
  end

  defp element(
         {_, _, [_, {:bit, _, {:element_at, _, _, _, _, _}, _, _, _} | _]} = instruction,
         acc,
         scan
       ) do
    evaluate(instruction, acc, scan)
  catch
    :throw, {@out_of_range, kind, read} -> out_of_range(instruction, acc, {kind, read})
  end

  defp element(
         {_, _, [_, _, {:bit, _, {:element_at, _, _, _, _, _}, _, _, _} | _]} = instruction,
         acc,
         scan
       ) do
    evaluate(instruction, acc, scan)
  catch
    :throw, {@out_of_range, kind, read} -> out_of_range(instruction, acc, {kind, read})
  end

  defp element({:cal, _, _} = instruction, acc, scan) do
    evaluate(instruction, acc, scan)
  catch
    :throw, {@out_of_range, kind, read} -> out_of_range(instruction, acc, {kind, read})
  end

  defp element(instruction, acc, scan), do: evaluate(instruction, acc, scan)

  defp out_of_range({symbol, line, _operands}, {_power, env}, {kind, read}),
    do:
      {false,
       Map.put(env, @faults, [{kind, symbol, line, read} | as_list(Map.get(env, @faults))])}

  # One instruction: `(instruction, {power_flow, env}, %Scan{})` to `{power_flow, env}`, a
  # clause for an energised rung and one for a de-energised one (CLAUDE.md). An operand is
  # `{:name, _, tag}`, `{:int_lit, _, value}` or, since M1-6, `{:member, _, path}`, and since
  # decision 202 a literal with its spelling, `{:int_lit, _, value, spelling}`; read/2 takes
  # each and write/3 every tag, so no instruction clause cares which it got.
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

  # M5-10 (decision 150): a `move` into a real writes the real's nearest value, an integer
  # widened into it and a real literal rounded to a single, which a routine's `reals` names
  # (`Logex.Program`); a routine of no real, `reals` nil, matches the first clause and moves
  # as it did before reals.
  defp evaluate({:move, _, [source, destination]}, {true, env}, %Scan{reals: nil}) do
    {true, write(env, destination, read(env, source))}
  end

  defp evaluate({:move, _, [source, destination]}, {true, env}, %Scan{reals: reals}) do
    {true, write(env, destination, as_real(real_of(destination, reals), read(env, source)))}
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

  # M3-4: the pulse coils (docs/naming.md, `osr` and `osf`; decisions 80, 100 to 102), IEC's
  # transition-sensing coils in the conventional set's form: the storage bit holds the power
  # the coil received at its last run, read as a contact reads a bit, as an `ons`'s does,
  # and the pulse bit is set for the one run on which that power rises, for `osr`, or falls,
  # for `osf`, and cleared at every other, IEC's variable "ON from one evaluation of this
  # element to the next". Never on an instance's first scan, nor where an online edit's
  # block list holds the storage bit, as for `ons` (decisions 21 and 69). Each run writes
  # the pulse bit, then the storage bit, and passes on the power it received, IEC's "always
  # copied to the right link". `osf`'s edge is seen by its de-energised run.
  defp evaluate({:osr, _, [storage, pulse]}, {true, env}, %Scan{} = scan) do
    rose = edge?(storage, scan) and not closed?(read(env, storage))
    {true, env |> write(pulse, one(rose)) |> write(storage, 1)}
  end

  defp evaluate({:osr, _, [storage, pulse]}, {false, env}, _scan) do
    {false, env |> write(pulse, 0) |> write(storage, 0)}
  end

  defp evaluate({:osf, _, [storage, pulse]}, {true, env}, _scan) do
    {true, env |> write(pulse, 0) |> write(storage, 1)}
  end

  defp evaluate({:osf, _, [storage, pulse]}, {false, env}, %Scan{} = scan) do
    fell = edge?(storage, scan) and closed?(read(env, storage))
    {false, env |> write(pulse, one(fell)) |> write(storage, 0)}
  end

  # The six comparisons (docs/naming.md, `eq` to `ge`) are input instructions, as a contact
  # is: energised, power is the comparison of the first operand with the second, `lt a b`
  # reading a < b; de-energised, no power. Neither writes anything. Since M5-4 the two may
  # be of any integer types, compared by value on Elixir's integers, so a signed -1 is less
  # than an unsigned 0 (decision 147).
  defp evaluate({op, _, [a, b]}, {true, env}, _scan) when op in @comparisons do
    {compare(op, read(env, a), read(env, b)), env}
  end

  defp evaluate({op, _, _}, {false, env}, _scan) when op in @comparisons do
    {false, env}
  end

  # M3-3: `add`, `sub` and `mul` (docs/naming.md; IEC's ADD, SUB and MUL; decisions 98 and
  # 146). Rung power is IEC's EN, and the power out its ENO. Energised, both sources are
  # read, the result computed exactly, on Elixir's integers, and wrapped into the
  # destination's type, its low bits kept, in two's complement for a signed type (M5-2,
  # superseding decision 77's saturation; since M5-4 every width, the type type_at/2 finds,
  # decision 147), then written: the power out is true, or false on the scan where the
  # result left the type, 2147483647 + 1 giving -2147483648 in a dint and 127 + 1 -128 in an
  # sint, with no fault, so no value outside its type ever reaches a state. The sources are read before the write, so the destination may be
  # one of them, `add total flow total`. De-energised, nothing is written and no
  # power passes, as `move`. No source a hand-built env holds outside its type reaches a
  # scan, nor since decision 173 one that is no integer: the state is refused where it is
  # handed in (decision 171), superseding M5-2's provisional reading, computed exactly and
  # then wrapped; nor since decision 184 an instance that is no map, nor since decision
  # 182 a program whose destination has no integer type.
  defp evaluate({op, line, [a, b, destination]}, {true, env}, scan) when op in @sums do
    {power, value} =
      wrapped(
        type_at({op, line}, destination, scan),
        sum(op, number(read(env, a)), number(read(env, b)))
      )

    {power, write(env, destination, value)}
  end

  defp evaluate({op, _, _}, {false, env}, _scan) when op in @sums do
    {false, env}
  end

  # M3-3: `div` and `mod` (docs/naming.md; IEC's DIV and MOD; decisions 78, 98 and 146).
  # Energised, `div` writes the quotient truncated toward zero, IEC's 7/3 = 2 and
  # (-7)/3 = -2, and `mod` the remainder, IEC's IN1 - (IN1/IN2)*IN2, whose sign is the
  # dividend's: Elixir's `div/2` and `rem/2`. A zero divisor writes 0 and passes no power
  # (decision 78). The one quotient outside its type, a signed type's minimum by -1,
  # -2147483648 / -1 in a dint, wraps to that minimum with no power and no fault, as
  # `add`'s sum does (decision 146); a remainder always fits. The power out is otherwise true. De-energised, nothing is
  # written and no power passes.
  defp evaluate({op, line, [a, b, destination]}, {true, env}, scan) when op in @divisions do
    divided({op, line}, number(read(env, a)), number(read(env, b)), {destination, scan}, env)
  end

  defp evaluate({op, _, _}, {false, env}, _scan) when op in @divisions do
    {false, env}
  end

  # M3-3: `neg` and `abs` (docs/naming.md; the vendors' NEG and IEC's ABS; decisions 98 and
  # 146). Energised, `neg` writes 0 - a and `abs` a's absolute value, wrapped into the
  # destination's type: its minimum alone has no positive twin, so each gives that minimum
  # itself, -2147483648 in a dint, with no power on that scan; the power out is otherwise true. De-energised, nothing is
  # written and no power passes.
  defp evaluate({op, line, [a, destination]}, {true, env}, scan) when op in @signs do
    {power, value} =
      wrapped(type_at({op, line}, destination, scan), signed(op, number(read(env, a))))

    {power, write(env, destination, value)}
  end

  defp evaluate({op, _, _}, {false, env}, _scan) when op in @signs do
    {false, env}
  end

  # M5-3: the integer conversions, `dint_to_int src dst` and the rest (docs/naming.md's
  # family stanza; IEC's typed `<FROM>_TO_<TO>`; decisions 146 and 148). Rung power is IEC's
  # EN and the power out its ENO. Energised, the source is read and written into the
  # destination, the type the mnemonic names, where it fits, with power; where it does not,
  # its low bits are kept, two's complement for a signed type, `dint_to_sint` of 129 giving
  # -127, as an arithmetic result is wrapped, and on that scan no power passes, with no
  # fault. A source reaches it as arithmetic's does, inside its type (decisions 171 and 173).
  # De-energised, nothing is written and no power passes, as `move`.
  defp evaluate({op, _, [source, destination]}, {true, env}, _scan)
       when is_map_key(@conversions, op) do
    {power, value} = wrapped(:erlang.map_get(op, @conversions), integer(read(env, source)))
    {power, write(env, destination, value)}
  end

  defp evaluate({op, _, _}, {false, env}, _scan) when is_map_key(@conversions, op) do
    {false, env}
  end

  # M5-8: the 76 bit-string conversions, `byte_to_word`, `word_to_int`, `int_to_word` and
  # the rest (docs/naming.md's two family stanzas; IEC's Tables 24 and 25; decision 148),
  # each a binary transfer, never a sign extension: energised, the source's bits in its
  # `from` type's width, its two's-complement pattern for an integer, are stored into the
  # rightmost bits of the destination, 0 filling on the left where it is wider and the
  # rightmost bits kept where it is narrower, a signed destination reading its top bit as
  # the sign: `int_to_dword` of -1 is 16#0000ffff and `word_to_int` of 16#ffff -1. A binary
  # transfer is defined for every value, so its power out is its power in (provisional).
  # De-energised, nothing is written and no power passes, as `move`.
  defp evaluate({op, _, [source, destination]}, {true, env}, _scan)
       when is_map_key(@transfers, op) do
    {from, to} = :erlang.map_get(op, @transfers)
    pattern = low(:unsigned, from, integer(read(env, source)))
    {true, write(env, destination, transfer(to, pattern))}
  end

  defp evaluate({op, _, _}, {false, env}, _scan) when is_map_key(@transfers, op) do
    {false, env}
  end

  # M5-10: the 34 real conversions (docs/naming.md's `real_to_int` family stanza; IEC's
  # typed `<FROM>_TO_<TO>`, Ed 3 Tables 22 and 23; decisions 148, 150 and 161). Energised,
  # a real into an integer type is rounded to the nearest, a tie to the even neighbour, and
  # wrapped into the type where it does not fit, its low bits kept, with no power and no
  # fault: `real_to_int` of 2.5 is 2 and of 40000.7 -25535; anything into a real is the
  # real's nearest value, an integer rounded once, a real past a `real`'s range saturated
  # with no power. De-energised, nothing is written and no power passes.
  defp evaluate({op, _, [source, destination]}, {true, env}, _scan)
       when is_map_key(@real_conversions, op) do
    {power, value} = converted(:erlang.map_get(op, @real_conversions), number(read(env, source)))
    {power, write(env, destination, value)}
  end

  defp evaluate({op, _, _}, {false, env}, _scan) when is_map_key(@real_conversions, op) do
    {false, env}
  end

  # M5-10: the 16 truncations, `real_trunc_int` and the rest (docs/naming.md's
  # `real_trunc_int` family stanza; IEC's Table 22 feature 2b; decisions 161 and 162):
  # energised, the source's fraction dropped, toward zero, `real_trunc_int` of -1.6 giving
  # -1, and wrapped where the whole part does not fit, with no power and no fault, 40000.7
  # giving -25536. De-energised, nothing is written and no power passes.
  defp evaluate({op, _, [source, destination]}, {true, env}, _scan)
       when is_map_key(@truncations, op) do
    {power, value} = wrapped(:erlang.map_get(op, @truncations), trunc(number(read(env, source))))
    {power, write(env, destination, value)}
  end

  defp evaluate({op, _, _}, {false, env}, _scan) when is_map_key(@truncations, op) do
    {false, env}
  end

  # M5-10: `sqrt` (docs/naming.md; IEC's SQRT, Ed 3 Table 28; decisions 79 and 164).
  # Energised, the source is read, a number, and its root computed in the destination's
  # type, a real's, rounded to it, with power; a negative source writes 0.0, passes no power
  # and raises the minor fault `:negative_sqrt`, recorded in the routine's env as a zero
  # divisor is, with the value read, the source checked before the BEAM's root is called,
  # which would raise. `-0.0` is no value a state holds, so a source is never one.
  # De-energised, nothing is written and no power passes.
  defp evaluate({:sqrt, line, [source, destination]}, {true, env}, scan) do
    rooted({:sqrt, line}, number(read(env, source)), {destination, scan}, env)
  end

  defp evaluate({:sqrt, _, _}, {false, env}, _scan) do
    {false, env}
  end

  # M5-8: `and`, `or` and `xor` (docs/naming.md; IEC's Table 31; decision 155), on bit
  # strings and integers alike. Energised, both sources are read, each a value of the
  # destination's type or of one Figure 11 widens into it (decision 147), and the bitwise
  # function of their two's-complement patterns is written in the destination's type,
  # `bits_at/3`'s, which keeps every bit the two sources have there; it cannot fail, so the
  # power out is the power in. De-energised, nothing is written and no power passes.
  defp evaluate({op, line, [a, b, destination]}, {true, env}, scan) when op in @bitwise do
    value = bitwise(op, integer(read(env, a)), integer(read(env, b)))
    {true, write(env, destination, transfer(bits_at({op, line}, destination, scan), value))}
  end

  defp evaluate({op, _, _}, {false, env}, _scan) when op in @bitwise do
    {false, env}
  end

  # M5-8: `not` (IEC's NOT): each bit of the source inverted, so `not` of a byte
  # 2#0000_1111 is 2#1111_0000 and of an int 0 is -1. Since decision 214 it computes in its
  # source's type, IEC's typing of NOT, whose result is its input's type, and the result is
  # then widened into the destination by Figure 11, by value: `not` of a bool 1 into a
  # `word` is 16#0000, of a byte 16#0f into a word 16#00f0, and of a usint 5 into an int
  # 250; a signed source, sign-extended, gives what the destination's width would.
  defp evaluate({:not, line, [source, destination]}, {true, env}, scan) do
    type = bits_at({:not, line}, destination, scan)
    value = Bitwise.bnot(integer(read(env, source)))
    {true, write(env, destination, widened(source_bits(source, type, scan), type, value))}
  end

  defp evaluate({:not, _, _}, {false, env}, _scan) do
    {false, env}
  end

  # M5-8: `shl`, `shr`, `rol` and `ror` (IEC's Table 30; decision 165). Energised, the
  # source's bits in its own type's width, its two's-complement pattern for an integer,
  # are shifted by the count, 0 filling the end left empty, so `shr` of an int -2 by 1
  # gives 32767, or rotated, circular within the width, the count taken modulo the width;
  # a shift of the width or more gives 0. Since decision 214 the width is the source's,
  # IEC's typing, whose OUT is IN's type, and the result is then widened into the
  # destination by value, so `rol` of a byte into a word rotates within 8 bits; a literal
  # source, judged by its slot, shifts in the destination's width. Each passes its power
  # in, but for a count that is negative when the rung runs, which writes the source
  # unshifted and passes no power, with no fault. De-energised, nothing is written and no
  # power passes.
  defp evaluate({op, line, [source, count, destination]}, {true, env}, scan)
       when op in @shifts do
    type = bits_at({op, line}, destination, scan)
    from = source_bits(source, type, scan)
    width = Declarations.width(from)
    pattern = low(:unsigned, width, integer(read(env, source)))
    {power, value} = shifted(op, pattern, integer(read(env, count)), width)
    {power, write(env, destination, widened(from, type, value))}
  end

  defp evaluate({op, _, _}, {false, env}, _scan) when op in @shifts do
    {false, env}
  end

  # The on-delay timer (docs/naming.md, `ton`; docs/organisation.md §4.6). Rung power is
  # its IN. `last` is the time this `ton` last ran, energised or not (decision 5), and
  # energised, `.acc` gains `now - last`, unless `.en` shows it was not already enabled:
  # timing starts at the scan that first sees the rung true, which adds nothing. `.acc`
  # stays in 0..max(.pre, 0), so it never leaves a dint however long the gap, and `.dn` is
  # set when it gets there. De-energised, `.acc .dn .tt .en` go to 0. `last` changes only
  # here, so a timer that does not run (a frozen function block, M2-5) catches up when it
  # next does. Since M5-6 a long timer, a `ton_ltime`, gains 1,000,000 ns of `.acc` for each
  # millisecond, by its unit, and every timer below so too (unit/3, decision 197). The
  # preset operand is not read: it is the timer's starting `.pre`, and logic
  # may have written another. Nothing may follow a `ton` on its path (Logex.Compiler), so
  # the power each clause hands on is never read; which it should be is not settled.
  defp evaluate(
         {:ton, _, [timer, _preset]},
         {true, env},
         %Scan{now: now, units: nil}
       ) do
    {true, write(env, timer, timing(as_map(read(env, timer)), now, 1))}
  end

  defp evaluate({:ton, line, [timer, _preset]}, {true, env}, scan) do
    {true,
     write(
       env,
       timer,
       timing(as_map(read(env, timer)), scan.now, unit(timer, scan, {:ton, line}))
     )}
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

  defp evaluate(
         {:tof, _, [timer, _preset]},
         {false, env},
         %Scan{now: now, units: nil}
       ) do
    {false, write(env, timer, off_delay(as_map(read(env, timer)), now, 1))}
  end

  defp evaluate({:tof, line, [timer, _preset]}, {false, env}, scan) do
    {false,
     write(
       env,
       timer,
       off_delay(as_map(read(env, timer)), scan.now, unit(timer, scan, {:tof, line}))
     )}
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
  defp evaluate(
         {:tp, _, [timer, _preset]},
         {true, env},
         %Scan{now: now, units: nil} = scan
       ) do
    {true, pulsed(env, timer, {true, now}, scan, 1)}
  end

  defp evaluate({:tp, line, [timer, _preset]}, {true, env}, scan) do
    {true, pulsed(env, timer, {true, scan.now}, scan, unit(timer, scan, {:tp, line}))}
  end

  defp evaluate(
         {:tp, _, [timer, _preset]},
         {false, env},
         %Scan{now: now, units: nil} = scan
       ) do
    {false, pulsed(env, timer, {false, now}, scan, 1)}
  end

  defp evaluate({:tp, line, [timer, _preset]}, {false, env}, scan) do
    {false, pulsed(env, timer, {false, scan.now}, scan, unit(timer, scan, {:tp, line}))}
  end

  # M3-2: the retentive timer (docs/naming.md, `rto`; the conventional RTO; decisions 76, 90
  # and 95). Rung power is its IN. Where its reset `r` is 1 when it runs, `.acc`, `.dn` and
  # `.tt` go to 0 and no time is added, whatever the rung, `.en` taking the rung's power.
  # Otherwise, energised, it runs as a `ton` does; de-energised, `.en` and `.tt` go to 0 and
  # `.acc` and `.dn` are kept, so its time adds up across the rung's drops. `last` is stamped
  # on every run, and `r` is kept as logic left it. Every start and restart puts it at 0, as
  # every tag is put (decision 76). Nothing may follow it on its path (decision 73).
  defp evaluate(
         {:rto, _, [timer, _preset]},
         {true, env},
         %Scan{now: now, units: nil}
       ) do
    {true, write(env, timer, retained(as_map(read(env, timer)), true, now, 1))}
  end

  defp evaluate({:rto, line, [timer, _preset]}, {true, env}, scan) do
    {true,
     write(
       env,
       timer,
       retained(as_map(read(env, timer)), true, scan.now, unit(timer, scan, {:rto, line}))
     )}
  end

  defp evaluate(
         {:rto, _, [timer, _preset]},
         {false, env},
         %Scan{now: now, units: nil}
       ) do
    {false, write(env, timer, retained(as_map(read(env, timer)), false, now, 1))}
  end

  defp evaluate({:rto, line, [timer, _preset]}, {false, env}, scan) do
    {false,
     write(
       env,
       timer,
       retained(as_map(read(env, timer)), false, scan.now, unit(timer, scan, {:rto, line}))
     )}
  end

  # M3-1: IEC's counters (docs/naming.md, `ctu`, `ctd` and `ctud`; decisions 67 to 71 and
  # 84 to 86). Rung power is the count input of the side the mnemonic names, `cu` for a
  # `ctu` and `cd` for a `ctd`, and each run is IEC's body for that side, over the
  # instance's type, which the routine's tag table names: on a `ctu` or a `ctud`, `r` puts
  # `cv` to 0; else on a `ctd` or a `ctud`, `ld` puts it to `pv`; either clears the flags;
  # otherwise a rising edge of the side's input, its edge memory 0 from its last run,
  # counts, never on the instance's first scan nor where the edit's block list holds the
  # memory (decision 87), stopping at its type's limits, a dint's or since M5-5 a typed
  # counter's, `ctu_int`'s 32767 (decision 158), with `ov` or `un` set, which stays
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

  # M3-5: the forward jump (docs/naming.md, `jmp`; IEC's jump, Ed 2 §4.1.4 Table 58;
  # decisions 81, 82 and 104). Energised, it records its label for the rung loop, which skips
  # the rungs after this one up to the one the label heads once this rung is done, IEC's rule
  # 3 (Ed 2 §4.1.3), and it passes on the power it receives, so anything may follow it.
  # De-energised, nothing, and no power passes. The compiler gives a rung one `jmp`, and every
  # `jmp` a label on a later rung of its routine (rungs/3).
  defp evaluate({:jmp, _, [{:label, _, label}]}, {true, env}, _scan) do
    {true, Map.put(env, @jump, label)}
  end

  defp evaluate({:jmp, _, _}, {false, env}, _scan) do
    {false, env}
  end

  # M3-5: the label (docs/naming.md, `lbl`; IEC's network label, Ed 2 §4.1.2), first on the
  # rung it names, where a skip ends (rungs/3): it passes on what it receives, always its
  # rung's power, and does nothing else.
  defp evaluate({:lbl, _, _}, {true, env}, _scan) do
    {true, env}
  end

  defp evaluate({:lbl, _, _}, {false, env}, _scan) do
    {false, env}
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
  # runs (decision 8), and an `ons`, `osr` or `osf` inside keeps its storage bit, at its
  # declared value until the body first runs, so a block that first runs after the
  # program's first scan can fire one on its first run: an `ons` or an `osr` whose rung is
  # true there, and an `osf` whose storage bit is declared 1 on a false rung, a fall that
  # never happened (decision 102).
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
  # running, always a `{:name, _, bit}`: the compiler refuses an `ons`, an `osr` or an `osf`
  # on a member, a counter's `r` or `ld`, the only bool members logic may write (M3-1,
  # M3-4). One on a member, which only a program built by hand can hold, is never blocked.
  # A counter's edge memory is blocked by its own instruction (counted/4). A bit inside an
  # instance is in the tree under the instance's name, which a `cal` hands its body (M2-5);
  # a storage bit is never named as an instance of its routine is.
  defp blocked?({:name, _, bit}, blocked), do: is_map_key(blocked, bit)
  defp blocked?({:member, _, _path}, _blocked), do: false

  # M5-8: a bit of a tag, `status.3`, is a leaf of the tree under its path, as a bool is
  # under its name; with no block its name is never made.
  defp blocked?({:bit, _, [_], _, _, _}, blocked) when map_size(blocked) == 0, do: false

  defp blocked?({:bit, _, [_], _, _, _} = bit, blocked),
    do: is_map_key(blocked, Walk.bit_name(bit))

  # Decision 221: so is a bit of an element, `faults[2].3`, by its name.
  defp blocked?({:bit, _, {:element, _, _, _, _}, _, _, _}, blocked) when map_size(blocked) == 0,
    do: false

  defp blocked?({:bit, _, {:element, _, _, _, _}, _, _, _} = bit, blocked),
    do: is_map_key(blocked, Walk.bit_name(bit))

  defp blocked?({:bit, _, _member, _, _, _}, _blocked), do: false

  # M5-11 (decision 154): an element kept as a storage bit, `edge[2]`, a leaf of the tree by
  # its name, its subscripts by value; with no block its name is never made.
  defp blocked?({:element, _, _, _, _}, blocked) when map_size(blocked) == 0, do: false

  defp blocked?({:element, _, _, _, _} = bit, blocked),
    do: is_map_key(blocked, Walk.bit_name(bit))

  # M3-4: whether a pulse coil may see an edge on this scan: not on a first scan, nor where
  # its storage bit is blocked, as an `ons` passes no power then.
  defp edge?(storage, %Scan{first: first, ons_blocked: blocked}),
    do: not first and not blocked?(storage, blocked)

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
         %Tag{
           type:
             %FbType{
               body: %Program{rungs: rungs, tags: own, file: file, units: units, reals: own_reals}
             } = type
         },
         instance,
         operands,
         env,
         %Scan{ons_blocked: blocked} = scan
       ) do
    [_instance | formals] = FbType.signature(type)
    slots = Enum.zip(formals, operands)
    state = Enum.reduce(slots, members_of(Map.get(env, instance)), &copy_in(&1, &2, env))
    inner = as_map(Map.get(blocked, instance))
    body = %{scan | tags: own, ons_blocked: inner, units: units, reals: own_reals}
    {state, env} = ran(instance, rungs(rungs, state, body), env)
    {state, env} = raised(Map.pop(state, @faults, []), instance, file, env)
    Enum.reduce(slots, Map.put(env, instance, state), &copy_out(&1, &2, state, scan.reals))
  end

  defp called(_not_a_block, _instance, _operands, env, _scan), do: env

  # The map a body runs over: its instance's members. One a hand-built env left holding a
  # record of the runtime's own, which no member can be, has it dropped, so the body runs
  # as its text says, as a counter's map is read with a member it leaves out, every member
  # it holds inside its type (decisions 171 and 173), and a block's instance is a value
  # (M3-5's review).
  defp members_of(instance), do: Map.drop(as_map(instance), @own_keys)

  # M2-5: an instance records that its body ran, with what its own body's `cal`s recorded,
  # so that the scan keeps the blocked bits of those that did not.
  defp ran(instance, state, env) do
    {nested, state} = recorded(state)
    {state, Map.put(env, @ran, Map.put(as_map(Map.get(env, @ran)), instance, nested))}
  end

  # M3-3 (decision 99): the faults a body's scan met, taken out of its instance's map, so
  # no state keeps one, and onto the routine's that ran it, newest first, each placed a
  # level down, at the instance, in the body's file. A body that met none adds nothing.
  defp raised({[], state}, _instance, _file, env), do: {state, env}

  defp raised({faults, state}, instance, file, env) do
    placed = Enum.flat_map(as_list(faults), &placed(&1, instance, file))
    {state, Map.put(env, @faults, placed ++ as_list(Map.get(env, @faults)))}
  end

  # M2-5: a `cal`'s copy-in and copy-out, by the formal each operand fills.
  # M5-10 (decisions 150 and 159): a formal that is a real takes its operand's nearest value,
  # an integer widened into it, and an operand that is a real takes its formal's, by the
  # routine's `reals`, nil for a routine of none, which copies as it did before reals.
  defp copy_in({{{:value, type}, %Member{name: name}}, operand}, state, env)
       when type in @reals,
       do: Map.put(state, name, as_real(type, read(env, operand)))

  defp copy_in({{{:value, _}, %Member{name: name}}, operand}, state, env),
    do: Map.put(state, name, read(env, operand))

  defp copy_in(_output, state, _env), do: state

  defp copy_out({{{:write, _}, %Member{name: name}}, operand}, env, state, nil),
    do: write(env, operand, Map.get(state, name, 0))

  defp copy_out({{{:write, _}, %Member{name: name}}, operand}, env, state, reals),
    do: write(env, operand, as_real(real_of(operand, reals), Map.get(state, name, 0)))

  defp copy_out(_input, env, _state, _reals), do: env

  # M3-1: one run of a counter's side. Its kind is its tag's type in the routine's table;
  # an instance a program built by hand holds no tag for counts as the mnemonic's own. The
  # compiler names a counter only whole, `{:name, _, counter}`. Its
  # edge memory is blocked where the edit's block list names it, `boxes.cu` under the
  # counter's name in the tree, and the run is recorded as a `cal`'s is, so that the scan
  # keeps no block of a memory whose instruction ran (decision 87).
  defp counted(env, {:name, _, name} = counter, {side, power}, %Scan{} = scan) do
    kind = counter_of(Map.get(scan.tags, name), side)
    memory = memory(side)
    tree = as_map(Map.get(scan.ons_blocked, name))
    blocked = scan.first or Map.get(tree, memory) == true
    state = as_map(read(env, counter))
    edge = power and not blocked and not closed?(Map.get(state, memory))
    env = write(env, counter, count(kind, side, state, {power, edge}))
    unblocked(map_size(tree) > 0, env, name)
  end

  # M5-5: a counter's kind, a typed counter's its kind's, a `ctu_int` a `ctu`'s, and the
  # limits it stops at, its count's type's, decision 71 by width (decision 158), from its
  # type's rules; a counter of no such tag is the mnemonic's own, a dint's.
  defp counter_of(%Tag{type: %FbType{body: nil} = type}, side),
    do: counting(FbType.rules(type), side)

  defp counter_of(_no_tag, side), do: {own_kind(side), @dint}

  defp counting(%{kind: :counter, family: kind, counts: counts}, _side),
    do: {kind, Declarations.range(counts)}

  defp counting(_no_counter, side), do: {own_kind(side), @dint}

  defp own_kind(:up), do: "ctu"
  defp own_kind(:down), do: "ctd"

  defp memory(:up), do: "cu"
  defp memory(:down), do: "cd"

  # A run is recorded without dropping a mark a skipped rung of the same instance left, a
  # ctud's other side's (M3-5, decision 106).
  defp unblocked(true, env, name),
    do: Map.put(env, @ran, Map.update(as_map(Map.get(env, @ran)), name, %{}, &as_map/1))

  defp unblocked(false, env, _name), do: env

  # Whatever a hand-built env left out of a counter, a well-formed one comes back: a member
  # it left out reads 0, and a bit is read as a contact; every member it holds is inside its
  # type (decisions 171 and 173).
  defp count({kind, limits}, side, state, {power, edge}) do
    pv = integer(Map.get(state, "pv"))
    flags = {closed?(Map.get(state, "ov")), closed?(Map.get(state, "un"))}

    {cv, {ov, un}} =
      step({kind, limits}, side, state, {integer(Map.get(state, "cv")), pv, flags, edge})

    members(kind, state, %{"pv" => pv, "cv" => cv, "ov" => ov, "un" => un}, {side, power})
  end

  # IEC's priority, R before LD before a count (Ed 3 Table 45): a ctu has no `ld` and a
  # ctd no `r`.
  defp step({kind, limits}, side, state, {cv, pv, flags, edge}),
    do: step(limits, reset?(kind, state), load?(kind, state), side, {cv, pv, flags, edge})

  defp step(_limits, true, _load, _side, {_cv, _pv, _flags, _edge}), do: {0, {false, false}}
  defp step(_limits, false, true, _side, {_cv, pv, _flags, _edge}), do: {pv, {false, false}}
  defp step(_limits, false, false, _side, {cv, _pv, flags, false}), do: {cv, flags}

  defp step(_min..max//1, false, false, :up, {cv, _pv, {_ov, un}, true}) when cv >= max,
    do: {cv, {true, un}}

  defp step(_limits, false, false, :up, {cv, _pv, flags, true}), do: {cv + 1, flags}

  defp step(min.._max//1, false, false, :down, {cv, _pv, {ov, _un}, true}) when cv <= min,
    do: {cv, {ov, true}}

  defp step(_limits, false, false, :down, {cv, _pv, flags, true}), do: {cv - 1, flags}

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

  # M3-3: the exact result of two sources, before it is wrapped into a dint.
  defp sum(:add, a, b) when is_integer(a) and is_integer(b), do: a + b
  defp sum(:sub, a, b) when is_integer(a) and is_integer(b), do: a - b
  defp sum(:mul, a, b) when is_integer(a) and is_integer(b), do: a * b

  # M5-10: a sum of reals, one past an `lreal`'s range an overflow of its sign.
  defp sum(:add, a, b), do: floated(fn -> a + b end, sign(a))
  defp sum(:sub, a, b), do: floated(fn -> a - b end, sign(a))
  defp sum(:mul, a, b), do: floated(fn -> a * b end, sign(a) * sign(b))

  defp sign(b) when b < 0, do: -1
  defp sign(_b), do: 1

  # M3-3: a division, by a divisor that is 0 or not. A zero divisor is a minor fault the
  # scan reports (decision 99), recorded in the routine's env as `{symbol, line}` until the
  # routine is done, which places it (`faulted/2`, `raised/4`).
  # M5-10 (decision 150): a real's zero divisor, 0.0 or an integer 0, writes 0.0, a real's
  # zero, which a routine of no real, `reals` nil, never meets.
  defp divided(at, _a, b, {destination, %Scan{reals: nil}}, env) when b == 0,
    do:
      {false, Map.put(write(env, destination, 0), @faults, [at | as_list(Map.get(env, @faults))])}

  defp divided(at, _a, b, {destination, %Scan{reals: reals}}, env) when b == 0,
    do:
      {false,
       Map.put(
         write(env, destination, zero_in(real_of(destination, reals))),
         @faults,
         [at | as_list(Map.get(env, @faults))]
       )}

  defp divided({op, _line} = at, a, b, {destination, scan}, env) do
    type = type_at(at, destination, scan)
    {power, value} = wrapped(type, quotient(type, op, a, b))
    {power, write(env, destination, value)}
  end

  # M5-10: `div` into a real is real division, its sources' integers too, `div i j r`
  # computing 7 / 2 as 3.5 in a real; one past an `lreal`'s range, which raises on the BEAM,
  # is an overflow the wrap saturates (decision 150).
  defp quotient(type, :div, a, b) when type in @reals,
    do: floated(fn -> a / b end, sign(a) * sign(b))

  defp quotient(_type, :div, a, b), do: div(a, b)
  defp quotient(_type, :mod, a, b), do: rem(a, b)

  defp zero_in(:none), do: 0
  defp zero_in(_real), do: 0.0

  # M5-10: a real result the BEAM cannot hold, an `lreal`'s past its range, which raises,
  # given as an overflow of the sign it would have had, the wrap saturating it (wrapped/2).
  defp floated(computed, sign) do
    computed.()
  rescue
    ArithmeticError -> {:overflow, sign}
  end

  defp rooted(at, value, {destination, _scan}, env) when value < 0,
    do:
      {false,
       Map.put(write(env, destination, 0.0), @faults, [
         {:negative_sqrt, at, value} | as_list(Map.get(env, @faults))
       ])}

  defp rooted(at, value, {destination, scan}, env) do
    {power, root} = wrapped(root_type(at, destination, scan), :math.sqrt(value))
    {power, write(env, destination, root)}
  end

  # A real conversion's result, rounded into an integer and wrapped, or the nearest value
  # of a real.
  defp converted(to, value) when to in @reals, do: Logex.Real.stored(to, value)
  defp converted(to, value), do: wrapped(to, rounded(value))

  defp rounded(value) when is_float(value), do: Logex.Real.round_even(value)
  defp rounded(value), do: value

  defp signed(:neg, a), do: -a
  defp signed(:abs, a), do: abs(a)

  # M5-8: the bitwise function of two values, on Elixir's integers, whose negatives are
  # two's complement of any width.
  defp bitwise(:and, a, b), do: Bitwise.band(a, b)
  defp bitwise(:or, a, b), do: Bitwise.bor(a, b)
  defp bitwise(:xor, a, b), do: Bitwise.bxor(a, b)

  # M5-8 (decision 165): a shift or rotate of an N-bit pattern, as `{power, pattern}`: a
  # negative count leaves it as it is with no power; a shift of N or more shifts every bit
  # out; a rotate by its count modulo N, a right one by N less that, as a left one.
  defp shifted(_op, pattern, count, _width) when count < 0, do: {false, pattern}

  defp shifted(op, _pattern, count, width) when op in [:shl, :shr] and count >= width,
    do: {true, 0}

  defp shifted(:shl, pattern, count, width),
    do: {true, Bitwise.band(Bitwise.bsl(pattern, count), mask(width))}

  defp shifted(:shr, pattern, count, _width), do: {true, Bitwise.bsr(pattern, count)}

  defp shifted(:rol, pattern, count, width),
    do: {true, rotated(pattern, rem(count, width), width)}

  defp shifted(:ror, pattern, count, width),
    do: {true, rotated(pattern, width - rem(count, width), width)}

  defp rotated(pattern, by, width),
    do:
      Bitwise.band(
        Bitwise.bor(Bitwise.bsl(pattern, by), Bitwise.bsr(pattern, width - by)),
        mask(width)
      )

  defp mask(width), do: Bitwise.bsl(1, width) - 1

  # M5-4 (decision 147): the type an arithmetic instruction computes in, its destination's,
  # a tag's in the routine's table or a member's of the built-in instance that holds it,
  # by the one rule `Logex.Program.destination/2`, which the entry point where a program is
  # first handed in has held to an integer type since decision 182, refusing a program
  # edited by hand whose destination has none. Since decision 190 a program edited by hand
  # after that check is trusted, not walked again; a scan that reaches such a destination
  # raises a pinned `ArgumentError` at it, so that nothing else escapes (provisional).
  # The lookup is the one rule's own reading, made here with no tuple, so that a scan costs
  # what it did before decision 182: a destination it does not take is handed to the rule,
  # which says what it is, or, were the two ever to differ, the type the rule finds.
  defp type_at(at, {:name, _, name} = destination, %Scan{tags: tags}),
    do: tag_type(Map.get(tags, name), {at, destination, tags})

  defp type_at(at, {:member, _, [instance, member]} = destination, %Scan{tags: tags}),
    do: member_type(Map.get(tags, instance), member, {at, destination, tags})

  # M5-11: an element computes in its array's elements' type.
  defp type_at(at, {:element, _, array, _index, _name} = destination, %Scan{tags: tags}),
    do: tag_type(element_tag(Map.get(tags, array)), {at, destination, tags})

  defp type_at(at, {:element_at, _, array, _, _, _} = destination, %Scan{tags: tags}),
    do: tag_type(element_tag(Map.get(tags, array)), {at, destination, tags})

  defp type_at(at, destination, %Scan{tags: tags}), do: refused_at({at, destination, tags})

  # An array's tag as the tag of one of its elements, of its elements' type, for the
  # destination rules above, which read a tag's type; anything else as none, which they
  # refuse, the one rule saying what it is (`Logex.Program.destination/3`).
  defp element_tag(%Tag{type: {:array, type, _dims}} = tag), do: %{tag | type: type}
  defp element_tag(_no_array), do: nil

  # M5-8: the type a bitwise instruction computes in, its destination's, an integer's or,
  # since decision 155, a bit string's, and since decision 206 a bool's, by the one rule
  # `Logex.Program.destination/3` reads as `:bitwise`, a bit's or a member's read there; a
  # destination it does not take raises as type_at/3's does.
  defp bits_at(at, {:name, _, name} = destination, %Scan{tags: tags}),
    do: bits_type(Map.get(tags, name), {at, destination, tags})

  defp bits_at(at, {:element, _, array, _index, _name} = destination, %Scan{tags: tags}),
    do: bits_type(element_tag(Map.get(tags, array)), {at, destination, tags})

  defp bits_at(at, {:element_at, _, array, _, _, _} = destination, %Scan{tags: tags}),
    do: bits_type(element_tag(Map.get(tags, array)), {at, destination, tags})

  defp bits_at(at, destination, %Scan{tags: tags}),
    do: bits_refused({at, destination, tags})

  defp bits_type(%Tag{type: type}, _met)
       when type in @integers or type in @bit_strings or type == :bool,
       do: type

  defp bits_type(_neither, met), do: bits_refused(met)

  defp bits_refused({at, destination, tags}),
    do: computes_in(Program.destination(destination, tags, :bitwise), at, destination)

  # Decision 214: the type a `not` or a shift computes in, its source's, IEC's typing: a
  # tag's in the routine's table, read by one guard, a bit's a
  # bool's, and a member's by the one rule, `Logex.Program.destination/3`; a literal, which
  # its slot judges, computes in the destination's type, `type`, as does a source the rule
  # finds no type for, which only a program edited by hand after its check holds.
  defp source_bits({:name, _, name}, type, %Scan{tags: tags}),
    do: own_bits(:maps.get(name, tags, nil), type)

  defp source_bits({:bit, _, _, _, _, _}, _type, _scan), do: :bool

  defp source_bits({:element, _, array, _index, _name}, type, %Scan{tags: tags}),
    do: own_bits(element_tag(:maps.get(array, tags, nil)), type)

  defp source_bits({:bit_at, _, _, _, _, _}, _type, _scan), do: :bool

  defp source_bits({:element_at, _, array, _, _, _}, type, %Scan{tags: tags}),
    do: own_bits(element_tag(:maps.get(array, tags, nil)), type)

  defp source_bits({:member, _, _} = source, type, %Scan{tags: tags}),
    do: found_bits(Program.destination(source, tags, :bitwise), type)

  defp source_bits(_literal, type, _scan), do: type

  defp own_bits(%Tag{type: from}, _type) when from in @bitwise_types, do: from
  defp own_bits(_neither, type), do: type

  defp found_bits({:ok, from}, _type), do: from
  defp found_bits({:error, _what}, type), do: type

  # The result, a pattern of the source's type, kept to its width and read as its type,
  # into the destination's, which Figure 11 widens it into, keeping its value: read once in
  # the destination's type where the two are one, and otherwise read in the source's and
  # then brought into the destination, which leaves a value that fits as it is.
  defp widened(type, type, pattern), do: transfer(type, pattern)
  defp widened(from, type, pattern), do: transfer(type, transfer(from, pattern))

  defp tag_type(%Tag{type: type}, _met) when type in @integers, do: type
  # M5-10: a real, which the arithmetic computes in too (decision 147).
  defp tag_type(%Tag{type: type}, _met) when type in @reals, do: type
  defp tag_type(_no_integer, met), do: refused_at(met)

  # M5-10: the type `sqrt` computes in, its destination's, a real's, by the one rule
  # `Logex.Program.destination/3` reads as `:real`; a destination it does not take raises as
  # type_at/3's does.
  defp root_type(at, {:name, _, name} = destination, %Scan{tags: tags}),
    do: root_of(Map.get(tags, name), {at, destination, tags})

  defp root_type(at, {:element, _, array, _index, _name} = destination, %Scan{tags: tags}),
    do: root_of(element_tag(Map.get(tags, array)), {at, destination, tags})

  defp root_type(at, {:element_at, _, array, _, _, _} = destination, %Scan{tags: tags}),
    do: root_of(element_tag(Map.get(tags, array)), {at, destination, tags})

  defp root_type(at, destination, %Scan{tags: tags}), do: rooted_at({at, destination, tags})

  defp root_of(%Tag{type: type}, _met) when type in @reals, do: type
  defp root_of(_no_real, met), do: rooted_at(met)

  defp rooted_at({at, destination, tags}),
    do: computes_in(Program.destination(destination, tags, :real), at, destination)

  defp member_type(%Tag{type: %FbType{body: nil} = type}, member, met),
    do: member_of(FbType.member(type, member), met)

  defp member_type(_no_builtin, _member, met), do: refused_at(met)

  defp member_of({:ok, %Member{type: type}}, _met) when type in @integers, do: type
  defp member_of(_no_integer, met), do: refused_at(met)

  defp refused_at({at, destination, tags}),
    do: computes_in(Program.destination(destination, tags), at, destination)

  defp computes_in({:ok, type}, _at, _destination), do: type

  defp computes_in({:error, what}, {op, line}, destination),
    do:
      raise(
        ArgumentError,
        "a scan's `#{op}` on line #{line} computes in the type of " <>
          Program.met(destination, what) <>
          ": the program was edited by hand after it was handed in and checked"
      )

  # M5-2: a result is brought into the dint by keeping its low 32 bits, read in two's
  # complement, and passes no power on the scan where that stored value is not the exact
  # one (decision 146, superseding decision 77's saturation); no fault is recorded for it.
  # A result inside the dint is itself and passes power. M5-3: so too into every integer
  # type, a conversion's, its width and kind the one table's, read unsigned for an
  # unsigned type; and since M5-4 an arithmetic result, into its destination's type.

  for %{type: type, kind: kind, width: width, range: range} <- Declarations.table(),
      kind in [:signed, :unsigned] do
    defp wrapped(unquote(type), value) when value in unquote(Macro.escape(range)),
      do: {true, value}

    defp wrapped(unquote(type), value), do: {false, low(unquote(kind), unquote(width), value)}
  end

  # M5-10 (decision 150): a real result is the real's nearest value, with power, or past its
  # range saturated at its largest finite value, the sign kept, with no power.
  defp wrapped(type, {:overflow, sign}) when type in @reals,
    do: {false, sign * Logex.Real.max(type)}

  defp wrapped(type, value) when type in @reals, do: Logex.Real.stored(type, value)

  # M5-8: a bit pattern into a type of the table, its low bits kept, read in two's
  # complement for a signed type and as unsigned for an unsigned type and a bit string (a
  # binary transfer, Ed 3 Tables 24 and 25), and since decision 206 for a bool, one bit,
  # which a bitwise instruction computes in.
  for %{type: type, kind: kind, width: width} <- Declarations.table(), kind != :real do
    defp transfer(unquote(type), pattern),
      do: low(unquote(Map.get(%{signed: :signed}, kind, :unsigned)), unquote(width), pattern)
  end

  defp low(:signed, width, value) do
    <<low::signed-size(^width)>> = <<value::size(width)>>
    low
  end

  defp low(:unsigned, width, value) do
    <<low::size(^width)>> = <<value::size(width)>>
    low
  end

  # `ne`, `ge` and `le` are the negations of `eq`, `lt` and `gt`, so each pair is
  # complementary by construction, as `xic` and `xio` are (M1-4). Each reads integers: a
  # state handed in holds no other value (decision 173), and a tag it leaves out reads 0.
  defp compare(:eq, a, b), do: a == b
  defp compare(:ne, a, b), do: not compare(:eq, a, b)
  defp compare(:lt, a, b), do: a < b
  defp compare(:ge, a, b), do: not compare(:lt, a, b)
  defp compare(:gt, a, b), do: a > b
  defp compare(:le, a, b), do: not compare(:gt, a, b)

  # Whatever a hand-built env left in a timer, a well-formed one comes back: a member it
  # leaves out reads 0, `.en` is read as a contact, and a `last` the env leaves out adds
  # nothing; every `.pre`, `.acc` and bit it holds is inside its type (decisions 171 and
  # 173), and its `last` an integer (decision 186) no later than the instance's `now`
  # (decision 188), so never later than the scan's. A negative `.acc`, which logic may write,
  # counts from 0: it is floored before the time is added, not after.
  #
  # M5-6 (decision 158): a timer's clock is the scan's `now` with what each millisecond adds
  # to its `.acc`, its type's `per_ms` (Logex.FbType.rules/1): 1 for a timer counted in ms,
  # and 1,000,000 for a long timer, counted in ns, whose resolution is so a millisecond,
  # a preset that is no whole number of them reached at the next. `last` stays a time on
  # the scan's clock, in ms.
  #
  # Decision 197: each timer's unit is settled when logex compiles, carried in the
  # program's `units` and so in the scan's, the routine's own: each clause that reads a
  # clock first matches `units: nil`, a routine with no timer of another unit, and passes
  # 1 with no look-up, so a plain timer's run costs what it did before long timers; a
  # routine holding a long timer looks each of its timers up here, one it leaves out, or
  # a member, which only a program built by hand names, counting in ms. A unit that is no
  # positive whole number, or units that are no map, which only a program edited by hand
  # after its check holds, raise (decision 194). `now` and the unit are passed as two
  # arguments, not a tuple, whose allocation the garbage collector counts.
  defp unit({:name, _, name} = timer, %Scan{units: units}, at) when is_map_key(units, name),
    do: unit_of(:erlang.map_get(name, units), {at, timer})

  defp unit(_member, %Scan{units: units}, _at) when is_map(units), do: 1

  defp unit(timer, %Scan{units: units}, {op, line}),
    do:
      raise(
        ArgumentError,
        "a scan's `#{op}` on line #{line} reads the unit of #{shown_timer(timer)} from units that " <>
          "are no map, got: #{inspect(units)}: #{by_hand()}"
      )

  defp unit_of(per_ms, _at) when is_integer(per_ms) and per_ms > 0, do: per_ms

  defp unit_of(per_ms, {{op, line}, timer}),
    do:
      raise(
        ArgumentError,
        "a scan's `#{op}` on line #{line} times #{shown_timer(timer)} in a unit of " <>
          "#{inspect(per_ms)}, which is no positive whole number a millisecond: #{by_hand()}"
      )

  defp shown_timer({:name, _, name}), do: "`#{name}`"

  defp by_hand, do: "the program was edited by hand after it was handed in and checked"

  defp timing(timer, now, per_ms) do
    pre = integer(Map.get(timer, "pre"))
    limit = max(pre, 0)
    elapsed = elapsed(closed?(Map.get(timer, "en")), Map.get(timer, "last"), now, per_ms)
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

  defp off_delay(timer, now, per_ms),
    do:
      delayed(
        closed?(Map.get(timer, "en")) or closed?(Map.get(timer, "tt")),
        timer,
        now,
        per_ms
      )

  defp delayed(true, timer, now, per_ms) do
    pre = integer(Map.get(timer, "pre"))
    limit = max(pre, 0)
    elapsed = elapsed(closed?(Map.get(timer, "tt")), Map.get(timer, "last"), now, per_ms)
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

  defp delayed(false, timer, now, _per_ms),
    do: %{
      "pre" => integer(Map.get(timer, "pre")),
      "acc" => integer(Map.get(timer, "acc")),
      "dn" => 0,
      "tt" => 0,
      "en" => 0,
      "last" => now
    }

  # M3-2: one run of an `rto`, its reset first.
  defp retained(timer, power, now, per_ms),
    do: retained(closed?(Map.get(timer, "r")), power, timer, now, per_ms)

  defp retained(true, power, timer, now, _per_ms),
    do: %{
      "pre" => integer(Map.get(timer, "pre")),
      "acc" => 0,
      "dn" => 0,
      "tt" => 0,
      "en" => one(power),
      "r" => 1,
      "last" => now
    }

  defp retained(false, true, timer, now, per_ms),
    do: Map.put(timing(timer, now, per_ms), "r", 0)

  defp retained(false, false, timer, now, _per_ms),
    do: %{
      "pre" => integer(Map.get(timer, "pre")),
      "acc" => integer(Map.get(timer, "acc")),
      "dn" => bit(Map.get(timer, "dn")),
      "tt" => 0,
      "en" => 0,
      "r" => 0,
      "last" => now
    }

  # M3-2: one run of a `tp`. The compiler names a timer only whole, `{:name, _, timer}`.
  defp pulsed(env, {:name, _, name} = timer, {power, _now} = at, scan, per_ms) do
    tree = as_map(Map.get(scan.ons_blocked, name))
    blocked = scan.first or Map.get(tree, "en") == true
    state = as_map(read(env, timer))
    edge = power and not blocked and not closed?(Map.get(state, "en"))
    env = write(env, timer, pulse(closed?(Map.get(state, "tt")), edge, state, at, per_ms))
    unblocked(map_size(tree) > 0, env, name)
  end

  # Pulsing: the time since its last run, whatever the rung or an edge.
  defp pulse(true, _edge, timer, {_power, now} = at, per_ms) do
    elapsed = elapsed(true, Map.get(timer, "last"), now, per_ms)
    pulsing(timer, max(integer(Map.get(timer, "acc")), 0) + elapsed, at)
  end

  # A rising edge starts the pulse from 0.
  defp pulse(false, true, timer, at, _per_ms), do: pulsing(timer, 0, at)

  # Neither: held true, `.dn` and `.acc` as they were; false, both 0.
  defp pulse(false, false, timer, {true, now}, _per_ms),
    do: %{
      "pre" => integer(Map.get(timer, "pre")),
      "acc" => integer(Map.get(timer, "acc")),
      "dn" => bit(Map.get(timer, "dn")),
      "tt" => 0,
      "en" => 1,
      "last" => now
    }

  defp pulse(false, false, timer, {false, now}, _per_ms),
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

  defp elapsed(true, last, now, per_ms) when is_integer(last), do: max(now - last, 0) * per_ms
  defp elapsed(_enabled, _last, _now, _per_ms), do: 0

  defp integer(value) when is_integer(value), do: value
  defp integer(_not_an_integer), do: 0

  defp as_input({name, value}, reals), do: {name, as_real(:maps.get(name, reals, :none), value)}

  defp as_array_input({name, value}, reals, arrays),
    do: array_input(:maps.get(name, arrays, nil), {name, value}, as_map(reals))

  defp array_input({:array, type, dims}, {name, value}, _reals),
    do: {name, Logex.Array.from_list(value, dims, &as_real(real_type(type), &1))}

  defp array_input(nil, input, reals), do: as_input(input, reals)

  defp as_element_input({key, value}, env, program) do
    [{array, index, _key}] = element_index(key, program)
    {:array, type, _dims} = :maps.get(array, program.arrays)
    stored = as_real(real_type(type), value)
    %{env | array => Logex.Array.put(:erlang.map_get(array, env), index, stored)}
  end

  defp real_type(type) when type in @reals, do: type
  defp real_type(_type), do: :none

  # M5-10: an arithmetic source, an integer or a real.
  defp number(value) when is_number(value), do: value
  defp number(_not_a_number), do: 0

  # M5-10 (decision 150): a value written into a real, its nearest value, an integer widened
  # into it, or into nothing that is a real, as it is.
  defp real_of({:name, _, name}, reals), do: :maps.get(name, reals, :none)
  # M5-11: an element of an array of reals is its elements' real, by its array's name.
  defp real_of({:element, _, array, _index, _name}, reals), do: :maps.get(array, reals, :none)
  defp real_of({:element_at, _, array, _, _, _}, reals), do: :maps.get(array, reals, :none)
  defp real_of(_member, _reals), do: :none

  defp as_real(:none, value), do: value
  defp as_real(type, value), do: elem(Logex.Real.stored(type, value), 1)

  defp one(true), do: 1
  defp one(false), do: 0

  # An operand's value: a literal's own, a tag's, or a member's, reached by its path. A tag
  # or member the env leaves out, or one whose instance a hand-built env left as anything
  # but a map, reads as 0, as a missing tag always has, so `move` copies a 0, not a nil.
  defp read(_env, {:int_lit, _, value}), do: value
  defp read(env, {:name, _, name}), do: Map.get(env, name, 0)
  defp read(env, {:member, _, path}), do: walk(env, path)

  # M5-8 (decision 155): a bit of a tag or a member, 1 where its mask's bits are set in the
  # value, read in two's complement, a signed type's top bit its sign (Logex.Compiler).
  defp read(env, {:bit, _, [name], _n, mask, _name}), do: bit_set(Map.get(env, name, 0), mask)
  # Decision 221: a bit of an element, its element read first.
  defp read(env, {:bit, _, {:element, _, _, _, _} = element, _n, mask, _name}),
    do: bit_set(read(env, element), mask)

  # M5-12: a bit of an element a tag subscripts, its element read first.
  defp read(env, {:bit, _, {:element_at, _, _, _, _, _} = element, _n, mask, _name}),
    do: bit_set(read(env, element), mask)

  defp read(env, {:bit, _, path, _n, mask, _name}), do: bit_set(walk(env, path), mask)
  # M5-9 (decision 160): a bit whose number a tag holds, the number read first, as an
  # integer, and its mask computed from the width and top bit the compiler gave: one past
  # the word's bits, or below 0, is out of range, thrown to the instruction (element/3).
  defp read(env, {:bit_at, _, [name], index, {width, top}, _name}),
    do: bit_set(Map.get(env, name, 0), bit_mask(integer(read(env, index)), width, top))

  defp read(env, {:bit_at, _, {:element, _, _, _, _} = element, index, {width, top}, _name}),
    do: bit_set(read(env, element), bit_mask(integer(read(env, index)), width, top))

  defp read(env, {:bit_at, _, {:element_at, _, _, _, _, _} = element, index, {width, top}, _}),
    do: bit_set(read(env, element), bit_mask(integer(read(env, index)), width, top))

  defp read(env, {:bit_at, _, path, index, {width, top}, _name}),
    do: bit_set(walk(env, path), bit_mask(integer(read(env, index)), width, top))

  # Decision 202: a literal written other than as its plain decimal keeps its spelling,
  # which no scan reads.
  defp read(_env, {:int_lit, _, value, _spelling}), do: value

  # M5-10: a real literal's own value, its spelling unread.
  defp read(_env, {:real_lit, _, value}), do: value
  defp read(_env, {:real_lit, _, value, _spelling}), do: value

  # M5-11 (decision 151): an element of an array, its subscripts literal, which the
  # compiler checked against its dimensions: one `elem/2` a dimension of the tuple its
  # array holds, which every state handed in holds whole (values!/2).
  defp read(env, {:element, _, array, [i], _name}), do: elem(:erlang.map_get(array, env), i)

  defp read(env, {:element, _, array, index, _name}),
    do: Logex.Array.fetch(:erlang.map_get(array, env), index)

  # M5-12 (decisions 152 and 153): an element a tag subscripts, each subscript a literal's
  # value or its tag's, read as an integer, and checked against its dimension as the element
  # is read: one outside it is thrown to the instruction (element/3), with every subscript
  # read, one a dimension.
  # One dimension and one tag, `weights[slot]`, read with no list built.
  defp read(env, {:element_at, _, array, [{:name, _, name}], [count], _name}),
    do: elem(:erlang.map_get(array, env), one_subscript(Map.get(env, name, 0), count))

  defp read(env, {:element_at, _, array, index, dims, _name}),
    do: Logex.Array.fetch(:erlang.map_get(array, env), subscripts(env, index, dims))

  defp walk(value, []), do: value
  defp walk(%{} = map, [key | path]), do: walk(Map.get(map, key, 0), path)
  defp walk(_not_a_map, _path), do: 0

  # A write to a member puts an instance back together where a hand-built env broke it:
  # what is not a map on the way becomes one.
  defp write(env, {:name, _, name}, value), do: Map.put(env, name, value)
  defp write(env, {:member, _, path}, value), do: put_path(env, path, value)

  # M5-11: an element is written into its array, the tuple of each dimension it passes
  # through copied, every other element kept.
  defp write(env, {:element, _, array, [i], _name}, value),
    do: %{env | array => put_elem(:erlang.map_get(array, env), i, value)}

  defp write(env, {:element, _, array, index, _name}, value),
    do: %{env | array => Logex.Array.put(:erlang.map_get(array, env), index, value)}

  # M5-12: an element a tag subscripts is written into its array once its subscripts are
  # read and checked, and a bit of one into its element, the rest of its word kept.
  defp write(env, {:element_at, _, array, [{:name, _, name}], [count], _name}, value),
    do: %{
      env
      | array =>
          put_elem(
            :erlang.map_get(array, env),
            one_subscript(Map.get(env, name, 0), count),
            value
          )
    }

  defp write(env, {:element_at, _, array, index, dims, _name}, value),
    do: %{
      env
      | array => Logex.Array.put(:erlang.map_get(array, env), subscripts(env, index, dims), value)
    }

  # M5-8: a bit is written into its word, the rest of the word kept: 1 sets the mask's bits
  # and 0 clears them, so a signed type's top bit, whose mask is every bit from it up, is
  # its sign, and the word stays inside its type.
  defp write(env, {:bit, _, [name], _n, mask, _name}, value),
    do: Map.put(env, name, with_bit(integer(Map.get(env, name, 0)), mask, value))

  # Decision 221: a bit of an element is written into the element, the rest of its word
  # kept, and the element into its array.
  defp write(env, {:bit, _, {:element, _, _, _, _} = element, _n, mask, _name}, value),
    do: write(env, element, with_bit(integer(read(env, element)), mask, value))

  # M5-12: a bit of an element a tag subscripts.
  defp write(env, {:bit, _, {:element_at, _, _, _, _, _} = element, _n, mask, _name}, value),
    do: write(env, element, with_bit(integer(read(env, element)), mask, value))

  defp write(env, {:bit, _, path, _n, mask, _name}, value),
    do: put_path(env, path, with_bit(integer(walk(env, path)), mask, value))

  defp write(env, {:bit_at, _, [name], index, {width, top}, _name}, value) do
    mask = bit_mask(integer(read(env, index)), width, top)
    Map.put(env, name, with_bit(integer(Map.get(env, name, 0)), mask, value))
  end

  defp write(env, {:bit_at, _, {:element, _, _, _, _} = element, index, {width, top}, _}, value) do
    mask = bit_mask(integer(read(env, index)), width, top)
    write(env, element, with_bit(integer(read(env, element)), mask, value))
  end

  defp write(
         env,
         {:bit_at, _, {:element_at, _, _, _, _, _} = element, index, {width, top}, _},
         value
       ) do
    word = integer(read(env, element))
    mask = bit_mask(integer(read(env, index)), width, top)
    write(env, element, with_bit(word, mask, value))
  end

  defp write(env, {:bit_at, _, path, index, {width, top}, _name}, value) do
    mask = bit_mask(integer(read(env, index)), width, top)
    put_path(env, path, with_bit(integer(walk(env, path)), mask, value))
  end

  # The mask of bit n of a word `width` bits wide, its top bit `top`, a signed type's sign
  # (Logex.Compiler); a number outside 0 to width - 1 is thrown, with the number read.
  defp bit_mask(n, width, _top) when n >= 0 and n < width - 1, do: Bitwise.bsl(1, n)
  defp bit_mask(n, width, top) when n == width - 1, do: top
  defp bit_mask(n, _width, _top), do: throw({@out_of_range, :bit_out_of_range, n})

  # M5-12: each subscript's value, a literal's own or its tag's as an integer, and the whole
  # index checked against the array's dimensions: one outside its dimension is thrown with
  # every subscript read, since decision 233 as a tuple, `{1, 9}` or `{8}`, which no
  # `inspect/1` shows as a charlist.
  defp subscripts(env, index, dims), do: in_dimensions(read_subscripts(env, index), dims)

  defp one_subscript(i, count) when is_integer(i) and i >= 0 and i < count, do: i
  defp one_subscript(i, count) when is_integer(i), do: in_dimensions([i], [count])
  defp one_subscript(_not_an_integer, count), do: one_subscript(0, count)

  defp read_subscripts(_env, []), do: []
  defp read_subscripts(env, [i | index]) when is_integer(i), do: [i | read_subscripts(env, index)]

  defp read_subscripts(env, [{:name, _, name} | index]),
    do: [integer(Map.get(env, name, 0)) | read_subscripts(env, index)]

  defp in_dimensions(read, dims), do: in_bounds(read, dims, read)

  defp in_bounds([], [], read), do: read

  defp in_bounds([i | index], [count | dims], read) when i >= 0 and i < count,
    do: in_bounds(index, dims, read)

  defp in_bounds(_index, _dims, read),
    do: throw({@out_of_range, :index_out_of_range, List.to_tuple(read)})

  defp bit_set(value, mask) when is_integer(value), do: one(Bitwise.band(value, mask) != 0)
  defp bit_set(_not_an_integer, _mask), do: 0

  defp with_bit(word, mask, 0), do: Bitwise.band(word, Bitwise.bnot(mask))
  defp with_bit(word, mask, _one), do: Bitwise.bor(word, mask)

  defp put_path(map, [key], value), do: Map.put(map, key, value)

  defp put_path(map, [key | path], value),
    do: Map.put(map, key, put_path(as_map(Map.get(map, key)), path, value))

  defp as_map(%{} = map), do: map
  defp as_map(_not_a_map), do: %{}

  # M1-4: `xic` reads this and `xio` its negation, so the two are complementary by
  # construction, whatever the env holds. The compiler lets only a bool reach a contact,
  # and since decisions 171 and 173 a state handed in holds only a bool's 0 or 1 there, so
  # what reaches it is a 0, a 1, or a tag or member left out, which reads open. A number
  # is read by value, nonzero closed (PLAN.md §5), a boolean as itself, nil open and
  # anything else closed, M1-4's totality kept for what no check looks into. A member is
  # read the same way (M1-6).
  defp closed?(value) when is_number(value), do: value != 0
  defp closed?(value) when value in [nil, false], do: false
  defp closed?(_value), do: true
end
