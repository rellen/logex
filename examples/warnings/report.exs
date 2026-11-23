# report.(first, cases, compile, options) prints each case after its number, the first
# case after the number `first`. A case is {title, text} or {title, [text, ...]}: each text
# is 1 program or 1 configuration. compile.(tags <> text) compiles it. The options are
# `tags:`, a text put before each text ("" if not given), and `none:`, the line printed
# for a text with no warning ("no warning" if not given). For each text, the script prints
# its lines with their line numbers, then each warning of the compiled text.
lines = fn text, before ->
  text
  |> String.split("\n")
  |> Enum.with_index(before + 1)
  |> Enum.map(fn {line, number} ->
    "    " <> String.pad_leading("#{number}", 4) <> "  " <> line
  end)
end

warnings = fn
  {:ok, %{warnings: []}}, none -> ["    " <> none]
  {:ok, %{warnings: found}}, _none -> Enum.map(found, &("    " <> Logex.Diagnostic.format(&1)))
end

fn first, cases, compile, options ->
  tags = Keyword.get(options, :tags, "")
  none = Keyword.get(options, :none, "no warning")
  before = length(String.split(tags, "\n", trim: true))

  for {{title, texts}, number} <- Enum.with_index(cases, first) do
    head = String.pad_leading("#{number}", 2) <> "  " <> title

    shown =
      Enum.flat_map(List.wrap(texts), fn text ->
        lines.(text, before) ++ warnings.(compile.(tags <> text), none)
      end)

    IO.puts(Enum.join([head | shown], "\n"))
  end
end
