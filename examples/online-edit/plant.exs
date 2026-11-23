# show.(first, cases) runs each case and prints it after its number, the first case after
# the number `first`. A case is {title, before, after, steps}. `before` is the
# configuration that runs, and `after` is the new configuration. Each is {text, programs}:
# programs is a map from the name of each program type to its text. A step is 1 of these:
#
#   {:cycle, ms, inputs}  runs 1 cycle with these input points, ms after the last cycle
#   {:get, names}         prints the value of each global or path
#   :accept               accepts the new configuration and prints the forecast, or
#                         prints "refused" and each diagnostic on a line of its own
#   :accept_old           accepts the old configuration, as a second edit, and prints the
#                         forecast
#   :test, :untest, :assemble, :cancel
#                         does the step and prints its report
#   {:restart, mode}      restarts the resource, :cold or :warm
#
# For each case, the script prints the lines that only `before` has, after a "-", and the
# lines that only `after` has, after a "+". Then it prints 1 line for each step.
alias Logex.Configuration.Edit

compile = fn {text, programs} ->
  types =
    Map.new(programs, fn {name, source} ->
      {:ok, type} = Logex.compile(source, name: name)
      {name, type}
    end)

  {:ok, configuration} = Logex.Configuration.compile("plant", text, types)
  configuration
end

# The lines of the configuration, then the lines of each program type.
lines = fn {text, programs} ->
  Enum.reduce(programs, String.split(text, "\n", trim: true), fn {name, source}, lines ->
    lines ++ Enum.map(String.split(source, "\n", trim: true), &"#{name}: #{&1}")
  end)
end

pairs = fn values -> Enum.map_join(values, " ", fn {name, value} -> "#{name}=#{value}" end) end

entries = fn
  [] -> ["(no entry)"]
  report -> Enum.map(report, &inspect/1)
end

print = fn label, lines ->
  [first | rest] = lines
  IO.puts("      " <> String.pad_trailing(label, 12) <> first)
  Enum.each(rest, &IO.puts("      " <> String.duplicate(" ", 12) <> &1))
end

accepted = fn
  {:ok, edit, forecast}, label, run ->
    print.(label, entries.(forecast))
    %{run | edit: edit, forecast: forecast}

  {:error, diagnostics}, label, run ->
    print.(label, ["refused"])
    Enum.each(diagnostics, &IO.puts("        " <> Logex.Diagnostic.format(&1)))
    run
end

# The report of the first test after an accept is the forecast.
tested = fn
  report, report -> ["the entries of the forecast"]
  report, _forecast -> entries.(report)
end

step = fn
  {:cycle, ms, inputs}, run ->
    {runtime, outputs, _events} = Logex.Runtime.cycle(run.runtime, ms, inputs)
    line = ["cycle +#{ms} ms", pairs.(inputs), "->", pairs.(outputs)]
    IO.puts("      " <> Enum.join(Enum.reject(line, &(&1 == "")), "  "))
    %{run | runtime: runtime}

  {:get, names}, run ->
    values = Enum.map(names, &{&1, Logex.Runtime.get!(run.runtime, &1)})
    print.("get", [pairs.(values)])
    run

  :accept, run ->
    accepted.(Edit.accept(run.runtime, run.after), "accept", run)

  :accept_old, run ->
    accepted.(Edit.accept(run.runtime, run.before), "accept old", run)

  {:restart, mode}, run ->
    print.("restart", [Atom.to_string(mode)])
    %{run | runtime: Logex.Runtime.restart(run.runtime, mode)}

  :test, run ->
    {edit, runtime, report} = Edit.test(run.edit, run.runtime)
    print.("test", tested.(report, run.forecast))
    %{run | edit: edit, runtime: runtime, forecast: nil}

  :untest, run ->
    {edit, runtime, report} = Edit.untest(run.edit, run.runtime)
    print.("untest", entries.(report))
    %{run | edit: edit, runtime: runtime}

  ending, run ->
    {_configuration, runtime, report} = apply(Edit, ending, [run.edit, run.runtime])
    print.(Atom.to_string(ending), entries.(report))
    %{run | runtime: runtime, edit: nil}
end

fn first, cases ->
  for {{title, before, later, steps}, number} <- Enum.with_index(cases, first) do
    IO.puts(String.pad_leading("#{number}", 2) <> "  " <> title)
    Enum.each(lines.(before) -- lines.(later), &IO.puts("      - " <> &1))
    Enum.each(lines.(later) -- lines.(before), &IO.puts("      + " <> &1))
    old = compile.(before)
    start = %{before: old, after: compile.(later), runtime: Logex.Runtime.start(old)}
    Enum.reduce(steps, Map.merge(start, %{edit: nil, forecast: nil}), step)
  end

  :ok
end
