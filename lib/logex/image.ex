defmodule Logex.Image do
  @moduledoc false
  # M6-4 (docs/organisation.md §4.13, decisions 273, 277 and 282): the retained image, the
  # plain data a store will hold (M6-5), taken out of an instance or a resource and laid
  # over a new one. Internal: `Logex.Runtime.retained/1,2`, `start/2` and `instance/2` are
  # its doors, and `Logex.Runtime` alone builds the resource, as its opacity requires.
  #
  # A lone instance's image is `%{program: name, kinds: kinds, values: values}`, each
  # keyed by a path inside the instance, as logic names it: `values` every retained leaf,
  # `boxes.cv` to `{:dint, 41}`, its type an elementary type's atom or an array of one,
  # `{:array, :int, [8]}`, with a host's list for its value; `kinds` every instance on the
  # way to a leaf, `boxes` to `"ctu"`, a user block's by its name, `s1` to `"seal"`, an
  # array of instances `{:array, "ton", [4]}`, its elements `lane_t[2].acc` by their
  # subscripts' values. A timer's `last` is never in it: each retained timer starts at
  # the start's `now` (decision 273). A resource's is `%{configuration: name, globals:
  # globals, instances: instances}`, `globals` each retained global by name to `{type,
  # value}` and `instances` each instance whose program retains anything by name to its
  # image.

  import Logex.Declarations, only: [is_elementary: 1, is_fitting: 2]

  alias Logex.{Array, Declarations, FbType, Program}
  alias Logex.FbType.Member

  @reals Declarations.reals()

  # ---- taken out ----------------------------------------------------------------------

  # A lone instance's image, from its env: one walk of the program's retained paths, so
  # its cost is the retained values' and the paths', whatever else the instance holds.
  def of(%Program{name: name, retained: nil}, _env),
    do: %{program: name, kinds: %{}, values: %{}}

  def of(%Program{name: name, retained: paths} = program, env) do
    {kinds, values} =
      Enum.reduce(paths, {%{}, %{}}, fn path, acc ->
        {_value, acc} = along(path, program, env, acc, &taken/4)
        acc
      end)

    %{program: name, kinds: kinds, values: values}
  end

  # Each value's entry, its type and its host's form; nothing changed.
  defp taken(path, {:array, _type, dims} = whole, value, {kinds, values}),
    do: {value, {kinds, Map.put(values, path, {whole, Array.to_list(value, dims)})}}

  defp taken(path, type, value, {kinds, values}),
    do: {value, {kinds, Map.put(values, path, {type, value})}}

  # The retained globals of a resource, by name.
  def globals(globals, values),
    do:
      for(
        %Logex.Configuration.Global{retain: :retain, name: name, type: type} <- globals,
        into: %{},
        do: {name, entry(type, Map.fetch!(values, name))}
      )

  defp entry({:array, _type, dims} = type, value), do: {type, Array.to_list(value, dims)}
  defp entry(type, value), do: {type, value}

  # ---- one walk of a retained path ------------------------------------------------------

  # A retained path of `Program.retained`, `boxes`, `s1.count` or `gates[*].k`, walked
  # through `env`, each instance on the way given its kind and each value under it given
  # to `leaf`, which gives the value to put back and the accumulator: `{env, acc}`.
  # A program handed in and checked, which the host then edited by hand, is trusted, as
  # decision 194 has it, and a walk that reaches a retained path its tags do not give
  # raises a pinned ArgumentError there, as a warm restart's does (M6-2's review).
  defp along(path, %Program{tags: tags, blocks: blocks}, env, acc, leaf) do
    [first | rest] = String.split(path, ".")
    {name, each} = each(first)
    type = typed(Map.fetch!(tags, name).type, blocks)
    {value, acc} = down(each, rest, {name, type}, Map.fetch!(env, name), {acc, leaf})
    {Map.put(env, name, value), acc}
  rescue
    _error in [KeyError, BadMapError, FunctionClauseError, ArgumentError, MatchError] ->
      reraise(
        ArgumentError,
        [
          message:
            "the retained image reaches the retained path #{inspect(path)}, which the " <>
              "program's tags do not give: the program was edited by hand after it was " <>
              "handed in and checked"
        ],
        __STACKTRACE__
      )
  end

  defp typed({:block, name}, blocks), do: FbType.within(Map.fetch!(blocks, name), blocks)

  defp typed({:array, {:block, name}, dims}, blocks),
    do: {:array, FbType.within(Map.fetch!(blocks, name), blocks), dims}

  defp typed(type, _blocks), do: type

  defp each(segment), do: each_of(:binary.split(segment, "[*]"))

  defp each_of([name, ""]), do: {name, true}
  defp each_of([name]), do: {name, false}

  # `[*]`: every element of an array of instances, the rest of the path in each.
  defp down(true, rest, {path, {:array, type, dims} = whole}, values, {acc, leaf}) do
    acc = kind(path, whole, acc)
    indexed(dims, values, {acc, leaf}, &walk(rest, {Array.name(path, &1), type}, &2, &3))
  end

  defp down(false, rest, at, value, with), do: walk(rest, at, value, with)

  defp walk([], at, value, with), do: whole(at, value, with)

  defp walk([segment | rest], {path, %FbType{} = type}, value, {acc, leaf}) do
    acc = kind(path, type, acc)
    {name, each} = each(segment)
    member = member!(type, name)
    at = {path <> "." <> name, FbType.type_of(type, member)}
    {kept, acc} = down(each, rest, at, Map.fetch!(value, name), {acc, leaf})
    {Map.put(value, name, kept), acc}
  end

  defp member!(%FbType{members: members}, name), do: Enum.find(members, &(&1.name == name))

  # Everything under a path: an instance's members, a timer's `last` left out, each
  # element of an array of instances, or a value.
  defp whole({path, %FbType{members: members} = type}, value, {acc, leaf}) do
    acc = kind(path, type, acc)
    members(members, type, {path, value}, {acc, leaf})
  end

  defp whole({path, {:array, %FbType{} = type, dims} = array}, values, {acc, leaf}) do
    acc = kind(path, array, acc)

    indexed(dims, values, {acc, leaf}, fn index, value, with ->
      members(type.members, type, {Array.name(path, index), value}, with)
    end)
  end

  defp whole({_path, :clock}, value, {acc, _leaf}), do: {value, acc}
  defp whole({path, type}, value, {acc, leaf}), do: leaf.(path, type, value, acc)

  defp members(members, type, {path, value}, with),
    do:
      Enum.reduce(members, {value, elem(with, 0)}, fn %Member{name: name} = member,
                                                      {value, acc} ->
        {kept, acc} =
          whole(
            {path <> "." <> name, FbType.type_of(type, member)},
            Map.fetch!(value, name),
            {acc, elem(with, 1)}
          )

        {Map.put(value, name, kept), acc}
      end)

  # An instance's kind in the accumulator's kinds, where it keeps kinds: the walk that
  # takes an image out, and the one that finds what a program retains.
  # An element of an array of instances has no kind of its own: its array's names it.
  defp kind(path, _type, acc) when binary_part(path, byte_size(path) - 1, 1) == "]", do: acc

  defp kind(path, type, {kinds, values}) when is_map(kinds),
    do: {Map.put(kinds, path, kind_of(type)), values}

  defp kind(_path, _type, acc), do: acc

  defp kind_of(%FbType{name: name}), do: name
  defp kind_of({:array, %FbType{name: name}, dims}), do: {:array, name, dims}

  # Each element of an array of `dims`, by its index, each row's tuple built once.
  defp indexed(dims, values, with, fun), do: indexed(dims, values, [], with, fun)

  defp indexed([count | dims], values, above, {acc, leaf}, fun),
    do: row(0, {count, dims}, values, {above, leaf, fun}, {[], acc})

  defp row(count, {count, _dims}, _values, _at, {done, acc}),
    do: {done |> Enum.reverse() |> List.to_tuple(), acc}

  defp row(i, {count, dims}, values, {above, leaf, fun} = at, {done, acc}) do
    {kept, acc} = element(dims, elem(values, i), {above ++ [i], leaf, fun}, acc)
    row(i + 1, {count, dims}, values, at, {[kept | done], acc})
  end

  defp element([], value, {index, leaf, fun}, acc), do: fun.(index, value, {acc, leaf})

  defp element(dims, values, {index, leaf, fun}, acc),
    do: indexed(dims, values, index, {acc, leaf}, fun)

  # ---- the image checked ---------------------------------------------------------------

  # A resource's image, every problem a line of one ArgumentError, the matching forgiving
  # a changed configuration and never a broken image.
  def resource!(%{configuration: name, globals: globals, instances: instances} = image, config)
      when map_size(image) == 3 do
    lines =
      configuration_line(name, config.name) ++
        map_lines(globals, "globals", &global_lines/2) ++
        map_lines(instances, "instances", &instance_lines/2)

    raised(lines)
  end

  def resource!(other, _config),
    do:
      raise(
        ArgumentError,
        "a resource's retained image is a map of `configuration`, `globals` and `instances`, " <>
          "as Logex.Runtime.retained/1 gives one, got: #{inspect(other)}"
      )

  # A lone instance's image.
  def lone!(image, %Program{name: name}) do
    raised(lone_lines(image, "") ++ program_line(image, name))
  end

  defp raised([]), do: :ok
  defp raised(lines), do: raise(ArgumentError, Enum.join(lines, "\n"))

  defp configuration_line(name, name), do: []

  defp configuration_line(name, config),
    do: [
      "the retained image is of configuration #{quoted(name)}, and this configuration is " <>
        "`#{config}`: an image starts only the configuration it was taken from"
    ]

  defp quoted(name) when is_binary(name), do: "`#{name}`"
  defp quoted(name), do: inspect(name)

  defp program_line(%{program: name}, name), do: []

  defp program_line(%{program: name}, program) when is_binary(name),
    do: [
      "the retained image is of program `#{name}`, and this program is `#{program}`: an " <>
        "image starts only an instance of the program it was taken from"
    ]

  defp program_line(_image, _program), do: []

  defp map_lines(map, _what, fun) when is_map(map) and not is_struct(map),
    do: map |> Enum.sort() |> Enum.flat_map(fn {key, value} -> fun.(key, value) end)

  defp map_lines(other, what, _fun),
    do: ["the retained image's `#{what}` are no map, got: #{inspect(other)}"]

  defp global_lines(name, entry),
    do: name_lines(name, "globals") ++ entry_lines(entry, "`globals` holds #{inspect(name)}")

  defp instance_lines(name, image),
    do:
      name_lines(name, "instances") ++
        lone_lines(image, "instance #{inspect(name)}: ")

  defp name_lines(name, what) do
    named(Declarations.name?(name), name, what)
  end

  defp named(true, _name, _what), do: []

  defp named(false, name, what),
    do: ["`#{what}` holds #{inspect(name)}, which names no #{singular(what)}"]

  defp singular("globals"), do: "global"
  defp singular("instances"), do: "instance"

  defp lone_lines(%{program: program, kinds: kinds, values: values} = image, at)
       when map_size(image) == 3 and is_map(kinds) and not is_struct(kinds) and is_map(values) and
              not is_struct(values) do
    parsed_kinds = Map.new(kinds, fn {path, kind} -> {path, {parsed(path), kind}} end)

    program_lines(program, at) ++
      Enum.flat_map(Enum.sort(parsed_kinds), &kind_lines(&1, parsed_kinds, at)) ++
      Enum.flat_map(Enum.sort(values), &value_lines(&1, parsed_kinds, at))
  end

  defp lone_lines(other, at),
    do: [
      "#{at}a retained image is a map of `program`, `kinds` and `values`, as " <>
        "Logex.Runtime.retained/2 gives one, got: #{inspect(other)}"
    ]

  defp program_lines(program, at) do
    program_named(Declarations.name?(program), program, at)
  end

  defp program_named(true, _program, _at), do: []

  defp program_named(false, program, at),
    do: ["#{at}the image's `program` is #{inspect(program)}, which names no program"]

  defp kind_lines({path, {{:error, _}, _kind}}, _kinds, at),
    do: ["#{at}`kinds` holds #{inspect(path)}, which is no path"]

  defp kind_lines({path, {segments, kind}}, kinds, at),
    do:
      kind_word_lines(kind, path, at) ++
        whole_lines(segments, path, "`kinds`", at) ++
        above_lines(segments, kinds, {path, "`kinds`"}, at)

  defp kind_word_lines(kind, path, at) when is_binary(kind),
    do: kind_word(Declarations.name?(kind), kind, path, at)

  defp kind_word_lines({:array, kind, dims}, path, at) when is_binary(kind),
    do: kind_word(Declarations.name?(kind) and dims?(dims), {:array, kind, dims}, path, at)

  defp kind_word_lines(kind, path, at), do: kind_word(false, kind, path, at)

  defp kind_word(true, _kind, _path, _at), do: []

  defp kind_word(false, kind, path, at),
    do: [
      "#{at}`kinds` holds `#{path}` as #{inspect(kind)}, which is no kind of instance: a " <>
        "built-in's or a block's name, or {:array, name, sizes}"
    ]

  defp value_lines({path, entry}, kinds, at),
    do: value_at(parsed(path), path, entry, kinds, at)

  defp value_at({:error, _}, path, _entry, _kinds, at),
    do: ["#{at}`values` holds #{inspect(path)}, which is no path"]

  defp value_at(segments, path, entry, kinds, at),
    do:
      entry_lines(entry, "#{at}`values` holds `#{path}`") ++
        whole_lines(segments, path, "`values`", at) ++
        both_lines(Map.has_key?(kinds, path), path, at) ++
        clock_lines(segments, kinds, path, at) ++
        above_lines(segments, kinds, {path, "`values`"}, at)

  defp entry_lines({type, _value}, at), do: type_lines(type?(type), type, at)
  defp entry_lines(other, at), do: ["#{at} as #{inspect(other)}, which is no {type, value}"]

  defp type_lines(true, _type, _at), do: []

  defp type_lines(false, type, at),
    do: [
      "#{at} of the type #{inspect(type)}, which is no type of a retained value: an " <>
        "elementary type's atom, or {:array, type, sizes}"
    ]

  defp type?(type) when is_elementary(type), do: true
  defp type?({:array, type, dims}) when is_elementary(type), do: dims?(dims)
  defp type?(_type), do: false

  defp dims?(dims) when is_list(dims) and length(dims) in 1..3,
    do: Enum.all?(dims, &(is_integer(&1) and &1 > 0)) and Array.size(dims) <= Array.max_elements()

  defp dims?(_dims), do: false

  # An array is retained whole, so no entry is one of its elements.
  defp whole_lines(segments, path, what, at), do: last_whole(List.last(segments), path, what, at)

  defp last_whole({_name, nil}, _path, _what, _at), do: []

  defp last_whole({_name, _index}, path, what, at),
    do: ["#{at}#{what} holds `#{path}`, an element: an array is retained whole"]

  defp both_lines(false, _path, _at), do: []

  defp both_lines(true, path, at),
    do: [
      "#{at}`kinds` and `values` both hold `#{path}`, which is an instance or a value, never both"
    ]

  # Decision 273: a timer's `last` is never in an image.
  defp clock_lines(segments, kinds, path, at) do
    clocked(List.last(segments), above_kind(segments, kinds), path, at)
  end

  defp clocked({"last", nil}, kind, path, at) when is_binary(kind),
    do: clocked_kind(FbType.rules(FbType.builtin(kind)), path, at)

  defp clocked(_segment, _kind, _path, _at), do: []

  defp clocked_kind(%{kind: :timer}, path, at),
    do: [
      "#{at}`values` holds `#{path}`, a timer's clock, which no image holds: each retained " <>
        "timer starts at the start's `now`"
    ]

  defp clocked_kind(_rules, _path, _at), do: []

  # The kind of the instance a path's last segment is a member of, an array's elements'.
  defp above_kind(segments, kinds) when length(segments) > 1,
    do: element_kind(Map.get(kinds, key(Enum.drop(segments, -1))))

  defp above_kind(_segments, _kinds), do: nil

  defp element_kind({_segments, {:array, kind, _dims}}), do: kind
  defp element_kind({_segments, kind}), do: kind
  defp element_kind(nil), do: nil

  # Every instance above an entry is a kind the image holds: each segment's instance, an
  # element's its array's, of the right shape.
  defp above_lines(segments, kinds, {path, what}, at) do
    segments
    |> Enum.drop(-1)
    |> Enum.scan([], &(&2 ++ [&1]))
    |> Enum.flat_map(&above(Map.get(kinds, key(&1)), List.last(&1), key(&1), {path, what, at}))
  end

  defp above(nil, _segment, above, {path, what, at}),
    do: ["#{at}#{what} holds `#{path}`, under `#{above}`, which `kinds` does not hold"]

  defp above({_segments, {:array, _kind, dims}}, {_name, index}, above, {path, what, at})
       when is_list(index) do
    in_array(is_list(dims) and length(index) == length(dims) and within?(index, dims), above, {
      path,
      what,
      at
    })
  end

  defp above({_segments, {:array, _kind, _dims}}, {_name, nil}, above, {path, what, at}),
    do: [
      "#{at}#{what} holds `#{path}`, under `#{above}`, an array of instances, by no element"
    ]

  defp above({_segments, _kind}, {_name, index}, above, {path, what, at}) when is_list(index),
    do: [
      "#{at}#{what} holds `#{path}`, by an element of `#{above}`, which is no array of instances"
    ]

  defp above(_kind, _segment, _above, _at), do: []

  defp in_array(true, _above, _at), do: []

  defp in_array(false, above, {path, what, at}),
    do: ["#{at}#{what} holds `#{path}`, by an element outside `#{above}`'s sizes"]

  defp within?(index, dims), do: Enum.all?(Enum.zip(index, dims), fn {i, n} -> i < n end)

  # ---- paths ------------------------------------------------------------------------------

  # A path as segments, each `{name, nil}` or an element's `{name, index}`, or `{:error, path}`.
  defp parsed(path) when is_binary(path),
    do: segments(:binary.split(path, ".", [:global]), [], path)

  defp parsed(path), do: {:error, path}

  defp segments([], done, _path), do: Enum.reverse(done)

  defp segments([segment | rest], done, path),
    do: segment(Array.split(segment), segment, {rest, done, path})

  defp segment(nil, name, {rest, done, path}),
    do: segment_named(Declarations.name?(name), {name, nil}, {rest, done, path})

  defp segment({name, subscripts}, whole, {rest, done, path}),
    do:
      segment_named(
        Declarations.name?(name) and String.ends_with?(whole, "]") and
          Enum.all?(subscripts, &digits?/1),
        {name, Enum.map(subscripts, &String.to_integer/1)},
        {rest, done, path}
      )

  defp segment_named(true, segment, {rest, done, path}),
    do: segments(rest, [segment | done], path)

  defp segment_named(false, _segment, {_rest, _done, path}), do: {:error, path}

  defp digits?(<<>>), do: false
  defp digits?(text), do: String.match?(text, ~r/\A[0-9]+\z/)

  # The kinds key of an instance: its segments, its own subscript left off.
  defp key(segments) do
    {name, _index} = List.last(segments)
    segments |> Enum.drop(-1) |> Enum.map(&written/1) |> Kernel.++([name]) |> Enum.join(".")
  end

  defp written({name, nil}), do: name
  defp written({name, index}), do: Array.name(name, index)

  # ---- the matching (decision 277) --------------------------------------------------------

  # A lone instance's image laid over `env`, its fresh env: `{env, dropped}`, each kept
  # value where the program declares its path retained, of exactly its type, the value
  # fitting it, under instances of the kinds the image holds, and the rest dropped, each
  # once by its path, `prefix` before it, with its reason.
  def matched(%Program{} = program, env, %{kinds: kinds, values: values}, prefix) do
    wanted = wanted(program, env)
    kinds = Map.new(kinds, fn {path, kind} -> {path, {parsed(path), kind}} end)

    {statuses, dropped} =
      Enum.reduce(Enum.sort(kinds), {%{}, []}, fn {path, _kind}, acc ->
        {_status, acc} = status(path, kinds, {program, wanted}, acc)
        acc
      end)

    {kept, dropped} =
      Enum.reduce(Enum.sort(values), {%{}, dropped}, fn {path, entry}, {kept, dropped} ->
        valued(
          above_ok?(parsed(path), statuses),
          {path, entry},
          {program, wanted},
          {kept, dropped}
        )
      end)

    {laid(program, env, kept),
     dropped |> Enum.sort_by(&elem(&1, 0)) |> Enum.map(&prefixed(&1, prefix))}
  end

  defp prefixed({path, reason}, prefix), do: {prefix <> path, reason}

  # What a program retains, its kinds and values, from its fresh env.
  defp wanted(%Program{retained: nil}, _env), do: {%{}, %{}}

  defp wanted(%Program{retained: paths} = program, env),
    do:
      Enum.reduce(paths, {%{}, %{}}, fn path, acc ->
        {_value, acc} =
          along(path, program, env, acc, fn path, type, value, {kinds, values} ->
            {value, {kinds, Map.put(values, path, type)}}
          end)

        acc
      end)

  # An instance's kind matched, its ancestors' first: `:ok`, or `:dropped`, reported
  # once, every entry under it silent.
  defp status(path, kinds, at, {statuses, _dropped} = acc) do
    status_of(Map.fetch(statuses, path), path, kinds, at, acc)
  end

  defp status_of({:ok, status}, _path, _kinds, _at, acc), do: {status, acc}

  defp status_of(:error, path, kinds, at, acc) do
    {segments, kind} = Map.fetch!(kinds, path)
    {up, {statuses, dropped}} = above_status(Enum.drop(segments, -1), kinds, at, acc)
    {status, dropped} = own_kind(up, {path, kind}, segments, at, dropped)
    {status, {Map.put(statuses, path, status), dropped}}
  end

  defp above_status([], _kinds, _at, acc), do: {:ok, acc}

  defp above_status(segments, kinds, at, acc), do: status(key(segments), kinds, at, acc)

  defp own_kind(:ok, {path, kind}, segments, {program, {wanted_kinds, _values}}, dropped),
    do: judged(kind, Map.get(wanted_kinds, path), {path, segments, program}, dropped)

  defp own_kind(_dropped, _kind, _segments, _at, dropped), do: {:silent, dropped}

  # Declared, of exactly its type, retained; for a value, fitting too.
  defp judged(stored, stored, _at, dropped), do: {:ok, dropped}

  defp judged(stored, nil, {path, segments, program}, dropped),
    do: unwanted(stored, type_at(segments, program), path, dropped)

  defp judged(stored, now, {path, _segments, _program}, dropped),
    do: {:dropped, [{path, changed(stored, now)} | dropped]}

  defp unwanted(_stored, :undeclared, path, dropped),
    do: {:dropped, [{path, :undeclared} | dropped]}

  defp unwanted(stored, stored, path, dropped), do: {:dropped, [{path, :unretained} | dropped]}

  defp unwanted(stored, now, path, dropped),
    do: {:dropped, [{path, changed(stored, now)} | dropped]}

  defp changed({:array, type, from}, {:array, type, to}), do: {:resized, from, to}
  defp changed(stored, now), do: {:retyped, stored, now}

  defp above_ok?({:error, _}, _statuses), do: false

  defp above_ok?(segments, statuses),
    do:
      segments
      |> Enum.drop(-1)
      |> Enum.scan([], &(&2 ++ [&1]))
      |> Enum.all?(&(Map.fetch!(statuses, key(&1)) == :ok))

  defp valued(false, _entry, _at, acc), do: acc

  defp valued(true, {path, {type, value}}, {program, {_kinds, wanted}}, {kept, dropped}) do
    valued_as(
      judged(type, Map.get(wanted, path), {path, parsed(path), program}, dropped),
      {path, type, value},
      {kept, dropped}
    )
  end

  defp valued_as({:ok, dropped}, {path, type, value}, {kept, _dropped}),
    do: fitted(fits?(type, value), {path, value}, {kept, dropped})

  defp valued_as({:dropped, dropped}, _entry, {kept, _dropped}), do: {kept, dropped}

  defp fitted(true, {path, value}, {kept, dropped}), do: {Map.put(kept, path, value), dropped}
  defp fitted(false, {path, _value}, {kept, dropped}), do: {kept, [{path, :misfit} | dropped]}

  # A value fits as a state's does (decisions 171 to 188): an integer or a bool of its
  # type's range, a real of its type's values, an array a host's list of its shape.
  def fits?({:array, type, dims}, value), do: Array.listed?(value, dims, &fits?(type, &1))
  def fits?(type, value) when is_fitting(type, value), do: true
  def fits?(type, value) when type in @reals, do: Logex.Real.value?(type, value)
  def fits?(_type, _value), do: false

  # The type a program declares at a path, in the image's words, or `:undeclared`.
  defp type_at([{name, index} | rest], %Program{tags: tags, blocks: blocks}),
    do: tag_at(Map.fetch(tags, name), {index, rest}, blocks)

  defp tag_at(:error, _at, _blocks), do: :undeclared

  defp tag_at({:ok, %Logex.Tag{type: type}}, {index, rest}, blocks),
    do: inside(typed(type, blocks), index, rest)

  defp inside(type, nil, []), do: image_type(type)

  # An element of an array of instances: its subscripts are within the array's sizes by
  # now, the array's kind matched, sizes and all, and the image's check holding the
  # subscripts to the stored ones.
  defp inside({:array, %FbType{} = type, _dims}, index, [{name, below} | rest])
       when is_list(index),
       do: member_inside(member!(type, name), type, {below, rest})

  defp inside(%FbType{} = type, nil, [{name, index} | rest]),
    do: member_inside(member!(type, name), type, {index, rest})

  defp inside(_type, _index, _rest), do: :undeclared

  defp member_inside(nil, _type, _at), do: :undeclared

  defp member_inside(member, type, {index, rest}),
    do: inside(FbType.type_of(type, member), index, rest)

  defp image_type(%FbType{} = type), do: kind_of(type)
  defp image_type({:array, %FbType{}, _dims} = type), do: kind_of(type)
  defp image_type(type), do: type

  # The kept values laid over the fresh env: one walk of the retained paths, each leaf the
  # kept value where there is one, an array's made a tuple, and the fresh one otherwise.
  defp laid(_program, env, kept) when map_size(kept) == 0, do: env

  defp laid(%Program{retained: paths} = program, env, kept),
    do:
      Enum.reduce(paths, env, fn path, env ->
        {env, nil} = along(path, program, env, nil, &put_back(&1, &2, &3, &4, kept))
        env
      end)

  defp put_back(path, type, value, nil, kept), do: {held(Map.fetch(kept, path), type, value), nil}

  defp held({:ok, list}, {:array, _type, dims}, _fresh), do: Array.from_list(list, dims, & &1)

  defp held({:ok, value}, _type, _fresh), do: value
  defp held(:error, _type, fresh), do: fresh

  # The retained globals of an image laid over a resource's: `{globals, dropped, kept}`,
  # `kept` the names of those it put back.
  def matched_globals(declared, values, stored) do
    by_name = Map.new(declared, &{&1.name, &1})

    {values, dropped, kept} =
      Enum.reduce(Enum.sort(stored), {values, [], []}, fn {name, {type, value}}, acc ->
        global(Map.get(by_name, name), {name, type, value}, acc)
      end)

    {values, Enum.reverse(dropped), kept}
  end

  defp global(nil, {name, _type, _value}, {values, dropped, kept}),
    do: {values, [{name, :undeclared} | dropped], kept}

  defp global(%{type: now}, {name, type, _value}, {values, dropped, kept}) when now != type,
    do: {values, [{name, changed(type, now)} | dropped], kept}

  defp global(%{retain: retain}, {name, _type, _value}, {values, dropped, kept})
       when retain != :retain,
       do: {values, [{name, :unretained} | dropped], kept}

  defp global(_global, {name, type, value}, acc),
    do: fitted_global(fits?(type, value), {name, type, value}, acc)

  defp fitted_global(true, {name, type, value}, {values, dropped, kept}),
    do: {Map.put(values, name, stored(type, value)), dropped, [name | kept]}

  defp fitted_global(false, {name, _type, _value}, {values, dropped, kept}),
    do: {values, [{name, :misfit} | dropped], kept}

  defp stored({:array, _type, dims}, list), do: Array.from_list(list, dims, & &1)
  defp stored(_type, value), do: value
end
