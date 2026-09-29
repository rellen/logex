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

  A mistake is a located diagnostic, not an exception:

      iex> {:error, [diagnostic]} = Logex.compile("var_input a bool\\nxyz a", name: "seal")
      iex> Logex.Diagnostic.format(diagnostic)
      "line 2: unknown instruction `xyz`"
  """

  alias Logex.{Compiler, Diagnostic, Program}

  @doc """
  Compiles `source` into a program named `name`: `{:ok, %Logex.Program{}}`, or
  `{:error, diagnostics}` with every mistake in line order. A lex or parse error stops the
  compile and is the only diagnostic, with its column.

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

  def compile(source, name: name) when is_binary(name),
    do: named(name_problem(name), name, source)

  def compile(_source, name: name),
    do: raise(ArgumentError, "a program's name is a string, got: #{inspect(name)}")

  def compile(_source, options),
    do:
      raise(
        ArgumentError,
        "Logex.compile/2 takes a name and no other option, as in " <>
          ~s|Logex.compile(source, name: "motor"), got: #{inspect(options)}|
      )

  defp named(nil, name, source), do: compiled(source, name)
  defp named(problem, _name, _source), do: raise(ArgumentError, problem)

  @doc """
  Reads and compiles the file at `path`, naming the program after the file:
  `motor.ld` is `motor`. Every diagnostic and warning carries `file: path`.

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

  defp from_file(nil, name, source), do: compiled(source, name)

  defp from_file(problem, _name, source),
    do: {:error, [file_problem(problem <> " (rename the file)") | mistakes(source)]}

  defp mistakes(source), do: mistakes_in(compiled(source, nil))

  defp mistakes_in({:ok, _program}), do: []
  defp mistakes_in({:error, diagnostics}), do: diagnostics

  defp file_problem(message), do: %Diagnostic{stage: :file, line: nil, message: message}

  defp in_file({:ok, program}, path),
    do: {:ok, %{program | warnings: Enum.map(program.warnings, &%{&1 | file: path})}}

  defp in_file({:error, diagnostics}, path),
    do: {:error, Enum.map(diagnostics, &%{&1 | file: path})}

  # Shape only. Reserved words are scoped by file kind (docs/organisation.md decision 10),
  # and a program type's name is never spelled inside a `.ld` body.
  defp name_problem(name),
    do: shaped(String.match?(name, ~r/\A[A-Za-z_][A-Za-z0-9_]*\z/), name)

  defp shaped(true, _name), do: nil

  defp shaped(false, name),
    do:
      "#{inspect(name)} cannot name a program: a name is a letter or `_`, " <>
        "then letters, digits or `_`"

  defp compiled(source, name), do: lexed(Compiler.tokenize(source), source, name)

  defp lexed({:ok, tokens, _end_line}, source, name),
    do: parsed(Compiler.parse(tokens), source, name)

  defp lexed({:error, {{line, column}, module, reason}, _line}, _source, _name),
    do: {:error, [front_end(:lex, line, column, module.format_error(reason))]}

  defp parsed({:ok, ast}, source, name), do: lowered(Compiler.instructionize(ast), source, name)

  defp parsed({:error, {{line, column}, module, reason}}, _source, _name),
    do: {:error, [front_end(:parse, line, column, module.format_error(reason))]}

  defp lowered({:ok, %Program{} = program}, source, name),
    do: {:ok, %{program | name: name, source: source}}

  defp lowered({:error, diagnostics}, _source, _name), do: {:error, diagnostics}

  defp front_end(stage, line, column, message),
    do: %Diagnostic{stage: stage, line: line, column: column, message: message}
end
