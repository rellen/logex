{:ok, boxes} = Logex.compile_file("boxes.ld")
# The file of the new program is a boxes.ld also, so the new program has the name `boxes`.
{:ok, new} = Logex.compile_file("edit-inputs-and-outputs/boxes.ld")

# The input points of the plant. Box 3 stays at the photo-eye.
points = %{"eye" => 1, "reset_pb" => 0, "case_gone" => 0}

# The duty of the host for each entry of a report.
duty = fn
  {:input, name, _value}, host -> %{host | send: [name | host.send]}
  {:unread, name, _value}, host -> %{host | send: host.send -- [name]}
  {:held, name, value}, host -> %{host | held: Map.put(host.held, name, value)}
  _entry, host -> host
end

step = fn {edit, state, report}, host, label ->
  IO.puts(label)
  Enum.each(report, &IO.puts("        #{inspect(&1)}"))
  {edit, state, Enum.reduce(report, host, duty)}
end

# 1 scan. The host sends the inputs of its list. It writes the outputs and the held points.
scan = fn state, program, host, label ->
  inputs = Map.take(points, host.send)
  state = Logex.Runtime.put_inputs(program, state, inputs)
  {outputs, state} = Logex.Runtime.scan(program, state, 10)
  IO.puts("#{label}  sends  #{inspect(Map.keys(inputs))}")
  IO.puts("             writes #{inspect(Map.merge(host.held, outputs))}")
  state
end

# 3 boxes go past the photo-eye.
state =
  Enum.reduce([0, 1, 0, 1, 0, 1], Logex.Runtime.instance(boxes), fn eye, state ->
    state = Logex.Runtime.put_inputs(boxes, state, %{"eye" => eye})
    elem(Logex.Runtime.scan(boxes, state, 10), 1)
  end)

host = %{send: ["eye", "reset_pb"], held: %{}}
state = scan.(state, boxes, host, "old program")

{:ok, edit, _forecast} = Logex.Edit.accept(boxes, new, state)
{edit, state, host} = step.(Logex.Edit.test(edit, state), host, "test")
state = scan.(state, Logex.Edit.running(edit), host, "under test ")
{edit, state, host} = step.(Logex.Edit.untest(edit, state), host, "untest")
state = scan.(state, Logex.Edit.running(edit), host, "untested   ")
{boxes, state, host} = step.(Logex.Edit.cancel(edit, state), host, "cancel")
scan.(state, boxes, host, "old program")
