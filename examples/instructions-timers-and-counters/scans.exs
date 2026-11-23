# scans.(file, step, inputs, names) compiles the program `file` and runs its scans.
# The map `inputs` gives, for each input, a list with its value in each scan. Each scan
# gets `step` ms. After each scan, it prints the number of the scan and the value of each
# name. A name is a tag, or a member such as "t1.acc".
fn file, step, inputs, names ->
  {:ok, program} = Logex.compile_file(file)
  columns = ["scan" | names]

  row = fn cells ->
    columns
    |> Enum.zip(cells)
    |> Enum.map_join("  ", fn {name, cell} ->
      String.pad_leading("#{cell}", String.length(name))
    end)
    |> IO.puts()
  end

  scan = fn values, {number, state} ->
    now = Map.new(Enum.zip(Map.keys(inputs), values))
    state = Logex.Runtime.put_inputs(program, state, now)
    {_outputs, state} = Logex.Runtime.scan(program, state, step)
    row.([number | Enum.map(names, &get_in(state.env, String.split(&1, ".")))])
    {number + 1, state}
  end

  row.(columns)

  inputs
  |> Map.values()
  |> Enum.zip_with(& &1)
  |> Enum.reduce({1, Logex.Runtime.instance(program)}, scan)
end
