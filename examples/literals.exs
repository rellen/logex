{:ok, fan_drive} = Logex.compile_file("literals/fan_drive.ld")

inputs = %{"eye" => 1, "status" => 4613, "hz" => 30.0}
state = Logex.Runtime.put_inputs(fan_drive, Logex.Runtime.instance(fan_drive), inputs)
{_outputs, state} = Logex.Runtime.scan(fan_drive, state)

for name <- ["mask", "code", "fault", "rpm", "fast", "trim"] do
  IO.puts("#{String.pad_trailing(name, 11)} #{inspect(state.env[name])}")
end

IO.puts("blocked.pre #{state.env["blocked"]["pre"]}")
