defmodule Logex do
  @moduledoc """
  Compiles ladder source into a named `%Logex.Program{}`, or reports every mistake in it.

  A program is compiled once and run as many times, and as many instances, as needed:

      iex> source = \"""
      ...> var_input start bool
      ...> var_input stop bool
      ...> var_output motor bool
      ...> ( xic start | xic motor ) xio stop ote motor
      ...> \"""
      iex> {:ok, seal} = Logex.compile(source, name: "seal")
      iex> seal.name
      "seal"
      iex> state = Logex.Runtime.instance(seal)
      iex> state = Logex.Runtime.put_inputs(seal, state, %{"start" => 1})
      iex> {outputs, state} = Logex.Runtime.scan(seal, state)
      iex> outputs
      %{"motor" => 1}
      iex> state = Logex.Runtime.put_inputs(seal, state, %{"start" => 0})
      iex> {outputs, state} = Logex.Runtime.scan(seal, state, 10)
      iex> outputs
      %{"motor" => 1}
      iex> state = Logex.Runtime.put_inputs(seal, state, %{"stop" => 1})
      iex> {outputs, _state} = Logex.Runtime.scan(seal, state, 10)
      iex> outputs
      %{"motor" => 0}

  Released, the start button leaves the motor sealed in; the stop button drops it out.

  A mistake is a located diagnostic, not an exception:

      iex> {:error, [diagnostic]} = Logex.compile("var_input a bool\\nxyz a", name: "seal")
      iex> Logex.Diagnostic.format(diagnostic)
      "line 2: unknown instruction `xyz`"
  """

  alias Logex.{Compiler, Declarations, Diagnostic, FbType, Program}

  @doc """
  Compiles `source` into a program named `name`: `{:ok, %Logex.Program{}}`, or
  `{:error, diagnostics}` with every mistake in line order. A lex or parse error stops the
  compile and is the only diagnostic, with its column.

  A source whose first rung is `function_block <name>`, comments and blank lines allowed
  before it, is a function block's (M2-5), and compiles to its type,
  `{:ok, %Logex.FbType{}}`, whose `body` is the program of its rungs, warnings included.
  Its name must be `name`, as a file's must be the file's.

  `types` are the function blocks the source may declare instances of, `var s1 seal`
  (decision 34): each a `%Logex.FbType{}` this function gave for a block's source, no two
  of one name. Each is compiled again from its source text, at full depth, and must be
  the one that text gives, so a type edited by hand is refused here (decision 54,
  `Logex.FbType.user?/1`), a type the tables of several of them share compiled again once
  (`Logex.FbType.check/2`). The
  program, or the block's type, holds every type its instances reach, at any depth, once,
  in one table, its `blocks`, and each instance's tag names its type (decision 53). The
  options come in either order, and `types` defaults to none.

  A name is required, because a configuration refers to a program type by its name. It is
  a letter or `_`, then letters, digits or `_`. A call that breaks this contract raises
  `ArgumentError`; nothing in the source does.
  """
  def compile(source, options)

  def compile(source, _options) when not is_binary(source),
    do:
      raise(
        ArgumentError,
        "Logex.compile/2 takes source text as a binary, got: #{inspect(source)}"
      )

  def compile(source, name: name), do: compile(source, name: name, types: [])
  def compile(source, types: types, name: name), do: compile(source, name: name, types: types)

  def compile(source, name: name, types: types) when is_binary(name),
    do: named(name_problem(name), name, source, types)

  def compile(_source, name: name, types: _types),
    do: raise(ArgumentError, "a program's name is a string, got: #{inspect(name)}")

  def compile(_source, options),
    do:
      raise(
        ArgumentError,
        "Logex.compile/2 takes a name and, where the source uses function blocks, their " <>
          ~s|types, as in Logex.compile(source, name: "motor", types: [seal]), | <>
          "got: #{inspect(options)}"
      )

  defp named(nil, name, source, types), do: compiled(source, name, types)
  defp named(problem, _name, _source, _types), do: raise(ArgumentError, problem)

  @doc """
  Reads and compiles the file at `path`, naming the program after the file:
  `motor.ld` is `motor`. Every diagnostic and warning carries `file: path`, and so does
  the program, as its `file` (fix F15), which `Logex.Edit`'s diagnostics then carry. A
  block's file compiles to its type, as `compile/2` says, its body carrying the file.

  A type word that names no built-in type and could name a function block, `var s1 seal`,
  is looked for as a block's file beside the file that names it, `seal.ld`, which is
  compiled first, once a call however many files name it (decision 34). A mistake in it
  is reported with its own file, and the file that names it is compiled no further, as
  after a lex or parse error. So are a chain of files that holds itself, reported at the
  line in the file that closes it, and a program's file named as a type, at the line that
  names it. The mistakes of the blocks a file names come in the order it names them.

  A program's `warnings` are its own, in line order, then each loaded block's, once a
  call, each stamped with its block's file (decision 34), a block that a block holds
  among them, in the order the loader compiled them: a block's after those of the blocks
  it holds. They stay in each block's type too. A block's file compiles to a type
  `compile/2` could give, its body's warnings its own (`Logex.FbType.user?/1`), so it
  hands back no other. `compile/2`, whose host compiled each block, gives only the
  program's.

  `path` is a `.ld` file's, exactly, since the extension says what kind of file it is
  (M2-2): any other, `seal.txt`, `seal.LD` or `seal` among them, is a `:file`
  diagnostic, and nothing is read; a configuration file (`.logex`) is told that
  `Logex.Configuration.compile_file/1` loads it. A file named only `.ld` is one whose name
  names no program, below.

  A file that cannot be read, or whose name cannot name a program, is a `:file`
  diagnostic, not an exception. After a refused name the source is still compiled, with
  the blocks beside it, so its own mistakes are listed too.
  """
  def compile_file(path) when is_binary(path) do
    {result, _call} = of_kind(Path.extname(path), Path.basename(path), path, {%{}, MapSet.new()})
    result
  end

  def compile_file(path),
    do:
      raise(ArgumentError, "Logex.compile_file/1 takes a path as a binary, got: #{inspect(path)}")

  @doc """
  Compiles each of `paths` as `compile_file/1` compiles it, in one call: a result a path,
  in their order. One memo serves the call (decision 34, M2-2), so a block that several of
  the files hold, at any depth, is read and compiled once, and its warnings are handed
  back once, among those of the first program in `paths` that holds it and compiles: a
  block's own file in `paths` hands back nothing, so a program after it still hands its
  blocks' warnings back. A chain of files that holds itself is found again for each path,
  since what it cites depends on the file it was reached from. A path given twice gives
  its one result twice. `Logex.Configuration.compile_file/1` loads a configuration's
  program types through it.

  `paths` that is not a proper list of binaries is the host's mistake, raised as
  `ArgumentError` before any file is read.
  """
  def compile_files(paths) do
    paths!(paths, paths)
    {results, _acc} = Enum.map_reduce(paths, {%{}, {%{}, MapSet.new()}}, &compiled_once/2)
    results
  end

  defp paths!([], _paths), do: :ok
  defp paths!([path | rest], paths) when is_binary(path), do: paths!(rest, paths)

  defp paths!(_not_paths, paths),
    do:
      raise(
        ArgumentError,
        "Logex.compile_files/1 takes a list of paths as binaries, got: #{inspect(paths)}"
      )

  # `done` is each path's result, as given back; `call` is the call's memo and the paths
  # of the blocks whose warnings a program has handed back, kept apart.
  defp compiled_once(path, {done, call}), do: once(Map.fetch(done, path), path, {done, call})

  defp once({:ok, result}, _path, acc), do: {result, acc}

  defp once(:error, path, {done, call}) do
    {result, call} = of_kind(Path.extname(path), Path.basename(path), path, call)
    {result, {Map.put(done, path, result), call}}
  end

  # The gate in front of the loader: the extension says what a file is, so only a `.ld`
  # file is read. A file named only `.ld` has no extension to Elixir, and is a `.ld` file
  # whose name names nothing, which the loader says.
  defp of_kind(".ld", _basename, path, call), do: loaded(path, call)
  defp of_kind("", ".ld", path, call), do: loaded(path, call)

  defp of_kind(".logex", basename, path, call),
    do:
      {not_ld(
         path,
         "`#{basename}` is a configuration file (`.logex`), which " <>
           "Logex.Configuration.compile_file/1 loads"
       ), call}

  defp of_kind(_extension, basename, path, call),
    do:
      {not_ld(
         path,
         "`#{basename}` is not a `.ld` file: Logex.compile_file/1 compiles a program " <>
           "or a function block from its `.ld` file"
       ), call}

  defp not_ld(path, message), do: {:error, [%{file_problem(message) | file: path}]}

  # One path of the call: its result, and the call's memo and handed-back paths after it.
  # The memo keeps each file's result with the blocks it reaches, so a program whose blocks
  # an earlier path compiled still finds them; a result a cycle gave is not kept past this
  # path, since what it cites depends on the files loaded above it.
  defp loaded(path, {memo, handed}) do
    {{result, reached, _cyclic}, {memo, cyclic}} = load(path, {%{}, []}, {memo, []})
    {result, handed} = handed_back(result, reached, memo, handed)
    {result, {Map.drop(memo, cyclic), handed}}
  end

  # `held` are the names of the files being loaded, as a set and as a list, innermost
  # first, so a cycle is found in one lookup and named only when there is one. The memo
  # is each file compiled so far, by path, so none is compiled twice, as `{result,
  # reached, cyclic}`: `reached` the paths of the blocks it holds, at any depth, each once,
  # a block after those it holds, and `cyclic` whether a cycle gave it. Beside it, the
  # paths this load gave a cyclic result.
  defp load(path, held, {memo, _cyclic} = state),
    do: loading(Map.fetch(memo, path), path, held, state)

  defp loading({:ok, entry}, _path, _held, state), do: {entry, state}

  defp loading(:error, path, held, state) do
    {{result, reached, cyclic}, {memo, cyclics}} = read(File.read(path), path, held, state)
    entry = {in_file(result, path), reached, cyclic}
    {entry, {Map.put(memo, path, entry), cyclics(cyclic, path, cyclics)}}
  end

  defp cyclics(true, path, cyclics), do: [path | cyclics]
  defp cyclics(false, _path, cyclics), do: cyclics

  # The program's own warnings, then those of every block it reaches that no program of
  # the call has handed back, a block's after those of the blocks it holds. Every block a
  # program that compiles reaches compiled too. A block's type, or a mistake, hands back
  # nothing, and counts no block as handed back.
  defp handed_back({:ok, %Program{warnings: own} = program}, reached, memo, handed) do
    fresh = Enum.reject(reached, &MapSet.member?(handed, &1))

    blocks =
      for path <- fresh,
          {{:ok, %FbType{body: body}}, _reached, _cyclic} = Map.fetch!(memo, path),
          do: body.warnings

    {{:ok, %{program | warnings: own ++ Enum.concat(blocks)}},
     MapSet.union(handed, MapSet.new(fresh))}
  end

  defp handed_back(result, _reached, _memo, handed), do: {result, handed}

  defp read({:error, reason}, _path, _held, state),
    do:
      {{{:error, [file_problem("cannot be read: #{:file.format_error(reason)}")]}, [], false},
       state}

  defp read({:ok, source}, path, held, state) do
    name = Path.rootname(Path.basename(path))
    from_file(name_problem(name), {name, path}, source, {held, state})
  end

  defp from_file(nil, {name, path}, source, context),
    do: parsed_file(parse(source), {name, path, name}, source, context)

  # A refused name still finds the blocks beside the file, so only the source's own
  # mistakes follow the name's: its blocks are no unknown types, nor their uses undeclared.
  # It is compiled under no name, as `compile/2` would not take this one.
  defp from_file(problem, {name, path}, source, context) do
    {{result, reached, cyclic}, state} =
      parsed_file(parse(source), {name, path, nil}, source, context)

    {{{:error, [file_problem(problem <> " (rename the file)") | mistakes_in(result)]}, reached,
      cyclic}, state}
  end

  defp parsed_file({:ok, ast}, {name, path, as}, source, {{set, list}, state}) do
    held = {Map.put(set, name, true), [name | list]}

    {types, problems, {reached, cyclic}, state} =
      ast
      |> needed(name)
      |> Enum.reduce({[], [], {[], false}, state}, &dependency(&1, &2, {path, held}))

    {{built(problems, ast, {as, source}, types), Enum.uniq(Enum.reverse(reached)), cyclic}, state}
  end

  defp parsed_file(front_end, _file, _source, {_held, state}), do: {{front_end, [], false}, state}

  defp built([], ast, {name, source}, types), do: lowered(ast, source, name, types)
  defp built(problems, _ast, _file, _types), do: {:error, Enum.uniq(Enum.reverse(problems))}

  # The type words of the declaration lines that could name a function block, and are not
  # the file's own name, which the compiler refuses as recursion: each once, at its first
  # line, in line order. A word no block can be named, a dotted one among them, is no
  # file's, and the compiler reports it where it is written.
  # Since M5-14 an array of a block's instances names the block by its type word's base,
  # `gate` of `gate[4]` (decision 154).
  defp needed({:routine, {:rungs, rungs}}, own) do
    words =
      for {:rung, [{:name, _, section}, {:name, _, _tag}, {:name, line, typed} | _]} <-
            Enum.map(rungs, &Declarations.unqualified/1),
          Declarations.reserved(section) == :section,
          word = unsized(typed),
          Declarations.block_name?(word),
          word != own,
          do: {word, line}

    Enum.uniq_by(words, &elem(&1, 0))
  end

  defp unsized(word), do: hd(:binary.split(word, "["))

  defp dependency({word, line}, acc, {path, held}) do
    file = Path.join(Path.dirname(path), word <> ".ld")
    found(File.exists?(file), {word, line, file}, acc, held)
  end

  # Nothing of that name: the compiler reports the type as unknown. Something that is no
  # file, a directory, is loaded, to be reported as one that cannot be read, with its path.
  defp found(false, _word, acc, _held), do: acc

  # A program's file is no type, whatever names it: said so before any cycle is looked for,
  # since a program may hold the block that names it, and its file is not compiled here.
  defp found(true, {_word, _line, file} = named, acc, held),
    do: kind_of(peek(file), named, acc, held)

  defp kind_of(:program, {word, line, file}, {types, problems, reach, state}, _held) do
    message =
      "`#{word}` is a program (#{Path.basename(file)}), not a function block: " <>
        "only a function block's file gives a type for `var`"

    {types, [%Diagnostic{stage: :validate, line: line, message: message} | problems], reach,
     state}
  end

  defp kind_of(_block_or_unread, {word, _line, _file} = named, acc, {set, _list} = held),
    do: cycle(is_map_key(set, word), named, acc, held)

  # A file's kind, from the first word of its first rung, in any case, as the compiler
  # reads a block's header: `:unknown` for a file that cannot be read or parsed, which is
  # loaded to report why.
  defp peek(file), do: peeked(File.read(file))

  defp peeked({:ok, source}), do: kind(parse(source))
  defp peeked({:error, _reason}), do: :unknown

  defp kind({:ok, {:routine, {:rungs, [{:rung, [{:name, _, word} | _]} | _]}}}),
    do: headed(String.downcase(word) in Declarations.kinds())

  defp kind({:ok, _ast}), do: :program
  defp kind({:error, _diagnostics}), do: :unknown

  defp headed(true), do: :block
  defp headed(false), do: :program

  # A cycle's message names the chain of files loaded above it, so the result it gives,
  # and every result above it, is cyclic.
  defp cycle(true, {word, line, _file}, {types, problems, {reached, _cyclic}, state}, held) do
    {_set, [own | _] = list} = held
    chain = [own | Enum.drop_while(Enum.reverse(list), &(&1 != word))]

    message =
      "`#{own}` cannot hold an instance of `#{word}` (#{Enum.join(chain, " → ")}): " <>
        "a function block never holds an instance of itself, at any depth"

    {types, [%Diagnostic{stage: :validate, line: line, message: message} | problems],
     {reached, true}, state}
  end

  defp cycle(false, {_word, _line, file}, {types, problems, reach, state}, held) do
    {{result, below, cyclic}, state} = load(file, held, state)
    dependent(result, {types, problems, reached(reach, below, file, cyclic), state})
  end

  # The blocks a file reaches, newest first: those its block reaches, then the block.
  defp reached({reached, cyclic}, below, file, below_cyclic),
    do: {[file | Enum.reverse(below, reached)], cyclic or below_cyclic}

  defp dependent({:ok, %FbType{} = type}, {types, problems, reach, state}),
    do: {[type | types], problems, reach, state}

  defp dependent({:error, diagnostics}, {types, problems, reach, state}),
    do: {types, Enum.reverse(diagnostics, problems), reach, state}

  defp mistakes_in({:ok, _program}), do: []
  defp mistakes_in({:error, diagnostics}), do: diagnostics

  defp file_problem(message), do: %Diagnostic{stage: :file, line: nil, message: message}

  defp in_file({:ok, %Program{} = program}, path), do: {:ok, filed(program, path)}

  defp in_file({:ok, %FbType{body: body}}, path), do: {:ok, FbType.of(filed(body, path))}

  # Each diagnostic is stamped with the file it was found in, so one from a block's file
  # that this file names carries that file already.
  defp in_file({:error, diagnostics}, path),
    do: {:error, Enum.map(diagnostics, &%{&1 | file: &1.file || path})}

  # Shape only. Reserved words are scoped by file kind (docs/organisation.md decision 10),
  # and a program type's name is never spelled inside a `.ld` body.
  defp name_problem(name), do: shaped(Declarations.name?(name), name)

  defp shaped(true, _name), do: nil

  defp shaped(false, name),
    do:
      "#{inspect(name)} cannot name a program: a name is a letter or `_`, " <>
        "then letters, digits or `_`"

  defp filed(%Program{warnings: warnings} = program, path),
    do: %{program | file: path, warnings: Enum.map(warnings, &%{&1 | file: path})}

  defp compiled(source, name, types), do: built_from(parse(source), source, name, types)

  defp built_from({:ok, ast}, source, name, types), do: lowered(ast, source, name, types)
  defp built_from(front_end, _source, _name, _types), do: front_end

  # `{:ok, ast}`, or a lex or parse error as the one diagnostic, with its column.
  defp parse(source), do: lexed(Compiler.tokenize(source))

  defp lexed({:ok, tokens, _end_line}), do: parsed(Compiler.parse(tokens))

  defp lexed({:error, {{line, column}, module, reason}, _line}),
    do: {:error, [front_end(:lex, line, column, module.format_error(reason))]}

  defp parsed({:ok, ast}), do: {:ok, ast}

  defp parsed({:error, {{line, column}, module, reason}}),
    do: {:error, [front_end(:parse, line, column, module.format_error(reason))]}

  defp lowered(ast, source, name, types),
    do: named_as(Compiler.instructionize(ast, [], types), header(ast), source, name)

  defp named_as({:ok, %Program{} = program}, _header, source, name),
    do: {:ok, %{program | name: name, source: source}}

  # M2-5: a block is named by its first rung, which must be the name it is compiled under.
  defp named_as({:ok, %FbType{name: name, body: body}}, _header, source, name),
    do: {:ok, FbType.of(%{body | source: source})}

  # Compiled with no name, after the file's name was refused: only its own mistakes count.
  defp named_as({:ok, %FbType{}} = block, _header, _source, nil), do: block

  defp named_as({:ok, %FbType{name: block}}, {line, _block}, _source, name),
    do: {:error, [misnamed(line, block, name)]}

  defp named_as({:error, diagnostics}, {line, block}, _source, name)
       when is_binary(block) and is_binary(name) and block != name,
       do: {:error, Enum.sort_by([misnamed(line, block, name) | diagnostics], & &1.line)}

  defp named_as({:error, diagnostics}, _header, _source, _name), do: {:error, diagnostics}

  defp misnamed(line, block, name),
    do: %Diagnostic{
      stage: :validate,
      line: line,
      message:
        "this function block is `#{block}`, but it is compiled as `#{name}`: " <>
          "a block is named after its file"
    }

  # The block's line and name, from a first rung `function_block <name>` in any case, or
  # nil for anything else, a program's first rung among them.
  defp header({:routine, {:rungs, [{:rung, [{:name, line, word}, {:name, _, block}]} | _]}}),
    do: heading(String.downcase(word), line, block)

  defp header(_ast), do: nil

  defp heading("function_block", line, block), do: {line, block}
  defp heading(_word, _line, _block), do: nil

  defp front_end(stage, line, column, message),
    do: %Diagnostic{stage: stage, line: line, column: column, message: message}
end
