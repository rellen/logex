{:ok, panel} = Logex.compile_file("faults/panel.ld")

columns = ["per_minute", "rate_ok", "fan_speed", "fan_ok", "lamp", "belt_sp", "belt_ok"]
IO.puts(Enum.join([String.pad_trailing("scan", 17) | columns], " "))

# Runs 1 scan, then prints the outputs and each fault of the scan.
scan = fn state, label, inputs ->
  state = Logex.Runtime.put_inputs(panel, state, inputs)
  {outputs, state} = Logex.Runtime.scan(panel, state)
  values = for name <- columns, do: String.pad_leading("#{outputs[name]}", String.length(name))
  IO.puts(Enum.join([String.pad_trailing(label, 17) | values], " "))

  for fault <- state.faults do
    what = Enum.map_join([fault.kind, fault.severity, fault.instruction], " ", &inspect/1)
    IO.puts("  #{what} line #{fault.line} read #{inspect(fault.read)}")
  end

  state
end

first = %{"drive" => 0x0010, "sel" => 4, "zone" => 1}

state =
  Logex.Runtime.put_inputs(panel, Logex.Runtime.instance(panel), first)
  |> scan.("1 in range", %{"boxes" => 120, "minutes" => 2, "pressure" => 4.0})
  |> scan.("2 minutes 0", %{"minutes" => 0})
  |> scan.("3 pressure -0.25", %{"minutes" => 2, "pressure" => -0.25})
  |> scan.("4 sel 16", %{"pressure" => 4.0, "sel" => 16})
  |> scan.("5 zone 4", %{"sel" => 4, "zone" => 4})
  |> scan.("6 all 4", %{"minutes" => 0, "pressure" => -1.0, "sel" => -1, "zone" => -1})

IO.puts("The first fault of scan 6:")
IO.inspect(hd(state.faults))
