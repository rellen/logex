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
  `compile/3`, from a configuration file's text, returns them; and
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
  - a task's interval is 1 to 2147483647 ms, and its priority 0, the highest, to 65535
    (decision 37);
  - a global's initial value fits its type, and a located global takes none; a location
    is `<device>.i.<address>` for an input point or `<device>.q.<address>` for an output
    point, its device a name, its address one or more whole numbers with no leading zero,
    the leftmost the highest level, and one written another way is told its one spelling;
    one address holds one global, and no two devices' names differ only in case. A global
    refused for its name has its location checked, but takes no address;
  - a program instance names a program type given, by a name that is no keyword, and, if
    it has one, a task;
  - a connection names a var_input or a var_output of an instance. A var_input is
    connected once, to a global of its type or a constant that fits it; a var_output to a
    global of its type, never an input point, and one connection at most drives a
    global. Every var_input is connected (decision 7), and an instance that leaves any
    unconnected is told them all in one diagnostic. Where an instance or a global is
    wanted, a name with `.` parts is told the reading it has (`docs/organisation.md`
    §4.7): a location, written only after `at`; an instance's member, since instances
    share a value only through a global; or a member of what is no instance;
  - a configuration runs at least one program instance.

  Its warnings: a global nothing uses, and an output point that something reads and
  nothing drives, which stays at 0.

  A mistake no configuration text can make is the host's, and `check/1` raises it as one
  `ArgumentError`, every such mistake a line each (decision 36), as
  `Logex.Compiler.instructionize/2` raises on a tree no source could say: a configuration
  whose name is not a name, or whose file is neither a string nor nil; programs that are
  not a map of names to `%Logex.Program{}`, each under its own name, one of them a
  function block type among them; a field that is not a proper list of its element
  struct, or a configuration or an element that lacks a key of its struct, as
  `Map.delete/2` can make one; a line that is not a positive integer or nil; lines that
  are neither all nil, as from Elixir, nor rising in each list, one element a line, as a
  file's are; a name, a location, a type or a task that the lexer does not read as one
  name token; a number that is not an integer of 0 or more, since a negative literal does
  not lex yet (`PLAN.md` §5); a global's type that is neither `:bool` nor `:dint`; and a
  connection's instance that is not a name, or with its member makes no one path.

  Each list of names a diagnostic ends with is given once, by the first diagnostic in
  line order that needs it, so a refusal is linear in its size. Its time is not: each
  unknown name is matched against every name for a did-you-mean, so a refusal of many bad
  names among many names takes time quadratic in the two, as the `.ld` compiler's
  refusals do. Only a mistake pays it.
  """

  alias Logex.{Declarations, Diagnostic, FbType, Program, Tag}
  alias Logex.Configuration.{Connection, Global, Instance, Text}

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

    {mistakes, diagnostics, warnings} = problems(config, [])

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
    compiled(Text.read(source), name, programs)
  end

  def compile(_name, source, _programs),
    do:
      raise(
        ArgumentError,
        "Logex.Configuration.compile/3 takes source text as a binary, got: #{inspect(source)}"
      )

  defp compiled({:error, [%Diagnostic{stage: :lex}] = lexed, []}, _name, _programs),
    do: {:error, lexed}

  defp compiled({:ok, entries}, name, programs), do: read_in(entries, [], name, programs)

  defp compiled({:error, unread, entries}, name, programs),
    do: read_in(entries, unread, name, programs)

  # The elements a text reads, and what its broken lines declare, checked as one.
  defp read_in(entries, unread, name, programs) do
    {declared, elements} = Enum.split_with(entries, &match?({:declared, _line, _named}, &1))

    config = %__MODULE__{
      name: name,
      programs: programs,
      globals: for(%Global{} = global <- elements, do: global),
      instances: for(%Instance{} = instance <- elements, do: instance),
      connections: for(%Connection{} = connection <- elements, do: connection)
    }

    {mistakes, diagnostics, warnings} = problems(config, declared)

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
    {mistakes, diagnostics, _warnings} = problems(config, [])
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
  # file's broken lines name, which only compile/3 gives.
  defp problems(config, declared) do
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
      diagnostics(config, {file, programs}, {tasks, globals, instances, connections}, declared)

    {mistakes, diagnostics, warnings}
  end

  # An element whose name no text can say is the host's mistake, and stays out of every
  # diagnostic. One whose name is refused here, a duplicate, a case twin, a name with `.`
  # parts or a keyword, has every other field checked, as a `.ld` declaration line does:
  # only its name is not kept. What a configuration file's broken line names, a
  # placeholder from Logex.Configuration.Text.read/1, takes its name as an element does,
  # and nothing that names it is reported again; a broken connection connects its
  # var_input.
  defp diagnostics(config, {file, programs}, parts, declared) do
    {tasks, globals, instances, connections} = parts
    {wired, named} = Enum.split_with(declared, &match?({:declared, _, %{kind: :connection}}, &1))
    [tasks, globals, instances] = Enum.map([tasks, globals, instances], &worded/1)
    space = namespace(tasks, globals, instances, named)
    {points, d_points} = located(globals, space.kept)
    world = world(space, points, programs)
    {wiring, d_wiring} = wiring(Enum.sort_by(connections, &line_key/1), world, wired)

    diagnostics =
      [
        space.problems,
        Enum.flat_map(tasks, &task/1),
        Enum.flat_map(globals, &global/1),
        d_points,
        runs(instances, {programs, given(config.programs)}, space),
        d_wiring,
        unconnected(instances, space.kept, world, wiring.inputs),
        empty(config.instances, named)
      ]
      |> Enum.concat()
      |> Enum.sort_by(&line_order/1)
      |> Enum.map_reduce(MapSet.new(), &listed_once/2)
      |> elem(0)

    {Enum.map(diagnostics, &%{&1 | file: file}),
     Enum.map(warnings(globals, wiring), &%{&1 | file: file})}
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

  defp line_key({:declared, line, _named}), do: {0, line}
  defp line_key(%{line: nil}), do: {1, 0}
  defp line_key(%{line: line}), do: {0, line}

  defp take_name({ref, element}, acc) do
    {kind, name, line} = held(element)
    refusal = refusal(String.contains?(name, "."), reserved?(name), name, kind)
    take(refusal, {ref, kind, name, line, stored(ref, element)}, acc)
  end

  defp stored(:declared, _placeholder), do: :declared
  defp stored(_ref, element), do: element

  defp held(%Logex.Configuration.Task{name: name, line: line}), do: {:task, name, line}
  defp held(%Global{name: name, line: line}), do: {:global, name, line}
  defp held(%Instance{name: name, line: line}), do: {:instance, name, line}
  defp held({:declared, line, %{kind: kind, name: name}}), do: {kind, name, line}

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

  defp initial(%Global{type: type, name: name, initial: v, line: line}, _location),
    do: fit(Declarations.fits?(type, v), type, v, "`#{name}`", line)

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

  defp located_word(true, at), do: one_spelling(spelled(at))
  defp located_word(false, _at), do: :error

  defp one_spelling({:ok, address}), do: {:ok, address}
  defp one_spelling(_other), do: :error

  # A location's parts, read so that one written another way than its one spelling is
  # told that spelling: `{:ok, address}` as written, `{:respell, address}` with `I` or `Q`
  # for `i` or `q`, or a field with a leading zero, and `:error` for no location. `at` is
  # one name token, so its first part is a name and its others names or digits.
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

  defp device(nil, {device, _io, _fields} = address, global, {points, devices, problems}),
    do:
      address(
        Map.get(points, address),
        address,
        global,
        {points, Map.put(devices, String.downcase(device), {device, global}), problems}
      )

  defp device({device, _first}, {device, _io, _fields} = address, global, acc),
    do: address(Map.get(elem(acc, 0), address), address, global, acc)

  defp device({other, first}, {device, _io, _fields}, global, acc),
    do:
      noted(
        acc,
        global.line,
        "the device `#{device}` and the device `#{other}` of `#{first.name}`#{where(first)} " <>
          "differ only in case: device names are case-sensitive, so these would be two devices"
      )

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
      globals: names_of(space.names, :global)
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
  defp runs(instances, programs, space),
    do: Enum.flat_map(instances, &(of_type(word?(&1.type), &1, programs) ++ on_task(&1, space)))

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
  defp on_task(%Instance{task: nil}, _space), do: []

  defp on_task(%Instance{task: task} = instance, space),
    do: task_word(word?(task), instance, space)

  # A task the lexer does not read as one name is the host's mistake, refused already.
  defp task_word(false, _instance, _space), do: []

  defp task_word(true, %Instance{task: task} = instance, space),
    do: task_held(MapSet.member?(space.silent, task), Map.get(space.names, task), instance, space)

  defp task_held(true, _held, _instance, _space), do: []
  defp task_held(false, {:task, _line, _ref}, _instance, _space), do: []

  defp task_held(false, _held, instance, space) do
    names = names_of(space.names, :task)

    message =
      hint(
        "program instance `#{instance.name}`: there is no task `#{instance.task}`",
        Declarations.suggest(instance.task, names, & &1, "names"),
        names
      )

    [diagnostic(instance.line, message)]
  end

  defp hint(message, "", []), do: message <> ": this configuration has no task"

  defp hint(message, "", names),
    do: {message, :tasks, fn -> ": the tasks are " <> listed(names) end}

  defp hint(message, suggestion, _names), do: message <> suggestion

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
        {%{inputs: inputs, driven: %{}, used: MapSet.new()}, []},
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

  defp unnamed(false, kind, name, world, type),
    do: declare(Declarations.suggest(name, known(world, kind), & &1, "names"), kind, name, type)

  defp declare("", :global, name, type),
    do: "no global `#{name}`: declare it, as in `var_global #{name} #{type}`"

  defp declare("", :instance, name, _type),
    do: "no instance `#{name}`: declare it, as in `program #{name} motor`"

  defp declare(suggestion, kind, name, _type), do: "no #{noun(kind)} `#{name}`" <> suggestion

  defp noun(:global), do: "global"
  defp noun(:instance), do: "instance"

  defp known(world, :global), do: world.globals
  defp known(world, :instance), do: world.instances

  defp on_instance(:skip, _connection, acc, _world), do: acc

  defp on_instance({:error, message}, connection, acc, _world),
    do: problem(acc, connection, message)

  defp on_instance({:ok, instance, program}, connection, acc, world),
    do:
      of_member(
        Map.fetch(program.tags, connection.member),
        instance,
        program,
        connection,
        acc,
        world
      )

  defp of_member({:ok, %Tag{section: :var_input} = tag}, _i, _p, connection, acc, world),
    do: input(connection, tag, acc, world)

  defp of_member({:ok, %Tag{section: :var_output} = tag}, _i, _p, connection, acc, world),
    do: output(other_end(connection.to), connection, tag, acc, world)

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
      "`#{connection.instance}` is a `#{program.name}`, which declares no `#{connection.member}`"

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
    sourced(Map.get(wiring.inputs, key), key, connection, tag, {wiring, problems}, world)
  end

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

  defp sourced(first, _key, connection, _tag, acc, _world),
    do:
      problem(
        acc,
        connection,
        "`#{connection.instance}.#{connection.member}` is already connected, to " <>
          "#{end_label(first.to)}#{where(first)}: a var_input has one source"
      )

  defp end_label(to) when is_binary(to) or is_integer(to), do: "`#{to}`"
  defp end_label(to), do: inspect(to)

  defp source(:global, connection, tag, acc, world),
    do: read_global(global_of(connection.to, tag.type, world), connection, tag, acc)

  defp source(:constant, %Connection{to: to} = connection, %Tag{type: type} = tag, acc, _world),
    do: constant(Declarations.fits?(type, to), connection, tag, acc)

  defp source(:junk, _connection, _tag, acc, _world), do: acc

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
  defp read_global({:ok, %Global{type: type} = global}, _connection, _tag, acc)
       when type not in [:bool, :dint],
       do: used(acc, global)

  defp read_global({:ok, global}, connection, tag, acc),
    do: same_type(global.type == tag.type, global, connection, tag, used(acc, global))

  defp read_global({:error, message}, connection, _tag, acc),
    do: problem(acc, connection, message)

  defp read_global(:skip, _connection, _tag, acc), do: acc

  defp used({wiring, problems}, global),
    do: {%{wiring | used: MapSet.put(wiring.used, global.name)}, problems}

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

  defp global_held(nil, name, type, world), do: {:error, no_named(:global, name, world, type)}

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

  defp member_held(false, nil, :error, {name, first, _type}, world),
    do:
      {:error,
       "`#{name}` names a member of an instance, and there is no instance `#{first}`" <>
         Declarations.suggest(first, world.instances, & &1, "names")}

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
       when type not in [:bool, :dint],
       do: used(acc, global)

  defp sink({:ok, global}, connection, tag, acc),
    do: drives(location(global.at), global, connection, tag, used(acc, global))

  defp sink({:error, message}, connection, _tag, acc), do: problem(acc, connection, message)
  defp sink(:skip, _connection, _tag, acc), do: acc

  defp drives({:ok, {_device, "i", _address}}, global, connection, _tag, acc),
    do:
      problem(
        acc,
        connection,
        "`#{global.name}` is an input point#{where(global)}: " <>
          "`#{connection.instance}.#{connection.member}`, a var_output, cannot drive it"
      )

  defp drives(_location, global, connection, tag, acc),
    do: typed_sink(global.type == tag.type, global, connection, tag, acc)

  defp typed_sink(false, global, connection, tag, acc),
    do: same_type(false, global, connection, tag, acc)

  defp typed_sink(true, global, connection, _tag, {wiring, _problems} = acc),
    do: driver(Map.get(wiring.driven, global.name), global, connection, acc)

  defp driver(nil, global, connection, {wiring, problems}),
    do: {%{wiring | driven: Map.put(wiring.driven, global.name, connection)}, problems}

  defp driver(first, global, connection, acc),
    do:
      problem(
        acc,
        connection,
        "`#{global.name}` is already driven by `#{first.instance}.#{first.member}`" <>
          "#{where(first)}"
      )

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
          %Tag{section: :var_input, name: name} <- declared(program),
          not Map.has_key?(inputs, {instance.name, name}),
          do: name
        ),
        instance
      )

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

  # IEC requires one program at least (Ed 2 Annex B.1.7; Ed 3 Annex A). A broken
  # `program` line counts, as it was reported already.
  defp empty([], named),
    do: no_program(Enum.any?(named, &match?({:declared, _line, %{kind: :instance}}, &1)))

  defp empty(_instances, _named), do: []

  defp no_program(true), do: []

  defp no_program(false),
    do: [diagnostic(nil, "this configuration declares no `program`: it would run nothing")]

  # The warnings, which stop nothing: a global nothing uses, and an output point that
  # something reads and nothing drives, which stays at 0. An output point nothing uses is
  # told it is unused only. A configuration that gives them has no mistake, so every global
  # keeps its name, and every output point its address.
  defp warnings(globals, wiring) do
    globals
    |> Enum.flat_map(&doubt(MapSet.member?(wiring.used, &1.name), &1, wiring))
    |> Enum.sort_by(&line_order/1)
  end

  defp doubt(false, global, _wiring),
    do: [warning(global.line, "`#{global.name}` is declared but nothing uses it")]

  defp doubt(true, global, wiring),
    do:
      undriven(
        output_point?(location(global.at)) and not Map.has_key?(wiring.driven, global.name),
        global
      )

  defp output_point?({:ok, {_device, "q", _fields}}), do: true
  defp output_point?(_location), do: false

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
