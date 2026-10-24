defmodule Logex.Configuration do
  @moduledoc """
  A configuration: the program types it runs, its tasks, its globals, its program
  instances and the connections that wire them (M2-1, `docs/organisation.md` §4.4). A
  value, plain data, which `Logex.Runtime.start/1` runs as one resource, built in Elixir
  or written in a configuration file (`.logex`, M2-2, read by `Logex.Configuration.Text`
  and printed back by its `print/1`, the round trip exact).

  - `programs` maps each program type's name to its `%Logex.Program{}`.
  - `tasks`, `globals`, `instances` and `connections` are lists, in declaration order, of
    `Logex.Configuration.Task`, `Logex.Configuration.Global`,
    `Logex.Configuration.Instance` and `Logex.Configuration.Connection`. The order of
    `instances` is the execution order within a task.
  - `name` is the configuration's own name, which it must have. `file` is the file it was
    read from, or nil for one built from Elixir; each element's `line` likewise, and
    `new!/1` refuses an element that brings one.
  - `warnings` are `%Logex.Diagnostic{severity: :warning}`, in line order: what runs, but
    is likely a slip. They stop nothing, and `new!/1` and `compile/3` give them.

  Every way of writing a configuration ends in `check/1`, the one validator: `new!/1`,
  from Elixir, raises one `ArgumentError` listing every problem it finds, a line each;
  `compile/3`, from a configuration file's text, returns them, and `compile_file/1` from
  the file on disk, its program types loaded from beside it (M2-2); and
  `Logex.Runtime.start/1` checks again. A mistake a configuration's text could also make
  is a `%Logex.Diagnostic{}` at stage `:configure`, cited at its element's line, which is
  how a reader of the text cites it, and worded as the configuration file says it,
  whether the element came from the text or from Elixir: one message a rule
  (`docs/organisation.md` §4.10). Its rules:

  - every name of a task, global or program instance is a name, as a tag's is, with no
    `.` parts, which are kept for a path and a location, and no configuration file's
    keyword (`Logex.Configuration.Text.keywords/0`) in any case; and no two of them are
    the same or differ only in case: one namespace, in which the first in line order keeps
    a name. A name refused for its `.` or as a keyword is reported once, and nothing that
    names it is reported again (decision 42), as nothing that names a configuration
    file's broken line is; a duplicate or a case twin is not recovered so, and a use of
    its name finds the element that kept it, as on a `.ld` declaration line. A program
    type is named in type position only, so an instance may share its type's name;
  - a task has an interval, 1 to 2147483647 ms, a single, or both (M2-6), and a priority,
    0, the highest, to 65535 (decision 37): IEC reads an interval of 0 as no periodic
    scheduling, and an instance that runs every cycle is one with no task, an event task
    one with no interval; a single names a bool global, located or not, whose rising edge
    makes the task due, read where a global is wanted, as a connection's is, its
    did-you-mean among the bool globals. A task with no priority is shown one of its own
    kind, its single, its interval or both, each its own where a line can say it, and its
    watchdog where it has one a line can say (M4-2), and named as every task example is,
    `t` where its name is none a line can declare; one with neither an interval, a single
    nor a priority, where the configuration declares no continuous task, is shown that
    too;
  - since M4-2 (decisions 109 to 111), a task's watchdog is 1 to 2147483647 ms, an
    interval's range, or none, for 500: every task has one, so 0 is told it is no "no
    watchdog"; and a configuration declares one continuous task at most, the first in
    line order, each after it told so, which takes no single, interval or priority, all
    it was given named in one diagnostic, and runs every instance with no timed task, an
    instance with no task among them;
  - a global's initial value fits its type, and a located global takes none; a location
    is `<device>.i.<address>` for an input point or `<device>.q.<address>` for an output
    point, its device a name, its address one or more whole numbers with no leading zero,
    the leftmost the highest level, and one written another way is told its one spelling;
    one address holds one global, and no two devices' names differ only in case. A global
    refused for its name has its location checked, but takes no address;
  - a program instance names a program type given, by a name that is no keyword, and, if
    it has one, a task the configuration declares; a name with `.` parts there is told a
    task's name has none, whatever else it could read as;
  - a connection names a var_input or a var_output of an instance. A var_input is
    connected once, to a global of its type or a constant that fits it; a var_output to a
    global of its type, never an input point, and one connection at most drives a
    global. Every var_input is connected (decision 7), and an instance that leaves any
    unconnected is told them all in one diagnostic. Where an instance or a global is
    wanted, a name with `.` parts is told the reading it has (`docs/organisation.md`
    §4.7): a location, written only after `at`; an instance's member, since instances
    share a value only through a global; or a member of what is no instance;
  - a program type an instance runs (M2-4) has, for each of its var_externals, a global of
    that name and type (Ed 2 §2.4.3), and writes through none of them an input point,
    which nothing drives; each type is checked once, at its first instance's line, its
    declaration's line and its first write's named in its own text, and a var_external
    named in a connection is told it reaches its global itself. Which tags it writes is
    `Logex.Walk.writes/1`'s;
  - a configuration runs at least one program instance.

  Its warnings: a global nothing uses, where an instance's var_external and a task's
  single use their global; an output point that something reads and nothing drives,
  which stays at 0, where a write through a var_external drives it; a task that runs no
  instance, the continuous task where every instance has a timed one (M4-2); and, since M2-4, two
  instances that write one global through a var_external, and an instance that writes
  through one a global a connection drives (decision 48), each in the words true of it:
  each scan reads what the other last wrote and the later write in a cycle stands; an
  instance's own connection's copy-out, after the scan, stands (decision 47); or, for a
  global an `ons`, or since M3-4 an `osr` or an `osf`, keeps its storage bit in, the
  one-shot fires on the wrong scans, its instruction named. Since
  M2-6, each timer a program instance runs that an event task runs, a task with a single
  alone or with an interval too, a timer inside a block its `cal`s run included, by its
  path: a ton times across the task's runs (`docs/organisation.md` §4.6, "Caveats"), at the
  instance's line, citing the `ton`'s line in its own text: its file's, the program's own
  line where the program was read from none, and a block's line by the block's name where
  the block was read from none, as in "on line 5 of block `inner`", each program type's timers
  read once (`Logex.Walk.timers/1`) and cited once, whatever its instances. Since M3-1,
  each counter such an instance runs, so too, after its timers (decision 72): a counter
  sees its rung only at the task's runs (`Logex.Walk.counters/1`). Since M3-2, each timer
  in its own type's words: a tof's delay and a tp's pulse end only at one of the task's
  runs, a tp starts only on an edge between two runs, and an rto, as a ton, adds the whole
  time between two runs whose rung is true. Since M3-4, each one-shot such an instance
  runs, an `ons`, an `osr` or an `osf`, a block's by its storage bit's path, so too, after
  its counters, each in its own words, citing its instruction (`Logex.Walk.one_shots/1`,
  decision 103): a one-shot sees its rung only at the task's runs, so an edge between two
  runs is never seen, and the pulse a coil sets stays on until the task's next run.

  **Arrays** (M5-11, `docs/organisation.md` §4.12, decisions 151 and 159). A global may be
  an array of an elementary type, `var_global temps int[8] 1 2 3 4 5 6 7 8`, its sizes
  and initial list judged as a declaration line's, and since M5-13 (decision 156) located,
  `var_global temps real[8] at card.i.0`, each element a point at consecutive addresses in
  the elements' order, its last field counting up, `temps[0]` at `card.i.0` to `temps[7]`
  at `card.i.7`, which overlaps no other point, both told where one would, and takes no
  initial list, an array of output points that nothing drives told the elements it
  leaves at 0, each named so in a location's message; a
  `var_external` array binds only to a global array of exactly its element type and every
  dimension's size; and a connection names an array var_input or var_output whole, to a
  global array of its sizes whose elements widen as a value does, or an element by literal
  subscripts, `m1.temps[3]`, as a tag of its element's type, an array var_input connected
  whole or at every element, a constant filling an element alone. Since decision 223 a
  connection's far end may be an element of a global array, `m2.speed speeds[1]`, read or
  driven as a global of its elements' type, widening as a global does, one connection at
  most driving each element and one that drives the array whole driving them all, decision
  48's writer warnings element by element. Since decision 227 a real initial value a
  `var_global` line writes with more digits than its real keeps is warned of, in decision
  219's words, at its line. A name with brackets names nothing else in a configuration.

  A mistake no configuration text can make is the host's, and `check/1` raises it as one
  `ArgumentError`, every such mistake a line each (decision 36), as
  `Logex.Compiler.instructionize/2` raises on a tree no source could say: a configuration
  whose name is not a name, or whose file is neither a string nor nil; programs that are
  not a map of names to `%Logex.Program{}`, each under its own name, one of them a
  function block type among them; a program edited by hand so that a var_input or
  var_output holds an instance, which no text declares, each such tag a line, connected or
  not (decision 169); a field that is not a proper list of its element
  struct, or a configuration or an element that lacks a key of its struct, as
  `Map.delete/2` can make one; a line that is not a positive integer or nil; lines that
  are neither all nil, as from Elixir, nor rising in each list, one element a line, as a
  file's are; a name, a location, a type or a task that the lexer does not read as one
  name token; a task's single that is neither nil nor one name token; a task's continuous
  that is neither true nor false (M4-2); a number that is not an integer, a watchdog's
  among them; a global's type that is no elementary type, `:bool`, `:dint` or since M5-3 another
  integer type, nor since M5-11 an array of one whose sizes are a non-empty list of
  integers, and an array global's initial value that is neither nil nor a list of numbers
  its elements could take; and a connection's
  instance that is not a name, or with its member makes no one path. A negative number was
  one too, until a negative literal lexed (M3-3, decision 97): a line can say one now, so
  a negative interval or priority is a diagnostic, in the file's words, as one too large is.

  Each list of names a diagnostic ends with is given once, by the first diagnostic in
  line order that needs it, so a refusal is linear in its size. Its time is not: each
  unknown name is matched against every name for a did-you-mean, so a refusal of many bad
  names among many names takes time quadratic in the two, as the `.ld` compiler's
  refusals do. Only a mistake pays it.
  """

  alias Logex.{Declarations, Diagnostic, FbType, Program, Tag, Walk}
  alias Logex.Configuration.{Connection, Global, Instance, Text}
  import Logex.Declarations, only: [is_elementary: 1]
  import Logex.Array, only: [is_array: 1]

  defstruct name: nil,
            file: nil,
            programs: %{},
            tasks: [],
            globals: [],
            instances: [],
            connections: [],
            warnings: []

  @type t :: %__MODULE__{
          name: String.t(),
          file: String.t() | nil,
          programs: %{String.t() => Program.t()},
          tasks: [Logex.Configuration.Task.t()],
          globals: [Global.t()],
          instances: [Instance.t()],
          connections: [Connection.t()],
          warnings: [Diagnostic.t()]
        }

  defmodule Task do
    @moduledoc """
    A task: `name`, `priority`, 0 the highest, to 65535, and what makes it due, in IEC's
    order (Ed 2 §2.7.2): `single`, the name of a bool global whose rising edge makes it
    due, an event task (M2-6), and `interval` in ms, which makes it due every `interval`
    ms from the start; one or both, nil for none. Its instances run once in every cycle
    in which it is due, in the order of the configuration's `instances`; with both, at
    most once a cycle, on an edge or periodically while its trigger is 0 (decision 39,
    `Logex.Runtime`).

    Since M4-2 (`docs/organisation.md` §4.11, decisions 109 to 111), `watchdog`, the
    milliseconds a run may take, 1 to 2147483647, or nil for 500
    (`Logex.Configuration.watchdog/1`), which the runner reads and `Logex.Runtime` does
    not; and `continuous`, true for the configuration's one continuous task, which takes
    no `single`, `interval` or `priority` and runs every instance with no timed task,
    those with no task among them, after the due tasks, once a cycle. Only `name` is
    enforced, since a timed task needs an interval or a single, and a priority, and a
    continuous task none of them, which `Logex.Configuration.check/1` says.
    """
    @enforce_keys [:name]
    defstruct [:name, :single, :interval, :priority, watchdog: nil, continuous: false, line: nil]

    @type t :: %__MODULE__{
            name: String.t(),
            single: String.t() | nil,
            interval: pos_integer | nil,
            priority: 0..65_535 | nil,
            watchdog: pos_integer | nil,
            continuous: boolean,
            line: pos_integer | nil
          }
  end

  defmodule Global do
    @moduledoc """
    A global: `name`, `type` (an elementary type, `:bool`, `:dint` or since M5-3 any
    integer type, `:uint` among them, or since M5-11 an array of one, `{:array, :int,
    [8]}`), an `initial` value or nil for 0, an array's a list of its elements' values in
    the elements' order, and
    `at`, a location such as `"panel.i.0"`, or nil. A global located at an `i` address is
    an input point, set by the host; one at a `q` address an output point, given back to
    the host after every cycle. Since M5-13 a located array is a point an element, at
    consecutive addresses from `at`, each named by its element, `temps[3]`.
    """
    @enforce_keys [:name, :type]
    defstruct [:name, :type, initial: nil, at: nil, line: nil]

    @type t :: %__MODULE__{
            name: String.t(),
            type: Logex.Declarations.elementary(),
            initial: non_neg_integer | nil,
            at: String.t() | nil,
            line: pos_integer | nil
          }
  end

  defmodule Instance do
    @moduledoc """
    A program instance: `name`, `type`, the name of the program it is an instance of,
    and `task`, the name of the task it runs under, or nil for none: a task-less instance
    runs once in every cycle, after every due task.
    """
    @enforce_keys [:name, :type]
    defstruct [:name, :type, task: nil, line: nil]

    @type t :: %__MODULE__{
            name: String.t(),
            type: String.t(),
            task: String.t() | nil,
            line: pos_integer | nil
          }
  end

  defmodule Connection do
    @moduledoc """
    A connection: `member`, a var_input or var_output of the program instance `instance`,
    connected `to` a global, by name, or, for a var_input, a constant. It carries no
    direction: the member's section gives it. A var_input is copied in from it before
    each scan of the instance, and a var_output copied out to it after.
    """
    @enforce_keys [:instance, :member, :to]
    defstruct [:instance, :member, :to, line: nil]

    @type t :: %__MODULE__{
            instance: String.t(),
            member: String.t(),
            to: String.t() | non_neg_integer,
            line: pos_integer | nil
          }
  end

  @fields [:name, :programs, :tasks, :globals, :instances, :connections]
  @interval 1..2_147_483_647
  @priority 0..65_535
  @parts [:tasks, :globals, :instances, :connections]
  # M5-10: the reals, whose globals take a float initial value too.
  @reals Logex.Declarations.reals()
  @elements [Logex.Configuration.Task, Global, Instance, Connection]
  @lines ": a configuration's lines are all nil, as from Elixir, or rise in each list, " <>
           "one element a line"

  @doc """
  A configuration built from Elixir: `name:`, which it needs, `programs:` (a list of
  `%Logex.Program{}`), `tasks:`, `globals:`, `instances:` and `connections:`, each a list
  of its element struct with no `line`, the rest optional. Checked by `check/1`: the
  configuration, with its warnings in `warnings`, or one `ArgumentError` with every
  problem, a line each: its own, then the host's mistakes `check/1` raises, then
  `check/1`'s diagnostics, formatted. Those are the diagnostics of the configuration with
  each mistaken field left out, never read as another value, so one may follow from a
  mistake: a var_input whose one connection the host gave a bad instance or member is also
  not connected.
  """
  def new!(fields) when is_list(fields), do: built(keyword?(fields), fields)

  def new!(other), do: raise(ArgumentError, takes(other))

  defp takes(other),
    do:
      "Logex.Configuration.new!/1 takes a keyword list of " <>
        "name:, programs:, tasks:, globals:, instances: and connections:, got: #{inspect(other)}"

  defp keyword?([]), do: true
  defp keyword?([{key, _} | rest]) when is_atom(key), do: keyword?(rest)
  defp keyword?(_not_keyword), do: false

  defp built(false, fields), do: raise(ArgumentError, takes(fields))

  defp built(true, fields) do
    given = Map.new(fields)
    {programs, problems} = programs_from(Map.get(given, :programs, []))

    {[tasks, globals, instances, connections], lined} =
      Enum.map_reduce(@parts, [], fn part, lined -> unlined(Map.get(given, part, []), lined) end)

    config = %__MODULE__{
      name: Map.get(given, :name),
      programs: programs,
      tasks: tasks,
      globals: globals,
      instances: instances,
      connections: connections
    }

    {mistakes, diagnostics, warnings} = problems(config, [], MapSet.new())

    raised(
      fields(fields) ++
        problems ++
        Enum.reverse(lined) ++ mistakes ++ Enum.map(diagnostics, &Diagnostic.format/1),
      %{config | warnings: warnings}
    )
  end

  # An element from Elixir has no line: a line is where a configuration file declares it,
  # and every message that cites one relies on that. One that brings a line is refused,
  # and checked without it, so the one mistake is one message, and the lines check/1 then
  # sees are all nil. A list that is not a proper one is left whole, for check/1 to refuse.
  defp unlined(list, lined),
    do:
      unlined_list(
        proper(list, &unline/2, {[], lined}, fn _tail, {_items, lined} -> {:improper, lined} end),
        list
      )

  defp unlined_list({:improper, lined}, list), do: {list, lined}
  defp unlined_list({items, lined}, _list), do: {Enum.reverse(items), lined}

  defp unline(%module{} = item, acc) when module in @elements,
    do: unline_whole(whole?(item), item, acc)

  defp unline(item, {items, lined}), do: {[item | items], lined}

  defp unline_whole(true, %{line: line} = item, {items, lined}) when line != nil,
    do:
      {[%{item | line: nil} | items],
       ["#{describe(item)} from Elixir has no line, got: #{inspect(line)}" | lined]}

  defp unline_whole(_whole, item, {items, lined}), do: {[item | items], lined}

  defp raised([], config), do: config
  defp raised(problems, _config), do: raise(ArgumentError, Enum.join(problems, "\n"))

  # Each field once, and none but the six.
  defp fields(fields) do
    keys = Keyword.keys(fields)

    for(key <- Enum.uniq(keys), key not in @fields, do: unknown_field(key)) ++
      for key <- Enum.uniq(keys -- Enum.uniq(keys)), do: "#{key}: is given twice"
  end

  defp unknown_field(key),
    do:
      "#{inspect(key)} is not a field of a configuration: its fields are " <>
        "name:, programs:, tasks:, globals:, instances: and connections:"

  # The programs, given as a list, keyed by name: a program is named once, and an unnamed
  # one cannot be, since an instance names its type.
  defp programs_from(%Program{name: name} = program) do
    {programs, problems} = programs_from([program])

    {programs,
     [
       "programs: is a list of %Logex.Program{}, as in programs: [motor], " <>
         "got the one program #{label(name)}"
       | problems
     ]}
  end

  defp programs_from(list) do
    {programs, problems} = proper(list, &program_from/2, {%{}, []}, &programs_not_a_list/2)
    {programs, Enum.reverse(problems)}
  end

  defp programs_not_a_list(list, {programs, problems}),
    do:
      {programs,
       [
         "programs: must be a list of %Logex.Program{} from Logex.compile/2, " <>
           "got: #{inspect(list)}"
         | problems
       ]}

  defp program_from(%Program{name: name} = program, {programs, problems}) when is_binary(name),
    do: program_named(Map.has_key?(programs, name), program, {programs, problems})

  # A function block type is kept under its name for check/1 to refuse, so that an
  # instance naming it is not refused again as naming no program: one mistake, one message.
  defp program_from(%FbType{name: name} = type, {programs, problems}) when is_binary(name),
    do: program_named(Map.has_key?(programs, name), type, {programs, problems})

  defp program_from(%Program{name: nil}, {programs, problems}),
    do:
      {programs,
       [
         "a program in a configuration needs a name, as Logex.compile/2 gives it: " <>
           "an instance names its program by it"
         | problems
       ]}

  defp program_from(other, {programs, problems}),
    do:
      {programs,
       ["programs: #{inspect(other)} is not a %Logex.Program{} from Logex.compile/2" | problems]}

  defp program_named(false, %{name: name} = program, {programs, problems}),
    do: {Map.put(programs, name, program), problems}

  defp program_named(true, %{name: name}, {programs, problems}),
    do:
      {programs, ["two programs are named `#{name}`: a configuration has one of each" | problems]}

  # A list walked to its end, a proper one element by element, and anything else, an
  # improper tail included, handed to `other` once: a host's list is never trusted to be
  # proper.
  defp proper([], _each, acc, _other), do: acc
  defp proper([item | rest], each, acc, other), do: proper(rest, each, each.(item, acc), other)
  defp proper(not_a_list, _each, acc, other), do: other.(not_a_list, acc)

  @doc """
  A configuration from a configuration file's text (`.logex`, `docs/organisation.md`
  §4.4): `{:ok, configuration}`, with its warnings in `warnings`, or `{:error,
  diagnostics}` with every mistake in line order, one with no line last. The pure seam:
  `name` is the configuration's, which its text never says, and `programs` are the
  program types its `program` lines may name, a map of each type's name to its
  `%Logex.Program{}`, as in `%{"motor" => motor}`. Nothing here reads a file.

  `source` is read by `Logex.Configuration.Text.read/1`, whose diagnostic for a line it
  cannot read comes first on its line, then checked by `check/1`'s rules, in the same
  words as a configuration from Elixir: what a broken line names is declared by it, so
  nothing that names it is reported again. A lex error stops it and is the only
  diagnostic. A source that is not a binary, a name that is not one, and programs
  `check/1` would refuse are the host's mistakes, raised as one `ArgumentError`, as
  `check/1` raises them: given a name and programs it takes, any source text is a result,
  never a raise.

  Its inverse is `Logex.Configuration.Text.print/1`: a configuration it gives compiles back
  from its printed text to itself, `compile(config.name, Text.print(config),
  config.programs) == {:ok, config}`, each element on its line.
  """
  def compile(name, source, programs) when is_binary(source) do
    {_programs, mistakes} = programs(programs)
    checked(configuration_name(name) ++ mistakes, [])
    {read, rounded} = Text.read_rounded(source)
    with_rounded(compiled(read, name, programs, {nil, [], MapSet.new()}), rounded)
  end

  def compile(_name, source, _programs),
    do:
      raise(
        ArgumentError,
        "Logex.Configuration.compile/3 takes source text as a binary, got: #{inspect(source)}"
      )

  # Decision 227: a configuration that compiles is told each real initial value its line
  # writes with more digits than its global's real keeps, in decision 219's words, at the
  # global's line, in its file, among its warnings by line.
  defp with_rounded({:ok, config}, [_ | _] = rounded) do
    told =
      for {line, spelling, type, held} <- rounded,
          do: %{
            warning(
              line,
              "`#{spelling}` is more precise than #{Declarations.a_type(type)} keeps: it is " <>
                "held as #{held}"
            )
            | file: config.file
          }

    {:ok, %{config | warnings: Enum.sort_by(told ++ config.warnings, &line_order/1)}}
  end

  defp with_rounded(compiled, _rounded), do: compiled

  @doc """
  A configuration from its configuration file on disk (`.logex`, decision 35), its program
  types loaded from beside it (`docs/organisation.md` §4.4, "Loading"): `{:ok,
  configuration}` or `{:error, diagnostics}`, as `compile/3` gives them. The
  configuration is named after the file, `plant.logex` being `plant`, its `file` is
  `path`, and every diagnostic its text gives carries `path` too.

  Each program type a `program` line names, `motor`, is `motor.ld` beside the file,
  compiled by `Logex.compile_files/1` in the order the types are first named: one memo for
  the configuration, so a function block several program types hold is read and compiled
  once, and its warnings are handed back once, by the first program type that holds it and
  compiles. A program type's warnings stay in its program, the configuration's own in its `warnings`.
  A name on a `program` line that gives no program type is cited once, at the line of
  its first instance, and no instance of it is reported again:

  - with no `motor.ld` beside the file, it is an unknown program type, with a
    did-you-mean among the `.ld` files beside it;
  - a function block's file gets the one message for a block type where a program goes
    (`Logex.Declarations.not_a_program/1`);
  - a file that does not compile is cited by name, with the files its mistakes are cited
    in, the blocks it holds among them, and those diagnostics, each with its file and
    line, follow the configuration's, a type's in the order the types are named, each
    once, though several types hold the block it is in.

  A path that is not a `.logex` file, one named only `.logex`, a file that cannot be
  read, or a name that cannot name a configuration is a `:file` diagnostic, and only after
  a refused name is the file still compiled, so that its own mistakes are listed too. A
  path that is not a binary is the host's mistake, raised as `ArgumentError`.
  """
  def compile_file(path) when is_binary(path),
    do: configuration_file(Path.extname(path), Path.basename(path), path)

  def compile_file(path),
    do:
      raise(
        ArgumentError,
        "Logex.Configuration.compile_file/1 takes a path as a binary, got: #{inspect(path)}"
      )

  # The extension says what a file is (decision 35), and a file named only `.logex` reads
  # as logex's own settings, which no configuration is.
  defp configuration_file(".logex", _basename, path), do: source_file(File.read(path), path)

  defp configuration_file("", ".logex", path),
    do:
      {:error,
       [
         file_problem(
           path,
           "`.logex` names no configuration: a configuration file is named after its " <>
             "configuration, as `plant.logex` is `plant`"
         )
       ]}

  defp configuration_file(_extension, basename, path),
    do:
      {:error,
       [
         file_problem(
           path,
           "`#{basename}` is not a configuration file: Logex.Configuration.compile_file/1 " <>
             "loads a configuration from its `.logex` file"
         )
       ]}

  defp source_file({:error, reason}, path),
    do: {:error, [file_problem(path, "cannot be read: #{:file.format_error(reason)}")]}

  defp source_file({:ok, source}, path) do
    name = Path.rootname(Path.basename(path))
    named_file(configuration_name(name), name, source, path)
  end

  defp named_file([], name, source, path), do: loaded_file(name, source, path)

  # A refused name is the file's, not the host's: the source is still compiled, under a
  # name that is one, so its own mistakes follow the name's.
  defp named_file([problem], _name, source, path),
    do:
      {:error,
       [
         file_problem(path, problem <> " (rename the file)")
         | mistakes_of(loaded_file("configuration", source, path))
       ]}

  defp mistakes_of({:ok, _config}), do: []
  defp mistakes_of({:error, diagnostics}), do: diagnostics

  defp file_problem(path, message),
    do: %Diagnostic{stage: :file, line: nil, message: message, file: path}

  # The program types the `program` lines name, each loaded once from beside the file,
  # through one memo, and what is cited at the line of each one's first instance.
  defp loaded_file(name, source, path) do
    {read, rounded} = Text.read_rounded(source)
    types = program_types(read)
    file = &Path.join(Path.dirname(path), &1 <> ".ld")
    {found, missing} = Enum.split_with(types, fn {type, _line} -> File.exists?(file.(type)) end)
    results = Logex.compile_files(Enum.map(found, fn {type, _line} -> file.(type) end))

    {programs, cited, theirs} =
      found
      |> Enum.zip(results)
      |> Enum.reduce({%{}, [], []}, &type_loaded/2)

    beside = beside(File.ls(Path.dirname(path)))
    absent = Enum.map(missing, &absent(&1, Path.basename(path), beside))

    uncited =
      for {type, _line} <- types, not Map.has_key?(programs, type), into: MapSet.new(), do: type

    loaded = {path, Enum.reverse(cited, absent), uncited}

    with_theirs(
      with_rounded(compiled(read, name, programs, loaded), rounded),
      Enum.reverse(theirs)
    )
  end

  # Each type a `program` line names that could be a file's, once, at its first line: one
  # that is no name, or a keyword, is check/1's to refuse, and is not looked for.
  defp program_types({:ok, entries}), do: program_types({:error, [], entries})

  defp program_types({:error, _diagnostics, entries}),
    do:
      for(
        %Instance{type: type, line: line} <- entries,
        Declarations.name?(type) and not reserved?(type),
        do: {type, line}
      )
      |> Enum.uniq_by(&elem(&1, 0))

  defp type_loaded({{type, _line}, {:ok, %Program{} = program}}, {programs, cited, theirs}),
    do: {Map.put(programs, type, program), cited, theirs}

  defp type_loaded({{type, line}, {:ok, %FbType{} = block}}, {programs, cited, theirs}),
    do:
      {programs, [diagnostic(line, "`#{type}` is " <> Declarations.not_a_program(block)) | cited],
       theirs}

  # The type's mistakes may be in the blocks it holds, so the files named are those they
  # are cited in, in the order they come.
  defp type_loaded({{type, line}, {:error, diagnostics}}, {programs, cited, theirs}) do
    files = for %Diagnostic{file: file} <- diagnostics, is_binary(file), uniq: true, do: file

    message =
      "program type `#{type}` does not compile: its mistakes follow, cited in " <>
        listed(Enum.map(files, &Path.basename/1))

    {programs, [diagnostic(line, message) | cited], Enum.reverse(diagnostics, theirs)}
  end

  # The program types a did-you-mean may offer: the `.ld` files beside the configuration.
  defp beside({:ok, files}),
    do: for(file <- files, Path.extname(file) == ".ld", do: Path.rootname(file))

  defp beside({:error, _reason}), do: []

  defp absent({type, line}, beside, names),
    do:
      diagnostic(
        line,
        "unknown program type `#{type}`: there is no `#{type}.ld` beside `#{beside}`" <>
          Declarations.suggest(type, Enum.sort(names), & &1, "program types")
      )

  # A block several program types hold gives each the same mistakes: each is listed once.
  defp with_theirs({:error, diagnostics}, theirs),
    do: {:error, diagnostics ++ Enum.uniq(theirs)}

  defp with_theirs({:ok, _config} = compiled, []), do: compiled

  # `loaded` is what compile_file/1 adds: the file, the diagnostics its loader cites at
  # `program` lines, and the program types they cite, whose instances are not reported
  # again. compile/3 adds nothing.
  defp compiled({:error, [%Diagnostic{stage: :lex}] = lexed, []}, _name, _programs, {file, _, _}),
    do: {:error, Enum.map(lexed, &%{&1 | file: file})}

  defp compiled({:ok, entries}, name, programs, loaded),
    do: read_in(entries, [], name, programs, loaded)

  defp compiled({:error, unread, entries}, name, programs, loaded),
    do: read_in(entries, unread, name, programs, loaded)

  # The elements a text reads, and what its broken lines declare, checked as one.
  defp read_in(entries, unread, name, programs, {file, cited, types}) do
    {declared, elements} = Enum.split_with(entries, &match?({:declared, _line, _named}, &1))
    unread = Enum.map(unread ++ cited, &%{&1 | file: file})

    config = %__MODULE__{
      name: name,
      file: file,
      programs: programs,
      tasks: for(%Logex.Configuration.Task{} = task <- elements, do: task),
      globals: for(%Global{} = global <- elements, do: global),
      instances: for(%Instance{} = instance <- elements, do: instance),
      connections: for(%Connection{} = connection <- elements, do: connection)
    }

    {mistakes, diagnostics, warnings} = problems(config, declared, types)

    read_back(
      checked(mistakes, Enum.sort_by(unread ++ diagnostics, &line_order/1)),
      config,
      warnings
    )
  end

  defp read_back([], config, warnings), do: {:ok, %{config | warnings: warnings}}
  defp read_back(diagnostics, _config, _warnings), do: {:error, diagnostics}

  @doc """
  The one validator: every problem with `config`, a `%Logex.Diagnostic{}` at stage
  `:configure` each, cited at its element's line in the configuration's `file`, in line
  order, a problem with no line last. `[]` for a configuration that runs, whatever its
  warnings, which are no problem: `new!/1` and `compile/3` give them.

  A configuration no configuration text can say, the host's mistake, raises one
  `ArgumentError` instead, each such mistake a line of its message (decision 36; the
  moduledoc lists them).
  """
  def check(config), do: checking(is_struct(config, __MODULE__) and whole?(config), config)

  defp checking(true, config) do
    {mistakes, diagnostics, _warnings} = problems(config, [], MapSet.new())
    checked(mistakes, diagnostics)
  end

  defp checking(false, other),
    do: raise(ArgumentError, "expected a %Logex.Configuration{}, got: #{inspect(other)}")

  defp checked([], diagnostics), do: diagnostics
  defp checked(mistakes, _diagnostics), do: raise(ArgumentError, Enum.join(mistakes, "\n"))

  # Every problem with a configuration, of two kinds, and its warnings: the host's
  # mistakes, which no configuration text can make, each a line of an ArgumentError's
  # message; the diagnostics, each a mistake a text could make too; and the warnings,
  # which stop nothing. A field that is a host's mistake is left out of every diagnostic,
  # never reported twice, and never read as another value: a bad name is not recovered, as
  # on a `.ld` declaration line. So new!/1, which gives both kinds, may follow a mistake
  # with a diagnostic of what is then missing: a var_input whose one connection names its
  # instance as an atom is not connected, and an instance whose task is named by an atom
  # names no task. check/1 raises the mistakes alone. `declared` are what a configuration
  # file's broken lines name, which only compile/3 gives, and `cited` the program types
  # compile_file/1's loader cited at a `program` line, whose instances are not reported
  # again.
  defp problems(config, declared, cited) do
    {file, m_file} = file(config.file)
    {programs, m_programs} = programs(config.programs)

    {[tasks, globals, instances, connections], {lined, m_parts}} =
      Enum.map_reduce(@parts, {[], []}, fn part, {lined, mistakes} ->
        {items, good, more} = elements(Map.fetch!(config, part), part)
        {items, {[good | lined], [more | mistakes]}}
      end)

    mistakes =
      m_file ++
        configuration_name(config.name) ++
        m_programs ++ Enum.concat(Enum.reverse(m_parts)) ++ lines(Enum.reverse(lined))

    {diagnostics, warnings} =
      diagnostics(
        config,
        {file, programs, cited},
        {tasks, globals, instances, connections},
        declared
      )

    {mistakes, diagnostics, warnings}
  end

  # An element whose name no text can say is the host's mistake, and stays out of every
  # diagnostic. One whose name is refused here, a duplicate, a case twin, a name with `.`
  # parts or a keyword, has every other field checked, as a `.ld` declaration line does:
  # only its name is not kept. What a configuration file's broken line names, a
  # placeholder from Logex.Configuration.Text.read/1, takes its name as an element does,
  # and nothing that names it is reported again; a broken connection connects its
  # var_input.
  defp diagnostics(config, {file, programs, cited}, parts, declared) do
    {tasks, globals, instances, connections} = parts
    {wired, named} = Enum.split_with(declared, &match?({:declared, _, %{kind: :connection}}, &1))
    [tasks, globals, instances] = Enum.map([tasks, globals, instances], &worded/1)
    space = namespace(tasks, globals, instances, Enum.reject(named, &unnamed?/1))
    {points, d_points} = located(globals, space.kept)
    world = world(space, points, programs)
    {wiring, d_wiring} = wiring(Enum.sort_by(connections, &line_key/1), world, wired)
    externals = externals(instances, world)
    {d_tasks, triggers} = tasks(tasks, world)

    diagnostics =
      [
        space.problems,
        d_tasks,
        Enum.flat_map(globals, &global/1),
        d_points,
        runs(instances, {programs, MapSet.union(given(config.programs), cited)}, world),
        d_wiring,
        externals.diagnostics,
        unconnected(instances, space.kept, world, wiring.inputs),
        empty(config.instances, named)
      ]
      |> Enum.concat()
      |> Enum.sort_by(&line_order/1)
      |> Enum.map_reduce(MapSet.new(), &listed_once/2)
      |> elem(0)

    {Enum.map(diagnostics, &%{&1 | file: file}),
     Enum.map(
       warnings({tasks, globals, instances}, wiring, externals, triggers) ++ timed(world),
       &%{&1 | file: file}
     )
     |> Enum.sort_by(&line_order/1)}
  end

  # Each list of names a diagnostic would end with is given once, by the first diagnostic
  # in line order that needs it, so that n instances of unknown program types among n
  # types make n short diagnostics, not n lists of n names. A diagnostic that needs a list holds
  # `{message, key, list}` until here, `key` naming the list and `list` making it.
  defp listed_once(%Diagnostic{message: {message, key, list}} = d, listed),
    do: once_listed(MapSet.member?(listed, key), d, message, {key, list}, listed)

  defp listed_once(diagnostic, listed), do: {diagnostic, listed}

  defp once_listed(false, d, message, {key, list}, listed),
    do: {%{d | message: message <> list.()}, MapSet.put(listed, key)}

  defp once_listed(true, d, message, _list, listed), do: {%{d | message: message}, listed}

  # The file every diagnostic is cited in: a name, or nil for a configuration built from
  # Elixir.
  defp file(file) when is_binary(file) or file == nil, do: {file, []}

  defp file(other),
    do:
      {nil,
       [
         "a configuration's file is a file name, or nil for one built from Elixir, " <>
           "got: #{inspect(other)}"
       ]}

  defp line_order(%Diagnostic{line: nil}), do: {1, 0}
  defp line_order(%Diagnostic{line: line}), do: {0, line}

  defp diagnostic(line, message),
    do: %Diagnostic{stage: :configure, line: line, message: message}

  # A configuration is named, as IEC's CONFIGURATION is: what a later runner reports the
  # resource by. Its text never names it (a reader takes the name from its caller, or a
  # file's name), so a bad one is always the host's.
  defp configuration_name(nil), do: [~s|a configuration needs a name, as in name: "plant"|]
  defp configuration_name(name), do: shaped(Declarations.name?(name), name, "a configuration")

  defp shaped(true, _name, _what), do: []
  defp shaped(false, name, what), do: ["#{inspect(name)} cannot name #{what}: " <> rule()]

  defp rule, do: "a name is a letter or `_`, then letters, digits or `_`"

  # The names under which programs were given, good or not.
  defp given(programs) when is_map(programs) and not is_struct(programs),
    do: MapSet.new(Map.keys(programs))

  defp given(programs) when is_list(programs),
    do: proper(programs, &given_name/2, MapSet.new(), fn _tail, names -> names end)

  defp given(_programs), do: MapSet.new()

  defp given_name(%Program{name: name}, names), do: MapSet.put(names, name)
  defp given_name(_other, names), do: names

  # The programs a configuration may run, by name, and the host's mistakes in the rest:
  # no text gives a program, which a host compiles and hands over.
  defp programs(programs) when is_map(programs) and not is_struct(programs) do
    {ok, mistakes} =
      Enum.reduce(Enum.sort(programs), {%{}, []}, fn {key, value}, {ok, mistakes} ->
        program(key, value, ok, mistakes)
      end)

    {ok, Enum.reverse(mistakes)}
  end

  defp programs(list) when is_list(list),
    do:
      {%{},
       [
         "programs must be a map of program names to %Logex.Program{}, got a list: " <>
           "Logex.Configuration.new!/1 takes a list and keys it by name"
       ]}

  defp programs(other),
    do:
      {%{},
       ["programs must be a map of program names to %Logex.Program{}, got: #{inspect(other)}"]}

  defp program(name, %Program{name: name, tags: tags, rungs: rungs} = program, ok, mistakes)
       when is_binary(name) and is_map(tags) and is_list(rungs),
       do: program_shaped(Declarations.name?(name), program, ok, mistakes)

  defp program(key, %Program{name: name, tags: tags, rungs: rungs}, ok, mistakes)
       when is_map(tags) and is_list(rungs),
       do: {ok, ["the program under #{label(key)} is named #{label(name)}" | mistakes]}

  defp program(key, %FbType{name: name} = type, ok, mistakes),
    do: {ok, [block_type(key, name, type) | mistakes]}

  defp program(key, other, ok, mistakes),
    do:
      {ok,
       [
         "the program under #{label(key)} is not a %Logex.Program{} from " <>
           "Logex.compile/2, got: #{inspect(other)}"
         | mistakes
       ]}

  # A function block type runs inside a program, never as one: the one message of every
  # entry point (Logex.Declarations.not_a_program/1), with the key where it differs.
  defp block_type(name, name, type), do: "#{label(name)} is " <> Declarations.not_a_program(type)

  defp block_type(key, name, type),
    do: "the program under #{label(key)} is #{label(name)}, " <> Declarations.not_a_program(type)

  defp program_shaped(true, %Program{} = program, ok, mistakes),
    do:
      program_held(ports_held(program) ++ Program.edited_by_hand(program), program, ok, mistakes)

  defp program_shaped(false, %Program{name: name}, ok, mistakes),
    do: {ok, Enum.reverse(shaped(false, name, "a program"), mistakes)}

  # Decision 169: no text declares a var_input or var_output that holds an instance
  # (Logex.Declarations refuses `var_input t ton`, from source and from Elixir), so a
  # compiled program whose own does was edited by hand after it compiled: the host's
  # mistake, a line for each such tag in name order, and the program is left out of every
  # diagnostic, as a misnamed one is. Since decision 182 so is one whose arithmetic
  # computes in a destination with no integer type, and since decision 197 one whose
  # units its tags do not give, a line each after them, in the words every entry point
  # that takes a program gives (`Logex.Program.edited_by_hand/1`).
  defp program_held([], %Program{name: name} = program, ok, mistakes),
    do: {Map.put(ok, name, program), mistakes}

  defp program_held(lines, _program, ok, mistakes), do: {ok, Enum.reverse(lines, mistakes)}

  defp ports_held(%Program{name: name, tags: tags}),
    do:
      for(
        {tag, %Tag{section: section, type: type}} <- Enum.sort(tags),
        section in [:var_input, :var_output],
        word = held_word(type),
        do:
          "`#{name}`'s #{section} `#{tag}` holds #{word}, which no text declares: an " <>
            "instance is the program's own, declared with `var`, so `#{name}` was edited by " <>
            "hand after it compiled"
      )

  defp held_word(%FbType{name: name} = type) when is_binary(name),
    do: Declarations.instance_of(type)

  defp held_word({:block, name}) when is_binary(name), do: "an instance of `#{name}`"
  defp held_word(_elementary_or_junk), do: nil

  # A part's elements: every one that is its struct, a bad line cleared; those whose line
  # is good, for the rule over lines; and the host's mistakes, each a line.
  defp elements(list, part) do
    module = module(part)

    {items, good, mistakes} =
      proper(list, &element(&1, &2, module), {[], [], []}, fn _tail, {items, good, mistakes} ->
        {items, good,
         ["#{part} must be a list of %#{inspect(module)}{}, got: #{inspect(list)}" | mistakes]}
      end)

    {Enum.reverse(items), Enum.reverse(good), Enum.reverse(mistakes)}
  end

  defp module(:tasks), do: Logex.Configuration.Task
  defp module(:globals), do: Global
  defp module(:instances), do: Instance
  defp module(:connections), do: Connection

  defp element(item, acc, module),
    do: element_of(is_struct(item, module) and whole?(item), item, acc, module)

  defp element_of(true, item, acc, _module), do: line(item, acc)

  defp element_of(false, other, {items, good, mistakes}, module),
    do:
      {items, good,
       ["#{one(module)} is a %#{inspect(module)}{}, got: #{inspect(other)}" | mistakes]}

  # A struct with every key its module gives it. A map that names the struct but lacks a
  # key, as Map.delete/2 makes one, is not that struct: nothing here reads it, so no
  # KeyError or FunctionClauseError escapes.
  defp whole?(%{__struct__: module} = item),
    do: Map.keys(module.__struct__()) -- Map.keys(item) == []

  defp one(Logex.Configuration.Task), do: "a task"
  defp one(Global), do: "a global"
  defp one(Instance), do: "an instance"
  defp one(Connection), do: "a connection"

  defp line(%{line: line} = item, {items, good, mistakes})
       when line == nil or (is_integer(line) and line > 0),
       do: {[item | items], [item | good], Enum.reverse(said(item), mistakes)}

  defp line(%{line: line} = item, {items, good, mistakes}),
    do:
      {[%{item | line: nil} | items], good,
       Enum.reverse(
         [
           "#{describe(item)} has line #{inspect(line)}: a line is a positive integer, " <>
             "or nil for one built from Elixir"
           | said(item)
         ],
         mistakes
       )}

  # What no configuration text can say in an element's fields: a name, a type, a task or
  # a location that is not one name token to the lexer; a number that is not an integer,
  # a negative one among those a line can say since M3-3; a global's type that is neither
  # :bool nor :dint, the type words a line has; and a connection's instance that is not a
  # name, or with its member no one path, as a line writes the two as one token. Each
  # such field is left out of the diagnostics.
  defp said(%Logex.Configuration.Task{name: name} = task),
    do:
      named(task) ++
        trigger_word(task.single, name) ++
        counted(task.interval, interval_rule(name)) ++
        counted(task.priority, priority_rule(name)) ++
        counted(task.watchdog, watchdog_rule(name)) ++ flag(task.continuous, name)

  defp said(%Global{} = global),
    do: named(global) ++ global_type(global) ++ global_initial(global) ++ global_at(global)

  defp said(%Instance{type: type, task: task} = instance),
    do:
      named(instance) ++
        of_word(
          word?(type),
          "#{describe(instance)}: its type is a program's name, found #{inspect(type)}"
        ) ++
        instance_task(task, instance)

  defp said(%Connection{} = connection),
    do:
      of_word(ends?(connection), ends_rule(connection)) ++
        of_word(other_end(connection.to) != :junk, other_end_rule(connection))

  defp named(%{name: name} = element), do: of_word(word?(name), cannot_name(element))

  defp of_word(true, _message), do: []
  defp of_word(false, message), do: [message]

  defp cannot_name(element),
    do: "#{inspect(element.name)} cannot name a #{kind(element)}: " <> rule()

  # A task's `single` (M2-6) names a global, as one name token, or is nil for none.
  defp trigger_word(nil, _name), do: []

  defp trigger_word(single, name),
    do:
      of_word(
        word?(single),
        "task #{label(name)}: a single is a bool global's name, or nil for none, " <>
          "found #{inspect(single)}"
      )

  defp counted(value, _rule) when value == nil or is_integer(value), do: []
  defp counted(value, rule), do: [rule <> ", found #{inspect(value)}"]

  defp interval_rule(name), do: "task #{label(name)}: an interval is 1 to 2147483647 ms"
  defp watchdog_rule(name), do: "task #{label(name)}: a watchdog is 1 to 2147483647 ms"

  # M4-2: a task is the continuous task or not, which a line says by a word or its
  # absence, so anything but a boolean is the host's.
  defp flag(continuous, _name) when is_boolean(continuous), do: []

  defp flag(continuous, name),
    do: ["task #{label(name)}: continuous is true or false, found #{inspect(continuous)}"]

  defp priority_rule(name), do: "task #{label(name)}: a priority is 0, the highest, to 65535"

  defp global_type(%Global{type: type}) when is_elementary(type), do: []

  # M5-11 (decision 151): an array of an elementary type, its sizes any integers a line can
  # say, which check/1 judges as a declaration's, a line's diagnostic.
  defp global_type(%Global{type: {:array, type, [_ | _] = dims}} = global)
       when is_elementary(type),
       do: sizes_said(Enum.all?(proper_or_not(dims), &is_integer/1), global)

  defp global_type(global), do: sizes_said(false, global)

  defp sizes_said(true, _global), do: []

  defp sizes_said(false, %Global{name: name, type: type}),
    do: [
      "global #{label(name)} has type #{inspect(type)}: a global is " <>
        Declarations.either(&inspect/1) <>
        ", or an array of one of them, as in `{:array, :int, [8]}`, its sizes a list of " <>
        "one integer a dimension"
    ]

  defp proper_or_not(list), do: proper_elements(list, [])

  defp proper_elements([], acc), do: acc
  defp proper_elements([element | rest], acc), do: proper_elements(rest, [element | acc])
  defp proper_elements(_improper, _acc), do: [:improper]

  defp global_initial(%Global{initial: nil}), do: []

  # M5-11 (decision 151): an array global's initial value is a list of its elements' values,
  # each an integer, or a real's a number, whose length and each value check/1 judges.
  defp global_initial(%Global{type: {:array, type, _dims}, initial: initial} = global)
       when is_list(initial),
       do: array_initial(Enum.all?(proper_or_not(initial), &element_said?(type, &1)), global)

  defp global_initial(%Global{name: name, type: {:array, _type, _dims}, initial: initial}),
    do: [
      "the initial value of global #{label(name)}, an array, must be a list of its " <>
        "elements' values, found #{inspect(initial)}"
    ]

  defp global_initial(%Global{initial: initial}) when is_integer(initial),
    do: []

  # M5-10: a real global's initial value may be a float, as its line's real literal is.
  defp global_initial(%Global{type: type, initial: initial})
       when type in @reals and is_float(initial),
       do: []

  defp global_initial(%Global{name: name, type: type, initial: initial}) when type in @reals,
    do: [
      "the initial value of global #{label(name)} must be a number, found #{inspect(initial)}"
    ]

  defp global_initial(%Global{name: name, initial: initial}),
    do: [
      "the initial value of global #{label(name)} must be an integer, found #{inspect(initial)}"
    ]

  defp array_initial(true, _global), do: []

  defp array_initial(false, %Global{name: name, type: {:array, type, _dims}, initial: initial}),
    do: [
      "the initial value of global #{label(name)}, an array of #{Declarations.word(type)}s, " <>
        "must be a list of its elements' values, each #{element_value(type)}, found " <>
        inspect(initial)
    ]

  defp element_said?(type, value) when type in @reals, do: is_number(value)
  defp element_said?(_type, value), do: is_integer(value)

  defp element_value(type) when type in @reals, do: "a number"
  defp element_value(_type), do: "an integer"

  defp global_at(%Global{at: nil}), do: []
  defp global_at(%Global{at: at} = global), do: of_word(word?(at), not_a_location(global))

  defp not_a_location(global),
    do:
      "global #{label(global.name)} is at #{label(global.at)}, which is not a location: " <>
        "a location is a device, `i` for an input or `q` for an output, then an " <>
        "address, as in `panel.i.0` or `panel.q.3`"

  defp instance_task(nil, _instance), do: []

  defp instance_task(task, instance),
    do:
      of_word(
        word?(task),
        "#{describe(instance)}: its task is a task's name, or nil for none, found #{inspect(task)}"
      )

  # A connection's line writes its instance and member as one path, `m1.start`, whose
  # first `.` ends the instance.
  defp ends?(%Connection{instance: instance, member: member}),
    do: Declarations.name?(instance) and is_binary(member) and word?(instance <> "." <> member)

  defp ends_rule(%Connection{instance: instance, member: member}),
    do:
      "a connection's instance is a name, and with its member makes one path, as in " <>
        "`m1.start`, found #{inspect(instance)} and #{inspect(member)}"

  defp other_end_rule(%Connection{instance: instance, member: member, to: to}),
    do:
      "#{path(instance, member)} is connected to #{inspect(to)}: a connection's other end is " <>
        "a global, by name, or a constant"

  # What a connection's other end is: a global's name, a constant, or the host's mistake.
  defp other_end(to) when is_integer(to) or is_float(to), do: :constant
  defp other_end(to), do: global_or_junk(word?(to))

  defp global_or_junk(true), do: :global
  defp global_or_junk(false), do: :junk

  # What the lexer reads as one name token, a name or a name with `.` parts: every name a
  # configuration's line holds is one.
  defp word?(word) when is_binary(word), do: one_word(Logex.Lexer.tokenize(word), word)
  defp word?(_word), do: false

  defp one_word({:ok, [{:name, _, word}], _}, word), do: true
  defp one_word(_lexed, _word), do: false

  # The rule over lines, for the elements whose own line is good: all nil, as from
  # Elixir, or each list in rising lines and no line holding two elements, as a file's.
  defp lines(parts) do
    {unlined, lined} = Enum.split_with(Enum.concat(parts), &(&1.line == nil))
    mixed(unlined, lined) ++ Enum.flat_map(parts, &rising/1) ++ shared(parts)
  end

  defp mixed([], _lined), do: []
  defp mixed(_unlined, []), do: []

  defp mixed(unlined, [first | _]),
    do:
      for(
        item <- unlined,
        do:
          "#{describe(item)} has no line, beside #{describe(first)} on line #{first.line}" <>
            @lines
      )

  defp rising(part) do
    part
    |> Enum.reject(&(&1.line == nil))
    |> Enum.chunk_every(2, 1, :discard)
    |> Enum.flat_map(fn [before, item] -> follows(item.line > before.line, before, item) end)
  end

  defp follows(true, _before, _item), do: []

  defp follows(false, before, item),
    do: [
      "#{describe(item)} is on line #{item.line}, but follows #{describe(before)}, on line " <>
        "#{before.line}" <> @lines
    ]

  # A line two lists share. Two of one list are rising/1's to refuse.
  defp shared(parts) do
    {_held, mistakes} =
      parts
      |> Enum.with_index()
      |> Enum.flat_map(fn {part, index} ->
        for item <- part, item.line != nil, do: {item, index}
      end)
      |> Enum.reduce({%{}, []}, fn {item, index}, {held, mistakes} ->
        held_by(Map.get(held, item.line), {item, index}, {held, mistakes})
      end)

    Enum.reverse(mistakes)
  end

  defp held_by(nil, {item, _index} = holder, {held, mistakes}),
    do: {Map.put(held, item.line, holder), mistakes}

  defp held_by({_first, index}, {_item, index}, acc), do: acc

  defp held_by({first, _index}, {item, _other}, {held, mistakes}),
    do:
      {held,
       [
         "#{describe(item)} is on line #{item.line}, as #{describe(first)} is" <> @lines
         | mistakes
       ]}

  defp describe(%Logex.Configuration.Task{name: name}), do: "task #{label(name)}"
  defp describe(%Global{name: name}), do: "global #{label(name)}"
  defp describe(%Instance{name: name}), do: "program instance #{label(name)}"

  defp describe(%Connection{instance: instance, member: member}),
    do: "the connection of #{path(instance, member)}"

  defp label(name) when is_binary(name), do: "`#{name}`"
  defp label(name), do: inspect(name)

  defp path(instance, member) when is_binary(instance) and is_binary(member),
    do: "`#{instance}.#{member}`"

  defp path(instance, member), do: "#{inspect(instance)}.#{inspect(member)}"

  defp where(%{line: nil}), do: ""
  defp where(%{line: line}), do: " (line #{line})"

  defp kind(%Logex.Configuration.Task{}), do: "task"
  defp kind(%Global{}), do: "global"
  defp kind(%Instance{}), do: "program instance"

  # The elements whose name the lexer reads as one token: any other name is the host's
  # mistake, refused already.
  defp worded(elements), do: Enum.filter(elements, &word?(&1.name))

  # One namespace for tasks, globals and program instances (decided here, not in IEC), and
  # for the names a configuration file's broken lines declare: the first to take a name
  # keeps it, in line order, and a case-only twin is refused as tags' are, since a name
  # differing only in case would be read as the same one. A program type is named in type
  # position only, so `program motor motor` is not a clash. A name with `.` parts, which a
  # line can hold, or a configuration file's keyword, in any case, names nothing: it is
  # refused once, and nothing that names it is reported again (decision 42), as nothing
  # that names a broken line's name is. A duplicate or a twin is not recovered so: a use of
  # its name finds the element that kept it, as on a `.ld` declaration line.
  #
  # `names` holds each name kept, `{kind, line, element}`, a placeholder's element
  # `:declared`; `silent` the names whose uses are not reported; `kept` each element that
  # keeps its name, as `{kind, index in its list}`, since two elements may be equal.
  defp namespace(tasks, globals, instances, declared) do
    {names, _folded, silent, kept, problems} =
      [
        Enum.with_index(tasks, &{{:task, &2}, &1}),
        Enum.with_index(globals, &{{:global, &2}, &1}),
        Enum.with_index(instances, &{{:instance, &2}, &1}),
        Enum.map(declared, &{:declared, &1})
      ]
      |> Enum.concat()
      |> Enum.sort_by(fn {_ref, element} -> line_key(element) end)
      |> Enum.reduce({%{}, %{}, MapSet.new(), MapSet.new(), []}, &take_name/2)

    %{names: names, silent: silent, kept: kept, problems: Enum.reverse(problems)}
  end

  # A placeholder for a `program` line broken before its name takes no name.
  defp unnamed?({:declared, _line, %{name: nil}}), do: true
  defp unnamed?(_placeholder), do: false

  defp line_key({:declared, line, _named}), do: {0, line}
  defp line_key(%{line: nil}), do: {1, 0}
  defp line_key(%{line: line}), do: {0, line}

  defp take_name({ref, element}, acc) do
    {kind, name, line} = held(element)
    refusal = refusal(String.contains?(name, [".", "["]), reserved?(name), name, kind)
    take(refusal, {ref, kind, name, line, stored(ref, element)}, acc)
  end

  defp stored(:declared, _placeholder), do: :declared
  defp stored(_ref, element), do: element

  defp held(%Logex.Configuration.Task{name: name, line: line}), do: {:task, name, line}
  defp held(%Global{name: name, line: line}), do: {:global, name, line}
  defp held(%Instance{name: name, line: line}), do: {:instance, name, line}
  defp held({:declared, line, %{kind: kind, name: name}}), do: {kind, name, line}

  # M5-11: brackets are kept for an element's subscripts, `m1.temps[3]`, as in a program.
  defp refusal(true, _reserved, name, kind) when binary_part(name, byte_size(name) - 1, 1) == "]",
    do:
      "`#{name}` cannot name #{a(kind)}: brackets are kept for an element's subscripts, as " <>
        "in `m1.temps[3]`"

  defp refusal(true, _reserved, name, kind),
    do:
      "`#{name}` cannot name #{a(kind)}: `.` is kept for a path, as in `m1.start`, and a " <>
        "location, as in `panel.i.0`"

  defp refusal(false, true, name, kind), do: "`#{name}` is a keyword and cannot name #{a(kind)}"
  defp refusal(false, false, _name, _kind), do: nil

  defp take(nil, {_ref, _kind, name, _line, _element} = held, {_, folded, _, _, _} = acc),
    do: clash(Map.get(folded, String.downcase(name)), held, acc)

  defp take(
         message,
         {_ref, _kind, name, line, _element},
         {names, folded, silent, kept, problems}
       ),
       do: {names, folded, MapSet.put(silent, name), kept, [diagnostic(line, message) | problems]}

  defp clash(
         nil,
         {ref, kind, name, line, element} = held,
         {names, folded, silent, kept, problems}
       ) do
    {silent, kept} = keeps(ref, name, silent, kept)
    names = Map.put(names, name, {kind, line, element})
    {names, Map.put(folded, String.downcase(name), held), silent, kept, problems}
  end

  defp clash({_ref, first, name, first_line, _}, {_, _kind, name, line, _}, acc),
    do: refused(acc, line, "`#{name}` is declared twice: " <> first_as(first_line, first))

  defp clash({_ref, first, twin, first_line, _}, {_, _kind, name, line, _}, acc),
    do:
      refused(
        acc,
        line,
        "`#{name}` and `#{twin}`#{at_line(first_line)} differ only in case: names are " <>
          "case-sensitive, so these would be two (`#{twin}` is #{a(first)})"
      )

  defp refused({names, folded, silent, kept, problems}, line, message),
    do: {names, folded, silent, kept, [diagnostic(line, message) | problems]}

  # A placeholder's name is declared by a broken line, reported there: nothing that names
  # it is reported again.
  defp keeps(:declared, name, silent, kept), do: {MapSet.put(silent, name), kept}
  defp keeps(ref, _name, silent, kept), do: {silent, MapSet.put(kept, ref)}

  defp first_as(nil, kind), do: "the first is #{a(kind)}"
  defp first_as(line, kind), do: "first on line #{line}, as #{a(kind)}"

  defp at_line(nil), do: ""
  defp at_line(line), do: " (line #{line})"

  defp a(:task), do: "a task"
  defp a(:global), do: "a global"
  defp a(:instance), do: "an instance"

  # A configuration file's keyword, in any case, which names nothing in one (§4.8).
  defp reserved?(word), do: String.downcase(word) in Text.keywords()

  # Each task's problems, and the globals their triggers use, which M2-2's warning for a
  # global nothing uses counts (M2-6).
  defp tasks(tasks, world) do
    bools = Enum.sort(for {name, {:global, _, %Global{type: :bool}}} <- world.names, do: name)
    indexed = Enum.with_index(tasks)
    first = Enum.find(indexed, &match?({%{continuous: true}, _index}, &1))
    world = Map.merge(world, %{bools: bools, continuous: first})

    {problems, used} =
      Enum.map_reduce(indexed, MapSet.new(), fn task, used -> task_problems(task, used, world) end)

    {Enum.concat(problems), used}
  end

  # M4-2 (decision 111): the continuous task takes none of a timed task's inputs, so none
  # of their rules, and is one at most; every task's watchdog is checked alike. A task
  # whose `continuous` is the host's mistake is read as neither kind.
  defp task_problems({%{continuous: continuous} = task, _index}, used, _world)
       when not is_boolean(continuous),
       do: {watched(task), used}

  defp task_problems({%{continuous: true} = task, index}, used, world),
    do: {second(world.continuous, index, task) ++ untimed(task) ++ watched(task), used}

  defp task_problems({task, _index}, used, world) do
    {problems, triggers} = trigger(task, world)

    {interval(task, world.continuous) ++ priority(task) ++ problems ++ watched(task),
     MapSet.union(used, triggers)}
  end

  # The first continuous task in line order is the configuration's; each after it is told
  # so, as the conventional family's one continuous task is (p.8).
  defp second({_first, index}, index, _task), do: []

  defp second({first, _index}, _other, task),
    do: [
      diagnostic(
        task.line,
        "`#{task.name}` is a second continuous task: a configuration has one at most, and " <>
          "`#{first.name}`#{where(first)} is its continuous task"
      )
    ]

  # A continuous task has no interval, single or priority (decision 111): it runs every
  # instance no timed task runs, at the lowest priority, once each round.
  defp untimed(task) do
    given =
      for {word, value} <- [single: task.single, interval: task.interval, priority: task.priority],
          value != nil,
          do: "`#{word}`"

    untimed_given(given, task)
  end

  defp untimed_given([], _task), do: []

  defp untimed_given(given, task),
    do: [
      diagnostic(
        task.line,
        "`#{task.name}` is the continuous task, which takes no #{or_listed(given)}: it runs " <>
          "every program instance with no timed task, after the due tasks, as in " <>
          "`task #{example(task.name)} continuous watchdog 200`"
      )
    ]

  defp or_listed([one]), do: one
  defp or_listed([one, two]), do: "#{one} or #{two}"
  defp or_listed([one | rest]), do: "#{one}, " <> or_listed(rest)

  # A watchdog a line can hold, an integer or none, is a diagnostic outside 1 to
  # 2147483647 ms, an interval's range (decision 109): every task has one, 500 ms where it
  # sets none, so 0 is no "no watchdog".
  defp watched(%{watchdog: watchdog}) when watchdog == nil or watchdog in @interval, do: []

  defp watched(%{name: name, watchdog: 0, line: line}),
    do: [
      diagnostic(
        line,
        "the watchdog of `#{name}` is 0: a watchdog is at least 1 ms, and a task that sets " <>
          "none has 500"
      )
    ]

  defp watched(%{name: name, watchdog: watchdog, line: line}) when is_integer(watchdog),
    do: [
      diagnostic(
        line,
        "the watchdog of `#{name}` is `#{watchdog}` ms: a watchdog is 1 to 2147483647 ms"
      )
    ]

  defp watched(_task), do: []

  # An interval or a priority a line can hold, an integer or none, is a
  # diagnostic outside its range, in the configuration file's words; anything else was the
  # host's mistake. A task needs an interval, a single or both (M2-6).
  defp interval(%{interval: interval}, _continuous)
       when is_integer(interval) and interval in @interval,
       do: []

  # Its examples name the task only where its name is one a line can declare (§4.10,
  # M2-6), and `t` otherwise. A task with no priority either, where the configuration
  # declares no continuous task, may be meant for it, and is shown it too (M4-2).
  defp interval(%{name: name, single: nil, interval: nil, line: line} = task, continuous),
    do: [
      diagnostic(
        line,
        "task `#{name}` needs an interval or a single, as in " <>
          "`task #{example(name)} interval 10 priority 1` or " <>
          "`task #{example(name)} single estop priority 0`" <>
          or_continuous(task.priority, continuous, name)
      )
    ]

  defp interval(task, _continuous), do: interval(task)

  defp or_continuous(nil, nil, name),
    do: ", or is the continuous task, as in `task #{example(name)} continuous`"

  defp or_continuous(_priority, _continuous, _name), do: ""

  # IEC reads an interval of 0 as no periodic scheduling (rule 2), and MatIEC runs such a
  # task every tick: an instance that runs every cycle has no task (§4.4, "Tasks"), and an
  # event task none at all.
  defp interval(%{name: name, single: single, interval: 0, line: line}) when single != nil,
    do: [
      diagnostic(
        line,
        "the interval of `#{name}` is 0: an interval is at least 1 ms, and a task that " <>
          "runs only on the rising edges of its single is declared without one"
      )
    ]

  defp interval(%{name: name, interval: 0, line: line}),
    do: [
      diagnostic(
        line,
        "the interval of `#{name}` is 0: an interval is at least 1 ms, and an instance " <>
          "that runs every cycle is declared without `with`"
      )
    ]

  defp interval(%{name: name, interval: interval, line: line}) when is_integer(interval),
    do: [
      diagnostic(
        line,
        "the interval of `#{name}` is `#{interval}` ms: an interval is 1 to 2147483647 ms"
      )
    ]

  defp interval(_task), do: []

  defp priority(%{priority: priority}) when is_integer(priority) and priority in @priority,
    do: []

  # Its example is a task of its own kind, named as the interval's examples are, with the
  # task's own single and interval where a line can say them (§4.10, M2-6).
  defp priority(%{name: name, priority: nil, line: line} = task),
    do: [
      diagnostic(
        line,
        "task `#{name}` needs a priority, as in " <>
          "`task #{example(name)}#{shown_kind(task)} priority 1" <>
          "#{shown_watchdog(task.watchdog)}`: 0 is the highest"
      )
    ]

  defp priority(%{name: name, priority: priority, line: line}) when is_integer(priority),
    do: [
      diagnostic(
        line,
        "the priority of `#{name}` is `#{priority}`: a priority is 0 to 65535, and 0 is " <>
          "the highest"
      )
    ]

  defp priority(_task), do: []

  defp example(name), do: example_named(Declarations.name?(name) and not reserved?(name), name)

  defp example_named(true, name), do: name
  defp example_named(false, _name), do: "t"

  # A task's kind, as its line says it: a single, an interval or both; one with neither,
  # told so already, is shown the periodic kind.
  defp shown_kind(%{single: nil, interval: interval}), do: " interval #{shown_interval(interval)}"
  defp shown_kind(%{single: single, interval: nil}), do: " single #{shown_single(single)}"

  defp shown_kind(%{single: single, interval: interval}),
    do: " single #{shown_single(single)} interval #{shown_interval(interval)}"

  # After the priority, the task's own watchdog where a line can say it (M4-2), and none
  # where it has none or one out of range, which is told so already.
  defp shown_watchdog(watchdog) when is_integer(watchdog) and watchdog in @interval,
    do: " watchdog #{watchdog}"

  defp shown_watchdog(_watchdog), do: ""

  defp shown_interval(interval) when is_integer(interval) and interval in @interval, do: interval
  defp shown_interval(_interval), do: 10

  defp shown_single(single) when is_binary(single),
    do: single_named(Declarations.name?(single) and not reserved?(single), single)

  defp shown_single(_single), do: "estop"

  defp single_named(true, single), do: single
  defp single_named(false, _single), do: "estop"

  # A task's single (M2-6) names a bool global, located or not (§4.4, "Events"): a name
  # where a global is wanted, read as a connection reads one (§4.7), the did-you-mean among
  # the bool globals, since a dint is never the fix. A name refused already is silent
  # (decision 42), and one no line can say was the host's mistake. `{problems, used}`: a
  # bool global the single names is used. A dint it names is a diagnostic, and a
  # configuration with one gives no warnings, so whether that counts as a use cannot be
  # seen: it counts none.
  defp trigger(%{single: single} = task, world) when is_binary(single),
    do: trigger_of(word?(single), task, world)

  defp trigger(_task, _world), do: {[], MapSet.new()}

  defp trigger_of(false, _task, _world), do: {[], MapSet.new()}

  defp trigger_of(true, task, world),
    do:
      triggered(
        single_reading(
          MapSet.member?(world.silent, task.single),
          String.contains?(task.single, "."),
          task.single,
          world
        ),
        task
      )

  defp single_reading(true, _dotted, _name, _world), do: :skip
  defp single_reading(false, true, name, world), do: dotted(spelled(name), name, :bool, world)

  defp single_reading(false, false, name, world),
    do: single_held(Map.get(world.names, name), name, world)

  defp single_held(nil, name, world), do: {:error, no_trigger(reserved?(name), name, world)}
  defp single_held(held, name, world), do: global_held(held, name, :bool, world)

  defp no_trigger(true, name, world), do: unnamed(true, :global, name, world, :bool)

  defp no_trigger(false, name, world),
    do: untriggered(String.split(name, "[", parts: 2), name, world)

  defp untriggered([array, _subscripts], name, world),
    do: element_named(Map.get(world.names, array), array, name)

  defp untriggered([_whole], name, world),
    do: declare(Declarations.suggest(name, world.bools, & &1, "names"), :global, name, :bool)

  defp triggered({:ok, %Global{name: name, type: :bool}}, _task), do: {[], MapSet.new([name])}

  # M5-11: an array of bools is no bool, so it is no single either.
  defp triggered({:ok, %Global{name: name, type: type} = global}, task)
       when is_elementary(type) or is_array(type),
       do:
         {[
            diagnostic(
              task.line,
              "the single of `#{task.name}`, `#{name}`, is #{Declarations.a_type(type)}" <>
                "#{where(global)}: a single is a bool global"
            )
          ], MapSet.new()}

  # A global whose type is the host's mistake, refused already.
  defp triggered({:ok, %Global{name: name}}, _task), do: {[], MapSet.new([name])}

  defp triggered({:error, message}, task),
    do: {[diagnostic(task.line, "the single of `#{task.name}`: " <> message)], MapSet.new()}

  defp triggered(:skip, _task), do: {[], MapSet.new()}

  defp global(%Global{type: type} = global) when is_elementary(type),
    do: initial(global, location(global.at))

  # M5-11 (decision 151): an array global meets every rule a declared array meets, its
  # dimensions, sizes and initial list, each a diagnostic at its line. Since M5-13
  # (decision 156) it may be located, each element a point at consecutive addresses, and
  # then takes no initial list, as a located global takes no initial value.
  defp global(%Global{at: nil, type: type} = global) when is_array(type), do: misfits(global)

  defp global(%Global{type: type} = global) when is_array(type),
    do: located_array(location(global.at), global)

  defp global(%Global{}), do: []

  defp misfits(%Global{type: type} = global),
    do:
      Enum.map(
        Declarations.array_misfits(global.name, type, global.initial),
        &diagnostic(global.line, &1)
      )

  defp located_array(_location, %Global{initial: nil} = global), do: misfits(global)

  # Its sizes judged as an unlocated array's; its list not, since it takes none, and told
  # so only where its sizes give it a range.
  defp located_array(location, %Global{} = global),
    do: listed_located(misfits(%{global | initial: nil}), location, global)

  defp listed_located([], location, %Global{name: name, line: line} = global),
    do: [diagnostic(line, "`#{name}` is #{a_point(location, global)}: " <> no_list(location))]

  defp listed_located(misfits, _location, _global), do: misfits

  defp no_list({:ok, {_device, "i", _fields}}),
    do: "their values come from the input image, so it takes no initial list"

  defp no_list({:ok, {_device, "q", _fields}}),
    do: "it takes no initial list, and each element is 0 until its driver writes it"

  defp no_list(:error), do: "a located array takes no initial list"

  # M5-13: how a message names a located global, a point or an array of points with the
  # range its elements occupy, `an array of input points, `card.i.0` to `card.i.7``.
  defp a_point({:ok, {_device, "i", _fields}}, %Global{type: type}) when not is_array(type),
    do: "an input point"

  defp a_point({:ok, {_device, "q", _fields}}, %Global{type: type}) when not is_array(type),
    do: "an output point"

  defp a_point({:ok, {device, io, fields}}, %Global{type: {:array, _type, dims}}) do
    points = Logex.Array.points("", dims, fields)
    {_, _, from} = hd(points)
    {_, _, to} = List.last(points)

    "an array of #{direction_word(io)} points, `#{spelling({device, io, from})}` to " <>
      "`#{spelling({device, io, to})}`"
  end

  defp a_point(:error, _global), do: "located"

  defp direction_word("i"), do: "input"
  defp direction_word("q"), do: "output"

  # A located global takes no initial value: an input point's value is the host's, and an
  # output point starts at 0, the safe value, until the instance that drives it first
  # scans.
  defp initial(%Global{initial: nil}, _location), do: []

  # A value the host's check refused already, any but an integer, and a real's float.
  defp initial(%Global{type: type, initial: v}, _location)
       when not is_integer(v) and not (type in @reals and is_float(v)),
       do: []

  defp initial(%Global{name: name, line: line}, {:ok, {_device, "i", _address}}),
    do: [
      diagnostic(
        line,
        "`#{name}` is an input point: its value comes from the input image, so it takes no " <>
          "initial value"
      )
    ]

  defp initial(%Global{name: name, line: line}, {:ok, {_device, "q", _address}}),
    do: [
      diagnostic(
        line,
        "`#{name}` is an output point: it takes no initial value, and is 0 until its " <>
          "driver writes it"
      )
    ]

  # Since M5-10 by the literal rules, as a declaration's initial value (decision 147): a
  # real one is no integer type's, and an integer one a real's only exactly.
  defp initial(%Global{type: type, name: name, initial: v, line: line}, _location),
    do: fit(Declarations.holds?(type, v), type, v, "`#{name}`", line)

  defp fit(true, _type, _v, _what, _line), do: []

  defp fit(false, type, v, what, line),
    do: [
      diagnostic(
        line,
        "#{what} is #{Declarations.a_type(type)}: " <> initial_misfit(type, v)
      )
    ]

  defp initial_misfit(type, v) when is_float(v) or type in @reals,
    do: Declarations.literal_misfit(type, v, "`#{shown_number(v)}`")

  defp initial_misfit(type, v), do: Declarations.initial_misfit(type, "`#{v}`")

  defp shown_number(v) when is_float(v), do: Float.to_string(v)
  defp shown_number(v), do: "#{v}"

  @doc """
  A global's value before anything sets it: its `initial`, or 0 without one, so that an
  input point and an output point start at 0.

  Since M5-11 an array global's value is a tuple, a tuple of tuples for more dimensions,
  each element at its type's zero or its initial list's value in the elements' order
  (decision 151), as a state holds an array.

  The one rule for a new global (`docs/organisation.md` §4.9), as
  `Logex.Program.initial_env/1` is for a tag: `Logex.Runtime.start/1` starts every global
  by it, `Logex.Runtime.restart/2` every global but an input point, whose value it keeps,
  and `Logex.Configuration.Edit`, the edit of a running configuration (OE-2), each
  global it adds, at the switch that first finds it missing. The edit's exceptions, for a
  global the resource already holds: a kept global keeps its value until a restart, a
  changed `initial` included, which the switch reports (decision 44); one the
  configuration started does not declare is kept unused until assemble or cancel prunes
  it; an input or output point is neither added nor removed while running, located I/O
  being refused then; and a global that nothing drives any more holds its value, as an
  output an edit leaves undriven does (decision 20).

      iex> Logex.Configuration.initial(%Logex.Configuration.Global{name: "sp", type: :dint, initial: 1200})
      1200
      iex> Logex.Configuration.initial(%Logex.Configuration.Global{name: "x", type: :bool, at: "panel.i.0"})
      0
  """
  def initial(%Global{type: type, initial: nil}) when is_elementary(type),
    do: Declarations.zero(type)

  # M5-11 (decision 151): an array global starts as a declared array does, each element at
  # its type's zero or its initial list's value in the elements' order, a real's at its
  # nearest, held as a state holds an array, a tuple of tuples.
  def initial(%Global{type: {:array, type, dims} = array, initial: initial})
      when is_elementary(type) and (initial == nil or is_list(initial)),
      do:
        initial_array(initial == nil or length(initial) == Logex.Array.size(dims), array, initial)

  def initial(%Global{type: type, initial: nil}) when not is_array(type), do: 0

  # M5-10 (decision 150): a real global's initial value is held as its nearest value, a
  # `real`'s rounded to a single, an integer one as the real it is.
  def initial(%Global{type: type, initial: initial}) when type in @reals and is_number(initial),
    do: Logex.Real.nearest(type, initial)

  def initial(%Global{initial: initial}) when is_integer(initial), do: initial

  def initial(other),
    do:
      raise(
        ArgumentError,
        "expected a %Logex.Configuration.Global{} whose initial value is an integer, a real's a " <>
          "number, or nil, " <>
          "got: #{inspect(other)}"
      )

  defp initial_array(true, array, initial), do: Logex.Array.started(array, initial)

  defp initial_array(false, array, initial),
    do:
      raise(
        ArgumentError,
        "expected an initial list of #{Logex.Array.size(elem(array, 2))} values for " <>
          "#{Declarations.a_type(array)}, got: #{inspect(initial, charlists: :as_lists)}"
      )

  @doc """
  A task's watchdog, in milliseconds: its `watchdog`, or 500 where it sets none, the one
  rule for it, as `initial/1` is a global's (M4-2, decisions 109 and 110). Every task has
  one, the continuous task's bounding each of its rounds (decision 111), and the runner
  reads it at each step it times; `Logex.Runtime` reads no clock and so none, and
  `Logex.Configuration.Edit` reports a change of it (decision 129). A watchdog outside 1
  to 2147483647 ms is a diagnostic of `check/1`, and given here, from a task no check has
  passed, is the host's mistake, raised.

      iex> Logex.Configuration.watchdog(%Logex.Configuration.Task{name: "fast", interval: 10, priority: 1})
      500
      iex> Logex.Configuration.watchdog(%Logex.Configuration.Task{name: "main", continuous: true, watchdog: 200})
      200
  """
  def watchdog(%Logex.Configuration.Task{watchdog: nil}), do: 500

  def watchdog(%Logex.Configuration.Task{watchdog: watchdog}) when watchdog in @interval,
    do: watchdog

  def watchdog(other),
    do:
      raise(
        ArgumentError,
        "expected a %Logex.Configuration.Task{} whose watchdog is 1 to 2147483647 ms or " <>
          "nil, got: " <> inspect(other)
      )

  @doc """
  A location's parts, `{:ok, {device, "i" | "q", address}}`, or `:error` for anything
  else: `<device>.i.<address>` or `<device>.q.<address>`, one token to the lexer, as
  `panel.q.0` is (`docs/organisation.md` §4.5), its device a name, `i` or `q` in
  lowercase, and its address one or more whole numbers with no leading zero, the leftmost
  the highest level, so an address has one spelling. What a runner routes a point by.

      iex> Logex.Configuration.location("panel.q.0")
      {:ok, {"panel", "q", [0]}}
      iex> Logex.Configuration.location("panel.x.0")
      :error
      iex> Logex.Configuration.location("panel.i.00")
      :error
  """
  def location(at), do: located_word(word?(at), at)

  defp located_word(true, at), do: one_spelling(spelled(at))
  defp located_word(false, _at), do: :error

  defp one_spelling({:ok, address}), do: {:ok, address}
  defp one_spelling(_other), do: :error

  # A location's parts, read so that one written another way than its one spelling is
  # told that spelling: `{:ok, address}` as written, `{:respell, address}` with `I` or `Q`
  # for `i` or `q`, or a field with a leading zero, and `:error` for no location. `at` is
  # one name token, so its first part is a name and its others names or digits. The `.ld`
  # compiler reads the same shape in a rung, to name a location there, and a test pins the
  # two readings as one shape.
  defp spelled(at), do: spelled_parts(String.split(at, "."), at)

  defp spelled_parts([device, io | fields], at) when io in ["i", "q", "I", "Q"] and fields != [],
    do: numbered(Enum.all?(fields, &digits?/1), {device, String.downcase(io), fields}, at)

  defp spelled_parts(_parts, _at), do: :error

  defp numbered(false, _parts, _at), do: :error

  defp numbered(true, {device, io, fields}, at) do
    address = {device, io, Enum.map(fields, &String.to_integer/1)}
    as_written(spelling(address) == at, address)
  end

  defp as_written(true, address), do: {:ok, address}
  defp as_written(false, address), do: {:respell, address}

  defp digits?(field), do: String.match?(field, ~r/\A[0-9]+\z/)

  # A location in its one spelling.
  defp spelling({device, io, fields}),
    do: Enum.join([device, io | Enum.map(fields, &Integer.to_string/1)], ".")

  # Each location a global is at, refused where it is no location or is not written in
  # its one spelling. A global that keeps its name takes its address, where no other
  # global holds it and no other device's name differs from its device's only in case,
  # which would make two devices of what is likely one; a global refused for its name has
  # its location checked, but takes nothing: one mistake, one message. A location the
  # lexer does not read as one token is the host's mistake, refused already.
  defp located(globals, kept) do
    {points, _devices, problems} =
      globals
      |> Enum.with_index()
      |> Enum.sort_by(fn {global, _index} -> line_key(global) end)
      |> Enum.reduce({%{}, %{}, []}, fn {global, index}, acc ->
        at(word?(global.at), global, MapSet.member?(kept, {:global, index}), acc)
      end)

    {points, Enum.reverse(problems)}
  end

  defp at(false, _global, _keeps, acc), do: acc
  defp at(true, global, keeps, acc), do: at_spelled(spelled(global.at), global, keeps, acc)

  defp at_spelled(:error, global, _keeps, acc),
    do:
      noted(
        acc,
        global.line,
        "`#{global.at}` is not a location: a location is a device, `i` or `q`, and an " <>
          "address, as in `panel.i.0`"
      )

  defp at_spelled({:respell, address}, global, _keeps, acc),
    do:
      noted(
        acc,
        global.line,
        "`#{global.at}` is not a location as written: a location's `i` or `q` is lowercase " <>
          "and its address has no leading zero, so it is written `#{spelling(address)}`"
      )

  defp at_spelled({:ok, _address}, _global, false, acc), do: acc

  defp at_spelled({:ok, {device, _io, _fields} = address}, global, true, {_, devices, _} = acc),
    do: device(Map.get(devices, String.downcase(device)), address, global, acc)

  defp device(
         nil,
         {device, _io, _fields} = address,
         %Global{type: type} = global,
         {points, devices, problems}
       )
       when not is_array(type),
       do:
         address(
           Map.get(points, address),
           address,
           global,
           {points, Map.put(devices, String.downcase(device), {device, global}), problems}
         )

  defp device(nil, {device, _io, _fields} = address, global, {points, devices, problems}),
    do:
      occupied(
        address,
        global,
        {points, Map.put(devices, String.downcase(device), {device, global}), problems}
      )

  defp device(
         {device, _first},
         {device, _io, _fields} = address,
         %Global{type: type} = global,
         acc
       )
       when not is_array(type),
       do: address(Map.get(elem(acc, 0), address), address, global, acc)

  defp device({device, _first}, {device, _io, _fields} = address, global, acc),
    do: occupied(address, global, acc)

  defp device({other, first}, {device, _io, _fields}, global, acc),
    do:
      noted(
        acc,
        global.line,
        "the device `#{device}` and the device `#{other}` of `#{first.name}`#{where(first)} " <>
          "differ only in case: device names are case-sensitive, so these would be two devices"
      )

  # M5-13 (decision 156): a located array occupies an address an element, each element a
  # point of its own, a global named by the element's name, `temps[3]`, at its own address,
  # so that a location in a connection names the element, and an element that overlaps
  # another point is told both names, once for each point it overlaps: an array laid over
  # another is one message, at the first element they share, naming the range it takes.
  # An array whose sizes are refused takes no address: one mistake, one message.
  defp occupied(address, %Global{type: type} = global, acc),
    do: sized(Declarations.array_misfits(global.name, type, nil), address, global, acc)

  defp sized([], {device, io, fields}, %Global{type: {:array, type, dims}} = global, acc) do
    {acc, _told} =
      Logex.Array.points(global.name, dims, fields)
      |> Enum.reduce({acc, MapSet.new()}, fn {_index, name, at}, {acc, told} ->
        address = {device, io, at}
        element = %Global{global | name: name, type: type, at: spelling(address)}
        overlapping(Map.get(elem(acc, 0), address), address, {element, global}, {acc, told})
      end)

    acc
  end

  defp sized(_misfits, _address, _global, acc), do: acc

  defp overlapping(nil, address, {element, _global}, {{points, devices, problems}, told}),
    do: {{Map.put(points, address, element), devices, problems}, told}

  defp overlapping(first, _address, {element, global}, {acc, told}),
    do: overlapped(MapSet.member?(told, owner(first)), first, {element, global}, {acc, told})

  defp overlapped(true, _first, _element, state), do: state

  defp overlapped(false, first, {element, global}, {acc, told}),
    do:
      {noted(
         acc,
         global.line,
         "`#{element.name}` is at `#{element.at}`, where `#{first.name}` already is" <>
           "#{where(first)}: a location holds one global, and `#{global.name}` is " <>
           "#{a_point(location(global.at), global)}"
       ), MapSet.put(told, owner(first))}

  # The global a point belongs to, an element's its array's.
  defp owner(%Global{name: name}), do: hd(:binary.split(name, "["))

  defp address(nil, address, global, {points, devices, problems}),
    do: {Map.put(points, address, global), devices, problems}

  defp address(first, _address, global, acc),
    do:
      noted(
        acc,
        global.line,
        "`#{global.name}` is at `#{global.at}`, where `#{first.name}` already is" <>
          "#{where(first)}: a location holds one global"
      )

  defp noted({points, devices, problems}, line, message),
    do: {points, devices, [diagnostic(line, message) | problems]}

  # What the connections are checked against: the names, those not to report, the
  # globals at each address, and each instance that can run with its program, by name.
  defp world(space, points, programs),
    do: %{
      names: space.names,
      silent: space.silent,
      points: points,
      runnable: runnable(space.names, programs),
      instances: names_of(space.names, :instance),
      globals: names_of(space.names, :global),
      tasks: names_of(space.names, :task)
    }

  defp names_of(names, kind), do: Enum.sort(for {name, {^kind, _line, _}} <- names, do: name)

  # The instances that keep their names and can run, each with its program: its type a
  # name that is no keyword, of a program given.
  defp runnable(names, programs),
    do:
      for(
        {name, {:instance, _line, %Instance{type: type} = instance}} <- names,
        Declarations.name?(type) and not reserved?(type),
        {:ok, program} <- [Map.fetch(programs, type)],
        into: %{},
        do: {name, {instance, program}}
      )

  # What is wrong with each instance's type, then its task.
  defp runs(instances, programs, world),
    do: Enum.flat_map(instances, &(of_type(word?(&1.type), &1, programs) ++ on_task(&1, world)))

  # A type the lexer does not read as one name is the host's mistake, refused already.
  defp of_type(false, _instance, _programs), do: []

  defp of_type(true, %Instance{type: type} = instance, programs),
    do: type_named(String.contains?(type, "."), reserved?(type), instance, programs)

  defp type_named(true, _reserved, instance, _programs),
    do: [
      diagnostic(
        instance.line,
        "`#{instance.type}` cannot name a program type: a type is named by its file, " <>
          "`motor.ld` for `motor`, and " <> rule()
      )
    ]

  defp type_named(false, true, instance, _programs),
    do: [
      diagnostic(instance.line, "`#{instance.type}` is a keyword and cannot name a program type")
    ]

  defp type_named(false, false, instance, {programs, given}),
    do: typed(Map.has_key?(programs, instance.type), instance, {programs, given})

  defp typed(true, _instance, _programs), do: []

  # A program given under this name but refused has its own message, and an instance of it
  # cannot run: one mistake, one message.
  defp typed(false, instance, {programs, given}),
    do: unknown_type(MapSet.member?(given, instance.type), instance, programs)

  defp unknown_type(true, _instance, _programs), do: []

  defp unknown_type(false, instance, programs) do
    names = Enum.sort(Map.keys(programs))
    unknown = "unknown program type `#{instance.type}`"

    [
      diagnostic(
        instance.line,
        types_hint(
          unknown,
          Declarations.suggest(instance.type, names, & &1, "program types"),
          names
        )
      )
    ]
  end

  defp types_hint(message, "", []), do: message <> ": no program types were given"

  defp types_hint(message, "", names),
    do: {message, :types, fn -> ": the types given are " <> listed(names) end}

  defp types_hint(message, suggestion, _names), do: message <> suggestion

  # An instance's task: one the configuration declares, unless its name was refused, which
  # is reported once.
  defp on_task(%Instance{task: nil}, _world), do: []

  defp on_task(%Instance{task: task} = instance, world),
    do: task_word(word?(task), instance, world)

  # A task the lexer does not read as one name is the host's mistake, refused already.
  defp task_word(false, _instance, _world), do: []

  defp task_word(true, %Instance{task: task} = instance, world),
    do: task_held(MapSet.member?(world.silent, task), Map.get(world.names, task), instance, world)

  defp task_held(true, _held, _instance, _world), do: []
  defp task_held(false, {:task, _line, _ref}, _instance, _world), do: []

  defp task_held(false, {kind, line, _ref}, instance, _world),
    do: [
      diagnostic(instance.line, "`#{instance.task}` is #{a(kind)}#{at_line(line)}, not a task")
    ]

  defp task_held(false, nil, %Instance{task: task} = instance, world),
    do: [diagnostic(instance.line, no_task(String.contains?(task, "."), task, world))]

  # A name with `.` parts after `with` is no task's: a task's name has none, so it is told
  # that, never a global's or a member's reading (§4.7).
  defp no_task(true, task, world),
    do:
      "no task `#{task}`: a task's name has no `.`, which is kept for a path and a location" <>
        Declarations.suggest(task, world.tasks, & &1, "names")

  defp no_task(false, task, world), do: no_named(:task, task, world, nil)

  defp listed(names) do
    quoted = Enum.map(names, &"`#{&1}`")
    listing(Enum.drop(quoted, -1), List.last(quoted))
  end

  defp listing([], last), do: last
  defp listing(rest, last), do: Enum.join(rest, ", ") <> " and " <> last

  # The connections, in line order, each checked against its instance's program and the
  # globals. One problem is reported per connection, the first; a var_input with a
  # connection that names it, whatever its other end, counts as connected, and a global as
  # driven only by a good one, so one mistake is one message. A connection whose instance
  # or member is the host's mistake is refused already, and names no var_input: a bad name
  # is not recovered. A broken connection line, `wired`, connects its var_input, so a
  # later connection to it is not a second source, though its own source is checked.
  #
  # The wiring: each var_input connected, `{instance, member}` to its first connection or
  # `:broken`; each global driven, to its driver; and each global a connection names.
  defp wiring(connections, world, wired) do
    inputs =
      Map.new(wired, fn {:declared, _line, %{instance: instance, member: member}} ->
        {{instance, member}, :broken}
      end)

    {wiring, problems} =
      Enum.reduce(
        connections,
        {%{inputs: inputs, driven: %{}, parts: %{}, used: MapSet.new()}, []},
        &connect(&1, &2, world)
      )

    {wiring, Enum.reverse(problems)}
  end

  defp connect(%Connection{} = connection, acc, world),
    do: connect_ends(ends?(connection), connection, acc, world)

  defp connect_ends(false, _connection, acc, _world), do: acc

  defp connect_ends(true, connection, acc, world),
    do: on_instance(instance_of(connection, world), connection, acc, world)

  # The instance a connection begins with: one that can run; one that cannot, its type
  # unknown, whose connections are not checked; or a name that names no instance.
  defp instance_of(%Connection{instance: name} = connection, world),
    do:
      instance_held(
        MapSet.member?(world.silent, name),
        Map.get(world.names, name),
        connection,
        world
      )

  defp instance_held(true, _held, _connection, _world), do: :skip

  defp instance_held(false, {:instance, _line, _ref}, connection, world),
    do: running(Map.fetch(world.runnable, connection.instance))

  defp instance_held(false, {kind, line, _ref}, connection, _world),
    do: {:error, "`#{connection.instance}` is #{a(kind)}#{at_line(line)}, not an instance"}

  # A connection line that begins with a location reads it as an instance's member, so
  # where no instance has that name, the message names the location reading (§4.7).
  defp instance_held(false, nil, connection, world),
    do: no_instance(spelled("#{connection.instance}.#{connection.member}"), connection, world)

  defp running({:ok, {instance, program}}), do: {:ok, instance, program}
  defp running(:error), do: :skip

  defp no_instance(:error, connection, world),
    do: {:error, no_named(:instance, connection.instance, world, nil)}

  defp no_instance(_location, connection, _world),
    do:
      {:error,
       "`#{connection.instance}.#{connection.member}` is a location, written only after `at` " <>
         "on a `var_global` line: a connection begins with an instance's var_input or " <>
         "var_output, as in `m1.start`"}

  # A name declared nowhere: a keyword, which names nothing in a configuration file, so
  # no message advises declaring one; a near name; or how to declare it.
  defp no_named(kind, name, world, type),
    do: unnamed(reserved?(name), kind, name, world, type)

  defp unnamed(true, kind, name, _world, _type),
    do:
      "no #{noun(kind)} `#{name}`: `#{name}` is a keyword of a configuration file, and " <>
        "nothing in one is named so"

  # M5-11: a name with a subscript, `ws[0]`, where a global is wanted whole, a task's
  # single, names no global (provisional reading 8), and no line declares one so; a
  # connection's far end takes an element since decision 223 (element_global/4).
  defp unnamed(false, :global, name, world, type),
    do: subscripted(String.split(name, "[", parts: 2), name, world, type)

  defp unnamed(false, kind, name, world, type),
    do: declare(Declarations.suggest(name, known(world, kind), & &1, "names"), kind, name, type)

  defp subscripted([array, _subscripts], name, world, _type),
    do: element_named(Map.get(world.names, array), array, name)

  defp subscripted([_whole], name, world, type),
    do:
      declare(
        Declarations.suggest(name, known(world, :global), & &1, "names"),
        :global,
        name,
        type
      )

  defp element_named({:global, _line, %Global{type: type} = global}, array, name)
       when is_array(type),
       do:
         "`#{name}` names an element of `#{array}`, #{Declarations.a_global(type)}" <>
           "#{where(global)}: a global is named here whole, never by one of its elements"

  defp element_named(_none, _array, name),
    do: "no global `#{name}`: a global is named here whole, never by one of its elements"

  defp declare("", :global, name, type),
    do: "no global `#{name}`: declare it, as in `var_global #{name} #{written_type(type)}`"

  defp declare("", :instance, name, _type),
    do: "no instance `#{name}`: declare it, as in `program #{name} motor`"

  defp declare("", :task, name, _type),
    do:
      "no task `#{name}`: declare it with a `task` line, as in " <>
        "`task #{name} interval 10 priority 1`"

  defp declare(suggestion, kind, name, _type), do: "no #{noun(kind)} `#{name}`" <> suggestion

  defp noun(:global), do: "global"
  defp noun(:instance), do: "instance"
  defp noun(:task), do: "task"

  defp known(world, :global), do: world.globals
  defp known(world, :instance), do: world.instances
  defp known(world, :task), do: world.tasks

  defp on_instance(:skip, _connection, acc, _world), do: acc

  defp on_instance({:error, message}, connection, acc, _world),
    do: problem(acc, connection, message)

  defp on_instance({:ok, instance, program}, connection, acc, world),
    do:
      of_member(
        member_tag(program, connection),
        instance,
        program,
        connection,
        acc,
        world
      )

  # M5-11 (decision 151, §4.12): a connection names an array var_input or var_output whole,
  # `m1.temps`, or an element of one by literal subscripts, `m1.temps[3]`, read as the tag
  # of its element's type under its element's name, `temps[3]` by its subscripts' values.
  defp member_tag(program, %Connection{member: member} = connection)
       when binary_part(member, byte_size(member) - 1, 1) == "]",
       do: element_tag(Logex.Array.split(member), program, "#{connection.instance}.#{member}")

  defp member_tag(program, %Connection{member: member}), do: Map.fetch(program.tags, member)

  defp element_tag({array, subscripts}, program, member),
    do: element_of_tag(Map.fetch(program.tags, array), {array, subscripts}, program, member)

  defp element_of_tag(:error, {array, _subscripts}, program, _member),
    do: {:element, "`#{program.name}` declares no `#{array}`"}

  defp element_of_tag({:ok, %Tag{type: {:array, type, dims}} = tag}, {_, subscripts}, _p, member),
    do:
      subscripted(
        Enum.map(subscripts, &Logex.Array.subscript/1),
        {tag, type, dims},
        member
      )

  defp element_of_tag({:ok, %Tag{} = tag}, {array, _subscripts}, program, member),
    do:
      {:element,
       "`#{member}` names an element of `#{array}`, but `#{array}` is " <>
         "#{shown_type(tag.type)}#{in_type(tag.line, program)}, no array"}

  defp subscripted(subscripts, {tag, type, dims}, member) do
    tags = for {:tag, name} <- subscripts, do: name
    literal = for {:literal, n} <- subscripts, do: n
    element_index(tags, {literal, subscripts}, {tag, type, dims}, member)
  end

  defp element_index([name | _], _subscripts, _array, member),
    do:
      {:element,
       "`#{member}`'s subscript `#{name}` is a tag's name: a connection names an element by " <>
         "literal subscripts, as in `#{elem(Logex.Array.split(member), 0)}[0]`"}

  defp element_index([], {index, _}, {tag, _type, dims}, member)
       when length(index) != length(dims),
       do:
         {:element,
          "`#{member}` names an element of `#{tag.name}`, #{Declarations.a_type(tag.type)}, " <>
            "by #{length(index)} subscript#{plural(length(index))}, where it takes " <>
            "#{length(dims)}, one a dimension"}

  defp element_index([], {index, _}, {tag, type, dims}, member),
    do:
      in_bounds(
        Enum.find(Enum.zip(index, dims), fn {i, n} -> i < 0 or i >= n end),
        index,
        {tag, type},
        member
      )

  defp in_bounds(nil, index, {tag, type}, _member),
    do: {:ok, %{tag | name: Logex.Array.name(tag.name, index), type: type}}

  defp in_bounds({i, n}, _index, {tag, _type}, member),
    do:
      {:element,
       "`#{member}`'s subscript `#{i}` is outside 0 to #{n - 1}: `#{tag.name}` is " <>
         "#{Declarations.a_type(tag.type)}"}

  defp plural(1), do: ""
  defp plural(_n), do: "s"

  # A type as a message names it, an instance's by its type.
  defp shown_type(type) when is_elementary(type) or is_array(type), do: Declarations.a_type(type)
  defp shown_type(type), do: Declarations.instance_of(type)

  # A type as a declaration line writes it, `dint` or `int[8]`.
  defp written_type({:array, type, dims}),
    do: "#{Declarations.word(type)}[#{Enum.join(dims, ",")}]"

  defp written_type(type), do: "#{type}"

  defp of_member({:ok, %Tag{section: :var_input} = tag}, _i, _p, connection, acc, world),
    do: input(connection, tag, acc, world)

  defp of_member({:ok, %Tag{section: :var_output} = tag}, _i, _p, connection, acc, world),
    do: output(other_end(connection.to), connection, tag, acc, world)

  # M2-4: a var_external reaches its global itself, so no connection names it.
  defp of_member({:ok, %Tag{section: :var_external}}, _i, program, connection, acc, _world),
    do:
      problem(
        acc,
        connection,
        "`#{connection.instance}.#{connection.member}` is a var_external of `#{program.name}`, " <>
          "which reaches the global `#{connection.member}` itself: only a var_input or " <>
          "var_output connects"
      )

  defp of_member({:ok, %Tag{section: section}}, _instance, program, connection, acc, _world),
    do:
      problem(
        acc,
        connection,
        "`#{connection.instance}.#{connection.member}` is internal to `#{program.name}` " <>
          "(declared `#{section}`): only a var_input or var_output connects"
      )

  defp of_member({:ok, _not_a_tag}, _instance, program, connection, acc, _world),
    do: problem(acc, connection, declares_no(connection, program))

  defp of_member({:element, message}, _instance, _program, connection, acc, _world),
    do: problem(acc, connection, message)

  defp of_member(:error, _instance, program, connection, acc, _world),
    do: unknown_member(String.contains?(connection.member, "."), program, connection, acc)

  defp unknown_member(true, _program, connection, acc),
    do:
      problem(
        acc,
        connection,
        "`#{connection.instance}.#{connection.member}` goes too deep: a connection names an " <>
          "instance's var_input or var_output, as in `#{connection.instance}.start`"
      )

  defp unknown_member(false, program, connection, acc) do
    names = for {name, %Tag{section: s}} <- program.tags, s in [:var_input, :var_output], do: name
    names = Enum.sort(names)

    problem(
      acc,
      connection,
      connects(
        declares_no(connection, program),
        Declarations.suggest(connection.member, names, & &1, "members"),
        names,
        program.name
      )
    )
  end

  defp declares_no(connection, program),
    do:
      "`#{connection.instance}` runs `#{program.name}`, which declares no `#{connection.member}`"

  defp connects(message, "", [], _type), do: message <> ": it has no var_input or var_output"

  defp connects(message, "", names, type),
    do:
      {message, {:members, type},
       fn -> ": its var_inputs and var_outputs are " <> listed(names) end}

  defp connects(message, suggestion, _names, _type), do: message <> suggestion

  defp problem({wiring, problems}, connection, message),
    do: {wiring, [diagnostic(connection.line, message) | problems]}

  # A var_input: connected once, to a global of its type or a constant that fits it.
  defp input(connection, tag, {wiring, problems}, world) do
    key = {connection.instance, tag.name}
    first = first_source(Logex.Array.split(tag.name), wiring.inputs, key)

    sourced(
      first,
      key,
      connection,
      tag,
      {%{wiring | inputs: parted(key, wiring.inputs, connection)}, problems},
      world
    )
  end

  # M5-11: an array var_input has one source whole, or one for each element: an element's
  # is its array's where the array is connected whole, and an array's the first of its
  # elements' where any is connected, kept under `{:elements, instance, array}`.
  defp first_source({array, _subscripts}, inputs, {instance, _element} = key),
    do: Map.get(inputs, key) || Map.get(inputs, {instance, array})

  defp first_source(nil, inputs, {instance, name} = key),
    do: Map.get(inputs, key) || Map.get(inputs, {:elements, instance, name})

  defp parted({instance, name}, inputs, connection),
    do: element_part(Logex.Array.split(name), instance, inputs, connection)

  defp element_part({array, _subscripts}, instance, inputs, connection),
    do: Map.put_new(inputs, {:elements, instance, array}, connection)

  defp element_part(nil, _instance, inputs, _connection), do: inputs

  defp sourced(nil, key, connection, tag, {wiring, problems}, world),
    do:
      source(
        other_end(connection.to),
        connection,
        tag,
        {%{wiring | inputs: Map.put(wiring.inputs, key, connection)}, problems},
        world
      )

  # Its first connection is a broken line, reported there: this one is no second source,
  # but its own source is checked.
  defp sourced(:broken, _key, connection, tag, acc, world),
    do: source(other_end(connection.to), connection, tag, acc, world)

  defp sourced(first, key, connection, tag, acc, world),
    do:
      already(
        parted?(first.member) == parted?(connection.member),
        first,
        {key, connection, tag},
        acc,
        world
      )

  defp parted?(member), do: Logex.Array.split(member) != nil

  defp already(false, %Connection{member: member} = first, {_key, connection, _tag}, acc, _world),
    do:
      problem(
        acc,
        connection,
        "`#{connection.instance}.#{connection.member}` is already connected, by " <>
          "`#{connection.instance}.#{member}` to #{end_label(first.to)}#{where(first)}: a " <>
          "var_input has one source, an array whole or each of its elements"
      )

  defp already(true, first, {_key, connection, _tag}, acc, _world),
    do:
      problem(
        acc,
        connection,
        "`#{connection.instance}.#{connection.member}` is already connected, to " <>
          "#{end_label(first.to)}#{where(first)}: a var_input has one source"
      )

  defp end_label(to) when is_binary(to) or is_integer(to), do: "`#{to}`"
  defp end_label(to) when is_float(to), do: "`#{Float.to_string(to)}`"
  defp end_label(to), do: inspect(to)

  defp source(:global, connection, tag, acc, world),
    do: read_global(global_of(connection.to, tag.type, world), connection, tag, acc)

  # M5-11: a constant is one value, so it fills an element, never an array whole.
  defp source(:constant, connection, %Tag{type: type} = tag, acc, _world) when is_array(type),
    do:
      problem(
        acc,
        connection,
        "`#{connection.instance}.#{connection.member}` is #{Declarations.a_type(type)}, and " <>
          "the constant `#{shown_number(connection.to)}` is one value: connect it to a global " <>
          "array of its sizes, or each element to a constant, as in " <>
          "`#{connection.instance}.#{Logex.Array.name(tag.name, Enum.map(elem(type, 2), fn _ -> 0 end))} " <>
          "#{shown_number(connection.to)}`"
      )

  defp source(:constant, %Connection{to: to} = connection, %Tag{type: type} = tag, acc, _world),
    do: constant(Declarations.holds?(type, to), connection, tag, acc)

  defp source(:junk, _connection, _tag, acc, _world), do: acc

  defp constant(true, _connection, _tag, acc), do: acc

  defp constant(false, connection, %Tag{type: type}, acc),
    do:
      problem(
        acc,
        connection,
        "`#{connection.instance}.#{connection.member}` is #{Declarations.a_type(type)}: " <>
          Declarations.literal_misfit(type, connection.to, "`#{shown_number(connection.to)}`")
      )

  # A global whose type is the host's mistake is refused already: one mistake, one message.
  defp read_global({:ok, %Global{type: type} = global}, _connection, _tag, acc)
       when not is_elementary(type) and not is_array(type),
       do: used(acc, global)

  # M5-3 (decision 159): a connection's copy-in widens as an instruction's source does, so
  # the global's type is the var_input's or one Ed 3 Figure 11 widens into it.
  defp read_global({:ok, global}, connection, tag, acc),
    do:
      same_type(
        widens?(global.type, tag.type),
        {global.type, tag.type},
        {global, connection, tag},
        used(acc, global)
      )

  defp read_global({:error, message}, connection, _tag, acc),
    do: problem(acc, connection, message)

  defp read_global(:skip, _connection, _tag, acc), do: acc

  # M5-11 (decisions 151 and 159): an array connects to an array of its sizes, each element
  # widening as a value does, and to nothing else.
  defp widens?({:array, from, dims}, {:array, to, dims}), do: Declarations.widens?(from, to)
  defp widens?(from, to) when is_array(from) or is_array(to), do: false
  defp widens?(from, to), do: Declarations.widens?(from, to)

  # An element of a global array, `speeds[1]`, is a use of its array (decision 223).
  defp used({wiring, problems}, global),
    do: {%{wiring | used: MapSet.put(wiring.used, array_of(global.name))}, problems}

  defp array_of(name), do: hd(:binary.split(name, "["))

  defp same_type(true, _types, _ends, acc), do: acc

  defp same_type(false, {from, to}, {global, connection, tag}, acc),
    do:
      problem(
        acc,
        connection,
        "`#{connection.instance}.#{connection.member}` is #{type_word(tag.type)}, but " <>
          "`#{global.name}` is #{Declarations.a_type(global.type)}#{where(global)}" <>
          unwidened(Declarations.conversion(from, to), from, to)
      )

  # Two integer types a connection cannot widen between are told the conversion, which a
  # program makes, since a connection converts nothing (M5-3, decision 159).
  defp unwidened(nil, _from, _to), do: ""

  defp unwidened(conversion, from, to),
    do:
      ": #{Declarations.a_type(from)} does not widen into #{Declarations.a_type(to)}, and a " <>
        "connection converts nothing: convert it inside the program, with `#{conversion}`"

  # A var_input or var_output that holds an instance is the host's mistake, refused before
  # any diagnostic (decision 169), so a connected member's type is elementary here.
  defp type_word(type), do: Declarations.a_type(type)

  # What a name where a global is wanted reads as: a global; nothing to report, its name
  # refused already; or a mistake, each reading named (§4.7). `type` is the member's, for
  # the advice to declare one.
  defp global_of(name, type, world),
    do:
      reading(MapSet.member?(world.silent, name), String.contains?(name, "."), name, type, world)

  defp reading(true, _dotted, _name, _type, _world), do: :skip

  defp reading(false, false, name, type, world),
    do: global_held(Map.get(world.names, name), name, type, world)

  defp reading(false, true, name, type, world), do: dotted(spelled(name), name, type, world)

  defp global_held({:global, _line, %Global{} = global}, _name, _type, _world),
    do: {:ok, global}

  defp global_held({kind, line, _ref}, name, _type, _world),
    do: {:error, "`#{name}` is #{a(kind)}#{at_line(line)}, not a global"}

  # Decision 223: a connection's far end may be an element of a global array, by literal
  # subscripts, `speeds[1]`, read and driven as a global of the elements' type under the
  # element's name by its subscripts' values, at the array's line.
  defp global_held(nil, name, type, world)
       when binary_part(name, byte_size(name) - 1, 1) == "]",
       do: element_global(String.split(name, "[", parts: 2), name, type, world)

  defp global_held(nil, name, type, world), do: {:error, no_named(:global, name, world, type)}

  defp element_global([array, _subscripts], name, type, world),
    do: element_silent(MapSet.member?(world.silent, array), array, name, type, world)

  defp element_global([_whole], name, type, world),
    do: {:error, no_named(:global, name, world, type)}

  # M5-13: an element of a global whose line was refused names what that line declares,
  # and is silent, as a use of the global's own name is (decision 42).
  defp element_silent(true, _array, _name, _type, _world), do: :skip

  defp element_silent(false, array, name, type, world),
    do: global_element(Map.get(world.names, array), name, type, world)

  defp global_element(
         {:global, _line, %Global{type: {:array, etype, dims}} = global},
         name,
         _,
         _
       ),
       do:
         global_subscripts(
           Enum.map(elem(Logex.Array.split(name), 1), &Logex.Array.subscript/1),
           {global, etype, dims},
           name
         )

  defp global_element({:global, _line, %Global{} = global}, name, _type, _world),
    do:
      {:error,
       "`#{name}` names an element of `#{global.name}`, but `#{global.name}` is " <>
         "#{Declarations.a_global(global.type)}#{where(global)}, no array"}

  defp global_element(nil, name, _type, world) do
    [array | _] = String.split(name, "[")

    {:error,
     "no global `#{name}`: there is no global array `#{array}`" <>
       Declarations.suggest(array, world.globals, & &1, "names")}
  end

  defp global_element({kind, line, _ref}, name, _type, _world) do
    [array | _] = String.split(name, "[")

    {:error,
     "`#{name}` names an element of `#{array}`, but `#{array}` is #{a(kind)}#{at_line(line)}, " <>
       "not a global"}
  end

  defp global_subscripts(subscripts, {global, etype, dims}, name) do
    tags = for {:tag, tag} <- subscripts, do: tag
    index = for {:literal, n} <- subscripts, do: n
    global_index(tags, index, {global, etype, dims}, name)
  end

  defp global_index([tag | _], _index, {global, _etype, dims}, name),
    do:
      {:error,
       "`#{name}`'s subscript `#{tag}` is a tag's name: a connection names an element of a " <>
         "global by literal subscripts, as in `#{global.name}[#{zeros(dims)}]`"}

  defp global_index([], index, {global, _etype, dims}, name) when length(index) != length(dims),
    do:
      {:error,
       "`#{name}` names an element of `#{global.name}`, " <>
         "#{Declarations.a_global(global.type)}#{where(global)}, by #{length(index)} " <>
         "subscript#{plural(length(index))}, where it takes #{length(dims)}, one a dimension, " <>
         "as in `#{global.name}[#{zeros(dims)}]`"}

  defp global_index([], index, {global, etype, dims}, name),
    do:
      global_in_bounds(
        Enum.find(Enum.zip(index, dims), fn {i, n} -> i < 0 or i >= n end),
        index,
        {global, etype},
        name
      )

  defp global_in_bounds(nil, index, {%Global{} = global, etype}, _name),
    do: {:ok, %Global{global | name: Logex.Array.name(global.name, index), type: etype}}

  defp global_in_bounds({i, n}, _index, {global, _etype}, name),
    do:
      {:error,
       "`#{name}`'s subscript `#{i}` is outside 0 to #{n - 1}: `#{global.name}` is " <>
         "#{Declarations.a_global(global.type)}#{where(global)}"}

  defp zeros(dims), do: Enum.map_join(dims, ",", fn _ -> 0 end)

  # A name with `.` parts: a location a global is at reads as that location first, written
  # another way or not, whatever its device is called, since a device may share an
  # instance's name; then an instance's member; then a location no global is at; then a
  # member of what is no instance.
  defp dotted(:error, name, type, world), do: member_of(name, :error, type, world)

  defp dotted({_written, address} = location, name, type, world),
    do: at_point(Map.get(world.points, address), location, name, type, world)

  defp at_point(nil, location, name, type, world), do: member_of(name, location, type, world)

  defp at_point(global, _location, name, _type, _world),
    do:
      {:error,
       "`#{name}` is a location, written only after `at` on a `var_global` line: name the " <>
         "global at it, `#{global.name}`#{where(global)}"}

  defp member_of(name, location, type, world) do
    [first | _rest] = String.split(name, ".")

    member_held(
      MapSet.member?(world.silent, first),
      Map.get(world.names, first),
      location,
      {name, first, type},
      world
    )
  end

  defp member_held(true, _held, _location, _named, _world), do: :skip

  # No program-to-program connection (§5): instances share a value through a global.
  defp member_held(false, {:instance, _line, _ref}, _location, {name, _first, _type}, _world),
    do:
      {:error,
       "`#{name}` is an instance's member: instances share a value only through a global, " <>
         "which one drives and the other reads"}

  # A raw location in a connection (§4.5: not adopted), its advice in its one spelling.
  defp member_held(false, _held, {_written, address}, {name, _first, type}, _world),
    do:
      {:error,
       "`#{name}` is a location, written only after `at` on a `var_global` line: declare a " <>
         "global at it, as in `var_global point #{type} at #{spelling(address)}`, and name that"}

  defp member_held(false, {kind, line, _ref}, :error, {name, first, _type}, _world),
    do:
      {:error,
       "`#{name}` names a member of `#{first}`, but `#{first}` is #{a(kind)}#{at_line(line)}, " <>
         "not an instance"}

  # M5-12's review: a member or bit of an element of a global array, `speeds[1].3`, is told
  # the element is a global's, as a member of a global is, or the element's own mistake.
  defp member_held(false, nil, :error, {name, first, type}, world)
       when binary_part(first, byte_size(first) - 1, 1) == "]",
       do: element_member(global_held(nil, first, type, world), name, first)

  defp member_held(false, nil, :error, {name, first, _type}, world),
    do:
      {:error,
       "`#{name}` names a member of an instance, and there is no instance `#{first}`" <>
         Declarations.suggest(first, world.instances, & &1, "names")}

  defp element_member({:ok, %Global{} = element}, name, first) do
    [array | _] = String.split(first, "[")

    {:error,
     "`#{name}` names a member of `#{first}`, but `#{first}` is an element of the global " <>
       "`#{array}`#{where(element)}, not an instance"}
  end

  defp element_member(error, _name, _first), do: error

  # A var_output: to a global of its type, never an input point, and the only connection
  # that drives that global.
  defp output(:global, connection, tag, acc, world),
    do: sink(global_of(connection.to, tag.type, world), connection, tag, acc)

  defp output(:constant, connection, _tag, acc, _world),
    do:
      problem(
        acc,
        connection,
        "`#{connection.instance}.#{connection.member}` is a var_output, which drives a " <>
          "global: it cannot drive the constant `#{connection.to}`"
      )

  defp output(:junk, _connection, _tag, acc, _world), do: acc

  defp sink({:ok, %Global{type: type} = global}, _connection, _tag, acc)
       when not is_elementary(type) and not is_array(type),
       do: used(acc, global)

  defp sink({:ok, global}, connection, tag, acc),
    do: drives(location(global.at), global, connection, tag, used(acc, global))

  defp sink({:error, message}, connection, _tag, acc), do: problem(acc, connection, message)
  defp sink(:skip, _connection, _tag, acc), do: acc

  defp drives({:ok, {_device, "i", _address}} = location, global, connection, _tag, acc),
    do:
      problem(
        acc,
        connection,
        "`#{global.name}` is #{a_point(location, global)}#{where(global)}: " <>
          "`#{connection.instance}.#{connection.member}`, a var_output, cannot drive it"
      )

  # M5-3 (decision 159): a copy-out widens as a destination takes a value, so the global's
  # type is the var_output's or one Ed 3 Figure 11 widens it into.
  defp drives(_location, global, connection, tag, acc),
    do: typed_sink(widens?(tag.type, global.type), global, connection, tag, acc)

  defp typed_sink(false, global, connection, tag, acc),
    do: same_type(false, {tag.type, global.type}, {global, connection, tag}, acc)

  defp typed_sink(true, global, connection, _tag, {wiring, _problems} = acc),
    do: driver(first_driver(wiring, global.name), global, connection, acc)

  # Decision 223: one connection at most drives each element of a global array, and one
  # that drives the array whole drives every element: an element's first driver is its own
  # or its array's, and an array's its own or that of any element of it, kept in `parts`.
  defp first_driver(wiring, name),
    do: driven_by(Map.get(wiring.driven, name), :binary.split(name, "["), wiring)

  defp driven_by(nil, [array, _subscripts], wiring),
    do: whole_driver(Map.get(wiring.driven, array), array)

  defp driven_by(nil, [array], wiring), do: part_driver(Map.get(wiring.parts, array), array)
  defp driven_by(first, _name, _wiring), do: first

  defp whole_driver(nil, _array), do: nil
  defp whole_driver(first, array), do: {:whole, first, array}

  defp part_driver(nil, _array), do: nil
  defp part_driver({element, first}, _array), do: {:part, first, element}

  defp driver(nil, global, connection, {wiring, problems}),
    do:
      {%{
         wiring
         | driven: Map.put(wiring.driven, global.name, connection),
           parts: driven_part(:binary.split(global.name, "["), global.name, connection, wiring)
       }, problems}

  defp driver({:whole, first, array}, global, connection, acc),
    do:
      problem(
        acc,
        connection,
        "`#{global.name}` is already driven by `#{first.instance}.#{first.member}`" <>
          "#{where(first)}, which drives `#{array}` whole: one connection drives each element"
      )

  defp driver({:part, first, element}, global, connection, acc),
    do:
      problem(
        acc,
        connection,
        "`#{global.name}` is already driven at its element `#{element}`, by " <>
          "`#{first.instance}.#{first.member}`#{where(first)}: one connection drives each element"
      )

  defp driver(first, global, connection, acc),
    do:
      problem(
        acc,
        connection,
        "`#{global.name}` is already driven by `#{first.instance}.#{first.member}`" <>
          "#{where(first)}"
      )

  defp driven_part([array, _subscripts], element, connection, wiring),
    do: Map.put_new(wiring.parts, array, {element, connection})

  defp driven_part([_whole], _name, _connection, wiring), do: wiring.parts

  # Decision 7: every var_input is connected, to a global, a point or a constant. An
  # instance that leaves any unconnected is told them all, in the program's declaration
  # order, in one diagnostic at its line.
  defp unconnected(instances, kept, world, inputs) do
    instances
    |> Enum.with_index()
    |> Enum.filter(fn {_instance, index} -> MapSet.member?(kept, {:instance, index}) end)
    |> Enum.flat_map(fn {instance, _index} ->
      left(Map.fetch(world.runnable, instance.name), inputs)
    end)
  end

  defp left(:error, _inputs), do: []

  defp left({:ok, {instance, program}}, inputs),
    do:
      leaves(
        for(
          %Tag{section: :var_input, name: name} = tag <- declared(program),
          not Map.has_key?(inputs, {instance.name, name}),
          left <- unconnected_part(tag, instance.name, inputs),
          do: left
        ),
        instance
      )

  # M5-11: an array var_input none of whose elements is connected is left whole, and one
  # some of whose elements are, at each other element, in the elements' order.
  defp unconnected_part(%Tag{name: name, type: {:array, _type, dims}}, instance, inputs)
       when is_map_key(inputs, {:elements, instance, name}),
       do:
         for(
           index <- Logex.Array.indexes(dims),
           element = Logex.Array.name(name, index),
           not Map.has_key?(inputs, {instance, element}),
           do: element
         )

  defp unconnected_part(%Tag{name: name}, _instance, _inputs), do: [name]

  defp leaves([], _instance), do: []

  defp leaves([one], instance),
    do: [
      diagnostic(
        instance.line,
        "`#{instance.name}` leaves its var_input `#{one}` unconnected: connect it to a " <>
          "global, a point or a constant, as in `#{instance.name}.#{one} 0`"
      )
    ]

  defp leaves([first | _rest] = names, instance),
    do: [
      diagnostic(
        instance.line,
        "`#{instance.name}` leaves its var_inputs #{listed(names)} unconnected: connect " <>
          "each to a global, a point or a constant, as in `#{instance.name}.#{first} 0`"
      )
    ]

  defp declared(%Program{tags: tags}),
    do:
      tags
      |> Map.values()
      |> Enum.filter(&match?(%Tag{}, &1))
      |> Enum.sort_by(&{line_key(&1), &1.name})

  # M2-4: each instantiated program type's var_externals, in the order it declares them,
  # each bound to the global of its name and type (Ed 2 §2.4.3), and nothing written through
  # one to an input point (docs/organisation.md §4.4). Each type is checked once, at its
  # first instance, its `program` line (instances come in line order, which check/1 holds
  # them to), naming the line of the type's declaration, and of its first write, in the
  # type's own file (§4.10, M2-2's "Citing a program type"). A type given but run by no
  # instance is not checked. What each instance
  # writes through a var_external comes from Logex.Walk.writes/1, read once a type, and a
  # one-shot's storage bit, an `ons`'s or since M3-4 an `osr`'s or an `osf`'s, from
  # Logex.Walk.storage_bits/1, with its instruction: the writers the warnings name, every
  # instance of a type among them.
  defp externals(instances, world) do
    found =
      instances
      |> Enum.flat_map(&instantiated(Map.fetch(world.runnable, &1.name), &1))
      |> Enum.reduce(
        %{types: %{}, diagnostics: [], used: MapSet.new(), driving: MapSet.new(), writers: []},
        &bound(&1, &2, world)
      )

    %{found | diagnostics: Enum.reverse(found.diagnostics), writers: Enum.reverse(found.writers)}
  end

  defp instantiated({:ok, {instance, program}}, instance), do: [{instance, program}]
  defp instantiated(_not_run, _instance), do: []

  defp bound({instance, program}, found, world) do
    {facts, first} = facts(Map.fetch(found.types, instance.type), program)

    writers =
      for %Tag{name: name} = tag <- facts.externals,
          is_map_key(facts.writes, name),
          written <- written_of(tag, facts.elements),
          do: {written, name, instance, Map.get(facts.bits, written)}

    %{
      found
      | types: Map.put(found.types, instance.type, facts),
        diagnostics: checked_once(first, facts, instance, program, world) ++ found.diagnostics,
        used: Enum.reduce(facts.externals, found.used, &MapSet.put(&2, &1.name)),
        driving: Enum.reduce(writers, found.driving, &MapSet.put(&2, elem(&1, 1))),
        writers: Enum.reverse(writers, found.writers)
    }
  end

  # What a write through a var_external writes: its global, or, for an array, each element
  # the program writes, by its subscripts' values, `g[1]`, since a scan copies the array
  # in and out whole and so two instances that write different elements each keep theirs;
  # since decision 221 a write of a bit of an element is its element's, as a bit of a word
  # global is the word's.
  #
  # M5-12 (§4.12's routine choice): a write through a tag subscript, `move x g[i]`, may write
  # any element, so it is a write of the array whole, `g`, which the walk names so.
  defp written_of(%Tag{name: name, type: type}, elements)
       when is_array(type) and is_map_key(elements, name),
       do: [name]

  defp written_of(%Tag{name: name, type: type}, elements) when is_array(type),
    do: for({element, _lines} <- elements, element_of?(element, name), do: element)

  defp written_of(%Tag{name: name}, _elements), do: [name]

  defp element_of?(element, name),
    do: String.starts_with?(element, name) and binary_part(element, byte_size(name), 1) == "["

  defp facts({:ok, facts}, _program), do: {facts, false}

  defp facts(:error, program) do
    {%{
       externals: for(%Tag{section: :var_external} = tag <- declared(program), do: tag),
       writes: Walk.writes(program),
       elements: Walk.element_writes(program),
       bits:
         Map.new(Walk.storage_bits(program.rungs), fn {bit, _line, symbol} -> {bit, symbol} end)
     }, true}
  end

  defp checked_once(false, _facts, _instance, _program, _world), do: []

  defp checked_once(true, facts, instance, program, world),
    do:
      facts.externals
      |> Enum.flat_map(&binding(&1, {facts.writes, program}, world))
      |> Enum.reverse()
      |> Enum.map(&diagnostic(instance.line, &1))

  # A var_external's name is no keyword and has no `.` (Logex.Declarations), so it never
  # names a global refused for its name. It may name what a broken line declares, a
  # placeholder whose element is `:declared`, a `var_global estop boo` among them: that
  # line's diagnostic is the one mistake, and a use of its name is silent (decision 42).
  defp binding(tag, typed, world), do: bound_to(Map.get(world.names, tag.name), tag, typed, world)

  defp bound_to(nil, tag, {_writes, program}, world),
    do: [no_global(Declarations.suggest(tag.name, world.globals, & &1, "names"), tag, program)]

  defp bound_to({:global, _line, :declared}, _tag, _typed, _world), do: []

  # A global whose type is the host's mistake is refused already: one mistake, one message.
  defp bound_to({:global, _line, %Global{type: type}}, _tag, _typed, _world)
       when not is_elementary(type) and not is_array(type),
       do: []

  defp bound_to(
         {:global, _line, %Global{type: type} = global},
         %Tag{type: type} = tag,
         {writes, program},
         _world
       ),
       do: written_point(location(global.at), Map.fetch(writes, tag.name), global, {tag, program})

  defp bound_to({:global, _line, global}, tag, {_writes, program}, _world),
    do: [
      "#{declares(tag, program)}, but `#{global.name}` is #{Declarations.a_type(global.type)}#{where(global)}" <>
        exactly(conversion_of(global.type, tag.type))
    ]

  defp bound_to({kind, line, _ref}, tag, {_writes, program}, _world),
    do: [
      "#{declares(tag, program)}, but `#{tag.name}` is #{a(kind)}#{at_line(line)}, not a global"
    ]

  # M5-3 (decision 159): a var_external is its global, one copy (decision 49), so it binds
  # only to a global of exactly its type, where a connection would widen.
  defp exactly(nil), do: ""

  # M5-11 (decision 159): an array var_external binds to an array of exactly its element
  # type and every dimension's size.
  defp exactly(:array),
    do:
      ": a var_external is its global, so it is an array of exactly the global's type and " <>
        "sizes, every dimension included"

  defp exactly(_conversion),
    do: ": a var_external is its global, so its type is exactly the global's, never widened"

  defp conversion_of(from, to) when is_array(from) or is_array(to), do: :array
  defp conversion_of(from, to), do: Declarations.conversion(from, to)

  defp no_global("", tag, program),
    do:
      "#{declares(tag, program)}, but there is no global `#{tag.name}`: declare it, as in " <>
        "`var_global #{tag.name} #{written_type(tag.type)}`"

  defp no_global(suggestion, tag, program),
    do: "#{declares(tag, program)}, but there is no global `#{tag.name}`" <> suggestion

  defp written_point(
         {:ok, {_device, "i", _address}} = location,
         {:ok, [line | _]},
         global,
         {tag, program}
       ),
       do: [
         "`#{program.name}` writes its var_external `#{tag.name}`#{in_type(line, program)}, but " <>
           "`#{global.name}` is #{a_point(location, global)}#{where(global)}: nothing writes an " <>
           "input point"
       ]

  defp written_point(_location, _written, _global, _tag), do: []

  defp declares(%Tag{} = tag, program),
    do:
      "`#{program.name}` declares `var_external #{tag.name} #{written_type(tag.type)}`" <>
        in_type(tag.line, program)

  # Where in a program type's own text a line is: in its file, when it was read from one.
  defp in_type(nil, _program), do: ""
  defp in_type(line, %Program{file: nil}), do: " on its line #{line}"
  defp in_type(line, %Program{file: file}), do: " on line #{line} of `#{Path.basename(file)}`"

  # IEC requires one program at least (Ed 2 Annex B.1.7; Ed 3 Annex A). A broken
  # `program` line counts, as it was reported already, one broken before its name too.
  defp empty([], named),
    do: no_program(Enum.any?(named, &match?({:declared, _line, %{kind: :instance}}, &1)))

  defp empty(_instances, _named), do: []

  defp no_program(true), do: []

  defp no_program(false),
    do: [diagnostic(nil, "this configuration declares no `program`: it would run nothing")]

  # The warnings, which stop nothing: a task that runs no instance; a global nothing uses;
  # and an output point that something reads and nothing drives, which stays at 0. An
  # output point nothing uses is told it is unused only. A configuration that gives them
  # has no mistake, so every task and global keeps its name, and every output point its
  # address. M2-4: a var_external of an instantiated type uses its global, and a write
  # through one drives it; and the two writer warnings (decision 48), which only the IR
  # shows (§4.4).
  defp warnings({tasks, globals, instances}, wiring, externals, triggers) do
    continuous = Enum.find_value(tasks, &continuous_name/1)
    running = MapSet.new(instances, &(&1.task || continuous))
    used = wiring.used |> MapSet.union(externals.used) |> MapSet.union(triggers)

    (Enum.flat_map(tasks, &idle(MapSet.member?(running, &1.name), &1)) ++
       Enum.flat_map(globals, &doubt(MapSet.member?(used, &1.name), &1, {wiring, externals})) ++
       writers(externals.writers, wiring.driven, arrays(globals)))
    |> Enum.sort_by(&line_order/1)
  end

  # M2-4 (decision 48): each instance that writes a global through its var_external after
  # an earlier one does, in line order, is told the first; and each that writes one a
  # connection drives is told the connection. One wording is true of every writer, a latch
  # among them: each scan reads what the other last wrote, and the later write in a cycle
  # stands. An instance's own connection's copy-out comes after its scan (decision 47), so
  # it stands; and a global any writer's `ons` keeps its storage bit in is told so, in the
  # words of Logex.Warnings' storage-bit warning, whoever the other writer is, since the
  # bit is then written between that one-shot's scans: of two such instances, the one that
  # runs second never fires on the edge the first saw.
  #
  # M3-4: the bit's one-shot named, `ons`, `osr` or `osf`, that of the first writer in line
  # order whose storage bit it is. M5-11: an array global is written by element, each
  # element its own, so two instances that write different elements of one are told
  # nothing (`written_of/2`).
  defp writers(writers, driven, arrays) do
    bits =
      Enum.reduce(writers, %{}, fn
        {written, _global, _instance, symbol}, bits when symbol != nil ->
          Map.put_new(bits, written, symbol)

        _writer, bits ->
          bits
      end)

    twice =
      for {target, [first | later]} <- shared(writers, arrays),
          {instance, may} <- later,
          do: twice(target, {instance, may}, first, Map.get(bits, target))

    connected =
      for {written, global, instance, _bit} <- writers,
          {:ok, connection} <- [driven_at(driven, written, global)],
          do: connected(written, instance, connection, Map.get(bits, written))

    twice ++ connected
  end

  defp arrays(globals),
    do:
      for(
        %Global{name: name, type: type} <- globals,
        is_array(type),
        into: MapSet.new(),
        do: name
      )

  # Each thing two instances or more write through their var_externals, with its writers in
  # line order, each with whether it may write it, through a tag subscript, rather than
  # does: a global that is no array, every instance that writes it; and since decision 236
  # an element of an array global, `speeds[1]`, every instance that writes it and every
  # one that writes the array whole, through a tag subscript (M5-12), which may; and the
  # array itself, `speeds`, the instances that write it whole, of which only the later of
  # two writing it whole is told, at the array, and not again at its elements.
  defp shared(writers, arrays) do
    by_global = Enum.group_by(writers, &elem(&1, 1))

    by_global
    |> Enum.sort_by(&elem(&1, 0))
    |> Enum.flat_map(fn {global, of} -> sharing(MapSet.member?(arrays, global), global, of) end)
  end

  defp sharing(false, global, writers),
    do: [{global, for({_written, _global, instance, _bit} <- writers, do: {instance, false})}]

  defp sharing(true, global, writers) do
    wholes = for {^global, _global, instance, _bit} <- writers, do: instance

    elements =
      for {written, _global, _i, _bit} <- writers, written != global, uniq: true, do: written

    by_element =
      for element <- Enum.sort(elements),
          do:
            told(
              element,
              for(
                {written, _global, instance, _bit} <- writers,
                written in [element, global],
                do: {instance, written == global}
              )
            )

    [{global, Enum.map(wholes, &{&1, true})} | by_element]
  end

  # Where the first writer of an element writes its array whole, a later one that does so
  # too was told at the array.
  defp told(element, [{_, true} = first | later]),
    do: {element, [first | Enum.reject(later, &elem(&1, 1))]}

  defp told(element, writers), do: {element, writers}

  defp twice(global, {instance, may}, {first, first_may}, bit),
    do:
      warning(
        instance.line,
        "`#{instance.name}` #{writes(may)} `#{global}` through its var_external, as " <>
          "`#{first.name}` #{does(first_may)}#{where(first)}: " <> stands(bit, global)
      )

  defp writes(false), do: "writes"
  defp writes(true), do: "may write"

  defp does(false), do: "does"
  defp does(true), do: "may"

  # Decision 223: an element a var_external writes is driven where a connection drives it or
  # its array whole; and since M5-12 an array written whole where a connection drives it or
  # any of its elements, the first in line order.
  defp driven_at(driven, global, global),
    do: or_element(Map.fetch(driven, global), driven, global)

  defp driven_at(driven, written, global),
    do: or_whole(Map.fetch(driven, written), driven, global)

  defp or_whole(:error, driven, global), do: Map.fetch(driven, global)
  defp or_whole(found, _driven, _global), do: found

  defp or_element(:error, driven, global) do
    elements =
      for {name, connection} <- driven, element_of?(name, global), do: connection

    first_connection(Enum.sort_by(elements, & &1.line))
  end

  defp or_element(found, _driven, _global), do: found

  defp first_connection([]), do: :error
  defp first_connection([connection | _]), do: {:ok, connection}

  defp connected(global, instance, %Connection{instance: name} = connection, bit),
    do:
      warning(
        instance.line,
        "`#{instance.name}` writes `#{global}` through its var_external, and " <>
          "#{own(name == instance.name)}`#{name}.#{connection.member}` " <>
          "#{drives(connection.to, global)}#{where(connection)}: " <>
          driven_stands(bit, name == instance.name, global)
      )

  # M5-12's review: a connection that drives an element of the array written, or the array
  # an element written is of, is told what it drives, `ins[2]`, as written.
  defp drives(global, global), do: "drives it"
  defp drives(to, _global), do: "drives `#{to}`"

  defp own(true), do: "its own "
  defp own(false), do: ""

  defp driven_stands(nil, true, _global), do: "its own copy-out, after the scan, stands"
  defp driven_stands(bit, _own, global), do: stands(bit, global)

  defp stands(nil, _global),
    do: "each scan reads what the other last wrote, and the later write in a cycle stands"

  # `ons`, `osr` and `osf` are each said letter by letter, "an".
  defp stands(one_shot, global),
    do:
      "`#{global}` is the storage bit of an `#{one_shot}`: the one-shot then fires on the " <>
        "wrong scans"

  # M2-6 (§4.6's caveat; §4.10, M2-6): each timer an instance an event task runs runs,
  # at any depth, a block's by its path, at the instance's line. A ton counts the time
  # between two of the task's runs where its rung was true on both, which only the
  # configuration knows is irregular, whether the task has a single alone or an interval
  # too. Each program type's timers are read once (Logex.Walk.timers/1), and each warning
  # cites its `ton` in the text it is in; since M3-1 its counters so too, and since M3-4
  # its one-shots (Logex.Walk.counters/1 and one_shots/1; decisions 72 and 103).
  defp timed(world) do
    events =
      for {name, {:task, _line, %Logex.Configuration.Task{single: single}}} <- world.names,
          is_binary(single),
          into: MapSet.new(),
          do: name

    world.runnable
    |> Map.values()
    |> Enum.filter(fn {instance, _program} -> MapSet.member?(events, instance.task) end)
    |> Enum.flat_map_reduce(%{}, fn {instance, program}, memo ->
      {timers, memo} = timers_of(Map.fetch(memo, program.name), program, memo)
      {Enum.map(timers, &timer_warning(&1, instance, program)), memo}
    end)
    |> elem(0)
  end

  defp timers_of({:ok, timers}, _program, memo), do: {timers, memo}

  # Each timer, then each counter (M3-1, decision 72), then each one-shot (M3-4, decision
  # 103), with its citation, built once a program type: the routines down each path are
  # read through a table of their typed tags, each routine's built once.
  defp timers_of(:error, %Program{name: name} = program, memo) do
    {timers, tables} = citing(Walk.timers(program), :timer, program, %{})
    {counters, tables} = citing(Walk.counters(program), :counter, program, tables)
    {one_shots, _tables} = citing(Walk.one_shots(program), :one_shot, program, tables)
    runs = timers ++ counters ++ one_shots
    {runs, Map.put(memo, name, runs)}
  end

  # Each with its word, read in the routine whose text holds it (M3-2): a timer's or a
  # counter's type word, and a one-shot's mnemonic.
  defp citing(runs, kind, program, tables),
    do:
      runs
      |> Enum.sort()
      |> Enum.map_reduce(tables, fn {path, {line, run}}, tables ->
        parts = String.split(path, ".")
        {holder, tables} = holder(parts, {:program, program}, tables)
        {word, tables} = word(kind, run, List.last(parts), holder, tables)
        {{kind, path, cited(line, holder), word}, tables}
      end)

  defp word(:one_shot, symbol, _name, _holder, tables), do: {Atom.to_string(symbol), tables}

  defp word(_built_in, _preset, name, holder, tables) do
    {typed, tables} = typed_tags(Map.fetch(tables, key(holder)), holder, tables)
    %Tag{type: %FbType{name: word}} = Map.fetch!(typed, name)
    {word, tables}
  end

  # M3-2: in the words of the timer's own type.
  defp timer_warning({:timer, path, cited, word}, instance, program),
    do:
      warning(
        instance.line,
        "`#{instance.name}` runs under the event task `#{instance.task}`, and " <>
          "`#{program.name}` runs the timer `#{path}`#{cited}: " <>
          across(FbType.family(FbType.builtin(word)), Declarations.a_or_an(word))
      )

  # M3-1 (decision 72): a counter sees its rung only at the task's runs, so an edge that
  # comes and goes between two is never counted, and one whose rung is the task's own
  # trigger is true at every run and never counts at all.
  defp timer_warning({:counter, path, cited, _word}, instance, program),
    do:
      warning(
        instance.line,
        "`#{instance.name}` runs under the event task `#{instance.task}`, and " <>
          "`#{program.name}` runs the counter `#{path}`#{cited}" <>
          ": a counter sees its rung only at the task's runs, so a pulse between two runs " <>
          "is never counted, and a rung that is the task's trigger is true at every run " <>
          "and never counts"
      )

  # M3-4 (decision 103, as the maintainer answered it): a one-shot sees its rung only at
  # the task's runs, so an edge between two runs is never seen, and a rung that is the
  # task's own trigger is true at every run and gives none; a coil's pulse bit stays on
  # until the task's next run. Each is said letter by letter, "an".
  defp timer_warning({:one_shot, path, cited, word}, instance, program),
    do:
      warning(
        instance.line,
        "`#{instance.name}` runs under the event task `#{instance.task}`, and " <>
          "`#{program.name}` runs an `#{word}`#{cited}, whose storage bit is `#{path}`: " <>
          sees(word)
      )

  defp sees("ons"),
    do:
      "an ons sees its rung only at the task's runs, so a pulse between two runs never " <>
        "fires it, and a rung that is the task's trigger is true at every run and never " <>
        "fires it"

  defp sees("osr"),
    do:
      "an osr sees its rung only at the task's runs, so a pulse between two runs is never " <>
        "seen, the pulse it sets stays on until the task's next run, and a rung that is the " <>
        "task's trigger is true at every run and never pulses"

  defp sees("osf"),
    do:
      "an osf sees its rung only at the task's runs, so a drop between two runs is never " <>
        "seen, the pulse it sets stays on until the task's next run, and a rung that is the " <>
        "task's trigger is true at every run and never pulses"

  # Since M5-6 by the timer's kind, its `family`, in its own words: a `ton_ltime`'s as a
  # `ton`'s, "a ton_ltime times across the task's runs" (decision 158).
  defp across("ton", a_word),
    do:
      "#{a_word} times across the task's runs, and one whose rung is true on two runs in a " <>
        "row counts the whole time between them"

  # M3-2: a tof's delay ends only at a run, which may be long after its preset.
  defp across("tof", a_word),
    do:
      "#{a_word}'s delay ends only at one of the task's runs, so what it holds on stays on " <>
        "until the first run after its preset has passed"

  # M3-2: an rto adds the time between two runs whose rung is true, as a ton counts it.
  defp across("rto", a_word),
    do:
      "#{a_word} times across the task's runs, and one whose rung is true on two runs in a " <>
        "row adds the whole time between them"

  # M3-2: a tp's pulse ends only at a run, and it sees an edge only between two runs.
  defp across("tp", a_word),
    do:
      "#{a_word}'s pulse ends only at one of the task's runs, so it lasts until the first " <>
        "run after its preset has passed, and it starts only on an edge between two runs: a " <>
        "rung that is the task's trigger is true at every run and never starts one"

  # The routine whose text holds a timer: the program's, or a block's body down its path,
  # each routine's typed tags read once, by the routine (`:program`, or its block's name,
  # one version a name in a program's table).
  defp holder([_timer], routine, tables), do: {routine, tables}

  defp holder([instance | rest], routine, tables) do
    {typed, tables} = typed_tags(Map.fetch(tables, key(routine)), routine, tables)
    %Tag{type: %FbType{body: body}} = Map.fetch!(typed, instance)
    holder(rest, {:block, body}, tables)
  end

  defp typed_tags({:ok, typed}, _routine, tables), do: {typed, tables}

  defp typed_tags(:error, {_kind, body} = routine, tables) do
    typed = Program.typed_tags(body)
    {typed, Map.put(tables, key(routine), typed)}
  end

  defp key({:program, _program}), do: :program
  defp key({:block, %Program{name: name}}), do: {:block, name}

  # A block's timer is cited in its block's own text: its file, or, read from no file, the
  # block by name, since "its line" would read as the program's.
  defp cited(line, {:program, program}), do: in_type(line, program)

  defp cited(line, {:block, %Program{file: nil, name: name}}),
    do: " on line #{line} of block `#{name}`"

  defp cited(line, {:block, body}), do: in_type(line, body)

  # M4-2: the continuous task runs every instance no timed task runs, those with no `with`
  # among them, so it runs none only where every instance has a timed task.
  defp continuous_name(%{continuous: true, name: name}), do: name
  defp continuous_name(_timed), do: nil

  defp idle(true, _task), do: []
  defp idle(false, task), do: [warning(task.line, "task `#{task.name}` runs no instance")]

  defp doubt(false, global, _seen),
    do: [warning(global.line, "`#{global.name}` is declared but nothing uses it")]

  # M5-13: an array of output points driven element by element is told the elements
  # nothing drives, each at 0; one a connection drives whole, or a program writes through
  # its var_external, is driven (provisional).
  defp doubt(true, %Global{type: {:array, _type, dims}, at: at} = global, {wiring, externals})
       when at != nil,
       do:
         elements_undriven(
           output_point?(location(at)) and not Map.has_key?(wiring.driven, global.name) and
             not MapSet.member?(externals.driving, global.name),
           global,
           dims,
           wiring
         )

  defp doubt(true, global, {wiring, externals}),
    do:
      undriven(
        output_point?(location(global.at)) and not Map.has_key?(wiring.driven, global.name) and
          not MapSet.member?(externals.driving, global.name),
        global
      )

  defp output_point?({:ok, {_device, "q", _fields}}), do: true
  defp output_point?(_location), do: false

  defp elements_undriven(false, _global, _dims, _wiring), do: []

  defp elements_undriven(true, global, dims, wiring),
    do:
      undriven_elements(
        for(
          index <- Logex.Array.indexes(dims),
          name = Logex.Array.name(global.name, index),
          not Map.has_key?(wiring.driven, name),
          do: name
        ),
        Logex.Array.size(dims),
        global
      )

  defp undriven_elements([], _size, _global), do: []

  defp undriven_elements(names, size, global) when length(names) == size,
    do: [
      warning(
        global.line,
        "`#{global.name}` is #{a_point(location(global.at), global)}, but nothing drives " <>
          "it: each element stays at 0"
      )
    ]

  defp undriven_elements(names, _size, global),
    do: [
      warning(
        global.line,
        "`#{global.name}` is #{a_point(location(global.at), global)}, but nothing drives " <>
          "#{elements_listed(names)}: #{it_they(names)} at 0"
      )
    ]

  defp elements_listed(names) when length(names) > 10,
    do: Enum.map_join(Enum.take(names, 10), ", ", &"`#{&1}`") <> " and #{length(names) - 10} more"

  defp elements_listed([one]), do: "`#{one}`"

  defp elements_listed(names) do
    {rest, [last]} = Enum.split(names, -1)
    Enum.map_join(rest, ", ", &"`#{&1}`") <> " or `#{last}`"
  end

  defp it_they([_one]), do: "it stays"
  defp it_they(_names), do: "they stay"

  defp undriven(false, _global), do: []

  defp undriven(true, global),
    do: [
      warning(
        global.line,
        "`#{global.name}` is an output point, but nothing drives it: it stays at 0"
      )
    ]

  defp warning(line, message),
    do: %Diagnostic{stage: :configure, line: line, message: message, severity: :warning}
end
