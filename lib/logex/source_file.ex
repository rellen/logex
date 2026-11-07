defmodule Logex.SourceFile do
  @moduledoc false
  # RV-2 (the review after Milestone 6): how the loaders, `Logex.compile_file/1`'s and
  # `Logex.Configuration.compile_file/1`'s, read a source file and tell what is beside a
  # file. Internal: its callers have checked their arguments.
  #
  # Decision 464 (RV-17): every call here is raw, off the VM's file server, which serves
  # every other file call of the VM one at a time, so that a compile waits on no other
  # file call the VM makes, a logger's or a store's write among them, as the runner's
  # store and forces reads do since decision 390: a file's look and its read, a name's look
  # beside a file, the listing of a configuration's directory, and the working directory
  # a relative path is taken from. Each answers as its call through the server does, so
  # the refusals of a FIFO, a device, a link to nothing and a link that loops are as they
  # were, their messages unchanged.

  require Record

  Record.defrecordp(
    :info,
    :file_info,
    Record.extract(:file_info, from_lib: "kernel/include/file.hrl")
  )

  # A file's text, read only where it is a regular file, or a directory, which a read
  # refuses, so that a FIFO or a device named `seal.ld` beside a program is refused where
  # its read hung the load for ever (a6-compile-scale-12).
  @doc false
  def read(path), do: read_by(:file.read_file_info(path, [:raw, time: :posix]), path)

  defp read_by({:ok, info(type: type)}, path) when type in [:regular, :directory],
    do: :file.read_file(path, [:raw])

  defp read_by({:ok, info(type: type)}, _path), do: {:error, {:not_regular, type}}
  defp read_by({:error, _reason}, path), do: :file.read_file(path, [:raw])

  # How a file that cannot be read is told so, a FIFO's or a device's among them.
  @doc false
  def unreadable({:not_regular, type}),
    do: "cannot be read: it is no regular file but #{a_kind(type)}, and logex reads a file"

  def unreadable(reason), do: "cannot be read: #{:file.format_error(reason)}"

  defp a_kind(:device), do: "a device"
  defp a_kind(_other), do: "a FIFO, a socket or another special file"

  # A name beside a file, a link to nothing or a link that loops among them, so that it is
  # loaded and told it cannot be read, where it was an unknown type, and the configuration's
  # loader a type with no file beside it, told to mean itself (a6-compile-scale-10). The
  # name's own look, which finds whatever a look through a link finds and the link besides.
  @doc false
  def present?(file), do: match?({:ok, _info}, :file.read_link_info(file, [:raw]))

  # The names in a directory, as `File.ls/1` gives them.
  @doc false
  def listed(dir), do: names(:prim_file.list_dir(dir))

  defp names({:ok, names}), do: {:ok, Enum.map(names, &IO.chardata_to_string/1)}
  defp names({:error, _reason} = error), do: error

  # A path made absolute, as `Path.expand/1` makes it, against the working directory; one
  # that cannot be read raises as `Path.expand/1` raised, `File.cwd!/0`'s error.
  @doc false
  def expanded(path), do: Path.expand(path, cwd(:prim_file.get_cwd()))

  defp cwd({:ok, dir}), do: IO.chardata_to_string(dir)

  defp cwd({:error, reason}),
    do: raise(File.Error, reason: reason, action: "get current working directory")
end
