defmodule Logex.Refusal do
  @moduledoc false
  # RV-5 (the review after Milestone 6, b3-store-image-10 and -11, a7-docs-1): a refusal of
  # a file the runner reads, the store (`Logex.Retain`) and the forces file
  # (`Logex.Runner`), and of the image a store holds (`Logex.Runtime.start/2`'s lines, each
  # naming the store), bounded and printable whatever the file holds. Internal.
  #
  # - A refusal is `<path>: line <n>: <problem>` a problem, its first 50 problems and then
  #   one line that counts the rest, `<path>: and 9949 more problems, not listed`, each
  #   line at most 1,000 bytes, cut at a character's boundary and ended `…`, so that a file
  #   of a million bad lines is told in some 50 KB, where 10 MB of them were told in 48 MB
  #   (provisional bounds).
  # - A text of the file a problem quotes is at most 60 bytes, a longer one cut there and
  #   ended `…`, each byte of it no store or forces file holds shown as its escape, `\xFF`,
  #   so that a refusal is printable, where a byte past ASCII made `IO.puts/1` of it raise;
  #   a tab and a carriage return are quoted as they are, as the forces file's refusals
  #   quoted them before, which its tests pin (M5-11's review).

  @shown_problems 50
  @longest_line 1000
  @longest_text 60

  # Every byte no store's or forces file's line holds: a tab, any other control byte, or
  # one past ASCII; each line's text is printable ASCII, its words one space apart.
  @unprintable Enum.map(Enum.concat(0..31, 127..255), &<<&1>>)

  # A file's problems, `{line, problem}` each in line order, as one refusal's message.
  def of(problems, path),
    do:
      problems
      |> Enum.map(fn {line, problem} -> "#{path}: line #{line}: #{problem}" end)
      |> told(path)

  # Lines of a refusal, each `<path>: ...` already: the first 50, each cut at 1,000 bytes,
  # and one counting the rest, joined.
  def told(lines, path) do
    {shown, rest} = Enum.split(lines, @shown_problems)
    Enum.map_join(shown ++ more(length(rest), path), "\n", &cut/1)
  end

  defp more(0, _path), do: []
  defp more(1, path), do: ["#{path}: and 1 more problem, not listed"]
  defp more(count, path), do: ["#{path}: and #{count} more problems, not listed"]

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

  # The first byte of `text` no line of either file holds, `{at, 1}`, or `:nomatch`;
  # `pattern/0` the bytes compiled once, for a reader of many lines.
  def unprintable(text), do: :binary.match(text, @unprintable)
  def unprintable(text, pattern), do: :binary.match(text, pattern)
  def pattern, do: :binary.compile_pattern(@unprintable)
end
