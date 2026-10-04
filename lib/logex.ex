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

  alias Logex.{Compiler, Diagnostic, FbType, Program}

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
  of one name. Each is checked again, at full depth, so a type edited by hand is refused
  here (`Logex.FbType.user?/1`). The options come in either order, and `types` defaults
  to none.

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

  A file that cannot be read, or whose name cannot name a program, is a `:file`
  diagnostic, not an exception. After a refused name the source is still compiled, so its
  own mistakes are listed too.
  """
  def compile_file(path) when is_binary(path), do: in_file(read(File.read(path), path), path)

  def compile_file(path),
    do:
      raise(ArgumentError, "Logex.compile_file/1 takes a path as a binary, got: #{inspect(path)}")

  defp read({:error, reason}, _path),
    do: {:error, [file_problem("cannot be read: #{:file.format_error(reason)}")]}

  defp read({:ok, source}, path) do
    name = Path.rootname(Path.basename(path))
    from_file(name_problem(name), name, source)
  end

  defp from_file(nil, name, source), do: compiled(source, name, [])

  defp from_file(problem, _name, source),
    do: {:error, [file_problem(problem <> " (rename the file)") | mistakes(source)]}

  defp mistakes(source), do: mistakes_in(compiled(source, nil, []))

  defp mistakes_in({:ok, _program}), do: []
  defp mistakes_in({:error, diagnostics}), do: diagnostics

  defp file_problem(message), do: %Diagnostic{stage: :file, line: nil, message: message}

  defp in_file({:ok, %Program{} = program}, path), do: {:ok, filed(program, path)}

  defp in_file({:ok, %FbType{body: body}}, path), do: {:ok, FbType.of(filed(body, path))}

  defp in_file({:error, diagnostics}, path),
    do: {:error, Enum.map(diagnostics, &%{&1 | file: path})}

  # Shape only. Reserved words are scoped by file kind (docs/organisation.md decision 10),
  # and a program type's name is never spelled inside a `.ld` body.
  defp name_problem(name), do: shaped(Logex.Declarations.name?(name), name)

  defp shaped(true, _name), do: nil

  defp shaped(false, name),
    do:
      "#{inspect(name)} cannot name a program: a name is a letter or `_`, " <>
        "then letters, digits or `_`"

  defp filed(%Program{warnings: warnings} = program, path),
    do: %{program | file: path, warnings: Enum.map(warnings, &%{&1 | file: path})}

  defp compiled(source, name, types),
    do: lexed(Compiler.tokenize(source), {source, name, types})

  defp lexed({:ok, tokens, _end_line}, compiling), do: parsed(Compiler.parse(tokens), compiling)

  defp lexed({:error, {{line, column}, module, reason}, _line}, _compiling),
    do: {:error, [front_end(:lex, line, column, module.format_error(reason))]}

  defp parsed({:ok, ast}, {source, name, types}),
    do: named_as(Compiler.instructionize(ast, [], types), header(ast), source, name)

  defp parsed({:error, {{line, column}, module, reason}}, _compiling),
    do: {:error, [front_end(:parse, line, column, module.format_error(reason))]}

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
