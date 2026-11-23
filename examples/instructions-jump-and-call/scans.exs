# scans.(program, step, inputs, names) runs the scans of a compiled program. The map
# `inputs` gives, for each input, a list with its value in each scan. Each scan gets
# `step` ms. After each scan, the script prints the number of the scan and the value of
# each name. A name is a tag, or a member such as "t1.acc". After a row, the script
# prints each fault of the scan.
where = fn
  nil -> ""
  path -> " in #{path}"
end

fault = fn %Logex.Fault{} = fault ->
  "      fault  #{fault.severity} #{inspect(fault.kind)}, `#{fault.instruction}` " <>
    "on line #{fault.line}#{where.(fault.path)}"
end

fn program, step, inputs, names ->
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
    Enum.each(state.faults, &IO.puts(fault.(&1)))
    {number + 1, state}
  end

  row.(columns)

  inputs
  |> Map.values()
  |> Enum.zip_with(& &1)
  |> Enum.reduce({1, Logex.Runtime.instance(program)}, scan)
end
