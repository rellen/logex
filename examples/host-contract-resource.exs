# A resource of fans.logex: 2 cycles, the reads of 12 access paths and the wrong calls.
alias Logex.Runtime

refused = fn label, call ->
  try do
    call.()
    IO.puts("#{label}: no error")
  rescue
    error in ArgumentError ->
      IO.puts("#{label}:\n  " <> String.replace(error.message, "\n", "\n  "))
  end
end

{:ok, fans} = Logex.Configuration.compile_file("host-contract/fans.logex")
resource = Runtime.start(fans)
IO.puts("next_due_in/1 after start/1: #{Runtime.next_due_in(resource)}")

inputs = %{"run" => 1, "level" => 7, "hz" => 25, "limits" => [10, 20, 30]}
{resource, outputs, events} = Runtime.cycle(resource, 0, inputs)
IO.puts("cycle at 0 ms: #{inspect(outputs)} #{inspect(events)}")
{resource, outputs, events} = Runtime.cycle(resource, 600, %{"limits[1]" => 21})
IO.puts("cycle at 600 ms: #{inspect(outputs)} #{inspect(events)}")

IO.puts(
  "next_due_in/1: #{Runtime.next_due_in(resource)}, overlaps/1: #{inspect(Runtime.overlaps(resource))}"
)

IO.puts("\nget/2:")

paths = [
  "fan_hz",
  "limits",
  "limits[1]",
  "f1.steps",
  "f1.steps[1]",
  "f1.t1.acc",
  "f1",
  "f1.t1",
  "f1.t1.last",
  "f1.limits[3]",
  "fast",
  "f1.nope"
]

for path <- paths,
    do: IO.puts("  #{String.pad_trailing(path, 13)} #{inspect(Runtime.get(resource, path))}")

IO.puts("\nWrong calls:")
refused.("start/1 with an atom", fn -> Runtime.start(:fans) end)
refused.("cycle/3 with -5 ms", fn -> Runtime.cycle(resource, -5, %{}) end)
refused.("cycle/3 with a list", fn -> Runtime.cycle(resource, 5, [{"run", 1}]) end)
refused.("cycle/3 with an atom key", fn -> Runtime.cycle(resource, 5, %{run: 1}) end)

refused.("cycle/3 with 5 wrong inputs", fn ->
  wrong = %{"fan" => 1, "fan_hz" => 1.0, "f1.trim" => 1, "levle" => 1, "run" => 2}
  Runtime.cycle(resource, 5, wrong)
end)

refused.("cycle/3 with a whole array and 1 element", fn ->
  Runtime.cycle(resource, 5, %{"limits" => [1, 2, 3], "limits[0]" => 1})
end)

refused.("get/2 with an atom", fn -> Runtime.get(resource, :fan) end)
refused.("get!/2 of a path that names nothing", fn -> Runtime.get!(resource, "f1.nope") end)
refused.("restart/2 with :hot", fn -> Runtime.restart(resource, :hot) end)
refused.("next_due_in/1 with a map", fn -> Runtime.next_due_in(%{}) end)

refused.("start/2 with the image of another configuration", fn ->
  Runtime.start(fans, %{configuration: "line", globals: %{}, instances: %{}, triggers: %{}})
end)

refused.("start/1 with a configuration that check/1 refuses", fn ->
  Runtime.start(%{fans | instances: [%{hd(fans.instances) | task: "fsat"}]})
end)
