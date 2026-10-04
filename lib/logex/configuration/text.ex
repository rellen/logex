defmodule Logex.Configuration.Text do
  @moduledoc """
  A configuration file's text (`.logex`, decision 35; `docs/organisation.md` §4.4), read
  into the elements of a `%Logex.Configuration{}` and printed back. By hand, like
  `Logex.Parser`: `Logex.Lexer`'s tokens, one line at a time, by recursive descent.

      file        -> line*                     the lexer drops blank lines and comments
      line        -> task | global | program | connection
      task        -> 'task' NAME ['interval' INT] ['priority' INT]
      global      -> 'var_global' NAME TYPE [INT] ['at' NAME]
      program     -> 'program' NAME NAME ['with' NAME]
      connection  -> PATH (NAME | INT)         PATH: a name with `.` parts, as `m1.start`
      TYPE        -> 'bool' | 'dint'

  `line/1` reads `line` by its first token; `task/3` reads `task`, with `inputs/2` its
  inputs, `order/4` their order and `value/5` each one's number; `global/3` reads
  `global`, with `typed/3` its type, `initial/2` its initial value and `located/2` its
  location; `program/3`, `typed_program/3`, `program_type/4`, `scheduled/2` and
  `with_task/4` read `program`; and `connection/4` and `wire/3` read `connection`. Every
  decision is made on the next token alone.

  Everything the lexer settles is reused whole: positions, `//` comments, a run of
  newlines as one line end, a line ended by LF, CRLF or a lone CR alike (B8), and the `.`
  rule that makes `m1.start` and `panel.q.0` one name token. `Logex.Parser` is not used: a
  configuration has no rungs and no branch groups, so `(`, `|` and `)` are refused here,
  and the `.ld` grammar, `test/fixtures/frontend_golden.txt` and `printer_test.exs`'s
  `@required_shapes` do not change.

  **What it reads into.** `read/1` gives the elements a `%Logex.Configuration{}` holds, in
  line order, each with the line that declares it:

  - `task <name> interval <ms> priority <p>`, a `%Logex.Configuration.Task{}`, its inputs
    in IEC's order, `interval` before `priority`, each once (Ed 2 Annex B.1.7,
    `task_initialization`). An interval is a whole number of milliseconds, as a timer's
    preset is (decision 13): `10ms`, `t#10ms` and `1.5` do not lex. An input left out
    reads as nil, which `Logex.Configuration.check/1` refuses, as it refuses one left
    out from Elixir;
  - `var_global <name> <type> [<initial>] [at <location>]`, a
    `%Logex.Configuration.Global{}`;
  - `program <instance> <type> [with <task>]`, a `%Logex.Configuration.Instance{}`, with
    no task where the line names none: IEC's `PROGRAM inst WITH task : type`, the type
    always the third word;
  - `<instance>.<member> <global or constant>`, a `%Logex.Configuration.Connection{}`, its
    path split at its first `.`, so `m1.t1.pre` is the instance `m1` and the member
    `t1.pre`, connected `to` a global's name or a constant. The member's section gives
    the direction, so the line carries no arrow (decision 5).

  This is the grammar only, and a mistake in it is a `:configure` diagnostic at its token,
  with a column. What the words mean, a name declared once and a location that is one, a
  task's interval and priority in range, a member that connects and an initial value that
  fits, is not the reader's to check: that is `Logex.Configuration.check/1`'s, the one
  validator, which a configuration built in Elixir meets too.

  **A broken line** is one diagnostic, the rest of its line skipped, and a lex error stops
  the read and is the only diagnostic. A broken line still names what its words name: for
  each whose name could be read, `read/1` gives a placeholder, `{:declared, line, %{kind:
  :task | :global | :instance, name: name}}`, or `{:declared, line, %{kind: :connection,
  instance: instance, member: member}}` for a connection, so that what checks the rest
  need not report that name undeclared, or that var_input unconnected: one mistake, one
  message. A line broken by `(`, `|` or `)` is read up to the delimiter for this.

  **Keywords**, `keywords/0`, are matched in any case, and names are not folded. Each
  Milestone 2 item brings its own words (`docs/organisation.md` §4.10). M2-2's are
  `var_global` and `program`, which start their lines, and `at`, `bool` and `dint`, which
  belong on a `var_global` line, so no line starts with one of those three and no global
  is named by one. M2-3's are `task`, which starts its line, `interval` and `priority`,
  which belong on a `task` line, so no line starts with one and no task is named by one,
  and `with`, which belongs on a `program` line after the type, so no line starts with it
  and no program type is named by it. A configuration file reserves its words in that
  file kind only (§4.8, decision 10): a `.ld` program may name a tag `program` or `task`.
  A message names a word only once a line reads it, so none offers a line this reader
  still refuses: `single`, M2-6's, is no input of a task yet.

  **What a line can say.** `entries!/1` is the text's own definition of its data, as
  `Logex.Parser.well_formed!/1` is a program's: exactly the entries a line can say, and so
  exactly those `print/1` can print and `read/1` read back. Data from Elixir is not held
  to it until it is printed: `Logex.Configuration.check/1` refuses a global named `at`,
  which no line can declare, as it refuses one named `program`, which a line can, since a
  configuration file's keyword names nothing in one.
  """

  alias Logex.{Declarations, Diagnostic, FbType}
  alias Logex.Configuration.{Connection, Global, Instance}

  # Each word of a configuration file's lines, and the place a line reads it: `:line`
  # starts one, `:task` goes on a `task` line, `:program` on a `program` line, and
  # `:global` and `:type` on a `var_global` line.
  @keywords %{
    "task" => :line,
    "var_global" => :line,
    "program" => :line,
    "interval" => :task,
    "priority" => :task,
    "with" => :program,
    "at" => :global,
    "bool" => :type,
    "dint" => :type
  }

  @types %{"bool" => :bool, "dint" => :dint}

  # A task's inputs, in IEC's order (Ed 2 Annex B.1.7, `task_initialization`), each with
  # its rank in that order and the field it fills.
  @inputs %{"interval" => {0, :interval}, "priority" => {1, :priority}}
  @order Enum.sort_by(Map.keys(@inputs), &elem(Map.fetch!(@inputs, &1), 0))

  # The words a line reads where a task's name goes, so no task is named by one.
  @input_words Map.keys(@inputs)

  # The words a `program` line reads after its type, so no program type is named by one.
  @after_type for {word, :program} <- @keywords, do: word

  # The words that start a line, among which an unknown first word gets a did-you-mean.
  @starts for {word, :line} <- @keywords, do: word

  # The words a `var_global` line reads where its name goes, so no global is named by one.
  @unnamed Enum.sort(for {word, place} <- @keywords, place in [:global, :type], do: word)

  @doc "The words of a configuration file's lines, lowercase."
  def keywords, do: Map.keys(@keywords)

  @doc """
  Reads a configuration's source: `{:ok, entries}`, the elements of its lines in line
  order, or `{:error, diagnostics, entries}` with one diagnostic for each line that could
  not be read, at its token and column, in line order, and the entries of the lines that
  could be, among them a placeholder for each broken line's name. A lex error stops the
  read and is the only diagnostic, at stage `:lex`.
  """
  def read(source) when is_binary(source), do: lexed(Logex.Lexer.tokenize(source))

  def read(source),
    do:
      raise(
        ArgumentError,
        "Logex.Configuration.Text.read/1 takes source text as a binary, got: #{inspect(source)}"
      )

  defp lexed({:ok, tokens, _end_line}), do: lines(split(tokens, [], []), [], [])

  defp lexed({:error, {location, module, reason}, _line}),
    do: {:error, [problem(:lex, location, module.format_error(reason))], []}

  defp lines([], entries, []), do: {:ok, Enum.reverse(entries)}
  defp lines([], entries, problems), do: {:error, Enum.reverse(problems), Enum.reverse(entries)}

  defp lines([tokens | rest], entries, problems),
    do: lines(rest, entries, problems, grouped(Enum.find(tokens, &delimiter?/1), tokens))

  defp lines(rest, entries, problems, {:ok, entry}), do: lines(rest, [entry | entries], problems)

  defp lines(rest, entries, problems, {:error, problem, declared}),
    do: lines(rest, Enum.reverse(declared, entries), [problem | problems])

  # `(`, `|` and `)` delimit a program's branch groups, and a configuration has none.
  defp delimiter?({kind, _location}) when kind in [:bst, :nxb, :bnd], do: true
  defp delimiter?(_token), do: false

  defp grouped(nil, tokens), do: line(tokens)

  # The delimiter is the line's one mistake, but the words before it are read first, so a
  # line that names something still declares it, as any other broken line does.
  defp grouped(delimiter, tokens),
    do:
      {:error, fail(delimiter, "a configuration line cannot hold `#{symbol(delimiter)}`"),
       before_delimiter(Enum.take_while(tokens, &(not delimiter?(&1))))}

  defp before_delimiter([]), do: []
  defp before_delimiter(words), do: placeholders(line(words))

  defp placeholders({:ok, entry}), do: declared(entry)
  defp placeholders({:error, _problem, declared}), do: declared

  # A line is read by its first word, and is never empty: the lexer coalesces newlines.
  defp line([{:name, _, word} = first | rest]),
    do: keyed(Map.get(@keywords, String.downcase(word)), String.downcase(word), first, rest)

  defp line([{:int_lit, _, value} = first | _rest]),
    do: {:error, fail(first, unknown("#{value}")), []}

  defp keyed(:line, "task", first, rest), do: task(rest, first, line_of(first))
  defp keyed(:line, "var_global", first, rest), do: global(rest, first, line_of(first))
  defp keyed(:line, "program", first, rest), do: program(rest, first, line_of(first))
  defp keyed(nil, _key, {:name, _, word} = first, rest), do: unkeyed(word, first, rest)

  # A word that belongs on a line is told which.
  defp keyed(place, _key, {:name, _, word} = first, _rest),
    do: {:error, fail(first, "a line cannot start with `#{word}`: " <> belongs(place)), []}

  defp belongs(:task),
    do: "it goes on a `task` line, as in `task fast interval 10 priority 1`"

  defp belongs(:program),
    do: "it goes on a `program` line, as in `program m1 motor with fast`"

  defp belongs(_global_or_type),
    do: "it goes on a `var_global` line, as in `var_global k1 bool at panel.q.0`"

  defp unkeyed(word, first, rest), do: dotted(String.contains?(word, "."), word, first, rest)

  defp dotted(true, path, first, rest), do: connection(rest, path, first, line_of(first))
  defp dotted(false, word, first, _rest), do: {:error, fail(first, unknown(word)), []}

  defp unknown(word), do: suggested(Declarations.suggest(word, @starts), word)

  defp suggested("", word),
    do:
      "unknown configuration line `#{word}`: a line starts with `task`, `var_global` or " <>
        "`program`, or is a connection, as in `m1.start pb_start_1`"

  defp suggested(suggestion, word), do: "unknown configuration line `#{word}`" <> suggestion

  # task -> 'task' NAME ['interval' INT] ['priority' INT]
  defp task([], first, _line),
    do: {:error, fail(first, "`task` needs a name, as in `task fast interval 10 priority 1`"), []}

  defp task([{:int_lit, _, value} = token | _rest], _first, _line),
    do: {:error, fail(token, "expected a task's name after `task`, found `#{value}`"), []}

  defp task([{:name, _, word} = token | rest], _first, line),
    do: named_task(String.downcase(word), word, token, {rest, line})

  # An input's word where the name goes is read as itself: the name is missing.
  defp named_task(key, word, token, _rest) when key in @input_words,
    do:
      {:error,
       fail(
         token,
         "`task` needs a name before `#{word}`, as in `task fast interval 10 priority 1`"
       ), []}

  defp named_task(_key, name, _token, {rest, line}) do
    task = %Logex.Configuration.Task{name: name, interval: nil, priority: nil, line: line}
    inputs(rest, task)
  end

  defp inputs([], task), do: {:ok, task}

  defp inputs([{:name, _, word} = token | rest], task),
    do: input(Map.fetch(@inputs, String.downcase(word)), token, rest, task)

  defp inputs([token | _rest], task),
    do: {:error, fail(token, unexpected_on_task(token, task)), declared(task)}

  defp input(:error, token, _rest, task),
    do: {:error, fail(token, unexpected_on_task(token, task)), declared(task)}

  defp input({:ok, {rank, field}}, {:name, _, word} = token, rest, task) do
    key = String.downcase(word)
    ordered(order(Map.fetch!(task, field), key, rank, task), {key, field}, token, {rest, task})
  end

  defp ordered(:ok, {key, field}, token, {rest, task}), do: value(rest, key, field, token, task)

  defp ordered(message, _input, token, {_rest, task}),
    do: {:error, fail(token, message), declared(task)}

  # A task's inputs come once each, in IEC's order: an input given after a later one is
  # told it goes before.
  defp order(nil, key, rank, task), do: before(Enum.find(@order, &later?(&1, rank, task)), key)

  defp order(_given, key, _rank, task),
    do: "`#{key}` is given twice on the line of task `#{task.name}`"

  defp later?(other, rank, task) do
    {later, field} = Map.fetch!(@inputs, other)
    later > rank and Map.fetch!(task, field) != nil
  end

  defp before(nil, _key), do: :ok

  defp before(later, key),
    do: "`#{key}` goes before `#{later}`, as in `task fast interval 10 priority 1`"

  # Each input takes a number, which the lexer reads whole, so an interval is a whole
  # number of milliseconds (decision 13).
  defp value([{:int_lit, _, number} | rest], _key, field, _token, task),
    do: inputs(rest, Map.put(task, field, number))

  defp value(rest, key, _field, token, task),
    do: {:error, fail(at_found(rest, token), takes(key) <> found(rest)), declared(task)}

  defp takes("interval"), do: "`interval` takes a number of milliseconds, as in `interval 10`"
  defp takes("priority"), do: "`priority` takes a number, 0 the highest, as in `priority 1`"

  defp unexpected_on_task(token, task),
    do:
      "unexpected #{describe(token)} on the line of task `#{task.name}`: a task takes " <>
        "`interval` and `priority`"

  # global -> 'var_global' NAME TYPE [INT] ['at' NAME]
  defp global([], first, _line),
    do:
      {:error, fail(first, "`var_global` needs a name and a type, as in `var_global estop bool`"),
       []}

  defp global([{:int_lit, _, value} = token | _rest], _first, _line),
    do: {:error, fail(token, "expected a global's name after `var_global`, found `#{value}`"), []}

  defp global([{:name, _, word} = token | rest], first, line),
    do: named_global(String.downcase(word), word, token, {rest, first, line})

  # A type word or `at` where the name goes is read as itself: the name is missing.
  defp named_global(key, word, token, _rest) when key in @unnamed,
    do:
      {:error,
       fail(token, "`var_global` needs a name before `#{word}`, as in `var_global estop bool`"),
       []}

  defp named_global(_key, name, _token, {rest, first, line}),
    do: typed(rest, %Global{name: name, type: nil, line: line}, first)

  defp typed([], global, first),
    do:
      {:error,
       fail(
         first,
         "`#{global.name}` needs a type: `var_global #{global.name} bool` or " <>
           "`var_global #{global.name} dint`"
       ), declared(global)}

  defp typed([{:int_lit, _, value} = token | _rest], global, _first),
    do:
      {:error, fail(token, "`#{global.name}` needs a type before its initial value `#{value}`"),
       declared(global)}

  defp typed([{:name, _, word} = token | rest], global, _first),
    do: type_word(String.downcase(word), word, token, {rest, global})

  defp type_word("at", _word, token, {_rest, global}),
    do:
      {:error,
       fail(
         token,
         "`#{global.name}` needs a type before `at`, as in " <>
           "`var_global #{global.name} bool at panel.q.0`"
       ), declared(global)}

  defp type_word(key, _word, _token, {rest, global}) when is_map_key(@types, key),
    do: initial(rest, %{global | type: Map.fetch!(@types, key)})

  defp type_word(_key, word, token, {_rest, global}),
    do:
      {:error, fail(token, unknown_type(FbType.builtin(word), word, global.name)),
       declared(global)}

  defp unknown_type(%FbType{name: type}, _word, name),
    do:
      "`#{name}` cannot be a `#{type}`: a global is a `bool` or a `dint`, and a #{type} " <>
        "is declared inside a program, as in `var #{name} #{type}`"

  defp unknown_type(nil, word, _name),
    do:
      "unknown type `#{word}`: a global is a `bool` or a `dint`" <>
        Declarations.suggest(word, ["bool", "dint"], & &1, "types")

  defp initial([{:int_lit, _, value} | rest], global),
    do: located(rest, %{global | initial: value})

  defp initial(rest, global), do: located(rest, global)

  defp located([], global), do: {:ok, global}

  defp located([{:name, _, word} = token | rest], %Global{at: nil} = global),
    do: at(String.downcase(word), token, rest, global)

  # A number after the initial value, or anything after the location.
  defp located([extra | _rest], global),
    do: {:error, fail(extra, after_global(extra, global)), declared(global)}

  defp at("at", _token, [{:name, _, location} | rest], global),
    do: located(rest, %{global | at: location})

  defp at("at", token, rest, global),
    do:
      {:error,
       fail(at_found(rest, token), "`at` needs a location, as in `at panel.i.0`" <> found(rest)),
       declared(global)}

  defp at(_word, token, _rest, global),
    do: {:error, fail(token, after_global(token, global)), declared(global)}

  defp after_global(token, global),
    do: "unexpected #{describe(token)} after the declaration of `#{global.name}`"

  # program -> 'program' NAME NAME ['with' NAME]
  defp program([], first, _line),
    do:
      {:error,
       fail(
         first,
         "`program` needs an instance name and a program type, as in `program m1 motor`"
       ), []}

  defp program([{:int_lit, _, value} = token | _rest], _first, _line),
    do: {:error, fail(token, "expected an instance name after `program`, found `#{value}`"), []}

  defp program([{:name, _, name} | rest], first, line),
    do: typed_program(rest, %Instance{name: name, type: nil, line: line}, first)

  defp typed_program([], instance, first),
    do:
      {:error,
       fail(
         first,
         "`program #{instance.name}` needs a program type, as in " <>
           "`program #{instance.name} motor`"
       ), declared(instance)}

  defp typed_program([{:int_lit, _, value} = token | _rest], instance, _first),
    do:
      {:error,
       fail(token, "expected a program type after `program #{instance.name}`, found `#{value}`"),
       declared(instance)}

  defp typed_program([{:name, _, type} = token | rest], instance, _first),
    do: program_type(String.downcase(type), type, token, {rest, instance})

  # `with` where the type goes is read as itself: the type is missing.
  defp program_type(key, word, token, {_rest, instance}) when key in @after_type,
    do:
      {:error,
       fail(
         token,
         "`program #{instance.name}` needs a program type before `#{word}`, as in " <>
           "`program #{instance.name} motor with fast`"
       ), declared(instance)}

  defp program_type(_key, type, _token, {rest, instance}),
    do: scheduled(rest, %{instance | type: type})

  # The type is read: then `with` and a task, or nothing.
  defp scheduled([], instance), do: {:ok, instance}

  defp scheduled([{:name, _, word} = token | rest], %Instance{task: nil} = instance),
    do: with_task(String.downcase(word), token, rest, instance)

  defp scheduled([extra | _rest], instance),
    do: {:error, fail(extra, after_program(extra, instance)), declared(instance)}

  defp with_task("with", _token, [{:name, _, task} | rest], instance),
    do: scheduled(rest, %{instance | task: task})

  defp with_task("with", token, rest, instance),
    do:
      {:error,
       fail(
         at_found(rest, token),
         "`with` needs a task, as in `program #{instance.name} #{instance.type} with fast`" <>
           found(rest)
       ), declared(instance)}

  defp with_task(_word, token, _rest, instance),
    do: {:error, fail(token, after_program(token, instance)), declared(instance)}

  defp after_program(token, %Instance{task: nil} = instance),
    do: "unexpected #{describe(token)} after `program #{instance.name} #{instance.type}`"

  defp after_program(token, instance),
    do:
      "unexpected #{describe(token)} after " <>
        "`program #{instance.name} #{instance.type} with #{instance.task}`"

  # connection -> PATH (NAME | INT)
  defp connection(rest, path, first, line) do
    [instance, member] = String.split(path, ".", parts: 2)
    wire(rest, %Connection{instance: instance, member: member, to: nil, line: line}, first)
  end

  defp wire([{:name, _, global}], connection, _first), do: {:ok, %{connection | to: global}}
  defp wire([{:int_lit, _, value}], connection, _first), do: {:ok, %{connection | to: value}}

  defp wire([], connection, first),
    do:
      {:error,
       fail(
         first,
         "`#{path(connection)}` needs a global or a constant to connect, as in " <>
           "`#{path(connection)} pb_start_1`"
       ), declared(connection)}

  defp wire([to, extra | _rest], connection, _first),
    do:
      {:error,
       fail(extra, "unexpected #{describe(extra)} after `#{path(connection)} #{plain(to)}`"),
       declared(connection)}

  defp path(%Connection{instance: instance, member: member}), do: "#{instance}.#{member}"

  # What a broken line declares, so nothing that names it is reported again.
  defp declared(%Logex.Configuration.Task{name: name, line: line}),
    do: [{:declared, line, %{kind: :task, name: name}}]

  defp declared(%Global{name: name, line: line}),
    do: [{:declared, line, %{kind: :global, name: name}}]

  defp declared(%Instance{name: name, line: line}),
    do: [{:declared, line, %{kind: :instance, name: name}}]

  defp declared(%Connection{instance: instance, member: member, line: line}),
    do: [{:declared, line, %{kind: :connection, instance: instance, member: member}}]

  # A word of the wrong kind is located at itself; a missing one at the word that wants it.
  defp at_found([], token), do: token
  defp at_found([found | _rest], _token), do: found

  defp found([]), do: ""
  defp found([token | _rest]), do: ", found #{describe(token)}"

  defp describe({:name, _, word}), do: "`#{word}`"
  defp describe({:int_lit, _, value}), do: "`#{value}`"

  defp plain({:name, _, word}), do: word
  defp plain({:int_lit, _, value}), do: "#{value}"

  defp symbol({:bst, _}), do: "("
  defp symbol({:nxb, _}), do: "|"
  defp symbol({:bnd, _}), do: ")"

  defp line_of({:name, {line, _column}, _word}), do: line

  defp fail({_kind, location, _value}, message), do: problem(:configure, location, message)
  defp fail({_kind, location}, message), do: problem(:configure, location, message)

  defp problem(stage, {line, column}, message),
    do: %Diagnostic{stage: stage, line: line, column: column, message: message}

  # Tokens to lines: a line is the tokens between two `rnd`s, and is never empty.
  defp split([{:rnd, _} | rest], line, lines), do: split(rest, [], add(line, lines))
  defp split([token | rest], line, lines), do: split(rest, [token | line], lines)
  defp split([], line, lines), do: Enum.reverse(add(line, lines))

  defp add([], lines), do: lines
  defp add(line, lines), do: [Enum.reverse(line) | lines]

  @doc """
  The canonical text of a configuration, or of `entries`, one line each, in their order:
  lowercase keywords, one space between words, no indentation and no comments. An entry
  with a line is printed on that line, the lines between left empty; entries with no line,
  from Elixir, are printed on lines 1, 2, 3 and on. `read/1` reads the text back to the
  same entries, each on the line it was printed on, which is how data is held to what the
  text can say (`docs/organisation.md` §4.9).

  A `%Logex.Configuration{}` is printed as its elements, merged in line order, as the file
  that declared them held them, or, built in Elixir with no lines, its tasks, then its
  globals, then its program instances, then its connections. The round trip is exact
  (§4.10): what `Logex.Configuration.compile/3` gives, `compile(config.name,
  print(config), config.programs)` gives back, each element on its line, its warnings
  included; a configuration from `Logex.Configuration.new!/1` comes back with its
  elements numbered from line 1. Its name and its programs are `compile/3`'s arguments,
  which no line says, and its warnings `compile/3`'s to give, so none of them is printed.

  Entries no configuration line could say raise `ArgumentError`, as `entries!/1` does, and
  so does a configuration whose parts are not each a proper list of them, their lines nil
  or rising, a line two of its lists share among them.
  """
  def print(%Logex.Configuration{
        tasks: tasks,
        globals: globals,
        instances: instances,
        connections: connections
      }) do
    parts = [tasks: tasks, globals: globals, instances: instances, connections: connections]
    Enum.each(parts, &part!/1)

    # Each list rises, so the one order of its elements is by line, which entries!/1 then
    # checks across the lists, a line two of them share refused; with no lines the sort
    # keeps them as listed.
    parts |> Keyword.values() |> Enum.concat() |> Enum.sort_by(& &1.line) |> print()
  end

  def print(entries) when is_list(entries) do
    entries!(entries)
    text(entries)
  end

  def print(other),
    do:
      raise(
        ArgumentError,
        "Logex.Configuration.Text.print/1 takes a %Logex.Configuration{} or a list of " <>
          "entries, got: #{inspect(other)}"
      )

  # One part of a configuration, a proper list of what its lines can say, in rising lines
  # or none, before the parts are merged: a merge would hide a list out of order.
  defp part!({part, entries}), do: part_listed!(proper?(entries), part, entries)

  defp part_listed!(true, _part, entries), do: entries!(entries)

  defp part_listed!(false, part, entries),
    do:
      raise(
        ArgumentError,
        "a configuration's #{part} must be a list of its elements, got: #{inspect(entries)}"
      )

  defp proper?([]), do: true
  defp proper?([_entry | rest]), do: proper?(rest)
  defp proper?(_tail), do: false

  defp text(entries),
    do: entries |> Enum.reduce({1, []}, &placed/2) |> elem(1) |> Enum.reverse() |> Enum.join()

  defp placed(%{line: nil} = entry, {next, text}), do: {next + 1, [printed(entry) | text]}

  defp placed(%{line: line} = entry, {next, text}),
    do: {line + 1, [String.duplicate("\n", line - next) <> printed(entry) | text]}

  defp printed(%Logex.Configuration.Task{name: name, interval: interval, priority: priority}) do
    words = ["task", name] ++ given("interval", interval) ++ given("priority", priority)
    Enum.join(words, " ") <> "\n"
  end

  defp printed(%Global{} = global),
    do:
      Enum.join(
        ["var_global", global.name, Atom.to_string(global.type)] ++
          given(nil, global.initial) ++ given("at", global.at),
        " "
      ) <> "\n"

  defp printed(%Instance{name: name, type: type, task: task}),
    do: Enum.join(["program", name, type] ++ given("with", task), " ") <> "\n"

  defp printed(%Connection{to: to} = connection), do: "#{path(connection)} #{to}\n"

  defp given(_word, nil), do: []
  defp given(nil, value), do: ["#{value}"]
  defp given(word, value), do: [word, value]

  @doc """
  `entries`, if a configuration file's lines can say them; otherwise an `ArgumentError`
  that names the first entry, in order, they cannot. The text's own definition of its
  data, as `Logex.Parser.well_formed!/1` is a program's: `print/1` checks its entries with
  it. A line can say a proper list of:

  - a `%Logex.Configuration.Task{}`, its name one name token to the lexer and neither
    `interval` nor `priority` in any case, which a line reads as that keyword; its
    interval and its priority each nil or an integer of 0 or more;
  - a `%Logex.Configuration.Global{}`, its name one name token to the lexer and none of
    `at`, `bool` or `dint` in any case, which a line reads as that keyword; its type
    `:bool` or `:dint`; its initial value nil or an integer of 0 or more; its location nil
    or one name token;
  - a `%Logex.Configuration.Instance{}`, its name, its type and its task, if it has one,
    each one name token, its type not `with` in any case, which a line reads as that
    keyword;
  - a `%Logex.Configuration.Connection{}`, its instance a name with no `.`, since its first
    `.` begins the member, and the two one name token, as in `m1.start`; connected to a
    global's name, one name token, or to a constant of 0 or more;

  each with the keys of its struct and no others, and their lines all nil, as from Elixir,
  or positive and rising from entry to entry, one entry a line, as `read/1` gives them. A
  number of 0 or more, since a negative one does not lex yet (`PLAN.md` §5).
  """
  def entries!(entries) do
    proper!(entries, entries)
    Enum.each(entries, &entry!/1)
    lines!(Enum.uniq(Enum.map(entries, & &1.line)), entries, nil)
    entries
  end

  # A proper list, walked to its end before anything walks it with `Enum`.
  defp proper!([], _entries), do: :ok
  defp proper!([_entry | rest], entries), do: proper!(rest, entries)

  defp proper!(_tail, entries),
    do: raise(ArgumentError, "entries must be a list, got: #{inspect(entries)}")

  @keys Map.new(
          [Logex.Configuration.Task, Global, Instance, Connection],
          &{&1, Enum.sort(Map.keys(&1.__struct__()))}
        )

  # An entry's struct, with its keys and no others: a map that lacks one, or carries
  # another, would not read back as it is.
  defp entry!(%module{} = entry) when is_map_key(@keys, module),
    do: whole!(Enum.sort(Map.keys(entry)) == Map.fetch!(@keys, module), entry)

  defp entry!(entry), do: kind!(entry)

  defp whole!(true, %{line: line} = entry) when is_nil(line) or (is_integer(line) and line > 0),
    do: fields!(entry)

  defp whole!(true, entry),
    do: unsaid!("a line is a positive integer, or nil for an entry built in Elixir", entry)

  defp whole!(false, entry), do: kind!(entry)

  defp kind!(entry),
    do:
      unsaid!(
        "an entry is a %Logex.Configuration.Task{}, %Logex.Configuration.Global{}, " <>
          "%Logex.Configuration.Instance{} or %Logex.Configuration.Connection{}, with its " <>
          "struct's keys",
        entry
      )

  defp fields!(
         %Logex.Configuration.Task{name: name, interval: interval, priority: priority} = entry
       ) do
    name!(name, entry)
    keyword!(name, @input_words, "a task's name", entry)
    count!(interval, entry)
    count!(priority, entry)
  end

  defp fields!(%Global{name: name, type: type, initial: initial, at: at} = entry) do
    name!(name, entry)
    keyword!(name, @unnamed, "a global's name", entry)
    type!(type, entry)
    count!(initial, entry)
    optional_name!(at, entry)
  end

  defp fields!(%Instance{name: name, type: type, task: task} = entry) do
    name!(name, entry)
    name!(type, entry)
    keyword!(type, @after_type, "a program's type", entry)
    optional_name!(task, entry)
  end

  defp fields!(%Connection{instance: instance, member: member, to: to} = entry) do
    path!(instance, member, entry)
    to!(to, entry)
  end

  defp type!(type, _entry) when type in [:bool, :dint], do: :ok
  defp type!(_type, entry), do: unsaid!("a global's type is :bool or :dint", entry)

  # A connection's first word is one name token, split at its first `.`: what `read/1`
  # reads as instance and member is exactly what joins back into that token.
  defp path!(instance, member, entry) when is_binary(instance) and is_binary(member) do
    name!(instance, entry)
    undotted!(String.contains?(instance, "."), entry)
    name!(instance <> "." <> member, entry)
  end

  defp path!(_instance, _member, entry), do: unsaid!("a name lexes as one name token", entry)

  defp undotted!(false, _entry), do: :ok

  defp undotted!(true, entry),
    do: unsaid!("a connection's instance has no `.`: its first `.` begins the member", entry)

  defp to!(to, entry) when is_binary(to), do: name!(to, entry)
  defp to!(to, entry) when is_integer(to), do: count!(to, entry)

  defp to!(_to, entry),
    do: unsaid!("a connection is to a global, by its name, or to a constant", entry)

  # A keyword a line reads in this place, in any case: `var_global at bool` reads `at` as
  # the keyword, so no line names a global `at`.
  defp keyword!(word, keywords, place, entry),
    do: read_as!(String.downcase(word) in keywords, keywords, place, entry)

  defp read_as!(false, _keywords, _place, _entry), do: :ok

  defp read_as!(true, keywords, place, entry),
    do:
      unsaid!(
        "#{place} is not #{either(keywords)}, in any case: a line reads that word as its " <>
          "keyword",
        entry
      )

  defp either([word]), do: "`#{word}`"

  defp either(words) do
    {init, [last]} = Enum.split(Enum.map(words, &"`#{&1}`"), -1)
    Enum.join(init, ", ") <> " or " <> last
  end

  defp optional_name!(nil, _entry), do: :ok
  defp optional_name!(name, entry), do: name!(name, entry)

  # The lexer is the one rule for a name, as it is for a program's tree.
  defp name!(word, entry) when is_binary(word),
    do: one_name!(Logex.Lexer.tokenize(word), word, entry)

  defp name!(_word, entry), do: unsaid!("a name lexes as one name token", entry)

  defp one_name!({:ok, [{:name, _, word}], _end_line}, word, _entry), do: :ok
  defp one_name!(_lexed, _word, entry), do: unsaid!("a name lexes as one name token", entry)

  defp count!(nil, _entry), do: :ok
  defp count!(n, _entry) when is_integer(n) and n >= 0, do: :ok

  defp count!(_n, entry),
    do:
      unsaid!(
        "a number is an integer, 0 or more: a negative one does not lex yet (PLAN.md §5)",
        entry
      )

  # Lines are where a file declares each entry: none from Elixir, or rising, one a line.
  defp lines!([nil], _entries, _last), do: :ok
  defp lines!(_lines, [], _last), do: :ok

  defp lines!(lines, [%{line: line} | rest], last)
       when is_integer(line) and (last == nil or line > last),
       do: lines!(lines, rest, line)

  defp lines!(_lines, [entry | _rest], last),
    do:
      unsaid!(
        "lines are nil for entries built in Elixir, or rise from entry to entry, one entry " <>
          "a line#{after_line(last)}",
        entry
      )

  defp after_line(nil), do: ", and no line is nil beside one that is not"
  defp after_line(last), do: ", and this one comes after line #{last}"

  defp unsaid!(rule, entry),
    do:
      raise(
        ArgumentError,
        "not an entry a configuration file can say: #{rule}, got: #{inspect(entry)}"
      )
end
