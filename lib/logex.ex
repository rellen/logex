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

  # Decision 432 (RV-15): the three are Logex.Compiler's, delegated, so that the loader and
  # its own compile of a file over the blocks it compiled itself are private code of the
  # module that compiles, which nothing a host hands in reaches.

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
  defdelegate compile(source, options), to: Logex.Compiler

  @doc """
  Reads and compiles the file at `path`, naming the program after the file:
  `motor.ld` is `motor`. Every diagnostic and warning carries `file: path`, and so does
  the program, as its `file` (fix F15), which `Logex.Edit`'s diagnostics then carry. A
  block's file compiles to its type, as `compile/2` says, its body carrying the file.

  A type word that names no built-in type and could name a function block, `var s1 seal`,
  is looked for as a block's file beside the file that names it, `seal.ld`, which is
  compiled first, once a call however many files name it (decision 34). A type the loader
  compiled so is not compiled again from its text when the file that names it compiles,
  as a type `compile/2` is given is (decision 371): the loader trusts its own, within its
  own call, so a chain of files each holding the next compiles once a file. The trust is
  no token and no mark (decision 432): the loader and its own compile are private code of
  `Logex.Compiler`, the types it compiled handed on along private functions alone, which
  no closure, struct or term a host hands in reaches, and no field of a type, option or
  name marks a type the loader's. So a type it gave and a host hands in, to `compile/2`
  or in a list to the compiler's internal entry, is checked as any other (decision 54),
  and one edited by hand is refused, and a closure handed there is refused and never
  called, however it was made (decision 430). A type word is read by its place on the
  line, after a qualifier, `var retain s1 seal`, and with an array's sizes,
  `var gates gate[4]` loading `gate.ld` (decision 154). A mistake in a block's file
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
  defdelegate compile_file(path), to: Logex.Compiler

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
  defdelegate compile_files(paths), to: Logex.Compiler
end
