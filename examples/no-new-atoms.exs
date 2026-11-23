# The text of a program: 1 output and 1 rung for each name.
text = fn names ->
  tags = Enum.map_join(names, "\n", &"var_output #{&1} bool")
  rungs = Enum.map_join(names, "\n", &"xio #{&1} ote #{&1}")
  tags <> "\n\n" <> rungs <> "\n"
end

# A small host: compile the text, make an instance, run 1 scan.
run = fn names ->
  {:ok, lamps} = Logex.compile(text.(names), name: "lamps")
  state = Logex.Runtime.instance(lamps)
  {outputs, _state} = Logex.Runtime.scan(lamps, state)
  map_size(outputs)
end

# The modules and the atoms that the BEAM holds.
beam = fn ->
  {length(:code.all_loaded()), :erlang.system_info(:atom_count)}
end

# The first run loads the modules of logex.
run.(["lamp_a", "lamp_b"])

# The 1,000 names are strings.
names = for n <- 1..1000, do: "lamp_#{n}"

{modules, atoms} = beam.()
outputs = run.(names)
{modules_after, atoms_after} = beam.()

IO.puts("a program with #{outputs} new names:")
IO.puts("#{modules_after - modules} new modules")
IO.puts("#{atoms_after - atoms} new atoms")
