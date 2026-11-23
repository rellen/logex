# report.(first, texts, compile) prints each text after its number, the first of them
# after the number `first`. After each text, it prints each diagnostic or each warning
# that compile.(text) returns, in lines of 80 characters or fewer.
wrap = fn message ->
  message
  |> String.split(" ")
  |> Enum.chunk_while(
    "     ",
    fn
      word, line when byte_size(line) + byte_size(word) < 80 -> {:cont, line <> " " <> word}
      word, line -> {:cont, line, "      " <> word}
    end,
    fn line -> {:cont, line, ""} end
  )
end

messages = fn
  {:error, diagnostics} -> diagnostics
  {:ok, compiled} -> compiled.warnings
end

lines = fn
  [] -> ["      the text compiles, and logex gives no warning"]
  found -> Enum.map(found, &wrap.(Logex.Diagnostic.format(&1)))
end

fn first, texts, compile ->
  for {text, number} <- Enum.with_index(texts, first) do
    head = String.pad_leading("#{number}", 2) <> "  " <> String.replace(text, "\n", "\n    ")
    IO.puts(Enum.join(List.flatten([head | lines.(messages.(compile.(text)))]), "\n"))
  end
end
