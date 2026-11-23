# For each type word, the script declares 1 instance and prints the members of its type.
# For each member, it prints the name, the type and the role. It prints `write` if a rung
# outside the instance can write the member. The script reads the fields `tags`, `blocks`
# and `members`, which are not part of the host contract. Do not use them in a host.
{:ok, fan_relay} = Logex.compile_file("function-blocks/fan_relay.ld")
words = ~w(ton rto ton_ltime ctu ctd ctud ctu_int fan_relay)

type_of = fn
  program, {:block, name} -> program.blocks[name]
  _program, type -> type
end

word_of = fn
  %Logex.FbType{name: name} -> name
  type -> to_string(type)
end

write = fn
  true -> "write"
  false -> ""
end

row = fn cells ->
  cells
  |> Enum.zip([10, 8, 8, 10, 0])
  |> Enum.map_join(fn {cell, width} -> String.pad_trailing("#{cell}", width) end)
  |> String.trim_trailing()
  |> IO.puts()
end

row.(["type word", "member", "type", "role", "write"])

for word <- words do
  {:ok, program} = Logex.compile("var x #{word}", name: "members", types: [fan_relay])
  type = type_of.(program, program.tags["x"].type)

  for {member, index} <- Enum.with_index(type.members) do
    first = Enum.at([word], index, "")
    row.([first, member.name, word_of.(member.type), member.role, write.(member.write)])
  end
end
