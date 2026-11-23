{scans, _} = Code.eval_file("instructions-bitwise/scans.exs")

inputs = %{
  "faults" => [0x0010, 0x0010, 0x8000, 0xFFFF, 0xFFFF],
  "sel" => [4, 5, 15, 16, -1]
}

names = ["faults", "sel", "lamp", "checked"]
scans.("selected.ld", inputs, names)
