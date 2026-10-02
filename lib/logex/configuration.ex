defmodule Logex.Configuration do
  @moduledoc """
  A configuration: the program types it runs, its tasks, its globals, its program
  instances and the connections that wire them (M2-1, `docs/organisation.md` §4.4). A
  value, plain data, which `Logex.Runtime.start/1` runs as one resource.

  - `programs` maps each program type's name to its `%Logex.Program{}`.
  - `tasks`, `globals`, `instances` and `connections` are lists, in declaration order, of
    `Logex.Configuration.Task`, `Logex.Configuration.Global`,
    `Logex.Configuration.Instance` and `Logex.Configuration.Connection`. The order of
    `instances` is the execution order within a task.
  - `name` is the configuration's own name, which it must have. `file` is the file it was
    read from, or nil for one built from Elixir; each element's `line` likewise, and
    `new!/1` refuses an element that brings one.
  - `warnings` are `%Logex.Diagnostic{severity: :warning}`. No check gives one yet, so it
    is empty.

  Every way of writing a configuration ends in `check/1`, the one validator: `new!/1`,
  from Elixir, raises one `ArgumentError` listing every problem it finds, a line each, and
  `Logex.Runtime.start/1` checks again. A mistake a configuration's text could also make
  is a `%Logex.Diagnostic{}` at stage `:configure`, cited at its element's line, which is
  how a reader of the text will cite it. Its rules:

  - every name of a task, global or program instance is a name, as a tag's is, and no two
    of them are the same or differ only in case: one namespace, in which the first in
    line order keeps a name. A program type is named in type position only, so an
    instance may share its type's name;
  - a task's interval is 1 to 2147483647 ms, and its priority 0, the highest, to 65535
    (decision 37);
  - a global's initial value fits its type, and a located global takes none; a location
    is `<device>.i.<address>` for an input point or `<device>.q.<address>` for an output
    point, its device a name, its address one or more whole numbers with no leading zero,
    the leftmost the highest level; and one address holds one global;
  - a program instance names a program and, if it has one, a task;
  - a connection names a var_input or a var_output of an instance. A var_input is
    connected once, to a global of its type or a constant that fits it; a var_output to a
    global of its type, never an input point, and one connection at most drives a
    global. Every var_input is connected (decision 7);
  - a configuration runs at least one program instance.

  A mistake no configuration text can make is the host's, and `check/1` raises it as one
  `ArgumentError`, every such mistake a line each (decision 36), as
  `Logex.Compiler.instructionize/2` raises on a tree no source could say: a configuration
  whose name is not a name, or whose file is neither a string nor nil; programs that are
  not a map of names to `%Logex.Program{}`, each under its own name, one of them a
  function block type among them; a field that is not a proper list of its element
  struct; a line that is not a positive integer or nil; lines that are neither all nil,
  as from Elixir, nor rising in each list, one element a line, as a file's are; a name,
  a location, a type or a task that the lexer does not read as one name token; a number
  that is not an integer of 0 or more, since a negative literal does not lex yet
  (`PLAN.md` §5); a global's type that is neither `:bool` nor `:dint`; and a connection's
  instance that is not a name, or with its member makes no one path.

  Each list of names a diagnostic ends with is given once, by the first diagnostic in
  line order that needs it, so a refusal is linear in its size. Its time is not: each
  unknown name is matched against every name for a did-you-mean, so a refusal of many bad
  names among many names takes time quadratic in the two, as the `.ld` compiler's
  refusals do. Only a mistake pays it.
  """

  alias Logex.{Declarations, Diagnostic, FbType, Program, Tag}
  alias Logex.Configuration.{Connection, Global, Instance}

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
    A periodic task: `name`, `interval` in ms and `priority`, 0 the highest, to 65535.
    Its instances run once in every cycle in which it is due, every `interval` ms from the
    start, in the order of the configuration's `instances` (`Logex.Runtime`).
    """
    @enforce_keys [:name, :interval, :priority]
    defstruct [:name, :interval, :priority, line: nil]

    @type t :: %__MODULE__{
            name: String.t(),
            interval: pos_integer,
            priority: 0..65_535,
            line: pos_integer | nil
          }
  end

  defmodule Global do
    @moduledoc """
    A global: `name`, `type` (`:bool` or `:dint`), an `initial` value or nil for 0, and
    `at`, a location such as `"panel.i.0"`, or nil. A global located at an `i` address is
    an input point, set by the host; one at a `q` address an output point, given back to
    the host after every cycle.
    """
    @enforce_keys [:name, :type]
    defstruct [:name, :type, initial: nil, at: nil, line: nil]

    @type t :: %__MODULE__{
            name: String.t(),
            type: :bool | :dint,
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
  @lines ": a configuration's lines are all nil, as from Elixir, or rise in each list, " <>
           "one element a line"

  @doc """
  A configuration built from Elixir: `name:`, which it needs, `programs:` (a list of
  `%Logex.Program{}`), `tasks:`, `globals:`, `instances:` and `connections:`, each a list
  of its element struct with no `line`, the rest optional. Checked by `check/1`: the
  configuration, or one `ArgumentError` with every problem, a line each: its own, then the
  host's mistakes `check/1` raises, then `check/1`'s diagnostics, formatted.
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

    {mistakes, diagnostics} = problems(config)

    raised(
      fields(fields) ++
        problems ++
        Enum.reverse(lined) ++ mistakes ++ Enum.map(diagnostics, &Diagnostic.format/1),
      config
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

  defp unline(%module{line: line} = item, {items, lined})
       when module in [Logex.Configuration.Task, Global, Instance, Connection] and line != nil,
       do:
         {[%{item | line: nil} | items],
          ["#{describe(item)} from Elixir has no line, got: #{inspect(line)}" | lined]}

  defp unline(item, {items, lined}), do: {[item | items], lined}

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
  The one validator: every problem with `config`, a `%Logex.Diagnostic{}` at stage
  `:configure` each, cited at its element's line in the configuration's `file`, in line
  order, a problem with no line last. `[]` for a configuration that runs.

  A configuration no configuration text can say, the host's mistake, raises one
  `ArgumentError` instead, each such mistake a line of its message (decision 36; the
  moduledoc lists them).
  """
  def check(%__MODULE__{} = config) do
    {mistakes, diagnostics} = problems(config)
    checked(mistakes, diagnostics)
  end

  def check(other),
    do: raise(ArgumentError, "expected a %Logex.Configuration{}, got: #{inspect(other)}")

  defp checked([], diagnostics), do: diagnostics
  defp checked(mistakes, _diagnostics), do: raise(ArgumentError, Enum.join(mistakes, "\n"))

  # Every problem with a configuration, of two kinds: the host's mistakes, which no
  # configuration text can make, each a line of an ArgumentError's message; and the
  # diagnostics, each a mistake a text could make too. A field that is a host's mistake is
  # left out of every diagnostic, so one mistake is one message.
  defp problems(config) do
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

    {mistakes, diagnostics(config, {file, programs}, {tasks, globals, instances, connections})}
  end

  defp diagnostics(config, {file, programs}, {tasks, globals, instances, connections}) do
    # Every instance declared under a name, whether or not it keeps the name: the
    # connections of one that cannot run are not checked, and only a name is suggested.
    declared =
      for %Instance{name: name} <- instances,
          Declarations.name?(name),
          into: MapSet.new(),
          do: name

    {named, d_names} = namespace(tasks ++ globals ++ instances)
    tasks = for %Logex.Configuration.Task{} = task <- named, do: task
    globals = for %Global{} = global <- named, do: global
    instances = for %Instance{} = instance <- named, do: instance
    {globals_by_name, d_located} = located(Enum.sort_by(globals, &line_key/1))
    tasks_by_name = Map.new(tasks, &{&1.name, &1})
    {runnable, d_runs} = runs(instances, {programs, given(config.programs)}, tasks_by_name)

    d_wiring =
      wiring(Enum.sort_by(connections, &line_key/1), {runnable, declared}, globals_by_name)

    [
      d_names,
      Enum.flat_map(tasks, &task/1),
      Enum.flat_map(globals, &global/1),
      d_located,
      d_runs,
      d_wiring,
      empty(config.instances)
    ]
    |> Enum.concat()
    |> Enum.sort_by(&line_order/1)
    |> Enum.map_reduce(MapSet.new(), &listed_once/2)
    |> elem(0)
    |> Enum.map(&%{&1 | file: file})
  end

  # Each list of names a diagnostic would end with is given once, by the first diagnostic
  # in line order that needs it, so that n connections to unknown globals among n globals
  # make n short diagnostics, not n lists of n names. A diagnostic that needs a list holds
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

  defp program(key, %FbType{name: name}, ok, mistakes),
    do: {ok, [block_type(key, name) | mistakes]}

  defp program(key, other, ok, mistakes),
    do:
      {ok,
       [
         "the program under #{label(key)} is not a %Logex.Program{} from " <>
           "Logex.compile/2, got: #{inspect(other)}"
         | mistakes
       ]}

  # A function block type runs inside a program, never as one. The words are interim:
  # M2-5 says how one runs there.
  defp block_type(name, name),
    do:
      "#{label(name)} is a function block type, which runs inside a program: an instance " <>
        "is of a %Logex.Program{}"

  defp block_type(key, name),
    do:
      "the program under #{label(key)} is #{label(name)}, a function block type, which runs " <>
        "inside a program: an instance is of a %Logex.Program{}"

  defp program_shaped(true, %Program{name: name} = program, ok, mistakes),
    do: {Map.put(ok, name, program), mistakes}

  defp program_shaped(false, %Program{name: name}, ok, mistakes),
    do: {ok, Enum.reverse(shaped(false, name, "a program"), mistakes)}

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

  defp element(%{__struct__: module} = item, acc, module), do: line(item, acc)

  defp element(other, {items, good, mistakes}, module),
    do:
      {items, good,
       ["#{one(module)} is a %#{inspect(module)}{}, got: #{inspect(other)}" | mistakes]}

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
  # a location that is not one name token to the lexer; a number that is not an integer
  # of 0 or more, since no negative literal lexes yet; a global's type that is neither
  # :bool nor :dint, the type words a line has; and a connection's instance that is not a
  # name, or with its member no one path, as a line writes the two as one token. Each
  # such field is left out of the diagnostics.
  defp said(%Logex.Configuration.Task{name: name} = task),
    do:
      named(task) ++
        counted(task.interval, interval_rule(name)) ++ counted(task.priority, priority_rule(name))

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

  defp counted(value, _rule) when value == nil or (is_integer(value) and value >= 0), do: []
  defp counted(value, rule), do: [rule <> ", found #{inspect(value)}"]

  defp interval_rule(name), do: "task #{label(name)}: an interval is 1 to 2147483647 ms"
  defp priority_rule(name), do: "task #{label(name)}: a priority is 0, the highest, to 65535"

  defp global_type(%Global{type: type}) when type in [:bool, :dint], do: []

  defp global_type(%Global{name: name, type: type}),
    do: ["global #{label(name)} has type #{inspect(type)}: a global is :bool or :dint"]

  defp global_initial(%Global{initial: initial})
       when initial == nil or (is_integer(initial) and initial >= 0),
       do: []

  defp global_initial(%Global{name: name, initial: initial}) when is_integer(initial),
    do: [
      "global #{label(name)} has the initial value `#{initial}`, which is negative: " <>
        "no line can say one until a negative literal lexes"
    ]

  defp global_initial(%Global{name: name, initial: initial}),
    do: [
      "the initial value of global #{label(name)} must be an integer, found #{inspect(initial)}"
    ]

  defp global_at(%Global{at: nil}), do: []
  defp global_at(%Global{at: at} = global), do: of_word(word?(at), not_a_location(global))

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
        "a global, by name, or a constant of 0 or more"

  # What a connection's other end is: a global's name, a constant, or the host's mistake.
  defp other_end(to) when is_integer(to) and to >= 0, do: :constant
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

  # One namespace for tasks, globals and program instances (decided here, not in IEC): the
  # first to take a name keeps it, in line order, and a case-only twin is refused as tags'
  # are, since a name differing only in case would be read as the same one. A program type
  # is named in type position only, so `program motor motor` is not a clash. A name with
  # `.` parts, which a line can hold, is no name; one the lexer does not read as one token
  # is the host's mistake, refused already.
  defp namespace(elements) do
    {named, _folded, problems} =
      elements
      |> Enum.sort_by(&line_key/1)
      |> Enum.reduce({[], %{}, []}, &take_name/2)

    {Enum.reverse(named), Enum.reverse(problems)}
  end

  defp line_key(%{line: nil}), do: {1, 0}
  defp line_key(%{line: line}), do: {0, line}

  defp take_name(%{name: name} = element, acc),
    do: name_shaped({Declarations.name?(name), word?(name)}, element, acc)

  defp name_shaped({true, _word}, %{name: name} = element, {named, folded, problems}) do
    key = String.downcase(name)
    taken(Map.get(folded, key), element, key, {named, folded, problems})
  end

  defp name_shaped({false, true}, element, {named, folded, problems}),
    do: {named, folded, [diagnostic(element.line, cannot_name(element)) | problems]}

  defp name_shaped({false, false}, _element, acc), do: acc

  defp taken(nil, element, key, {named, folded, problems}),
    do: {[element | named], Map.put(folded, key, element), problems}

  defp taken(%{name: name} = first, %{name: name} = element, _key, {named, folded, problems}),
    do:
      {named, folded,
       [
         diagnostic(
           element.line,
           "`#{name}` is already the name of a #{kind(first)}#{where(first)}: " <>
             "tasks, globals and program instances share one namespace"
         )
         | problems
       ]}

  defp taken(first, element, _key, {named, folded, problems}),
    do:
      {named, folded,
       [
         diagnostic(
           element.line,
           "`#{element.name}` and the #{kind(first)} `#{first.name}`#{where(first)} differ " <>
             "only in case: names are case-sensitive, so these would be two names"
         )
         | problems
       ]}

  defp task(%Logex.Configuration.Task{} = task),
    do: interval(task) ++ priority(task)

  # An interval or a priority a line can hold, an integer of 0 or more or none, is a
  # diagnostic outside its range; anything else was the host's mistake.
  defp interval(%{interval: interval}) when is_integer(interval) and interval in @interval,
    do: []

  defp interval(%{name: name, interval: interval, line: line})
       when interval == nil or (is_integer(interval) and interval >= 0),
       do: [diagnostic(line, interval_rule(name) <> ", found #{inspect(interval)}")]

  defp interval(_task), do: []

  defp priority(%{priority: priority}) when is_integer(priority) and priority in @priority,
    do: []

  defp priority(%{name: name, priority: priority, line: line})
       when priority == nil or (is_integer(priority) and priority >= 0),
       do: [diagnostic(line, priority_rule(name) <> ", found #{inspect(priority)}")]

  defp priority(_task), do: []

  defp global(%Global{type: type} = global) when type in [:bool, :dint],
    do: initial(global, location(global.at))

  defp global(%Global{}), do: []

  # A located global takes no initial value: an input point's value is the host's, and an
  # output point starts at 0, the safe value, until the instance that drives it first
  # scans.
  defp initial(%Global{initial: nil}, _location), do: []

  defp initial(%Global{initial: v}, _location) when not is_integer(v) or v < 0, do: []

  defp initial(%Global{name: name, line: line}, {:ok, {_device, "i", _address}}),
    do: [
      diagnostic(
        line,
        "global `#{name}` is an input point: its value comes from outside, " <>
          "so it takes no initial value"
      )
    ]

  defp initial(%Global{name: name, line: line}, {:ok, {_device, "q", _address}}),
    do: [
      diagnostic(
        line,
        "global `#{name}` is an output point: it starts at 0 and takes its value from the " <>
          "instance that drives it, so it takes no initial value"
      )
    ]

  defp initial(%Global{type: type, name: name, initial: v, line: line}, _location),
    do: fit(Declarations.fits?(type, v), type, v, "global `#{name}`", line)

  defp fit(true, _type, _v, _what, _line), do: []

  defp fit(false, :bool, v, what, line),
    do: [diagnostic(line, "#{what} is a bool: its initial value must be 0 or 1, found `#{v}`")]

  defp fit(false, :dint, v, what, line),
    do: [diagnostic(line, "#{what} is a dint: `#{v}` does not fit in 32 bits")]

  @doc """
  A global's value before anything sets it: its `initial`, or 0 without one, so that an
  input point and an output point start at 0.

  The one rule for a new global (`docs/organisation.md` §4.9), as
  `Logex.Program.initial_env/1` is for a tag: `Logex.Runtime.start/1` starts every global
  by it, `Logex.Runtime.restart/2` every global but an input point, whose value it keeps,
  and an online edit of a configuration (OE-2) is to start each global it adds by it. The
  edit's exceptions, for a global the resource already holds: a kept global keeps
  its value until a restart, a changed `initial` included; an input or output point is
  neither added nor removed while running, located I/O being refused then; and an output
  point that no connection drives any more holds its value, as an output an edit leaves
  undriven does (decision 20).

      iex> Logex.Configuration.initial(%Logex.Configuration.Global{name: "sp", type: :dint, initial: 1200})
      1200
      iex> Logex.Configuration.initial(%Logex.Configuration.Global{name: "x", type: :bool, at: "panel.i.0"})
      0
  """
  def initial(%Global{initial: nil}), do: 0
  def initial(%Global{initial: initial}) when is_integer(initial), do: initial

  def initial(other),
    do:
      raise(
        ArgumentError,
        "expected a %Logex.Configuration.Global{} whose initial value is an integer or nil, " <>
          "got: #{inspect(other)}"
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

  defp located_word(true, at), do: address(String.split(at, "."))
  defp located_word(false, _at), do: :error

  defp address([device, io | fields]) when io in ["i", "q"] and fields != [],
    do: numbers(fields, [], device, io)

  defp address(_parts), do: :error

  defp numbers([], numbers, device, io), do: {:ok, {device, io, Enum.reverse(numbers)}}

  defp numbers([field | rest], numbers, device, io),
    do: number(Integer.parse(field), field, rest, numbers, device, io)

  # A field is digits with no leading zero, so each address has one spelling, and two
  # globals at one address have the same string.
  defp number({n, ""}, <<digit, _::binary>>, rest, numbers, device, io) when digit in ?1..?9,
    do: numbers(rest, [n | numbers], device, io)

  defp number({0, ""}, "0", rest, numbers, device, io),
    do: numbers(rest, [0 | numbers], device, io)

  defp number(_parsed, _field, _rest, _numbers, _device, _io), do: :error

  # The globals by name, and a diagnostic for each location that is not one, and each
  # address a second global takes. A location the lexer does not read as one token is the
  # host's mistake, refused already.
  defp located(globals) do
    {_by_address, problems} =
      Enum.reduce(globals, {%{}, []}, fn global, acc -> at(global, location(global.at), acc) end)

    {Map.new(globals, &{&1.name, &1}), Enum.reverse(problems)}
  end

  defp at(%Global{at: nil}, _location, acc), do: acc

  defp at(%Global{at: at} = global, :error, acc), do: not_located(word?(at), global, acc)

  defp at(%Global{} = global, {:ok, address}, {taken, problems}),
    do: address_taken(Map.get(taken, address), global, address, {taken, problems})

  defp not_located(true, global, {taken, problems}),
    do: {taken, [diagnostic(global.line, not_a_location(global)) | problems]}

  defp not_located(false, _global, acc), do: acc

  defp not_a_location(global),
    do:
      "global #{label(global.name)} is at #{label(global.at)}, which is not a location: " <>
        "a location is a device, `i` for an input or `q` for an output, then an " <>
        "address, as in `panel.i.0` or `panel.q.3`"

  defp address_taken(nil, global, address, {taken, problems}),
    do: {Map.put(taken, address, global), problems}

  defp address_taken(first, global, _address, {taken, problems}),
    do:
      {taken,
       [
         diagnostic(
           global.line,
           "global `#{global.name}` is at `#{global.at}`, the address of global " <>
             "`#{first.name}`#{where(first)}: one address holds one global"
         )
         | problems
       ]}

  # The instances that can run, each with its program, and what is wrong with the rest.
  defp runs(instances, programs, tasks) do
    {runnable, problems} =
      Enum.reduce(instances, {%{}, []}, fn instance, {runnable, problems} ->
        run(instance, programs, tasks, {runnable, problems})
      end)

    {runnable, Enum.reverse(problems)}
  end

  defp run(%Instance{type: type} = instance, programs, tasks, acc),
    do: run_typed(word?(type), instance, programs, tasks, acc)

  defp run_typed(true, instance, programs, tasks, acc),
    do: typed(Map.fetch(elem(programs, 0), instance.type), instance, programs, tasks, acc)

  defp run_typed(false, instance, _programs, tasks, acc), do: on_task(instance, tasks, acc)

  defp typed({:ok, program}, instance, _programs, tasks, {runnable, problems}),
    do:
      on_task(instance, tasks, {Map.put(runnable, instance.name, {instance, program}), problems})

  # A program given under this name but refused has its own message, and an instance of it
  # cannot run: one mistake, one message.
  defp typed(:error, instance, {programs, given}, tasks, acc),
    do: unknown_type(MapSet.member?(given, instance.type), instance, programs, tasks, acc)

  defp unknown_type(true, instance, _programs, tasks, acc), do: on_task(instance, tasks, acc)

  defp unknown_type(false, instance, programs, tasks, {runnable, problems}) do
    names = Enum.sort(Map.keys(programs))

    message =
      hint(
        "program instance `#{instance.name}`: there is no program `#{instance.type}`",
        Declarations.suggest(instance.type, names, & &1, "names"),
        names,
        "programs"
      )

    on_task(instance, tasks, {runnable, [diagnostic(instance.line, message) | problems]})
  end

  defp on_task(%Instance{task: nil}, _tasks, acc), do: acc

  defp on_task(%Instance{task: task} = instance, tasks, acc),
    do: task_word(word?(task), instance, tasks, acc)

  defp task_word(true, instance, tasks, acc),
    do: task_known(Map.has_key?(tasks, instance.task), instance, tasks, acc)

  defp task_word(false, _instance, _tasks, acc), do: acc

  defp task_known(true, _instance, _tasks, acc), do: acc

  defp task_known(false, instance, tasks, {runnable, problems}) do
    names = Enum.sort(Map.keys(tasks))

    message =
      hint(
        "program instance `#{instance.name}`: there is no task `#{instance.task}`",
        Declarations.suggest(instance.task, names, & &1, "names"),
        names,
        "tasks"
      )

    {runnable, [diagnostic(instance.line, message) | problems]}
  end

  defp hint(message, "", [], noun), do: message <> ": this configuration has no #{singular(noun)}"

  defp hint(message, "", names, noun),
    do: {message, noun, fn -> ": the #{noun} are " <> listed(names) end}

  defp hint(message, suggestion, _names, _noun), do: message <> suggestion

  defp singular("programs"), do: "program"
  defp singular("tasks"), do: "task"
  defp singular("program instances"), do: "program instance"
  defp singular("globals"), do: "global"

  defp listed(names) do
    quoted = Enum.map(names, &"`#{&1}`")
    listing(Enum.drop(quoted, -1), List.last(quoted))
  end

  defp listing([], last), do: last
  defp listing(rest, last), do: Enum.join(rest, ", ") <> " and " <> last

  # The connections, each checked against its instance's program and the globals, then
  # every var_input checked to be connected (decision 7). One problem is reported per
  # connection, the first; a var_input with a connection, good or bad, counts as
  # connected, and a global as driven only by a good one, so one mistake is one message.
  # A connection whose instance or member is the host's mistake is refused already.
  defp wiring(connections, {runnable, _declared} = instances, globals) do
    {inputs, _driven, problems} =
      Enum.reduce(connections, {%{}, %{}, []}, &connect(&1, &2, instances, globals))

    Enum.reverse(problems) ++ unconnected(runnable, inputs)
  end

  defp connect(%Connection{} = connection, acc, instances, globals),
    do: connect_ends(ends?(connection), connection, acc, instances, globals)

  # An instance that is declared but cannot run, its program unknown, has its own
  # diagnostic, and its connections are not checked.
  defp connect_ends(true, connection, acc, {runnable, declared}, globals),
    do:
      of_instance(
        Map.fetch(runnable, connection.instance),
        MapSet.member?(declared, connection.instance),
        connection,
        acc,
        {declared, globals}
      )

  defp connect_ends(false, _connection, acc, _instances, _globals), do: acc

  defp of_instance({:ok, {_instance, program}}, true, connection, acc, {_declared, globals}),
    do: of_member(member_of(program, connection.member), program, connection, acc, globals)

  defp of_instance(:error, true, _connection, acc, _known), do: acc

  defp of_instance(:error, false, connection, {inputs, driven, problems}, {declared, _globals}) do
    names = Enum.sort(MapSet.to_list(declared))

    message =
      hint(
        "`#{connection.instance}.#{connection.member}`: there is no program instance " <>
          "`#{connection.instance}`",
        Declarations.suggest(connection.instance, names, & &1, "names"),
        names,
        "program instances"
      )

    {inputs, driven, [diagnostic(connection.line, message) | problems]}
  end

  defp member_of(%Program{tags: tags}, member), do: Map.fetch(tags, member)

  defp of_member({:ok, %Tag{section: :var_input} = tag}, _program, connection, acc, globals),
    do: input(connection, tag, acc, globals)

  defp of_member({:ok, %Tag{section: :var_output} = tag}, _program, connection, acc, globals),
    do: output(other_end(connection.to), connection, tag, acc, globals)

  defp of_member({:ok, %Tag{section: section}}, program, connection, acc, _globals),
    do:
      problem(
        acc,
        connection,
        "`#{connection.instance}.#{connection.member}` is internal to `#{program.name}` " <>
          "(declared `#{section}`): only a var_input or var_output connects"
      )

  defp of_member({:ok, _not_a_tag}, program, connection, acc, _globals),
    do:
      problem(
        acc,
        connection,
        "`#{connection.instance}` is a `#{program.name}`, which declares no " <>
          "`#{connection.member}`"
      )

  defp of_member(:error, program, connection, acc, _globals),
    do: unknown_member(String.contains?(connection.member, "."), program, connection, acc)

  defp unknown_member(true, _program, connection, acc),
    do:
      problem(
        acc,
        connection,
        "`#{connection.instance}.#{connection.member}` goes too deep: a connection names a " <>
          "var_input or var_output of a program instance, as in `#{connection.instance}.start`"
      )

  defp unknown_member(false, program, connection, acc) do
    names = for {name, %Tag{section: s}} <- program.tags, s in [:var_input, :var_output], do: name

    names = Enum.sort(names)

    problem(
      acc,
      connection,
      connects(
        "`#{connection.instance}` is a `#{program.name}`, which declares no " <>
          "`#{connection.member}`",
        Declarations.suggest(connection.member, names),
        names,
        program.name
      )
    )
  end

  defp connects(message, "", [], _type), do: message <> ": it has no var_input or var_output"

  defp connects(message, "", names, type),
    do:
      {message, {:members, type},
       fn -> ": its var_inputs and var_outputs are " <> listed(names) end}

  defp connects(message, suggestion, _names, _type), do: message <> suggestion

  defp problem({inputs, driven, problems}, connection, message),
    do: {inputs, driven, [diagnostic(connection.line, message) | problems]}

  # A var_input: connected once, to a global of its type or a constant that fits it.
  defp input(connection, tag, {inputs, driven, problems}, globals) do
    key = {connection.instance, tag.name}

    once(
      Map.get(inputs, key),
      connection,
      tag,
      {Map.put_new(inputs, key, connection), driven, problems},
      globals
    )
  end

  defp once(nil, connection, tag, acc, globals),
    do: source(other_end(connection.to), connection, tag, acc, globals)

  defp once(first, connection, _tag, acc, _globals),
    do:
      problem(
        acc,
        connection,
        "`#{connection.instance}.#{connection.member}` is already connected, to " <>
          "#{end_label(first.to)}#{where(first)}: a var_input is connected once"
      )

  defp end_label(to) when is_binary(to), do: "`#{to}`"
  defp end_label(to), do: inspect(to)

  defp source(:global, connection, tag, acc, globals),
    do: of_global(Map.fetch(globals, connection.to), connection, tag, acc, globals)

  defp source(:constant, %Connection{to: to} = connection, %Tag{type: type} = tag, acc, _globals),
    do: constant(Declarations.fits?(type, to), connection, tag, acc)

  defp source(:junk, _connection, _tag, acc, _globals), do: acc

  defp constant(true, _connection, _tag, acc), do: acc

  defp constant(false, connection, %Tag{type: :bool}, acc),
    do:
      problem(
        acc,
        connection,
        "`#{connection.instance}.#{connection.member}` is a bool: only 0 or 1 fit, " <>
          "found `#{connection.to}`"
      )

  defp constant(false, connection, %Tag{type: :dint}, acc),
    do:
      problem(
        acc,
        connection,
        "`#{connection.instance}.#{connection.member}` is a dint: `#{connection.to}` " <>
          "does not fit in 32 bits"
      )

  # A global whose type is the host's mistake is refused already: one mistake, one message.
  defp of_global({:ok, %Global{type: type}}, _connection, _tag, acc, _globals)
       when type not in [:bool, :dint],
       do: acc

  defp of_global({:ok, global}, connection, tag, acc, _globals),
    do: same_type(global.type == tag.type, global, connection, tag, acc)

  defp of_global(:error, connection, _tag, acc, globals) do
    names = Enum.sort(Map.keys(globals))

    problem(
      acc,
      connection,
      hint(
        "`#{connection.instance}.#{connection.member}` is connected to `#{connection.to}`, " <>
          "which is not a global",
        Declarations.suggest(connection.to, names, & &1, "names"),
        names,
        "globals"
      )
    )
  end

  defp same_type(true, _global, _connection, _tag, acc), do: acc

  defp same_type(false, global, connection, tag, acc),
    do:
      problem(
        acc,
        connection,
        "`#{connection.instance}.#{connection.member}` is a #{type_word(tag.type)}, but " <>
          "`#{global.name}` is a #{global.type}#{where(global)}"
      )

  defp type_word(%Logex.FbType{name: name}), do: name
  defp type_word(type), do: to_string(type)

  # A var_output: to a global of its type, never an input point, and the only connection
  # that drives that global.
  defp output(:global, connection, tag, acc, globals),
    do: sink(Map.fetch(globals, connection.to), connection, tag, acc, globals)

  defp output(:constant, connection, _tag, acc, _globals),
    do:
      problem(
        acc,
        connection,
        "`#{connection.instance}.#{connection.member}` is a var_output: it drives a global, " <>
          "and a constant cannot be driven"
      )

  defp output(:junk, _connection, _tag, acc, _globals), do: acc

  defp sink(:error, connection, tag, acc, globals),
    do: of_global(:error, connection, tag, acc, globals)

  defp sink({:ok, %Global{type: type}}, _connection, _tag, acc, _globals)
       when type not in [:bool, :dint],
       do: acc

  defp sink({:ok, global}, connection, tag, acc, _globals),
    do: drives(location(global.at), global, connection, tag, acc)

  defp drives({:ok, {_device, "i", _address}}, global, connection, _tag, acc),
    do:
      problem(
        acc,
        connection,
        "`#{global.name}` is an input point#{where(global)}: " <>
          "`#{connection.instance}.#{connection.member}` cannot drive it"
      )

  defp drives(_location, global, connection, tag, acc),
    do: typed_sink(global.type == tag.type, global, connection, tag, acc)

  defp typed_sink(false, global, connection, tag, acc),
    do: same_type(false, global, connection, tag, acc)

  defp typed_sink(true, global, connection, _tag, {inputs, driven, problems}),
    do: driver(Map.get(driven, global.name), global, connection, {inputs, driven, problems})

  defp driver(nil, global, connection, {inputs, driven, problems}),
    do: {inputs, Map.put(driven, global.name, connection), problems}

  defp driver(first, global, connection, acc),
    do:
      problem(
        acc,
        connection,
        "`#{global.name}` is already driven by `#{first.instance}.#{first.member}`" <>
          "#{where(first)}: one connection drives a global"
      )

  # Decision 7: every var_input is connected, to a global or a constant, cited at its
  # instance, in the program's declaration order.
  defp unconnected(runnable, inputs) do
    runnable
    |> Map.values()
    |> Enum.sort_by(fn {instance, _program} -> instance.name end)
    |> Enum.flat_map(fn {instance, program} ->
      for %Tag{section: :var_input, name: name} <- declared(program),
          not Map.has_key?(inputs, {instance.name, name}),
          do:
            diagnostic(
              instance.line,
              "`#{instance.name}.#{name}` is not connected: every var_input is connected, " <>
                "to a global or a constant"
            )
    end)
  end

  defp declared(%Program{tags: tags}),
    do:
      tags
      |> Map.values()
      |> Enum.filter(&match?(%Tag{}, &1))
      |> Enum.sort_by(&{line_key(&1), &1.name})

  defp empty([]), do: [diagnostic(nil, "a configuration runs at least one program instance")]
  defp empty(_instances), do: []
end
