# calls.(first, cases) runs each case of the list cases, a {call, function} pair, the first
# of them as the case `first`. It prints the number of the case and the call. Then it
# prints the message of the ArgumentError that the function raises, in lines of 80
# characters or fewer.
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

fn first, cases ->
  for {{call, fun}, number} <- Enum.with_index(cases, first) do
    message =
      try do
        fun.()
        "no error"
      rescue
        error in ArgumentError -> error.message
      end

    lines = Enum.flat_map(String.split(message, "\n"), wrap)
    IO.puts(Enum.join([String.pad_leading("#{number}", 2) <> "  " <> call | lines], "\n"))
  end
end
