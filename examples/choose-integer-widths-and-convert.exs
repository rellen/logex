{:ok, drive} = Logex.compile_file("choose-integer-widths-and-convert/drive.ld")
names = ["speed", "twice", "twice_ok", "trim", "trim_ok", "offset"]

scan = fn state, number, inputs ->
  state = Logex.Runtime.put_inputs(drive, state, inputs)
  {outputs, state} = Logex.Runtime.scan(drive, state)
  IO.puts("#{number}  " <> Enum.map_join(names, "  ", &"#{&1} #{outputs[&1]}"))
  state
end

Logex.Runtime.instance(drive)
|> scan.(1, %{"hz" => 1200, "level" => 100})
|> scan.(2, %{"hz" => 65_535, "level" => 129})
|> scan.(3, %{"level" => -1})
