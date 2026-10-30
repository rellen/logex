defmodule Logex.Retain do
  @moduledoc false
  # M6-5 (docs/organisation.md §4.13, decisions 275, 276, 285 and 312): the store, the file
  # on the host's disk that stands in for battery-backed memory. Internal: `Logex.Runner`
  # alone reads and writes it, the core staying pure (decision 282), and a resource's
  # retained image, `Logex.Runtime.retained/1`'s, is what it holds.
  #
  # Its text is decision 276's, a person's to read after an incident and, where decision
  # 284 has it, to edit by hand:
  #
  #     logex retain 1
  #     configuration plant written 2026-10-27T14:00:00Z
  #     global total_boxes dint 41
  #     trigger arm 0
  #     instance m1 motor
  #     m1.boxes ctu
  #     m1.boxes.cu bool 1
  #     m1.boxes.cv dint 41
  #     m1.weights int[8] 0 0 12 14 0 0 0 0
  #
  # a header, `logex retain 1`; the configuration's name and the time of the write on the
  # host's wall clock, in UTC to the second, for a person and for `status/1`, never for a
  # timer; each retained global, `global <name> <type> <value>`; since decision 313 each
  # retained `single`'s last sample, `trigger <name> <sample>`; and each instance whose
  # program retains anything, `instance <name> <program type>`, followed by its lines in
  # path order (`Logex.Image.ordered/1`), each instance on the way to a value `<path>
  # <kind>`, an array of instances `m1.lane_t ton[4]`, and each value `<path> <type>
  # <value>`, an array's elements in the elements' order, the rightmost subscript fastest,
  # each path the instance's name and then the path inside it, an element by its
  # subscripts' values (decision 312). An integer and a bool are written in decimal, a real
  # in the shortest text that reads back to it, a single's for a `real` (`Logex.Real.
  # spelled/2`), and a timer's `last` never (decision 273).

  alias Logex.{Array, Declarations, Image, Real}

  @header "logex retain 1"

  @reals Declarations.reals()

  # Each elementary type by its word, as a declaration's type word is read.
  @words Map.new(Declarations.elementary(), &{Declarations.word(&1), &1})

  # ---- written ------------------------------------------------------------------------

  # A resource's retained image as the store's text, written at `at`, a UTC DateTime.
  def encode(%{configuration: name, globals: globals, instances: instances} = image, at) do
    [
      @header,
      "\n",
      "configuration #{name} written #{DateTime.to_iso8601(at)}\n",
      for({name, entry} <- Enum.sort(globals), do: ["global #{name} ", entry(entry), "\n"]),
      for({name, sample} <- Enum.sort(image.triggers), do: "trigger #{name} #{sample}\n"),
      for({name, lone} <- Enum.sort(instances), do: instance(name, lone))
    ]
    |> IO.iodata_to_binary()
  end

  defp instance(name, %{program: program, kinds: kinds, values: values}) do
    lines =
      Image.ordered(
        Enum.map(kinds, fn {path, kind} -> {path, {:kind, kind}} end) ++
          Enum.map(values, fn {path, entry} -> {path, {:value, entry}} end)
      )

    [
      "instance #{name} #{program}\n"
      | for({path, line} <- lines, do: [name, ?., path, ?\s, line_of(line), ?\n])
    ]
  end

  defp line_of({:kind, {:array, kind, dims}}), do: sized(kind, dims)
  defp line_of({:kind, kind}), do: kind
  defp line_of({:value, entry}), do: entry(entry)

  defp entry({{:array, type, dims}, list}),
    do: [
      sized(Declarations.word(type), dims) | Enum.map(List.flatten(list), &[?\s, value(type, &1)])
    ]

  defp entry({type, value}), do: [Declarations.word(type), ?\s, value(type, value)]

  defp sized(word, dims), do: "#{word}[#{Enum.join(dims, ",")}]"

  defp value(type, value) when type in @reals, do: Real.spelled(type, value)
  defp value(_type, value), do: Integer.to_string(value)

  # The time a store is written at, the host's wall clock in ms since the Unix epoch, to
  # the second, as the header holds it.
  def at(wall_ms),
    do: wall_ms |> DateTime.from_unix!(:millisecond) |> DateTime.truncate(:second)

  # The forces file's write rule (decision 127), shared with the store's (decision 275):
  # the text written whole to `<path>.tmp` beside the file, flushed to the disk, closed and
  # renamed over it, so that a crash at any moment leaves the old file or the new; a write
  # that fails leaves the file as it was, `{:error, reason}`, its `.tmp` deleted.
  def written(path, text) do
    beside = path <> ".tmp"
    renamed(written_out(:file.open(beside, [:write, :raw, :binary]), text), beside, path)
  end

  defp written_out({:ok, io}, text), do: synced(:file.write(io, text), io)
  defp written_out(error, _text), do: error

  defp synced(:ok, io), do: closed(:file.sync(io), io)
  defp synced(error, io), do: closed(error, io)

  defp closed(:ok, io), do: :file.close(io)

  defp closed(error, io) do
    :file.close(io)
    error
  end

  defp renamed(:ok, beside, path), do: discarded(:file.rename(beside, path), beside)
  defp renamed(error, beside, _path), do: discarded(error, beside)

  defp discarded(:ok, _beside), do: :ok

  defp discarded(error, beside) do
    :file.delete(beside)
    error
  end

  # ---- read ---------------------------------------------------------------------------

  # A store's text read back, `{image, written_at}`, for the configuration `name`; one that
  # is not one, or is of another configuration, is the host's mistake, every problem a line
  # of one ArgumentError, `<path>: line <n>: …` (decisions 276 and 285). What its image
  # holds is judged by `Logex.Runtime.start/2`, which forgives a changed configuration.
  def decode!(text, {path, name}) do
    lines = text |> String.split("\n") |> unended() |> Enum.with_index(1)
    {written_at, problems} = headed(lines, name)
    acc = %{image: empty(name), instance: nil, seen: %{}, problems: Enum.reverse(problems)}
    acc = lines |> Enum.drop(2) |> Enum.reduce(acc, &line/2)
    refused!(Enum.reverse(acc.problems), path)
    {acc.image, written_at}
  end

  # The text after the last newline, empty in a file the runner wrote, is no line.
  defp unended(lines), do: unended(List.last(lines), lines)
  defp unended("", lines), do: Enum.drop(lines, -1)
  defp unended(_last, lines), do: lines

  defp empty(name), do: %{configuration: name, globals: %{}, instances: %{}, triggers: %{}}

  defp refused!([], _path), do: :ok

  defp refused!(problems, path),
    do:
      raise(
        ArgumentError,
        Enum.map_join(problems, "\n", fn {line, problem} ->
          "#{path}: line #{line}: #{problem}"
        end)
      )

  # The header, its version, and the configuration and the time, each a problem of its
  # line where it is not one.
  defp headed([], _name),
    do: {nil, [{1, "the store is empty: its first line is `#{@header}`"}]}

  defp headed([{first, 1} | rest], name),
    do: {written_at(rest), header(String.split(first, " "), first) ++ named(rest, name)}

  defp header(["logex", "retain", "1"], _text), do: []

  defp header(["logex", "retain", version], _text),
    do: [
      {1,
       "the store is of version #{version}, which this logex does not read: it reads " <>
         "`#{@header}`"}
    ]

  defp header(_other, text),
    do: [{1, "`#{text}` is no store's header: a store's first line is `#{@header}`"}]

  defp named([], _name),
    do: [
      {2,
       "the store names no configuration: its second line is `configuration <name> " <>
         "written <time>`"}
    ]

  defp named([{text, 2} | _rest], name),
    do: configuration(String.split(text, " "), text, name)

  defp configuration(["configuration", name, "written", time], _text, name), do: time_lines(time)

  defp configuration(["configuration", stored, "written", time], _text, name),
    do:
      [
        {2,
         "the store is of configuration `#{stored}`, and this configuration is `#{name}`: " <>
           "a store starts only the configuration it was written for, so a renamed " <>
           "configuration starts only cold: start it with start: :cold to start over it"}
      ] ++ time_lines(time)

  defp configuration(_other, text, _name),
    do: [
      {2,
       "`#{text}` names no configuration: a store's second line is `configuration <name> " <>
         "written <time>`"}
    ]

  defp time_lines(time), do: time_problem(DateTime.from_iso8601(time), time)

  defp time_problem({:ok, _at, 0}, _time), do: []

  defp time_problem(_other, time),
    do: [{2, "`#{time}` is no time a store is written at, in UTC, as 2026-10-27T14:00:00Z"}]

  defp written_at([{text, 2} | _rest]), do: at_of(String.split(text, " "))
  defp written_at(_none), do: nil

  defp at_of(["configuration", _name, "written", time]), do: utc(DateTime.from_iso8601(time))
  defp at_of(_other), do: nil

  defp utc({:ok, at, 0}), do: at
  defp utc(_other), do: nil

  # Each line after the header: a global, a trigger, an instance, or one of the instance's
  # lines, a kind or a value.
  defp line({text, n}, acc), do: spaced(String.split(text, " "), {text, n}, acc)

  # A line's words each one space apart, with none before or after: any other spacing is
  # no line.
  defp spaced(words, at, acc), do: shaped("" in words, words, at, acc)

  defp shaped(true, _words, at, acc), do: line([], at, acc)
  defp shaped(false, words, at, acc), do: line(words, at, acc)

  defp line(["global", name, type | values], at, acc) when values != [],
    do: entered(typed(type, values), {:global, name}, at, acc)

  defp line(["trigger", name, sample], at, acc),
    do: entered(sample(number(sample), sample), {:trigger, name}, at, acc)

  defp line(["instance", name, program], at, acc), do: instance(name, program, at, acc)
  defp line([path, kind], at, acc), do: under(acc.instance, path, {:kind, kind}, at, acc)

  defp line([path, type | values], at, acc) when values != [],
    do: under(acc.instance, path, {:value, type, values}, at, acc)

  defp line(_other, {text, n}, acc),
    do:
      problem(
        acc,
        n,
        "`#{text}` is no line of a store: a line is `global <name> <type> <value>`, " <>
          "`trigger <name> <sample>`, `instance <name> <program type>`, `<path> <kind>` or " <>
          "`<path> <type> <value>`"
      )

  defp problem(acc, n, message), do: %{acc | problems: [{n, message} | acc.problems]}

  defp instance(name, program, {_text, n} = at, acc) do
    acc =
      %{acc | instance: name}
      |> named_problem(name, n, "instance")
      |> named_problem(program, n, "program type")

    once(acc, {:instance, name}, at, fn acc ->
      lone = %{program: program, kinds: %{}, values: %{}}
      %{acc | image: %{acc.image | instances: Map.put(acc.image.instances, name, lone)}}
    end)
  end

  defp named_problem(acc, name, n, what),
    do: name_problem(Declarations.name?(name), name, n, what, acc)

  defp name_problem(true, _name, _n, _what, acc), do: acc
  defp name_problem(false, name, n, what, acc), do: problem(acc, n, "`#{name}` names no #{what}")

  defp under(nil, _path, _line, {text, n}, acc),
    do:
      problem(
        acc,
        n,
        "`#{text}` comes before any `instance` line: an instance's lines follow its own"
      )

  defp under(name, path, line, at, acc),
    do: inside(String.split(path, name <> ".", parts: 2), name, line, at, acc)

  defp inside(["", inner], name, line, at, acc) when inner != "",
    do: put(read_line(line), name, inner, at, acc)

  defp inside(_other, name, _line, {text, n}, acc),
    do: problem(acc, n, "`#{text}` is not under the instance `#{name}` whose lines it follows")

  defp read_line({:kind, kind}), do: kind(Array.split(kind), kind)
  defp read_line({:value, type, values}), do: typed(type, values)

  # A kind: a built-in's or a block's name, or an array of its instances, `ton[4]`.
  defp kind(nil, kind), do: kind_named(Declarations.name?(kind), kind, kind)

  defp kind({name, sizes}, kind),
    do: kind_named(Declarations.name?(name), {:array, name, sizes(sizes)}, kind)

  defp kind_named(true, {:array, _name, :error}, kind), do: {:error, no_kind(kind)}
  defp kind_named(true, kind, _text), do: {:ok, {:kind, kind}}
  defp kind_named(false, _kind, text), do: {:error, no_kind(text)}

  defp no_kind(kind),
    do:
      "`#{kind}` is no kind of instance: a built-in's or a block's name, or an array of " <>
        "its instances, as `ton[4]`"

  defp sizes(texts), do: Enum.reduce_while(texts, [], &size/2) |> sized_list()

  defp size(text, acc), do: size_of(number(text), acc)

  defp size_of({:ok, n}, acc) when is_integer(n) and n > 0, do: {:cont, [n | acc]}
  defp size_of(_other, _acc), do: {:halt, :error}

  defp sized_list(:error), do: :error
  defp sized_list(sizes), do: Enum.reverse(sizes)

  # A type word, an elementary type's or an array's, `int[8]`, and its values, one each
  # element, each a number the lexer reads as one literal.
  defp typed(word, values), do: values_of(type(word), values, word)

  defp type(word), do: type_of(Map.fetch(@words, String.downcase(word)), word)

  defp type_of({:ok, type}, _word), do: {:ok, type}
  defp type_of(:error, word), do: array_type(Declarations.array_word(word))

  defp array_type({:ok, type}), do: {:ok, type}
  defp array_type(:error), do: :error

  defp values_of(:error, _values, word),
    do:
      {:error,
       "`#{word}` is no type of a retained value: an elementary type's word, or an array " <>
         "of one, as `int[8]`"}

  defp values_of({:ok, {:array, type, dims} = whole}, values, word),
    do: counted(length(values) == Array.size(dims), whole, numbers(values, type), word)

  defp values_of({:ok, type}, [value], _word), do: one(number(value), type, value)

  defp values_of({:ok, _type}, values, word),
    do: {:error, "`#{word}` holds one value, and the line gives #{length(values)}"}

  defp counted(true, {:array, _type, dims} = whole, {:ok, values}, _word),
    do: {:ok, {:value, {whole, Array.to_list(Array.from_flat(values, dims), dims)}}}

  defp counted(true, _whole, {:error, text}, _word), do: {:error, no_number(text)}

  defp counted(false, {:array, _type, dims}, _values, word),
    do:
      {:error,
       "`#{word}` holds #{Array.size(dims)} values, one an element, in the elements' order"}

  defp numbers(values, type),
    do: Enum.reduce_while(values, {:ok, []}, &each_number(&1, &2, type)) |> reversed()

  defp each_number(text, {:ok, acc}, type), do: next_number(number(text), text, acc, type)

  defp next_number({:ok, n}, _text, acc, type), do: {:cont, {:ok, [held(type, n) | acc]}}
  defp next_number(:error, text, _acc, _type), do: {:halt, {:error, text}}

  defp reversed({:ok, values}), do: {:ok, Enum.reverse(values)}
  defp reversed(error), do: error

  defp sample({:ok, n}, _text), do: {:ok, n}
  defp sample(:error, text), do: {:error, no_number(text)}

  defp one({:ok, n}, type, _text), do: {:ok, {:value, {type, held(type, n)}}}
  defp one(:error, _type, text), do: {:error, no_number(text)}

  defp no_number(text), do: "`#{text}` is no number"

  # A real's text read as its type's nearest value, as a forces file's is (decision 156),
  # so that the shortest text of a single reads back to the single; one past its range
  # kept as read, which the start drops as a misfit.
  defp held(type, n) when type in @reals and is_float(n),
    do: held_real(Real.in_range?(type, n), type, n)

  defp held(_type, n), do: n

  defp held_real(true, type, n), do: Real.nearest(type, n)
  defp held_real(false, _type, n), do: n

  # A global's or a trigger's entry, once, its name a name.
  defp entered({:error, message}, _key, {_text, n}, acc), do: problem(acc, n, message)

  defp entered({:ok, entry}, {kind, name} = key, {_text, n} = at, acc) do
    acc = named_problem(acc, name, n, "global")
    once(acc, key, at, &put_entry(kind, name, entry, &1))
  end

  defp put_entry(:global, name, {:value, entry}, acc),
    do: %{acc | image: %{acc.image | globals: Map.put(acc.image.globals, name, entry)}}

  defp put_entry(:trigger, name, sample, acc),
    do: %{acc | image: %{acc.image | triggers: Map.put(acc.image.triggers, name, sample)}}

  defp put({:error, message}, _name, _inner, {_text, n}, acc), do: problem(acc, n, message)

  defp put({:ok, line}, name, inner, at, acc),
    do:
      once(acc, {name, inner}, at, fn acc ->
        lone = put_lone(line, inner, Map.fetch!(acc.image.instances, name))
        %{acc | image: %{acc.image | instances: Map.put(acc.image.instances, name, lone)}}
      end)

  defp put_lone({:kind, kind}, inner, lone), do: %{lone | kinds: Map.put(lone.kinds, inner, kind)}

  defp put_lone({:value, entry}, inner, lone),
    do: %{lone | values: Map.put(lone.values, inner, entry)}

  # What a line names, once: a second line naming it is a problem of its own, the first
  # line kept.
  defp once(acc, key, {text, n}, put),
    do: once_at(Map.fetch(acc.seen, key), key, {text, n}, acc, put)

  defp once_at({:ok, first}, _key, {text, n}, acc, _put),
    do: problem(acc, n, "`#{text}` names what line #{first} names already")

  defp once_at(:error, key, {_text, n}, acc, put),
    do: put.(%{acc | seen: Map.put(acc.seen, key, n)})

  # A number's text, any number the lexer reads as one literal, decision 149's forms
  # among them, `37.50`, `3.75e1`, `16#ff` or `1_000`, and nothing else, so that a comment
  # or a tab the lexer would pass over, `1//c` or `1\t`, is none: the forces file's rule
  # (decisions 218 and 226), shared with the store's.
  def number(text), do: valued(number_text?(text), Logex.Lexer.tokenize(text))

  defp number_text?(<<c, rest::binary>>)
       when c in ?0..?9 or c in ?a..?z or c in ?A..?Z or c in [?-, ?#, ?_, ?.],
       do: number_text?(rest)

  defp number_text?(<<>>), do: true
  defp number_text?(_other), do: false

  defp valued(false, _tokens), do: :error

  defp valued(true, {:ok, [{kind, _at, number}], _end_line}) when kind in [:int_lit, :real_lit],
    do: {:ok, number}

  # Since decision 228 a subnormal double, `1.0e-310`, lexes as itself; and since decision
  # 231 one no float holds, `1.0e-400`, lexes as 0.0 with its spelling.
  defp valued(true, {:ok, [{kind, _at, number, _spelling}], _end_line})
       when kind in [:int_lit, :real_lit],
       do: {:ok, number}

  defp valued(true, _other), do: :error
end
