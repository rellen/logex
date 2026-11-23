{scans, _} = Code.eval_file("instructions-bitwise/scans.exs")

inputs = %{
  "status" => [0x0008, 0xFFF7, 0x8000, 0x0F0F],
  "shift" => [4, -1, 16, 8]
}

names = ["status", "shift", "at_speed", "slow_w", "low", "moved", "moved_ok", "flags"]
scans.("status.ld", inputs, names)
