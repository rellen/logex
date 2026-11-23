# scans.(file, inputs, names) compiles the program `file` and runs its scans. The map
# `inputs` gives, for each input, a list with its value in each scan. The script prints
# a table with 1 row for each scan: the number of the scan and the value of each name
# after the scan. After a row, it prints each fault of the scan.
fn file, inputs, names ->
  {:ok, program} = Logex.compile_file(file)

  scan = fn values, {number, state, rows} ->
    now = Map.new(Enum.zip(Map.keys(inputs), values))
    state = Logex.Runtime.put_inputs(program, state, now)
    {_outputs, state} = Logex.Runtime.scan(program, state)
    cells = Enum.map([number | Enum.map(names, &state.env[&1])], &"#{&1}")
    {number + 1, state, [{cells, state.faults} | rows]}
  end

  {_number, _state, rows} =
    inputs
    |> Map.values()
    |> Enum.zip_with(& &1)
    |> Enum.reduce({1, Logex.Runtime.instance(program), []}, scan)

  rows = [{["scan" | names], []} | Enum.reverse(rows)]

  widths =
    Enum.zip_with(Enum.map(rows, &elem(&1, 0)), fn column ->
      Enum.max(Enum.map(column, &String.length/1))
    end)

  for {cells, faults} <- rows do
    IO.puts(Enum.join(Enum.zip_with(cells, widths, &String.pad_leading/2), "  "))

    for fault <- faults,
        do: IO.puts("      fault  #{fault.severity}, #{inspect(fault.kind)}, line #{fault.line}")
  end
end
