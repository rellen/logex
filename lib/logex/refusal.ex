defmodule Logex.Refusal do
  @moduledoc false
  # RV-5 (the review after Milestone 6, b3-store-image-10 and -11, a7-docs-1): a refusal of
  # a file the runner reads, the store (`Logex.Retain`) and the forces file
  # (`Logex.Runner`), and of the image a store holds (`Logex.Runtime.start/2`'s lines, each
  # naming the store), bounded and printable whatever the file holds. Internal.
  #
  # - A refusal is `<path>: line <n>: <problem>` a problem, its first 50 problems and then
  #   one line that counts the rest, `<path>: and 9949 more problems, not listed`, each
  #   line at most 1,000 bytes after its path, cut at a character's boundary and ended `…`,
  #   so that a file
  #   of a million bad lines is told in some 50 KB, where 10 MB of them were told in 48 MB
  #   (provisional bounds).
  # - A text of the file a problem quotes is at most 60 bytes, a longer one cut there and
  #   ended `…`, each byte of it no store or forces file holds shown as its escape, `\xFF`,
  #   so that a refusal is printable, where a byte past ASCII made `IO.puts/1` of it raise;
  #   a tab and a carriage return are quoted as they are, as the forces file's refusals
  #   quoted them before, which its tests pin (M5-11's review). Since decision 410 (RV-13)
  #   a carriage return ends a line of either file, as LF does, so no line quoted holds
  #   one.
  # - Since RV-5's review the file's path, the host's, as each line names it, is printable
  #   and bounded too (path/1): a control byte, DEL and a byte of no UTF-8 character shown
  #   as its escape, and a path past 4,096 bytes, the most a path Linux opens holds, shown
  #   as `…` and its last 4,096, its file's name among them; and a line's 1,000 bytes are
  #   counted after the path, so that every line names the file, the line and the problem
  #   whatever the path (decision 419), where a 1,115-byte path filled the line and a byte
  #   255 in it made the message one `IO.puts/1` raises on.

  @shown_problems 50
  @longest_line 1000
  @longest_text 60
  @longest_path 4096

  # Every byte no store's or forces file's line holds: a tab, any other control byte, or
  # one past ASCII; each line's text is printable ASCII, its words one space apart.
  @unprintable Enum.map(Enum.concat(0..31, 127..255), &<<&1>>)

  # A file's problems, `{line, problem}` each in line order, as one refusal's message: the
  # first 50 made lines, the rest counted and none of them made (RV-5's review, where every
  # problem was made a line and all but 50 dropped).
  def of(problems, path) do
    {shown, rest} = Enum.split(problems, @shown_problems)
    at = path(path)

    shown
    |> Enum.map(fn {line, problem} -> "line #{line}: #{problem}" end)
    |> joined(length(rest), at)
  end

  # Lines of a refusal, each named by the file's path as path/1 shows it, `<path>: ...`:
  # the first 50, each cut at 1,000 bytes after its path, and one counting the rest,
  # joined.
  def told(lines, path) do
    {shown, rest} = Enum.split(lines, @shown_problems)
    joined(shown, length(rest), path(path))
  end

  defp joined(lines, more, at),
    do: Enum.join(Enum.map(lines, &"#{at}: #{cut(&1)}") ++ more(more, at), "\n")

  defp more(0, _at), do: []
  defp more(1, at), do: ["#{at}: and 1 more problem, not listed"]
  defp more(count, at), do: ["#{at}: and #{count} more problems, not listed"]

  defp cut(<<line::binary-size(@longest_line), _::binary>>), do: whole(line) <> "…"
  defp cut(line), do: line

  # A cut line ended at a character's boundary: the bytes of a character the cut split,
  # at most three, dropped.
  defp whole(line), do: whole_at(String.valid?(line), line)

  defp whole_at(true, line), do: line
  defp whole_at(false, line), do: whole(binary_part(line, 0, byte_size(line) - 1))

  # A text of the file's as a problem quotes it, in backquotes, and bare.
  def quoted(text), do: "`" <> shown(text) <> "`"
  def shown(text), do: shown(text, @longest_text, [])

  defp shown(<<>>, _left, acc), do: acc |> Enum.reverse() |> IO.iodata_to_binary()
  defp shown(_rest, 0, acc), do: shown(<<>>, 0, ["…" | acc])

  defp shown(<<c, rest::binary>>, left, acc) when c in 0x20..0x7E or c in [?\t, ?\r],
    do: shown(rest, left - 1, [c | acc])

  defp shown(<<c, rest::binary>>, left, acc), do: shown(rest, left - 1, [escaped(c) | acc])

  # A byte as a refusal shows it, `\xFF`.
  def escaped(c), do: "\\x" <> String.pad_leading(Integer.to_string(c, 16), 2, "0")

  # The host's path as a refusal names it: each character of it a printable one, a UTF-8
  # character past ASCII among them, as it is, and each control byte, DEL and byte of no
  # UTF-8 character as its escape; a path past 4,096 bytes so shown, `…` and its last
  # 4,096, cut at a character's boundary.
  def path(path), do: path |> printed([]) |> ended()

  defp printed(<<>>, acc), do: acc |> Enum.reverse() |> IO.iodata_to_binary()

  defp printed(<<c::utf8, rest::binary>>, acc) when c in 0x20..0x7E or c > 0x9F,
    do: printed(rest, [<<c::utf8>> | acc])

  defp printed(<<c, rest::binary>>, acc), do: printed(rest, [escaped(c) | acc])

  defp ended(path) when byte_size(path) > @longest_path,
    do: "…" <> started(binary_part(path, byte_size(path) - @longest_path, @longest_path))

  defp ended(path), do: path

  # A path's end cut at a character's boundary: the bytes of a character the cut split,
  # each a continuation byte, dropped from its front.
  defp started(<<0b10::2, _::6, rest::binary>>), do: started(rest)
  defp started(path), do: path

  # The first byte of `text` no line of either file holds, `{at, 1}`, or `:nomatch`;
  # `pattern/0` the bytes compiled once, for a reader of many lines.
  def unprintable(text), do: :binary.match(text, @unprintable)
  def unprintable(text, pattern), do: :binary.match(text, pattern)
  def pattern, do: :binary.compile_pattern(@unprintable)
end
