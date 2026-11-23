# For each conversion, the script compiles a program of 1 rung, gives the source to
# the input `a` and runs 1 scan. It prints the type and the value of the source, then
# its bits. Then it prints the same for the value that the conversion writes to `d`.
# It prints the bits in rows of 16, with the low bit at the right, and the value of a
# bit string as a based literal of 16.
widths = %{"sint" => 8, "int" => 16, "dint" => 32, "uint" => 16, "word" => 16, "dword" => 32}
power = %{0 => "false", 1 => "true"}

rows = fn value, width ->
  text = Integer.to_string(Bitwise.band(value, Bitwise.bsl(1, width) - 1), 2)
  groups = for <<group::binary-size(4) <- String.pad_leading(text, width, "0")>>, do: group

  for row <- Enum.chunk_every(groups, 4) do
    String.duplicate(" ", 10) <> String.pad_leading(Enum.join(row, " "), 19)
  end
end

shown = fn
  value, type when type in ["word", "dword"] ->
    digits = String.downcase(Integer.to_string(value, 16))
    "16#" <> String.pad_leading(digits, div(widths[type], 4), "0")

  value, _type ->
    "#{value}"
end

lines = fn type, value ->
  ["   " <> String.pad_trailing(type, 7) <> shown.(value, type) | rows.(value, widths[type])]
end

conversions = [
  {"dint", "sint", 129},
  {"sint", "dint", -127},
  {"int", "uint", -1},
  {"sint", "word", -1},
  {"int", "dword", -1},
  {"word", "int", 0xFFFF},
  {"word", "dint", 0x8000},
  {"dword", "word", 0x12345678}
]

for {{from, into, value}, number} <- Enum.with_index(conversions, 1) do
  mnemonic = "#{from}_to_#{into}"
  text = "var_input a #{from}\nvar_output d #{into}\nvar_output ok bool\n#{mnemonic} a d ote ok\n"
  {:ok, program} = Logex.compile(text, name: "bits")
  state = Logex.Runtime.put_inputs(program, Logex.Runtime.instance(program), %{"a" => value})
  {outputs, _state} = Logex.Runtime.scan(program, state)
  head = "#{number}  #{mnemonic}, power out #{power[outputs["ok"]]}"
  IO.puts(Enum.join([head | lines.(from, value)] ++ lines.(into, outputs["d"]), "\n"))
end
