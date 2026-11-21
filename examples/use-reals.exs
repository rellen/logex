{:ok, fan} = Logex.compile_file("use-reals/fan.ld")

show = fn outputs, names -> Enum.map_join(names, "  ", &"#{&1} #{inspect(outputs[&1])}") end

scan = fn state, hz ->
  state = Logex.Runtime.put_inputs(fan, state, %{"hz" => hz})
  {outputs, state} = Logex.Runtime.scan(fan, state)
  IO.puts("hz #{inspect(hz)}")
  IO.puts("  " <> show.(outputs, ["speed", "precise", "root", "root_ok"]))
  IO.puts("  " <> show.(outputs, ["rpm", "rpm_ok", "whole", "whole_ok"]))

  for fault <- state.faults,
      do: IO.puts("  fault #{inspect(fault.kind)} on line #{fault.line}, read #{fault.read}")

  state
end

state =
  Logex.Runtime.instance(fan)
  |> scan.(0.1)
  |> scan.(0.125)
  |> scan.(0.375)
  |> scan.(-0.25)
  |> scan.(600)

try do
  Logex.Runtime.put_inputs(fan, state, %{"hz" => 1.0e39})
rescue
  error in ArgumentError -> IO.puts(Exception.message(error))
end
