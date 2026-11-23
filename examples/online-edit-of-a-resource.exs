alias Logex.Configuration.Edit
alias Logex.Runtime

{:ok, line} = Logex.Configuration.compile_file("line.logex")
# The new configuration is line.logex with no conveyor c2. Its program types are those of line.
[text, _c2] = String.split(File.read!("line.logex"), "program c2 ")
{:ok, smaller} = Logex.Configuration.compile("line", text, line.programs)

# The generation, the instances that run and the instances set aside. These are fields of
# the resource that only logex reads: fields/1 is an internal function of Logex.Runtime.
names = fn
  map when map_size(map) == 0 -> "none"
  map -> Enum.join(Map.keys(map), " ")
end

show = fn label, resource, report ->
  fields = Runtime.fields(resource)
  run = names.(fields.instances)
  aside = names.(fields.aside)

  IO.puts(
    String.pad_trailing(label, 7) <> "generation #{fields.generation}, run #{run}, aside #{aside}"
  )

  Enum.each(report, fn entry -> IO.puts("  " <> inspect(entry)) end)
end

resource = Runtime.start(line)
{resource, _outputs, _events} = Runtime.cycle(resource, 0, %{"pb_start_2" => 1})
show.("start", resource, [])

{:ok, edit, forecast} = Edit.accept(resource, smaller)
show.("accept", resource, forecast)
{edit, resource, report} = Edit.test(edit, resource)
show.("test", resource, report)
{resource, outputs, _events} = Runtime.cycle(resource, 50, %{})
IO.puts("outputs after a cycle: #{inspect(outputs)}")
{untested, resource, report} = Edit.untest(edit, resource)
show.("untest", resource, report)
{_line, resource, report} = Edit.cancel(untested, resource)
show.("cancel", resource, report)

# The edit of the untest expects generation 2. The cancel moved the resource to 3.
try do
  Edit.test(untested, resource)
rescue
  error in ArgumentError -> IO.puts(Exception.message(error))
end
