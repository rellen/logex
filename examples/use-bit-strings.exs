{:ok, drive} = Logex.compile_file("use-bit-strings/status.ld")

hex = fn value ->
  "16#" <> String.pad_leading(String.downcase(Integer.to_string(value, 16)), 4, "0")
end

scan = fn state, number, inputs ->
  state = Logex.Runtime.put_inputs(drive, state, inputs)
  {outputs, state} = Logex.Runtime.scan(drive, state)
  bits = Enum.map_join(["at_speed", "lamp"], "  ", &"#{&1} #{outputs[&1]}")
  words = Enum.map_join(["flags", "error", "command"], "  ", &"#{&1} #{hex.(outputs[&1])}")
  IO.puts("#{number}  #{bits}  #{words}  code #{outputs["code"]}  faults #{length(state.faults)}")
  state
end

Logex.Runtime.instance(drive)
|> scan.(1, %{"status" => 0x0009, "run" => 1, "sel" => 3})
|> scan.(2, %{"status" => 0x2A01, "run" => 0, "sel" => 13})
|> scan.(3, %{"sel" => 16})
