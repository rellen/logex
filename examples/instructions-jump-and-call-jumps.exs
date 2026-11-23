{scans, _} = Code.eval_file("instructions-jump-and-call/scans.exs")

tags = """
var_input  skip   bool
var_input  other  bool
var_input  eye    bool
var_output lamp   bool
var_output belt   bool
"""

# Each case is the rungs of a program and the inputs of its scans.
cases = [
  {"xic skip jmp done ote lamp\nxic eye ote belt\nlbl done",
   %{"skip" => [0, 1, 1, 0], "other" => [0, 0, 0, 0], "eye" => [1, 0, 0, 0]}},
  {"( xic skip jmp done | xic eye ) ote lamp\nxic eye ote belt\nlbl done",
   %{"skip" => [0, 1, 1, 0], "other" => [0, 0, 0, 0], "eye" => [1, 0, 0, 0]}},
  {"xic skip jmp mid\nxic other jmp last\nlbl mid xic eye ote lamp\nxic eye ote belt\nlbl last",
   %{"skip" => [0, 1, 0, 0], "other" => [0, 1, 1, 0], "eye" => [1, 0, 1, 1]}},
  {"jmp done\nxic eye ote lamp\nlbl done xic eye ote belt",
   %{"skip" => [0, 0], "other" => [0, 0], "eye" => [1, 0]}},
  {"xic skip jmp done\nxic eye ote lamp\nxic other jmp done\nxic eye ote belt\nlbl done",
   %{"skip" => [0, 0, 1, 0], "other" => [0, 1, 0, 0], "eye" => [1, 0, 0, 0]}},
  {"xic skip jmp mid\nxic eye ote lamp\nlbl mid xic other jmp last\nxic eye ote belt\nlbl last",
   %{"skip" => [0, 1, 1, 0], "other" => [0, 1, 0, 0], "eye" => [1, 0, 0, 0]}}
]

# A blank line comes before each case after the first.
head = fn
  1 -> "Case 1"
  number -> "\nCase #{number}"
end

for {{rungs, inputs}, number} <- Enum.with_index(cases, 1) do
  IO.puts(head.(number) <> "\n" <> rungs <> "\n")
  {:ok, program} = Logex.compile(tags <> rungs, name: "case")
  scans.(program, 10, inputs, ["skip", "other", "eye", "lamp", "belt"])
end
