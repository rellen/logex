{scans, _} = Code.eval_file("instructions-bitwise/scans.exs")

inputs = %{
  "eyes" => [0b0000_0000, 0b0000_0001, 0b0000_0010, 0b0000_0010, 0b1000_0100, 0b0000_0000],
  "step" => [1, 0, 1, 1, 0, 1]
}

names = ["eyes", "step", "changed", "alarms", "lamps"]
scans.("instructions-bitwise/eyes.ld", inputs, names)
