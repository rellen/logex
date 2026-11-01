defmodule Logex.SourceFile do
  @moduledoc false
  # RV-2 (the review after Milestone 6): how the loaders, `Logex.compile_file/1`'s and
  # `Logex.Configuration.compile_file/1`'s, read a source file and tell what is beside a
  # file. Internal: its callers have checked their arguments.

  # A file's text, read only where it is a regular file, or a directory, which File.read/1
  # refuses, so that a FIFO or a device named `seal.ld` beside a program is refused where
  # its read hung the load for ever (a6-compile-scale-12).
  @doc false
  def read(path), do: read_by(File.stat(path), path)

  defp read_by({:ok, %File.Stat{type: type}}, path) when type in [:regular, :directory],
    do: File.read(path)

  defp read_by({:ok, %File.Stat{type: type}}, _path), do: {:error, {:not_regular, type}}
  defp read_by({:error, _reason}, path), do: File.read(path)

  # How a file that cannot be read is told so, a FIFO's or a device's among them.
  @doc false
  def unreadable({:not_regular, type}),
    do: "cannot be read: it is no regular file but #{a_kind(type)}, and logex reads a file"

  def unreadable(reason), do: "cannot be read: #{:file.format_error(reason)}"

  defp a_kind(:device), do: "a device"
  defp a_kind(_other), do: "a FIFO, a socket or another special file"

  # A name beside a file, a link to nothing or a link that loops among them, so that it is
  # loaded and told it cannot be read, where it was an unknown type, and the configuration's
  # loader a type with no file beside it, told to mean itself (a6-compile-scale-10).
  @doc false
  def present?(file), do: File.exists?(file) or match?({:ok, _}, File.lstat(file))
end
