{scans, _} = Code.eval_file("instructions-arithmetic-and-comparison/scans.exs")

inputs = %{
  "hz" => [0.375, 0.625, -0.625, 600.0],
  "status" => [0x0008, 0xFFFF, 0x8000, 0x0000],
  "boxes" => [100, 129, -129, 200]
}

names = ["hz", "speed", "rpm", "rpm_ok", "whole", "status", "code", "boxes", "shown", "shown_ok"]
scans.("conversions/fan_panel.ld", inputs, names)
