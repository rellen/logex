defmodule Logex.Configuration.Text do
  @moduledoc """
  A configuration file's text (`.logex`, decision 35; `docs/organisation.md` §4.4), read
  into the elements of a `%Logex.Configuration{}` and printed back. By hand, like
  `Logex.Parser`: `Logex.Lexer`'s tokens, one line at a time, by recursive descent.

      file        -> line*                     the lexer drops blank lines and comments
      line        -> task | global | program | connection
      task        -> 'task' NAME ['continuous'] ['single' NAME] ['interval' INT]
                     ['priority' INT] ['watchdog' INT]
      global      -> 'var_global' [QUALIFIER] NAME TYPE [INT] ['at' NAME]
                   | 'var_global' [QUALIFIER] NAME ARRAY INT* ['at' NAME]
      program     -> 'program' NAME NAME ['with' NAME]
      connection  -> PATH (NAME | INT)         PATH: a name with `.` parts, as `m1.start`,
                                               or an element's, `m1.temps[3]` (M5-11)
      TYPE        -> 'bool' | 'dint' | each of Logex.Declarations.type_words/0 (M5-3)
      ARRAY       -> a TYPE with its sizes, one NAME token, `int[8]` or `real[4,8]` (M5-11)
      QUALIFIER   -> 'retain' | 'non_retain'                                    (M6-3)

  `line/1` reads `line` by its first token; `task/3` reads `task`, with `inputs/2` its
  words, `order/4` their order and `value/5` each one's number, for `single` its name and
  for `continuous` nothing; `global/3` reads `global`, with `typed/3` its type, `initial/2` its initial value
  and `located/2` its location; `program/3`, `typed_program/3`, `program_type/4`,
  `scheduled/2` and `with_task/4` read `program`; and `connection/4` and `wire/3` read
  `connection`. Every decision is made on the next token alone.

  Everything the lexer settles is reused whole: positions, `//` comments, a run of
  newlines as one line end, a line ended by LF, CRLF or a lone CR alike (B8), and the `.`
  rule that makes `m1.start` and `panel.q.0` one name token. `Logex.Parser` is not used: a
  configuration has no rungs and no branch groups, so `(`, `|` and `)` are refused here,
  and the `.ld` grammar, `test/fixtures/frontend_golden.txt` and `printer_test.exs`'s
  `@required_shapes` do not change.

  **What it reads into.** `read/1` gives the elements a `%Logex.Configuration{}` holds, in
  line order, each with the line that declares it:

  - `task <name> [continuous] [single <global>] [interval <ms>] [priority <p>] [watchdog
    <ms>]`, a `%Logex.Configuration.Task{}`, its inputs in IEC's order, `single` before
    `interval` before `priority`, each once (Ed 2 Annex B.1.7, `task_initialization`),
    and since M4-2 (decisions 109 to 111) `continuous` before them all, a word with no
    value that makes the task the continuous one, and `watchdog` after them, IEC having
    neither, each once too. A single is a name, whatever it names, a dotted one among
    them, for `Logex.Configuration.check/1` to read (M2-6). An interval and a watchdog
    are whole numbers of milliseconds, as a timer's preset is (decision 13): `10ms`,
    `t#10ms` and `1.5` do not lex. An input left out reads as nil, `continuous` as false,
    and a timed task with neither a single nor an interval, or no priority, or a
    continuous one with any of the three, is refused by `Logex.Configuration.check/1`,
    as it is from Elixir;
  - `var_global <name> <type> [<initial>] [at <location>]`, a
    `%Logex.Configuration.Global{}`, and since M6-3 (`docs/organisation.md` §4.13,
    decisions 267, 268 and 298) `var_global retain <name> …` or `var_global non_retain
    <name> …`, its `retain` `:retain` or `:non_retain`, the qualifier straight after
    `var_global` as on a `.ld` declaration line; one given twice, both, or one anywhere
    else on the line, after the name, the type, the initial value or the location, is a
    broken line told where it goes, and a line that starts with one is told the line it
    belongs on;
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
  message. A line broken by `(`, `|` or `)` is read up to the delimiter for this. A
  `program` line broken before its instance's name, its delimiters aside, gives
  `{:declared, line, %{kind: :instance, name: nil}}`, which names nothing, so that a
  configuration is not also told it declares no `program`. Since decision 301
  (2026-10-29) a `var_global` line broken for its qualifiers alone, given twice, both or
  out of their place, is read on past them and gives its global itself, with no
  qualifier, among the entries, so that its declaration and its uses are checked as a
  `.ld` line's are (decision 294); one broken another way too gives the placeholder.

  **Keywords**, `keywords/0`, are matched in any case, and names are not folded. Each
  Milestone 2 item brings its own words (`docs/organisation.md` §4.10). M2-2's are
  `var_global` and `program`, which start their lines, and `at`, `bool` and `dint`, which
  belong on a `var_global` line, so no line starts with one of those three and no global
  is named by one; since M5-3 the seven other integer type words belong there too, as
  every word of the one table of types does (`Logex.Declarations.type_words/0`). M2-3's are `task`, which starts its line, `interval` and `priority`,
  which belong on a `task` line, so no line starts with one and no task is named by one,
  and `with`, which belongs on a `program` line after the type, so no line starts with it
  and no program type is named by it. M2-6's is `single`, which belongs on a `task` line,
  so no line starts with it and no task is named by it, and M4-2's are `continuous` and
  `watchdog`, which belong there too. M6-3's are `retain` and `non_retain`, which belong
  on a `var_global` line straight after `var_global`, so no line starts with one and, by
  decision 298, nothing in a configuration file is named by one, a global, an instance, a
  task, a program type or a device, as no `.ld` tag is; they are the one pair a
  configuration file shares with a `.ld` file's reserved words. A configuration file
  reserves its other words in that
  file kind only (§4.8, decision 10): a `.ld` program may name a tag `program`, `task`,
  `single` or `watchdog`. A message names a word only once a line reads it, so
  none offers a line this reader refuses.

  **What a line can say.** `entries!/1` is the text's own definition of its data, as
  `Logex.Parser.well_formed!/1` is a program's: exactly the entries a line can say, and so
  exactly those `print/1` can print and `read/1` read back. Data from Elixir is not held
  to it until it is printed: `Logex.Configuration.check/1` refuses a global named `at`,
  which no line can declare, as it refuses one named `program`, which a line can, since a
  configuration file's keyword names nothing in one.
  """

  alias Logex.{Declarations, Diagnostic, FbType, Parser}
  alias Logex.Configuration.{Connection, Global, Instance}
  import Logex.Declarations, only: [is_elementary: 1]
  import Logex.Parser, only: [is_int_lit: 1, is_literal: 1]

  # Each word of a configuration file's lines, and the place a line reads it: `:line`
  # starts one, `:task` goes on a `task` line, `:program` on a `program` line, and
  # `:global` and `:type` on a `var_global` line, each type word one of the elementary
  # types' (`Logex.Declarations.table/0`, M5-1).
  @keywords Map.merge(Map.new(Declarations.type_words(), &{&1, :type}), %{
              "task" => :line,
              "var_global" => :line,
              "program" => :line,
              "continuous" => :task,
              "single" => :task,
              "interval" => :task,
              "priority" => :task,
              "watchdog" => :task,
              "with" => :program,
              "at" => :global,
              "retain" => :qualifier,
              "non_retain" => :qualifier
            })

  # M6-3 (decisions 267 and 298): a qualifier straight after `var_global`, each to the
  # global's `retain`.
  @qualifiers %{"retain" => :retain, "non_retain" => :non_retain}

  # A word that may be a qualifier, told in a guard by its length and its first letter in
  # either case, as `Logex.Declarations` tells one, so that since the review of M6-4 a
  # location such as `drive.q.10`, ten bytes, is not lowercased to be looked up.
  defguardp may_qualify(word)
            when (byte_size(word) == 6 and binary_part(word, 0, 1) in ["r", "R"]) or
                   (byte_size(word) == 10 and binary_part(word, 0, 1) in ["n", "N"])

  @types Map.new(Declarations.elementary(), &{Declarations.word(&1), &1})
  # M5-10: the reals, whose globals take a real initial value.
  @reals Declarations.reals()

  # A task's inputs, in IEC's order (Ed 2 Annex B.1.7, `task_initialization`), each with
  # its rank in that order and the field it fills; since M4-2, `continuous` before them,
  # what kind of task the line declares, and `watchdog` after them, neither IEC's.
  @inputs %{
    "continuous" => {0, :continuous},
    "single" => {1, :single},
    "interval" => {2, :interval},
    "priority" => {3, :priority},
    "watchdog" => {4, :watchdog}
  }
  @order Enum.sort_by(Map.keys(@inputs), &elem(Map.fetch!(@inputs, &1), 0))

  # The words a line reads where a task's name goes, so no task is named by one.
  @input_words Map.keys(@inputs)

  # The words a `program` line reads after its type, so no program type is named by one.
  @after_type for {word, :program} <- @keywords, do: word

  # The words that start a line, among which an unknown first word gets a did-you-mean.
  @starts for {word, :line} <- @keywords, do: word

  # The words a `var_global` line reads where its name goes, so no global is named by one:
  # since M6-3 a qualifier there is read as one.
  @unnamed Enum.sort(
             for {word, place} <- @keywords, place in [:global, :type, :qualifier], do: word
           )

  @doc "The words of a configuration file's lines, lowercase."
  def keywords, do: Map.keys(@keywords)

  @doc """
  Reads a configuration's source: `{:ok, entries}`, the elements of its lines in line
  order, or `{:error, diagnostics, entries}` with one diagnostic for each line that could
  not be read, at its token and column, in line order, and the entries of the lines that
  could be, among them a placeholder for each broken line's name. A lex error stops the
  read and is the only diagnostic, at stage `:lex`.
  """
  def read(source) when is_binary(source), do: lexed(underflowed(Logex.Lexer.tokenize(source)))

  def read(source),
    do:
      raise(
        ArgumentError,
        "Logex.Configuration.Text.read/1 takes source text as a binary, got: #{inspect(source)}"
      )

  defp lexed({:ok, tokens, _end_line}), do: lines(split(tokens, [], []), [], [])

  defp lexed({:error, {location, module, reason}, _line}),
    do: {:error, [problem(:lex, location, module.format_error(reason))], []}

  @doc false
  # Decision 227: `read/1`'s result and, from the same tokens, each real initial value a
  # `var_global` line writes with more digits than its global's real keeps, `var_global sp
  # real 16777217.0`, as `{line, spelling, type, held}`, `held` the shortest text of the
  # value it is held as (`Logex.Real.held_as/3`), an array's initial list element by element:
  # the line's text keeps a value's spelling, which a global, a value, does not.
  #
  # Since decision 237 its third element is each real literal no double holds but 0.0,
  # `1.0e-400`, which the line holds as a stand-in, `{line, shown, spelling}`: a subnormal
  # double no other literal of the text holds, which every rule of `check/1` refuses as it
  # refuses a subnormal one, `1.0e-310`, in the global's or the member's words, and whose
  # text, `shown`, `Logex.Configuration.compile/3` puts back as written in each message. No configuration holding a stand-in compiles, so none is ever handed out.
  def read_rounded(source) when is_binary(source) do
    {lexed, spelled} = stood_in(Logex.Lexer.tokenize(source))
    {read, rounded} = lexed_rounded(lexed)
    {read, rounded, spelled}
  end

  # Decision 237: each underflowed literal, in source order, stood in for by a subnormal
  # double, the next `k * 5.0e-324`, k from 7919, that no real literal of the text holds, so
  # that its shortest text, which a message quotes, is no other literal's.
  # A text with none, nearly every one, is passed over at a reduction a token.
  defp stood_in({:ok, tokens, _end_line} = lexed), do: stood_in(underflows?(tokens), lexed)
  defp stood_in(error), do: {error, []}

  defp stood_in(false, lexed), do: {lexed, []}

  defp stood_in(true, {:ok, tokens, end_line}) do
    {tokens, {_count, _held, spelled}} =
      Enum.map_reduce(tokens, {7919, held(tokens), []}, &stand_in/2)

    {{:ok, tokens, end_line}, Enum.reverse(spelled)}
  end

  defp underflows?([{:real_lit, _, zero, _} = token | rest]) when zero == 0.0,
    do: Parser.underflowed?(token) or underflows?(rest)

  defp underflows?([_token | rest]), do: underflows?(rest)
  defp underflows?([]), do: false

  defp stand_in({:real_lit, {line, _} = location, zero, spelling} = token, acc)
       when zero == 0.0,
       do: stand_in(Parser.underflowed?(token), token, {location, line, spelling}, acc)

  defp stand_in(token, acc), do: {token, acc}

  defp stand_in(true, token, {location, line, spelling} = at, {k, held, spelled}),
    do:
      free(
        MapSet.member?(held, k * 5.0e-324),
        token,
        at,
        {k, held, spelled},
        {location, line, spelling}
      )

  defp stand_in(false, token, _at, acc), do: {token, acc}

  # A stand-in no real literal of the text holds, so that no message quotes another
  # literal's value as written for it.
  defp free(true, token, at, {k, held, spelled}, _where),
    do: stand_in(true, token, at, {k + 1, held, spelled})

  defp free(false, _token, _at, {k, held, spelled}, {location, line, spelling}) do
    value = k * 5.0e-324

    {{:real_lit, location, value},
     {k + 1, held, [{line, Float.to_string(value), spelling} | spelled]}}
  end

  defp held(tokens),
    do: MapSet.new(for token <- tokens, elem(token, 0) == :real_lit, do: elem(token, 2))

  # Decision 231: a real literal no double holds but 0.0, `1.0e-400`, lexes as 0.0 with its
  # spelling, which a program's slot refuses naming the instruction and the tag; `read/1`
  # gives entries, which hold values, and refuses it as the lexer did until then, a lex
  # error at its column, the only diagnostic (provisional), where `compile/3` refuses it
  # in its global's or member's words since decision 237.
  defp underflowed({:ok, tokens, end_line} = lexed),
    do: underflow(Enum.find(tokens, &Parser.underflowed?/1), lexed, end_line)

  defp underflowed(error), do: error

  defp underflow(nil, lexed, _end_line), do: lexed

  defp underflow({:real_lit, {line, _} = location, _zero, spelling}, _lexed, _end_line),
    do: {:error, {location, Logex.Lexer, {:real_small, spelling}}, line}

  defp lexed_rounded({:ok, tokens, _end_line}) do
    split = split(tokens, [], [])
    {lines(split, [], []), Enum.flat_map(split, &rounded_line/1)}
  end

  defp lexed_rounded(error), do: {lexed(error), []}

  defp rounded_line([{:name, {line, _}, word}, {:name, _, _name}, {:name, _, type} | values]),
    do: rounded_global(String.downcase(word), line, real_word(String.downcase(type)), values)

  defp rounded_line(_tokens), do: []

  defp real_word(word) when is_map_key(@types, word), do: Map.fetch!(@types, word)

  defp real_word(word) when binary_part(word, byte_size(word) - 1, 1) == "]",
    do: array_real(Declarations.array_word(word))

  defp real_word(_word), do: nil

  defp array_real({:ok, {:array, type, _dims}}), do: type
  defp array_real(:error), do: nil

  defp rounded_global("var_global", line, type, values) when type in @reals,
    do:
      for(
        value <- Enum.take_while(values, &is_literal/1),
        elem(value, 0) == :real_lit,
        {:rounded, held} <- [
          Logex.Real.held_as(type, Parser.value(value), Parser.spelling(value))
        ],
        do: {line, Parser.spelling(value), type, held}
      )

  defp rounded_global(_word, _line, _type, _values), do: []

  defp lines([], entries, []), do: {:ok, Enum.reverse(entries)}
  defp lines([], entries, problems), do: {:error, Enum.reverse(problems), Enum.reverse(entries)}

  defp lines([tokens | rest], entries, problems),
    do:
      lines(
        rest,
        entries,
        problems,
        counted(grouped(Enum.find(tokens, &delimiter?/1), tokens), tokens)
      )

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

  defp placeholders({:error, _problem, declared}),
    do: Enum.flat_map(declared, &placeholder/1)

  # Decision 301: a line refused for its qualifier alone declares its global, an element,
  # but one broken by a delimiter as well only names it.
  defp placeholder({:declared, _line, _named} = placeholder), do: [placeholder]
  defp placeholder(element), do: declared(element)

  # A `program` line broken before its instance's name, delimiters aside, still declares
  # a program, one it cannot name: a configuration it is in is not told it declares none.
  defp counted({:error, problem, []}, tokens),
    do: {:error, problem, unnamed(Enum.find(tokens, &(not delimiter?(&1))))}

  defp counted(read, _tokens), do: read

  defp unnamed({:name, _, word} = first), do: program_line(String.downcase(word), first)
  defp unnamed(_number_or_nothing), do: []

  defp program_line("program", first),
    do: [{:declared, line_of(first), %{kind: :instance, name: nil}}]

  defp program_line(_word, _first), do: []

  # A line is read by its first word, and is never empty: the lexer coalesces newlines.
  defp line([{:name, _, word} = first | rest]),
    do: keyed(Map.get(@keywords, String.downcase(word)), String.downcase(word), first, rest)

  defp line([first | _rest]) when is_literal(first),
    do: {:error, fail(first, unknown(plain(first))), []}

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

  defp belongs(:qualifier),
    do:
      "it goes on a `var_global` line, straight after `var_global`, as in " <>
        "`var_global retain total_boxes dint 0`"

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

  # task -> 'task' NAME ['continuous'] ['single' NAME] ['interval' INT] ['priority' INT]
  #         ['watchdog' INT]
  defp task([], first, _line),
    do: {:error, fail(first, "`task` needs a name, as in `task fast interval 10 priority 1`"), []}

  defp task([token | _rest], _first, _line) when is_literal(token),
    do: {:error, fail(token, "expected a task's name after `task`, found #{describe(token)}"), []}

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
    task = %Logex.Configuration.Task{name: name, priority: nil, line: line}
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
  # told it goes before. One not given is nil, or false for `continuous` (M4-2), which
  # comes first and so is never a later one.
  defp order(given, key, rank, task) when given in [nil, false],
    do: before(Enum.find(@order, &later?(&1, rank, task)), key)

  defp order(_given, key, _rank, task),
    do: "`#{key}` is given twice on the line of task `#{task.name}`"

  defp later?(other, rank, task) do
    {later, field} = Map.fetch!(@inputs, other)
    later > rank and Map.fetch!(task, field) != nil
  end

  defp before(nil, _key), do: :ok

  defp before(later, key), do: "`#{key}` goes before `#{later}`, as in " <> in_order(key, later)

  defp in_order("continuous", _later), do: "`task main continuous watchdog 200`"
  defp in_order("single", _later), do: "`task parts single part_in interval 1000 priority 2`"
  defp in_order(_key, "watchdog"), do: "`task fast interval 10 priority 1 watchdog 50`"
  defp in_order(_interval, _priority), do: "`task fast interval 10 priority 1`"

  # `continuous` takes no value: it says what kind of task the line declares (M4-2). A
  # single takes a name, which check/1 reads (M2-6), but not an input's word, which is
  # the next input: the name is missing. The others take a number, which the lexer reads
  # whole, so an interval and a watchdog are whole numbers of milliseconds (decision 13).
  defp value(rest, "continuous", field, _token, task),
    do: inputs(rest, Map.put(task, field, true))

  defp value([{:name, _, name} | rest] = tokens, "single", field, token, task),
    do:
      single_value(
        String.downcase(name) in @input_words,
        {name, rest, tokens},
        token,
        {field, task}
      )

  defp value([number | rest], key, field, _token, task)
       when key != "single" and is_int_lit(number),
       do: inputs(rest, Map.put(task, field, Parser.value(number)))

  defp value(rest, key, _field, token, task), do: refused_value(rest, key, token, task)

  defp single_value(false, {name, rest, _tokens}, _token, {field, task}),
    do: inputs(rest, Map.put(task, field, name))

  defp single_value(true, {_name, _rest, tokens}, token, {_field, task}),
    do: refused_value(tokens, "single", token, task)

  defp refused_value(rest, key, token, task),
    do: {:error, fail(at_found(rest, token), takes(key) <> found(rest)), declared(task)}

  defp takes("single"), do: "`single` takes a bool global's name, as in `single estop`"
  defp takes("interval"), do: "`interval` takes a number of milliseconds, as in `interval 10`"
  defp takes("priority"), do: "`priority` takes a number, 0 the highest, as in `priority 1`"
  defp takes("watchdog"), do: "`watchdog` takes a number of milliseconds, as in `watchdog 50`"

  defp unexpected_on_task(token, task),
    do:
      "unexpected #{describe(token)} on the line of task `#{task.name}`: a task takes " <>
        "`continuous`, `single`, `interval`, `priority` and `watchdog`"

  # global -> 'var_global' [QUALIFIER] NAME TYPE [INT] ['at' NAME]
  #         | 'var_global' [QUALIFIER] NAME ARRAY INT* ['at' NAME]   (M5-11, M6-3)
  #
  # M6-3: a qualifier straight after `var_global`, then the line as before, the global
  # holding it; one after it, given twice or both, is the line's one mistake.
  defp global([{:name, _, word} = token | rest], first, line)
       when may_qualify(word),
       do: qualifier(Map.get(@qualifiers, String.downcase(word)), token, {rest, first, line})

  defp global(rest, first, line), do: unqualified(rest, first, line)

  defp qualifier(nil, token, {rest, first, line}), do: unqualified([token | rest], first, line)

  defp qualifier(retain, {:name, _, word} = token, {rest, _first, line}),
    do: after_qualifier(rest, {retain, word, token}, line)

  defp after_qualifier([], {_retain, word, token}, _line),
    do:
      {:error,
       fail(
         token,
         "`var_global #{word}` needs a name and a type, as in " <>
           "`var_global #{word} total_boxes dint 0`"
       ), []}

  defp after_qualifier([{:name, _, second} = token | rest], {retain, word, first}, line)
       when may_qualify(second),
       do:
         second_word(
           Map.get(@qualifiers, String.downcase(second)),
           token,
           {rest, {retain, word, first}, line}
         )

  defp after_qualifier(rest, {retain, _word, token}, line),
    do: qualified(unqualified(rest, token, line), retain)

  defp second_word(nil, token, {rest, {retain, _word, first}, line}),
    do: qualified(unqualified([token | rest], first, line), retain)

  # Decision 301 (the maintainer, 2026-10-29), decision 294's rule in a configuration
  # file: a line refused for its qualifiers alone, given twice or both, is read on without
  # them and declares its global with none, so its uses are checked; one broken another way
  # too only names it, as every broken line does (decision 42).
  defp second_word(_second, {:name, _, second} = token, {rest, {_retain, word, first}, line}),
    do:
      {:error, fail(token, both(String.downcase(second) == String.downcase(word), word, second)),
       still_declared(unqualified(rest, first, line))}

  # The global read on holds no qualifier: only a line read whole is given one (qualified/2).
  defp still_declared({:ok, global}), do: [global]
  defp still_declared({:error, _diagnostic, declared}), do: declared

  defp both(true, word, second),
    do:
      "`#{second}` is given twice: a global takes `#{word}` once, as in " <>
        "`var_global #{word} total_boxes dint 0`"

  defp both(false, word, second),
    do: "a global takes `retain` or `non_retain`, not both: found `#{word}` and `#{second}`"

  defp qualified({:ok, global}, retain), do: {:ok, %{global | retain: retain}}
  defp qualified(broken, _retain), do: broken

  # A qualifier anywhere else on a `var_global` line is told where it goes, and since
  # decision 301 the line is read on past it, `rest` read as it would have been, so that a
  # line refused for its qualifier alone declares its global with none.
  defp misplaced(token, word, global, read_on),
    do:
      {:error,
       fail(
         token,
         "`#{word}` comes straight after `var_global`, as in " <>
           "`var_global #{String.downcase(word)} #{global.name} #{example_type(global.type)}`"
       ), still_declared(read_on.())}

  defp example_type(nil), do: "dint"
  defp example_type(type), do: type_text(type)

  defp unqualified([], first, _line),
    do:
      {:error, fail(first, "`var_global` needs a name and a type, as in `var_global estop bool`"),
       []}

  defp unqualified([token | _rest], _first, _line) when is_literal(token),
    do:
      {:error,
       fail(token, "expected a global's name after `var_global`, found #{describe(token)}"), []}

  defp unqualified([{:name, _, word} = token | rest], first, line),
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
         "`#{global.name}` needs a type, as in `var_global #{global.name} bool` or " <>
           "`var_global #{global.name} dint`"
       ), declared(global)}

  defp typed([token | _rest], global, _first) when is_literal(token),
    do:
      {:error,
       fail(token, "`#{global.name}` needs a type before its initial value #{describe(token)}"),
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

  defp type_word(key, word, token, {rest, global}) when is_map_key(@qualifiers, key),
    do: misplaced(token, word, global, fn -> typed(rest, global, token) end)

  # M5-11 (decision 151): an array's type word, `int[8]` or `real[4,8]`, its sizes literal
  # numbers, then an initial list of one literal an element, as a declaration line's, which
  # check/1 judges, its length and each value.
  defp type_word(key, word, token, {rest, global})
       when binary_part(key, byte_size(key) - 1, 1) == "]",
       do: array_word(Declarations.array_word(word), word, token, {rest, global})

  defp type_word(_key, word, token, {_rest, global}),
    do:
      {:error, fail(token, unknown_type(FbType.builtin(word), word, global.name)),
       declared(global)}

  defp array_word({:ok, {:array, type, _dims} = array}, _word, _token, {rest, global}),
    do: listed(rest, %{global | type: array}, type, [])

  defp array_word(:error, word, token, {_rest, global}),
    do:
      {:error, fail(token, unknown_array(FbType.builtin(base_word(word)), word, global.name)),
       declared(global)}

  defp base_word(word), do: hd(:binary.split(word, "["))

  # M5-14 (decision 154): an array of instances is a program's own, as an instance is.
  defp unknown_array(%FbType{name: type}, word, name),
    do:
      "`#{name}` cannot be an array of #{type}s, `#{word}`: a global array's type is " <>
        "#{a_global()} with its sizes, and an array of #{type}s is declared inside a " <>
        "program, as in `var #{name} #{word}`"

  defp unknown_array(nil, word, name),
    do:
      "unknown type `#{word}`: a global array's type is #{a_global()} with its sizes, " <>
        "literal numbers, as in `var_global #{name} int[8]`"

  defp listed([value | rest], global, type, values) when is_literal(value),
    do: listed(rest, global, type, [held(type, Parser.value(value)) | values])

  # Decision 301: a qualifier among an array's initial values, or before them, is told
  # where it goes and the list read on past it, as the line without it reads.
  defp listed([{:name, _, word} = token | rest], global, type, values)
       when may_qualify(word),
       do:
         listed_word(
           is_map_key(@qualifiers, String.downcase(word)),
           token,
           {rest, global},
           {type, values}
         )

  defp listed(rest, global, _type, values), do: list_done(rest, global, values)

  defp listed_word(true, {:name, _, word} = token, {rest, global}, {type, values}),
    do: misplaced(token, word, global, fn -> listed(rest, global, type, values) end)

  defp listed_word(false, token, {rest, global}, {_type, values}),
    do: list_done([token | rest], global, values)

  defp list_done(rest, global, []), do: located(rest, global)

  defp list_done(rest, global, values),
    do: located(rest, %{global | initial: Enum.reverse(values)})

  defp unknown_type(%FbType{name: type}, _word, name),
    do:
      "`#{name}` cannot be #{Declarations.a_or_an(type, "`#{type}`")}: a global's type is " <>
        "#{a_global()}, and " <>
        "#{Declarations.a_or_an(type)} is declared inside a program, as in `var #{name} #{type}`"

  defp unknown_type(nil, word, _name),
    do:
      "unknown type `#{word}`: a global's type is #{a_global()}" <>
        Declarations.suggest(word, Declarations.type_words(), & &1, "types")

  # The elementary types a global may have, each by its word, from the one table: `bool`,
  # `sint`, … or `ulint` (M5-3).
  defp a_global, do: Declarations.either(&"`#{Declarations.word(&1)}`")

  defp initial([value | rest], global) when is_literal(value),
    do: located(rest, %{global | initial: held(global.type, Parser.value(value))})

  # Decision 301: a qualifier where the initial value goes, `var_global total dint retain
  # 0`, is told where it goes and the value read on past it, as the line without it reads.
  defp initial([{:name, _, word} = token | rest], global) when may_qualify(word),
    do: initial_word(is_map_key(@qualifiers, String.downcase(word)), token, {rest, global})

  defp initial(rest, global), do: located(rest, global)

  defp initial_word(true, {:name, _, word} = token, {rest, global}),
    do: misplaced(token, word, global, fn -> initial(rest, global) end)

  defp initial_word(false, token, {rest, global}), do: located([token | rest], global)

  # M5-10 (decision 156): a real global's real initial value is read as the real's nearest
  # value, so that `print/1` spells it as the shortest text that reads back to it, and the
  # round trip is exact; any other value is read as it is written, which `check/1` judges,
  # one past the range or, since decision 216, one a write would flush to 0.0 among them.
  defp held(type, value) when type in @reals and is_float(value),
    do: real_held(Declarations.holds?(type, value), type, value)

  defp held(_type, value), do: value

  defp real_held(true, type, value), do: Logex.Real.nearest(type, value)
  defp real_held(false, _type, value), do: value

  defp located([], global), do: {:ok, global}

  defp located([{:name, _, word} = token | rest], %Global{at: nil} = global),
    do: at(String.downcase(word), token, rest, global)

  # M6-3: a qualifier after the location is told where it goes.
  defp located([{:name, _, word} = token | rest], global) when may_qualify(word),
    do: late(is_map_key(@qualifiers, String.downcase(word)), token, word, {rest, global})

  # A number after the initial value, or anything after the location.
  defp located([extra | _rest], global),
    do: {:error, fail(extra, after_global(extra, global)), declared(global)}

  # Decision 301: a qualifier where the location goes, before the location, `at retain
  # panel.i.0`, is told where it goes and the location read on past it. One the line ends
  # on is read as the location, as before, so that a global printed with any location
  # reads back to it, which check/1 judges.
  defp at("at", token, [{:name, _, location} = word, {:name, _, _} = next | rest], global)
       when may_qualify(location),
       do:
         at_word(
           is_map_key(@qualifiers, String.downcase(location)),
           token,
           [word, next | rest],
           global
         )

  defp at("at", _token, [{:name, _, location} | rest], global),
    do: located(rest, %{global | at: location})

  defp at("at", token, rest, global),
    do:
      {:error,
       fail(at_found(rest, token), "`at` needs a location, as in `at panel.i.0`" <> found(rest)),
       declared(global)}

  defp at(key, {:name, _, word} = token, rest, global) when is_map_key(@qualifiers, key),
    do: misplaced(token, word, global, fn -> located(rest, global) end)

  defp at(_word, token, _rest, global),
    do: {:error, fail(token, after_global(token, global)), declared(global)}

  defp at_word(true, token, [{:name, _, word} = qualifier | rest], global),
    do: misplaced(qualifier, word, global, fn -> at("at", token, rest, global) end)

  defp at_word(false, _token, [{:name, _, location} | rest], global),
    do: located(rest, %{global | at: location})

  defp late(true, token, word, {rest, global}),
    do: misplaced(token, word, global, fn -> located(rest, global) end)

  defp late(false, token, _word, {_rest, global}),
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

  defp program([token | _rest], _first, _line) when is_literal(token),
    do:
      {:error, fail(token, "expected an instance name after `program`, found #{describe(token)}"),
       []}

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

  defp typed_program([token | _rest], instance, _first) when is_literal(token),
    do:
      {:error,
       fail(
         token,
         "expected a program type after `program #{instance.name}`, found #{describe(token)}"
       ), declared(instance)}

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

  defp wire([value], connection, _first) when is_literal(value),
    do: {:ok, %{connection | to: Parser.value(value)}}

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
  defp describe(literal) when is_literal(literal), do: "`#{Parser.spelling(literal)}`"

  defp plain({:name, _, word}), do: word
  defp plain(literal) when is_literal(literal), do: Parser.spelling(literal)

  defp symbol({:bst, _}), do: "("
  defp symbol({:nxb, _}), do: "|"
  defp symbol({:bnd, _}), do: ")"

  defp line_of({:name, {line, _column}, _word}), do: line

  defp fail({_kind, location, _value}, message), do: problem(:configure, location, message)

  defp fail({kind, location, _value, _spelling}, message) when kind in [:int_lit, :real_lit],
    do: problem(:configure, location, message)

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

  defp printed(%Logex.Configuration.Task{name: name, interval: interval, priority: priority} = t) do
    words =
      ["task", name] ++
        flagged(t.continuous) ++
        given("single", t.single) ++
        given("interval", interval) ++
        given("priority", priority) ++ given("watchdog", t.watchdog)

    Enum.join(words, " ") <> "\n"
  end

  defp printed(%Global{retain: nil} = global),
    do:
      Enum.join(
        ["var_global", global.name, type_text(global.type)] ++
          initial_text(global.type, global.initial) ++ given("at", global.at),
        " "
      ) <> "\n"

  # M6-3: the qualifier straight after `var_global`.
  defp printed(%Global{retain: retain} = global),
    do:
      "var_global #{qualifier_text(retain)} " <>
        String.replace_prefix(printed(%{global | retain: nil}), "var_global ", "")

  defp printed(%Instance{name: name, type: type, task: task}),
    do: Enum.join(["program", name, type] ++ given("with", task), " ") <> "\n"

  defp printed(%Connection{to: to} = connection),
    do: "#{path(connection)} #{spelled(nil, to)}\n"

  # M5-11: an array's type word, its elements' type and its sizes, `int[4,8]`, and its
  # initial list, a literal an element.
  defp type_text({:array, type, dims}), do: "#{Declarations.word(type)}[#{Enum.join(dims, ",")}]"
  defp type_text(type), do: Declarations.word(type)

  defp initial_text({:array, type, _dims}, values) when is_list(values),
    do: Enum.map(values, &"#{spelled(type, &1)}")

  defp initial_text(type, value), do: given(nil, spelled(type, value))

  defp qualifier_text(:retain), do: "retain"
  defp qualifier_text(:non_retain), do: "non_retain"

  defp flagged(true), do: ["continuous"]
  defp flagged(false), do: []

  # M5-10 (decision 156): a real global's float initial value in the shortest text that reads
  # back to it, a `real`'s the shortest whose nearest single it is, and any other float, a
  # constant's, whose type the line does not say, `Float.to_string/1`'s, the shortest that
  # reads back to the double.
  defp spelled(type, value) when type in @reals and is_float(value),
    do: Logex.Real.spelled(type, value)

  defp spelled(_type, value) when is_float(value), do: Float.to_string(value)
  defp spelled(_type, value), do: value

  defp given(_word, nil), do: []
  defp given(nil, value), do: ["#{value}"]
  defp given(word, value), do: [word, value]

  @doc """
  `entries`, if a configuration file's lines can say them; otherwise an `ArgumentError`
  that names the first entry, in order, they cannot. The text's own definition of its
  data, as `Logex.Parser.well_formed!/1` is a program's: `print/1` checks its entries with
  it. A line can say a proper list of:

  - a `%Logex.Configuration.Task{}`, its name one name token to the lexer and none of
    `continuous`, `single`, `interval`, `priority` and `watchdog` in any case, which a line
    reads as that keyword; its single nil or one name token, none of those five in any case
    either (M2-6, M4-2); its interval, its priority and its watchdog each nil or an
    integer; and whether it is continuous true or false (M4-2);
  - a `%Logex.Configuration.Global{}`, its name one name token to the lexer and none of
    `at`, a type word or since M6-3 a qualifier in any case, which a line reads as that
    keyword; its `retain` nil, `:retain` or `:non_retain` (M6-3); its type an
    elementary type, `:bool`, `:dint` or since M5-3 any integer type, or since M5-11 an
    array of one, `{:array, :int, [4, 8]}`, its sizes a non-empty list of integers; its
    initial value nil or an integer, a real's a float of its values too, and an array's
    nil or a non-empty list of its elements' values, each as a global's own; its location
    nil or one name token;
  - a `%Logex.Configuration.Instance{}`, its name, its type and its task, if it has one,
    each one name token, its type not `with` in any case, which a line reads as that
    keyword;
  - a `%Logex.Configuration.Connection{}`, its instance a name with no `.`, since its first
    `.` begins the member, and the two one name token, as in `m1.start`; connected to a
    global's name, one name token, or to a constant;

  each with the keys of its struct and no others, and their lines all nil, as from Elixir,
  or positive and rising from entry to entry, one entry a line, as `read/1` gives them. A
  number may be negative, since a negative literal lexes (M3-3, decision 97), `-5`, and
  prints as it reads.
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
    optional_name!(entry.single, entry)
    optional_keyword!(entry.single, @input_words, "a task's single", entry)
    count!(interval, entry)
    count!(priority, entry)
    count!(entry.watchdog, entry)
    continuous!(entry.continuous, entry)
  end

  defp fields!(%Global{name: name, type: type, initial: initial, at: at} = entry) do
    name!(name, entry)
    keyword!(name, @unnamed, "a global's name", entry)
    type!(type, entry)
    initial!(type, initial, entry)
    optional_name!(at, entry)
    retain!(entry.retain, entry)
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

  # M6-3: a line says a global's qualifier by its word straight after `var_global`, and by
  # none that it has none.
  defp retain!(retain, _entry) when retain in [nil, :retain, :non_retain], do: :ok

  defp retain!(_retain, entry),
    do: unsaid!("a global's retain is :retain, :non_retain or nil", entry)

  # M4-2: a line says a task is continuous by a word, and by its absence that it is not.
  defp continuous!(continuous, _entry) when is_boolean(continuous), do: :ok

  defp continuous!(_continuous, entry),
    do: unsaid!("a task's continuous is true or false", entry)

  defp type!(type, _entry) when is_elementary(type), do: :ok

  # M5-11: an array of an elementary type, its sizes one integer a dimension, which a type
  # word holds as written, so that it reads back as it is.
  defp type!({:array, type, [_ | _] = dims}, entry) when is_elementary(type),
    do: sizes!(proper?(dims) and Enum.all?(dims, &is_integer/1), entry)

  defp type!(_type, entry),
    do:
      unsaid!(
        "a global's type is " <>
          Declarations.either(&inspect/1) <> ", or an array of one, as in `{:array, :int, [8]}`",
        entry
      )

  defp sizes!(true, _entry), do: :ok
  defp sizes!(false, entry), do: unsaid!("an array's sizes are a list of integers", entry)

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
  defp to!(to, _entry) when is_float(to), do: :ok

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

  defp optional_keyword!(nil, _keywords, _place, _entry), do: :ok
  defp optional_keyword!(word, keywords, place, entry), do: keyword!(word, keywords, place, entry)

  defp optional_name!(nil, _entry), do: :ok
  defp optional_name!(name, entry), do: name!(name, entry)

  # The lexer is the one rule for a name, as it is for a program's tree.
  defp name!(word, entry) when is_binary(word),
    do: one_name!(Logex.Lexer.tokenize(word), word, entry)

  defp name!(_word, entry), do: unsaid!("a name lexes as one name token", entry)

  defp one_name!({:ok, [{:name, _, word}], _end_line}, word, _entry), do: :ok
  defp one_name!(_lexed, _word, entry), do: unsaid!("a name lexes as one name token", entry)

  # M5-10: a real global's initial value may be a float, as a line reads one: its nearest
  # value, which `print/1` spells so that it reads back as it is.
  defp initial!(type, initial, entry) when type in @reals and is_float(initial),
    do: real_value!(Logex.Real.value?(type, initial), entry)

  # M5-11: an array's initial list, a literal an element, each as a global's own value is,
  # and never empty, since a line with no initial value says nil.
  defp initial!({:array, type, _dims}, [_ | _] = initial, entry),
    do: listed!(proper?(initial), type, initial, entry)

  defp initial!({:array, _type, _dims}, nil, _entry), do: :ok

  defp initial!({:array, _type, _dims}, _initial, entry),
    do: unsaid!("an array global's initial value is nil or a list of its elements' values", entry)

  defp initial!(_type, initial, entry), do: count!(initial, entry)

  defp listed!(true, type, initial, entry), do: Enum.each(initial, &initial!(type, &1, entry))

  defp listed!(false, _type, _initial, entry),
    do: unsaid!("an array global's initial value is nil or a list of its elements' values", entry)

  defp real_value!(true, _entry), do: :ok

  defp real_value!(false, entry),
    do:
      unsaid!(
        "a real global's real initial value is one of its type's values, as a line reads it",
        entry
      )

  defp count!(nil, _entry), do: :ok
  defp count!(n, _entry) when is_integer(n), do: :ok
  defp count!(_n, entry), do: unsaid!("a number is an integer", entry)

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
