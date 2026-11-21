# show.(type, value) gives the text of a value of the type. A `byte` is in base 2, a
# `word` and a `dword` are in base 16, and each other value is in base 10. Each text
# is a literal of logex for the same value.
digits = fn number, base, count ->
  number
  |> Integer.to_string(base)
  |> String.downcase()
  |> String.pad_leading(count, "0")
  |> String.graphemes()
  |> Enum.chunk_every(4)
  |> Enum.map_join("_", &Enum.join/1)
end

fn
  :byte, number -> "2#" <> digits.(number, 2, 8)
  :word, number -> "16#" <> digits.(number, 16, 4)
  :dword, number -> "16#" <> digits.(number, 16, 8)
  _type, number -> "#{number}"
end
