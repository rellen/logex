{:ok, packer} = Logex.compile_file("declarations-and-types/packer.ld")
state = Logex.Runtime.instance(packer)

for {name, tag} <- Enum.sort_by(packer.tags, fn {_name, tag} -> tag.line end) do
  line = String.pad_leading("#{tag.line}", 2)
  IO.puts("line #{line}  #{String.pad_trailing(name, 9)} #{inspect(state.env[name])}")
end
