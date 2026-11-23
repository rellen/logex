texts = [
  "var_output fault bool\neq 5 5 ote fault",
  "var_output trim int\nadd 2 3 trim",
  "var_output trim int\nneg 5 trim",
  "var_output trim int\ndint_to_int 40000 trim",
  "var_input count uint\nvar_output fault bool\nge count 0 ote fault",
  "var_output rpm real\nmove 16777217.0 rpm",
  "var_input eye bool\nvar cure ton_ltime\nxic eye ton cure 1500",
  "var_input eye bool\nvar_output fault bool\nvar cure ton_ltime\n" <>
    "ge cure.acc 3000 ote fault\nxic eye ton cure 5000000"
]

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

lines =
  for {text, number} <- Enum.with_index(texts, 1) do
    {:ok, program} = Logex.compile(text, name: "warned")
    head = " #{number}  " <> String.replace(text, "\n", "\n    ")
    [head | Enum.map(program.warnings, &wrap.(Logex.Diagnostic.format(&1)))]
  end

IO.puts(Enum.join(List.flatten(lines), "\n"))
