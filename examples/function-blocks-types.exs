{report, _} = Code.eval_file("instructions-contacts-and-coils/report.exs")
{:ok, seal} = Logex.compile_file("seal.ld")

# `line` is a function block that holds an instance of `seal`. `other_seal` is a different
# function block with the name `seal`: its rung has no contact `run`.
line_text = "function_block line\nvar_input go bool\nvar_input halt bool\nvar_output run bool\n"

{:ok, line} =
  Logex.compile(line_text <> "var hold seal\ncal hold go halt run", name: "line", types: [seal])

seal_text = "function_block seal\nvar_input start bool\nvar_input stop bool\n"

{:ok, other_seal} =
  Logex.compile(seal_text <> "var_output run bool\nxic start xio stop ote run", name: "seal")

# Text 31 declares `seal` and gives only `line` in `types:`.
program =
  "var_input go bool\nvar_input halt bool\nvar_output run bool\n" <>
    "var l1 line\nvar s1 seal\ncal l1 go halt run"

report.(31, [program], &Logex.compile(&1, name: "panel", types: [line]))

# Texts 32 to 35 give a wrong option `types:` with the text of belts.ld. The script prints
# each message in lines of 80 characters or fewer. Of a message that is longer than 300
# characters, it prints the first 120 characters.
belts = File.read!("belts.ld")
changed = %{seal | name: "seal2"}

calls = [
  {"[seal, seal]", [seal, seal]},
  {~s(["seal.ld"]), ["seal.ld"]},
  {"[line, other_seal]", [line, other_seal]},
  {"[changed]", [changed]}
]

short = fn
  message when byte_size(message) > 300 -> binary_part(message, 0, 120) <> " ..."
  message -> message
end

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

for {{label, types}, number} <- Enum.with_index(calls, 32) do
  try do
    Logex.compile(belts, name: "belts", types: types)
  rescue
    error in ArgumentError ->
      IO.puts("#{number}  Logex.compile(belts, name: \"belts\", types: #{label})")
      IO.puts(Enum.join(["      ArgumentError" | wrap.(short.(Exception.message(error)))], "\n"))
  end
end
