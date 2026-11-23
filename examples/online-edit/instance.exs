# show.(first, cases) runs each case and prints it after its number, the first case after
# the number `first`. A case is {title, before, after, steps}. `before` is the program that
# runs, and `after` is the new program. Each is a text, or {text, blocks}: blocks is a list
# of {name, text}, 1 for each function block that the program uses. A step is 1 of these:
#
#   {:scan, ms, inputs}  sets the inputs, then scans the program that runs, ms after the
#                        last scan
#   :accept              accepts the new program and prints the forecast, or prints
#                        "refused" and each diagnostic on a line of its own
#   :test, :untest, :assemble, :cancel
#                        does the step and prints its report
#
# For each case, the script prints the lines that only `before` has, after a "-", and the
# lines that only `after` has, after a "+". Then it prints 1 line for each step.
block = fn {name, text} ->
  {:ok, type} = Logex.compile(text, name: name)
  type
end

program = fn
  {text, blocks} -> Logex.compile(text, name: "line", types: Enum.map(blocks, block))
  text -> Logex.compile(text, name: "line")
end

pairs = fn values -> Enum.map_join(values, " ", fn {name, value} -> "#{name}=#{value}" end) end

entries = fn
  [] -> ["(no entry)"]
  report -> Enum.map(report, &inspect/1)
end

# Before the accept and after the end of the edit, the host scans its own program.
running = fn
  nil, program -> program
  edit, _program -> Logex.Edit.running(edit)
end

print = fn label, lines ->
  [first | rest] = lines
  IO.puts("      " <> String.pad_trailing(label, 12) <> first)
  Enum.each(rest, &IO.puts("      " <> String.duplicate(" ", 12) <> &1))
end

accepted = fn
  {:ok, edit, forecast}, run ->
    print.("accept", entries.(forecast))
    %{run | edit: edit, forecast: forecast}

  {:error, diagnostics}, run ->
    print.("accept", ["refused"])
    Enum.each(diagnostics, &IO.puts("        " <> Logex.Diagnostic.format(&1)))
    run
end

# The report of the first test after an accept is the forecast.
tested = fn
  report, report -> ["the entries of the forecast"]
  report, _forecast -> entries.(report)
end

step = fn
  {:scan, ms, inputs}, run ->
    program = running.(run.edit, run.program)
    state = Logex.Runtime.put_inputs(program, run.state, inputs)
    {outputs, state} = Logex.Runtime.scan(program, state, ms)
    line = ["scan +#{ms} ms", pairs.(inputs), "->", pairs.(outputs)]
    IO.puts("      " <> Enum.join(Enum.reject(line, &(&1 == "")), "  "))
    %{run | state: state}

  :accept, run ->
    accepted.(Logex.Edit.accept(run.program, run.after, run.state), run)

  :test, run ->
    {edit, state, report} = Logex.Edit.test(run.edit, run.state)
    print.("test", tested.(report, run.forecast))
    %{run | edit: edit, state: state, forecast: nil}

  :untest, run ->
    {edit, state, report} = Logex.Edit.untest(run.edit, run.state)
    print.("untest", entries.(report))
    %{run | edit: edit, state: state}

  ending, run ->
    {program, state, report} = apply(Logex.Edit, ending, [run.edit, run.state])
    print.(Atom.to_string(ending), entries.(report))
    %{run | program: program, state: state, edit: nil}
end

# The lines of the blocks, then the lines of the program.
text = fn
  {text, blocks} -> Enum.map_join(blocks, "\n", &elem(&1, 1)) <> "\n" <> text
  text -> text
end

fn first, cases ->
  for {{title, before, later, steps}, number} <- Enum.with_index(cases, first) do
    IO.puts(String.pad_leading("#{number}", 2) <> "  " <> title)
    old = String.split(text.(before), "\n", trim: true)
    new = String.split(text.(later), "\n", trim: true)
    Enum.each(old -- new, &IO.puts("      - " <> &1))
    Enum.each(new -- old, &IO.puts("      + " <> &1))
    {:ok, running} = program.(before)
    {:ok, candidate} = program.(later)
    start = %{program: running, after: candidate, state: Logex.Runtime.instance(running)}
    Enum.reduce(steps, Map.merge(start, %{edit: nil, forecast: nil}), step)
  end

  :ok
end
