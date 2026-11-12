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

  **A compile's own process** (decision 520). Each of `compile/2`, `compile_file/1` and
  `compile_files/1` compiles in a process of its own and hands its result back, so that
  the host sees what it would have seen compiling itself: the same program or type, the
  same diagnostics in the same order and the same warnings. The process is given an
  allowance of binaries off its heap, its `min_bin_vheap_size`, sized to its text, twice
  its words beside the caller's own, and the loader's raises its own to twice what it
  holds as it reads each file: a program keeps its source text (decision 54), so a long
  text held over the compile, with its refusals' messages, outgrew the VM's allowance and
  turned most of the compile's collections into full ones, each copying the whole heap:
  7,095 of them for a box counter's 280 KB program, refused in 50 s, where the allowance
  leaves 28 and 32 s, before the did-you-mean was bounded (`compile/2`). It takes the
  caller's priority and heap settings, `min_heap_size`, `max_heap_size` and
  `fullsweep_after` (provisional), and its group leader, as a spawn always does, and reads
  and writes no process dictionary, the caller's or its own. It is linked to the caller
  and unlinks itself before it answers, so a caller that traps exits is sent nothing of
  it, its links as they were. A mistake it raises, a host's `ArgumentError` among them, is
  raised again in the caller, its message and stack unchanged; a compile killed from
  outside takes its caller with it, with the same reason, trapping exits or not, as a
  compile killed in the caller would have (provisional); and a caller that exits, killed
  by a host's own time limit among them, takes the compile with it, its work never left
  running. The caller is charged the reductions the compile spent, so that its own count,
  `Process.info(self(), :reductions)`, holds the whole compile, as when it ran there
  (provisional: `PLAN.md`'s RV-20, question 3).

  Outside its own process a compile costs what it did: README's motor 8,712 reductions,
  63 more than when the caller compiled itself, the handing over.
  """

  # Decision 432 (RV-15): the three are Logex.Compiler's, so that the loader and its own
  # compile of a file over the blocks it compiled itself are private code of the module
  # that compiles, which nothing a host hands in reaches. Since decision 520 (RV-20) each
  # runs them in a process of its own, Logex.Compiler.Worker's, which hands the result
  # back.

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

  **The cost that remains** (decision 520). A compile grows linearly in its text: its
  declarations, its rungs, the depth of its groups and the types it holds. A refusal costs
  near the count of its mistakes: the first hundred names it cannot find, in line order,
  a tag, a label or a member, are each offered the nearest name of a like length, within
  one character of its own, a name differing only in case always among them, and every
  name after them is told what a name with none near it is told, looked for among nothing
  (provisional, `Logex.Declarations`). So a box counter of 4,000 tags in which a renamed
  tag leaves 1,000, 2,000 and 4,000 rungs naming a tag that is gone is refused in some
  0.38, 0.45 and 0.44 s, 34 to 37 million reductions and 10 or 11 full collections, where
  it took 13, 50 and 253 s, 1,257 to 5,706 million reductions and up to 48,353 full
  collections, each name matched against all 4,000 (RV-20's figures, the least of three on
  one machine). What is left is the text's own compile and the hundred suggestions, each
  matched against the names of its like length, some 30 million reductions of them among
  4,000 tags; the engineer waits for it, and nothing runs meanwhile.
  """
  defdelegate compile(source, options), to: Logex.Compiler.Worker

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
  diagnostic, not an exception: a FIFO, a device or another special file is refused before
  it is opened, and so is a link to nothing or one that loops. After a refused name the
  source is still compiled, with the blocks beside it, so its own mistakes are listed too.

  Every file the loader reads or looks at, and the working directory a relative path is
  taken from, it reaches raw, off the VM's file server (decision 464), which serves every
  other file call of the VM one at a time: so a compile waits on no file call the VM makes
  through the server, a logger's or a store's write among them, and finishes while another
  process holds the server. A raw call takes one of the VM's dirty I/O schedulers, which
  every raw file call of the VM shares, so a compile still waits where all of them are
  taken, by ten raw opens of FIFOs that no process writes, say, as every raw call does.
  The working directory is read only for a path still relative once a leading `~/` is the
  user's home, so an absolute path compiles while it cannot be read; a relative one then,
  a deleted directory's among them, is a `:file` diagnostic, "cannot be located: the
  working directory cannot be read", and nothing is read (decision 478).
  """
  defdelegate compile_file(path), to: Logex.Compiler.Worker

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
  defdelegate compile_files(paths), to: Logex.Compiler.Worker
end
