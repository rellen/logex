alias Logex.Runtime

{:ok, motor} = Logex.compile_file("motor.ld")
# logex refuses an edit to a program of another name. compile_file/1 names this
# program `motor_v2`, so the script gives it the name `motor`.
{:ok, v2} = Logex.compile(File.read!("motor_v2.ld"), name: "motor")

# 1 line for each scan: the time, then 3 outputs.
# A dash is an output that the program does not have.
columns = [{"motor", 6}, {"at_speed", 9}, {"started", 8}]

scan = fn state, program, inputs, elapsed, label ->
  state = Runtime.put_inputs(program, state, inputs)
  {outputs, state} = Runtime.scan(program, state, elapsed)

  cells =
    Enum.map_join(columns, fn {name, width} ->
      String.pad_leading("#{Map.get(outputs, name, "-")}", width)
    end)

  IO.puts(String.pad_trailing(label, 11) <> String.pad_leading("#{state.now}", 5) <> cells)
  state
end

IO.puts(
  String.pad_trailing("", 11) <>
    "    t" <> Enum.map_join(columns, fn {name, width} -> String.pad_leading(name, width) end)
)

# motor.ld runs. The start button starts the motor, and the seal-in keeps it on.
running =
  Runtime.instance(motor)
  |> scan.(motor, %{"start" => 1}, 10, "motor.ld")
  |> scan.(motor, %{"start" => 0}, 10, "motor.ld")

# A plain swap: motor_v2.ld scans the same state, with no edit.
running
|> scan.(v2, %{}, 10, "plain swap")
|> scan.(v2, %{}, 2000, "plain swap")

# An online edit: the same state, moved to motor_v2.ld by a test.
{:ok, edit, _forecast} = Logex.Edit.accept(motor, v2, running)
{edit, state, report} = Logex.Edit.test(edit, running)

state
|> scan.(Logex.Edit.running(edit), %{}, 10, "online edit")
|> scan.(Logex.Edit.running(edit), %{}, 2000, "online edit")

# The report of the test, 1 entry on each line: the kind, then the name and the value.
# For a timer, the script shows only the preset.
value = fn
  name, %{"pre" => preset} -> "#{name}.pre=#{preset}"
  name, value -> "#{name}=#{value}"
end

IO.puts("the report of the test:")

Enum.each(report, fn {kind, name, detail} ->
  IO.puts("  " <> String.pad_trailing("#{kind}", 12) <> value.(name, detail))
end)
