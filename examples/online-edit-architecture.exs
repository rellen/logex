alias Logex.{Edit, Runtime}

{:ok, motor} = Logex.compile_file("motor.ld")
# An edit keeps the name of the program, so the script gives motor_v2.ld the name `motor`.
{:ok, v2} = Logex.compile(File.read!("motor_v2.ld"), name: "motor")

# 1 line for each step: 3 fields of the instance. Then 1 line for each entry of the
# report: the kind, the name and the value. For a timer, the script shows only the preset.
value = fn
  %{"pre" => preset} -> "pre=#{preset}"
  value -> inspect(value)
end

show = fn label, state, report ->
  fields = Map.take(state, [:now, :switched, :ons_blocked])
  IO.puts(String.pad_trailing(label, 9) <> inspect(fields))

  Enum.each(report, fn {kind, name, detail} ->
    IO.puts("  " <> String.pad_trailing("#{kind}", 12) <> "#{name} " <> value.(detail))
  end)
end

state = Runtime.put_inputs(motor, Runtime.instance(motor), %{"start" => 1})
{_outputs, state} = Runtime.scan(motor, state, 10)
show.("before", state, [])

# The accept does the switch of a test, keeps its report and drops its state.
{:ok, edit, forecast} = Edit.accept(motor, v2, state)
{edit, tested, report} = Edit.test(edit, state)
show.("test", tested, report)
IO.puts("forecast is the report of the test: #{forecast == report}")

# This report has only :added writes. Applied to the state before the test, they give
# the state after it.
added = for {:added, name, value} <- report, into: %{}, do: {name, value}
IO.puts("state rebuilt from the report: #{Map.merge(state.env, added) == tested.env}")

# An untest with no scan between gives the instance back. It removes nothing.
{edit, untested, report} = Edit.untest(edit, tested)
show.("untest", untested, report)
IO.puts("the tags of the test stay: #{Map.merge(state.env, added) == untested.env}")

{edit, tested, report} = Edit.test(edit, untested)
show.("test", tested, report)
# running/1 gives the program that the instance runs at this stage of the edit.
{_outputs, scanned} = Runtime.scan(Edit.running(edit), tested, 10)
show.("scan", scanned, [])
{_program, assembled, report} = Edit.assemble(edit, scanned)
show.("assemble", assembled, report)
